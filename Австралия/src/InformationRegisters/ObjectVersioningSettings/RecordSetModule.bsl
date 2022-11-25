#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure BeforeWrite(Cancel, Replacing)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	For Each Row In ThisObject Do
		Row.Use = Row.Variant <> Enums.ObjectsVersioningOptions.DontVersionize;
	EndDo;
	
EndProcedure

#EndRegion

#EndIf