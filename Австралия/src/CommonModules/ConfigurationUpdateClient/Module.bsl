#Region Public

// Opens the update installation form with the specified parameters.
//
// Parameters:
//    UpdateInstallationParameters - Structure - Additional update installation parameters:
//     * Exit - Boolean - True if the application is closed after installing an update. 
//                                          The default value is False.
//     * ConfigurationUpdateRetrieved - Boolean - True if an update was retrieved from an online 
//                                          application. The default value is False (regular update installation mode).
//     * ExecuteUpdate     - Boolean - if True, skip update file selection and proceed to installing 
//                                          an update. The default value is False (offer a choice).
//
Procedure ShowUpdateSearchAndInstallation(UpdateIntallationParameters = Undefined) Export
	
	If UpdateStartPossible() Then
		OpenForm("DataProcessor.InstallUpdates.Form.Form", UpdateIntallationParameters);
	EndIf;
	
EndProcedure

// Displays a backup creation settings form.
//
// Parameters:
//    BackupParameters - Structure - backup form parameters.
//      * CreateBackup - Number - if 0, do not back up the infobase.
//                                          1 - create a temporary infobase backup.
//                                          2 - create an infobase backup.
//      * IBBackupDirectoryName - String - a backup directory.
//      * RestoreInfobase - Boolean - roll back in case of update errors.
//    NotifyDescription - NotifyDescription - a description of form closing notification.
//
Procedure ShowBackup(BackupParameters, NotifyDescription) Export
	
	OpenForm("DataProcessor.InstallUpdates.Form.BackupSettings", BackupParameters,,,,, NotifyDescription);
	
EndProcedure

#Region ForCallsFromOtherSubsystems

// OnlineUserSupport.GetApplicationUpdates

// Returns the backup settings title text for displaying in a form.
//
// Parameters:
//    Parameters - Structure - backup parameters.
//
// Returns:
//    String - backup creation hyperlink title.
//
Function BackupCreationTitle(Parameters) Export
	
	If Parameters.CreateBackup = 0 Then
		Result = NStr("ru = 'Не создавать резервную копию ИБ'; en = 'Do not back up the infobase'; pl = 'Nie twórz kopii zapasowej bazy informacyjnej';es_ES = 'No crear la copia de respaldo de la infobase';es_CO = 'No crear la copia de respaldo de la infobase';tr = 'Infobase''i yedekleme';it = 'Non eseguire il backup InfoBase';de = 'Die Infobase nicht sichern'");
	ElsIf Parameters.CreateBackup = 1 Then
		Result = NStr("ru = 'Создавать временную резервную копию ИБ'; en = 'Create a temporary infobase backup'; pl = 'Utwórz tymczasową kopię zapasową bazy informacyjnej';es_ES = 'Crear una copia de respaldo temporal de la infobase';es_CO = 'Crear una copia de respaldo temporal de la infobase';tr = 'Geçici Infobase yedeği oluştur';it = 'Crea un backup infobase temporaneo';de = 'Erstellen Sie eine temporäre Sicherung der Infobase'");
	ElsIf Parameters.CreateBackup = 2 Then
		Result = NStr("ru = 'Создавать резервную копию ИБ'; en = 'Create an infobase backup'; pl = 'Utwórz kopię zapasową bazy informacyjnej';es_ES = 'Crear una copia de respaldo de la infobase';es_CO = 'Crear una copia de respaldo de la infobase';tr = 'Infobase yedeği oluştur';it = 'Crea un backup infobase';de = 'Erstellen Sie eine Infobase-Sicherung'");
	EndIf;
	
	If Parameters.RestoreInfobase Then
		Result = Result + " " + NStr("ru = 'и выполнять откат при нештатной ситуации'; en = 'and roll back if any issues occur during the update'; pl = 'i wycofaj w przypadku błędu';es_ES = 'y retroceder en el caso de un error';es_CO = 'y retroceder en el caso de un error';tr = 've hata durumunda geri dön';it = 'e ripristinare nel caso un errore venga registrato durante l''aggiornamento';de = 'und im Falle eines Fehlers zurückrollen'");
	Else
		Result = Result + " " + NStr("ru = 'и не выполнять откат при нештатной ситуации'; en = 'and do not roll back if any issues occur during the update'; pl = 'i nie wycofuj w przypadku błędu';es_ES = 'y no retroceder en el caso de un error';es_CO = 'y no retroceder en el caso de un error';tr = 've hata durumunda geri dönme';it = 'e non ripristinare nel casi in cui un errore sia registrato durante l''aggiornamento.';de = 'und im Falle eines Fehlers nicht zurückrollen'");
	EndIf;
	
	Return Result;
	
EndFunction

// Checks whether update installation is possible. If possible, runs the update script or schedules 
// an update for a specified time.
//
// Parameters:
//    Form - ClientApplicationForm - the form where a user initiates an update (it must be closed at the end).
//    Parameters - Structure - Update installation parameters:
//        * UpdateMode - Number - an update installation option. Available values:
//                                    0 - now, 1 - on exit, 2 - scheduled update.
//        * UpdateDateTime - Date - a scheduled update date.
//        * EmailReport - Boolean - shows whether update reports are sent by email.
//        * EmailAddress - String - an email address for sending update reports.
//        * SchedulerTaskCode - Number - a code of a scheduled update task.
//        * UpdateFileName - String - the update file name.
//        * CreateBackup - Number - shows whether a backup is created.
//        * IBBackupDirectoryName - String - a backup directory.
//        * RestoreInfobase - Boolean - shows whether an infobase is restored from a backup in case of update errors.
//        * Exit - Boolean - shows that an update is installed when the application is closed.
//        * UpdateFiles - Array - contains values of Structure type.
//        * Patches - Structure - with the following keys:
//           ** Install - Array - paths to the patch files in a temporary storage.
//                                    
//           ** Delete    - Array - UUIDs of patches to be deleted (String).
//    AdministrationParameters - Structure - See StandardSubsystemsServer.AdministrationParameters. 
//
Procedure InstallUpdate(Form, Parameters, AdministrationParameters) Export
	
	If Not UpdateInstallationPossible(Parameters, AdministrationParameters) Then
		Return;
	EndIf;
	
	If Parameters.UpdateMode = 0 Then // Update now
		ApplicationParameters.Insert("StandardSubsystems.SkipExitConfirmation", True);
		Exit(False);
		RunUpdateScript(Parameters, AdministrationParameters);
	ElsIf Parameters.UpdateMode = 1 Then // On exiting the application
		ParameterName = "StandardSubsystems.SuggestInfobaseUpdateOnExitSession";
		ApplicationParameters.Insert(ParameterName, True);
		ApplicationParameters.Insert("StandardSubsystems.UpdateFilesNames", UpdateFilesNames(Parameters));
	ElsIf Parameters.UpdateMode = 2 Then // Schedule an update
		ScheduleConfigurationUpdate(Parameters, AdministrationParameters);
	EndIf;
	
	ConfigurationUpdateServerCall.SaveConfigurationUpdateSettings(Parameters);
	
	If Form <> Undefined Then
		Form.Close();
	EndIf;
	
