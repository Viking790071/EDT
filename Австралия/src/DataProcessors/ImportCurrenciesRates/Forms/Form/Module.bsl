
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If NOT Parameters.Property("OpeningFromList") Then
		If CurrencyRateOperations.RatesUpToDate() Then
			MessageRatesUpToDate = True;
			Return;
		EndIf;
	EndIf;
	
	If Parameters.Property("Company") Then
		Company = Parameters.Company;
	Else
		Company = DriveReUse.GetUserDefaultCompany();
	EndIf;
	
	FillCurrencies();
	
	// Starting and end point for a rates import period.
	Object.ImportPeriodEnd = BegOfDay(CurrentSessionDate());
	Object.ImportPeriodStart = Object.ImportPeriodEnd;
	MinDate = BegOfYear(Object.ImportPeriodEnd);
	For Each Currency In Object.CurrenciesList Do
		If ValueIsFilled(Currency.RateDate) AND Currency.RateDate < Object.ImportPeriodStart Then
			If Currency.RateDate < MinDate Then
				Object.ImportPeriodStart = MinDate;
				Break;
			EndIf;
			Object.ImportPeriodStart = Currency.RateDate;
		EndIf;
	EndDo;
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	If MessageRatesUpToDate Then
		CurrencyRateOperationsClient.NotifyRatesUpToDate();
		Cancel = True;
		Return;
	EndIf;
	
	AttachIdleHandler("ValidateCurrenciesToImportList", 0.1, True);
EndProcedure

&AtClient
Procedure CompanyOnChange(Item)
	FillCurrencies();
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure BeginOfPeriodOnChange(Item)
	CheckDate(Object.ImportPeriodStart);
EndProcedure

&AtClient
Procedure EndOfPeriodOnChange(Item)
	CheckDate(Object.ImportPeriodEnd);
EndProcedure

#EndRegion

#Region CurrenciesListFormTableItemsEventHandlers

&AtClient
Procedure CurrencyListChoice(Item, RowSelected, Field, StandardProcessing)
	StandardProcessing = False;
	SwitchImport();
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ImportCurrenciesRates(Command)
	ExchangeRatesImport();
EndProcedure

&AtClient
Procedure SelectAllCurrencies(Command)
	ConnectSelection(True);
	SetItemsEnabled();
EndProcedure

&AtClient
Procedure ClearSelection(Command)
	ConnectSelection(False);
	SetItemsEnabled();
EndProcedure

&AtClient
Procedure ImportOnChange(Item)
	SetItemsEnabled();
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.RateDate.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Object.CurrenciesList.RateDate");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = New StandardBeginningDate(DriveServer.GetDefaultDate());

	Item.Appearance.SetParameterValue("Text", "");

EndProcedure

&AtClient
Procedure ConnectSelection(Choice)
	For Each Currency In Object.CurrenciesList Do
		Currency.Import = Choice;
	EndDo;
EndProcedure

&AtServer
Procedure FillCurrencies()
	
	// Fill the table with a list of currencies whose rate is independent of other currency rates.
	CurrenciesList = Object.CurrenciesList;
	CurrenciesList.Clear();
	
	CurrenciesToImport = CurrencyRateOperations.CurrenciesToImport();
	
	For Each CurrencyItem In CurrenciesToImport Do
		AddCurrencyToList(CurrencyItem);
	EndDo;
	
EndProcedure

&AtServer
Procedure AddCurrencyToList(Currency)
	
	// Creates entries in the currency list.
	NewRow = Object.CurrenciesList.Add();
	
	// Fills in rate data on the basis of a currency reference.
	FillTableRowDataBasedOnCurrency(NewRow, Currency);
	
	NewRow.Import = True;
	
EndProcedure

&AtServer
Procedure RefreshInfoInCurrenciesList()
	
	// Updating currency rate entries in the list.
	
	For Each DataString In Object.CurrenciesList Do
		RefToCurrency = DataString.Currency;
		FillTableRowDataBasedOnCurrency(DataString, RefToCurrency);
	EndDo;
	
EndProcedure

