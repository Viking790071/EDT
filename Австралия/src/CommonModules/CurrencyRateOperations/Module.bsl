#Region Public

// Adds currencies from the classifier to the currency catalog.
//
// Parameters:
//   Codes - Array - numeric codes for the currencies to be added.
//
// Returns:
//   Array, CatalogRef.Currencies - references to the created currencies.
//
Function AddCurrenciesByCode(Val Codes) Export
	
	If Metadata.DataProcessors.Find("ImportCurrenciesRates") <> Undefined Then
		Result = DataProcessors["ImportCurrenciesRates"].AddCurrenciesByCode(Codes);
	Else
		Result = New Array();
	EndIf;
	
	Return Result;
	
EndFunction

// Returns a currency rate for a specific date.
//
// Parameters:
//   Currency - CatalogRef.Currencies - the currency.
//   RateDate - Date - the date.
//
// Returns:
//   Structure - the rate parameters.
//       * Rate      - Number - the currency rate as of the specified date.
//       * Multiplier - Number - the currency rate multiplier as of the specified date.
//       * Currency    - CatalogRef.Currencies - a currency reference.
//       * RateDate - Date - the exchange rate date.
//
Function GetCurrencyRate(RateDate = '00010101', Currency, Company) Export
	
	Result = InformationRegisters.ExchangeRate.GetLast(RateDate, New Structure("Currency,Company", Currency, Company));
	
	Result.Insert("Currency", 			Currency);
	Result.Insert("Company",  			Company);
	Result.Insert("RateDate", 			RateDate);
	
	Return Result;
	
EndFunction

// Generates a presentation of an amount of a given currency in words.
//
// Parameters:
//   AmontAsNumber - Number - the amount to be presented in words.
//   Currency - CatalofRef.Currencies - the currency the amount must be presented in.
//   OutputAmountWithoutFractionalPart - Boolean - shows whether the amount presentation contains the fractional part.
//
// Returns:
//   String - the amount in words.
//
Function GenerateAmountInWords(AmountAsNumber, Currency, OutputAmountWithoutFractionalPart = False) Export
	
	Amount             = ?(AmountAsNumber < 0, -AmountAsNumber, AmountAsNumber);
	AmountInWordsParameters = Common.ObjectAttributeValue(Currency, "InWordParametersInEnglish");
	
	Result = NumberInWords(Amount, "L=" + CommonClientServer.DefaultLanguageCode() + ";FS=False", AmountInWordsParameters);
	
	If OutputAmountWithoutFractionalPart AND Int(Amount) = Amount Then
		Result = Left(Result, StrFind(Result, "0") - 1);
	EndIf;
	
	Return Result;
	
EndFunction

// Converts an amount from one currency to another.
//
// Parameters:
//  Amount          - Number - the source amount.
//  SourceCurrency - CatalogRef.Currencies - the source currency.
//  NewCurrency    - CatalogRef.Currencies - the new currency.
//  Date           - Date - the exchange rate date.
//
// Returns:
//  Number - the converted amount.
//
Function ConvertToCurrency(Amount, ExchangeRateMethod, SourceCurrency, NewCurrency, Company, Date) Export
	
	Return CurrenciesExchangeRatesClientServer.ConvertAtRate(Amount,
	    ExchangeRateMethod,
		GetCurrencyRate(Date, SourceCurrency, Company),
		GetCurrencyRate(Date, NewCurrency, Company));
		
EndFunction

#EndRegion

#Region Internal

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See ToDoListOverridable.OnDetermineToDoListHandlers. 
Procedure OnFillToDoList(ToDoList) Export
	
	MetadataObject = Metadata.DataProcessors.Find("ImportCurrenciesRates");
	If MetadataObject = Undefined Then
		Return;
	EndIf;

	ModuleToDoListServer = Common.CommonModule("ToDoListServer");
	If Common.DataSeparationEnabled() // Automatic update in SaaS mode.
		Or CommonCached.IsStandaloneWorkplace()
		Or Not AccessRight("Update", Metadata.InformationRegisters.ExchangeRate)
		Or ModuleToDoListServer.UserTaskDisabled("CurrencyClassifier") Then
		Return;
	EndIf;
	
	RatesUpToDate = RatesUpToDate();
	
	// This procedure is only called when To-do list subsystem is available. Therefore, the subsystem 
	// availability check is redundant.
	Sections = ModuleToDoListServer.SectionsForObject(MetadataObject.FullName());
	
	For Each Section In Sections Do
		
		CurrencyID = "CurrencyClassifier" + StrReplace(Section.FullName(), ".", "");
		UserTask = ToDoList.Add();
		UserTask.ID  = CurrencyID;
		UserTask.HasUserTasks       = Not RatesUpToDate;
		UserTask.Presentation  = NStr("en = 'Update exchange rate'; ru = 'Обновить курс валюты'; pl = 'Zaktualizuj kursy walut';es_ES = 'Actualizar el tipo de cambio';es_CO = 'Actualizar el tipo de cambio';tr = 'Döviz kurunu güncelle';it = 'Aggiornare tasso di cambio';de = 'Wechselkurs aktualisieren'");
		UserTask.Important         = True;
		UserTask.Form          = "DataProcessor.ImportCurrenciesRates.Form";
		UserTask.FormParameters = New Structure("OpeningFromList", True);
		UserTask.Owner       = Section;
		
	EndDo;
	
EndProcedure

// See ImportDataFromFileOverridable.OnDefineCatalogsForDataImport. 
Procedure OnDefineCatalogsForDataImport(CatalogsToImport) Export
	
	// Import to the currency classifier is denied.
	TableRow = CatalogsToImport.Find(Metadata.Catalogs.Currencies.FullName(), "FullName");
	If TableRow <> Undefined Then 
		CatalogsToImport.Delete(TableRow);
	EndIf;
	
EndProcedure

// See BatchObjectModificationOverridable.OnDetermineObjectsWithEditableAttributes. 
Procedure OnDefineObjectsWithEditableAttributes(Objects) Export
	Objects.Insert(Metadata.Catalogs.Currencies.FullName(), "AttributesToEditInBatchProcessing");
EndProcedure

// See ScheduledJobsOverridable.OnDefineScheduledJobSettings. 
Procedure OnDefineScheduledJobSettings(Dependencies) Export
	If Metadata.DataProcessors.Find("ImportCurrenciesRates") <> Undefined Then
		DataProcessors["ImportCurrenciesRates"].OnDefineScheduledJobSettings(Dependencies);
	EndIf;
EndProcedure

// See UsersOverridable.OnDefineRolesAssignment. 
Procedure OnDefineRoleAssignment(RolesAssignment) Export
	
	// BothForUsersAndExternalUsers.
	RolesAssignment.BothForUsersAndExternalUsers.Add(
		Metadata.Roles.ReadCurrencyRates.Name);
	
EndProcedure

// See CommonOverridable.OnAddClientParametersOnStart. 
Procedure OnAddClientParametersOnStart(Parameters) Export
	
	If Common.DataSeparationEnabled() Or CommonCached.IsStandaloneWorkplace() Then
		RatesUpdatedByEmployeesResponsible = False; // Automatic update in SaaS mode.
	ElsIf NOT AccessRight("Update", Metadata.InformationRegisters.ExchangeRate) Then
		RatesUpdatedByEmployeesResponsible = False; // The user cannot update currency rates.
	Else
		RatesUpdatedByEmployeesResponsible = RatesImportedFromInternet(); // There are currencies whose rates can be imported.
	EndIf;
	
	EnableNotifications = Not Common.SubsystemExists("StandardSubsystems.ToDoList");
	CurrenciesExchangeRatesOverridable.OnDetermineWhetherCurrencyRateUpdateWarningRequired(EnableNotifications);
	
	Parameters.Insert("Currencies", New FixedStructure("RatesUpdatedByEmployeesResponsible", (RatesUpdatedByEmployeesResponsible AND EnableNotifications)));
	
EndProcedure

// See CommonOverridable.OnAddRefsSearchExceptions. 
Procedure OnAddReferenceSearchExceptions(Array) Export
	
	Array.Add(Metadata.InformationRegisters.ExchangeRate.FullName());
	
EndProcedure

// See SafeModeManagerOverridable.OnFillPermissionsToAccessExternalResources. 
Procedure OnFillPermissionsToAccessExternalResources(PermissionRequests) Export
	
	If Common.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	ModuleSafeModeManager = Common.CommonModule("SafeModeManager");
	PermissionRequests.Add(
		ModuleSafeModeManager.RequestToUseExternalResources(Permissions()));
	
EndProcedure

// See InfobaseUpdateSSL.OnAddUpdateHandlers. 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version = "2.1.4.4";
	Handler.Procedure = "CurrencyRateOperations.UpdateCurrencyInformation937";
	Handler.ExecutionMode = "Exclusive";
	
	Handler = Handlers.Add();
	Handler.Version = "2.2.3.10";
	Handler.Procedure = "CurrencyRateOperations.FillCurrencyRateSettingMethod";
	Handler.ExecutionMode = "Exclusive";
	
	If Metadata.DataProcessors.Find("ImportCurrenciesRates") <> Undefined Then
		DataProcessors["ImportCurrenciesRates"].OnAddUpdateHandlers(Handlers);
	EndIf;
	
EndProcedure

Procedure ConvertCurrencyLinks() Export
	If Metadata.DataProcessors.Find("ImportCurrenciesRates") <> Undefined Then
		DataProcessors["ImportCurrenciesRates"].ConvertCurrencyLinks();
	EndIf;
EndProcedure

// See OnlineSupportOverridable.OnSaveOnlineSupportUserAuthenticationData. 
Procedure OnSaveOnlineSupportUserAuthenticationData(UserData) Export
	
	If Metadata.DataProcessors.Find("ImportCurrenciesRates") <> Undefined Then
		DataProcessors["ImportCurrenciesRates"].OnSaveOnlineSupportUserAuthenticationData(UserData);
	EndIf;
	
EndProcedure

// See OnlineSupportOverridable.OnDeleteOnlineSupportUserAuthenticationData. 
Procedure OnDeleteOnlineSupportUserAuthenticationData() Export
	
	If Metadata.DataProcessors.Find("ImportCurrenciesRates") <> Undefined Then
		DataProcessors["ImportCurrenciesRates"].OnDeleteOnlineSupportUserAuthenticationData();
	EndIf;
	
EndProcedure

// Checks whether the exchange rate and multiplier as of January 1, 1980, are available.
// If they are not available, sets them both to one.
//
// Parameters:
//  Currency - a reference to a Currencies catalog item.
//
Procedure CheckCurrencyRateAvailabilityFor01_01_1980(Ref) Export
	
	RateDate = Date("19800101");
	
	If TypeOf(Ref) = Type("CatalogRef.Currencies") Then
		
		Currency = Ref;
		CompanySelection = Catalogs.Companies.Select();
		While CompanySelection.Next() Do
			
			RateStructure = GetCurrencyRate(RateDate, Currency, CompanySelection.Ref);
			
			If (RateStructure.Rate = 0) Or (RateStructure.Repetition = 0) Then
				RecordSet = InformationRegisters.ExchangeRate.CreateRecordSet();
				RecordSet.Filter.Currency.Set(Currency);
				RecordSet.Filter.Company.Set(CompanySelection.Ref);
				RecordSet.Filter.Period.Set(RateDate);
				Record = RecordSet.Add();
				Record.Currency = Currency;
				Record.Company = CompanySelection.Ref;
				Record.Period = RateDate;
				Record.Rate = 1;
				Record.Repetition = 1;
				RecordSet.AdditionalProperties.Insert("SkipPeriodClosingCheck");
				RecordSet.Write();
			EndIf;
		EndDo;
		
	Elsif TypeOf(Ref) = Type("CatalogRef.Companies") Then
		
		Company = Ref;
		CurrencySelection = Catalogs.Currencies.Select();
		While CurrencySelection.Next() Do
			
			RateStructure = GetCurrencyRate(RateDate, CurrencySelection.Ref, Company);
			
			If (RateStructure.Rate = 0) Or (RateStructure.Repetition = 0) Then
				RecordSet = InformationRegisters.ExchangeRate.CreateRecordSet();
				RecordSet.Filter.Currency.Set(CurrencySelection.Ref);
				RecordSet.Filter.Company.Set(Company);
				RecordSet.Filter.Period.Set(RateDate);
				Record = RecordSet.Add();
				Record.Currency = CurrencySelection.Ref;
				Record.Company = Company;
				Record.Period = RateDate;
				Record.Rate = 1;
				Record.Repetition = 1;
				RecordSet.AdditionalProperties.Insert("SkipPeriodClosingCheck");
				RecordSet.Write();
			EndIf;
		EndDo;
		
	EndIf;

EndProcedure

#EndRegion

#Region Private

Procedure ImportActualRate(ImportParameters = Undefined, ResultAddress = Undefined) Export
	
	If Metadata.DataProcessors.Find("ImportCurrenciesRates") <> Undefined Then
		DataProcessors["ImportCurrenciesRates"].ImportActualRate(ImportParameters, ResultAddress);
	EndIf;
	
EndProcedure

// Returns a list of permissions to import currency rates from the 1C website.
//
// Returns:
//  Array.
//
Function Permissions()
	
	Permissions = New Array;
	DataProcessorName = "ImportCurrenciesRates";
	If Metadata.DataProcessors.Find(DataProcessorName) <> Undefined Then
		DataProcessors[DataProcessorName].AddPermissions(Permissions);
	EndIf;
	
	Return Permissions;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Internal export procedures and functions.

// Returns an array of currencies whose rates are imported from the 1C website.
//
Function CurrenciesToImport() Export
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	Currencies.Ref AS Ref
	|FROM
	|	Catalog.Currencies AS Currencies
	|WHERE
	|	Currencies.RateSource = VALUE(Enum.RateSources.DownloadFromInternet)
	|	AND NOT Currencies.DeletionMark
	|
	|ORDER BY
	|	Currencies.DescriptionFull";

	Return Query.Execute().Unload().UnloadColumn("Ref");
	
EndFunction

// Returns a currency rate by a currency reference.
// Returns data as a structure.
//
// Parameters:
// SelectedCurrency - Catalog.Currencies / Reference - reference to the currency to find out the 
//                  rate for.
//
// Returns:
// RateData   - structure describing the most recent rate record.
//                 
//
Function FillCurrencyRateData(SelectedCurrency, Company = Undefined) Export
	
	RateData = New Structure("RateDate, Rate, Repetition");
	
	Query = New Query;
	
	Query.Text = "SELECT RegRates.Period, RegRates.Rate, RegRates.Repetition
	              | FROM InformationRegister.ExchangeRate.SliceLast(&ImportPeriodEnd, Currency = &SelectedCurrency AND Company = &Company) AS RegRates";
	Query.SetParameter("SelectedCurrency", 	SelectedCurrency);
	Query.SetParameter("Company", 			?(ValueIsFilled(Company), Company, DriveReUse.GetUserDefaultCompany()));
	Query.SetParameter("ImportPeriodEnd", 	CurrentSessionDate());
	
	SelectionRate = Query.Execute().Select();
	SelectionRate.Next();
	
	RateData.RateDate = SelectionRate.Period;
	RateData.Rate      = SelectionRate.Rate;
	RateData.Repetition = SelectionRate.Repetition;
	
	Return RateData;
	
EndFunction

// Returns a value table containing currencies depending on the one set as the parameter.
// 
// Returns
// ValueTable column "Reference" - CatalogRef.Currencies column "Markup" - number.
// 
// 
//
Function DependentCurrenciesList(BaseCurrency, AdditionalProperties = Undefined) Export
	
	Cached = (TypeOf(AdditionalProperties) = Type("Structure"));
	
	If Cached Then
		
		DependentCurrencies = AdditionalProperties.DependentCurrencies.Get(BaseCurrency);
		
		If TypeOf(DependentCurrencies) = Type("ValueTable") Then
			Return DependentCurrencies;
		EndIf;
		
	EndIf;
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	CurrencyCatalog.Ref,
	|	CurrencyCatalog.Markup,
	|	CurrencyCatalog.RateSource,
	|	CurrencyCatalog.RateCalculationFormula
	|FROM
	|	Catalog.Currencies AS CurrencyCatalog
	|WHERE
	|	CurrencyCatalog.MainCurrency = &BaseCurrency
	|
	|UNION ALL
	|
	|SELECT
	|	CurrencyCatalog.Ref,
	|	CurrencyCatalog.Markup,
	|	CurrencyCatalog.RateSource,
	|	CurrencyCatalog.RateCalculationFormula
	|FROM
	|	Catalog.Currencies AS CurrencyCatalog
	|WHERE
	|	CurrencyCatalog.RateCalculationFormula LIKE &AlphabeticCode";
	
	Query.SetParameter("BaseCurrency", BaseCurrency);
	Query.SetParameter("AlphabeticCode", "%" + Common.ObjectAttributeValue(BaseCurrency, "Description") + "%");
	
	DependentCurrencies = Query.Execute().Unload();
	
	If Cached Then
		
		AdditionalProperties.DependentCurrencies.Insert(BaseCurrency, DependentCurrencies);
		
	EndIf;
	
	Return DependentCurrencies;
	