EndProcedure

// End OnlineUserSupport.GetApplicationUpdates

#EndRegion

#EndRegion

#Region Internal

Procedure ProcessUpdateResult(UpdateResult, ScriptDirectory) Export
	
	If IsBlankString(ScriptDirectory) Then
		EventLogClient.AddMessageForEventLog(EventLogEvent(),
			"Warning",
			NStr("ru = 'Обновление выполнено с очень старой версии программы. 
			           |Данные журнала обновления не были загружены, но сам журнал 
			           |можно найти в папке временных файлов %temp% - 
			           |в папке вида 1Cv8Update.<xxxxxxxx>(цифры).'; 
			           |en = 'The application is updated from a very old version.
			           |The update log data was not imported. See the log
			           |in the temporary files folder %temp%, in the
			           |1Cv8Update.<xxxxxxxx> subfolder (where xxxxxxxx are digits).'; 
			           |pl = 'Aktualizacja jest wykonana z bardzo starej wersji programu. 
			           |Dane dziennika aktualizacji nie były pobrane, ale sam dziennik 
			           |można znaleźć w folderze tymczasowych plików %temp% - 
			           |w folderze rodzaju 1Cv8Update.<xxxxxxxx>(cyfry).';
			           |es_ES = 'El programa ha sido actualizado de la versión muy antigua. 
			           |Los datos del registro de la actualización no han sido cargados pero se puede encontrar 
			           |el registro mismo en la carpeta de los archivos temporales %temp% - 
			           | en la carpeta del tipo 1Cv8Update.<xxxxxxxx>(cifras).';
			           |es_CO = 'El programa ha sido actualizado de la versión muy antigua. 
			           |Los datos del registro de la actualización no han sido cargados pero se puede encontrar 
			           |el registro mismo en la carpeta de los archivos temporales %temp% - 
			           | en la carpeta del tipo 1Cv8Update.<xxxxxxxx>(cifras).';
			           |tr = 'Güncelleme uygulamanın çok eski sürümünden yapıldı. 
			           |Güncelleme günlüğün verileri yüklenmedi, ancak günlük 
			           | geçici dosya klasöründe%temp% -
			           |1Cv8Update.<xxxxxxxx>(rakamlar)tür klasörde bulunabilir.';
			           |it = 'L''applicazione è aggiornata da una versione molto vecchia.
			           |I dati del registro di aggiornamento non sono stati importati. Visualizzare il registro
			           |nella cartella di file temporanei %temp% nella sottocartella 
			           |1Cv8Update.<xxxxxxxx> (dove xxxxxxxx sono cifre).';
			           |de = 'Update erfolgt mit einer sehr alten Version des Programms.
			           |Die Update-Protokolldaten wurden nicht heruntergeladen, das Protokoll
			           |selbst befindet sich jedoch im Ordner für temporäre Dateien %temp% -
			           |im Ordner des Typs 1Cv8Update. <xxxxxxxx>Unterordner (xxxxxxxx sind Zahlen).'"),
			, 
			True);
			
		UpdateResult = True; // Considering the update successful.
	Else 
		EventLogClient.AddMessageForEventLog(EventLogEvent(),
			"Information", 
			StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Папка с журналом обновления расположена %1'; en = 'The update log is located in %1.'; pl = 'Folder z dziennikiem aktualizacji jest rozmieszczony %1';es_ES = 'La carpeta con el registro se encuentra %1';es_CO = 'La carpeta con el registro se encuentra %1';tr = 'Güncelleme günlüğü klasörün konumu%1';it = 'Il registro di aggiornamento è posizionato in %1.';de = 'Der Ordner mit dem Aktualisierungsprotokoll befindet sich %1'"), ScriptDirectory),
			,
			True);
		
		ReadDataToEventLog(UpdateResult, ScriptDirectory);
	EndIf;

EndProcedure

// Updates database configuration.
//
// Parameters:
//  StandardProcessing - Boolean - if False, do not show
//                                  the manual update instruction.
Procedure InstallConfigurationUpdate(Exit = False) Export
	
	FormParameters = New Structure("Exit, ConfigurationUpdateReceived",
		Exit, Exit);
	ShowUpdateSearchAndInstallation(FormParameters);
	
EndProcedure

// Writes an error marker file to the script directory.
//
Procedure WriteErrorProtocolFile(ScriptDirectory) Export
	
#If Not WebClient Then
	LogFile = New TextWriter(ScriptDirectory + "error.txt");
	LogFile.Close();
#EndIf
	
EndProcedure

// Opens a form with a list of installed patches.
//
// Parameters:
//  Patches - ValueList - a list of names of installed patches to be displayed.
//                                 If it is not specified, the method displays all patches.
//
Procedure ShowInstalledPatches(Patches = Undefined) Export
	
	FormParameters = New Structure("Patches", Patches);
	OpenForm("CommonForm.InstalledPatches", FormParameters);
	
EndProcedure

// Determines whether an extension is a patch.
// Parameters:
//  PatchName - String - an extension name.
//
Function IsPatch(PatchName) Export
	Return StrStartsWith(PatchName, "EF_");
EndFunction

// Determines whether configuration update is possible.
//
// Returns:
//  Boolean - shows whether update is possible.
//
Function UpdateStartPossible() Export
	
	UpdateStartPossible = True;
	
#If WebClient Then
	UpdateStartPossible = False;
	MessageText = NStr("ru = 'Обновление программы недоступно в веб-клиенте.'; en = 'Cannot update the application in the web client.'; pl = 'Aktualizacja aplikacji w kliencie sieci Web jest niedostępna.';es_ES = 'Actualización de la aplicación en el cliente web no se encuentra disponible.';es_CO = 'Actualización de la aplicación en el cliente web no se encuentra disponible.';tr = 'Uygulama web istemcisinde güncellenemez.';it = 'Impossibile aggiornare l''applicazione in client web.';de = 'Das Aktualisieren der Anwendung im Webclient ist nicht möglich.'");
	
#ElsIf MobileClient Then
	
	UpdateStartPossible = False;
	MessageText = NStr("ru = 'Обновление программы недоступно в мобильном клиенте.'; en = 'Cannot update the application in the mobile client.'; pl = 'Aktualizacja programu jest niedostępna w mobilnym kliencie.';es_ES = 'La actualización del programa no está disponible en el cliente móvil.';es_CO = 'La actualización del programa no está disponible en el cliente móvil.';tr = 'Uygulama mobil istemcide güncellenemez.';it = 'Impossibile aggiornare l''applicazione in client mobile.';de = 'Das Programm-Update ist im mobilen Client nicht verfügbar.'");
	
#Else
	
	If Not CommonClientServer.IsWindowsClient() Then
		UpdateStartPossible = False;
		MessageText = NStr("ru = 'Обновление программы доступно только в клиенте под управлением ОС Windows.'; en = 'The update is only available in the Windows client.'; pl = 'Aktualizacja programu jest dostępna tylko w kliencie w systemie operacyjnym SO Windows.';es_ES = 'La actualización del programa está disponible solo en el cliente bajo OS Windows.';es_CO = 'La actualización del programa está disponible solo en el cliente bajo OS Windows.';tr = 'Uygulama OS Windows işletim sistemini çalıştıran istemcide güncellenir.';it = 'L''aggiornamento è possibile solo nel client Windows.';de = 'Das Programm-Update ist nur auf dem Client verfügbar, auf dem Windows ausgeführt wird.'");
	EndIf;
	
	If CommonClient.ClientConnectedOverWebServer() Then
		UpdateStartPossible = False;
		MessageText = NStr("ru = 'Обновление программы недоступно при подключении через веб-сервер.'; en = 'Cannot update the application using a web server connection.'; pl = 'Aktualizacja aplikacji przy użyciu połączenia z serwerem sieciowym jest niedostępna.';es_ES = 'Actualización de la aplicación utilizando la conexión del servidor web no se encuentra disponible.';es_CO = 'Actualización de la aplicación utilizando la conexión del servidor web no se encuentra disponible.';tr = 'Uygulama, web sunucusu bağlantısı kullanılarak güncellenemez.';it = 'Impossibile aggiornare l''applicazione usando una connessione web server.';de = 'Das Aktualisieren der Anwendung über die Webserververbindung ist nicht möglich.'");
	EndIf;
	
#EndIf

	If Not UpdateStartPossible Then
		ShowMessageBox(, MessageText);
	EndIf;
		
	Return UpdateStartPossible;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See CommonClientOverridable.OnStart. 
Procedure OnStart(Parameters) Export
	
	CheckForConfigurationUpdate();
	
EndProcedure

// See CommonClientOverridable.BeforeExit. 
Procedure BeforeExit(Cancel, Warnings) Export
	
	// Warning! When the "Configuration Update" subsystem sets its flag, it clears the list of all the 
	// previously added warnings.
	If ApplicationParameters["StandardSubsystems.SuggestInfobaseUpdateOnExitSession"] = True Then
		WarningParameters = StandardSubsystemsClient.WarningOnExit();
		WarningParameters.CheckBoxText  = NStr("ru = 'Установить обновление конфигурации'; en = 'Install configuration update'; pl = 'Zainstaluj aktualizację konfiguracji';es_ES = 'Instalar la actualización de la configuración';es_CO = 'Instalar la actualización de la configuración';tr = 'Yapılandırma güncellemesini yükle';it = 'Installare l''aggiornamento della configurazione';de = 'Installieren Sie das Konfigurationsupdate'");
		WarningParameters.WarningText  = NStr("ru = 'Запланирована установка обновления'; en = 'Update installation is scheduled'; pl = 'Zostało zaplanowane ustawienie aktualizacji';es_ES = 'Se ha planificado la instalación de la actualización';es_CO = 'Se ha planificado la instalación de la actualización';tr = 'Güncelleme planlandı';it = 'Installazione pianificata dell''aggiornamento';de = 'Geplante Update-Installation'");
		WarningParameters.Priority = 50;
		WarningParameters.OutputSingleWarning = True;
		
		ActionIfFlagSet = WarningParameters.ActionIfFlagSet;
		ActionIfFlagSet.Form = "DataProcessor.InstallUpdates.Form.Form";
		ActionIfFlagSet.FormParameters = New Structure("Exit, RunUpdate", True, True);
		
		Warnings.Add(WarningParameters);
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

Function UpdateInstallationPossible(Parameters, AdministrationParameters)
	
	IsFileInfobase = CommonClient.FileInfobase();
	
	If IsFileInfobase AND Parameters.CreateBackup = 2 Then
		File = New File(Parameters.IBBackupDirectoryName);
		If Not File.Exist() Or Not File.IsDirectory() Then
			ShowMessageBox(, NStr("ru = 'Укажите существующий каталог для сохранения резервной копии ИБ.'; en = 'Please specify an existing directory for storing the infobase backup.'; pl = 'Wskaż istniejący katalog dla zachowania kopii zapasowej BI.';es_ES = 'Especificar un directorio existente para guardar la copia de respaldo de la infobase.';es_CO = 'Especificar un directorio existente para guardar la copia de respaldo de la infobase.';tr = 'IB yedeğini kaydetmek için varolan bir dizini belirtin.';it = 'Si prega di indicare una directory esistente per salvare il backup dell''infobase.';de = 'Geben Sie ein vorhandenes Verzeichnis an, um die IB-Sicherung zu speichern.'"));
			Return False;
		EndIf;
	EndIf;
	
	If Parameters.UpdateMode = 0 Then // Update now
		ParameterName = "StandardSubsystems.MessagesForEventLog";
		If IsFileInfobase AND ConfigurationUpdateServerCall.HasActiveConnections(ApplicationParameters[ParameterName]) Then
			ShowMessageBox(, NStr("ru = 'Невозможно продолжить обновление конфигурации, так как не завершены все соединения с информационной базой.'; en = 'Cannot proceed with configuration update as some infobase connections were not terminated.'; pl = 'Nie można kontynuować aktualizacji konfiguracji, ponieważ nie zostały zakończone wszystkie połączenia z bazą informacyjną.';es_ES = 'Esta actualización de configuraciones no puede procederse porque las conexiones con la infobase no se han finalizado.';es_CO = 'Esta actualización de configuraciones no puede procederse porque las conexiones con la infobase no se han finalizado.';tr = 'Bazı Infobase bağlatıları sonlandırılmadığından yapılandırma güncellemesi devam edemiyor.';it = 'Impossibile continuare l''aggiornamento di configurazione, perché non tutte le connessioni al database sono state terminate.';de = 'Das Konfigurationsupdate kann nicht fortgesetzt werden, da Verbindungen mit der Infobase nicht beendet wurden.'"));
			Return False;
		EndIf;
	ElsIf Parameters.UpdateMode = 2 Then
		If Not UpdateDateCorrect(Parameters) Then
			Return False;
		EndIf;
		If Parameters.EmailReport
			AND Not CommonClientServer.EmailAddressMeetsRequirements(Parameters.EmailAddress) Then
			ShowMessageBox(, NStr("ru = 'Укажите допустимый адрес электронной почты.'; en = 'Please specify a valid email address.'; pl = 'Podaj ważny adres poczty e-mail.';es_ES = 'Especificar una dirección de correo electrónico admisible.';es_CO = 'Especificar una dirección de correo electrónico admisible.';tr = 'İzin verilen bir e-posta adresi belirtin.';it = 'Si prega di specificare un indirizzo email valido.';de = 'Geben Sie eine zulässige E-Mail-Adresse an.'"));
			Return False;
		EndIf;
		If Not TaskSchedulerSupported() Then
			ShowMessageBox(, NStr("ru = 'Планировщик заданий поддерживается только начиная с операционной системы версии 6.0 Vista.'; en = 'Job scheduler is supported only since Windows Vista 6.0.'; pl = 'Program planowania zadań jest obsługiwany tylko zaczynając od systemu operacyjnego wersji 6.0 Vista.';es_ES = 'El planificador de las tareas se admite solo empezando con el sistema operativo de la versión 6.0 Vista.';es_CO = 'El planificador de las tareas se admite solo empezando con el sistema operativo de la versión 6.0 Vista.';tr = 'Görev planlayıcısı işletim sistemin yalnızca 6.0 Vista sürümünden itibaren desteklenir.';it = 'Il programmatore di compiti è supportato solo da Windows Vista 6.0 in poi.';de = 'Der Job Scheduler wird erst ab der Betriebssystem-Version 6.0 von Vista unterstützt.'"));
			Return False;
		EndIf;
	EndIf;
	
	Return True;
	
EndFunction

Procedure RunUpdateScript(Parameters, AdministrationParameters)
	
	MainScriptFileName = GenerateUpdateScriptFiles(True, Parameters, AdministrationParameters);
	EventLogClient.AddMessageForEventLog(EventLogEvent(), "Information",
		NStr("ru = 'Выполняется процедура обновления конфигурации:'; en = 'Running configuration update procedure:'; pl = 'Trwa aktualizacja konfiguracji:';es_ES = 'Actualizando la configuración:';es_CO = 'Actualizando la configuración:';tr = 'Güncelleme yapılandırması:';it = 'Esecuzione procedura di aggiornamento configurazione:';de = 'Konfiguration aktualisieren:'") + " " + MainScriptFileName);
	ConfigurationUpdateServerCall.WriteUpdateStatus(UserName(), True, False, False,
		MainScriptFileName, ApplicationParameters["StandardSubsystems.MessagesForEventLog"]);
		
	Shell = New COMObject("Wscript.Shell");
	Shell.RegWrite("HKCU\Software\Microsoft\Internet Explorer\Styles\MaxScriptStatements", 1107296255, "REG_DWORD");
	
	PathToLauncher = StandardSubsystemsClient.SystemApplicationFolder() + "mshta.exe";
	
	CommandLine = """%1"" ""%2"" [p1]%3[/p1][p2]%4[/p2]";
	CommandLine = StringFunctionsClientServer.SubstituteParametersToString(CommandLine,
		PathToLauncher, MainScriptFileName,
		StringUnicode(AdministrationParameters.InfobaseAdministratorPassword),
		StringUnicode(AdministrationParameters.ClusterAdministratorPassword));
		
	CommonClientServer.StartApplication(CommandLine);
	
EndProcedure

Function UpdateDateCorrect(Parameters)
	
	CurrentDate = CommonClient.SessionDate();
	If Parameters.UpdateDateTime < CurrentDate Then
		MessageText = NStr("ru = 'Обновление конфигурации может быть запланировано только на будущую дату и время.'; en = 'A configuration update can be scheduled only for a future date and time.'; pl = 'Aktualizacja konfiguracji może być zaplanowana tylko na przyszłą datę i czas.';es_ES = 'Actualización de configuraciones puede programarse solo para una fecha y una hora en el futuro.';es_CO = 'Actualización de configuraciones puede programarse solo para una fecha y una hora en el futuro.';tr = 'Yapılandırma güncellemesi sadece ileri bir tarih ve saat için planlanabilir.';it = 'L''aggiornamento della configurazione può essere pianificato solo per la data e l''ora future.';de = 'Das Konfigurationsupdate kann nur für ein zukünftiges Datum und eine geplante Uhrzeit geplant werden.'");
	ElsIf Parameters.UpdateDateTime > AddMonth(CurrentDate, 1) Then
		MessageText = NStr("ru = 'Обновление конфигурации может быть запланировано не позднее, чем через месяц относительно текущей даты.'; en = 'A configuration update cannot be scheduled to a date later than one month from the current date.'; pl = 'Aktualizacja konfiguracji może być zaplanowana nie później niż po miesiącu od bieżącej daty.';es_ES = 'Actualización de configuraciones puede programarse no más tarde que en un mes a partir de la fecha actual.';es_CO = 'Actualización de configuraciones puede programarse no más tarde que en un mes a partir de la fecha actual.';tr = 'Yapılandırma güncellemesi, geçerli tarihten itibaren bir ay içinde geçmeyecek şekilde programlanabilir.';it = 'Un aggiornamento configurazione non può essere pianificato a una data successiva a un mese dalla data corrente.';de = 'Die Aktualisierung der Konfiguration kann nicht später als in einem Monat ab dem aktuellen Datum geplant werden.'");
	EndIf;
	
	DateCorrect = IsBlankString(MessageText);
	If Not DateCorrect Then
		ShowMessageBox(, MessageText);
	EndIf;
	
	Return DateCorrect;
	
EndFunction

Function GenerateUpdateScriptFiles(Val InteractiveMode, Parameters, AdministrationParameters)
	
	ClientRunParameters = StandardSubsystemsClient.ClientRunParameters();
	IsFileInfobase = ClientRunParameters.FileInfobase;
	
	#If Not WebClient AND NOT MobileClient Then
	PlatformDirectory = Undefined;
	Parameters.Property("PlatformDirectory", PlatformDirectory);
	ApplicationDirectory = ?(ValueIsFilled(PlatformDirectory), PlatformDirectory, BinDir());
	
	
	DesignerExecutableFileName = ApplicationDirectory + StandardSubsystemsClient.ApplicationExecutableFileName(True);
	ClientExecutableFileName = ApplicationDirectory + StandardSubsystemsClient.ApplicationExecutableFileName();
	COMConnectorPath = BinDir() + "comcntr.dll";
	
	UseCOMConnector = Not (ClientRunParameters.IsBaseConfigurationVersion Or ClientRunParameters.IsTrainingPlatform);
	
	ScriptParameters = GetUpdateAdministratorAuthenticationParameters(AdministrationParameters);
	InfobaseConnectionString = ScriptParameters.InfobaseConnectionString + ScriptParameters.StringForConnection;
	If StrEndsWith(InfobaseConnectionString, ";") Then
		InfobaseConnectionString = Left(InfobaseConnectionString, StrLen(InfobaseConnectionString) - 1);
	EndIf;
	
	// Determining path to the infobase.
	InfobasePath = IBConnectionsClientServer.InfobasePath(, AdministrationParameters.ClusterPort);
	InfobasePathParameter = ?(IsFileInfobase, "/F", "/S") + InfobasePath;
	InfobasePathString = ?(IsFileInfobase, InfobasePath, "");
	InfobasePathString = CommonClientServer.AddLastPathSeparator(StrReplace(InfobasePathString, """", "")) + "1Cv8.1CD";
	
	EmailAddress = ?(Parameters.UpdateMode = 2 AND Parameters.EmailReport, Parameters.EmailAddress, "");
	
	
	// Calling TempFilesDir instead of GetTempFileName as the directory cannot be deleted automatically 
	// on client application exit.
	// It stores the executable files, execution log, and a backup (it the settings include backup creation).
	TempFilesDirForUpdate = TempFilesDir() + "1Cv8Update." + Format(CommonClient.SessionDate(), "DF=yymmddHHmmss") + "\";
	
	If Parameters.CreateBackup = 1 Then 
		BackupDirectory = TempFilesDirForUpdate;
	ElsIf Parameters.CreateBackup = 2 Then 
		BackupDirectory = CommonClientServer.AddLastPathSeparator(Parameters.IBBackupDirectoryName);
	Else 
		BackupDirectory = "";
	EndIf;
	
	CreateBackup = IsFileInfobase AND (Parameters.CreateBackup = 1 Or Parameters.CreateBackup = 2);
	
	ExecuteDeferredHandlers = False;
	IsDeferredUpdate = (Parameters.UpdateMode = 2);
	TemplatesTexts = ConfigurationUpdateServerCall.TemplatesTexts(InteractiveMode,
		ApplicationParameters["StandardSubsystems.MessagesForEventLog"], ExecuteDeferredHandlers, IsDeferredUpdate);
	Username = AdministrationParameters.InfobaseAdministratorName;
	
	If IsDeferredUpdate Then 
		RandomNumberGenerator = New RandomNumberGenerator;
		TaskCode = Format(RandomNumberGenerator.RandomNumber(1000, 9999), "NG=0");
		TaskName = ScheduleServiceTaskName(TaskCode);
	EndIf;
	
	ParametersArea = TemplatesTexts.ParametersArea;
	InsertScriptParameter("DesignerExecutableFileName" , DesignerExecutableFileName          , True, ParametersArea);
	InsertScriptParameter("ClientExecutableFileName"       , ClientExecutableFileName                , True, ParametersArea);
	InsertScriptParameter("COMConnectorPath"               , COMConnectorPath                        , True, ParametersArea);
	InsertScriptParameter("InfobasePathParameter"   , InfobasePathParameter            , True, ParametersArea);
	InsertScriptParameter("InfobaseFilePathString", InfobasePathString              , True, ParametersArea);
	InsertScriptParameter("InfobaseConnectionString", InfobaseConnectionString         , True, ParametersArea);
	InsertScriptParameter("EventLogEvent"         , EventLogEvent()                , True, ParametersArea);
	InsertScriptParameter("EmailAddress"             , EmailAddress                      , True, ParametersArea);
	InsertScriptParameter("NameOfUpdateAdministrator"       , Username                            , True, ParametersArea);
	InsertScriptParameter("COMConnectorName"                 , ClientRunParameters.COMConnectorName   , True, ParametersArea);
	InsertScriptParameter("BackupDirectory"             , BackupDirectory                      , True, ParametersArea);
	InsertScriptParameter("CreateBackup"           , CreateBackup                    , False  , ParametersArea);
	InsertScriptParameter("RestoreInfobase" , Parameters.RestoreInfobase, False  , ParametersArea);
	InsertScriptParameter("BlockIBConnections"           , Not IsFileInfobase                         , False  , ParametersArea);
	InsertScriptParameter("UseCOMConnector"        , UseCOMConnector                 , False  , ParametersArea);
	InsertScriptParameter("StartSessionAfterUpdate"       , Not Parameters.Exit       , False  , ParametersArea);
	InsertScriptParameter("CompressIBTables"           , IsFileInfobase                            , False  , ParametersArea);
	InsertScriptParameter("ExecuteDeferredHandlers"    , ExecuteDeferredHandlers             , False  , ParametersArea);
	InsertScriptParameter("TaskSchedulerTaskName"        , TaskName                                  , True, ParametersArea);
	
	CreateDirectory(TempFilesDirForUpdate);
	PatchesInformation = PatchesInformation(Parameters, TempFilesDirForUpdate);
	ParametersArea = StrReplace(ParametersArea, "[UpdateFilesNames]", UpdateFilesNames(Parameters));
	ParametersArea = StrReplace(ParametersArea, "[PatchFilesNames]", PatchesInformation.Set);
	ParametersArea = StrReplace(ParametersArea, "[DeletedChangesNames]", PatchesInformation.Delete);
	
	TemplatesTexts.ConfigurationUpdateFileTemplate = ParametersArea + TemplatesTexts.ConfigurationUpdateFileTemplate;
	TemplatesTexts.Delete("ParametersArea");
	
	//
	ScriptFile = New TextDocument;
	ScriptFile.Output = UseOutput.Enable;
	ScriptFile.SetText(TemplatesTexts.ConfigurationUpdateFileTemplate);
	
	ScriptFileName = TempFilesDirForUpdate + "main.js";
	ScriptFile.Write(ScriptFileName, UpdateProgramFilesEncoding());
	
	// Auxiliary file: helpers.js.
	ScriptFile = New TextDocument;
	ScriptFile.Output = UseOutput.Enable;
	ScriptFile.SetText(TemplatesTexts.AdditionalConfigurationUpdateFile);
	ScriptFile.Write(TempFilesDirForUpdate + "helpers.js", UpdateProgramFilesEncoding());
	
	If InteractiveMode Then
		// Auxiliary file: splash.png.
		PictureLib.ExternalOperationSplash.Write(TempFilesDirForUpdate + "splash.png");
		// Auxiliary file: splash.ico.
		PictureLib.ExternalOperationSplashIcon.Write(TempFilesDirForUpdate + "splash.ico");
		// Auxiliary  file: progress.gif.
		PictureLib.TimeConsumingOperation48.Write(TempFilesDirForUpdate + "progress.gif");
		// Main splash screen file: splash.hta.
		MainScriptFileName = TempFilesDirForUpdate + "splash.hta";
		ScriptFile = New TextDocument;
		ScriptFile.Output = UseOutput.Enable;
		ScriptFile.SetText(TemplatesTexts.ConfigurationUpdateSplash);
		ScriptFile.Write(MainScriptFileName, UpdateProgramFilesEncoding());
	Else
		MainScriptFileName = TempFilesDirForUpdate + "updater.js";
		ScriptFile = New TextDocument;
		ScriptFile.Output = UseOutput.Enable;
		ScriptFile.SetText(TemplatesTexts.NonInteractiveConfigurationUpdate);
		ScriptFile.Write(MainScriptFileName, UpdateProgramFilesEncoding());
	EndIf;
	
	If IsDeferredUpdate Then 
		
		StartDate = Format(Parameters.UpdateDateTime, "DF=yyyy-MM-ddTHH:mm:ss");
		
		ScriptPath = StandardSubsystemsClient.SystemApplicationFolder() + "wscript.exe";
		ScriptParameters = StringFunctionsClientServer.SubstituteParametersToString("//nologo ""%1"" /p1:""%2"" /p2:""%3""",
			MainScriptFileName,
			StringUnicode(AdministrationParameters.InfobaseAdministratorPassword),
			StringUnicode(AdministrationParameters.ClusterAdministratorPassword));
		
		TaskDetails = NStr("ru = 'Обновление конфигурации 1С:Предприятие'; en = 'Update 1C:Enterprise configuration'; pl = 'Aktualizacja konfiguracji 1C:Enterprise';es_ES = 'Actualizar la configuración de 1C:Enterprise';es_CO = 'Actualizar la configuración de 1C:Enterprise';tr = '1C:Enterprise yapılandırma güncellemesi';it = 'Aggiornamento configurazione 1C:Enterprise';de = 'Konfigurationsupdate 1C:Enterprise'");
		
		TaskSchedulerTaskCreationScript = TemplatesTexts.TaskSchedulerTaskCreationScript;
		
		InsertScriptParameter("StartDate" , StartDate, True, TaskSchedulerTaskCreationScript);
		InsertScriptParameter("ScriptPath" , ScriptPath, True, TaskSchedulerTaskCreationScript);
		InsertScriptParameter("ScriptParameters" , ScriptParameters, True, TaskSchedulerTaskCreationScript);
		InsertScriptParameter("TaskName" , TaskName, True, TaskSchedulerTaskCreationScript);
		InsertScriptParameter("TaskDetails" , TaskDetails, True, TaskSchedulerTaskCreationScript);
		
		TaskSchedulerTaskCreationScriptName = TempFilesDirForUpdate + "addsheduletask.js";
		ScriptFile = New TextDocument;
		ScriptFile.Output = UseOutput.Enable;
		ScriptFile.SetText(TaskSchedulerTaskCreationScript);
		ScriptFile.Write(TaskSchedulerTaskCreationScriptName, UpdateProgramFilesEncoding());
		
		Parameters.SchedulerTaskCode = TaskCode;
		
		Parameters.Insert("TaskSchedulerTaskCreationScriptName", TaskSchedulerTaskCreationScriptName);
		
	EndIf;
	
	LogFile = New TextDocument;
	LogFile.Output = UseOutput.Enable;
	LogFile.SetText(StandardSubsystemsClient.SupportInformation());
	LogFile.Write(TempFilesDirForUpdate + "templog.txt", TextEncoding.System);
	
	ScriptFile = New TextDocument;
	ScriptFile.Output = UseOutput.Enable;
	ScriptFile.SetText(TemplatesTexts.PatchesDeletionScript);
	ScriptFile.Write(TempFilesDirForUpdate + "add-delete-patches.js", UpdateProgramFilesEncoding());
	
	Return MainScriptFileName;
	
	#EndIf
	
EndFunction

Procedure InsertScriptParameter(Val ParameterName, Val ParameterValue, DoFormat, ParametersArea)
	
	If DoFormat = True Then
		ParameterValue = DoFormat(ParameterValue);
	ElsIf DoFormat = False Then
		ParameterValue = ?(ParameterValue, "true", "false");
	EndIf;
	ParametersArea = StrReplace(ParametersArea, "[" + ParameterName + "]", ParameterValue);
	
EndProcedure

Function UpdateFilesNames(Parameters)
	
	ParameterName = "StandardSubsystems.UpdateFilesNames";
	If ApplicationParameters.Get(ParameterName) <> Undefined Then
		Return ApplicationParameters[ParameterName];
	EndIf;
	
	If Parameters.Property("UpdateFileRequired") AND Not Parameters.UpdateFileRequired Then
		UpdateFilesNames = "";
	Else
		If IsBlankString(Parameters.NameOfUpdateFile) Then
			FileNames = New Array;
			For Each UpdateFile In Parameters.UpdateFiles Do
				UpdateFilePrefix = ?(UpdateFile.RunUpdateHandlers, "+", "");
				FileNames.Add(DoFormat(UpdateFilePrefix + UpdateFile.UpdateFileFullName));
			EndDo;
			UpdateFilesNames = StrConcat(FileNames, ",");
		Else
			UpdateFilesNames = DoFormat(Parameters.NameOfUpdateFile);
		EndIf;
	EndIf;
	
	Return "[" + UpdateFilesNames + "]";
	
EndFunction

Function PatchesInformation(Parameters, TempFilesDir)
	
	ParameterName = "StandardSubsystems.PatchesInformation";
	If ApplicationParameters.Get(ParameterName) <> Undefined Then
		Return ApplicationParameters[ParameterName];
	EndIf;
	
	PatchesToInstall = "['']";
	PatchesToDelete = "['']";
	If Parameters.Property("PatchesFiles") Then
		PatchesToInstall = PatchFilesNames(Parameters);
	ElsIf Parameters.Property("Patches") Then
		If Parameters.Patches.Property("Set")
			AND Parameters.Patches.Set.Count() > 0 Then
			FileNames = New Array;
			For Each NewPatch In Parameters.Patches.Set Do
				FileName = StrReplace(String(New UUID),"-", "") + ".cfe";
				FullFileName = TempFilesDir + FileName;
				GetFile(NewPatch, FullFileName, False);
				FileNames.Add(DoFormat(FullFileName));
			EndDo;
			PatchesToInstall = StrConcat(FileNames, ",");
			PatchesToInstall = "[" + PatchesToInstall + "]";
		EndIf;
		
		If Parameters.Patches.Property("Delete")
			AND Parameters.Patches.Delete.Count() > 0 Then
			PatchesToDelete = StrConcat(Parameters.Patches.Delete, ",");
			PatchesToDelete = "[" + PatchesToDelete + "]";
		EndIf;
	EndIf;
	
	PatchesInformation = New Structure;
	PatchesInformation.Insert("Set", PatchesToInstall);
	PatchesInformation.Insert("Delete", PatchesToDelete);
	
	Return PatchesInformation;
	
EndFunction

Function PatchFilesNames(Parameters)
	
	ParameterName = "StandardSubsystems.PatchFilesNames";
	If ApplicationParameters.Get(ParameterName) <> Undefined Then
		Return ApplicationParameters[ParameterName];
	EndIf;
	
	FileNames = New Array;
	For Each PatchFileName In Parameters.PatchesFiles Do
		FileNames.Add(DoFormat(PatchFileName));
	EndDo;
	PatchFilesNames = StrConcat(FileNames, ",");
	
	Return "[" + PatchFilesNames + "]";
	
EndFunction

Function DoFormat(Val Text)
	Text = StrReplace(Text, "\", "\\");
	Text = StrReplace(Text, """", "\""");
	Text = StrReplace(Text, "'", "\'");
	Return "'" + Text + "'";
EndFunction

Function GetUpdateAdministratorAuthenticationParameters(AdministrationParameters)
	
	Result = New Structure("StringForConnection, InfobaseConnectionString");
	
	ClusterPort = AdministrationParameters.ClusterPort;
	CurrentConnections = IBConnectionsServerCall.ConnectionsInformation(True,
		ApplicationParameters["StandardSubsystems.MessagesForEventLog"], ClusterPort);
		
	Result.InfobaseConnectionString = CurrentConnections.InfobaseConnectionString;
	Result.StringForConnection = "Usr=""{0}"";Pwd=""{1}""";
	
	Return Result;
	
EndFunction

Function ScheduleServiceTaskName(Val TaskCode)
	
	Return StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Обновление конфигурации (%1)'; en = 'Update configuration (%1)'; pl = 'Aktualizacja konfiguracji (%1)';es_ES = 'Actualizar la configuración (%1)';es_CO = 'Actualizar la configuración (%1)';tr = 'Yapılandırmayı güncelle (%1)';it = 'Aggiornamento configurazione (%1)';de = 'Konfigurationsupdate (%1)'"), Format(TaskCode, "NG=0"));
	
EndFunction

Function StringUnicode(String)
	
	Result = "";
	
	For CharNumber = 1 To StrLen(String) Do
		
		Char = Format(CharCode(Mid(String, CharNumber, 1)), "NG=0");
		Char = StringFunctionsClientServer.SupplementString(Char, 4);
		Result = Result + Char;
		
	EndDo;
	
	Return Result;
	
EndFunction

// Returns the event name for writing to the event log.
Function EventLogEvent() Export
	Return NStr("ru = 'Обновление конфигурации'; en = 'Configuration update'; pl = 'Aktualizacja konfiguracji';es_ES = 'Actualización de la configuración';es_CO = 'Actualización de la configuración';tr = 'Yapılandırma güncellemesi';it = 'Aggiornamento della configurazione';de = 'Konfigurations-Update'", CommonClientServer.DefaultLanguageCode());
EndFunction

// Checks whether a configuration update is available at startup.
//
Procedure CheckForConfigurationUpdate()
	
	If Not CommonClientServer.IsWindowsClient() Then
		Return;
	EndIf;
	
#If NOT WebClient AND NOT MobileClient Then
	ClientRunParameters = StandardSubsystemsClient.ClientParametersOnStart();
	If ClientRunParameters.DataSeparationEnabled Or Not ClientRunParameters.SeparatedDataUsageAvailable Then
		Return;
	EndIf;
	
	If ClientRunParameters.Property("ShowInvalidHandlersMessage") Then
		Return; // Update results form will be shown later.
	EndIf;
	
	UpdateSettings = ClientRunParameters.UpdateSettings;
	UpdateAvailability = UpdateSettings.CheckPreviousInfobaseUpdates;
	
	If UpdateAvailability Then
		// The previous update must be completed.
		OpenForm("DataProcessor.ApplicationUpdateResult.Form.DeferredIBUpdateProgressIndicator");
		Return;
	EndIf;
	
	If UpdateSettings.ConfigurationChanged Then
		ShowUserNotification(NStr("ru = 'Обновление конфигурации'; en = 'Configuration update'; pl = 'Aktualizacja konfiguracji';es_ES = 'Actualización de la configuración';es_CO = 'Actualización de la configuración';tr = 'Yapılandırma güncellemesi';it = 'Aggiornamento della configurazione';de = 'Konfigurations-Update'"),
			"e1cib/app/DataProcessor.InstallUpdates",
			NStr("ru = 'Конфигурация отличается от основной конфигурации информационной базы.'; en = 'The configuration is different from the main infobase configuration.'; pl = 'Konfiguracja różni się od głównej konfiguracji bazy informacyjnej.';es_ES = 'La configuración es diferente de la configuración básica de la infobase.';es_CO = 'La configuración es diferente de la configuración básica de la infobase.';tr = 'Yapılandırma, veritabanın temel yapılandırmasından farklıdır.';it = 'La configurazione è diversa dalla configurazione di base di informazioni.';de = 'Die Konfiguration unterscheidet sich von der Grundkonfiguration der Infobase.'"), 
			PictureLib.Information32);
	EndIf;
	
#EndIf

EndProcedure

Procedure ReadDataToEventLog(UpdateResult, ScriptDirectory)
	
	UpdateResult = Undefined;
	ErrorOccurredDuringUpdate = False;
	
	FilesArray = FindFiles(ScriptDirectory, "log*.txt");
	
	If FilesArray.Count() = 0 Then
		Return;
	EndIf;
	
	LogFile = FilesArray[0];
	TextDocument = New TextDocument;
	TextDocument.Read(LogFile.FullName);
	
	For LineNumber = 1 To TextDocument.LineCount() Do
		
		CurrentLine = TextDocument.GetLine(LineNumber);
		If IsBlankString(CurrentLine) Then
			Continue;
		EndIf;
		
		LevelPresentation = "Information";
		If Mid(CurrentLine, 3, 1) = "." AND Mid(CurrentLine, 6, 1) = "." Then // A string with a date.
			StringArray = StrSplit(CurrentLine, " ", False);
			DateArray = StrSplit(StringArray[0], ".");
			TimeArray = StrSplit(StringArray[1], ":");
			EventDate = Date(DateArray[2], DateArray[1], DateArray[0], TimeArray[0], TimeArray[1], TimeArray[2]);
			If StringArray[2] = "{ERR}" Then
				LevelPresentation = "Error";
				ErrorOccurredDuringUpdate = True;
			EndIf;
			Comment = TrimAll(Mid(CurrentLine, StrFind(CurrentLine, "}") + 2));
			
			If Comment = NStr("ru = 'Обновление выполнено'; en = 'Update completed'; pl = 'Aktualizacja została zakończona';es_ES = 'Actualización se ha realizado';es_CO = 'Actualización se ha realizado';tr = 'Güncelleme yapıldı';it = 'Aggiornamento completato';de = 'Update abgeschlossen'") Then
				UpdateResult = True;
				Continue;
			ElsIf Comment = NStr("ru = 'Обновление не выполнено'; en = 'Update failed'; pl = 'Aktualizacja nie jest wykonana';es_ES = 'Actualización no se ha realizado';es_CO = 'Actualización no se ha realizado';tr = 'Güncelleme yapılmadı';it = 'Aggiornamento fallito';de = 'Update nicht abgeschlossen'") Then
				UpdateResult = False;
				Continue;
			EndIf;
			
			
			For NextLineNumber = LineNumber + 1 To TextDocument.LineCount() Do
				CurrentLine = TextDocument.GetLine(NextLineNumber);
				If Mid(CurrentLine, 3, 1) = "." AND Mid(CurrentLine, 6, 1) = "." Then
					// The next line is a new event line.
					LineNumber = NextLineNumber - 1;
					Break;
				EndIf;
				
				Comment = Comment + Chars.LF + CurrentLine;
				
			EndDo;
			
			EventLogClient.AddMessageForEventLog(EventLogEvent(), LevelPresentation, Comment, EventDate);
			
		EndIf;
		
	EndDo;
	
	// If the update was performed from SSL version earlier than 2.3.1.6, the following log entries might be absent:
	// - "Update completed"
	// - "Update failed"
	// Therefore, let us rely on whether errors occurred during the update.
	If UpdateResult = Undefined Then 
		UpdateResult = Not ErrorOccurredDuringUpdate;
	EndIf;
	
	WriteEventsToEventLog();
	
EndProcedure

Procedure WriteEventsToEventLog() Export
	
	EventsForEventLog = ApplicationParameters["StandardSubsystems.MessagesForEventLog"];
	
	If TypeOf(EventsForEventLog) <> Type("ValueList") Then
		Return;
	EndIf;
	
	If EventsForEventLog.Count() = 0 Then
		Return;
	EndIf;
	
	EventLogServerCall.WriteEventsToEventLog(EventsForEventLog);
	
EndProcedure

Function TaskSchedulerSupported()
	
	// Task Scheduler is supported for versions 6.0 (Windows Vista) and later.
	
	SystemInfo = New SystemInfo();
	
	DotPosition = StrFind(SystemInfo.OSVersion, ".");
	If DotPosition < 2 Then 
		Return False;
	EndIf;
	
	VersionNumber = Mid(SystemInfo.OSVersion, DotPosition - 2, 2);
	
	TypeDescriptionNumber = New TypeDescription("Number");
	VersionLaterThanVista = TypeDescriptionNumber.AdjustValue(VersionNumber) >= 6;
	
	Return VersionLaterThanVista;
	
EndFunction

Procedure ScheduleConfigurationUpdate(Parameters, AdministrationParameters)
	
	GenerateUpdateScriptFiles(False, Parameters, AdministrationParameters);
	
	CommandPattern = "wscript.exe //nologo %1";
	CommandString = StringFunctionsClientServer.SubstituteParametersToString(
		CommandPattern, 
		Parameters.TaskSchedulerTaskCreationScriptName);
	
	ApplicationStartupParameters = CommonClientServer.ApplicationStartupParameters();
	ApplicationStartupParameters.ExecuteWithFullRights = True;
	
	CommonClientServer.StartApplication(CommandString, ApplicationStartupParameters);
	
	ConfigurationUpdateServerCall.WriteUpdateStatus(UserName(), True, False, False);
	
EndProcedure

#If Not WebClient AND NOT MobileClient Then

Function UpdateProgramFilesEncoding()
	
	// wscript.exe can process only UTF-16 LE-encoded files.
	Return TextEncoding.UTF16;
	
EndFunction

#EndIf

#EndRegion