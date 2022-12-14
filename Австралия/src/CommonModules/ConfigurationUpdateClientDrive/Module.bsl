
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
	
	Status(NStr("en = 'Check for updates online'; ru = '???????????????? ?????????????? ???????????????????? ?? ??????????????????';pl = 'Sprawdzenie aktualizacji w Internecie';es_ES = 'Revisar las actualizaciones online';es_CO = 'Revisar las actualizaciones online';tr = '??evrimi??i g??ncellemeleri kontrol et';it = 'Controlla aggiornamenti on-line';de = 'Suchen Sie online nach Updates'"));
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
			NStr("en = 'Cannot connect to the Internet to check for updates.'; ru = '???????????????????? ???????????????????????? ?? ???????? ???????????????? ?????? ???????????????? ????????????????????.';pl = 'Nie mo??na pod????czy?? si?? do Internetu dla sprawdzenia aktualizacji.';es_ES = 'No se puede conectar a Internet para revisar las actualizaciones.';es_CO = 'No se puede conectar a Internet para revisar las actualizaciones.';tr = 'G??ncellemeleri kontrol etmek i??in internete ba??lan??lam??yor.';it = 'Non ?? impossibile collegarsi a Internet per controllare gli aggiornamenti';de = 'Es kann keine Verbindung zum Internet hergestellt werden, um nach Updates zu suchen.'"));
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
				NStr("en = 'Update is not required: the newest configuration version is already installed.'; ru = '???????????????????? ???? ??????????????????: ?????????????????? ???????????? ???????????????????????? ?????? ??????????????????????.';pl = 'Aktualizacja nie jest konieczna: ostatnia wersja konfiguracji jest ju?? zainstalowana.';es_ES = 'No se requiere la actualizaci??n: la versi??n m??s nueva de la configuraci??n ya se ha instalado.';es_CO = 'No se requiere la actualizaci??n: la versi??n m??s nueva de la configuraci??n ya se ha instalado.';tr = 'G??ncelleme gerekmiyor: En yeni yap??land??rma s??r??m?? zaten y??kl??.';it = 'Aggiornamento non ?? necessario: la versione pi?? recente di configurazione ?? gi?? installata.';de = 'Update ist nicht erforderlich: Die neueste Konfigurationsversion ist bereits installiert.'"));
			
			Parameters.PageName = "UpdatesNotDetected";
			Return;
			
		EndIf;
	EndIf;
	
	MessageText = NStr("en = 'Newer configuration version is found on the Internet: %1.'; ru = '???????????????????? ?????????? ?????????? ???????????? ???????????????????????? ?? ??????????????????: %1.';pl = 'W Internecie znaleziono nowsz?? wersj?? konfiguracji:%1.';es_ES = 'Versi??n m??s reciente de la configuraci??n se ha encontrado en Internet: %1.';es_CO = 'Versi??n m??s reciente de la configuraci??n se ha encontrado en Internet: %1.';tr = '??nternette daha yeni bir yap??land??rma s??r??m?? bulunuyor: %1.';it = 'Una versione pi?? recente della configurazione si trova su Internet: %1.';de = 'Neuere Konfigurationsversion im Internet gefunden: %1.'");
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
		NStr("en = 'Check for updates on the Internet on schedule.'; ru = '???????????????? ?????????????? ???????????????????? ?? ???????? ???????????????? ???? ????????????????????.';pl = 'Sprawdzaj aktualizacje w Internecie zgodnie z harmonogramem.';es_ES = 'Revisar las actualizaciones en Internet del horario.';es_CO = 'Revisar las actualizaciones en Internet del horario.';tr = '??nternet ??zerinden program g??ncellemelerini kontrol edin.';it = 'Controllare gli aggiornamenti su Internet nei tempi previsti.';de = 'Im Internet nach Updates suchen.'"));
		
	AvailableUpdatePageDescription = "AvailableUpdate";
	CheckUpdateExistsViaInternet();
	Parameters = GetAvailableConfigurationUpdate();
	If Parameters.UpdateSource <> -1 AND Parameters.PageName = AvailableUpdatePageDescription Then
			
		EventLogClient.AddMessageForEventLog(ConfigurationUpdateClient.EventLogEvent(),,
			NStr("en = 'New configuration version is detected:'; ru = '???????????????????? ?????????? ???????????? ????????????????????????:';pl = 'Jest ujawniona nowa wersja konfiguracji:';es_ES = 'Versi??n m??s reciente de la configuraci??n se ha detectado:';es_CO = 'Versi??n m??s reciente de la configuraci??n se ha detectado:';tr = 'Yeni yap??land??rma s??r??m?? alg??land??:';it = 'viene rilevata Nuova versione di configurazione:';de = 'Neue Konfigurationsversion wurde erkannt:'") + " " + Parameters.FileParametersUpdateChecks.Version);
				
		ConfigurationUpdateOptions.UpdateSource = 0;
		ConfigurationUpdateOptions.ScheduleOfUpdateExistsCheck = ScheduleOfUpdateExistsCheck;
		ConfigurationUpdateServerCallDrive.WriteStructureOfAssistantSettings(ConfigurationUpdateOptions, ApplicationParameters["StandardSubsystems.MessagesForEventLogMonitor"]);
		
		Parameters.UpdateSource = ConfigurationUpdateOptions.UpdateSource;
		Parameters.NeedUpdateFile = ConfigurationUpdateOptions.NeedUpdateFile;
		Parameters.FlagOfAutoTransitionToPageWithUpdate = True;
		ShowUserNotification(NStr("en = 'Configuration update is available'; ru = '???????????????? ???????????????????? ????????????????????????';pl = 'Aktualizacja konfiguracji jest dost??pna';es_ES = 'Actualizaci??n de la configuraci??n est?? disponible';es_CO = 'Actualizaci??n de la configuraci??n est?? disponible';tr = 'Yap??land??rma g??ncellemesi mevcut';it = 'L''aggiornamento della configurazione ?? disponibile';de = 'Konfigurationsaktualisierung ist verf??gbar'"),
			"e1cib/app/DataProcessor.InstallUpdates",
			NStr("en = 'Version:'; ru = '????????????:';pl = 'Wersja:';es_ES = 'Versi??n:';es_CO = 'Versi??n:';tr = 'S??r??m:';it = 'Versione:';de = 'Version:'") + " " + Parameters.FileParametersUpdateChecks.Version, 
			PictureLib.Information32);
	Else
		EventLogClient.AddMessageForEventLog(ConfigurationUpdateClient.EventLogEvent(),, 
			NStr("en = 'No available updates were found.'; ru = '?????????????????? ???????????????????? ???? ????????????????????.';pl = 'Nie znaleziono dost??pnych aktualizacji.';es_ES = 'No se han encontrado las actualizaciones disponibles.';es_CO = 'No se han encontrado las actualizaciones disponibles.';tr = 'Kullan??labilir g??ncelleme bulunamad??.';it = 'Nessun aggiornamenti disponibili sono stati trovati.';de = 'Keine verf??gbaren Updates wurden gefunden.'"));
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
			                 |ru = '???? ?????????????? ?????????????? ?????????????????? ?????????????? ?????? ???????????????? ?????????????? ????????????????????.
			                 |%1';
			                 |pl = 'Nie mo??na utworzy?? katalogu tymczasowego, aby sprawdzi?? dost??pno???? aktualizacji.
			                 |%1';
			                 |es_ES = 'No se puede crear el directorio temporal para revisar las actualizaciones.
			                 |%1';
			                 |es_CO = 'No se puede crear el directorio temporal para revisar las actualizaciones.
			                 |%1';
			                 |tr = 'G??ncellemeleri kontrol etmek i??in ge??ici dizin olu??turulamad??.
			                 |%1';
			                 |it = 'Impossibile creare la directory temporanea per controllare gli aggiornamenti."
