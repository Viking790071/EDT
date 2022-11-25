#Region Public

// Overrides subsystem settings.
//
// Parameters:
//  Settings - Structure -
//   * Schedules - Map:
//      ** Key     - String - a schedule presentation.
//      ** Value -JobSchedule - a schedule option.
//   * StandardIntervals - Array - contains string presentations of time intervals.
Procedure OnDefineSettings(Settings) Export
	
EndProcedure

// Overrides an array of object attributes, relative to which the reminder time can be set.
// For example, you can hide attributes with internal dates or dates, for which it makes no sense to 
// set reminders: document or job date, and so on.
// 
// Parameters:
//  Source - AnyRef - a reference to the object, for which an array of attributes with dates is generated.
//  AttributesWithDates - Array - attribute names (from metadata) containing dates.
//
Procedure OnFillSourceAttributesListWithReminderDates(Source, AttributesWithDates) Export
	
EndProcedure

#EndRegion
