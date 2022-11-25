
#Region ServiceHandlers

&AtClient
// Fills the exchange rate and the exchange rate multiplier of the document currency.
//
Procedure FillExchangeRateMultiplicityCurrencies(IsDocumentCurrency)
	
	If IsDocumentCurrency Then
		
		If DocumentCurrency = SettlementsCurrency Then
			
			RateDocumentCurrency = ExchangeRate;
			RepetitionDocumentCurrency = Multiplicity;
		
		ElsIf ValueIsFilled(SettlementsCurrency) Then
			
			ArrayCourseRepetition = ExchangeRates.FindRows(New Structure("Currency", DocumentCurrency));
			
			If ArrayCourseRepetition.Count() > 0 Then
				
				RateDocumentCurrency = ArrayCourseRepetition[0].ExchangeRate;
				RepetitionDocumentCurrency = ArrayCourseRepetition[0].Multiplicity;
				
			Else
				
				RateDocumentCurrency = 0;
				RepetitionDocumentCurrency = 0;
				
			EndIf;
			
		EndIf;
		
	Else
		
		If ValueIsFilled(DocumentCurrency) Then
			
			ArrayCourseRepetition = ExchangeRates.FindRows(New Structure("Currency", SettlementsCurrency));
			
			If ArrayCourseRepetition.Count() > 0 Then
				
				ExchangeRate = ArrayCourseRepetition[0].ExchangeRate;
				Multiplicity = ArrayCourseRepetition[0].Multiplicity;
				
			Else
				
				ExchangeRate = 0;
				Multiplicity = 0;
				
			EndIf;
			
		EndIf;
		
		If DocumentCurrency = SettlementsCurrency Then
			
			RateDocumentCurrency = ExchangeRate;
			RepetitionDocumentCurrency = Multiplicity;
		
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
// Procedure checks the correctness of the form attributes filling.
//
Procedure CheckFillOfFormAttributes(Cancel)
	
	If Not ValueIsFilled(DocumentCurrency) Then
		Message = New UserMessage();
		Message.Text = NStr("en = 'Currency for population is not selected.'; ru = 'Не выбрана валюта для заполнения!';pl = 'Nie wybrano waluty dla wypełnienia.';es_ES = 'Moneda para poblar no se ha seleccionado.';es_CO = 'Moneda para poblar no se ha seleccionado.';tr = 'Doldurulacak para birimi seçilmedi.';it = 'Valuta per la popolazione non è selezionata.';de = 'Währung zum Ausfüllen ist nicht ausgewählt.'");
		Message.Field = "DocumentCurrency";
		Message.Message();
		Cancel = True;
	EndIf;
	
	If Not ValueIsFilled(ExchangeRate) Then
		Message = New UserMessage();
		Message.Text = NStr("en = 'Cannot save the currency because its exchange rate is zero. Please, specify a different multiplier.'; ru = 'Обнаружен нулевой курс валюты документа.';pl = 'Nie można zapisać waluty, ponieważ ponieważ jej kurs wymiany wynosi zero. Proszę podać inny mnożnik.';es_ES = 'No se puede guardar la moneda porque su tipo de cambio es cero. Por favor, especifique un multiplicador diferente.';es_CO = 'No se puede guardar la moneda porque su tipo de cambio es cero. Por favor, especifique un multiplicador diferente.';tr = 'Döviz kuru sıfır olduğu için para birimi kaydedilemiyor. Lütfen, farklı bir çarpan belirtin.';it = 'Non è possibile salvare la valuta, perché il suo tasso di cambio è pari a zero. Si prega di specificare un diverso moltiplicatore.';de = 'Die Währung kann nicht gespeichert werden, da ihr Wechselkurs Null ist. Bitte geben Sie einen anderen Multiplikator an.'");
		Message.Field = "ExchangeRate";
		Message.Message();
		Cancel = True;
	EndIf;
	
	If Not ValueIsFilled(Multiplicity) Then
		Message = New UserMessage();
		Message.Text = NStr("en = 'Cannot save the currency because its exchange rate multiplier is zero. Please, specify a different multiplier.'; ru = 'Обнаружена нулевая кратность курса валюты документа.';pl = 'Nie można zapisać waluty, ponieważ jej przelicznik walutowy wynosi zero. Proszę podać inny mnożnik.';es_ES = 'No se puede guardar la moneda porque su multiplicado del tipo de cambio es igual a cero. Por favor, especificar un multiplicador diferente.';es_CO = 'No se puede guardar la moneda porque su multiplicado del tipo de cambio es igual a cero. Por favor, especificar un multiplicador diferente.';tr = 'Döviz kuru çarpanı sıfır olduğu için para birimi kaydedilemiyor. Lütfen, farklı bir çarpan belirtin.';it = 'Non è possibile salvare la valuta, perché il suo moltiplicatore  del tasso di cambio è pari a zero. Si prega di specificare un diverso moltiplicatore.';de = 'Die Währung kann nicht gespeichert werden, da ihr Wechselkursmultiplikator Null ist. Bitte geben Sie einen anderen Multiplikator an.'");
		Message.Field = "SettlementsMultiplicity";
		Message.Message();
		Cancel = True;
	EndIf;
	
	If Not ValueIsFilled(SettlementsCurrency) Then
		Message = New UserMessage();
		Message.Text = NStr("en = 'Settlement currency for population is not selected.'; ru = 'Не выбрана валюта расчетов для заполнения!';pl = 'Nie wybrano waluty rozliczeń do wypełnienia.';es_ES = 'Moneda de liquidaciones para la población no está seleccionada.';es_CO = 'Moneda de liquidaciones para la población no está seleccionada.';tr = 'Hesaplaşma için doldurulacak para birimi seçilmedi.';it = 'La valuta di pagamento non è selezionata.';de = 'Abrechnungswährung für Ausfüllung ist nicht ausgewählt.'");
		Message.Field = "SettlementsCurrency";
		Message.Message();
		Cancel = True;
	EndIf;
	
