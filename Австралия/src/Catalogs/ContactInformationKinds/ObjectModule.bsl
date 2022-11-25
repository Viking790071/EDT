#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure BeforeWrite(Cancel)
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If NOT IsFolder Then
		Result = ContactsManagerInternal.CheckContactsKindParameters(ThisObject);
		If Result.HasErrors Then
			Cancel = True;
			Raise Result.ErrorText;
		EndIf;
	EndIf;

EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If IsFolder Then
		
		AttributesNotToCheck = New Array;
		AttributesNotToCheck.Add("Parent");
		Common.DeleteNotCheckedAttributesFromArray(CheckedAttributes, AttributesNotToCheck);

	EndIf;
	
EndProcedure

#EndRegion

#EndIf