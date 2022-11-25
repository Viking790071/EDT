#Region Variables

&AtClient
Var WriteSettings, MinDateOfNextAutomaticBackup;

#EndRegion

#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If Not CommonClientServer.IsWindowsClient() Then
		Raise NStr("ru = 'Резервное копирование и восстановление данных необходимо настроить средствами операционной системы или другими сторонними средствами.'; en = 'Set up data backup and recovery by using the operating system tools or other third-party tools.'; pl = 'Tworzenie kopii zapasowych i odzyskiwanie danych muszą być konfigurowane za pomocą systemu operacyjnego lub innych narzędzi stron trzecich.';es_ES = 'Es necesario ajustar la creación de las copias de respaldo y la restauración de los datos con los recursos del sistema operativo o con otros recursos terceros.';es_CO = 'Es necesario ajustar la creación de las copias de respaldo y la restauración de los datos con los recursos del sistema operativo o con otros recursos terceros.';tr = 'Veri yedekleme ve geri yükleme, işletim sistemin araçları veya diğer üçüncü taraf araçları tarafından yapılandırılmalıdır.';it = 'Il backup e il recupero dei dati devono essere configurati tramite gli strumenti del sistema operativo o altri strumenti esterni.';de = 'Die Sicherung und Wiederherstellung von Daten muss mit dem Betriebssystem oder anderen Tools von Drittanbietern konfiguriert werden.'");
	EndIf;
	
	If CommonClientServer.IsWebClient() Then
		Raise NStr("ru = 'Резервное копирование недоступно в веб-клиенте.'; en = 'Backup is not available in web client.'; pl = 'Kopia zapasowa nie jest dostępna w kliencie www.';es_ES = 'Copia de respaldo no se encuentra disponible en el cliente web.';es_CO = 'Copia de respaldo no se encuentra disponible en el cliente web.';tr = 'Yedekleme web istemcisinde mevcut değildir.';it = 'Backup non è disponibile in client web.';de = 'Die Sicherung ist im Webclient nicht verfügbar.'");
	EndIf;
	
	BackupSettings = IBBackupServer.BackupSettings();
	
	Object.ExecutionOption = BackupSettings.ExecutionOption;
	Object.RunAutomaticBackup = BackupSettings.RunAutomaticBackup;
	Object.BackupConfigured = BackupSettings.BackupConfigured;
	
	If Not Object.BackupConfigured Then
		Object.RunAutomaticBackup = True;
	EndIf;
	IsBaseConfigurationVersion = StandardSubsystemsServer.IsBaseConfigurationVersion();
	Items.Normal.Visible = Not IsBaseConfigurationVersion;
	Items.Basic.Visible = IsBaseConfigurationVersion;
	
	IBAdministratorPassword = BackupSettings.IBAdministratorPassword;
	Schedule = CommonClientServer.StructureToSchedule(BackupSettings.CopyingSchedule);
	Items.EditSchedule.Title = String(Schedule);
	Object.BackupDirectory = BackupSettings.BackupsStorageDirectory;
	
	// Filling settings for storing old copies.
	
	FillPropertyValues(Object, BackupSettings.DeletionParameters);
	
	UpdateBackupDirectoryRestrictionType(ThisObject);
	
	UserInformation = IBBackupServer.UserInformation();
	PasswordRequired = UserInformation.PasswordRequired;
	If PasswordRequired Then
		IBAdministrator = UserInformation.Name;
	Else
		Items.AuthorizationGroup.Visible = False;
		Items.InfobaseAdministratorAuthorization.Visible = False;
		IBAdministratorPassword = "";
	EndIf;
	
	SetVisibilityAvailability();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	IBParameters = ApplicationParameters["StandardSubsystems.IBParameters"];
	
	MinDateOfNextAutomaticBackup = IBParameters.MinDateOfNextAutomaticBackup;
	IBParameters.MinDateOfNextAutomaticBackup = '29990101';
	WriteSettings = False;
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If WriteSettings Then
		ParameterName = "IBBackupOnExit";
		ParametersOnExit = New Structure(StandardSubsystemsClient.ClientParameter(ParameterName));
		ParametersOnExit.ExecuteOnExit = Object.RunAutomaticBackup
			AND Object.ExecutionOption = "OnExit";
		ParametersOnExit = New FixedStructure(ParametersOnExit);
		StandardSubsystemsClient.SetClientParameter(ParameterName, ParametersOnExit);
	Else
		ParameterName = "StandardSubsystems.IBParameters";
		ApplicationParameters[ParameterName].MinDateOfNextAutomaticBackup
			= MinDateOfNextAutomaticBackup;
	EndIf;
	
	If Exit Then
		Return;
	EndIf;
	
	Notify("BackupSettingsFormClosed");
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure RunAutomaticBackupOnChange(Item)
	
	SetVisibilityAvailability();
	
