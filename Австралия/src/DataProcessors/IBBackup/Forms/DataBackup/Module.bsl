#Region Variables

&AtClient
Var BackupInProgress;

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
	
	If NOT Common.FileInfobase() Then
		Raise NStr("ru = 'В клиент-серверном варианте работы резервное копирование следует выполнять сторонними средствами (средствами СУБД).'; en = 'Back up data using external tools (DBMS tools) in the client/server mode.'; pl = 'Utwórz kopię zapasową danych za pomocą narzędzi zewnętrznych (narzędzia SUBD) w trybie klient/serwer.';es_ES = 'Datos de la copia de respaldo utilizando herramientas externas (herramientas DBMS) en el modo de cliente/servidor.';es_CO = 'Datos de la copia de respaldo utilizando herramientas externas (herramientas DBMS) en el modo de cliente/servidor.';tr = 'İstemci / sunucu modunda harici araçları (DBMS araçları) kullanarak verileri yedekleyin.';it = 'Eseguire backup dati usando strumenti esterni (strumenti DBMS) in modalità client/server.';de = 'Sichern Sie Daten mit externen Tools (DBMS-Tools) im Client / Server-Modus.'");
	EndIf;
	
	BackupSettings = IBBackupServer.BackupSettings();
	IBAdministratorPassword = BackupSettings.IBAdministratorPassword;
	
	If Parameters.RunMode = "ExecuteNow" Then
		Items.WizardPages.CurrentPage = Items.InformationAndBackupCreationPage;
		If Not IsBlankString(Parameters.Explanation) Then
			Items.WaitingGroup.CurrentPage = Items.WaitingForStartPage;
			Items.WaitingForBackupLabel.Title = Parameters.Explanation;
		EndIf;
	ElsIf Parameters.RunMode = "ExecuteOnExit" Then
		Items.WizardPages.CurrentPage = Items.InformationAndBackupCreationPage;
	ElsIf Parameters.RunMode = "CompletedSuccessfully" Then
		Items.WizardPages.CurrentPage = Items.BackupSuccessfulPage;
		BackupFileName = Parameters.BackupFileName;
	ElsIf Parameters.RunMode = "NotCompleted" Then
		Items.WizardPages.CurrentPage = Items.BackupCreationErrorsPage;
	EndIf;
	
	AutomaticRun = (Parameters.RunMode = "ExecuteNow" Or Parameters.RunMode = "ExecuteOnExit");
	
	If BackupSettings.Property("ManualBackupsStorageDirectory")
		AND Not IsBlankString(BackupSettings.ManualBackupsStorageDirectory)
		AND Not AutomaticRun Then
		Object.BackupDirectory = BackupSettings.ManualBackupsStorageDirectory;
	Else
		Object.BackupDirectory = BackupSettings.BackupsStorageDirectory;
	EndIf;
	
	If BackupSettings.LatestBackupDate = Date(1, 1, 1) Then
		TitleText = NStr("ru = 'Резервное копирование еще ни разу не проводилось'; en = 'Backup has never been made'; pl = 'Tworzenie kopii zapasowej nigdy wcześniej nie było przeprowadzane';es_ES = 'Nunca se ha creado una copia de respaldo';es_CO = 'Nunca se ha creado una copia de respaldo';tr = 'Yedekleme hiç yapılmadı';it = 'Il backup non è mai stato eseguito';de = 'Sicherung wurde nie gemacht'");
	Else
		TitleText = NStr("ru = 'В последний раз резервное копирование проводилось: %1'; en = 'Last backup: %1'; pl = 'Ostatnie utworzenie kopii zapasowej:%1';es_ES = 'Última copia de respaldo: %1';es_CO = 'Última copia de respaldo: %1';tr = 'Son yedekleme: %1';it = 'Ultimo backup: %1';de = 'Letzte Sicherung: %1'");
		LastBackupDate = Format(BackupSettings.LatestBackupDate, "DLF=ДДВ");
		TitleText = StringFunctionsClientServer.SubstituteParametersToString(TitleText, LastBackupDate);
	EndIf;
	Items.LastBackupDateLabel.Title = TitleText;
	
	Items.AutomaticBackupGroup.Visible = Not BackupSettings.RunAutomaticBackup;
	
	UserInformation = IBBackupServer.UserInformation();
	PasswordRequired = UserInformation.PasswordRequired;
	If PasswordRequired Then
		IBAdministrator = UserInformation.Name;
	Else
		Items.AuthorizationGroup.Visible = False;
		IBAdministratorPassword = "";
	EndIf;
	
	ManualStart = (Items.WizardPages.CurrentPage = Items.BackupCreationPage);
	
	If ManualStart Then
		
		If InfobaseSessionCount() > 1 Then
			
			Items.BackupStatusPages.CurrentPage = Items.ActiveUsersPage;
			
		EndIf;
		
		Items.Next.Title = NStr("ru = 'Сохранить резервную копию'; en = 'Save backup'; pl = 'Zapisz kopię zapasową';es_ES = 'Guardar la copia de respaldo';es_CO = 'Guardar la copia de respaldo';tr = 'Yedeği kaydet';it = 'Salva backup';de = 'Sicherung speichern'");
		
	EndIf;
	
	IBBackupServer.SetSettingValue("LastBackupManualStart", ManualStart);
	
	Parameters.Property("ApplicationDirectory", ApplicationDirectory);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	GoToPage(Items.WizardPages.CurrentPage);
	
