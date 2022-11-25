#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	StandardProcessing = False;
	
	ChoiceData = New ValueList;
	
	ChoiceData.Add(Enums.OperationTypesSupplierInvoice.Invoice);
	
	If Not Parameters.Property("IsAdvanceInvoiceEnabled") Then
		
		ChoiceData.Add(Enums.OperationTypesSupplierInvoice.AdvanceInvoice);
		
	ElsIf Parameters.IsAdvanceInvoiceEnabled Then
	
		ChoiceData.Add(Enums.OperationTypesSupplierInvoice.AdvanceInvoice);
	
	EndIf;
	
	If Constants.UseZeroInvoicePurchases.Get() Then
		
		ChoiceData.Add(Enums.OperationTypesSupplierInvoice.ZeroInvoice);
		
	EndIf;
	
	If GetFunctionalOption("UseDropShipping") Then
		
		ChoiceData.Add(Enums.OperationTypesSupplierInvoice.DropShipping);
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf