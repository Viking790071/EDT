
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If Not CommonClientServer.IsWindowsClient() Then
		Raise NStr("ru = 'Резервное копирование и восстановление данных необходимо настроить средствами операционной системы или другими сторонними средствами.'; en = 'Set up data backup and recovery by using the operating system tools or other third-party tools.'; pl = 'Tworzenie kopii zapasowych i odzyskiwanie danych muszą być konfigurowane za pomocą systemu operacyjnego lub innych narzędzi stron trzecich.';es_ES = 'Es necesario ajustar la creación de las copias de respaldo y la restauración de los datos con los recursos del sistema operativo o con otros recursos terceros.';es_CO = 'Es necesario ajustar la creación de las copias de respaldo y la restauración de los datos con los recursos del sistema operativo o con otros recursos terceros.';tr = 'Veri yedekleme ve geri yükleme, işletim sistemin araçları veya diğer üçüncü taraf araçları tarafından yapılandırılmalıdır.';it = 'Il backup e il recupero dei dati devono essere configurati tramite gli strumenti del sistema operativo o altri strumenti esterni.';de = 'Die Sicherung und Wiederherstellung von Daten muss mit dem Betriebssystem oder anderen Tools von Drittanbietern konfiguriert werden.'");
	EndIf;
	
	If Not CommonClientServer.IsWindowsClient() Then
		Return; // Cancel is set in OnOpen().
	EndIf;
	
	If CommonClientServer.IsWebClient() Then
		Raise NStr("ru = 'Резервное копирование недоступно в веб-клиенте.'; en = 'Backup is not available in web client.'; pl = 'Kopia zapasowa nie jest dostępna w kliencie www.';es_ES = 'Copia de respaldo no se encuentra disponible en el cliente web.';es_CO = 'Copia de respaldo no se encuentra disponible en el cliente web.';tr = 'Yedekleme web istemcisinde mevcut değildir.';it = 'Backup non è disponibile in client web.';de = 'Die Sicherung ist im Webclient nicht verfügbar.'");
	EndIf;
	
	If Not Common.FileInfobase() Then
		Raise NStr("ru = 'В клиент-серверном варианте работы резервное копирование следует выполнять сторонними средствами (средствами СУБД).'; en = 'Back up data using external tools (DBMS tools) in the client/server mode.'; pl = 'Utwórz kopię zapasową danych za pomocą narzędzi zewnętrznych (narzędzia SZBD) w trybie klient/serwer.';es_ES = 'Datos de la copia de respaldo utilizando herramientas externas (herramientas DBMS) en el modo de cliente/servidor.';es_CO = 'Datos de la copia de respaldo utilizando herramientas externas (herramientas DBMS) en el modo de cliente/servidor.';tr = 'İstemci / sunucu modunda harici araçları (DBMS araçları) kullanarak verileri yedekleyin.';it = 'Eseguire backup dati usando strumenti esterni (strumenti DBMS) in modalità client/server.';de = 'Sichern Sie Daten mit externen Tools (DBMS-Tools) im Client / Server-Modus.'");
	EndIf;
	
	BackupSettings = IBBackupServer.BackupSettings();
	IBAdministratorPassword = BackupSettings.IBAdministratorPassword;
	Object.BackupDirectory = BackupSettings.BackupsStorageDirectory;
	
	If InfobaseSessionCount() > 1 Then
		
		Items.RecoveryStatusPages.CurrentPage = Items.ActiveUsersPage;
		
	EndIf;
	
	UserInformation = IBBackupServer.UserInformation();
	PasswordRequired = UserInformation.PasswordRequired;
	If PasswordRequired Then
		IBAdministrator = UserInformation.Name;
	Else
		Items.AuthorizationGroup.Visible = False;
		IBAdministratorPassword = "";
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
#If WebClient Then
	Items.ComcntrGroupFileMode.Visible = False;
