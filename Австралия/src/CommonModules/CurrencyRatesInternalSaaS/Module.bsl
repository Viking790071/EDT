
#Region Internal

// Import a complete rate list of all time.
//
Procedure ImportCurrencyRates() Export
	
	Descriptors = SuppliedData.SuppliedDataDescriptorsFromManager("ExchangeRate");
	
	If Descriptors.Descriptor.Count() < 1 Then
		Raise(NStr("ru = 'В менеджере сервиса отсутствуют данные типа ""CurrencyRates""'; en = 'The service manager has no CurrencyRates data type'; pl = 'Nie ma danych o typie CurrencyRates w menedżerze usług';es_ES = 'No hay datos sobre el tipo de ExchangeRates en el gestor de servicios';es_CO = 'No hay datos sobre el tipo de ExchangeRates en el gestor de servicios';tr = 'Servis yöneticisinde CurrencyRates türüne ait veri mevcut değil';it = 'Il gestore del servizio non ha tipi di dato cambio valuta';de = 'Im Service Manager sind keine Daten der Art der Wechselkurse enthalten'"));
	EndIf;
	
	Rates = SuppliedData.SuppliedDataReferencesFromCache("OneCurrencyRates");
	For each Rate In Rates Do
		SuppliedData.DeleteSuppliedDataFromCache(Rate);
	EndDo; 
	
	SuppliedData.ImportAndProcessData(Descriptors.Descriptor[0]);
	
EndProcedure

// Is called when the currency rate setting method is changed.
//
// Currency - CatalogRef.Currencies
//
Procedure ScheduleCopyCurrencyRates(Val Currency) Export
	
	If Currency.RateSource <> Enums.RateSources.DownloadFromInternet Then
		Return;
	EndIf;
	
	MethodParameters = New Array;
	MethodParameters.Add(Currency.Code);

	JobParameters = New Structure;
	JobParameters.Insert("MethodName", "CurrencyRatesInternalSaaS.CopyCurrencyRates");
	JobParameters.Insert("Parameters", MethodParameters);
	
	SetPrivilegedMode(True);
	JobQueue.AddJob(JobParameters);

EndProcedure

// Is called on update from previous versions where the ImportFromInternet check box is not selected.
//
Procedure ConvertCurrencyLinks() Export
	CurrencyRateOperations.ConvertCurrencyLinks();
EndProcedure

// Cal this method after importing data to an area and after changing the currency rate setting method.
// Copies one currency rates for all dates from a separated xml file to the shared register.
// 
// 
// Parameters:
//  CurrencyCode - String
//
Procedure CopyCurrencyRates(Val CurrencyCode) Export
	
	CurrencyRef = Catalogs.Currencies.FindByCode(CurrencyCode);
	If CurrencyRef.IsEmpty() Then
		Return;
	EndIf;
	
	RateDataType = XDTOFactory.Type("http://www.1c.ru/SaaS/SuppliedData/CurrencyRates", "Rate");
	
	Filter = New Array;
	Filter.Add(New Structure("Code, Value", "Currency", CurrencyCode));
	Rates = SuppliedData.SuppliedDataReferencesFromCache("OneCurrencyRates", Filter);
	If Rates.Count() = 0 Then
		Return;
	EndIf;
	
	PathToFile = GetTempFileName();
	SuppliedData.SuppliedDataFromCache(Rates[0]).Write(PathToFile);
	RateTable = ReadRateTable(PathToFile, True);
	DeleteFiles(PathToFile);
	
	RateTable.Columns.Date.Name = "Period";
	RateTable.Columns.Add("Currency");
	RateTable.FillValues(CurrencyRef, "Currency");
	
	RecordSet = InformationRegisters.ExchangeRate.CreateRecordSet();
	RecordSet.Filter.Currency.Set(CurrencyRef);
	RecordSet.Load(RateTable);
	RecordSet.DataExchange.Load = True;
	
	RecordSet.Write();
	
	// Checks whether the exchange rate and multiplier as of January 1, 1980, are available.
	CurrencyRateOperations.CheckCurrencyRateAvailabilityFor01_01_1980(CurrencyRef);

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// The procedure is called when a new data notification is received.
// In the procedure body, check whether the application requires this data. If it does, select the 
// Import check box.
// 
// Parameters:
//   Descriptor - XDTODataObject - a descriptor.
//   Import - Boolean - True if import, False otherwise.
//
Procedure NewDataAvailable(Val Descriptor, Import) Export
	
	// When getting CurrencyRatesForDay the data from the file are appended to all the stored rates and 
	// are recorded in all data fields for currencies mentioned in the fields. Is written only for the 
	// current date.
	//
	If Descriptor.DataType = "CurrencyRatesForDay" Then
		Import = True;
	// CurrencyRates return in 3 cases. When you connect the infobase to MS during infobase update 
	// period, when after the update the infobase requires currency that was not needed during the 
	// manual import of the rate file to MS.
	// 
	// In all cases it is necessary to clear the cache and to overwrite all rates in all data areas.
	ElsIf Descriptor.DataType = "ExchangeRate" Then
		Import = True;
	EndIf;
	
