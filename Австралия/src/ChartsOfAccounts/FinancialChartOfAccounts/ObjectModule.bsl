#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

// Procedure - event handler BeforeWrite object.
//
Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If NOT ValueIsFilled(Order) Then
		Order = 1;
	EndIf;
	
EndProcedure

#EndRegion

#EndIf