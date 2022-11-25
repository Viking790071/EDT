#Region FormEventHandlers

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	EDIClientServer.CheckCounterpartyIsReadyForExchange(Record.Counterparty, Cancel);
	
EndProcedure

#EndRegion

