////////////////////////////////////////////////////////////////////////////////
// Subsystem "Banks".
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProgramInterface

// It is called once the configuration is launched, activates the wait handler.
//
Procedure AfterSystemOperationStart() Export
	
	ClientParameters = StandardSubsystemsClientCached.ClientParametersOnStart();
	If ClientParameters.Property("Banks") AND ClientParameters.Banks.StaleAlertOutput Then
		AttachIdleHandler("BankManagerDisplayObsoleteDataWarning", 45, True);
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

#Region UpdateOfTheBankClassifier

// Displays an appropriate notification.
//
Procedure NotifyClassifierOutOfDate() Export
	
	ShowUserNotification(
		NStr("en = 'Bank classifier is outdated'; ru = 'Классификатор банков устарел';pl = 'Klasyfikator bankowy jest nieaktualny';es_ES = 'Clasificador de bancos está desactualizado';es_CO = 'Clasificador de bancos está desactualizado';tr = 'Banka sınıflandırıcı zaman aşımına uğramış';it = 'Il Classificatore Banche è obsoleto';de = 'Bank-Klassifikator ist veraltet'"),
		URLFormsExport(),
		NStr("en = 'Update the bank clasifier'; ru = 'Обновите классификатор банков';pl = 'Zaktualizuj klasyfikator bankowy';es_ES = 'Actualizar el clasificador de bancos';es_CO = 'Actualizar el clasificador de bancos';tr = 'Banka sınıflandırıcıyı güncelleyin';it = 'Aggiornare il classificatore bancario';de = 'Aktualisieren Sie die Bank-Klassifikator'"),
		PictureLib.Warning32);
	
EndProcedure

// Displays an appropriate notification.
//
Procedure NotifyClassifierUpdatedSuccessfully() Export
	
	ShowUserNotification(
		NStr("en = 'Bank classifier has been successfully updated'; ru = 'Классификатор банков успешно обновлен';pl = 'Klasyfikator bankowy został pomyślnie zaktualizowany';es_ES = 'Clasificador de bancos de la actualizado con éxito';es_CO = 'Clasificador de bancos de la actualizado con éxito';tr = 'Banka sınıflandırıcı başarıyla güncellendi';it = 'Il Classificatore Banche è stato aggiornato con successo';de = 'Bank-Klassifikator wurde erfolgreich aktualisiert'"),
		URLFormsExport(),
		NStr("en = 'Bank classifier is updated'; ru = 'Классификатор банков обновлен';pl = 'Klasyfikator bankowy jest aktualizowany';es_ES = 'Clasificador de bancos está actualizado';es_CO = 'Clasificador de bancos está actualizado';tr = 'Banka sınıflandırıcı güncellendi';it = 'Il Classificatore Banche viene aggiornato';de = 'Bank-Klassifikator ist aktualisiert'"),
		PictureLib.Information32);
	
EndProcedure

// Displays an appropriate notification.
//
Procedure NotifyClassifierIsActual() Export
	
	ShowMessageBox(,NStr("en = 'The bank classifier is up-to-date and doesn''t need an update.'; ru = 'Классификатор банков актуален и не нуждается в обновлении.';pl = 'Klasyfikator bankowy jest aktualny i nie wymaga aktualizacji.';es_ES = 'El clasificador de bancos está actualizado y no necesita ninguna actualización.';es_CO = 'El clasificador de bancos está actualizado y no necesita ninguna actualización.';tr = 'Banka sınıflandırıcısı günceldir ve bir güncellemeye ihtiyaç duymuyor.';it = 'Il classificatore banca è up-to-date e non ha bisogno di un aggiornamento.';de = 'Der Bank Klassifikator ist auf dem neuesten Stand und benötigt keine Aktualisierung.'"));
	
EndProcedure

// Returns the navigational link for the notifications.
//
Function URLFormsExport()
	Return "e1cib/data/Catalog.BankClassifier.Form.ImportClassifier";
EndFunction

#EndRegion

#EndRegion
