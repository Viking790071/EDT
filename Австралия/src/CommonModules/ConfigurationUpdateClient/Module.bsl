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
		Result = NStr("ru = '???? ?????????????????? ?????????????????? ?????????? ????'; en = 'Do not back up the infobase'; pl = 'Nie tw??rz kopii zapasowej bazy informacyjnej';es_ES = 'No crear la copia de respaldo de la infobase';es_CO = 'No crear la copia de respaldo de la infobase';tr = 'Infobase''i yedekleme';it = 'Non eseguire il backup InfoBase';de = 'Die Infobase nicht sichern'");
	ElsIf Parameters.CreateBackup = 1 Then
		Result = NStr("ru = '?????????????????? ?????????????????? ?????????????????? ?????????? ????'; en = 'Create a temporary infobase backup'; pl = 'Utw??rz tymczasow?? kopi?? zapasow?? bazy informacyjnej';es_ES = 'Crear una copia de respaldo temporal de la infobase';es_CO = 'Crear una copia de respaldo temporal de la infobase';tr = 'Ge??ici Infobase yede??i olu??tur';it = 'Crea un backup infobase temporaneo';de = 'Erstellen Sie eine tempor??re Sicherung der Infobase'");
	ElsIf Parameters.CreateBackup = 2 Then
		Result = NStr("ru = '?????????????????? ?????????????????? ?????????? ????'; en = 'Create an infobase backup'; pl = 'Utw??rz kopi?? zapasow?? bazy informacyjnej';es_ES = 'Crear una copia de respaldo de la infobase';es_CO = 'Crear una copia de respaldo de la infobase';tr = 'Infobase yede??i olu??tur';it = 'Crea un backup infobase';de = 'Erstellen Sie eine Infobase-Sicherung'");
	EndIf;
	
	If Parameters.RestoreInfobase Then
		Result = Result + " " + NStr("ru = '?? ?????????????????? ?????????? ?????? ?????????????????? ????????????????'; en = 'and roll back if any issues occur during the update'; pl = 'i wycofaj w przypadku b????du';es_ES = 'y retroceder en el caso de un error';es_CO = 'y retroceder en el caso de un error';tr = 've hata durumunda geri d??n';it = 'e ripristinare nel caso un errore venga registrato durante l''aggiornamento';de = 'und im Falle eines Fehlers zur??ckrollen'");
	Else
		Result = Result + " " + NStr("ru = '?? ???? ?????????????????? ?????????? ?????? ?????????????????? ????????????????'; en = 'and do not roll back if any issues occur during the update'; pl = 'i nie wycofuj w przypadku b????du';es_ES = 'y no retroceder en el caso de un error';es_CO = 'y no retroceder en el caso de un error';tr = 've hata durumunda geri d??nme';it = 'e non ripristinare nel casi in cui un errore sia registrato durante l''aggiornamento.';de = 'und im Falle eines Fehlers nicht zur??ckrollen'");
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
			NStr("ru = '???????????????????? ?????????????????? ?? ?????????? ???????????? ???????????? ??????????????????. 
			           |???????????? ?????????????? ???????????????????? ???? ???????? ??????????????????, ???? ?????? ???????????? 
			           |?????????? ?????????? ?? ?????????? ?????????????????? ???????????? %temp% - 
			           |?? ?????????? ???????? 1Cv8Update.<xxxxxxxx>(??????????).'; 
			           |en = 'The application is updated from a very old version.
			           |The update log data was not imported. See the log
			           |in the temporary files folder %temp%, in the
			           |1Cv8Update.<xxxxxxxx> subfolder (where xxxxxxxx are digits).'; 
			           |pl = 'Aktualizacja jest wykonana z bardzo starej wersji programu. 
			           |Dane dziennika aktualizacji nie by??y pobrane, ale sam dziennik 
			           |mo??na znale???? w folderze tymczasowych plik??w %temp% - 
			           |w folderze rodzaju 1Cv8Update.<xxxxxxxx>(cyfry).';
			           |es_ES = 'El programa ha sido actualizado de la versi??n muy antigua. 
			           |Los datos del registro de la actualizaci??n no han sido cargados pero se puede encontrar 
			           |el registro mismo en la carpeta de los archivos temporales %temp% - 
			           | en la carpeta del tipo 1Cv8Update.<xxxxxxxx>(cifras).';
			           |es_CO = 'El programa ha sido actualizado de la versi??n muy antigua. 
			           |Los datos del registro de la actualizaci??n no han sido cargados pero se puede encontrar 
			           |el registro mismo en la carpeta de los archivos temporales %temp% - 
			           | en la carpeta del tipo 1Cv8Update.<xxxxxxxx>(cifras).';
			           |tr = 'G??ncelleme uygulaman??n ??ok eski s??r??m??nden yap??ld??. 
			           |G??ncelleme g??nl??????n verileri y??klenmedi, ancak g??nl??k 
			           | ge??ici dosya klas??r??nde%temp% -
			           |1Cv8Update.<xxxxxxxx>(rakamlar)t??r klas??rde bulunabilir.';
			           |it = 'L''applicazione ?? aggiornata da una versione molto vecchia.
			           |I dati del registro di aggiornamento non sono stati importati. Visualizzare il registro
			           |nella cartella di file temporanei %temp% nella sottocartella 
			           |1Cv8Update.<xxxxxxxx> (dove xxxxxxxx sono cifre).';
			           |de = 'Update erfolgt mit einer sehr alten Version des Programms.
			           |Die Update-Protokolldaten wurden nicht heruntergeladen, das Protokoll
			           |selbst befindet sich jedoch im Ordner f??r tempor??re Dateien %temp% -
			           |im Ordner des Typs 1Cv8Update. <xxxxxxxx>Unterordner (xxxxxxxx sind Zahlen).'"),
			, 
			True);
			
		UpdateResult = True; // Considering the update successful.
	Else 
		EventLogClient.AddMessageForEventLog(EventLogEvent(),
			"Information", 
			StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = '?????????? ?? ???????????????? ???????????????????? ?????????????????????? %1'; en = 'The update log is located in %1.'; pl = 'Folder z dziennikiem aktualizacji jest rozmieszczony %1';es_ES = 'La carpeta con el registro se encuentra %1';es_CO = 'La carpeta con el registro se encuentra %1';tr = 'G??ncelleme g??nl?????? klas??r??n konumu%1';it = 'Il registro di aggiornamento ?? posizionato in %1.';de = 'Der Ordner mit dem Aktualisierungsprotokoll befindet sich %1'"), ScriptDirectory),
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
	MessageText = NStr("ru = '???????????????????? ?????????????????? ???????????????????? ?? ??????-??????????????.'; en = 'Cannot update the application in the web client.'; pl = 'Aktualizacja aplikacji w kliencie sieci Web jest niedost??pna.';es_ES = 'Actualizaci??n de la aplicaci??n en el cliente web no se encuentra disponible.';es_CO = 'Actualizaci??n de la aplicaci??n en el cliente web no se encuentra disponible.';tr = 'Uygulama web istemcisinde g??ncellenemez.';it = 'Impossibile aggiornare l''applicazione in client web.';de = 'Das Aktualisieren der Anwendung im Webclient ist nicht m??glich.'");
	
#ElsIf MobileClient Then
	
	UpdateStartPossible = False;
	MessageText = NStr("ru = '???????????????????? ?????????????????? ???????????????????? ?? ?????????????????? ??????????????.'; en = 'Cannot update the application in the mobile client.'; pl = 'Aktualizacja programu jest niedost??pna w mobilnym kliencie.';es_ES = 'La actualizaci??n del programa no est?? disponible en el cliente m??vil.';es_CO = 'La actualizaci??n del programa no est?? disponible en el cliente m??vil.';tr = 'Uygulama mobil istemcide g??ncellenemez.';it = 'Impossibile aggiornare l''applicazione in client mobile.';de = 'Das Programm-Update ist im mobilen Client nicht verf??gbar.'");
	
#Else
	
	If Not CommonClientServer.IsWindowsClient() Then
		UpdateStartPossible = False;
		MessageText = NStr("ru = '???????????????????? ?????????????????? ???????????????? ???????????? ?? ?????????????? ?????? ?????????????????????? ???? Windows.'; en = 'The update is only available in the Windows client.'; pl = 'Aktualizacja programu jest dost??pna tylko w kliencie w systemie operacyjnym SO Windows.';es_ES = 'La actualizaci??n del programa est?? disponible solo en el cliente bajo OS Windows.';es_CO = 'La actualizaci??n del programa est?? disponible solo en el cliente bajo OS Windows.';tr = 'Uygulama OS Windows i??letim sistemini ??al????t??ran istemcide g??ncellenir.';it = 'L''aggiornamento ?? possibile solo nel client Windows.';de = 'Das Programm-Update ist nur auf dem Client verf??gbar, auf dem Windows ausgef??hrt wird.'");
	EndIf;
	
	If CommonClient.ClientConnectedOverWebServer() Then
		UpdateStartPossible = False;
		MessageText = NStr("ru = '???????????????????? ?????????????????? ???????????????????? ?????? ?????????????????????? ?????????? ??????-????????????.'; en = 'Cannot update the application using a web server connection.'; pl = 'Aktualizacja aplikacji przy u??yciu po????czenia z serwerem sieciowym jest niedost??pna.';es_ES = 'Actualizaci??n de la aplicaci??n utilizando la conexi??n del servidor web no se encuentra disponible.';es_CO = 'Actualizaci??n de la aplicaci??n utilizando la conexi??n del servidor web no se encuentra disponible.';tr = 'Uygulama, web sunucusu ba??lant??s?? kullan??larak g??ncellenemez.';it = 'Impossibile aggiornare l''applicazione usando una connessione web server.';de = 'Das Aktualisieren der Anwendung ??ber die Webserververbindung ist nicht m??glich.'");
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
		WarningParameters.CheckBoxText  = NStr("ru = '???????????????????? ???????????????????? ????????????????????????'; en = 'Install configuration update'; pl = 'Zainstaluj aktualizacj?? konfiguracji';es_ES = 'Instalar la actualizaci??n de la configuraci??n';es_CO = 'Instalar la actualizaci??n de la configuraci??n';tr = 'Yap??land??rma g??ncellemesini y??kle';it = 'Installare l''aggiornamento della configurazione';de = 'Installieren Sie das Konfigurationsupdate'");
		WarningParameters.WarningText  = NStr("ru = '?????????????????????????? ?????????????????? ????????????????????'; en = 'Update installation is scheduled'; pl = 'Zosta??o zaplanowane ustawienie aktualizacji';es_ES = 'Se ha planificado la instalaci??n de la actualizaci??n';es_CO = 'Se ha planificado la instalaci??n de la actualizaci??n';tr = 'G??ncelleme planland??';it = 'Installazione pianificata dell''aggiornamento';de = 'Geplante Update-Installation'");
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
			ShowMessageBox(, NStr("ru = '?????????????? ???????????????????????? ?????????????? ?????? ???????????????????? ?????????????????? ?????????? ????.'; en = 'Please specify an existing directory for storing the infobase backup.'; pl = 'Wska?? istniej??cy katalog dla zachowania kopii zapasowej BI.';es_ES = 'Especificar un directorio existente para guardar la copia de respaldo de la infobase.';es_CO = 'Especificar un directorio existente para guardar la copia de respaldo de la infobase.';tr = 'IB yede??ini kaydetmek i??in varolan bir dizini belirtin.';it = 'Si prega di indicare una directory esistente per salvare il backup dell''infobase.';de = 'Geben Sie ein vorhandenes Verzeichnis an, um die IB-Sicherung zu speichern.'"));
			Return False;
		EndIf;
	EndIf;
	
	If Parameters.UpdateMode = 0 Then // Update now
		ParameterName = "StandardSubsystems.MessagesForEventLog";
		If IsFileInfobase AND ConfigurationUpdateServerCall.HasActiveConnections(ApplicationParameters[ParameterName]) Then
			ShowMessageBox(, NStr("ru = '???????????????????? ???????????????????? ???????????????????? ????????????????????????, ?????? ?????? ???? ?????????????????? ?????? ???????????????????? ?? ???????????????????????????? ??????????.'; en = 'Cannot proceed with configuration update as some infobase connections were not terminated.'; pl = 'Nie mo??na kontynuowa?? aktualizacji konfiguracji, poniewa?? nie zosta??y zako??czone wszystkie po????czenia z baz?? informacyjn??.';es_ES = 'Esta actualizaci??n de configuraciones no puede procederse porque las conexiones con la infobase no se han finalizado.';es_CO = 'Esta actualizaci??n de configuraciones no puede procederse porque las conexiones con la infobase no se han finalizado.';tr = 'Baz?? Infobase ba??lat??lar?? sonland??r??lmad??????ndan yap??land??rma g??ncellemesi devam edemiyor.';it = 'Impossibile continuare l''aggiornamento di configurazione, perch?? non tutte le connessioni al database sono state terminate.';de = 'Das Konfigurationsupdate kann nicht fortgesetzt werden, da Verbindungen mit der Infobase nicht beendet wurden.'"));
			Return False;
		EndIf;
	ElsIf Parameters.UpdateMode = 2 Then
		If Not UpdateDateCorrect(Parameters) Then
			Return False;
		EndIf;
		If Parameters.EmailReport
			AND Not CommonClientServer.EmailAddressMeetsRequirements(Parameters.EmailAddress) Then
			ShowMessageBox(, NStr("ru = '?????????????? ???????????????????? ?????????? ?????????????????????? ??????????.'; en = 'Please specify a valid email address.'; pl = 'Podaj wa??ny adres poczty e-mail.';es_ES = 'Especificar una direcci??n de correo electr??nico admisible.';es_CO = 'Especificar una direcci??n de correo electr??nico admisible.';tr = '??zin verilen bir e-posta adresi belirtin.';it = 'Si prega di specificare un indirizzo email valido.';de = 'Geben Sie eine zul??ssige E-Mail-Adresse an.'"));
			Return False;
		EndIf;
		If Not TaskSchedulerSupported() Then
			ShowMessageBox(, NStr("ru = '?????????????????????? ?????????????? ???????????????????????????? ???????????? ?????????????? ?? ???????????????????????? ?????????????? ???????????? 6.0 Vista.'; en = 'Job scheduler is supported only since Windows Vista 6.0.'; pl = 'Program planowania zada?? jest obs??ugiwany tylko zaczynaj??c od systemu operacyjnego wersji 6.0 Vista.';es_ES = 'El planificador de las tareas se admite solo empezando con el sistema operativo de la versi??n 6.0 Vista.';es_CO = 'El planificador de las tareas se admite solo empezando con el sistema operativo de la versi??n 6.0 Vista.';tr = 'G??rev planlay??c??s?? i??letim sistemin yaln??zca 6.0 Vista s??r??m??nden itibaren desteklenir.';it = 'Il programmatore di compiti ?? supportato solo da Windows Vista 6.0 in poi.';de = 'Der Job Scheduler wird erst ab der Betriebssystem-Version 6.0 von Vista unterst??tzt.'"));
			Return False;
		EndIf;
	EndIf;
	
	Return True;
	
EndFunction

Procedure RunUpdateScript(Parameters, AdministrationParameters)
	
	MainScriptFileName = GenerateUpdateScriptFiles(True, Parameters, AdministrationParameters);
	EventLogClient.AddMessageForEventLog(EventLogEvent(), "Information",
		NStr("ru = '?????????????????????? ?????????????????? ???????????????????? ????????????????????????:'; en = 'Running configuration update procedure:'; pl = 'Trwa aktualizacja konfiguracji:';es_ES = 'Actualizando la configuraci??n:';es_CO = 'Actualizando la configuraci??n:';tr = 'G??ncelleme yap??land??rmas??:';it = 'Esecuzione procedura di aggiornamento configurazione:';de = 'Konfiguration aktualisieren:'") + " " + MainScriptFileName);
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
		MessageText = NStr("ru = '???????????????????? ???????????????????????? ?????????? ???????? ?????????????????????????? ???????????? ???? ?????????????? ???????? ?? ??????????.'; en = 'A configuration update can be scheduled only for a future date and time.'; pl = 'Aktualizacja konfiguracji mo??e by?? zaplanowana tylko na przysz???? dat?? i czas.';es_ES = 'Actualizaci??n de configuraciones puede programarse solo para una fecha y una hora en el futuro.';es_CO = 'Actualizaci??n de configuraciones puede programarse solo para una fecha y una hora en el futuro.';tr = 'Yap??land??rma g??ncellemesi sadece ileri bir tarih ve saat i??in planlanabilir.';it = 'L''aggiornamento della configurazione pu?? essere pianificato solo per la data e l''ora future.';de = 'Das Konfigurationsupdate kann nur f??r ein zuk??nftiges Datum und eine geplante Uhrzeit geplant werden.'");
	ElsIf Parameters.UpdateDateTime > AddMonth(CurrentDate, 1) Then
		MessageText = NStr("ru = '???????????????????? ???????????????????????? ?????????? ???????? ?????????????????????????? ???? ??????????????, ?????? ?????????? ?????????? ???????????????????????? ?????????????? ????????.'; en = 'A configuration update cannot be scheduled to a date later than one month from the current date.'; pl = 'Aktualizacja konfiguracji mo??e by?? zaplanowana nie p????niej ni?? po miesi??cu od bie????cej daty.';es_ES = 'Actualizaci??n de configuraciones puede programarse no m??s tarde que en un mes a partir de la fecha actual.';es_CO = 'Actualizaci??n de configuraciones puede programarse no m??s tarde que en un mes a partir de la fecha actual.';tr = 'Yap??land??rma g??ncellemesi, ge??erli tarihten itibaren bir ay i??inde ge??meyecek ??ekilde programlanabilir.';it = 'Un aggiornamento configurazione non pu?? essere pianificato a una data successiva a un mese dalla data corrente.';de = 'Die Aktualisierung der Konfiguration kann nicht sp??ter als in einem Monat ab dem aktuellen Datum geplant werden.'");
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
		
		TaskDetails = NStr("ru = '???????????????????? ???????????????????????? 1??:??????????????????????'; en = 'Update 1C:Enterprise configuration'; pl = 'Aktualizacja konfiguracji 1C:Enterprise';es_ES = 'Actualizar la configuraci??n de 1C:Enterprise';es_CO = 'Actualizar la configuraci??n de 1C:Enterprise';tr = '1C:Enterprise yap??land??rma g??ncellemesi';it = 'Aggiornamento configurazione 1C:Enterprise';de = 'Konfigurationsupdate 1C:Enterprise'");
		
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
	
	Return StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = '???????????????????? ???????????????????????? (%1)'; en = 'Update configuration (%1)'; pl = 'Aktualizacja konfiguracji (%1)';es_ES = 'Actualizar la configuraci??n (%1)';es_CO = 'Actualizar la configuraci??n (%1)';tr = 'Yap??land??rmay?? g??ncelle (%1)';it = 'Aggiornamento configurazione (%1)';de = 'Konfigurationsupdate (%1)'"), Format(TaskCode, "NG=0"));
	
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
	Return NStr("ru = '???????????????????? ????????????????????????'; en = 'Configuration update'; pl = 'Aktualizacja konfiguracji';es_ES = 'Actualizaci??n de la configuraci??n';es_CO = 'Actualizaci??n de la configuraci??n';tr = 'Yap??land??rma g??ncellemesi';it = 'Aggiornamento della configurazione';de = 'Konfigurations-Update'", CommonClientServer.DefaultLanguageCode());
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
		ShowUserNotification(NStr("ru = '???????????????????? ????????????????????????'; en = 'Configuration update'; pl = 'Aktualizacja konfiguracji';es_ES = 'Actualizaci??n de la configuraci??n';es_CO = 'Actualizaci??n de la configuraci??n';tr = 'Yap??land??rma g??ncellemesi';it = 'Aggiornamento della configurazione';de = 'Konfigurations-Update'"),
			"e1cib/app/DataProcessor.InstallUpdates",
			NStr("ru = '???????????????????????? ???????????????????? ???? ???????????????? ???????????????????????? ???????????????????????????? ????????.'; en = 'The configuration is different from the main infobase configuration.'; pl = 'Konfiguracja r????ni si?? od g????wnej konfiguracji bazy informacyjnej.';es_ES = 'La configuraci??n es diferente de la configuraci??n b??sica de la infobase.';es_CO = 'La configuraci??n es diferente de la configuraci??n b??sica de la infobase.';tr = 'Yap??land??rma, veritaban??n temel yap??land??rmas??ndan farkl??d??r.';it = 'La configurazione ?? diversa dalla configurazione di base di informazioni.';de = 'Die Konfiguration unterscheidet sich von der Grundkonfiguration der Infobase.'"), 
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
			
			If Comment = NStr("ru = '???????????????????? ??????????????????'; en = 'Update completed'; pl = 'Aktualizacja zosta??a zako??czona';es_ES = 'Actualizaci??n se ha realizado';es_CO = 'Actualizaci??n se ha realizado';tr = 'G??ncelleme yap??ld??';it = 'Aggiornamento completato';de = 'Update abgeschlossen'") Then
				UpdateResult = True;
				Continue;
			ElsIf Comment = NStr("ru = '???????????????????? ???? ??????????????????'; en = 'Update failed'; pl = 'Aktualizacja nie jest wykonana';es_ES = 'Actualizaci??n no se ha realizado';es_CO = 'Actualizaci??n no se ha realizado';tr = 'G??ncelleme yap??lmad??';it = 'Aggiornamento fallito';de = 'Update nicht abgeschlossen'") Then
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