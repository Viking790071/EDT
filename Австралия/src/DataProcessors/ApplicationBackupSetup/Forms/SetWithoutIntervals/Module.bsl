#Region Variables

&AtClient
Var AnswerBeforeClose;

#EndRegion

#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	If CommonClientServer.IsMobileClient() Then // This is a temporary solution for mobile client. It will be removed from next versions.
		
		Cancel = True;
		Raise NStr("ru = 'Для корректной работы необходим режим толстого, тонкого или ВЕБ-клиента.'; en = 'Thin, thick, or web client mode is required.'; pl = 'Do prawidłowego działania wymagany jest gruby, cienki tryb klienta lub tryb klienta WEB.';es_ES = 'Para el funcionamiento correcto es necesario el modo del cliente grueso, ligero o cliente web.';es_CO = 'Para el funcionamiento correcto es necesario el modo del cliente grueso, ligero o cliente web.';tr = 'Doğu çalışma için kalın, ince veya WEB istemci modu gerekmektedir.';it = 'La modalità Thin, thick, o web client è richiesta.';de = 'Für den korrekten Betrieb ist es notwendig, den Thick-, Thin- oder WEB-Client Modus zu verwenden.'");
		
	EndIf;
	
	BackupSettings = DataAreaBackup.GetAreaBackupSettings(
		SaaS.SessionSeparatorValue());
	FillPropertyValues(ThisObject, BackupSettings);
	
	For MonthNumber = 1 To 12 Do
		Items.EarlyBackupMonth.ChoiceList.Add(MonthNumber, 
			Format(Date(2, MonthNumber, 1), "DF=MMMM"));
	EndDo;
	
	TimeZone = SessionTimeZone();
	AreaTimeZone = TimeZone + " (" + TimeZonePresentation(TimeZone) + ")";
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	If Not Modified Then
		Return;
	EndIf;
	
	If AnswerBeforeClose = True Then
		Return;
	EndIf;
	
	Cancel = True;
	If Exit Then
		Return;
	EndIf;
	
	NotifyDescription = New NotifyDescription("BeforeCloseCompletion", ThisObject);
	ShowQueryBox(NotifyDescription, NStr("ru = 'Настройки были изменены. Сохранить изменения?'; en = 'Settings were changed. Save changes?'; pl = 'Ustawienia zostały zmienione. Czy chcesz zachować zmiany?';es_ES = 'Configuraciones se han cambiado. ¿Quiere guardar los cambios?';es_CO = 'Configuraciones se han cambiado. ¿Quiere guardar los cambios?';tr = 'Ayarlar değiştirildi. Değişiklikleri kaydetmek istiyor musunuz?';it = 'Le impostazioni sono cambiate. Salvare le modifiche?';de = 'Einstellungen wurden geändert. Möchten Sie Änderungen speichern?'"), 
		QuestionDialogMode.YesNoCancel, , DialogReturnCode.Yes);
		
EndProcedure
		
&AtClient
Procedure BeforeCloseCompletion(Response, AdditionalParameters) Export	
	
	If Response = DialogReturnCode.Cancel Then
		Return;
	EndIf;
	
	If Response = DialogReturnCode.Yes Then
		WriteBackupSettings();
	EndIf;
	AnswerBeforeClose = True;
    Close();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure SetDefault(Command)
	
	SetDefaultAtServer();
	
EndProcedure

&AtClient
Procedure WriteAndClose(Command)
	
	WriteBackupSettings();
	Modified = False;
	Close(DialogReturnCode.OK);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetDefaultAtServer()
	
	BackupSettings = DataAreaBackup.GetAreaBackupSettings();
	FillPropertyValues(ThisObject, BackupSettings);
	
EndProcedure

&AtServer
Procedure WriteBackupSettings()

	SettingsMap = DataAreasBackupCached.MapBetweenSMSettingsAndAppSettings();
	
	BackupSettings = New Structure;
	For Each KeyAndValue In SettingsMap Do
		BackupSettings.Insert(KeyAndValue.Value, ThisObject[KeyAndValue.Value]);
	EndDo;
	
	DataAreaBackup.SetAreaBackupSettings(
		SaaS.SessionSeparatorValue(), BackupSettings);
		
EndProcedure

#EndRegion
