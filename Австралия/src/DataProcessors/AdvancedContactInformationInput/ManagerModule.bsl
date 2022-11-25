#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Private

// Returns name of form used to edit contact information type.
//
// Parameters:
//      ContactsKind - EnumRef.ContactsTypes, CatalogRef.ContactsKinds - requested type.
//                      
//
// Returns:
//      String - a full name of the form.
//
Function ContactInformationInputFormName(Val InformationKind) Export
	
	InformationType = ContactInformationManagementInternalCached.ContactInformationKindType(InformationKind);
	
	AllTypes = "Enum.ContactInformationTypes.";
	If InformationType = PredefinedValue(AllTypes + "Address") Then
		Return "DataProcessor.ContactInformationInput.Form.AddressInput";
		
	ElsIf InformationType = PredefinedValue(AllTypes + "Phone") Then
		Return "DataProcessor.ContactInformationInput.Form.PhoneInput";
		
	ElsIf InformationType = PredefinedValue(AllTypes + "Fax") Then
		Return "DataProcessor.ContactInformationInput.Form.PhoneInput";
		
	EndIf;
	
	Return Undefined;
	
EndFunction

#Region InteractionWithAddressClassifier

// Specifying operation mode of the input forms.
// 
// Returns:
//     Boolean - True if the classifier is available over a web service.
//
Function ClassierAvailableOverWebService() Export
	
	If Not Common.SubsystemExists("StandardSubsystems.AddressClassifier") Then
		Return False;
	EndIf;
	
	ModuleAddressClassifierInternal = Common.CommonModule("AddressClassifierInternal");
	Source = ModuleAddressClassifierInternal.AddressClassifierDataSource();
	
	Return Not IsBlankString(Source);
EndFunction

// Returns the flag that shows whether the current user can import or clear the address classifier.
//
// Returns:
//     Boolean - the result of the check.
//
Function CanChangeAddressClassifier() Export
	
	If Common.SubsystemExists("StandardSubsystems.AddressClassifier") Then
		ControlObject = Metadata.InformationRegisters.Find("AddressObjects");
		Return ControlObject <> Undefined AND AccessRight("Update", ControlObject) AND NOT Common.DataSeparationEnabled();
	EndIf;
	
	Return False;
	
EndFunction

// Provider availability check - a local base or service. Request a version.
// 
// Returns:
//     Structure - status description.
//       * Cancel - Boolean - supplier is not available. 
//       * DetailedErrorPresentation - String - error description if a supplier is not available. Undefined if Cancel
//                                                 = False.
//       * BriefErrorPresentation -String - error description if a supplier is not available. Undefined if Cancel
//                                                 = False.
//       * Data - String - description of the supplier version.
//
Function ClassifierDataSourceVersion()
	
	If Common.SubsystemExists("StandardSubsystems.AddressClassifier") Then
		ModuleAddressClassifierInternal = Common.CommonModule("AddressClassifierInternal");
		Return ModuleAddressClassifierInternal.DataSupplierVersion();
	EndIf;
	
	Result = AddressClassifierSourceErrorStructure();
	Result.Insert("Version");
	Return Result;
	
EndFunction

// Checks whether classifier is available and puts the result to the storage.
//
Procedure CheckClassifierAvailability(ClassifierAvailabilityAddress, ResultAddress) Export
	
	PutToTempStorage(ClassifierDataSourceVersion(), ResultAddress);
	
EndProcedure

// Returns a state description by state code.
//
//  Parameters:
//      Code - String, Number - a state code.
//
// Returns:
//      String - a full description and short form of a state.
//      Undefined - if the address classifier subsystem is unavailable.
// 
Function CodeState(Val Code)
	
	If Common.SubsystemExists("StandardSubsystems.AddressClassifier") Then
		ModuleAddressClassifier = Common.CommonModule("AddressClassifier");
		Return ModuleAddressClassifier.StateDescriptionByCode(Code);
	EndIf;
	
	Return Undefined;
	
EndFunction

// Returns a structure describing a locality according to the current address classifier's hierarchy.
//   Structure key names may vary depending on the classifier.
//  
//
//  Parameters:
//      ID - UUID - Object ID. If specified, the structure is filled with data for this object.
//                                                
//      ClassifierOption                   - String - the classifier kind.
// 
// Returns:
//      Structure - locality details.
//
Function AttributesListLocality(AddressObjectInfo = Undefined) Export
	
	Address = ContactsManager.NewContactInformationDetails(Enums.ContactInformationTypes.Address);
	
	If AddressObjectInfo = Undefined Then
		Return Address;
	EndIf;
	
	If Not Common.SubsystemExists("StandardSubsystems.AddressClassifier") Then
		Return Undefined;
	EndIf;
	
	// Fiild in daya by the classifier.
	ModuleAddressClassifierInternal = Common.CommonModule("AddressClassifierInternal");
	AddressInformation = ModuleAddressClassifierInternal.RelevantAddressInfo(AddressObjectInfo);
	If NOT ValueIsFilled(AddressInformation.Data) OR AddressInformation.Cancel = True Then
		Return Address;
	EndIf;
	
	FillPropertyValues(Address, AddressInformation.Data, "addressType,codeKLADR,id,ifnsFLAreaCode,ifnsFLCode,ifnsULAreaCode,ifnsULCode,okato,oktmo,ZIPCode,value");
	
	If IsBlankString(Address.Country) Then
		Address.Insert("Country", String(AddressManagerClientServer.MainCountry()));
	EndIf;

	DataStructure = AddressInformation.Data;
	For each LevelName In AddressLevelsMapping() Do
		
		Address[LevelName]          = DataStructure[LevelName];
		Address[LevelName + "Type"] = DataStructure[LevelName + "Type"];
		Address[LevelName + "Id"]   = DataStructure[LevelName + "Id"];
		
	EndDo;
	
	Return Address;
EndFunction

Function AddressLevelsMapping()
	Levels = New Array;
	Levels.Add("Area");
	Levels.Add("MunDistrict");
	Levels.Add("District");
	Levels.Add("Settlement");
	Levels.Add("City");
	Levels.Add("CityDistrict");
	Levels.Add("Locality");
	Levels.Add("Territory");
	Levels.Add("Street");
	
	Return Levels;
	
EndFunction

Procedure CheckAddress(AddressInXML, CheckResult, CheckParametersAddresses = Undefined) Export
	
	If IsBlankString(AddressInXML) Then
		CheckResult.Result = "NotChecked";
		Return;
	EndIf;
	
	Address = ContactsManager.ContactInformationInJSON(AddressInXML);
	HasErrors = False;
	
	OnlyNationalAddress = True;
	If TypeOf(CheckParametersAddresses) = Type("CatalogRef.ContactInformationKinds") Then
		CheckParameters = ContactsManagerInternal.ContactInformationKindStructure(CheckParametersAddresses);
		OnlyNationalAddress = CheckParameters.OnlyNationalAddress;
	Else
		CheckParameters = ContactsManagerInternal.ContactInformationKindStructure();
		If CheckParametersAddresses <> Undefined Then
			If CheckParametersAddresses.Property("OnlyNationalAddress") AND ValueIsFilled(CheckParametersAddresses.OnlyNationalAddress) Then
				OnlyNationalAddress = CheckParametersAddresses.OnlyNationalAddress;
			EndIf;
		EndIf;
		CheckParameters.CheckValidity = True;
	EndIf;
	
	CheckParameters.Insert("OnlyNationalAddress", OnlyNationalAddress);
	ErrorsList = XDTOAddressFillingErrors(Address, CheckParameters);
	
	If ErrorsList.Count() = 0 Then
		CheckResult.Result = "Correct";
	Else
		If NOT ErrorsList[0].Check Then
			CheckResult.Result = "NotChecked";
		Else
			CheckResult.Result = "ContainsErrors";
		EndIf;
	EndIf;
	
	CheckResult.ErrorsList = ErrorsList;
	
	
EndProcedure

// Returns classifier data by ZIP code.
//
// Parameters:
//     ZipCode - String, Number - a zip code for which you need to receive data.
//
//     AdditionalParameters - Structure - describes the search settings. Contains a set of optional fields:
//         * HideObsolete - Boolean - a flag specifying that obsolete addresses must be excluded from the list. The default value is False.
//         * AddressFormat - String - a classifier type.
//
// Returns:
//     Structure - found options. Contains fields:
//       * Cancel - Boolean - supplier is not available. 
//       * DetailedErrorPresentation - String - error description if a supplier is not available. Undefined if Cancel
//                                                 = False.
//       * BriefErrorPresentation -String - error description if a supplier is not available. Undefined if Cancel
//                                                 = False.
//       * PresentationCommonPart -String - a common part of the address presentations.
//       * Data - ValueTable - contains data for selection. Columns:
//                                           ** NonRelevant - Boolean - check box specifying that a data string is obsolete.
//                                           ** ID - UUID - a classifier code used to search for 
//                                                                                        options by ZIP code.
//                                           ** Presentation - String - an option presentation.
//
Function ClassifierAddressByZipCode(Val Index, Val AdditionalParameters) Export
	
	If Common.SubsystemExists("StandardSubsystems.AddressClassifier") Then
		
		NumberType = New TypeDescription("Number");
		IndexNumber = NumberType.AdjustValue(Index);
		
		ModuleAddressClassifierInternal = Common.CommonModule("AddressClassifierInternal");
		Return ModuleAddressClassifierInternal.AddressesByClassifierZIPCode(IndexNumber, AdditionalParameters);
		
	EndIf;
	
	Result = AddressClassifierSourceErrorStructure();
	Result.Insert("Data", New ValueTable);
	Return Result;
	
EndFunction

// Returns classifier data for a selection field by level.
//
// Parameters:
//     Parent - UUID - a parent object.
//     Level - Number - Required data level. 1-7, 90, 91 - address objects, -1
//                                                         - landmarks.
//     AdditionalParameters - Structure - search settings description. Fields:
//         * HideObsolete - Boolean - a flag specifying that obsolete addresses must be excluded from the list. Default
//                                                        False.
//         * AddressFormat - String - a classifier type.
//
//         * PortionSize - Number - optional portion size of returned data. If not specified or 0, 
//                                                    returns all items.
//         * FirstRecord - UUID - Item from which the data batch starts. Item itself is not included 
//                                                    in the selection.
//         * Sorting - String - Sort direction for a batch.
//
// Returns:
//     Structure - found options. Contains fields:
//       * Cancel - Boolean - supplier is not available. 
//       * DetailedErrorPresentation - String - error description if a supplier is not available. Undefined if Cancel
//                                                 = False.
//       * BriefErrorPresentation -String - error description if a supplier is not available. Undefined if Cancel
//                                                 = False.
//       * Title - String - Selection offer string.
//       * Data - ValueTable - contains data for selection. Columns:
//             ** NonRelevant - Boolean - check box specifying that a data string is obsolete.
//             ** ID - UUID - a classifier code used to search for options by ZIP code.
//             ** Presentation - String - an option presentation.
//
Function AddressesForInteractiveSelection(Parent, Level, AddressType, AdditionalParameters) Export
	
	If Common.SubsystemExists("StandardSubsystems.AddressClassifier") Then
		ModuleAddressClassifierInternal = Common.CommonModule("AddressClassifierInternal");
		Return ModuleAddressClassifierInternal.AddressesForInteractiveSelection(Parent, Level, AddressType, AdditionalParameters);
	EndIf;
	
	Result = AddressClassifierSourceErrorStructure();
	Result.Insert("Title");
	Result.Insert("Data", New ValueTable);
	Return Result;