#EndIf
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	CurrentPage = Items.DataImportPages.CurrentPage;
	If CurrentPage <> Items.DataImportPages.ChildItems.InformationAndBackupCreationPage Then
		Return;
	EndIf;
		
	WarningText = NStr("ru = 'Прервать подготовку к восстановлению данных?'; en = 'Stop preparing for data recovery?'; pl = 'Czy chcesz zaprzestać przygotowanie do przywrócenia danych?';es_ES = '¿Quiere parar la preparación para recuperar los datos?';es_CO = '¿Quiere parar la preparación para recuperar los datos?';tr = 'Verileri geri yüklemek için hazırlanmaktan vazgeçmek istiyor musunuz?';it = 'Fermare la preparazione del ripristino dati?';de = 'Möchten Sie die Wiederherstellung von Daten einstellen?'");
	CommonClient.ShowArbitraryFormClosingConfirmation(ThisObject,
		Cancel, Exit, WarningText, "ForceCloseForm");
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;
	
	DetachIdleHandler("Timeout");
	DetachIdleHandler("CheckForSingleConnection");
	DetachIdleHandler("EndUserSessions");

EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	If EventName = "UserSessionsCompletion" AND Parameter.SessionCount <= 1
		AND Items.DataImportPages.CurrentPage = Items.InformationAndBackupCreationPage Then
			StartBackup();
	EndIf;
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure PathToArchiveDirectoryStartChoice(Item, ChoiceData, StandardProcessing)
	
	SelectBackupFile();
	
EndProcedure

&AtClient
Procedure UsersListClick(Item)
	
	StandardSubsystemsClient.OpenActiveUserList(, ThisObject);
	
EndProcedure

&AtClient
Procedure LableUpdateComponentVersionURLProcessing(Item, FormattedStringURL, StandardProcessing)
	StandardProcessing = False;
	CommonClient.RegisterCOMConnector();
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure FormCancel(Command)
	
	Close();
	
EndProcedure

&AtClient
Procedure Finish(Command)
	
	ClearMessages();
	
	If Not CheckAttributeFilling() Then
		Return;
	EndIf;
	
	Pages = Items.DataImportPages;
	
	AttachmentResult = IBBackupClient.CheckAccessToInfobase(IBAdministratorPassword);
	If AttachmentResult.AddInAttachmentError Then
		Items.RecoveryStatusPages.CurrentPage = Items.ConnectionErrorPage;
		ConnectionErrorFound = AttachmentResult.BriefErrorDescription;
		Return;
	Else
		SetBackupParemeters();
	EndIf;

	Pages.CurrentPage = Items.InformationAndBackupCreationPage; 
	Items.Close.Enabled = True;
	Items.Finish.Enabled = False;
	
	InfobaseSessionCount = InfobaseSessionCount();
	Items.ActiveUserCount.Title = InfobaseSessionCount;
	
	SetConnectionLock = True;
	IBConnectionsServerCall.SetConnectionLock(NStr("ru = 'Выполняется восстановление информационной базы.'; en = 'Infobase recovery is in progress.'; pl = 'Wykonuje się odzyskiwanie bazy informacyjnej:';es_ES = 'Recuperación de la infobase está en progreso.';es_CO = 'Recuperación de la infobase está en progreso.';tr = 'Veritabanı kurtarma işlemi devam ediyor.';it = 'Il ripristino della base informativa viene effettuato.';de = 'Die Wiederherstellung der Infobase läuft gerade.'"), "Backup");
	
	If InfobaseSessionCount = 1 Then
		IBConnectionsClient.SetUserTerminationInProgressFlag(SetConnectionLock);
		IBConnectionsClient.TerminateThisSession(False);
		StartBackup();
	Else
		IBConnectionsClient.SetSessionTerminationHandlers(SetConnectionLock);
		SetIdleIdleHandlerOfBackupStart();
		SetIdleHandlerOfBackupTimeout();
	EndIf;
	
EndProcedure

&AtClient
Procedure GoToEventLog(Command)
	OpenForm("DataProcessor.EventLog.Form.EventLog", , ThisObject);
EndProcedure

#EndRegion

#Region Private

// Attaches an idle time-out handler before forced start of data backup or restore.
// 
&AtClient
Procedure SetIdleHandlerOfBackupTimeout()
	
	AttachIdleHandler("Timeout", 300, True);
	
EndProcedure

// Attaches an idle deferred backup handler.
&AtClient
Procedure SetIdleIdleHandlerOfBackupStart() 
	
	AttachIdleHandler("CheckForSingleConnection", 60);
	
EndProcedure

