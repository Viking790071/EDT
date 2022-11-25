#Region Variables

&AtClient
Var IdleHandlerParameters;

#EndRegion

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If Not Parameters.Property("OpeningFromList") Then
		// Open by navigation reference.
		If BankManager.ClassifierUpToDate() Then
			NotifyClassifierIsActual = True;
			Return;
		EndIf;
	EndIf;
	
	Settings = BankManager.Settings();
	
	UseImportFromWeb = Settings.UseImportFromWeb;	
	UseImportFromFile = Settings.UseImportFromFile;	
	
	If CommonClientServer.IsWebClient() Or (UseImportFromWeb AND Not UseImportFromFile) Then
		AutoSaveDataInSettings = AutoSaveFormDataInSettings.DontUse;
		Items.ImportingOption.Enabled = False;
		Items.PathToFile.Enabled = False;
		Items.FormPages.CurrentPage = Items.ImportingFromWebsite;
	ElsIf UseImportFromWeb AND UseImportFromFile Then
		Items.FormPages.CurrentPage = Items.PageSelectSource;
	ElsIf UseImportFromFile Then
		Items.FormPages.CurrentPage = Items.ImportingFromFile;
		ImportingOption = "FILE";
	Else
		Raise NStr("en = 'Import methods are not set in bank classifier import processor'; ru = 'В обработке загрузки классификатора банков не указаны способы загрузки.';pl = 'Metody importu nie są ustawione w procedurze importu klasyfikatora banku';es_ES = 'Métodos de importación no se han establecido en el procesador de importación del clasificador de bancos';es_CO = 'Métodos de importación no se han establecido en el procesador de importación del clasificador de bancos';tr = 'Banka sınıflandırıcı içe aktarma işlemcisinde içe aktarma yöntemleri ayarlanmamış';it = 'metodi di importazione non sono scolpiti nella banca processore classificatore import';de = 'Importmethoden werden nicht im Bank-Klassifikator-Importprozessor festgelegt'");
	EndIf;
	
	VerifyAccessRights("Update", Metadata.Catalogs.BankClassifier);
	ImportingOption = "WEB";
	
	SetChangesInInterface();
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	SetChangesInInterface();
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	If NotifyClassifierIsActual Then
		BankManagerClient.NotifyClassifierUpToDate();
		Cancel = True;
		Return;
	EndIf;
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure ImportingOptionOnChange(Item)
	SetChangesInInterface();
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure GoToNext(Command)
	
	If Items.FormPages.CurrentPage = Items.ResultPage Then
		Close();
	Else
		ClearMessages();
		
		If ImportingOption = "FILE" AND Not ValueIsFilled(PathToFile) Then
			CommonClientServer.MessageToUser(
				NStr("en = 'Specify the path to the classifier file'; ru = 'Укажите путь к файлу классификатора';pl = 'Określ ścieżkę do pliku klasyfikatora';es_ES = 'Especifique la ruta al archivo del clasificador';es_CO = 'Especifique la ruta al archivo del clasificador';tr = 'Sınıflandırıcı dosyası yolunu belirtin';it = 'Specificare percorso per il file classificatore';de = 'Den Pfad zur Klassifikator-Datei angeben'"),
				,
				"PathToFile");
			Return;
		EndIf;
		Items.FormPages.CurrentPage = Items.ImportingInProgress;
		SetChangesInInterface();
		AttachIdleHandler("ImportClassifier", 0.1, True);
	EndIf;

EndProcedure

&AtClient
Procedure Back(Command)
	CurrentPage = Items.FormPages.CurrentPage;
	
	If CurrentPage = Items.ResultPage Then
		#If WebClient Then
		Items.FormPages.CurrentPage = Items.ImportingFromWebsite;
		#Else
		Items.FormPages.CurrentPage = Items.PageSelectSource;
		#EndIf
	EndIf;
	
	SetChangesInInterface();

EndProcedure

&AtClient
Procedure Cancel(Command)
	If ValueIsFilled(JobID) Then
		CompleteBackgroundTasks(JobID);
	EndIf;
	Close();
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

#Region Client

