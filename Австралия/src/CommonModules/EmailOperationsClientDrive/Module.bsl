#Region Private

// Validating email account.
//
// See procedure EmailOperationsInternal.CheckCanSendReceiveEmail.
//
Procedure CheckCanSendReceiveEmail(ResultHandler, Account) Export
	
	ErrorMessage = "";
	AdditionalMessage = "";
	EmailServerCall.CheckSendReceiveEmailAvailability(Account, ErrorMessage, AdditionalMessage);
	
	If ValueIsFilled(ErrorMessage) Then
		ShowMessageBox(ResultHandler, StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Проверка параметров учетной записи завершилась с ошибками:
					   |%1'; 
					   |en = 'Account parameters check is completed with errors:
					   |%1'; 
					   |pl = 'Weryfikacja parametrów konta została zakończona z błędami:
					   |%1';
					   |es_ES = 'Revisión de parámetros de la cuenta se ha finalizado con errores:
					   |%1';
					   |es_CO = 'Revisión de parámetros de la cuenta se ha finalizado con errores:
					   |%1';
					   |tr = 'Hesap parametreleri kontrolü hatalarla tamamlandı:
					   |%1';
					   |it = 'Il controllo dei parametri contabili è completato con errori:
					   |%1';
					   |de = 'Die Überprüfung der Kontenparameter ist fehlerhaft verlaufen:
					   |%1'"), ErrorMessage ),,
			NStr("ru = 'Проверка учетной записи'; en = 'Check account'; pl = 'Sprawdź konto';es_ES = 'Revisar la cuenta';es_CO = 'Revisar la cuenta';tr = 'Hesabı kontrol et';it = 'Controllare account Email';de = 'Konto prüfen'"));
	Else
		ShowMessageBox(ResultHandler, StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Проверка параметров учетной записи завершилась успешно. %1'; en = 'Account parameters check is completed successfully. %1'; pl = 'Sprawdzenie parametrów konta zakończyło się pomyślnie. %1';es_ES = 'Revisión de los parámetros de la cuenta se ha finalizado con éxito. %1';es_CO = 'Revisión de los parámetros de la cuenta se ha finalizado con éxito. %1';tr = 'Hesap parametresi kontrolü başarıyla tamamlandı.%1';it = 'Il controllo dei parametri contabili è completato con successo. %1';de = 'Die Überprüfung der Kontoparameter wurde erfolgreich abgeschlossen. %1'"),
			AdditionalMessage),,
			NStr("ru = 'Проверка учетной записи'; en = 'Check account'; pl = 'Sprawdź konto';es_ES = 'Revisar la cuenta';es_CO = 'Revisar la cuenta';tr = 'Hesabı kontrol et';it = 'Controllare account Email';de = 'Konto prüfen'"));
	EndIf;
	
EndProcedure

#EndRegion
