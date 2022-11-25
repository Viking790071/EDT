#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Variables

Var AccessRestrictionAtRecordLevelEnabled; // Flag showing whether the constant value changed from False to True.
                                                 // Used in OnWrite event handler.

Var AccessRestrictionAtRecordLevelChanged; // Flag indicating whether the constant value changed.
                                                 // Used in OnWrite event handler.

#EndRegion

#Region EventHandlers

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	AccessRestrictionAtRecordLevelEnabled
		= Value AND NOT Constants.LimitAccessAtRecordLevel.Get();
	
	AccessRestrictionAtRecordLevelChanged
		= Value <>   Constants.LimitAccessAtRecordLevel.Get();
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If AccessRestrictionAtRecordLevelChanged Then
		AccessManagementInternal.OnChangeAccessRestrictionAtRecordLevel(
			AccessRestrictionAtRecordLevelEnabled);
		
		If AccessRestrictionAtRecordLevelEnabled
		   AND Constants.LimitAccessAtRecordLevelUniversally.Get() Then
			
			AccessManagementInternal.ScheduleAccessUpdate();
			AccessManagementInternal.SetAccessUpdate(True);
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#EndIf