EndProcedure

// The procedure is called after calling NewDataAvailable, it parses the data.
//
// Parameters:
//   Descriptor - XDTODataObject - a descriptor.
//   PathToFile - String – extracted file full name. The file is automatically deleted once the 
//                  procedure is executed. If the file is not specified in Service Manager, the 
//                  parameter value is Undefined.
//
Procedure ProcessNewData(Val Descriptor, Val PathToFile) Export
	
	If Descriptor.DataType = "CurrencyRatesForDay" Then
		HandleSuppliedRatesPerDay(Descriptor, PathToFile);
	ElsIf Descriptor.DataType = "ExchangeRate" Then
		HandleSuppliedRates(Descriptor, PathToFile);
	EndIf;
	
EndProcedure

// The procedure is called if data processing is canceled due to an error.
//
// Parameters:
//   Descriptor - XDTODataObject - a descriptor.
//
Procedure DataProcessingCanceled(Val Descriptor) Export 
	
	SuppliedData.AreaProcessed(Descriptor.FileGUID, "CurrencyRatesForDay", Undefined);
	
EndProcedure	

// See InfobaseUpdateSSL.OnAddUpdateHandlers. 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version = "2.1.1.7";
	Handler.Procedure = "CurrencyRatesInternalSaaS.ConvertCurrencyLinks";
	
EndProcedure

// See JobQueueOverridable.OnDefineHandlerAliases. 
Procedure OnDefineHandlerAliases(NameAndAliasMap) Export
	
	NameAndAliasMap.Insert("CurrencyRatesInternalSaaS.CopyCurrencyRates");
	
EndProcedure

// See SuppliedDataOverridable.GetSuppliedDataHandlers. 
Procedure OnDefineSuppliedDataHandlers(Handlers) Export
	
	RegisterSuppliedDataHandlers(Handlers);
	
EndProcedure

// See ExportImportDataOverridable.AfterDataImport. 
Procedure AfterImportData(Container) Export
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.SuppliedData") Then
		// Creating links between separated and shared currencies, copying rates.
		UpdateCurrencyRates();
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

// It is called after the data import to the area.
// Updates currency rates from the supplied data.
//
Procedure UpdateCurrencyRates()
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	Currencies.Code
	|FROM
	|	Catalog.Currencies AS Currencies
	|WHERE
	|	Currencies.RateSource = VALUE(Enum.RateSources.DownloadFromInternet)";
	Selection = Query.Execute().Select();
	
	// Copy rates. It needs to be done synchronously, for after the call UpdateCurrencyRates the 
	// infobase is updated, there is an attempt at locking the infobase. Copy rates - a long process 
	// that can begin at an arbitrary moment in an asynchronous transfer mode to prevent the infobase 
	// from locking.
	While Selection.Next() Do
		CopyCurrencyRates(Selection.Code);
	EndDo;
	
