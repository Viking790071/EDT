
#Region Private

// Receive page address on the configuration vendor web
// server where information about available updates is located.
//
// Returns:
//   String   - web page address.
//
Function AddressOfResourcesForVerificationOfUpdateAvailability(CheckUpdateToNewEdition = False) Export
	
	UpdateSettings = ConfigurationUpdateClientCachedDrive.ClientWorkParameters().UpdateSettings;
	ConfigurationShortName = UpdateSettings.ConfigurationShortName;
	ConfigurationShortName = StrReplace(ConfigurationShortName, "\", "/");
	If CheckUpdateToNewEdition Then
		ConfigurationShortName = StrReplace(ConfigurationShortName, PlatformCurrentEdition(), PlatformNextEdition());
	EndIf;
	Result = ConfigurationUpdateClientServer.AddFinalPathSeparator(UpdateSettings.AddressOfResourceForVerificationOfUpdateAvailability)
		+ ConfigurationShortName;
	Return Result;
	
EndFunction

// Receive update files directory address on the updates service.
//
// Returns:
//   String   - catalog address on web server.
//
Function TemplatesDirectoryAddressAtUpdatesServer() Export
	
	UpdateServer = ConfigurationUpdateClientCachedDrive.ClientWorkParameters().UpdateSettings.UpdatesDirectory;
	
	If Find(UpdateServer, "ftp://") <> 0 Then
		Protocol = "ftp://";
	ElsIf Find(UpdateServer, "ftps://") <> 0 Then
		Protocol = "ftps://";
	ElsIf Find(UpdateServer, "https://") <> 0 Then
		Protocol = "https://";
	Else
		Protocol = "http://";
	EndIf;
	
	UpdateServer = StrReplace(UpdateServer, Protocol, "");
	TemplatesDirectoryAtServer = "";
	Position = Find(UpdateServer, "/");
	If Position > 0 Then
		TemplatesDirectoryAtServer = Mid(UpdateServer, Position, StrLen(UpdateServer));
	EndIf;
	Return TemplatesDirectoryAtServer;
	
EndFunction

// Receive service address of update receipt legality check.
//
// Returns:
//   String   - service address.
//
Function LegalityCheckServiceAddress() Export
	
	Return ConfigurationUpdateClientCachedDrive.ClientWorkParameters().UpdateSettings.LegalityCheckServiceAddress;
	
EndFunction

// Receive updates server address.
//
// Returns:
//   String   - web server address.
//
Function AddressOfUpdatesServer() Export
	
	UpdateServer = ConfigurationUpdateClientCachedDrive.ClientWorkParameters().UpdateSettings.UpdatesDirectory;
	
	If Find(UpdateServer, "ftp://") <> 0 Then
		Protocol = "ftp://";
	ElsIf Find(UpdateServer, "ftps://") <> 0 Then
		Protocol = "ftps://";
	ElsIf Find(UpdateServer, "https://") <> 0 Then
		Protocol = "https://";
	Else
		Protocol = "http://";
	EndIf;
	
	UpdateServer = StrReplace(UpdateServer, Protocol, "");
	Position = Find(UpdateServer, "/");
	If Position > 0 Then
		UpdateServer = Mid(UpdateServer, 1, Position - 1);
	EndIf;
	
	Return Protocol + UpdateServer;
	
EndFunction

// Receive attachment file name with information about available update on
// configuration vendor website.
//
// Returns:
//   String   - attachment file name.
//
Function FileNameOfUpdateAvailabilityCheck() Export
	
	Return "UpdInfo.txt";
	
EndFunction

// Function enables and disables check for update by the schedule.
// 
// Parameters:
// CheckBoxEnableOrDisable: Boolean if TRUE - check is enabled, otherwise, disabled.
Function EnableDisableCheckOnSchedule(EnableDisableFlag = True) Export
	If EnableDisableFlag Then
		AttachIdleHandler("ProcessUpdateCheckOnSchedule", 60 * 5); // every 5 minutes
	Else
		DetachIdleHandler("ProcessUpdateCheckOnSchedule");
	EndIf;
EndFunction

// Procedure that checks whether there is an update for configuration via the Internet.
//
// Parameters: 
//	OutputMessages: Boolean, shows that errors messages are output to a user.
Procedure CheckUpdateExistsViaInternet(OutputMessages = False, UpdateAvailableForNewEdition = False) Export
	
	Status(NStr("en = 'Check for updates online'; ru = 'Проверка наличия обновления в Интернете';pl = 'Sprawdzenie aktualizacji w Internecie';es_ES = 'Revisar las actualizaciones online';es_CO = 'Revisar las actualizaciones online';tr = 'Çevrimiçi güncellemeleri kontrol et';it = 'Controlla aggiornamenti on-line';de = 'Suchen Sie online nach Updates'"));
	Parameters = GetAvailableConfigurationUpdate(); 
	If Parameters.UpdateSource <> -1 Then
		TimeOfObtainingUpdate = Parameters.TimeOfObtainingUpdate;
		If TimeOfObtainingUpdate <> Undefined AND CommonClient.SessionDate() - TimeOfObtainingUpdate < 30 Then
			Return;
		EndIf;
	EndIf;
	
	Parameters.FileParametersUpdateChecks = GetFileOfUpdateAvailabilityCheck(OutputMessages);
	If TypeOf(Parameters.FileParametersUpdateChecks) = Type("String") Then
		EventLogClient.AddMessageForEventLog(ConfigurationUpdateClient.EventLogEvent(), "Warning",
			NStr("en = 'Cannot connect to the Internet to check for updates.'; ru = 'Невозможно подключиться к сети Интернет для проверки обновлений.';pl = 'Nie można podłączyć się do Internetu dla sprawdzenia aktualizacji.';es_ES = 'No se puede conectar a Internet para revisar las actualizaciones.';es_CO = 'No se puede conectar a Internet para revisar las actualizaciones.';tr = 'Güncellemeleri kontrol etmek için internete bağlanılamıyor.';it = 'Non è impossibile collegarsi a Internet per controllare gli aggiornamenti';de = 'Es kann keine Verbindung zum Internet hergestellt werden, um nach Updates zu suchen.'"));
		Parameters.PageName = "InternetConnection";
		Return;
	EndIf;
	
	Parameters.LastConfigurationVersion = Parameters.FileParametersUpdateChecks.Version;
	ConfigurationVersion = ConfigurationUpdateClientCachedDrive.ClientWorkParameters().ConfigurationVersion;
	If CommonClientServer.CompareVersions(ConfigurationVersion, Parameters.LastConfigurationVersion) >= 0 Then
		
		UpdatesNotDetected = True;
		
		If CheckUpdateForNextPlatformVersion() Then
			
			Parameters.FileParametersUpdateChecks = GetFileOfUpdateAvailabilityCheck(False, True);
			
			If TypeOf(Parameters.FileParametersUpdateChecks) <> Type("String") Then
				
				Parameters.LastConfigurationVersion = Parameters.FileParametersUpdateChecks.Version;
				ConfigurationVersion = ConfigurationUpdateClientCachedDrive.ClientWorkParameters().ConfigurationVersion;
				
				If CommonClientServer.CompareVersions(ConfigurationVersion, Parameters.LastConfigurationVersion) < 0 Then
					UpdatesNotDetected = False;
					UpdateAvailableForNewEdition = True;
				EndIf;
				
			EndIf;
			
		EndIf;
		
		If UpdatesNotDetected Then
			
			EventLogClient.AddMessageForEventLog(ConfigurationUpdateClient.EventLogEvent(), "Information",
				NStr("en = 'Update is not required: the newest configuration version is already installed.'; ru = 'Обновление не требуется: последняя версия конфигурации уже установлена.';pl = 'Aktualizacja nie jest konieczna: ostatnia wersja konfiguracji jest już zainstalowana.';es_ES = 'No se requiere la actualización: la versión más nueva de la configuración ya se ha instalado.';es_CO = 'No se requiere la actualización: la versión más nueva de la configuración ya se ha instalado.';tr = 'Güncelleme gerekmiyor: En yeni yapılandırma sürümü zaten yüklü.';it = 'Aggiornamento non è necessario: la versione più recente di configurazione è già installata.';de = 'Update ist nicht erforderlich: Die neueste Konfigurationsversion ist bereits installiert.'"));
			
			Parameters.PageName = "UpdatesNotDetected";
			Return;
			
		EndIf;
	EndIf;
	
	MessageText = NStr("en = 'Newer configuration version is found on the Internet: %1.'; ru = 'Обнаружена более новая версия конфигурации в Интернете: %1.';pl = 'W Internecie znaleziono nowszą wersję konfiguracji:%1.';es_ES = 'Versión más reciente de la configuración se ha encontrado en Internet: %1.';es_CO = 'Versión más reciente de la configuración se ha encontrado en Internet: %1.';tr = 'İnternette daha yeni bir yapılandırma sürümü bulunuyor: %1.';it = 'Una versione più recente della configurazione si trova su Internet: %1.';de = 'Neuere Konfigurationsversion im Internet gefunden: %1.'");
	MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageText, Parameters.LastConfigurationVersion);
	EventLogClient.AddMessageForEventLog(ConfigurationUpdateClient.EventLogEvent(), "Information", MessageText);
	
	Parameters.UpdateSource = 0;
	Parameters.PageName = "AvailableUpdate";
	Parameters.TimeOfObtainingUpdate = CommonClient.SessionDate();
	
EndProcedure

// Procedure checks whether it is possible and checks whether there is
// configuration update via the Internet if needed.
Procedure CheckUpdateOnSchedule() Export
	
	ParameterName = "StandardSubsystems.ConfigurationUpdateOptions";
	If ApplicationParameters[ParameterName] = Undefined Then
		ApplicationParameters.Insert(ParameterName, Undefined);
	EndIf;
	ApplicationParameters[ParameterName] = ConfigurationUpdateClientCachedDrive.ClientWorkParameters().UpdateSettings.ConfigurationUpdateOptions;
	ConfigurationUpdateOptions = ApplicationParameters[ParameterName];
	
	ConfigurationUpdateClientServer.GetUpdatedConfigurationUpdateSettings(ApplicationParameters[ParameterName]);
	ScheduleOfUpdateExistsCheck = ConfigurationUpdateOptions.ScheduleOfUpdateExistsCheck;
	If ConfigurationUpdateOptions.CheckUpdateExistsOnStart <> 1 
		OR ScheduleOfUpdateExistsCheck = Undefined Then
		Return;	
	EndIf;	
			
	Schedule = CommonClientServer.StructureToSchedule(ScheduleOfUpdateExistsCheck);
	CheckDate = CommonClient.SessionDate();
	If Not Schedule.ExecutionRequired(CheckDate, ConfigurationUpdateOptions.TimeOfLastUpdateCheck) Then
		Return;	
	EndIf;	
		
	ConfigurationUpdateOptions.TimeOfLastUpdateCheck = CheckDate;
	EventLogClient.AddMessageForEventLog(ConfigurationUpdateClient.EventLogEvent(),, 
		NStr("en = 'Check for updates on the Internet on schedule.'; ru = 'Проверка наличия обновления в сети Интернет по расписанию.';pl = 'Sprawdzaj aktualizacje w Internecie zgodnie z harmonogramem.';es_ES = 'Revisar las actualizaciones en Internet del horario.';es_CO = 'Revisar las actualizaciones en Internet del horario.';tr = 'İnternet üzerinden program güncellemelerini kontrol edin.';it = 'Controllare gli aggiornamenti su Internet nei tempi previsti.';de = 'Im Internet nach Updates suchen.'"));
		
	AvailableUpdatePageDescription = "AvailableUpdate";
	CheckUpdateExistsViaInternet();
	Parameters = GetAvailableConfigurationUpdate();
	If Parameters.UpdateSource <> -1 AND Parameters.PageName = AvailableUpdatePageDescription Then
			
		EventLogClient.AddMessageForEventLog(ConfigurationUpdateClient.EventLogEvent(),,
			NStr("en = 'New configuration version is detected:'; ru = 'Обнаружена новая версия конфигурации:';pl = 'Jest ujawniona nowa wersja konfiguracji:';es_ES = 'Versión más reciente de la configuración se ha detectado:';es_CO = 'Versión más reciente de la configuración se ha detectado:';tr = 'Yeni yapılandırma sürümü algılandı:';it = 'viene rilevata Nuova versione di configurazione:';de = 'Neue Konfigurationsversion wurde erkannt:'") + " " + Parameters.FileParametersUpdateChecks.Version);
				
		ConfigurationUpdateOptions.UpdateSource = 0;
		ConfigurationUpdateOptions.ScheduleOfUpdateExistsCheck = ScheduleOfUpdateExistsCheck;
		ConfigurationUpdateServerCallDrive.WriteStructureOfAssistantSettings(ConfigurationUpdateOptions, ApplicationParameters["StandardSubsystems.MessagesForEventLogMonitor"]);
		
		Parameters.UpdateSource = ConfigurationUpdateOptions.UpdateSource;
		Parameters.NeedUpdateFile = ConfigurationUpdateOptions.NeedUpdateFile;
		Parameters.FlagOfAutoTransitionToPageWithUpdate = True;
		ShowUserNotification(NStr("en = 'Configuration update is available'; ru = 'Доступно обновление конфигурации';pl = 'Aktualizacja konfiguracji jest dostępna';es_ES = 'Actualización de la configuración está disponible';es_CO = 'Actualización de la configuración está disponible';tr = 'Yapılandırma güncellemesi mevcut';it = 'L''aggiornamento della configurazione è disponibile';de = 'Konfigurationsaktualisierung ist verfügbar'"),
			"e1cib/app/DataProcessor.InstallUpdates",
			NStr("en = 'Version:'; ru = 'Версия:';pl = 'Wersja:';es_ES = 'Versión:';es_CO = 'Versión:';tr = 'Sürüm:';it = 'Versione:';de = 'Version:'") + " " + Parameters.FileParametersUpdateChecks.Version, 
			PictureLib.Information32);
	Else
		EventLogClient.AddMessageForEventLog(ConfigurationUpdateClient.EventLogEvent(),, 
			NStr("en = 'No available updates were found.'; ru = 'Доступных обновлений не обнаружено.';pl = 'Nie znaleziono dostępnych aktualizacji.';es_ES = 'No se han encontrado las actualizaciones disponibles.';es_CO = 'No se han encontrado las actualizaciones disponibles.';tr = 'Kullanılabilir güncelleme bulunamadı.';it = 'Nessun aggiornamenti disponibili sono stati trovati.';de = 'Keine verfügbaren Updates wurden gefunden.'"));
	EndIf;
	ConfigurationUpdateServerCallDrive.WriteStructureOfAssistantSettings(ConfigurationUpdateOptions, ApplicationParameters["StandardSubsystems.MessagesForEventLogMonitor"]);
	
EndProcedure

// Return update general parameters.
//
Function GetUpdateParameters(CheckUpdateToNewEdition = False) Export
	#If Not WebClient Then
		
	ParametersStructure = New Structure();
	ParametersStructure.Insert("UpdateDateTimeIsSet"	, False);
	
	// Internet
	ParametersStructure.Insert("ZIPFileNameOfListOfTemplates" , "v8upd11.zip");
	ParametersStructure.Insert("ListTemplatesFileName"        , "v8cscdsc.xml");
	ParametersStructure.Insert("UpdateDescriptionFileName"    , "ReleaseNotes.html");
	ParametersStructure.Insert("UpdateOrderFileName"          , "ReleaseNotes.html");

	// Service files names
	ParametersStructure.Insert("NameOfExecutableDesignerFile" , StandardSubsystemsClient.ApplicationExecutableFileName(True));
	ParametersStructure.Insert("NameOfExecutableFileOfClient" , StandardSubsystemsClient.ApplicationExecutableFileName());
	ParametersStructure.Insert("EventLogEvent"         		  , ConfigurationUpdateClient.EventLogEvent());
	
	// Determine temporary files directory.
	ParametersStructure.Insert("UpdateFilesDir"			, DirectoryLocalAppData() + "1C\1Cv8Update\"); 
	UpdateTempFilesDir = TempFilesDir() + "1Cv8Update." + Format(CommonClient.SessionDate(), "DF=yyMMddHHmmss") + "\";
	ParametersStructure.Insert("UpdateTempFilesDir"	, UpdateTempFilesDir);
	
	ParametersStructure.Insert("AddressOfResourcesForVerificationOfUpdateAvailability"			, AddressOfResourcesForVerificationOfUpdateAvailability(CheckUpdateToNewEdition));
	ParametersStructure.Insert("InfoAboutObtainingAccessToUserSitePageAddress"					, InfoAboutObtainingAccessToUserSitePageAddress());
	ParametersStructure.Insert("TemplatesDirectoryAddressAtUpdatesServer"						, TemplatesDirectoryAddressAtUpdatesServer());
	ParametersStructure.Insert("AddressOfUpdatesServer"											, AddressOfUpdatesServer());
	ParametersStructure.Insert("LegalityCheckServiceAddress"									, LegalityCheckServiceAddress());
	ParametersStructure.Insert("FileNameOfUpdateAvailabilityCheck"								, FileNameOfUpdateAvailabilityCheck());
	
	Return ParametersStructure;
	#EndIf
EndFunction

// Get web page address with information on how to get the access to custom section on the website of configuration vendor.
//
// Returns:
//   String   - web page address.
Function InfoAboutObtainingAccessToUserSitePageAddress() Export
	
	PageAddress = ConfigurationUpdateClientOverridable.InfoAboutObtainingAccessToUserSitePageAddress();
	If Not ValueIsFilled(PageAddress) Then
		PageAddress = "http://v8.1c.ru/"; // Value by default
	EndIf;
	
	ConfigurationUpdateClientOverridable.WhenDeterminingPageAddressForAccessToUpdateWebsite(PageAddress);
	
	Return PageAddress;
	
EndFunction

// Function returns path to the temporary files directory to execute an update.
Function DirectoryLocalAppData()
	App			= New COMObject("Shell.Application");
	Folder		= App.Namespace(28);
	Result	= Folder.Self.Path;
	Return ConfigurationUpdateClientServer.AddFinalPathSeparator(Result);
EndFunction

Function PlatformCurrentEdition()
	
	SystemInfo = New SystemInfo;
	CurrentVersionArray = StringFunctionsClientServer.SplitStringIntoSubstringsArray(SystemInfo.AppVersion, ".");
	CurrentEdition = CurrentVersionArray[0] + CurrentVersionArray[1];
	
	Return CurrentEdition;
	
EndFunction

Function PlatformNextEdition() Export
	
	SystemInfo = New SystemInfo;
	CurrentVersionArray = StringFunctionsClientServer.SplitStringIntoSubstringsArray(SystemInfo.AppVersion, ".");
	NextEdition = CurrentVersionArray[0] + String(Number(CurrentVersionArray[1]) +1);
	
	Return NextEdition;
	
EndFunction

// Returns parameters of the found (available) configuration update.
Function GetAvailableConfigurationUpdate() Export
	ParameterName = "StandardSubsystems.AvailableConfigurationUpdate";
	If ApplicationParameters[ParameterName] = Undefined Then
		ApplicationParameters.Insert(ParameterName, New Structure);
		ApplicationParameters[ParameterName].Insert("UpdateSource", -1);
		ApplicationParameters[ParameterName].Insert("NeedUpdateFile", False);
		ApplicationParameters[ParameterName].Insert("FlagOfAutoTransitionToPageWithUpdate", False);
		ApplicationParameters[ParameterName].Insert("FileParametersUpdateChecks", Undefined);
		ApplicationParameters[ParameterName].Insert("PageName", "");
		ApplicationParameters[ParameterName].Insert("TimeOfObtainingUpdate", CommonClient.SessionDate());
		ApplicationParameters[ParameterName].Insert("LastConfigurationVersion", "");
	EndIf;
	
	Return ApplicationParameters[ParameterName];
EndFunction

// Exports check for updates file from the Internet.
//
// Parameters:
// OutputMessages - Boolean - Shows that it is necessary to output errors messages to user.
// CheckUpdateToNewEdition - Boolean - shows that it is necessary to
//                                                check updates for platform new edition.
//
Function GetFileOfUpdateAvailabilityCheck(Val OutputMessages = True, CheckUpdateToNewEdition = False) Export
	
	UpdateParameters = GetUpdateParameters(CheckUpdateToNewEdition);
	UpdateSettings = ConfigurationUpdateClientCachedDrive.ClientWorkParameters().UpdateSettings;
	
	TempFile = UpdateParameters.UpdateFilesDir + UpdateParameters.FileNameOfUpdateAvailabilityCheck;
	
	// Create directory for the temporary file if needed.
	DirectoryTemporaryFile = CommonClientServer.ParseFullFileName(TempFile).Path;
	TemporaryFileDirectoryObject = New File(DirectoryTemporaryFile);
	If Not TemporaryFileDirectoryObject.Exist() Then
		Try 
			CreateDirectory(DirectoryTemporaryFile);
		Except
			ErrorInfo = ErrorInfo();
			
			ErrorInfo = NStr("en = 'Unable to create the temporary directory to check for updates.
			                 |%1'; 
			                 |ru = 'Не удалось создать временный каталог для проверки наличия обновлений.
			                 |%1';
			                 |pl = 'Nie można utworzyć katalogu tymczasowego, aby sprawdzić dostępność aktualizacji.
			                 |%1';
			                 |es_ES = 'No se puede crear el directorio temporal para revisar las actualizaciones.
			                 |%1';
			                 |es_CO = 'No se puede crear el directorio temporal para revisar las actualizaciones.
			                 |%1';
			                 |tr = 'Güncellemeleri kontrol etmek için geçici dizin oluşturulamadı.
			                 |%1';
			                 |it = 'Impossibile creare la directory temporanea per controllare gli aggiornamenti."
"%1';
			                 |de = 'Das temporäre Verzeichnis konnte nicht erstellt werden, um nach Updates zu suchen.
			                 |%1'");
			EventLogClient.AddMessageForEventLog(ConfigurationUpdateClient.EventLogEvent(), "Error",
				StringFunctionsClientServer.SubstituteParametersToString(ErrorInfo, DetailErrorDescription(ErrorInfo)),, 
				True);
				
			ErrorInfo = StringFunctionsClientServer.SubstituteParametersToString(ErrorInfo, 
				BriefErrorDescription(ErrorInfo));
			If OutputMessages Then
				ShowMessageBox(, ErrorInfo);
			EndIf;
			Return ErrorInfo;
		EndTry;
	EndIf;
		
	// Receive the file from the Internet.
	DownloadURL = UpdateSettings.ServerAddressForVerificationOfUpdateAvailability
		+ UpdateParameters.AddressOfResourcesForVerificationOfUpdateAvailability
		+ UpdateParameters.FileNameOfUpdateAvailabilityCheck;
	Result = GetFilesFromInternetClient.DownloadFileAtClient(DownloadURL,
		New Structure("PathForSaving", ?(IsBlankString(TempFile), Undefined, TempFile)));
		
	If Result.Status <> True Then
		ErrorInfo = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Unable to check for updates.
			     |%1'; 
			     |ru = 'Не удалось проверить наличие обновлений.
			     |%1';
			     |pl = 'Nie można sprawdzić aktualizacji.
			     |%1';
			     |es_ES = 'No se puede revisar las actualizaciones.
			     |%1';
			     |es_CO = 'No se puede revisar las actualizaciones.
			     |%1';
			     |tr = 'Güncellemeler kontrol edilemiyor.
			     |%1';
			     |it = 'Impossibile verificare gli aggiornamenti. 
			     |%1';
			     |de = 'Es konnte nicht nach Updates gesucht werden.
			     |%1'"),
			Result.ErrorMessage);
		If OutputMessages Then
			ShowMessageBox(, ErrorInfo);
		EndIf;
		Return ErrorInfo;
	EndIf;
	
	Return InstallationPackageParameters(TempFile);
	
EndFunction

Function CheckUpdateForNextPlatformVersion()
	
	CheckUpdate = ConfigurationUpdateClientOverridable.CheckUpdateForNextPlatformVersion();
	If CheckUpdate = Undefined Then
		CheckUpdate = False;
	EndIf;
	
	ConfigurationUpdateClientOverridable.WhenCheckingUpdatesForNextPlatformVersion(CheckUpdate);
	
	Return CheckUpdate;
	
EndFunction

// Read data by update from the UpdatePresenceCheckFileName file (UpdInfo.txt).
// Calculated: 
// 	update version number on
// 	server, versions numbers from which update is executed
// 	(separated by the ";" character) update publication date.
// 
// Parameters:
//  FileName - UpdInfo file full name.txt.
// 
// Returns:
//  Structure: 
// 	Version - update version.
// 	FromVersions - from which versions updates.
// 	UpdateDate - publishing date.
//  String - error description if file is not found or does not contain required values.
//
Function InstallationPackageParameters(Val FileName) Export
	File = New File(FileName);
	If Not File.Exist() Then
		Return NStr("en = 'Update description file is not received'; ru = 'Файл описания обновлений не получен';pl = 'Plik opisu aktualizacji nie został odebrany';es_ES = 'Archivo de la descripción de la actualización no se ha recibido';es_CO = 'Archivo de la descripción de la actualización no se ha recibido';tr = 'Güncelleme açıklama dosyası alınamadı';it = 'Descrizione Aggiornamento file non viene ricevuto';de = 'Datei der Update-Beschreibungsdatei wurde nicht empfangen'");
	EndIf;	
	TextDocument = New TextDocument(); 
	TextDocument.Read(File.FullName);
	SetParameters = New Structure();
	For LineNumber = 1 To TextDocument.LineCount() Do
		TemporaryString = Lower(TrimAll(TextDocument.GetLine(LineNumber)));
		If IsBlankString(TemporaryString) Then
			Continue;
		EndIf; 
		If Find(TemporaryString,"fromversions=")>0 Then
			TemporaryString = TrimAll(Mid(TemporaryString,Find(TemporaryString,"fromversions=")+StrLen("fromversions=")));
			TemporaryString = ?(Left(TemporaryString,1)=";","",";") + TemporaryString + ?(Right(TemporaryString,1)=";","",";");
			SetParameters.Insert("FromVersions",TemporaryString);
		ElsIf Find(TemporaryString,"version=")>0 Then
			SetParameters.Insert("Version",Mid(TemporaryString,Find(TemporaryString,"version=")+StrLen("version=")));
		ElsIf Find(TemporaryString,"updatedate=")>0 Then
			// date format = Date, 
			TemporaryString = Mid(TemporaryString,Find(TemporaryString,"updatedate=")+StrLen("updatedate="));
			If StrLen(TemporaryString)>8 Then
				If Find(TemporaryString,".")=5 Then
					// date format YYYY.MM.DD
					TemporaryString = StrReplace(TemporaryString,".","");
				ElsIf Find(TemporaryString,".")=3 Then
					// date format DD.MM.YYYY
					TemporaryString = Right(TemporaryString,4)+Mid(TemporaryString,4,2)+Left(TemporaryString,2);
				Else 
					// date format YYYYMMDD
				EndIf;
			EndIf;
			SetParameters.Insert("UpdateDate",Date(TemporaryString));
		Else
			Return NStr("en = 'Incorrect update information format'; ru = 'Неверный формат сведений о наличии обновлений';pl = 'Nieprawidłowy format informacji o aktualizacji';es_ES = 'Formato de la información de la actualización incorrecto';es_CO = 'Formato de la información de la actualización incorrecto';tr = 'Yanlış güncelleme bilgisi formatı';it = 'Formato di informazioni di aggiornamento non valido';de = 'Falsches Aktualisierungsinformationsformat'");
		EndIf;
	EndDo;
	If SetParameters.Count() <> 3 Then 
		Return NStr("en = 'Incorrect update information format'; ru = 'Неверный формат сведений о наличии обновлений';pl = 'Nieprawidłowy format informacji o aktualizacji';es_ES = 'Formato de la información de la actualización incorrecto';es_CO = 'Formato de la información de la actualización incorrecto';tr = 'Yanlış güncelleme bilgisi formatı';it = 'Formato di informazioni di aggiornamento non valido';de = 'Falsches Aktualisierungsinformationsformat'");
	EndIf;
	Return SetParameters;
EndFunction

#Region ProceduresForUpdateReceiptLegalityCheck

#If Not WebClient Then

// Returns web server response structure.
//
Function CheckUpdateImportLegality(QueryParameters) Export
	
	CheckLegality = ConfigurationUpdateClientOverridable.UseUpdateExportLegalityCheck();
	If CheckLegality = Undefined Then
		CheckLegality = True;
	EndIf;
	
	ConfigurationUpdateClientOverridable.WhenCheckingUpdatesExportLegality(CheckLegality);
	
	If Not CheckLegality Then
		
		Return New Structure("ResultValue, ErrorText", True, "");
		
	EndIf;
	
	Try
	// Create service description
		ServiceDescription = LegalityCheckServiceDescription();
	Except
		ErrorText = NStr("en = 'An error occurred when creating description of web service for update legality check.'; ru = 'Ошибка создания описания веб-сервиса проверки легальности получения обновления.';pl = 'Wystąpił błąd podczas tworzenia opisu serwisu www do weryfikacji legalności pobierania aktualizacji.';es_ES = 'Ha ocurrido un error al crear la descripción del servicio web para la revisión de la legalidad de la actualización.';es_CO = 'Ha ocurrido un error al crear la descripción del servicio web para la revisión de la legalidad de la actualización.';tr = 'Güncelleme yasallığı kontrolü için web hizmeti açıklaması oluştururken bir hata oluştu.';it = 'Errore durante la creazione della descrizione del servizio Web per verificare la legalità dell''aggiornamento.';de = 'Beim Erstellen der Beschreibung des Web-Service für die Überprüfung der Rechtmäßigkeit des Updates ist ein Fehler aufgetreten.'");
		Return WebServerResponceStructure(ErrorText, True,,, DetailErrorDescription(ErrorInfo()));
	EndTry;
	
	// Determine whether web service is available.
	Try
		
		ServerResponse = ServiceAvailable(ServiceDescription);
		
		If Lower(TrimAll(ServerResponse)) <> "ready" Then
			
			ErrorText = NStr("en = 'Service of updates receipt legality check is temporarily unavailable.
			                 |Try again later'; 
			                 |ru = 'Сервис проверки легальности получения обновлений временно недоступен.
			                 |Повторите попытку позднее';
			                 |pl = 'Usługa weryfikacji legalności pobierania aktualizacji jest chwilowo niedostępna.
			                 |Spróbuj ponownie później';
			                 |es_ES = 'Servicio de la revisión de la legalidad del recibo de actualizaciones temporalmente no se encuentra disponible.
			                 |Intentar de nuevo más tarde';
			                 |es_CO = 'Servicio de la revisión de la legalidad del recibo de actualizaciones temporalmente no se encuentra disponible.
			                 |Intentar de nuevo más tarde';
			                 |tr = 'Güncelleme yasallık kontrolü hizmeti geçici olarak kullanılamıyor. 
			                 |Daha sonra tekrar deneyin';
			                 |it = 'Servizio di controllo della legalità aggiornamenti ricevuti è temporaneamente non disponibile.
			                 |Riprovare più tardi';
			                 |de = 'Der Service für die Überprüfung der Rechtmäßigkeit des Updates ist vorübergehend nicht verfügbar.
			                 |Versuchen Sie es später erneut'");
			Return WebServerResponceStructure(ErrorText, True, ServerResponse);
			
		EndIf;
		
	Except
		
		ErrorText = NStr("en = 'Unable to connect to the service of updates receipt legality check.
		                 |Check your Internet connection settings'; 
		                 |ru = 'Не удалось подключиться к сервису проверки легальности получения обновлений.
		                 |Проверьте параметры подключения к Интернету';
		                 |pl = 'Nie można połączyć się z serwisem weryfikacji legalności pobierania aktualizacji.
		                 |Sprawdź ustawienia połączenia internetowego';
		                 |es_ES = 'No se puede conectar al servicio de la revisión de la legalidad del recibo de actualizaciones.
		                 |Revisar sus configuraciones de conexión a Internet';
		                 |es_CO = 'No se puede conectar al servicio de la revisión de la legalidad del recibo de actualizaciones.
		                 |Revisar sus configuraciones de conexión a Internet';
		                 |tr = 'Güncelleme yasallık kontrolü hizmetine bağlanılamıyor. 
		                 |İnternet bağlantı ayarlarınızı kontrol edin';
		                 |it = 'Impossibile connettersi al servizio di controllo della legalità degli aggiornamenti ricevuti.
		                 |Controllare le impostazioni di connessione a Internet';
		                 |de = 'Es konnte keine Verbindung mit dem Service für die Überprüfung der Rechtmäßigkeit des Updates hergestellt werden.
		                 |Überprüfen Sie Ihre Internetverbindungseinstellungen'");
		Return WebServerResponceStructure(ErrorText, True,,, DetailErrorDescription(ErrorInfo()));
		
	EndTry;
	
	// Receive response from the web service.
	Return CheckUpdateReceiptLegality(QueryParameters, ServiceDescription);
	
EndFunction

#Region ProceduresAndFunctionsForWorkWithLegalityHighLevel
// check web service at a "high level".

// Adds parameters from structure to query.
//
// Parameters:
// LegalityCheckServiceDescription (Structure) - description of connection to the legality check web sevice.
// QueryParameters - String -  already generated parameters.
// ListOfParameters - XDTODataObject - parameters values list.
//
Procedure AddParametersToResponce(LegalityCheckServiceDescription, QueryParameters, ListOfParameters)
	
	TypeParameter = LegalityCheckServiceDescription.XDTOFactory.Type(LegalityCheckServiceDescription.OfURIService, "Parameter");
	CountParameters = 0;
	
	For Each PassingParameter In ListOfParameters Do 
		
		// Define object of the parameter (XDTO Object).
		Parameter = LegalityCheckServiceDescription.XDTOFactory.Create(TypeParameter);
		
		Parameter.name  = TrimAll(PassingParameter.Key);
		Parameter.value = TrimAll(PassingParameter.Value);
		Parameter.index = CountParameters;
		
		QueryParameters.parameter.Add(Parameter);
		
		CountParameters = CountParameters + 1;
		
	EndDo;
	
EndProcedure

// Checks if update export is legal.
//
// Parameters:
// AdditionalParameters - Structure - additional parameters for passing to the web service;
// LegalityCheckServiceDescription (Structure) - description of connection to the legality check web sevice.
//
// Returns:
// Structure - structured web server response.
//
Function CheckUpdateReceiptLegality(AdditionalParameters, LegalityCheckServiceDescription)
	
	Try
		
		AnswerType  = LegalityCheckServiceDescription.XDTOFactory.Type(LegalityCheckServiceDescription.OfURIService, "ProcessResponseType");
		TypeQuery = LegalityCheckServiceDescription.XDTOFactory.Type(LegalityCheckServiceDescription.OfURIService, "Parameters");
		
		QueryParameters = LegalityCheckServiceDescription.XDTOFactory.Create(TypeQuery);
		
		// If there are passed parameters, then add them.
		If AdditionalParameters <> Undefined Then
			AddParametersToResponce(LegalityCheckServiceDescription, QueryParameters, AdditionalParameters);
		EndIf;
		
		// Execution of the process method of the WEB-Service.
		ServerResponse = RefreshReceivedLegally(QueryParameters, LegalityCheckServiceDescription);
		
	Except
		
		ErrorText = NStr("en = 'An error occurred while checking update receipt legality.
		                 |Contact the administrator'; 
		                 |ru = 'Ошибка выполнения проверки легальности получения обновления.
		                 |Обратитесь к администратору';
		                 |pl = 'Wystąpił błąd podczas weryfikacji legalności pobierania aktualizacji.
		                 |Skontaktuj się z administratorem';
		                 |es_ES = 'Ha ocurrido un error al revisar la legalidad del recibo de la actualización.
		                 |Contactar el administrador';
		                 |es_CO = 'Ha ocurrido un error al revisar la legalidad del recibo de la actualización.
		                 |Contactar el administrador';
		                 |tr = 'Güncelleme yasallığı kontrol edilirken bir hata oluştu. 
		                 |Yönetici ile iletişime geçin';
		                 |it = 'Si è verificato un errore durante la verifica della legalità del aggiornamento ricevuto."
"Contattare l''amministratore';
		                 |de = 'Bei der Überprüfung der Rechtmäßigkeit des Updates des Empfangs ist ein Fehler aufgetreten.
		                 |Kontaktieren Sie den Administrator'");
		Return WebServerResponceStructure(ErrorText, True,,,DetailErrorDescription(ErrorInfo()));
		
	EndTry;
	
	CommandStructure = ServerResponse.command[0];
	
	If CommandStructure.name = "store.put" Then
		
		ResponseParameters = CommandStructure.parameters.parameter;
		
		Result = New Structure;
		For Each Parameter In ResponseParameters Do
			
			Result.Insert(Parameter.name, Parameter.value);
			
		EndDo;
		
		Result = WebServerResponceStructure(Result.resultTextError, False,
			Result.resultCodeError, Result.resultAvtorisation);
		
	Else
		
		Result = WebServerResponceStructure(NStr("en = 'Unexpected update service response'; ru = 'Неожиданный ответ сервиса проверки легальности получения обновлений';pl = 'Nieoczekiwana odpowiedź usługi na weryfikację legalności pobierania aktualizacji';es_ES = 'Respuesta de servicio de la actualización inesperada';es_CO = 'Respuesta de servicio de la actualización inesperada';tr = 'Beklenmeyen güncelleme hizmeti yanıtı';it = 'Risposta inaspettata dal servizio per verificare la legalità della ricezione degli aggiornamenti';de = 'Unerwartete Update-Service-Antwort'"), True);
		
	EndIf;
	
	Return Result;
	
EndFunction

// Returns server response as a structure.
//
Function WebServerResponceStructure(ErrorText, RecordToEventLogMonitor,
	ErrorCode = 0, ResultValue = False, MessageText = "")
	
	AnswerStructure = New Structure;
	
	AnswerStructure.Insert("ResultValue", Boolean(ResultValue));
	AnswerStructure.Insert("ErrorText", String(ErrorText));
	
	If RecordToEventLogMonitor Then
		
		If IsBlankString(MessageText) Then
			MessageText = NStr("en = '%ErrorText. Error code: %ErrorCode'; ru = '%ErrorText. Код ошибки: %ErrorCode.';pl = '%ErrorText. Kod błędu: %ErrorCode';es_ES = '%ErrorTexto. Código de error: %ErrorCódigo';es_CO = '%ErrorTexto. Código de error: %ErrorCódigo';tr = '%ErrorText. Hata kodu: %ErrorCode';it = '%ErrorText. Codice errore: %ErrorCode.';de = '%ErrorText. Fehlercode: %ErrorCode'");
			MessageText = StrReplace(MessageText, "%ErrorText", ErrorText);
			MessageText = StrReplace(MessageText, "%ErrorCode", ErrorCode);
		EndIf;
		
		EventLogClient.AddMessageForEventLog(ConfigurationUpdateClient.EventLogEvent(), "Error", MessageText);
		
	EndIf;
	
	Return AnswerStructure;
	
EndFunction

#EndRegion

// Returns web server response structure.
//
#Region ProceduresAndFunctionsForWorkWithLegalityLowLevel

// Generates web service description from WSDL-document
// for further work with legality check web service.
//
// Returns:
// Structure with properties:
// 	WSDLAddress (String) - WSDL-document URL;
// 		executed using temporary files;
// 	XDTOFactory (XDTOFactory) - Web-service XDTO factory;
// 	ServiceURI (String) - web service URI of legality check;
// 	PortConnection (HTTPConnection) - connection
// 		with the service port to execute web service method calls;
// 	PortPath (String) - port path on server;
//	
Function LegalityCheckServiceDescription()
	
	WSDLAddress = LegalityCheckServiceAddress();
	ConnectionParameters = CommonClientServer.URIStructure(WSDLAddress);
	
	Result = New Structure("WSDLAddress", WSDLAddress);
	
	InternetProxy = GetFilesFromInternetClientServer.GetProxy(ConnectionParameters.Schema);
	
	NetworkTimeout = 10;
	
	HTTP = New HTTPConnection(ConnectionParameters.Host,
		ConnectionParameters.Port,
		ConnectionParameters.Login,
		ConnectionParameters.Password,
		InternetProxy,
		NetworkTimeout,
		?(ConnectionParameters.Schema = "https",
			New OpenSSLSecureConnection(),
			Undefined));
	
	Try
		
		HTTPRequest = New HTTPRequest(ConnectionParameters.PathAtServer);
		Response = HTTP.Get(HTTPRequest);
		WSDLText = Response.GetBodyAsString();
		
	Except
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'An error occurred while creating the description of the web service.
		                                                                             |Unable to receive WSDL-description from server of update import legality check (%1): %2.'; 
		                                                                             |ru = 'Ошибка при создании описания веб-сервиса.
		                                                                             |Не удалось получить WSDL-описание с сервера проверки легальности скачивания обновления (%1): %2.';
		                                                                             |pl = 'Wystąpił błąd podczas tworzenia opisu usługi webowej.
		                                                                             |Nie można odebrać opisu WSDL z serwera weryfikacji legalności importu aktualizacji (%1): %2.';
		                                                                             |es_ES = 'Ha ocurrido un error al crear la descripción del servicio web.
		                                                                             |No se puede recibir la descripción-WSDL desde el servidor de la revisión de la legalidad de la importación de la actualización (%1): %2.';
		                                                                             |es_CO = 'Ha ocurrido un error al crear la descripción del servicio web.
		                                                                             |No se puede recibir la descripción-WSDL desde el servidor de la revisión de la legalidad de la importación de la actualización (%1): %2.';
		                                                                             |tr = 'Web hizmetinin açıklamasını oluştururken bir hata oluştu. 
		                                                                             |Güncellemeyi indirmenin yasallığını kontrol eden (%1) web servisi WSDL açıklamasını okurken hata oluştu:%2.';
		                                                                             |it = 'Si è verificato un errore durante la creazione della descrizione del servizio web. 
		                                                                             |Impossibile ricevere la descrizione WDSL dal server di aggiornamento del controllo di legalità di importazione (%1): %2.';
		                                                                             |de = 'Beim Erstellen der Beschreibung des Webservices ist ein Fehler aufgetreten.
		                                                                             |Kann die WSDL-Beschreibung vom Server der Update-Import-Legalitätsprüfung (%1) nicht empfangen: %2.'"),
			WSDLAddress, DetailErrorDescription(ErrorInfo()));
		Raise ErrorMessage;
	EndTry;
	
	XMLReader = New XMLReader;
	XMLReader.SetString(WSDLText);
	
	DOMBuilder = New DOMBuilder;
	Try
		DOMDocument = DOMBuilder.Read(XMLReader);
	Except
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'An error occurred while describing web service (%1).
		                                                                             |An error occurred while reading web service WSDL-description of update import legality check: %2.'; 
		                                                                             |ru = 'Ошибка при создании описания веб-сервиса (%1).
		                                                                             |Ошибка чтения WSDL-описания веб-сервиса проверки легальности скачивания обновления: %2.';
		                                                                             |pl = 'Wystąpił błąd podczas opisywania usługi webowej(%1).
		                                                                             |Wystąpił błąd podczas odczytu opisu WSDL usługi www weryfikacji legalności importu aktualizacji: %2.';
		                                                                             |es_ES = 'Ha ocurrido un error al describir el servicio web (%1).
		                                                                             |Ha ocurrido un error al leer la descripción-WSDL del servicio web de la revisión de la legalidad de la importación de la actualización: %2.';
		                                                                             |es_CO = 'Ha ocurrido un error al describir el servicio web (%1).
		                                                                             |Ha ocurrido un error al leer la descripción-WSDL del servicio web de la revisión de la legalidad de la importación de la actualización: %2.';
		                                                                             |tr = 'Web hizmetini (%1) açıklarken bir hata oluştu. 
		                                                                             |Güncellemeyi indirmenin yasallığı kontrol eden web servisi WSDL açıklamasını okurken bir hata oluştu:%2.';
		                                                                             |it = 'Si è verificato un errore durante la descrizione del servizio web (%1). 
		                                                                             |Si è verificato un errore durante la lettura della descrizione WDSL del servizio web di aggiornamento del controllo di legalità di importazione: %2.';
		                                                                             |de = 'Bei der Beschreibung von Webservice (%1) ist ein Fehler aufgetreten.
		                                                                             |Beim Lesen der Webservice -WSDL-Beschreibung der Update-Import-Legalitätsprüfung ist ein Fehler aufgetreten: %2.'"),
			WSDLAddress, DetailErrorDescription(ErrorInfo()));
		Raise ErrorMessage;
	EndTry;
	
	// Create XDTO factory of legality check web service.
	
	SchemeNodes = DOMDocument.GetElementByTagName("wsdl:types");
	If SchemeNodes.Count() = 0 Then
		
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'An error occurred while describing web service (%1).
		                                                                             |An error occurred while reading web service
		                                                                             |WSDL-description of update import legality check: There is no data types description item (<wsdl:types ...>).'; 
		                                                                             |ru = 'Ошибка при создании описания веб-сервиса (%1).
		                                                                             |Ошибка чтения WSDL-описания веб-сервиса проверки легальности скачивания обновления:
		                                                                             |Отсутствует элемент описания типов данных (<wsdl:types ...>).';
		                                                                             |pl = 'Wystąpił błąd podczas opisywania usługi webowej (%1).
		                                                                             |Wystąpił błąd podczas odczytu usługi
		                                                                             |opis WSDL serwisu www weryfikacji legalności importu aktualizacji: Brak pozycji opisu typów danych (<wsdl:types ...>).';
		                                                                             |es_ES = 'Ha ocurrido un error al describir el servicio web (%1).
		                                                                             |Ha ocurrido un error al leer la descripción-WSDL
		                                                                             |del servicio web de la revisión de la legalidad de la importación de la actualización: No hay un artículo de la descripción de los tipos de datos (<wsdl:types ...>).';
		                                                                             |es_CO = 'Ha ocurrido un error al describir el servicio web (%1).
		                                                                             |Ha ocurrido un error al leer la descripción-WSDL
		                                                                             |del servicio web de la revisión de la legalidad de la importación de la actualización: No hay un artículo de la descripción de los tipos de datos (<wsdl:types ...>).';
		                                                                             |tr = 'Web hizmeti (%1) açıklanırken bir hata oluştu.
		                                                                             |Web hizmeti okunurken bir hata oluştu. Güncellemeyi indirmenin yasallığı kontrol eden web servisi
		                                                                             |WSDL açıklamasını okurken bir hata oluştu: Veri türü açıklama öğesi yok (<wsdl:types ...>).';
		                                                                             |it = 'Si è verificato un errore durante la descrizione del web service (%1).
		                                                                             |Si è verificato un errore durante la lettura servizio web
		                                                                             |WSDL-descrizione dei controlli di legalità dell''importazione aggiornamento: Non esiste alcun tipo di dati descrizione (<wsdl: tipi ...>).';
		                                                                             |de = 'Bei der Beschreibung des Web Service (%1) ist ein Fehler aufgetreten.
		                                                                             |Beim Lesen der Webservice-
		                                                                             |WSDL-Beschreibung der Update-Import-Legalitätsprüfung ist ein Fehler aufgetreten: Es gibt keine Beschreibung für Datentypen (<wsdl: types ...>).'"), WSDLAddress);
		Raise ErrorMessage;
		
	EndIf;
	
	SchemeDescriptionNode = SchemeNodes[0].FirstSubsidiary;
	If SchemeDescriptionNode = Undefined Then
		
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'An error occurred while describing web service (%1).
		                                                                             |An error occurred while reading web service
		                                                                             |WSDL-description of update import legality check: There is no data types description item (<xs:schema ...>)'; 
		                                                                             |ru = 'Ошибка при создании описания веб-сервиса (%1).
		                                                                             |Ошибка чтения WSDL-описания веб-сервиса
		                                                                             |проверки легальности скачивания обновления: Отсутствует элемент описания типов данных (<xs:schema ...>)';
		                                                                             |pl = 'Wystąpił błąd podczas opisywania usługi webowej (%1).
		                                                                             |Wystąpił błąd podczas odczytu
		                                                                             |opisu WSDL usługi weryfikacji legalności importu aktualizacji: Brak pozycji opisu typów danych (<xs:schema ...>).';
		                                                                             |es_ES = 'Ha ocurrido un error al describir el servicio web (%1).
		                                                                             |Ha ocurrido un error al leer la descripción-WSDL
		                                                                             |del servicio web de la revisión de la legalidad de la importación de la actualización: No hay un artículo de la descripción de los tipos de datos (<xs:schema ...>).';
		                                                                             |es_CO = 'Ha ocurrido un error al describir el servicio web (%1).
		                                                                             |Ha ocurrido un error al leer la descripción-WSDL
		                                                                             |del servicio web de la revisión de la legalidad de la importación de la actualización: No hay un artículo de la descripción de los tipos de datos (<xs:schema ...>).';
		                                                                             |tr = 'Web hizmetini (%1) açıklarken bir hata oluştu. 
		                                                                             | Güncellemeyi indirmenin yasallığını kontrol eden web servisi 
		                                                                             |WSDL açıklamasını okurken bir hata oluştu: Veri türü açıklama öğesi yok (<xs:schema ...>)';
		                                                                             |it = 'Si è verificato un errore durante la descrizione del web service (%1).
		                                                                             |Si è verificato un errore durante la lettura servizio web
		                                                                             |WSDL-descrizione dei controlli di legalità dell''importazione aggiornamento: Non esiste alcun elemento di descrizione tipi dati (<xs: schema...>).';
		                                                                             |de = 'Bei der Beschreibung des Webservice (%1) ist ein Fehler aufgetreten.
		                                                                             |Beim Lesen des Webservice
		                                                                             |WSDL-Beschreibung der Update-Import-Legalitätsprüfung ist ein Fehler aufgetreten: Es gibt keine Datentypen Beschreibungsposition (<xs: schema ...>)'"), WSDLAddress);
		Raise ErrorMessage;
		
	EndIf;
	
	SchemeBuilder = New XMLSchemaBuilder;
	
	Try
		ServiceDataScheme = SchemeBuilder.CreateXMLSchema(SchemeDescriptionNode);
	Except
		
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'An error occurred while describing web service (%1).
		                                                                             |An error occurred while creating data schema from web service
		                                                                             |WSDL-description of update import legality check: %2'; 
		                                                                             |ru = 'Ошибка при создании описания веб-сервиса (%1).
		                                                                             |Ошибка при создании схемы данных из WSDL-описания
		                                                                             |веб-сервиса проверки легальности скачивания обновления: %2';
		                                                                             |pl = 'Wystąpił błąd podczas opisywania usługi webowej(%1).
		                                                                             |Wystąpił błąd podczas tworzenia schematu danych dla opisu
		                                                                             |WSDL usługi webowej weryfikacji legalności importu aktualizacji: %2';
		                                                                             |es_ES = 'Ha ocurrido un error al describir el servicio web (%1).
		                                                                             |Ha ocurrido un error al crear el esquema de datos de la descripción-WSDL
		                                                                             |del servicio web de la revisión de la legalidad de la importación de la actualización: %2';
		                                                                             |es_CO = 'Ha ocurrido un error al describir el servicio web (%1).
		                                                                             |Ha ocurrido un error al crear el esquema de datos de la descripción-WSDL
		                                                                             |del servicio web de la revisión de la legalidad de la importación de la actualización: %2';
		                                                                             |tr = 'Web hizmeti (%1) açıklanırken bir hata oluştu. 
		                                                                             |Güncellemeyi indirmenin yasallığını kontrol eden web servisi 
		                                                                             |WSDL açıklamasından veri şeması oluşturulurken bir hata oluştu:%2';
		                                                                             |it = 'Si è verificato un errore durante la descrizione del servizio web (%1).
		                                                                             |Si è verificato un errore durante la creazione dello schema dati dalla descrizione WSDL
		                                                                             | del servizio web di aggiornamento del controllo di legalità di importazione: %2';
		                                                                             |de = 'Bei der Beschreibung des Web-Service (%1) ist ein Fehler aufgetreten.
		                                                                             |Beim Erstellen des Datenschemas aus dem Web-Service
		                                                                             |WSDL-Beschreibung der Update-Import-Legalitätsprüfung ist ein Fehler aufgetreten: %2'"), WSDLAddress, DetailErrorDescription(ErrorInfo()));
		Raise ErrorMessage;
		
	EndTry;
	
	SchemaSet = New XMLSchemaSet;
	SchemaSet.Add(ServiceDataScheme);
	
	Try
		ServiceFactory = New XDTOFactory(SchemaSet);
	Except
		
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'An error occurred while describing web service (%1).
		                                                                             |An error occurred while creating XDTO factory from web service WSDL-description of update import legality check: %2'; 
		                                                                             |ru = 'Ошибка при создании описания веб-сервиса (%1).
		                                                                             |Ошибка при создании фабрики XDTO из WSDL-описания веб-сервиса проверки легальности скачивания обновления: %2';
		                                                                             |pl = 'Wystąpił błąd podczas opisywania usługi webowej(%1).
		                                                                             |Wystąpił błąd podczas tworzenia fabryki XDTO z usługi www opis WSDL sprawdzania legalności importu aktualizacji: %2';
		                                                                             |es_ES = 'Ha ocurrido un error al describir el servicio web (%1).
		                                                                             |Ha ocurrido un error al crear la fábrica XDTO de la descripción-WSDL del servicio web de la revisión de la legalidad de la importación de la actualización: %2';
		                                                                             |es_CO = 'Ha ocurrido un error al describir el servicio web (%1).
		                                                                             |Ha ocurrido un error al crear la fábrica XDTO de la descripción-WSDL del servicio web de la revisión de la legalidad de la importación de la actualización: %2';
		                                                                             |tr = 'Web hizmeti açıklaması oluşturulurken hata oluştu (%1). 
		                                                                             |Güncellemeyi indirmenin yasallığını kontrol eden web servisi WSDL açıklamasından XDTO fabrikasını oluştururken bir hata oluştu:%2';
		                                                                             |it = 'Si è verificato un errore durante la descrizione del web service (%1).
		                                                                             |Si è verificato un errore durante la creazione del fattore XDTO dal servizio Web WSDL-descrizione dei controlli di aggiornamento importazione legalità: %2';
		                                                                             |de = 'Bei der Beschreibung des Web-Service (%1) ist ein Fehler aufgetreten.
		                                                                             |Beim Erstellen der XDTO-Fabrik über die Webservice-WSDL-Beschreibung der Update-Import-Legalitätsprüfung ist ein Fehler aufgetreten: %2'"),
			WSDLAddress, DetailErrorDescription(ErrorInfo()));
		Raise ErrorMessage;
		
	EndTry;
	
	// Determine service port connection parameters.
	
	RootElement = DOMDocument.FirstSubsidiary;
	
	Result.Insert("XDTOFactory", ServiceFactory);
	
	OfURIService = DOMNodeAttributeValue(RootElement, "targetNamespace");
	If Not ValueIsFilled(OfURIService) Then
		
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'An error occurred while describing web service (%1).
		                                                                             |An error occurred while reading web service
		                                                                             |WSDL-description of update import legality check: There is no names space URI in WSDL-description.'; 
		                                                                             |ru = 'Ошибка при создании описания веб-сервиса (%1).
		                                                                             |Ошибка чтения WSDL-описания веб-сервиса
		                                                                             |проверки легальности скачивания обновления: Отсутствует URI пространства имен в WSDL-описании.';
		                                                                             |pl = 'Wystąpił błąd podczas opisywania usługi webowej (%1).
		                                                                             |Wystąpił błąd podczas odczytu
		                                                                             |opisu usługi webowej WSDL weryfikacji legalności importu aktualizacji: Brak identyfikatora URI przestrzeni nazw w opisie WSDL.';
		                                                                             |es_ES = 'Ha ocurrido un error al describir el servicio web (%1).
		                                                                             |Ha ocurrido un error al leer la descripción-WSDL
		                                                                             |del servicio web de la revisión de la legalidad de la importación de la actualización: No hay URI de espacio de los nombres en la descripción-WSDL.';
		                                                                             |es_CO = 'Ha ocurrido un error al describir el servicio web (%1).
		                                                                             |Ha ocurrido un error al leer la descripción-WSDL
		                                                                             |del servicio web de la revisión de la legalidad de la importación de la actualización: No hay URI de espacio de los nombres en la descripción-WSDL.';
		                                                                             |tr = 'Web hizmeti açıklaması oluşturulurken hata oluştu (%1). 
		                                                                             |Güncellemeyi indirmenin yasallığını kontrol eden web servisi 
		                                                                             |WSDL açıklamasını okurken hata oluştu: WSDL açıklamasında ad alanının URI''si yok.';
		                                                                             |it = 'Si è verificato un errore durante la descrizione del servizio web (%1). 
		                                                                             |Si è verificato un errore durante la lettura della descrizione WDSL
		                                                                             | del servizio web di aggiornamento del controllo di legalità di importazione: Non c''è spazio nomi URI nella descrizione WSDL.';
		                                                                             |de = 'Bei der Beschreibung des Web-Service ist ein Fehler aufgetreten (%1).
		                                                                             |Beim Lesen des Webservice
		                                                                             |WSDL-Beschreibung der Update-Import-Legalitätsprüfung ist ein Fehler aufgetreten: In der WSDL-Beschreibung ist kein Namespace-URI vorhanden.'"), WSDLAddress);
		Raise ErrorMessage;
		
	EndIf;
	
	Result.Insert("OfURIService" , OfURIService);
	
	// Determine address of web service port.
	ServicesNodes = RootElement.GetElementByTagName("wsdl:service");
	If ServicesNodes.Count() = 0 Then
		
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'An error occurred while describing web service (%1).
		                                                                             |An error occurred while reading web service
		                                                                             |WSDL-description of update import legality check: There is no web services description in WSDL-description (<wsdl:service ...>).'; 
		                                                                             |ru = 'Ошибка при создании описания веб-сервиса (%1).
		                                                                             |Ошибка чтения WSDL-описания веб-сервиса проверки легальности скачивания обновления:
		                                                                             |Отсутствует описание веб-сервисов в WSDL-описании (<wsdl:service ...>).';
		                                                                             |pl = 'Wystąpił błąd podczas opisywania usługi webowej (%1).
		                                                                             |Wystąpił błąd podczas odczytu
		                                                                             |opisu WSDL usługi webowej weryfikacji legalności importu aktualizacji: Brak opisu usługi webowej w opisie WSDL (<wsdl:service ...>).';
		                                                                             |es_ES = 'Ha ocurrido un erro al describir el servicio web (%1).
		                                                                             |Ha ocurrido un error al leer la descripción-WSDL
		                                                                             |del servicio web de la revisión de la legalidad de la importación de la actualización: No hay la descripción de los servicios web en la descripción-WSDL (<wsdl:service ...>).';
		                                                                             |es_CO = 'Ha ocurrido un erro al describir el servicio web (%1).
		                                                                             |Ha ocurrido un error al leer la descripción-WSDL
		                                                                             |del servicio web de la revisión de la legalidad de la importación de la actualización: No hay la descripción de los servicios web en la descripción-WSDL (<wsdl:service ...>).';
		                                                                             |tr = 'Web hizmeti açıklaması oluşturulurken hata oluştu (%1). 
		                                                                             |Güncellemeyi indirmenin yasallığını kontrol eden web servisi 
		                                                                             |WSDL açıklamasını okurken hata oluştu: WSDL açıklamasındaki web hizmetleri açıklaması yok (<wsdl:service ...>).';
		                                                                             |it = 'Si è verificato un errore durante la descrizione del servizio web (%1). 
		                                                                             |Si è verificato un errore durante la lettura della descrizione WDSL
		                                                                             | del servizio web di aggiornamento del controllo di legalità di importazione: Non descrizione del servizio web nella descrizione WSDL(<wsdl:service ...>).';
		                                                                             |de = 'Bei der Beschreibung des Webservice (%1) ist ein Fehler aufgetreten.
		                                                                             |Beim Lesen des Webservice
		                                                                             |WSDL-Beschreibung des Update-Import-Legalitäts-Checks ist ein Fehler aufgetreten: In der WSDL-Beschreibung (<wsdl: service ...>) gibt es keine Web-Services-Beschreibung.'"), WSDLAddress);
		Raise ErrorMessage;
		
	EndIf;
	
	ServiceNode = ServicesNodes[0];
	
	ServiceName = DOMNodeAttributeValue(ServiceNode, "name");
	
	PortsNodes = ServiceNode.GetElementByTagName("wsdl:port");
	
	If PortsNodes.Count() = 0 Then
		
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'An error occurred while describing web service (%1).
			     |An error occurred while reading web service
			     |WSDL-description of update import legality check: There is no ports description in WSDL-description (<wsdl:port ...>).'; 
			     |ru = 'Ошибка при создании описания веб-сервиса (%1).
			     |Ошибка чтения WSDL-описания веб-сервиса проверки легальности скачивания обновления:
			     |Отсутствует описание портов в WSDL-описании (<wsdl:port ...>).';
			     |pl = 'Wystąpił błąd podczas opisywania usługi webowej (%1).
			     |Wystąpił błąd podczas odczytu
			     |opisu WSDL usługi webowej weryfikacji legalności importu aktualizacji: W opisie WSDL brak opisu portów (<wsdl:port ...>).';
			     |es_ES = 'Ha ocurrido un error al describir el servicio web (%1).
			     |Ha ocurrido un error al leer la descripción-WSDL
			     |del servicio web de la revisión de la legalidad de la importación de la actualización: No hay la descripción de puertos en la descripción-WSDL (<wsdl:port ...>).';
			     |es_CO = 'Ha ocurrido un error al describir el servicio web (%1).
			     |Ha ocurrido un error al leer la descripción-WSDL
			     |del servicio web de la revisión de la legalidad de la importación de la actualización: No hay la descripción de puertos en la descripción-WSDL (<wsdl:port ...>).';
			     |tr = 'Web hizmeti açıklaması oluşturulurken hata oluştu (%1).
			     |Güncellemeyi indirmenin yasallığını kontrol eden web servisi 
			     |WSDL açıklamasını okurken hata oluştu: WSDL açıklamasında bağlantı noktası açıklaması yok (<wsdl:port ...>).';
			     |it = 'Si è verificato un errore durante la descrizione del servizio web (%1). 
			     |Si è verificato un errore durante la lettura della descrizione WDSL
			     | del servizio web di aggiornamento del controllo di legalità di importazione: Non descrizione delle porte nella descrizione WSDL(<wsdl:port ...>).';
			     |de = 'Bei der Beschreibung des Web Service (%1) ist ein Fehler aufgetreten.
			     |Beim Lesen des Webservice
			     |WSDL-Beschreibung der Update-Import-Legalitätsprüfung ist ein Fehler aufgetreten: Es gibt keine Beschreibung der Ports in WSDL-description (<wsdl: port ...>).'"), 
			WSDLAddress);
			
		Raise ErrorMessage;
		
	EndIf;
	
	PortNode	= PortsNodes[0];
	PortName	= DOMNodeAttributeValue(PortNode, "name");
	
	If Not ValueIsFilled(PortName) Then
		
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'An error occurred while creating web service description (%1).
			     |An error occurred while reading
			     |web service WSDL-description of online user support: Unable to determine service port name (%2).'; 
			     |ru = 'Ошибка при создании описания веб-сервиса (%1).
			     |Ошибка чтения WSDL-описания веб-сервиса интернет-поддержки пользователей:
			     |Не удалось определить имя порта сервиса (%2).';
			     |pl = 'Wystąpił błąd podczas tworzenia opisu usługi webowej (%1).
			     | Wystąpił błąd podczas odczytu
			     |opisu WSDL usługi webowej obsługi użytkowników online: Nie można ustalić nazwy portu serwisu (%2).';
			     |es_ES = 'Ha ocurrido un error al crear la descripción del servicio web (%1).
			     |Ha ocurrido un error al leer
			     |la descripción-WSDL del servicio web del soporte de usuario online: No se puede determinar el nombre del puerto del servicio (%2).';
			     |es_CO = 'Ha ocurrido un error al crear la descripción del servicio web (%1).
			     |Ha ocurrido un error al leer
			     |la descripción-WSDL del servicio web del soporte de usuario online: No se puede determinar el nombre del puerto del servicio (%2).';
			     |tr = 'Web hizmeti açıklaması oluşturulurken hata oluştu (%1). 
			     |Çevrim içi İnternet kullanıcılarının 
			     |web servisi WSDL açıklamasını okurken bir hata oluştu: Servis portu ismi tespit edilemedi (%2).';
			     |it = 'Un errore si è registrato durante la creazione della descrizione web service (%1).
			     |Un errore si è registrato durante la lettura del
			     |web service WSDL-desrizione del supporto online: Non è possibile determinare il nome della porta di servizio (%2).';
			     |de = 'Beim Erstellen der Webservice-Beschreibung ist ein Fehler aufgetreten (%1).
			     |Ein Fehler beim Lesen der
			     |Webservice WSDL-Beschreibung der Online-Benutzerunterstützung ist aufgetreten: Der Service-Port-Name (%2) konnte nicht ermittelt werden.'"), 
			WSDLAddress, 
			ServiceName);
		
		Raise ErrorMessage;
		
	EndIf;
	
	PortAddress = Undefined;
	AddressNodes = PortNode.GetElementByTagName("soap:address");
	If AddressNodes.Count() > 0 Then
		PortAddress = DOMNodeAttributeValue(AddressNodes[0], "location");
	EndIf;
	
	If Not ValueIsFilled(PortAddress) Then
		
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'An error occurred while describing web service (%1).
		                                                                             |An error occurred while reading
		                                                                             |web service WSDL-description of online user support: Unable to determine URL of the service specified port (%2).'; 
		                                                                             |ru = 'Ошибка при создании описания веб-сервиса (%1).
		                                                                             |Ошибка чтения WSDL-описания
		                                                                             |веб-сервиса интернет-поддержки пользователей: Не удалось определить URL заданного порта сервиса (%2).';
		                                                                             |pl = 'Wystąpił błąd podczas opisywania usługi webowej (%1).
		                                                                             |Wystąpił błąd podczas odczytywania
		                                                                             |opisu WSDL usługi webowej obsługi użytkowników online: Nie można określić adresu URL określonego portu serwisu(%2).';
		                                                                             |es_ES = 'Ha ocurrido un error al describir el servicio web (%1).
		                                                                             |Ha ocurrido un error al leer la descripción-WSDL del servicio web
		                                                                             | del soporte de usuario online: No se puede determinar URL del puerto especificado de servicio (%2).';
		                                                                             |es_CO = 'Ha ocurrido un error al describir el servicio web (%1).
		                                                                             |Ha ocurrido un error al leer la descripción-WSDL del servicio web
		                                                                             | del soporte de usuario online: No se puede determinar URL del puerto especificado de servicio (%2).';
		                                                                             |tr = 'Web hizmeti açıklaması oluşturulurken hata oluştu (%1). 
		                                                                             |Çevrimiçi kullanıcı destek hizmeti 
		                                                                             |WSDL açıklamasını okurken bir hata oluştu: Belirtilen hizmet portunun URL''si belirlenemedi (%2).';
		                                                                             |it = 'Si è verificato un errore durante la descrizione del servizio web (%1).
		                                                                             |Si è verificato un errore durante la lettura
		                                                                             |della descrizione WSDL del servizio web dell''assistenza clienti online: Impossibile determinare l''URL della porta specificata del servizio (%2).';
		                                                                             |de = 'Bei der Beschreibung des Webservice (%1) ist ein Fehler aufgetreten.
		                                                                             |Beim Lesen der Webservice
		                                                                             |WSDL-Beschreibung der Online-Benutzerunterstützung ist ein Fehler aufgetreten: Die URL des vom Service angegebenen Ports (%2) konnte nicht ermittelt werden.'"), WSDLAddress, PortName);
		
		Raise ErrorMessage;
		
	EndIf;
	
	PortConnection = New HTTPConnection(ConnectionParameters.Host,
		ConnectionParameters.Port,
		ConnectionParameters.Login,
		ConnectionParameters.Password,
		InternetProxy,
		NetworkTimeout,
		?(ConnectionParameters.Schema = "https",
			New OpenSSLSecureConnection(),
			Undefined));
	
	Result.Insert("PortConnection"       , PortConnection);
	Result.Insert("PortPath"             , ConnectionParameters.PathAtServer);
	
	Return Result;
	
