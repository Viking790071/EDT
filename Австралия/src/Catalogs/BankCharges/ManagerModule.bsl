#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region LibrariesHandlers

#Region ObjectVersioning

// StandardSubsystems.ObjectAttributesLock

// See ObjectsAttributesEditBlockedOverridable.OnDefineObjectsWithLockedAttributes.
Function GetObjectAttributesToLock() Export
	
	AttributesToLock = New Array;
	
	AttributesToLock.Add("ChargeType");
	AttributesToLock.Add("Value");
	AttributesToLock.Add("Item");
	AttributesToLock.Add("ExpenseItem");
	
	Return AttributesToLock;
	
EndFunction

// End StandardSubsystems.ObjectAttributesLock

#EndRegion

#EndRegion

#EndRegion

#Region EventHandlers

Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	NativeLanguagesSupportServer.ChoiceDataGetProcessing(
		ChoiceData,
		Parameters,
		StandardProcessing,
		Metadata.Catalogs.BankCharges);
	
EndProcedure

Procedure PresentationGetProcessing(Data, Presentation, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationGetProcessing(Data, Presentation, StandardProcessing);
	
EndProcedure

Procedure PresentationFieldsGetProcessing(Fields, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationFieldsGetProcessing(Fields, StandardProcessing);
	
EndProcedure

#EndRegion

#EndIf