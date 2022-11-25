#Region FormCommandHandlers

&AtClient
Procedure GoToSettingsClick(Item)
	Close();
	OpenForm("DataProcessor.MonitoringCenterSettings.Form.MonitoringCenterSettings");
EndProcedure

&AtClient
Procedure Yes(Command)
	NewParameters = New Structure("SendDumpsFiles", 1);
	SetMonitoringCenterParameters(NewParameters);
	Close();
EndProcedure

&AtClient
Procedure None(Command)
	NewParameters = New Structure("SendDumpsFiles", 0);
	NewParameters.Insert("SendingResult", NStr("ru = 'Пользователь отказал в предоставлении полных дампов.';
														|en = 'User refused to submit full dumps.';pl = 'Użytkownik odmówił przesyłania pełnych zrzutów.';es_ES = 'El usuario se negó a enviar los volcados por completo.';es_CO = 'El usuario se negó a enviar los volcados por completo.';tr = 'Kullanıcı tam döküm göndermeyi reddetti.';it = 'L''utente ha rifiutato di trasmettere i dump interi.';de = 'Der Benutzer lehnte Einreichen von vollen Dumps ab.'"));
	SetMonitoringCenterParameters(NewParameters);
	Close();
EndProcedure

#EndRegion

#Region Private

&AtServerNoContext
Procedure SetMonitoringCenterParameters(NewParameters)
	MonitoringCenterInternal.SetMonitoringCenterParametersExternalCall(NewParameters);
EndProcedure

#EndRegion

