#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Variables

Var ErrorInRateCalculationByFormula;

#EndRegion

#Region EventHandlers

// The dependent currency rates are controlled while writing.
//
Procedure OnWrite(Cancel, Replacing)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If AdditionalProperties.Property("DisableDependentCurrenciesControl") Then
		Return;
	EndIf;
		
	AdditionalProperties.Insert("DependentCurrencies", New Map);
	
	If Count() > 0 Then
		UpdateSubordinateCurrenciesRates();
	Else
		DeleteDependentCurrencyRates();
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

// Finds all dependent currencies and changes their rate.
//
Procedure UpdateSubordinateCurrenciesRates()
	
	DependentCurrency = Undefined;
	AdditionalProperties.Property("UpdateSubordinateCurrencyRate", DependentCurrency);
	If DependentCurrency <> Undefined Then
		DependentCurrency = Common.ObjectAttributesValues(DependentCurrency, 
			"Ref,Markup,RateSource,RateCalculationFormula");
	EndIf;
	
	For Each BaseCurrencyRecord In ThisObject Do

		If DependentCurrency <> Undefined Then // Only the given currency's rate must be updated.
			UpdatedPeriods = Undefined;
			If Not AdditionalProperties.Property("UpdatedPeriods", UpdatedPeriods) Then
				UpdatedPeriods = New Map;
				AdditionalProperties.Insert("UpdatedPeriods", UpdatedPeriods);
			EndIf;
			// The rate is not updated more than once over the same period of time.
			If UpdatedPeriods[BaseCurrencyRecord.Period] = Undefined Then
				UpdateSubordinateCurrencyRate(DependentCurrency, BaseCurrencyRecord); 
				UpdatedPeriods.Insert(BaseCurrencyRecord.Period, True);
			EndIf;
		Else	// Refresh the rate for all dependent currencies.
			DependentCurrencies = CurrencyRateOperations.DependentCurrenciesList(BaseCurrencyRecord.Currency, AdditionalProperties);
			For Each DependentCurrency In DependentCurrencies Do
				UpdateSubordinateCurrencyRate(DependentCurrency, BaseCurrencyRecord); 
			EndDo;
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure UpdateSubordinateCurrencyRate(DependentCurrency, BaseCurrencyRecord)
	
	RecordSet = InformationRegisters.ExchangeRate.CreateRecordSet();
	RecordSet.Filter.Currency.Set(DependentCurrency.Ref, True);
	RecordSet.Filter.Company.Set(BaseCurrencyRecord.Company, True);
	RecordSet.Filter.Period.Set(BaseCurrencyRecord.Period, True);
	
	WriteCurrencyRate = RecordSet.Add();
	WriteCurrencyRate.Currency = DependentCurrency.Ref;
	WriteCurrencyRate.Company = BaseCurrencyRecord.Company;
	WriteCurrencyRate.Period = BaseCurrencyRecord.Period;
	If DependentCurrency.RateSource = Enums.RateSources.MarkupForOtherCurrencyRate Then
		WriteCurrencyRate.Rate = BaseCurrencyRecord.Rate + BaseCurrencyRecord.Rate * DependentCurrency.Markup / 100;
		WriteCurrencyRate.Repetition = BaseCurrencyRecord.Repetition;
	Else // by formula
		Rate = CurrencyRateByFormula(DependentCurrency.Ref, DependentCurrency.RateCalculationFormula, BaseCurrencyRecord.Period, BaseCurrencyRecord.Company);
		If Rate <> Undefined Then
			WriteCurrencyRate.Rate = Rate;
			WriteCurrencyRate.Repetition = 1;
		EndIf;
	EndIf;
		
	RecordSet.AdditionalProperties.Insert("DisableDependentCurrenciesControl");
	RecordSet.AdditionalProperties.Insert("SkipPeriodClosingCheck");
	
	If WriteCurrencyRate.Rate > 0 Then
		RecordSet.Write();
	EndIf;
	
EndProcedure	

// Clears rates for dependent currencies.
//
Procedure DeleteDependentCurrencyRates()
	
	CurrencyOwner = Filter.Currency.Value;
	Period = Filter.Period;
	
	DependentCurrency = Undefined;
	If AdditionalProperties.Property("UpdateSubordinateCurrencyRate", DependentCurrency) Then
		DeleteCurrencyRates(DependentCurrency, Period);
	Else
		DependentCurrencies = CurrencyRateOperations.DependentCurrenciesList(CurrencyOwner, AdditionalProperties);
		For Each DependentCurrency In DependentCurrencies Do
			DeleteCurrencyRates(DependentCurrency.Ref, Period);
		EndDo;
	EndIf;
	
EndProcedure

Procedure DeleteCurrencyRates(CurrencyRef, Period)
	RecordSet = InformationRegisters.ExchangeRate.CreateRecordSet();
	RecordSet.Filter.Currency.Set(CurrencyRef);
	RecordSet.Filter.Period.Set(Period);
	If Filter.Company.Use Then
		RecordSet.Filter.Company.Set(Filter.Company.Value);
	EndIf;
	RecordSet.AdditionalProperties.Insert("DisableDependentCurrenciesControl");
	RecordSet.Write();
EndProcedure
	
Function CurrencyRateByFormula(Currency, Formula, Period, Company)
	QueryText =
	"SELECT
	|	Currencies.Description AS AlphabeticCode,
	|	CASE
	|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|			THEN ISNULL(CurrencyRatesSliceLast.Repetition, 1) / ISNULL(CurrencyRatesSliceLast.Rate, 1)
	|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|			THEN ISNULL(CurrencyRatesSliceLast.Rate, 1) / ISNULL(CurrencyRatesSliceLast.Repetition, 1)
	|	END AS Rate
	|FROM
	|	Catalog.Currencies AS Currencies
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Period, Company = &Company) AS CurrencyRatesSliceLast
	|		ON (CurrencyRatesSliceLast.Currency = Currencies.Ref)
	|WHERE
	|	Currencies.RateSource <> VALUE(Enum.RateSources.MarkupForOtherCurrencyRate)
	|	AND Currencies.RateSource <> VALUE(Enum.RateSources.CalculationByFormula)";
	
	Query = New Query(QueryText);
	Query.SetParameter("Period", 				Period);
	Query.SetParameter("Company", 				Company);
	Query.SetParameter("ExchangeRateMethod",	DriveServer.GetExchangeMethod(Company));
	Expression = StrReplace(Formula, ",", ".");
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		Expression = StrReplace(Expression, Selection.AlphabeticCode, Format(Selection.Rate, "NDS=.; NG=0"));
	EndDo;
	
	Try
		Result = Common.CalculateInSafeMode(Expression);
	Except
		If ErrorInRateCalculationByFormula = Undefined Then
			ErrorInRateCalculationByFormula = New Map;
		EndIf;
		If ErrorInRateCalculationByFormula[Currency] = Undefined Then
			ErrorInRateCalculationByFormula.Insert(Currency, True);
			ErrorInformation = ErrorInfo();
			
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = '???????????? ?????????? ???????????? ""%1"" ???? ?????????????? ""%2"" ???? ????????????????:'; en = 'Cannot calculate the exchange rate for currency %1 by formula ""%2"".'; pl = 'Obliczenie kursu wymiany ""%1"" przy u??yciu formu??y ""%2"" nie zosta??o wykonane:';es_ES = 'C??lculo del tipo de cambio ""%1"" utilizando la f??rmula ""%2"" no se ha ejecutado:';es_CO = 'C??lculo del tipo de cambio ""%1"" utilizando la f??rmula ""%2"" no se ha ejecutado:';tr = '%1 para birimi i??in ""%2"" form??l??yle d??viz kuru hesaplanamad??.';it = 'Impossibile calcolare il tasso di cambio per la valuta %1 in base alla formula ""%2"".';de = 'Berechnung des Wechselkurses ""%1"" mit Formel ""%2"" wird nicht ausgef??hrt.'",
				CommonClientServer.DefaultLanguageCode()), Currency, Formula);
				
			CommonClientServer.MessageToUser(ErrorText + Chars.LF + BriefErrorDescription(ErrorInformation), 
				Currency, "Object.RateCalculationFormula");
				
			If AdditionalProperties.Property("UpdateSubordinateCurrencyRate") Then
				Raise ErrorText + Chars.LF + BriefErrorDescription(ErrorInformation);
			Else
				WriteLogEvent(NStr("ru = '????????????.???????????????? ???????????? ??????????'; en = 'Currencies.Import currency exchange rates'; pl = 'Waluta.Import kurs??w wymiany walut';es_ES = 'Moneda.Importaci??n de los tipos de cambio';es_CO = 'Moneda.Importaci??n de los tipos de cambio';tr = 'Para birimi. D??viz kuru i??e aktar??m??';it = 'Valute. Importare tassi di cambio delle valute';de = 'W??hrung. Wechselkurse importieren'", CommonClientServer.DefaultLanguageCode()),
					EventLogLevel.Error, Currency.Metadata(), Currency, 
					ErrorText + Chars.LF + DetailErrorDescription(ErrorInformation));
			EndIf;
		EndIf;
		Result = Undefined;
	EndTry;
	
	Return Result;
EndFunction

#EndRegion

#EndIf