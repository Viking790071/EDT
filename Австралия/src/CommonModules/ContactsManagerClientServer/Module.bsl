#Region Public

// Generates a presentation with the specified kind for the address input form.
//
// Parameters:
//    AddressStructure - Structur - an address as a structure.
//                                   Details of the structure see in the AddressManager.AddressInfo.
//                                   Details of the previous structure version see in the AddressManager.AddressInfo.PreviousContactsXMLStructure function.
//    Presentation - String - address presentation.
//    KindDescription - String - kind description.
//
// Returns:
//    String - an address presentation with kind.
//
Function GenerateAddressPresentation(AddressStructure, Presentation, KindDescription = Undefined) Export
	
	Presentation = "";
	
	If TypeOf(AddressStructure) <> Type("Structure") Then
		Return Presentation;
	EndIf;
	
	FIASFormat = AddressStructure.Property("County");
	
	If AddressStructure.Property("Country") Then
		Presentation = AddressStructure.Country;
	EndIf;
	
	AddressPresentationByStructure(AddressStructure, "IndexOf", Presentation);
	AddressPresentationByStructure(AddressStructure, "State", Presentation, "StateShortForm", FIASFormat);
	AddressPresentationByStructure(AddressStructure, "County", Presentation, "CountyShortForm", FIASFormat);
	AddressPresentationByStructure(AddressStructure, "District", Presentation, "DistrictShortForm", FIASFormat);
	AddressPresentationByStructure(AddressStructure, "City", Presentation, "CityShortForm", FIASFormat);
	AddressPresentationByStructure(AddressStructure, "CityDistrict", Presentation, "CityDistrictShortForm", FIASFormat);
	AddressPresentationByStructure(AddressStructure, "Locality", Presentation, "LocalityShortForm", FIASFormat);
	AddressPresentationByStructure(AddressStructure, "Territory", Presentation, "TerritoryShortForm", FIASFormat);
	AddressPresentationByStructure(AddressStructure, "Street", Presentation, "StreetShortForm", FIASFormat);
	AddressPresentationByStructure(AddressStructure, "AdditionalTerritory", Presentation, "AdditionalTerritoryShortForm", FIASFormat);
	AddressPresentationByStructure(AddressStructure, "AdditionalTerritoryItem", Presentation, "AdditionalTerritoryItemShortForm", FIASFormat);
	
	If AddressStructure.Property("Building") Then
		SupplementAddressPresentation(TrimAll(ValueByStructureKey("Number", AddressStructure.Building)), ", " + ValueByStructureKey("BuildingType", AddressStructure.Building) + " № ", Presentation);
	Else
		SupplementAddressPresentation(TrimAll(ValueByStructureKey("House", AddressStructure)), ", " + ValueByStructureKey("HOUSETYPE", AddressStructure) + " № ", Presentation);
	EndIf;
	
	If AddressStructure.Property("BuildingUnits") Then
		For each BuildingUnit In AddressStructure.BuildingUnits Do
			SupplementAddressPresentation(TrimAll(ValueByStructureKey("Number", BuildingUnit )), ", " + ValueByStructureKey("BuildingUnitType", BuildingUnit)+ " ", Presentation);
		EndDo;
	Else
		SupplementAddressPresentation(TrimAll(ValueByStructureKey("BuildingUnit", AddressStructure)), ", " + ValueByStructureKey("BuildingUnitType", AddressStructure)+ " ", Presentation);
	EndIf;
	
	If AddressStructure.Property("Premises") Then
		For each Premise In AddressStructure.Premises Do
			SupplementAddressPresentation(TrimAll(ValueByStructureKey("Number", Premise)), ", " + ValueByStructureKey("PremiseType", Premise)+ " ", Presentation);
		EndDo;
	Else
		SupplementAddressPresentation(TrimAll(ValueByStructureKey("Apartment", AddressStructure)), ", " + ValueByStructureKey("ApartmentType", AddressStructure) + " ", Presentation);
	EndIf;
	
	KindDescription = ValueByStructureKey("KindDescription", AddressStructure);
	PresentationWithKind = KindDescription + ": " + Presentation;
	
	Return PresentationWithKind;
	
EndFunction

// Generates a string presentation of a phone number.
//
// Parameters:
//    CountryCode - String - a country code.
//    CityCode - String - a city code.
//    PhoneNumber - String - a phone number.
//    Additional - String - an additional number.
//    Comment - String - a comment.
//
// Returns:
//   - String - phone presentation.
//
Function GeneratePhonePresentation(CountryCode, CityCode, PhoneNumber, Extension, Comment) Export
	
	Presentation = TrimAll(CountryCode);
	If Not IsBlankString(Presentation) AND Not StrStartsWith(Presentation, "+") Then
		Presentation = "+" + Presentation;
	EndIf;
	
	If Not IsBlankString(CityCode) Then
		Presentation = Presentation + ?(IsBlankString(Presentation), "", " ") + "(" + TrimAll(CityCode) + ")";
	EndIf;
	
	If Not IsBlankString(PhoneNumber) Then
		Presentation = Presentation + ?(IsBlankString(Presentation), "", " ") + TrimAll(PhoneNumber);
	EndIf;
	
	If NOT IsBlankString(Extension) Then
		Presentation = Presentation + ?(IsBlankString(Presentation), "", ", ") + "ext. " + TrimAll(Extension);
	EndIf;
	
	If NOT IsBlankString(Comment) Then
		Presentation = Presentation + ?(IsBlankString(Presentation), "", ", ") + TrimAll(Comment);
	EndIf;
	
	Return Presentation;
	
EndFunction

// Returns flag specifying whether the contact information data string is in XML format.
//
// Parameters:
//     Text - String - checked string.
//
// Returns:
//     Boolean - the result of the check.
//
Function IsXMLContactInformation(Val Text) Export
	
	Return TypeOf(Text) = Type("String") AND StrStartsWith(TrimL(Text), "<");
	
EndFunction

// Returns flag specifying whether the contact information data string is in a JSON format.
//
// Parameters:
//     Text - String - checked string.
//
// Returns:
//     Boolean - the result of the check.
//
Function IsJSONContactInformation(Val Text) Export
	
	Return TypeOf(Text) = Type("String") AND StrStartsWith(TrimL(Text), "{");
	
EndFunction

// Text that displays in the contacts field when it is empty and displayed as a hyperlink.
// 
// Returns:
//  String - a text that displays in the contacts field.
//
Function EmptyAddressTextAsHiperlink() Export
	Return NStr("ru = 'Заполнить'; en = 'Fill in'; pl = 'Wypełnij';es_ES = 'Rellenar';es_CO = 'Rellenar';tr = 'Doldur';it = 'Compila';de = 'Ausfüllen'");
EndFunction

// Determines whether information is entered in the contacts field, in the scenario when information is displayed as a hyperlink.
//
// Parameters:
//  Value - String - a contacts value.
// 
// Returns:
//  Boolean - if True, the contacts field is filled in.
//
Function ContactsFilledIn(Value) Export
	Return Value <> EmptyAddressTextAsHiperlink();
EndFunction

#Region ObsoleteProceduresAndFunctions

// Obsolete. Use AddressManagerClientServer.ContactsStructureByType.
// Returns contact information structure by type.
//
// Parameters:
//  CIType - EnumRef.ContactsTypes - a contacts type.
//  AddressFormat - String - not used, left for the backward compatibility.
// 
// Returns:
//  Structure - a blank contact information structure, keys - field names and field values.
//
Function ContactInformationStructureByType(CIType, AddressFormat = Undefined) Export

	If CIType = PredefinedValue("Enum.ContactInformationTypes.Address") Then
		Return AddressFieldsStructure();
	ElsIf CIType = PredefinedValue("Enum.ContactInformationTypes.Phone") Then
		Return PhoneFieldStructure();
	Else
		Return New Structure;
	EndIf;
	
EndFunction

#EndRegion

#EndRegion

#Region Internal

// Returns a namespace for XDTO contact information management.
//
// Returns:
//      String - a namespace.
//
Function Namespace() Export
	Return "http://www.v8.1c.ru/ssl/contactinfo";
EndFunction

// Details of contacts structure for storing it in the JSON format.
// Fields list can be extended by national fields in the homonymous function of the AddressManagerClientServer module.
//
// Parameters:
//    ContactInformationType - EnumRef.ContactInformationTypes -
//                               Contact information type that determines a composition of contact information fields.
//
// Returns:
//   Structure - contacts fields with the fields:
//     * Value - String - presentation of contacts.
//     * Comment - String - a comment.
//     * Type - String - a contacts type.
//     For a contact information type, an address is as follows:
//     * Type - String - a contacts type.
//     * Country - String - country description.
//     * CountryCode - String - a country code.
//     * ZIPcode - String - a postal code.
//     * Area - String - a state presentation
//     * AreaType - String - a short form (type) of "state."
//     * City - String - city presentation.
//     * CityType - String - a short form of "city."
//     * Street - String -  street presentation.
//     * StreetType - String - a short form of "street."
//     For the type of contacts phone:
//     * CountryCode - String - a country code.
//     * AreaCode - String - a state code.
//     * Number - String - a phone number.
//     * ExtNumber - String - an additional phone number.
//
Function NewContactInformationDetails(Val ContactInformationType) Export
	
	If TypeOf(ContactInformationType) <> Type("EnumRef.ContactInformationTypes") Then
		ContactInformationType = "";
	EndIf;
	
	Result = New Structure;
	
	Result.Insert("value",   "");
	Result.Insert("comment", "");
	Result.Insert("type",    ContactInformationTypeToString(ContactInformationType));
	
	If ContactInformationType = PredefinedValue("Enum.ContactInformationTypes.Address") Then
		
		Result.Insert("country",     "");
		Result.Insert("addressType", AddressInFreeForm());
		Result.Insert("countryCode", "");
		Result.Insert("ZIPcode",     "");
		Result.Insert("area",        "");
		Result.Insert("areaType",    "");
		Result.Insert("city",        "");
		Result.Insert("cityType",    "");
		Result.Insert("street",      "");
		Result.Insert("streetType",  "");
		
	ElsIf ContactInformationType = PredefinedValue("Enum.ContactInformationTypes.Phone")
		Or ContactInformationType = PredefinedValue("Enum.ContactInformationTypes.Fax") Then
		
		Result.Insert("countryCode", "");
		Result.Insert("areaCode", "");
		Result.Insert("number", "");
		Result.Insert("extNumber", "");
		
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion

#Region Private

Function ContactInformationTypeToString(Val ContactInformationType) Export
	Result = New Map;
	Result.Insert(PredefinedValue("Enum.ContactInformationTypes.Address"), "Address");
	Result.Insert(PredefinedValue("Enum.ContactInformationTypes.Phone"), "Phone");
	Result.Insert(PredefinedValue("Enum.ContactInformationTypes.EmailAddress"), "EmailAddress");
	Result.Insert(PredefinedValue("Enum.ContactInformationTypes.Skype"), "Skype");
	Result.Insert(PredefinedValue("Enum.ContactInformationTypes.WebPage"), "WebPage");
	Result.Insert(PredefinedValue("Enum.ContactInformationTypes.Fax"), "Fax");
	Result.Insert(PredefinedValue("Enum.ContactInformationTypes.Other"), "Other");
	Result.Insert("", "");
	Return Result[ContactInformationType];
EndFunction

Function AddressInFreeForm() Export
	Return NStr("ru='ВСвободнойФорме'; en = 'FreeForm'; pl = 'FreeForm';es_ES = 'FreeForm';es_CO = 'FreeForm';tr = 'FreeForm';it = 'FreeForm';de = 'InFreierForm'");
EndFunction

Function EEUAddress() Export
	Return NStr("ru='ЕАЭС'; en = 'EEU'; pl = 'EAWG (Euroazjatycka Wspólnota Gospodarcza)';es_ES = 'UEE';es_CO = 'UEE';tr = 'EAES';it = 'EEU';de = 'EAWU'");
EndFunction

Function ForeignAddress() Export
	Return NStr("ru='Иностранный'; en = 'Foreign'; pl = 'Zagraniczny';es_ES = 'Extranjero';es_CO = 'Extranjero';tr = 'Yabancı';it = 'Straniero';de = 'Ausländische'");
EndFunction

Function IsAddressInFreeForm(AddressType) Export
	Return StrCompare(AddressInFreeForm(), AddressType) = 0;
EndFunction

Function IsForeignAddress(AddressType) Export
	Return StrCompare(ForeignAddress(), AddressType) = 0;
EndFunction

Function ConstructionOrPremiseValue(Type, Value) Export
	Return New Structure("type, number", Type, Value);
EndFunction

Function IsAddressType(TypeValue) Export
	Return StrCompare(TypeValue, String(PredefinedValue("Enum.ContactInformationTypes.Address"))) = 0;
EndFunction

// Returns a blank address structure.
//
// Returns:
//    Structure - address, keys - field names and field values.
//
Function AddressFieldsStructure()
	
	AddressStructure = New Structure;
	AddressStructure.Insert("Presentation", "");
	AddressStructure.Insert("Country", "");
	AddressStructure.Insert("CountryDescription", "");
	AddressStructure.Insert("CountryCode","");
	
	Return AddressStructure;
	
EndFunction

#Region PrivateForWorkingWithXMLAddresses

// Returns structure with a description and a short form by value.
//
// Parameters:
//     Text - String - a full description.
//
// Returns:
//     Structure - a processing result.
//         * Description - String - a text part.
//         * ShortForm - String - a text part.
//
Function DescriptionShortForm(Val Text) Export
	Result = New Structure("Description, ShortForm");
	
	Parts = DescriptionsAndShortFormsSet(Text, True);
	If Parts.Count() > 0 Then
		FillPropertyValues(Result, Parts[0]);
	Else
		Result.Description = Text;
	EndIf;
	
	Return Result;
EndFunction

// Returns a short form by value.
//
// Parameters:
//     Text - String - a full description.
//
// Returns:
//     String - a short form.
//
Function ShortForm(Val Text) Export
	
	Parts = DescriptionShortForm(Text);
	Return Parts.ShortForm;
	
EndFunction

// Splits text into words using the specified separators Separators by default - space characters.
//
// Parameters:
//     Text - String - a split string.
//     Separators - String - an optional string of separator characters.
//
// Returns:
//     Array - string, words
//
Function TextWords(Val Text, Val Separators = Undefined)
	
	WordBeginning = 0;
	State   = 0;
	Result   = New Array;
	
	For Position = 1 To StrLen(Text) Do
		CurrentChar = Mid(Text, Position, 1);
		IsSeparator = ?(Separators = Undefined, IsBlankString(CurrentChar), StrFind(Separators, CurrentChar) > 0);
		
		If State = 0 AND (Not IsSeparator) Then
			WordBeginning = Position;
			State   = 1;
		ElsIf State = 1 AND IsSeparator Then
			Result.Add(Mid(Text, WordBeginning, Position-WordBeginning));
			State = 0;
		EndIf;
	EndDo;
	
	If State = 1 Then
		Result.Add(Mid(Text, WordBeginning, Position-WordBeginning));    
	EndIf;
	
	Return Result;
EndFunction

// Splits comma-separated text.
//
// Parameters:
//     Text - String - a split text.
//     ExtractShortForms - Boolean - an optional parameter.
//
// Returns:
//     Array - contains "Description, ShortForm" structures.
//
Function DescriptionsAndShortFormsSet(Val Text, Val ExtractShortForms = True)
	
	Result = New Array;
	For Each Term In TextWords(Text, ",") Do
		PartRow = TrimAll(Term);
		If IsBlankString(PartRow) Then
			Continue;
		EndIf;
		
		Position = ?(ExtractShortForms, StrLen(PartRow), 0);
		While Position > 0 Do
			If Mid(PartRow, Position, 1) = " " Then
				Result.Add(New Structure("Description, ShortForm",
					TrimAll(Left(PartRow, Position-1)), TrimAll(Mid(PartRow, Position))));
				Position = -1;
				Break;
			EndIf;
			Position = Position - 1;
		EndDo;
		If Position = 0 Then
			Result.Add(New Structure("Description, ShortForm", PartRow));
		EndIf;
		
	EndDo;
	
	Return Result;
EndFunction    

// Returns the first list item.
//
// Parameters:
//     DataList - ValueList, Array, FormField.
//
// Returns:
//     Arbitrary - the first item.
//     Undefined - no first item.
// 
Function FirstOrEmpty(Val DataList) Export
	
	ListType = TypeOf(DataList);
	If ListType = Type("ValueList") AND DataList.Count() > 0 Then
		Return DataList[0].Value;
	ElsIf ListType = Type("Array") AND DataList.Count() > 0 Then
		Return DataList[0];
	ElsIf ListType = Type("FormField") Then
		Return FirstOrEmpty(DataList.ChoiceList);
	EndIf;
	
	Return Undefined;
EndFunction

#EndRegion

#Region OtherInternalProceduresAndFunctions

// Adds string to address presentation.
//
// Parameters:
//    Addition - String - addess addition.
//    ConcatenationString - String - a concatenation string.
//    Presentation - String - address presentation.
//
Procedure SupplementAddressPresentation(Supplement, ConcatenationString, Presentation)
	
	If Supplement <> "" Then
		Presentation = Presentation + ConcatenationString + Supplement;
	EndIf;
	
EndProcedure

// Returns value string by structure property.
// 
// Parameters:
//    Key - String - a structure key.
//    Structure - Structure - a passed structure.
//
// Returns:
//    Arbitrary - value.
//    String - an empty string if no value.
//
Function ValueByStructureKey(varKey, Structure)
	
	Value = Undefined;
	
	If Structure.Property(varKey, Value) Then 
		Return String(Value);
	EndIf;
	
	Return "";
	
EndFunction

Procedure AddressPresentationByStructure(AddressStructure, DescriptionKey, Presentation, ShortFormKey = "", AddShortForms = False, ConcatenationString = ", ")
	
	If AddressStructure.Property(DescriptionKey) Then
		Supplement = TrimAll(AddressStructure[DescriptionKey]);
		If ValueIsFilled(Supplement) Then
			If AddShortForms AND AddressStructure.Property(ShortFormKey) Then
				Supplement = Supplement + " " + TrimAll(AddressStructure[ShortFormKey]);
			EndIf;
			If ValueIsFilled(Presentation) Then
				Presentation = Presentation + ConcatenationString + Supplement;
			Else
				Presentation = Supplement;
			EndIf;
		EndIf;
	EndIf;
EndProcedure

// Returns empty phone structure.
//
// Returns:
//    Sructure - keys - fields names, field values.
//
Function PhoneFieldStructure() Export
	
	PhoneStructure = New Structure;
	PhoneStructure.Insert("Presentation", "");
	PhoneStructure.Insert("CountryCode", "");
	PhoneStructure.Insert("CityCode", "");
	PhoneStructure.Insert("PhoneNumber", "");
	PhoneStructure.Insert("Extension", "");
	PhoneStructure.Insert("Comment", "");
	
	Return PhoneStructure;
	
EndFunction

// Returns value list. Transforms a string containing fields to a value list.
//
// Parameters:
//    FieldsString - String - a fields string.
//
// Returns:
//    ValueList - a list of fields values.
//
Function ConvertStringToFieldList(FieldsString) Export
	
	// Conversion of XML serialization is not required.
	If IsXMLContactInformation(FieldsString) Then
		Return FieldsString;
	EndIf;
	
	Result = New ValueList;
	
	FieldsValuesStructure = FieldsValuesStructure(FieldsString);
	For each FieldValue In FieldsValuesStructure Do
		Result.Add(FieldValue.Value, FieldValue.Key);
	EndDo;
	
	Return Result;
	
EndFunction

// Gets a short form of a geographical name of an object.
//
// Parameters:
//    GeographicalName - String - an object geographical name.
//
// Returns:
//     String - an empty string, or the last word of the geographical name.
//
Function AddressShortForm(Val GeographicalName)
	
	ShortForm = "";
	WordArray = StrSplit(GeographicalName, " ", False);
	If WordArray.Count() > 1 Then
		ShortForm = WordArray[WordArray.Count() - 1];
	EndIf;
	
	Return ShortForm;
	
EndFunction

//  Converts the string of the fields kind key = value into the structure.
//
//  Parameters:
//      FieldsString - String - a string of fields with the data kind key = value.
//      ContctsKind - CatalogRef.ContactsKind - to determine the composition of blank fields.
//                                                                            
//
//  Returns:
//      Structure - fields values.
//
Function FieldsValuesStructure(FieldsString, ContactInformationKind = Undefined) Export
	
	If ContactInformationKind = PredefinedValue("Enum.ContactInformationTypes.Address") Then
		Result = AddressFieldsStructure();
	ElsIf ContactInformationKind = PredefinedValue("Enum.ContactInformationTypes.Phone") Then
		Result = PhoneFieldStructure();
	Else
		Result = New Structure;
	EndIf;
	
	LastItem = Undefined;
	
	For Iteration = 1 To StrLineCount(FieldsString) Do
		ReceivedString = StrGetLine(FieldsString, Iteration);
		If StrStartsWith(ReceivedString, Chars.Tab) Then
			If Result.Count() > 0 Then
				Result.Insert(LastItem, Result[LastItem] + Chars.LF + Mid(ReceivedString, 2));
			EndIf;
		Else
			CharPosition = StrFind(ReceivedString, "=");
			If CharPosition <> 0 Then
				FieldName = Left(ReceivedString, CharPosition - 1);
				FieldValue = Mid(ReceivedString, CharPosition + 1);
				If FieldName = "State" Or FieldName = "District" Or FieldName = "City" 
					Or FieldName = "Locality" Or FieldName = "Street" Then
					If StrFind(FieldsString, FieldName + "ShortForm") = 0 Then
						Result.Insert(FieldName + "ShortForm", AddressShortForm(FieldValue));
					EndIf;
				EndIf;
				Result.Insert(FieldName, FieldValue);
				LastItem = FieldName;
			EndIf;
		EndIf;
	EndDo;
	
	Return Result;
EndFunction

Procedure UpdateAddressPresentation(Address, IncludeCountryInPresentation) Export
	
	If TypeOf(Address) <> Type("Structure") Then
		Raise NStr("ru='Для формирования представления адреса передан некорректный тип адреса'; en = 'Incorrect address type was passed to generate address representation'; pl = 'Do tworzenia prezentacji adresu został przekazany nieprawidłowy rodzaj adresu';es_ES = 'Para generar la presentación de la dirección ha sido enviado un tipo incorrecto de la dirección';es_CO = 'Para generar la presentación de la dirección ha sido enviado un tipo incorrecto de la dirección';tr = 'Bir adres görünümü oluşturmak için yanlış adres türü iletildi';it = 'Un tipo di indirizzo non corretto è stato passato per generare il riepilogo dell''indirizzo';de = 'Es wurde ein falscher Adresstyp übergeben, um eine Adressendarstellung zu generieren'");
	EndIf;
	
	FilledLevelsList = New Array;
	
	If IncludeCountryInPresentation AND Address.Property("Country") AND NOT IsBlankString(Address.Country) Then
		FilledLevelsList.Add(Address.Country);
	EndIf;
	
	If Address.Property("ZipCode") AND NOT IsBlankString(Address.ZipCode) Then
		FilledLevelsList.Add(Address.ZipCode);
	EndIf;
	
	FilledLevelsList.Add(Address["Area"] + " " + Address["AreaType"]);
	FilledLevelsList.Add(Address["City"] + " " + Address["CityType"]);
	
	Address.Value = StrConcat(FilledLevelsList, ", ");
	
EndProcedure

#EndRegion

#EndRegion
