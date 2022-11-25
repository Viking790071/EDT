#Region Public

// Method recalculate exchange rate text.
//
// Parameters:
// CurrencyRateInLetters	  - String -  Exchange rate for Document's date (ex."1 USD = 0,8315 EUR")
// RateNewCurrenciesInLetters - String -  Exchange rate for new date (ex."1 USD = 0,8432 EUR")
//
// Returns:
// RecalculateExchangeRateText - message text
//
Function RecalculateExchangeRateText(CurrencyRateInLetters, RateNewCurrenciesInLetters) Export
	
	Return StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Exchange rate of the transaction currency for this Document was set to %1.
			 |Do you wish to update exchange rate according to the new date? (%2)'; 
			 |ru = 'На дату документа был задан курс валюты расчетов %1.
			 |Установить курс валюты расчетов в соответствии с новой датой документа? (%2)';
			 |pl = 'Kurs wymiany waluty transakcji dla tego dokumentu został ustawiony na %1.
			 |Czy chcesz zaktualizować kurs wymiany zgodnie z nową datą? (%2)';
			 |es_ES = 'Tipo de cambio de la moneda de transacción para el Documento se ha establecido para %1.
			 |¿Quiere actualizar el tipo de cambio según la fecha nueva? (%2)';
			 |es_CO = 'Tipo de cambio de la moneda de transacción para el Documento se ha establecido para %1.
			 |¿Quiere actualizar el tipo de cambio según la fecha nueva? (%2)';
			 |tr = 'Bu Belge için işlem para biriminin döviz kuru %1 olarak ayarlandı. 
			 |Döviz kurunu yeni tarihe göre güncellemek ister misiniz? (%2)';
			 |it = 'Il tasso di cambio della valuta della transazione per questo Documento è stato impostato a %1.
			 |Volete aggiornare il tasso di cambio in accodo con la nuova data? (%2)';
			 |de = 'Der Wechselkurs der Transaktionswährung für dieses Dokument wurde auf %1.
			 |Eingestellt. Möchten Sie den Wechselkurs entsprechend dem neuen Datum aktualisieren? (%2)'"),
		CurrencyRateInLetters,
		RateNewCurrenciesInLetters);
		
EndFunction

#EndRegion
