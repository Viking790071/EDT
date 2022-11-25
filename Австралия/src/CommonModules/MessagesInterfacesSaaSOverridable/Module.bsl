#Region Public

// Fills the passed array with the common modules used as incoming message interface handlers.
//  
//
// Parameters:
//  HandlerArray - Array - array elements are common modules.
//
Procedure FillIncomingMessageHandlers(HandlerArray) Export
	
EndProcedure

// Fills the passed array with the common modules used as outgoing message interface handlers.
//  
//
// Parameters:
//  HandlerArray - Array - array elements are common modules.
//
Procedure FillOutgoingMessageHandlers(HandlerArray) Export
	
EndProcedure

// The procedure is called when determining a message interface version supported both by 
//  correspondent infobase and the current infobase. This procedure is intended to implement 
//  mechanisms for enabling backward compatibility with earlier versions of correspondent infobases.
//
// Parameters:
//  MessageInterface - String - name of an application message interface whose version is to be determined.
//  ConnectionParameters - Structure - parameters for connecting to the correspondent infobase.
//  RecipientPresentation - String - infobase correspondent presentation.
//  Result - String - version to be defined. Value of this parameter can be modified in this procedure.
//
Procedure OnDetermineCorrespondentInterfaceVersion(Val MessageInterface, Val ConnectionParameters, Val RecipientPresentation, Result) Export
	
EndProcedure

#EndRegion