#If WebClient Then
	Items.UpdateComponentVersionLabel.Visible = False;
#EndIf
	
	If Parameters.RunMode = "CompletedSuccessfully"
		AND CommonClient.SubsystemExists("OnlineUserSupport.CloudArchive") Then
		ModuleCloudArchiveClient = CommonClient.CommonModule("CloudArchiveClient");
		ModuleCloudArchiveClient.UploadFileToCloud(ThisObject.BackupFileName, 10);
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	CurrentPage = Items.WizardPages.CurrentPage;
	If CurrentPage <> Items.WizardPages.ChildItems.InformationAndBackupCreationPage Then
		Return;
	EndIf;
	
	WarningText = NStr("ru = 'Прервать подготовку к резервному копированию данных?'; en = 'Stop preparing for data backup?'; pl = 'Czy chcesz zaprzestać przygotowanie do tworzenia kopii zapasowych?';es_ES = '¿Quiere parar la preparación para la creación de la copia de respaldo?';es_CO = '¿Quiere parar la preparación para la creación de la copia de respaldo?';tr = 'Yedeklemeye hazırlanmayı durdurmak istiyor musunuz?';it = 'Fermare la preparazione per il backup dati?';de = 'Wollen Sie die Vorbereitung für die Sicherung stoppen?'");
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
	
	If BackupInProgress = True Then
		Return;
	EndIf;
	
	IBConnectionsClient.SetTerminateAllSessionsExceptCurrentFlag(False);
	IBConnectionsServerCall.AllowUserAuthorization();
	
	If ProcessRunning() Then
		ProcessRunning(False);
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	If EventName = "UserSessionsCompletion" AND Parameter.SessionCount <= 1
		AND ApplicationParameters["StandardSubsystems.IBParameters"].ProcessRunning Then
			StartBackup();
	EndIf;
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure UsersListClick(Item)
	
	StandardSubsystemsClient.OpenActiveUserList(, ThisObject);
	
EndProcedure

&AtClient
Procedure PathToArchiveDirectoryStartChoice(Item, ChoiceData, StandardProcessing)
	
	SelectedPath = GetPath(FileDialogMode.ChooseDirectory);
	If Not IsBlankString(SelectedPath) Then 
		Object.BackupDirectory = SelectedPath;
	EndIf;

EndProcedure

&AtClient
Procedure BackupFileNameOpen(Item, StandardProcessing)
	
	StandardProcessing = False;
	CommonClient.OpenExplorer(BackupFileName);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Next(Command)
	
	ClearMessages();
	
	If Not CheckAttributeFilling() Then
		Return;
	EndIf;
	
	CurrentWizardPage = Items.WizardPages.CurrentPage;
	If CurrentWizardPage = Items.WizardPages.ChildItems.BackupCreationPage Then
		
		GoToPage(Items.InformationAndBackupCreationPage);
		SetBackupArchivePath(Object.BackupDirectory);
		
	Else
		
		Close();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure Cancel(Command)
	
	Close();
	
