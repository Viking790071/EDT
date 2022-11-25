#Region Public

#Region ObsoleteProceduresAndFunctions

// Obsolete. Use UserRemindersOverridable.OnFillSourceAttributesListWithReminderDates().
//
// Overrides an array of object attributes, relative to which the reminder time can be set.
// For example, you can hide attributes with internal dates or dates, for which it makes no sense to 
// set reminders: document or job date, and so on.
// 
// Parameters:
//  Source - AnyRef - a reference to the object, for which an array of attributes with dates is generated.
//  AttributesArray - Array - attribute names (from metadata) containing dates.
//
Procedure OnFillSourceAttributesListWithReminderDates(Source, AttributesArray) Export
	
EndProcedure

// Obsolete. Use UserRemindersOverridable.OnDefineSettings().
//
// Overrides schedule options to be selected by a user.
//
// Parameters:
//  Schedules - Map - a collection of schedules:
//    * Key     - String - a schedule presentation.
//    * Value -JobSchedule - a schedule option.
Procedure OnGetStandardSchedulesForReminder(Schedules) Export
	
EndProcedure

// Obsolete. Use UserRemindersOverridable.OnDefineSettings().
//
// Overrides an array of text presentations of standard time intervals.
//
// Parameters:
//  StandardIntervals - Array - contains string presentations of time intervals.
//
Procedure OnGetStandardNotificationIntervals(StandardIntervals) Export
	
EndProcedure

#EndRegion

#EndRegion
