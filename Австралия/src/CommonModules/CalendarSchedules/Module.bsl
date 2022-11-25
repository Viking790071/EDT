#Region Public

// Returns dates that differ from the specified date DateFrom by the number of days included in the 
// specified schedule WorkSchedule.
//
// Parameters:
//	 Work schedule	 - CatalogRef.Calendars, CatalogRef.BusinessCalendars - a schedule or business 
//                    calendar to be used to calculate dates.
//	 DateFrom			- Date - a date starting from which the number of days is to be calculated.
//	 DaysArray		- Array - a number of days by which the start date is to be increased.
//	 CalculateFollowingDateFromPrevious	- Boolean - shows whether the following date is to be 
//											           calculated from the previous one or all dates are calculated from the passed date.
//	 RaiseException - Boolean - if True, throw an exception if the schedule is not filled in.
//
// Returns:
//	 Undefined, Array - an array of dates increased by the number of days included in the schedule.
//	                        If schedule WorkSchedule is not filled in and RaiseException = False, Undefined returns.
//
Function DatesByCalendar(Val WorkSchedule, Val DateFrom, Val DaysArray, Val CalculateNextDateFromPrevious = False, RaiseException = True) Export
	
	If Not ValueIsFilled(WorkSchedule) Then
		If RaiseException Then
			Raise NStr("ru = 'Не указан график работы или производственный календарь.'; en = 'Work schedule or business calendar is not specified.'; pl = 'Nie jest wskazany harmonogram pracy lub kalendarz biznesowy.';es_ES = 'No se ha indicado el horario o el calendario laboral.';es_CO = 'No se ha indicado el horario o el calendario laboral.';tr = 'Çalışma programı veya iş takvimi belirtilmedi.';it = 'La pianificazione del lavoro o il Calendario aziendale non sono specificati.';de = 'Es ist kein Arbeitszeitplan oder Produktionskalender angegeben.'");
		EndIf;
		Return Undefined;
	EndIf;
	
	If TypeOf(WorkSchedule) <> Type("CatalogRef.BusinessCalendars") Then
		If Common.SubsystemExists("StandardSubsystems.WorkSchedules") Then
			ModuleWorkSchedules = Common.CommonModule("WorkSchedules");
			Return ModuleWorkSchedules.DatesBySchedule(
				WorkSchedule, DateFrom, DaysArray, CalculateNextDateFromPrevious, RaiseException);
		EndIf;
	EndIf;
	
	TempTablesManager = New TempTablesManager;
	
	CreateTTDaysIncrement(TempTablesManager, DaysArray, CalculateNextDateFromPrevious);
	
	// The algorithm works as follows:
	// Get all calendar days coming after the start date.
	// For each of such days, calculate the number of days included in the schedule starting from the start date.
	// Select the number of days calculated that way based on the days increment table.
	
	Query = New Query;
	
	Query.TempTablesManager = TempTablesManager;
	
	// According to business calendar.
	Query.Text =
	"SELECT
	|	CalendarSchedules.Date AS ScheduleDate
	|INTO TTSubsequentScheduleDates
	|FROM
	|	InformationRegister.BusinessCalendarData AS CalendarSchedules
	|WHERE
	|	CalendarSchedules.Date >= &DateFrom
	|	AND CalendarSchedules.BusinessCalendar = &WorkSchedule
	|	AND CalendarSchedules.DayKind IN (VALUE(Enum.BusinessCalendarDaysKinds.Work), VALUE(Enum.BusinessCalendarDaysKinds.Preholiday))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SubsequentScheduleDates.ScheduleDate,
	|	COUNT(CalendarSchedules.ScheduleDate) - 1 AS NumberOfDaysInSchedule
	|INTO TTSubsequentScheduleDatesWithDayCount
	|FROM
	|	TTSubsequentScheduleDates AS SubsequentScheduleDates
	|		INNER JOIN TTSubsequentScheduleDates AS CalendarSchedules
	|		ON (CalendarSchedules.ScheduleDate <= SubsequentScheduleDates.ScheduleDate)
	|
	|GROUP BY
	|	SubsequentScheduleDates.ScheduleDate
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DaysIncrement.RowIndex,
	|	ISNULL(SubsequentDays.ScheduleDate, UNDEFINED) AS DateByCalendar
	|FROM
	|	TTDayIncrement AS DaysIncrement
	|		LEFT JOIN TTSubsequentScheduleDatesWithDayCount AS SubsequentDays
	|		ON DaysIncrement.DaysCount = SubsequentDays.NumberOfDaysInSchedule
	|
	|ORDER BY
	|	DaysIncrement.RowIndex";
	
	Query.SetParameter("DateFrom", BegOfDay(DateFrom));
	Query.SetParameter("WorkSchedule", WorkSchedule);
	
	Selection = Query.Execute().Select();
	
	DatesArray = New Array;
	
	While Selection.Next() Do
		If Selection.DateByCalendar = Undefined Then
			ErrorMessage = NStr("ru = 'Производственный календарь ""%1"" не заполнен с даты %2 на указанное количество рабочих дней.'; en = 'The ""%1"" business calendar is not filled for the period beginning from %2 and lasting the specified number of days.'; pl = 'Kalendarz biznesowy «%1» nie jest wypełniony od daty %2 nie jest wskazana ilość dni roboczych.';es_ES = 'El ""%1"" calendario laboral no está rellenado desde la fecha %2 para el número especificado de los días laborales.';es_CO = 'El ""%1"" calendario laboral no está rellenado desde la fecha %2 para el número especificado de los días laborales.';tr = '""%1"" İş takvimi belirtilen iş günü için belirtilen %2 itibaren doldurulmamıştır.';it = 'Il Calendario aziendale ""%1"" non è compilato per il periodo che va dal %2 e dura per il numero specificato di giorni.';de = 'Der Produktionskalender ""%1"" wird nicht ab dem Datum %2 der angegebenen Anzahl von Arbeitstagen ausgefüllt.'");
			If RaiseException Then
				Raise StringFunctionsClientServer.SubstituteParametersToString(ErrorMessage, WorkSchedule, Format(DateFrom, "DLF=D"));
			Else
				Return Undefined;
			EndIf;
		EndIf;
		
		DatesArray.Add(Selection.DateByCalendar);
	EndDo;
	
	Return DatesArray;
	
EndFunction

// Returns a date that differs from the specified date DateFrom by the number of days included in 
// the specified schedule or the WorkSchedule business calendar.
//
// Parameters:
//	 Work schedule	 - CatalogRef.Calendars, CatalogRef.BusinessCalendars - a schedule or business 
//                    calendar to be used to calculate a date.
//	 DateFrom			- Date - a date starting from which the number of days is to be calculated.
//	 DaysCount	- Number - a number of days by which the start date is to be increased.
//	 RaiseException - Boolean - if True, throw an exception if the schedule is not filled in.
//
// Returns:
//	 Date, Undefined - a date increased by the number of days included in the schedule.
//	                      If the selected schedule is not filled in and RaiseException = False, Undefined returns.
//
Function DateByCalendar(Val WorkSchedule, Val DateFrom, Val DaysCount, RaiseException = True) Export
	
	If Not ValueIsFilled(WorkSchedule) Then
		If RaiseException Then
			Raise NStr("ru = 'Не указан график работы или производственный календарь.'; en = 'Work schedule or business calendar is not specified.'; pl = 'Nie jest wskazany harmonogram pracy lub kalendarz biznesowy.';es_ES = 'No se ha indicado el horario o el calendario laboral.';es_CO = 'No se ha indicado el horario o el calendario laboral.';tr = 'Çalışma programı veya iş takvimi belirtilmedi.';it = 'La pianificazione del lavoro o il Calendario aziendale non sono specificati.';de = 'Es ist kein Arbeitszeitplan oder Produktionskalender angegeben.'");
		EndIf;
		Return Undefined;
	EndIf;
	
	DateFrom = BegOfDay(DateFrom);
	
	If DaysCount = 0 Then
		Return DateFrom;
	EndIf;
	
	DaysArray = New Array;
	DaysArray.Add(DaysCount);
	
	DatesArray = DatesByCalendar(WorkSchedule, DateFrom, DaysArray, , RaiseException);
	
	Return ?(DatesArray <> Undefined, DatesArray[0], Undefined);
	
EndFunction

// Defines the number of days included in the schedule for the specified period.
//
// Parameters:
//	 WorkSchedule	- CatalogRef.Calendars, CatalogRef.BusinessCalendars - a schedule or business 
//                    calendar to be used to calculate days.
//	 StartDate		- Date - a period start date.
//	 EndDate	- Date - a period end date.
//	 RaiseException - Boolean - if True, throw an exception if the schedule is not filled in.
//
// Returns:
//	 Number		 - a number of days between the start and end dates.
//	              If schedule WorkSchedule is not filled in and RaiseException = False, Undefined returns.
//
Function DateDiffByCalendar(Val WorkSchedule, Val StartDate, Val EndDate, RaiseException = True) Export
	
	If Not ValueIsFilled(WorkSchedule) Then
		If RaiseException Then
			Raise NStr("ru = 'Не указан график работы или производственный календарь.'; en = 'Work schedule or business calendar is not specified.'; pl = 'Nie jest wskazany harmonogram pracy lub kalendarz biznesowy.';es_ES = 'No se ha indicado el horario o el calendario laboral.';es_CO = 'No se ha indicado el horario o el calendario laboral.';tr = 'Çalışma programı veya iş takvimi belirtilmedi.';it = 'La pianificazione del lavoro o il Calendario aziendale non sono specificati.';de = 'Es ist kein Arbeitszeitplan oder Produktionskalender angegeben.'");
		EndIf;
		Return Undefined;
	EndIf;
	
	StartDate = BegOfDay(StartDate);
	EndDate = BegOfDay(EndDate);
	
	ScheduleDates = New Array;
	ScheduleDates.Add(StartDate);
	If Year(StartDate) <> Year(EndDate) AND EndOfDay(StartDate) <> EndOfYear(StartDate) Then
		// If dates belong to different years, add year boundaries.
		For YearNumber = Year(StartDate) To Year(EndDate) - 1 Do
			ScheduleDates.Add(Date(YearNumber, 12, 31));
		EndDo;
	EndIf;
	ScheduleDates.Add(EndDate);
	
	// Generate a query text of the temporary table containing the specified dates.
	QueryText = "";
	For Each ScheduleDate In ScheduleDates Do
		If IsBlankString(QueryText) Then
			UnionTemplate = 
			"SELECT
			|	DATETIME(%1) AS ScheduleDate
			|INTO TTScheduleDates
			|";
		Else
			UnionTemplate = 
			"UNION ALL
			|
			|SELECT
			|	DATETIME(%1)";
		EndIf;
		QueryText = QueryText + StringFunctionsClientServer.SubstituteParametersToString(UnionTemplate, Format(ScheduleDate, "DF='yyyy, mm, d'"));
	EndDo;
	
	TempTablesManager = New TempTablesManager;
	
	Query = New Query(QueryText);
	Query.TempTablesManager = TempTablesManager;
	Query.Execute();
	
	// Prepare temporary tables with initial data.
	Query.Text =
	"SELECT DISTINCT
	|	ScheduleDates.ScheduleDate
	|INTO TTDifferentScheduleDates
	|FROM
	|	TTScheduleDates AS ScheduleDates
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	YEAR(ScheduleDates.ScheduleDate) AS Year
	|INTO TTDifferentScheduleYears
	|FROM
	|	TTScheduleDates AS ScheduleDates";
	
	Query.Execute();
	
	If TypeOf(WorkSchedule) = Type("CatalogRef.BusinessCalendars") Then
		// According to business calendar.
		Query.Text = 
		"SELECT
		|	CalendarSchedules.Year,
		|	CalendarSchedules.Date AS ScheduleDate,
		|	CASE
		|		WHEN CalendarSchedules.DayKind IN (VALUE(Enum.BusinessCalendarDaysKinds.Work), VALUE(Enum.BusinessCalendarDaysKinds.Preholiday))
		|			THEN TRUE
		|		ELSE FALSE
		|	END AS DayAddedToSchedule
		|INTO TTCalendarSchedules
		|FROM
		|	InformationRegister.BusinessCalendarData AS CalendarSchedules
		|		INNER JOIN TTDifferentScheduleYears AS ScheduleYears
		|		ON (ScheduleYears.Year = CalendarSchedules.Year)
		|WHERE
		|	CalendarSchedules.BusinessCalendar = &WorkSchedule";
		Query.SetParameter("WorkSchedule", WorkSchedule);
		Query.Execute();
	Else
		// According to work schedule
		If Common.SubsystemExists("StandardSubsystems.WorkSchedules") Then
			ModuleWorkSchedules = Common.CommonModule("WorkSchedules");
			ModuleWorkSchedules.CreateScheduleDataTT(TempTablesManager, WorkSchedule);
		EndIf;
	EndIf;
	
	Query.Text =
	"SELECT
	|	ScheduleDates.ScheduleDate,
	|	COUNT(DaysIncludedInSchedule.ScheduleDate) AS DayCountInScheduleSinceYearBeginning
	|INTO TTNumberOfDaysInSchedule
	|FROM
	|	TTDifferentScheduleDates AS ScheduleDates
	|		LEFT JOIN TTCalendarSchedules AS DaysIncludedInSchedule
	|		ON (DaysIncludedInSchedule.Year = YEAR(ScheduleDates.ScheduleDate))
	|			AND (DaysIncludedInSchedule.ScheduleDate <= ScheduleDates.ScheduleDate)
	|			AND (DaysIncludedInSchedule.DayAddedToSchedule)
	|
	|GROUP BY
	|	ScheduleDates.ScheduleDate
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ScheduleDates.ScheduleDate,
	|	ISNULL(ScheduleData.DayAddedToSchedule, FALSE) AS DayAddedToSchedule,
	|	DaysIncludedInSchedule.DayCountInScheduleSinceYearBeginning
	|FROM
	|	TTScheduleDates AS ScheduleDates
	|		LEFT JOIN TTCalendarSchedules AS ScheduleData
	|		ON (ScheduleData.Year = YEAR(ScheduleDates.ScheduleDate))
	|			AND (ScheduleData.ScheduleDate = ScheduleDates.ScheduleDate)
	|		LEFT JOIN TTNumberOfDaysInSchedule AS DaysIncludedInSchedule
	|		ON (DaysIncludedInSchedule.ScheduleDate = ScheduleDates.ScheduleDate)
	|
	|ORDER BY
	|	ScheduleDates.ScheduleDate";
	
	Result = Query.Execute();
	
	If Result.IsEmpty() Then
		If RaiseException Then
			ErrorMessage = NStr("ru = 'График работы ""%1"" не заполнен на период %2.'; en = 'The ""%1"" work schedule is not filled in for period: %2.'; pl = 'Harmonogram pracy «%1» nie jest wypełniony na okres %2.';es_ES = 'El ""%1"" horario de trabajo no está rellenado para el período %2.';es_CO = 'El ""%1"" horario de trabajo no está rellenado para el período %2.';tr = '""%1"" çalışma programı %2 dönemi için doldurulmadı.';it = 'La pianificazione del lavoro ""%1"" non è compilata per il periodo: %2.';de = 'Der Arbeitszeitplan ""%1"" ist für den Zeitraum %2 nicht ausgefüllt.'");
			Raise StringFunctionsClientServer.SubstituteParametersToString(ErrorMessage, WorkSchedule, PeriodPresentation(StartDate, EndOfDay(EndDate)));
		Else
			Return Undefined;
		EndIf;
	EndIf;
	
	Selection = Result.Select();
	
	// Get selection, in which the number of days included in the schedule from the beginning of the 
	// year is defined for each original date.
	// Subtract all subsequent values from the value set as of the first selection date. The subtraction 
	// result is the number of days included in the schedule for the entire period with the minus sign.
	// If the first selection day is a workday and the next one is a weekend day, then the number of 
	// days included in the schedule is the same for these both dates. In that case, add one day to the 
	// final value for adjustment.
	
	DaysCountInSchedule = Undefined;
	AddFirstDay = False;
	
	While Selection.Next() Do
		If DaysCountInSchedule = Undefined Then
			DaysCountInSchedule = Selection.DayCountInScheduleSinceYearBeginning;
			AddFirstDay = Selection.DayAddedToSchedule;
		Else
			DaysCountInSchedule = DaysCountInSchedule - Selection.DayCountInScheduleSinceYearBeginning;
		EndIf;
	EndDo;
	
	Return - DaysCountInSchedule + ?(AddFirstDay, 1, 0);
	
EndFunction

// Defines a date of the nearest workday for each date.
//
//	Parameters:
//	  Schedule	- CatalogRef.Calendars, CatalogRef.BusinessCalendars - a schedule or business calendar 
//                    to be used for calculations.
//	  InitialDates				- Array - an array of dates (Date).
//	  GetPrevious		- Boolean - a method of getting the closest date:
//										If True, workdays preceding the ones passed in the InitialDates parameter are defined, 
//										if False, dates not earlier than the initial date are defined.
//	  RaiseException - Boolean - if True, throw an exception if the schedule is not filled in.
//	  IgnoreUnfilledSchedule - Boolean - if True, a map returns in any way.
//										Initial dates whose values are missing because of unfilled schedule will not be included.
//
//	Returns:
//	  Map, Undefined - a map, where key is a date from the passed array and value is the working date 
//									closest to it (if a working date is passed, it returns).
//									If the selected schedule is not filled in and RaiseException = False, Undefined returns.
//
Function ClosestWorkdaysDates(Schedule, InitialDates, GetPrevious = False, RaiseException = True, 
	IgnoreUnfilledSchedule = False) Export
	
	If Not ValueIsFilled(Schedule) Then
		If RaiseException Then
			Raise NStr("ru = 'Не указан график работы или производственный календарь.'; en = 'Work schedule or business calendar is not specified.'; pl = 'Nie jest wskazany harmonogram pracy lub kalendarz biznesowy.';es_ES = 'No se ha indicado el horario o el calendario laboral.';es_CO = 'No se ha indicado el horario o el calendario laboral.';tr = 'Çalışma programı veya iş takvimi belirtilmedi.';it = 'La pianificazione del lavoro o il Calendario aziendale non sono specificati.';de = 'Es ist kein Arbeitszeitplan oder Produktionskalender angegeben.'");
		EndIf;
		Return Undefined;
	EndIf;
	
	TTQueryText = "";
	FirstPart = True;
	For Each InitialDate In InitialDates Do
		If Not ValueIsFilled(InitialDate) Then
			Continue;
		EndIf;
		If Not FirstPart Then
			TTQueryText = TTQueryText + "
			|UNION ALL
			|";
		EndIf;
		TTQueryText = TTQueryText + "
		|SELECT
		|	DATETIME(" + Format(InitialDate, "DF=yyyy,mm,dd") + ")";
		If FirstPart Then
			TTQueryText = TTQueryText + " AS Date 
			|INTO InitialDates
			|";
		EndIf;
		FirstPart = False;
	EndDo;

	If IsBlankString(TTQueryText) Then
		Return New Map;
	EndIf;
	
	Query = New Query(TTQueryText);
	Query.TempTablesManager = New TempTablesManager;
	Query.Execute();
	
	If TypeOf(Schedule) = Type("CatalogRef.BusinessCalendars") Then
		QueryText = 
		"SELECT
		|	InitialDates.Date,
		|	%Function%(CalendarDates.Date) AS NearestDate
		|FROM
		|	InitialDates AS InitialDates
		|		LEFT JOIN InformationRegister.BusinessCalendarData AS CalendarDates
		|		ON (CalendarDates.Date %ConditionSign% InitialDates.Date)
		|			AND (CalendarDates.BusinessCalendar = &Schedule)
		|			AND (CalendarDates.DayKind IN (
		|			VALUE(Enum.BusinessCalendarDaysKinds.Work), 
		|			VALUE(Enum.BusinessCalendarDaysKinds.Preholiday)
		|			))
		|
		|GROUP BY
		|	InitialDates.Date";
	Else
		// According to work schedule
		If Common.SubsystemExists("StandardSubsystems.WorkSchedules") Then
			ModuleWorkSchedules = Common.CommonModule("WorkSchedules");
			QueryText = ModuleWorkSchedules.NextDatesAccordingToWorkScheduleDefinitionQueryTextTemplate();
		EndIf;
	EndIf;
	
	QueryText = StrReplace(QueryText, "%Function%", 				?(GetPrevious, "MAX", "MIN"));
	QueryText = StrReplace(QueryText, "%ConditionSign%", 			?(GetPrevious, "<=", ">="));
	
	Query.Text = QueryText;
	Query.SetParameter("Schedule", Schedule);
	
	Selection = Query.Execute().Select();
	
	WorkdaysDates = New Map;
	While Selection.Next() Do
		If ValueIsFilled(Selection.NearestDate) Then
			WorkdaysDates.Insert(Selection.Date, Selection.NearestDate);
		Else 
			If IgnoreUnfilledSchedule Then
				Continue;
			EndIf;
			If RaiseException Then
				MessageText = NStr("ru = 'Невозможно определить ближайшую рабочую дату для даты %1, возможно, график работы не заполнен.'; en = 'Cannot determine the closest working date for date %1. The work schedule might not have been filled in.'; pl = 'Nie można określić najbliższego dnia pracy dla daty %1, możliwe że harmonogram pracy nie został wypełniony.';es_ES = 'No de puede determinar el día laboral más cercando para la fecha %1, el horario de trabajo puede no estar poblado.';es_CO = 'No de puede determinar el día laboral más cercando para la fecha %1, el horario de trabajo puede no estar poblado.';tr = '%1 tarihi için en yakın iş günü belirlenemiyor. Çalışma programı doldurulmamış olabilir.';it = 'Non è possibile definire il giorno lavorativo più vicino per la data %1. La pianificazione del lavoro potrebbe non essere stato compilato.';de = 'Kann den nächsten Werktag für das Datum nicht ermitteln %1, der Arbeitszeitplan ist möglicherweise nicht ausgefüllt.'");
				Raise StringFunctionsClientServer.SubstituteParametersToString(MessageText, Format(Selection.Date, "DLF=D"));
			Else
				Return Undefined;
			EndIf;
		EndIf;
	EndDo;
	
	Return WorkdaysDates;
	
EndFunction

// Generates work schedules for dates included in the specified schedules for the specified period.
// If the schedule for a pre-holiday day is not set, it is defined as if this day is a workday.
// Note that this function requires the WorkSchedules subsystem.
//
// Parameters:
//	Schedules - Array - an array of items of the CatalogRef.Calendars type, for which schedules are created.
//	StartDate - Date - a start date of the period, for which schedules are to be created.
//	EndDate - Date - a period end date.
//
// Returns:
//   ValueTable - a table with columns:
//	  * WorkSchedule - CatalogRef.Calendars - a work schedule.
//	  * ScheduleDate - Date - a date in the WorkSchedule work schedule.
//	  * StartTime - Date - work start time on the ScheduleDate day.
//	  * EndTime - Date - work end time on the ScheduleDate day.
//
Function WorkSchedulesForPeriod(Schedules, StartDate, EndDate) Export
	
	If Common.SubsystemExists("StandardSubsystems.WorkSchedules") Then
		ModuleWorkSchedules = Common.CommonModule("WorkSchedules");
		Return ModuleWorkSchedules.WorkSchedulesForPeriod(Schedules, StartDate, EndDate);
	EndIf;
	
	Raise NStr("ru = 'Подсистема ""Графики работы"" не обнаружена.'; en = 'The Work schedules subsystem is not found.'; pl = 'Podsystem «Harmonogramy pracy» nie został znaleziony';es_ES = 'Subsistema ""Horarios de trabajo"" no encontrado.';es_CO = 'Subsistema ""Horarios de trabajo"" no encontrado.';tr = 'Çalışma programları alt sistemi bulunamadı.';it = 'Il sottosistema pianificazione del lavoro non è stato trovato.';de = 'Das Subsystem ""Arbeitszeitpläne"" wurde nicht gefunden.'");
	
EndFunction

// Creates temporary table TTWorkSchedules in the manager. The table contains columns matching the 
// return value of the WorkSchedulesForPeriod function.
// Note that this function requires the WorkSchedules subsystem.
//
// Parameters:
//  TempTablesManager - TempTablesManager - manager, in which the temporary table is created.
//	Schedules - Array - an array of items of the CatalogRef.Calendars type, for which schedules are created.
//	StartDate - Date - a start date of the period, for which schedules are to be created.
//	EndDate - Date - a period end date.
//
Procedure CreateTTWorkSchedulesForPeriod(TempTablesManager, Schedules, StartDate, EndDate) Export
	
	If Common.SubsystemExists("StandardSubsystems.WorkSchedules") Then
		ModuleWorkSchedules = Common.CommonModule("WorkSchedules");
		ModuleWorkSchedules.CreateTTWorkSchedulesForPeriod(TempTablesManager, Schedules, StartDate, EndDate);
		Return;
	EndIf;
	
	Raise NStr("ru = 'Подсистема ""Графики работы"" не обнаружена.'; en = 'The Work schedules subsystem is not found.'; pl = 'Podsystem «Harmonogramy pracy» nie został znaleziony';es_ES = 'Subsistema ""Horarios de trabajo"" no encontrado.';es_CO = 'Subsistema ""Horarios de trabajo"" no encontrado.';tr = 'Çalışma programları alt sistemi bulunamadı.';it = 'Il sottosistema pianificazione del lavoro non è stato trovato.';de = 'Das Subsystem ""Arbeitszeitpläne"" wurde nicht gefunden.'");
	
EndProcedure

// Fills in an attribute in the form if only one business calendar is used.
//
// Parameters:
//	Form - ClientApplicationForm - a form, in which the attribute is to be filled in.
//	AttributePath - String - a path to the data, for example: "Object.BusinessCalendar".
//	CRTR			- String - a taxpayer ID (tax registration reason code) used to determine a state.
//
Procedure FillBusinessCalendarInForm(Form, AttributePath, CRTR = Undefined) Export
	
	Calendar = Undefined;
	
	If Not GetFunctionalOption("UseMultipleBusinessCalendars") Then
		Calendar = SingleBusinessCalendar();
	Else
		Calendar = StateBusinessCalendar(CRTR);
	EndIf;
	
	If Calendar <> Undefined Then
		CommonClientServer.SetFormAttributeByPath(Form, AttributePath, Calendar);
	EndIf;
	
EndProcedure

// Returns a basic business calendar used in accounting.
//
// Returns:
//   CatalogRef.BusinessCalendars, Undefined - a basic business calendar or
//                                                              Undefined if it is not found.
//
Function MainBusinessCalendar() Export
		
	If Metadata.DataProcessors.Find("FillCalendarSchedules") = Undefined Then
		Return Undefined;
	EndIf;	
	
	ModuleCalendarSchedules = Common.CommonModule("DataProcessors.FillCalendarSchedules");
	Return ModuleCalendarSchedules.MainBusinessCalendar();
	
EndFunction

#Region ForCallsFromOtherSubsystems

// OnlineUserSupport.ClassifiersOperations 

// See ClassifiersOperationsOverridable.OnAddClassifiers. 
Procedure OnAddClassifiers(Classifiers) Export
	
	Specifier = Undefined;
	
	If Common.SubsystemExists("OnlineUserSupport.ClassifiersOperations") Then
		ModuleClassifiersOperations = Common.CommonModule("ClassifiersOperations");
		Specifier = ModuleClassifiersOperations.ClassifierDetails();
	EndIf;
	
	If Specifier = Undefined Then
		Return;
	EndIf;
	
	Specifier.ID = ClassifierID();
	Specifier.Description = NStr("ru = 'Производственные календари'; en = 'Business calendars'; pl = 'Kalendarze biznesowe';es_ES = 'Calendarios de los días laborales';es_CO = 'Calendarios de los días laborales';tr = 'İş takvimleri';it = 'Agende di lavoro';de = 'Geschäftskalender'");
	Specifier.AutoUpdate = True;
	Specifier.SharedData = True;
	Specifier.SharedDataProcessing = True;
	Specifier.SaveFileToCache = True;
	
	Classifiers.Add(Specifier);
	
EndProcedure

// See ClassifiersOperationsOverridable.OnImportClassifier. 
Procedure OnImportClassifier(ID, Version, Address, Processed, AdditionalParameters) Export
	
	If ID <> ClassifierID() Then
		Return;
	EndIf;
	
	LoadBusinessCalendarsData(Version, Address, Processed, AdditionalParameters);
	
EndProcedure

// End OnlineUserSupport.ClassifiersOperations

#EndRegion

#Region ObsoleteProceduresAndFunctions

// Obsolete. Use MainBusinessCalendar.
// Returns a business calendar created according to the article 112 of the Labor Code of the Russian Federation.
//
// Returns:
//   CatalogRef.BusinessCalendars, Undefined - a business calendar of the Russian Federation or
//     Undefined if it is not found.
//
Function RussianFederationBusinessCalendar() Export
		
	BusinessCalendar = Catalogs.BusinessCalendars.FindByCode("RF");
	
	If BusinessCalendar.IsEmpty() Then 
		Return Undefined;
	EndIf;

	Return BusinessCalendar;
	
EndFunction

// Obsolete. Use DatesByCalendar.
// Returns dates that differ from the specified date DateFrom by the number of days included in the 
// specified schedule WorkSchedule.
//
// Parameters:
//	 Work schedule	 - CatalogRef.Calendars, CatalogRef.BusinessCalendars - a schedule or business 
//                    calendar to be used to calculate dates.
//	 DateFrom			- Date - a date starting from which the number of days is to be calculated.
//	 DaysArray		- Array - a number of days by which the start date is to be increased.
//	 CalculateFollowingDateFromPrevious	- Boolean - shows whether the following date is to be 
//											           calculated from the previous one or all dates are calculated from the passed date.
//	 RaiseException - Boolean - if True, throw an exception if the schedule is not filled in.
//
// Returns:
//	 Undefined, Array - an array of dates increased by the number of days included in the schedule.
//	                        If schedule WorkSchedule is not filled in and RaiseException = False, Undefined returns.
//
Function GetDatesArrayByCalendar(Val WorkSchedule, Val DateFrom, Val DaysArray, Val CalculateNextDateFromPrevious = False, RaiseException = True) Export
	Return DatesByCalendar(WorkSchedule, DateFrom, DaysArray, CalculateNextDateFromPrevious, RaiseException);
EndFunction

// Obsolete. Use DateByCalendar.
// Returns a date that differs from the specified date DateFrom by the number of days included in 
// the specified schedule or the WorkSchedule business calendar.
//
// Parameters:
//	 Work schedule	 - CatalogRef.Calendars, CatalogRef.BusinessCalendars - a schedule or business 
//                    calendar to be used to calculate a date.
//	 DateFrom			- Date - a date starting from which the number of days is to be calculated.
//	 DaysCount	- Number - a number of days by which the start date is to be increased.
//	 RaiseException - Boolean - if True, throw an exception if the schedule is not filled in.
//
// Returns:
//	 Date, Undefined - a date increased by the number of days included in the schedule.
//	                      If the selected schedule is not filled in and RaiseException = False, Undefined returns.
//
Function GetDateByCalendar(Val WorkSchedule, Val DateFrom, Val DaysCount, RaiseException = True) Export
	Return DateByCalendar(WorkSchedule, DateFrom, DaysCount, RaiseException);
EndFunction

// Obsolete. Use DateDiffByCalendar.
// Defines the number of days included in the schedule for the specified period.
//
// Parameters:
//	 WorkSchedule	- CatalogRef.Calendars, CatalogRef.BusinessCalendars - a schedule or business 
//                    calendar to be used to calculate days.
//	 StartDate		- Date - a period start date.
//	 EndDate	- Date - a period end date.
//	 RaiseException - Boolean - if True, throw an exception if the schedule is not filled in.
//
// Returns:
//	 Number		 - a number of days between the start and end dates.
//	              If schedule WorkSchedule is not filled in and RaiseException = False, Undefined returns.
//
Function GetDateDiffByCalendar(Val WorkSchedule, Val StartDate, Val EndDate, RaiseException = True) Export
	Return DateDiffByCalendar(WorkSchedule, StartDate, EndDate, RaiseException);
EndFunction

// Obsolete. Use ClosestWorkdaysDates.
// Defines a date of the nearest workday for each date.
//
//	Parameters:
//	  Schedule	- CatalogRef.Calendars, CatalogRef.BusinessCalendars - a schedule or business calendar 
//                    to be used for calculations.
//	  InitialDates				- Array - an array of dates (Date).
//	  GetPrevious		- Boolean - a method of getting the closest date:
//										If True, workdays preceding the ones passed in the InitialDates parameter are defined, 
//										if False, dates not earlier than the initial date are defined.
//	  RaiseException - Boolean - if True, throw an exception if the schedule is not filled in.
//	  IgnoreUnfilledSchedule - Boolean - if True, a map returns in any way.
//										Initial dates whose values are missing because of unfilled schedule will not be included.
//
//	Returns:
//	  Map, Undefined - a map, where key is a date from the passed array and value is the working date 
//									closest to it (if a working date is passed, it returns).
//									If the selected schedule is not filled in and RaiseException = False, Undefined returns.
//
Function GetWorkdaysDates(Schedule, InitialDates, GetPrevious = False, RaiseException = True, IgnoreUnfilledSchedule = False) Export
	Return ClosestWorkdaysDates(Schedule, InitialDates, GetPrevious, RaiseException, IgnoreUnfilledSchedule);
EndFunction

#EndRegion

#EndRegion

#Region Internal

// Creates temporary table TTDaysIncrement, in which a row with item index and value (number of 
// days) is generated for each item of the DaysArray.
// 
// Parameters:
//	- TempTablesManager.
//	- DaysArray - an array, a number of days.
//	- CalculateFollowingDateFromPrevious - optional, False by default.
//
Procedure CreateTTDaysIncrement(TempTablesManager, Val DaysArray, Val CalculateNextDateFromPrevious = False) Export
	
	DaysIncrement = New ValueTable;
	DaysIncrement.Columns.Add("RowIndex", New TypeDescription("Number"));
	DaysIncrement.Columns.Add("DaysCount", New TypeDescription("Number"));
	
	DaysCount = 0;
	RowNumber = 0;
	For Each DaysRow In DaysArray Do
		DaysCount = DaysCount + DaysRow;
		
		Row = DaysIncrement.Add();
		Row.RowIndex			= RowNumber;
		If CalculateNextDateFromPrevious Then
			Row.DaysCount	= DaysCount;
		Else
			Row.DaysCount	= DaysRow;
		EndIf;
			
		RowNumber = RowNumber + 1;
	EndDo;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	
	Query.Text =
	"SELECT
	|	DaysIncrement.RowIndex,
	|	DaysIncrement.DaysCount
	|INTO TTDayIncrement
	|FROM
	|	&DaysIncrement AS DaysIncrement";
	
	Query.SetParameter("DaysIncrement",	DaysIncrement);
	
	Query.Execute();
	
EndProcedure

// Updates items related to a business calendar, for example, Work schedules.
// 
//
// Parameters:
//	ChangesTable - a table with columns.
//		- BusinessCalendarCode - a code of business calendar whose data is changed.
//		- Year - the year, for which data is to be updated.
//
Procedure DistributeBusinessCalendarsDataChanges(ChangesTable) Export
	
	CalendarSchedulesOverridable.OnUpdateBusinessCalendars(ChangesTable);
	
	If Common.DataSeparationEnabled() Then
		PlanUpdateOfDataDependentOnBusinessCalendars(ChangesTable);
		Return;
	EndIf;
	
	FillDataDependentOnBusinessCalendars(ChangesTable);
	
EndProcedure

// Updates items related to a business calendar, for example, Work schedules, in data areas.
// 
//
// Parameters:
//	ChangesTable - a table with columns.
//		- BusinessCalendarCode - a code of business calendar whose data is changed.
//		- Year - the year, for which data is to be updated.
//
Procedure FillDataDependentOnBusinessCalendars(ChangesTable) Export
	
	If Common.SubsystemExists("StandardSubsystems.WorkSchedules") Then
		ModuleWorkSchedules = Common.CommonModule("WorkSchedules");
		ModuleWorkSchedules.UpdateWorkSchedulesAccordingToBusinessCalendars(ChangesTable);
	EndIf;
	
	CalendarSchedulesOverridable.OnUpdateDataDependentOnBusinessCalendars(ChangesTable);
	
EndProcedure

// Returns the internal classifier ID for the ClassifiersOperations subsystem.
//
// Returns:
//	String - a classifier ID.
//
Function ClassifierID() Export
	Return "Calendars";
EndFunction

// Defines a version of data related to calendars built in the configuration.
//
// Returns:
//   Number - a version number.
//
Function CalendarsVersion() Export
	
	If Metadata.DataProcessors.Find("FillCalendarSchedules") = Undefined Then
		Return 0;
	EndIf;
	
	ModuleCalendarSchedules = Common.CommonModule("DataProcessors.FillCalendarSchedules");
	Return ModuleCalendarSchedules.CalendarsVersion();
	
EndFunction

// Returns the version of classifier data imported to the infobase.
//
// Returns:
//   Number - the version number of the imported data, or 0 if the classifier operations subsystem is unavailable.
//
Function LoadedCalendarsVersion() Export
	
	LoadedCalendarsVersion = Undefined;
	If Common.SubsystemExists("OnlineUserSupport.ClassifiersOperations") Then
		ModuleClassifiersOperations = Common.CommonModule("ClassifiersOperations");
		LoadedCalendarsVersion = ModuleClassifiersOperations.ClassifierVersion(ClassifierID());
	EndIf;
	
	If LoadedCalendarsVersion = Undefined Then
		LoadedCalendarsVersion = 0;
	EndIf;
	
	Return LoadedCalendarsVersion;
	
EndFunction

// Requests a file with calendar classifier data.
// Converts the retrieved file into a structure with calendar tables and their data.
// If the ClassifiersOperations subsystem is unavailable, or the classifier file cannot be retrieved, throws an exception.
//
// Returns:
//  Structure - with the following properties:
//   * BusinessCalendars - Structure - with the following properties:
//   	* TableName - String - a table name.
//   	* Data - ValueTable - a calendar table converted from XML.
//   * BusinessCalendarsData - Structure - with the following properties:
//   	* TableName - String - a table name.
//   	* Data - ValueTable - a calendar data table converted from XML.
//
Function ClassifierData() Export
	
	FilesData = Undefined;
	
	IDs = CommonClientServer.ValueInArray(ClassifierID());
	If Common.SubsystemExists("OnlineUserSupport.ClassifiersOperations") Then
		ModuleClassifiersOperations = Common.CommonModule("ClassifiersOperations");
		FilesData = ModuleClassifiersOperations.GetClassifiersFiles(IDs);
	EndIf;
	
	If FilesData = Undefined Then
		MessageText = NStr("ru = 'Не удалось получить данные календаря.
                               |Работа с классификаторами не поддерживается или отсутствует.'; 
                               |en = 'Cannot get calendar data.
                               |Classifiers operations are not supported or missing.'; 
                               |pl = 'Nie udało się otrzymać dane kalendarza.
                               |Praca z klasyfikatorami nie jest obsługiwana lub nie istnieje.';
                               |es_ES = 'No se ha podido recibir los datos de calendario.
                               |El uso de los clasificadores no se admite o no hay.';
                               |es_CO = 'No se ha podido recibir los datos de calendario.
                               |El uso de los clasificadores no se admite o no hay.';
                               |tr = 'Takvim verileri alınamadı. 
                               |Sınıflandırıcılarla çalışma desteklenmiyor veya eksik.';
                               |it = 'Impossibile prendere i dati del Calendario.
                               |Operazioni dei classificatori sono non supportate o mancanti.';
                               |de = 'Die Kalenderdaten konnten nicht abgerufen werden.
                               |Das Arbeiten mit Klassifikatoren wird nicht unterstützt oder fehlt.'");
		Raise MessageText;
	EndIf;
	
	If Not IsBlankString(FilesData.ErrorCode) Then
		EventName = NStr("ru = 'Календарные графики.Получение файла классификатора'; en = 'Calendar schedules.Get classifier file'; pl = 'Harmonogramy kalendarzowe.Pobieranie pliku klasyfikatora';es_ES = 'Horarios. Recepción del archivo del clasificador';es_CO = 'Horarios. Recepción del archivo del clasificador';tr = 'Takvim grafikleri.Sınıflandırıcı dosyasını alma';it = 'Pianificazioni calendario.Prendi il file classificatore';de = 'Kalendergrafiken. Erhalten einer Klassifikatordatei'", CommonClientServer.DefaultLanguageCode());
		WriteLogEvent(
			EventName, 
			EventLogLevel.Error,,, 
			StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Не удалось получить данные календаря. 
                      |%1'; 
                      |en = 'Cannot get calendar data.
                      |%1'; 
                      |pl = 'Nie udało się otrzymać dane kalendarza. 
                      |%1';
                      |es_ES = 'No se ha podido recibir los datos del calendario. 
                      |%1';
                      |es_CO = 'No se ha podido recibir los datos del calendario. 
                      |%1';
                      |tr = 'Takvim verileri alınamadı. 
                      |%1';
                      |it = 'Impossibile prendere dati calendario.
                      |%1';
                      |de = 'Die Kalenderdaten konnten nicht abgerufen werden.
                      |%1'"), 
				FilesData.ErrorInfo));
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Не удалось получить данные календаря.
                               |%1.'; 
                               |en = 'Cannot get calendar data.
                               |%1.'; 
                               |pl = 'Nie udało się otrzymać dane kalendarza.
                               |%1.';
                               |es_ES = 'No se ha podido recibir los datos del calendario. 
                               |%1.';
                               |es_CO = 'No se ha podido recibir los datos del calendario. 
                               |%1.';
                               |tr = 'Takvim verileri alınamadı.
                               |%1.';
                               |it = 'Impossibile prendere dati calendario.
                               |%1.';
                               |de = 'Die Kalenderdaten konnten nicht abgerufen werden.
                               |%1.'"), 
			FilesData.ErrorMessage);
		Raise MessageText;
	EndIf;
	
	RowsFilter = New Structure("ID");
	RowsFilter.ID = ClassifierID();
	FoundRows = FilesData.ClassifiersData.FindRows(RowsFilter);
	If FoundRows.Count() = 0 Then
		MessageText = NStr("ru = 'Не удалось получить данные календаря.
                               |Полученные классификаторы не содержат календарей.'; 
                               |en = 'Cannot get calendar data.
                               |Got classifiers do not contain calendars.'; 
                               |pl = 'Nie udało się otrzymać dane kalendarza.
                               |Otrzymane klasyfikatory nie zawierają kalendarzy.';
                               |es_ES = 'No se ha podido recibir los datos del calendario.
                               |Los clasificadores recibidos no contiene calendarios.';
                               |es_CO = 'No se ha podido recibir los datos del calendario.
                               |Los clasificadores recibidos no contiene calendarios.';
                               |tr = 'Takvim verileri alınamadı. 
                               |Alınan sınıflandırıcılar takvimleri içermez.';
                               |it = 'Impossibile recuperare i dati di calendario.
                               |I classificatori ricevuti non contengono calendari.';
                               |de = 'Die Kalenderdaten konnten nicht abgerufen werden.
                               |Die empfangenen Klassifikatoren enthalten keine Kalender.'");
		Raise MessageText;
	EndIf;
	
	FileInfo = FoundRows[0];
	
	If FileInfo.Version < CalendarsVersion() Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Не удалось обработать полученные данные календаря из-за конфликта версий.
                  |Версия календарей
                  |- полученного классификатора %1, 
                  |- встроенных в конфигурацию %2, 
                  |- загруженного ранее классификатора %3.'; 
                  |en = 'Cannot process got calendar data due to version conflict.
                  |Calendar version:
                  |- of got classifier %1
                  |- of built-in configuration %2
                  |- of previously imported classifier %3.'; 
                  |pl = 'Nie udało się przetworzyć otrzymane dane kalendarza z powodu konfliktu wersji.
                  |Wersja kalendarzy
                  |- otrzymanego klasyfikatora %1, 
                  |- wbudowanych w konfigurację %2, 
                  |- pobranego wcześniej klasyfikatora %3.';
                  |es_ES = 'No se ha podido procesar los datos recibidos del calendario a causa del conflicto de las versiones.
                  |La versión de calendarios
                  |- recibido del clasificador %1, 
                  |- integrados en la configuración %2, 
                  |- descargado anteriormente del clasificador %3.';
                  |es_CO = 'No se ha podido procesar los datos recibidos del calendario a causa del conflicto de las versiones.
                  |La versión de calendarios
                  |- recibido del clasificador %1, 
                  |- integrados en la configuración %2, 
                  |- descargado anteriormente del clasificador %3.';
                  |tr = 'Sürüm çakışması nedeniyle alınan takvim verileri işlenemedi.
                  | Takvimler sürümü %3- alınan %1sınıflandırıcının
                  | - yapılandırmada yerleşik%2, -
                  | daha önce yüklenen sınıflandırıcıdan
                  |.';
                  |it = 'Impossibile elaborare i dati di calendario ricevuti a causa di un conflitto di versioni.
                  |Versione calendario:
                  |- del classificatore ricevuto %1
                  |- della configurazione integrata %2
                  |- dei classificatori importati precedentemente %3.';
                  |de = 'Aufgrund eines Versionskonflikts war es nicht möglich, die Kalenderdaten zu verarbeiten.
                  |Die Kalenderversion
                  |- empfangener Klassifikator%1,
                  |- eingebaut in die Konfiguration%2,
                  |- zuvor geladene Klassifikator%3.'"),
			FileInfo.Version,
			CalendarsVersion(),
			LoadedCalendarsVersion());
		Raise MessageText;
	EndIf;
	
	Try
		ClassifierData = ClassifierFileData(FileInfo.FileAddress);
	Except
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Не удалось обработать полученные данные календаря.
                  |%1.'; 
                  |en = 'Cannot process got calendar data.
                  |%1.'; 
                  |pl = 'Nie udało się przetworzyć otrzymane dane kalendarza.
                  |%1.';
                  |es_ES = 'No se ha podido procesar los datos recibidos del calendario.
                  |%1.';
                  |es_CO = 'No se ha podido procesar los datos recibidos del calendario.
                  |%1.';
                  |tr = 'Takvim verileri işlenemedi. 
                  |%1';
                  |it = 'Impossibile elaborare i dati del calendario ricevuti.
                  |%1.';
                  |de = 'Fehler beim Verarbeiten der empfangenen Kalenderdaten.
                  |%1.'"),
			BriefErrorDescription(ErrorInfo()));
		Raise MessageText;
	EndTry;
	
	Return ClassifierData;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See InfobaseUpdateSSL.OnAddUpdateHandlers. 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.InitialFilling = True;
	Handler.Procedure = "CalendarSchedules.UpdateBusinessCalendars";
	Handler.SharedData = True;
	
	Handler = Handlers.Add();
	Handler.Version = "2.3.1.2";
	Handler.Procedure = "CalendarSchedules.DeleteInvalidDataFromBusinessCalendar";
	Handler.ExecutionMode = "Exclusive";
	Handler.SharedData = True;
	
	Handler = Handlers.Add();
	Handler.Version = "3.0.1.66";
	Handler.Procedure = "CalendarSchedules.UpdateDependentBusinessCalendarsData";
	Handler.ExecutionMode = "Seamless";
	Handler.SharedData = True;
	
	Handler = Handlers.Add();
	Handler.Version = "3.0.1.102";
	Handler.Procedure = "CalendarSchedules.UpdateMultipleBusinessCalendarsUsage";
	Handler.ExecutionMode = "Seamless";
	Handler.SharedData = True;
	
	Handler = Handlers.Add();
	Handler.Version = BusinessCalendarsUpdateVersion();
	Handler.Procedure = "CalendarSchedules.UpdateBusinessCalendars";
	Handler.ExecutionMode = "Seamless";
	Handler.SharedData = True;
	
	Handler = Handlers.Add();
	Handler.Version = BusinessCalendarsDataUpdateVersion();
	Handler.Procedure = "CalendarSchedules.UpdateBusinessCalendarsData";
	Handler.ExecutionMode = "Seamless";
	Handler.SharedData = True;
	
	If Not Common.DataSeparationEnabled() Then
		Handler = Handlers.Add();
		Handler.Version = BusinessCalendarsDataUpdateVersion();
		Handler.Procedure = "CalendarSchedules.UpdateDataDependentOnBusinessCalendars";
		Handler.DeferredProcessingQueue = 1;
		Handler.UpdateDataFillingProcedure = "CalendarSchedules.FillBusinessCalendarDependentDataUpdateData";
		Handler.ExecutionMode = "Deferred";
		Handler.RunAlsoInSubordinateDIBNodeWithFilters = True;
		Handler.ObjectsToRead = "InformationRegister.BusinessCalendarData";
		Handler.ObjectsToChange = "InformationRegister.BusinessCalendarData";
		Handler.CheckProcedure = "InfobaseUpdate.DataUpdatedForNewApplicationVersion";
		Handler.ID = New UUID("b1082291-b482-418f-82ab-3c96e93072cc");
		Handler.Comment = NStr("ru = 'Обновление графиков работы и др. данных, зависимых от производственных календарей.'; en = 'Update work schedules and other data depending on business calendars.'; pl = 'Aktualizacja harmonogramów pracy i in. danych, zależących od kalendarzy produkcyjnych.';es_ES = 'La actualización de los horarios y otros datos que dependen de los calendarios laborales.';es_CO = 'La actualización de los horarios y otros datos que dependen de los calendarios laborales.';tr = 'Çalışma programlarını ve diğer verileri iş takvimlerine göre güncelle.';it = 'Aggiorna le pianificazioni lavoro e altri dati a seconda dei calendari aziendali.';de = 'Aktualisierung von Arbeitszeitplänen und anderen Daten in Abhängigkeit von Produktionskalendern.'");
		FillObjectsToBlockDependentOnBusinessCalendars(Handler);
	EndIf;
	
EndProcedure

// See UsersOverridable.OnDefineRolesAssignment. 
Procedure OnDefineRoleAssignment(RolesAssignment) Export
	
	// ForSystemUsersOnly.
	RolesAssignment.ForSystemUsersOnly.Add(
		Metadata.Roles.AddEditCalendarSchedules.Name);
	
EndProcedure

// See ExportImportDataOverridable.OnFillCommonDataTypesSupportingReferenceComparisonOnImport. 
Procedure OnFillCommonDataTypesSupportingRefMappingOnExport(Types) Export
	
	Types.Add(Metadata.Catalogs.BusinessCalendars);
	
EndProcedure

// See SaaSOverridable.OnEnableDataSeparation. 
Procedure OnEnableSeparationByDataAreas() Export
	
	UpdateBusinessCalendars();
	
EndProcedure

#EndRegion

#Region Private

// Gets a single business calendar in the infobase.
//
Function SingleBusinessCalendar()
	
	UsedCalendars = Catalogs.BusinessCalendars.BusinessCalendarsList();
	
	If UsedCalendars.Count() = 1 Then
		Return UsedCalendars[0];
	EndIf;
	
EndFunction

// Defines a state business calendar by CRTR.
//
Function StateBusinessCalendar(CRTR)
	
	If Metadata.DataProcessors.Find("FillCalendarSchedules") = Undefined Then
		Return Undefined;
	EndIf;	
	
	ModuleCalendarSchedules = Common.CommonModule("DataProcessors.FillCalendarSchedules");
	Return ModuleCalendarSchedules.StateBusinessCalendar(CRTR);
	
EndFunction

Procedure LoadBusinessCalendarsData(Version, Address, Processed, AdditionalParameters)
	
	If Version <= CalendarsVersion() Then
		Processed = True;
		Return;
	EndIf;
	
	ClassifierData = ClassifierFileData(Address);
	
	// Update the list of business calendars.
	CalendarsTable = ClassifierData["BusinessCalendars"].Data;
	Catalogs.BusinessCalendars.UpdateBusinessCalendars(CalendarsTable);
	
	// Update business calendar data.
	XMLData = ClassifierData["BusinessCalendarsData"];
	DataTable = Catalogs.BusinessCalendars.BusinessCalendarsDataFromXML(XMLData, CalendarsTable);
	ChangesTable = Catalogs.BusinessCalendars.UpdateBusinessCalendarsData(DataTable);
	
	CalendarSchedulesOverridable.OnUpdateBusinessCalendars(ChangesTable);
	
	// Include changes table in additional parameters to update data areas.
	UpdateParameters = New Structure("ChangesTable");
	UpdateParameters.ChangesTable = ChangesTable;
	AdditionalParameters.Insert(ClassifierID(), UpdateParameters);
	
	Processed = True;
	
EndProcedure

Function ClassifierFileData(Address)
	
	ClassifierData = New Structure(
		"BusinessCalendars,
		|BusinessCalendarsData");
	
	PathToFile = GetTempFileName();
	BinaryData = GetFromTempStorage(Address);
	BinaryData.Write(PathToFile);
	
	XMLReader = New XMLReader;
	XMLReader.OpenFile(PathToFile);
	XMLReader.MoveToContent();
	CheckItemStart(XMLReader, "CalendarSuppliedData");
	XMLReader.Read();
	CheckItemStart(XMLReader, "Calendars");
	
	ClassifierData.BusinessCalendars = Common.ReadXMLToTable(XMLReader);
	
	XMLReader.Read();
	CheckItemEnd(XMLReader, "Calendars");
	XMLReader.Read();
	CheckItemStart(XMLReader, "CalendarData");
	
	ClassifierData.BusinessCalendarsData = Common.ReadXMLToTable(XMLReader);
	
	XMLReader.Close();
	DeleteFiles(PathToFile);
	
	Return ClassifierData;
	
EndFunction

Procedure CheckItemStart(Val XMLReader, Val Name)
	
	If XMLReader.NodeType <> XMLNodeType.StartElement Or XMLReader.Name <> Name Then
		EventName = NStr("ru = 'Календарные графики.Обработка файла классификатора'; en = 'Calendar schedules.Process classifier file'; pl = 'Harmonogramy kalendarzowe.Przetwarzanie pliku klasyfikatora';es_ES = 'Horarios.Procesamiento del archivo del clasificador';es_CO = 'Horarios.Procesamiento del archivo del clasificador';tr = 'Takvim grafikleri.Sınıflandırıcı dosyasını işleme';it = 'Pianificazioni calendario.Elaborazione file classificatore';de = 'Kalendergrafiken. Verarbeitung der Klassifikatordatei'", CommonClientServer.DefaultLanguageCode());
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Неверный формат файла данных. Ожидается начало элемента %1'; en = 'Incorrect format of the data file. Start of the %1 item is expected'; pl = 'Nieprawidłowy format pliku danych. Oczekiwany jest początek elementu %1';es_ES = 'Formato incorrecto del archivo de datos. Inicio del artículo %1 está esperado';es_CO = 'Formato incorrecto del archivo de datos. Inicio del artículo %1 está esperado';tr = 'Yanlış veri dosyası formatı. %1 öğesinin başlaması bekleniyor';it = 'Formato non corretto del file di dati. L''inizio dell''elemento %1 è atteso';de = 'Falsches Format der Datendatei. Der Start des Artikels %1 wird erwartet'"), 
			Name);
		WriteLogEvent(EventName, EventLogLevel.Error, , , MessageText);
		Raise MessageText;
	EndIf;
	
EndProcedure

Procedure CheckItemEnd(Val XMLReader, Val Name)
	
	If XMLReader.NodeType <> XMLNodeType.EndElement Or XMLReader.Name <> Name Then
		EventName = NStr("ru = 'Календарные графики.Обработка файла классификатора'; en = 'Calendar schedules.Process classifier file'; pl = 'Harmonogramy kalendarzowe.Przetwarzanie pliku klasyfikatora';es_ES = 'Horarios.Procesamiento del archivo del clasificador';es_CO = 'Horarios.Procesamiento del archivo del clasificador';tr = 'Takvim grafikleri.Sınıflandırıcı dosyasını işleme';it = 'Pianificazioni calendario.Elaborazione file classificatore';de = 'Kalendergrafiken. Verarbeitung der Klassifikatordatei'", CommonClientServer.DefaultLanguageCode());
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Неверный формат файла данных. Ожидается конец элемента %1'; en = 'Incorrect format of the data file. End of the %1 item is expected'; pl = 'Nieprawidłowy format pliku danych. Oczekiwany jest koniec elementu %1';es_ES = 'Formato incorrecto del archivo de datos. Final del artículo %1 está esperado';es_CO = 'Formato incorrecto del archivo de datos. Final del artículo %1 está esperado';tr = 'Yanlış veri dosyası formatı. %1 öğesinin sona ermesi bekleniyor';it = 'Formato non corretto del file dati. È prevista la fine dell''elemento %1';de = 'Falsches Format der Datendatei. Ende des Artikels %1 wird erwartet'"), 
			Name);
		WriteLogEvent(EventName, EventLogLevel.Error, , , MessageText);
		Raise MessageText;
	EndIf;
	
EndProcedure

Function BusinessCalendarsUpdateVersion()
	
	If Metadata.DataProcessors.Find("FillCalendarSchedules") = Undefined Then
		Return "1.0.0.1";
	EndIf;	
	
	ModuleCalendarSchedules = Common.CommonModule("DataProcessors.FillCalendarSchedules");
	Return ModuleCalendarSchedules.BusinessCalendarsUpdateVersion();
	
EndFunction

Function BusinessCalendarsDataUpdateVersion()
	
	If Metadata.DataProcessors.Find("FillCalendarSchedules") = Undefined Then
		Return "1.0.0.1";
	EndIf;	
	
	ModuleCalendarSchedules = Common.CommonModule("DataProcessors.FillCalendarSchedules");
	Return ModuleCalendarSchedules.BusinessCalendarsDataUpdateVersion();
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Updating an infobase.

// Updates the Business calendars catalog from the template with the same name.
//
Procedure UpdateBusinessCalendars() Export
	
	If Common.IsStandaloneWorkplace() Then
		Return;
	EndIf;
	
	BuiltInCalendarsVersion = CalendarsVersion();
	If BuiltInCalendarsVersion <= LoadedCalendarsVersion() Then
		Return;
	EndIf;
	
	CalendarsTable = Catalogs.BusinessCalendars.BusinessCalendarsFromTemplate();
	
	If CalendarsTable.Count() = 0 Then
		Return;
	EndIf;
	
	Catalogs.BusinessCalendars.UpdateBusinessCalendars(CalendarsTable);
	UpdateMultipleBusinessCalendarsUsage();
	
	FillBusinessCalendarsDataOnUpdate();
	
	If Common.SubsystemExists("OnlineUserSupport.ClassifiersOperations") Then
		ModuleClassifiersOperations = Common.CommonModule("ClassifiersOperations");
		ModuleClassifiersOperations.SetClassifierVersion(ClassifierID(), BuiltInCalendarsVersion);
	EndIf;
	
EndProcedure

// Updates business calendar data from a template.
//  BusinessCalendarsData.
//
Procedure UpdateBusinessCalendarsData() Export
	
	If Common.IsStandaloneWorkplace() Then
		Return;
	EndIf;
	
	BuiltInCalendarsVersion = CalendarsVersion();
	If BuiltInCalendarsVersion <= LoadedCalendarsVersion() Then
		Return;
	EndIf;
	
	FillBusinessCalendarsDataOnUpdate();
	
	If Common.SubsystemExists("OnlineUserSupport.ClassifiersOperations") Then
		ModuleClassifiersOperations = Common.CommonModule("ClassifiersOperations");
		ModuleClassifiersOperations.SetClassifierVersion(ClassifierID(), BuiltInCalendarsVersion);
	EndIf;
	
EndProcedure

// Updates data of business calendars dependent on the basic ones.
//
Procedure UpdateDependentBusinessCalendarsData() Export
	
	If Common.IsStandaloneWorkplace() Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.SetParameter("Year", 2018);
	Query.Text = 
		"SELECT
		|	DependentCalendars.Ref AS Calendar,
		|	DependentCalendars.BasicCalendar AS BasicCalendar
		|INTO TTDependentCalendars
		|FROM
		|	Catalog.BusinessCalendars AS DependentCalendars
		|WHERE
		|	DependentCalendars.BasicCalendar <> VALUE(Catalog.BusinessCalendars.EmptyRef)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT DISTINCT
		|	CalendarData.BusinessCalendar AS BusinessCalendar,
		|	CalendarData.Year AS Year
		|INTO TTCalendarYears
		|FROM
		|	InformationRegister.BusinessCalendarData AS CalendarData
		|WHERE
		|	CalendarData.Year >= &Year
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT DISTINCT
		|	DependentCalendars.BasicCalendar AS BasicCalendar,
		|	DependentCalendars.BasicCalendar.Code AS BusinessCalendarCode,
		|	BasicCalendarData.Year AS Year
		|FROM
		|	TTDependentCalendars AS DependentCalendars
		|		INNER JOIN TTCalendarYears AS BasicCalendarData
		|		ON (BasicCalendarData.BusinessCalendar = DependentCalendars.BasicCalendar)
		|		LEFT JOIN TTCalendarYears AS DependentCalendarData
		|		ON (DependentCalendarData.BusinessCalendar = DependentCalendars.Calendar)
		|			AND (DependentCalendarData.Year = BasicCalendarData.Year)
		|WHERE
		|	DependentCalendarData.Year IS NULL";
	
	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	ChangesTable = QueryResult.Unload();
	Catalogs.BusinessCalendars.UpdateDependentBusinessCalendarsData(ChangesTable);
	
	If Common.DataSeparationEnabled() Then
		PlanUpdateOfDataDependentOnBusinessCalendars(ChangesTable);
		Return;
	EndIf;
	
	HandlerParameters = InfobaseUpdateInternal.DeferredUpdateHandlerParameters(
		"CalendarSchedules.UpdateDataDependentOnBusinessCalendars");
	If HandlerParameters <> Undefined AND HandlerParameters.Property("ChangesTable") Then
		CommonClientServer.SupplementTable(ChangesTable, HandlerParameters.ChangesTable);
	EndIf;
	
	HandlerParameters = New Structure("ChangesTable");
	HandlerParameters.ChangesTable = ChangesTable;
	InfobaseUpdateInternal.WriteDeferredUpdateHandlerParameters(
		"CalendarSchedules.UpdateDataDependentOnBusinessCalendars", HandlerParameters);
	
EndProcedure

// Updates data dependent on business calendars.
//
Procedure UpdateDataDependentOnBusinessCalendars(UpdateParameters) Export
	
	If Not UpdateParameters.Property("ChangesTable") Then
		UpdateParameters.ProcessingCompleted = True;
		Return;
	EndIf;
	
	ChangesTable = UpdateParameters.ChangesTable;
	ChangesTable.GroupBy("BusinessCalendarCode, Year");
	
	FillDataDependentOnBusinessCalendars(ChangesTable);
	
	UpdateParameters.ProcessingCompleted = True;
	
EndProcedure

Procedure FillBusinessCalendarDependentDataUpdateData(UpdateParameters) Export
	
EndProcedure

Procedure FillObjectsToBlockDependentOnBusinessCalendars(Handler)
	
	ObjectsToLock = New Array;
	
	If Common.SubsystemExists("StandardSubsystems.WorkSchedules") Then
		ModuleWorkSchedules = Common.CommonModule("WorkSchedules");
		ModuleWorkSchedules.FillObjectsToBlockDependentOnBusinessCalendars(ObjectsToLock);
	EndIf;
	
	CalendarSchedulesOverridable.OnFillObjectsToBlockDependentOnBusinessCalendars(ObjectsToLock);
	
	Handler.ObjectsToLock = StrConcat(ObjectsToLock, ",");
	
EndProcedure

// The procedure updates data dependent on business calendars for all data areas.
// 
//
Procedure PlanUpdateOfDataDependentOnBusinessCalendars(Val UpdateConditions)
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.CalendarSchedulesSaaS") Then
		ModuleCalendarSchedulesInternalSaaS = Common.CommonModule("CalendarSchedulesInternalSaaS");
		ModuleCalendarSchedulesInternalSaaS.PlanUpdateOfDataDependentOnBusinessCalendars(UpdateConditions);
	EndIf;
	
EndProcedure

Procedure FillBusinessCalendarsDataOnUpdate()
	
	DataTable = Catalogs.BusinessCalendars.BusinessCalendarsDataFromTemplate();
	
	// Update business calendar data.
	ChangesTable = Catalogs.BusinessCalendars.UpdateBusinessCalendarsData(DataTable);
	
	If Common.DataSeparationEnabled() Then
		PlanUpdateOfDataDependentOnBusinessCalendars(ChangesTable);
		Return;
	EndIf;

	HandlerParameters = InfobaseUpdateInternal.DeferredUpdateHandlerParameters(
		"CalendarSchedules.UpdateDataDependentOnBusinessCalendars");
	If HandlerParameters <> Undefined AND HandlerParameters.Property("ChangesTable") Then
		CommonClientServer.SupplementTable(ChangesTable, HandlerParameters.ChangesTable);
	EndIf;
	
	HandlerParameters = New Structure("ChangesTable");
	HandlerParameters.ChangesTable = ChangesTable;
	InfobaseUpdateInternal.WriteDeferredUpdateHandlerParameters(
		"CalendarSchedules.UpdateDataDependentOnBusinessCalendars", HandlerParameters);
	
EndProcedure

// Sets a value of the constant defining usage of multiple business calendars.
//
Procedure UpdateMultipleBusinessCalendarsUsage() Export
	
	If Common.IsStandaloneWorkplace() Then
		Return;
	EndIf;
	
	UseMultipleCalendars = Catalogs.BusinessCalendars.BusinessCalendarsList().Count() <> 1;
	If UseMultipleCalendars <> GetFunctionalOption("UseMultipleBusinessCalendars") Then
		Constants.UseMultipleBusinessCalendars.Set(UseMultipleCalendars);
	EndIf;
	
EndProcedure

// Deletes mistakenly added information register records, in which dates not referring to year data are mentioned.
//
Procedure DeleteInvalidDataFromBusinessCalendar() Export
	
	If Common.IsStandaloneWorkplace() Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = New TempTablesManager;
	
	Query.Text = 
		"SELECT DISTINCT
		|	BusinessCalendarData.BusinessCalendar,
		|	BusinessCalendarData.Year
		|INTO TTInvalidData
		|FROM
		|	InformationRegister.BusinessCalendarData AS BusinessCalendarData
		|WHERE
		|	BusinessCalendarData.Year <> YEAR(BusinessCalendarData.Date)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	CalendarData.BusinessCalendar,
		|	CalendarData.Date,
		|	CalendarData.Year,
		|	CalendarData.DayKind,
		|	CalendarData.ReplacementDate
		|FROM
		|	InformationRegister.BusinessCalendarData AS CalendarData
		|		INNER JOIN TTInvalidData AS InvalidData
		|		ON (InvalidData.BusinessCalendar = CalendarData.BusinessCalendar)
		|			AND (InvalidData.Year = CalendarData.Year)
		|			AND (YEAR(CalendarData.Date) = CalendarData.Year)
		|
		|ORDER BY
		|	CalendarData.BusinessCalendar,
		|	CalendarData.Year";
		
	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then 
		Return;
	EndIf;
	
	Selection = QueryResult.Select();
	While Selection.NextByFieldValue("BusinessCalendar") Do
		While Selection.NextByFieldValue("Year") Do
			RecordSet = InformationRegisters.BusinessCalendarData.CreateRecordSet();
			While Selection.Next() Do
				FillPropertyValues(RecordSet.Add(), Selection);
			EndDo;
			RecordSet.Filter.BusinessCalendar.Set(Selection.BusinessCalendar);
			RecordSet.Filter.Year.Set(Selection.Year);
			RecordSet.DataExchange.Load = True;
			RecordSet.Write();
		EndDo;
	EndDo;
	
	// Update related work schedules.
	Query.Text = 
		"SELECT
		|	BusinessCalendars.Code AS BusinessCalendarCode,
		|	InvalidData.Year
		|FROM
		|	TTInvalidData AS InvalidData
		|		INNER JOIN Catalog.BusinessCalendars AS BusinessCalendars
		|		ON InvalidData.BusinessCalendar = BusinessCalendars.Ref";
	
	DataTable = Query.Execute().Unload();
	DistributeBusinessCalendarsDataChanges(DataTable);
		
EndProcedure

#EndRegion
