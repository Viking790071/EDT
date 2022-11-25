#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If RateSource = Enums.RateSources.CalculationByFormula Then
		QueryText =
		"SELECT
		|	Currencies.Description AS AlphabeticCode
		|FROM
		|	Catalog.Currencies AS Currencies
		|WHERE
		|	Currencies.RateSource = VALUE(Enum.RateSources.MarkupForOtherCurrencyRate)
		|
		|UNION ALL
		|
		|SELECT
		|	Currencies.Description
		|FROM
		|	Catalog.Currencies AS Currencies
		|WHERE
		|	Currencies.RateSource = VALUE(Enum.RateSources.CalculationByFormula)";
		
		Query = New Query(QueryText);
		DependentCurrencies = Query.Execute().Unload().UnloadColumn("AlphabeticCode");
		
		For Each Currency In DependentCurrencies Do
			If StrFind(RateCalculationFormula, Currency) > 0 Then
				Cancel = True;
			EndIf;
		EndDo;
	EndIf;
	
	If ValueIsFilled(MainCurrency.MainCurrency) Then
		Cancel = True;
	EndIf;
	
	If Cancel Then
		CommonClientServer.MessageToUser(
			NStr("ru = 'Курс валюты можно связать только с курсом независимой валюты.'; en = 'An exchange rate can only be linked to the rate of an independent currency.'; pl = 'Kursy wymiany mogą być powiązane wyłącznie z kursem niezależnej waluty.';es_ES = 'Tipos de cambio pueden estar vinculados solo al tipo de la moneda independiente.';es_CO = 'Tipos de cambio pueden estar vinculados solo al tipo de la moneda independiente.';tr = 'Döviz kurları sadece bağımsız para birimine bağlanabilir.';it = 'Un tasso di cambio può essere collegato solo al tasso di una valuta indipendente.';de = 'Wechselkurse können nur mit der Rate der unabhängigen Währung verknüpft werden.'"));
	EndIf;
	
	If RateSource <> Enums.RateSources.MarkupForOtherCurrencyRate Then
		AttributesToExclude = New Array;
		AttributesToExclude.Add("MainCurrency");
		AttributesToExclude.Add("Markup");
		Common.DeleteNotCheckedAttributesFromArray(CheckedAttributes, AttributesToExclude);
	EndIf;
	
	If RateSource <> Enums.RateSources.CalculationByFormula Then
		AttributesToExclude = New Array;
		AttributesToExclude.Add("RateCalculationFormula");
		Common.DeleteNotCheckedAttributesFromArray(CheckedAttributes, AttributesToExclude);
	EndIf;
	
	If Not IsNew()
		AND RateSource = Enums.RateSources.MarkupForOtherCurrencyRate
		AND CurrencyRateOperations.DependentCurrenciesList(Ref).Count() > 0 Then
		CommonClientServer.MessageToUser(
			NStr("ru = 'Валюта не может быть подчиненной, так как она является основной для других валют.'; en = 'The currency cannot be subordinate because it is used as the base currency for other currencies.'; pl = 'Waluta nie może być podrzędna, ponieważ jest walutą główną dla innych walut.';es_ES = 'La moneda no puede ser subordinada, porque es la principal para otras monedas.';es_CO = 'La moneda no puede ser subordinada, porque es la principal para otras monedas.';tr = 'Para birimi, diğer para birimleri için ana birim olduğundan dolayı ikincil olamaz.';it = 'La valuta non può essere subordinata essendo utilizzata come valuta di base per altre valute.';de = 'Die Währung kann nicht untergeordnet sein, da sie die Hauptwährung für andere Währungen ist.'"));
		Cancel = True;
	EndIf;
	
	If ValueIsFilled(Code) And Not IsOnlyNumbersInNumericCode() Then
		CommonClientServer.MessageToUser(
			NStr("en = 'The Numeric code cannot contain characters other than numbers.'; ru = 'Цифровой код может содержать только цифры.';pl = 'Kod numeryczny może zawierać tylko cyfry.';es_ES = 'El código numérico no puede contener caracteres que no sean números.';es_CO = 'El código numérico no puede contener caracteres que no sean números.';tr = 'Sayısal kod, rakamlardan başka karakter içeremez.';it = 'Il codice numero non può contenere caratteri che non siano numeri.';de = 'Der numerische Code darf nur Nummer und keine anderen Zeichen enthalten.'"));
		Cancel = True;
	EndIf;
	
	If ValueIsFilled(Description) And IsNumbersInAlphabeticCode() Then
		CommonClientServer.MessageToUser(
			NStr("en = 'The Alphabetic code cannot contain numbers.'; ru = 'Буквенный код не может содержать цифры.';pl = 'Kod alfabetyczny nie może zawierać cyfr.';es_ES = 'El código alfabético no puede contener números.';es_CO = 'El código alfabético no puede contener números.';tr = 'Alfabetik kod, rakam içeremez.';it = 'Il codice Alfabetico non può contenere numeri.';de = 'Der alphabetische Code darf keine Nummer enthalten.'"));
		Cancel = True;
	EndIf;
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If AdditionalProperties.Property("UpdateRates") Then
		CurrencyParameters = New Structure;
		CurrencyParameters.Insert("MainCurrency");
		CurrencyParameters.Insert("Ref");
		CurrencyParameters.Insert("Markup");
		CurrencyParameters.Insert("AdditionalProperties");
		CurrencyParameters.Insert("RateCalculationFormula");
		FillPropertyValues(CurrencyParameters, ThisObject);
		
		JobParameters = New Structure;
		JobParameters.Insert("SubordinateCurrency", CurrencyParameters);
		JobParameters.Insert("RateSource", RateSource);
		
		ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(New UUID());
		ExecutionParameters.WaitForCompletion = 0;
		ExecutionParameters.RunNotInBackground = InfobaseUpdate.InfobaseUpdateRequired();
		
		Result = TimeConsumingOperations.ExecuteInBackground("CurrencyRateOperations.UpdateCurrencyRate", JobParameters, ExecutionParameters);
		If Result.Status = "Error" Then
			Raise Result.BriefErrorPresentation;
		EndIf;
	EndIf;
	
	If AdditionalProperties.Property("ScheduleCopyCurrencyRates") Then
		If Common.DataSeparationEnabled()
			AND Common.SubsystemExists("StandardSubsystems.SaaS.CurrenciesSaaS") Then
			ModuleCurrencyExchangeRatesInternalSaaS = Common.CommonModule("CurrencyRatesInternalSaaS");
			ModuleCurrencyExchangeRatesInternalSaaS.ScheduleCopyCurrencyRates(ThisObject);
		EndIf;
	EndIf;
	
	CurrencyRateOperations.CheckCurrencyRateAvailabilityFor01_01_1980(Ref);
	
EndProcedure

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	RateImportedFromInternet = RateSource = Enums.RateSources.DownloadFromInternet;
	RateDependsOnOtherCurrency = RateSource = Enums.RateSources.MarkupForOtherCurrencyRate;
	RateCalculatedByFormula = RateSource = Enums.RateSources.CalculationByFormula;
	
	If IsNew() Then
		If RateDependsOnOtherCurrency Or RateCalculatedByFormula Then
			AdditionalProperties.Insert("UpdateRates");
		EndIf;
		AdditionalProperties.Insert("IsNew");
		AdditionalProperties.Insert("ScheduleCopyCurrencyRates");
	Else
		PreviousValues = Common.ObjectAttributesValues(Ref, "Code,RateSource,MainCurrency,Markup,RateCalculationFormula");
		
		RateSourceChanged = PreviousValues.RateSource <> RateSource;
		CurrencyCodeChanged = PreviousValues.Code <> Code;
		BaseCurrencyChanged = PreviousValues.MainCurrency <> MainCurrency;
		IncreaseByValueChanged = PreviousValues.Markup <> Markup;
		FormulaChanged = PreviousValues.RateCalculationFormula <> RateCalculationFormula;
		
		If (RateDependsOnOtherCurrency AND (BaseCurrencyChanged Or IncreaseByValueChanged Or RateSourceChanged))
			Or (RateCalculatedByFormula AND (FormulaChanged Or RateSourceChanged)) Then
			AdditionalProperties.Insert("UpdateRates");
		EndIf;
		
		If RateImportedFromInternet AND (RateSourceChanged Or CurrencyCodeChanged) Then
			AdditionalProperties.Insert("ScheduleCopyCurrencyRates");
		EndIf;
	EndIf;
	
	If RateSource <> Enums.RateSources.MarkupForOtherCurrencyRate Then
		MainCurrency = Catalogs.Currencies.EmptyRef();
		Markup = 0;
	EndIf;
	
	If RateSource <> Enums.RateSources.CalculationByFormula Then
		RateCalculationFormula = "";
	EndIf;
	
	InWordParametersInEnglish = InWordParametersInEnglish(InWordsParameters);
	
EndProcedure

#EndRegion

#Region Private

Function InWordParametersInEnglish(InWordsParameters)
	
	If Not ValueIsFilled(InWordsParameters) Then
		Return "";
	EndIf;
	
	ParameterString = StrReplace(InWordsParameters, ",", Chars.LF);
	
	AmountInWordsField1Russian	= TrimAll(StrGetLine(ParameterString, 1));
	AmountInWordsField2Russian	= TrimAll(StrGetLine(ParameterString, 2));
	AmountInWordsField5Russian	= TrimAll(StrGetLine(ParameterString, 5));
	AmountInWordsField6Russian	= TrimAll(StrGetLine(ParameterString, 6));
	FractionalPartLength		= TrimAll(StrGetLine(ParameterString, 9));
	
	Return AmountInWordsField1Russian + ", "
			+ AmountInWordsField2Russian + ", "
			+ AmountInWordsField5Russian + ", "
			+ AmountInWordsField6Russian + ", "
			+ FractionalPartLength;
	
EndFunction

Function IsOnlyNumbersInNumericCode()
	
	Result = True;
	StringLength = StrLen(Code);
	
	For CharNumber = 1 To StringLength Do
		CharCode = CharCode(Code, CharNumber);
		If Not (CharCode >= 48 And CharCode <= 57) Then
			Result = False;
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

Function IsNumbersInAlphabeticCode()
	
	Result = False;
	StringLength = StrLen(Description);
	
	For CharNumber = 1 To StringLength Do
		CharCode = CharCode(Description, CharNumber);
		If CharCode >= 48 And CharCode <= 57 Then
			Result = True;
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

#EndRegion

#EndIf