"%1';
			                 |de = 'Das tempor??re Verzeichnis konnte nicht erstellt werden, um nach Updates zu suchen.
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
			     |ru = '???? ?????????????? ?????????????????? ?????????????? ????????????????????.
			     |%1';
			     |pl = 'Nie mo??na sprawdzi?? aktualizacji.
			     |%1';
			     |es_ES = 'No se puede revisar las actualizaciones.
			     |%1';
			     |es_CO = 'No se puede revisar las actualizaciones.
			     |%1';
			     |tr = 'G??ncellemeler kontrol edilemiyor.
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
		Return NStr("en = 'Update description file is not received'; ru = '???????? ???????????????? ???????????????????? ???? ??????????????';pl = 'Plik opisu aktualizacji nie zosta?? odebrany';es_ES = 'Archivo de la descripci??n de la actualizaci??n no se ha recibido';es_CO = 'Archivo de la descripci??n de la actualizaci??n no se ha recibido';tr = 'G??ncelleme a????klama dosyas?? al??namad??';it = 'Descrizione Aggiornamento file non viene ricevuto';de = 'Datei der Update-Beschreibungsdatei wurde nicht empfangen'");
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
			Return NStr("en = 'Incorrect update information format'; ru = '???????????????? ???????????? ???????????????? ?? ?????????????? ????????????????????';pl = 'Nieprawid??owy format informacji o aktualizacji';es_ES = 'Formato de la informaci??n de la actualizaci??n incorrecto';es_CO = 'Formato de la informaci??n de la actualizaci??n incorrecto';tr = 'Yanl???? g??ncelleme bilgisi format??';it = 'Formato di informazioni di aggiornamento non valido';de = 'Falsches Aktualisierungsinformationsformat'");
		EndIf;
	EndDo;
	If SetParameters.Count() <> 3 Then 
		Return NStr("en = 'Incorrect update information format'; ru = '???????????????? ???????????? ???????????????? ?? ?????????????? ????????????????????';pl = 'Nieprawid??owy format informacji o aktualizacji';es_ES = 'Formato de la informaci??n de la actualizaci??n incorrecto';es_CO = 'Formato de la informaci??n de la actualizaci??n incorrecto';tr = 'Yanl???? g??ncelleme bilgisi format??';it = 'Formato di informazioni di aggiornamento non valido';de = 'Falsches Aktualisierungsinformationsformat'");
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
		ErrorText = NStr("en = 'An error occurred when creating description of web service for update legality check.'; ru = '???????????? ???????????????? ???????????????? ??????-?????????????? ???????????????? ?????????????????????? ?????????????????? ????????????????????.';pl = 'Wyst??pi?? b????d podczas tworzenia opisu serwisu www do weryfikacji legalno??ci pobierania aktualizacji.';es_ES = 'Ha ocurrido un error al crear la descripci??n del servicio web para la revisi??n de la legalidad de la actualizaci??n.';es_CO = 'Ha ocurrido un error al crear la descripci??n del servicio web para la revisi??n de la legalidad de la actualizaci??n.';tr = 'G??ncelleme yasall?????? kontrol?? i??in web hizmeti a????klamas?? olu??tururken bir hata olu??tu.';it = 'Errore durante la creazione della descrizione del servizio Web per verificare la legalit?? dell''aggiornamento.';de = 'Beim Erstellen der Beschreibung des Web-Service f??r die ??berpr??fung der Rechtm????igkeit des Updates ist ein Fehler aufgetreten.'");
		Return WebServerResponceStructure(ErrorText, True,,, DetailErrorDescription(ErrorInfo()));
	EndTry;
	
	// Determine whether web service is available.
	Try
		
		ServerResponse = ServiceAvailable(ServiceDescription);
		
		If Lower(TrimAll(ServerResponse)) <> "ready" Then
			
			ErrorText = NStr("en = 'Service of updates receipt legality check is temporarily unavailable.
			                 |Try again later'; 
			                 |ru = '???????????? ???????????????? ?????????????????????? ?????????????????? ???????????????????? ???????????????? ????????????????????.
			                 |?????????????????? ?????????????? ??????????????';
			                 |pl = 'Us??uga weryfikacji legalno??ci pobierania aktualizacji jest chwilowo niedost??pna.
			                 |Spr??buj ponownie p????niej';
			                 |es_ES = 'Servicio de la revisi??n de la legalidad del recibo de actualizaciones temporalmente no se encuentra disponible.
			                 |Intentar de nuevo m??s tarde';
			                 |es_CO = 'Servicio de la revisi??n de la legalidad del recibo de actualizaciones temporalmente no se encuentra disponible.
			                 |Intentar de nuevo m??s tarde';
			                 |tr = 'G??ncelleme yasall??k kontrol?? hizmeti ge??ici olarak kullan??lam??yor. 
			                 |Daha sonra tekrar deneyin';
			                 |it = 'Servizio di controllo della legalit?? aggiornamenti ricevuti ?? temporaneamente non disponibile.
			                 |Riprovare pi?? tardi';
			                 |de = 'Der Service f??r die ??berpr??fung der Rechtm????igkeit des Updates ist vor??bergehend nicht verf??gbar.
			                 |Versuchen Sie es sp??ter erneut'");
			Return WebServerResponceStructure(ErrorText, True, ServerResponse);
			
		EndIf;
		
	Except
		
		ErrorText = NStr("en = 'Unable to connect to the service of updates receipt legality check.
		                 |Check your Internet connection settings'; 
		                 |ru = '???? ?????????????? ???????????????????????? ?? ?????????????? ???????????????? ?????????????????????? ?????????????????? ????????????????????.
		                 |?????????????????? ?????????????????? ?????????????????????? ?? ??????????????????';
		                 |pl = 'Nie mo??na po????czy?? si?? z serwisem weryfikacji legalno??ci pobierania aktualizacji.
		                 |Sprawd?? ustawienia po????czenia internetowego';
		                 |es_ES = 'No se puede conectar al servicio de la revisi??n de la legalidad del recibo de actualizaciones.
		                 |Revisar sus configuraciones de conexi??n a Internet';
		                 |es_CO = 'No se puede conectar al servicio de la revisi??n de la legalidad del recibo de actualizaciones.
		                 |Revisar sus configuraciones de conexi??n a Internet';
		                 |tr = 'G??ncelleme yasall??k kontrol?? hizmetine ba??lan??lam??yor. 
		                 |??nternet ba??lant?? ayarlar??n??z?? kontrol edin';
		                 |it = 'Impossibile connettersi al servizio di controllo della legalit?? degli aggiornamenti ricevuti.
		                 |Controllare le impostazioni di connessione a Internet';
		                 |de = 'Es konnte keine Verbindung mit dem Service f??r die ??berpr??fung der Rechtm????igkeit des Updates hergestellt werden.
		                 |??berpr??fen Sie Ihre Internetverbindungseinstellungen'");
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
		                 |ru = '???????????? ???????????????????? ???????????????? ?????????????????????? ?????????????????? ????????????????????.
		                 |???????????????????? ?? ????????????????????????????';
		                 |pl = 'Wyst??pi?? b????d podczas weryfikacji legalno??ci pobierania aktualizacji.
		                 |Skontaktuj si?? z administratorem';
		                 |es_ES = 'Ha ocurrido un error al revisar la legalidad del recibo de la actualizaci??n.
		                 |Contactar el administrador';
		                 |es_CO = 'Ha ocurrido un error al revisar la legalidad del recibo de la actualizaci??n.
		                 |Contactar el administrador';
		                 |tr = 'G??ncelleme yasall?????? kontrol edilirken bir hata olu??tu. 
		                 |Y??netici ile ileti??ime ge??in';
		                 |it = 'Si ?? verificato un errore durante la verifica della legalit?? del aggiornamento ricevuto."
"Contattare l''amministratore';
		                 |de = 'Bei der ??berpr??fung der Rechtm????igkeit des Updates des Empfangs ist ein Fehler aufgetreten.
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
		
		Result = WebServerResponceStructure(NStr("en = 'Unexpected update service response'; ru = '?????????????????????? ?????????? ?????????????? ???????????????? ?????????????????????? ?????????????????? ????????????????????';pl = 'Nieoczekiwana odpowied?? us??ugi na weryfikacj?? legalno??ci pobierania aktualizacji';es_ES = 'Respuesta de servicio de la actualizaci??n inesperada';es_CO = 'Respuesta de servicio de la actualizaci??n inesperada';tr = 'Beklenmeyen g??ncelleme hizmeti yan??t??';it = 'Risposta inaspettata dal servizio per verificare la legalit?? della ricezione degli aggiornamenti';de = 'Unerwartete Update-Service-Antwort'"), True);
		
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
			MessageText = NStr("en = '%ErrorText. Error code: %ErrorCode'; ru = '%ErrorText. ?????? ????????????: %ErrorCode.';pl = '%ErrorText. Kod b????du: %ErrorCode';es_ES = '%ErrorTexto. C??digo de error: %ErrorC??digo';es_CO = '%ErrorTexto. C??digo de error: %ErrorC??digo';tr = '%ErrorText. Hata kodu: %ErrorCode';it = '%ErrorText. Codice errore: %ErrorCode.';de = '%ErrorText. Fehlercode: %ErrorCode'");
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
		                                                                             |ru = '???????????? ?????? ???????????????? ???????????????? ??????-??????????????.
		                                                                             |???? ?????????????? ???????????????? WSDL-???????????????? ?? ?????????????? ???????????????? ?????????????????????? ???????????????????? ???????????????????? (%1): %2.';
		                                                                             |pl = 'Wyst??pi?? b????d podczas tworzenia opisu us??ugi webowej.
		                                                                             |Nie mo??na odebra?? opisu WSDL z serwera weryfikacji legalno??ci importu aktualizacji (%1): %2.';
		                                                                             |es_ES = 'Ha ocurrido un error al crear la descripci??n del servicio web.
		                                                                             |No se puede recibir la descripci??n-WSDL desde el servidor de la revisi??n de la legalidad de la importaci??n de la actualizaci??n (%1): %2.';
		                                                                             |es_CO = 'Ha ocurrido un error al crear la descripci??n del servicio web.
		                                                                             |No se puede recibir la descripci??n-WSDL desde el servidor de la revisi??n de la legalidad de la importaci??n de la actualizaci??n (%1): %2.';
		                                                                             |tr = 'Web hizmetinin a????klamas??n?? olu??tururken bir hata olu??tu. 
		                                                                             |G??ncellemeyi indirmenin yasall??????n?? kontrol eden (%1) web servisi WSDL a????klamas??n?? okurken hata olu??tu:%2.';
		                                                                             |it = 'Si ?? verificato un errore durante la creazione della descrizione del servizio web. 
		                                                                             |Impossibile ricevere la descrizione WDSL dal server di aggiornamento del controllo di legalit?? di importazione (%1): %2.';
		                                                                             |de = 'Beim Erstellen der Beschreibung des Webservices ist ein Fehler aufgetreten.
		                                                                             |Kann die WSDL-Beschreibung vom Server der Update-Import-Legalit??tspr??fung (%1) nicht empfangen: %2.'"),
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
		                                                                             |ru = '???????????? ?????? ???????????????? ???????????????? ??????-?????????????? (%1).
		                                                                             |???????????? ???????????? WSDL-???????????????? ??????-?????????????? ???????????????? ?????????????????????? ???????????????????? ????????????????????: %2.';
		                                                                             |pl = 'Wyst??pi?? b????d podczas opisywania us??ugi webowej(%1).
		                                                                             |Wyst??pi?? b????d podczas odczytu opisu WSDL us??ugi www weryfikacji legalno??ci importu aktualizacji: %2.';
		                                                                             |es_ES = 'Ha ocurrido un error al describir el servicio web (%1).
		                                                                             |Ha ocurrido un error al leer la descripci??n-WSDL del servicio web de la revisi??n de la legalidad de la importaci??n de la actualizaci??n: %2.';
		                                                                             |es_CO = 'Ha ocurrido un error al describir el servicio web (%1).
		                                                                             |Ha ocurrido un error al leer la descripci??n-WSDL del servicio web de la revisi??n de la legalidad de la importaci??n de la actualizaci??n: %2.';
		                                                                             |tr = 'Web hizmetini (%1) a????klarken bir hata olu??tu. 
		                                                                             |G??ncellemeyi indirmenin yasall?????? kontrol eden web servisi WSDL a????klamas??n?? okurken bir hata olu??tu:%2.';
		                                                                             |it = 'Si ?? verificato un errore durante la descrizione del servizio web (%1). 
		                                                                             |Si ?? verificato un errore durante la lettura della descrizione WDSL del servizio web di aggiornamento del controllo di legalit?? di importazione: %2.';
		                                                                             |de = 'Bei der Beschreibung von Webservice (%1) ist ein Fehler aufgetreten.
		                                                                             |Beim Lesen der Webservice -WSDL-Beschreibung der Update-Import-Legalit??tspr??fung ist ein Fehler aufgetreten: %2.'"),
			WSDLAddress, DetailErrorDescription(ErrorInfo()));
		Raise ErrorMessage;
	EndTry;
	
	// Create XDTO factory of legality check web service.
	
	SchemeNodes = DOMDocument.GetElementByTagName("wsdl:types");
	If SchemeNodes.Count() = 0 Then
		
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'An error occurred while describing web service (%1).
		                                                                             |An error occurred while reading web service
		                                                                             |WSDL-description of update import legality check: There is no data types description item (<wsdl:types ...>).'; 
		                                                                             |ru = '???????????? ?????? ???????????????? ???????????????? ??????-?????????????? (%1).
		                                                                             |???????????? ???????????? WSDL-???????????????? ??????-?????????????? ???????????????? ?????????????????????? ???????????????????? ????????????????????:
		                                                                             |?????????????????????? ?????????????? ???????????????? ?????????? ???????????? (<wsdl:types ...>).';
		                                                                             |pl = 'Wyst??pi?? b????d podczas opisywania us??ugi webowej (%1).
		                                                                             |Wyst??pi?? b????d podczas odczytu us??ugi
		                                                                             |opis WSDL serwisu www weryfikacji legalno??ci importu aktualizacji: Brak pozycji opisu typ??w danych (<wsdl:types ...>).';
		                                                                             |es_ES = 'Ha ocurrido un error al describir el servicio web (%1).
		                                                                             |Ha ocurrido un error al leer la descripci??n-WSDL
		                                                                             |del servicio web de la revisi??n de la legalidad de la importaci??n de la actualizaci??n: No hay un art??culo de la descripci??n de los tipos de datos (<wsdl:types ...>).';
		                                                                             |es_CO = 'Ha ocurrido un error al describir el servicio web (%1).
		                                                                             |Ha ocurrido un error al leer la descripci??n-WSDL
		                                                                             |del servicio web de la revisi??n de la legalidad de la importaci??n de la actualizaci??n: No hay un art??culo de la descripci??n de los tipos de datos (<wsdl:types ...>).';
		                                                                             |tr = 'Web hizmeti (%1) a????klan??rken bir hata olu??tu.
		                                                                             |Web hizmeti okunurken bir hata olu??tu. G??ncellemeyi indirmenin yasall?????? kontrol eden web servisi
		                                                                             |WSDL a????klamas??n?? okurken bir hata olu??tu: Veri t??r?? a????klama ????esi yok (<wsdl:types ...>).';
		                                                                             |it = 'Si ?? verificato un errore durante la descrizione del web service (%1).
		                                                                             |Si ?? verificato un errore durante la lettura servizio web
		                                                                             |WSDL-descrizione dei controlli di legalit?? dell''importazione aggiornamento: Non esiste alcun tipo di dati descrizione (<wsdl: tipi ...>).';
		                                                                             |de = 'Bei der Beschreibung des Web Service (%1) ist ein Fehler aufgetreten.
		                                                                             |Beim Lesen der Webservice-
		                                                                             |WSDL-Beschreibung der Update-Import-Legalit??tspr??fung ist ein Fehler aufgetreten: Es gibt keine Beschreibung f??r Datentypen (<wsdl: types ...>).'"), WSDLAddress);
		Raise ErrorMessage;
		
	EndIf;
	
	SchemeDescriptionNode = SchemeNodes[0].FirstSubsidiary;
	If SchemeDescriptionNode = Undefined Then
		
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'An error occurred while describing web service (%1).
		                                                                             |An error occurred while reading web service
		                                                                             |WSDL-description of update import legality check: There is no data types description item (<xs:schema ...>)'; 
		                                                                             |ru = '???????????? ?????? ???????????????? ???????????????? ??????-?????????????? (%1).
		                                                                             |???????????? ???????????? WSDL-???????????????? ??????-??????????????
		                                                                             |???????????????? ?????????????????????? ???????????????????? ????????????????????: ?????????????????????? ?????????????? ???????????????? ?????????? ???????????? (<xs:schema ...>)';
		                                                                             |pl = 'Wyst??pi?? b????d podczas opisywania us??ugi webowej (%1).
		                                                                             |Wyst??pi?? b????d podczas odczytu
		                                                                             |opisu WSDL us??ugi weryfikacji legalno??ci importu aktualizacji: Brak pozycji opisu typ??w danych (<xs:schema ...>).';
		                                                                             |es_ES = 'Ha ocurrido un error al describir el servicio web (%1).
		                                                                             |Ha ocurrido un error al leer la descripci??n-WSDL
		                                                                             |del servicio web de la revisi??n de la legalidad de la importaci??n de la actualizaci??n: No hay un art??culo de la descripci??n de los tipos de datos (<xs:schema ...>).';
		                                                                             |es_CO = 'Ha ocurrido un error al describir el servicio web (%1).
		                                                                             |Ha ocurrido un error al leer la descripci??n-WSDL
		                                                                             |del servicio web de la revisi??n de la legalidad de la importaci??n de la actualizaci??n: No hay un art??culo de la descripci??n de los tipos de datos (<xs:schema ...>).';
		                                                                             |tr = 'Web hizmetini (%1) a????klarken bir hata olu??tu. 
		                                                                             | G??ncellemeyi indirmenin yasall??????n?? kontrol eden web servisi 
		                                                                             |WSDL a????klamas??n?? okurken bir hata olu??tu: Veri t??r?? a????klama ????esi yok (<xs:schema ...>)';
		                                                                             |it = 'Si ?? verificato un errore durante la descrizione del web service (%1).
		                                                                             |Si ?? verificato un errore durante la lettura servizio web
		                                                                             |WSDL-descrizione dei controlli di legalit?? dell''importazione aggiornamento: Non esiste alcun elemento di descrizione tipi dati (<xs: schema...>).';
		                                                                             |de = 'Bei der Beschreibung des Webservice (%1) ist ein Fehler aufgetreten.
		                                                                             |Beim Lesen des Webservice
		                                                                             |WSDL-Beschreibung der Update-Import-Legalit??tspr??fung ist ein Fehler aufgetreten: Es gibt keine Datentypen Beschreibungsposition (<xs: schema ...>)'"), WSDLAddress);
		Raise ErrorMessage;
		
	EndIf;
	
	SchemeBuilder = New XMLSchemaBuilder;
	
	Try
		ServiceDataScheme = SchemeBuilder.CreateXMLSchema(SchemeDescriptionNode);
	Except
		
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'An error occurred while describing web service (%1).
		                                                                             |An error occurred while creating data schema from web service
		                                                                             |WSDL-description of update import legality check: %2'; 
		                                                                             |ru = '???????????? ?????? ???????????????? ???????????????? ??????-?????????????? (%1).
		                                                                             |???????????? ?????? ???????????????? ?????????? ???????????? ???? WSDL-????????????????
		                                                                             |??????-?????????????? ???????????????? ?????????????????????? ???????????????????? ????????????????????: %2';
		                                                                             |pl = 'Wyst??pi?? b????d podczas opisywania us??ugi webowej(%1).
		                                                                             |Wyst??pi?? b????d podczas tworzenia schematu danych dla opisu
		                                                                             |WSDL us??ugi webowej weryfikacji legalno??ci importu aktualizacji: %2';
		                                                                             |es_ES = 'Ha ocurrido un error al describir el servicio web (%1).
		                                                                             |Ha ocurrido un error al crear el esquema de datos de la descripci??n-WSDL
		                                                                             |del servicio web de la revisi??n de la legalidad de la importaci??n de la actualizaci??n: %2';
		                                                                             |es_CO = 'Ha ocurrido un error al describir el servicio web (%1).
		                                                                             |Ha ocurrido un error al crear el esquema de datos de la descripci??n-WSDL
		                                                                             |del servicio web de la revisi??n de la legalidad de la importaci??n de la actualizaci??n: %2';
		                                                                             |tr = 'Web hizmeti (%1) a????klan??rken bir hata olu??tu. 
		                                                                             |G??ncellemeyi indirmenin yasall??????n?? kontrol eden web servisi 
		                                                                             |WSDL a????klamas??ndan veri ??emas?? olu??turulurken bir hata olu??tu:%2';
		                                                                             |it = 'Si ?? verificato un errore durante la descrizione del servizio web (%1).
		                                                                             |Si ?? verificato un errore durante la creazione dello schema dati dalla descrizione WSDL
		                                                                             | del servizio web di aggiornamento del controllo di legalit?? di importazione: %2';
		                                                                             |de = 'Bei der Beschreibung des Web-Service (%1) ist ein Fehler aufgetreten.
		                                                                             |Beim Erstellen des Datenschemas aus dem Web-Service
		                                                                             |WSDL-Beschreibung der Update-Import-Legalit??tspr??fung ist ein Fehler aufgetreten: %2'"), WSDLAddress, DetailErrorDescription(ErrorInfo()));
		Raise ErrorMessage;
		
	EndTry;
	
	SchemaSet = New XMLSchemaSet;
	SchemaSet.Add(ServiceDataScheme);
	
	Try
		ServiceFactory = New XDTOFactory(SchemaSet);
	Except
		
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'An error occurred while describing web service (%1).
		                                                                             |An error occurred while creating XDTO factory from web service WSDL-description of update import legality check: %2'; 
		                                                                             |ru = '???????????? ?????? ???????????????? ???????????????? ??????-?????????????? (%1).
		                                                                             |???????????? ?????? ???????????????? ?????????????? XDTO ???? WSDL-???????????????? ??????-?????????????? ???????????????? ?????????????????????? ???????????????????? ????????????????????: %2';
		                                                                             |pl = 'Wyst??pi?? b????d podczas opisywania us??ugi webowej(%1).
		                                                                             |Wyst??pi?? b????d podczas tworzenia fabryki XDTO z us??ugi www opis WSDL sprawdzania legalno??ci importu aktualizacji: %2';
		                                                                             |es_ES = 'Ha ocurrido un error al describir el servicio web (%1).
		                                                                             |Ha ocurrido un error al crear la f??brica XDTO de la descripci??n-WSDL del servicio web de la revisi??n de la legalidad de la importaci??n de la actualizaci??n: %2';
		                                                                             |es_CO = 'Ha ocurrido un error al describir el servicio web (%1).
		                                                                             |Ha ocurrido un error al crear la f??brica XDTO de la descripci??n-WSDL del servicio web de la revisi??n de la legalidad de la importaci??n de la actualizaci??n: %2';
		                                                                             |tr = 'Web hizmeti a????klamas?? olu??turulurken hata olu??tu (%1). 
		                                                                             |G??ncellemeyi indirmenin yasall??????n?? kontrol eden web servisi WSDL a????klamas??ndan XDTO fabrikas??n?? olu??tururken bir hata olu??tu:%2';
		                                                                             |it = 'Si ?? verificato un errore durante la descrizione del web service (%1).
		                                                                             |Si ?? verificato un errore durante la creazione del fattore XDTO dal servizio Web WSDL-descrizione dei controlli di aggiornamento importazione legalit??: %2';
		                                                                             |de = 'Bei der Beschreibung des Web-Service (%1) ist ein Fehler aufgetreten.
		                                                                             |Beim Erstellen der XDTO-Fabrik ??ber die Webservice-WSDL-Beschreibung der Update-Import-Legalit??tspr??fung ist ein Fehler aufgetreten: %2'"),
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
		                                                                             |ru = '???????????? ?????? ???????????????? ???????????????? ??????-?????????????? (%1).
		                                                                             |???????????? ???????????? WSDL-???????????????? ??????-??????????????
		                                                                             |???????????????? ?????????????????????? ???????????????????? ????????????????????: ?????????????????????? URI ???????????????????????? ???????? ?? WSDL-????????????????.';
		                                                                             |pl = 'Wyst??pi?? b????d podczas opisywania us??ugi webowej (%1).
		                                                                             |Wyst??pi?? b????d podczas odczytu
		                                                                             |opisu us??ugi webowej WSDL weryfikacji legalno??ci importu aktualizacji: Brak identyfikatora URI przestrzeni nazw w opisie WSDL.';
		                                                                             |es_ES = 'Ha ocurrido un error al describir el servicio web (%1).
		                                                                             |Ha ocurrido un error al leer la descripci??n-WSDL
		                                                                             |del servicio web de la revisi??n de la legalidad de la importaci??n de la actualizaci??n: No hay URI de espacio de los nombres en la descripci??n-WSDL.';
		                                                                             |es_CO = 'Ha ocurrido un error al describir el servicio web (%1).
		                                                                             |Ha ocurrido un error al leer la descripci??n-WSDL
		                                                                             |del servicio web de la revisi??n de la legalidad de la importaci??n de la actualizaci??n: No hay URI de espacio de los nombres en la descripci??n-WSDL.';
		                                                                             |tr = 'Web hizmeti a????klamas?? olu??turulurken hata olu??tu (%1). 
		                                                                             |G??ncellemeyi indirmenin yasall??????n?? kontrol eden web servisi 
		                                                                             |WSDL a????klamas??n?? okurken hata olu??tu: WSDL a????klamas??nda ad alan??n??n URI''si yok.';
		                                                                             |it = 'Si ?? verificato un errore durante la descrizione del servizio web (%1). 
		                                                                             |Si ?? verificato un errore durante la lettura della descrizione WDSL
		                                                                             | del servizio web di aggiornamento del controllo di legalit?? di importazione: Non c''?? spazio nomi URI nella descrizione WSDL.';
		                                                                             |de = 'Bei der Beschreibung des Web-Service ist ein Fehler aufgetreten (%1).
		                                                                             |Beim Lesen des Webservice
		                                                                             |WSDL-Beschreibung der Update-Import-Legalit??tspr??fung ist ein Fehler aufgetreten: In der WSDL-Beschreibung ist kein Namespace-URI vorhanden.'"), WSDLAddress);
		Raise ErrorMessage;
		
	EndIf;
	
	Result.Insert("OfURIService" , OfURIService);
	
	// Determine address of web service port.
	ServicesNodes = RootElement.GetElementByTagName("wsdl:service");
	If ServicesNodes.Count() = 0 Then
		
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'An error occurred while describing web service (%1).
		                                                                             |An error occurred while reading web service
		                                                                             |WSDL-description of update import legality check: There is no web services description in WSDL-description (<wsdl:service ...>).'; 
		                                                                             |ru = '???????????? ?????? ???????????????? ???????????????? ??????-?????????????? (%1).
		                                                                             |???????????? ???????????? WSDL-???????????????? ??????-?????????????? ???????????????? ?????????????????????? ???????????????????? ????????????????????:
		                                                                             |?????????????????????? ???????????????? ??????-???????????????? ?? WSDL-???????????????? (<wsdl:service ...>).';
		                                                                             |pl = 'Wyst??pi?? b????d podczas opisywania us??ugi webowej (%1).
		                                                                             |Wyst??pi?? b????d podczas odczytu
		                                                                             |opisu WSDL us??ugi webowej weryfikacji legalno??ci importu aktualizacji: Brak opisu us??ugi webowej w opisie WSDL (<wsdl:service ...>).';
		                                                                             |es_ES = 'Ha ocurrido un erro al describir el servicio web (%1).
		                                                                             |Ha ocurrido un error al leer la descripci??n-WSDL
		                                                                             |del servicio web de la revisi??n de la legalidad de la importaci??n de la actualizaci??n: No hay la descripci??n de los servicios web en la descripci??n-WSDL (<wsdl:service ...>).';
		                                                                             |es_CO = 'Ha ocurrido un erro al describir el servicio web (%1).
		                                                                             |Ha ocurrido un error al leer la descripci??n-WSDL
		                                                                             |del servicio web de la revisi??n de la legalidad de la importaci??n de la actualizaci??n: No hay la descripci??n de los servicios web en la descripci??n-WSDL (<wsdl:service ...>).';
		                                                                             |tr = 'Web hizmeti a????klamas?? olu??turulurken hata olu??tu (%1). 
		                                                                             |G??ncellemeyi indirmenin yasall??????n?? kontrol eden web servisi 
		                                                                             |WSDL a????klamas??n?? okurken hata olu??tu: WSDL a????klamas??ndaki web hizmetleri a????klamas?? yok (<wsdl:service ...>).';
		                                                                             |it = 'Si ?? verificato un errore durante la descrizione del servizio web (%1). 
		                                                                             |Si ?? verificato un errore durante la lettura della descrizione WDSL
		                                                                             | del servizio web di aggiornamento del controllo di legalit?? di importazione: Non descrizione del servizio web nella descrizione WSDL(<wsdl:service ...>).';
		                                                                             |de = 'Bei der Beschreibung des Webservice (%1) ist ein Fehler aufgetreten.
		                                                                             |Beim Lesen des Webservice
		                                                                             |WSDL-Beschreibung des Update-Import-Legalit??ts-Checks ist ein Fehler aufgetreten: In der WSDL-Beschreibung (<wsdl: service ...>) gibt es keine Web-Services-Beschreibung.'"), WSDLAddress);
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
			     |ru = '???????????? ?????? ???????????????? ???????????????? ??????-?????????????? (%1).
			     |???????????? ???????????? WSDL-???????????????? ??????-?????????????? ???????????????? ?????????????????????? ???????????????????? ????????????????????:
			     |?????????????????????? ???????????????? ???????????? ?? WSDL-???????????????? (<wsdl:port ...>).';
			     |pl = 'Wyst??pi?? b????d podczas opisywania us??ugi webowej (%1).
			     |Wyst??pi?? b????d podczas odczytu
			     |opisu WSDL us??ugi webowej weryfikacji legalno??ci importu aktualizacji: W opisie WSDL brak opisu port??w (<wsdl:port ...>).';
			     |es_ES = 'Ha ocurrido un error al describir el servicio web (%1).
			     |Ha ocurrido un error al leer la descripci??n-WSDL
			     |del servicio web de la revisi??n de la legalidad de la importaci??n de la actualizaci??n: No hay la descripci??n de puertos en la descripci??n-WSDL (<wsdl:port ...>).';
			     |es_CO = 'Ha ocurrido un error al describir el servicio web (%1).
			     |Ha ocurrido un error al leer la descripci??n-WSDL
			     |del servicio web de la revisi??n de la legalidad de la importaci??n de la actualizaci??n: No hay la descripci??n de puertos en la descripci??n-WSDL (<wsdl:port ...>).';
			     |tr = 'Web hizmeti a????klamas?? olu??turulurken hata olu??tu (%1).
			     |G??ncellemeyi indirmenin yasall??????n?? kontrol eden web servisi 
			     |WSDL a????klamas??n?? okurken hata olu??tu: WSDL a????klamas??nda ba??lant?? noktas?? a????klamas?? yok (<wsdl:port ...>).';
			     |it = 'Si ?? verificato un errore durante la descrizione del servizio web (%1). 
			     |Si ?? verificato un errore durante la lettura della descrizione WDSL
			     | del servizio web di aggiornamento del controllo di legalit?? di importazione: Non descrizione delle porte nella descrizione WSDL(<wsdl:port ...>).';
			     |de = 'Bei der Beschreibung des Web Service (%1) ist ein Fehler aufgetreten.
			     |Beim Lesen des Webservice
			     |WSDL-Beschreibung der Update-Import-Legalit??tspr??fung ist ein Fehler aufgetreten: Es gibt keine Beschreibung der Ports in WSDL-description (<wsdl: port ...>).'"), 
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
			     |ru = '???????????? ?????? ???????????????? ???????????????? ??????-?????????????? (%1).
			     |???????????? ???????????? WSDL-???????????????? ??????-?????????????? ????????????????-?????????????????? ??????????????????????????:
			     |???? ?????????????? ???????????????????? ?????? ?????????? ?????????????? (%2).';
			     |pl = 'Wyst??pi?? b????d podczas tworzenia opisu us??ugi webowej (%1).
			     | Wyst??pi?? b????d podczas odczytu
			     |opisu WSDL us??ugi webowej obs??ugi u??ytkownik??w online: Nie mo??na ustali?? nazwy portu serwisu (%2).';
			     |es_ES = 'Ha ocurrido un error al crear la descripci??n del servicio web (%1).
			     |Ha ocurrido un error al leer
			     |la descripci??n-WSDL del servicio web del soporte de usuario online: No se puede determinar el nombre del puerto del servicio (%2).';
			     |es_CO = 'Ha ocurrido un error al crear la descripci??n del servicio web (%1).
			     |Ha ocurrido un error al leer
			     |la descripci??n-WSDL del servicio web del soporte de usuario online: No se puede determinar el nombre del puerto del servicio (%2).';
			     |tr = 'Web hizmeti a????klamas?? olu??turulurken hata olu??tu (%1). 
			     |??evrim i??i ??nternet kullan??c??lar??n??n 
			     |web servisi WSDL a????klamas??n?? okurken bir hata olu??tu: Servis portu ismi tespit edilemedi (%2).';
			     |it = 'Un errore si ?? registrato durante la creazione della descrizione web service (%1).
			     |Un errore si ?? registrato durante la lettura del
			     |web service WSDL-desrizione del supporto online: Non ?? possibile determinare il nome della porta di servizio (%2).';
			     |de = 'Beim Erstellen der Webservice-Beschreibung ist ein Fehler aufgetreten (%1).
			     |Ein Fehler beim Lesen der
			     |Webservice WSDL-Beschreibung der Online-Benutzerunterst??tzung ist aufgetreten: Der Service-Port-Name (%2) konnte nicht ermittelt werden.'"), 
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
		                                                                             |ru = '???????????? ?????? ???????????????? ???????????????? ??????-?????????????? (%1).
		                                                                             |???????????? ???????????? WSDL-????????????????
		                                                                             |??????-?????????????? ????????????????-?????????????????? ??????????????????????????: ???? ?????????????? ???????????????????? URL ?????????????????? ?????????? ?????????????? (%2).';
		                                                                             |pl = 'Wyst??pi?? b????d podczas opisywania us??ugi webowej (%1).
		                                                                             |Wyst??pi?? b????d podczas odczytywania
		                                                                             |opisu WSDL us??ugi webowej obs??ugi u??ytkownik??w online: Nie mo??na okre??li?? adresu URL okre??lonego portu serwisu(%2).';
		                                                                             |es_ES = 'Ha ocurrido un error al describir el servicio web (%1).
		                                                                             |Ha ocurrido un error al leer la descripci??n-WSDL del servicio web
		                                                                             | del soporte de usuario online: No se puede determinar URL del puerto especificado de servicio (%2).';
		                                                                             |es_CO = 'Ha ocurrido un error al describir el servicio web (%1).
		                                                                             |Ha ocurrido un error al leer la descripci??n-WSDL del servicio web
		                                                                             | del soporte de usuario online: No se puede determinar URL del puerto especificado de servicio (%2).';
		                                                                             |tr = 'Web hizmeti a????klamas?? olu??turulurken hata olu??tu (%1). 
		                                                                             |??evrimi??i kullan??c?? destek hizmeti 
		                                                                             |WSDL a????klamas??n?? okurken bir hata olu??tu: Belirtilen hizmet portunun URL''si belirlenemedi (%2).';
		                                                                             |it = 'Si ?? verificato un errore durante la descrizione del servizio web (%1).
		                                                                             |Si ?? verificato un errore durante la lettura
		                                                                             |della descrizione WSDL del servizio web dell''assistenza clienti online: Impossibile determinare l''URL della porta specificata del servizio (%2).';
		                                                                             |de = 'Bei der Beschreibung des Webservice (%1) ist ein Fehler aufgetreten.
		                                                                             |Beim Lesen der Webservice
		                                                                             |WSDL-Beschreibung der Online-Benutzerunterst??tzung ist ein Fehler aufgetreten: Die URL des vom Service angegebenen Ports (%2) konnte nicht ermittelt werden.'"), WSDLAddress, PortName);
		
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
		
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'An error occurred when calling operation isReady of service (%1): %2'; ru = '???????????? ?????? ???????????? ???????????????? isReady ?????????????? (%1): %2';pl = 'Wyst??pi?? b????d podczas wywo??ywania operacji isReady serwisu (%1): %2';es_ES = 'Ha ocurrido un error al llamar la operaci??n est??Preparado del servicio (%1): %2';es_CO = 'Ha ocurrido un error al llamar la operaci??n est??Preparado del servicio (%1): %2';tr = 'Servisin isReady i??lemi ??a??r??l??rken bir hata olu??tu (%1): %2';it = 'Si ?? verificato un errore durante la chiamata al servizio isReady (%1): %2';de = 'Beim Aufrufen der Operation isReady (%1) ist ein Fehler aufgetreten: %2'"),
			LegalityCheckServiceDescription.WSDLAddress, DetailErrorDescription(ErrorInfo()));
		Raise ErrorMessage;
		
	EndTry;
	
	ObjectType = LegalitySeviceFactoryRootPropertyValueType("isReadyResponse", LegalityCheckServiceDescription);
	If ObjectType = Undefined Then
		ErrorMessage = StrReplace(NStr("en = 'An error occurred while calling the isReady operation of service (%1).
		                               |Unable to define the type of the isReadyResponse root property.'; 
		                               |ru = '???????????? ?????? ???????????? ???????????????? isReady ?????????????? (%1).
		                               |???? ?????????????? ???????????????????? ?????? ?????????????????? ???????????????? isReadyResponse.';
		                               |pl = 'Wyst??pi?? b????d podczas wywo??ywania operacji isReady us??ugi (%1).
		                               |Nie mo??na zdefiniowa?? typu w??a??ciwo??ci g????wnej isReadyResponse w czasie odpowiedzi.';
		                               |es_ES = 'Ha ocurrido un error al llamar la operaci??n est??Preparado del servicio (%1).
		                               |No se puede definir el tipo de la propiedad ra??z est??PreparadaRespuesta.';
		                               |es_CO = 'Ha ocurrido un error al llamar la operaci??n est??Preparado del servicio (%1).
		                               |No se puede definir el tipo de la propiedad ra??z est??PreparadaRespuesta.';
		                               |tr = 'Servisin isReady i??lemi ??a??r??l??rken bir hata olu??tu (%1). 
		                               |??sReadyResponse''nin k??k ??zelli??inin t??r?? belirlenemedi';
		                               |it = 'Si ?? verificato un errore durante la chiamata dell''operazione isReady del servizio (%1).
		                               |Impossibile definire il tipo di propriet?? radice isReadyResponse.';
		                               |de = 'Beim Aufrufen der Operation ist dienstbereit (%1) ist ein Fehler aufgetreten.
		                               |Der Typ der Root-Eigenschaft isReady Response konnte nicht definiert werden.'"),
			"%1",
			LegalityCheckServiceDescription.WSDLAddress);
		Raise ErrorMessage;
	EndIf;
	
	Try
		Value = ReadResponseInSOAPEnvelope(ResponseBody, LegalityCheckServiceDescription, ObjectType);
	Except
		ErrorMessage = StrReplace(NStr("en = 'An error occurred when calling operation isReady of service (%1).'; ru = '???????????? ?????? ???????????? ???????????????? isReady ?????????????? (%1).';pl = 'Wyst??pi?? b????d podczas wywo??ywania operacji isReady serwisu (%1).';es_ES = 'Ha ocurrido un error al llamar la operaci??n est??Preparado del servicio (%1).';es_CO = 'Ha ocurrido un error al llamar la operaci??n est??Preparado del servicio (%1).';tr = 'isReady''nin k??k ??zelli??inin t??r?? belirlenemedi (%1).';it = 'Si ?? verificato un errore durante la chiamata al servizio isReady (%1).';de = 'Beim Aufrufen der Operation isReady (%1) ist ein Fehler aufgetreten.'"),
			"%1",
			LegalityCheckServiceDescription.WSDLAddress)
			+ Chars.LF
			+ DetailErrorDescription(ErrorInfo())
			+ Chars.LF + Chars.LF
			+ NStr("en = 'Query body:'; ru = '???????? ??????????????:';pl = 'Zawarto???? zapytania:';es_ES = 'Cuerpo de la solicitud:';es_CO = 'Cuerpo de la solicitud:';tr = 'Sorgu g??vdesi:';it = 'Corpo della Query:';de = 'Abfragek??rper:'")
			+ Chars.LF
			+ EnvelopeText;
		
		Raise ErrorMessage;
	EndTry;
	
	If TypeOf(Value) = Type("Structure") Then
		
		// Description of SOAP exception is returned.
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'An error occurred while calling the
		                                                                             |isReady operation of service (%1) SOAP error: %2'; 
		                                                                             |ru = '???????????? ?????? ???????????? ????????????????
		                                                                             |isReady ?????????????? (%1) ???????????? SOAP: %2';
		                                                                             |pl = 'Wyst??pi?? b????d podczas wywo??ywania operacji
		                                                                             |isReady serwisu (%1) SOAP: %2';
		                                                                             |es_ES = 'Ha ocurrido un error al llamar la
		                                                                             |operaci??n est??Preparado del servicio (%1) SOAP error: %2';
		                                                                             |es_CO = 'Ha ocurrido un error al llamar la
		                                                                             |operaci??n est??Preparado del servicio (%1) SOAP error: %2';
		                                                                             |tr = 'Servisin 
		                                                                             |isReady i??lemi ??a??r??l??rken bir hata olu??tu (%1) SOAP hatas??: %2';
		                                                                             |it = 'Si ?? verificato un errore durante la chiamata alla
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
		
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'An error occurred when calling operation process of service (%1): %2'; ru = '???????????? ?????? ???????????? ???????????????? process ?????????????? (%1): %2';pl = 'Wyst??pi?? b????d podczas wywo??ywania operacji process serwisu (%1): %2';es_ES = 'Ha ocurrido un error al llamar el proceso de la operaci??n del servicio (%1): %2';es_CO = 'Ha ocurrido un error al llamar el proceso de la operaci??n del servicio (%1): %2';tr = 'Servisin process i??lemi ??a??r??l??rken bir hata olu??tu (%1): %2';it = 'Si ?? verificato un errore durante la chiamata al processo di servizio  (%1): %2';de = 'Beim Aufruf des Operationsprozesses von Service ist ein Fehler aufgetreten (%1): %2'"),
			LegalityCheckServiceDescription.WSDLAddress, DetailErrorDescription(ErrorInfo()));
		Raise ErrorMessage;
		
	EndTry;
	
	ObjectType = LegalitySeviceFactoryRootPropertyValueType("processResponse", LegalityCheckServiceDescription);
	If ObjectType = Undefined Then
		ErrorMessage = StrReplace(NStr("en = 'An error occurred while calling the process operation of service (%1).
		                               |Unable to define the type of the processResponse root property.'; 
		                               |ru = '???????????? ?????? ???????????? ???????????????? process ?????????????? (%1).
		                               |???? ?????????????? ???????????????????? ?????? ?????????????????? ???????????????? processResponse.';
		                               |pl = 'Wyst??pi?? b????d podczas wywo??ywania operacji procesu us??ugi (%1).
		                               |Nie mo??na zdefiniowa?? typu w??a??ciwo??ci g????wnej processResponse w czasie odpowiedzi.';
		                               |es_ES = 'Ha ocurrido un error al llamar la operaci??n de proceso del servicio (%1).
		                               |No se puede definir el tipo de la propiedad ra??z procesarRespuesta.';
		                               |es_CO = 'Ha ocurrido un error al llamar la operaci??n de proceso del servicio (%1).
		                               |No se puede definir el tipo de la propiedad ra??z procesarRespuesta.';
		                               |tr = 'Servisin process i??lemi ??a??r??l??rken bir hata olu??tu (%1). 
		                               |??sReadyResponse''nin k??k ??zelli??inin t??r?? belirlenemedi';
		                               |it = 'Si ?? verificato un errore durante la chiamata della operazione di servizio (%1).
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
		
		ErrorMessage = StrReplace(NStr("en = 'An error occurred when calling operation process of service (%1).'; ru = '???????????? ?????? ???????????? ???????????????? process ?????????????? (%1).';pl = 'Wyst??pi?? b????d podczas wywo??ywania operacji procesu serwisu (%1).';es_ES = 'Ha ocurrido un error al llamar el proceso de la operaci??n del servicio (%1).';es_CO = 'Ha ocurrido un error al llamar el proceso de la operaci??n del servicio (%1).';tr = 'Servisin process i??lemi ??a??r??l??rken bir hata olu??tu (%1).';it = 'Si ?? verificato un errore durante la chiamata al processo di servizio (%1).';de = 'Beim Aufruf des Operationsprozesses von Service (%1) ist ein Fehler aufgetreten.'"),
			"%1",
			LegalityCheckServiceDescription.WSDLAddress)
			+ Chars.LF
			+ DetailErrorDescription(ErrorInfo())
			+ Chars.LF + Chars.LF
			+ NStr("en = 'Query body:'; ru = '???????? ??????????????:';pl = 'Zawarto???? zapytania:';es_ES = 'Cuerpo de la solicitud:';es_CO = 'Cuerpo de la solicitud:';tr = 'Sorgu g??vdesi:';it = 'Corpo della Query:';de = 'Abfragek??rper:'")
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
		ErrorMessage = NStr("en = 'A connection error occurred when sending a SOAP query.'; ru = '???????????? ???????????????? ???????????????????? ?????? ???????????????? SOAP-??????????????.';pl = 'Wyst??pi?? b????d po????czenia podczas wysy??ania zapytania SOAP.';es_ES = 'Ha ocurrido un error de conexi??n al enviar una solicitud SOAP.';es_CO = 'Ha ocurrido un error de conexi??n al enviar una solicitud SOAP.';tr = 'SOAP sorgusu g??nderilirken ba??lant?? hatas?? olu??tu.';it = 'Si ?? verificato un errore di connessione durante l''invio di una query SOAP.';de = 'Beim Senden einer SOAP-Abfrage ist ein Verbindungsfehler aufgetreten.'")
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
		                                                                             |ru = '????????????
		                                                                             |????????????
		                                                                             |???????????? SOAP:
		                                                                             |%1 ???????? ????????????: %2';
		                                                                             |pl = 'Wyst??pi?? b????d
		                                                                             |podczas
		                                                                             |odczytu SOAP:
		                                                                             |%1 Zawarto???? odpowiedzi: %2';
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
		                                                                             | bir hata olu??tu: 
		                                                                             |%1 Yan??t g??vdesi: %2';
		                                                                             |it = 'Si ?? verificato un errore
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
			                                                                             |ru = '????????????
			                                                                             |????????????
			                                                                             |???????????? SOAP:
			                                                                             |%1 ???????? ????????????: %2';
			                                                                             |pl = 'Wyst??pi?? b????d
			                                                                             |podczas
			                                                                             |odczytu SOAP:
			                                                                             |%1 Zawarto???? odpowiedzi: %2';
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
			                                                                             | bir hata olu??tu: 
			                                                                             |%1 Yan??t g??vdesi: %2';
			                                                                             |it = 'Si ?? verificato un errore
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
			NStr("en = 'The SOAP-server error occurred when processing the query: %1'; ru = '???????????? SOAP-?????????????? ?????? ?????????????????? ??????????????: %1';pl = 'Wyst??pi?? b????d serwera SOAP podczas przetwarzania zapytania: %1';es_ES = 'Ha ocurrido el error del servidor-SOAP al procesar la solicitud: %1';es_CO = 'Ha ocurrido el error del servidor-SOAP al procesar la solicitud: %1';tr = 'Sorgu i??lenirken SOAP sunucusu hatas?? olu??tu: %1';it = 'Errore del server SOAP durante l''elaborazione della richiesta: %1';de = 'Der SOAP-Server-Fehler ist bei der Verarbeitung der Abfrage aufgetreten: %1'"), DescriptionSOAPExceptionToRow(ExceptionDetails));
		Raise ErrorMessage;
		
	EndIf;
	
	Try
		Value = LegalityCheckServiceDescription.XDTOFactory.ReadXML(ResponseReading, ValueType);
	Except
		
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'An error occurred while reading object
		                                                                             |(%1)
		                                                                             |in the
		                                                                             |SOAP envelope: %2 Response body: %3'; 
		                                                                             |ru = '???????????? ???????????? ??????????????
		                                                                             |(%1)
		                                                                             |?? ????????????????
		                                                                             |SOAP: %2 ???????? ????????????: %3';
		                                                                             |pl = 'Wyst??pi?? b????d podczas odczytu obiektu 
		                                                                             |(%1)
		                                                                             | w kopercie
		                                                                             |SOAP: %2 Zawarto???? odpowiedzi: %3';
		                                                                             |es_ES = 'Ha ocurrido un error al leer el objeto
		                                                                             |(%1)
		                                                                             |en el
		                                                                             |sobre SOAP: %2 Cuerpo de la respuesta: %3';
		                                                                             |es_CO = 'Ha ocurrido un error al leer el objeto
		                                                                             |(%1)
		                                                                             |en el
		                                                                             |sobre SOAP: %2 Cuerpo de la respuesta: %3';
		                                                                             |tr = 'SOAP zarf??nda nesne
		                                                                             | (%1) 
		                                                                             |okunurken%2 bir hata olu??tu: 
		                                                                             |Yan??t g??vdesi:%3';
		                                                                             |it = 'Si ?? verificato un errore durante la lettura dell''oggetto
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
		Result = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Error code: %1'; ru = '?????? ????????????: %1';pl = 'Kod b????du: %1';es_ES = 'C??digo de error: %1';es_CO = 'C??digo de error: %1';tr = 'Hata kodu: %1';it = 'Codice errore: %1';de = 'Fehlercode: %1'"), ExceptionSOAP.FaultCode);
	EndIf;
	
	If Not IsBlankString(ExceptionSOAP.FaultString) Then
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Error line: %1'; ru = '???????????? ????????????: %1';pl = 'Wiersz b????du: %1';es_ES = 'L??nea de error: %1';es_CO = 'L??nea de error: %1';tr = 'Hata sat??r??: %1';it = 'Linea errore: %1';de = 'Fehlerzeile: %1'"), ExceptionSOAP.FaultString);
		Result = Result + Chars.LF + ErrorText;
	EndIf;
	
	If Not IsBlankString(ExceptionSOAP.FaultActor) Then
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Error source: %1'; ru = '???????????????? ????????????: %1';pl = '??r??d??o b????du: %1';es_ES = 'Fuente de error: %1';es_CO = 'Fuente de error: %1';tr = 'Hata kayna????: %1';it = 'Fonte dell''errore: %1';de = 'Fehlerquelle: %1'"), ExceptionSOAP.FaultActor);
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