EndProcedure

&AtClient
Procedure GoToEventLog(Command)
	OpenForm("DataProcessor.EventLog.Form.EventLog", , ThisObject);
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure GoToPage(NewPage)
	
	GoToNext = True;
	SubordinatePages = Items.WizardPages.ChildItems;
	If NewPage = SubordinatePages.InformationAndBackupCreationPage Then
		GoToInformationAndBackupPage(GoToNext);
	ElsIf NewPage = SubordinatePages.BackupCreationErrorsPage 
		OR NewPage = SubordinatePages.BackupSuccessfulPage Then
		GoToBackupResultsPage();
	EndIf;
	
	If Not GoToNext Then
		Return;
	EndIf;
	
	If NewPage <> Undefined Then
		Items.WizardPages.CurrentPage = NewPage;
	Else
		Close();
	EndIf;
	
EndProcedure

&AtClient
Procedure GoToInformationAndBackupPage(GoToNext)
	
	If Not CheckAttributeFilling(False) Then
		Items.WizardPages.CurrentPage = Items.BackupCreationErrorsPage;
		GoToNext = False;
		Return;
	EndIf;
	
	AttachmentResult = IBBackupClient.CheckAccessToInfobase(IBAdministratorPassword);
	If AttachmentResult.AddInAttachmentError Then
		Items.BackupStatusPages.CurrentPage = Items.ConnectionErrorPage;
		ConnectionErrorFound = AttachmentResult.BriefErrorDescription;
		GoToNext = False;
		Return;
	Else
		SetBackupParemeters();
	EndIf;
	
	ProcessRunning(True);
	
	Items.Cancel.Enabled = True;
	Items.ActiveUserCount.Title = InfobaseSessionCount();
	SetButtonTitleNext(True);
	Items.Next.Enabled = False;
	
	If InfobaseSessionCount() = 1 Then
		
		IBConnectionsServerCall.SetConnectionLock(NStr("ru = 'Для выполнения резервного копирования.'; en = 'For backup execution.'; pl = 'Do utworzenia kopii zapasowej.';es_ES = 'Para la ejecución de la copia de respaldo.';es_CO = 'Para la ejecución de la copia de respaldo.';tr = 'Yedekleme çalışması için.';it = 'Per l''esecuzione del Backup.';de = 'Für die Ausführung der Sicherung.'"), "Backup");
		IBConnectionsClient.SetTerminateAllSessionsExceptCurrentFlag(True);
		IBConnectionsClient.SetUserTerminationInProgressFlag(True);
		IBConnectionsClient.TerminateThisSession(False);
		
		StartBackup();
		
	Else
		
		ClearMessages();
		
		CheckForBlockingSessions();
		
		IBConnectionsServerCall.SetConnectionLock(NStr("ru = 'Для выполнения резервного копирования.'; en = 'For backup execution.'; pl = 'Do utworzenia kopii zapasowej.';es_ES = 'Para la ejecución de la copia de respaldo.';es_CO = 'Para la ejecución de la copia de respaldo.';tr = 'Yedekleme çalışması için.';it = 'Per l''esecuzione del Backup.';de = 'Für die Ausführung der Sicherung.'"), "Backup");
		IBConnectionsClient.SetSessionTerminationHandlers(True);
		SetIdleIdleHandlerOfBackupStart();
		SetIdleHandlerOfBackupTimeout();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure CheckForBlockingSessions()
	
	BlockingSessionsInformation = IBConnections.BlockingSessionsInformation("");
	HasBlockingSessions = BlockingSessionsInformation.HasBlockingSessions;
	
	If HasBlockingSessions Then
		Items.ActiveSessionsDecoration.Title = BlockingSessionsInformation.MessageText;
	EndIf;
	
	Items.ActiveSessionsDecoration.Visible = HasBlockingSessions;
	