// The function asks the user and returns a path to file or directory.
&AtClient
Procedure SelectBackupFile()
	
	OpenFileDialog = New FileDialog(FileDialogMode.Open);
	OpenFileDialog.Filter = NStr("ru = 'Резервная копия базы (*.zip, *.1CD)|*.zip;*.1cd'; en = 'Infobase backup (*.zip, *.1CD)|*.zip;*.1cd'; pl = 'Kopia zapasowa bazy danych (*.zip, *.1CD)|*.zip;*.1cd';es_ES = 'Copia de respaldo de la base (*.zip, *.1CD)|-*.zip;*.1cd';es_CO = 'Copia de respaldo de la base (*.zip, *.1CD)|-*.zip;*.1cd';tr = 'Infobase yedeklemesi (*.zip, *.1CD)|*.zip;*.1cd';it = 'Database di backup (*.zip, *.1CD)|*.zip;*.1cd';de = 'Datenbanksicherung (*.zip, *.1CD)|*.zip;*.1cd'");
	OpenFileDialog.Title= NStr("ru = 'Выберите файл резервной копии'; en = 'Select a backup file'; pl = 'Wybierz plik kopii zapasowej';es_ES = 'Seleccionar un archivo de la copia de respaldo';es_CO = 'Seleccionar un archivo de la copia de respaldo';tr = 'Bir yedekleme dosyası seçin';it = 'Selezionare i file di backup';de = 'Wählen Sie eine Sicherungsdatei'");
	OpenFileDialog.CheckFileExist = True;
	
	If OpenFileDialog.Choose() Then
		
		Object.BackupImportFile = OpenFileDialog.FullFileName;
		
	EndIf;
	
EndProcedure

&AtClient
Function CheckAttributeFilling()
	
#If WebClient Then
	MessageText = NStr("ru = 'Восстановление не доступно в веб-клиенте.'; en = 'Recovery is not available in web client.'; pl = 'Odzyskiwanie nie jest dostępne w kliencie Web.';es_ES = 'La restauración no está disponible en el cliente web.';es_CO = 'La restauración no está disponible en el cliente web.';tr = 'Web istemcide geri yükleme yapılamaz.';it = 'Ripristino non è disponibile nel web client.';de = 'Die Wiederherstellung ist im Webclient nicht verfügbar.'");
	CommonClientServer.MessageToUser(MessageText);
	Return False;
