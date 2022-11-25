#Region Private

// Parses contact information presentation and returns an XML string containing parsed field values.
//
//  Parameters:
//      Text - String - a contact information presentation.
//      ExpectedType - CatalogRef.ContactsKinds, EnumRef.ContactsTYpes - to control types.
//                     
//
//  Returns:
//      String - JSON
//
Function ContactsByPresentation(Val Text, Val ExpectedKind) Export
	Return ContactsManager.ContactsByPresentation(Text, ExpectedKind);
EndFunction

// Returns a composition string from a contact information value.
//
//  Parameters:
//      XMLData - String - XML of contact information data.
//
//  Returns:
//      String - content
//      Undefined - if a composition value has a complex type.
//
Function ContactInformationCompositionString(Val XMLData) Export;
	Return ContactsManagerInternal.ContactInformationCompositionString(XMLData);
EndFunction

// Converts all incoming contact information formats to XML.
//
Function TransformContactInformationXML(Val Data) Export
	Return ContactsManagerInternal.TransformContactInformationXML(Data);
EndFunction

// Returns a list of IDs of address strings available for copying to the current address.
// 
Function AddressesAvailableForCopying(Val FieldsValuesForAnalysis, Val AddressKind) Export
	
	Return ContactsManagerInternal.AddressesAvailableForCopying(FieldsValuesForAnalysis, AddressKind);
	
EndFunction

// Returns the found reference or creates a new world country record and returns a reference to it.
//
Function WorldCountryByClassifierData(Val CountryCode) Export
	
	Return ContactsManager.WorldCountryByCodeOrDescription(CountryCode);
	
EndFunction

// Fills in a collection with references to found or created world country records.
//
Procedure WorldCountriesCollectionByClassifierData(Collection) Export
	
	For Each KeyValue In Collection Do
		Collection[KeyValue.Key] =  ContactsManager.WorldCountryByCodeOrDescription(KeyValue.Value.Code);
	EndDo;
	
EndProcedure

// Fills in the list of countries upon automatic completion by the text entered by the user.
//
Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing) Export
	
	If Not ContactsManagerInternal.HasRightToAdd() Then
		// No rights to add a new world country, default behavior.
		Return;
	EndIf;
	
	ChoiceData = ContactsManagerInternal.FiilInDataOfAutoCompleteSelectionByCountries(Parameters);
	StandardProcessing = (ChoiceData.Count() = 0);
	
EndProcedure

// Fills in the list of address options upon automatic completion by the text entered by the user.
//
Procedure AddressAutoComplete(Val Text, ChoiceData) Export
	
	ContactsManagerInternal.AddressAutoComplete(Text, ChoiceData);
	
EndProcedure

#EndRegion