&AtClient
Procedure ImportClassifier()
	// Imports bank classifier from file or from website.
	
	ClassifierImportParameters = New Map;
	// (Number) Quantity of new classifier records:
	ClassifierImportParameters.Insert("Exported", 0);
	// (Number) Quantity of updated classifier records:
	ClassifierImportParameters.Insert("Updated", 0);
	// (String) Message text about import results:
	ClassifierImportParameters.Insert("MessageText", "");
	// (Boolean) Flag of successfull classifier data import complete:
	ClassifierImportParameters.Insert("ImportCompleted", False);
	
	If ImportingOption = "FILE" Then
		ClassifierImportParameters.Insert("MethodName", "BankManager.ImportDataFile");
		Result = GetDataFile(ClassifierImportParameters);
	ElsIf ImportingOption = "WEB" Then
		ClassifierImportParameters.Insert("MethodName", "BankManager.GetWebsiteData");
		Result = DataExportFileOnServer(ClassifierImportParameters);
	EndIf;
	
	StorageAddress = Result.ResultAddress;
	If Not Result.Status = "Completed" Then
		JobID = Result.JobID;
		
		TimeConsumingOperationsClient.InitIdleHandlerParameters(IdleHandlerParameters);
		AttachIdleHandler("Attachable_CheckJobExecution", 1, True);
	Else
		ImportResult();
	EndIf;
 	
EndProcedure

&AtClient
Procedure ImportResult()
	// Displays the import attempt result of Russian Federation bank
	// classifier in the events log monitor and in import form.
	
	If ImportingOption = "FILE" Then
		Source = NStr("en = 'File'; ru = 'Файл';pl = 'Plik';es_ES = 'Archivo';es_CO = 'Archivo';tr = 'Dosya';it = 'File';de = 'Datei'");
	Else
		Source = NStr("en = 'Website'; ru = 'Вебсайт';pl = 'Strona internetowa';es_ES = 'Página web';es_CO = 'Página web';tr = 'Web sitesi';it = 'Sito internet';de = 'Webseite'");
	EndIf;
	
	ClassifierImportParameters = GetFromTempStorage(StorageAddress);
	
	EventName = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Bank classifier import. %1.'; ru = 'Загрузка банковского классификатора. %1.';pl = 'Import klasyfikatora banków. %1.';es_ES = 'Importación del clasificador de bancos. %1.';es_CO = 'Importación del clasificador de bancos. %1.';tr = 'Banka sınıflandırıcısını içe aktar. %1.';it = 'Importazione del Classificatore Banche. %1.';de = 'Bank-Klassifikator-Import. %1.'"), Source);
	
	If ClassifierImportParameters["ImportCompleted"] Then
		EventLogClient.AddMessageForEventLog(EventName,, 
			ClassifierImportParameters["MessageText"],, True);
		BankManagerClient.NotifyClassifierSuccessfullyUpdated();
	Else
		EventLogClient.AddMessageForEventLog(EventName, 
			"Error", ClassifierImportParameters["MessageText"],, True);
	EndIf;
	Items.ExplanationText.Title = ClassifierImportParameters["MessageText"];
	
	Items.FormPages.CurrentPage = Items.ResultPage;
	SetChangesInInterface();
	
	If (ClassifierImportParameters["Updated"] > 0) Or (ClassifierImportParameters["Exported"] > 0) Then
		NotifyChanged(Type("CatalogRef.BankClassifier"));
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_CheckJobExecution()
	JobCompleted = Undefined;
	Try
		JobCompleted = JobCompleted(JobID);
	Except
		EventLogClient.AddMessageForEventLog(NStr("en = 'Bank classifier import. %1.'; ru = 'Загрузка банковского классификатора. %1.';pl = 'Import klasyfikatora banków. %1.';es_ES = 'Importación del clasificador de bancos. %1.';es_CO = 'Importación del clasificador de bancos. %1.';tr = 'Banka sınıflandırıcısını içe aktar. %1.';it = 'Importazione del Classificatore Banche. %1.';de = 'Bank-Klassifikator-Import. %1.'", CommonClientServer.DefaultLanguageCode()),
			"Error", DetailErrorDescription(ErrorInfo()), , True);
			
		Items.ExplanationText.Title = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Bank classifier import is aborted by the reason of: %1
			     |Details see in events log monitor.'; 
			     |ru = 'Загрузка банковского классификатора прервана по причине: %1
			     |Подробности см. в журнале регистрации';
			     |pl = 'Pobranie klasyfikatora banków zostało przerwane z powodu:%1
			     |Patrz szczegóły w dzienniku wydarzeń.';
			     |es_ES = 'Importación del clasificador de bancos se ha cancelado a causa de: %1
			     |Ver detalles en la pantalla del registro de eventos.';
			     |es_CO = 'Importación del clasificador de bancos se ha cancelado a causa de: %1
			     |Ver detalles en la pantalla del registro de eventos.';
			     |tr = 'Banka sınıflandırıcı içe aktarma 
			     |şu nedenlerle iptal edildi: %1Ayrıntılar için olay günlüğü izleyicisine bakın.';
			     |it = 'L''importazione del Classificatore Banche è stata interrotta per la ragione: %1
			     |Vedere i dettagli nel registro eventi del monitor.';
			     |de = 'Der Import vom Bank-Klassifikator wird abgebrochen aus folgenden Gründen: %1
			     |Details siehe Ereignisprotokoll-Monitor.'"),
			BriefErrorDescription(ErrorInfo()));
			
		Items.FormPages.CurrentPage = Items.ResultPage;
		SetChangesInInterface();
		Return;
	EndTry;
		
	If JobCompleted Then 
		ImportResult();
	Else
		TimeConsumingOperationsClient.UpdateIdleHandlerParameters(IdleHandlerParameters);
		AttachIdleHandler(
			"Attachable_CheckJobExecution", 
			IdleHandlerParameters.CurrentInterval, 
			True);
	EndIf;

