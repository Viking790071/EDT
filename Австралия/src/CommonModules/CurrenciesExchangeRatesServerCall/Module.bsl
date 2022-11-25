#Region Private

// Checks whether all currency rates are up-to-date.
//
Function RatesUpToDate() Export
	Return CurrencyRateOperations.RatesUpToDate();
EndFunction

#EndRegion
