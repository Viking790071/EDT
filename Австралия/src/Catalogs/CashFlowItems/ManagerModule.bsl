#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region LibrariesHandlers

#Region ObjectAttributesLock

// StandardSubsystems.ObjectAttributesLock

// See ObjectsAttributesEditBlockedOverridable.OnDefineObjectsWithLockedAttributes.
Function GetObjectAttributesToLock() Export
	
	AttributesToLock = New Array;
	AttributesToLock.Add("Parent");
	AttributesToLock.Add("CorrespondingAccount");
	
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
		Metadata.Catalogs.CashFlowItems);
	
EndProcedure

Procedure PresentationGetProcessing(Data, Presentation, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationGetProcessing(Data, Presentation, StandardProcessing);
	
EndProcedure

Procedure PresentationFieldsGetProcessing(Fields, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationFieldsGetProcessing(Fields, StandardProcessing);
	
EndProcedure

#EndRegion

#EndIf