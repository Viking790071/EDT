#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Private

// Adds currencies from the classifier to the currencies catalog.
//
// Parameters:
//   Codes - Array - numeric codes for the currencies to be added.
//
// Returns:
//   Array, CatalogRef.Currencies - references to the created currencies.
//
Function AddCurrenciesByCode(Val Codes) Export
	Var XMLClassifier, ClassifierTable, CCRecord, NewRow, Result;
	XMLClassifier = GetTemplate("NationalCurrencyClassifier").GetText();
	
	ClassifierTable = Common.ReadXMLToTable(XMLClassifier).Data;
	
	Result = New Array();
	
	For each Code In Codes Do
		CCRecord = ClassifierTable.Find(Code, "Code"); 
		If CCRecord = Undefined Then
			Continue;
		EndIf;
		
		CurrencyRef = Catalogs.Currencies.FindByCode(CCRecord.Code);
		If CurrencyRef.IsEmpty() Then
			NewRow = Catalogs.Currencies.CreateItem();
			NewRow.Code = CCRecord.Code;
			NewRow.Description = CCRecord.CodeSymbol;
			NewRow.DescriptionFull = CCRecord.Name;
			If CCRecord.RBCLoading Then
				NewRow.RateSource = Enums.RateSources.DownloadFromInternet;
			Else
				NewRow.RateSource = Enums.RateSources.ManualInput;
			EndIf;
			NewRow.InWordsParameters = CCRecord.NumerationItemOptions;
			NewRow.Write();
			Result.Add(NewRow.Ref);
		Else
			Result.Add(CurrencyRef);
		EndIf
	EndDo; 
	
	Return Result;
	
EndFunction

// Imports currency rates for the current date.
//
// Parameters:
//  ImportParameters - Structure - import details:
//   * PeriodStart - Date - start date of the period for loading the rate;
//   * PeriodEnd - Date - end date of the period for loading the rate;
//   * CurrenciesList - ValueTable - currencies to be loaded:
//     ** Currency - CatalogRef.Currencies;
//     ** CurrencyCode - String.
//  ResultAddress - String - a temporary storage address to store import results.
//
Procedure ImportActualRate(ImportParameters = Undefined, ResultAddress = Undefined) Export
	
	Common.OnStartExecuteScheduledJob(Metadata.ScheduledJobs.ImportCurrenciesRates);
	
	EventName = LogEventName();
	
	WriteLogEvent(EventName, EventLogLevel.Information, , ,
		NStr("ru = '???????????? ???????????????????????? ???????????????? ???????????? ??????????'; en = 'Scheduled import of currency exchange rates started.'; pl = 'Rozpocz??to pobieranie kurs??w walut obcych';es_ES = 'Importaci??n programada de los tipos de cambio de moneda se ha iniciado.';es_CO = 'Importaci??n programada de los tipos de cambio de moneda se ha iniciado.';tr = 'D??viz kurlar??n??n zamanlanm???? i??e aktar??m?? ba??lad??.';it = 'Importazione pianificata dei tassi di cambio delle valute avviata.';de = 'Geplanter Import der Wechselkurse gestartet.'"));
	
	If CurrenciesImportedFromInternet().Count() = 0 Then
		Raise NStr("en = 'There are no currencies detected which rates should be imported from the Internet. 
		           |In order to enable rate import for a given currency, please navigate to Cash management>Currencies, 
		           |edit selected currency, then set value ""imported from the Internet"" for option ""Exchange rate"".'; 
		           |ru = '???? ???????????????????? ??????????, ?????????????? ???????????? ???????? ?????????????????? ???? ??????????????????. 
		           |?????????? ???????????????? ???????????????? ?????? ????????????, ???????????????????? ?????????? ?? ???????????????????????? - ????????????, 
		           |???????????????? ???????????? ???????????????? ???????????????? ""?????????????????????? ???? ??????????????????"" ?? ?????????? ""???????? ????????????"".';
		           |pl = 'Nie wykryto ??adnych walut, kt??re powinny by?? importowane z Internetu. 
		           |W celu umo??liwienia importu st??p dla danej waluty obcej, przejd?? do ??rodki pieni????ne>Waluty, 
		           |edytuj wybran?? walut??, a nast??pnie ustaw warto???? ""importowana z Internetu"" dla opcji ""Kurs waluty"".';
		           |es_ES = 'No hay monedas detectadas cuyas tasas tienen que importarse desde Internet. 
		           |Para activar la importaci??n del tipo de cambio para la moneda dada, por favor, navegar a Gesti??n de efectivo> Monedas, 
		           |editar la moneda seleccionada, despu??s establecer el valor ""importado desde Internet"" para la variante ""Tipo de cambio"".';
		           |es_CO = 'No hay monedas detectadas cuyas tasas tienen que importarse desde Internet. 
		           |Para activar la importaci??n del tipo de cambio para la moneda dada, por favor, navegar a los Fondos> Monedas, 
		           |editar la moneda seleccionada, despu??s establecer el valor ""importado desde Internet"" para la opci??n ""Tipo de cambio"".';
		           |tr = 'D??viz kurlar??n??n internetten i??e aktar??lmas?? gereken para birimleri bulunamad??.
		           |Belirli bir para birimi i??in kur aktar??m??n?? etkinle??tirmek i??in l??tfen Finans > Para birimleri''ne gidin,
		           |se??ili para birimini d??zenleyin ve ""D??viz kuru"" se??ene??i i??in ""??nternetten i??e aktar??ld??"" de??erini ayarlay??n.';
		           |it = 'Non c''?? alcuna valuta identificata i cui tassi devono essere importati da internet.
		           |Al fine di abilitare l''importazione tassi per una valuta data, si prega di navigare alla Tesoreria>Valute,
		           |modifica la valuta selezionata, poi impostare ""importato da internet"" per l''opzione ""Tasso di cambio"".';
		           |de = 'Es werden keine W??hrungen gefunden, welche Tarife aus dem Internet importiert werden sollen.
		           |Um den Kursimport f??r eine bestimmte W??hrung zu aktivieren, navigieren Sie zu Barmittelverwaltungsw??hrungen,
		           |bearbeiten Sie die ausgew??hlte W??hrung und setzen Sie dann f??r die Option ""Wechselkurs"" den Wert ""aus dem Internet importiert"".'");
	EndIf;
		
	CurrentDate = CurrentSessionDate();
	
	DownloadStatus = Undefined;
	ErrorsOccurredOnImport = False;
	
	If ImportParameters = Undefined Then
		QueryText = 
		"SELECT
		|	ExchangeRate.Currency AS Currency,
		|	ExchangeRate.Currency.Code AS CurrencyCode,
		|	ExchangeRate.Company AS Company,
		|	MAX(ExchangeRate.Period) AS RateDate,
		|	Companies.ExchangeRatesImportProcessor AS ExchangeRatesImportProcessor
		|FROM
		|	InformationRegister.ExchangeRate AS ExchangeRate
		|		LEFT JOIN Catalog.Companies AS Companies
		|		ON ExchangeRate.Company = Companies.Ref
		|WHERE
		|	ExchangeRate.Currency.RateSource = VALUE(Enum.RateSources.DownloadFromInternet)
		|	AND NOT ExchangeRate.Currency.DeletionMark
		|	AND NOT Companies.DeletionMark
		|	AND NOT Companies.ExchangeRatesImportProcessor = VALUE(Catalog.AdditionalReportsAndDataProcessors.EmptyRef)
		|
		|GROUP BY
		|	ExchangeRate.Currency,
		|	ExchangeRate.Currency.Code,
		|	ExchangeRate.Company,
		|	Companies.ExchangeRatesImportProcessor
		|TOTALS BY
		|	ExchangeRatesImportProcessor";
		Query = New Query(QueryText);
		ImportProcessorSelection = Query.Execute().Select(QueryResultIteration.ByGroups);
		While ImportProcessorSelection.Next() Do
			
			DataProcessorManager = AdditionalReportsAndDataProcessors.ExternalDataProcessorObject(ImportProcessorSelection.ExchangeRatesImportProcessor);	
		
			EndOfPeriod = CurrentDate;
			Selection = ImportProcessorSelection.Select();
			While Selection.Next() Do
				BeginOfPeriod = ?(Selection.RateDate = DriveServer.GetDefaultDate(), BegOfYear(AddMonth(CurrentDate, -12)), Selection.RateDate + 60*60*24);
				CurrenciesList = CommonClientServer.ValueInArray(Selection);
				DataProcessorManager.ImportCurrencyRatesByParameters(CurrenciesList, Selection.Company, BeginOfPeriod, EndOfPeriod, ErrorsOccurredOnImport);
			EndDo;
		EndDo;
	Else
		
		ExtDataProcessor = Common.ObjectAttributeValue(ImportParameters.Company, "ExchangeRatesImportProcessor");
		If Not ValueIsFilled(ExtDataProcessor) Then	
			
			If Constants.UseSeveralCompanies.Get() Then
				MessageText = NStr("en = 'The Exchange rate import processor is required for the selected company.
					|Go to Company > Enterprise > Companies or Company details and fill in the Exchange rate import processor field for the company'; 
					|ru = '?????? ?????????????????? ?????????????????????? ???????????????????? ?????????????????? ???????????????? ???????????? ??????????.
					|?????????????????? ?? ???????????? ?????????????????????? > ?????????????????????? > ?????????????????????? ?????? ?????????????????? ?????????????????????? ?? ?????????????????? ???????? ?????????????????? ???????????????? ???????????? ?????????? ?????? ??????????????????????.';
					|pl = 'Procesor importu kurs??w walut jest wymagany dla wybranej firmy.
					|Przejd?? do Firma > Przedsi??biorstwo > Szczeg????y firm lub firmy i wype??nij pole procesora importu kurs??w walut dla firmy';
					|es_ES = 'El procesador de importaci??n de tipo de cambio es necesario para la empresa seleccionada.
					|Ir a Empresa > Enterprise > Empresas o Detalles de la empresa y rellene el campo Procesador de importaci??n de tipo de cambio para la empresa';
					|es_CO = 'El procesador de importaci??n de tipo de cambio es necesario para la empresa seleccionada.
					|Ir a Empresa > Enterprise > Empresas o Detalles de la empresa y rellene el campo Procesador de importaci??n de tipo de cambio para la empresa';
					|tr = 'Se??ilen i?? yeri i??in D??viz kuru oranlar?? i??e aktarma i??lemcisi gerekli.
					|???? yeri > Kurum > ???? yerleri veya ???? yeri ayr??nt??lar?? b??l??m??nde i?? yeri i??in D??viz kuru oranlar?? i??e aktarma i??lemcisi alan??n?? doldurun';
					|it = 'Il processore di importazione del tasso di cambio ?? richiesto per l''azienda selezionata. 
					|Andare a Azienda> Impresa > Aziende o dettagli azienda e compilare il campo processore di importazione del tasso di cambio per l''azienda';
					|de = 'Der Wechselkurse Importprozessor ist f??r die ausgew??hlte Firma erforderlich.
					|Gehen Sie zu Firma > Unternehmen > Firmen oder Firmendetails und f??llen Sie das Feld Wechselkurse Importprozessor f??r die Firma aus'");
			Else
				MessageText = NStr("en = 'The Exchange rate import processor is required for the selected company.
					|Go to Company > Enterprise > Company details and fill in the Exchange rate import processor field.'; 
					|ru = '?????? ?????????????????? ?????????????????????? ???????????????????? ?????????????????? ???????????????? ???????????? ??????????.
					|?????????????????? ?? ???????????? ?????????????????????? > ?????????????????????? > ?????????????????? ?????????????????????? ?? ?????????????????? ???????? ?????????????????? ???????????????? ???????????? ??????????.';
					|pl = 'Procesor importu kurs??w walut jest wymagany dla wybranej firmy.
					|Przejd?? do Firma > Przedsi??biorstwo > Szczeg????y firmy i wype??nij pole procesora importu kurs??w walut.';
					|es_ES = 'El procesador de importaci??n de tipo de cambio es necesario para la empresa seleccionada.
					|Ir a Empresa > Enterprise > Detalles de la empresa y rellene el campo Procesador de importaci??n de tipo de cambio para la empresa.';
					|es_CO = 'El procesador de importaci??n de tipo de cambio es necesario para la empresa seleccionada.
					|Ir a Empresa > Enterprise > Detalles de la empresa y rellene el campo Procesador de importaci??n de tipo de cambio para la empresa.';
					|tr = 'Se??ilen i?? yeri i??in D??viz kuru i??e aktarma i??lemcisi gerekli.
					|???? yeri > Kurum > ???? yeri ayr??nt??lar?? b??l??m??nde D??viz kuru i??e aktarma i??lemcisi alan??n?? doldurun.';
					|it = 'Il processore di importazione del tasso di cambio ?? richiesto per l''azienda selezionata. 
					|Andare a Azienda> Impresa > Dettagli azienda e compilare il campo processore di importazione del tasso di cambio.';
					|de = 'Der Wechselkurs-Importverarbeiter ist f??r die ausgew??hlte Firma erforderlich.
					|Gehen Sie zu Firma > Unternehmen > Firmendetails und f??llen Sie das Feld Wechselkurse Importprozessor aus.'");
			EndIf;
			
			Raise MessageText;
		EndIf;
		
		DataProcessorManager = AdditionalReportsAndDataProcessors.ExternalDataProcessorObject(ExtDataProcessor);	
		
		Result = DataProcessorManager.ImportCurrencyRatesByParameters(ImportParameters.CurrenciesList, ImportParameters.Company,   
			ImportParameters.BeginOfPeriod, ImportParameters.EndOfPeriod, ErrorsOccurredOnImport);
	EndIf;
		
	If ResultAddress <> Undefined Then
		PutToTempStorage(Result, ResultAddress);
	EndIf;

	If ErrorsOccurredOnImport Then
		WriteLogEvent(
			EventName,
			EventLogLevel.Error,
			, 
			,
			NStr("ru = '???? ?????????? ?????????????????????????? ?????????????? ???????????????? ???????????? ?????????? ???????????????? ????????????'; en = 'Errors occurred in the ""Import currency exchange rates"" scheduled job.'; pl = 'Wyst??pi??y b????dy w zaplanowanym zadaniu ""Importuj kursy wymiany walut obcych"".';es_ES = 'Se han producido errores en la tarea programada ""Importar tipos de cambio de monedas"".';es_CO = 'Se han producido errores en la tarea programada ""Importar tipos de cambio de monedas"".';tr = '""D??viz kurlar??n?? i??e aktar"" zamanlanm???? i??inde hatalar olu??tu.';it = 'Si ?? verificato un errore nel lavoro pianificato ""Importazione tassi di cambio valute"".';de = 'Im geplanten Job ""Wechselkurse der W??hrung importieren"" sind Fehler aufgetreten.'"));
		Raise NStr("ru = '???????????????? ???????????? ???? ??????????????????.'; en = 'The exchange rates are not imported.'; pl = 'Kursy wymiany nie s?? importowane.';es_ES = 'Tipos de cambio no importados.';es_CO = 'Tipos de cambio no importados.';tr = 'D??viz kurlar?? i??e aktar??lamad??.';it = 'I tassi di cambio non sono importati.';de = 'Die Wechselkurse werden nicht importiert.'");
	Else
		WriteLogEvent(
			EventName,
			EventLogLevel.Information,
			,
			,
			NStr("ru = '?????????????????? ???????????????????????? ???????????????? ???????????? ??????????.'; en = 'Scheduled import of currency exchange rates is completed.'; pl = 'Planowane pobieranie kurs??w wymiany walut obcych zosta??o zako??czone.';es_ES = 'Importaci??n programada de los tipos de cambio de moneda se ha completado.';es_CO = 'Importaci??n programada de los tipos de cambio de moneda se ha completado.';tr = 'D??viz kurlar??n??n zamanlanm???? i??e aktar??m?? tamamland??.';it = 'Importazione pianificata dei tassi di cambio delle valute completata.';de = 'Der planm????ige Import der Wechselkurse der W??hrung ist abgeschlossen.'"));
	EndIf;
	
EndProcedure

// Returns a list of permissions required to import the bank classifier from the 1C website.
//
// Parameters:
//  Permissions - Array - permissions collection.
//
Procedure AddPermissions(Permissions) Export
	
	SetPrivilegedMode(True);
	UseAlternativeServer = Constants.UseAlternativeSerrverToImportCurrencyRates.Get();
	SetPrivilegedMode(False);
	
	ModuleSafeModeManager = Common.CommonModule("SafeModeManager");
	
	If UseAlternativeServer Then
		Protocol = "HTTP";
		Address = "cbrates.rbc.ru";
		Port = Undefined;
		Details = NStr("ru = '???????????????? ???????????? ?????????? ?? ?????????? ??????.'; en = 'Import exchange rates from the RBC website.'; pl = 'Pobierz kursy walut ze strony RBC.';es_ES = 'Importar los tipos de cambio de la p??gina web de RBC.';es_CO = 'Importar los tipos de cambio de la p??gina web de RBC.';tr = 'D??viz kurlar??n?? RBC web sitesinden i??e aktar??n.';it = 'Importare tassi di cambio dal sito RBC.';de = 'Importieren Sie Wechselkurse von der RBC-Website.'");
		Permissions.Add( 
			ModuleSafeModeManager.PermissionToUseInternetResource(Protocol, Address, Port, Details));
	Else
		Protocol = "HTTPS";
		Address = "currencyrates.1c.ru";
		Port = Undefined;
		Details = NStr("ru = '???????????????? ???????????? ?????????? ?? ?????????? 1??.'; en = 'Import exchange rates from the 1C website.'; pl = 'Pobierz kursy walut ze strony 1C.';es_ES = 'Importar los tipos de cambio de la p??gina web de 1C.';es_CO = 'Importar los tipos de cambio de la p??gina web de 1C.';tr = 'D??viz kurlar??n?? 1C web sitesinden i??e aktar??n';it = 'Importa i tassi di cambio dal sito 1C';de = 'Importieren Sie Wechselkurse von der 1C-Website.'");
		Permissions.Add( 
			ModuleSafeModeManager.PermissionToUseInternetResource(Protocol, Address, Port, Details));
	EndIf;
	
EndProcedure

// See InfobaseUpdateSSL.OnAddUpdateHandlers. 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version = "1.0.5.9";
	Handler.Procedure = "DataProcessors.ImportCurrenciesRates.UpdateDataInWordsStorageFormat";
	
	Handler = Handlers.Add();
	Handler.Version = "2.4.1.1";
	Handler.Procedure = "DataProcessors.ImportCurrenciesRates.DisableImportCurrencyRate643FromInternet";
	Handler.ExecutionMode = "Deferred";
	Handler.ID = New UUID("dc79c561-8657-4852-bbc5-38ced6996fff");
	Handler.Comment = NStr("ru = '?????????????????? ???????????????? ???????????????????? ???????????????? ???????????? ???????????? ""???????????????????? ?????????? (643)"" ???? ??????????????????.'; en = 'Disables erroneously enabled import of exchange rate for ""Russian ruble (643)"" from the internet.'; pl = 'Wy????cza b????dnie w????czony import kursu wymiany walut obcych ""Rubel rosyjski (643)"" z internetu.';es_ES = 'Desactivar importaci??n err??neamente permitida del tipo de cambio de ""Rublo ruso (643)"" de Internet.';es_CO = 'Desactivar importaci??n err??neamente permitida del tipo de cambio de ""Rublo ruso (643)"" de Internet.';tr = '??nternetten ""Rus Rublesi (643)"" i??in d??viz kurunun hatal?? ??ekilde al??nmas??n?? engeller.';it = 'Disattiva l''importazione avviata erroneamente del tasso di cambio per ""Rublo russo (643)"" da internet.';de = 'Deaktiviert f??lschlicherweise den Import des Wechselkurses f??r ""Russischer Rubel (643)"" aus dem Internet.'");
	Handler.DeferredProcessingQueue = 1;
	Handler.UpdateDataFillingProcedure = "DataProcessors.ImportCurrenciesRates.RegisterDataToProcessForMigrationToNewVersion";
	Handler.ObjectsToRead      = "Catalog.Currencies";
	Handler.ObjectsToChange    = "Catalog.Currencies";
	
	If Not Common.DataSeparationEnabled() Then
		Handler = Handlers.Add();
		Handler.Version = "2.4.1.1";
		Handler.Procedure = "DataProcessors.ImportCurrenciesRates.SetJobSchedule";
		Handler.ExecutionMode = "Seamless";
		Handler.InitialFilling = True;
	EndIf;
	
EndProcedure

// Registers the objects to be updated to the latest version in the InfobaseUpdate exchange plan.
// 
//
// Parameters:
//  Parameters - Structure - an internal parameter to pass to the InfobaseUpdate.MarkForProcessing procedure.
//
Procedure RegisterDataToProcessForMigrationToNewVersion(Parameters) Export
	
	QueryText =
	"SELECT
	|	Currencies.Ref
	|FROM
	|	Catalog.Currencies AS Currencies
	|WHERE
	|	Currencies.Code = ""643""
	|	AND Currencies.RateSource = VALUE(Enum.RateSources.DownloadFromInternet)";
	
	Query = New Query(QueryText);
	
	Result = Query.Execute().Unload();
	RefsArray = Result.UnloadColumn("Ref");
	
	InfobaseUpdate.MarkForProcessing(Parameters, RefsArray);
	
EndProcedure

// See ScheduledJobsOverridable.OnDefineScheduledJobSettings. 
Procedure OnDefineScheduledJobSettings(Dependencies) Export
	Dependence = Dependencies.Add();
	Dependence.ScheduledJob = Metadata.ScheduledJobs.ImportCurrenciesRates;
	Dependence.AvailableSaaS = False;
	Dependence.AvailableAtStandaloneWorkstation = False;
EndProcedure

// Sets the flag indicating that rates must be downloaded from the internet following the classifier data.
Procedure ConvertCurrencyLinks() Export
	Var Query, Selection, RecordSet, Record;
	Var XMLClassifier, ClassifierTable, Currency, FoundRow;
	
	XMLClassifier = DataProcessors["ImportCurrenciesRates"].GetTemplate("NationalCurrencyClassifier").GetText();
	ClassifierTable = Common.ReadXMLToTable(XMLClassifier).Data;
	ClassifierTable.Indexes.Add("Code");
	
	Selection = Catalogs.Currencies.Select();
	While Selection.Next()  Do
		Currency = Selection.GetObject();
		FoundRow = ClassifierTable.Find(Currency.Code, "Code");
		If FoundRow <> Undefined AND FoundRow.RBCLoading = "true" Then
			Currency.RateSource = Enums.RateSources.DownloadFromInternet;
			InfobaseUpdate.WriteData(Currency);
		EndIf;
	EndDo;

EndProcedure

Procedure UpdateDataInWordsStorageFormat() Export
	
	CurrencySelection = Catalogs.Currencies.Select();
	
	While CurrencySelection.Next() Do
		Object = CurrencySelection.GetObject();
		ParameterString = StrReplace(Object.InWordsParameters, ",", Chars.LF);
		Sort1 = Lower(Left(TrimAll(StrGetLine(ParameterString, 4)), 1));
		Sort2 = Lower(Left(TrimAll(StrGetLine(ParameterString, 8)), 1));
		Object.InWordsParameters = 
					  TrimAll(StrGetLine(ParameterString, 1)) + ", "
					+ TrimAll(StrGetLine(ParameterString, 2)) + ", "
					+ TrimAll(StrGetLine(ParameterString, 3)) + ", "
					+ Sort1 + ", "
					+ TrimAll(StrGetLine(ParameterString, 5)) + ", "
					+ TrimAll(StrGetLine(ParameterString, 6)) + ", "
					+ TrimAll(StrGetLine(ParameterString, 7)) + ", "
					+ Sort2 + ", "
					+ TrimAll(StrGetLine(ParameterString, 9));
		InfobaseUpdate.WriteData(Object);
	EndDo;
	
EndProcedure

// Turns off the internet download for the currency 643.
Procedure DisableImportCurrencyRate643FromInternet(Parameters) Export
	Selection = InfobaseUpdate.SelectRefsToProcess(Parameters.PositionInQueue, "Catalog.Currencies");
	While Selection.Next() Do
		Currency = Selection.Ref.GetObject();
		Currency.RateSource = Enums.RateSources.ManualInput;
		InfobaseUpdate.WriteData(Currency);
	EndDo;
	
	Parameters.ProcessingCompleted = InfobaseUpdate.DataProcessingCompleted(Parameters.PositionInQueue, "Catalog.Currencies");
EndProcedure

Procedure SetJobSchedule() Export
	
	RandomNumberGenerator = New RandomNumberGenerator(CurrentUniversalDateInMilliseconds());
	Delay = RandomNumberGenerator.RandomNumber(0, 21600); // From midnight till 6 AM.
	
	Schedule = New JobSchedule;
	Schedule.DaysRepeatPeriod = 1;
	Schedule.WeeksPeriod = 1;
	Schedule.BeginTime = '00010101000000' + Delay;
	
	JobParameters = New Structure;
	JobParameters.Insert("Schedule", Schedule);
	JobParameters.Insert("RestartIntervalOnFailure", 600);
	JobParameters.Insert("RestartCountOnFailure", 10);
	
	SetScheduledJobParameters(JobParameters);
	
EndProcedure

Procedure SetScheduledJobParameters(ParametersToChange)
	ScheduledJobsServer.SetScheduledJobParameters(
		Metadata.ScheduledJobs.ImportCurrenciesRates, ParametersToChange);
EndProcedure

Function CurrenciesImportedFromInternet()
	
	QueryText =
	"SELECT
	|	Currencies.Ref AS Ref
	|FROM
	|	Catalog.Currencies AS Currencies
	|WHERE
	|	NOT Currencies.DeletionMark
	|	AND Currencies.RateSource = VALUE(Enum.RateSources.DownloadFromInternet)";
	
	Query = New Query(QueryText);
	Result = Query.Execute().Unload().UnloadColumn("Ref");
	
	Return Result;
EndFunction

Function LogEventName()
	Return NStr("ru = '????????????.???????????????? ???????????? ??????????'; en = 'Currencies.Import currency exchange rates'; pl = 'Waluta.Import kurs??w wymiany walut';es_ES = 'Moneda.Importaci??n de los tipos de cambio';es_CO = 'Moneda.Importaci??n de los tipos de cambio';tr = 'Para birimi. D??viz kuru i??e aktar??m??';it = 'Valute. Importare tassi di cambio delle valute';de = 'W??hrung. Wechselkurse importieren'", CommonClientServer.DefaultLanguageCode());
EndFunction

// See OnlineSupportOverridable.OnSaveOnlineSupportUserAuthenticationData. 
Procedure OnSaveOnlineSupportUserAuthenticationData(UserData) Export
	SetScheduledJobParameters(New Structure("Use", True));
EndProcedure

// See OnlineSupportOverridable.OnDeleteOnlineSupportUserAuthenticationData. 
Procedure OnDeleteOnlineSupportUserAuthenticationData() Export
	SetScheduledJobParameters(New Structure("Use", False));
EndProcedure

#EndRegion

#EndIf