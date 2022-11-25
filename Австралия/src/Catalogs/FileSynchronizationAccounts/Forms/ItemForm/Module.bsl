#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If ValueIsFilled(Object.FilesAuthor) Then
		AsFilesAuthor = "User";
		Items.FilesAuthor.Enabled = True;
	Else
		AsFilesAuthor = "ExchangePlan";
		Items.FilesAuthor.Enabled = False;
	EndIf;
	
	If Not IsBlankString(Object.Service) Then
		If Object.Service = "https://webdav.yandex.ru" Then
			ServicePresentation = "Yandex.Disk"
		ElsIf Object.Service = "https://webdav.4shared.com" Then
			ServicePresentation = "4shared.com"
		ElsIf Object.Service = "https://dav.box.com/dav" Then
			ServicePresentation = "Box"
		ElsIf Object.Service = "https://dav.dropdav.com" Then
			ServicePresentation = "Dropbox"
		EndIf;
	EndIf;
	
	If Not IsBlankString(Object.Description) Then
		Items.AsFilesAuthor.ChoiceList[0].Presentation =
			StringFunctionsClientServer.SubstituteParametersToString(Items.AsFilesAuthor.Title, "(" + Object.Description + ")");
	EndIf;
	
	// Object attribute editing prohibition subsystem handler
	If Common.SubsystemExists("StandardSubsystems.ObjectAttributesLock") Then
		ModuleObjectAttributesLock = Common.CommonModule("ObjectAttributesLock");
    	ModuleObjectAttributesLock.LockAttributes(ThisObject);
	EndIf;
	
EndProcedure

&AtServer
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If Not Cancel Then
		SetPrivilegedMode(True);
		Common.WriteDataToSecureStorage(CurrentObject.Ref, Username, "Username");
		Common.WriteDataToSecureStorage(CurrentObject.Ref, Password);
		SetPrivilegedMode(False);
	EndIf;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	SetPrivilegedMode(True);
	Mandate = Common.ReadDataFromSecureStorage(CurrentObject.Ref, "Username, Password");
	Username = Mandate.Username;
	Password = Mandate.Password;
	SetPrivilegedMode(False);
	
EndProcedure

&AtClient
Procedure ServicePresentationOnChange(Item)
	
	Modified = True;
	
	If ServicePresentation = "Yandex.Disk" Then
		Object.Service = "https://webdav.yandex.ru"
	ElsIf ServicePresentation = "4shared.com" Then
		Object.Service = "https://webdav.4shared.com"
	ElsIf ServicePresentation = "Box" Then
		Object.Service = "https://dav.box.com/dav"
	ElsIf ServicePresentation = "Dropbox" Then
		Object.Service = "https://dav.dropdav.com"
	Else
		Object.Service = "";
	EndIf;

EndProcedure

&AtClient
Procedure AsFilesAuthorOnChange(Item)
	
	Object.FilesAuthor = Undefined;
	Items.FilesAuthor.Enabled = False;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure CheckSettings(Command)
	
	ClearMessages();
	
	If Object.Ref.IsEmpty() Or Modified Then
		NotifyDescription = New NotifyDescription("CheckSettingsCompletion", ThisObject);
		QuestionText = NStr("ru = 'Для проверки настроек необходимо записать данные учетной записи. Продолжить?'; en = 'To check the settings, write the account data. Continue?'; pl = 'Aby zweryfikować ustawienia, należy zapisać dane konta. Kontynuować?';es_ES = 'Para comprobar lo ajustes es necesario guardar los datos de la cuenta. ¿Continuar?';es_CO = 'Para comprobar lo ajustes es necesario guardar los datos de la cuenta. ¿Continuar?';tr = 'Ayarları doğrulamak için hesap bilgilerini kaydetmeniz gerekir. Devam etmek istiyor musunuz?';it = 'Per verificare le impostazioni, registrare i dati di account. Continuare?';de = 'Um die Einstellungen zu überprüfen, müssen Sie die Kontodaten aufschreiben. Fortsetzen?'");
		Buttons = New ValueList;
		Buttons.Add("Continue", NStr("ru = 'Продолжить'; en = 'Continue'; pl = 'Kontynuuj';es_ES = 'Continuar';es_CO = 'Continuar';tr = 'Devam';it = 'Continua';de = 'Weiter'"));
		Buttons.Add(DialogReturnCode.Cancel);
		ShowQueryBox(NotifyDescription, QuestionText, Buttons);
	Else
		CheckCanSyncWithCloudService();
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_AllowObjectAttributesEditing(Command)
	
	ModuleObjectAttributesLockClient = CommonClient.CommonModule("ObjectAttributesLockClient");
	ModuleObjectAttributesLockClient.AllowObjectAttributeEdit(ThisObject);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure CheckSettingsCompletion(DialogResult, AdditionalParameters) Export
	
	If DialogResult <> "Continue" Then
		Return;
	EndIf;
	
	If Not Write() Then
		Return;
	EndIf;
	
	CheckCanSyncWithCloudService();
	
EndProcedure

&AtClient
Procedure CheckCanSyncWithCloudService()
	
	ResultStructure = Undefined;
	
	ExecuteConnectionCheck(Object.Ref, ResultStructure);
	
	ResultProtocol = ResultStructure.ResultProtocol;
	ResultText = ResultStructure.ResultText;
	
	If ResultStructure.Cancel Then
		ShowMessageBox(Undefined, StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Проверка параметров учетной записи завершилась с ошибками.
					   |Проверьте правильность задания корневой папки, логина и пароля.
					   |
					   |Технические подробности:
					   |
					   |%1'; 
					   |en = 'Errors occurred while checking the account parameters.
					   |Make sure the root folder, username, and password are correct.
					   |
					   |Technical details:
					   |
					   |%1'; 
					   |pl = 'Weryfikacja parametrów konta została zakończona z błędami.
					   |Sprawdź, czy prawidłowo określono katalog główny, imię użytkownika i hasło.
					   |
					   |Szczegóły techniczne:
					   |
					   |%1';
					   |es_ES = 'La prueba de los parámetros de la cuenta se ha terminado con errores.
					   |Compruebe si la tarea de carpeta de raíz, el nombre o la contraseña están correctas.
					   |
					   |Detalles técnicos:
					   |
					   |%1';
					   |es_CO = 'La prueba de los parámetros de la cuenta se ha terminado con errores.
					   |Compruebe si la tarea de carpeta de raíz, el nombre o la contraseña están correctas.
					   |
					   |Detalles técnicos:
					   |
					   |%1';
					   |tr = 'Hesap ayarlarını doğrulama hataları ile sona erdi. 
					   |Kök klasör, oturum açma ve parola ayarının doğru olup olmadığını kontrol edin. 
					   |
					   |Teknik detaylar:
					   |
					   |%1';
					   |it = 'Si è registrato un errore durante il controllo dei parametri dell''account.
					   |Assicuratevi che la cartella radice, il nome utente e la password siano corrette.
					   |
					   |Dettagli tecnici:
					   |
					   |%1';
					   |de = 'Bei der Überprüfung der Kontenparameter sind Fehler aufgetreten.
					   |Stellen Sie sicher, dass der Stammordner, der Benutzername und das Passwort korrekt sind.
					   |
					   |Technische Details:
					   |
					   |%1'"),
					   StringFunctionsClientServer.ExtractTextFromHTML(ResultProtocol)),,
			NStr("ru = 'Проверка учетной записи'; en = 'Checking accounts'; pl = 'Sprawdź konto';es_ES = 'Revisar la cuenta';es_CO = 'Revisar la cuenta';tr = 'Hesabı kontrol et';it = 'Controllando l''account';de = 'Konto prüfen'"));
	Else
		ShowMessageBox(Undefined, StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Проверка параметров учетной записи завершилась успешно. 
					   |%1'; 
					   |en = 'Account parameters check is completed successfully.
					   |%1'; 
					   |pl = 'Sprawdzenie parametrów konta zakończyło się pomyślnie. 
					   |%1';
					   |es_ES = 'La prueba de los parámetros de la cuenta se ha terminado con éxito. 
					   |%1';
					   |es_CO = 'La prueba de los parámetros de la cuenta se ha terminado con éxito. 
					   |%1';
					   |tr = 'Hesap parametresi kontrolü başarıyla tamamlandı.
					   |%1';
					   |it = 'Il controllo dei parametri dell''account è stato completato con successo.
					   |%1';
					   |de = 'Die Überprüfung der Kontenparameter wurde erfolgreich abgeschlossen.
					   |%1'"),
			ResultText),,
			NStr("ru = 'Проверка учетной записи'; en = 'Checking accounts'; pl = 'Sprawdź konto';es_ES = 'Revisar la cuenta';es_CO = 'Revisar la cuenta';tr = 'Hesabı kontrol et';it = 'Controllando l''account';de = 'Konto prüfen'"));
	EndIf;
		
EndProcedure

&AtServer
Procedure ExecuteConnectionCheck(Account, ResultStructure)
	FilesOperationsInternal.ExecuteConnectionCheck(Account, ResultStructure);
EndProcedure

&AtClient
Procedure AsFilesAuthorUserOnChange(Item)
	
	Items.FilesAuthor.Enabled = True;
	
EndProcedure

#EndRegion