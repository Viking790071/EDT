#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Variables

Var SettingEnabled; // Flag showing whether the constant value changed from False to True.
                         // Used in OnWrite event handler.

#EndRegion

#Region EventHandlers

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	SettingEnabled = Value AND NOT Constants.UseImportForbidDates.Get();
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If Not AdditionalProperties.Property("SkipPeriodClosingDatesVersionUpdate") Then
		PeriodClosingDatesInternal.UpdatePeriodClosingDatesVersion();
	EndIf;
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If SettingEnabled Then
		SectionsProperties = PeriodClosingDatesInternal.SectionsProperties();
		If Not SectionsProperties.ImportRestrictionDatesImplemented Then
			Raise PeriodClosingDatesInternal.ErrorTextImportRestrictionDatesNotImplemented();
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#EndIf