EndFunction

// Returns a structure with the "Data" field containing the list used for locality auto completion 
//  by hierarchical presentation.
//
//  Parameters:
//      Text - String - a text of auto completion.
//      AdditionalParameters - Structure - describes the search settings. Contains a set of optional fields:
//         * HideObsolete - Boolean - a flag specifying that obsolete addresses must be excluded from the list. Default
//                                                        False.
//         * AddressFormat - String - a classifier type.
//
// Returns:
//       * Cancel - Boolean - supplier is not available. 
//       * DetailedErrorPresentation - String - error description if a supplier is not available. Undefined if Cancel
//                                                 = False.
//       * BriefErrorPresentation -String - error description if a supplier is not available. Undefined if Cancel
//                                                 = False.
//       * PresentationCommonPart -String - a common part of the address presentations.
//       * Data - ValueList - result for auto completion.
//
Function LocalityAutoCompleteList(Text, AdditionalParameters) Export
	Result = New Structure("Data", New ValueList);
	AddressClassifierSourceErrorStructure(Result);
	If Not Common.SubsystemExists("StandardSubsystems.AddressClassifier") Then
		Result.Cancel = True;
		Result.BriefErrorPresentation = NStr("ru='Адресные сведения отсутствуют.'; en = 'There is no address information.'; pl = 'Brak informacji o adresach.';es_ES = 'No hay información de dirección.';es_CO = 'No hay información de dirección.';tr = 'Adres bilgisi yok.';it = 'Non ci sono informazioni di indirizzo.';de = 'Es gibt keine Adressinformationen.'");
		Return Result;
	EndIf;
	
	ModuleAddressClassifierInternal = Common.CommonModule("AddressClassifierInternal");
	Result.Data = ModuleAddressClassifierInternal.AutoCompleteOptions(Text, AdditionalParameters);
	
	Return Result;
EndFunction

// Returns a structure with the ChoiceData field containing the list used for street auto completion 
//  by superiority-based hierarchical presentation.
//
//  Parameters:
//      Text - String - a text of auto completion.
//      AutoCompleteParameters - Structure - describes the search settings. Contains a set of optional fields:
//         * ID - UUID - a parent address object.
//         * AddressType - String - a type of used address.
//
// Returns:
//       * Cancel - Boolean - supplier is not available. 
//       * DetailedErrorPresentation - String - error description if a supplier is not available. Undefined if Cancel
//                                                 = False.
//       * BriefErrorPresentation -String - error description if a supplier is not available. Undefined if Cancel
//                                                 = False.
//       * Data - ValueList - result for auto completion.
//
Function StreetAutoCompleteList(Text, AutoCompleteParameteres) Export
	
	Result = New Structure("Data", New ValueList);
	AddressClassifierSourceErrorStructure(Result);
	
	ChoiceData              = New ValueList;
	Level                   = 7;
	ParentID = AutoCompleteParameteres.ID;
	AddressType                 = AutoCompleteParameteres.AddressType;
	
	ModuleAddressClassifierInternal = Common.CommonModule("AddressClassifierInternal");
	Result = ModuleAddressClassifierInternal.AddressLevelObjects(ParentID, Level, AddressType, Text);
	
	Return Result;
	
EndFunction

// Returns the list of values containing the house numbers for the auto completion.
//
//  Parameters:
//      AddressObjectID         - UUID - a locality or a street.
//      SearchString - String - a text of auto completion.
// Returns:
//       ValueList - a result for auto completion.
//
Function HouseNumberAutoCompleteList(AddressObjectID, SearchString) Export
	
	HouseOptions = New ValueList;
	
	HouseList = HouseList(AddressObjectID, SearchString);
	If HouseList <> Undefined Then
		HouseOptions = New ValueList;
		For each Row In HouseList Do
			HouseOptions.Add(Row.Value, Row.Presentation);
		EndDo;
	EndIf;
	
	Return HouseOptions;
EndFunction

// Returns a list of houses by address object ID, similarity search.
//
// Parameters:
//     AddressObjectID - UUID - Parent object.
//     SearchString - String - Text, filter in the house list.
//
// Returns:
//     ValueTable - found options.
//
Function HouseList(AddressObjectID, SearchString = "", BatchOnSearch = 20) Export
	
	If Common.SubsystemExists("StandardSubsystems.AddressClassifier") Then
		ModuleAddressClassifierInternal = Common.CommonModule("AddressClassifierInternal");
		HouseList = ModuleAddressClassifierInternal.HouseList(AddressObjectID, SearchString, BatchOnSearch);
		Return HouseList;
	EndIf;
	
	Return Undefined;
	
EndFunction

#EndRegion

//======================================================================================================================
// Internal

// Internal, for serialization purposes.
Function AddressDeserializationCommon(Val FieldsValues, Val Presentation, Val ExpectedType = Undefined)
	
	If ContactsManagerClientServer.IsXMLContactInformation(FieldsValues) Then
		// Common format of contact information.
		Return ContactsManagerInternal.ContactsFromXML(FieldsValues, ExpectedType);
	EndIf;
	
	If ExpectedType <> Undefined Then
		If ExpectedType <> Enums.ContactInformationTypes.Address Then
			Raise NStr("ru = 'Ошибка десериализации контактной информации, ожидается адрес'; en = 'Contact information deserialization error. Address is expected.'; pl = 'Błąd deserializowania danych kontaktowych. Oczekiwany jest Adres.';es_ES = 'Información de contacto error de deserialización. Dirección se espera.';es_CO = 'Información de contacto error de deserialización. Dirección se espera.';tr = 'İletişim bilgileri seri kaldırma hatası. Adres bekleniyor.';it = 'Errore nella deserializzazione dell''indirizzo. L''indirizzo è atteso.';de = 'Fehler bei der Deserialisierung von Kontaktinformationen. Die Adresse wird erwartet.'");
		EndIf;
	EndIf;
	
	// Old format with line separator and equality.
	Namespace = ContactsManagerClientServer.Namespace();
	
	Result = XDTOFactory.Create(XDTOFactory.Type(Namespace, "ContactInformation"));
	
	Result.Comment = "";
	Result.Content      = XDTOFactory.Create(XDTOFactory.Type(Namespace, "Address"));
	
	MainCountryName  = Upper(AddressManagerClientServer.MainCountry().Description);
	ApartmentItem = Undefined;
	BuildingUnitItem   = Undefined;
	HouseItem      = Undefined;
	
	// National
	NationalAddress = XDTOFactory.Create(XDTOFactory.Type(AddressManager.Namespace(), "AddressUS"));
	
	// Common composition
	Address = Result.Content;
	Address.Country = MainCountryName; // Default country
	AddressDomestic = True;
	
	FieldValueType = TypeOf(FieldsValues);
	If FieldValueType = Type("ValueList") Then
		FieldsList = FieldsValues;
	ElsIf FieldValueType = Type("Structure") Then
		FieldsList = ContactsManagerClientServer.ConvertStringToFieldList(
			AddressManagerClientServer.FieldsString(FieldsValues, False));
	Else
		// Already transformed to a string
		FieldsList = ContactsManagerClientServer.ConvertStringToFieldList(FieldsValues);
	EndIf;
	
	ApartmentTypeUndefined = True;
	UnitTypeUndefined  = True;
	HouseTypeUndefined     = True;
	PresentationField      = "";
	
	For Each ListItem In FieldsList Do
		FieldName = Upper(ListItem.Presentation);
		
		If FieldName="INDEXOF" Then
			ZipCodeItem = GenerateAdditionalAddressItem(NationalAddress);
			ZipCodeItem.AddressItemType = AddressManagerClientServer.ZipCodeSerializationCode();
			ZipCodeItem.Value = ListItem.Value;
			
		ElsIf FieldName = "COUNTRY" Then
			Address.Country = ListItem.Value;
			If Upper(ListItem.Value) <> MainCountryName Then
				AddressDomestic = False;
			EndIf;
			
		ElsIf FieldName = "COUNTRYCODE" Then
			// No action required
			
		ElsIf FieldName = "STATECODE" Then
			NationalAddress.USTerritorialEntitiy = CodeState(ListItem.Value);
			
		ElsIf FieldName = "STATE" Then
			NationalAddress.USTerritorialEntitiy = ListItem.Value;
			
		ElsIf FieldName = "DISTRICT" Then
			If NationalAddress.MunicipalEntityDistrictProperty = Undefined Then
				NationalAddress.MunicipalEntityDistrictProperty = XDTOFactory.Create( NationalAddress.Type().Properties.Get("MunicipalEntityDistrictProperty").Type )
			EndIf;
			NationalAddress.MunicipalEntityDistrictProperty.District = ListItem.Value;
			
		ElsIf FieldName = "CITY" Then
			NationalAddress.City = ListItem.Value;
			
		ElsIf FieldName = "LOCALITY" Then
			NationalAddress.Settlmnt = ListItem.Value;
			
		ElsIf FieldName = "STREET" Then
			NationalAddress.Street = ListItem.Value;
			
		ElsIf FieldName = "HOUSETYPE" Then
			If HouseItem = Undefined Then
				HouseItem = GenerateNumberOfAdditionalAddressItem(NationalAddress);
			EndIf;
			HouseItem.Type = AddressManagerClientServer.AddressingObjectSerializationCode(ListItem.Value);
			HouseTypeUndefined = False;
			
		ElsIf FieldName = "HOUSE" Then
			If HouseItem = Undefined Then
				HouseItem = GenerateNumberOfAdditionalAddressItem(NationalAddress);
			EndIf;
			HouseItem.Value = ListItem.Value;
			
		ElsIf FieldName = "BUILDINGUNITTYPE" Then
			If BuildingUnitItem = Undefined Then
				BuildingUnitItem = GenerateNumberOfAdditionalAddressItem(NationalAddress);
			EndIf;
			BuildingUnitItem.Type = AddressManagerClientServer.AddressingObjectSerializationCode(ListItem.Value);
			UnitTypeUndefined = False;
			
		ElsIf FieldName = "BUILDINGUNIT" Then
			If BuildingUnitItem = Undefined Then
				BuildingUnitItem = GenerateNumberOfAdditionalAddressItem(NationalAddress);
			EndIf;
			BuildingUnitItem.Value = ListItem.Value;
			
		ElsIf FieldName = "APARTMENTTYPE" Then
			If ApartmentItem = Undefined Then
				ApartmentItem = GenerateNumberOfAdditionalAddressItem(NationalAddress);
			EndIf;
			ApartmentItem.Type = AddressManagerClientServer.AddressingObjectSerializationCode(ListItem.Value);
			ApartmentTypeUndefined = False;
			
		ElsIf FieldName = "APARTMENT" Then
			If ApartmentItem = Undefined Then
				ApartmentItem = GenerateNumberOfAdditionalAddressItem(NationalAddress);
			EndIf;
			ApartmentItem.Value = ListItem.Value;
			
		ElsIf FieldName = "PRESENTATION" Then
			PresentationField = TrimAll(ListItem.Value);
			
		EndIf;
		
	EndDo;
	
	// Default preferences
	If HouseTypeUndefined AND HouseItem <> Undefined Then
		HouseItem.Type = AddressManagerClientServer.AddressingObjectSerializationCode("House");
	EndIf;
	
	If UnitTypeUndefined AND BuildingUnitItem <> Undefined Then
		BuildingUnitItem.Type = AddressManagerClientServer.AddressingObjectSerializationCode("BuildingUnit");
	EndIf;
	
	If ApartmentTypeUndefined AND ApartmentItem <> Undefined Then
		ApartmentItem.Type = AddressManagerClientServer.AddressingObjectSerializationCode("Apartment");
	EndIf;
	
	// Presentation with priorities.
	If Not IsBlankString(Presentation) Then
		Result.Presentation = Presentation;
	Else
		Result.Presentation = PresentationField;
	EndIf;
	
	Address.Content = ?(AddressDomestic, NationalAddress, Result.Presentation);
	
	Return Result;