&AtServer
Procedure FillTableRowDataBasedOnCurrency(TableRow, Currency);
	
	CurrencyInfo = Common.ObjectAttributesValues(Currency, "DescriptionFull,Code,Description");
	
	TableRow.Currency = Currency;
	TableRow.CurrencyCode = CurrencyInfo.Code;
	TableRow.AlphabeticCode = CurrencyInfo.Description;
	TableRow.Presentation = CurrencyInfo.DescriptionFull;
	
	RateData = CurrencyRateOperations.FillCurrencyRateData(Currency, Company);
	
	If TypeOf(RateData) = Type ("Structure") Then
		TableRow.RateDate = RateData.RateDate;
		TableRow.Rate      = RateData.Rate;
		TableRow.Repetition = RateData.Repetition;
	EndIf;
	
EndProcedure

&AtClient
Procedure ValidateCurrenciesToImportList()
	If Object.CurrenciesList.Count() = 0 Then
		NotifyDescription = New NotifyDescription("ValidateCurrenciesToImportListCompletion", ThisObject);
		WarningText = NStr("ru = '?? ?????????????????????? ?????????? ?????????????????????? ????????????, ?????????? ?????????????? ?????????? ?????????????????? ???? ???????? ????????????????.'; en = 'The list of currencies contains no currencies whose exchange rates are imported from the internet.'; pl = 'Lista walut obcych nie zawiera walut, kt??rych kursy wymiany s?? importowane z internetu.';es_ES = 'La lista de monedas no contiene divisas cuyos tipos de cambio se han importado de Internet.';es_CO = 'La lista de monedas no contiene divisas cuyos tipos de cambio se han importado de Internet.';tr = 'Para birimleri listesi, d??viz kurlar?? internetten al??nan para birimleri i??ermiyor.';it = 'L''elenco delle valute non contiene valute il cui tasso di cambio ?? importato da internet.';de = 'Die Liste der W??hrungen enth??lt keine W??hrungen, deren Wechselkurse aus dem Internet importiert werden.'");
		ShowMessageBox(NotifyDescription, WarningText);
	EndIf;
EndProcedure

&AtClient
Procedure ValidateCurrenciesToImportListCompletion(AdditionalParameters) Export
	Close();
EndProcedure

&AtClient
Procedure SetItemsEnabled()
	
	HaveSelectedCurrencies = Object.CurrenciesList.FindRows(New Structure("Import", True)).Count() > 0;
	Items.FormImportCurrenciesRates.Enabled = HaveSelectedCurrencies;
	
EndProcedure

&AtClient
Procedure DisableImportSelectedCurrencyRateFromInternet(Command)
	CurrentData = Items.CurrenciesList.CurrentData;
	RemoveImportFromInternetFlag(CurrentData.Currency);
	Object.CurrenciesList.Delete(CurrentData);
EndProcedure

&AtServer
Procedure RemoveImportFromInternetFlag(CurrencyRef)
	CurrencyObject = CurrencyRef.GetObject();
	CurrencyObject.RateSource = Enums.RateSources.ManualInput;
	CurrencyObject.Write();
EndProcedure

&AtClient
Procedure SwitchImport()
	Items.CurrenciesList.CurrentData.Import = Not Items.CurrenciesList.CurrentData.Import;
	SetItemsEnabled();
EndProcedure

&AtServer
Function ExecuteRatesImport()
	
	SetPrivilegedMode(True);
	
	ScheduledJob = Metadata.ScheduledJobs.ImportCurrenciesRates;
	
	BackgroundJobDescription = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = '???????????? ??????????????: %1'; en = '%1 (started manually)'; pl = '%1 (uruchamiany r??cznie)';es_ES = '%1 (iniciado manualmente)';es_CO = '%1 (iniciado manualmente)';tr = '%1 (Manuel olarak ba??lad??)';it = '%1 (avviato manualmente)';de = '%1 (manuell gestartet)'"),
		ScheduledJob.Synonym);
	
	ImportParameters = New Structure;
	ImportParameters.Insert("BeginOfPeriod", Object.ImportPeriodStart);
	ImportParameters.Insert("EndOfPeriod", Object.ImportPeriodEnd);
	ImportParameters.Insert("Company", Company);
	ImportParameters.Insert("CurrenciesList", Common.ValueTableToArray(Object.CurrenciesList.Unload(
		Object.CurrenciesList.FindRows(New Structure("Import", True)), "CurrencyCode,Currency")));
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	ExecutionParameters.BackgroundJobDescription = BackgroundJobDescription;
	
	Return TimeConsumingOperations.ExecuteInBackground(ScheduledJob.MethodName, ImportParameters, ExecutionParameters);
	
EndFunction

