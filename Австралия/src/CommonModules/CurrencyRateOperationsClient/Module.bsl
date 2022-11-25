#Region Internal

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See CommonClientOverridable.AfterStart. 
Procedure AfterStart() Export
	
	ClientParameters = StandardSubsystemsClient.ClientParametersOnStart();
	If ClientParameters.Property("Currencies") AND ClientParameters.Currencies.RatesUpdatedByEmployeesResponsible Then
		AttachIdleHandler("CurrencyRateOperationsOutputObsoleteDataNotification", 15, True);
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Currency rates update.

// Displays the update notification.
//
Procedure NotifyRatesObsolete() Export
	
	ShowUserNotification(
		NStr("ru = 'Курсы валют устарели'; en = 'Exchange rates are outdated'; pl = 'Kursy wymiany walut są nieaktualne';es_ES = 'Tipos de cambio están desactualizados';es_CO = 'Tipos de cambio están desactualizados';tr = 'Döviz kurları güncel değil';it = 'I tassi di cambio non sono aggiornati';de = 'Wechselkurse sind veraltet'"),
		DataProcessorURL(),
		NStr("ru = 'Обновить курсы валют'; en = 'Update exchange rates'; pl = 'Zaktualizuj kursy wymiany walut';es_ES = 'Actualizar los tipos de cambio';es_CO = 'Actualizar los tipos de cambio';tr = 'Döviz kurlarını güncelle';it = 'Aggiornare i tassi di cambio';de = 'Wechselkurs aktualisieren'"),
		PictureLib.Warning32);
	
EndProcedure

// Displays the update notification.
//
Procedure NotifyRatesAreUpdated() Export
	
	ShowUserNotification(
		NStr("ru = 'Курсы валют успешно обновлены'; en = 'Exchange rates are updated'; pl = 'Kursy wymiany są aktualizowane';es_ES = 'Tipos de cambio se han actualizado';es_CO = 'Tipos de cambio se han actualizado';tr = 'Döviz kurları güncellendi';it = 'I tassi di cambio sono aggiornati';de = 'Wechselkurse werden aktualisiert'"),
		,
		NStr("ru = 'Курсы валют обновлены'; en = 'The exchange rates are updated.'; pl = 'Kursy wymiany są aktualizowane';es_ES = 'Tipos de cambio se han actualizado';es_CO = 'Tipos de cambio se han actualizado';tr = 'Döviz kurları güncellendi.';it = 'Tassi di cambio aggiornati.';de = 'Wechselkurse werden aktualisiert'"),
		PictureLib.Information32);
	
EndProcedure

// Displays the update notification.
//
Procedure NotifyRatesUpToDate() Export
	
	ShowMessageBox(,NStr("ru = 'Курсы валют актуальны.'; en = 'The exchange rates are up-to-date.'; pl = 'Kursy wymiany są istotne.';es_ES = 'Tipos de cambio son relevantes.';es_CO = 'Tipos de cambio son relevantes.';tr = 'Döviz kurları güncel.';it = 'I tassi di cambio sono attuali.';de = 'Wechselkurse sind relevant.'"));
	
EndProcedure

// Returns a notification URL.
//
Function DataProcessorURL()
	Return "e1cib/app/DataProcessor.ImportCurrenciesRates";
EndFunction

#EndRegion
