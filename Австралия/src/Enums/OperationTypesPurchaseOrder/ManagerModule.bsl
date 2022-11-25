#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	StandardProcessing = False;
	
	ChoiceData = New ValueList;
	
	ChoiceData.Add(Enums.OperationTypesPurchaseOrder.OrderForPurchase);
	
	If GetFunctionalOption("TransferRawMaterialsForProcessing")
		And Constants.UseSubcontractorManufacturers.Get() Then
		
		ChoiceData.Add(Enums.OperationTypesPurchaseOrder.OrderForProcessing);
		
	EndIf;
	
	If GetFunctionalOption("UseDropShipping") Then
		ChoiceData.Add(Enums.OperationTypesPurchaseOrder.OrderForDropShipping);
	EndIf;
	
EndProcedure

#EndRegion

#EndIf