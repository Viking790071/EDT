#Region Public

// Is called by following a link or double-clicking a cell of a spreadsheet document that contains 
// application release notes (common template ApplicationReleaseNotes).
//
// Parameters:
//   Area - SpreadsheetDocumentRange - a document area that was clicked.
//             
//
Procedure OnClickUpdateDetailsDocumentHyperlink(Val Area) Export
	
	

EndProcedure

// Is called in the BeforeStart handler. Checks for an update to a current version of a program.
// 
//
// Parameters:
//  DataVersion - String - data version of a main configuration that is to be updated (from the 
//                          SubsystemVersions information register).
//
Procedure OnDetermineUpdateAvailability(Val DataVersion) Export
	
	
	
EndProcedure

#EndRegion
