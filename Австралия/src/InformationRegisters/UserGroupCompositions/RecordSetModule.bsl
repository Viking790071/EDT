
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure OnWrite(Cancel, Replacing)
	
	If DataExchange.Load Then
		If Not AdditionalProperties.Property("SkipPeriodClosingDatesVersionUpdate") Then
			UpdatePeriodClosingDatesVersionOnDataImport();
		EndIf;
		Return;
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

Procedure UpdatePeriodClosingDatesVersionOnDataImport()
	
	// Changes to the usual write mode are registered in the AfterUpdateUserGroupContentsOverridable 
	// procedure of the UsersInternal common module.
	
	If Common.SubsystemExists("StandardSubsystems.PeriodClosingDates") Then
		ModulePeriodClosingDatesInternal = Common.CommonModule("PeriodClosingDatesInternal");
		ModulePeriodClosingDatesInternal.UpdatePeriodClosingDatesVersionOnDataImport(ThisObject);
	EndIf;
	
EndProcedure

#EndRegion

#EndIf

