#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Not ValueIsFilled(Description) Then
		Description = DescriptionForPrinting;
	EndIf;
	
EndProcedure

#EndRegion

#EndIf
