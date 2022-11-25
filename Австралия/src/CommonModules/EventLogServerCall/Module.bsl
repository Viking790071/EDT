#Region Public

// Handles bunch message writing to the event log.
// The EventsForEventLog variable is cleared after writing.
//
// Parameters:
//  EventsForEventLog - ValueList - where Value is Structure with the following properties:
//              * EventName  - String - a name of the event to write.
//              * LevelPresentation  - String - a presentation of the EventLogLevel collection values.
//                                       Possible values: Information, Error, Warning, and Note.
//              * Comment - String - an event comment.
//              * EventDate - Date   - the event date that is added to the comment when writing.
//
Procedure WriteEventsToEventLog(EventsForEventLog) Export
	
	EventLogOperations.WriteEventsToEventLog(EventsForEventLog);
	
EndProcedure

#EndRegion
