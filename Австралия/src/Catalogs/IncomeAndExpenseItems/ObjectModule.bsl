#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Not IsFolder And Not IsIncome And Not IsExpense Then
		
		IsIncome = True;
		IsExpense = True;
		
	EndIf;
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If Not IsFolder And IncomeAndExpenseType = Catalogs.IncomeAndExpenseTypes.ManufacturingOverheads Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "MethodOfDistribution");
	EndIf;
	
EndProcedure

#EndRegion

#Region Internal

Procedure OnReadPresentationsAtServer(Object) Export
	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
EndProcedure

#EndRegion

#EndIf