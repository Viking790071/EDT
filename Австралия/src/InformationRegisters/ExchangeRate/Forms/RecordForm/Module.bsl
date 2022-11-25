
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	If Not ValueIsFilled(Record.SourceRecordKey) Then
		Record.Period = CurrentSessionDate();
	EndIf;
	
	CompleteCurrency();

	CurrencySelectionAvailable = Not Parameters.FillingValues.Property("Currency") AND Not ValueIsFilled(Parameters.Key);
	Items.CurrencyLabel.Visible = Not CurrencySelectionAvailable;
	Items.CurrencyList.Visible = CurrencySelectionAvailable;
	
	CompanySelectionAvailable = Not Parameters.FillingValues.Property("Company") AND Not ValueIsFilled(Parameters.Key);
	Items.Company.Type = ?(CompanySelectionAvailable, FormFieldType.InputField, FormFieldType.LabelField);
	
	WindowOptionsKey = ?(CurrencySelectionAvailable, "WithCurrencyChoice", "NoCurrencyChoice");
	
	PresentationCurrency = GetPresentationCurrency(Record.Company);
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	// StandardSubsystems.PeriodClosingDates
	If Common.SubsystemExists("StandardSubsystems.PeriodClosingDates") Then
		ModulePeriodClosingDates = Common.CommonModule("PeriodClosingDates");
		ModulePeriodClosingDates.ObjectOnReadAtServer(ThisObject, CurrentObject);
	EndIf;
	// End StandardSubsystems.PeriodClosingDates
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	Notify("Write_CurrencyRates", WriteParameters, Record);
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	If Not CurrencySelectionAvailable Then
		AttributesToExclude = New Array;
		AttributesToExclude.Add("CurrencyList");
		Common.DeleteNotCheckedAttributesFromArray(CheckedAttributes, AttributesToExclude);
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	If Record.Currency = PresentationCurrency Then
		If Record.Rate <> 1 Or Record.Repetition <> 1 Then
			CommonClientServer.MessageToUser(NStr("en = 'The presentation currency rate and multiplier must always be equal to 1.'; ru = 'Курс валюты представления отчетности и кратность всегда должны быть равны 1.';pl = 'Kurs i mnożnik waluty prezentacji i mnożnik muszą zawsze być równe 1.';es_ES = 'El tipo de moneda de presentación y el multiplicador deben ser siempre iguales a 1.';es_CO = 'El tipo de moneda de presentación y el multiplicador deben ser siempre iguales a 1.';tr = 'Finansal tablo döviz kuru ve çarpanı daima 1''e eşit olmalıdır.';it = 'Il tasso di valuta di presentazione e il moltiplicatore devono sempre essere uguali a 1.';de = 'Die Ratio der Währung für die Berichtserstattung und der Multiplikator müssen immer 1 gleich sein.'"),
				,
				?(Record.Rate <> 1, "Record.Rate", "Record.Repetition"),
				,
				Cancel);
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure CurrencyOnChange(Item)
	Record.Currency = CurrencyList;
EndProcedure

&AtClient
Procedure CompanyOnChange(Item)
	PresentationCurrency = GetPresentationCurrency(Record.Company);
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure CompleteCurrency()
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	Currencies.Ref AS Ref,
	|	Currencies.Description AS AlphabeticCode,
	|	Currencies.DescriptionFull AS Description
	|FROM
	|	Catalog.Currencies AS Currencies
	|WHERE
	|	Currencies.DeletionMark = FALSE
	|
	|ORDER BY
	|	Description";
	
	CurrencySelection = Query.Execute().Select();
	
	While CurrencySelection.Next() Do
		CurrencyPresentation = StringFunctionsClientServer.SubstituteParametersToString("%1 (%2)", CurrencySelection.Description, CurrencySelection.AlphabeticCode);
		Items.CurrencyList.ChoiceList.Add(CurrencySelection.Ref, CurrencyPresentation);
		If CurrencySelection.Ref = Record.Currency Then
			CurrencyLabel = CurrencyPresentation;
			CurrencyList = Record.Currency;
		EndIf;
	EndDo;
	
EndProcedure

&AtServerNoContext
Function GetPresentationCurrency(Company)
	Return DriveServer.GetPresentationCurrency(Company);
EndFunction

#EndRegion