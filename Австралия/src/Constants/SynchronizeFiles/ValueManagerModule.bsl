#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;

	If Value Then
		Return;
	EndIf;
	
	FilesOperationsInternal.SetFilesSynchronizationScheduledJobParameter(False, "Use");
	
EndProcedure

#EndRegion

#EndIf

