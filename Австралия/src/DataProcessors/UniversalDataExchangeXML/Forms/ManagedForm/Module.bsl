
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// First of all, checking the access rights.
	If Not AccessRight("Administration", Metadata) Then
		Raise NStr("ru = 'Использование обработки в интерактивном режиме доступно только администратору.'; en = 'Running the data processor manually requires administrator rights.'; pl = 'Używanie przetwarzania danych w trybie interaktywnym jest dostępne tylko dla administratora.';es_ES = 'Uso del procesador de datos en el modo interactivo está disponible solo para el administrador';es_CO = 'Uso del procesador de datos en el modo interactivo está disponible solo para el administrador';tr = 'Etkileşimli modda veri işlemcisi kullanımı sadece yönetici için kullanılabilir.';it = 'L''utilizzo dell''elaborazione in modalità interattiva è disponibile solo per l''amministratore.';de = 'Die Verwendung des Datenprozessors im interaktiven Modus ist nur für Administratoren verfügbar.'");
	EndIf;
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	CheckPlatformVersionAndCompatibilityMode();
	
	Object.IsInteractiveMode = True;
	Object.SafeMode = True;
	
	FormHeader = NStr("ru = 'Универсальный обмен данными в формате XML (%DataProcessorVersion%)'; en = 'Universal data exchange in XML format (%DataProcessorVersion%)'; pl = 'Uniwersalna wymiana danymi w formacie XML (%DataProcessorVersion%)';es_ES = 'Intercambio de datos universal en el formato XML (%DataProcessorVersion%)';es_CO = 'Intercambio de datos universal en el formato XML (%DataProcessorVersion%)';tr = 'XML formatında üniversal veri değişimi (%DataProcessorVersion%)';it = 'Scambio dati universale in formato XML (%DataProcessorVersion%)';de = 'Universeller Datenaustausch im XML-Format (%DataProcessorVersion%)'");
	FormHeader = StrReplace(FormHeader, "%DataProcessorVersion%", ObjectVersionAsStringAtServer());
	
	Title = FormHeader;
	
	FillTypeAvailableToDeleteList();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	Items.RulesFileName.ChoiceList.LoadValues(ExchangeRules.UnloadValues());
	Items.ExchangeFileName.ChoiceList.LoadValues(DataImportFromFile.UnloadValues());
	Items.DataFileName.ChoiceList.LoadValues(DataExportToFile.UnloadValues());
	
	OnPeriodChange();
	
	OnChangeChangesRegistrationDeletionType();
	
	ClearDataImportFileData();
	
	DirectExport = ?(Object.DirectReadingInDestinationIB, 1, 0);
	
	SavedImportMode = (Object.ExchangeMode = "Load");
	
	If SavedImportMode Then
		
		// Setting the appropriate page.
		Items.FormMainPanel.CurrentPage = Items.FormMainPanel.ChildItems.Load;
		
	EndIf;
	
	ProcessTransactionManagementItemsEnabled();
	
	ExpandTreeRows(DataToDelete, Items.DataToDelete, "Check");
	
	ArchiveFileOnValueChange();
	DirectExportOnValueChange();
	
	ChangeProcessingMode(IsClient);
	
	#If WebClient Then
		Items.ExportDebugPages.CurrentPage = Items.ExportDebugPages.ChildItems.WebClientExportGroup;
		Items.ImportDebugPages.CurrentPage = Items.ImportDebugPages.ChildItems.WebClientImportGroup;
		Object.HandlersDebugModeFlag = False;
	#EndIf
	
	SetDebugCommandsEnabled();
	
	If SavedImportMode
		AND Object.AutomaticDataImportSetup <> 0 Then
		
		If Object.AutomaticDataImportSetup = 1 Then
			
			NotifyDescription = New NotifyDescription("OnOpenCompletion", ThisObject);
			ShowQueryBox(NotifyDescription, NStr("ru = 'Выполнить загрузку данных из файла обмена?'; en = 'Do you want to import data from the exchange file?'; pl = 'Importować dane z pliku wymiany?';es_ES = '¿Importar los datos del archivo de intercambio?';es_CO = '¿Importar los datos del archivo de intercambio?';tr = 'Veri alışveriş dosyasından içe aktarılsın mı?';it = 'Volete importare i dati dal file di scambio?';de = 'Daten von der Austausch-Datei importieren?'"), QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
			
		Else
			
			OnOpenCompletion(DialogReturnCode.Yes, Undefined);
			
		EndIf;
		
	EndIf;
	
	If Not IsWindowsClient() Then
		Items.OSGroup.CurrentPage = Items.OSGroup.ChildItems.LinuxGroup;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpenCompletion(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		ExecuteImportFromForm();
		ExportPeriodPresentation = PeriodPresentation(Object.StartDate, Object.EndDate);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ArchiveFileOnChange(Item)
	
	ArchiveFileOnValueChange();
	
EndProcedure

&AtClient
Procedure ExchangeRuleFileNameStartChoice(Item, ChoiceData, StandardProcessing)
	
	SelectFile(Item, ThisObject, "RulesFileName", True, , False, True);
	
EndProcedure

&AtClient
Procedure ExchangeRuleFileNameOpen(Item, StandardProcessing)
	
	OpenInApplication(Item.EditText, StandardProcessing);
	
EndProcedure

&AtClient
Procedure DirectExportOnChange(Item)
	
	DirectExportOnValueChange();
	
EndProcedure

&AtClient
Procedure FormMainPanelOnCurrentPageChange(Item, CurrentPage)
	
	If CurrentPage.Name = "DataExported" Then
		
		Object.ExchangeMode = "DataExported";
		
	ElsIf CurrentPage.Name = "Load" Then
		
		Object.ExchangeMode = "Load";
		
	EndIf;
	
EndProcedure

&AtClient
Procedure DebugModeFlagOnChange(Item)
	
	If Object.DebugModeFlag Then
		
		Object.UseTransactions = False;
				
	EndIf;
	
	ProcessTransactionManagementItemsEnabled();

EndProcedure

&AtClient
Procedure ProcessedObjectCountToUpdateStatusOnChange(Item)
	
	If Object.ProcessedObjectsCountToUpdateStatus = 0 Then
		Object.ProcessedObjectsCountToUpdateStatus = 100;
	EndIf;
	
EndProcedure

&AtClient
Procedure ExchangeFileNameStartChoice(Item, ChoiceData, StandardProcessing)
	
	SelectFile(Item, ThisObject, "ExchangeFileName", False, , Object.ArchiveFile);
	
EndProcedure

&AtClient
Procedure ExchangeProtocolFileNameStartChoice(Item, ChoiceData, StandardProcessing)
	
	SelectFile(Item, Object, "ExchangeProtocolFileName", False, "txt", False);
	
EndProcedure

&AtClient
Procedure ImportExchangeProtocolFileNameStartChoice(Item, ChoiceData, StandardProcessing)
	
	SelectFile(Item, Object, "ImportExchangeLogFileName", False, "txt", False);
	
EndProcedure

&AtClient
Procedure DataFileNameStartChoice(Item, ChoiceData, StandardProcessing)
	
	SelectFile(Item, ThisObject, "DataFileName", False, , Object.ArchiveFile);
	
EndProcedure

&AtClient
Procedure InfobaseConnectionDirectoryStartChoice(Item, ChoiceData, StandardProcessing)
	
	FileSelectionDialog = New FileDialog(FileDialogMode.ChooseDirectory);
	
	FileSelectionDialog.Title = NStr("ru = 'Выберите каталог информационной базы'; en = 'Select infobase directory'; pl = 'Wybierz katalog bazy informacyjnej';es_ES = 'Seleccionar un directorio de la infobase';es_CO = 'Seleccionar un directorio de la infobase';tr = 'Bir veritabanı yedekleme dizini seçin';it = 'Selezionare la directory dell''infobase';de = 'Wählen Sie ein Infobase-Verzeichnis'");
	FileSelectionDialog.Directory = Object.InfobaseToConnectDirectory;
	FileSelectionDialog.CheckFileExist = True;
	
	Notification = New NotifyDescription("ProcessSelectionInfobaseDirectoryToAdd", ThisObject);
	FileSelectionDialog.Show(Notification);
	
EndProcedure

&AtClient
Procedure ProcessSelectionInfobaseDirectoryToAdd(SelectedFiles, AdditionalParameters) Export
	
	If SelectedFiles = Undefined Then
		Return;
	EndIf;
	
	Object.InfobaseToConnectDirectory = SelectedFiles[0];
	
EndProcedure

&AtClient
Procedure ExchangeProtocolFileNameOpen(Item, StandardProcessing)
	
	OpenInApplication(Item.EditText, StandardProcessing);
	
EndProcedure

&AtClient
Procedure ImportExchangeProtocolFileNameOpen(Item, StandardProcessing)
	
	OpenInApplication(Item.EditText, StandardProcessing);
	
EndProcedure

&AtClient
Procedure InfobaseConnectionDirectoryOpen(Item, StandardProcessing)
	
	OpenInApplication(Item.EditText, StandardProcessing);
	
EndProcedure

&AtClient
Procedure InfobaseWindowsAuthenticationForConnectionOnChange(Item)
	
	Items.InfobaseToConnectUser.Enabled = NOT Object.InfobaseToConnectWindowsAuthentication;
	Items.InfobaseToConnectPassword.Enabled = NOT Object.InfobaseToConnectWindowsAuthentication;
	
EndProcedure

&AtClient
Procedure RuleFileNameOnChange(Item)
	
	File = New File(RulesFileName);
	
	Notification = New NotifyDescription("AfterExistenceCheckRulesFileName", ThisObject);
	File.BeginCheckingExistence(Notification);
	
EndProcedure

&AtClient
Procedure AfterExistenceCheckRulesFileName(Exists, AdditionalParameters) Export
	
	If Not Exists Then
		MessageToUser(NStr("ru = 'Не найден файл правил обмена'; en = 'Exchange rule file not found'; pl = 'Nie znaleziono pliku reguł wymiany.';es_ES = 'Archivo de las reglas de intercambio no encontrado';es_CO = 'Archivo de las reglas de intercambio no encontrado';tr = 'Değişim kuralları dosyası bulunamadı';it = 'Il file regole di scambio non è stato trovato';de = 'Die Datei der Austauschregeln wurde nicht gefunden'"), "RulesFileName");
		SetImportRuleFlag(False);
		Return;
	EndIf;
	
	If RuleAndExchangeFileNamesMatch() Then
		Return;
	EndIf;
	
	NotifyDescription = New NotifyDescription("RuleFileNameOnChangeCompletion", ThisObject);
	ShowQueryBox(NotifyDescription, NStr("ru = 'Загрузить правила обмена данными?'; en = 'Do you want to import data exchange rules?'; pl = 'Importuj reguły wymiany danych?';es_ES = '¿Importar las reglas de intercambio de datos?';es_CO = '¿Importar las reglas de intercambio de datos?';tr = 'Veri değişimi kuralları içe aktarılsın mı?';it = 'Volete importare le regole di scambio dati?';de = 'Importieren Sie Datenaustauschregeln?'"), QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
	
EndProcedure

&AtClient
Procedure RuleFileNameOnChangeCompletion(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		ExecuteImportExchangeRules();
		
	Else
		
		SetImportRuleFlag(False);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExchangeFileNameOpen(Item, StandardProcessing)
	
	OpenInApplication(Item.EditText, StandardProcessing);
	
EndProcedure

&AtClient
Procedure ExchangeFileNameOnChange(Item)
	
	ClearDataImportFileData();
	
EndProcedure

&AtClient
Procedure UseTransactionsOnChange(Item)
	
	ProcessTransactionManagementItemsEnabled();
	
EndProcedure

&AtClient
Procedure ImportHandlerDebugModeFlagOnChange(Item)
	
	SetDebugCommandsEnabled();
	
EndProcedure

&AtClient
Procedure ExportHandlerDebugModeFlagOnChange(Item)
	
	SetDebugCommandsEnabled();
	
EndProcedure

&AtClient
Procedure DataFileNameOpening(Item, StandardProcessing)
	
	OpenInApplication(Item.EditText, StandardProcessing);
	
EndProcedure

&AtClient
Procedure DataFileNameOnChange(Item)
	
	If EmptyAttributeValue(DataFileName, "DataFileName", Items.DataFileName.Title)
		Or RuleAndExchangeFileNamesMatch() Then
		Return;
	EndIf;
	
	Object.ExchangeFileName = DataFileName;
	
	File = New File(Object.ExchangeFileName);
	ArchiveFile = (Upper(File.Extension) = Upper(".zip"));
	
EndProcedure

&AtClient
Procedure InfobaseTypeForConnectionOnChange(Item)
	
	InfobaseTypeForConnectionOnValueChange();
	
EndProcedure

&AtClient
Procedure InfobasePlatformVersionForConnectionOnChange(Item)
	
	If IsBlankString(Object.InfobaseToConnectPlatformVersion) Then
		
		Object.InfobaseToConnectPlatformVersion = "V8";
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ChangeRecordsForExchangeNodeDeleteAfterExportTypeOnChange(Item)
	
	OnChangeChangesRegistrationDeletionType();
	
EndProcedure

&AtClient
Procedure ExportPeriodOnChange(Item)
	
	OnPeriodChange();
	
EndProcedure

&AtClient
Procedure DeletionPeriodOnChange(Item)
	
	OnPeriodChange();
	
EndProcedure

&AtClient
Procedure SafeImportOnChange(Item)
	
	ChangeSafeImportMode();
	
EndProcedure

&AtClient
Procedure NameOfImportRulesFileStartChoice(Item, ChoiceData, StandardProcessing)
	
	SelectFile(Item, ThisObject, "NameOfImportRulesFile", True, , False, True);
	
EndProcedure

&AtClient
Procedure NameOfImportRulesFileOnChange(Item)
	
	PutImportRulesFileInStorage();
	
EndProcedure

#EndRegion

#Region ExportRuleTableFormTableItemEventHandlers

&AtClient
Procedure ExportRuleTableBeforeRowChange(Item, Cancel)
	
	If Item.CurrentItem.Name = "ExchangeNodeRef" Then
		
		If Item.CurrentData.IsFolder Then
			Cancel = True;
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExportRuleTableOnChange(Item)
	
	If Item.CurrentItem.Name = "DER" Then
		
		curRow = Item.CurrentData;
		
		If curRow.Enable = 2 Then
			curRow.Enable = 0;
		EndIf;
		
		SetSubordinateMarks(curRow, "Enable");
		SetParentMarks(curRow, "Enable");
		
	EndIf;
	
EndProcedure

#EndRegion

#Region DataToDeleteFormTableItemEventHandlers

&AtClient
Procedure DataToDeleteOnChange(Item)
	
	curRow = Item.CurrentData;
	
	SetSubordinateMarks(curRow, "Check");
	SetParentMarks(curRow, "Check");

EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ConnectionTest(Command)
	
	EstablishConnectionWithDestinationIBAtServer();
	
EndProcedure

&AtClient
Procedure GetExchangeFileInfo(Command)
	
	FileAddress = "";
	
	If IsClient Then
		
		NotifyDescription = New NotifyDescription("GetExchangeFileInfoCompletion", ThisObject);
		BeginPutFile(NotifyDescription, FileAddress,NStr("ru = 'Файл обмена'; en = 'Exchange file'; pl = 'Plik wymiany';es_ES = 'Archivo de intercambio';es_CO = 'Archivo de intercambio';tr = 'Alışveriş dosyası';it = 'File di scambio';de = 'Datei austauschen'"),, UUID);
		
	Else
		
		GetExchangeFileInfoCompletion(True, FileAddress, "", Undefined);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure GetExchangeFileInfoCompletion(Result, Address, SelectedFileName, AdditionalParameters) Export
	
	If Result Then
		
		Try
			
			OpenImportFileAtServer(Address);
			ExportPeriodPresentation = PeriodPresentation(Object.StartDate, Object.EndDate);
			
		Except
			
			MessageToUser(NStr("ru = 'Не удалось прочитать файл обмена.'; en = 'Cannot read the exchange file.'; pl = 'Nie można odczytać pliku wymiany.';es_ES = 'No se puede leer el archivo de intercambio.';es_CO = 'No se puede leer el archivo de intercambio.';tr = 'Değişim dosyası okunamıyor.';it = 'Impossibile leggere il file di scambio.';de = 'Die Austauschdatei kann nicht gelesen werden.'"));
			ClearDataImportFileData();
			
		EndTry;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure DeletionSelectAll(Command)
	
	For Each Row In DataToDelete.GetItems() Do
		
		Row.Check = 1;
		SetSubordinateMarks(Row, "Check");
		
	EndDo;
	
EndProcedure

&AtClient
Procedure DeletionClearAll(Command)
	
	For Each Row In DataToDelete.GetItems() Do
		Row.Check = 0;
		SetSubordinateMarks(Row, "Check");
	EndDo;
	
EndProcedure

&AtClient
Procedure DeletionDelete(Command)
	
	NotifyDescription = New NotifyDescription("DeletionDeleteCompletion", ThisObject);
	ShowQueryBox(NotifyDescription, NStr("ru = 'Удалить выбранные данные в информационной базе?'; en = 'Do you want to delete selected data?'; pl = 'Usunąć wybrane dane z bazy informacyjnej?';es_ES = '¿Borrar los datos seleccionados en la infobase?';es_CO = '¿Borrar los datos seleccionados en la infobase?';tr = 'Seçilen veriler silinsin mi?';it = 'Volete eliminare i dati selezionati?';de = 'Die ausgewählten Daten in der Infobase löschen?'"), QuestionDialogMode.YesNo, , DialogReturnCode.No);
	
EndProcedure

&AtClient
Procedure DeletionDeleteCompletion(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		DeleteAtServer();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExportSelectAll(Command)
	
	For Each Row In Object.ExportRuleTable.GetItems() Do
		Row.Enable = 1;
		SetSubordinateMarks(Row, "Enable");
	EndDo;
	
EndProcedure

&AtClient
Procedure ExportClearAll(Command)
	
	For Each Row In Object.ExportRuleTable.GetItems() Do
		Row.Enable = 0;
		SetSubordinateMarks(Row, "Enable");
	EndDo;
	
EndProcedure

&AtClient
Procedure ExportClearExchangeNodes(Command)
	
	FillExchangeNodeInTreeRowsAtServer(Undefined);
	
EndProcedure

&AtClient
Procedure ExportMarkExchangeNode(Command)
	
	If Items.ExportRuleTable.CurrentData = Undefined Then
		Return;
	EndIf;
	
	FillExchangeNodeInTreeRowsAtServer(Items.ExportRuleTable.CurrentData.ExchangeNodeRef);
	
EndProcedure

&AtClient
Procedure SaveParameters(Command)
	
	SaveParametersAtServer();
	
EndProcedure

&AtClient
Procedure RestoreParameters(Command)
	
	RestoreParametersAtServer();
	
EndProcedure

&AtClient
Procedure ExportDebugSetup(Command)
	
	Object.ExchangeRuleFileName = FileNameAtServerOrClient(RulesFileName, RuleFileAddressInStorage);
	
	OpenHandlerDebugSetupForm(True);
	
EndProcedure

&AtClient
Procedure AtClient(Command)
	
	If Not IsClient Then
		
		IsClient = True;
		
		ChangeProcessingMode(IsClient);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AtServer(Command)
	
	If IsClient Then
		
		IsClient = False;
		
		ChangeProcessingMode(IsClient);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ImportDebugSetup(Command)
	
	ExchangeFileAddressInStorage = "";
	FileNameForExtension = "";
	
	If IsClient Then
		
		NotifyDescription = New NotifyDescription("ImportDebugSetupCompletion", ThisObject);
		BeginPutFile(NotifyDescription, ExchangeFileAddressInStorage,NStr("ru = 'Файл обмена'; en = 'Exchange file'; pl = 'Plik wymiany';es_ES = 'Archivo de intercambio';es_CO = 'Archivo de intercambio';tr = 'Alışveriş dosyası';it = 'File di scambio';de = 'Datei austauschen'"),, UUID);
		
	Else
		
		If EmptyAttributeValue(ExchangeFileName, "ExchangeFileName", Items.ExchangeFileName.Title) Then
			Return;
		EndIf;
		
		ImportDebugSetupCompletion(True, ExchangeFileAddressInStorage, FileNameForExtension, Undefined);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ImportDebugSetupCompletion(Result, Address, SelectedFileName, AdditionalParameters) Export
	
	If Result Then
		
		Object.ExchangeFileName = FileNameAtServerOrClient(ExchangeFileName ,Address, SelectedFileName);
		
		OpenHandlerDebugSetupForm(False);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteExport(Command)
	
	ExecuteExportFromForm();
	
EndProcedure

&AtClient
Procedure ExecuteImport(Command)
	
	ExecuteImportFromForm();
	
EndProcedure

&AtClient
Procedure ReadExchangeRules(Command)
	
	If Not IsWindowsClient() AND DirectExport = 1 Then
		ShowMessageBox(,NStr("ru = 'Прямое подключение к информационной базе поддерживается только в клиенте под управлением ОС Windows.'; en = 'Direct connection to the infobase is available only on a client running Windows OS.'; pl = 'Bezpośrednie podłączenie do bazy informacyjnej jest obsługiwane tylko w kliencie w systemie operacyjnym Windows.';es_ES = 'Conexión directa a la infobase solo se admite en un cliente bajo OS Windows.';es_CO = 'Conexión directa a la infobase solo se admite en un cliente bajo OS Windows.';tr = 'Veri tabanına doğrudan bağlantı yalnızca Windows tabanlı bir istemcide desteklenir.';it = 'Connessione diretta all''infobase è disponibile solo un client che utilizza Sistema Operativo Windows.';de = 'Eine direkte Verbindung zur Informationsbasis wird nur auf dem Client unter Windows unterstützt.'"));
		Return;
	EndIf;
	
	FileNameForExtension = "";
	
	If IsClient Then
		
		NotifyDescription = New NotifyDescription("ReadExchangeRulesCompletion", ThisObject);
		BeginPutFile(NotifyDescription, RuleFileAddressInStorage,NStr("ru = 'Файл правил обмена'; en = 'Exchange rule file'; pl = 'Plik reguł wymiany';es_ES = 'Archivo de la regla de intercambio';es_CO = 'Archivo de la regla de intercambio';tr = 'Alışveriş kuralı dosyası';it = 'File regole di scambio';de = 'Austausch-Regeldatei'"),, UUID);
		
	Else
		
		RuleFileAddressInStorage = "";
		If EmptyAttributeValue(RulesFileName, "RulesFileName", Items.RulesFileName.Title) Then
			Return;
		EndIf;
		
		ReadExchangeRulesCompletion(True, RuleFileAddressInStorage, FileNameForExtension, Undefined);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ReadExchangeRulesCompletion(Result, Address, SelectedFileName, AdditionalParameters) Export
	
	If Result Then
		
		RuleFileAddressInStorage = Address;
		
		ExecuteImportExchangeRules(Address, SelectedFileName);
		
		If Object.ErrorFlag Then
			
			SetImportRuleFlag(False);
			
		Else
			
			SetImportRuleFlag(True);
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

// Opens an exchange file in an external application.
//
// Parameters:
//  
// 
&AtClient
Procedure OpenInApplication(FileName, StandardProcessing = False)
	
	StandardProcessing = False;
	
	AdditionalParameters = New Structure();
	AdditionalParameters.Insert("FileName", FileName);
	AdditionalParameters.Insert("NotifyDescription", New NotifyDescription);
	
	File = New File();
	File.BeginInitialization(New NotifyDescription("CheckFileExistence", ThisObject, AdditionalParameters), FileName);
	
EndProcedure

// Continuation of the procedure (see above).
&AtClient
Procedure CheckFileExistence(File, AdditionalParameters) Export
	NotifyDescription = New NotifyDescription("AfterDetermineFileExistence", ThisObject, AdditionalParameters);
	File.BeginCheckingExistence(NotifyDescription);
EndProcedure

// Continuation of the procedure (see above).
&AtClient
Procedure AfterDetermineFileExistence(Exists, AdditionalParameters) Export
	
	If Exists Then
		BeginRunningApplication(AdditionalParameters.NotifyDescription, AdditionalParameters.FileName);
	EndIf;
	
EndProcedure

&AtClient
Procedure ClearDataImportFileData()
	
	Object.ExchangeRulesVersion = "";
	Object.DataExportDate = "";
	ExportPeriodPresentation = "";
	
EndProcedure

&AtClient
Procedure ProcessTransactionManagementItemsEnabled()
	
	Items.UseTransactions.Enabled = NOT Object.DebugModeFlag;
	
	Items.ObjectCountPerTransaction.Enabled = Object.UseTransactions;
	
EndProcedure

&AtClient
Procedure ArchiveFileOnValueChange()
	
	If Object.ArchiveFile Then
		DataFileName = StrReplace(DataFileName, ".xml", ".zip");
	Else
		DataFileName = StrReplace(DataFileName, ".zip", ".xml");
	EndIf;
	
	Items.ExchangeFileCompressionPassword.Enabled = Object.ArchiveFile;
	
EndProcedure

&AtServer
Procedure FillExchangeNodeInTreeRows(Tree, ExchangeNode)
	
	For Each Row In Tree Do
		
		If Row.IsFolder Then
			
			FillExchangeNodeInTreeRows(Row.GetItems(), ExchangeNode);
			
		Else
			
			Row.ExchangeNodeRef = ExchangeNode;
			
		EndIf;
		
	EndDo;
	
EndProcedure

&AtClient
Function RuleAndExchangeFileNamesMatch()
	
	If Upper(TrimAll(RulesFileName)) = Upper(TrimAll(DataFileName)) Then
		
		MessageToUser(NStr("ru = 'Файл правил обмена не может совпадать с файлом данных.
		|Выберите другой файл для выгрузки данных.'; 
		|en = 'Exchange rule file cannot match the data file.
		|Select another file to export the data to.'; 
		|pl = 'Plik reguł wymiany nie może być jednakowy z plikiem danych.
		|Wybierz inny plik do eksportu danych.';
		|es_ES = 'Archivo de las reglas de intercambio no puede emparejarse con el archivo de datos.
		|Seleccionar otro archivo para la exportación de datos.';
		|es_CO = 'Archivo de las reglas de intercambio no puede emparejarse con el archivo de datos.
		|Seleccionar otro archivo para la exportación de datos.';
		|tr = 'Alışveriş kuralları dosyası veri dosyasıyla eşleşemez. 
		|Veri aktarımı için diğer dosyayı seçin.';
		|it = 'Il file regole di scambio non corrispondono ai dati del file.
		|Selezionare un altro file in cui esportare i dati.';
		|de = 'Die Austausch-Regeldatei kann nicht mit der Datendatei übereinstimmen.
		|Wählen Sie die andere Datei für den Datenexport.'"));
		Return True;
		
	Else
		
		Return False;
		
	EndIf;
	
EndFunction

// Fills a value tree with metadata objects available for deletion
&AtServer
Procedure FillTypeAvailableToDeleteList()
	
	DataTree = FormAttributeToValue("DataToDelete");
	
	DataTree.Rows.Clear();
	
	TreeRow = DataTree.Rows.Add();
	TreeRow.Presentation = NStr("ru = 'Справочники'; en = 'Catalogs'; pl = 'Katalogi';es_ES = 'Catálogos';es_CO = 'Catálogos';tr = 'Ana kayıtlar';it = 'Anagrafiche';de = 'Kataloge'");
	
	For each MetadateObject In Metadata.Catalogs Do
		
		If Not AccessRight("Delete", MetadateObject) Then
			Continue;
		EndIf;
		
		MDRow = TreeRow.Rows.Add();
		MDRow.Presentation = MetadateObject.Name;
		MDRow.Metadata = "CatalogRef." + MetadateObject.Name;
		
	EndDo;
	
	TreeRow = DataTree.Rows.Add();
	TreeRow.Presentation = NStr("ru = 'Планы видов характеристик'; en = 'Charts of characteristic types'; pl = 'Plany rodzajów charakterystyk';es_ES = 'Diagramas de los tipos de características';es_CO = 'Diagramas de los tipos de características';tr = 'Özellik türü listeleri';it = 'Grafici di tipi caratteristiche';de = 'Diagramme von charakteristischen Typen'");
	
	For each MetadateObject In Metadata.ChartsOfCharacteristicTypes Do
		
		If Not AccessRight("Delete", MetadateObject) Then
			Continue;
		EndIf;
		
		MDRow = TreeRow.Rows.Add();
		MDRow.Presentation = MetadateObject.Name;
		MDRow.Metadata = "ChartOfCharacteristicTypesRef." + MetadateObject.Name;
		
	EndDo;
	
	TreeRow = DataTree.Rows.Add();
	TreeRow.Presentation = NStr("ru = 'Документы'; en = 'Documents'; pl = 'Dokumenty';es_ES = 'Documentos';es_CO = 'Documentos';tr = 'Belgeler';it = 'Documenti';de = 'Dokumente'");
	
	For each MetadateObject In Metadata.Documents Do
		
		If Not AccessRight("Delete", MetadateObject) Then
			Continue;
		EndIf;
		
		MDRow = TreeRow.Rows.Add();
		MDRow.Presentation = MetadateObject.Name;
		MDRow.Metadata = "DocumentRef." + MetadateObject.Name;
		
	EndDo;
	
	TreeRow = DataTree.Rows.Add();
	TreeRow.Presentation = "InformationRegisters";
	
	For each MetadateObject In Metadata.InformationRegisters Do
		
		If Not AccessRight("Update", MetadateObject) Then
			Continue;
		EndIf;
		
		Subordinate = (MetadateObject.WriteMode = Metadata.ObjectProperties.RegisterWriteMode.RecorderSubordinate);
		If Subordinate Then Continue EndIf;
		
		MDRow = TreeRow.Rows.Add();
		MDRow.Presentation = MetadateObject.Name;
		MDRow.Metadata = "InformationRegisterRecord." + MetadateObject.Name;
		
	EndDo;
	
	ValueToFormAttribute(DataTree, "DataToDelete");
	
EndProcedure

// Returns data processor version
&AtServer
Function ObjectVersionAsStringAtServer()
	
	Return FormAttributeToValue("Object").ObjectVersionAsString();
	
EndFunction

&AtClient
Procedure ExecuteImportExchangeRules(RuleFileAddressInStorage = "", FileNameForExtension = "")
	
	Object.ErrorFlag = False;
	
	ImportExchangeRulesAndParametersAtServer(RuleFileAddressInStorage, FileNameForExtension);
	
	If Object.ErrorFlag Then
		
		SetImportRuleFlag(False);
		
	Else
		
		SetImportRuleFlag(True);
		ExpandTreeRows(Object.ExportRuleTable, Items.ExportRuleTable, "Enable");
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExpandTreeRows(DataTree, PresentationOnForm, CheckBoxName)
	
	TreeRows = DataTree.GetItems();
	
	For Each Row In TreeRows Do
		
		RowID=Row.GetID();
		PresentationOnForm.Expand(RowID, False);
		EnableParentIfSubordinateItemsEnabled(Row, CheckBoxName);
		
	EndDo;
	
EndProcedure

&AtClient
Procedure EnableParentIfSubordinateItemsEnabled(TreeRow, CheckBoxName)
	
	Enable = TreeRow[CheckBoxName];
	
	For Each SubordinateRow In TreeRow.GetItems() Do
		
		If SubordinateRow[CheckBoxName] = 1 Then
			
			Enable = 1;
			
		EndIf;
		
		If SubordinateRow.GetItems().Count() > 0 Then
			
			EnableParentIfSubordinateItemsEnabled(SubordinateRow, CheckBoxName);
			
		EndIf;
		
	EndDo;
	
	TreeRow[CheckBoxName] = Enable;
	
EndProcedure

&AtClient
Procedure OnPeriodChange()
	
	Object.StartDate = ExportPeriod.StartDate;
	Object.EndDate = ExportPeriod.EndDate;
	
EndProcedure

&AtServer
Procedure ImportExchangeRulesAndParametersAtServer(RuleFileAddressInStorage, FileNameForExtension)
	
	ExchangeRuleFileName = FileNameAtServerOrClient(RulesFileName ,RuleFileAddressInStorage, FileNameForExtension);
	
	If ExchangeRuleFileName = Undefined Then
		
		Return;
		
	Else
		
		Object.ExchangeRuleFileName = ExchangeRuleFileName;
		
	EndIf;
	
	ObjectForServer = FormAttributeToValue("Object");
	ObjectForServer.ExportRuleTable = FormAttributeToValue("Object.ExportRuleTable");
	ObjectForServer.ParameterSetupTable = FormAttributeToValue("Object.ParameterSetupTable");
	
	ObjectForServer.ImportExchangeRules();
	ObjectForServer.InitializeInitialParameterValues();
	ObjectForServer.Parameters.Clear();
	Object.ErrorFlag = ObjectForServer.ErrorFlag;
	
	If IsClient Then
		
		DeleteFiles(Object.ExchangeRuleFileName);
		
	EndIf;
	
	ValueToFormAttribute(ObjectForServer.ExportRuleTable, "Object.ExportRuleTable");
	ValueToFormAttribute(ObjectForServer.ParameterSetupTable, "Object.ParameterSetupTable");
	
EndProcedure

// Opens file selection dialog.
//
&AtClient
Procedure SelectFile(Item, StorageObject, PropertyName, CheckForExistence, Val DefaultExtension = "xml",
	ArchiveDataFile = True, RuleFileSelection = False)
	
	FileSelectionDialog = New FileDialog(FileDialogMode.Open);

	If DefaultExtension = "txt" Then
		
		FileSelectionDialog.Filter = "File protocol exchange (*.txt)|*.txt";
		FileSelectionDialog.DefaultExt = "txt";
		
	ElsIf Object.ExchangeMode = "DataExported" Then
		
		If ArchiveDataFile Then
			
			FileSelectionDialog.Filter = "Archived file data (*.zip)|*.zip";
			FileSelectionDialog.DefaultExt = "zip";
			
		ElsIf RuleFileSelection Then
			
			FileSelectionDialog.Filter = "File data (*.xml)|*.xml|Archived file data (*.zip)|*.zip";
			FileSelectionDialog.DefaultExt = "xml";
			
		Else
			
			FileSelectionDialog.Filter = "File data (*.xml)|*.xml";
			FileSelectionDialog.DefaultExt = "xml";
			
		EndIf; 
		
	Else
		If RuleFileSelection Then
			FileSelectionDialog.Filter = "File data (*.xml)|*.xml";
			FileSelectionDialog.DefaultExt = "xml";
		Else
			FileSelectionDialog.Filter = "File data (*.xml)|*.xml|Archived file data (*.zip)|*.zip";
			FileSelectionDialog.DefaultExt = "xml";
		EndIf;
	EndIf;
	
	FileSelectionDialog.Title = NStr("ru = 'Выберите файл'; en = 'Select file'; pl = 'Wybierz plik';es_ES = 'Seleccionar un archivo';es_CO = 'Seleccionar un archivo';tr = 'Dosya seç';it = 'Selezionare il file';de = 'Datei auswählen'");
	FileSelectionDialog.Preview = False;
	FileSelectionDialog.FilterIndex = 0;
	FileSelectionDialog.FullFileName = Item.EditText;
	FileSelectionDialog.CheckFileExist = CheckForExistence;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("StorageObject", StorageObject);
	AdditionalParameters.Insert("PropertyName",    PropertyName);
	AdditionalParameters.Insert("Item",        Item);
	
	Notification = New NotifyDescription("FileSelectionDialogChoiceProcessing", ThisObject, AdditionalParameters);
	FileSelectionDialog.Show(Notification);
	
EndProcedure

&AtClient
Procedure FileSelectionDialogChoiceProcessing(SelectedFiles, AdditionalParameters) Export
	
	If SelectedFiles = Undefined Then
		Return;
	EndIf;
	
	AdditionalParameters.StorageObject[AdditionalParameters.PropertyName] = SelectedFiles[0];
	
	Item = AdditionalParameters.Item;
	
	If Item = Items.RulesFileName Then
		RuleFileNameOnChange(Item);
	ElsIf Item = Items.ExchangeFileName Then
		ExchangeFileNameOnChange(Item);
	ElsIf Item = Items.DataFileName Then
		DataFileNameOnChange(Item);
	ElsIf Item = Items.NameOfImportRulesFile Then
		NameOfImportRulesFileOnChange(Item);
	EndIf;
	
EndProcedure

&AtServer
Function EstablishConnectionWithDestinationIBAtServer()
	
	ObjectForServer = FormAttributeToValue("Object");
	FillPropertyValues(ObjectForServer, Object);
	ConnectionResult = ObjectForServer.EstablishConnectionWithDestinationIB();
	
	If ConnectionResult <> Undefined Then
		
		MessageToUser(NStr("ru = 'Подключение успешно установлено.'; en = 'Connection established.'; pl = 'Połączenie zostało pomyślnie ustanowione.';es_ES = 'Conexión se ha establecido con éxito.';es_CO = 'Conexión se ha establecido con éxito.';tr = 'Bağlantı başarıyla yapıldı.';it = 'Connessione stabilita.';de = 'Die Verbindung wurde erfolgreich hergestellt.'"));
		
	EndIf;
	
EndFunction

// Sets mark value in subordinate tree rows according to the mark value in the current row.
// 
//
// Parameters:
//  CurRow      - a value tree row.
// 
&AtClient
Procedure SetSubordinateMarks(curRow, CheckBoxName)
	
	SubordinateElements = curRow.GetItems();
	
	If SubordinateElements.Count() = 0 Then
		Return;
	EndIf;
	
	For Each Row In SubordinateElements Do
		
		Row[CheckBoxName] = curRow[CheckBoxName];
		
		SetSubordinateMarks(Row, CheckBoxName);
		
	EndDo;
		
EndProcedure

// Sets mark values in parent tree rows according to the mark value in the current row.
// 
//
// Parameters:
//  CurRow      - a value tree row.
// 
&AtClient
Procedure SetParentMarks(curRow, CheckBoxName)
	
	Parent = curRow.GetParent();
	If Parent = Undefined Then
		Return;
	EndIf; 
	
	CurState = Parent[CheckBoxName];
	
	EnabledItemsFound  = False;
	DisabledItemsFound = False;
	
	For Each Row In Parent.GetItems() Do
		If Row[CheckBoxName] = 0 Then
			DisabledItemsFound = True;
		ElsIf Row[CheckBoxName] = 1
			OR Row[CheckBoxName] = 2 Then
			EnabledItemsFound  = True;
		EndIf; 
		If EnabledItemsFound AND DisabledItemsFound Then
			Break;
		EndIf; 
	EndDo;
	
	If EnabledItemsFound AND DisabledItemsFound Then
		Enable = 2;
	ElsIf EnabledItemsFound AND (Not DisabledItemsFound) Then
		Enable = 1;
	ElsIf (Not EnabledItemsFound) AND DisabledItemsFound Then
		Enable = 0;
	ElsIf (Not EnabledItemsFound) AND (Not DisabledItemsFound) Then
		Enable = 2;
	EndIf;
	
	If Enable = CurState Then
		Return;
	Else
		Parent[CheckBoxName] = Enable;
		SetParentMarks(Parent, CheckBoxName);
	EndIf; 
	
EndProcedure

&AtServer
Procedure OpenImportFileAtServer(FileAddress)
	
	If IsClient Then
		
		BinaryData = GetFromTempStorage (FileAddress);
		AddressOnServer = GetTempFileName(".xml");
		// Temporary file is deleted not via DeleteFiles(AddressOnServer), but via
		// DeleteFiles(Object.ExchangeFileName) below.
		BinaryData.Write(AddressOnServer);
		Object.ExchangeFileName = AddressOnServer;
		
	Else
		
		FileOnServer = New File(ExchangeFileName);
		
		If Not FileOnServer.Exist() Then
			
			MessageToUser(NStr("ru = 'Не найден файл обмена на сервере.'; en = 'Exchange file not found on the server.'; pl = 'Plik wymiany nie został znaleziony na serwerze.';es_ES = 'Archivo de intercambio no encontrado en el servidor.';es_CO = 'Archivo de intercambio no encontrado en el servidor.';tr = 'Alışveriş dosyası sunucuda bulunamadı.';it = 'File di scambio non trovato sul server';de = 'Austausch-Datei wurde nicht auf dem Server gefunden.'"), "ExchangeFileName");
			Return;
			
		EndIf;
		
		Object.ExchangeFileName = ExchangeFileName;
		
	EndIf;
	
	ObjectForServer = FormAttributeToValue("Object");
	
	ObjectForServer.OpenImportFile(True);
	
	Object.StartDate = ObjectForServer.StartDate;
	Object.EndDate = ObjectForServer.EndDate;
	Object.DataExportDate = ObjectForServer.DataExportDate;
	Object.ExchangeRulesVersion = ObjectForServer.ExchangeRulesVersion;
	Object.Comment = ObjectForServer.Comment;
	
EndProcedure

// Deletes marked metadata tree rows.
//
&AtServer
Procedure DeleteAtServer()
	
	ObjectForServer = FormAttributeToValue("Object");
	DataBeingDeletedTree = FormAttributeToValue("DataToDelete");
	
	ObjectForServer.InitManagersAndMessages();
	
	For Each TreeRow In DataBeingDeletedTree.Rows Do
		
		For Each MDRow In TreeRow.Rows Do
			
			If Not MDRow.Check Then
				Continue;
			EndIf;
			
			TypeString = MDRow.Metadata;
			ObjectForServer.DeleteObjectsOfType(TypeString);
			
		EndDo;
		
	EndDo;
	
EndProcedure

// Sets an exchange node at tree rows.
//
&AtServer
Procedure FillExchangeNodeInTreeRowsAtServer(ExchangeNode)
	
	FillExchangeNodeInTreeRows(Object.ExportRuleTable.GetItems(), ExchangeNode);
	
EndProcedure

// Saves parameter values.
//
&AtServer
Procedure SaveParametersAtServer()
	
	ParametersTable = FormAttributeToValue("Object.ParameterSetupTable");
	
	ParametersToSave = New Structure;
	
	For Each TableRow In ParametersTable Do
		ParametersToSave.Insert(TableRow.Description, TableRow.Value);
	EndDo;
	
	SystemSettingsStorage.Save("UniversalDataExchangeXML", "Parameters", ParametersToSave);
	
EndProcedure

// Restores parameter values
//
&AtServer
Procedure RestoreParametersAtServer()
	
	ParametersTable = FormAttributeToValue("Object.ParameterSetupTable");
	RestoredParameters = SystemSettingsStorage.Load("UniversalDataExchangeXML", "Parameters");
	
	If TypeOf(RestoredParameters) <> Type("Structure") Then
		Return;
	EndIf;
	
	If RestoredParameters.Count() = 0 Then
		Return;
	EndIf;
	
	For Each Param In RestoredParameters Do
		
		ParameterName = Param.Key;
		
		TableRow = ParametersTable.Find(Param.Key, "Description");
		
		If TableRow <> Undefined Then
			
			TableRow.Value = Param.Value;
			
		EndIf;
		
	EndDo;
	
	ValueToFormAttribute(ParametersTable, "Object.ParameterSetupTable");
	
EndProcedure

// Performs interactive data export.
//
&AtClient
Procedure ExecuteImportFromForm()
	
	FileAddress = "";
	FileNameForExtension = "";
	
	AddRowToChoiceList(Items.ExchangeFileName.ChoiceList, ExchangeFileName, DataImportFromFile);
	
	If IsClient Then
		
		NotifyDescription = New NotifyDescription("ExecuteImportFromFormCompletion", ThisObject);
		BeginPutFile(NotifyDescription, FileAddress,NStr("ru = 'Файл обмена'; en = 'Exchange file'; pl = 'Plik wymiany';es_ES = 'Archivo de intercambio';es_CO = 'Archivo de intercambio';tr = 'Alışveriş dosyası';it = 'File di scambio';de = 'Datei austauschen'"),, UUID);
		
	Else
		
		If EmptyAttributeValue(ExchangeFileName, "ExchangeFileName", Items.ExchangeFileName.Title) Then
			Return;
		EndIf;
		
		ExecuteImportFromFormCompletion(True, FileAddress, FileNameForExtension, Undefined);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteImportFromFormCompletion(Result, Address, SelectedFileName, AdditionalParameters) Export
	
	If Result Then
		
		ExecuteImportAtServer(Address, SelectedFileName);
		
		OpenExchangeProtocolDataIfNecessary();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ExecuteImportAtServer(FileAddress, FileNameForExtension)
	
	FileToImportName = FileNameAtServerOrClient(ExchangeFileName ,FileAddress, FileNameForExtension);
	
	If FileToImportName = Undefined Then
		
		Return;
		
	Else
		
		Object.ExchangeFileName = FileToImportName;
		
	EndIf;
	
	If Object.SafeImport Then
		If IsTempStorageURL(ImportRulesFileAddressInStorage) Then
			BinaryData = GetFromTempStorage(ImportRulesFileAddressInStorage);
			AddressOnServer = GetTempFileName("xml");
			// Temporary file is deleted not via DeleteFiles(AddressOnServer), but via
			// DeleteFiles(Object.ExchangeRuleFileName) below.
			BinaryData.Write(AddressOnServer);
			Object.ExchangeRuleFileName = AddressOnServer;
		Else
			MessageToUser(NStr("ru = 'Не указан файл правил для загрузки данных.'; en = 'File of data import rules is not specified.'; pl = 'Nie wskazano pliku reguł do pobierania danych.';es_ES = 'No se ha indicado un archivo de reglas para cargar los datos.';es_CO = 'No se ha indicado un archivo de reglas para cargar los datos.';tr = 'Verileri içe aktarma kuralları dosyası belirtilmedi.';it = 'Il file di dati regole di scambio non è stato specificato.';de = 'Es ist keine Regeldatei für das Herunterladen von Daten angegeben.'"));
			Return;
		EndIf;
	EndIf;
	
	ObjectForServer = FormAttributeToValue("Object");
	FillPropertyValues(ObjectForServer, Object);
	ObjectForServer.ExecuteImport();
	
	Try
		
		If Not IsBlankString(FileAddress) Then
			DeleteFiles(FileToImportName);
		EndIf;
		
	Except
		WriteLogEvent(NStr("ru = 'Универсальный обмен данными в формате XML'; en = 'Universal data exchange in XML format'; pl = 'Uniwersalna wymiana danymi w formacie XML';es_ES = 'Intercambio de datos universal en el formato XML';es_CO = 'Intercambio de datos universal en el formato XML';tr = 'XML formatında üniversal veri değişimi';it = 'Scambio di dati universale in formato XML';de = 'Universeller Datenaustausch im XML-Format'", ObjectForServer.DefaultLanguageCode()),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
	EndTry;
	
	ObjectForServer.Parameters.Clear();
	ValueToFormAttribute(ObjectForServer, "Object");
	
	RulesAreImported = False;
	Items.FormExecuteExport.Enabled = False;
	Items.ExportNoteLabel.Visible = True;
	Items.ExportDebugAvailableGroup.Enabled = False;
	
EndProcedure

&AtServer
Function FileNameAtServerOrClient(AttributeName ,Val FileAddress, Val FileNameForExtension = ".xml",
	CreateNew = False, CheckForExistence = True)
	
	FileName = Undefined;
	
	If IsClient Then
		
		If CreateNew Then
			
			Extension = ? (Object.ArchiveFile, ".zip", ".xml");
			
			FileName = GetTempFileName(Extension);
			
			File = New File(FileName);
			
		Else
			
			Extension = FileExtention(FileNameForExtension);
			BinaryData = GetFromTempStorage(FileAddress);
			AddressOnServer = GetTempFileName(Extension);
			// The temporary file is deleted not via the DeleteFiles(AddressOnServer), but via 
			// DeleteFiles(Object.ExchangeRulesFileName) and DeleteFiles(Object.ExchangeFileName) below.
			BinaryData.Write(AddressOnServer);
			FileName = AddressOnServer;
			
		EndIf;
		
	Else
		
		FileOnServer = New File(AttributeName);
		
		If Not FileOnServer.Exist() AND CheckForExistence Then
			
			MessageToUser(NStr("ru = 'Указанный файл не существует.'; en = 'The file does not exist.'; pl = 'Podany plik nie istnieje.';es_ES = 'El archivo especificado no existe.';es_CO = 'El archivo especificado no existe.';tr = 'Belirtilen dosya mevcut değil.';it = 'Il file non esiste.';de = 'Die angegebene Datei existiert nicht.'"));
			
		Else
			
			FileName = AttributeName;
			
		EndIf;
		
	EndIf;
	
	Return FileName;
	
EndFunction

&AtServer
Function FileExtention(Val FileName)
	
	PointPosition = LastSeparator(FileName);
	
	Extension = Right(FileName,StrLen(FileName) - PointPosition + 1);
	
	Return Extension;
	
EndFunction

&AtServer
Function LastSeparator(StringWithSeparator, Separator = ".")
	
	StringLength = StrLen(StringWithSeparator);
	
	While StringLength > 0 Do
		
		If Mid(StringWithSeparator, StringLength, 1) = Separator Then
			
			Return StringLength; 
			
		EndIf;
		
		StringLength = StringLength - 1;
		
	EndDo;

EndFunction

&AtClient
Procedure ExecuteExportFromForm()
	
	// Adding rule file name and data file name to the selection list.
	AddRowToChoiceList(Items.RulesFileName.ChoiceList, RulesFileName, ExchangeRules);
	
	If Not Object.DirectReadingInDestinationIB AND Not IsClient Then
		
		If RuleAndExchangeFileNamesMatch() Then
			Return;
		EndIf;
		
		AddRowToChoiceList(Items.DataFileName.ChoiceList, DataFileName, DataExportToFile);
		
	EndIf;
	
	DataFileAddressInStorage = ExecuteExportAtServer();
	
	If DataFileAddressInStorage = Undefined Then
		Return;
	EndIf;
	
	ExpandTreeRows(Object.ExportRuleTable, Items.ExportRuleTable, "Enable");
	
	If IsClient AND Not DirectExport AND Not Object.ErrorFlag Then
		
		FileToSaveName = ?(Object.ArchiveFile, NStr("ru = 'Файл выгрузки.zip'; en = 'Export file.zip'; pl = 'Eksportowany plik.zip';es_ES = 'Exportar el archivo.zip';es_CO = 'Exportar el archivo.zip';tr = 'Dışa aktarma dosyası.zip';it = 'Esportazione file.zip';de = 'Datei.zip exportieren'"),NStr("ru = 'Файл выгрузки.xml'; en = 'Export file.xml'; pl = 'Eksportowany plik.xml';es_ES = 'Exportar el archivo.xml';es_CO = 'Exportar el archivo.xml';tr = 'Dışa aktarma dosyası.xml';it = 'Esportazione file.xml';de = 'Datei.xml exportieren'"));
		
		GetFile(DataFileAddressInStorage, FileToSaveName)
		
	EndIf;
	
	OpenExchangeProtocolDataIfNecessary();
	
EndProcedure

&AtServer
Function ExecuteExportAtServer()
	
	Object.ExchangeRuleFileName = FileNameAtServerOrClient(RulesFileName, RuleFileAddressInStorage);
	
	If Not DirectExport Then
		
		TemporaryDataFileName = FileNameAtServerOrClient(DataFileName, "",,True, False);
		
		If TemporaryDataFileName = Undefined Then
			
			Return Undefined;
			MessageToUser(NStr("ru = 'Не определен файл данных'; en = 'Data file not specified'; pl = 'Plik danych nie jest określony';es_ES = 'Archivo de datos no está especificado';es_CO = 'Archivo de datos no está especificado';tr = 'Veri dosyası belirtilmedi';it = 'File dati non specificato';de = 'Datendatei ist nicht angegeben'"));
			
		Else
			
			Object.ExchangeFileName = TemporaryDataFileName;
			
		EndIf;
		
	EndIf;
	
	ExportRuleTable = FormAttributeToValue("Object.ExportRuleTable");
	ParameterSetupTable = FormAttributeToValue("Object.ParameterSetupTable");
	
	ObjectForServer = FormAttributeToValue("Object");
	FillPropertyValues(ObjectForServer, Object);
	
	If ObjectForServer.HandlersDebugModeFlag Then
		
		Cancel = False;
		
		File = New File(ObjectForServer.EventHandlerExternalDataProcessorFileName);
		
		If Not File.Exist() Then
			
			MessageToUser(NStr("ru = 'Файл внешней обработки отладчиков событий не существует на сервере'; en = 'Event debugger external data processor file does not exist on the server'; pl = 'Zewnętrzny plik opracowania debuggera wydarzeń nie istnieje na serwerze';es_ES = 'Archivo del procesador de datos externo de los depuradores de eventos no existe en el servidor';es_CO = 'Archivo del procesador de datos externo de los depuradores de eventos no existe en el servidor';tr = 'Sunucuda olay hata ayıklayıcılarının dış veri işlemci dosyası yok';it = 'Il file di elaborazione esterna dei debugger eventi non esiste sul server';de = 'Eine externe Datenprozessordatei von Ereignisdebuggern ist auf dem Server nicht vorhanden'"));
			Return Undefined;
			
		EndIf;
		
		ObjectForServer.ExportEventHandlers(Cancel);
		
		If Cancel Then
			
			MessageToUser(NStr("ru = 'Не удалось выгрузить обработчики событий'; en = 'Cannot export event handlers'; pl = 'Nie można wyeksportować programów do obsługi wydarzeń';es_ES = 'No se puede exportar los manipuladores de eventos';es_CO = 'No se puede exportar los manipuladores de eventos';tr = 'Etkinlik işleyicileri dışa aktarılamıyor';it = 'Impossibile esportare i gestori di eventi';de = 'Ereignis-Handler können nicht exportiert werden'"));
			Return "";
			
		EndIf;
		
	Else
		
		ObjectForServer.ImportExchangeRules();
		ObjectForServer.InitializeInitialParameterValues();
		
	EndIf;
	
	ChangeExportRuleTree(ObjectForServer.ExportRuleTable.Rows, ExportRuleTable.Rows);
	ChangeParameterTable(ObjectForServer.ParameterSetupTable, ParameterSetupTable);
	
	ObjectForServer.ExecuteExport();
	ObjectForServer.ExportRuleTable = FormAttributeToValue("Object.ExportRuleTable");
	
	If IsClient AND Not DirectExport Then
		
		DataFileAddress = PutToTempStorage(New BinaryData(Object.ExchangeFileName), UUID);
		DeleteFiles(Object.ExchangeFileName);
		
	Else
		
		DataFileAddress = "";
		
	EndIf;
	
	If IsClient Then
		
		DeleteFiles(ObjectForServer.ExchangeRuleFileName);
		
	EndIf;
	
	ObjectForServer.Parameters.Clear();
	ValueToFormAttribute(ObjectForServer, "Object");
	
	Return DataFileAddress;
	
EndFunction

&AtClient
Procedure SetDebugCommandsEnabled();
	
	Items.ImportDebugSetup.Enabled = Object.HandlersDebugModeFlag;
	Items.ExportDebugSetup.Enabled = Object.HandlersDebugModeFlag;
	
EndProcedure

// Modifies an exchange rule tree according to the tree specified in the form
//
&AtServer
Procedure ChangeExportRuleTree(InitialTreeRows, TreeToReplaceRows)
	
	EnableColumn = TreeToReplaceRows.UnloadColumn("Enable");
	InitialTreeRows.LoadColumn(EnableColumn, "Enable");
	NodeColumn = TreeToReplaceRows.UnloadColumn("ExchangeNodeRef");
	InitialTreeRows.LoadColumn(NodeColumn, "ExchangeNodeRef");
	
	For Each InitialTreeRow In InitialTreeRows Do
		
		RowIndex = InitialTreeRows.IndexOf(InitialTreeRow);
		TreeToReplaceRow = TreeToReplaceRows.Get(RowIndex);
		
		ChangeExportRuleTree(InitialTreeRow.Rows, TreeToReplaceRow.Rows);
		
	EndDo;
	
EndProcedure

// Changed parameter table according the table in the form.
//
&AtServer
Procedure ChangeParameterTable(BaseTable, FormTable)
	
	DescriptionColumn = FormTable.UnloadColumn("Description");
	BaseTable.LoadColumn(DescriptionColumn, "Description");
	ValueColumn = FormTable.UnloadColumn("Value");
	BaseTable.LoadColumn(ValueColumn, "Value");
	
EndProcedure

&AtClient
Procedure DirectExportOnValueChange()
	
	ExportParameters = Items.ExportParameters;
	
	ExportParameters.CurrentPage = ?(DirectExport = 0,
										  ExportParameters.ChildItems.ExportToFile,
										  ExportParameters.ChildItems.ExportToDestinationIB);
	
	Object.DirectReadingInDestinationIB = (DirectExport = 1);
	
	InfobaseTypeForConnectionOnValueChange();
	
EndProcedure

&AtClient
Procedure InfobaseTypeForConnectionOnValueChange()
	
	InfobaseType = Items.InfobaseType;
	InfobaseType.CurrentPage = ?(Object.InfobaseToConnectType,
								InfobaseType.ChildItems.FileInfobase,
								InfobaseType.ChildItems.ServerInfobase);
	
EndProcedure

&AtClient
Procedure AddRowToChoiceList(ValueListToSave, SavingValue, ParameterNameToSave)
	
	If IsBlankString(SavingValue) Then
		Return;
	EndIf;
	
	FoundItem = ValueListToSave.FindByValue(SavingValue);
	If FoundItem <> Undefined Then
		ValueListToSave.Delete(FoundItem);
	EndIf;
	
	ValueListToSave.Insert(0, SavingValue);
	
	While ValueListToSave.Count() > 10 Do
		ValueListToSave.Delete(ValueListToSave.Count() - 1);
	EndDo;
	
	ParameterNameToSave = ValueListToSave;
	
EndProcedure

&AtClient
Procedure OpenHandlerDebugSetupForm(EventHandlersFromRuleFile)
	
	DataProcessorName = Left(FormName, LastSeparator(FormName));
	FormNameToCall = DataProcessorName + "HandlerDebugSetupManagedForm";
	
	FormParameters = New Structure;
	FormParameters.Insert("EventHandlerExternalDataProcessorFileName", Object.EventHandlerExternalDataProcessorFileName);
	FormParameters.Insert("AlgorithmDebugMode", Object.AlgorithmDebugMode);
	FormParameters.Insert("ExchangeRuleFileName", Object.ExchangeRuleFileName);
	FormParameters.Insert("ExchangeFileName", Object.ExchangeFileName);
	FormParameters.Insert("ReadEventHandlersFromExchangeRulesFile", EventHandlersFromRuleFile);
	FormParameters.Insert("DataProcessorName", DataProcessorName);
	
	Mode = FormWindowOpeningMode.LockOwnerWindow;
	Handler = New NotifyDescription("OpenHandlerDebugSetupFormCompletion", ThisObject, EventHandlersFromRuleFile);
	DebugParameters = OpenForm(FormNameToCall, FormParameters, ThisObject,,,,Handler, Mode);
	
EndProcedure

&AtClient
Procedure OpenHandlerDebugSetupFormCompletion(DebugParameters, EventHandlersFromRuleFile) Export
	
	If DebugParameters <> Undefined Then
		
		FillPropertyValues(Object, DebugParameters);
		
		If IsClient Then
			
			If EventHandlersFromRuleFile Then
				
				FileName = Object.ExchangeRuleFileName;
				
			Else
				
				FileName = Object.ExchangeFileName;
				
			EndIf;
			
			Notification = New NotifyDescription("OpenHandlersDebugSettingsFormCompletionFileDeletion", ThisObject);
			BeginDeletingFiles(Notification, FileName);
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenHandlersDebugSettingsFormCompletionFileDeletion(AdditionalParameters) Export
	
	Return;
	
EndProcedure

&AtClient
Procedure ChangeFileLocation()
	
	Items.RulesFileName.Visible = Not IsClient;
	Items.DataFileName.Visible = Not IsClient;
	Items.ExchangeFileName.Visible = Not IsClient;
	Items.SafeImportGroup.Visible = Not IsClient;
	
	SetImportRuleFlag(False);
	
EndProcedure

&AtClient
Procedure ChangeProcessingMode(RunMode)
	
	ModeGroup = CommandBar.ChildItems.ProcessingMode.ChildItems;
	
	ModeGroup.FormAtClient.Check = RunMode;
	ModeGroup.FormAtServer.Check = Not RunMode;
	
	CommandBar.ChildItems.ProcessingMode.Title = 
	?(RunMode, NStr("ru = 'Режим работы (на клиенте)'; en = 'Mode (client)'; pl = 'Tryb pracy (na kliencie)';es_ES = 'Modo de operación (en el cliente)';es_CO = 'Modo de operación (en el cliente)';tr = 'Çalışma modu (istemcide)';it = 'Modalità (client)';de = 'Betriebsmodus (auf dem Client)'"), NStr("ru = 'Режим работы (на сервере)'; en = 'Mode (server)'; pl = 'Tryb pracy (na serwerze)';es_ES = 'Modo de operación (en el servidor)';es_CO = 'Modo de operación (en el servidor)';tr = 'Çalışma modu (sunucuda)';it = 'Modalità (server)';de = 'Betriebsmodus (auf dem Server)'"));
	
	Object.ExportRuleTable.GetItems().Clear();
	Object.ParameterSetupTable.Clear();
	
	ChangeFileLocation();
	
EndProcedure

&AtClient
Procedure OpenExchangeProtocolDataIfNecessary()
	
	If NOT Object.OpenExchangeProtocolsAfterExecutingOperations Then
		Return;
	EndIf;
	
	#If Not WebClient Then
		
		If Not IsBlankString(Object.ExchangeProtocolFileName) Then
			OpenInApplication(Object.ExchangeProtocolFileName);
		EndIf;
		
		If Object.DirectReadingInDestinationIB Then
			
			Object.ImportExchangeLogFileName = GetProtocolNameForSecondCOMConnectionInfobaseAtServer();
			
			If Not IsBlankString(Object.ImportExchangeLogFileName) Then
				OpenInApplication(Object.ImportLogName);
			EndIf;
			
		EndIf;
		
	#EndIf
	
EndProcedure

&AtServer
Function GetProtocolNameForSecondCOMConnectionInfobaseAtServer()
	
	Return FormAttributeToValue("Object").GetProtocolNameForCOMConnectionSecondInfobase();
	
EndFunction

&AtClient
Function EmptyAttributeValue(Attribute, DataPath, Header)
	
	If IsBlankString(Attribute) Then
		
		MessageText = NStr("ru = 'Поле ""%1"" не заполнено'; en = 'Field ""%1"" is blank'; pl = 'Pole ""%1"" nie jest wypełnione';es_ES = 'El ""%1"" campo no está rellenado';es_CO = 'El ""%1"" campo no está rellenado';tr = '""%1"" alanı doldurulmadı.';it = 'Il campo ""%1"" è vuoto';de = 'Das Feld ""%1"" ist nicht ausgefüllt'");
		MessageText = StrReplace(MessageText, "%1", Header);
		
		MessageToUser(MessageText, DataPath);
		
		Return True;
		
	Else
		
		Return False;
		
	EndIf;
	
EndFunction

&AtClient
Procedure SetImportRuleFlag(Flag)
	
	RulesAreImported = Flag;
	Items.FormExecuteExport.Enabled = Flag;
	Items.ExportNoteLabel.Visible = Not Flag;
	Items.ExportDebugGroup.Enabled = Flag;
	
EndProcedure

&AtClient
Procedure OnChangeChangesRegistrationDeletionType()
	
	If IsBlankString(ChangesRegistrationDeletionTypeForExportedExchangeNodes) Then
		Object.ChangesRegistrationDeletionTypeForExportedExchangeNodes = 0;
	Else
		Object.ChangesRegistrationDeletionTypeForExportedExchangeNodes = Number(ChangesRegistrationDeletionTypeForExportedExchangeNodes);
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Procedure MessageToUser(Text, DataPath = "")
	
	Message = New UserMessage;
	Message.Text = Text;
	Message.DataPath = DataPath;
	Message.Message();
	
EndProcedure

// Returns True if the client application is running on Windows.
//
// Returns:
//  Boolean. Returns False if the client OS is not Linux.
//
&AtClient
Function IsWindowsClient()
	
	SystemInfo = New SystemInfo;
	
	IsWindowsClient = SystemInfo.PlatformType = PlatformType.Windows_x86
	             OR SystemInfo.PlatformType = PlatformType.Windows_x86_64;
	
	Return IsWindowsClient;
	
EndFunction

&AtServer
Function CheckPlatformVersionAndCompatibilityMode()
	
	Information = New SystemInfo;
	If Not (Left(Information.AppVersion, 3) = "8.3"
		AND (Metadata.CompatibilityMode = Metadata.ObjectProperties.CompatibilityMode.DontUse
		Or (Metadata.CompatibilityMode <> Metadata.ObjectProperties.CompatibilityMode.Version8_1
		AND Metadata.CompatibilityMode <> Metadata.ObjectProperties.CompatibilityMode.Version8_2_13
		AND Metadata.CompatibilityMode <> Metadata.ObjectProperties.CompatibilityMode["Version8_2_16"]
		AND Metadata.CompatibilityMode <> Metadata.ObjectProperties.CompatibilityMode["Version8_3_1"]
		AND Metadata.CompatibilityMode <> Metadata.ObjectProperties.CompatibilityMode["Version8_3_2"]))) Then
		
		Raise NStr("ru = 'Обработка предназначена для запуска на версии платформы
			|1С:Предприятие 8.3 с отключенным режимом совместимости или выше'; 
			|en = 'The data processor is intended for use with 
			|1C:Enterprise 8.3 or later, with disabled compatibility mode'; 
			|pl = 'Przetwarzanie jest przeznaczona do uruchomienia na wersji platformy 
			|1C:Enterprise 8.3 z odłączonym trybem kompatybilności lub wyżej';
			|es_ES = 'El procesamiento se utiliza para iniciar en la versión de la plataforma
			| 1C:Enterprise 8.3 con el modo de compatibilidad desactivado o superior';
			|es_CO = 'El procesamiento se utiliza para iniciar en la versión de la plataforma
			| 1C:Enterprise 8.3 con el modo de compatibilidad desactivado o superior';
			|tr = 'İşlem, 
			|1C: İşletme 8.3 platform sürümü (veya üzeri) uyumluluk modu kapalı olarak başlamak için kullanılır';
			|it = 'L''elaborazione è predisposta per essere eseguita sulla versione della piattaforma
			|1C:Enterprise 8.3 con la modalità di compatibilità disabilitata o superiore';
			|de = 'Die Verarbeitung soll auf der Plattform Version
			|1C:Enterprise 8.3 mit deaktiviertem Kompatibilitätsmodus oder höher gestartet werden'");
		
	EndIf;
	
EndFunction

&AtClient
Procedure ChangeSafeImportMode(Interactively = True)
	
	Items.SafeImportGroup.Enabled = Object.SafeImport;
	
	ThroughStorage = IsClient;
	#If WebClient Then
		ThroughStorage = True;
	#EndIf
	
	If Object.SafeImport AND ThroughStorage Then
		PutImportRulesFileInStorage();
	EndIf;
	
EndProcedure

&AtClient
Procedure PutImportRulesFileInStorage()
	
	ThroughStorage = IsClient;
	#If WebClient Then
		ThroughStorage = True;
	#EndIf
	
	FileAddress = "";
	NotifyDescription = New NotifyDescription("PutImportRulesFileInStorageCompletion", ThisObject);
	BeginPutFile(NotifyDescription, FileAddress,
		?(ThroughStorage, NStr("ru = 'Файл обмена'; en = 'Exchange file'; pl = 'Plik wymiany';es_ES = 'Archivo de intercambio';es_CO = 'Archivo de intercambio';tr = 'Alışveriş dosyası';it = 'File di scambio';de = 'Datei austauschen'"), NameOfImportRulesFile), ThroughStorage, UUID);
	
EndProcedure

&AtClient
Procedure PutImportRulesFileInStorageCompletion(Result, Address, SelectedFileName, AdditionalParameters) Export
	
	If Result Then
		ImportRulesFileAddressInStorage = Address;
	EndIf;
	
EndProcedure

#EndRegion