EndProcedure

&AtClient
// Procedure checks if the form was modified.
//
Function CheckIfFormWasModified()
	
	WereMadeChanges = False;
	
	If RecalculatePricesByCurrency
		OR (ExchangeRateBeforeChange <> ExchangeRate)
		OR (MultiplicityBeforeChange <> Multiplicity)
		OR (ExchangeRateDocumentCurrencyBeforeChange <> RateDocumentCurrency)
		OR (MultiplicityDocumentCurrencyBeforeChange <> RepetitionDocumentCurrency)
		OR (SettlementsCurrencyBeforeChange <> SettlementsCurrency)
		OR (DocumentCurrencyBeforeChange <> DocumentCurrency) Then
		
		WereMadeChanges = True;
		
	EndIf; 
	
	Return WereMadeChanges;

EndFunction

&AtClient
// The RecalculatePricesByCurrency flag control
Procedure SetAmountsConvertingFlag()
	
	If ValueIsFilled(SettlementsCurrency) AND SettlementsCurrencyBeforeChange <> SettlementsCurrency Then
		
		RecalculatePricesByCurrency = True;
		
	ElsIf ExchangeRate <> ExchangeRateBeforeChange Then
		
		RecalculatePricesByCurrency = True;
		
	ElsIf Multiplicity <> MultiplicityBeforeChange Then
		
		RecalculatePricesByCurrency = True;
		
	ElsIf ValueIsFilled(DocumentCurrency) AND DocumentCurrencyBeforeChange <> DocumentCurrency Then
		
		RecalculatePricesByCurrency = True;
		
	ElsIf RateDocumentCurrency <> ExchangeRateDocumentCurrencyBeforeChange Then
		
		RecalculatePricesByCurrency = True;
		
	ElsIf RepetitionDocumentCurrency <> MultiplicityDocumentCurrencyBeforeChange Then
		
		RecalculatePricesByCurrency = True;
		
	Else
		
		RecalculatePricesByCurrency = False;
		
	EndIf;
	
EndProcedure

&AtServer
// Procedure fills the form parameters.
//
Procedure GetFormValuesOfParameters()
	
	Company										= Parameters.Company;
	DocumentCurrency							= Parameters.DocumentCurrency;
	DocumentCurrencyBeforeChange				= Parameters.DocumentCurrency;
	RateDocumentCurrency						= Parameters.RateDocumentCurrency;
	ExchangeRateDocumentCurrencyBeforeChange	= Parameters.RateDocumentCurrency;
	RepetitionDocumentCurrency					= Parameters.RepetitionDocumentCurrency;
	MultiplicityDocumentCurrencyBeforeChange	= Parameters.RepetitionDocumentCurrency;
	
	SettlementsCurrency							= Parameters.SettlementsCurrency;
	SettlementsCurrencyBeforeChange				= Parameters.SettlementsCurrency;
	ExchangeRate 								= Parameters.ExchangeRate;
	ExchangeRateBeforeChange					= Parameters.ExchangeRate;
	Multiplicity 								= Parameters.Multiplicity;
	MultiplicityBeforeChange 					= Parameters.Multiplicity;
	
	DocumentDate 								= Parameters.DocumentDate;
	