EndProcedure

// Registers supplied data handlers for the day and for all time.
//
// Parameters:
//     Handlers - ValueTable - table for adding handlers. Contains the following columns.
//       * DataKind - String - code of the data kind processed by the handler.
//       * HandlerCode - Sting - used for recovery after a data processing error.
//       * Handler - CommonModule - module contains the following export procedures:
//                                          NewDataAvailable(Descriptor, Import) Export
//                                          ProcessNewData(Descriptor, PathToFile) Export
//                                          DataProcessingCanceled(Descriptor) Export
//
Procedure RegisterSuppliedDataHandlers(Val Handlers)
	
	Handler = Handlers.Add();
	Handler.DataKind = "CurrencyRatesForDay";
	Handler.HandlerCode = "CurrencyRatesForDay";
	Handler.Handler = CurrencyRatesInternalSaaS;
	
	Handler = Handlers.Add();
	Handler.DataKind = "ExchangeRate";
	Handler.HandlerCode = "ExchangeRate";
	Handler.Handler = CurrencyRatesInternalSaaS;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Rate file serialization/deserialization.

// Writes files in the supplied data format.
//
// Parameters:
//  RateTable - ValueTable with the following columns Code, Date, UnitConversionFactor, Rate.
//  File - String or TextWriter.
//
Procedure SaveRateTable(Val RateTable, Val File)
	
	If TypeOf(File) = Type("String") Then
		TextWriter = New TextWriter(File);
	Else
		TextWriter = File;
	EndIf;
	
	For each TableRow In RateTable Do
			
		XMLRate = StrReplace(
		StrReplace(
		StrReplace(
			StrReplace("<Rate Code=""%1"" Date=""%2"" Factor=""%3"" Rate=""%4""/>", 
			"%1", TableRow.Code),
			"%2", Left(XDTOSerializer.XMLString(TableRow.Date), 10)),
			"%3", XDTOSerializer.XMLString(TableRow.Repetition)),
			"%4", XDTOSerializer.XMLString(TableRow.Rate));
		
		TextWriter.WriteLine(XMLRate);
	EndDo; 
	
	If TypeOf(File) = Type("String") Then
		TextWriter.Close();
	EndIf;
	
EndProcedure

// Reads files in the supplied data format.
//
// Parameters:
//  PathToFile - String, file name.
//  SearchForDuplicates - Boolean, collapses entries with the same date.
//
// Returns
//	ValueTable with the following columns Code, Date, UnitConversionFactor, Rate.
//
Function ReadRateTable(Val PathToFile, Val SearchForDuplicates = False)
	
	RateDataType = XDTOFactory.Type("http://www.1c.ru/SaaS/SuppliedData/CurrencyRates", "Rate");
	RateTable = New ValueTable();
	RateTable.Columns.Add("Code", New TypeDescription("String", , New StringQualifiers(200)));
	RateTable.Columns.Add("Date", New TypeDescription("Date", , , New DateQualifiers(DateFractions.Date)));
	RateTable.Columns.Add("Repetition", New TypeDescription("Number", New NumberQualifiers(9, 0)));
	RateTable.Columns.Add("Rate", New TypeDescription("Number", New NumberQualifiers(20, 4)));
	
	Read = New TextReader(PathToFile);
	CurrentRow = Read.ReadLine();
	While CurrentRow <> Undefined Do
		
		XMLReader = New XMLReader();
		XMLReader.SetString(CurrentRow);
		Rate = XDTOFactory.ReadXML(XMLReader, RateDataType);
		
		If SearchForDuplicates Then
			For each Duplicate In RateTable.FindRows(New Structure("Date", Rate.Date)) Do
				RateTable.Delete(Duplicate);
			EndDo;
		EndIf;
		
		WriteCurrencyRate = RateTable.Add();
		WriteCurrencyRate.Code    = Rate.Code;
		WriteCurrencyRate.Date    = Rate.Date;
		WriteCurrencyRate.Repetition = Rate.Factor;
		WriteCurrencyRate.Rate      = Rate.Rate;

		CurrentRow = Read.ReadLine();
	EndDo;
	Read.Close();
	
	RateTable.Indexes.Add("Code");
	Return RateTable;
		
EndFunction

// Is called when CurrencyRates data type is received.
//
// Parameters:
//   Descriptor - XDTODataObject Descriptor.
//   PathToFile - string. Extracted file full name.
//
Procedure HandleSuppliedRates(Val Descriptor, Val PathToFile)
	
	RateTable = ReadRateTable(PathToFile);
	
	// Split the files by currency and write them to the database.
	CodeTable = RateTable.Copy( , "Code");
	CodeTable.GroupBy("Code");
	For each CodeString In CodeTable Do
		
		TempFileName = GetTempFileName();
		SaveRateTable(RateTable.FindRows(New Structure("Code", CodeString.Code)), TempFileName);
		
		CacheDescriptor = New Structure;
		CacheDescriptor.Insert("DataKind", "OneCurrencyRates");
		CacheDescriptor.Insert("AddedOn", CurrentUniversalDate());
		CacheDescriptor.Insert("FileID", New UUID);
		CacheDescriptor.Insert("Characteristics", New Array);
		
		CacheDescriptor.Characteristics.Add(New Structure("Code, Value, KeyStructure", "Currency", CodeString.Code, True));
		
		SuppliedData.SaveSuppliedDataInCache(CacheDescriptor, TempFileName);
		DeleteFiles(TempFileName);
		
	EndDo;
	
	AreasForUpdate = SuppliedData.AreasRequireProcessing(
		Descriptor.FileGUID, "ExchangeRate");
	
	DistributeRatesByDataAreas(Undefined, RateTable, AreasForUpdate, 
		Descriptor.FileGUID, "ExchangeRate");

EndProcedure

// Is called after getting new CurrencyRatesForDay data type.
//
// Parameters:
//   Descriptor - XDTODataObject Descriptor.
//   PathToFile - string. Extracted file full name.
//
Procedure HandleSuppliedRatesPerDay(Val Descriptor, Val PathToFile)
		
	RateTable = ReadRateTable(PathToFile);
	
	RatesDate = "";
	For each Characteristic In Descriptor.Properties.Property Do
		If Characteristic.Code = "Date" Then
			RatesDate = Date(Characteristic.Value); 		
		EndIf;
	EndDo; 
	
	If RatesDate = "" Then
		Raise NStr("ru = 'Данные вида ""CurrencyRatesForDay"" не содержат характеристики ""Дата"". Обновление курсов невозможно.'; en = 'Data of CurrencyRatesForDay kind does not contain Data characteristics. Cannot update the rates.'; pl = 'Dane typu ""CurrencyRatesForDay"" nie zawierają charakterystyki ""Date"". Nie można zaktualizować kursów walut.';es_ES = 'Datos del tipo ""ExchangeRatesForDay"" no contienen las características ""Fecha"". No se puede actualizar las tasas.';es_CO = 'Datos del tipo ""ExchangeRatesForDay"" no contienen las características ""Fecha"". No se puede actualizar las tasas.';tr = '""CurrencyRatesForDay"" türünün verileri ""Data"" özelliklerini içermez. Kurlar güncellenemiyor.';it = 'I dati della tipologia CurrencyRatesForDAy non contengono caratteristiche dati. Impossibile aggiornare i tassi.';de = 'Daten vom Typ ""WechselkurseFürTag"" enthalten nicht die ""Datum""-Eigenschaften. Die Kurse können nicht aktualisiert werden.'"); 
	EndIf;
	
	AreasForUpdate = SuppliedData.AreasRequireProcessing(Descriptor.FileGUID, "CurrencyRatesForDay", True);
	
	CommonRateIndex = AreasForUpdate.Find(-1);
	If CommonRateIndex <> Undefined Then
		
		RateCache = SuppliedData.SuppliedDataFromCacheDescriptors("OneCurrencyRates", , False);
		If RateCache.Count() > 0 Then
			For each RateString In RateTable Do
				
				CurrentCache = Undefined;
				For	each CacheDescriptor In RateCache Do
					If CacheDescriptor.Characteristics.Count() > 0 
						AND CacheDescriptor.Characteristics[0].Code = "Currency"
						AND CacheDescriptor.Characteristics[0].Value = RateString.Code Then
						CurrentCache = CacheDescriptor;
						Break;
					EndIf;
				EndDo;
				
				TempFileName = GetTempFileName();
				If CurrentCache <> Undefined Then
					Data = SuppliedData.SuppliedDataFromCache(CurrentCache.FileID);
					Data.Write(TempFileName);
				Else
					CurrentCache = New Structure;
					CurrentCache.Insert("DataKind", "OneCurrencyRates");
					CurrentCache.Insert("AddedOn", CurrentUniversalDate());
					CurrentCache.Insert("FileID", New UUID);
					CurrentCache.Insert("Characteristics", New Array);
					
					CurrentCache.Characteristics.Add(New Structure("Code, Value, KeyStructure", "Currency", RateString.Code, True));
				EndIf;
				
				TextWriter = New TextWriter(TempFileName, TextEncoding.UTF8, 
				Chars.LF, True);
				
				TableToWrite = New Array;
				TableToWrite.Add(RateString);
				SaveRateTable(TableToWrite, TextWriter);
				TextWriter.Close();
				
				SuppliedData.SaveSuppliedDataInCache(CurrentCache, TempFileName);
				DeleteFiles(TempFileName);
			EndDo;
			
		EndIf;
		
		AreasForUpdate.Delete(CommonRateIndex);
	EndIf;
	
	DistributeRatesByDataAreas(RatesDate, RateTable, AreasForUpdate, 
		Descriptor.FileGUID, "CurrencyRatesForDay");

EndProcedure

// Copies rates in all data areas
//
// Parameters:
//  RatesDate - Date or Undefined. The rates are added for the specified date or for all time.
//  RateTable - ValueTable containing rates.
//  AreasForUpdate - array of area codes.
//  FileID - file UUID of processed rates.
//  HandlerCode - String, handler code.
//
Procedure DistributeRatesByDataAreas(Val RatesDate, Val RateTable, Val AreasForUpdate, Val FileID, Val HandlerCode)
	
	AreaCurrencies = New Map();
	
	CommonQuery = New Query();
	CommonQuery.TempTablesManager = New TempTablesManager;
	CommonQuery.SetParameter("SuppliedRates", RateTable);
	CommonQuery.SetParameter("OneDayOnly", RatesDate <> Undefined);
	CommonQuery.SetParameter("RatesDate", RatesDate);
	CommonQuery.SetParameter("RateDeliveryStart", Date("19800101"));
	
	For each DataArea In AreasForUpdate Do
		
		Try
			SaaS.SetSessionSeparation(True, DataArea);
		Except
			SaaS.SetSessionSeparation(False);
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Не удалось установить разделение сеанса %1 по причине:
				|%2'; 
				|en = 'Cannot set the session separation %1 due to:
				|%2'; 
				|pl = 'Nie udało się ustawić podział sesji %1 z powodu:
				|%2';
				|es_ES = 'No se ha podido instalar la división de la sesión %1 a causa de:
				|%2';
				|es_CO = 'No se ha podido instalar la división de la sesión %1 a causa de:
				|%2';
				|tr = 'Oturum %1öğesi 
				|%2nedenle kaydedilemedi:';
				|it = 'Impossibile impostare la separazione di sessione %1 a causa di:
				|%2';
				|de = 'Konnte die Trennung der Sitzung %1 nicht herstellen, weil:
				|%2'", CommonClientServer.DefaultLanguageCode()),
				Format(DataArea, "NZ=0; NG=0"),
				DetailErrorDescription(ErrorInfo()));
			
			WriteLogEvent(NStr("ru = 'Поставляемые данные.Распространение курсов валют по областям данных'; en = 'Supplied data.Currency distribution around data areas'; pl = 'Dostarczane dane.Rozpowszechnianie kursów walut według obszarów danych';es_ES = 'Datos suministrados.La extensión de los tipos de cambios por las áreas de datos';es_CO = 'Datos suministrados.La extensión de los tipos de cambios por las áreas de datos';tr = 'Sağlanan veriler. Döviz kurlarının veri alanlarına yayılması';it = 'Dati forniti.Distribuzione valute per aree di dati';de = 'Zu liefernde Daten. Verbreitung der Wechselkurse nach Datenbereichen'", CommonClientServer.DefaultLanguageCode()),
				EventLogLevel.Error,,,
				ErrorText);
				
			Continue;
			
		EndTry;
		
		AreaCurrenciesString = Common.ValueToXMLString(AreaCurrencies);
		
		BeginTransaction();
	
		Try
			
			ProcessTransactionedAreaRates(CommonQuery, AreaCurrencies, RateTable);
			SaaS.SetSessionSeparation(False);
			SuppliedData.AreaProcessed(FileID, HandlerCode, DataArea);
			
			CommitTransaction();
			
		Except
			
			RollbackTransaction();
			
			AreaCurrencies = Common.ValueFromXMLString(AreaCurrenciesString);
			SaaS.SetSessionSeparation(False);
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Не удалось обновить курсы валют в области %1 по причине:
				|%2'; 
				|en = 'Cannot update exchange rates in data area ""%1"". Reason:
				|%2'; 
				|pl = 'Nie udało się aktualizować kursy walut w obszarze %1 z powodu:
				|%2';
				|es_ES = 'No se ha podido actualizar los tipos de cambios en el área %1 a causa de:
				|%2';
				|es_CO = 'No se ha podido actualizar los tipos de cambios en el área %1 a causa de:
				|%2';
				|tr = '""%1"" veri alanındaki döviz kurları güncellenemedi. Nedeni:
				|%2';
				|it = 'Impossibile aggiornare i tassi di cambio nell''area %1per un motivo:
				|%2';
				|de = 'Eine Aktualisierung der Wechselkurse in den Bereichen %1 war aus diesem Grund nicht möglich:
				|%2'", CommonClientServer.DefaultLanguageCode()),
				Format(DataArea, "NZ=0; NG=0"),
				DetailErrorDescription(ErrorInfo()));
			WriteLogEvent(NStr("ru = 'Поставляемые данные.Распространение курсов валют по областям данных'; en = 'Supplied data.Currency distribution around data areas'; pl = 'Dostarczane dane.Rozpowszechnianie kursów walut według obszarów danych';es_ES = 'Datos suministrados.La extensión de los tipos de cambios por las áreas de datos';es_CO = 'Datos suministrados.La extensión de los tipos de cambios por las áreas de datos';tr = 'Sağlanan veriler. Döviz kurlarının veri alanlarına yayılması';it = 'Dati forniti.Distribuzione valute per aree di dati';de = 'Zu liefernde Daten. Verbreitung der Wechselkurse nach Datenbereichen'", CommonClientServer.DefaultLanguageCode()),
				EventLogLevel.Error,,,
				ErrorText);
			
		EndTry;
		
	EndDo;
	
