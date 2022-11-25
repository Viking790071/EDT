#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	If Not ValueIsFilled(Parameters.Key) Then
		ErrorText = 
			NStr("ru = 'Общая форма ""Предупреждение безопасности"" является вспомогательной и открывается из служебных механизмов программы.'; en = 'The common form ""Security warning"" is auxiliary; it is meant to be opened by the internal application algorithms.'; pl = 'Wspólny formularz ""Ostrzeżenie o bezpieczeństwie"" jest pomocniczy; Ma być otwarty przez wewnętrzne algorytmy aplikacji.';es_ES = 'El formulario común ""Avisos de seguridad"" es adicional y se abre de los mecanismos de servicio del programa.';es_CO = 'El formulario común ""Avisos de seguridad"" es adicional y se abre de los mecanismos de servicio del programa.';tr = '""Güvenlik Uyarısı"" genel formu yardımcı olup programın hizmet mekanizmalarından açılır.';it = 'Il modulo comune ""Avviso di sicurezza"" è ausiliario e si apre dai meccanismi di servizio del programma.';de = 'Die allgemeine Form der ""Sicherheitswarnung"" ist eine Hilfsform, die sich aus den Servicemechanismen des Programms öffnet.'");
		Raise ErrorText;
	EndIf;
	
	CurrentPage = Items.Find(Parameters.Key);
	For Each Page In Items.Pages.ChildItems Do
		Page.Visible = (Page = CurrentPage);
	EndDo;
	Items.Pages.CurrentPage = CurrentPage;
	
	If CurrentPage = Items.AfterUpdate Then
		Items.DenyOpeningExternalReportsAndDataProcessors.DefaultButton = True;
	ElsIf CurrentPage = Items.AfterObtainRight Then
		Items.IAgree.DefaultButton = True;
	EndIf;
	
	PurposeUseKey = Parameters.Key;
	WindowOptionsKey = Parameters.Key;
	
	If Not IsBlankString(Parameters.FileName) Then
		Items.WarningOnOpenFile.Title =
			StringFunctionsClientServer.SubstituteParametersToString(
				Items.WarningOnOpenFile.Title, Parameters.FileName);
	EndIf;
	
	If Common.DataSeparationEnabled() Then 
		Items.WarningBeforeDeleteExtensionBackup.Visible = False;
	Else 
		If Common.SubsystemExists("StandardSubsystems.IBBackup") Then
			
			ModuleIBBackupServer = Common.CommonModule("IBBackupServer");
			
			Backup = New Array;
			Backup.Add(NStr("ru = 'Перед удалением расширения рекомендуется'; en = 'It is recommended that you create an infobase backup'; pl = 'Przed usunięciem rozszerzenia jest zalecane';es_ES = 'Antes de eliminar la extensión se recomienda';es_CO = 'Antes de eliminar la extensión se recomienda';tr = 'Uzantıyı silmeden önce';it = 'Si consiglia di creare un backup di infobase';de = 'Bevor Sie die Erweiterung löschen, wird empfohlen, dass Sie eine Info-Base-Sicherung erstellen'"));
			Backup.Add(Chars.LF);
			Backup.Add(New FormattedString(
				NStr("ru = 'выполнить резервное копирование информационной базы'; en = 'before deleting the extension.'; pl = 'wykonaj kopiowanie zapasowe bazy informacyjnej';es_ES = 'hacer una copia de respaldo de la base de información';es_CO = 'hacer una copia de respaldo de la base de información';tr = 'veritabanın yedeklenmesi önerilir';it = 'prima di eliminare estensioni.';de = 'eine Sicherungskopie der Infobase durchführen'"),,,,
				ModuleIBBackupServer.BackupDataProcessorURL()));
			Backup.Add(".");
			
			Items.WarningBeforeDeleteExtensionBackup.Title = 
				New FormattedString(Backup);
			
		EndIf;
	EndIf;
	
	If Parameters.MultipleChoice Then 
		Items.WarningBeforeDeleteExtensionTextDelete.Title = NStr("ru = 'Удалить выделенные расширения?'; en = 'Do you want to delete the selected extensions?'; pl = 'Usunąć zaznaczone rozszerzenia?';es_ES = '¿Eliminar las extensiones seleccionadas?';es_CO = '¿Eliminar las extensiones seleccionadas?';tr = 'Seçilen uzantılar silinsin mi?';it = 'Eliminare le estensioni selezionate?';de = 'Ausgewählte Erweiterungen löschen?'");
	Else 
		Items.WarningBeforeDeleteExtensionTextDelete.Title = NStr("ru = 'Удалить расширение?'; en = 'Do you want to delete the extension?'; pl = 'Usunąć rozszerzenie?';es_ES = '¿Eliminar la extensión?';es_CO = '¿Eliminar la extensión?';tr = 'Uzantı silinsin mi?';it = 'Eliminare l''estensione?';de = 'Erweiterung löschen?'");
	EndIf;
	
	If CommonClientServer.IsMobileClient() Then
		
		For each FormItem In Items Do
			
			If TypeOf(FormItem) <> Type("FormButton")
				OR StrFind(FormItem.Name, "Cancel") = 0 Then
				
				Continue;
				
			EndIf;
			
			CommonClientServer.SetFormItemProperty(Items, FormItem.Name, "Visible", False);
			
		EndDo;
		
		CommonClientServer.SetFormItemProperty(Items, "Label4", "Visible", False);
		CommonClientServer.SetFormItemProperty(Items, "Label4MobileClient", "Visible", True);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormItemsEventHandlers

&AtClient
Procedure WarningBeforeDeleteBackupProcessURLExtension(Item, 
	FormattedStringURL, StandardProcessing)
	
	Close(DialogReturnCode.Cancel);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ContinueCommand(Command)
	SelectedButtonName = Command.Name;
	CloseFormAndReturnResult();
EndProcedure

&AtClient
Procedure DenyOpeningExternalReportsAndDataProcessors(Command)
	AllowInteractiveOpening = False;
	ManageRoleAtClient(Command);
EndProcedure

&AtClient
Procedure AllowOpeningExternalReportsAndDataProcessors(Command)
	AllowInteractiveOpening = True;
	ManageRoleAtClient(Command);
EndProcedure

&AtClient
Procedure IAgree(Command)
	SelectedButtonName = Command.Name;
	IAgreeAtServer();
	CloseFormAndReturnResult();
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure ManageRoleAtClient(Command)
	SelectedButtonName = Command.Name;
	ManageRoleAtServer();
	RefreshReusableValues();
	ProposeRestart();
EndProcedure

&AtServer
Procedure ManageRoleAtServer()
	If Not AccessRight("Administration", Metadata) Then
		Return;
	EndIf;
	OpeningRole = Metadata.Roles.InteractiveOpenExtReportsAndDataProcessors;
	AdministratorRole = Metadata.Roles.SystemAdministrator;
	
	AdministrationParameters = StandardSubsystemsServer.AdministrationParameters();
	AdministrationParameters.Insert("OpenExternalReportsAndDataProcessorsDecisionMade", True);
	StandardSubsystemsServer.SetAdministrationParameters(AdministrationParameters);
	
	RefreshReusableValues();
	
	IBUsers = InfoBaseUsers.GetUsers();
	For Each InfobaseUser In IBUsers Do
		If AllowInteractiveOpening Then
			If InfobaseUser.Roles.Contains(AdministratorRole)
				AND Not InfobaseUser.Roles.Contains(OpeningRole) Then
				InfobaseUser.Roles.Add(OpeningRole);
				InfobaseUser.Write();
			EndIf;
		Else
			If InfobaseUser.Roles.Contains(OpeningRole) Then
				InfobaseUser.Roles.Delete(OpeningRole);
				InfobaseUser.Write();
			EndIf;
		EndIf;
	EndDo;
	
	If AllowInteractiveOpening Then
		RestartRequired = Not AccessRight("InteractiveOpenExtDataProcessors", Metadata);
	Else
		RestartRequired = AccessRight("InteractiveOpenExtDataProcessors", Metadata);
	EndIf;
	
	IAgreeAtServer();
	
	// In the SaaS mode, data area users do not have the right to open external reports and data 
	// processors.
	If Common.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.SetExternalReportsAndDataProcessorsOpenRight(AllowInteractiveOpening);
	EndIf;
	
EndProcedure

&AtServer
Procedure IAgreeAtServer()
	Common.CommonSettingsStorageSave("SecurityWarning", "UserAccepts", True);
EndProcedure

&AtClient
Procedure CloseFormAndReturnResult()
	If IsOpen() Then
		NotifyChoice(SelectedButtonName);
	EndIf;
EndProcedure

&AtClient
Procedure ProposeRestart()
	If Not RestartRequired Then
		CloseFormAndReturnResult();
		Return;
	EndIf;
	
	Handler = New NotifyDescription("RestartApplication", ThisObject);
	Buttons = New ValueList;
	Buttons.Add("Restart", NStr("ru = 'Перезапустить'; en = 'Restart'; pl = 'Uruchom ponownie';es_ES = 'Reiniciar';es_CO = 'Reiniciar';tr = 'Yeniden başlat';it = 'Ricominciare';de = 'Neustart'"));
	Buttons.Add("DoNotRestart", NStr("ru = 'Не перезапускать'; en = 'Do not restart'; pl = 'Nie uruchamiaj ponownie';es_ES = 'No reiniciar';es_CO = 'No reiniciar';tr = 'Yeniden başlatma';it = 'Non riavviare';de = 'Nicht neu starten'"));
	QuestionText = NStr("ru = 'Для применения изменений требуется перезапустить программу.'; en = 'To apply the changes, restart the application.'; pl = 'Aby zastosować zmiany, należy zrestartować program.';es_ES = 'Para aplicar los cambios se requiere reiniciar el programa.';es_CO = 'Para aplicar los cambios se requiere reiniciar el programa.';tr = 'Değişikliklerin uygulanması için program yeniden başlatılmalıdır.';it = 'Per applicare le modifiche, riavviare l''applicazione.';de = 'Um die Änderungen zu übernehmen, muss das Programm neu gestartet werden.'");
	ShowQueryBox(Handler, QuestionText, Buttons);
EndProcedure

&AtClient
Procedure RestartApplication(Response, ExecutionParameters) Export
	CloseFormAndReturnResult();
	If Response = "Restart" Then
		Exit(False, True);
	EndIf;
EndProcedure

#EndRegion
