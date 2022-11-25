#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region ToDoList

// StandardSubsystems.ToDoList

// See ToDoListOverridable.OnDetermineToDoListHandlers. 
Procedure OnFillToDoList(ToDoList) Export
	
	If Not AccessRight("Edit", Metadata.Catalogs.Calendars) Then
		Return;
	ElsIf Not GetFunctionalOption("UsePayrollSubsystem")
			// begin Drive.FullVersion
			And Not GetFunctionalOption("UseProductionSubsystem")
			// end Drive.FullVersion
			Then
		Return;
	EndIf;
	
	CountCalendars = 0;
	IsAllCalendarsAreCurrent = AllCalendarsAreCurrent(CountCalendars);
	
	StringID = "BusinessCalendarOfCompanies";
	
	// Standard work hours
	ToDo				= ToDoList.Add();
	ToDo.ID				= StringID;
	ToDo.HasUserTasks	= Not IsAllCalendarsAreCurrent;
	ToDo.Presentation	= NStr("en = 'Standard work hours'; ru = 'Производственный календарь';pl = 'Kalendarz biznesowy';es_ES = 'Horas de trabajo estándar';es_CO = 'Horas de trabajo estándar';tr = 'Standart iş saatleri';it = 'Ore di lavoro standard';de = 'Geschäftskalender'");
	ToDo.Owner			= Metadata.Subsystems.Enterprise;
	
	ToDo				= ToDoList.Add();
	ToDo.ID				= "BusinessCalendar";
	ToDo.HasUserTasks	= Not IsAllCalendarsAreCurrent; 
	ToDo.Owner			= StringID;
	ToDo.Form			= "Catalog.Calendars.ListForm";
	ToDo.Count			= CountCalendars;
	
	If CountCalendars = 1 Then
		ToDo.Presentation	= NStr("en = 'The company''s work schedule is not filled in'; ru = 'График работы организации не заполнен';pl = 'Nie wypełniono harmonogram pracy firmy';es_ES = 'El horario de trabajo de la empresa no está rellenado';es_CO = 'El horario de trabajo de la empresa no está rellenado';tr = 'İş yerinin çalışma programı doldurulmadı';it = 'Il grafico di lavoro dell''azienda non è compilato';de = 'Der Firmenarbeitszeitplan ist nicht aufgefüllt'");
	Else
		ToDo.Presentation	= NStr("en = 'Work schedules are not filled in for companies'; ru = 'Не заполнены графики работы организаций';pl = 'Nie wypełniono harmonogramy pracy dla firm';es_ES = 'Los horarios de trabajo no se rellenan para las empresas';es_CO = 'Los horarios de trabajo no se rellenan para las empresas';tr = 'İş yerlerinin çalışma programları doldurulmadı';it = 'I grafici di lavoro non sono compilati per le aziende';de = 'Die Arbeitszeitpläne sind für Firmen nicht aufgefüllt'");
	EndIf;
	
EndProcedure

// End StandardSubsystems.ToDoList

#EndRegion

#EndRegion

#Region Private

// The function reads the work schedule data from the register.
//
// Parameters:
//	WorkSchedule	- Reference to the current catalog item.
//	YearNumber		- Number of the year for which the schedule is to be read.
//
// Return value - map where Key is a date.
//
Function ReadScheduleDataFromRegister(WorkSchedule, YearNumber) Export
	
	QueryText =
	"SELECT
	|	CalendarSchedules.ScheduleDate AS CalendarDate
	|FROM
	|	InformationRegister.CalendarSchedules AS CalendarSchedules
	|WHERE
	|	CalendarSchedules.Calendar = &WorkSchedule
	|	AND CalendarSchedules.Year = &CurrentYear
	|	AND CalendarSchedules.DayAddedToSchedule
	|
	|ORDER BY
	|	CalendarDate";
	
	Query = New Query(QueryText);
	Query.SetParameter("WorkSchedule",	WorkSchedule);
	Query.SetParameter("CurrentYear",		YearNumber);
	
	DaysIncludedInSchedule = New Map;
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		DaysIncludedInSchedule.Insert(Selection.CalendarDate, True);
	EndDo;
	
	Return DaysIncludedInSchedule;
	
EndFunction

// The procedure writes the schedule data to the register.
//
// Parameters:
//	WorkSchedule	- Reference to the current catalog item.
//	YearNumber		- Number of the year for which the schedule is to be recorded.
//	DaysIncludedInSchedule - the map of the date and the data related thereto.
//
// Returns
//	No
//
Procedure WriteScheduleDataToRegister(WorkSchedule, DaysIncludedInSchedule, StartDate, EndDate, ReplaceManualChanges = False) Export
	
	SetDays = InformationRegisters.CalendarSchedules.CreateRecordSet();
	SetDays.Filter.Calendar.Set(WorkSchedule);
	
	// Fill in the calendar by years.
	// Select the years used
	// For each year,
	// - read the set,
	// - modify it considering the written data, and
	// - write it.
	
	DataByYears = New Map;
	
	DayDate = StartDate;
	While DayDate <= EndDate Do
		DataByYears.Insert(Year(DayDate), True);
		DayDate = DayDate + 86400;
	EndDo;
	
	ManualChanges = Undefined;
	If Not ReplaceManualChanges Then
		ManualChanges = ScheduleManualChanges(WorkSchedule);
	EndIf;
	
	// Process data by years.
	For Each KeyAndValue In DataByYears Do
		Year = KeyAndValue.Key;
		
		// Read sets for the year
		SetDays.Filter.Year.Set(Year);
		SetDays.Read();
		
		// Fill in contents of the set according to the dates for fast access.
		SetRowsDays = New Map;
		For Each SetRow In SetDays Do
			SetRowsDays.Insert(SetRow.ScheduleDate, SetRow);
		EndDo;
		
		BeginningOfYear = Date(Year, 1, 1);
		EndOfYear = Date(Year, 12, 31);
		
		TraversalStart = ?(StartDate > BeginningOfYear, StartDate, BeginningOfYear);
		TraversalEnd = ?(EndDate < EndOfYear, EndDate, EndOfYear);
		
		// The data in the set should be replaced for the traversal period.
		DayDate = TraversalStart;
		While DayDate <= TraversalEnd Do
			
			If ManualChanges <> Undefined AND ManualChanges[DayDate] <> Undefined Then
				// Leave manual adjustments in the set without change.
				DayDate = DayDate + 86400;
				Continue;
			EndIf;
			
			// If the set has no row for a date, create it.
			SetRowDays = SetRowsDays[DayDate];
			If SetRowDays = Undefined Then
				SetRowDays = SetDays.Add();
				SetRowDays.Calendar = WorkSchedule;
				SetRowDays.Year = Year;
				SetRowDays.ScheduleDate = DayDate;
				SetRowsDays.Insert(DayDate, SetRowDays);
			EndIf;
			
			// If the day is included in the schedule, fill in the intervals.
			DayData = DaysIncludedInSchedule.Get(DayDate);
			If DayData = Undefined Then
				// Remove the row from the set if the day is a non-working day.
				SetDays.Delete(SetRowDays);
				SetRowsDays.Delete(DayDate);
			Else
				SetRowDays.DayAddedToSchedule = True;
			EndIf;
			DayDate = DayDate + 86400;
		EndDo;
		
		// Fill in secondary data to optimize calculations based on calendars.
		TraversalDate = BeginningOfYear;
		DayCountInScheduleSinceYearBeginning = 0;
		While TraversalDate <= EndOfYear Do
			SetRowDays = SetRowsDays[TraversalDate];
			If SetRowDays <> Undefined Then
				// The day is included in the schedule
				DayCountInScheduleSinceYearBeginning = DayCountInScheduleSinceYearBeginning + 1;
			Else
				// The day is not included in the schedule
				SetRowDays = SetDays.Add();
				SetRowDays.Calendar = WorkSchedule;
				SetRowDays.Year = Year;
				SetRowDays.ScheduleDate = TraversalDate;
			EndIf;
			SetRowDays.DayCountInScheduleSinceYearBeginning = DayCountInScheduleSinceYearBeginning;
			TraversalDate = TraversalDate + 86400;
		EndDo;
		
		SetDays.Write();
		
	EndDo;
	
EndProcedure

// Uses business calendar data to update work schedules.
// 
//
// Parameters:
//	- UpdateConditions - value table with columns.
//		- BusinessCalendarCode - a code of business calendar whose data is changed.
//		- Year - the year, for which data is to be updated.
//
Procedure UpdateWorkSchedulesAccordingToBusinessCalendars(UpdateConditions) Export
	
	// Identify schedules to be updated, get the data of these schedules, and update the data for each 
	// year.
	// 
	
	QueryText = 
		"SELECT
		|	UpdateConditions.BusinessCalendarCode,
		|	UpdateConditions.Year,
		|	DATEADD(DATETIME(1, 1, 1), YEAR, UpdateConditions.Year - 1) AS BeginningOfYear,
		|	DATEADD(DATETIME(1, 12, 31), YEAR, UpdateConditions.Year - 1) AS EndOfYear
		|INTO UpdateConditions
		|FROM
		|	&UpdateConditions AS UpdateConditions
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	Calendars.Ref AS WorkSchedule,
		|	Calendars.FillingMethod,
		|	Calendars.BusinessCalendar,
		|	Calendars.StartingDate,
		|	Calendars.ConsiderHolidays,
		|	Calendars.StartDate,
		|	Calendars.EndDate
		|INTO TTWorkSchedulesDependingOnCalendars
		|FROM
		|	Catalog.Calendars AS Calendars
		|		INNER JOIN Catalog.BusinessCalendars AS BusinessCalendars
		|		ON (BusinessCalendars.Ref = Calendars.BusinessCalendar)
		|			AND (Calendars.FillingMethod = VALUE(Enum.WorkScheduleFillingMethods.ByWeeks))
		|
		|UNION ALL
		|
		|SELECT
		|	Calendars.Ref,
		|	Calendars.FillingMethod,
		|	Calendars.BusinessCalendar,
		|	Calendars.StartingDate,
		|	Calendars.ConsiderHolidays,
		|	Calendars.StartDate,
		|	Calendars.EndDate
		|FROM
		|	Catalog.Calendars AS Calendars
		|		INNER JOIN Catalog.BusinessCalendars AS BusinessCalendars
		|		ON (BusinessCalendars.Ref = Calendars.BusinessCalendar)
		|			AND (Calendars.FillingMethod = VALUE(Enum.WorkScheduleFillingMethods.ByArbitraryLengthPeriods))
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	Calendars.WorkSchedule,
		|	UpdateConditions.Year,
		|	Calendars.FillingMethod,
		|	Calendars.BusinessCalendar,
		|	CASE
		|		WHEN Calendars.StartDate < UpdateConditions.BeginningOfYear
		|			THEN UpdateConditions.BeginningOfYear
		|		ELSE Calendars.StartDate
		|	END AS StartDate,
		|	CASE
		|		WHEN Calendars.EndDate > UpdateConditions.EndOfYear
		|			THEN UpdateConditions.EndOfYear
		|		ELSE Calendars.EndDate
		|	END AS EndDate,
		|	Calendars.StartingDate,
		|	Calendars.ConsiderHolidays
		|INTO TTWorkSchedulesByUpdateCondition
		|FROM
		|	TTWorkSchedulesDependingOnCalendars AS Calendars
		|		INNER JOIN UpdateConditions AS UpdateConditions
		|		ON (UpdateConditions.BusinessCalendarCode = Calendars.BusinessCalendar.Code)
		|			AND Calendars.StartDate <= UpdateConditions.EndOfYear
		|			AND Calendars.EndDate >= UpdateConditions.BeginningOfYear
		|			AND (Calendars.EndDate <> DATETIME(1, 1, 1))
		|
		|UNION ALL
		|
		|SELECT
		|	Calendars.WorkSchedule,
		|	UpdateConditions.Year,
		|	Calendars.FillingMethod,
		|	Calendars.BusinessCalendar,
		|	CASE
		|		WHEN Calendars.StartDate < UpdateConditions.BeginningOfYear
		|			THEN UpdateConditions.BeginningOfYear
		|		ELSE Calendars.StartDate
		|	END,
		|	UpdateConditions.EndOfYear,
		|	Calendars.StartingDate,
		|	Calendars.ConsiderHolidays
		|FROM
		|	TTWorkSchedulesDependingOnCalendars AS Calendars
		|		INNER JOIN UpdateConditions AS UpdateConditions
		|		ON (UpdateConditions.BusinessCalendarCode = Calendars.BusinessCalendar.Code)
		|			AND Calendars.StartDate <= UpdateConditions.EndOfYear
		|			AND (Calendars.EndDate = DATETIME(1, 1, 1))
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	Calendars.WorkSchedule,
		|	Calendars.Year,
		|	Calendars.FillingMethod,
		|	Calendars.BusinessCalendar,
		|	Calendars.StartDate,
		|	Calendars.EndDate,
		|	Calendars.StartingDate,
		|	Calendars.ConsiderHolidays
		|INTO TTUpdatableWorkSchedules
		|FROM
		|	TTWorkSchedulesByUpdateCondition AS Calendars
		|		LEFT JOIN InformationRegister.ManualWorkScheduleChanges AS ManualChangesForAllYears
		|		ON (ManualChangesForAllYears.WorkSchedule = Calendars.WorkSchedule)
		|			AND (ManualChangesForAllYears.Year = 0)
		|WHERE
		|	ManualChangesForAllYears.WorkSchedule IS NULL 
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	WorkSchedulesToUpdate.WorkSchedule,
		|	WorkSchedulesToUpdate.Year,
		|	WorkSchedulesToUpdate.FillingMethod,
		|	WorkSchedulesToUpdate.BusinessCalendar,
		|	WorkSchedulesToUpdate.StartDate,
		|	WorkSchedulesToUpdate.EndDate,
		|	WorkSchedulesToUpdate.StartingDate,
		|	WorkSchedulesToUpdate.ConsiderHolidays
		|FROM
		|	TTUpdatableWorkSchedules AS WorkSchedulesToUpdate
		|
		|ORDER BY
		|	WorkSchedulesToUpdate.WorkSchedule,
		|	WorkSchedulesToUpdate.Year
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	FillingTemplate.Ref AS WorkSchedule,
		|	FillingTemplate.LineNumber AS LineNumber,
		|	FillingTemplate.DayAddedToSchedule
		|FROM
		|	Catalog.Calendars.FillingTemplate AS FillingTemplate
		|WHERE
		|	FillingTemplate.Ref IN
		|			(SELECT
		|				TTUpdatableWorkSchedules.WorkSchedule
		|			FROM
		|				TTUpdatableWorkSchedules)
		|
		|ORDER BY
		|	WorkSchedule,
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	WorkSchedule.Ref AS WorkSchedule,
		|	WorkSchedule.DayNumber AS DayNumber,
		|	WorkSchedule.BeginTime,
		|	WorkSchedule.EndTime
		|FROM
		|	Catalog.Calendars.WorkSchedule AS WorkSchedule
		|WHERE
		|	WorkSchedule.Ref IN
		|			(SELECT
		|				TTUpdatableWorkSchedules.WorkSchedule
		|			FROM
		|				TTUpdatableWorkSchedules)
		|
		|ORDER BY
		|	WorkSchedule,
		|	WorkSchedule.DayNumber";
	
	Query = New Query(QueryText);
	Query.SetParameter("UpdateConditions", UpdateConditions);
	
	QueryResults = Query.ExecuteBatch();
	SelectionBySchedule = QueryResults[QueryResults.UBound() - 2].Select();
	SelectionByTemplate = QueryResults[QueryResults.UBound() - 1].Select();
	SelectionByTimetable = QueryResults[QueryResults.UBound()].Select();
	
	FillingTemplate = New ValueTable;
	FillingTemplate.Columns.Add("DayAddedToSchedule", New TypeDescription("Boolean"));
	
	WorkSchedule = New ValueTable;
	WorkSchedule.Columns.Add("DayNumber", 		New TypeDescription("Number", New NumberQualifiers(7)));
	WorkSchedule.Columns.Add("BeginTime", 	New TypeDescription("Date", , , New DateQualifiers(DateFractions.Time)));
	WorkSchedule.Columns.Add("EndTime",	New TypeDescription("Date", , , New DateQualifiers(DateFractions.Time)));
	
	While SelectionBySchedule.NextByFieldValue("WorkSchedule") Do
		FillingTemplate.Clear();
		While SelectionByTemplate.FindNext(SelectionBySchedule.WorkSchedule, "WorkSchedule") Do
			NewRow = FillingTemplate.Add();
			NewRow.DayAddedToSchedule = SelectionByTemplate.DayAddedToSchedule;
		EndDo;
		WorkSchedule.Clear();
		While SelectionByTimetable.FindNext(SelectionBySchedule.WorkSchedule, "WorkSchedule") Do
			NewInterval = WorkSchedule.Add();
			NewInterval.DayNumber			= SelectionByTimetable.DayNumber;
			NewInterval.BeginTime		= SelectionByTimetable.BeginTime;
			NewInterval.EndTime	= SelectionByTimetable.EndTime;
		EndDo;
		While SelectionBySchedule.NextByFieldValue("StartDate") Do
			// If the end date is not specified, it will be picked by the business calendar.
			FillingEndDate = SelectionBySchedule.EndDate;
			DaysIncludedInSchedule = DaysIncludedInSchedule(
									SelectionBySchedule.StartDate, 
									SelectionBySchedule.FillingMethod, 
									FillingTemplate, 
									FillingEndDate,
									SelectionBySchedule.BusinessCalendar, 
									SelectionBySchedule.ConsiderHolidays, 
									SelectionBySchedule.StartingDate);
			WriteScheduleDataToRegister(SelectionBySchedule.WorkSchedule, DaysIncludedInSchedule, SelectionBySchedule.StartDate, FillingEndDate);
		EndDo;
	EndDo;
	
