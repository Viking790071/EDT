#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure OnWrite(Cancel)
	
	If Not AdditionalProperties.Property("SkipPeriodClosingDatesVersionUpdate") Then
		PeriodClosingDatesInternal.UpdatePeriodClosingDatesVersion();
	EndIf;
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
EndProcedure

#EndRegion

#EndIf