EndFunction

// Proxy-function for calling the isReady() method of legality check web service
//
// Parameters:
// LegalityCheckServiceDescription (Structure) - for the check
// 	legality web service description, see LegalityCheckServiceDescription();
//
// Returns:
// String:
// 	value returned by the isReady() method of legality check web service;
//
Function ServiceAvailable(LegalityCheckServiceDescription)
	
	EnvelopeRecord = NewSOAPEnvelopeRecord();
	EnvelopeText  = TextInSOAPEnvelope(EnvelopeRecord);
	
	Try
		ResponseBody = SendSOAPQuery(EnvelopeText, LegalityCheckServiceDescription);
	Except
		
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'An error occurred when calling operation isReady of service (%1): %2'; ru = 'Ошибка при вызове операции isReady сервиса (%1): %2';pl = 'Wystąpił błąd podczas wywoływania operacji isReady serwisu (%1): %2';es_ES = 'Ha ocurrido un error al llamar la operación estáPreparado del servicio (%1): %2';es_CO = 'Ha ocurrido un error al llamar la operación estáPreparado del servicio (%1): %2';tr = 'Servisin isReady işlemi çağrılırken bir hata oluştu (%1): %2';it = 'Si è verificato un errore durante la chiamata al servizio isReady (%1): %2';de = 'Beim Aufrufen der Operation isReady (%1) ist ein Fehler aufgetreten: %2'"),
			LegalityCheckServiceDescription.WSDLAddress, DetailErrorDescription(ErrorInfo()));
		Raise ErrorMessage;
		
	EndTry;
	
	ObjectType = LegalitySeviceFactoryRootPropertyValueType("isReadyResponse", LegalityCheckServiceDescription);
	If ObjectType = Undefined Then
		ErrorMessage = StrReplace(NStr("en = 'An error occurred while calling the isReady operation of service (%1).
		                               |Unable to define the type of the isReadyResponse root property.'; 
		                               |ru = 'Ошибка при вызове операции isReady сервиса (%1).
		                               |Не удалось определить тип корневого свойства isReadyResponse.';
		                               |pl = 'Wystąpił błąd podczas wywoływania operacji isReady usługi (%1).
		                               |Nie można zdefiniować typu właściwości głównej isReadyResponse w czasie odpowiedzi.';
		                               |es_ES = 'Ha ocurrido un error al llamar la operación estáPreparado del servicio (%1).
		                               |No se puede definir el tipo de la propiedad raíz estáPreparadaRespuesta.';
		                               |es_CO = 'Ha ocurrido un error al llamar la operación estáPreparado del servicio (%1).
		                               |No se puede definir el tipo de la propiedad raíz estáPreparadaRespuesta.';
		                               |tr = 'Servisin isReady işlemi çağrılırken bir hata oluştu (%1). 
		                               |İsReadyResponse''nin kök özelliğinin türü belirlenemedi';
		                               |it = 'Si è verificato un errore durante la chiamata dell''operazione isReady del servizio (%1).
		                               |Impossibile definire il tipo di proprietà radice isReadyResponse.';
		                               |de = 'Beim Aufrufen der Operation ist dienstbereit (%1) ist ein Fehler aufgetreten.
		                               |Der Typ der Root-Eigenschaft isReady Response konnte nicht definiert werden.'"),
			"%1",
			LegalityCheckServiceDescription.WSDLAddress);
		Raise ErrorMessage;
	EndIf;
	
	Try
		Value = ReadResponseInSOAPEnvelope(ResponseBody, LegalityCheckServiceDescription, ObjectType);
	Except
		ErrorMessage = StrReplace(NStr("en = 'An error occurred when calling operation isReady of service (%1).'; ru = 'Ошибка при вызове операции isReady сервиса (%1).';pl = 'Wystąpił błąd podczas wywoływania operacji isReady serwisu (%1).';es_ES = 'Ha ocurrido un error al llamar la operación estáPreparado del servicio (%1).';es_CO = 'Ha ocurrido un error al llamar la operación estáPreparado del servicio (%1).';tr = 'isReady''nin kök özelliğinin türü belirlenemedi (%1).';it = 'Si è verificato un errore durante la chiamata al servizio isReady (%1).';de = 'Beim Aufrufen der Operation isReady (%1) ist ein Fehler aufgetreten.'"),
			"%1",
			LegalityCheckServiceDescription.WSDLAddress)
			+ Chars.LF
			+ DetailErrorDescription(ErrorInfo())
			+ Chars.LF + Chars.LF
			+ NStr("en = 'Query body:'; ru = 'Тело запроса:';pl = 'Zawartość zapytania:';es_ES = 'Cuerpo de la solicitud:';es_CO = 'Cuerpo de la solicitud:';tr = 'Sorgu gövdesi:';it = 'Corpo della Query:';de = 'Abfragekörper:'")
			+ Chars.LF
			+ EnvelopeText;
		
		Raise ErrorMessage;
	EndTry;
	
	If TypeOf(Value) = Type("Structure") Then
		
		// Description of SOAP exception is returned.
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'An error occurred while calling the
		                                                                             |isReady operation of service (%1) SOAP error: %2'; 
		                                                                             |ru = 'Ошибка при вызове операции
		                                                                             |isReady сервиса (%1) Ошибка SOAP: %2';
		                                                                             |pl = 'Wystąpił błąd podczas wywoływania operacji
		                                                                             |isReady serwisu (%1) SOAP: %2';
		                                                                             |es_ES = 'Ha ocurrido un error al llamar la
		                                                                             |operación estáPreparado del servicio (%1) SOAP error: %2';
		                                                                             |es_CO = 'Ha ocurrido un error al llamar la
		                                                                             |operación estáPreparado del servicio (%1) SOAP error: %2';
		                                                                             |tr = 'Servisin 
		                                                                             |isReady işlemi çağrılırken bir hata oluştu (%1) SOAP hatası: %2';
		                                                                             |it = 'Si è verificato un errore durante la chiamata alla
		                                                                             |operazione isReady del servizio (%1) Errore SOAP: %2';
		                                                                             |de = 'Beim Aufruf der
		                                                                             |ist dienstbereit-Operation (%1) SOAP-Fehler ist ein Fehler aufgetreten: %2'"), LegalityCheckServiceDescription.WSDLAddress, DescriptionSOAPExceptionToRow(Value));
		Raise ErrorMessage;
		
	ElsIf TypeOf(Value) = Type("XDTODataValue") Then
		Return Value.Value;
	Else
		Return Undefined;
	EndIf;
	
EndFunction

// Web service method for update receipt legality check.
//
// Parameters:
// QueryParameters (ObjectXDTO) - parameters of the process() method query;
// LegalityCheckServiceDescription (Structure) - for the check
// 	legality web service description, see LegalityCheckServiceDescription();
//
// Returns:
// XDTODataObject:
// 	value returned by the process() method of legality check web service;
//
Function RefreshReceivedLegally(QueryParameters, LegalityCheckServiceDescription)
	
	EnvelopeRecord = NewSOAPEnvelopeRecord();
	
	EnvelopeRecord.WriteStartElement("m:processRequest");
	EnvelopeRecord.WriteAttribute("xmlns:m", LegalityCheckServiceDescription.OfURIService);
	
	LegalityCheckServiceDescription.XDTOFactory.WriteXML(EnvelopeRecord,
		QueryParameters,
		"parameters",
		,
		XMLForm.Element,
		XMLTypeAssignment.Explicit);
	
	EnvelopeRecord.WriteEndElement(); // </m:processRequest>
	
	EnvelopeText = TextInSOAPEnvelope(EnvelopeRecord);
	
	Try
		ResponseBody = SendSOAPQuery(EnvelopeText, LegalityCheckServiceDescription);
	Except
		
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'An error occurred when calling operation process of service (%1): %2'; ru = 'Ошибка при вызове операции process сервиса (%1): %2';pl = 'Wystąpił błąd podczas wywoływania operacji process serwisu (%1): %2';es_ES = 'Ha ocurrido un error al llamar el proceso de la operación del servicio (%1): %2';es_CO = 'Ha ocurrido un error al llamar el proceso de la operación del servicio (%1): %2';tr = 'Servisin process işlemi çağrılırken bir hata oluştu (%1): %2';it = 'Si è verificato un errore durante la chiamata al processo di servizio  (%1): %2';de = 'Beim Aufruf des Operationsprozesses von Service ist ein Fehler aufgetreten (%1): %2'"),
			LegalityCheckServiceDescription.WSDLAddress, DetailErrorDescription(ErrorInfo()));
		Raise ErrorMessage;
		
	EndTry;
	
	ObjectType = LegalitySeviceFactoryRootPropertyValueType("processResponse", LegalityCheckServiceDescription);
	If ObjectType = Undefined Then
		ErrorMessage = StrReplace(NStr("en = 'An error occurred while calling the process operation of service (%1).
		                               |Unable to define the type of the processResponse root property.'; 
		                               |ru = 'Ошибка при вызове операции process сервиса (%1).
		                               |Не удалось определить тип корневого свойства processResponse.';
		                               |pl = 'Wystąpił błąd podczas wywoływania operacji procesu usługi (%1).
		                               |Nie można zdefiniować typu właściwości głównej processResponse w czasie odpowiedzi.';
		                               |es_ES = 'Ha ocurrido un error al llamar la operación de proceso del servicio (%1).
		                               |No se puede definir el tipo de la propiedad raíz procesarRespuesta.';
		                               |es_CO = 'Ha ocurrido un error al llamar la operación de proceso del servicio (%1).
		                               |No se puede definir el tipo de la propiedad raíz procesarRespuesta.';
		                               |tr = 'Servisin process işlemi çağrılırken bir hata oluştu (%1). 
		                               |İsReadyResponse''nin kök özelliğinin türü belirlenemedi';
		                               |it = 'Si è verificato un errore durante la chiamata della operazione di servizio (%1).
		                               |Impossibile definire il tipo di proprieta radice del processResponse.';
		                               |de = 'Beim Aufrufen der Prozessoperation von Service (%1) ist ein Fehler aufgetreten.
		                               |Der Typ der processResponse-Stammeigenschaft konnte nicht definiert werden.'"),
			"%1",
			LegalityCheckServiceDescription.WSDLAddress);
		Raise ErrorMessage;
	EndIf;
	
	Try
		Value = ReadResponseInSOAPEnvelope(ResponseBody, LegalityCheckServiceDescription, ObjectType);
	Except
		
		ErrorMessage = StrReplace(NStr("en = 'An error occurred when calling operation process of service (%1).'; ru = 'Ошибка при вызове операции process сервиса (%1).';pl = 'Wystąpił błąd podczas wywoływania operacji procesu serwisu (%1).';es_ES = 'Ha ocurrido un error al llamar el proceso de la operación del servicio (%1).';es_CO = 'Ha ocurrido un error al llamar el proceso de la operación del servicio (%1).';tr = 'Servisin process işlemi çağrılırken bir hata oluştu (%1).';it = 'Si è verificato un errore durante la chiamata al processo di servizio (%1).';de = 'Beim Aufruf des Operationsprozesses von Service (%1) ist ein Fehler aufgetreten.'"),
			"%1",
			LegalityCheckServiceDescription.WSDLAddress)
			+ Chars.LF
			+ DetailErrorDescription(ErrorInfo())
			+ Chars.LF + Chars.LF
			+ NStr("en = 'Query body:'; ru = 'Тело запроса:';pl = 'Zawartość zapytania:';es_ES = 'Cuerpo de la solicitud:';es_CO = 'Cuerpo de la solicitud:';tr = 'Sorgu gövdesi:';it = 'Corpo della Query:';de = 'Abfragekörper:'")
			+ Chars.LF
			+ EnvelopeText;
		
		Raise ErrorMessage;
		
	EndTry;
	
	If TypeOf(Value) = Type("XDTODataObject") Then
		Return Value.commands;
	Else
		Return Undefined;
	EndIf;
	
EndFunction

// Returns a row value of the DOM-document node attribute.
//
// Parameters:
// DOMNode (DOMNode) - DOM-document node;
// AttributeName (String) - full name of the attribute;
// ValueIfNotFound (Custom) - value if the attribute is not found;
//
// Returns:
// String:
// 	Node attribute row presentation;
//
Function DOMNodeAttributeValue(DOMNode, AttributeName, ValueIfNotFound = Undefined)
	
	Attribute = DOMNode.Attributes.GetNamedItem(AttributeName);
	
	If Attribute = Undefined Then
		Return ValueIfNotFound;
	Else
		Return Attribute.Value;
	EndIf;
	
EndFunction

// Determines root property value type of
// XDTO factory pack of legality check web service.
//
// Parameters:
// PropertyName (String) - name of the root property;
// LegalityCheckServiceDescription (Structure) - for the check
// 	legality web service description, see LegalityCheckServiceDescription();
//
// Returns:
// XDTOValueType;
// XDTOObjectType;
// Undefined - if root property is not found;
//
Function LegalitySeviceFactoryRootPropertyValueType(PropertyName, LegalityCheckServiceDescription)
	
	Package            = LegalityCheckServiceDescription.XDTOFactory.packages.Get(LegalityCheckServiceDescription.OfURIService);
	RootProperty = Package.RootProperties.Get(PropertyName);
	If RootProperty = Undefined Then
		Return Undefined;
	Else
		Return RootProperty.Type;
	EndIf;
	
EndFunction

// Generates XMLWrite object type with the already written ones.
// SOAP-titles;
//
// Returns:
// XMLWriter:
// 	object of XML record with the written SOAP-titles;
//
Function NewSOAPEnvelopeRecord()
	
	XMLWriter = New XMLWriter;
	XMLWriter.SetString();
	
	XMLWriter.WriteStartElement("soap:Envelope");
	XMLWriter.WriteAttribute("xmlns:soap", "http://schemas.xmlsoap.org/soap/envelope/");
	XMLWriter.WriteStartElement("soap:Header");
	XMLWriter.WriteEndElement(); // </soap:Header>
	XMLWriter.WriteStartElement("soap:Body");
	
	Return XMLWriter;
	
EndFunction

// Finalizes the record of SOAP-envelope and returns the envelope text.
//
// Parameters:
// EnvelopeRecord (XMLWriter) - object to which the envelope is written;
//
// Returns:
// String: SOAP envelope text;
//
Function TextInSOAPEnvelope(EnvelopeRecord)
	
	EnvelopeRecord.WriteEndElement(); // </soap:Body>
	EnvelopeRecord.WriteEndElement(); // </soap:Envelope>
	
	Return EnvelopeRecord.Close();
	
EndFunction

// Sends SOAP-envelope to the web service and receives a response one.
// SOAP-envelope.
//
// Parameters:
// EnvelopeText (String) - query-envelope text;
// LegalityCheckServiceDescription (Structure) - for the check
// 	legality web service description, see LegalityCheckServiceDescription();
//
// Returns:
// String: text of the SOAP envelope response;
//
Function SendSOAPQuery(EnvelopeText, LegalityCheckServiceDescription)
	
	HTTPRequest = New HTTPRequest(LegalityCheckServiceDescription.PortPath);
	HTTPRequest.Headers["Content-Type"] = "text/xml;charset=UTF-8";
	HTTPRequest.SetBodyFromString(EnvelopeText);
	
	Try
		HTTPResponse = LegalityCheckServiceDescription.PortConnection.Post(HTTPRequest);
	Except
		ErrorMessage = NStr("en = 'A connection error occurred when sending a SOAP query.'; ru = 'Ошибка сетевого соединения при отправке SOAP-запроса.';pl = 'Wystąpił błąd połączenia podczas wysyłania zapytania SOAP.';es_ES = 'Ha ocurrido un error de conexión al enviar una solicitud SOAP.';es_CO = 'Ha ocurrido un error de conexión al enviar una solicitud SOAP.';tr = 'SOAP sorgusu gönderilirken bağlantı hatası oluştu.';it = 'Si è verificato un errore di connessione durante l''invio di una query SOAP.';de = 'Beim Senden einer SOAP-Abfrage ist ein Verbindungsfehler aufgetreten.'")
			+ Chars.LF
			+ DetailErrorDescription(ErrorInfo());
		Raise ErrorMessage;
	EndTry;
	
	ResponseBody = HTTPResponse.GetBodyAsString();
	
	Return ResponseBody;
	
EndFunction

// Reads object or value in the responce SOAP-envelope
// according to the factory of XDTO web service types.
//
// Parameters:
// ResponseBody (String) - body in the SOAP envelope response;
// LegalityCheckServiceDescription (Structure) - for the check
// 	legality web service description, see LegalityCheckServiceDescription();
// ValueType (XDTOValueType, XDTOObjectType) - read value type;
//
Function ReadResponseInSOAPEnvelope(ResponseBody, LegalityCheckServiceDescription, ValueType)
	
	ResponseReading = New XMLReader;
	ResponseReading.SetString(ResponseBody);
	
	Try
		
		// Transition to the response body
		While ResponseReading.Name <> "soap:Body" Do
			ResponseReading.Read();
		EndDo;
		
		// Transfer to the response object description.
		ResponseReading.Read();
		
	Except
		
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'An error occurred
		                                                                             |while
		                                                                             |reading SOAP:
		                                                                             |%1 Response body: %2'; 
		                                                                             |ru = 'Ошибка
		                                                                             |чтения
		                                                                             |ответа SOAP:
		                                                                             |%1 Тело ответа: %2';
		                                                                             |pl = 'Wystąpił błąd
		                                                                             |podczas
		                                                                             |odczytu SOAP:
		                                                                             |%1 Zawartość odpowiedzi: %2';
		                                                                             |es_ES = 'Ha ocurrido un error
		                                                                             |al
		                                                                             |leer SOAP:
		                                                                             |%1 Cuerpo de la respuesta: %2';
		                                                                             |es_CO = 'Ha ocurrido un error
		                                                                             |al
		                                                                             |leer SOAP:
		                                                                             |%1 Cuerpo de la respuesta: %2';
		                                                                             |tr = 'SOAP 
		                                                                             |okunurken
		                                                                             | bir hata oluştu: 
		                                                                             |%1 Yanıt gövdesi: %2';
		                                                                             |it = 'Si è verificato un errore
		                                                                             |durante
		                                                                             |la lettura di SOAP:
		                                                                             |%1 Corpo di risposta: %2';
		                                                                             |de = '
		                                                                             |Beim Lesen von SOAP
		                                                                             |ist ein Fehler aufgetreten:
		                                                                             |%1Antworttext: %2'"), DetailErrorDescription(ErrorInfo()), ResponseBody);
		Raise ErrorMessage;
		
	EndTry;
	
	If ResponseReading.NodeType = XMLNodeType.StartElement
		AND Upper(ResponseReading.Name) = "SOAP:FAULT" Then
		// It is the exception of the web service
		Try
			ExceptionDetails = ReadServiceExceptionsDescription(ResponseReading);
		Except
			
			ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'An error occurred
			                                                                             |while
			                                                                             |reading SOAP:
			                                                                             |%1 Response body: %2'; 
			                                                                             |ru = 'Ошибка
			                                                                             |чтения
			                                                                             |ответа SOAP:
			                                                                             |%1 Тело ответа: %2';
			                                                                             |pl = 'Wystąpił błąd
			                                                                             |podczas
			                                                                             |odczytu SOAP:
			                                                                             |%1 Zawartość odpowiedzi: %2';
			                                                                             |es_ES = 'Ha ocurrido un error
			                                                                             |al
			                                                                             |leer SOAP:
			                                                                             |%1 Cuerpo de la respuesta: %2';
			                                                                             |es_CO = 'Ha ocurrido un error
			                                                                             |al
			                                                                             |leer SOAP:
			                                                                             |%1 Cuerpo de la respuesta: %2';
			                                                                             |tr = 'SOAP 
			                                                                             |okunurken
			                                                                             | bir hata oluştu: 
			                                                                             |%1 Yanıt gövdesi: %2';
			                                                                             |it = 'Si è verificato un errore
			                                                                             |durante
			                                                                             |la lettura di SOAP:
			                                                                             |%1 Corpo di risposta: %2';
			                                                                             |de = '
			                                                                             |Beim Lesen von SOAP
			                                                                             |ist ein Fehler aufgetreten:
			                                                                             |%1Antworttext: %2'"), DetailErrorDescription(ErrorInfo()), ResponseBody);
			Raise ErrorMessage;
			
		EndTry;
		
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'The SOAP-server error occurred when processing the query: %1'; ru = 'Ошибка SOAP-Сервера при обработке запроса: %1';pl = 'Wystąpił błąd serwera SOAP podczas przetwarzania zapytania: %1';es_ES = 'Ha ocurrido el error del servidor-SOAP al procesar la solicitud: %1';es_CO = 'Ha ocurrido el error del servidor-SOAP al procesar la solicitud: %1';tr = 'Sorgu işlenirken SOAP sunucusu hatası oluştu: %1';it = 'Errore del server SOAP durante l''elaborazione della richiesta: %1';de = 'Der SOAP-Server-Fehler ist bei der Verarbeitung der Abfrage aufgetreten: %1'"), DescriptionSOAPExceptionToRow(ExceptionDetails));
		Raise ErrorMessage;
		
	EndIf;
	
	Try
		Value = LegalityCheckServiceDescription.XDTOFactory.ReadXML(ResponseReading, ValueType);
	Except
		
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'An error occurred while reading object
		                                                                             |(%1)
		                                                                             |in the
		                                                                             |SOAP envelope: %2 Response body: %3'; 
		                                                                             |ru = 'Ошибка чтения объекта
		                                                                             |(%1)
		                                                                             |в конверте
		                                                                             |SOAP: %2 Тело ответа: %3';
		                                                                             |pl = 'Wystąpił błąd podczas odczytu obiektu 
		                                                                             |(%1)
		                                                                             | w kopercie
		                                                                             |SOAP: %2 Zawartość odpowiedzi: %3';
		                                                                             |es_ES = 'Ha ocurrido un error al leer el objeto
		                                                                             |(%1)
		                                                                             |en el
		                                                                             |sobre SOAP: %2 Cuerpo de la respuesta: %3';
		                                                                             |es_CO = 'Ha ocurrido un error al leer el objeto
		                                                                             |(%1)
		                                                                             |en el
		                                                                             |sobre SOAP: %2 Cuerpo de la respuesta: %3';
		                                                                             |tr = 'SOAP zarfında nesne
		                                                                             | (%1) 
		                                                                             |okunurken%2 bir hata oluştu: 
		                                                                             |Yanıt gövdesi:%3';
		                                                                             |it = 'Si è verificato un errore durante la lettura dell''oggetto
		                                                                             |(%1)
		                                                                             |nel 
		                                                                             |plico SOAP: %2 Corpo di risposta: %3';
		                                                                             |de = 'Beim Lesen von object
		                                                                             |(%1)
		                                                                             |im SOAP-Umschlag
		                                                                             |ist ein Fehler aufgetreten: %2Antworttext: %3'"), String(ValueType), DetailErrorDescription(ErrorInfo()), ResponseBody);
		Raise ErrorMessage;
		
	EndTry;
	
	Return Value;
	
EndFunction

// If the response SOAP-envelope contains an
// error description, then the error description is read.
//
// Parameters:
// ResponseReading (XMLReading) - object used for
// 	reading the response SOAP-envelope. At the time of the call it is positioned at the description.
// 	exceptions SOAP;
//
// Returns:
// Structure with properties:
// 	FaultCode (String), FaultString (String), FaultActor (String);
//
Function ReadServiceExceptionsDescription(ResponseReading)
	
	DetailsExceptions = New Structure("FaultCode, FaultString, FaultActor", "", "", "");
	
	While Not (Upper(ResponseReading.Name) = "SOAP:BODY" AND ResponseReading.NodeType = XMLNodeType.EndElement) Do
		
		If ResponseReading.NodeType = XMLNodeType.StartElement Then
			NodeNameInReg = Upper(ResponseReading.Name);
			
			If NodeNameInReg = "FAULTCODE"
				OR NodeNameInReg = "FAULTSTRING"
				OR NodeNameInReg = "FAULTACTOR" Then
				
				ResponseReading.Read(); // Read the node text
				
				If ResponseReading.NodeType = XMLNodeType.Text Then
					DetailsExceptions[NodeNameInReg] = ResponseReading.Value;
				EndIf;
				
				ResponseReading.Read(); // Read the end of item
				
			EndIf;
			
		EndIf;
		
		If Not ResponseReading.Read() Then
			Break;
		EndIf;
		
	EndDo;
	
	Return DetailsExceptions;
	
EndFunction

// Converts structure-specifier of
// SOAP exception to string for a user presentation;
//
// Parameters:
// SOAPException (Structure) - see ReadServiceExceptionsDescription();
//
// Returns:
// String: user presentation of SOAP exception;
//
Function DescriptionSOAPExceptionToRow(ExceptionSOAP)
	
	Result = "";
	If Not IsBlankString(ExceptionSOAP.FaultCode) Then
		Result = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Error code: %1'; ru = 'Код ошибки: %1';pl = 'Kod błędu: %1';es_ES = 'Código de error: %1';es_CO = 'Código de error: %1';tr = 'Hata kodu: %1';it = 'Codice errore: %1';de = 'Fehlercode: %1'"), ExceptionSOAP.FaultCode);
	EndIf;
	
	If Not IsBlankString(ExceptionSOAP.FaultString) Then
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Error line: %1'; ru = 'Строка ошибки: %1';pl = 'Wiersz błędu: %1';es_ES = 'Línea de error: %1';es_CO = 'Línea de error: %1';tr = 'Hata satırı: %1';it = 'Linea errore: %1';de = 'Fehlerzeile: %1'"), ExceptionSOAP.FaultString);
		Result = Result + Chars.LF + ErrorText;
	EndIf;
	
	If Not IsBlankString(ExceptionSOAP.FaultActor) Then
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Error source: %1'; ru = 'Источник ошибки: %1';pl = 'Źródło błędu: %1';es_ES = 'Fuente de error: %1';es_CO = 'Fuente de error: %1';tr = 'Hata kaynağı: %1';it = 'Fonte dell''errore: %1';de = 'Fehlerquelle: %1'"), ExceptionSOAP.FaultActor);
		Result = Result + Chars.LF + ErrorText;
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion

#EndIf

#EndRegion

// Return file directory - part of the path without the attachment file name.
//
// Parameters:
//  PathToFile  - String - file path.
//
// Returns:
//   String   - file directory
Function GetFileDir(Val PathToFile) Export

	CharPosition = GetNumberOfLastChar(PathToFile, "\");
	If CharPosition > 1 Then
		Return Mid(PathToFile, 1, CharPosition - 1); 
	Else
		Return "";
	EndIf;

EndFunction

Function GetNumberOfLastChar(Val SourceLine, Val SearchChar)
	
	CharPosition = StrLen(SourceLine);
	While CharPosition >= 1 Do
		
		If Mid(SourceLine, CharPosition, 1) = SearchChar Then
			Return CharPosition; 
		EndIf;
		
		CharPosition = CharPosition - 1;	
	EndDo;

	Return 0;
  	
EndFunction

// Function, opens online address on the Internet.
//
// Parameters:
// PageAddress - String, path to a page in the Internet that should be opened.
// Title - String, the title of "browser" window.
//
Procedure OpenWebPage(Val PageAddress, Val Title = "") Export
	
	OpenForm("DataProcessor.InstallUpdates.Form.Browser", 
		New Structure("PageAddress,Title", PageAddress, Title));

EndProcedure
		
#Region HandlersOfTheConditionalCallsIntoOtherSubsystems

// Checks if update receipt is legal. If there
// is no legality check subsystem, returns True.
//
// Parameters:
//  Notification - NotifyDescription - contains
//               handler called after update receipt legality confirmation.
//
Function CheckSoftwareUpdateLegality(Notification) Export
	
	If CommonClient.SubsystemExists("StandardSubsystems.CheckUpdateReceiveLegality") Then
		ModuleUpdateObtainingLegalityCheckClient = CommonClient.CommonModule("CheckUpdateReceiveLegalityClient");
		ModuleUpdateObtainingLegalityCheckClient.ShowUpdateReceiptLealityCheck(Notification);
	Else
		ExecuteNotifyProcessing(Notification, True);
	EndIf;
	
EndFunction

#EndRegion


#EndRegion
