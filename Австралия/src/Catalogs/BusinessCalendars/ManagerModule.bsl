
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region ForCallsFromOtherSubsystems

// CloudTechnology.ExportImportData

// Returns the catalog attributes that naturally form a catalog item key.
//  
//
// Returns:
//  Array - an array of attribute names that form a natural key.
//
Function NaturalKeyFields() Export
	
	Result = New Array();
	
	Result.Add("Code");
	
	Return Result;
	
EndFunction

// End CloudTechnology.ExportImportData

// StandardSubsystems.Print

// Generates print forms
//
// Parameters:
//  ObjectArray - Array - references to objects to be printed.
//  PrintParameters - Structure - additional print settings.
//  PrintFormsCollection - ValueTable - generated spreadsheet documents (output parameter).
//  PrintObjects - ValueList - value - a reference to the object.
//                                            presentation - a name of the area where object is 
//                                                            displayed (output parameter).
//  OutputParameters - Structure - additional parameters of generated spreadsheet documents (output 
//                                            parameter).
//
Procedure Print(ObjectsArray, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters) Export
	
	If Common.SubsystemExists("StandardSubsystems.Print") Then
		ModulePrintManager = Common.CommonModule("PrintManagement");
		ModulePrintManager.OutputSpreadsheetDocumentToCollection(
				PrintFormsCollection,
				"BusinessCalendar", NStr("ru = 'Производственный календарь'; en = 'Business calendar'; pl = 'Kalendarz biznesowy';es_ES = 'Calendario de los días laborales';es_CO = 'Calendario de los días laborales';tr = 'İş takvimi';it = 'Agenda di lavoro';de = 'Geschäftskalender'"),
				BusinessCalendarPrintForm(PrintParameters),
				,
				"Catalog.BusinessCalendars.PF_MXL_BusinessCalendar");
	EndIf;
	
EndProcedure

// End StandardSubsystems.Print

#EndRegion

#EndRegion

#Region Internal

// The function detects the last day for which the data of the specified business calendar is filled 
// in.
//
// Parameters:
//	BusinessCalendar - CatalogRef.BusinessCalendars - a calendar.
//
// Returns:
//  Date - a date until which the business calendar is filled in. Undefined if the calendar is not filled in.
//
Function BusinessCalendarFillingEndDate(BusinessCalendar) Export
	
	Query = New Query;
	Query.SetParameter("BusinessCalendar", BusinessCalendar);
	Query.Text = 
		"SELECT
		|	MAX(BusinessCalendarData.Date) AS Date
		|FROM
		|	InformationRegister.BusinessCalendarData AS BusinessCalendarData
		|WHERE
		|	BusinessCalendarData.BusinessCalendar = &BusinessCalendar
		|
		|HAVING
		|	MAX(BusinessCalendarData.Date) IS NOT NULL ";
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Return Selection.Date;
	EndIf;
	
	Return Undefined;
	
EndFunction

// The function reads business calendar data from the register.
//
// Parameters:
//	BusinessCalendar			 - a reference to the current catalog item.
//	YearNumber							 - a number of the year for which the business calendar is to be read.
//
// Returns
//	BusinessCalendarData	 - a value table that stores data on the day kind of each calendar date.
//
Function BusinessCalendarData(BusinessCalendar, YearNumber) Export
	
	Query = New Query;
	
	Query.SetParameter("BusinessCalendar",	BusinessCalendar);
	Query.SetParameter("CurrentYear",	YearNumber);
	Query.Text =
		"SELECT
		|	BusinessCalendarData.Date,
		|	BusinessCalendarData.DayKind,
		|	BusinessCalendarData.ReplacementDate
		|FROM
		|	InformationRegister.BusinessCalendarData AS BusinessCalendarData
		|WHERE
		|	BusinessCalendarData.Year = &CurrentYear
		|	AND BusinessCalendarData.BusinessCalendar = &BusinessCalendar";
	
	Return Query.Execute().Unload();
	
EndFunction

#EndRegion

#Region Private

// Updates the Business calendars catalog from an XML file.
//
// Parameters:
//	- CalendarsTable - a value table with business calendar details.
//
Procedure UpdateBusinessCalendars(CalendarsTable) Export
	
	Query = New Query;
	Query.SetParameter("ClassifierTable", CalendarsTable);
	Query.Text = 
		"SELECT
		|	CAST(ClassifierTable.Code AS STRING(2)) AS Code,
		|	CAST(ClassifierTable.Base AS STRING(2)) AS CodeOfBasicCalendar,
		|	CAST(ClassifierTable.Description AS STRING(100)) AS Description
		|INTO ClassifierTable
		|FROM
		|	&ClassifierTable AS ClassifierTable
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	ClassifierTable.Code AS Code,
		|	ClassifierTable.CodeOfBasicCalendar AS CodeOfBasicCalendar,
		|	ClassifierTable.Description AS Description,
		|	BusinessCalendars.Ref AS Ref,
		|	ISNULL(BusinessCalendars.Code, """") AS BusinessCalendarCode,
		|	ISNULL(BusinessCalendars.Description, """") AS BusinessCalendarDescription,
		|	ISNULL(BusinessCalendars.BasicCalendar.Code, """") AS BusinessCalendarBasicCode
		|FROM
		|	ClassifierTable AS ClassifierTable
		|		LEFT JOIN Catalog.BusinessCalendars AS BusinessCalendars
		|		ON ClassifierTable.Code = BusinessCalendars.Code
		|
		|ORDER BY
		|	CodeOfBasicCalendar";
	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	Selection = QueryResult.Select();
	While Selection.Next() Do
		If TrimAll(Selection.Code) = TrimAll(Selection.BusinessCalendarCode)
			AND TrimAll(Selection.Description) = TrimAll(Selection.BusinessCalendarDescription) 
			AND TrimAll(Selection.CodeOfBasicCalendar) = TrimAll(Selection.BusinessCalendarBasicCode) Then
			Continue;
		EndIf;
		If ValueIsFilled(Selection.Ref) Then
			CatalogObject = Selection.Ref.GetObject();
		Else
			If Not Common.DataSeparationEnabled() AND ValueIsFilled(Selection.CodeOfBasicCalendar) Then
				// Dependent calendars are not created automatically upon update in the local mode.
				Continue;
			EndIf;
			CatalogObject = CreateItem();
		EndIf;
		CatalogObject.Code = TrimAll(Selection.Code);
		CatalogObject.Description = TrimAll(Selection.Description);
		If ValueIsFilled(Selection.CodeOfBasicCalendar) Then
			CatalogObject.BasicCalendar = FindByCode(Selection.CodeOfBasicCalendar);
		EndIf;
		If InfobaseUpdate.IsCallFromUpdateHandler() Then
			InfobaseUpdate.WriteObject(CatalogObject);
			Continue;
		EndIf;
		CatalogObject.Write();
	EndDo;
	
EndProcedure

// Updates business calendar data by a data table.
//
Function UpdateBusinessCalendarsData(Val DataTable) Export
	
	ChangesTable = BusinessCalendarsChangesTable();
	
	UpdateBusinessCalendarsBasicData(DataTable, ChangesTable);
	
	UpdateDependentBusinessCalendarsData(ChangesTable);
	
	Return ChangesTable;
	
EndFunction

// The function prepares a result of filling in a business calendar with default data.
//  
// If the configuration contains a template with predefined business calendar data for this year, 
//  the template data is used, otherwise, business calendar data is based on information about 
//  holidays and effective holiday replacement rules.
//  
//
Function BusinessCalendarDefaultFillingResult(CalendarCode, YearNumber, Val BasicCalendarCode = Undefined) Export
	
	DaysKinds = New Map;
	ShiftedDays = New Map;
	
	// If the template contains data, use it.
	// Get data for a basic calendar as well, if it is set.
	CalendarsCodes = New Array;
	CalendarsCodes.Add(CalendarCode);
	HasBasicCalendar = False;
	If BasicCalendarCode <> Undefined Then
		CalendarsCodes.Add(BasicCalendarCode);
		HasBasicCalendar = True;
	EndIf;
	
	// Select data from the template for both calendars.
	// Get only holidays and day replacements and not a complete set.
	TemplateData = DefaultBusinessCalendarsData(CalendarsCodes);
	
	RowsFilter = New Structure("BusinessCalendarCode,Year");
	RowsFilter.Year = YearNumber;
	
	HasCalendarData = False;
	RowsFilter.BusinessCalendarCode = CalendarCode;
	CalendarData = TemplateData.FindRows(RowsFilter);
	If CalendarData.Count() > 0 Then
		HasCalendarData = True;
		FillDaysKindsWithCalendarData(CalendarData, DaysKinds, ShiftedDays);
	EndIf;
	
	// Check if the template contains basic calendar data.
	HasBasicCalendarData = False;
	If HasBasicCalendar Then
		RowsFilter.BusinessCalendarCode = BasicCalendarCode;
		CalendarData = TemplateData.FindRows(RowsFilter);
		If CalendarData.Count() > 0 Then
			HasBasicCalendarData = True;
			If Not HasCalendarData Then
				FillDaysKindsWithCalendarData(CalendarData, DaysKinds, ShiftedDays);
			EndIf;
		EndIf;
	EndIf;
	
	// Add default data for other days.
	DayDate = Date(YearNumber, 1, 1);
	While DayDate <= Date(YearNumber, 12, 31) Do
		If DaysKinds[DayDate] = Undefined Then
			DaysKinds.Insert(DayDate, DayKindByDate(DayDate));
		EndIf;
		DayDate = DayDate + DayLength();
	EndDo;
	
	// If there are no data in the template, fill in permanent holidays.
	If Not HasCalendarData Then
		If HasBasicCalendar AND HasBasicCalendarData Then
			// Request permanent holidays of the basic calendar only if they are missing in the template.
			BasicCalendarCode = Undefined;
		EndIf;
		FillPermanentHolidays(DaysKinds, ShiftedDays, YearNumber, CalendarCode, BasicCalendarCode);
	EndIf;
	
	// Convert them to table.
	BusinessCalendarData = NewBusinessCalendarsData();
	For Each KeyAndValue In DaysKinds Do
		NewRow = BusinessCalendarData.Add();
		NewRow.Date = KeyAndValue.Key;
		NewRow.DayKind = KeyAndValue.Value;
		ReplacementDate = ShiftedDays[NewRow.Date];
		If ReplacementDate <> Undefined Then
			NewRow.ReplacementDate = ReplacementDate;
		EndIf;
		NewRow.Year = YearNumber;
		NewRow.BusinessCalendarCode = CalendarCode;
	EndDo;
	
	BusinessCalendarData.Sort("Date");
	
	Return BusinessCalendarData;
	
EndFunction

Function BusinessCalendarsDefaultFillingResult(CalendarsCodes) Export
	
	Query = New Query;
	Query.SetParameter("CalendarsCodes", CalendarsCodes);
	Query.Text = 
		"SELECT
		|	BusinessCalendars.Ref AS Ref,
		|	BusinessCalendars.Code AS CalendarCode,
		|	BusinessCalendars.BasicCalendar AS BasicCalendar,
		|	BusinessCalendars.BasicCalendar.Code AS BasicCalendarCode
		|FROM
		|	Catalog.BusinessCalendars AS BusinessCalendars
		|WHERE
		|	BusinessCalendars.Code IN(&CalendarsCodes)";
	QueryResult = Query.Execute();
	
	// Request data of all calendars from the template to determine years to be filled in.
	TemplateDataCodes = QueryResult.Unload().UnloadColumn("CalendarCode");
	TemplateData = DefaultBusinessCalendarsData(TemplateDataCodes);
	
	DataTable = NewBusinessCalendarsData();
	Selection = QueryResult.Select();
	While Selection.Next() Do
		RowsFilter = New Structure("BusinessCalendarCode");
		RowsFilter.BusinessCalendarCode = Selection.CalendarCode;
		TemplateCalendarData = TemplateData.FindRows(RowsFilter);
		YearsNumbers = Common.UnloadColumn(TemplateCalendarData, "Year", True);
		CurrentYear = Year(CurrentSessionDate());
		If YearsNumbers.Find(CurrentYear) = Undefined Then
			// Add the current year by default.
			YearsNumbers.Add(CurrentYear);
		EndIf;
		For Each YearNumber In YearsNumbers Do
			CalendarData = BusinessCalendarDefaultFillingResult(Selection.CalendarCode, YearNumber, Selection.BasicCalendarCode);
			CommonClientServer.SupplementTable(CalendarData, DataTable);
		EndDo;
	EndDo;
	
	Return DataTable;
	
EndFunction

// Converts business calendar data supplied as a template in the configuration.
//
// Parameters:
//	 CalendarCodes - an optional parameter, an array, if it is not specified, all available data will be got from the template.
//	 GenerateFullSet - an optional parameter, Boolean, if false, only data on variances from the default calendar will be generated.
//
// Returns:
//  ValueTable - see BusinessCalendarsDataFromXML. 
//
Function BusinessCalendarsDataFromTemplate(CalendarsCodes = Undefined, GenerateFullSet = True) Export
	
	If Metadata.DataProcessors.Find("FillCalendarSchedules") = Undefined Then
		Return NewBusinessCalendarsData();
	EndIf;
	
	ModuleCalendarSchedules = Common.CommonModule("DataProcessors.FillCalendarSchedules");
	TextDocument = ModuleCalendarSchedules.GetTemplate("BusinessCalendarsData");
	
	XMLData = Common.ReadXMLToTable(TextDocument.GetText());
	
	CalendarsTable = BusinessCalendarsFromTemplate();
	
	Return BusinessCalendarsDataFromXML(XMLData, CalendarsTable, CalendarsCodes, GenerateFullSet);
	
EndFunction

// Converts business calendar data presented as XML.
//
// Parameters:
//	 XMLData - a structure extracted from an XML file using the Common.ReadXMLToTable method.
//	 CalendarsTable - a value table, a list of business calendars supported in the application.
//	 CalendarsCodes - an optional parameter, an array, if it is not set, the filter will not be set.
//	 GenerateFullSet - an optional parameter, Boolean, if false, only data on variances from the default calendar will be generated.
//
// Returns:
//  ValueTable - a table with columns:
//	* BusinessCalendarCode
//	* DayKind
//	* Year
//	* Date
//	* ReplacementDate.
//
Function BusinessCalendarsDataFromXML(Val XMLData, CalendarsTable, CalendarsCodes = Undefined, GenerateFullSet = True) Export
	
	DataTable = NewBusinessCalendarsData();
	
	ClassifierTable = XMLData.Data;
	
	CalendarsYears = ClassifierTable.Copy(, "Calendar,Year");
	CalendarsYears.GroupBy("Calendar,Year");
	
	RowsFilter = New Structure("Calendar,Year");
	For Each Combination In CalendarsYears Do
		If CalendarsCodes <> Undefined AND CalendarsCodes.Find(Combination.Calendar) = Undefined Then
			Continue;
		EndIf;
		YearDates = New Map;
		FillPropertyValues(RowsFilter, Combination);
		CalendarDataRows = ClassifierTable.FindRows(RowsFilter);
		For Each ClassifierRow In CalendarDataRows Do
			NewRow = NewCalendarDataRowFromClassifier(DataTable, ClassifierRow);
			YearDates.Insert(NewRow.Date, True);
		EndDo;
		BasicCalendarCode = BasicCalendarCode(Combination.Calendar, CalendarsTable);
		If BasicCalendarCode <> Undefined Then
			RowsFilter.Calendar = BasicCalendarCode;
			CalendarDataRows = ClassifierTable.FindRows(RowsFilter);
			For Each ClassifierRow In CalendarDataRows Do
				ClassifierRow.Calendar = Combination.Calendar;
				NewRow = NewCalendarDataRowFromClassifier(DataTable, ClassifierRow, True, False);
				ClassifierRow.Calendar = BasicCalendarCode;
				If NewRow <> Undefined Then
					YearDates.Insert(NewRow.Date, True);
				EndIf;
			EndDo;
		EndIf;
		If Not GenerateFullSet Then
			Continue;
		EndIf;
		YearNumber = Number(Combination.Year);
		DayDate = Date(YearNumber, 1, 1);
		While DayDate <= Date(YearNumber, 12, 31) Do
			If YearDates[DayDate] = Undefined Then
				NewRow = DataTable.Add();
				NewRow.BusinessCalendarCode = Combination.Calendar;
				NewRow.Year = YearNumber;
				NewRow.Date = DayDate;
				NewRow.DayKind = DayKindByDate(DayDate);
			EndIf;
			DayDate = DayDate + DayLength();
		EndDo;
	EndDo;
	
	Return DataTable;
	
EndFunction

// Gets the table of business calendars supplied with the application.
//
// Returns:
//	 ValueTable.
//
Function BusinessCalendarsFromTemplate() Export
	
	If Metadata.DataProcessors.Find("FillCalendarSchedules") = Undefined Then
		Table = New ValueTable;
		Table.Columns.Add("Code");
		
		Return Table;
	EndIf;
	
	ModuleCalendarSchedules = Common.CommonModule("DataProcessors.FillCalendarSchedules");
	TextDocument = ModuleCalendarSchedules.GetTemplate("BusinessCalendars");
	CalendarsTable = Common.ReadXMLToTable(TextDocument.GetText()).Data;
	
	Return CalendarsTable;
	
EndFunction

Procedure FillDefaultBusinessCalendarsTimeConsumingOperation(Parameters, ResultAddress) Export
	
	Calendars = DefaultBusinessCalendars();
	PutToTempStorage(Calendars, ResultAddress);
	
EndProcedure

Procedure UpdateBusinessCalendarsBasicData(DataTable, CalendarsChanges)
	
	If DataTable.Count() = 0 Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.SetParameter("ClassifierTable", DataTable);
	Query.Text = 
		"SELECT
		|	ClassifierTable.BusinessCalendarCode AS CalendarCode,
		|	ClassifierTable.Date AS Date,
		|	ClassifierTable.Year AS Year,
		|	ClassifierTable.DayKind AS DayKind,
		|	ClassifierTable.ReplacementDate AS ReplacementDate
		|INTO TTClassifierTable
		|FROM
		|	&ClassifierTable AS ClassifierTable
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT DISTINCT
		|	BusinessCalendars.Ref AS BusinessCalendar,
		|	ClassifierTable.CalendarCode AS BusinessCalendarCode,
		|	ClassifierTable.Year AS Year
		|INTO TTCalendarChanges
		|FROM
		|	TTClassifierTable AS ClassifierTable
		|		INNER JOIN Catalog.BusinessCalendars AS BusinessCalendars
		|		ON ClassifierTable.CalendarCode = BusinessCalendars.Code
		|		LEFT JOIN InformationRegister.BusinessCalendarData AS BusinessCalendarData
		|		ON (BusinessCalendars.Ref = BusinessCalendarData.BusinessCalendar)
		|			AND ClassifierTable.Year = BusinessCalendarData.Year
		|			AND ClassifierTable.Date = BusinessCalendarData.Date
		|			AND ClassifierTable.DayKind = BusinessCalendarData.DayKind
		|			AND ClassifierTable.ReplacementDate = BusinessCalendarData.ReplacementDate
		|WHERE
		|	BusinessCalendarData.DayKind IS NULL
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	CalendarsChanges.BusinessCalendar AS BusinessCalendar,
		|	CalendarsChanges.BusinessCalendarCode AS BusinessCalendarCode,
		|	CalendarsChanges.Year AS Year,
		|	ClassifierTable.Date AS Date,
		|	ClassifierTable.DayKind AS DayKind,
		|	ClassifierTable.ReplacementDate AS ReplacementDate
		|FROM
		|	TTCalendarChanges AS CalendarsChanges
		|		INNER JOIN TTClassifierTable AS ClassifierTable
		|		ON (ClassifierTable.CalendarCode = CalendarsChanges.BusinessCalendarCode)
		|			AND (ClassifierTable.Year = CalendarsChanges.Year)
		|
		|ORDER BY
		|	CalendarsChanges.BusinessCalendar,
		|	Year";
	
	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	RecordSet = InformationRegisters.BusinessCalendarData.CreateRecordSet();
	
	RegisterKeys = New Array;
	RegisterKeys.Add("BusinessCalendar");
	RegisterKeys.Add("Year");
	
	Selection = QueryResult.Select();
	While Selection.NextByFieldValue("BusinessCalendar") Do
		While Selection.NextByFieldValue("Year") Do
			RecordSet.Clear();
			While Selection.Next() Do
				FillPropertyValues(RecordSet.Add(), Selection);
			EndDo;
			FillPropertyValues(CalendarsChanges.Add(), Selection);
			For Each varKey In RegisterKeys Do 
				RecordSet.Filter[varKey].Set(Selection[varKey]);
			EndDo;
			If InfobaseUpdate.IsCallFromUpdateHandler() Then
				InfobaseUpdate.WriteRecordSet(RecordSet);
				Continue;
			EndIf;
			RecordSet.Write();
		EndDo;
	EndDo;
	
	CalendarsChanges.GroupBy("BusinessCalendarCode, Year");
	
EndProcedure

Procedure UpdateDependentBusinessCalendarsData(CalendarsChanges) Export
	
	If CalendarsChanges.Count() = 0 Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.SetParameter("CalendarsChanges", CalendarsChanges);
	Query.SetParameter("DependentCalendarsUpdateStartYear", 2018);
	Query.Text = 
		"SELECT
		|	CalendarsChanges.BusinessCalendarCode AS BusinessCalendarCode,
		|	CalendarsChanges.Year AS Year
		|INTO TTCalendarChanges
		|FROM
		|	&CalendarsChanges AS CalendarsChanges
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	DependentCalendars.Ref AS BusinessCalendar,
		|	DependentCalendars.Code AS Code,
		|	BasicCalendarChanges.Year AS Year,
		|	DependentCalendars.BasicCalendar.Code AS BasicCalendarCode
		|FROM
		|	Catalog.BusinessCalendars AS DependentCalendars
		|		INNER JOIN TTCalendarChanges AS BasicCalendarChanges
		|		ON DependentCalendars.BasicCalendar.Code = BasicCalendarChanges.BusinessCalendarCode
		|			AND (DependentCalendars.BasicCalendar <> VALUE(Catalog.BusinessCalendars.EmptyRef))
		|			AND (BasicCalendarChanges.Year >= &DependentCalendarsUpdateStartYear)
		|		LEFT JOIN TTCalendarChanges AS DependentCalendarChanges
		|		ON (DependentCalendarChanges.BusinessCalendarCode = DependentCalendars.Code)
		|			AND (DependentCalendarChanges.Year = BasicCalendarChanges.Year)
		|WHERE
		|	DependentCalendarChanges.Year IS NULL";
	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	CodesOfDependent = QueryResult.Unload().UnloadColumn("Code");
	TemplateData = DefaultBusinessCalendarsData(CodesOfDependent);
	
	RowsFilter = New Structure(
		"BusinessCalendarCode,
		|Year");
	
	Selection = QueryResult.Select();
	While Selection.Next() Do
		RowsFilter.BusinessCalendarCode = Selection.Code;
		RowsFilter.Year = Selection.Year;
		FoundRows = TemplateData.FindRows(RowsFilter);
		If FoundRows.Count() > 0 Then
			// If the template contains data, it is not to be refilled.
			Continue;
		EndIf;
		CalendarData = BusinessCalendarDefaultFillingResult(Selection.Code, Selection.Year, Selection.BasicCalendarCode);
		CalendarData.Columns.Add("BusinessCalendar");
		CalendarData.FillValues(Selection.BusinessCalendar, "BusinessCalendar");
		RecordSet = InformationRegisters.BusinessCalendarData.CreateRecordSet();
		RecordSet.Load(CalendarData);
		RecordSet.Filter.BusinessCalendar.Set(Selection.BusinessCalendar);
		RecordSet.Filter.Year.Set(Selection.Year);
		If InfobaseUpdate.IsCallFromUpdateHandler() Then
			InfobaseUpdate.WriteRecordSet(RecordSet);
		Else
			RecordSet.Write();
		EndIf;
		// Add it to the changes table.
		NewRow = CalendarsChanges.Add();
		NewRow.BusinessCalendarCode = Selection.Code;
		NewRow.Year = Selection.Year;
	EndDo;
	
EndProcedure

// Defines a source of the current list of supported business calendars (template or classifier delivery).
//
// Returns:
//	 ValueTable.
//
Function DefaultBusinessCalendars()
	
	If CalendarSchedules.CalendarsVersion() >= CalendarSchedules.LoadedCalendarsVersion() Then
		Return BusinessCalendarsFromTemplate();
	EndIf;
	
	Try
		Return BusinessCalendarsFromClassifierFile();
	Except
		EventName = NStr("ru = 'Календарные графики.Получение календарей из классификатора'; en = 'Calendar schedules.Get calendars from classifier'; pl = 'Harmonogramy kalendarzowe.Pobieranie kalendarzy z klasyfikatora';es_ES = 'Horarios. Recepción de los calendarios del clasificador';es_CO = 'Horarios. Recepción de los calendarios del clasificador';tr = 'Takvim grafikler. Sınıflandırıcıdan takvim alma';it = 'Pianificazioni calendario.Prendi i calendari dal classificatore';de = 'Kalenderzeitpläne. Abrufen von Kalendern aus dem Klassifikator'", CommonClientServer.DefaultLanguageCode());
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Не удалось получить список производственных календарей из классификатора.
                  |Список календарей получен из поставляемого макета.
                  |%1'; 
                  |en = 'Cannot get a business calendars list from classifier.
                  |The calendars list is got from supplied template.
                  |%1'; 
                  |pl = 'Pobieranie listy kalendarzy produkcyjnych z klasyfikatora nie powiodło się.
                  |Lista kalendarzy została pobrana z dostarczanego szablonu.
                  |%1';
                  |es_ES = 'No se ha podido recibir la lista de horarios del clasificador.
                  |La lista de horarios ha sido recibido del modelo suministrado.
                  |%1';
                  |es_CO = 'No se ha podido recibir la lista de horarios del clasificador.
                  |La lista de horarios ha sido recibido del modelo suministrado.
                  |%1';
                  |tr = 'Bir sınıflandırıcıdan üretim takvimleri listesi alınamadı. 
                  |Takvim listesi verilen şablondan alınmıştır.
                  |%1';
                  |it = 'Impossibile recuperare elenco calendari aziendali dal classificatore.
                  |L''elenco calendari è presa dal template fornito:
                  |%1';
                  |de = 'Es war nicht möglich, die Liste der Produktionskalender aus dem Klassifikator zu beziehen.
                  |Die Liste der Kalender entnehmen Sie bitte dem mitgelieferten Layout.
                  |%1'"), 
			DetailErrorDescription(ErrorInfo()));
		WriteLogEvent(EventName, EventLogLevel.Error, , , MessageText);
	EndTry;
	
	Return BusinessCalendarsFromTemplate();
	
EndFunction

// Defines a source of relevant business calendar data (template or classifier delivery).
//
// Parameters:
//	 CalendarsCodes - an array.
//
// Returns:
//  ValueTable - see Catalogs.BusinessCalendars.BusinessCalendarsDataFromXML. 
//
Function DefaultBusinessCalendarsData(CalendarsCodes)
	
	If CalendarSchedules.CalendarsVersion() >= CalendarSchedules.LoadedCalendarsVersion() Then
		Return BusinessCalendarsDataFromTemplate(CalendarsCodes, False);
	EndIf;
	
	Return BusinessCalendarsDataFromClassifierFile(CalendarsCodes);
	
EndFunction

Function BusinessCalendarsFromClassifierFile()
	
	ClassifierData = CalendarSchedules.ClassifierData();
	
	CalendarsTable = ClassifierData["BusinessCalendars"].Data;
	
	Return	CalendarsTable;

EndFunction

Function BusinessCalendarsDataFromClassifierFile(CalendarsCodes)
	
	ClassifierData = CalendarSchedules.ClassifierData();
	
	Return BusinessCalendarsDataFromXML(
		ClassifierData["BusinessCalendarsData"], 
		ClassifierData["BusinessCalendars"].Data,
		CalendarsCodes, 
		False);
	
EndFunction

// Generates a value table to describe changes of business calendar data.
//
Function BusinessCalendarsChangesTable()
	
	ChangesTable = New ValueTable;
	ChangesTable.Columns.Add("BusinessCalendarCode", New TypeDescription("String", , New StringQualifiers(3)));
	ChangesTable.Columns.Add("Year", New TypeDescription("Number", New NumberQualifiers(4)));
	
	Return ChangesTable;
	
EndFunction

// The procedure records data of one business calendar for one year.
//
// Parameters:
//	BusinessCalendar			 - a reference to the current catalog item.
//	YearNumber							 - a number of the year for which the business calendar is to be recorded.
//	BusinessCalendarData	 - a value table that stores data on the day kind of each calendar date.
//
// Returns
//	No
//
Procedure WriteBusinessCalendarData(BusinessCalendar, YearNumber, BusinessCalendarData) Export
	
	RecordSet = InformationRegisters.BusinessCalendarData.CreateRecordSet();
	
	For Each KeyAndValue In BusinessCalendarData Do
		FillPropertyValues(RecordSet.Add(), KeyAndValue);
	EndDo;
	
	FilterValues = New Structure("BusinessCalendar, Year", BusinessCalendar, YearNumber);
	
	For Each KeyAndValue In FilterValues Do
		RecordSet.Filter[KeyAndValue.Key].Set(KeyAndValue.Value);
	EndDo;
	
	For Each SetRow In RecordSet Do
		FillPropertyValues(SetRow, FilterValues);
	EndDo;
	
	RecordSet.Write(True);
	
	UpdateConditions = WorkScheduleUpdateConditions(BusinessCalendar, YearNumber);
	CalendarSchedules.DistributeBusinessCalendarsDataChanges(UpdateConditions);
	
EndProcedure
	
// Defines a map between business calendar day kinds and appearance color of this day in the 
// calendar field.
//
// Returns
//	AppearanceColors - a map between day kinds and appearance colors.
//
Function BusinessCalendarDayKindsAppearanceColors() Export
	
	AppearanceColors = New Map;
	
	AppearanceColors.Insert(Enums.BusinessCalendarDaysKinds.Work,			StyleColors.BusinessCalendarDayKindWorkdayColor);
	AppearanceColors.Insert(Enums.BusinessCalendarDaysKinds.Saturday,			StyleColors.BusinessCalendarDayKindSaturdayColor);
	AppearanceColors.Insert(Enums.BusinessCalendarDaysKinds.Sunday,		StyleColors.BusinessCalendarDayKindSundayColor);
	AppearanceColors.Insert(Enums.BusinessCalendarDaysKinds.Preholiday,	StyleColors.BusinessCalendarDayKindDayPreholidayColor);
	AppearanceColors.Insert(Enums.BusinessCalendarDaysKinds.Holiday,			StyleColors.BusinessCalendarDayKindHolidayColor);
	
	Return AppearanceColors;
	
EndFunction

// The function creates a list of all possible business calendar day kinds according to metadata of 
// the BusinessCalendarDayKinds enumeration.
//
// Returns
//	DayKindsList - a value list containing an enumeration value and its synonym as a presentation.
//  					
//
Function DayKindsList() Export
	
	DayKindsList = New ValueList;
	
	For Each DayKindMetadata In Metadata.Enums.BusinessCalendarDaysKinds.EnumValues Do
		DayKindsList.Add(Enums.BusinessCalendarDaysKinds[DayKindMetadata.Name], DayKindMetadata.Synonym);
	EndDo;
	
	Return DayKindsList;
	
EndFunction

// The function creates an array of business calendars available for using, for example, as a 
// template.
//
Function BusinessCalendarsList() Export

	Query = New Query(
	"SELECT
	|	BusinessCalendars.Ref
	|FROM
	|	Catalog.BusinessCalendars AS BusinessCalendars
	|WHERE
	|	(NOT BusinessCalendars.DeletionMark)");
		
	BusinessCalendarsList = New Array;
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		BusinessCalendarsList.Add(Selection.Ref);
	EndDo;
	
	Return BusinessCalendarsList;
	
EndFunction

// Fills in an array of holidays according to a business calendar for a specific calendar year.
// 
//
Function BusinessCalendarHolidays(BusinessCalendarCode, YearNumber)
	
	Holidays = New ValueTable;
	Holidays.Columns.Add("Date", New TypeDescription("Date"));
	Holidays.Columns.Add("ShiftHoliday", New TypeDescription("Boolean"));
	Holidays.Columns.Add("AddPreholiday", New TypeDescription("Boolean"));
	Holidays.Columns.Add("NonWorkingOnly", New TypeDescription("Boolean"));
	
	If Metadata.DataProcessors.Find("FillCalendarSchedules") <> Undefined Then
		ModuleCalendarSchedules = Common.CommonModule("DataProcessors.FillCalendarSchedules");
		ModuleCalendarSchedules.FillHolidays(BusinessCalendarCode, YearNumber, Holidays);
	EndIf;
	
	Return Holidays;
	
EndFunction

Function WorkScheduleUpdateConditions(BusinessCalendar, Year)
	
	UpdateConditions = BusinessCalendarsChangesTable();
	
	NewRow = UpdateConditions.Add();
	NewRow.BusinessCalendarCode = Common.ObjectAttributeValue(BusinessCalendar, "Code");
	NewRow.Year = Year;

	Return UpdateConditions;
	
EndFunction

Function DayLength()
	Return 24 * 3600;
EndFunction
	
Function NewBusinessCalendarsData()
	
	DataTable = New ValueTable;
	DataTable.Columns.Add("BusinessCalendarCode", New TypeDescription("String", , New StringQualifiers(2)));
	DataTable.Columns.Add("DayKind", New TypeDescription("EnumRef.BusinessCalendarDaysKinds"));
	DataTable.Columns.Add("Year", New TypeDescription("Number"));
	DataTable.Columns.Add("Date", New TypeDescription("Date"));
	DataTable.Columns.Add("ReplacementDate", New TypeDescription("Date"));
	Return DataTable;
	
EndFunction	

Procedure FillPermanentHolidays(DaysKinds, ShiftedDays, YearNumber, CalendarCode, BasicCalendarCode = Undefined)
	
	// If not, fill in holidays and their replacements.
	Holidays = BusinessCalendarHolidays(CalendarCode, YearNumber);
	// Add holidays of the next year to the table as well because they affect filling of the current 
	// year (for example, December 31 is a pre-holiday day).
	NextYearHolidays = BusinessCalendarHolidays(CalendarCode, YearNumber + 1);
	CommonClientServer.SupplementTable(NextYearHolidays, Holidays);
	
	If BasicCalendarCode <> Undefined Then
		// Add basic calendar holidays to the table as well.
		BasicCalendarHolidays = BusinessCalendarHolidays(BasicCalendarCode, YearNumber);
		CommonClientServer.SupplementTable(BasicCalendarHolidays, Holidays);
		NextYearHolidays = BusinessCalendarHolidays(BasicCalendarCode, YearNumber + 1);
		CommonClientServer.SupplementTable(NextYearHolidays, Holidays);
	EndIf;
	
	// If a holiday falls on a weekend, the holiday replaces the next workday, except for holidays 
	// falling on a weekend during the New Year and Christmas holidays.	
	// 
	// 
	
	For Each TableRow In Holidays Do
		PublicHoliday = TableRow.Date;
		// Mark the day immediately preceding the holiday as a pre-holiday day.
		// 
		If TableRow.AddPreholiday Then
			PreholidayDate = PublicHoliday - DayLength();
			If Year(PreholidayDate) = YearNumber Then
				// Skip pre-holiday days of another year.
				If DaysKinds[PreholidayDate] = Enums.BusinessCalendarDaysKinds.Work 
					AND Holidays.Find(PreholidayDate, "Date") = Undefined Then
					DaysKinds.Insert(PreholidayDate, Enums.BusinessCalendarDaysKinds.Preholiday);
				EndIf;
			EndIf;
		EndIf;
		If Year(PublicHoliday) <> YearNumber Then
			// Also skip holidays of another year.
			Continue;
		EndIf;
		If DaysKinds[PublicHoliday] <> Enums.BusinessCalendarDaysKinds.Work 
			AND TableRow.ShiftHoliday Then
			// If a holiday falls on a weekend and it needs to replace another day, move the holiday to the next 
			// workday.
			// 
			DayDate = PublicHoliday;
			While True Do
				DayDate = DayDate + DayLength();
				If DaysKinds[DayDate] = Enums.BusinessCalendarDaysKinds.Work 
					AND Holidays.Find(DayDate, "Date") = Undefined Then
					DaysKinds.Insert(DayDate, DaysKinds[PublicHoliday]);
					ShiftedDays.Insert(DayDate, PublicHoliday);
					ShiftedDays.Insert(PublicHoliday, DayDate);
					Break;
				EndIf;
			EndDo;
		EndIf;
		If TableRow.NonWorkingOnly Then
			DaysKinds.Insert(PublicHoliday, Enums.BusinessCalendarDaysKinds.NonWorkingDay);
		Else
			DaysKinds.Insert(PublicHoliday, Enums.BusinessCalendarDaysKinds.Holiday);
		EndIf;
	EndDo;
	
EndProcedure

Procedure FillDaysKindsWithCalendarData(CalendarData, DaysKinds, ShiftedDays)
	
	For Each DataString In CalendarData Do
		DaysKinds.Insert(DataString.Date, DataString.DayKind);
		If ValueIsFilled(DataString.ReplacementDate) Then
			ShiftedDays.Insert(DataString.Date, DataString.ReplacementDate);
		EndIf;
	EndDo;
	
EndProcedure

Function DayKindByDate(Date)
	
	WeekDayNumber = WeekDay(Date);
	
	If WeekDayNumber <= 5 Then
		Return Enums.BusinessCalendarDaysKinds.Work;
	EndIf;
	
	If WeekDayNumber = 6 Then
		Return Enums.BusinessCalendarDaysKinds.Saturday;
	EndIf;
	
	If WeekDayNumber = 7 Then
		Return Enums.BusinessCalendarDaysKinds.Sunday;
	EndIf;
	
EndFunction

Function BasicCalendarCode(CalendarCode, CalendarClassifier)
	
	CalendarRow = CalendarClassifier.Find(CalendarCode, "Code");
	
	If CalendarRow = Undefined Then
		Return Undefined;
	EndIf;
	
	If Not ValueIsFilled(CalendarRow["Base"]) Then
		Return Undefined;
	EndIf;
	
	Return CalendarRow["Base"];
	
EndFunction

Function NewCalendarDataRowFromClassifier(CalendarData, ClassifierRow, CheckSSL = False, Replace = False)
	
	If CheckSSL Then
		RowsFilter = New Structure("BusinessCalendarCode,Date");
		RowsFilter.BusinessCalendarCode = ClassifierRow.Calendar;
		RowsFilter.Date = Date(ClassifierRow.Date);
		FoundRows = CalendarData.FindRows(RowsFilter);
		If FoundRows.Count() > 0 Then
			If Not Replace Then
				Return Undefined;
			EndIf;
			For Each FoundRow In FoundRows Do
				CalendarData.Delete(FoundRow);
			EndDo;
		EndIf;
	EndIf;
	
	NewRow = CalendarData.Add();
	NewRow.BusinessCalendarCode = ClassifierRow.Calendar;
	NewRow.DayKind = Enums.BusinessCalendarDaysKinds[ClassifierRow.DayType];
	NewRow.Year = Number(ClassifierRow.Year);
	NewRow.Date = Date(ClassifierRow.Date);
	If ValueIsFilled(ClassifierRow.SwapDate) Then
		NewRow.ReplacementDate = Date(ClassifierRow.SwapDate);
	EndIf;
	
	Return NewRow;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Business calendar print form.

Function BusinessCalendarPrintForm(PrintFormPreparationParameters)
	
	SpreadsheetDocument = New SpreadsheetDocument;
	
	Template = PrintManagement.PrintFormTemplate("Catalog.BusinessCalendars.PF_MXL_BusinessCalendar");
	If Common.SubsystemExists("StandardSubsystems.Print") Then
		ModulePrintManager = Common.CommonModule("PrintManagement");
		Template = ModulePrintManager.PrintFormTemplate("Catalog.BusinessCalendars.PF_MXL_BusinessCalendar");
	EndIf;
	
	BusinessCalendar = PrintFormPreparationParameters.BusinessCalendar;
	YearNumber = PrintFormPreparationParameters.YearNumber;
	
	PrintTitle = Template.GetArea("Title");
	PrintTitle.Parameters.BusinessCalendar = BusinessCalendar;
	PrintTitle.Parameters.Year = Format(YearNumber, "NG=");
	SpreadsheetDocument.Put(PrintTitle);
	
	// Initial values regardless of query execution result.
	WorkTime40Year = 0;
	WorkTime36Year = 0;
	WorkTime24Year = 0;
	
	NonWorkdayKinds = New Array;
	NonWorkdayKinds.Add(Enums.BusinessCalendarDaysKinds.Saturday);
	NonWorkdayKinds.Add(Enums.BusinessCalendarDaysKinds.Sunday);
	NonWorkdayKinds.Add(Enums.BusinessCalendarDaysKinds.Holiday);
	NonWorkdayKinds.Add(Enums.BusinessCalendarDaysKinds.NonWorkingDay);
	
	Query = New Query;
	Query.SetParameter("Year", YearNumber);
	Query.SetParameter("BusinessCalendar", BusinessCalendar);
	Query.Text = 
		"SELECT
		|	YEAR(CalendarData.Date) AS CalendarYear,
		|	QUARTER(CalendarData.Date) AS CalendarQuarter,
		|	MONTH(CalendarData.Date) AS CalendarMonth,
		|	COUNT(DISTINCT CalendarData.Date) AS CalendarDays,
		|	CalendarData.DayKind AS DayKind
		|FROM
		|	InformationRegister.BusinessCalendarData AS CalendarData
		|WHERE
		|	CalendarData.Year = &Year
		|	AND CalendarData.BusinessCalendar = &BusinessCalendar
		|
		|GROUP BY
		|	CalendarData.DayKind,
		|	YEAR(CalendarData.Date),
		|	QUARTER(CalendarData.Date),
		|	MONTH(CalendarData.Date)
		|
		|ORDER BY
		|	CalendarYear,
		|	CalendarQuarter,
		|	CalendarMonth
		|TOTALS BY
		|	CalendarYear,
		|	CalendarQuarter,
		|	CalendarMonth";
	Result = Query.Execute();
	
	SelectionByYear = Result.Select(QueryResultIteration.ByGroups);
	While SelectionByYear.Next() Do
		
		SelectionByQuarter = SelectionByYear.Select(QueryResultIteration.ByGroups);
		While SelectionByQuarter.Next() Do
			QuarterNumber = Template.GetArea("Quarter");
			QuarterNumber.Parameters.QuarterNumber = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = '%1 квартал'; en = 'quarter %1'; pl = 'kwartał %1';es_ES = 'trimestre %1';es_CO = 'trimestre %1';tr = 'çeyrek yıl %1';it = 'trimestre %1';de = 'Quartal %1'"), SelectionByQuarter.CalendarQuarter);
			SpreadsheetDocument.Put(QuarterNumber);
			
			QuarterHeader = Template.GetArea("QuarterHeader");
			SpreadsheetDocument.Put(QuarterHeader);
			
			CalendarDaysQuarter = 0;
			WorkTime40Quarter = 0;
			WorkTime36Quarter = 0;
			WorkTime24Quarter = 0;
			WorkdaysQuarter	 = 0;
			WeekendDaysQuarter	 = 0;
			
			If SelectionByQuarter.CalendarQuarter = 1 
				Or SelectionByQuarter.CalendarQuarter = 3 Then
				CalendarDaysHalfYear1	= 0;
				WorkTime40HalfYear1	= 0;
				WorkTime36HalfYear1	= 0;
				WorkTime24HalfYear1	= 0;
				WorkdaysHalfYear1		= 0;
				WeekendDaysHalfYear1		= 0;
			EndIf;
			
			If SelectionByQuarter.CalendarQuarter = 1 Then
				CalendarDaysYear	= 0;
				WorkTime40Year	= 0;
				WorkTime36Year	= 0;
				WorkTime24Year	= 0;
				WorkdaysYear		= 0;
				WeekendDaysYear		= 0;
			EndIf;
			
			SelectionByMonth = SelectionByQuarter.Select(QueryResultIteration.ByGroups);
			While SelectionByMonth.Next() Do
				
				WeekendDays		= 0;
				WorkTime40	= 0;
				WorkTime36	= 0;
				WorkTime24	= 0;
				CalendarDays	= 0;
				Workdays		= 0;
				SelectionByDayKind = SelectionByMonth.Select(QueryResultIteration.Linear);
				
				While SelectionByDayKind.Next() Do
					If NonWorkdayKinds.Find(SelectionByDayKind.DayKind) <> Undefined Then
						 WeekendDays = WeekendDays + SelectionByDayKind.CalendarDays
					 ElsIf SelectionByDayKind.DayKind = Enums.BusinessCalendarDaysKinds.Work Then 
						 WorkTime40 = WorkTime40 + SelectionByDayKind.CalendarDays * 8;
						 WorkTime36 = WorkTime36 + SelectionByDayKind.CalendarDays * 36 / 5;
						 WorkTime24 = WorkTime24 + SelectionByDayKind.CalendarDays * 24 / 5;
						 Workdays 	= Workdays + SelectionByDayKind.CalendarDays;
					 ElsIf SelectionByDayKind.DayKind = Enums.BusinessCalendarDaysKinds.Preholiday Then
						 WorkTime40 = WorkTime40 + SelectionByDayKind.CalendarDays * 7;
						 WorkTime36 = WorkTime36 + SelectionByDayKind.CalendarDays * (36 / 5 - 1);
						 WorkTime24 = WorkTime24 + SelectionByDayKind.CalendarDays * (24 / 5 - 1);
						 Workdays		= Workdays + SelectionByDayKind.CalendarDays;
					 EndIf;
					 CalendarDays = CalendarDays + SelectionByDayKind.CalendarDays;
				EndDo;
				
				CalendarDaysQuarter = CalendarDaysQuarter + CalendarDays;
				WorkTime40Quarter = WorkTime40Quarter + WorkTime40;
				WorkTime36Quarter = WorkTime36Quarter + WorkTime36;
				WorkTime24Quarter = WorkTime24Quarter + WorkTime24;
				WorkdaysQuarter	 = WorkdaysQuarter 	+ Workdays;
				WeekendDaysQuarter	 = WeekendDaysQuarter	+ WeekendDays;
				
				CalendarDaysHalfYear1 = CalendarDaysHalfYear1 + CalendarDays;
				WorkTime40HalfYear1 = WorkTime40HalfYear1 + WorkTime40;
				WorkTime36HalfYear1 = WorkTime36HalfYear1 + WorkTime36;
				WorkTime24HalfYear1 = WorkTime24HalfYear1 + WorkTime24;
				WorkdaysHalfYear1	 = WorkdaysHalfYear1 	+ Workdays;
				WeekendDaysHalfYear1	 = WeekendDaysHalfYear1	+ WeekendDays;
				
				CalendarDaysYear = CalendarDaysYear + CalendarDays;
				WorkTime40Year = WorkTime40Year + WorkTime40;
				WorkTime36Year = WorkTime36Year + WorkTime36;
				WorkTime24Year = WorkTime24Year + WorkTime24;
				WorkdaysYear	 = WorkdaysYear 	+ Workdays;
				WeekendDaysYear	 = WeekendDaysYear	+ WeekendDays;
				
				MonthColumn = Template.GetArea("MonthColumn");
				MonthColumn.Parameters.WeekendDays = WeekendDays;
				MonthColumn.Parameters.WorkTime40 	= WorkTime40;
				MonthColumn.Parameters.WorkTime36 	= WorkTime36;
				MonthColumn.Parameters.WorkTime24 	= WorkTime24;
				MonthColumn.Parameters.CalendarDays 	= CalendarDays;
				MonthColumn.Parameters.Workdays 		= Workdays;
				MonthColumn.Parameters.MonthName 		= Format(Date(YearNumber, SelectionByMonth.CalendarMonth, 1), "DF='MMMM'");
				SpreadsheetDocument.Join(MonthColumn);
				
			EndDo;
			MonthColumn = Template.GetArea("MonthColumn");
			MonthColumn.Parameters.WeekendDays 	= WeekendDaysQuarter;
			MonthColumn.Parameters.WorkTime40 	= WorkTime40Quarter;
			MonthColumn.Parameters.WorkTime36 	= WorkTime36Quarter;
			MonthColumn.Parameters.WorkTime24 	= WorkTime24Quarter;
			MonthColumn.Parameters.CalendarDays 	= CalendarDaysQuarter;
			MonthColumn.Parameters.Workdays 		= WorkdaysQuarter;
			MonthColumn.Parameters.MonthName 		= StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = '%1 квартал'; en = 'quarter %1'; pl = 'kwartał %1';es_ES = 'trimestre %1';es_CO = 'trimestre %1';tr = 'çeyrek yıl %1';it = 'trimestre %1';de = 'Quartal %1'"), SelectionByQuarter.CalendarQuarter);
			SpreadsheetDocument.Join(MonthColumn);
			
			If SelectionByQuarter.CalendarQuarter = 2 
				Or SelectionByQuarter.CalendarQuarter = 4 Then 
				MonthColumn = Template.GetArea("MonthColumn");
				MonthColumn.Parameters.WeekendDays 	= WeekendDaysHalfYear1;
				MonthColumn.Parameters.WorkTime40 	= WorkTime40HalfYear1;
				MonthColumn.Parameters.WorkTime36 	= WorkTime36HalfYear1;
				MonthColumn.Parameters.WorkTime24 	= WorkTime24HalfYear1;
				MonthColumn.Parameters.CalendarDays 	= CalendarDaysHalfYear1;
				MonthColumn.Parameters.Workdays 		= WorkdaysHalfYear1;
				MonthColumn.Parameters.MonthName 		= StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = '%1 полугодие'; en = 'half year %1'; pl = '%1 półrocze';es_ES = '%1 medio año';es_CO = '%1 medio año';tr = '%1 yarım yıl';it = 'semestre %1';de = '%1 Halbjahr'"), SelectionByQuarter.CalendarQuarter / 2);
				SpreadsheetDocument.Join(MonthColumn);
			EndIf;
			
		EndDo;
		
		MonthColumn = Template.GetArea("MonthColumn");
		MonthColumn.Parameters.WeekendDays 	= WeekendDaysYear;
		MonthColumn.Parameters.WorkTime40 	= WorkTime40Year;
		MonthColumn.Parameters.WorkTime36 	= WorkTime36Year;
		MonthColumn.Parameters.WorkTime24 	= WorkTime24Year;
		MonthColumn.Parameters.CalendarDays 	= CalendarDaysYear;
		MonthColumn.Parameters.Workdays 		= WorkdaysYear;
		MonthColumn.Parameters.MonthName 		= StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = '%1 год'; en = 'year %1'; pl = '%1 rok';es_ES = '%1 año';es_CO = '%1 año';tr = '%1 yıl';it = 'anno %1';de = '%1 Jahr'"), Format(SelectionByYear.CalendarYear, "NG="));
		SpreadsheetDocument.Join(MonthColumn);
		
	EndDo;
	
	MonthColumn = Template.GetArea("MonthAverage");
	MonthColumn.Parameters.WorkTime40 	= WorkTime40Year;
	MonthColumn.Parameters.WorkTime36 	= WorkTime36Year;
	MonthColumn.Parameters.WorkTime24 	= WorkTime24Year;
	MonthColumn.Parameters.MonthName 		= StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = '%1 год'; en = 'year %1'; pl = '%1 rok';es_ES = '%1 año';es_CO = '%1 año';tr = '%1 yıl';it = 'anno %1';de = '%1 Jahr'"), Format(YearNumber, "NG="));
	SpreadsheetDocument.Put(MonthColumn);
	
	MonthColumn = Template.GetArea("MonthColumnAverage");
	MonthColumn.Parameters.WorkTime40 	= Format(WorkTime40Year / 12, "NFD=2; NG=0");
	MonthColumn.Parameters.WorkTime36 	= Format(WorkTime36Year / 12, "NFD=2; NG=0");
	MonthColumn.Parameters.WorkTime24 	= Format(WorkTime24Year / 12, "NFD=2; NG=0");
	MonthColumn.Parameters.MonthName 		= NStr("ru = 'Среднемесячное количество'; en = 'Average monthly count'; pl = 'Średnia miesięczna ilość';es_ES = 'Cantidad mensual media';es_CO = 'Cantidad mensual media';tr = 'Ortalama aylık miktar';it = 'Conteggio medio mensile';de = 'Durchschnittliche monatliche Menge'");
	SpreadsheetDocument.Join(MonthColumn);
	
	Return SpreadsheetDocument;
	
EndFunction

#EndRegion

#EndIf
