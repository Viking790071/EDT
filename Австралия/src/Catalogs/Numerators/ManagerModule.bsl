#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

// Returns a structure of the Numerators fields
//
// Returns:
//   Structure
//     Description
//     Periodicity
//     NumberFormat
//     IndependentNumberingByCompanies
//     IndependentNumberingByDepartment
//     IndependentNumberingByDocumentKind
//     IndependentNumberingByProject
//     IndependentNumberingByActivityIssue
//     LinkType
//
Function GetNumeratorsStructure() Export
	
	NumeratorsParameters = New Structure;
	NumeratorsParameters.Insert("Description");
	NumeratorsParameters.Insert("Periodicity");
	NumeratorsParameters.Insert("NumberFormat");
	NumeratorsParameters.Insert("IndependentNumberingByDocumentTypes");
	NumeratorsParameters.Insert("IndependentNumberingByOperationTypes");
	NumeratorsParameters.Insert("IndependentNumberingByCompanies");
	NumeratorsParameters.Insert("IndependentNumberingByBusinessUnits");
	NumeratorsParameters.Insert("IndependentNumberingByCounterparties");
	
	Return NumeratorsParameters;
	
EndFunction

// Creates and writes Numerator to the database
//
// Parameters:
//   NumeratorStructure - Structure - a numerator field structure.
//
Function CreateNumerator(NumeratorStructure) Export
	
	NewNumerator = CreateItem();
	FillPropertyValues(NewNumerator, NumeratorStructure);
	NewNumerator.Write();
	
	Return NewNumerator.Ref;
	
EndFunction

#EndRegion

#Region EventHandlers

Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	NativeLanguagesSupportServer.ChoiceDataGetProcessing(
		ChoiceData,
		Parameters,
		StandardProcessing,
		Metadata.Catalogs.Numerators);
	
EndProcedure

Procedure PresentationGetProcessing(Data, Presentation, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationGetProcessing(Data, Presentation, StandardProcessing);
	
EndProcedure

Procedure PresentationFieldsGetProcessing(Fields, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationFieldsGetProcessing(Fields, StandardProcessing);
	
EndProcedure

#EndRegion

#EndIf