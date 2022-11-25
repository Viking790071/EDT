#Region Public

// Converts the Amount from the Source Currency to the New Currency according to their rate parameters.
//   To get currency rate parameters, use the function
//   CurrencyExchangeRates.GetCurrencyRate(RateDate, Currency, Company).
//
// Parameters:
//   Amount - Number - the amount to be converted.
//   CurrentRateParameters - Structure - the rate parameters for the source currency.
//       * Currency    - CatalogRef.Currencies - reference to the currency to be converted.
//       * Rate      - Number - Rate of the currency being converted.
//       * Multiplier - Number - Multiplier for the currency being converted.
//   NewRateParameters   - Structure - the rate parameters for the new currency.
//       * Currency    - CatalogRef.Currencies - Reference to the currency to convert to.
//       * Rate      - Number - Rate of the currency to convert to.
//       * Multiplier - Number - Multiplier of the currency to convert to.
//
// Returns:
//   Number - the amount converted at the new rate.
//
Function ConvertAtRate(Amount, ExchangeRateMethod, SourceRateParameters, NewRateParameters) Export
	If SourceRateParameters.Currency = NewRateParameters.Currency
		Or (SourceRateParameters.Rate = NewRateParameters.Rate 
			AND SourceRateParameters.Repetition = NewRateParameters.Repetition) Then
		
		Return Amount;
	EndIf;
	
	If SourceRateParameters.Rate = 0
		Or SourceRateParameters.Repetition = 0
		Or NewRateParameters.Rate = 0
		Or NewRateParameters.Repetition = 0 Then
		
		CommonClientServer.MessageToUser(StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'При пересчете в валюту %1 сумма %2 установлена в нулевое значение, т.к. курс валюты не задан.'; en = 'When converting into currency %1, the amount %2 was set to zero because the currency exchange rate was not specified.'; pl = 'Podczas konwersji na walutę %1, suma %2 została ustawiona na zero, ponieważ nie podano kursu waluty.';es_ES = 'Al convertir en la moneda %1, la suma %2 se ha establecido a nula porque el tipo de la moneda no se había especificado.';es_CO = 'Al convertir en la moneda %1, la suma %2 se ha establecido a nula porque el tipo de la moneda no se había especificado.';tr = 'Para biriminin döviz kuru belirtilmediğinden, %1 para birimine dönüştürülürken %2 tutarı sıfır olarak ayarlandı.';it = 'Durante la conversione nella valuta %1, l''importo %2 è stato impostato a zero perchè il tasso di cambio non è specificato.';de = 'Bei der Währungsumrechnung %1 wurde die Summe %2 auf null gesetzt, da der Wechselkurs nicht angegeben wurde.'"), 
				NewRateParameters.Currency, 
				Format(Amount, "NFD=2; NZ=0")));
		
		Return 0;
		
	EndIf;
	
	If ExchangeRateMethod = PredefinedValue("Enum.ExchangeRateMethods.Multiplier") Then
		
		Return Round((Amount * SourceRateParameters.Rate * NewRateParameters.Repetition) / (NewRateParameters.Rate * SourceRateParameters.Repetition), 2);
		
	ElsIf ExchangeRateMethod = PredefinedValue("Enum.ExchangeRateMethods.Divisor") Then
		
		Return Round((Amount * NewRateParameters.Rate * SourceRateParameters.Repetition) / (SourceRateParameters.Rate * NewRateParameters.Repetition), 2);
		
	Else
		
		CommonClientServer.MessageToUser(StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'When converting into currency %1, the amount %2 was set to zero because the exchange rate method was not specified in current company.'; ru = 'При пересчете в валюту %1 сумма %2 установлена в нулевое значение, т.к. метод расчета курсов валют не задан для текущей организации.';pl = 'Podczas konwersji na walutę %1, kwota %2 została ustawiona na zero, ponieważ nie podano kursu waluty w bieżącej firmie.';es_ES = 'Al convertir en la moneda %1 la suma %2 se ha establecido a cero porque el método del tipo de cambio no estaba especificado en la empresa actual.';es_CO = 'Al convertir en la moneda %1 la suma %2 se ha establecido a cero porque el método del tipo de cambio no estaba especificado en la empresa actual.';tr = 'Mevcut iş yerinde döviz kuru yöntemi belirtilmediğinden, %1 para birimine dönüştürülürken %2 tutarı sıfır olarak ayarlandı.';it = 'Durante la conversione nella valuta %1, l''importo %2 è stato impostato a zero perchè il metodo di tasso di cambio non è stato impostato per la azienda corrente.';de = 'Bei der Währungsumrechnung %1 wurde die Summe %2 auf Null gesetzt, da die Wechselkursmethode in dieser Firma nicht angegeben wurde.'"), 
				NewRateParameters.Currency, 
				Format(Amount, "NFD=2; NZ=0")));
		
		Return 0;
		
	EndIf;
	
EndFunction

#Region ObsoleteProceduresAndFunctions

// Obsolete. Use ConvertAtRate instead.
//
// Converts the amount from the currency CurrencyTrg at the rate of AtRateSrc into the currency 
// CurrencyTrg at the rate of AtRateTrg.
//
// Parameters:
//   Amount - Number - the amount to be converted.
//   CurrencySrc      - CatalogRef.Currencies - the source currency.
//   CurrencyDst      - CatalogRef.Currencies - the destination currency.
//   AtRateSrc     - Number - the source currency rate.
//   AtRateDst     - Number - the destination currency rate.
//   ByMultiplierSrc - Number - the source currency rate multiplier (the default value is 1).
//   ByMultiplierDst - Number - the destination currency rate multiplier (the default value is 1).
//
// Returns:
//   Number - The converted amount.
//
Function ConvertCurrencies(Amount, ExchangeRateMethod, CurrencySrc, CurrencyDst, AtRateSrc, AtRateDst, 
	ByMultiplierSrc = 1, ByMultiplierDst = 1) Export
	
	Return ConvertAtRate(
		Amount,
		ExchangeRateMethod,
		New Structure("Currency, Rate, Repetition", CurrencySrc, AtRateSrc, ByMultiplierSrc),
		New Structure("Currency, Rate, Repetition", CurrencyDst, AtRateDst, ByMultiplierDst));
	
EndFunction

#EndRegion

#EndRegion
