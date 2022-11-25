#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If Not GetFunctionalOption("PlanCompanyResourcesImporting") Then
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "WorkCenterTypes");
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf