#Region Internal

// Open external data processor form - ExchangeRatesImportProcessor
Procedure OpenFormOfExchangeRatesImportProcessor(FormParameters = Undefined) Export         
	
	// Check for data processor
	CurrenciesExchangeRatesServerCallDrive.CheckAbilityOfUsingExchangeRatesImportProcessor();
	
	OpenForm("DataProcessor.ImportCurrenciesRates.Form", FormParameters);
	
EndProcedure

#EndRegion