#EndIf
	
	AttributesFilled = True;
	
	If PasswordRequired AND IsBlankString(IBAdministratorPassword) Then
		MessageText = NStr("ru = 'Не задан пароль администратора.'; en = 'Administrator password is not specified.'; pl = 'Hasło administratora nie zostało określone.';es_ES = 'Contraseña del administrador no está especificada.';es_CO = 'Contraseña del administrador no está especificada.';tr = 'Yönetici şifresi belirtilmemiş.';it = 'La password dell''amministratore non è specificata';de = 'Administrator-Kennwort ist nicht angegeben.'");
		CommonClientServer.MessageToUser(MessageText,, "IBAdministratorPassword");
		AttributesFilled = False;
	EndIf;
	
	Object.BackupImportFile = TrimAll(Object.BackupImportFile);
	FileName = TrimAll(Object.BackupImportFile);
	
	If IsBlankString(FileName) Then
		MessageText = NStr("ru = 'Не выбран файл с резервной копией.'; en = 'Backup file is not selected.'; pl = 'Plik kopii zapasowej nie jest wybrany.';es_ES = 'Archivo de la copia de respaldo no está seleccionado.';es_CO = 'Archivo de la copia de respaldo no está seleccionado.';tr = 'Yedekleme dosyası seçilmedi.';it = 'Il file di backup non è selezionato.';de = 'Sicherungsdatei ist nicht ausgewählt.'");
		CommonClientServer.MessageToUser(MessageText,, "Object.BackupImportFile");
		Return False;
	EndIf;
	
	ArchiveFile = New File(FileName);
	If Upper(ArchiveFile.Extension) <> ".ZIP" Or Upper(ArchiveFile.Extension) <> ".1CD"  Then
		
		MessageText = NStr("ru = 'Выбранный файл не является архивом с резервной копией.'; en = 'The selected file is not an archive with backup.'; pl = 'Wybrany plik nie jest archiwum z kopią zapasową.';es_ES = 'El archivo seleccionado no es un archivo con copia de respaldo.';es_CO = 'El archivo seleccionado no es un archivo con copia de respaldo.';tr = 'Seçilen dosya yedek kopyası olan bir arşiv değildir.';it = 'Il file selezionato non è un archivio di backup.';de = 'Die ausgewählte Datei ist kein Archiv mit Sicherung.'");
		CommonClientServer.MessageToUser(MessageText,, "Object.BackupImportFile");
		Return AttributesFilled;
		
	EndIf;
	
	If Upper(ArchiveFile.Extension) = ".1CD" Then
		
		If Upper(ArchiveFile.BaseName) <> "1CV8" Then
		
			MessageText = NStr("ru = 'Выбранный файл не является резервной копией (неправильное имя файла информационной базы).'; en = 'The selected file is not a backup (incorrect name of the infobase file).'; pl = 'Wybrany plik nie jest kopią zapasową (niepoprawna nazwa pliku bazy informacyjnej).';es_ES = 'El archivo seleccionado no es una copia de respaldo (nombre inválido del archivo de la infobase).';es_CO = 'El archivo seleccionado no es una copia de respaldo (nombre inválido del archivo de la infobase).';tr = 'Seçilen dosya yedekleme değil (Infobase dosyasının adı yanlış).';it = 'Il file selezionato non è un file di backup (nome non corretto del file infobase).';de = 'Die ausgewählte Datei ist keine Sicherungskopie (falscher Name der Informationsbasisdatei).'");
			CommonClientServer.MessageToUser(MessageText,, "Object.BackupImportFile");
			Return False;
		EndIf;
		
		Return AttributesFilled;
	EndIf;
	
	ZIPFile = New ZipFileReader(FileName);
	If ZIPFile.Items.Count() <> 1 Then
		
		MessageText = NStr("ru = 'Выбранный файл не является архивом с резервной копией (содержит более одного файла).'; en = 'The selected file is not an archive with backup (contains more than one file).'; pl = 'Wybrany plik nie jest archiwum z kopią zapasową (zawiera więcej niż jeden plik).';es_ES = 'El archivo seleccionado no es un archivo con copia de respaldo (contiene más de un archivo).';es_CO = 'El archivo seleccionado no es un archivo con copia de respaldo (contiene más de un archivo).';tr = 'Seçilen dosya yedek kopyası olan bir arşiv değildir (birden fazla dosya içerir).';it = 'Il file selezionato non è un archivio di backup (contiene più di un file).';de = 'Die ausgewählte Datei ist kein Archiv mit Sicherung (enthält mehr als eine Datei).'");
		CommonClientServer.MessageToUser(MessageText,, "Object.BackupImportFile");
		Return False;
		
	EndIf;
	
	FileInArchive = ZIPFile.Items[0];
	
	If Upper(FileInArchive.Extension) <> "1CD" Then
		
		MessageText = NStr("ru = 'Выбранный файл не является архивом с резервной копией (не содержит файл информационной базы).'; en = 'The selected file is not an archive with backup (infobase file is missing).'; pl = 'Wybrany plik nie jest archiwum z kopią zapasową (nie zawiera pliku bazy informacyjnej).';es_ES = 'El archivo seleccionado no es un archivo con copia de respaldo (no contiene un archivo de la infobase).';es_CO = 'El archivo seleccionado no es un archivo con copia de respaldo (no contiene un archivo de la infobase).';tr = 'Seçilen dosya yedek kopyası olan bir arşiv değildir (veritabanı dosyasını içermez).';it = 'Il file selezionato non è un archivio di backup (manca file infobase).';de = 'Die ausgewählte Datei ist kein Archiv mit Sicherung (enthält keine Infobase-Datei).'");
		CommonClientServer.MessageToUser(MessageText,, "Object.BackupImportFile");
		Return False;
		
	EndIf;
	
	If Upper(FileInArchive.BaseName) <> "1CV8" Then
		
		MessageText = NStr("ru = 'Выбранный файл не является архивом с резервной копией (неправильное имя файла информационной базы).'; en = 'The selected file is not an archive with backup (invalid name of the infobase file).'; pl = 'Wybrany plik nie jest archiwum z kopią zapasową (nieprawidłowa nazwa pliku bazy informacyjnej).';es_ES = 'El archivo seleccionado no es un archivo con copia de respaldo (nombre inválido del archivo de la infobase).';es_CO = 'El archivo seleccionado no es un archivo con copia de respaldo (nombre inválido del archivo de la infobase).';tr = 'Seçilen dosya yedek kopyası olan bir arşiv değildir (veritabanı dosyasının geçersiz adı).';it = 'Il file selezionato non è un archivio con backup (nome file infobase non valido).';de = 'Die ausgewählte Datei ist kein Archiv mit Sicherung (ungültiger Name der Infobase-Datei).'");
		CommonClientServer.MessageToUser(MessageText,, "Object.BackupImportFile");
		Return False;
		
	EndIf;
	
	Return AttributesFilled;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Idle handler procedures.

&AtClient
Procedure Timeout()
	
	DetachIdleHandler("CheckForSingleConnection");
	CancelPreparation();
	
EndProcedure

&AtServer
Procedure CancelPreparation()
	
	Items.FailedLabel.Title = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = '%1.
		|Подготовка к восстановлению данных из резервной копии отменена. Информационная база разблокирована.'; 
		|en = '%1.
		|Preparing for data recovery from backup is canceled. Infobase is unlocked.'; 
		|pl = '%1
		|Przygotowanie do przywrócenia danych z kopii zapasowej zostanie anulowane. Baza informacyjna jest zablokowana.';
		|es_ES = '%1.
		|Preparación para recuperar los datos de la copia de respaldo se ha cancelado. Infobase está bloqueada.';
		|es_CO = '%1.
		|Preparación para recuperar los datos de la copia de respaldo se ha cancelado. Infobase está bloqueada.';
		|tr = '%1. 
		| Yedekten veri yenilenmesi için hazırlık iptal edildi. Veritabanı kilitlendi.';
		|it = '%1.
		|La preparazione per il ripristino dati da backup è stata annullata. L''infobase è sbloccato.';
		|de = '%1.
		|Vorbereitung für die Datenwiederherstellung von der Sicherung wird abgebrochen. Infobase ist gesperrt.'"),
		IBConnections.ActiveSessionsMessage());
	Items.DataImportPages.CurrentPage = Items.BackupCreationErrorsPage;
	Items.Finish.Visible = False;
	Items.Close.Title = NStr("ru = 'Закрыть'; en = 'Close'; pl = 'Zamknij';es_ES = 'Cerrar';es_CO = 'Cerrar';tr = 'Kapat';it = 'Chiudi';de = 'Schließen'");
	Items.Close.DefaultButton = True;
	
	IBConnections.AllowUserAuthorization();
	
EndProcedure

&AtClient
Procedure CheckForSingleConnection()
	
	If InfobaseSessionCount() = 1 Then
		StartBackup();
	EndIf;
	
EndProcedure

&AtClient
Procedure StartBackup() 
	
	MainScriptFileName = GenerateUpdateScriptFiles();
	EventLogClient.AddMessageForEventLog(IBBackupClient.EventLogEvent(), 
		"Information",
		NStr("ru = 'Выполняется восстановление данных информационной базы:'; en = 'Infobase data recovery is in progress:'; pl = 'Odtwarzane są informacje z bazy danych:';es_ES = 'Recuperación de los datos de la infobase está en progreso:';es_CO = 'Recuperación de los datos de la infobase está en progreso:';tr = 'Veritabanı kurtarma işlemi devam ediyor:';it = 'Ripristino dati infobase in corso:';de = 'Die Daten der Informationsbasis werden wiederhergestellt:'") + " " + MainScriptFileName);
	
	ForceCloseForm = True;
	Close();
	
	ApplicationParameters.Insert("StandardSubsystems.SkipExitConfirmation", True);
	
	PathToLauncher = StandardSubsystemsClient.SystemApplicationFolder() + "mshta.exe";
	
	CommandLine = """%1"" ""%2"" [p1]%3[/p1]";
	CommandLine = StringFunctionsClientServer.SubstituteParametersToString(CommandLine,
		PathToLauncher, MainScriptFileName, IBBackupClient.StringUnicode(IBAdministratorPassword));
		
	CommonClientServer.StartApplication(CommandLine);
	
	Exit(False);
	
EndProcedure

//////////////////////////////////////////////////////////////////////////////////////////////////////////
// Data restore preparation procedures and functions.

&AtClient
Function GenerateUpdateScriptFiles() 
	
	CopyingParameters = IBBackupClient.ClientBackupParameters();
	ClientRunParameters = StandardSubsystemsClient.ClientRunParameters();
	CreateDirectory(CopyingParameters.TempFilesDirForUpdate);
	
	// Parameters structure is necessary to determine them on the client and transfer to the server.
	ParametersStructure = New Structure;
	ParametersStructure.Insert("ApplicationFileName"			, CopyingParameters.ApplicationFileName);
	ParametersStructure.Insert("EventLogEvent"	, CopyingParameters.EventLogEvent);
	ParametersStructure.Insert("COMConnectorName"			, ClientRunParameters.COMConnectorName);
	ParametersStructure.Insert("IsBaseConfigurationVersion"	, ClientRunParameters.IsBaseConfigurationVersion);
	ParametersStructure.Insert("FileInfobase"	, ClientRunParameters.FileInfobase);
	ParametersStructure.Insert("ScriptParameters"				, IBBackupClient.UpdateAdministratorAuthenticationParameters(IBAdministratorPassword));
	
	TemplatesNames = "AddlBackupFile";
	TemplatesNames = TemplatesNames + ",RecoverySplash";
	
	TemplatesTexts = GetTemplateTexts(TemplatesNames, ParametersStructure, ApplicationParameters["StandardSubsystems.MessagesForEventLog"]);
	
	ScriptFile = New TextDocument;
	ScriptFile.Output = UseOutput.Enable;
	ScriptFile.SetText(TemplatesTexts[0]);
	
	ScriptFileName = CopyingParameters.TempFilesDirForUpdate + "main.js";
	ScriptFile.Write(ScriptFileName, IBBackupClient.IBBackupApplicationFilesEncoding());
	
	// Auxiliary file: helpers.js.
	ScriptFile = New TextDocument;
	ScriptFile.Output = UseOutput.Enable;
	ScriptFile.SetText(TemplatesTexts[1]);
	ScriptFile.Write(CopyingParameters.TempFilesDirForUpdate + "helpers.js", IBBackupClient.IBBackupApplicationFilesEncoding());
	
	MainScriptFileName = Undefined;
	// Auxiliary file: splash.png.
	PictureLib.ExternalOperationSplash.Write(CopyingParameters.TempFilesDirForUpdate + "splash.png");
	// Auxiliary file: splash.ico.
	PictureLib.ExternalOperationSplashIcon.Write(CopyingParameters.TempFilesDirForUpdate + "splash.ico");
	// Auxiliary  file: progress.gif.
	PictureLib.TimeConsumingOperation48.Write(CopyingParameters.TempFilesDirForUpdate + "progress.gif");
	// Main splash screen file: splash.hta.
	MainScriptFileName = CopyingParameters.TempFilesDirForUpdate + "splash.hta";
	ScriptFile = New TextDocument;
	ScriptFile.Output = UseOutput.Enable;
	ScriptFile.SetText(TemplatesTexts[2]);
	ScriptFile.Write(MainScriptFileName, IBBackupClient.IBBackupApplicationFilesEncoding());
	
	LogFile = New TextDocument;
	LogFile.Output = UseOutput.Enable;
	LogFile.SetText(StandardSubsystemsClient.SupportInformation());
	LogFile.Write(CopyingParameters.TempFilesDirForUpdate + "templog.txt", TextEncoding.System);
	
	Return MainScriptFileName;
	
EndFunction

&AtServer
Function GetTemplateTexts(TemplatesNames, ParametersStructure, MessagesForEventLog)
	
	// Writing accumulated events to the event log.
	
	EventLogOperations.WriteEventsToEventLog(MessagesForEventLog);
	
	Result = New Array();
	Result.Add(GetScriptText(ParametersStructure));
	
	TemplateNamesArray = StrSplit(TemplatesNames, ",");
	For each TemplateName In TemplateNamesArray Do
		Result.Add(DataProcessors.IBBackup.GetTemplate(TemplateName).GetText());
	EndDo;
	Return Result;
	
EndFunction

&AtServer
Function GetScriptText(ParametersStructure)
	
	// Configuration update file: main.js.
	ScriptTemplate = DataProcessors.IBBackup.GetTemplate("LoadIBFileTemplate");
	
	Script = ScriptTemplate.GetArea("ParameterArea");
	Script.DeleteLine(1);
	Script.DeleteLine(Script.LineCount() - 1);
	
	Text = ScriptTemplate.GetArea("BackupArea");
	Text.DeleteLine(1);
	Text.DeleteLine(Text.LineCount() - 1);
	
	Return InsertScriptParameters(Script.GetText(), ParametersStructure) + Text.GetText();
	
EndFunction

&AtServer
Function InsertScriptParameters(Val Text, Val ParametersStructure)
	
	Result = Text;
	
	ScriptParameters = ParametersStructure.ScriptParameters;
	InfobaseConnectionString = ScriptParameters.InfobaseConnectionString + ScriptParameters.StringForConnection;
	
	If StrEndsWith(InfobaseConnectionString, ";") Then
		InfobaseConnectionString = Left(InfobaseConnectionString, StrLen(InfobaseConnectionString) - 1);
	EndIf;
	
	NameOfExecutableApplicationFile = BinDir() + ParametersStructure.ApplicationFileName;
	
	// Determining path to the infobase.
	FileModeFlag = Undefined;
	InfobasePath = IBConnectionsClientServer.InfobasePath(FileModeFlag, 0);
	
	InfobasePathParameter = ?(FileModeFlag, "/F", "/S") + InfobasePath; 
	InfobasePathString	= ?(FileModeFlag, InfobasePath, "");
	DirectoryString = CheckDirectoryForRootItemIndication(Object.BackupDirectory);
	
	Result = StrReplace(Result, "[NameOfExecutableApplicationFile]"     , PrepareText(NameOfExecutableApplicationFile));
	Result = StrReplace(Result, "[InfobasePathParameter]"   , PrepareText(InfobasePathParameter));
	Result = StrReplace(Result, "[InfobaseFilePathString]", PrepareText(CommonClientServer.AddLastPathSeparator(StrReplace(InfobasePathString, """", ""))));
	Result = StrReplace(Result, "[InfobaseConnectionString]", PrepareText(InfobaseConnectionString));
	Result = StrReplace(Result, "[NameOfUpdateAdministrator]"       , PrepareText(UserName()));
	Result = StrReplace(Result, "[EventLogEvent]"         , PrepareText(ParametersStructure.EventLogEvent));
	Result = StrReplace(Result, "[BackupFile]"                , PrepareText(Object.BackupImportFile));
	Result = StrReplace(Result, "[COMConnectorName]"                 , PrepareText(ParametersStructure.COMConnectorName));
	Result = StrReplace(Result, "[UseCOMConnector]"        , ?(ParametersStructure.IsBaseConfigurationVersion, "false", "true"));
	// TempFilesDir is used as automatic deletion of temporary directory is not allowed.
	Result = StrReplace(Result, "[TempFilesDir]"            , PrepareText(TempFilesDir()));
	
	Return Result;
	
EndFunction

&AtServer
Function CheckDirectoryForRootItemIndication(DirectoryString)
	
	If StrEndsWith(DirectoryString, ":\") Then
		Return Left(DirectoryString, StrLen(DirectoryString) - 1) ;
	Else
		Return DirectoryString;
	EndIf;
	
EndFunction

&AtServer
Function PrepareText(Val Text)
	
	Row = StrReplace(Text, "\", "\\");
	Row = StrReplace(Row, "'", "\'");
	
	Return StringFunctionsClientServer.SubstituteParametersToString("'%1'", Row);
	
EndFunction

&AtServer
Procedure SetBackupParemeters()
	
	BackupParameters = IBBackupServer.BackupSettings();
	
	BackupParameters.Insert("IBAdministrator", IBAdministrator);
	BackupParameters.Insert("IBAdministratorPassword", ?(PasswordRequired, IBAdministratorPassword, ""));
	
	IBBackupServer.SetBackupParemeters(BackupParameters);
	
EndProcedure

&AtServer
Function InfobaseSessionCount()
	
	Return IBConnections.InfobaseSessionCount(False, False);
	
EndFunction

#EndRegion
