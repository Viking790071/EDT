#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	NativeLanguagesSupportServer.ChoiceDataGetProcessing(
		ChoiceData,
		Parameters,
		StandardProcessing,
		Metadata.Catalogs.EarningsCalculationParameters);
	
EndProcedure

Procedure PresentationGetProcessing(Data, Presentation, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationGetProcessing(Data, Presentation, StandardProcessing);
	
EndProcedure

Procedure PresentationFieldsGetProcessing(Fields, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationFieldsGetProcessing(Fields, StandardProcessing);
	
EndProcedure

#EndRegion

#Region InfobaseUpdate

Procedure ChangeSalesAmountForResponsibleParameter() Export
	
	OldQueryText =
	"SELECT
	|	SUM(ISNULL(Sales.Amount * &AccountingCurrencyExchangeRate * &DocumentCurrencyMultiplicity / (&DocumentCurrencyRate * &AccountingCurrecyFrequency), 0)) AS SalesAmount
	|FROM
	|	AccumulationRegister.Sales AS Sales
	|WHERE
	|	Sales.Amount >= 0
	|	AND Sales.Period BETWEEN BEGINOFPERIOD(&RegistrationPeriod, MONTH) AND ENDOFPERIOD(&RegistrationPeriod, MONTH)
	|	AND Sales.Company = &Company
	|	AND Sales.Department = &Department
	|	AND Sales.Document.Responsible = &Employee
	|	AND (CAST(Sales.Recorder AS Document.SalesOrder) REFS Document.SalesOrder
	|			OR CAST(Sales.Recorder AS Document.ShiftClosure) REFS Document.ShiftClosure
	|			OR CAST(Sales.Recorder AS Document.SalesInvoice) REFS Document.SalesInvoice
	|			OR CAST(Sales.Recorder AS Document.SalesSlip) REFS Document.SalesSlip)
	|
	|GROUP BY
	|	Sales.Document.Responsible";
	
	Parameter = Catalogs.EarningsCalculationParameters.FindByAttribute("ID", "SalesAmountForResponsible");
	If ValueIsFilled(Parameter)
		And StrCompare(StrReplace(Parameter.Query, Chars.CR, ""), OldQueryText) = 0 Then
		
		ParameterObject = Parameter.GetObject();
		ParameterObject.ID = "SalesAmountByResponsible";
		ParameterObject.Query =
		"SELECT
		|	SUM(CASE
		|			WHEN Companies.ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
		|				THEN ISNULL(Sales.Amount * &DocumentCurrencyMultiplicity / &DocumentCurrencyRate, 0)
		|			ELSE ISNULL(Sales.Amount * &DocumentCurrencyRate / &DocumentCurrencyMultiplicity, 0)
		|		END) AS SalesAmount
		|FROM
		|	AccumulationRegister.Sales AS Sales
		|		INNER JOIN Catalog.Companies AS Companies
		|		ON Sales.Company = Companies.Ref
		|WHERE
		|	Sales.Amount >= 0
		|	AND Sales.Period BETWEEN BEGINOFPERIOD(&RegistrationPeriod, MONTH) AND ENDOFPERIOD(&RegistrationPeriod, MONTH)
		|	AND Sales.Company = &Company
		|	AND Sales.Department = &Department
		|	AND Sales.Document.Responsible = &Employee
		|	AND (Sales.Recorder REFS Document.ShiftClosure
		|			OR Sales.Recorder REFS Document.SalesInvoice
		|			OR Sales.Recorder REFS Document.SalesSlip)
		|
		|GROUP BY
		|	Sales.Document.Responsible";
		
		TabRow = ParameterObject.QueryParameters.Find("AccountingCurrencyExchangeRate", "Name");
		If TabRow <> Undefined Then
			ParameterObject.QueryParameters.Delete(TabRow);
		EndIf;
		
		TabRow = ParameterObject.QueryParameters.Find("AccountingCurrecyFrequency", "Name");
		If TabRow <> Undefined Then
			ParameterObject.QueryParameters.Delete(TabRow);
		EndIf;
		
		BeginTransaction();
		
		Try
			
			InfobaseUpdate.WriteObject(ParameterObject);
			
			CommitTransaction();
			
		Except
			
			RollbackTransaction();
			
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot write catalog ""%1"". Details: %2'; ru = 'Не удалось записать справочник ""%1"". Подробнее: %2';pl = 'Nie można zapisać katalogu ""%1"". Szczegóły: %2';es_ES = 'No se ha podido guardar el catálogo ""%1"". Detalles: %2';es_CO = 'No se ha podido guardar el catálogo ""%1"". Detalles: %2';tr = '""%1"" kataloğu kaydedilemiyor. Ayrıntılar: %2';it = 'Impossibile scrivere l''anagrafica ""%1"". Dettagli: %2';de = 'Fehler beim Speichern des Katalogs ""%1"". Details: %2'", CommonClientServer.DefaultLanguageCode),
				Parameter,
				BriefErrorDescription(ErrorInfo()));
			
			WriteLogEvent(
				InfobaseUpdate.EventLogEvent(),
				EventLogLevel.Error,
				Metadata.Catalogs.EarningsCalculationParameters,
				,
				ErrorDescription);
			
		EndTry;
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf