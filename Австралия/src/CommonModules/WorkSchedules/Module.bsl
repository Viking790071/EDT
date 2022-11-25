#Region Public

// Returns dates that differ from the specified date DateFrom by the number of days included in the 
// specified schedule WorkSchedule.
//
// Parameters:
//	WorkSchedule	- CatalogRef.Calendars - schedule to be used.
//	DateFrom			- Date - a date starting from which the number of days is to be calculated.
//	DaysArray		- Array - a number of days by which the start date is to be increased.
//	CalculateNextDateFromPrevious	- Boolean - shows if the next date is to be calculated from the 
//											           previous one or all dates are calculated from the passed date.
//	RaiseException - Boolean - if True, an exception is thrown if the schedule is not filled in.
//
// Returns:
//	Array, Undefined - dates increased by the number of days included in schedule WorkSchedule.
//	                       If schedule WorkSchedule is not filled in and RaiseException = False, Undefined returns.
//
Function DatesBySchedule(Val WorkSchedule, Val DateFrom, Val DaysArray, 
	Val CalculateNextDateFromPrevious = False, RaiseException = True) Export
	
	TempTablesManager = New TempTablesManager;
	
	CalendarSchedules.CreateTTDaysIncrement(TempTablesManager, DaysArray, CalculateNextDateFromPrevious);
	
	// The algorithm works as follows:
	// Get the number of days included in the schedule as of starting date.
	// For all the following years, get the offset of the number of days as a sum of the number of days in previous years.
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	
	Query.Text =
	"SELECT
	|	CalendarSchedules.Year,
	|	MAX(CalendarSchedules.DayCountInScheduleSinceYearBeginning) AS DaysInSchedule
	|INTO TTNumberOfDaysInScheduleByYear
	|FROM
	|	InformationRegister.CalendarSchedules AS CalendarSchedules
	|WHERE
	|	CalendarSchedules.ScheduleDate >= &DateFrom
	|	AND CalendarSchedules.Calendar = &WorkSchedule
	|
	|GROUP BY
	|	CalendarSchedules.Year
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	NumberOfDaysInScheduleByYears.Year,
	|	SUM(ISNULL(NumberOfDaysInPreviousYears.DaysInSchedule, 0)) AS DaysInSchedule
	|INTO TTNumberOfDaysIncludingPreviousYears
	|FROM
	|	TTNumberOfDaysInScheduleByYear AS NumberOfDaysInScheduleByYears
	|		LEFT JOIN TTNumberOfDaysInScheduleByYear AS NumberOfDaysInPreviousYears
	|		ON (NumberOfDaysInPreviousYears.Year < NumberOfDaysInScheduleByYears.Year)
	|
	|GROUP BY
	|	NumberOfDaysInScheduleByYears.Year
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(CalendarSchedules.DayCountInScheduleSinceYearBeginning) AS DayCountInScheduleSinceYearBeginning
	|INTO TTNumberOfDaysInScheduleForStartDate
	|FROM
	|	InformationRegister.CalendarSchedules AS CalendarSchedules
	|WHERE
	|	CalendarSchedules.ScheduleDate >= &DateFrom
	|	AND CalendarSchedules.Year = YEAR(&DateFrom)
	|	AND CalendarSchedules.Calendar = &WorkSchedule
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DaysIncrement.RowIndex,
	|	ISNULL(CalendarSchedules.ScheduleDate, UNDEFINED) AS DateByCalendar
	|FROM
	|	TTDayIncrement AS DaysIncrement
	|		INNER JOIN TTNumberOfDaysInScheduleForStartDate AS NumberOfDaysInScheduleForStartDate
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.CalendarSchedules AS CalendarSchedules
	|			INNER JOIN TTNumberOfDaysIncludingPreviousYears AS NumberOfDaysIncludingPreviousYears
	|			ON (NumberOfDaysIncludingPreviousYears.Year = CalendarSchedules.Year)
	|		ON (CalendarSchedules.DayCountInScheduleSinceYearBeginning = NumberOfDaysInScheduleForStartDate.DayCountInScheduleSinceYearBeginning - NumberOfDaysIncludingPreviousYears.DaysInSchedule + DaysIncrement.DaysCount)
	|			AND (CalendarSchedules.ScheduleDate >= &DateFrom)
	|			AND (CalendarSchedules.Calendar = &WorkSchedule)
	|			AND (CalendarSchedules.DayAddedToSchedule)
	|
	|ORDER BY
	|	DaysIncrement.RowIndex";
	
	Query.SetParameter("DateFrom", BegOfDay(DateFrom));
	Query.SetParameter("WorkSchedule", WorkSchedule);
	
	Selection = Query.Execute().Select();
	
	DatesArray = New Array;
	
	While Selection.Next() Do
		If Selection.DateByCalendar = Undefined Then
			ErrorMessage = NStr("ru = 'График работы ""%1"" не заполнен с даты %2 на указанное количество рабочих дней.'; en = 'Work schedule ""%1"" is not filled in from date %2 for the specified number of workdays.'; pl = 'Harmonogram pracy ""%1"" nie jest wypełniony od daty %2 na wskazaną ilość dni roboczych.';es_ES = 'El horario ""%1"" no está rellenado de la fecha %2 para la cantidad de los días laborables indicada.';es_CO = 'El horario ""%1"" no está rellenado de la fecha %2 para la cantidad de los días laborables indicada.';tr = '""%1"" Çalışma takvimi belirtilen sayıda çalışma günü için%2 tarihinden itibaren doldurulmamıştır.';it = 'La pianificazione del lavoro ""%1"" non è compilata dalla data %2 per i numeri di giorni di lavoro specificati.';de = 'Der Arbeitszeitplan ""%1"" wird nicht ab dem Datum %2 der angegebenen Anzahl von Arbeitstagen ausgefüllt.'");
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
// the specified schedule WorkSchedule.
//
// Parameters:
//	WorkSchedule	- CatalogRef.Calendars - schedule to be used.
//	DateFrom			- Date - a date starting from which the number of days is to be calculated.
//	DayCount	- Number - number of days by which the start date DateFrom is to be increased.
//	RaiseException - Boolean - if True, an exception is thrown if the schedule is not filled in.
//
// Returns:
//	Date, Undefined - a date increased by the number of days included in schedule WorkSchedule.
//	                     If schedule WorkSchedule is not filled in and RaiseException = False, Undefined returns.
//
Function DateAccordingToSchedule(Val WorkSchedule, Val DateFrom, Val DaysCount, RaiseException = True) Export
	
	DateFrom = BegOfDay(DateFrom);
	
	If DaysCount = 0 Then
		Return DateFrom;
	EndIf;
	
	DaysArray = New Array;
	DaysArray.Add(DaysCount);
	
	DatesArray = DatesBySchedule(WorkSchedule, DateFrom, DaysArray, , RaiseException);
	
	Return ?(DatesArray <> Undefined, DatesArray[0], Undefined);
	
EndFunction

// Generates work schedules for dates included in the specified schedules for the specified period.
// If the schedule for a pre-holiday day is not set, it is defined as if this day is a workday.
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
	
	TempTablesManager = New TempTablesManager;
	
	// Create a temporary schedule table.
	CreateTTWorkSchedulesForPeriod(TempTablesManager, Schedules, StartDate, EndDate);
	
	QueryText = 
	"SELECT
	|	WorkSchedules.WorkSchedule,
	|	WorkSchedules.ScheduleDate,
	|	WorkSchedules.BeginTime,
	|	WorkSchedules.EndTime
	|FROM
	|	TTWorkSchedules AS WorkSchedules";
	
	Query = New Query(QueryText);
	Query.TempTablesManager = TempTablesManager;
	
	Return Query.Execute().Unload();
	
EndFunction

// Creates temporary table TTWorkSchedules in the manager. The table contains columns matching the 
// return value of the WorkSchedulesForPeriod function.
//
// Parameters:
//  TempTablesManager - TempTablesManager - manager, in which the temporary table is created.
//	Schedules - Array - an array of items of the CatalogRef.Calendars type, for which schedules are created.
//	StartDate - Date - a start date of the period, for which schedules are to be created.
//	EndDate - Date - a period end date.
//
Procedure CreateTTWorkSchedulesForPeriod(TempTablesManager, Schedules, StartDate, EndDate) Export
	
	QueryText = 
	"SELECT
	|	FillingTemplate.Ref AS WorkSchedule,
	|	MAX(FillingTemplate.LineNumber) AS PeriodLength
	|INTO TTSchedulePeriodLength
	|FROM
	|	Catalog.Calendars.FillingTemplate AS FillingTemplate
	|WHERE
	|	FillingTemplate.Ref IN(&Calendars)
	|
	|GROUP BY
	|	FillingTemplate.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Calendars.Ref AS WorkSchedule,
	|	BusinessCalendarData.Date AS ScheduleDate,
	|	CASE
	|		WHEN BusinessCalendarData.DayKind = VALUE(Enum.BusinessCalendarDaysKinds.Preholiday)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS PreholidayDay
	|INTO TTPreHolidayDays
	|FROM
	|	InformationRegister.BusinessCalendarData AS BusinessCalendarData
	|		INNER JOIN Catalog.Calendars AS Calendars
	|		ON BusinessCalendarData.BusinessCalendar = Calendars.BusinessCalendar
	|			AND (Calendars.Ref IN (&Calendars))
	|			AND (BusinessCalendarData.Date BETWEEN &StartDate AND &EndDate)
	|			AND (BusinessCalendarData.DayKind = VALUE(Enum.BusinessCalendarDaysKinds.Preholiday))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Calendars.Ref AS WorkSchedule,
	|	BusinessCalendarData.Date AS ScheduleDate,
	|	BusinessCalendarData.ReplacementDate
	|INTO TTShiftDates
	|FROM
	|	InformationRegister.BusinessCalendarData AS BusinessCalendarData
	|		INNER JOIN Catalog.Calendars AS Calendars
	|		ON BusinessCalendarData.BusinessCalendar = Calendars.BusinessCalendar
	|			AND (Calendars.Ref IN (&Calendars))
	|			AND (BusinessCalendarData.Date BETWEEN &StartDate AND &EndDate)
	|			AND (BusinessCalendarData.ReplacementDate <> DATETIME(1, 1, 1))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CalendarSchedules.Calendar AS WorkSchedule,
	|	CalendarSchedules.ScheduleDate AS ScheduleDate,
	|	DATEDIFF(Calendars.StartingDate, CalendarSchedules.ScheduleDate, DAY) + 1 AS DaysFromStartDate,
	|	PreholidayDays.PreholidayDay,
	|	ShiftDates.ReplacementDate
	|INTO TTDaysIncludedInSchedule
	|FROM
	|	InformationRegister.CalendarSchedules AS CalendarSchedules
	|		INNER JOIN Catalog.Calendars AS Calendars
	|		ON CalendarSchedules.Calendar = Calendars.Ref
	|			AND (CalendarSchedules.Calendar IN (&Calendars))
	|			AND (CalendarSchedules.ScheduleDate BETWEEN &StartDate AND &EndDate)
	|			AND (CalendarSchedules.DayAddedToSchedule)
	|		LEFT JOIN TTPreHolidayDays AS PreholidayDays
	|		ON (PreholidayDays.WorkSchedule = CalendarSchedules.Calendar)
	|			AND (PreholidayDays.ScheduleDate = CalendarSchedules.ScheduleDate)
	|		LEFT JOIN TTShiftDates AS ShiftDates
	|		ON (ShiftDates.WorkSchedule = CalendarSchedules.Calendar)
	|			AND (ShiftDates.ScheduleDate = CalendarSchedules.ScheduleDate)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DaysIncludedInSchedule.WorkSchedule,
	|	DaysIncludedInSchedule.ScheduleDate,
	|	CASE
	|		WHEN DaysIncludedInSchedule.ModuloOperationResult = 0
	|			THEN DaysIncludedInSchedule.PeriodLength
	|		ELSE DaysIncludedInSchedule.ModuloOperationResult
	|	END AS DayNumber,
	|	DaysIncludedInSchedule.PreholidayDay
	|INTO TTDatesDayNumbers
	|FROM
	|	(SELECT
	|		DaysIncludedInSchedule.WorkSchedule AS WorkSchedule,
	|		DaysIncludedInSchedule.ScheduleDate AS ScheduleDate,
	|		DaysIncludedInSchedule.PreholidayDay AS PreholidayDay,
	|		DaysIncludedInSchedule.PeriodLength AS PeriodLength,
	|		DaysIncludedInSchedule.DaysFromStartDate - DaysIncludedInSchedule.DivisionOutputIntegerPart * DaysIncludedInSchedule.PeriodLength AS ModuloOperationResult
	|	FROM
	|		(SELECT
	|			DaysIncludedInSchedule.WorkSchedule AS WorkSchedule,
	|			DaysIncludedInSchedule.ScheduleDate AS ScheduleDate,
	|			DaysIncludedInSchedule.PreholidayDay AS PreholidayDay,
	|			DaysIncludedInSchedule.DaysFromStartDate AS DaysFromStartDate,
	|			PeriodsLength.PeriodLength AS PeriodLength,
	|			(CAST(DaysIncludedInSchedule.DaysFromStartDate / PeriodsLength.PeriodLength AS NUMBER(15, 0))) - CASE
	|				WHEN (CAST(DaysIncludedInSchedule.DaysFromStartDate / PeriodsLength.PeriodLength AS NUMBER(15, 0))) > DaysIncludedInSchedule.DaysFromStartDate / PeriodsLength.PeriodLength
	|					THEN 1
	|				ELSE 0
	|			END AS DivisionOutputIntegerPart
	|		FROM
	|			TTDaysIncludedInSchedule AS DaysIncludedInSchedule
	|				INNER JOIN Catalog.Calendars AS Calendars
	|				ON DaysIncludedInSchedule.WorkSchedule = Calendars.Ref
	|					AND (Calendars.FillingMethod = VALUE(Enum.WorkScheduleFillingMethods.ByArbitraryLengthPeriods))
	|				INNER JOIN TTSchedulePeriodLength AS PeriodsLength
	|				ON DaysIncludedInSchedule.WorkSchedule = PeriodsLength.WorkSchedule) AS DaysIncludedInSchedule) AS DaysIncludedInSchedule
	|
	|UNION ALL
	|
	|SELECT
	|	DaysIncludedInSchedule.WorkSchedule,
	|	DaysIncludedInSchedule.ScheduleDate,
	|	CASE
	|		WHEN DaysIncludedInSchedule.ReplacementDate IS NULL 
	|			THEN WEEKDAY(DaysIncludedInSchedule.ScheduleDate)
	|		ELSE WEEKDAY(DaysIncludedInSchedule.ReplacementDate)
	|	END,
	|	DaysIncludedInSchedule.PreholidayDay
	|FROM
	|	TTDaysIncludedInSchedule AS DaysIncludedInSchedule
	|		INNER JOIN Catalog.Calendars AS Calendars
	|		ON DaysIncludedInSchedule.WorkSchedule = Calendars.Ref
	|WHERE
	|	Calendars.FillingMethod = VALUE(Enum.WorkScheduleFillingMethods.ByWeeks)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	DaysIncludedInSchedule.WorkSchedule,
	|	DaysIncludedInSchedule.ScheduleDate,
	|	DaysIncludedInSchedule.DayNumber,
	|	ISNULL(PreholidayWorkSchedules.BeginTime, WorkSchedules.BeginTime) AS BeginTime,
	|	ISNULL(PreholidayWorkSchedules.EndTime, WorkSchedules.EndTime) AS EndTime
	|INTO TTWorkSchedules
	|FROM
	|	TTDatesDayNumbers AS DaysIncludedInSchedule
	|		LEFT JOIN Catalog.Calendars.WorkSchedule AS WorkSchedules
	|		ON (WorkSchedules.Ref = DaysIncludedInSchedule.WorkSchedule)
	|			AND (WorkSchedules.DayNumber = DaysIncludedInSchedule.DayNumber)
	|		LEFT JOIN Catalog.Calendars.WorkSchedule AS PreholidayWorkSchedules
	|		ON (PreholidayWorkSchedules.Ref = DaysIncludedInSchedule.WorkSchedule)
	|			AND (PreholidayWorkSchedules.DayNumber = 0)
	|			AND (DaysIncludedInSchedule.PreholidayDay)
	|
	|INDEX BY
	|	DaysIncludedInSchedule.WorkSchedule,
	|	DaysIncludedInSchedule.ScheduleDate";
	
	// To calculate a number in the cycle of arbitrary length for a day included in the schedule, use the following formula:
	// Day number = Days from starting date % Cycle length where % is modulo operation.
	
	// Modulo operation is based on the formula:
	// Dividend - Int(Dividend / Divisor) * Divisor, where Int() is an integer part extraction function.
	
	// To extract an integer part, use the construct:
	// if the result of a number rounding by rule 1.5 as 2 is larger than the original value, reduce it by 1.
	
	Query = New Query(QueryText);
	Query.TempTablesManager = TempTablesManager;
	Query.SetParameter("Calendars", Schedules);
	Query.SetParameter("StartDate", StartDate);
	Query.SetParameter("EndDate", EndDate);
	Query.Execute();
	
EndProcedure

#EndRegion

#Region Internal

// Uses business calendar data to update work schedules.
// 
//
// Parameters:
//	- UpdateConditions - value table with columns.
//		- BusinessCalendarCode - a code of business calendar whose data is changed.
//		- Year - the year, for which data is to be updated.
//
Procedure UpdateWorkSchedulesAccordingToBusinessCalendars(UpdateConditions) Export
	
	Catalogs.Calendars.UpdateWorkSchedulesAccordingToBusinessCalendars(UpdateConditions);
	
EndProcedure

// Adds work schedule catalog to the list of locked items to make schedules unavailable for changing 
// by user while updating business calendars.
//
// Parameters:
//	- LockedItems - array, names of locked item metadata.
//
Procedure FillObjectsToBlockDependentOnBusinessCalendars(ObjectsToLock) Export
	
	ObjectsToLock.Add("Catalog.Calendars");
	
EndProcedure

// Creates temporary table CalendarSchedulesTT that contains WorkSchedule data for the years listed 
// in DifferentScheduleYearsTT.
//
// Parameters:
//	- TempTablesManager - it must contain DifferentScheduleYearsTT with the Year field, the Number type (4.0).
//	- WorkSchedule - schedule to be used, type CatologRef.Calendars.
//
Procedure CreateScheduleDataTT(TempTablesManager, WorkSchedule) Export
	
	QueryText = 
	"SELECT
	|	CalendarSchedules.Year,
	|	CalendarSchedules.ScheduleDate,
	|	CalendarSchedules.DayAddedToSchedule
	|INTO TTCalendarSchedules
	|FROM
	|	InformationRegister.CalendarSchedules AS CalendarSchedules
	|		INNER JOIN TTDifferentScheduleYears AS ScheduleYears
	|		ON (ScheduleYears.Year = CalendarSchedules.Year)
	|WHERE
	|	CalendarSchedules.Calendar = &WorkSchedule";
	
	Query = New Query(QueryText);
	Query.TempTablesManager = TempTablesManager;
	Query.SetParameter("WorkSchedule", WorkSchedule);
	Query.Execute();
	
EndProcedure

// Generates a query text template embedded in the CalendarSchedules.GetWorkdayDates method.
//
Function NextDatesAccordingToWorkScheduleDefinitionQueryTextTemplate() Export
	
	Return
	"SELECT
	|	InitialDates.Date,
	|	%Function%(CalendarDates.ScheduleDate) AS NearestDate
	|FROM
	|	InitialDates AS InitialDates
	|		LEFT JOIN InformationRegister.CalendarSchedules AS CalendarDates
	|		ON (CalendarDates.ScheduleDate %ConditionSign% InitialDates.Date)
	|			AND (CalendarDates.Calendar = &Schedule)
	|			AND (CalendarDates.DayAddedToSchedule)
	|
	|GROUP BY
	|	InitialDates.Date";
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See InfobaseUpdateSSL.OnAddUpdateHandlers. 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version = "2.1.3.1";
	Handler.Procedure = "WorkSchedules.FillWorkSchedulesFillingSettings";
	
	Handler = Handlers.Add();
	Handler.Version = "2.2.2.14";
	Handler.Procedure = "WorkSchedules.FillDaysCountInScheduleFromYearBeginning";
	
	If Metadata.DataProcessors.Find("FillWorkSchedules") <> Undefined Then
		ModuleWorkSchedules = Common.CommonModule("DataProcessors.FillWorkSchedules");
		ModuleWorkSchedules.OnAddUpdateHandlers(Handlers);
	EndIf;
	
EndProcedure

// See UsersOverridable.OnDefineRolesAssignment. 
Procedure OnDefineRoleAssignment(RolesAssignment) Export
	
	// BothForUsersAndExternalUsers.
	RolesAssignment.BothForUsersAndExternalUsers.Add(
		Metadata.Roles.ReadWorkSchedules.Name);
	
EndProcedure

#EndRegion

#Region Private

// Fills in a business calendar for work schedules that were created not according to the template 
// or were created prior to business calendars.
//
Procedure FillWorkSchedulesFillingSettings() Export
	
	BusinessCalendar = CalendarSchedules.MainBusinessCalendar();
	If BusinessCalendar = Undefined Then
		// If there is no default business calendar for some reason, it is not reasonable to fill in the 
		// settings.
		Return;
	EndIf;
	
	QueryText = 
	"SELECT
	|	Calendars.Ref,
	|	Calendars.DeleteCalendarType AS CalendarKind,
	|	Calendars.BusinessCalendar
	|FROM
	|	Catalog.Calendars AS Calendars
	|WHERE
	|	Calendars.FillingMethod = VALUE(Enum.WorkScheduleFillingMethods.EmptyRef)";
	
	Query = New Query(QueryText);
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		WorkScheduleObject = Selection.Ref.GetObject();
		If Not ValueIsFilled(Selection.BusinessCalendar) Then
			// Set up the USA calendar
			WorkScheduleObject.BusinessCalendar = BusinessCalendar;
		EndIf;
		WorkScheduleObject.StartDate = Date(2012, 1, 1);
		If Not ValueIsFilled(Selection.CalendarKind) Then
			// If the calendar kind is not specified, you cannot write the exact filling setting.
			WorkScheduleObject.FillingMethod = Enums.WorkScheduleFillingMethods.ByArbitraryLengthPeriods;
			WorkScheduleObject.StartingDate = Date(2012, 1, 1);
		Else
			// Fill in the setting for a five-day or a six-day week.
			WorkScheduleObject.ConsiderHolidays = True;
			WorkScheduleObject.FillingMethod = Enums.WorkScheduleFillingMethods.ByWeeks;
			WorkdayCount = 5;
			If Selection.CalendarKind = Enums.DeleteCalendarsKinds.SixDayWeek Then
				WorkdayCount = 6;
			EndIf;
			WorkScheduleObject.FillingTemplate.Clear();
			For DayNumber = 1 To 7 Do
				NewRow = WorkScheduleObject.FillingTemplate.Add();
				NewRow.DayAddedToSchedule = DayNumber <= WorkdayCount;
			EndDo;
		EndIf;
		InfobaseUpdate.WriteData(WorkScheduleObject);
	EndDo;
	
EndProcedure

// Fills in secondary data to optimize date calculation based on calendar.
//
Procedure FillDaysCountInScheduleFromYearBeginning() Export
	
	QueryText = 
	"SELECT DISTINCT
	|	BusinessCalendarData.Date,
	|	BusinessCalendarData.Year
	|INTO TTDates
	|FROM
	|	InformationRegister.BusinessCalendarData AS BusinessCalendarData
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Dates.Year,
	|	COUNT(Dates.Date) AS DaysCount
	|INTO TTNumberOfDaysByYears
	|FROM
	|	TTDates AS Dates
	|
	|GROUP BY
	|	Dates.Year
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CalendarSchedules.Calendar,
	|	CalendarSchedules.Year,
	|	COUNT(CalendarSchedules.ScheduleDate) AS DaysCount
	|INTO TTNumberOfDaysBySchedules
	|FROM
	|	InformationRegister.CalendarSchedules AS CalendarSchedules
	|
	|GROUP BY
	|	CalendarSchedules.Calendar,
	|	CalendarSchedules.Year
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	NumberOfDaysInSchedules.Calendar,
	|	NumberOfDaysInSchedules.Year
	|INTO TTSchedulesYears
	|FROM
	|	TTNumberOfDaysBySchedules AS NumberOfDaysInSchedules
	|		INNER JOIN TTNumberOfDaysByYears AS NumberOfDaysByYears
	|		ON NumberOfDaysInSchedules.Year = NumberOfDaysByYears.Year
	|			AND NumberOfDaysInSchedules.DaysCount < NumberOfDaysByYears.DaysCount
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SchedulesYears.Calendar AS Calendar,
	|	SchedulesYears.Year AS Year,
	|	Dates.Date AS ScheduleDate,
	|	ISNULL(CalendarSchedules.DayAddedToSchedule, FALSE) AS DayAddedToSchedule
	|FROM
	|	TTSchedulesYears AS SchedulesYears
	|		INNER JOIN TTDates AS Dates
	|		ON SchedulesYears.Year = Dates.Year
	|		LEFT JOIN InformationRegister.CalendarSchedules AS CalendarSchedules
	|		ON (CalendarSchedules.Calendar = SchedulesYears.Calendar)
	|			AND (CalendarSchedules.Year = SchedulesYears.Year)
	|			AND (CalendarSchedules.ScheduleDate = Dates.Date)
	|
	|ORDER BY
	|	SchedulesYears.Calendar,
	|	SchedulesYears.Year,
	|	Dates.Date
	|TOTALS BY
	|	Calendar,
	|	Year";
	
	// Choose work schedules and years for which the DayCountInScheduleSinceYearBeginning resource value 
	// is not filled in, fill it in for them by calculating the number of days sequentially.
	
	Query = New Query(QueryText);
	SelectionBySchedule = Query.Execute().Select(QueryResultIteration.ByGroups);
	While SelectionBySchedule.Next() Do
		SelectionByYears = SelectionBySchedule.Select(QueryResultIteration.ByGroups);
		While SelectionByYears.Next() Do
			RecordSet = InformationRegisters.CalendarSchedules.CreateRecordSet();
			DayCountInScheduleSinceYearBeginning = 0;
			Selection = SelectionByYears.Select();
			While Selection.Next() Do
				If Selection.DayAddedToSchedule Then
					DayCountInScheduleSinceYearBeginning = DayCountInScheduleSinceYearBeginning + 1;
				EndIf;
				SetRow = RecordSet.Add();
				FillPropertyValues(SetRow, Selection);
				SetRow.DayCountInScheduleSinceYearBeginning = DayCountInScheduleSinceYearBeginning;
			EndDo;
			RecordSet.Filter.Calendar.Set(SelectionByYears.Calendar);
			RecordSet.Filter.Year.Set(SelectionByYears.Year);
			InfobaseUpdate.WriteData(RecordSet);
		EndDo;
	EndDo;
	
EndProcedure

#EndRegion
