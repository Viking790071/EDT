#Region Private

// Sends and receives system messages.
//
// Parameters:
//  Cancel - Boolean. A cancellation flag. Appears on errors during operations.
//
Procedure SendAndReceiveMessages(Cancel) Export
	
	DataExchangeServer.CheckCanSynchronizeData();
	
	MessageExchangeInternal.SendAndReceiveMessages(Cancel);
	
EndProcedure

#EndRegion
