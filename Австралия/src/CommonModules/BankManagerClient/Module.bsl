#Region Internal

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See CommonClientOverridable.AfterStart. 
Procedure AfterStart() Export
	
	ClientParameters = StandardSubsystemsClient.ClientParametersOnStart();
	If ClientParameters.Property("Banks") AND ClientParameters.Banks.ShowMessageOnInvalidity Then
		AttachIdleHandler("BankManagerDisplayObsoleteDataWarning", 45, True);
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Bank classifier update.

// Displays the update notification.
//
Procedure NotifyClassifierObsolete() Export
	
	ShowUserNotification(
		NStr("ru = 'Классификатор банков устарел'; en = 'Bank classifier is outdated'; pl = 'Klasyfikator bankowy jest nieaktualny';es_ES = 'Clasificador de bancos está desactualizado';es_CO = 'Clasificador de bancos está desactualizado';tr = 'Banka sınıflandırıcı zaman aşımına uğramış';it = 'Il Classificatore Banche è obsoleto';de = 'Bank-Klassifikator ist veraltet'"),
		NotificationURLImportForm(),
		NStr("ru = 'Обновить классификатор банков'; en = 'Update bank classifier'; pl = 'Zaktualizować klasyfikator banków';es_ES = 'Actualizar el clasificador de los bancos';es_CO = 'Actualizar el clasificador de los bancos';tr = 'Banka sınıflandırıcısını yenile';it = 'Aggiornamento classificatore banche';de = 'Bankklassifikator aktualisieren'"),
		PictureLib.Warning32);
	
EndProcedure

// Displays the update notification.
//
Procedure NotifyClassifierSuccessfullyUpdated() Export
	
	ShowUserNotification(
		NStr("ru = 'Классификатор банков успешно обновлен'; en = 'Bank classifier is successfully updated'; pl = 'Klasyfikator bankowy został pomyślnie zaktualizowany';es_ES = 'Clasificador de bancos de la actualizado con éxito';es_CO = 'Clasificador de bancos de la actualizado con éxito';tr = 'Banka sınıflandırıcı başarıyla güncellendi';it = 'Il classificatore banche è stato aggiornato con successo';de = 'Bank-Klassifikator wurde erfolgreich aktualisiert'"),
		NotificationURLImportForm(),
		NStr("ru = 'Классификатор банков обновлен'; en = 'Bank classifier is updated'; pl = 'Klasyfikator bankowy jest aktualizowany';es_ES = 'Clasificador de bancos está actualizado';es_CO = 'Clasificador de bancos está actualizado';tr = 'Banka sınıflandırıcı güncellendi';it = 'Il Classificatore Banche viene aggiornato';de = 'Bank-Klassifikator ist aktualisiert'"),
		PictureLib.Information32);
	
EndProcedure

// Displays the update notification.
//
Procedure NotifyClassifierUpToDate() Export
	
	ShowMessageBox(,NStr("ru = 'Классификатор банков актуален.'; en = 'Bank classifier is up-to-date.'; pl = 'Klasyfikator banków aktualny.';es_ES = 'Clasificador de los bancos está actualizado.';es_CO = 'Clasificador de los bancos está actualizado.';tr = 'Banka sınıflandırıcısı günceldir.';it = 'Il classificatore banche è aggiornato.';de = 'Bankklassifikator ist aktuell.'"));
	
EndProcedure

// Returns a notification URL.
//
Function NotificationURLImportForm()
	Return "e1cib/data/DataProcessor.ImportBankClassifier.Form.ImportClassifier";
EndFunction

Procedure OpenClassifierImportForm(Owner, OpenFromList = False) Export
	If OpenFromList Then
		FormParameters = New Structure("OpeningFromList", OpenFromList);
	EndIf;
	FormName = "Catalog.BankClassifier.Form.ImportClassifier";
	OpenForm(FormName, FormParameters, Owner);
EndProcedure

#EndRegion
