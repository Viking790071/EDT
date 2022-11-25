#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

// Procedure - event handler BeforeWrite record set.
//
Procedure BeforeWrite(Cancel, WriteMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	RecordSetTable = Unload();
	
	AccountingRegisters.AccountingJournalEntriesCompound.SetEntryNumbers(RecordSetTable);
	
	Load(RecordSetTable);
	
EndProcedure

#EndRegion

#EndIf