EndProcedure

&AtClient
Procedure GoToBackupResultsPage()
	
	Items.Next.Visible= False;
	Items.Cancel.Title = NStr("ru = 'Закрыть'; en = 'Close'; pl = 'Zamknij';es_ES = 'Cerrar';es_CO = 'Cerrar';tr = 'Kapat';it = 'Chiudi';de = 'Schließen'");
	Items.Cancel.DefaultButton = True;
	BackupParameters = BackupSettings();
	IBBackupClient.FillGlobalVariableValues(BackupParameters);
	SetBackupResult();
	
EndProcedure

&AtServerNoContext
Procedure SetBackupResult()
	
	IBBackupServer.SetBackupResult();
	
EndProcedure

&AtServer
Procedure SetBackupParemeters()
	
	BackupParameters = IBBackupServer.BackupSettings();
	
	BackupParameters.Insert("IBAdministrator", IBAdministrator);
	BackupParameters.Insert("IBAdministratorPassword", ?(PasswordRequired, IBAdministratorPassword, ""));
	
	IBBackupServer.SetBackupParemeters(BackupParameters);
	
EndProcedure

&AtServerNoContext
Function BackupSettings()
	
	Return IBBackupServer.BackupSettings();
	
EndFunction

&AtClient
Function CheckAttributeFilling(ShowError = True)

#If WebClient Then
	MessageText = NStr("ru = 'Создание резервной копии не доступно в веб-клиенте.'; en = 'Backups cannot be created in web client.'; pl = 'Tworzenie kopii zapasowej nie jest dostępne w kliencie Web.';es_ES = 'La creación de la copia de respaldo no está disponible en el cliente web.';es_CO = 'La creación de la copia de respaldo no está disponible en el cliente web.';tr = 'Web istemcide yedekleme yapılamaz.';it = 'Il backup non può essere creato in web client.';de = 'Eine Sicherung ist im Webclient nicht verfügbar.'");
	CommonClientServer.MessageToUser(MessageText);
	AttributesFilled = False;
#Else
	
	AttributesFilled = True;
	
	Object.BackupDirectory = TrimAll(Object.BackupDirectory);
	
	If IsBlankString(Object.BackupDirectory) Then
		
		MessageText = NStr("ru = 'Не выбран каталог для резервной копии.'; en = 'Backup directory is not selected.'; pl = 'Nie wybrano katalogu dla kopii rezerwowej.';es_ES = 'Directorio de la copia de respaldo no se ha seleccionado.';es_CO = 'Directorio de la copia de respaldo no se ha seleccionado.';tr = 'Yedekleme dizini seçilmedi.';it = 'La directory di backup non è selezionata.';de = 'Sicherungsverzeichnis ist nicht ausgewählt.'");
		RecordAttributeCheckError(MessageText, "Object.BackupDirectory", ShowError);
		AttributesFilled = False;
		
	ElsIf FindFiles(Object.BackupDirectory).Count() = 0 Then
		
		MessageText = NStr("ru = 'Указан несуществующий каталог.'; en = 'Non-existing directory is specified.'; pl = 'Podano nieistniejący katalog.';es_ES = 'Directorio no existente está especificado.';es_CO = 'Directorio no existente está especificado.';tr = 'Mevcut olmayan dizin belirlendi.';it = 'E'' specificata una directory non-esistente.';de = 'Nicht existierendes Verzeichnis ist angegeben.'");
		RecordAttributeCheckError(MessageText, "Object.BackupDirectory", ShowError);
		AttributesFilled = False;
		
	Else
		
		Try
			TestFile = New XMLWriter;
			TestFile.OpenFile(Object.BackupDirectory + "/test.test1C");
			TestFile.WriteXMLDeclaration();
			TestFile.Close();
		Except
			MessageText = NStr("ru = 'Нет доступа к каталогу с резервными копиями.'; en = 'Cannot access directory with backups.'; pl = 'Nie można uzyskać dostępu do katalogu z kopiami zapasowymi.';es_ES = 'No se puede acceder el directorio con copias de respaldo.';es_CO = 'No se puede acceder el directorio con copias de respaldo.';tr = 'Dizine yedeklerle erişilemiyor.';it = 'Non è possibile accedere alla directory con i backup.';de = 'Zugriff auf das Verzeichnis mit Sicherungen nicht möglich.'");
			RecordAttributeCheckError(MessageText, "Object.BackupDirectory", ShowError);
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
		RecordAttributeCheckError(MessageText, "IBAdministratorPassword", ShowError);
		AttributesFilled = False;
		
	EndIf;

