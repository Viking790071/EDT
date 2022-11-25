#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If ValueIsFilled(Owner) Then
		ParametersData = Catalogs.BatchSettings.ProductBatchSettings(Owner);
		If Not ParametersData.UseBatchNumber Then
			DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "BatchNumber");
		EndIf;
		If Not ParametersData.UseExpirationDate Then
			DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "ExpirationDate");
		EndIf;
		If Not ParametersData.UseProductionDate Then
			DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "ProductionDate");
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#EndIf