&AtClient
Procedure OnCompleteImportRates(Result, AdditionalParameters) Export
	
	Items.Pages.CurrentPage = Items.CurrenciesListPage;
	Items.CommandBar.Enabled = True;
	
	If Result = Undefined Then
		Return;
	EndIf;
	
	If Result.Status = "Error" Then
		Raise Result.BriefErrorPresentation + Chars.LF + NStr("ru = '?????????????????????? ????. ?? ?????????????? ??????????????????????.'; en = 'See the event log for details.'; pl = 'Szczeg????y w Dzienniku wydarze??';es_ES = 'Ver detalles en el registro.';es_CO = 'Ver detalles en el registro.';tr = 'Ayr??nt??lar i??in olay g??nl??????ne bak??n.';it = 'Guarda il registro eventi per dettagli.';de = 'Siehe Details im Protokoll.'");
	EndIf;
	
	ProcessImportResult(GetFromTempStorage(Result.ResultAddress));
	
EndProcedure

&AtClient
Procedure ProcessImportResult(ImportResult)
	
	HaveImportedRates = False;
	WithoutErrors = True;
	
	ErrorsCount = 0;
	
	ErrorsList = New TextDocument;
	For Each DownloadStatus In ImportResult Do
		If DownloadStatus.OperationStatus Then
			HaveImportedRates = True;
		Else
			WithoutErrors = False;
			ErrorsCount = ErrorsCount + 1;
			ErrorsList.AddLine(TrimAll(DownloadStatus.Message) + Chars.LF);
		EndIf;
	EndDo;
	
	If HaveImportedRates Then
		RefreshInfoInCurrenciesList();
		WriteParameters = Undefined;
		CurrenciesToUpdateArray = New Array;
		For Each TableRow In Object.CurrenciesList Do
			CurrenciesToUpdateArray.Add(TableRow.Currency);
		EndDo;
		Notify("Write_CurrencyRateImport", WriteParameters, CurrenciesToUpdateArray);
		CurrencyRateOperationsClient.NotifyRatesAreUpdated();
	EndIf;
	
	If WithoutErrors Then
		NotifyDescription = New NotifyDescription("ImportResultProcessingMessageBoxEnd", ThisObject);
		ShowMessageBox(
			NotifyDescription, 
			NStr("en = 'Exchange rates have been successfully imported.'; ru = '?????????? ?????????? ?????????????? ??????????????????.';pl = 'Kursy wymiany walut zosta??y pomy??lnie zaimportowane.';es_ES = 'Tipos de cambio se han importado con ??xito.';es_CO = 'Tipos de cambio se han importado con ??xito.';tr = 'D??viz kurlar?? ba??ar??yla i??e aktar??ld??.';it = 'Il tasso di cambio ?? stato importato con successo.';de = 'Wechselkurse wurden erfolgreich importiert.'"), );
	Else
		ErrorPresentation = TrimAll(ErrorsList.GetText());
		If ErrorsCount > 1 Then
			Buttons = New ValueList;
			Buttons.Add("Details", NStr("ru = '??????????????????...'; en = 'Details...'; pl = 'Wi??cej???';es_ES = 'M??s...';es_CO = 'M??s...';tr = 'Ayr??nt??lar...';it = 'Dettagli...';de = 'Details...'"));
			Buttons.Add("Continue", NStr("ru = '????????????????????'; en = 'Continue'; pl = 'Kontynuuj';es_ES = 'Continuar';es_CO = 'Continuar';tr = 'Devam';it = 'Continua';de = 'Weiter'"));
			QuestionText = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = '???? ?????????????? ?????????????????? ?????????? ?????????? (%1).'; en = 'Cannot import currency exchange rates (%1).'; pl = 'Nie mo??na importowa?? kurs??w wymiany walut obcych (%1).';es_ES = 'No se puede importar los tipos de cambio de moneda (%1).';es_CO = 'No se puede importar los tipos de cambio de moneda (%1).';tr = 'D??viz kurlar?? i??e aktar??lam??yor (%1).';it = 'Impossibile importare i tassi di cambio delle valute (%1).';de = 'Es ist nicht m??glich, Wechselkurse der W??hrung (%1) zu importieren.'"), ErrorsCount);
			NotifyDescription = New NotifyDescription("ProcessImportResultIfQuestionAnswered", ThisObject, ErrorPresentation);
			ShowQueryBox(NotifyDescription, QuestionText, Buttons);
		Else
			ShowMessageBox(, ErrorPresentation);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure ImportResultProcessingMessageBoxEnd(Parameters) Export
	Close();
EndProcedure

&AtClient
Procedure ProcessImportResultIfQuestionAnswered(QuestionResult, ErrorPresentation) Export
	If QuestionResult <> "Details" Then
		Return;
	EndIf;
	
	OpenForm("DataProcessor.ImportCurrenciesRates.Form.ErrorMessages", New Structure("Text", ErrorPresentation));	
EndProcedure

&AtClient
Procedure ExchangeRatesImport()
	
	ClearMessages();
	
	Cancel = False;
	If Not ValueIsFilled(Company) Then
		CommonClientServer.MessageToUser(
			NStr("en = 'Please specify the company'; ru = '???????? ""??????????????????????"" ???? ??????????????????';pl = 'Prosz?? okre??li?? firm??';es_ES = 'Por favor, especifique la empresa';es_CO = 'Por favor, especifique la empresa';tr = 'L??tfen, i?? yerini belirtin';it = 'Si prega di specificare l''azienda';de = 'Bitte geben Sie die Firma an'"),
			,
			"Company");
		Cancel = True;
	EndIf;
	If Not ValueIsFilled(Object.ImportPeriodStart) Then
		CommonClientServer.MessageToUser(
			NStr("ru = '???? ???????????? ???????? ???????????? ?????????????? ????????????????.'; en = 'Please specify the start date of the import period.'; pl = 'Prosz?? poda?? dat?? rozpocz??cia okresu importu.';es_ES = 'Por favor, especifique la fecha de inicio del per??odo de importaci??n.';es_CO = 'Por favor, especifique la fecha de inicio del per??odo de importaci??n.';tr = 'L??tfen, i??e aktarma d??neminin ba??lang???? tarihini belirtin.';it = 'Si prega di specificare la data di avvio del periodo di importazione.';de = 'Bitte geben Sie das Startdatum des Importzeitraums an.'"),
			,
			"Object.ImportPeriodStart");
		Cancel = True;
	EndIf;
	If Not ValueIsFilled(Object.ImportPeriodEnd) Then
		CommonClientServer.MessageToUser(
			NStr("ru = '???? ???????????? ???????? ?????????????????? ?????????????? ????????????????.'; en = 'Please specify the end date of the import period.'; pl = 'Prosz?? poda?? dat?? rozpocz??cia okresu importu.';es_ES = 'Por favor, especifique la fecha de final del per??odo de importaci??n.';es_CO = 'Por favor, especifique la fecha de final del per??odo de importaci??n.';tr = 'L??tfen i??e aktarma d??neminin biti?? tarihini belirtin.';it = 'Si prega di specificare la data di fine del periodo di importazione.';de = 'Bitte geben Sie das Enddatum des Importzeitraums an.'"),
			,
			"Object.ImportPeriodEnd");
		Cancel = True;
	EndIf;
	If Cancel Then
		Return;
	EndIf;
	
	RatesDownloadOperation = ExecuteRatesImport();
	
	Items.Pages.CurrentPage = Items.RatesImportInProgressPage;
	Items.CommandBar.Enabled = False;
	
	IdleParameters = TimeConsumingOperationsClient.IdleParameters(ThisObject);
	IdleParameters.OutputIdleWindow = False;
	
	NotifyDescription = New NotifyDescription("OnCompleteImportRates", ThisObject);
	TimeConsumingOperationsClient.WaitForCompletion(RatesDownloadOperation, NotifyDescription, IdleParameters);
	
EndProcedure

&AtClient
Procedure CheckDate(Attribute)
	
	If Attribute > CurrentDate() Then
		MessageText = NStr("en = 'The date cannot be earlier than the current time'; ru = '???????? ???? ?????????? ???????? ???????????? ???????????????? ??????????????';pl = 'Data nie mo??e by?? wcze??niejsza ni?? bie????ca data';es_ES = 'La fecha no puede ser anterior a la hora actual';es_CO = 'La fecha no puede ser anterior a la hora actual';tr = 'Tarih ??u ankinden ??nce olamaz';it = 'La data non pu?? essere precedente all''ora corrente';de = 'Das Datum darf nicht vor der aktueller Uhrzeit liegen'");
		CommonClientServer.MessageToUser(MessageText);
		Attribute = CurrentDate();
	EndIf;
	
EndProcedure

#EndRegion
