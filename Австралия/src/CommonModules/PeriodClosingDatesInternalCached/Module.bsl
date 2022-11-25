#Region Private

// Returns info on the last version check of the valid period-end closing dates.
//
// Returns:
//  Structure - with the following properties:
//   * Date - Date - date and time of the last valid date check.
//
Function LastCheckOfEffectiveClosingDatesVersion() Export
	
	Return New Structure("Date", '00010101');
	
EndFunction

#EndRegion
