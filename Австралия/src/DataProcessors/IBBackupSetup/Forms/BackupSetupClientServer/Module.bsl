
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If CommonClientServer.IsWebClient() Then
		Raise NStr("ru = 'Резервное копирование недоступно в веб-клиенте.'; en = 'Backup is not available in web client.'; pl = 'Kopia zapasowa nie jest dostępna w kliencie www.';es_ES = 'Copia de respaldo no se encuentra disponible en el cliente web.';es_CO = 'Copia de respaldo no se encuentra disponible en el cliente web.';tr = 'Yedekleme web istemcisinde mevcut değildir.';it = 'Backup non è disponibile in client web.';de = 'Die Sicherung ist im Webclient nicht verfügbar.'");
	EndIf;
	
	If Not CommonClientServer.IsWindowsClient() Then
		Return; // Cancel is set in OnOpen().
	EndIf;
	
	BackupParameters = IBBackupServer.BackupParameters();
	DisableNotifications = BackupParameters.BackupConfigured;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If Not CommonClientServer.IsWindowsClient() Then
		Cancel = True;
		MessageText = NStr("ru = 'Резервное копирование поддерживается только в клиенте под управлением ОС Windows.'; en = 'Backup is supported on the client running Windows OS only.'; pl = 'Kopia zapasowa jest obsługiwana tylko w kliencie z systemem operacyjnym Windows.';es_ES = 'Copia de respaldo está admitida solo en el cliente bajo el sistema operativo Windows.';es_CO = 'Copia de respaldo está admitida solo en el cliente bajo el sistema operativo Windows.';tr = 'OS Windows işletim sistemini çalıştıran istemcide yedekleme desteklenir.';it = 'Il backup è supportato solo sul client con SO Windows.';de = 'Sicherungen werden nur von dem Client unter Windows unterstützt.'");
		ShowMessageBox(, MessageText);
		Return;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure OK(Command)
	
	ApplicationParameters["StandardSubsystems.IBParameters"].NotificationParameter =
		?(DisableNotifications, "DoNotNotify", "NotConfiguredYet");
	
	If DisableNotifications Then
		IBBackupClient.DisableBackupIdleHandler();
	Else
		IBBackupClient.AttachIdleBackupHandler();
	EndIf;
	
	OKAtServer();
	Notify("BackupSettingsFormClosed");
	Close();
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure OKAtServer()
	
	BackupParameters = IBBackupServer.BackupParameters();
	
	BackupParameters.BackupConfigured = DisableNotifications;
	BackupParameters.RunAutomaticBackup = False;
	
	IBBackupServer.SetBackupParemeters(BackupParameters);
	
EndProcedure

#EndRegion