EndProcedure

&AtClient
Function GetDataFile(ClassifierImportParameters) 

	// (String) Path to File:
	ClassifierImportParameters.Insert("PathToFile", "");
	
	DataExportFile(ClassifierImportParameters);
	Result = DataExportFileOnServer(ClassifierImportParameters);
	
	ClassifierImportParameters.Insert("ImportCompleted", True);
	
	Return Result;
	
EndFunction

&AtClient
Procedure DataExportFile(FilesImportingParameters)
	// Receives classifier data from file.
	
	DataFile = Undefined;
	FileFound = False;
	
	Result = New Structure;
	If ValueIsFilled(PathToFile) Then
		// Path to the file is specified clearly.
		DataFile = New File(PathToFile);
		If DataFile.Exist() Then
			FilesImportingParameters.Insert("PathToFile", PathToFile);
			FileFound = True;
		Else
			SupportData = "";
		EndIf;
	EndIf;
	
	If FileFound Then
		ClassifierData = New BinaryData(DataFile.FullName);
		DataAddress = PutToTempStorage(ClassifierData, UUID);
		FilesImportingParameters.Insert("DataAddress", DataAddress);
		DataFile = Undefined;
	Else
		MessageText = NStr("en = 'Classifier data was not found.'; ru = 'Данные классификатора не обнаружены.';pl = 'Dane klasyfikatora nie zostały odnalezione.';es_ES = 'Datos del clasificador no se han encontrado.';es_CO = 'Datos del clasificador no se han encontrado.';tr = 'Sınıflandırıcı verisi bulunamadı.';it = 'Dati Classificatore non è stata trovata.';de = 'Klassifikatordaten wurden nicht gefunden.'");
		FilesImportingParameters.Insert("MessageText", MessageText);
	EndIf;
	
	FilesImportingParameters.Insert("MessageText", MessageText);
	
EndProcedure

#EndRegion

#Region CallingTheServer

&AtServerNoContext
Function JobCompleted(JobID)
	Return TimeConsumingOperations.JobCompleted(JobID);
EndFunction

&AtServer
Procedure SetChangesInInterface()
	// Depending on the current page it sets the accessibility of certain fields for the user.
	
	Items.PathToFile.Enabled = (ImportingOption = "FILE");
	
	If Items.FormPages.CurrentPage = Items.PageSelectSource
		Or Items.FormPages.CurrentPage = Items.ImportingFromFile 
		Or Items.FormPages.CurrentPage = Items.ImportingFromWebsite Then
		Items.FormButtonBack.Visible  = False;
		Items.FormNextButton.Title = NStr("en = 'Import'; ru = 'Загрузить';pl = 'Importuj';es_ES = 'Importar';es_CO = 'Importar';tr = 'İçe aktar';it = 'Importazione';de = 'Import'");
		Items.FormCancelButton.Enabled = True;
		Items.FormNextButton.Enabled  = True;
	ElsIf Items.FormPages.CurrentPage = Items.ImportingInProgress Then
		Items.FormButtonBack.Visible = False;
		Items.FormNextButton.Enabled  = False;
		Items.FormCancelButton.Enabled = True;
	Else
		Items.FormButtonBack.Visible = True;
		Items.FormNextButton.Title = NStr("en = 'Close'; ru = 'Закрыть';pl = 'Zamknij';es_ES = 'Cerrar';es_CO = 'Cerrar';tr = 'Kapat';it = 'Chiudi';de = 'Schließen'");
		Items.FormCancelButton.Enabled = False;
		Items.FormNextButton.Enabled  = True;
	EndIf;
	