#EndIf
	
	Return AttributesFilled;
	
EndFunction

&AtClient
Procedure RecordAttributeCheckError(ErrorText, AttributePath, ShowError)
	
	If ShowError Then
		CommonClientServer.MessageToUser(ErrorText,, AttributePath);
	Else
		EventLogClient.AddMessageForEventLog(IBBackupClient.EventLogEvent(),
			"Error", ErrorText, , True);
	EndIf;
	
EndProcedure

&AtClient
Procedure SetIdleHandlerOfBackupTimeout()
	
	AttachIdleHandler("Timeout", 300, True);
	
EndProcedure

&AtClient
Procedure Timeout()
	
	DetachIdleHandler("CheckForSingleConnection");
	QuestionText = NStr("ru = 'Не удалось отключить всех пользователей от базы. Провести резервное копирование? (возможны ошибки при архивации)'; en = 'Cannot disconnect all users from the base. Back up the data? (errors may occur during backup)'; pl = 'Nie można odłączyć wszystkich użytkowników od tej bazy. Utworzyć kopię zapasową danych? (podczas tworzenia kopii zapasowej mogą wystąpić błędy)';es_ES = 'No se puede desconectar todos usuarios de la base. ¿Crear una copia de respaldo de los datos? (errores pueden ocurrir durante la creación de la copia de respaldo)';es_CO = 'No se puede desconectar todos usuarios de la base. ¿Crear una copia de respaldo de los datos? (errores pueden ocurrir durante la creación de la copia de respaldo)';tr = 'Tüm kullanıcılar tabandan kesilemez. Veriler yedeklensin mi? (yedekleme sırasında hatalar oluşabilir)';it = 'Impossibile disconnettere tutti gli utenti dalla base. Eseguire backup dati? (potrebbero verificarsi errori durante il backup)';de = 'Es können nicht alle Benutzer von der Basis getrennt werden. Sichern Sie die Daten? (Fehler können während der Sicherung auftreten)'");
	NoteText = NStr("ru = 'Не удалось отключить пользователя.'; en = 'Cannot disable the user.'; pl = 'Nie można wyłączyć użytkownika.';es_ES = 'No se puede desactivar el usuario.';es_CO = 'No se puede desactivar el usuario.';tr = 'Kullanıcı devre dışı bırakılamaz.';it = 'Non è possibile disabilitare l''utente.';de = 'Der Benutzer kann nicht deaktiviert werden.'");
	NotifyDescription = New NotifyDescription("ExpiringTimeoutCompletion", ThisObject);
	ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo, 30, DialogReturnCode.No, NoteText, DialogReturnCode.No);
	
EndProcedure

&AtClient
Procedure ExpiringTimeoutCompletion(Response, AdditionalParameters) Export
	
	If Response = DialogReturnCode.Yes Then
		StartBackup();
	Else
		ClearMessages();
		IBConnectionsClient.SetTerminateAllSessionsExceptCurrentFlag(False);
		CancelPreparation();
EndIf;
	
EndProcedure

