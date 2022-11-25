#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure OnWrite(Cancel, Replacing)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	UsersInternal.EnableUserActivityMonitoringJobIfRequired(
		Unload(, "User").UnloadColumn("User"));
	
EndProcedure

#EndRegion

#EndIf