EndProcedure

// Creates a set of workdays based on business calendar, filling method, and other settings.
//  
//
// Parameters:
//	- Year - year number.
//	- BusinessCalendar - business calendar by which days are defined.
//	- FillingMethod - filling method.
//	- FillingTemplate - template of filling by days.
//	- ConsiderHolidays - Boolean, if True, then public holidays will be excluded.
//	- StartDate - optional, it is specified only to fill in cycles of arbitrary length.
//
// Return value - a map where Key is a date, and value is structure array describing time intervals 
// for the specified date.
//
Function DaysIncludedInSchedule(StartDate, FillingMethod, FillingTemplate, EndDate, BusinessCalendar, ConsiderHolidays, Val StartingDate = Undefined) Export
	
	DaysIncludedInSchedule = New Map;

	If FillingTemplate.Count() = 0 Then
		Return DaysIncludedInSchedule;
	EndIf;
	
	If Not ValueIsFilled(EndDate) Then
		// If the end date is not specified, fill it in till the end of the year.
		EndDate = EndOfYear(StartDate);
		If ValueIsFilled(BusinessCalendar) Then
			// If the business calendar is specified, fill the data in until the calendar is filled.
			FillingEndDate = Catalogs.BusinessCalendars.BusinessCalendarFillingEndDate(BusinessCalendar);
			If FillingEndDate <> Undefined 
				AND FillingEndDate > EndDate Then
				EndDate = FillingEndDate;
			EndIf;
		EndIf;
	EndIf;
	
	// Fill in data on an annual basis.
	CurrentYear = Year(StartDate);
	While CurrentYear <= Year(EndDate) Do
		YearBeginDate = StartDate;
		YearEndDate = EndDate;
		AdjustStartDatesEndDates(CurrentYear, YearBeginDate, YearEndDate);	
		// Get schedule data for the year.
		If FillingMethod = Enums.WorkScheduleFillingMethods.ByWeeks Then
			DaysForYear = DaysIncludedInScheduleByWeeks(CurrentYear, BusinessCalendar, FillingTemplate, ConsiderHolidays, YearBeginDate, YearEndDate);
		Else
			DaysForYear = DaysIncludedInScheduleArbitraryLength(CurrentYear, BusinessCalendar, FillingTemplate, ConsiderHolidays, StartingDate, YearBeginDate, YearEndDate);
		EndIf;
		// Add to the shared set
		For Each KeyAndValue In DaysForYear Do
			DaysIncludedInSchedule.Insert(KeyAndValue.Key, KeyAndValue.Value);
		EndDo;
		CurrentYear = CurrentYear + 1;
	EndDo;
	
	Return DaysIncludedInSchedule;
	
EndFunction

Function DaysIncludedInScheduleByWeeks(Year, BusinessCalendar, FillingTemplate, ConsiderHolidays, Val StartDate = Undefined, Val EndDate = Undefined)
	
	// Fill in the work schedule by weeks.
	
	DaysIncludedInSchedule = New Map;
	
	FillAccordingToBusinessCalendar = ValueIsFilled(BusinessCalendar);
	
	DaysInYear = DayOfYear(Date(Year, 12, 31));
	BusinessCalendarData = Catalogs.BusinessCalendars.BusinessCalendarData(BusinessCalendar, Year);
	If FillAccordingToBusinessCalendar 
		AND BusinessCalendarData.Count() <> DaysInYear Then
		// If the business calendar is specified but filled in incorrectly, it cannot be filled in by weeks.
		Return DaysIncludedInSchedule;
	EndIf;
	
	BusinessCalendarData.Indexes.Add("Date");
	
	DayLength = 24 * 3600;
	
	DayDate = StartDate;
	While DayDate <= EndDate Do
		PublicHoliday = False;
		NonWorkingDay = False;
		DayNumber = WeekDay(DayDate);
		//If FillAccordingToBusinessCalendar AND ConsiderHolidays Then
		If FillAccordingToBusinessCalendar Then
			DayData = BusinessCalendarData.FindRows(New Structure("Date", DayDate))[0];
			If DayData.DayKind = Enums.BusinessCalendarDaysKinds.Saturday Then
				DayNumber = 6;
				NonWorkingDay = True;
			ElsIf DayData.DayKind = Enums.BusinessCalendarDaysKinds.Sunday Then
				DayNumber = 7;
				NonWorkingDay = True;
			Else
				If DayData.DayKind = Enums.BusinessCalendarDaysKinds.Holiday Then
					PublicHoliday = True;
				ElsIf DayData.DayKind = Enums.BusinessCalendarDaysKinds.NonWorkingDay Then
					NonWorkingDay = True;
				EndIf;
			EndIf;
		EndIf;
		If Not PublicHoliday AND Not NonWorkingDay Then
			DayRow = FillingTemplate[DayNumber - 1];
			If DayRow.DayAddedToSchedule Then
				DaysIncludedInSchedule.Insert(DayDate, True);
			EndIf;
		EndIf;
		DayDate = DayDate + DayLength;
	EndDo;
	
	Return DaysIncludedInSchedule;
	
EndFunction

Function DaysIncludedInScheduleArbitraryLength(Year, BusinessCalendar, FillingTemplate, ConsiderHolidays, StartingDate, Val StartDate = Undefined, Val EndDate = Undefined)
	
	DaysIncludedInSchedule = New Map;
	
	DayLength = 24 * 3600;
	
	DayDate = StartingDate;
	While DayDate <= EndDate Do
		For Each DayRow In FillingTemplate Do
			If DayRow.DayAddedToSchedule 
				AND DayDate >= StartDate Then
				DaysIncludedInSchedule.Insert(DayDate, True);
			EndIf;
			DayDate = DayDate + DayLength;
		EndDo;
	EndDo;
	
	//If Not ConsiderHolidays Then
	//	Return DaysIncludedInSchedule;
	//EndIf;
	
	// Exclude holidays.
	
	BusinessCalendarData = Catalogs.BusinessCalendars.BusinessCalendarData(BusinessCalendar, Year);
	If BusinessCalendarData.Count() = 0 Then
		Return DaysIncludedInSchedule;
	EndIf;
	
	RowsFilter = New Structure("DayKind");
	RowsFilter.DayKind = Enums.BusinessCalendarDaysKinds.Holiday;
	PublicHolidaysData = BusinessCalendarData.FindRows(RowsFilter);
	For Each DayData In PublicHolidaysData Do
		DaysIncludedInSchedule.Delete(DayData.Date);
	EndDo;
	RowsFilter.DayKind = Enums.BusinessCalendarDaysKinds.NonWorkingDay;
	PublicHolidaysData = BusinessCalendarData.FindRows(RowsFilter);
	For Each DayData In PublicHolidaysData Do
		DaysIncludedInSchedule.Delete(DayData.Date);
	EndDo;
	
	Return DaysIncludedInSchedule;
	
EndFunction

Procedure AdjustStartDatesEndDates(Year, StartDate, EndDate)
	
	BeginningOfYear = Date(Year, 1, 1);
	EndOfYear = Date(Year, 12, 31);
	
	If StartDate <> Undefined Then
		StartDate = Max(StartDate, BeginningOfYear);
	Else
		StartDate = BeginningOfYear;
	EndIf;
	
	If EndDate <> Undefined Then
		EndDate = Min(EndDate, EndOfYear);
	Else
		EndDate = EndOfYear;
	EndIf;
	
EndProcedure

// Defines dates when the specified schedule is changed manually.
//
Function ScheduleManualChanges(WorkSchedule)
	
	Query = New Query(
	"SELECT
	|	ManualChanges.WorkSchedule,
	|	ManualChanges.Year,
	|	ManualChanges.ScheduleDate,
	|	ISNULL(CalendarSchedules.DayAddedToSchedule, FALSE) AS DayAddedToSchedule
	|FROM
	|	InformationRegister.ManualWorkScheduleChanges AS ManualChanges
	|		LEFT JOIN InformationRegister.CalendarSchedules AS CalendarSchedules
	|		ON (CalendarSchedules.Calendar = ManualChanges.WorkSchedule)
	|			AND (CalendarSchedules.Year = ManualChanges.Year)
	|			AND (CalendarSchedules.ScheduleDate = ManualChanges.ScheduleDate)
	|WHERE
	|	ManualChanges.WorkSchedule = &WorkSchedule
	|	AND ManualChanges.ScheduleDate <> DATETIME(1, 1, 1)");

	Query.SetParameter("WorkSchedule", WorkSchedule);
	
	Selection = Query.Execute().Select();
	
	ManualChanges = New Map;
	While Selection.Next() Do
		ManualChanges.Insert(Selection.ScheduleDate, Selection.DayAddedToSchedule);
	EndDo;
	
	Return ManualChanges;
	
EndFunction

#Region ToDoList

Function AllCalendarsAreCurrent(CountCalendars)
	
	Result = True;
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED DISTINCT
	|	Companies.BusinessCalendar AS BusinessCalendar
	|FROM
	|	Catalog.Companies AS Companies
	|		INNER JOIN Catalog.Calendars AS Calendars
	|		ON Companies.BusinessCalendar = Calendars.Ref
	|WHERE
	|	Calendars.EndDate < &CurrentDate";
	
	Query.SetParameter("CurrentDate", BegOfDay(CurrentSessionDate()));
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	CountCalendars = SelectionDetailRecords.Count();
	
	If CountCalendars > 0 Then
		Result = False;
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion

#EndRegion

#EndIf