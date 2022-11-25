#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Variables

Var ValueChanged;

#EndRegion

#Region EventHandlers

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	ValueChanged = Value <> Constants.UseAdditionalAttributesAndInfo.Get();
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If ValueChanged Then
		If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
			ModuleAccessManagement = Common.CommonModule("AccessManagement");
			ModuleAccessManagement.UpdateAllowedValuesOnChangeAccessKindsUsage();
		EndIf;
		
		If Value = False Then
			Constants.UseCommonAdditionalValues.Set(False);
			Constants.UseAdditionalCommonAttributesAndInfo.Set(False);
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#EndIf
