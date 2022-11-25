
#Region EventHandlers

&AtClient
Procedure OnOpen(Cancel)
	ItemsCount = 0;
	If FilesOperationsInternalClient.InitAddIn() Then
		DeviceArray = FilesOperationsInternalClient.EnumDevices();
		For Each Row In DeviceArray Do
			ItemsCount = ItemsCount + 1;
			Items.DeviceName.ChoiceList.Add(Row);
		EndDo;
	EndIf;
	If ItemsCount = 0 Then
		Cancel = True;
		ShowMessageBox(, NStr("ru = 'Не установлен сканер. Обратитесь к администратору программы.'; en = 'Scanner is not installed. Contact the application administrator.'; pl = 'Skaner nie jest zainstalowany. Skontaktuj się z administratorem aplikacji.';es_ES = 'Escáner no se ha instalado. Contactar el administrador de la aplicación.';es_CO = 'Escáner no se ha instalado. Contactar el administrador de la aplicación.';tr = 'Tarayıcı yüklü değil. Uygulama yöneticisine başvurun.';it = 'Scanner non installato. Contattate l''amministratore del sistema.';de = 'Scanner ist nicht installiert. Wenden Sie sich an den Anwendungsadministrator.'"));
	Else
		Items.DeviceName.ListChoiceMode = True;
	EndIf;
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ChooseScanner(Command)
	
	If IsBlankString(DeviceName) Then
		MessageText = NStr("ru = 'Не выбран сканер.'; en = 'Scanner is not selected.'; pl = 'Nie wybrano skanera.';es_ES = 'Escáner no seleccionado.';es_CO = 'Escáner no seleccionado.';tr = 'Tarayıcı seçilmedi.';it = 'Scanner non selezionato.';de = 'Kein Scanner ausgewählt.'");
		CommonClientServer.MessageToUser(MessageText, , "DeviceName");
		Return;
	EndIf;
	
	SystemInfo = New SystemInfo();
	CommonServerCall.CommonSettingsStorageSave(
		"ScanningSettings/DeviceName",
		SystemInfo.ClientID,
		DeviceName,
		,
		,
		True);
	Close(DeviceName);
EndProcedure

#EndRegion