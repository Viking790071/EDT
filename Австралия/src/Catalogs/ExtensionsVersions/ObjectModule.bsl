
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Variables

Var NewObject;

#EndRegion

#Region EventHandlers

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	NewObject = IsNew();
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If NewObject Then
		Catalogs.ExtensionsVersions.EnableDeleteObsoleteExtensionsVersionsParametersJob(True);
	EndIf;
	
EndProcedure

#EndRegion

#EndIf