EndFunction

Procedure UpdateCurrencyRate(Parameters, ResultAddress) Export
	
	SubordinateCurrency    = Parameters.SubordinateCurrency;
	RateSource = Parameters.RateSource;
	
	If RateSource = Enums.RateSources.MarkupForOtherCurrencyRate Then
		Query = New Query;
		Query.Text = 
		"SELECT
		|	ExchangeRate.Period,
		|	ExchangeRate.Currency,
		|	ExchangeRate.Company,
		|	ExchangeRate.Rate,
		|	ExchangeRate.Repetition
		|FROM
		|	InformationRegister.ExchangeRate AS ExchangeRate
		|WHERE
		|	ExchangeRate.Currency = &SourceCurrency";
		Query.SetParameter("SourceCurrency", SubordinateCurrency.MainCurrency);
		
		Selection = Query.Execute().Select();
		
		RecordSet = InformationRegisters.ExchangeRate.CreateRecordSet();
		RecordSet.Filter.Currency.Set(SubordinateCurrency.Ref);
		
		IncreaseBy = SubordinateCurrency.Markup;
		
		While Selection.Next() Do
			
			NewRateSetRecord = RecordSet.Add();
			NewRateSetRecord.Currency   = SubordinateCurrency.Ref;
			NewRateSetRecord.Company 	= Selection.Company;
			NewRateSetRecord.Repetition = Selection.Repetition;
			NewRateSetRecord.Rate      	= Selection.Rate + Selection.Rate * IncreaseBy / 100;
			NewRateSetRecord.Period    	= Selection.Period;
			
		EndDo;
		
		RecordSet.AdditionalProperties.Insert("DisableDependentCurrenciesControl");
		If SubordinateCurrency.AdditionalProperties.Property("IsNew") Then
			RecordSet.AdditionalProperties.Insert("SkipPeriodClosingCheck");
		EndIf;

		RecordSet.Write();
		
	ElsIf RateSource = Enums.RateSources.CalculationByFormula Then
		
		// Getting the base currencies for SubordinateCurrency.
		Query = New Query;
		Query.Text = 
		"SELECT
		|	Currencies.Ref AS Ref
		|FROM
		|	Catalog.Currencies AS Currencies
		|WHERE
		|	&RateCalculationFormula LIKE ""%"" + Currencies.Description + ""%""";
		
		Query.SetParameter("RateCalculationFormula", SubordinateCurrency.RateCalculationFormula);
		BaseCurrencies = Query.Execute().Unload();
		
		If BaseCurrencies.Count() = 0 Then
			ErrorText = NStr("ru = 'В формуле должна быть использована хотя бы одна основная валюта.'; en = 'The formula must include at least one base currency.'; pl = 'We wzorze należy zastosować co najmniej jedną walutę główną.';es_ES = 'Como mínimo una moneda principal tiene que utilizarse en la fórmula.';es_CO = 'Como mínimo una moneda principal tiene que utilizarse en la fórmula.';tr = 'Formülde en az bir ana para birimi kullanılacaktır.';it = 'La formula deve includere almeno una valuta di base.';de = 'In der Formel muss mindestens eine Hauptwährung verwendet werden.'");
			CommonClientServer.MessageToUser(ErrorText, , "Object.RateCalculationFormula");
			Raise ErrorText;
		EndIf;
		
		UpdatedPeriods = New Map; // Cache for a single rate conversion over the same period.
		// Rewrite the rates for base currencies to update the SubordinateCurrency rate.
		For each BaseCurrencyRecord In BaseCurrencies Do
			RecordSet = InformationRegisters.ExchangeRate.CreateRecordSet();
			RecordSet.Filter.Currency.Set(BaseCurrencyRecord.Ref);
			RecordSet.Read();
			RecordSet.AdditionalProperties.Insert("UpdateSubordinateCurrencyRate", SubordinateCurrency.Ref);
			RecordSet.AdditionalProperties.Insert("UpdatedPeriods", UpdatedPeriods);
			
			If SubordinateCurrency.AdditionalProperties.Property("IsNew") Then
				RecordSet.AdditionalProperties.Insert("SkipPeriodClosingCheck");
			EndIf;
			
			RecordSet.Write();
		EndDo
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Updating an infobase.

// Updates currency info after the "Amendment 33/2012 ARCC All-Russian Classifier of Currencies.
// OK (MK (ISO 4217) 003-97) 014-2000" document passed and implemented by the decree of Russian Federal Agency for Technical Regulating and Metrology No.1883-st from 12/12/2012).
//
Procedure UpdateCurrencyInformation937() Export
	Currency = Catalogs.Currencies.FindByCode("937");
	If Not Currency.IsEmpty() Then
		Currency = Currency.GetObject();
		Currency.Description = "VEF";
		Currency.DescriptionFull = NStr("ru = 'Боливар'; en = 'Bolivar'; pl = 'Bolivar';es_ES = 'Bolívar';es_CO = 'Bolívar';tr = 'Bolivar';it = 'Bolivar';de = 'Bolivar'");
		InfobaseUpdate.WriteData(Currency);
	EndIf;
EndProcedure

// Fills in the RateSource attribute for all items of the Currencies catalog.
Procedure FillCurrencyRateSettingMethod() Export
	Selection = Catalogs.Currencies.Select();
	While Selection.Next() Do
		Currency = Selection.Ref.GetObject();
		If Currency.ImportingFromInternet Then
			Currency.RateSource = Enums.RateSources.DownloadFromInternet;
		ElsIf Not Currency.MainCurrency.IsEmpty() Then
			Currency.RateSource = Enums.RateSources.MarkupForOtherCurrencyRate;
		Else
			Currency.RateSource = Enums.RateSources.ManualInput;
		EndIf;
		InfobaseUpdate.WriteData(Currency);
	EndDo;
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Currency rates update.

// Checks whether all currency rates are up-to-date.
//
Function RatesUpToDate() Export
	QueryText =
	"SELECT ALLOWED
	|	Currencies.Ref AS Currency,
	|	Companies.Ref AS Company
	|INTO ttCurrencies
	|FROM
	|	Catalog.Companies AS Companies
	|		INNER JOIN Catalog.Currencies AS Currencies
	|		ON (TRUE)
	|WHERE
	|	Currencies.RateSource = VALUE(Enum.RateSources.DownloadFromInternet)
	|	AND Currencies.DeletionMark = FALSE
	|	AND Companies.DeletionMark = FALSE
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	1 AS Field1
	|FROM
	|	ttCurrencies AS Currencies
	|		LEFT JOIN InformationRegister.ExchangeRate AS ExchangeRate
	|		ON Currencies.Currency = ExchangeRate.Currency
	|			AND Currencies.Company = ExchangeRate.Company
	|			AND (ExchangeRate.Period = &CurrentDate)
	|WHERE
	|	ExchangeRate.Currency IS NULL";
	
	Query = New Query;
	Query.SetParameter("CurrentDate", BegOfDay(CurrentSessionDate()));
	Query.Text = QueryText;
	
	Return Query.Execute().IsEmpty();
EndFunction

// Determines whether there is at least one currency whose rate can be imported from the internet.
//
Function RatesImportedFromInternet()
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	1 AS Field1
	|FROM
	|	Catalog.Currencies AS Currencies
	|WHERE
	|	Currencies.RateSource = VALUE(Enum.RateSources.DownloadFromInternet)
	|	AND Currencies.DeletionMark = FALSE";
	Return NOT Query.Execute().IsEmpty();
EndFunction

#EndRegion