EndProcedure

&AtClient
Procedure BackupDirectoryRestrictionTypeOnChange(Item)
	
	
	UpdateBackupDirectoryRestrictionType(ThisObject);
	
EndProcedure

&AtClient
Procedure PathToArchiveDirectoryStartChoice(Item, ChoiceData, StandardProcessing)
	
	OpenFileDialog = New FileDialog(FileDialogMode.ChooseDirectory);
	OpenFileDialog.Title= NStr("ru = 'Выберите каталог для сохранения резервных копий'; en = 'Select a directory to save backups to'; pl = 'Wybierz katalog dla kopii zapasowych';es_ES = 'Seleccione un catálogo para guardar las copias de respaldo';es_CO = 'Seleccione un catálogo para guardar las copias de respaldo';tr = 'Yedeklerin kaydedileceği klasörü seç';it = 'Seleziona una cartella in cui salvare i backup.';de = 'Wählen Sie ein Verzeichnis zum Speichern von Sicherungen aus'");
	OpenFileDialog.Directory = Items.BackupDirectory.EditText;
	
	If OpenFileDialog.Choose() Then
		Object.BackupDirectory = OpenFileDialog.Directory;
	EndIf;
	
EndProcedure

// Handler of transfer to the event log.
&AtClient
Procedure LabelGoToEventLogClick(Item)
	OpenForm("DataProcessor.EventLog.Form.EventLog", , ThisObject);
EndProcedure

&AtClient
Procedure BackupOptionOnChange(Item)
	
	Items.EditSchedule.Enabled = (Object.ExecutionOption = "Schedule");
	
EndProcedure

&AtClient
Procedure BackupStoragePeriodUOMClear(Item, StandardProcessing)
	
	StandardProcessing = False;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Finish(Command)
	
	WriteSettings = True;
	GoFromSettingPage();
	
EndProcedure

// Calls a standard scheduled job settings form and fills it with the current backup schedule 
// settings.
&AtClient
Procedure EditSchedule(Command)
	
	ScheduleDialog = New ScheduledJobDialog(Schedule);
	NotifyDescription = New NotifyDescription("ChangeScheduleCompletion", ThisObject);
	ScheduleDialog.Show(NotifyDescription);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure GoFromSettingPage()
	
	IBParameters = ApplicationParameters["StandardSubsystems.IBParameters"];
	CurrentUser = UsersClientServer.CurrentUser();
	
	If Object.RunAutomaticBackup Then
		
		If Not CheckDirectoryWithBackups() Then
			Return;
		EndIf;
		
		AttachmentResult = IBBackupClient.CheckAccessToInfobase(IBAdministratorPassword);
		If AttachmentResult.AddInAttachmentError Then
			Items.WizardPages.CurrentPage = Items.AdditionalSettings;
			ConnectionErrorFound = AttachmentResult.BriefErrorDescription;
			Return;
		EndIf;
		
		WriteSettings(CurrentUser);
		
		If Object.ExecutionOption = "Schedule" Then
			CurrentDate = CommonClient.SessionDate();
			IBParameters.MinDateOfNextAutomaticBackup = CurrentDate;
			IBParameters.LatestBackupDate = CurrentDate;
			IBParameters.ScheduleValue = Schedule;
		ElsIf Object.ExecutionOption = "OnExit" Then
			IBParameters.MinDateOfNextAutomaticBackup = '29990101';
		EndIf;
		
		IBBackupClient.AttachIdleBackupHandler();
		
		SettingFormName = "e1cib/app/DataProcessor.IBBackupSetup/";
		
		ShowUserNotification(NStr("ru = 'Резервное копирование'; en = 'Backup'; pl = 'Kopia zapasowa';es_ES = 'Copia de respaldo';es_CO = 'Copia de respaldo';tr = 'Yedek';it = 'Creazione backup';de = 'Sicherungskopie'"), SettingFormName,
			NStr("ru = 'Резервное копирование настроено.'; en = 'Backup is set up.'; pl = 'Kopia zapasowa została skonfigurowana';es_ES = 'Copia de respaldo se ha configurado.';es_CO = 'Copia de respaldo se ha configurado.';tr = 'Yedekleme ayarlandı.';it = 'Backup impostato.';de = 'Die Sicherung ist eingerichtet.'"));
		
	Else
		
		StopNotificationService(CurrentUser);
		IBBackupClient.DisableBackupIdleHandler();
		IBParameters.MinDateOfNextAutomaticBackup = '29990101';
		
	EndIf;
	
	IBParameters.NotificationParameter = "DoNotNotify";
	
	RefreshReusableValues();
	Close();
	
EndProcedure

&AtClient
Function CheckDirectoryWithBackups()
	
#If WebClient OR MobileClient Then
	MessageText = NStr("ru = 'Для корректной работы необходим режим тонкого или толстого клиента.'; en = 'Thin or thick client mode is required.'; pl = 'Aby wszystko działało poprawnie, potrzebujesz cienkiego lub grubego trybu klienta.';es_ES = 'Para el funcionamiento correcto es necesario el modo del cliente ligero o grueso.';es_CO = 'Para el funcionamiento correcto es necesario el modo del cliente ligero o grueso.';tr = 'Doğu çalışma için ince veya kalın istemci modu gerekmektedir.';it = 'È richiesta la modalità thin o thick client.';de = 'Für den korrekten Betrieb ist der Thin- oder Thick-Client-Modus erforderlich.'");
	CommonClientServer.MessageToUser(MessageText);
	AttributesFilled = False;
#Else
	AttributesFilled = True;
	
	If IsBlankString(Object.BackupDirectory) Then
		
		MessageText = NStr("ru = 'Не выбран каталог для резервной копии.'; en = 'Backup directory is not selected.'; pl = 'Nie wybrano katalogu dla kopii rezerwowej.';es_ES = 'Directorio de la copia de respaldo no se ha seleccionado.';es_CO = 'Directorio de la copia de respaldo no se ha seleccionado.';tr = 'Yedekleme dizini seçilmedi.';it = 'La directory di backup non è selezionata.';de = 'Sicherungsverzeichnis ist nicht ausgewählt.'");
		CommonClientServer.MessageToUser(MessageText,, "Object.BackupDirectory");
		AttributesFilled = False;
		
	ElsIf FindFiles(Object.BackupDirectory).Count() = 0 Then
		
		MessageText = NStr("ru = 'Указан несуществующий каталог.'; en = 'Non-existing directory is specified.'; pl = 'Podano nieistniejący katalog.';es_ES = 'Directorio no existente está especificado.';es_CO = 'Directorio no existente está especificado.';tr = 'Mevcut olmayan dizin belirlendi.';it = 'E'' specificata una directory non-esistente.';de = 'Nicht existierendes Verzeichnis ist angegeben.'");
		CommonClientServer.MessageToUser(MessageText,, "Object.BackupDirectory");
		AttributesFilled = False;
		
	Else
		
		Try
			TestFile = New XMLWriter;
			TestFile.OpenFile(Object.BackupDirectory + "/test.test1C");
			TestFile.WriteXMLDeclaration();
			TestFile.Close();
		Except
			MessageText = NStr("ru = 'Нет доступа к каталогу с резервными копиями.'; en = 'Cannot access directory with backups.'; pl = 'Nie można uzyskać dostępu do katalogu z kopiami zapasowymi.';es_ES = 'No se puede acceder el directorio con copias de respaldo.';es_CO = 'No se puede acceder el directorio con copias de respaldo.';tr = 'Dizine yedeklerle erişilemiyor.';it = 'Non è possibile accedere alla directory con i backup.';de = 'Zugriff auf das Verzeichnis mit Sicherungen nicht möglich.'");
			CommonClientServer.MessageToUser(MessageText,, "Object.BackupDirectory");
			AttributesFilled = False;
		EndTry;
		
		If AttributesFilled Then
			
			Try
				DeleteFiles(Object.BackupDirectory, "*.test1C");
			Except
				// The exception is not processed as files are not deleted at this step.
			EndTry;
			
		EndIf;
		
	EndIf;
	
	If PasswordRequired AND IsBlankString(IBAdministratorPassword) Then
		
		MessageText = NStr("ru = 'Не задан пароль администратора.'; en = 'Administrator password is not specified.'; pl = 'Hasło administratora nie zostało określone.';es_ES = 'Contraseña del administrador no está especificada.';es_CO = 'Contraseña del administrador no está especificada.';tr = 'Yönetici şifresi belirtilmemiş.';it = 'La password dell''amministratore non è specificata';de = 'Administrator-Kennwort ist nicht angegeben.'");
		CommonClientServer.MessageToUser(MessageText,, "IBAdministratorPassword");
		AttributesFilled = False;
		
	EndIf;

