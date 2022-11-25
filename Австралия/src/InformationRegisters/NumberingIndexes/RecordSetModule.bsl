#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	For Each Record In ThisObject Do
		If Record.Object = Undefined Then 
			CheckedAttributes.Delete(CheckedAttributes.Find("Object"));
		EndIf;
	EndDo;
	
EndProcedure

#EndRegion

#EndIf