&AtServer
Procedure CancelPreparation()
	
	Items.FailedLabel.Title = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = '%1.
		|Подготовка к резервному копированию отменена. Информационная база разблокирована.'; 
		|en = '%1.
		|Preparation for backup is canceled. Infobase is unlocked.'; 
		|pl = '%1.
		|Przygotowanie do tworzenia kopii zapasowej zostanie anulowane. Baza informacyjna jest zablokowana.';
		|es_ES = '%1.
		|Preparación para una copia de respaldo se ha cancelado. Infobase está bloqueada.';
		|es_CO = '%1.
		|Preparación para una copia de respaldo se ha cancelado. Infobase está bloqueada.';
		|tr = '%1. 
		| Yedekleme için hazırlık iptal edildi. Veritabanı kilitlendi.';
		|it = '%1.
		|La preparazione per il backup è stata annullata. L''infobase è sbloccato.';
		|de = '%1.
		|Die Vorbereitung für eine Sicherung wird abgebrochen. Infobase ist gesperrt.'"),
		IBConnections.ActiveSessionsMessage());
	Items.WizardPages.CurrentPage = Items.BackupCreationErrorsPage;
	Items.GoToEventLog1.Visible = False;
	Items.Next.Visible = False;
	Items.Cancel.Title = NStr("ru = 'Закрыть'; en = 'Close'; pl = 'Zamknij';es_ES = 'Cerrar';es_CO = 'Cerrar';tr = 'Kapat';it = 'Chiudi';de = 'Schließen'");
	Items.Cancel.DefaultButton = True;
	
	IBConnections.AllowUserAuthorization();
	
EndProcedure

&AtClient
Procedure SetIdleIdleHandlerOfBackupStart()
	
	AttachIdleHandler("CheckForSingleConnection", 30);
	
EndProcedure

&AtClient
Procedure CheckForSingleConnection()
	
	UsersCount = InfobaseSessionCount();
	Items.ActiveUserCount.Title = String(UsersCount);
	If UsersCount = 1 Then
		StartBackup();
	Else
		CheckForBlockingSessions();
	EndIf;
	
EndProcedure

&AtClient
Procedure SetButtonTitleNext(ThisButtonNext)
	
	Items.Next.Title = ?(ThisButtonNext, NStr("ru = 'Далее >'; en = 'Next >'; pl = 'Dalej >';es_ES = 'Siguiente >';es_CO = 'Siguiente >';tr = 'Sonraki >';it = 'Avanti >';de = 'Weiter >'"), NStr("ru = 'Готово'; en = 'Finish'; pl = 'Koniec';es_ES = 'Finalizar';es_CO = 'Finalizar';tr = 'Bitiş';it = 'Termina';de = 'Abschluss'"));
	
EndProcedure

&AtClient
Function GetPath(DialogMode)
	
	Mode = DialogMode;
	OpenFileDialog = New FileDialog(Mode);
	If Mode = FileDialogMode.ChooseDirectory Then
		OpenFileDialog.Title= NStr("ru = 'Выберите каталог'; en = 'Select directory'; pl = 'Wybierz folder';es_ES = 'Seleccionar el directorio';es_CO = 'Seleccionar el directorio';tr = 'Dizini seçin';it = 'Selezionare la directory';de = 'Wählen Sie das Verzeichnis aus'");
	Else
		OpenFileDialog.Title= NStr("ru = 'Выберите файл'; en = 'Select file'; pl = 'Wybierz plik';es_ES = 'Seleccionar un archivo';es_CO = 'Seleccionar un archivo';tr = 'Dosya seç';it = 'Selezionare il file';de = 'Datei auswählen'");
	EndIf;	
		
	If OpenFileDialog.Choose() Then
		If DialogMode = FileDialogMode.ChooseDirectory Then
			Return OpenFileDialog.Directory;
		Else
			Return OpenFileDialog.FullFileName;
		EndIf;
	EndIf;
	
EndFunction

&AtClient
Procedure StartBackup()
	
	MainScriptFileName = GenerateUpdateScriptFiles();
	
	EventLogClient.AddMessageForEventLog(IBBackupClient.EventLogEvent(),
		"Information",  NStr("ru = 'Выполняется резервное копирование информационной базы:'; en = 'Infobase backup is in progress:'; pl = 'Wykonuje się rezerwowe kopiowanie bazy informacyjnej:';es_ES = 'Copia de respaldo de la infobase está en progreso:';es_CO = 'Copia de respaldo de la infobase está en progreso:';tr = 'Veritabanı yedekleniyor:';it = 'Il backup della base informativa viene effettuata:';de = 'Infobase-Sicherung läuft:'") + " " + MainScriptFileName);
		
	If Parameters.RunMode = "ExecuteNow" Or Parameters.RunMode = "ExecuteOnExit" Then
		IBBackupClient.DeleteConfigurationBackups();
	EndIf;
	
	BackupInProgress = True;
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

/////////////////////////////////////////////////////////////////////////////////////////////////////////
// Handlers of form events on the server and changes of backup settings.

&AtServerNoContext
Procedure SetBackupArchivePath(Path)
	
	PathSettings = IBBackupServer.BackupSettings();
	PathSettings.Insert("ManualBackupsStorageDirectory", Path);
	IBBackupServer.SetBackupParemeters(PathSettings);
	
EndProcedure

//////////////////////////////////////////////////////////////////////////////////////////////////////////
// Backup preparation procedures and functions.

&AtClient
Function GenerateUpdateScriptFiles()
	
	BackupParameters = IBBackupClient.ClientBackupParameters();
	ClientParametersOnStart = StandardSubsystemsClient.ClientParametersOnStart();
	CreateDirectory(BackupParameters.TempFilesDirForUpdate);
	
	// Parameters structure is necessary to determine them on the client and transfer to the server.
	ParametersStructure = New Structure;
	ParametersStructure.Insert("ApplicationFileName"			, BackupParameters.ApplicationFileName);
	ParametersStructure.Insert("EventLogEvent"	, BackupParameters.EventLogEvent);
	ParametersStructure.Insert("COMConnectorName"			, ClientParametersOnStart.COMConnectorName);
	ParametersStructure.Insert("IsBaseConfigurationVersion"	, ClientParametersOnStart.IsBaseConfigurationVersion);
	ParametersStructure.Insert("ScriptParameters"				, IBBackupClient.UpdateAdministratorAuthenticationParameters(IBAdministratorPassword));
	
	TemplatesNames = "AddlBackupFile";
	TemplatesNames = TemplatesNames + ",BackupSplash";
	TemplatesTexts = GetTemplateTexts(TemplatesNames, ParametersStructure, ApplicationParameters["StandardSubsystems.MessagesForEventLog"]);
	
	ScriptFile = New TextDocument;
	ScriptFile.Output = UseOutput.Enable;
	ScriptFile.SetText(TemplatesTexts[0]);
	
	ScriptFileName = BackupParameters.TempFilesDirForUpdate + "main.js";
	ScriptFile.Write(ScriptFileName, IBBackupClient.IBBackupApplicationFilesEncoding());
	
	// Auxiliary file: helpers.js.
	ScriptFile = New TextDocument;
	ScriptFile.Output = UseOutput.Enable;
	ScriptFile.SetText(TemplatesTexts[1]);
	ScriptFile.Write(BackupParameters.TempFilesDirForUpdate + "helpers.js", IBBackupClient.IBBackupApplicationFilesEncoding());
	
	MainScriptFileName = Undefined;
	// Auxiliary file: splash.png.
	PictureLib.ExternalOperationSplash.Write(BackupParameters.TempFilesDirForUpdate + "splash.png");
	// Auxiliary file: splash.ico.
	PictureLib.ExternalOperationSplashIcon.Write(BackupParameters.TempFilesDirForUpdate + "splash.ico");
	// Auxiliary  file: progress.gif.
	PictureLib.TimeConsumingOperation48.Write(BackupParameters.TempFilesDirForUpdate + "progress.gif");
	// Main splash screen file: splash.hta.
	MainScriptFileName = BackupParameters.TempFilesDirForUpdate + "splash.hta";
	ScriptFile = New TextDocument;
	ScriptFile.Output = UseOutput.Enable;
	ScriptFile.SetText(TemplatesTexts[2]);
	ScriptFile.Write(MainScriptFileName, IBBackupClient.IBBackupApplicationFilesEncoding());
	
	LogFile = New TextDocument;
	LogFile.Output = UseOutput.Enable;
	LogFile.SetText(StandardSubsystemsClient.SupportInformation());
	LogFile.Write(BackupParameters.TempFilesDirForUpdate + "templog.txt", TextEncoding.System);
	
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
	ScriptTemplate = DataProcessors.IBBackup.GetTemplate("BackupFileTemplate");
	
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
	
	ApplicationDirectory = ?(IsBlankString(ApplicationDirectory), BinDir(), ApplicationDirectory);
	NameOfExecutableApplicationFile = ApplicationDirectory + ParametersStructure.ApplicationFileName;
	
	// Determining path to the infobase.
	FileModeFlag = Undefined;
	InfobasePath = IBConnectionsClientServer.InfobasePath(FileModeFlag, 0);
	
	InfobasePathParameter = ?(FileModeFlag, "/F", "/S") + InfobasePath; 
	InfobasePathString	= ?(FileModeFlag, InfobasePath, "");
	
	DirectoryString = CheckDirectoryForRootItemIndication(Object.BackupDirectory);
	
	Result = StrReplace(Result, "[NameOfExecutableApplicationFile]"	 , PrepareText(NameOfExecutableApplicationFile));
	Result = StrReplace(Result, "[InfobasePathParameter]"	 , PrepareText(InfobasePathParameter));
	Result = StrReplace(Result, "[InfobaseFilePathString]"   , PrepareText(CommonClientServer.AddLastPathSeparator(StrReplace(InfobasePathString, """", ""))));
	Result = StrReplace(Result, "[InfobaseConnectionString]" , PrepareText(InfobaseConnectionString));
	Result = StrReplace(Result, "[NameOfUpdateAdministrator]", PrepareText(UserName()));
	Result = StrReplace(Result, "[EventLogEvent]"			 , PrepareText(ParametersStructure.EventLogEvent));
	Result = StrReplace(Result, "[CreateBackup]"			 , "true");
	Result = StrReplace(Result, "[BackupDirectory]"			 , PrepareText(DirectoryString + "\backup" + DirectoryStringFromDate()));
	Result = StrReplace(Result, "[RestoreInfobase]"			 , "false");
	Result = StrReplace(Result, "[COMConnectorName]"		 , PrepareText(ParametersStructure.COMConnectorName));
	Result = StrReplace(Result, "[UseCOMConnector]"			 , ?(ParametersStructure.IsBaseConfigurationVersion, "false", "true"));
	Result = StrReplace(Result, "[ExecuteOnExit]"			 , ?(Parameters.RunMode = "ExecuteOnExit", "true", "false"));
	
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
Function DirectoryStringFromDate()
	
	ReturnString = "";
	DateNow = CurrentSessionDate();
	ReturnString = Format(DateNow, "DF = yyyy_mm_dd_HH_mm_ss");
	Return ReturnString;
	
EndFunction

&AtServer
Function PrepareText(Val Text)
	
	Row = StrReplace(Text, "\", "\\");
	Row = StrReplace(Row, "'", "\'");
	
	Return StringFunctionsClientServer.SubstituteParametersToString("'%1'", Row);
	
EndFunction

&AtClient
Procedure LableUpdateComponentVersionURLProcessing(Item, FormattedStringURL, StandardProcessing)
	StandardProcessing = False;
	CommonClient.RegisterCOMConnector();
EndProcedure

&AtServer
Function InfobaseSessionCount()
	
	Return IBConnections.InfobaseSessionCount(False, False);
	
EndFunction

&AtClient
Function ProcessRunning(Value = Undefined)
	
	ParameterName = "StandardSubsystems.IBParameters";
	
	If ApplicationParameters.Get(ParameterName) = Undefined Then
		ApplicationParameters.Insert(ParameterName, New Structure("ProcessRunning", False));
	EndIf;
	
	If Value <> Undefined Then
		ApplicationParameters[ParameterName].ProcessRunning = Value;
		IBBackupServerCall.SetSettingValue("ProcessRunning", Value);
	Else
		Return ApplicationParameters[ParameterName].ProcessRunning;
	EndIf;
	
EndFunction

#EndRegion