#EndIf
	
	Return AttributesFilled;
	
EndFunction

&AtServerNoContext
Procedure StopNotificationService(CurrentUser)
	// Stops notifications of backup.
	BackupSettings = IBBackupServer.BackupSettings();
	BackupSettings.RunAutomaticBackup = False;
	BackupSettings.BackupConfigured = True;
	BackupSettings.MinDateOfNextAutomaticBackup = '29990101';
	IBBackupServer.SetBackupParemeters(BackupSettings, CurrentUser);
EndProcedure

&AtServer
Procedure WriteSettings(CurrentUser)
	
	IsBaseConfigurationVersion = StandardSubsystemsServer.IsBaseConfigurationVersion();
	If IsBaseConfigurationVersion Then
		Object.ExecutionOption = "OnExit";
	EndIf;
	
	BackupParameters = IBBackupServer.BackupParameters();
	
	BackupParameters.Insert("IBAdministrator", IBAdministrator);
	BackupParameters.Insert("IBAdministratorPassword", ?(PasswordRequired, IBAdministratorPassword, ""));
	BackupParameters.LastNotificationDate = Date('29990101');
	BackupParameters.BackupsStorageDirectory = Object.BackupDirectory;
	BackupParameters.ExecutionOption = Object.ExecutionOption;
	BackupParameters.RunAutomaticBackup = Object.RunAutomaticBackup;
	BackupParameters.BackupConfigured = True;
	
	FillPropertyValues(BackupParameters.DeletionParameters, Object);
	
	If Object.ExecutionOption = "Schedule" Then
		
		ScheduleStructure = CommonClientServer.ScheduleToStructure(Schedule);
		BackupParameters.CopyingSchedule = ScheduleStructure;
		BackupParameters.MinDateOfNextAutomaticBackup = CurrentSessionDate();
		BackupParameters.LatestBackupDate = CurrentSessionDate();
		
	ElsIf Object.ExecutionOption = "OnExit" Then
		
		BackupParameters.MinDateOfNextAutomaticBackup = '29990101';
		
	EndIf;
	
	IBBackupServer.SetBackupParemeters(BackupParameters, CurrentUser);
	
EndProcedure

&AtClientAtServerNoContext
Procedure UpdateBackupDirectoryRestrictionType(Form)
	
	Form.Items.GroupStoreLastBackupsForPeriod.Enabled = (Form.Object.RestrictionType = "ByPeriod");
	Form.Items.BackupsCountInDirectoryGroup.Enabled = (Form.Object.RestrictionType = "ByCount");
	
EndProcedure

&AtClient
Procedure ChangeScheduleCompletion(ScheduleResult, AdditionalParameters) Export
	
	If ScheduleResult = Undefined Then
		Return;
	EndIf;
	
	Schedule = ScheduleResult;
	Items.EditSchedule.Title = String(Schedule);
	
EndProcedure

/////////////////////////////////////////////////////////
// Data presentation on the form.

// For internal use.
&AtServer
Procedure SetVisibilityAvailability()
	
	Items.EditSchedule.Enabled = (Object.ExecutionOption = "Schedule");
	
	BackupAvailable = Object.RunAutomaticBackup;
	Items.ParametersGroup.Enabled = BackupAvailable;
	Items.SelectAutomaticBackupOption.Enabled = BackupAvailable;
	
EndProcedure

#EndRegion
