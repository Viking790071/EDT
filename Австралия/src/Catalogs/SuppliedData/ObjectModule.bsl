#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure BeforeWrite(Cancel)
	Var Characteristic;
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	Details = DataKind;
	For each Characteristic In DataCharacteristics Do
		Details = Details 
			+ ", " + Characteristic.Characteristic + ": " + Characteristic.Value;
	EndDo;
		
EndProcedure

#EndRegion

#EndIf