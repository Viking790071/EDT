#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	NativeLanguagesSupportServer.ChoiceDataGetProcessing(
		ChoiceData,
		Parameters,
		StandardProcessing,
		Metadata.Catalogs.CounterpartiesAccessGroups);
	
EndProcedure

Procedure PresentationGetProcessing(Data, Presentation, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationGetProcessing(Data, Presentation, StandardProcessing);
	
EndProcedure

Procedure PresentationFieldsGetProcessing(Fields, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationFieldsGetProcessing(Fields, StandardProcessing);
	
EndProcedure

#EndRegion
	
#Region ProgramInterface

// Function determines whether counterparty access groups are used or not.
//
//	Returns:
//		Boolean - If TRUE, it means that access groups are used
//
Function AccessGroupsAreUsed() Export
	
	Return
		GetFunctionalOption("LimitAccessAtRecordLevel")
		AND GetFunctionalOption("UseCounterpartiesAccessGroups");
	
EndFunction

#EndRegion

#EndIf