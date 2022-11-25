#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

// Get the recalculation parameters for the work schedule
//
// Parameters:
//  WorkSchedule - CatalogRef.Calendars
//
// Returns:
//  Structure - values of the recalculation parameters
//  Undefined - if there are no parameters for the work schedule.
//
Function GetWorkSchedulePeriodSettings(WorkSchedule) Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	WorkSchedulePeriodSettings.WorkingHoursInDay AS WorkingHoursInDay,
	|	WorkSchedulePeriodSettings.WorkingHoursInWeek AS WorkingHoursInWeek,
	|	WorkSchedulePeriodSettings.WorkingDaysInMonth AS WorkingDaysInMonth
	|FROM
	|	InformationRegister.WorkSchedulePeriodSettings AS WorkSchedulePeriodSettings
	|WHERE
	|	WorkSchedulePeriodSettings.WorkSchedule = &WorkSchedule";
	
	Query.SetParameter("WorkSchedule", WorkSchedule);
	
	Result = Query.Execute();
	
	If Result.IsEmpty() Then
		
		Return Undefined;
		
	Else
		ResultTable = Result.Unload();
		ResultStructure = New Structure("WorkingHoursInDay, WorkingHoursInWeek, WorkingDaysInMonth");
		
		FillPropertyValues(ResultStructure, ResultTable[0]);
		
		Return ResultStructure;
		
	EndIf;
	
EndFunction

#EndRegion

#EndIf