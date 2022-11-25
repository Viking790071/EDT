#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure BeforeWrite(Cancel)
	
	AdditionalProperties.Insert("CurrentValue", Constants.UseSeparationByDataAreas.Get());
	
	If DataExchange.Load Then
		
		Return;
		
	EndIf;
	
EndProcedure

Procedure OnWrite(Cancel)
	
	// The following constants are mutually exclusive and intended for use in specific functional options only.
	//
	// Constant.IsStandaloneWorkstation -> FD.StandaloneModeOperations
	// Constant.DoNotUseDataSeparation -> FD.StandaloneModeOperations
	// Constant.UseDataSeparation -> FD.SaaS.
	//
	// Names of the constants are retained for backwards compatibility purposes.
	
	If Value Then
		
		Constants.DoNotUseSeparationByDataAreas.Set(False);
		Constants.IsStandaloneWorkplace.Set(False);
		
	ElsIf Constants.IsStandaloneWorkplace.Get() Then
		
		Constants.DoNotUseSeparationByDataAreas.Set(False);
		
	Else
		
		Constants.DoNotUseSeparationByDataAreas.Set(True);
		
	EndIf;
	
	If AdditionalProperties.CurrentValue <> Value Then
		
		RefreshReusableValues();
		
		If Value Then
			
			SSLSubsystemsIntegration.OnEnableSeparationByDataAreas();
			
		EndIf;
		
	EndIf;
	
	If DataExchange.Load Then
		
		Return;
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf