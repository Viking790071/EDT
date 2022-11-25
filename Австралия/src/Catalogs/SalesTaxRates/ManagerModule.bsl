#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region Libraries

// StandardSubsystems.ObjectAttributesLock
//
Function GetObjectAttributesToLock() Export
	
	AttributesToLock = New Array;
	
	AttributesToLock.Add("Agency");
	AttributesToLock.Add("Rate");
	AttributesToLock.Add("Combined");
	AttributesToLock.Add("TaxComponents");
	
	Return AttributesToLock;
	
EndFunction
// End StandardSubsystems.ObjectAttributesLock

#EndRegion

// Function returns the list of the "key" attributes names.
//
Function GetObjectAttributesBeingLocked() Export
	
	Return GetObjectAttributesToLock();
	
EndFunction

#EndRegion

#Region EventHandlers

Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	NativeLanguagesSupportServer.ChoiceDataGetProcessing(
		ChoiceData,
		Parameters,
		StandardProcessing,
		Metadata.Catalogs.SalesTaxRates);
	
EndProcedure

Procedure PresentationGetProcessing(Data, Presentation, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationGetProcessing(Data, Presentation, StandardProcessing);
	
EndProcedure

Procedure PresentationFieldsGetProcessing(Fields, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationFieldsGetProcessing(Fields, StandardProcessing);
	
EndProcedure

#EndRegion

#EndIf