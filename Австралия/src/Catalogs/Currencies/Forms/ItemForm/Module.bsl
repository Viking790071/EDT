
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	If UsersClientServer.IsExternalUserSession() Then
		
		Cancel = True;
		Return;
		
	EndIf;
	
	If Object.Ref.IsEmpty() Then
		
		If Parameters.Property("CurrencyCode") Then
			Object.Code = Parameters.CurrencyCode;
		EndIf;
		
		If Parameters.Property("ShortDescription") Then
			Object.Description = Parameters.ShortDescription;
		EndIf;
		
		If Parameters.Property("DescriptionFull") Then
			Object.DescriptionFull = Parameters.DescriptionFull;
		EndIf;
		
		If Parameters.Property("Importing") AND Parameters.Importing Then
			Object.RateSource = Enums.RateSources.DownloadFromInternet;
		Else 
			Object.RateSource = Enums.RateSources.ManualInput;
		EndIf;
		
		If Parameters.Property("InWordsParameters") Then
			Object.InWordsParameters = Parameters.InWordsParameters;
		EndIf;
		
	EndIf;
	
	AmountInWordsParametersFormExists = Metadata.DataProcessors.Find("ImportCurrenciesRates") <> Undefined;
	
	SetItemsAvailability(ThisObject);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

////////////////////////////////////////////////////////////////////////////////
// Basic Additional Data page.

&AtClient
Procedure BaseCurrencyStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	PrepareSubordinateCurrencyChoiceData(ChoiceData, Object.Ref);
	
EndProcedure

&AtClient
Procedure CurrencyRateOnChange(Item)
	SetItemsAvailability(ThisObject);
EndProcedure

&AtClient
Procedure AmountInWordsParametersClick(Item)
	
	NotifyDescription = New NotifyDescription("OnChangeCurrencyParametersInWords", ThisObject);
	If AmountInWordsParametersFormExists Then
		OpeningParameters = New Structure;
		OpeningParameters.Insert("ReadOnly", ReadOnly);
		OpeningParameters.Insert("InWordsParameters", Object.InWordsParameters);
		AmountInWordsParametersFormName = "DataProcessor.ImportCurrenciesRates.Form.CurrencyInWordsParameters";
		OpenForm(AmountInWordsParametersFormName, OpeningParameters, ThisObject, , , , NotifyDescription);
	Else
		ShowInputString(NotifyDescription, Object.InWordsParameters, NStr("ru = 'Параметры прописи валюты'; en = 'Parameters for writing amounts in words'; pl = 'Parametry do zapisywania kwot słownie';es_ES = 'Parámetros de escribir las cantidades en palabras';es_CO = 'Parámetros de escribir las cantidades en palabras';tr = 'Miktarları kelime olarak yazmak için parametreler';it = 'Parametri per la scrittura degli importi in lettere';de = 'Aufzeichnungsparameter'"));
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServerNoContext
Procedure PrepareSubordinateCurrencyChoiceData(ChoiceData, Ref)
	
	// Prepares a selection list for a subordinate currency excluding the subordinate currency itself.
	// 
	
	ChoiceData = New ValueList;
	
	Query = New Query;
	
	Query.Text = 
	"SELECT
	|	Currencies.Ref AS Ref,
	|	Currencies.DescriptionFull AS DescriptionFull,
	|	Currencies.Description AS Description
	|FROM
	|	Catalog.Currencies AS Currencies
	|WHERE
	|	Currencies.Ref <> &Ref
	|	AND Currencies.MainCurrency = VALUE(Catalog.Currencies.EmptyRef)
	|
	|ORDER BY
	|	Currencies.DescriptionFull";
	
	Query.Parameters.Insert("Ref", Ref);
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		ChoiceData.Add(Selection.Ref, Selection.DescriptionFull + " (" + Selection.Description + ")");
	EndDo;
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetItemsAvailability(Form)
	Items = Form.Items;
	Object = Form.Object;
	Items.IncreaseByGroup.Enabled = Object.RateSource = PredefinedValue("Enum.RateSources.MarkupForOtherCurrencyRate");
	Items.RateCalculationFormula.Enabled = Object.RateSource = PredefinedValue("Enum.RateSources.CalculationByFormula");
EndProcedure

&AtClient
Procedure OnChangeCurrencyParametersInWords(Result, AdditionalParameters) Export
	If Result = Undefined Then
		Return;
	EndIf;
	
	Object.InWordsParameters = Result;
	Modified = True;
EndProcedure

#EndRegion