EndProcedure

Function SuppliedCurrencyProperties(AreaCurrencies, CurrencyCode, RateTable, CommonQuery)
	
	CurrencyProperties = AreaCurrencies.Get(CurrencyCode);
	
	If CurrencyProperties <> Undefined Then 
		
		Return CurrencyProperties;
		
	EndIf;
	
	SuppliedRates = RateTable.Copy(New Structure("Code", CurrencyCode));
	
	CurrencyProperties = New Structure("Supplied, SequenceNumber", False, Undefined);
	
	If SuppliedRates.Count() = 0 Then
		
		AreaCurrencies.Insert(CurrencyCode, CurrencyProperties);
		Return CurrencyProperties;
		
	EndIf;
	
	SequenceNumber = Format(CommonQuery.TempTablesManager.Tables.Count() + 1, "NZ=0; NG=0");
	
	QueryText = 
	"SELECT
	|	SuppliedRates.Date AS Date,
	|	SuppliedRates.Repetition AS Repetition,
	|	SuppliedRates.Rate AS Rate
	|INTO CurrencyRatesNNN
	|FROM
	|	&SuppliedRates AS SuppliedRates
	|WHERE
	|	SuppliedRates.Code = &CurrencyCode
	|	AND SuppliedRates.Date > &RateDeliveryStart
	|	AND CASE
	|			WHEN &OneDayOnly
	|				THEN SuppliedRates.Date = &RatesDate
	|			ELSE TRUE
	|		END";
	
	CommonQuery.Text = StrReplace(QueryText, "NNN", SequenceNumber);
	CommonQuery.Execute();
	
	CurrencyProperties.Supplied = True;
	CurrencyProperties.SequenceNumber = SequenceNumber;
	
	AreaCurrencies.Insert(CurrencyCode, CurrencyProperties);
	
	Return CurrencyProperties;
	