EndProcedure

&AtServer
// Procedure fills the exchange rates table
//
Procedure FillExchangeRateTable()
	
	Query = New Query;
	Query.SetParameter("DocumentDate", DocumentDate);
	Query.SetParameter("Company", Company);
	
	Query.Text = 
	"SELECT ALLOWED
	|	ExchangeRateSliceLast.Currency,
	|	ExchangeRateSliceLast.Rate AS ExchangeRate,
	|	ExchangeRateSliceLast.Repetition AS Multiplicity
	|FROM
	|	InformationRegister.ExchangeRate.SliceLast(&DocumentDate, Company = &Company) AS ExchangeRateSliceLast";
	
	QueryResultTable = Query.Execute().Unload();
	ExchangeRates.Load(QueryResultTable);
	
EndProcedure

#EndRegion

#Region CommandHandlers

&AtServer
// Procedure - event handler OnCreateAtServer of the form.
// The procedure implements
// - initializing the form parameters.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	GetFormValuesOfParameters();
	
	FillExchangeRateTable();
	
EndProcedure

#EndRegion

#Region CommandHandlers

&AtClient
// Procedure - event handler of clicking the Cancel button.
//
Procedure CancelExecute()
	
	ReturnStructure = New Structure();
	ReturnStructure.Insert("DialogReturnCode", DialogReturnCode.Cancel);
	ReturnStructure.Insert("WereMadeChanges", False);
	Close(ReturnStructure);

EndProcedure

&AtClient
// Procedure - event handler of clicking the OK button.
//
Procedure ButtOKExecute()
	
	Cancel = False;
	
	CheckFillOfFormAttributes(Cancel);
	If Not Cancel Then
		
		WereMadeChanges = CheckIfFormWasModified();
		
		ReturnStructure = New Structure();
		ReturnStructure.Insert("ChangedDocumentCurrency", 	DocumentCurrency <> DocumentCurrencyBeforeChange OR RateDocumentCurrency <> ExchangeRateDocumentCurrencyBeforeChange OR RepetitionDocumentCurrency <> MultiplicityDocumentCurrencyBeforeChange);
		ReturnStructure.Insert("DocumentCurrency", 			DocumentCurrency);
		ReturnStructure.Insert("RateDocumentCurrency", 		RateDocumentCurrency);
		ReturnStructure.Insert("RepetitionDocumentCurrency",	RepetitionDocumentCurrency);
		
		ReturnStructure.Insert("ChangedCurrencySettlements", 	SettlementsCurrency <> SettlementsCurrencyBeforeChange OR ExchangeRate <> ExchangeRateBeforeChange OR Multiplicity <> MultiplicityBeforeChange);
		ReturnStructure.Insert("SettlementsCurrency", 			SettlementsCurrency);
		ReturnStructure.Insert("ExchangeRate", 						ExchangeRate);
		ReturnStructure.Insert("Multiplicity", 				Multiplicity);
		
		ReturnStructure.Insert("RecalculatePricesByCurrency", 	RecalculatePricesByCurrency);
		
		ReturnStructure.Insert("WereMadeChanges", 		WereMadeChanges);
		ReturnStructure.Insert("DialogReturnCode", 		DialogReturnCode.OK);
		
		Close(ReturnStructure);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region HeaderAttributesHandlers

&AtClient
// Procedure - event handler OnChange of the Currency input field.
//
Procedure CurrencyOnChange(Item)
	
	FillExchangeRateMultiplicityCurrencies(False);
	SetAmountsConvertingFlag();
	
EndProcedure

&AtClient
Procedure DocumentCurrencyOnChange(Item)
	
	FillExchangeRateMultiplicityCurrencies(True);
	SetAmountsConvertingFlag();
	
EndProcedure

&AtClient
Procedure SettlementsCurrencyRateOnChange(Item)
	
	SetAmountsConvertingFlag();
	
	If DocumentCurrency = SettlementsCurrency Then
		
		RateDocumentCurrency = ExchangeRate;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SettlementsCurrenciesRatioOnChange(Item)
	
	SetAmountsConvertingFlag();
	
	If DocumentCurrency = SettlementsCurrency Then
		
		RepetitionDocumentCurrency = Multiplicity;
		
	EndIf;
	
EndProcedure

#EndRegion