////////////////////////////////////////////////////////////////////////////////
// Subsystem "Dynamic configuration update control".
//  
////////////////////////////////////////////////////////////////////////////////

#Region ServiceApplicationInterface

// Running on the interactive beginning of user work with data area or in local mode.
// Called after the complete OnStart actions.
// Used to connect wait handlers that should not be called on interactive actions before and during the system start.
//
Procedure AfterSystemOperationStart() Export
	
	AttachIdleHandler("IdleHandlerOfIBDynamicChangesCheckup", 20 * 60); // every 20 minutes
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Wait handler verifies that infobase was updated dynamically and reports this to the user.
// 
Procedure DynamicUpdateCheckWaitHandler() Export
	
	If Not ConfigurationDynamicUpdateControlServerCall.DBConfigurationWasChangedDynamically() Then
		Return;
	EndIf;
		
	DetachIdleHandler("IdleHandlerOfIBDynamicChangesCheckup");
	
	MessageText = NStr("en = 'Application version has been updated (changes were made to the info base configuration).
	                   |It is recommended to restart the application for further operations.
	                   |Restart now?'; 
	                   |ru = 'Версия программы обновлена (внесены изменения в конфигурацию информационной базы).
	                   |Для дальнейшей работы рекомендуется перезапустить программу.
	                   |Перезапустить?';
	                   |pl = 'Wersja aplikacji została zaktualizowana (zmiany wprowadzono w konfiguracji bazy informacyjnej).
	                   |Zaleca się ponowne uruchomienie aplikacji w celu dalszych operacji.
	                   |Czy chcesz teraz zrestartować?';
	                   |es_ES = 'Versión de la aplicación se ha actualizado (cambios se han hecho para la configuración de la infobase).
	                   |Se recomienda reiniciar la aplicación para futuras operaciones.
	                   |¿Reiniciar ahora?';
	                   |es_CO = 'Versión de la aplicación se ha actualizado (cambios se han hecho para la configuración de la infobase).
	                   |Se recomienda reiniciar la aplicación para futuras operaciones.
	                   |¿Reiniciar ahora?';
	                   |tr = 'Uygulama sürümü güncellendi (veritabanı yapılandırmasında değişiklikler yapıldı). 
	                   |Diğer işlemler için uygulamayı tekrar başlatmanız önerilir. 
	                   |Şimdi yeniden başlatmak istiyor musunuz?';
	                   |it = 'La versione della applicazione è stata aggiornata (sono state apportate modifiche alla configurazione dell''infobase).
	                   |Si consiglia di riavviare l''applicazione per ulteriori operazioni.
	                   |Riavviare adesso?';
	                   |de = 'Die Anwendungsversion wurde aktualisiert (Änderungen wurden an der Konfiguration der Infobase vorgenommen).
	                   |Es wird empfohlen, die Anwendung für weitere Operationen neu zu starten.
	                   |Jetzt neu starten?'");
								
	NotifyDescription = New NotifyDescription("DynamicUpdateCheckWaitHandlerEnd", ThisObject);
	ShowQueryBox(NotifyDescription, MessageText, QuestionDialogMode.YesNo);
	
EndProcedure

// Alert handler called from procedure IdleHandlerOfIBDynamicChangesCheckup.
//
Procedure DynamicUpdateCheckWaitHandlerEnd(Response, AdditionalParameters) Export
	
	If Response = DialogReturnCode.Yes Then
		StandardSubsystemsClient.SkipExitConfirmation();
		Exit(True, True);
	EndIf;
	
	AttachIdleHandler("IdleHandlerOfIBDynamicChangesCheckup", 20 * 60); // every 20 minutes
	
EndProcedure

#EndRegion
