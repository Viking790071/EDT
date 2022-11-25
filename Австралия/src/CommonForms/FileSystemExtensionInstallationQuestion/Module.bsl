
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	If Not IsBlankString(Parameters.SuggestionText) Then
		Items.NoteDecoration.Title = Parameters.SuggestionText
			+ Chars.LF
			+ NStr("ru = 'Установить?'; en = 'Do you want to install the extension?'; pl = 'Zainstalować?';es_ES = '¿Instalar?';es_CO = '¿Instalar?';tr = 'Ayarla?';it = 'Installare l''estensione?';de = 'Installieren?'");
		
	ElsIf Not Parameters.CanContinueWithoutInstalling Then
		Items.NoteDecoration.Title =
			NStr("ru = 'Для выполнения действия требуется установить расширение для веб-клиента 1С:Предприятие.
			           |Установить?'; 
			           |en = 'To perform this operation, you need to install 1C:Enterprise web client extension.
			           |Do you want to install it?'; 
			           |pl = 'Do wykonania czynności wymagane jest zainstalowanie rozszerzenia dla klienta sieci Web 1C:Enterprise.
			           |Zainstalować?';
			           |es_ES = 'Para la ejecución de la acción, se requiere instalar la extensión para el cliente web de la 1C:Empresa.
			           |¿Instalar?';
			           |es_CO = 'Para la ejecución de la acción, se requiere instalar la extensión para el cliente web de la 1C:Empresa.
			           |¿Instalar?';
			           |tr = 'İşlemin yürütülmesi için 1C:Enterprise web istemcisi eklentisinin yüklenmesi gerekiyor.
			           |Eklenti yüklensin mi?';
			           |it = 'Per eseguire questa operazione è necessario installare l''estensione web client di 1C:Enterprise.
			           |Installare estensione?';
			           |de = 'Für die Ausführung dieser Operation muss eine Erweiterung für den 1C:Enterprise Webclient installiert werden.
			           |Installieren?'");
	EndIf;
	
	If Not Parameters.CanContinueWithoutInstalling Then
		Items.ContinueWithoutInstalling.Title = NStr("ru = 'Отмена'; en = 'Cancel'; pl = 'Anuluj';es_ES = 'Cancelar';es_CO = 'Cancelar';tr = 'İptal et';it = 'Annulla';de = 'Abbrechen'");
		Items.NoLongerPrompt.Visible = False;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure InstallAndContinue(Command)
	
	Notification = New NotifyDescription("InstallAndContinueCompletion", ThisObject);
	BeginInstallFileSystemExtension(Notification);
	
EndProcedure

&AtClient
Procedure ContinueWithoutInstalling(Command)
	Close("ContinueWithoutInstalling");
EndProcedure

&AtClient
Procedure NoLongerPrompt(Command)
	Close("DoNotPrompt");
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure InstallAndContinueCompletion(AdditionalParameters) Export
	
	Notification = New NotifyDescription("InstallAndContinueAfterAttachExtension", ThisObject);
	BeginAttachingFileSystemExtension(Notification);
	
EndProcedure

&AtClient
Procedure InstallAndContinueAfterAttachExtension(Attached, AdditionalParameters) Export
	
	If Attached Then
		Result = "ExtensionAttached";
	Else
		Result = "ContinueWithoutInstalling";
	EndIf;
	Close(Result);
	
EndProcedure

#EndRegion