EndFunction

// Converts a string into XDTO address contacts.
//
//  Parameters:
//      FieldsValues - String - serialized information, fields values.
//      Presentation - String superiority-based presentation. Used for parsing purposes if 
//                               FieldsValues is empty.
//      ExpectedType - EnumRef.ContactsType - an optional type for control.
//
//  Returns:
//      XDTOObject - contacts.
//
Function XMLAddressInXDTO(Val FieldsValues, Val Presentation = "", Val ExpectedType = Undefined) Export
	
	If Metadata.DataProcessors.Find("AdvancedContactInformationInput") <> Undefined Then
		
		ValueType = TypeOf(FieldsValues);
		ParseByFields = (ValueType = Type("ValueList") Or ValueType = Type("Structure")
			Or (ValueType = Type("String") AND Not IsBlankString(FieldsValues)));
		If ParseByFields Then
			// Parsing the field values.
			Return AddressDeserializationCommon(FieldsValues, Presentation, ExpectedType);
		EndIf;
		
		// Parsing the address presentation by classifier.
		If Common.SubsystemExists("StandardSubsystems.AddressClassifier") Then
			Return GenerateAddressByPresentation(Presentation);
		EndIf;
		
	EndIf;
	
	// Empty object with presentation.
	Namespace = ContactsManagerClientServer.Namespace();
	Result = XDTOFactory.Create(XDTOFactory.Type(Namespace, "ContactInformation"));
	Result.Content = XDTOFactory.Create(XDTOFactory.Type(Namespace, "Address"));
	Result.Content.Content = Presentation;
	Result.Presentation = Presentation;
	Return Result;
	
EndFunction

Function GenerateAddressByPresentation(Presentation)
	
	Address = ContactsManager.ContactsByPresentation(Presentation, Enums.ContactInformationTypes.Address);
	XML = ContactsManager.ContactInformationToXML(Address, Presentation, Enums.ContactInformationTypes.Address);
	Return ContactsManagerInternal.XMLAddressInXDTO(XML, Presentation, Enums.ContactInformationTypes.Address);
	
EndFunction

// Returns the hierarchical presentation of locality.
//
//  Parameters:
//      AddressObject - XDTOObject - RF address.
//
//  Returns:
//      String - presentation.
//
Function LocalityPresentation(AddressObj) Export
	
	AddressLevelsNoShortForms = New Map();
	AddressLevelsNoShortForms.Insert("MunDistrict", True);
	AddressLevelsNoShortForms.Insert("Settlement",  True);
	
	If NOT AddressObj.Property("AddressType") Then
		AddressFieldsList = "Area,City";
	ElsIf AddressManagerClientServer.IsMunicipalAddress(AddressObj.AddressType) Then
		AddressFieldsList = "Area,MunDistrict,Settlement,CityDistrict,Locality,Territory";
	Else
		AddressFieldsList = "Area,District,City,CityDistrict,Locality,Territory";
	EndIf;
	FieldsList = StrSplit(AddressFieldsList, ",");
	
	Address = New Array;
	For each FieldName In FieldsList Do
		If AddressObj.Property(FieldName) AND ValueIsFilled(AddressObj[FieldName]) Then
			LevelPresentation = AddressObj[FieldName]
				+ ?(AddressLevelsNoShortForms.Get(FieldName) = Undefined, " " + AddressObj[FieldName + "Type"], "");
			Address.Add(TrimAll(LevelPresentation));
		EndIf;
	EndDo;
	
	Return StrConcat(Address, ", ");
	
EndFunction

//======================================================================================================================
// Structure and address fields.

// Returns the extracted XDTO of a domestic address or Undefined for a foreign address.
//
//  Parameters:
//      InformationObject - XDTODataObject - contacts or XDTO of address.
//
//  Returns:
//      XDTODataObject - a domestic address.
//      Undefined - no domestic address.
//
Function NationalAddress(InformationObject)
	Result = Undefined;
	XDTOType   = Type("XDTODataObject");
	
	If TypeOf(InformationObject) = XDTOType Then
		Namespace = ContactsManagerClientServer.Namespace();
		
		If InformationObject.Type() = XDTOFactory.Type(Namespace, "ContactInformation") Then
			Address = InformationObject.Content;
		Else
			Address = InformationObject;
		EndIf;
		
		If TypeOf(Address) = XDTOType AND Address.Type() = XDTOFactory.Type(Namespace, "Address") Then
			Address = Address.Content;
		EndIf;
		
		If TypeOf(Address) = XDTOType Then
			Result = Address;
		EndIf;
	EndIf;
	
	Return Result;
EndFunction

// Reads and sets address zip code.
//
//  Parameters:
//      XDTOAddress     - XDTODataObject - a contact information or XDTO of an address.
//      NewValue - String - a value to be set.
//
//  Returns:
//      String - zip code.
//
Function AddressZipCode(XDTOAddress, NewValue = Undefined) Export
	
	LocalAddress = NationalAddress(XDTOAddress);
	If LocalAddress = Undefined Then
		Return Undefined;
	EndIf;
	
	If NewValue = Undefined Then
		// Read
		Result = LocalAddress.Get( AddressManagerClientServer.ZipCodeXPath() );
		If Result <> Undefined Then
			Result = Result.Value;
		EndIf;
		Return Result;
	EndIf;
	
	// Record
	PostalCodeCode = AddressManagerClientServer.ZipCodeSerializationCode();
	
	PostalCodeRecord = LocalAddress.Get(AddressManagerClientServer.ZipCodeXPath());
	If PostalCodeRecord = Undefined Then
		PostalCodeRecord = LocalAddress.AdditionalAddressItem.Add(XDTOFactory.Create(XDTOAddress.AdditionalAddressItem.OwningProperty.Type));
		PostalCodeRecord.AddressItemType = PostalCodeCode;
	EndIf;
	
	PostalCodeRecord.Value = TrimAll(NewValue);
	Return NewValue;
EndFunction

// Reads and sets an address district.
//
//  Parameters:
//      XDTOAddress     - XDTODataObject - a contact information or XDTO of an address.
//      NewValue - String - a value being set.
//
//  Returns:
//      String - a new value.
//
Function AddressDistrict(XDTOAddress, NewValue = Undefined)
	
	If NewValue = Undefined Then
		// Read
		
		Result = Undefined;
		
		XDTODataType = XDTOAddress.Type();
		If XDTODataType = XDTOFactory.Type(AddressManager.Namespace(), "AddressUS") Then
			LocalAddress = XDTOAddress;
		Else
			LocalAddress = XDTOAddress.Content;
		EndIf;
		
		If TypeOf(LocalAddress) = Type("XDTODataObject") Then
			Return GetXDTOObjectAttribute(LocalAddress, AddressManagerClientServer.DistrictXPath());
		EndIf;
		
		Return Undefined;
	EndIf;
	
	// Record
	Record = MunicipalEntityDistrictProperty(XDTOAddress);
	Record.District = NewValue;
	Return NewValue;
EndFunction

Function MunicipalEntityDistrictProperty(LocalAddress)
	If LocalAddress.MunicipalEntityDistrictProperty <> Undefined Then
		Return LocalAddress.MunicipalEntityDistrictProperty;
	EndIf;
	
	LocalAddress.MunicipalEntityDistrictProperty = XDTOFactory.Create( LocalAddress.Properties().Get("MunicipalEntityDistrictProperty").Type );
	Return LocalAddress.MunicipalEntityDistrictProperty;
EndFunction

// Returns value of 90(additional item) and 91(subordinate) levels from the address.
//
Function AdditionalItemsValue(Val XDTOAddress) Export
	
	Result = New Structure("AdditionalItem, SubordinateItem");
	
	LocalAddress = NationalAddress(XDTOAddress);
	If LocalAddress = Undefined Then
		Return Result;
	EndIf;
	
	
	AdditionalAddressItem = FindAdditionalAddressItem(LocalAddress).Value;

	Result.AdditionalItem = AdditionalAddressItem;
	Result.SubordinateItem = AdditionalAddressItem(LocalAddress, AddressManagerClientServer.AdditionalAddressingObject(91));
	
	Return Result;
	
EndFunction

// Read additional address item in its path.
//
//  Parameters:
//      XDTOAddress     - XDTODataObject - a contact information or XDTO of an address.
//      ItemXPath - String - path to the item.
//
//  Returns:
//      String - an item value.
Function AdditionalAddressItem(XDTOAddress, ItemXPath)
	
	LocalAddress = NationalAddress(XDTOAddress);
	If LocalAddress = Undefined Then
		Return Undefined;
	EndIf;
	
	Result = LocalAddress.Get(ItemXPath);
	If Result <> Undefined Then
		Return Result.Value;
	EndIf;
	
	Return Result;
EndFunction

// Returns additional address.
//
Function FindAdditionalAddressItem(LocalAddress)
	
	AdditionalAddressItemOptions = AdditionalAddressItemOptions();
	
	XPath = "";
	AdditionalAddressItem = Undefined;
	For each AdditionalAddressItemOption In AdditionalAddressItemOptions Do
		XPath = AddressManagerClientServer.AdditionalAddressingObject(90, AdditionalAddressItemOption);
		AdditionalAddressItem = AdditionalAddressItem(LocalAddress, XPath);
		If AdditionalAddressItem <> Undefined Then
			Break;
		EndIf;
	EndDo;
	
	Return New Structure("Value, XPath", AdditionalAddressItem, XPath);
	
EndFunction

Function AdditionalAddressItemOptions()
	
	AdditionalAddressItemOptions = New Array;
	AdditionalAddressItemOptions.Add("HS");
	AdditionalAddressItemOptions.Add("GCC");
	AdditionalAddressItemOptions.Add("TER");
	AdditionalAddressItemOptions.Add("");
	Return AdditionalAddressItemOptions;

EndFunction

Function GenerateNumberOfAdditionalAddressItem(LocalAddress)
	AdditionalAddressItem = GenerateAdditionalAddressItem(LocalAddress);
	AdditionalAddressItem.Number = XDTOFactory.Create(AdditionalAddressItem.Type().Properties.Get("Number").Type);
	Return AdditionalAddressItem.Number;
EndFunction

Function GenerateAdditionalAddressItem(LocalAddress)
	AdditionalAddressItemProperty = LocalAddress.AdditionalAddressItem.OwningProperty;
	AdditionalAddressItem = XDTOFactory.Create(AdditionalAddressItemProperty.Type);
	LocalAddress.AdditionalAddressItem.Add(AdditionalAddressItem);
	Return AdditionalAddressItem;
EndFunction

// Reads buildings and premises from an address, or writes them.
//
//  Parameters:
//      XDTOAddress     - XDTODataObject - a contact information or XDTO of an address.
//      NewValue - Structure - set value. The following fields are expected:
//                          * Buildings - ValueTable - a table with the following columns:
//                                        ** Type      - String - a type of internal classifier of 
//                                                               additional address objects. Example Unit.
//                                        ** Value - string - a house number, apartment number, and so on.
//                          * Premises - ValueTable with columns, similar to the Building field.
//
//  Returns:
//      Structure - current data. Contains fields:
//          * Buildings - ValueTable - a table with the following columns:
//                        ** Type        - String - a type of internal classifier of additional address objects.
//                                                 Example Unit.
//                        ** ShortForm - String -  a short form of a name to be used in a presentation.
//                        ** Value - string - a house number, apartment number, and so on.
//                        ** PathXPath - String - a path to the object value.
//          * Premises - ValueTable with columns, similar to the Building field.
//
Function AddressBuildingsAndPremises(XDTOAddress, NewValue = Undefined) Export
	
	Result = New Structure("Buildings, Premises", 
		ValueTable("Type, Value, ShortForm, XPath, Kind", "Type, Kind"),
		ValueTable("Type, Value, ShortForm, XPath, Kind", "Type, Kind"));
	
	LocalAddress = NationalAddress(XDTOAddress);
	If LocalAddress = Undefined Then
		Return Result;
	EndIf;
	
	If NewValue <> Undefined Then
		// Record
		If NewValue.Property("Buildings") Then
			For Each Row In NewValue.Buildings Do
				InsertBuildingPremise(XDTOAddress, Row.Type, Row.Value);
			EndDo;
		EndIf;
		If NewValue.Property("Premises") Then
			For Each Row In NewValue.Premises Do
				InsertBuildingPremise(XDTOAddress, Row.Type, Row.Value);
			EndDo;
		EndIf;
		Return NewValue
	EndIf;
	
	// Read
	For Each AdditionalItem In LocalAddress.AdditionalAddressItem Do
		If AdditionalItem.Number <> Undefined Then
			ObjectCode = AdditionalItem.Number.Type;
			ObjectType = AddressManagerClientServer.ObjectTypeBySerializationCode(ObjectCode);
			If ObjectType <> Undefined Then
				Kind = ObjectType.Type;
				If Kind = 1 Or Kind = 2 Then
					NewRow = Result.Buildings.Add();
				ElsIf Kind = 3 Then
					NewRow = Result.Premises.Add();
				Else
					NewRow = Undefined;
				EndIf;
				If NewRow <> Undefined Then
					NewRow.Type        = ObjectType.Description;
					NewRow.Value   = AdditionalItem.Number.Value;
					NewRow.ShortForm = ObjectType.ShortForm;
					NewRow.XPath  = AddressManagerClientServer.AdditionalAddressingObjectNumberXPath(NewRow.Type);
					NewRow.Kind        = Kind;
				EndIf;
			Else
				NewRow = Result.Premises.Add();
				NewRow.Type        = AdditionalItem.Number.Type;
				NewRow.Value   = AdditionalItem.Number.Value;
				NewRow.ShortForm = AdditionalItem.Number.Type;
				NewRow.XPath  = AddressManagerClientServer.AdditionalAddressingObjectNumberXPath("2000");
				NewRow.Kind        = 3;
			EndIf;
		EndIf;
	EndDo;
	
	Result.Buildings.Sort("Kind");
	Result.Premises.Sort("Kind");
	
	Return Result;
EndFunction

Function BuildingOrPremiseValue(Data, Options, AllOptionValues)
	
	Result = ValueTable("Type, Value");
	
	For each ObjectInfo In Data Do
		For each Option In Options.TypeOptions Do
			If StrCompare(Option, ObjectInfo.Type) = 0 Then
				FillPropertyValues(Result.Add(), ObjectInfo);
				If Not AllOptionValues Then
					Break;
				EndIf;
			EndIf;
		EndDo;
	EndDo;
	
	Return Result;
	
EndFunction

Procedure InsertBuildingPremise(XDTOAddress, Type, Value)
	If IsBlankString(Value) Then
		Return;
	EndIf;
	
	Record = XDTOAddress.Get(AddressManagerClientServer.AdditionalAddressingObjectNumberXPath(Type));
	If Record = Undefined Then
		Record = XDTOAddress.AdditionalAddressItem.Add( XDTOFactory.Create(XDTOAddress.AdditionalAddressItem.OwningProperty.Type));
		Record.Number = XDTOFactory.Create(Record.Properties().Get("Number").Type);
		Record.Number.Value = Value;
		
		TypeCode = AddressManagerClientServer.AddressingObjectSerializationCode(Type);
		If TypeCode = Undefined Then
			TypeCode = Type;
		EndIf;
		Record.Number.Type = TypeCode
	Else
		Record.Value = Value;
	EndIf;
	
EndProcedure

// Value table constructor.
//
Function ValueTable(ColumnsList, IndexList = "")
	ResultTable = New ValueTable;
	
	For Each KeyValue In (New Structure(ColumnsList)) Do
		ResultTable.Columns.Add(KeyValue.Key);
	EndDo;
	
	IndexRows = StrReplace(IndexList, "|", Chars.LF);
	For PostalCodeNumber = 1 To StrLineCount(IndexRows) Do
		IndexColumns = TrimAll(StrGetLine(IndexRows, PostalCodeNumber));
		For Each KeyValue In (New Structure(IndexColumns)) Do
			ResultTable.Indexes.Add(KeyValue.Key);
		EndDo;
	EndDo;
	
	Return ResultTable;
EndFunction

// Getting object deep property. 
//
Function GetXDTOObjectAttribute(XTDOObject, XPath)
	
	// Line breaks are not expected in XPath.
	PropertyString = StrReplace(StrReplace(XPath, "/", Chars.LF), Chars.LF + Chars.LF, "/");
	
	PropertyCount = StrLineCount(PropertyString);
	If PropertyCount = 1 Then
		Result = XTDOObject.Get(PropertyString);
		If TypeOf(Result) = Type("XDTODataObject") Then 
			Return Result.Value;
		EndIf;
		Return Result;
	EndIf;
	
	Result = ?(PropertyCount = 0, Undefined, XTDOObject);
	For Index = 1 To PropertyCount Do
		Result = Result.Get(StrGetLine(PropertyString, Index));
		If Result = Undefined Then 
			Break;
		EndIf;
	EndDo;
	
	Return Result;
EndFunction

// Sets value by XPath in XDTO address.
//
Procedure SetXDTOAttributeOfObject(XDTODataObject, XPath, Value) Export
	
	If Value = Undefined Then
		Return;
	EndIf;
	
	// XPath parts
	PathParts  = StrReplace(XPath, "/", Chars.LF);
	PathPartsCount = StrLineCount(PathParts);
	
	LeadingObject = XDTODataObject;
	Object        = XDTODataObject;
	
	For Position = 1 To PathPartsCount Do
		PathPart = StrGetLine(PathParts, Position);
		If PathPartsCount = 1 Then
			Break;
		EndIf;
		
		Property = Object.Properties().Get(PathPart);
		If Not Object.IsSet(Property) Then
			Object.Set(Property, XDTOFactory.Create(Property.Type));
		EndIf;
		LeadingObject = Object;
		Object        = Object[PathPart];
	EndDo;
	
	If Object <> Undefined Then
		
		If StrFind(PathPart, "AdditionalAddressItem") = 0 Then
			Object[PathPart] = Value;
		Else
			CodeXPath = Mid(PathPart, 20, 8);
			FieldValue = Object.AdditionalAddressItem.Add(XDTOFactory.Create(Object.AdditionalAddressItem.OwningProperty.Type));
			FieldValue.AddressItemType = CodeXPath;
			FieldValue.Value = Value;
		EndIf;
		
	ElsIf LeadingObject <> Undefined Then
		LeadingObject[PathPart] =  Value;
		
	EndIf;
	
EndProcedure

//======================================================================================================================
// Address check

// Returns the list of address errors.
//
// Parameters:
//     Address - XDTOObject, ValueList, String - address details.
//     InformationKind - CatalogRef.ContactsKinds, Structure - a reference to the matching kind of 
//                         contacts.
//     ResultByGroups - Boolean - if True, an array of error groups will be returned, otherwise a 
//                                  list of values.
//
// Returns:
//     ValueList - if the ResultByGroups parameter equals False. Contains a presentation - an error text, value -
//                      Error field XPath.
//     Array - if the ResultByGroups parameter equals True. Contains structures with the following fields:
//                         ** ErrorType - String - description of error group (type). Possible values:
//                               "PresentationDoesNotMatchFieldsSet"
//                               "MandatoryFieldsNotFilled"
//                               "ShortFormsOfFieldsNotSpecified"
//                               "InvalidFieldCharacters"
//                               "FieldsLengthDoesNotMatch"
//                               "ErrorsByClassifier"
//                         ** Message - String - a detailed error text.
//                         ** Fields - Array - contains the error field description structures. Each 
//                                                 structure has attributes:
//                               *** FieldName - String - an internal ID of the invalid address item.
//                               *** Message - String - a detailed error text for this field.
//
Function XDTOAddressFillingErrors(Val Address, InformationKind, ResultByGroups = False) Export
	
	If TypeOf(Address) = Type("String") Then
		Address = ContactsManagerInternal.JSONStringToStructure(Address);
	EndIf;
	
	If TypeOf(Address) = Type("XDTODataObject") Then
		XMLAddress = ContactsManagerInternal.XDTOContactsInXML(Address);
		Address = ContactsManager.ContactInformationInJSON(XMLAddress);
	EndIf;
	
	Result = ?(ResultByGroups, New Array, New ValueList);
	
	// Check flags
	If TypeOf(InformationKind) = Type("CatalogRef.ContactInformationKinds") Then
		CheckFlags = ContactsManagerInternal.ContactInformationKindStructure(InformationKind);
	Else
		CheckFlags = InformationKind;
	EndIf;
	
	If CheckFlags.InternationalAddressFormat Then
		
		If ContactsManagerClientServer.IsAddressInFreeForm(Address.addressType) Then
			
			AddressPresentation = Address.value;
			If InformationKind.IncludeCountryInPresentation Then
				AddressPresentation = StrReplace(AddressPresentation, Address.country, "");
			EndIf;
			OnlyRomanInString(AddressPresentation, Result, ResultByGroups);
			
		Else
		
			LevelNames = AddressManagerClientServer.AddressLevelsNames(Address.addressType, True);
		
			For each LevelName In LevelNames Do
				
				OnlyRomanInString(Address[LevelName], Result, ResultByGroups);
				If Result.Count() > 0 Then
					Break;
				EndIf;
				
			EndDo;
			
		EndIf;
		
		Return Result;
	EndIf;
	
	// Checking the empty address separately if it has to be filled.
	If Not ContactsManagerInternal.ContactsFilledIn(Address) Then
		// The address is empty
		If CheckFlags.Mandatory Then
			// But it is mandatory to fill
			ErrorText = NStr("ru = 'Адрес не заполнен.'; en = 'The address is required.'; pl = 'Nie wprowadzono adresu.';es_ES = 'Dirección requerida.';es_CO = 'Dirección requerida.';tr = 'Adres gerekli.';it = 'L''indirizzo è richiesto.';de = 'Die Adresse wird benötigt.'");
			
			If ResultByGroups Then
				Result = New Array;
				Result.Add(New Structure("Fields, ErrorType, Message", New Array,
					"MandatoryFieldsNotFilled", ErrorText));
			Else
				Result = New ValueList;
				Result.Add("/", ErrorText);
			EndIf;
			
			Return Result
		EndIf;
		
		// Address is blank but it is not mandatory to fill - it is considered to be valid.
		Return ?(ResultByGroups, New Array, New ValueList);
	EndIf;
	
	LocalAddress = Undefined;
	
	AllErrors = AddressFillErrorsCommonGroups(Address, CheckFlags);
	CheckClassifier = True;
	
	ClassifierErrors = New ValueList;
	If CheckClassifier AND Common.SubsystemExists("StandardSubsystems.AddressClassifier") Then
		FillAddressErrorsByClassifier(Address, CheckFlags, ClassifierErrors);
	EndIf;
		
	If ResultByGroups Then
		ErrorGroupDescription = "ErrorsByClassifier";
		ErrorsCount = ClassifierErrors.Count();
		
		If ErrorsCount = 1 AND ClassifierErrors[0].Value <> Undefined
			AND ClassifierErrors[0].Value.XPath = Undefined Then
			AllErrors.Add(AddressErrorGroup(ErrorGroupDescription, ClassifierErrors[0].Presentation));
			
		ElsIf ErrorsCount > 0 Then
			// Detailed error description
			AllErrors.Add(AddressErrorGroup(ErrorGroupDescription,
				NStr("ru = 'Части адреса не соответствуют адресному классификатору:'; en = 'Address parts do not match the address classifier:'; pl = 'Części adresu nie pasują do klasyfikatora adresu:';es_ES = 'Las partes de la dirección no coinciden con el clasificador de direcciones:';es_CO = 'Las partes de la dirección no coinciden con el clasificador de direcciones:';tr = 'Adres bölümleri adres sınıflandırıcısına uymuyor:';it = 'Parti dell''indirizzo non corrispondono al classificatore indirizzo:';de = 'Adressteile stimmen nicht mit dem Adressklassifikator überein:'")));
				
			ClassifierErrorsGroup = AllErrors[AllErrors.UBound()];
			
			EntityList = "";
			For Each Item In ClassifierErrors Do
				ErrorItem = Item.Value;
				If ErrorItem = Undefined Then
					// Abstract error
					AddAddressFillError(ClassifierErrorsGroup, "", Item.Presentation);
				Else
					AddAddressFillError(ClassifierErrorsGroup, ErrorItem.XPath, Item.Presentation);
					EntityList = EntityList + ", " + ErrorItem.FieldEntity;
				EndIf;
			EndDo;
			
			ClassifierErrorsGroup.Message = ClassifierErrorsGroup.Message + Mid(EntityList, 2);
		EndIf;
		
		Return AllErrors;
	EndIf;
	
	// Adding all data to a list
	Result = New ValueList;
	For Each Folder In AllErrors Do
		For Each Field In Folder.Fields Do
			Result.Add(Field.FieldName, Field.Message, True);
		EndDo;
	EndDo;
	For Each ListItem In ClassifierErrors Do
		Result.Add(ListItem.Value.XPath, ListItem.Presentation, ListItem.Value.AddressChecked);
	EndDo;
	
	Return Result;
EndFunction

Procedure OnlyRomanInString(Value, Val Result, Val ResultByGroups)
	
	If Not StringFunctionsClientServer.OnlyRomanInString(Value, False, "1234567890,") Then
		ErrorText = NStr("ru = 'Адрес в международном формате должен быть набран латиницей.'; en = 'Address in the international format must be entered in Latin characters.'; pl = 'Adres w formacie międzynarodowym musi być wpisany po łacinką.';es_ES = 'La dirección en el formato internacional debe introducirse con letras latinas.';es_CO = 'La dirección en el formato internacional debe introducirse con letras latinas.';tr = 'Uluslararası formattaki adres Latince karakterlerle girilmelidir.';it = 'L''indirizzo nel formato internazionale deve essere inserito in caratteri latini.';de = 'Die Adresse im internationalen Format muss in lateinischen Buchstaben eingegeben werden.'");
		If ResultByGroups Then
			Result.Add(New Structure("Fields, ErrorType, Message", New Array,
			"InternationFormatAddressContainsNotOnlyLatinLetters", ErrorText));
		Else
			Result.Add("/", ErrorText).Check = True;
		EndIf;
	EndIf;

EndProcedure

// General address validation.
//
//  Parameters:
//      AddressData - String, ValueList - XML, XDTO with data of the RF address.
//      InformationKind - CatalogRef.ContactsKinds - a reference to the matching kind of contacts.
//
// Returns:
//      Array - contains structures with the following fields:
//         * ErrorType - String - an error group ID. Can take on the value:
//              "PresentationDoesNotMatchFieldsSet",
//              "MandatoryFieldsNotFilled"
//              "ShortFormsOfFieldsNotSpecified"
//              "InvalidFieldCharacters"
//              "FieldsLengthDoesNotMatch".
//         * Message - String - a detailed error text.
//         * Fields - an array of structures with the following fields:
//             ** FieldName - an internal ID of the invalid field.
//             ** Message - a detailed error text for the field.
//
Function AddressFillErrorsCommonGroups(Val AddressData, Val InformationKind)
	Result = New Array;
	
	MandatoryFieldsNotFilled = AddressErrorGroup("MandatoryFieldsNotFilled",
		NStr("ru = 'Не заполнены обязательные поля:'; en = 'Mandatory fields are not filled in:'; pl = 'Pola obowiązkowe nie są wypełniane:';es_ES = 'Los campos obligatorios no están rellenados:';es_CO = 'Los campos obligatorios no están rellenados:';tr = 'Zorunlu alanlar doldurulmamıştır:';it = 'I campi obbligatori non sono stati compilati:';de = 'Pflichtfelder sind nicht ausgefüllt:'"));
	Result.Add(MandatoryFieldsNotFilled);
	
	ShortFormsOfFieldsNotSpecified = AddressErrorGroup("ShortFormsOfFieldsNotSpecified",
		NStr("ru = 'Не указано сокращение для полей:'; en = 'Short forms are not specified for fields:'; pl = 'Krótkie formularze nie są określone dla pól:';es_ES = 'Las formas cortas no se especifican para los campos:';es_CO = 'Las formas cortas no se especifican para los campos:';tr = 'Alanlar için kısa formlar belirtilmemiş:';it = 'Le forme brevi non sono specificate per i campi:';de = 'Kurzformen sind für Felder nicht vorgesehen:'"));
	Result.Add(ShortFormsOfFieldsNotSpecified);
	
	InvalidFieldCharacters = AddressErrorGroup("IllegalFieldCharacters",
		NStr("ru = 'Найдены недопустимые символы в полях:'; en = 'Invalid characters found in fields:'; pl = 'Nieprawidłowe znaki znalezione w polach:';es_ES = 'Símbolos inválidos encontrados en los campos:';es_CO = 'Símbolos inválidos encontrados en los campos:';tr = 'Alanlarda geçersiz karakterler bulundu:';it = 'Caratteri non validi sono stati trovati nei campi';de = 'Ungültige Zeichen in Feldern:'"));
	Result.Add(InvalidFieldCharacters);
	
	FieldsLengthDoesNotMatch = AddressErrorGroup("FieldsLengthDoesNotMatch",
		NStr("ru = 'Не соответствует установленной длина полей:'; en = 'Field length does not match the set length:'; pl = 'Długość pola nie odpowiada ustawionej długości:';es_ES = 'La longitud del campo no coincide con la longitud del conjunto:';es_CO = 'La longitud del campo no coincide con la longitud del conjunto:';tr = 'Alan uzunluğu ayarlanan uzunlukla eşleşmiyor:';it = 'La lunghezza del campo non corrisponde alla lunghezza impostata:';de = 'Die Feldlänge entspricht nicht der eingestellten Länge:'"));
	Result.Add(FieldsLengthDoesNotMatch);
	
	State = TrimAll(AddressData.Area + " " + AddressData.AreaType);
	If IsBlankString(State) Then
		AddAddressFillError(MandatoryFieldsNotFilled, "USTerritorialEntitiy",
			NStr("ru = 'Не указан регион.'; en = 'The state is blank.'; pl = 'Stan jest pusty.';es_ES = 'Estado no especificado.';es_CO = 'Estado no especificado.';tr = 'Bölge alanı boş.';it = 'La provincia/regione non è compilata.';de = 'Der Staat ist leer.'"), "State");
	EndIf;
		
	// 3) State, District, City, Locality, and Street must have short forms (cyrillic letters only).
	
	AllowedBesidesCyrillicChars = "/,-. 0123456789_N";
	
	// State
	If Not IsBlankString(State) Then
		Field = "USTerritorialEntitiy";
		If IsBlankString(AddressData.AreaType) Then
			AddAddressFillError(ShortFormsOfFieldsNotSpecified, "USTerritorialEntitiy",
				StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Не указано сокращение в названии региона ""%1"".'; en = 'Short form is not specified for state ""%1.""'; pl = 'Krótki formularz nie jest określony dla stanu ""%1.""';es_ES = 'La forma corta no se especifica para el estado ""%1.""';es_CO = 'La forma corta no se especifica para el estado ""%1.""';tr = '""%1 ""Durumu için kısa form belirtilmedi.';it = 'La forma breve non è specificata per la provincia/regione ""%1"".';de = 'Kurzform ist für den Staat ""%1"" nicht angegeben.'"), State), NStr("ru = 'Состояние'; en = 'State'; pl = 'Stan';es_ES = 'Estado';es_CO = 'Estado';tr = 'Bölge';it = 'Provincia/Regione';de = 'Status'"));
		EndIf;
		If Not StringFunctionsClientServer.OnlyLatinInString(State, False, AllowedBesidesCyrillicChars) Then
			AddAddressFillError(InvalidFieldCharacters, Field,
				StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'В названии региона ""%1"" есть не кириллические символы.'; en = 'The state name ""%1"" contains non-Latin characters.'; pl = 'Miasto ""%1"" zawiera znaki spoza alfabetu łacińskiego.';es_ES = 'Nombre de estado ""%1"" contiene símbolos no latinos.';es_CO = 'Nombre de estado ""%1"" contiene símbolos no latinos.';tr = '""%1"" bölge adı Latin harfleri dışında karakterler içeriyor.';it = 'Il nome della Provincia/Stato ""%1"" contiene caratteri non latini.';de = 'Der Staatsname ""%1"" enthält nicht-lateinische Zeichen.'"), State), NStr("ru = 'Состояние'; en = 'State'; pl = 'Stan';es_ES = 'Estado';es_CO = 'Estado';tr = 'Bölge';it = 'Provincia/Regione';de = 'Status'"));
		EndIf
	EndIf;
	
	// District
	District = TrimAll(AddressData.District + " " + AddressData.DistrictType);
	If Not IsBlankString(District) Then
		Field = "District";
		If IsBlankString(AddressData.DistrictType) Then
			AddAddressFillError(ShortFormsOfFieldsNotSpecified, Field,
				StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Не указано сокращение в названии района ""%1"".'; en = 'Short form is not specified in the name of district ""%1"".'; pl = 'Skrócona forma nie jest określona w nazwie powiatu ""%1"".';es_ES = 'Forma corta no está especificada en el nombre de la región ""%1"".';es_CO = 'Forma corta no está especificada en el nombre de la región ""%1"".';tr = '""%1"" Bölge adı altında kısa form belirtilmedi.';it = 'Non è specificata la forma breve nel nome della zona ""%1"".';de = 'Die Kurzform wird nicht im Namen des Bezirks ""%1"" angegeben.'"), District), NStr("ru = 'Район'; en = 'District'; pl = 'Powiat';es_ES = 'Distrito';es_CO = 'Distrito';tr = 'Ilçe';it = 'Quartiere';de = 'Bezirk'"));
		EndIf;
		If Not StringFunctionsClientServer.OnlyLatinInString(District, False, AllowedBesidesCyrillicChars) Then
			AddAddressFillError(InvalidFieldCharacters, Field,
				StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'В названии района ""%1"" есть не кириллические символы.'; en = 'The name of district ""%1"" contains non-Latin characters.'; pl = 'Nazwa powiatu ""%1"" zawiera znaki spoza alfabetu łacińskiego.';es_ES = 'El nombre de la región ""%1"" contiene símbolos no latinos.';es_CO = 'El nombre de la región ""%1"" contiene símbolos no latinos.';tr = '""%1"" bölgesinin adı Latin olmayan karakterler içeriyor.';it = 'Il nome della zona ""%1"" contiene caratteri non latini.';de = 'Der Name des Bezirks ""%1"" enthält nicht-lateinische Zeichen.'"), District), NStr("ru = 'Район'; en = 'District'; pl = 'Powiat';es_ES = 'Distrito';es_CO = 'Distrito';tr = 'Ilçe';it = 'Quartiere';de = 'Bezirk'"));
		EndIf;
	EndIf;
	
	// City
	City = TrimAll(AddressData.City + " " + AddressData.CityType);
	If Not IsBlankString(City) Then
		Field = "City";
		If IsBlankString(AddressData.CityType) Then
			AddAddressFillError(ShortFormsOfFieldsNotSpecified, Field,
				StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Не указано сокращение в названии города ""%1"".'; en = 'Short form is not specified for city ""%1"".'; pl = 'Krótki formularz nie jest określony dla miasta ""%1"".';es_ES = 'La forma corta no se especifica para la ciudad ""%1.""';es_CO = 'La forma corta no se especifica para la ciudad ""%1.""';tr = '""%1"" şehri için kısa form belirtilmemiş.';it = 'La forma breve non è specificata per la città ""%1"".';de = 'Für die Stadt ""%1"" ist keine Kurzform angegeben.'"), City), NStr("ru = 'Город'; en = 'City'; pl = 'Miejscowość';es_ES = 'Ciudad';es_CO = 'Ciudad';tr = 'Şehir';it = 'Città';de = 'Ort'"));
		EndIf;
		If Not StringFunctionsClientServer.OnlyLatinInString(City, False, AllowedBesidesCyrillicChars) Then
			AddAddressFillError(InvalidFieldCharacters, Field,
				StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'В названии города ""%1"" есть не кириллические символы.'; en = 'The name of city ""%1"" contains non-Latin characters.'; pl = 'Nazwa miasta ""%1"" zawiera znaki spoza alfabetu łacińskiego.';es_ES = 'El nombre de la ciudad ""%1"" contiene símbolos no latinos.';es_CO = 'El nombre de la ciudad ""%1"" contiene símbolos no latinos.';tr = '""%1"" şehri adı Latin olmayan karakterler içeriyor.';it = 'Il nome della città ""%1"" contiene caratteri non latini.';de = 'Der Name der Stadt ""%1"" enthält nicht-lateinische Zeichen.'"), City), NStr("ru = 'Город'; en = 'City'; pl = 'Miejscowość';es_ES = 'Ciudad';es_CO = 'Ciudad';tr = 'Şehir';it = 'Città';de = 'Ort'"));
		EndIf;
	EndIf;
	
	// Locality.
	Locality = TrimAll(AddressData.Locality + " " + AddressData.LocalityType);
	If Not IsBlankString(Locality) Then
		Field = "Settlmnt";
		If IsBlankString(AddressData.LocalityType) Then
			AddAddressFillError(ShortFormsOfFieldsNotSpecified, Field,
				StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Не указано сокращение в названии населенного пункта ""%1"".'; en = 'Short form is not specified for locality ""%1"".'; pl = 'Krótki formularz nie jest określony dla miejscowości ""%1"".';es_ES = 'La forma corta no se ha especificada para localidad ""%1"".';es_CO = 'La forma corta no se ha especificada para localidad ""%1"".';tr = '""%1"" bölgesi için kısa biçim belirtilmemiş.';it = 'Il nome breve non è specificato per la località ""%1"".';de = 'Für den Ort ""%1"" ist keine Kurzform angegeben.'"), Locality),
					NStr("ru = 'Населенный пункт'; en = 'Locality'; pl = 'Miejscowość';es_ES = 'Liquidación';es_CO = 'Liquidación';tr = 'Yerleşim yeri';it = 'Località';de = 'Siedlung'"));
		EndIf;
		If Not StringFunctionsClientServer.OnlyLatinInString(Locality, False, AllowedBesidesCyrillicChars) Then
			AddAddressFillError(InvalidFieldCharacters, Field,
				StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'В названии населенного пункта ""%1"" есть не кириллические символы.'; en = 'The name of locality ""%1"" contains non-Latin characters.'; pl = 'Nazwa dla miejscowości ""%1"" zawiera znaki spoza alfabetu łacińskiego.';es_ES = 'El nombre de la localidad ""%1"" contiene símbolos no latinos.';es_CO = 'El nombre de la localidad ""%1"" contiene símbolos no latinos.';tr = '""%1"" bölge adı Latin olmayan karakterler içeriyor.';it = 'Il nome della località ""%1"" contiene caratteri non latini.';de = 'Der Ortsname ""%1"" enthält nicht-lateinische Zeichen.'"), Locality),
					NStr("ru = 'Населенный пункт'; en = 'Locality'; pl = 'Miejscowość';es_ES = 'Liquidación';es_CO = 'Liquidación';tr = 'Yerleşim yeri';it = 'Località';de = 'Siedlung'"));
		EndIf;
	EndIf;
	
	// Street
	Street = TrimAll(AddressData.Street + " " + AddressData.StreetType);
	If Not IsBlankString(Street) Then
		Field = "Street";
		If IsBlankString(AddressData.StreetType) Then
			AddAddressFillError(ShortFormsOfFieldsNotSpecified, Field,
				StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Не указано сокращение в названии улицы ""%1"".'; en = 'Short form is not specified for street ""%1"".'; pl = 'Krótki formularz nie jest określony dla ulicy ""%1"".';es_ES = 'La forma corta no se especifica para la calle ""%1"".';es_CO = 'La forma corta no se especifica para la calle ""%1"".';tr = '""%1 ""caddesi için kısa form belirtilmedi.';it = 'La forma breve non è specificata per la via ""%1"".';de = 'Für die Straße ""%1"" ist keine Kurzform angegeben.'"), Street), NStr("ru = 'Улица'; en = 'Street'; pl = 'Ulica';es_ES = 'Calle';es_CO = 'Calle';tr = 'Sokak';it = 'Via';de = 'Straße'"));
		EndIf;
		If Not StringFunctionsClientServer.OnlyLatinInString(Street, False, AllowedBesidesCyrillicChars) Then
			AddAddressFillError(InvalidFieldCharacters, Field,
				StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'В названии улицы ""%1"" есть не кириллические символы.'; en = 'The name of street ""%1"" contains non-Latin characters.'; pl = 'Nazwa ulicy ""%1"" zawiera znaki spoza alfabetu łacińskiego.';es_ES = 'El nombre de la calle ""%1"" contiene símbolos no latinos.';es_CO = 'El nombre de la calle ""%1"" contiene símbolos no latinos.';tr = '""%1"" sokak adı Latin olmayan karakterler içeriyor.';it = 'Nel nome della via ""%1"" ci sono caratteri non latini.';de = 'Der Name der Straße ""%1"" enthält nicht-lateinische Zeichen.'"), Street), NStr("ru = 'Улица'; en = 'Street'; pl = 'Ulica';es_ES = 'Calle';es_CO = 'Calle';tr = 'Sokak';it = 'Via';de = 'Straße'"));
		EndIf;
	EndIf;
	
	// 4) ZipCode - must contain 6 digits, if any.
	If Not IsBlankString(AddressData.ZipCode) Then
		Field = "IndexOf";
		If StrLen(AddressData.ZipCode) <> 6 Or Not StringFunctionsClientServer.OnlyNumbersInString(AddressData.ZipCode) Then
			AddAddressFillError(FieldsLengthDoesNotMatch, Field,
				NStr("ru = 'Почтовый индекс должен состоять из 6 цифр.'; en = 'The ZIP code must contain 6 digits.'; pl = 'Kod pocztowy musi zawierać 6 cyfr.';es_ES = 'El código ZIP debe contener 6 símbolos.';es_CO = 'El código ZIP debe contener 6 símbolos.';tr = 'Posta kodu 6 hane içermelidir.';it = 'Il codice ZIP deve contenere 6 cifre.';de = 'Die Postleitzahl muss aus 6 Ziffern bestehen.'"),
				NStr("ru = 'Индекс'; en = 'Index'; pl = 'Kod pocztowy';es_ES = 'Índice';es_CO = 'Índice';tr = 'Endeks';it = 'Indice';de = 'Index'"));
		EndIf;
	EndIf;
	
	// 6) Both City and Locality fields can be blank only in the state is a federal city.
	If IsBlankString(City) AND IsBlankString(Locality) AND IsBlankString(District) Then
		If FederalCityNames().Find(Upper(State)) = Undefined Then
			AddAddressFillError(MandatoryFieldsNotFilled, "City",
				NStr("ru = 'Город может быть не указан только в регионе - городе федерального значения.'; en = 'A city is required for all states except for federal cities.'; pl = 'Miasto jest wymagane dla wszystkich województw z wyjątkiem miast federalnych.';es_ES = 'Se requiere una ciudad para todos los estados excepto para las ciudades federales.';es_CO = 'Se requiere una ciudad para todos los estados excepto para las ciudades federales.';tr = 'Federal şehirler dışındaki tüm eyaletler için bir şehir gerekmektedir.';it = 'La città è richiest per tutte le province/regioni, tranne per le città metropolitane.';de = 'Eine Stadt ist für alle Bundesländer mit Ausnahme von Bundesstädten erforderlich.'"),
				NStr("ru = 'Город'; en = 'City'; pl = 'Miejscowość';es_ES = 'Ciudad';es_CO = 'Ciudad';tr = 'Şehir';it = 'Città';de = 'Ort'"));
			AddAddressFillError(MandatoryFieldsNotFilled, "Settlmnt",
				NStr("ru = 'Населенный пункт может быть не указан только в регионе - городе федерального значения.'; en = 'A locality is required for all states except for federal cities.'; pl = 'Miejscowość jest wymagana dla wszystkich województw z wyjątkiem miast federalnych.';es_ES = 'Se requiere una localidad para todos los estados excepto para las ciudades federales.';es_CO = 'Se requiere una localidad para todos los estados excepto para las ciudades federales.';tr = 'Federal şehirler dışındaki tüm eyaletler için bir bölge gereklidir.';it = 'Una località è richiesta per tutte le province/regioni tranne che le città metropolitane.';de = 'Eine Lokalität ist für alle Bundesländer mit Ausnahme von Bundesstädten erforderlich.'"),
				NStr("ru = 'Населенный пункт'; en = 'Locality'; pl = 'Miejscowość';es_ES = 'Liquidación';es_CO = 'Liquidación';tr = 'Yerleşim yeri';it = 'Località';de = 'Siedlung'"));
		EndIf;
	EndIf;
	
	// 7) Houses cannot be empty
	If IsBlankString(AddressData.houseNumber) AND AddressData.buildings.Count() = 0 Then
		Field = "House";
		AddAddressFillError(FieldsLengthDoesNotMatch, Field,
			NStr("ru = 'Не указан номер дома.'; en = 'House number not specified.'; pl = 'Numer domu nie został podany.';es_ES = 'Número de edificio no especificado.';es_CO = 'Número de edificio no especificado.';tr = 'Ev numarası belirtilmemiştir.';it = 'Il numero di casa non è specificato.';de = 'Hausnummer nicht angegeben.'"),
			NStr("ru = 'Дом'; en = 'House'; pl = 'Nr domu';es_ES = 'Casa';es_CO = 'Casa';tr = 'Bina';it = 'Abitazione';de = 'Haus'"));
	EndIf;
	
	// All. Removing the empty results, modifying the group message
	For Index = 1-Result.Count() To 0 Do
		Folder = Result[-Index];
		Fields = Folder.Fields;
		EntityList = "";
		For FieldIndex = 1-Fields.Count() To 0 Do
			Field = Fields[-FieldIndex];
			If IsBlankString(Field.Message) Then
				Fields.Delete(-FieldIndex);
			Else
				EntityList = ", " + Field.FieldEntity + EntityList;
				Field.Delete("FieldEntity");
			EndIf;
		EndDo;
		If Fields.Count() = 0 Then
			Result.Delete(-Index);
		ElsIf Not IsBlankString(EntityList) Then
			Folder.Message = Folder.Message + Mid(EntityList, 2);
		EndIf;
	EndDo;
	
	Return Result;
EndFunction

Function AddressErrorGroup(ErrorType, Message)
	Return New Structure("ErrorType, Message, Fields", ErrorType, Message, New Array);
EndFunction

Procedure AddAddressFillError(Folder, FieldName = "", Message = "", FieldEntity = "")
	Folder.Fields.Add(New Structure("FieldName, Message, FieldEntity", FieldName, Message, FieldEntity));
EndProcedure

Procedure FillAddressErrorsByClassifier(LocalAddress, CheckFlags, Result)
	
	Addresses = New Array;
	Addresses.Add(New Structure("Address, AddressFormat", LocalAddress, "FIAS"));
	
	ModuleAddressClassifierInternal = Common.CommonModule("AddressClassifierInternal");
	AnalysisResults = ModuleAddressClassifierInternal.ResultOfAddressValidationByClassifier(Addresses);
	If AnalysisResults.Cancel Then
		Result.Add( New Structure("XPath, FieldEntity, AddressChecked", "/",, False), AnalysisResults.BriefErrorPresentation);
		Return;
	EndIf;
	
	// Only unique errors - we could check the address twice.
	ProcessedItems = New Map;
	For Each CheckResult In AnalysisResults.Data Do
			For Each AddressError In CheckResult.Errors Do
				varKey = AddressError.Key;
				If ProcessedItems[varKey] = Undefined Then
					Result.Add(New Structure("XPath, FieldEntity, AddressChecked", varKey,, CheckResult.AddressChecked), 
						TrimAll(AddressError.Text + Chars.LF + AddressError.ToolTip));
					ProcessedItems[varKey] = True;
				EndIf;
			EndDo;
	EndDo;
	
EndProcedure

// Returns the array of description of states - federal cities.
Function FederalCityNames()
	
	Result = New Array;
	Result.Add("MOSCOW G");
	Result.Add("ST.-PETERSBURG G");
	Result.Add("SEVASTOPOL G");
	Result.Add("BAIKONUR G");
	
	Return Result;
EndFunction

Function AddressClassifierSourceErrorStructure(InitialStructure = Undefined)
	
	If InitialStructure = Undefined Then
		InitialStructure = New Structure;
	EndIf;
		
	InitialStructure.Insert("Cancel", False);
	InitialStructure.Insert("DetailedErrorPresentation");
	InitialStructure.Insert("BriefErrorPresentation");

	Return InitialStructure;
EndFunction

Procedure FillExtendedTabularSectionAttributesForAddress(Val Address, Val TabularSectionRow) Export
	
	FillPropertyValues(TabularSectionRow, Address, "State, City"); 
	
EndProcedure

//======================================================================================================================
// Backward compatibility

// Returns contacts fields.
//
// Parameters:
//   XDTOContacts - XDTOObject, String - contacts or a XML string.
//   OldFieldsComposition - Boolean - optional flag specifying whether fields not available in SL 
//                                          versions earlier than 2.1.3 should be excluded from the field composition.
//
// Returns:
//   Structure - data. Contains fields:
//     * Presentation - String - address presentation.
//     * FieldsValues - ValueList - values. The value composition for the address:
//        ** Country           - String - a text presentation of a country.
//        ** CountryCode - String - an ARCC country code.
//        ** ZipCode           - String - a zip code (only for local addresses).
//        ** State - String - text presentation of a RF state (only for local addresses).
//        ** StateCode       - String - a code of a local state (only for local addresses).
//        ** StateShortForm - String - a short form of "state" (if OldFieldsComposition = False).
//        ** District - String - text presentation of a district (only for local addresses).
//        ** DistrictShortForm - String - a short form of "district" (if OldFieldsComposition = False).
//        ** City - String - text presentation of a city (only for local addresses).
//        ** CityShortForm - String - a short form of "city" (only for local addresses).
//        ** Locality  - String - a presentation of a locality (only for local addresses).
//        ** LocalityShortForm - a short form of "locality" (if OldFieldsComposition = False).
//        ** HouseType - String - see AddressManagerClientServer.TypeOfAddressingObjectOfRFAddress(). 
//        ** House - String - text presentation of a house (only for local addresses).
//        ** BlockType - String - see AddressManagerClientServer.TypeOfAddressingObjectOfRFAddress(). 
//        ** Block - String - text presentation of a block (only for local addresses).
//        ** ApartmentType - String - see AddressManagerClientServer. TypeOfAddressingObjectOfRFAddress().
//        ** Apartment - String - text presentation of an apartment (only for local addresses).
//       The value composition for the phone:
//        ** CountryCode        - String - a country code. For example, +7.
//        ** CityCode        - String - a city code. For example, 495.
//        ** PhoneNumber    - String - a phone number.
//        ** Additional       - String - an additional phone number.
//
Function ContactInformationToOldStructure(XDTOContactInformation, OldFieldsComposition = False) Export
	
	If ContactsManagerClientServer.IsXMLContactInformation(XDTOContactInformation) Then
		XDTOContact = ContactsManagerInternal.ContactsFromXML(XDTOContactInformation);
	Else
		XDTOContact = XDTOContactInformation
	EndIf;
	
	Result = New Structure("Presentation, FieldsValues", XDTOContact.Presentation, New ValueList);
	
	Namespace = ContactsManagerClientServer.Namespace();
	Composition = XDTOContact.Content;
	
	If Composition = Undefined Then
		Return Result;
	EndIf;
	
	Type = Composition.Type();
	If Type = XDTOFactory.Type(Namespace, "Address") Then
		Result.FieldsValues = AddressToOldFieldList(Composition, Not OldFieldsComposition);
		Result.FieldsValues.Add(Result.Presentation, "Presentation");
		
	ElsIf Type = XDTOFactory.Type(Namespace, "PhoneNumber") Then
		Result.FieldsValues = ContactsManagerInternal.PhoneNumberToOldFieldList(Composition);
		Result.FieldsValues.Add(XDTOContact.Comment, "Comment");
	EndIf;
	
	Return Result;
EndFunction

// Transforms XDTO format address to an old list of value of the ValueList type.
//
// Parameters:
//     XDTOAddress - XDTOObject, String - contacts or an XML string.
//     ExpandedFieldComposition -Boolean - an optional flag specifying whether fields should be 
//                                     excluded from the field composition to ensure compatibility with SL version 2.1.2.
//
//  Returns:
//     ValueList
//
Function AddressToOldFieldList(XDTOAddress, ExpandedFieldsComposition = True)
	List = New ValueList;
	
	Namespace = ContactsManagerClientServer.Namespace();
	XDTODataType = XDTOAddress.Type();
	If XDTODataType = XDTOFactory.Type(Namespace, "Address") Then
		
		// Country with code
		AddValue(List, "Country", XDTOAddress.Country);
		If IsBlankString(XDTOAddress.Country) Then
			CountryCode = "";
		Else
			Country = Catalogs.WorldCountries.FindByDescription(XDTOAddress.Country, True);
			CountryCode = TrimAll(Country.Code);
		EndIf;
		AddValue(List, "CountryCode", CountryCode);
		
		If Not AddressManagerClientServer.IsMainCountry(XDTOAddress.Country) Then
			Return List;
		EndIf;
		
		LocalAddress = XDTOAddress.Content;
		
	ElsIf XDTODataType = XDTOFactory.Type(AddressManager.Namespace(), "AddressUS") Then
		LocalAddress = XDTOAddress;
		
	Else
		Return List;
		
	EndIf;
	
	AddValue(List, "IndexOf", AddressZipCode(LocalAddress) );
	
	AddValue(List, "State", LocalAddress.USTerritorialEntitiy);
	AddValue(List, "StateCode", AddressManager.StateCode(LocalAddress.USTerritorialEntitiy) );
	If ExpandedFieldsComposition Then
		AddValue(List, "StateShortForm", ContactsManagerClientServer.ShortForm(LocalAddress.USTerritorialEntitiy));
	EndIf;
	
	District = AddressDistrict(LocalAddress);
	AddValue(List, "District", District);
	If ExpandedFieldsComposition Then
		AddValue(List, "DistrictShortForm", ContactsManagerClientServer.ShortForm(District));
	EndIf;
	
	AddValue(List, "City", LocalAddress.City);
	If ExpandedFieldsComposition Then
		AddValue(List, "CityShortForm", ContactsManagerClientServer.ShortForm(LocalAddress.City));
	EndIf;
	
	// transform FIAS into ARCA
	Locality                 = LocalAddress.Settlmnt;
	Street                           = LocalAddress.Street;
	AdditionalAddressItem     = FindAdditionalAddressItem(LocalAddress).Value;
	SubordinateItemOfAddressItem = AdditionalAddressItem(LocalAddress,
		AddressManagerClientServer.AdditionalAddressingObject(91));
	
	HasStreet                           = ValueIsFilled(Street);
	HasAdditionalAddressItem     = ValueIsFilled(AdditionalAddressItem);
	HasSubordinateItemOfAddressItem = ValueIsFilled(SubordinateItemOfAddressItem);
	
	If HasAdditionalAddressItem Then
		
		If HasSubordinateItemOfAddressItem Then
			Locality = AdditionalAddressItem;
			Street = SubordinateItemOfAddressItem;
		Else
			Street = AdditionalAddressItem;
		EndIf;
		
	ElsIf HasSubordinateItemOfAddressItem Then
		Street = SubordinateItemOfAddressItem;
	EndIf;
	
	AddValue(List, "Locality", Locality);
	If ExpandedFieldsComposition Then
		AddValue(List, "LocalityShortForm", ContactsManagerClientServer.ShortForm(Locality));
	EndIf;

	AddValue(List, "Street", Street);
	
	If ExpandedFieldsComposition Then
		AddValue(List, "StreetShortForm", ContactsManagerClientServer.ShortForm(Street));
	EndIf;
	
	// House and block
	BuildingsAndPremises = AddressBuildingsAndPremises(LocalAddress);
	
	ObjectParameters = BuildingOrPremiseValue(BuildingsAndPremises.Buildings, DataOptionsHouse(), ExpandedFieldsComposition);
	If ObjectParameters.Count() = 0 Then
		AddValue(List, "HOUSETYPE", "");
		AddValue(List, "House",     "");
	Else
		For Each ObjectString In ObjectParameters Do
			AddValue(List, "HOUSETYPE", ObjectString.Type,      ExpandedFieldsComposition);
			AddValue(List, "House",     ObjectString.Value, ExpandedFieldsComposition);
		EndDo;
	EndIf;
	
	ObjectParameters = BuildingOrPremiseValue(BuildingsAndPremises.Buildings, ConstructionDataOptions(), ExpandedFieldsComposition);
	If ObjectParameters.Count() = 0 Then
		AddValue(List, "BuildingUnitType", "");
		AddValue(List, "BuildingUnit",     "");
	ElsIf ObjectParameters.Count() = 1 Then
		ObjectString  = ObjectParameters[0];
		AddValue(List, "BuildingUnitType", ObjectString.Type,      ExpandedFieldsComposition);
		AddValue(List, "BuildingUnit",     ObjectString.Value, ExpandedFieldsComposition);
	Else
		BuildingUnitType  = ObjectParameters[0].Type;
		BlockValue = "";
		Separator = "";
		ShortForms = AddressManagerClientServer.ShortFormsOfRFAddressAddressingObjects();
		For Each ObjectString In ObjectParameters Do
			BuildingName = ?(ValueIsFilled(ShortForms[ObjectString.Type]), ShortForms[ObjectString.Type], ObjectString.Type);
			BlockValue  = BlockValue  + Separator + BuildingName + " " + ObjectString.Value;
			Separator = ", " ;
		EndDo;
		AddValue(List, "BuildingUnitType", BuildingUnitType,      ExpandedFieldsComposition);
		AddValue(List, "BuildingUnit",     BlockValue  , ExpandedFieldsComposition);
	EndIf;
	
	ObjectParameters = BuildingOrPremiseValue(BuildingsAndPremises.Premises, PremiseDataOptions(), ExpandedFieldsComposition);
	If ObjectParameters.Count() = 0 Then
		AddValue(List, "ApartmentType", "");
		AddValue(List, "Apartment",    "");
	ElsIf ObjectParameters.Count() = 1 Then
		ObjectString  = ObjectParameters[0];
		AddValue(List, "ApartmentType", ObjectString.Type,      ExpandedFieldsComposition);
		AddValue(List, "Apartment",    ObjectString.Value, ExpandedFieldsComposition);
	Else
		PremiseType  = ObjectParameters[0].Type;
		PremiseValue = "";
		Separator = "";
		ShortForms = AddressManagerClientServer.ShortFormsOfRFAddressAddressingObjects();
		For Each ObjectString In ObjectParameters Do
			PremiseName = ?(ValueIsFilled(ShortForms[ObjectString.Type]), ShortForms[ObjectString.Type], ObjectString.Type);
			PremiseValue = PremiseValue + Separator + PremiseName + " " + ObjectString.Value;
			Separator = ", " ;
		EndDo;
		AddValue(List, "ApartmentType", PremiseType,      ExpandedFieldsComposition);
		AddValue(List, "Apartment",    PremiseValue, ExpandedFieldsComposition);
	EndIf;
	
	Return List;
EndFunction

Procedure AddValue(List, FieldName, Value, AllowDuplicates = False)
	
	If Not AllowDuplicates Then
		For Each Item In List Do
			If Item.Presentation = FieldName Then
				Item.Value = String(Value);
				Return;
			EndIf;
		EndDo;
	EndIf;
	
	List.Add(String(Value), FieldName);
EndProcedure

// Returns house type options.
Function DataOptionsHouse() Export
	
	Return New Structure("TypeOptions, CanPickValues", 
		AddressManagerClientServer.AddressingObjectsDescriptionsByType(1), False);
		
EndFunction

// Returns house type options (by a construction type).
Function ConstructionDataOptions() Export
	
	Return New Structure("TypeOptions, CanPickValues", 
		AddressManagerClientServer.AddressingObjectsDescriptionsByType(2), False);
		
EndFunction

// Returns available premise types.
Function PremiseDataOptions() Export
	
	Return New Structure("TypeOptions, CanPickValues", 
		AddressManagerClientServer.AddressingObjectsDescriptionsByType(3, False), False);
		
EndFunction

#EndRegion

#Region EventSubscriptionHandler

Procedure FormGetProcessing(FormType, Parameters, SelectedForm, AdditionalInfo, StandardProcessing)
	
	If Parameters <> Undefined AND Parameters.Property("OpenByScenario") Then
		StandardProcessing = False;
		InformationKind = Parameters.ContactInformationKind;
		SelectedForm = DriveServerCall.AdvancedContactInformationInputContactInformationInputFormName(InformationKind);
	
		If SelectedForm = Undefined Then
			Raise NStr("en = 'Not processed type addresses:'; ru = 'Необработанные адреса:';pl = 'Nie przetworzono adresów o typie:';es_ES = 'Tipo de direcciones no procesado:';es_CO = 'Tipo de direcciones no procesado:';tr = 'İşlenmemiş tür adresleri:';it = 'Tipi di indirizzi non processati:';de = 'Nicht verarbeitete Adresstypen:'") + " "+ InformationKind + """'";
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf