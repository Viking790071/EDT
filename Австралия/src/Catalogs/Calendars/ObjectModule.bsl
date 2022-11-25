#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If IsFolder Then
		Return;
	EndIf;
	
	InfobaseUpdate.CheckObjectProcessed("Catalog.Calendars");
	
	If Not ConsiderHolidays Then
		// If the work schedule does not consider holidays, delete preholiday intervals.
		PreholidaySchedule = WorkSchedule.FindRows(New Structure("DayNumber", 0));
		For Each ScheduleString In PreholidaySchedule Do
			WorkSchedule.Delete(ScheduleString);
		EndDo;
	EndIf;
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If IsFolder Then
		Return;
	EndIf;
	
	// If the end date is not specified, it will be picked by the business calendar.
	FillingEndDate = EndDate;
	
	DaysIncludedInSchedule = Catalogs.Calendars.DaysIncludedInSchedule(
									StartDate, 
									FillingMethod, 
									FillingTemplate, 
									FillingEndDate,
									BusinessCalendar, 
									ConsiderHolidays, 
									StartingDate);
									
	Catalogs.Calendars.WriteScheduleDataToRegister(
		Ref, DaysIncludedInSchedule, StartDate, FillingEndDate);
	
EndProcedure

#EndRegion

#EndIf