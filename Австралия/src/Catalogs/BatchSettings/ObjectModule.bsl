#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If Not UseExpirationDate Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "ExpirationDatePrecision");
	EndIf;
	If Not UseProductionDate Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "ProductionDatePrecision");
	EndIf;
	
EndProcedure

#EndRegion

#Region Internal

Procedure OnReadPresentationsAtServer(Object) Export
	
	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

#EndRegion

#EndIf