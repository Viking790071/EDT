
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	// Filling in the currency list from the currency classifier.
	CloseOnChoice = False;
	FillCurrencyTable();
	
EndProcedure

#EndRegion

#Region CurrenciesListFormTableItemsEventHandlers

&AtClient
Procedure CurrencyListChoice(Item, RowSelected, Field, StandardProcessing)
	
	ProcessChoiceInCurrencyList(StandardProcessing);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure SelectExecute()
	
	ProcessChoiceInCurrencyList();
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure FillCurrencyTable()
	
	// Fills in the currency list from the currency classifier template.
	
	XMLClassifier = DataProcessors.ImportCurrenciesRates.GetTemplate("NationalCurrencyClassifier").GetText();
	
	ClassifierTable = Common.ReadXMLToTable(XMLClassifier).Data;
	
	For Each CCRecord In ClassifierTable Do
		NewRow = Currencies.Add();
		NewRow.NumericCurrencyCode         = CCRecord.Code;
		NewRow.AlphabeticCurrencyCode        = CCRecord.CodeSymbol;
		NewRow.Description              = CCRecord.Name;
		NewRow.CountriesAndTerritories         = CCRecord.Description;
		NewRow.Importing               = CCRecord.RBCLoading;
		NewRow.InWordsParameters = CCRecord.NumerationItemOptions;
	EndDo;
	
EndProcedure

&AtServer
Function SaveSelectedRows(Val SelectedRows, ThereAreRates, MessageTextArray)
	
	ThereAreRates = False;
	CurrentRef = Undefined;
	
	For each RowNumber In SelectedRows Do
		CurrentData = Currencies[RowNumber];
		
		RowInDatabase = Catalogs.Currencies.FindByCode(CurrentData.NumericCurrencyCode);
		If ValueIsFilled(RowInDatabase) Then
			MessageText = StrTemplate(NStr("en = 'The value ""%1"" of the numeric code is not unique.'; ru = 'Значение ""%1"" числового кода уже существует.';pl = 'Wartość ""%1"" kodu numerycznego nie jest unikalna.';es_ES = 'El valor ""%1"" del código numérico no es único.';es_CO = 'El valor ""%1"" del código numérico no es único.';tr = 'Sayısal kodun ""%1"" değeri benzersiz değil.';it = 'Il valore ""%1"" del codice numerico non è univoco.';de = 'Der Wert ""%1"" des numerischen ""Code"" ist nicht einzigartig.'"),
				CurrentData.NumericCurrencyCode);
			MessageTextArray.Add(MessageText);
			Continue;
		EndIf;
		
		NewRow = Catalogs.Currencies.CreateItem();
		NewRow.Code                       = CurrentData.NumericCurrencyCode;
		NewRow.Description              = CurrentData.AlphabeticCurrencyCode;
		NewRow.DescriptionFull        = CurrentData.Description;
		If CurrentData.Importing Then
			NewRow.RateSource = Enums.RateSources.DownloadFromInternet;
		Else
			NewRow.RateSource = Enums.RateSources.ManualInput;
		EndIf;
		NewRow.InWordsParameters = CurrentData.InWordsParameters;
		NewRow.Write();
		
		If RowNumber = Items.CurrenciesList.CurrentRow Or CurrentRef = Undefined Then
			CurrentRef = NewRow.Ref;
		EndIf;
		
		If CurrentData.Importing Then 
			ThereAreRates = True;
		EndIf;
		
	EndDo;
	
	Return CurrentRef;

EndFunction

&AtClient
Procedure ProcessChoiceInCurrencyList(StandardProcessing = Undefined)
	Var ThereAreRates;
	
	// Add a catalog item and display the result to the user.
	StandardProcessing = False;
	
	MessageTextArray = New Array;
	
	CurrentRef = SaveSelectedRows(Items.CurrenciesList.SelectedRows, ThereAreRates, MessageTextArray);
	
	If ValueIsFilled(CurrentRef) Then
		NotifyChoice(CurrentRef);
		
		ShowUserNotification(
			NStr("ru = 'Валюты добавлены.'; en = 'Currencies are added.'; pl = 'Waluty zostały dodane';es_ES = 'Monedas se han añadido.';es_CO = 'Monedas se han añadido.';tr = 'Para birimleri eklendi.';it = 'Sono state aggiunte valute.';de = 'Währungen werden hinzugefügt.'"), ,
			?(StandardSubsystemsClient.ClientRunParameters().DataSeparationEnabled AND ThereAreRates, 
				NStr("ru = 'Курсы будут загружены автоматически через непродолжительное время.'; en = 'The exchange rates will soon be imported automatically.'; pl = 'Kursy wymiany walut zostaną wkrótce zaimportowane automatycznie.';es_ES = 'Los tipos de cambio pronto serán importados automáticamente.';es_CO = 'Los tipos de cambio pronto serán importados automáticamente.';tr = 'Döviz kurları yakında otomatik olarak içe aktarılacak.';it = 'I tassi di cambio saranno importati automaticamente a breve.';de = 'Die Wechselkurse werden in Kürze automatisch importiert.'"), ""),
			PictureLib.Information32);
	EndIf;
	
	If MessageTextArray.Count() > 0 Then
		
		For Each MessageText In MessageTextArray Do
			ShowUserNotification(NStr("en = 'Currencies have not been added.'; ru = 'Валюты не добавлены.';pl = 'Waluty nie były dodane.';es_ES = 'No se han añadido monedas.';es_CO = 'No se han añadido monedas.';tr = 'Para birimleri eklenmedi.';it = 'Le valute non sono state aggiunte.';de = 'Währungen wurden nicht hinzugefügt.'"),
				,
				MessageText,
				PictureLib.Error32);
		EndDo;
		
	EndIf;
	
	Close();
	
EndProcedure

#EndRegion
