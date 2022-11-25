#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If IsBlankString(OperandID) OR NOT PriceGenerationFormulaServerCall.CheckPriceTypeID(OperandID, Ref) Then
		
		PriceGenerationFormulaServerCall.GenerateNewIndicatorPriceType(OperandID, Description, String(Owner));
		
	EndIf;
	
EndProcedure

Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	If TypeOf(FillingData) = Type("Structure") AND FillingData.Property("Counterparty") Then
		
		If TypeOf(FillingData.Counterparty) = Type("CatalogRef.Counterparties") Then
			
			Counterparty = FillingData.Counterparty;
			
		ElsIf TypeOf(FillingData.Counterparty) = Type("Array") Then 
			
			For each CounterpartyForFilling In FillingData.Counterparty Do
				If ValueIsFilled(CounterpartyForFilling) Then
					Counterparty = CounterpartyForFilling;
					Break;
				EndIf;
			EndDo;
			
		EndIf;
		
	EndIf;
	
EndProcedure


#EndRegion

#EndIf