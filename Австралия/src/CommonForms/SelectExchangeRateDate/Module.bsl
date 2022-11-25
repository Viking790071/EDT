#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Parameters.Property("Company", Company);
	Parameters.Property("Currency", Currency);
	Parameters.Property("ExchangeRateMethod", ExchangeRateMethod);
	Parameters.Property("PresentationCurrency", PresentationCurrency);
	Parameters.Property("RateDate", RateDate);
	
	SetCurrencyRatePresentation();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure RateDateOnChange(Item)
	
	SetCurrencyRatePresentation();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure OK(Command)
	
	If Not CheckFilling() Then
		Return;
	EndIf;
	
	Close(Rate);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetCurrencyRatePresentation()
	
	CurrencyRate = CurrencyRateOperations.GetCurrencyRate(RateDate, Currency, Company);
	Rate = CurrencyRate.Rate;
	Multiplier = CurrencyRate.Repetition;
	
	If ExchangeRateMethod = Enums.ExchangeRateMethods.Divisor Then
		CurRateText = StrTemplate("%1 %2/%3 %4", Multiplier, PresentationCurrency, Currency, Format(Rate, "NFD=4"));
	Else
		CurRateText = StrTemplate("%1 %2/%3 %4", Multiplier, Currency, PresentationCurrency, Format(Rate, "NFD=4"));
	EndIf;
	
EndProcedure

#EndRegion