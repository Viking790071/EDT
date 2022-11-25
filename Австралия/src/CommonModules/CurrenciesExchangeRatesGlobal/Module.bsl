#Region Private

// Notifies that currency rates must be updated.
//
Procedure CurrencyRateOperationsOutputObsoleteDataNotification() Export
	If NOT CurrenciesExchangeRatesServerCall.RatesUpToDate() Then
		CurrencyRateOperationsClient.NotifyRatesObsolete();
	EndIf;
	
	CurrentDate = CommonClient.SessionDate();
	NextDayHandlerPeriod = EndOfDay(CurrentDate) - CurrentDate + 59;
	AttachIdleHandler("CurrencyRateOperationsOutputObsoleteDataNotification", NextDayHandlerPeriod, True);
EndProcedure

#EndRegion
