
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure BeforeWrite(Cancel, Replacing)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Filter.User.Use
	   AND Not PeriodClosingDatesInternal.IsPeriodClosingAddressee(Filter.User.Value) Then
		// Import restriction dates are set up separately in each infobase.
		AdditionalProperties.Insert("DisableObjectChangeRecordMechanism");
	EndIf;
	
EndProcedure

Procedure OnWrite(Cancel, Replacing)
	
	If DataExchange.Load Then
		If Not AdditionalProperties.Property("SkipPeriodClosingDatesVersionUpdate") Then
			PeriodClosingDatesInternal.UpdatePeriodClosingDatesVersionOnDataImport(ThisObject);
		EndIf;
		Return;
	EndIf;
	
	If Not AdditionalProperties.Property("SkipPeriodClosingDatesVersionUpdate") Then
		PeriodClosingDatesInternal.UpdatePeriodClosingDatesVersion();
	EndIf;
	
EndProcedure

#EndRegion

#EndIf