EndFunction

Procedure ProcessTransactionedAreaRates(CommonQuery, AreaCurrencies, RateTable)
	
	CurrencyQuery = New Query;
	CurrencyQuery.Text = 
	"SELECT
	|	Currencies.Ref,
	|	Currencies.Code
	|FROM
	|	Catalog.Currencies AS Currencies
	|WHERE
	|	Currencies.RateSource = VALUE(Enum.RateSources.DownloadFromInternet)";
	
	CurrencySelection = CurrencyQuery.Execute().Select();
	
	While CurrencySelection.Next() Do
		
		CommonQuery.SetParameter("Currency", CurrencySelection.Ref);
		CommonQuery.SetParameter("CurrencyCode", CurrencySelection.Code);
		
		CurrencyProperties = SuppliedCurrencyProperties(AreaCurrencies, CurrencySelection.Code, RateTable, CommonQuery);
		
		If NOT CurrencyProperties.Supplied Then
			Continue;
		EndIf;
		
		QueryText = 
		"SELECT
		|	Comparison.Date AS Date,
		|	Comparison.Repetition AS Repetition,
		|	Comparison.Rate AS Rate,
		|	MAX(Comparison.InFile) AS InFile,
		|	MAX(Comparison.InData) AS InData
		|FROM
		|	(SELECT
		|		SuppliedRates.Date AS Date,
		|		SuppliedRates.Repetition AS Repetition,
		|		SuppliedRates.Rate AS Rate,
		|		1 AS InFile,
		|		0 AS InData
		|	FROM
		|		CurrencyRatesNNN AS SuppliedRates
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		ExchangeRate.Period,
		|		ExchangeRate.Repetition,
		|		ExchangeRate.Rate,
		|		0,
		|		1
		|	FROM
		|		InformationRegister.ExchangeRate AS ExchangeRate
		|	WHERE
		|		ExchangeRate.Currency = &Currency
		|		AND ExchangeRate.Period > &RateDeliveryStart
		|		AND CASE
		|				WHEN &OneDayOnly
		|					THEN ExchangeRate.Period = &RatesDate
		|				ELSE TRUE
		|			END) AS Comparison
		|
		|GROUP BY
		|	Comparison.Date,
		|	Comparison.Repetition,
		|	Comparison.Rate
		|
		|HAVING
		|	MAX(Comparison.InFile) <> MAX(Comparison.InData)
		|
		|ORDER BY
		|	Date,
		|	InData";
		
		CommonQuery.Text = StrReplace(QueryText, "NNN", CurrencyProperties.SequenceNumber);
		
		CommonResult = CommonQuery.Execute();
		CommonSelection = CommonResult.Select();
		
		CurDate = Undefined;
		FirstIterationByDate = True;
		
		While CommonSelection.Next() Do
			
			If CurDate <> CommonSelection.Date Then
				FirstIterationByDate = True;
				CurDate = CommonSelection.Date;
			EndIf;
			
			If NOT FirstIterationByDate Then
				Continue;
			EndIf;
			
			FirstIterationByDate = False;
			
			RecordSet = InformationRegisters.ExchangeRate.CreateRecordSet();
			RecordSet.Filter.Currency.Set(CurrencySelection.Ref);
			RecordSet.Filter.Period.Set(CommonSelection.Date);
			If NOT CommonQuery.Parameters.OneDayOnly Then
				// Block the ineffective associated currency update.
				RecordSet.DataExchange.Load = True;
			EndIf;
			
			If CommonSelection.InFile = 1 Then
				
				Record = RecordSet.Add();
				Record.Currency = CurrencySelection.Ref;
				Record.Period = CommonSelection.Date;
				Record.Repetition = CommonSelection.Repetition;
				Record.Rate = CommonSelection.Rate;
				
			EndIf;
			
			// Check change closing date.
			
			Write = True;
			If Common.SubsystemExists("StandardSubsystems.PeriodClosingDates") Then
				ModulePeriodClosingDatesInternal = Common.CommonModule("PeriodClosingDatesInternal");
				If ModulePeriodClosingDatesInternal.PeriodEndClosingChecked(Metadata.InformationRegisters.ExchangeRate) Then
					ModulePeriodClosingDates = Common.CommonModule("PeriodClosingDates");
					Write = Not ModulePeriodClosingDates.DataChangesDenied(RecordSet);
				EndIf;
			EndIf;
			
			If Write Then
				RecordSet.Write();
			Else
				Comment = NStr("ru = 'Загрузка курса валюты %1 на дату %2 отменена из-за нарушения даты запрета изменений.'; en = 'The %1 currency exchange rate import as of %2 is canceled due to change closing date violation.'; pl = 'Pobieranie kursu waluty %1 na dzień %2 jest anulowane z powodu naruszenia daty zakazu zmian.';es_ES = 'La descarga del tipo de cambio %1 de la fecha %2 ha sido cancelada a causa de la prohibición de los cambios.';es_CO = 'La descarga del tipo de cambio %1 de la fecha %2 ha sido cancelada a causa de la prohibición de los cambios.';tr = 'Değişiklik yasağı tarihi ihlal edildiğinden dolayı %1 tarihi itibariyle döviz%2 kuru yüklenemedi.';it = 'L''importazione del tasso di cambio della valuta %1 in data %2 è annullata a causa della violazione alla modifica della data di chiusura.';de = 'Das Herunterladen des Wechselkurses %1 am Tag %2 wird wegen der Verletzung des Datums des Änderungsverbots abgebrochen.'"); 
				Comment = StringFunctionsClientServer.SubstituteParametersToString(Comment, CurrencySelection.Code, CommonSelection.Date);
				EventName = NStr("ru = 'Поставляемые данные.Отмена загрузки курсов валюты'; en = 'Supplied data. Cancel import of exchange rates'; pl = 'Dostarczane dane.Anulowanie pobierania kursów waluty';es_ES = 'Datos suministrados.Cancelar la descarga de los tipos de cambio';es_CO = 'Datos suministrados.Cancelar la descarga de los tipos de cambio';tr = 'Sağlanan veriler. Döviz kurların içe aktarımı iptal edildi.';it = 'Dati forniti. Annullare importazione dei tassi di cambio';de = 'Gelieferte Daten. Wechselkurse herunterladen abbrechen'", CommonClientServer.DefaultLanguageCode());
				WriteLogEvent(EventName, EventLogLevel.Information,, CurrencySelection.Ref, Comment);
			EndIf;
			
		EndDo;
		
		// Checks whether the exchange rate and multiplier as of January 1, 1980, are available.
		CurrencyRateOperations.CheckCurrencyRateAvailabilityFor01_01_1980(CurrencySelection.Ref);
		
	EndDo;
	
EndProcedure

#EndRegion
