#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure SessionParametersSetting(SessionParameterNames)
	
	// StandardSubsystems
	StandardSubsystemsServer.SessionParametersSetting(SessionParameterNames);
	// End StandardSubsystems
	
	SessionParameters.DisabledAccessKinds = "ALL";
	
EndProcedure

#EndRegion

#EndIf