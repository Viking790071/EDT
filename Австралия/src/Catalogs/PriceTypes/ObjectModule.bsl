#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If PriceCalculationMethod = Enums.PriceCalculationMethods.Formula Then
		
		CheckedAttributes.Add("Formula");
		
	ElsIf PriceCalculationMethod = Enums.PriceCalculationMethods.CalculatedDynamic Then
		
		CheckedAttributes.Add("PricesBaseKind");
		CheckedAttributes.Add("Company");
		
		
	ElsIf PriceCalculationMethod = Enums.PriceCalculationMethods.CalculatedStatic Then
		
		CheckedAttributes.Add("PricesBaseKind");
		
	Else
		
		CheckedAttributes.Add("PriceCurrency");
		
	EndIf;
	
EndProcedure

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If IsBlankString(OperandID) OR NOT PriceGenerationFormulaServerCall.CheckPriceTypeID(OperandID, Ref) Then
		
		PriceGenerationFormulaServerCall.GenerateNewIndicatorPriceType(OperandID, Description);
		
	EndIf;
	
EndProcedure

Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	If Not GetFunctionalOption("UseSeveralCompanies") Then
		Company = Catalogs.Companies.MainCompany;
	EndIf;
	
EndProcedure

#EndRegion

#EndIf