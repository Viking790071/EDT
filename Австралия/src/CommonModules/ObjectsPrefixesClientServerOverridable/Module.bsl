#Region Public

// On get number for printing event handler.
// The event occurs before standard processing of getting a number.
// The handler can override the default application behavior upon getting a number for printing.
//
// Parameters:
//  ObjectNumber - String - an object number or code being processed.
//  StandardProcessing - Boolean - standard processing flag, if the flag value is set to False, the 
//                                              standard processing of generating a number for 
//                                              printing will not be executed.
//  DeleteInfobasePrefix - Boolean - shows whether an infobase prefix is to be removed.
//                                              by default, it is equal to False.
//  DeleteCustomPrefix - Boolean - shows whether a custom prefix is to be removed.
//                                              by default, it is equal to False.
//
// Example:
//
//   ObjectNumber = ObjectsPrefixesClientServer.DeleteCustomPrefixesFromObjectNumber(ObjectNumber).
//   StandardProcessing = False.
//
Procedure OnGetNumberForPrinting(ObjectNumber, StandardProcessing,
	DeleteInfobasePrefix, DeleteCustomPrefix) Export
	
EndProcedure

#EndRegion