EndProcedure

&AtServer
Procedure CompleteBackgroundTasks(JobID)
	BackgroundJob = BackgroundJobs.FindByUUID(JobID);
	If BackgroundJob <> Undefined Then
		BackgroundJob.Cancel();
	EndIf;
EndProcedure

&AtServer
Function DataExportFileOnServer(FilesImportingParameters)
	// Imports data from file to the bank classifier.
	//
// Parameters:
	//   FilesImportingParameters - see description of the same name variable in ImportClassifier().
	
	DataAddress = FilesImportingParameters.Get("DataAddress");
	
	If DataAddress <> Undefined Then 
		If Common.DataSeparationEnabled() Then
			Return NStr("en = 'Import bank classifier in data separation mode is prohibited'; ru = 'В режиме разделения данных запрещено загружать банковский классификатор.';pl = 'Importowanie klasyfikatora banku w trybie separacji danych jest zabronione';es_ES = 'Está prohibido clasificar bancos de importación en modo de separación de datos';es_CO = 'Está prohibido clasificar bancos de importación en modo de separación de datos';tr = 'Veri ayırma modunda banka sınıflandırıcısını içe aktarma yasaktır';it = 'Vietata l''importazione del classificatore bancario in modalità separazione dei dati';de = 'Der Import des Bankklassifikators im Datentrennungsmodus ist verboten'");
		EndIf;
		
		FilesImportingParameters["DataAddress"] = New ValueStorage(
		GetFromTempStorage(DataAddress), New Deflation(9));
		DeleteFromTempStorage(DataAddress);
	EndIf;
	
	JobDescription = NStr("en = 'Import bank classifier'; ru = 'Загрузить классификатор банков';pl = 'Import klasyfikatora banków';es_ES = 'Importar el clasificador bancario';es_CO = 'Importar el clasificador bancario';tr = 'Banka sınıflandırıcıyı içe aktar';it = 'Importazione del classificatore bancario';de = 'Bankklassifikator importieren'");
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	ExecutionParameters.BackgroundJobDescription = JobDescription;
	
	Result = TimeConsumingOperations.ExecuteInBackground(
		FilesImportingParameters["MethodName"], 
		FilesImportingParameters, 
		ExecutionParameters);
	
	Return Result;
	
EndFunction

#EndRegion

#Region Server

&AtClient
Procedure PathToFileStartChoice(Item, ChoiceData, StandardProcessing)
	ClearMessages();
	
	SelectDialog = New FileDialog(FileDialogMode.Open);
	SelectDialog.Title = NStr("en = 'Choose the path '; ru = 'Укажите путь';pl = 'Wybierz ścieżkę dostępu ';es_ES = 'Elegir la ruta';es_CO = 'Elegir la ruta';tr = 'Yol seçin';it = 'Scelta del percorso';de = 'Wählen Sie den Pfad'");
	SelectDialog.Directory   = PathToFile;
	
	If Not SelectDialog.Choose() Then
		Return;
	EndIf;
	
	PathToFile = SelectDialog.FullFileName;
EndProcedure

&AtClient
Procedure PathToFile1StartChoice(Item, ChoiceData, StandardProcessing)
	ClearMessages();
	
	SelectDialog = New FileDialog(FileDialogMode.Open);
	SelectDialog.Title = NStr("en = 'Specify path '; ru = 'Укажите путь';pl = 'Określ ścieżkę dostępu ';es_ES = 'Especificar la ruta';es_CO = 'Especificar la ruta';tr = 'Yol belirleyin';it = 'Specificare il percorso';de = 'Pfad angeben'");
	SelectDialog.Directory   = PathToFile;
	
	If Not SelectDialog.Choose() Then
		Return;
	EndIf;
	
	PathToFile = SelectDialog.FullFileName;
EndProcedure

#EndRegion

#EndRegion
