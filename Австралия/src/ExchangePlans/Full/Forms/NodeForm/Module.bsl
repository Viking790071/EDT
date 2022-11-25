
#Region FormEventHandlers

&AtServer
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	DataExchangeServer.NodeFormOnWriteAtServer(CurrentObject, Cancel);
	
EndProcedure

#EndRegion