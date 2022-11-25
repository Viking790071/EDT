#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	StandardProcessing = False;
	
	ChoiceData = New ValueList;
	
	ChoiceData.Add(Enums.OperationTypesSalesInvoice.Invoice);
	ChoiceData.Add(Enums.OperationTypesSalesInvoice.AdvanceInvoice);
	
	If GetFunctionalOption("UseZeroInvoiceSales") Then
		ChoiceData.Add(Enums.OperationTypesSalesInvoice.ZeroInvoice);
	EndIf;
	
	If GetFunctionalOption("IssueClosingInvoices") Then
		ChoiceData.Add(Enums.OperationTypesSalesInvoice.ClosingInvoice);
	EndIf;
	
EndProcedure

#EndRegion

#EndIf