#Region Public

// Returns a description of a local territorial entity for an address or a blank string if the territorial entity is not defined.
// If the passed string does not contain information on the address, an exception is thrown.
//
// Parameters:
//    Address - String, Structure - a string in the JSON or XML format matching the Address XDTO data package.
//
// Returns:
//    String - a state description.
//
Function ContactInformationAddressState(Val Address) Export
	
	If TypeOf(Address) = Type("String") Then
		
		If IsBlankString(Address) Then
			Return "";
		EndIf;
	
		If ContactsManagerClientServer.IsXMLContactInformation(Address) Then
			Address = ContactsManager.ContactInformationInJSON(Address, Enums.ContactInformationTypes.Address);
		EndIf;
		
		Address = ContactsManagerInternal.JSONStringToStructure(Address);
		
	ElsIf TypeOf(Address) <> Type("Structure") Then
		
		Raise NStr("ru = 'Невозможно определить субъекта РФ, ожидается адрес.'; en = 'Cannot determine territorial entity of the RF. Address expected.'; pl = 'Nie można określić jednostki terytorialnej RF. Oczekiwany adres.';es_ES = 'No puede determinar la entidad territorial de la RF. Dirección estimada.';es_CO = 'No puede determinar la entidad territorial de la RF. Dirección estimada.';tr = 'RF''nin bölgesel varlığı belirlenemiyor. Adres bekleniyor.';it = 'Impossibile determinare l''entità territoriale della Federazione Russa. Indirizzo atteso.';de = 'Die territoriale Einheit der RF kann nicht bestimmt werden. Adresse erwartet.'");
		
	EndIf;
	
	USTerritorialEntitiy = TrimAll(Address.Area + " " + Address.AreaType);
	
	Return USTerritorialEntitiy;
	
EndFunction

// Returns a city description for a local address and a blank string for a foreign address.
// If the passed string does not contain information on the address, an exception is thrown.
//
// Parameters:
//    Address - String, Structure - a string in the JSON format or an XML string matching the Address XDTO data package.
//
// Returns:
//    String - a city description.
//
Function ContactInformationAddressCity(Val Address) Export
	
	If TypeOf(Address) = Type("String") Then
		
		If IsBlankString(Address) Then
			Return "";
		EndIf;
	
		If ContactsManagerClientServer.IsXMLContactInformation(Address) Then
			Address = ContactsManager.ContactInformationInJSON(Address, Enums.ContactInformationTypes.Address);
		EndIf;
		
		Address = ContactsManagerInternal.JSONStringToStructure(Address);
		
	ElsIf TypeOf(Address) <> Type("Structure") Then
		
		Raise NStr("ru = 'Невозможно определить город, ожидается адрес.'; en = 'Cannot determine city. Address expected.'; pl = 'Nie można ustalić miasta, oczekiwanie adresu.';es_ES = 'No se puede determinar la ciudad; dirección pendiente.';es_CO = 'No se puede determinar la ciudad; dirección pendiente.';tr = 'Ülke belirlenemiyor; adres bekleniyor.';it = 'Impossibile determinare la città. Indirizzo atteso.';de = 'Die Stadt kann nicht bestimmt werden. Adresse erwartet.'");
		
	EndIf;
	
	City = TrimAll(Address.City + " " + Address.CityType);
	
	Return City;
	
EndFunction

// Returns address info as a structure of address parts and ARCA codes.
//
// Parameters:
//   Address                 - String - an address in the internal JSON or XML format matching the Address XDTO data package.
//                          - XDTODataObject - an XDTO data object matching the Address XDTO data package.
//   AdditionalParameters - Structure - to clarify the return value:
//       * WithoutPresentations - Boolean - if True, the Presentation field will not be displayed. The default value is False.
//       * AddressCodes       - Boolean - if True, the result contains the AddressObjectID and 
//                                     HouseID fields and the structure with address codes (IDs, RNCMT, RNCPS, and so on).
//                                     For more information, see the return value of the IDs and AdditionalCodes structures. The default value is False.
//                                     If there are no IDs in an address and no address objects IDs 
//                                     are imported to the application, you can get IDs using an HTTP request to the 1C orgaddress web service.
//       * ARCACodes - Boolean - if True, the structure of ARCACodes returns. The default value is False.
//                                     If there are no codes in an address and no address objects are imported to the application, 
//                                     you can get codes using an HTTP request to the 1C orgaddress web service.
//       * FullDescriptionsOfShortForms - Boolean - if True, returns full descriptions of address objects.
//       * DescriptionIncludesShortForm - Boolean - if True, the descriptions of address objects contain their short forms.
//       * CheckAddress   - Boolean - if True, the address is checked for compliance with FIAS. The default value is False.
//                                     If address objects being checked are not imported to the 
//                                     application, you can check an address using an HTTP request to the 1C orgaddress web service.
//
// Returns:
//   Array - contains structures array, see structure content in the AddressInfo function details.
//
Function AddressesInfo(Addresses, AdditionalParameters = Undefined) Export
	Return AddressesInfoAsStructure(Addresses, AdditionalParameters);
EndFunction

// Returns address info as separated address parts and various codes (state code, RNCMT, and so on).
//
// Parameters:
//   Address                  - String - an address in the internal JSON or XML format matching the Address XDTO data package.
//                          - XDTODataObject - an XDTO data object matching the Address XDTO data package.
//   AdditionalParameters - Structure - to clarify the return value:
//       * WithoutPresentations - Boolean - if True, the Presentation field will not be displayed. The default value is False.
//       * AddressCodes       - Boolean - if True, the result contains the AddressObjectID and 
//                                     HouseID fields and structure with address codes (IDs, AdditionalCodes, and ARCACodes).
//                                     For more information, see the return value of the IDs and AdditionalCodes structures. The default value is False.
//                                     If there are no IDs in an address and no address objects IDs 
//                                     are imported to the application, you can get IDs using an HTTP request to the 1C orgaddress web service.
//       * ARCACodes - Boolean - if True, the structure of ARCACodes returns. The default value is False.
//                                     If there are no codes in an address and no address objects are imported to the application, 
//                                     you can get codes using an HTTP request to the 1C orgaddress web service.
//       * FullDescriptionsOfShortForms - Boolean - if True, returns full descriptions of address objects.
//       * DescriptionIncludesShortForm - Boolean - if True, the descriptions of address objects contain their short forms.
//       * CheckAddress   - Boolean - if True, the address is checked for compliance with FIAS. The default value is False.
//                                     If address objects being checked are not imported to the 
//                                     application, you can check an address using an HTTP request to the 1C orgaddress web service.
//
// Returns:
//   Structure - info on the address:
//        * Presentation    - String - a text presentation of an address with administrative and territorial structure.
//        * MunicipalPresentation - String - a text presentation of an address with municipal structure.
//        * AddressType        - String - the main address type (only for local addresses).
//                                      Available options: "Municipal" and "Administrative and territorial".
//        * Country           - String - a text presentation of a country.
//        * CountryCode - String - an ARCC country code (can be blank if the country field is blank).
//        * ZipCode           - String - a zip code.
//        * StateCode       - String - a code of a local state.
//        * State           - String - a text presentation of a local state.
//        * StateShortForm - String - a short form of a state.
//        * County            - String - a text presentation of county (obsolete).
//        * CountyShortForm - String - a short form of "county" (obsolete).
//        * District            - String - a text presentation of a district (for addresses with administrative and territorial structure).
//        * DistrictShortForm - String - a short form of "district" (for addresses with administrative and territorial structure).
//        * MunicipalDistrict - String - a text presentation of a municipal district (for addresses with municipal structure).
//        * MunicipalDistrictShortForm - String - a short form of "municipal district" (for addresses with municipal structure).
//        * City            - String - a text presentation of a city (for addresses with administrative and territorial structure).
//        * CityShortForm - String - a short form of "city" (for addresses with administrative and territorial structure).
//        * Settlement            - String - a text presentation of a settlement (for addresses with municipal division).
//        * SettlementShortForm  - String - a short form of "settlement" (for addresses with municipal division).
//        * CityDistrict - String - a text presentation of a city district.
//        * CityDistrictShortForm - String - a short form of "city district."
//        * Locality - String - a text presentation of a locality.
//        * LocalityShortForm - String - a short form of "locality."
//        * Territory - String - a text presentation of a territory.
//        * TerritoryShortForm - String - a short form of "territory."
//        * Street            - String - a text presentation of a street.
//        * StreetShortForm - String - a short form of "street."
//        * AdditionalTerritory - String - a text presentation of an additional territory (obsolete).
//        * AdditionalTerritoryShortForm - String - a short form of "additional territory" (obsolete).
//        * AdditionalTerritoryItem - String - a text presentation of an additional territory item (obsolete).
//        * AdditionalTerritoryItem - String - a short form of "additional territory item" (obsolete).
//        * Building - Structure - a structure with building address information.
//            ** BuildingType - String - an addressing object type of an RF address in accordance to the order of Ministry of Finance of Russia dated 11/05/2015. N
//                                     171N
//            ** Number - String - a text presentation of a house number (only for local addresses).
//        * BuildingUnit - Array - contains structures (structure fields: BuildingUnitType and Number) that list address building units.
//        * Premises - Array - contains structures (structure fields: PremiseType and Number) that list address premises.
//        * Comment - String - a comment about an address.
//        * AddressObjectID - UUID - an identification code of the last address object in the 
//                                        address hierarchy. For example, for the address 9 
//                                        Dmitrovskoye sh., Moscow, the street ID serves as an address object ID.
//                                        The field is not displayed if the additional parameter AddressCodes is False.
//        * HouseID            - UUID - an identification code of the house (construction) of the address object.
//                                        The field is not displayed if the additional parameter AddressCodes is False.
//        * IDs - Structure - address objects IDs if the AddressCodes or ARCACodes parameter is set.
//                                       The field is not displayed if the additional parameter AddressCodes or ARCACodes is False.
//            ** State               - UUID - a state ID.
//            ** District                - UUID - a district ID.
//            ** MunicipalDistrict   - UUID - a municipal district ID.
//            ** City                - UUID - a city ID.
//            ** Settlement            - UUID - a settlement ID.
//            ** CityDistrict - UUID - a city district ID.
//            ** Territory           - UUID - a territory ID.
//            ** Street                - UUID - a street ID.
//        * ARCACodes           - Structure - ARCA codes if the ARCACodes parameter is set to True.
//           ** State          - String - an ARCA code of a state.
//           ** District           - String - an ARCA code of a district.
//           ** City           - String - an ARCA code of a city.
//           ** Locality - String - an ARCA code of a locality.
//           ** Street           - String - an ARCA code of a street.
//        * Additional codes - Structure - the following codes: RNCMT, RNCPS, IFTSICode, IFTSLECode, IFTSIAreaCode, and IFTSLEAreaCode.
//                                            The field is not displayed if the additional parameter AddressCodes is False.
//        * AddressCheckResult - String - "Success" if the address is correct, "Error" if there are some check errors,
//                                             "Cancel" if cannot validate the address as the classifier is unavailable.
//                                             Blank string if the CheckAddress check box is not 
//                                             selected in the AdditionalParameters.CheckAddress parameter.
//        * AddressCheckErrors - String - details of address errors detected upon the check.
//
Function AddressInfo(Address, AdditionalParameters = Undefined) Export
	Return AddressInfoAsStructure(Address, AdditionalParameters);
EndFunction

// Checks an address for compliance with address information requirements.
//
// Parameters:
//   Address              - String - a contact information string in the JSON or XML format matching the Address XDTO data package.
//   CheckParameters - Structure - CatalogRef.ContactInformationKinds - check boxes of address check:
//          OnlyNationalAddress - Boolean - an address is to be only local. Default value is True.
//          AddressFormat - String - Obsolete. The classifier used for validation: "ARCA" or "FIAS". Default value is "ARCA".
// Returns:
//   Structure - contains a structure with the following fields:
//        * Result - String - a check result: "Correct", "NotChecked", or "ContainsErrors".
//        * ErrorsList - ValueList - information on errors.
Function CheckAddress(Val Address, CheckParameters = Undefined) Export
	Return ContactsManagerInternal.CheckAddress(Address, CheckParameters);
EndFunction

// Transforms a structure that describes an address to the internal contact information storage format JSON.
//
// Parameters:
//  AddressFields - Structure - an address broken down by fields. To view the list of fields, see  AddressManagerClientServer.AddressFields.
// 
// Returns:
//  String - an address in the internal JSON format.
//
Function AddressFieldsInJSON(AddressFields) Export
	
	Result = AddressManagerClientServer.NewContactInformationDetails(
		Enums.ContactInformationTypes.Address);
	
	UUIDType = Type("UUID");
	
	Result.AddressType = AddressFields.AddressType;
	If AddressFields.AddressType <> AddressManagerClientServer.MunicipalAddress()
		AND AddressFields.AddressType <> AddressManagerClientServer.AdministrativeAndTerritorialAddress() Then
		ExceptionText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Некорректный тип адреса (%1)'; en = 'Incorrect address type (%1)'; pl = 'Nieprawidłowy typ adresu (%1)';es_ES = 'Tipo de dirección incorrecto (%1)';es_CO = 'Tipo de dirección incorrecto (%1)';tr = 'Yanlış adres türü (%1)';it = 'Tipo di indirizzo non corretto (%1)';de = 'Falscher Adresstyp (%1)'"),
			AddressFields.AddressType);
		Raise ExceptionText;
	EndIf;
	
	If AddressFields.AddressType <> AddressManagerClientServer.AdministrativeAndTerritorialAddress() Then
		Result.Value = AddressFields.Presentation;
	Else
		Result.Value = AddressFields.MunicipalPresentation;
	EndIf;
	
	Result.Comment     = AddressFields.Comment;
	
	Result.Country     = AddressFields.Country;
	Result.CountryCode = AddressFields.CountryCode;
	
	Result.ZIPcode     = AddressFields.IndexOf;
	
	Result.AreaCode    = AddressFields.StateCode;
	
	Result.Area     = AddressFields.State;
	Result.AreaType = AddressFields.StateShortForm;
	
	Result.City     = AddressFields.City;
	Result.CityType = AddressFields.CityShortForm;
	
	Result.Street     = AddressFields.Street;
	Result.StreetType = AddressFields.StreetShortForm;
	
	Result.District     = AddressFields.District;
	Result.DistrictType = AddressFields.DistrictShortForm;
	
	Result.MunDistrict     = AddressFields.MunicipalDistrict;
	Result.MunDistrictType = AddressFields.MunicipalDistrictShortForm;
	
	Result.Settlement     = AddressFields.Settlement;
	Result.SettlementType = AddressFields.SettlementShortForm;
	
	Result.CityDistrict     = AddressFields.CityDistrict;
	Result.CityDistrictType = AddressFields.CityDistrictShortForm;
	
	Result.Locality     = AddressFields.Locality;
	Result.LocalityType = AddressFields.LocalityShortForm;
	
	Result.Territory     = AddressFields.Territory;
	Result.TerritoryType = AddressFields.TerritoryShortForm;
	
	Result.HouseType   = AddressFields.Building.BuildingType;
	Result.HouseNumber = AddressFields.Building.Number;
	
	If AddressFields.Property("IDs") Then
		If TypeOf(AddressFields.IDs.StateID) = UUIDType
			AND ValueIsFilled(AddressFields.IDs.StateID) Then
			Result.AreaID = String(AddressFields.IDs.StateID);
			Result.ID = Result.AreaID;
		EndIf;
		
		If TypeOf(AddressFields.IDs.DistrictID) = UUIDType
			AND ValueIsFilled(AddressFields.IDs.DistrictID) Then
			Result.DistrictID = String(AddressFields.IDs.DistrictID);
			Result.ID         = Result.DistrictID;
		EndIf;
		
		If TypeOf(AddressFields.IDs.CityID) = UUIDType
			AND ValueIsFilled(AddressFields.IDs.CityID) Then
			Result.CityID = String(AddressFields.IDs.CityID);
			Result.ID     = Result.CityID;
		EndIf;
		
		If TypeOf(AddressFields.IDs.MunicipalDistrictID) = UUIDType
			AND ValueIsFilled(AddressFields.IDs.MunicipalDistrictID) Then
			Result.MunDistrictID = String(AddressFields.IDs.MunicipalDistrictID);
			Result.ID            = Result.MunDistrictID;
		EndIf;
		
		If TypeOf(AddressFields.IDs.SettlementID) = UUIDType
			AND ValueIsFilled(AddressFields.IDs.SettlementID) Then
			Result.SettlementID = String(AddressFields.IDs.SettlementID);
			Result.ID           = Result.SettlementID;
		EndIf;
		
		If TypeOf(AddressFields.IDs.CityDistrictID) = UUIDType
			AND ValueIsFilled(AddressFields.IDs.CityDistrictID) Then
			Result.CityDistrictID = String(AddressFields.IDs.CityDistrictID);
			Result.ID             = Result.CityDistrictID;
		EndIf;
		
		If TypeOf(AddressFields.IDs.LocalityID) = UUIDType
			AND ValueIsFilled(AddressFields.IDs.LocalityID) Then
			Result.LocalityID = String(AddressFields.IDs.LocalityID);
			Result.ID         = Result.LocalityID;
		EndIf;
		
		If TypeOf(AddressFields.IDs.TerritoryID) = UUIDType
			AND ValueIsFilled(AddressFields.IDs.TerritoryID) Then
			Result.TerritoryID = String(AddressFields.IDs.TerritoryID);
			Result.ID          = Result.TerritoryID;
		EndIf;
		
		If TypeOf(AddressFields.IDs.StreetID) = UUIDType
			AND ValueIsFilled(AddressFields.IDs.StreetID) Then
			Result.StreetID = String(AddressFields.IDs.StreetID);
			Result.ID       = Result.StreetID;
		EndIf;
	EndIf;
	
	If AddressFields.Property("HouseID")
		AND TypeOf(AddressFields.HouseID) = UUIDType
		AND ValueIsFilled(AddressFields.HouseID) Then
		Result.HouseID = String(AddressFields.HouseID);
	EndIf;
	
	If AddressFields.Property("AddressObjectID")
		AND TypeOf(AddressFields.AddressObjectID) = UUIDType
		AND ValueIsFilled(AddressFields.AddressObjectID) Then
		Result.ID = String(AddressFields.AddressObjectID);
	EndIf;
	
	For Each BuildingUnit In AddressFields.BuildingUnits Do
		Result.Buildings.Add(ContactsManagerClientServer.ConstructionOrPremiseValue(BuildingUnit.BuildingUnitType, BuildingUnit.Number));
	EndDo;
	
	For Each CurrentPremise In AddressFields.Premises Do
		Result.Apartments.Add(ContactsManagerClientServer.ConstructionOrPremiseValue(CurrentPremise.PremiseType, CurrentPremise.Number));
	EndDo;
	
	// Filling an ARCA code of the last address object in the hierarchy.
	If AddressFields.Property("ARCACodes") Then
		If Not IsBlankString(AddressFields.ARCACodes.Street) Then
			Result.CodeKLADR = AddressFields.ARCACodes.Street;
		ElsIf Not IsBlankString(AddressFields.ARCACodes.Locality) Then
			Result.CodeKLADR = AddressFields.ARCACodes.Locality;
		ElsIf Not IsBlankString(AddressFields.ARCACodes.City) Then
			Result.CodeKLADR = AddressFields.ARCACodes.City;
		ElsIf Not IsBlankString(AddressFields.ARCACodes.District) Then
			Result.CodeKLADR = AddressFields.ARCACodes.District;
		ElsIf Not IsBlankString(AddressFields.ARCACodes.State) Then
			Result.CodeKLADR = AddressFields.ARCACodes.State;
		EndIf;
	EndIf;
	
	If AddressFields.Property("AdditionalCodes") Then
		Result.OKTMO          = AddressFields.AdditionalCodes.RNCMT;
		Result.OKATO          = AddressFields.AdditionalCodes.RNCPS;
		Result.IFNSFLCode     = AddressFields.AdditionalCodes.IndividualFTSCode;
		Result.IFNSULCode     = AddressFields.AdditionalCodes.BusinessIFTSCode;
		Result.IFNSFLAreaCode = AddressFields.AdditionalCodes.IndividualFTSAreaCode;
		Result.IFNSULAreaCode = AddressFields.AdditionalCodes.BusinessIFTSAreaCode;
	EndIf;
	
	If Not ValueIsFilled(Result.Value) Then
		AddressManagerClientServer.UpdateAddressPresentation(Result, False);
	EndIf;
	
	Return ContactsManagerInternal.ToJSONStringStructure(Result);
	
EndFunction

// Returns an address as an XML string in accordance with the XDTO data structure Contact information and Address.
//
// Parameters:
//  AddressID - String - a global unique identification code of an address object.
//  AdditionalAddressInformation - Structure - address fields that will be added to the address:
//   * AddressInJSON               - Boolean - returns an address in the JSON format.
//   * AdditionalInformation - String - a comment to the address.
//   * Country                   - String - a country description in the address.
//   * HouseNumber                - String - a house number.
//   * OfficeNumber               - String - an office number.
//   * ConstructionNumber            - String - a construction number.
//   * ZipCode           - String - an address zip code.
//   * PostOfficeBox          - String - a post office box in the address.
//   * Municipal            - Boolean - if True, the address is generated in the municipal format.
//                                         The default value is False.
//
// Returns:
//  String, Undefined - an XML in accordance with the structure of the Address and Contact information XDTO data packages.
//                         JSON if the AddressInJSON parameter in AdditionalAddressInformation is set to True.
//                         Undefined if cannot generate an address by ID.
//
Function AddressByID(AdsressID, AdditionalAddressInformation = Undefined) Export
	
	If AdditionalAddressInformation = Undefined Then
		AdditionalAddressInformation = New Structure();
	EndIf;
	
	Municipal = ?(AdditionalAddressInformation.Property("Municipal"), Boolean(AdditionalAddressInformation.Municipal), False);
	
	Info = New Structure();
	Info.Insert("ID", AdsressID);
	Info.Insert("Municipal", Municipal);
	
	ModuleAddressClassifierInternal = Common.CommonModule("AddressClassifierInternal");
	ReceivedAddress = ModuleAddressClassifierInternal.RelevantAddressInfo(Info);
	
	If ReceivedAddress.Cancel Then
		Return Undefined;
	EndIf;
	
	Address = ReceivedAddress.Data;
	
	If AdditionalAddressInformation.Property("HouseNumber") AND ValueIsFilled(AdditionalAddressInformation.HouseNumber) Then
		
		HouseDetails = SeparateHousesAndConstructions(AdditionalAddressInformation.HouseNumber, NStr("ru='Дом'; en = 'House'; pl = 'Nr domu';es_ES = 'Casa';es_CO = 'Casa';tr = 'Bina';it = 'Abitazione';de = 'Haus'"));
		Address.Insert("houseType",   HouseDetails.Type);
		Address.Insert("houseNumber", HouseDetails.Number);
		Address.Insert("houseId",     "");
		
	EndIf;
	
	If AdditionalAddressInformation.Property("ConstructionNumber") AND ValueIsFilled(AdditionalAddressInformation.ConstructionNumber) Then
		
		ConstructionDetails = SeparateHousesAndConstructions(AdditionalAddressInformation.ConstructionNumber, NStr("ru='Корпус'; en = 'BuildingUnit'; pl = 'BuildingUnit';es_ES = 'BuildingUnit';es_CO = 'BuildingUnit';tr = 'BuildingUnit';it = 'Blocco';de = 'BuildingUnit'"));
		Building = ContactsManagerClientServer.ConstructionOrPremiseValue(ConstructionDetails.Type,  ConstructionDetails.Number);
		Address.buildings.Add(Building);
		
	EndIf;
	
	If AdditionalAddressInformation.Property("OfficeNumber") AND ValueIsFilled(AdditionalAddressInformation.OfficeNumber) Then
		
		PremiseDetails = SeparateHousesAndConstructions(AdditionalAddressInformation.OfficeNumber, NStr("ru='Офис'; en = 'Office'; pl = 'Biuro';es_ES = 'Oficina';es_CO = 'Oficina';tr = 'Ofis';it = 'Ufficio';de = 'Büro'"));
		Premise = ContactsManagerClientServer.ConstructionOrPremiseValue(PremiseDetails.Type,  PremiseDetails.Number);
		Address.apartments.Add(Premise);
		
	EndIf;
	
	If AdditionalAddressInformation.Property("PostOfficeBox") AND ValueIsFilled(AdditionalAddressInformation.PostOfficeBox) Then
		
		PostOfficeBoxDetails = SeparateHousesAndConstructions(AdditionalAddressInformation.PostOfficeBox, NStr("ru='А/Я'; en = 'P.O. box'; pl = 'Skrytka pocztowa';es_ES = 'P.O. caja';es_CO = 'P.O. caja';tr = 'Posta kutusu';it = 'Casella postale';de = 'Postfach'"));
		PostOfficeBox = ContactsManagerClientServer.ConstructionOrPremiseValue(PostOfficeBoxDetails.Type,  PostOfficeBoxDetails.Number);
		Address.apartments.Add(PostOfficeBox);
	EndIf;

	If AdditionalAddressInformation.Property("ZipCode") AND ValueIsFilled(AdditionalAddressInformation.ZipCode) Then
		Address.ZIPcode = AdditionalAddressInformation.ZipCode;
	EndIf;
	
	If AdditionalAddressInformation.Property("AdditionalInformation") AND ValueIsFilled(AdditionalAddressInformation.AdditionalInformation) Then
		Address.comment = AdditionalAddressInformation.AdditionalInformation;
	EndIf;
	
	If AdditionalAddressInformation.Property("Country")  AND ValueIsFilled(AdditionalAddressInformation.Country) Then
		Address.country = Upper(AdditionalAddressInformation.Country);
	EndIf;
	
	InformationKind = New Structure("Type", Enums.ContactInformationTypes.Address);
	EstimatedPresentation = ContactsManagerInternal.ContactInformationPresentation(Address, InformationKind);
	Address.value = EstimatedPresentation;
	
	If AdditionalAddressInformation.Property("AddressInJSON") AND AdditionalAddressInformation.AddressInJSON = True Then
		
		Return ContactsManagerInternal.ToJSONStringStructure(Address);
		
	EndIf;
	
	Return ContactsManagerInternal.ContactsFromJSONToXML(Address, Enums.ContactInformationTypes.Address);
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Backward compatibility.

#Region ObsoleteProceduresAndFunctions

// Obsolete. Use AddressManager.AddressInfo.
// Converts XML data to the previous contact information format.
//
// Parameters:
//    Data                 - String - an XML string matching the Address XDTO data package.
//    ShortFieldsComposition - Boolean - if False, fields missing in SSL versions earlier than 2.1.3 
//                                      are excluded from the fields composition.
//
// Returns:
//    String - a set of key-value pairs separated by line breaks.
//
Function PreviousContactInformationXMLFormat(Val Data, Val ShortFieldsComposition = False) Export
	
	If ContactsManagerClientServer.IsXMLContactInformation(Data) Then
		OldFormat = DataProcessors.AdvancedContactInformationInput.ContactInformationToOldStructure(Data, ShortFieldsComposition);
		Return AddressManagerClientServer.ConvertFieldsListToString(OldFormat.FieldsValues, False);
	EndIf;
	
	Return Data;
EndFunction

// Obsolete. Use AddressManager.AddressInfo.
// Converts data of a new contact information XML format to the structure of the old format.
//
// Parameters:
//   Data                  - String - an XML string matching the Address XDTO data package.
//   ContactInformationKind - CatalogRef.ContactInformationKinds, Structure - Contact information parameters.
//     * Type - EnumRef.ContactInformationTypes - a contact information type.
//
// Returns:
//   Structure - a set of key-value pairs. The set of properties for the address:
//        ** Country           - String - presentation of a country.
//        ** CountryCode - String - an ARCC country code.
//        ** ZipCode           - String - a zip code (only for local addresses).
//        ** State           - String - a presentation of a local state (only for local addresses).
//        ** StateCode       - String - a code of a local state (only for local addresses).
//        ** StateShortForm - String - a short form of "state" (if OldFieldsComposition = False).
//        ** District            - String - a presentation of a district (only for local addresses).
//        ** DistrictShortForm - String - a short form of "district" (if OldFieldsComposition = False).
//        ** City            - String - a presentation of a city (only for local addresses).
//        ** CityShortForm - String - a short form of "city" (only for local addresses).
//        ** Locality - String - a presentation of a locality (only for local addresses).
//        ** LocalityShortForm - String - a short form of "locality" (if OldFieldsComposition = False).
//        ** Street            - String - presentation of a street (only for local addresses).
//        ** StreetShortForm - String - a short form of "street" (if OldFieldsComposition = False).
//        ** HouseType          - String - a house type, see AddressManagerClientServer. LocalAddressesAddressingObjectsTypes.
//        ** House              - String - a house presentation (only for local addresses).
//        ** BuildingUnitType       - String - a building unit type, see AddressManagerClientServer. LocalAddressesAddressingObjectsTypes.
//        ** BuildingUnit           - String - a building unit presentation (only for local addresses).
//        ** ApartmentType      - String - an apartment type, see AddressManagerClientServer. LocalAddressesAddressingObjectsTypes.
//        ** Apartment         - String - an apartment presentation (only for local addresses).
//       The set of properties for a phone:
//        ** CountryCode        - String - a country code. For example, +7.
//        ** CityCode        - String - a city code. For example, 495.
//        ** PhoneNumber    - String - a phone number.
//        ** Additional       - String - an additional phone number.
//
Function PreviousContactInformationXMLStructure(Val Data, Val ContactInformationKind = Undefined) Export
	
	If ContactsManagerClientServer.IsXMLContactInformation(Data) Then
		// New contact information format
		Return ContactsManagerClientServer.FieldsValuesStructure(
			PreviousContactInformationXMLFormat(Data));
		
	EndIf;
	
	If ContactInformationKind <> Undefined
		AND ((TypeOf(ContactInformationKind) = Type("Structure") AND ContactInformationKind.Property("Type"))
		OR TypeOf(ContactInformationKind) = Type("CatalogRef.ContactInformationKinds")) Then
			ContactInformationType = ContactInformationKind.Type;
	Else
		ContactInformationType = Undefined;
	EndIf;
	
	If IsBlankString(Data)  Then
		// Generating by kind
		Return AddressManagerClientServer.ContactInformationStructureByType(ContactInformationType);
		
	EndIf;
	
	// Returning full structure for the selected kind with filled in fields.
	Result = AddressManagerClientServer.ContactInformationStructureByType(ContactInformationType);
	FieldsValuesStructure = ContactsManagerClientServer.FieldsValuesStructure(Data, ContactInformationKind);
	If ContactInformationType <> Undefined Then
		FillPropertyValues(Result, FieldsValuesStructure);
		Return Result;
	EndIf;
	
	Return FieldsValuesStructure;
	
EndFunction

// Obsolete. Use AddressManager.AddressInfo.
// Converts addresses of a new FIAS XML format to addresses of the ARCA format.
//
// Parameters:
//   Data                  - String - an XML string matching the Address XDTO data package.
//
// Returns:
//   Structure - a set of key-value pairs. The set of properties for the address:
//        ** Country           - String - presentation of a country.
//        ** CountryCode - String - an ARCC country code.
//        ** ZipCode           - String - a zip code (only for local addresses).
//        ** State           - String - a presentation of a local state (only for local addresses).
//        ** StateCode       - String - a code of a local state (only for local addresses).
//        ** StateShortForm - String - a short form of a state.
//        ** District            - String - a presentation of a district (only for local addresses).
//        ** DistrictShortForm - String - a short form of "district."
//        ** City            - String - a presentation of a city (only for local addresses).
//        ** CityShortForm - String - a short form of "city" (only for local addresses).
//        ** Locality - String - a presentation of a locality (only for local addresses).
//        ** LocalityShortForm - String - a short form of "locality."
//        ** Street            - String - presentation of a street (only for local addresses).
//        ** StreetShortForm - String - a short form of "street."
//        ** HouseType          - String - a house type, see AddressManagerClientServer. LocalAddressesAddressingObjectsTypes.
//        ** House              - String - a house presentation (only for local addresses).
//        ** BuildingUnitType       - String - a building unit type, see AddressManagerClientServer. LocalAddressesAddressingObjectsTypes.
//        ** BuildingUnit           - String - a building unit presentation (only for local addresses).
//        ** ApartmentType      - String - an apartment type, see AddressManagerClientServer. LocalAddressesAddressingObjectsTypes.
//        ** Apartment         - String - an apartment presentation (only for local addresses).
//        ** LocalAddress          - Boolean - if True, it is a local address.
//        ** Presentation    - String - an address presentation.
//
Function AddressInARCAFormat(Val Data) Export
	
	If ContactsManagerClientServer.IsXMLContactInformation(Data) Then
		// New contact information format
		Result = ContactsManagerClientServer.FieldsValuesStructure(
				PreviousContactInformationXMLFormat(Data));
			Presentation = ContactsManager.ContactInformationPresentation(Data);
			
	ElsIf IsBlankString(Data) Then
		// Generating a blank structure by kind
		Result = AddressManagerClientServer.ContactInformationStructureByType(
			Enums.ContactInformationTypes.Address);
		Presentation = "";
	EndIf;
	
	If Result.Property("Country") AND StrCompare(Result.Country, AddressManagerClientServer.MainCountry().Description) = 0 Then
		Result.Insert("AddressUS", True);
	Else
		Result.Insert("AddressUS", False);
	EndIf;
	Result.Insert("Presentation", Presentation);
	
	Return Result;
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
	Return "http://www.v8.1c.ru/ssl/contactinfo_ru";
EndFunction

// Converts an XML. Backward compatibility.
//
Function BeforeReadXDTOContactInformation(XMLText) Export
	
	If StrFind(XMLText, "Address") = 0 Then
		Return XMLText;
	EndIf;
	
	If StrFind(XMLText, "http://www.v8.1c.ru/ssl/contactinfo_ru") > 0 Then
		Return XMLText;
	EndIf;
	
	XMLText = StrReplace(XMLText, "xsi:type=""AddressUS""", "xmlns:rf=""http://www.v8.1c.ru/ssl/contactinfo_ru"" xsi:type=""rf:AddressUS""");
	
	XMLText = StrReplace(XMLText, "<USTerritorialEntitiy", "<rf:USTerritorialEntitiy");
	XMLText = StrReplace(XMLText, "/USTerritorialEntitiy>", "/rf:USTerritorialEntitiy>");
	XMLText = StrReplace(XMLText, "<USTerritorialEntitiy/>", "<rf:USTerritorialEntitiy/>");
	
	XMLText = StrReplace(XMLText, "<County", "<rf:County");
	XMLText = StrReplace(XMLText, "/County>", "/rf:County>");
	XMLText = StrReplace(XMLText, "<County/>", "<rf:County/>");
	
	XMLText = StrReplace(XMLText, "<MunicipalEntityDistrictProperty", "<rf:MunicipalEntityDistrictProperty");
	XMLText = StrReplace(XMLText, "/MunicipalEntityDistrictProperty>", "/rf:MunicipalEntityDistrictProperty>");
	XMLText = StrReplace(XMLText, "<MunicipalEntityDistrictProperty/>", "<rf:MunicipalEntityDistrictProperty/>");
	
	XMLText = StrReplace(XMLText, "<District", "<rf:District");
	XMLText = StrReplace(XMLText, "/District>", "/rf:District>");
	XMLText = StrReplace(XMLText, "</District>", "</rf:District>");
	
	XMLText = StrReplace(XMLText, "<City", "<rf:City");
	XMLText = StrReplace(XMLText, "/City>", "/rf:City>");
	XMLText = StrReplace(XMLText, "<City/>", "<rf:City/>");
	
	XMLText = StrReplace(XMLText, "CityDistrict", "rf:CityDistrict");
	
	XMLText = StrReplace(XMLText, "Settlmnt", "rf:Settlmnt");
	
	XMLText = StrReplace(XMLText, "<Street", "<rf:Street");
	XMLText = StrReplace(XMLText, "/Street>", "/rf:Street>");
	XMLText = StrReplace(XMLText, "<Street/>", "<rf:Street/>");
	
	XMLText = StrReplace(XMLText, "RNCMT", "rf:RNCMT");
	XMLText = StrReplace(XMLText, "RNCPS", "rf:RNCPS");
	
	XMLText = StrReplace(XMLText, "AdditionalAddressItem", "rf:AdditionalAddressItem");
	
	XMLText = StrReplace(XMLText, "<Number", "<rf:Number");
	XMLText = StrReplace(XMLText, "/Number>", "/rf:Number>");
	XMLText = StrReplace(XMLText, "<Number/>", "<rf:Number/>");
	
	XMLText = StrReplace(XMLText, "<Location", "<rf:Location");
	XMLText = StrReplace(XMLText, "/Location>", "/rf:Location>");
	XMLText = StrReplace(XMLText, "<Location/>", "<rf:Location/>");
	
	Return XMLText;
	
EndFunction

Function BeforeWriteXDTOContactInformation(XMLText) Export
	
	Position = StrFind(XMLText, "AddressUS""");
	If Position > 0 Then
		PositionStart = StrFind(XMLText, """", SearchDirection.FromEnd, Position);
		Prefix = Mid(XMLText, PositionStart + 1, Position - PositionStart - 2);
		
		XMLText = StrReplace(XMLText, Prefix +":", "");
		XMLText = StrReplace(XMLText, " xmlns:"+ Prefix + "=""http://www.v8.1c.ru/ssl/contactinfo_ru""", "");
	EndIf;
	
	Return XMLText;
EndFunction

Function AdditionalConversionRules() Export
	
	AdditionalAddressItemsCodes = New TextDocument;
	For Each AdditionalAddressItem In AddressManagerClientServer.LocalAddressesAddressingObjectsTypes() Do
		AdditionalAddressItemsCodes.AddLine("<data:item data:title=""" + AdditionalAddressItem.Description + """>" + AdditionalAddressItem.Code + "</data:item>");
		AdditionalAddressItemsCodes.AddLine("<data:item data:title=""" + Lower(AdditionalAddressItem.Description) + """>" + AdditionalAddressItem.Code + "</data:item>");
	EndDo;
	
	StatesCodes = New TextDocument;
	AllStates = AllStates();
	If AllStates <> Undefined Then
		For Each Row In AllStates Do
			StatesCodes.AddLine("<data:item data:code=""" + Format(Row.TerritorialEntityCode, "NZ=; NG=") + """>" 
			+ Row.Presentation + "</data:item>");
		EndDo;
	EndIf;
	
	ExtendedConversionText = "
	|  <xsl:template match=""/"" mode=""domestic"">
	|    <xsl:element name=""Content"">
	|      <xsl:attribute name=""xsi:type"">AddressUS</xsl:attribute>
	|    
	|      <xsl:element name=""USTerritorialEntitiy"">
	|        <xsl:variable name=""value"" select=""tns:Structure/tns:Property[@name='State']/tns:Value/text()"" />
	|
	|        <xsl:choose>
	|          <xsl:when test=""0=count($value)"">
	|            <xsl:variable name=""regioncode"" select=""tns:Structure/tns:Property[@name='StateCode']/tns:Value/text()""/>
	|            <xsl:variable name=""regiontitle"" select=""$enum-regioncode-nodes/data:item[@data:code=number($regioncode)]"" />
	|              <xsl:if test=""0!=count($regiontitle)"">
	|                <xsl:value-of select=""$regiontitle""/>
	|              </xsl:if>
	|          </xsl:when>
	|          <xsl:otherwise>
	|            <xsl:value-of select=""$value"" />
	|          </xsl:otherwise> 
	|        </xsl:choose>
	|
	|      </xsl:element>
	|   
	|      <xsl:element name=""County"">
	|        <xsl:value-of select=""tns:Structure/tns:Property[@name='County']/tns:Value/text()""/>
	|      </xsl:element>
	|
	|      <xsl:element name=""MunicipalEntityDistrictProperty"">
	|        <xsl:element name=""District"">
	|          <xsl:value-of select=""tns:Structure/tns:Property[@name='District']/tns:Value/text()""/>
	|        </xsl:element>
	|      </xsl:element>
	|  
	|      <xsl:element name=""City"">
	|        <xsl:value-of select=""tns:Structure/tns:Property[@name='City']/tns:Value/text()""/>
	|      </xsl:element>
	|    
	|      <xsl:element name=""CityDistrict"">
	|        <xsl:value-of select=""tns:Structure/tns:Property[@name='CityDistrict']/tns:Value/text()""/>
	|      </xsl:element>
	|
	|      <xsl:element name=""Settlmnt"">
	|        <xsl:value-of select=""tns:Structure/tns:Property[@name='Locality']/tns:Value/text()""/>
	|      </xsl:element>
	|
	|      <xsl:element name=""Street"">
	|        <xsl:value-of select=""tns:Structure/tns:Property[@name='Street']/tns:Value/text()""/>
	|      </xsl:element>
	|
	|      <xsl:variable name=""index"" select=""tns:Structure/tns:Property[@name='IndexOf']/tns:Value/text()"" />
	|      <xsl:if test=""0!=count($index)"">
	|        <xsl:element name=""AdditionalAddressItem"">
	|          <xsl:attribute name=""AddressItemType"">" + AddressManagerClientServer.ZipCodeSerializationCode() + "</xsl:attribute>
	|          <xsl:attribute name=""Value""><xsl:value-of select=""$index""/></xsl:attribute>
	|        </xsl:element>
	|      </xsl:if>
	|
	|      <xsl:call-template name=""add-elem-number"">
	|        <xsl:with-param name=""source"" select=""tns:Structure/tns:Property[@name='HOUSETYPE']/tns:Value/text()"" />
	|        <xsl:with-param name=""defsrc"" select=""'House'"" />
	|        <xsl:with-param name=""value""  select=""tns:Structure/tns:Property[@name='House']/tns:Value/text()"" />
	|      </xsl:call-template>
	|
	|      <xsl:call-template name=""add-elem-number"">
	|        <xsl:with-param name=""source"" select=""tns:Structure/tns:Property[@name='BuildingUnitType']/tns:Value/text()"" />
	|        <xsl:with-param name=""defsrc"" select=""'BuildingUnit'"" />
	|        <xsl:with-param name=""value""  select=""tns:Structure/tns:Property[@name='BuildingUnit']/tns:Value/text()"" />
	|      </xsl:call-template>
	|
	|      <xsl:call-template name=""add-elem-number"">
	|        <xsl:with-param name=""source"" select=""tns:Structure/tns:Property[@name='ApartmentType']/tns:Value/text()"" />
	|        <xsl:with-param name=""defsrc"" select=""'Apartment'"" />
	|        <xsl:with-param name=""value""  select=""tns:Structure/tns:Property[@name='Apartment']/tns:Value/text()"" />
	|      </xsl:call-template>
	|    
	|    </xsl:element>
	|  </xsl:template>
	|
	|  <xsl:param name=""enum-codevalue"">
	|" + AdditionalAddressItemsCodes.GetText() + "
	|  </xsl:param>
	|  <xsl:variable name=""enum-codevalue-nodes"" select=""exsl:node-set($enum-codevalue)"" />
	|
	|  <xsl:param name=""enum-regioncode"">
	|" + StatesCodes.GetText() + "
	|  </xsl:param>
	|  <xsl:variable name=""enum-regioncode-nodes"" select=""exsl:node-set($enum-regioncode)"" />
	|  
	|  <xsl:template name=""add-elem-number"">
	|    <xsl:param name=""source"" />
	|    <xsl:param name=""defsrc"" />
	|    <xsl:param name=""value"" />
	|
	|    <xsl:if test=""0!=count($value)"">
	|
	|      <xsl:choose>
	|        <xsl:when test=""0!=count($source)"">
	|          <xsl:variable name=""type-code"" select=""$enum-codevalue-nodes/data:item[@data:title=$source]"" />
	|          <xsl:element name=""AdditionalAddressItem"">
	|            <xsl:element name=""Number"">
	|              <xsl:attribute name=""Type""><xsl:value-of select=""$type-code"" /></xsl:attribute>
	|              <xsl:attribute name=""Value""><xsl:value-of select=""$value""/></xsl:attribute>
	|            </xsl:element>
	|          </xsl:element>
	|
	|        </xsl:when>
	|        <xsl:otherwise>
	|          <xsl:variable name=""type-code"" select=""$enum-codevalue-nodes/data:item[@data:title=$defsrc]"" />
	|          <xsl:element name=""AdditionalAddressItem"">
	|            <xsl:element name=""Number"">
	|              <xsl:attribute name=""Type""><xsl:value-of select=""$type-code"" /></xsl:attribute>
	|              <xsl:attribute name=""Value""><xsl:value-of select=""$value""/></xsl:attribute>
	|            </xsl:element>
	|          </xsl:element>
	|
	|        </xsl:otherwise>
	|      </xsl:choose>
	|
	|    </xsl:if>
	|  
	|  </xsl:template>
	|  
	|</xsl:stylesheet>";
	
	Return ExtendedConversionText;
EndFunction

#EndRegion

#Region Private

// Internal, for serialization purposes.
Function ConvertAddressFromJSONToXML(Val FieldsValues, Val Presentation, Val ExpectedType = Undefined) Export
	
	// Old format with line separator and equality.
	Namespace = ContactsManagerClientServer.Namespace();
	
	Result = XDTOFactory.Create(XDTOFactory.Type(Namespace, "ContactInformation"));
	Result.Content      = XDTOFactory.Create(XDTOFactory.Type(Namespace, "Address"));
	
	// Common composition
	Address = Result.Content;
	
	PresentationField      = "";
	
	For Each ListItem In FieldsValues Do
		
		If IsBlankString(ListItem.Value) Then
			Continue;
		EndIf;
		
		FieldName = Upper(ListItem.Key);
		
		If FieldName = "COMMENT" Then
			Comment = TrimAll(ListItem.Value);
			If ValueIsFilled(Comment) Then
				Result.Comment = Comment;
			EndIf;
			
		ElsIf FieldName = "COUNTRY" Then
			Address.Country = String(ListItem.Value);
			
		ElsIf FieldName = "VALUE" Then
			PresentationField = TrimAll(ListItem.Value);
			
		EndIf;
		
	EndDo;
	
	// Presentation with priorities.
	If Not IsBlankString(Presentation) Then
		Result.Presentation = Presentation;
	Else
		Result.Presentation = PresentationField;
	EndIf;
	
	Address.Content = Result.Presentation;
	
	Return Result;
EndFunction

// Converts the XML format to the JSON format
//
Function ContactInformationToJSONStructure(ContactInformation, Val Type = Undefined, Presentation = "", UpdateIDs = True) Export
	
	If Type <> Undefined AND TypeOf(Type) <> Type("EnumRef.ContactInformationTypes") Then
		Type = ContactInformationManagementInternalCached.ContactInformationKindType(Type);
	EndIf;
	
	If Type = Undefined Then
		
		If TypeOf(ContactInformation) = Type("String") Then
			Type = ContactsManager.ContactInformationType(ContactInformation);
		ElsIf TypeOf(ContactInformation) = Type("XDTODataObject") Then
			Namespace = ContactsManagerClientServer.Namespace();
			
			TypeFound = ?(ContactInformation.Content = Undefined, Undefined, ContactInformation.Content.Type());
			Type = ContactsManagerInternal.MapXDTOToContactsTypes(TypeFound);
			
		EndIf;
		
	EndIf;
	
	If Metadata.CommonModules.Find("AddressManagerClientServer") <> Undefined Then
		ModuleAddressManagerClientServer = Common.CommonModule("AddressManagerClientServer");
		Result = ModuleAddressManagerClientServer.NewContactInformationDetails(Type);
		MainCountry = ModuleAddressManagerClientServer.MainCountry();
	Else
		Result = ContactsManagerClientServer.NewContactInformationDetails(Type);
		MainCountry = "";
	EndIf;
	
	CountryDescription = "";
	Format9Commas = False;
	AddressItems = New Map;
	
	If TypeOf(ContactInformation) = Type("String") Then
		
		If ContactsManagerClientServer.IsXMLContactInformation(ContactInformation) Then
			
			ConversionResult = New Structure;
			XDTOContactInformation = ContactsManagerInternal.ContactsFromXML(ContactInformation, Type, ConversionResult, Presentation);
			Result.Value   = XDTOContactInformation.Presentation;
			Result.Comment = XDTOContactInformation.Comment;
		Else
			If StrOccurrenceCount(ContactInformation, ",") = 9 AND StrFind(ContactInformation, "=") = 0 Then
				Format9Commas = True;
				LocalAddress        = ContactInformation;
			Else
				XDTOContactInformation = ContactsManagerInternal.ContactsFromXML(ContactInformation, Type,, Presentation);
				Result.Value          = XDTOContactInformation.Presentation;
				Result.Comment        = XDTOContactInformation.Comment;
			EndIf;
		EndIf;
		
	ElsIf TypeOf(ContactInformation) = Type("XDTODataObject") Then
		
		XDTOContactInformation = ContactInformation;
		Result.Value          = XDTOContactInformation.Presentation;
		Result.Comment        = XDTOContactInformation.Comment;
		
	ElsIf TypeOf(ContactInformation) = Type("Structure") Then
		
		Return AddressStructureToJSONStructure(ContactInformation);
		
	EndIf;
	
	If Type <> Enums.ContactInformationTypes.Address AND Type <> Enums.ContactInformationTypes.Phone Then
		Return Result;
	EndIf;

	If NOT Format9Commas Then
		
		Namespace = ContactsManagerClientServer.Namespace();
		Composition = XDTOContactInformation.Content;
		
		If Composition = Undefined Then
			Return Result;
		EndIf;
		
		XDTODataType = Composition.Type();
		
		If XDTODataType = XDTOFactory.Type(Namespace, "Address") Then
			
			Result.Insert("Country", Composition.Country);
			Country = ?(IsBlankString(Composition.Country),
					MainCountry,
					Catalogs.WorldCountries.FindByDescription(Composition.Country, True));
			CountryDescription = Country.Description;
			Result.Insert("CountryCode", TrimAll(Country.Code));
			
			LocalAddress = Composition.Content;
			
		ElsIf 
			XDTODataType = XDTOFactory.Type(ContactsManagerClientServer.Namespace(), "PhoneNumber")
			Or XDTODataType = XDTOFactory.Type(ContactsManagerClientServer.Namespace(), "FaxNumber") Then
			
			Result.CountryCode = Composition.CountryCode;
			Result.AreaCode    = Composition.CityCode;
			Result.Number      = Composition.Number;
			Result.ExtNumber   = Composition.Extension;
			
			Return Result;
			
		ElsIf XDTODataType = XDTOFactory.Type(Namespace(), "AddressUS") Then
			LocalAddress = Composition;
		Else
			Return Result;
		EndIf;
		
		If LocalAddress = Undefined Then
			Return Result;
		ElsIf TypeOf(LocalAddress) = Type("String") Then
			
			If StrOccurrenceCount(LocalAddress, ",") = 9 Then
				
				If ContactsManager.IsEEUMemberCountry(Result.Country) Then
					Result.AddressType = ContactsManagerClientServer.EEUAddress();
				Else
					Result.AddressType = ContactsManagerClientServer.ForeignAddress();
				EndIf;
				
				AddressParts = StrSplit(LocalAddress, ",");
				Result.ZIPCode = AddressParts[1];
				
				DescriptionShortForm = ContactsManagerClientServer.DescriptionShortForm(AddressParts[2]);
				Result.Area     = DescriptionShortForm.Description;
				Result.AreaType = DescriptionShortForm.ShortForm;
				
				DescriptionShortForm = ContactsManagerClientServer.DescriptionShortForm(AddressParts[3]);
				Result.District     = DescriptionShortForm.Description;
				Result.DistrictType = DescriptionShortForm.ShortForm;
				
				DescriptionShortForm = ContactsManagerClientServer.DescriptionShortForm(AddressParts[4]);
				Result.City         = DescriptionShortForm.Description;
				Result.CityType     = DescriptionShortForm.ShortForm;
				
				DescriptionShortForm = ContactsManagerClientServer.DescriptionShortForm(AddressParts[5]);
				Result.Locality     = DescriptionShortForm.Description;
				Result.LocalityType = DescriptionShortForm.ShortForm;
				
				DescriptionShortForm = ContactsManagerClientServer.DescriptionShortForm(AddressParts[6]);
				Result.Street       = DescriptionShortForm.Description;
				Result.StreetType   = DescriptionShortForm.ShortForm;
				
				DescriptionShortForm = ContactsManagerClientServer.DescriptionShortForm(AddressParts[7]);
				Result.HouseNumber  = DescriptionShortForm.ShortForm;
				Result.HouseType    = DescriptionShortForm.Description;
				
				If ValueIsFilled(AddressParts[8]) Then
					DescriptionShortForm = ContactsManagerClientServer.DescriptionShortForm(AddressParts[8]);
					Result.Buildings.Add(ContactsManagerClientServer.ConstructionOrPremiseValue(
						DescriptionShortForm.Description, DescriptionShortForm.ShortForm));
				EndIf;
				
				If ValueIsFilled(AddressParts[9]) Then
					DescriptionShortForm = ContactsManagerClientServer.DescriptionShortForm(AddressParts[9]);
					Result.Apartments.Add(ContactsManagerClientServer.ConstructionOrPremiseValue(
						DescriptionShortForm.Description, DescriptionShortForm.ShortForm));
				EndIf;
			EndIf;
		Else
			
			If ValueIsFilled(LocalAddress.Address_by_document) Then
				Result.AddressType = ContactsManagerClientServer.AddressInFreeForm();
			Else
				Result.AddressType = AddressManagerClientServer.AdministrativeAndTerritorialAddress();
			EndIf;
			
			Result.Country = CountryDescription;
			Result.ZIPCode = DataProcessors.AdvancedContactInformationInput.AddressZipCode(LocalAddress);
			Result.OKTMO = Format(LocalAddress.RNCMT, "NG=0");
			Result.OKATO = Format(LocalAddress.RNCPS, "NG=0");
			
			USTerritorialEntitiy = ContactsManagerClientServer.DescriptionShortForm(LocalAddress.USTerritorialEntitiy);
			Result.Area     = String(USTerritorialEntitiy.Description);
			Result.AreaType = String(USTerritorialEntitiy.ShortForm);
			
			AddressDistrict = ContactsManagerClientServer.DescriptionShortForm(AddressDistrict(LocalAddress));
			Result.District     = String(AddressDistrict.Description);
			Result.DistrictType = String(AddressDistrict.ShortForm);
			
			City = ContactsManagerClientServer.DescriptionShortForm(LocalAddress.City);
			Result.City     = String(City.Description);
			Result.CityType = String(City.ShortForm);
			
			Settlmnt = ContactsManagerClientServer.DescriptionShortForm(LocalAddress.Settlmnt);
			Result.Locality     = String(Settlmnt.Description);
			Result.LocalityType = String(Settlmnt.ShortForm);
			
			Street = ContactsManagerClientServer.DescriptionShortForm(LocalAddress.Street);
			Result.Street     = String(Street.Description);
			Result.StreetType = String(Street.ShortForm);
			
			CityDistrict = ContactsManagerClientServer.DescriptionShortForm(LocalAddress.CityDistrict);
			Result.CityDistrict     = String(CityDistrict.Description);
			Result.CityDistrictType = String(CityDistrict.ShortForm);
			
			AdditionalItemsValue = DataProcessors.AdvancedContactInformationInput.AdditionalItemsValue(LocalAddress);
			If ValueIsFilled(AdditionalItemsValue.AdditionalItem) Then
				AdditionalItem = ContactsManagerClientServer.DescriptionShortForm(AdditionalItemsValue.AdditionalItem);
				Result.Territory     = String(AdditionalItem.Description);
				Result.TerritoryType = String(AdditionalItem.ShortForm);
			EndIf;
			If ValueIsFilled(AdditionalItemsValue.SubordinateItem) Then
				SubordinateItem = ContactsManagerClientServer.DescriptionShortForm(AdditionalItemsValue.SubordinateItem);
				Result.Street     = String(SubordinateItem.Description);
				Result.StreetType = String(SubordinateItem.ShortForm);
			EndIf;
			
			BuildingsAndPremises = DataProcessors.AdvancedContactInformationInput.AddressBuildingsAndPremises(LocalAddress);
			For each Building In BuildingsAndPremises.Buildings Do
				If Building.Kind = 1 Then
					Result.HouseType = Building.Type;
					Result.HouseNumber = Building.Value;
				Else
					Result.Buildings.Add(ContactsManagerClientServer.ConstructionOrPremiseValue(Building.Type, Building.Value));
				EndIf;
			EndDo;
			
			For each Premise In BuildingsAndPremises.Premises Do
				Result.Apartments.Add(ContactsManagerClientServer.ConstructionOrPremiseValue(Premise.Type, Premise.Value));
			EndDo;
			
		EndIf;
	EndIf;
	
	If UpdateIDs AND Common.SubsystemExists("StandardSubsystems.AddressClassifier") Then
		ModuleAddressClassifierInternal = Common.CommonModule("AddressClassifierInternal");
		ModuleAddressClassifierInternal.SetAddressIDs(Result);
	EndIf;
	
	Return Result;
	
EndFunction

Function PrepareAddressForInput(Data) Export
	
	If Data.Property("id") AND IsBlankString(Data.id) AND Common.SubsystemExists("StandardSubsystems.AddressClassifier") Then
		
		ModuleAddressClassifierInternal = Common.CommonModule("AddressClassifierInternal");
		ModuleAddressClassifierInternal.SetAddressIDs(Data);
		
	EndIf;
	
	LocalityDetailed = AddressManagerClientServer.NewContactInformationDetails(PredefinedValue("Enum.ContactInformationTypes.Address"));
	FillPropertyValues(LocalityDetailed, Data);
	
	If TypeOf(LocalityDetailed.Buildings) <> Type("Array") Then
		LocalityDetailed.Buildings = New Array;
	EndIf;
	
	If TypeOf(LocalityDetailed.Apartments) <> Type("Array") Then
		LocalityDetailed.Buildings = New Array;
	EndIf;
	
	For each AddressItem In LocalityDetailed Do
		
		If StrEndsWith(AddressItem.Key, "Id")
			AND TypeOf(AddressItem.Value) = Type("String")
			AND StrLen(AddressItem.Value) = 36 Then
				LocalityDetailed[AddressItem.Key] = New UUID(AddressItem.Value);
		EndIf;
		
	EndDo;
	
	If Data.Property("house") Then
		LocalityDetailed.HouseNumber = Data.house;
	EndIf;
	
	Return LocalityDetailed;
	
EndFunction

Function AddressStructureToJSONStructure(Val ContactInformation)
	
	ContactInformationDetails = AddressManagerClientServer.NewContactInformationDetails(Enums.ContactInformationTypes.Address);
	
	FieldsMap = New Map();
	FieldsMap.Insert("AddressType",                     "AddressType");
	FieldsMap.Insert("Presentation",                 "value");
	FieldsMap.Insert("Comment",                   "comment");
	FieldsMap.Insert("CountryDescription",             "country");
	FieldsMap.Insert("Country",                         "country");
	FieldsMap.Insert("IndexOf",                         "ZIPCode");
	FieldsMap.Insert("RNCMT",                          "oktmo");
	FieldsMap.Insert("RNCPS",                          "okato");
	FieldsMap.Insert("State",                         "area");
	FieldsMap.Insert("StateShortForm",               "areaType");
	FieldsMap.Insert("District",                          "district");
	FieldsMap.Insert("DistrictShortForm",                "districtType");
	FieldsMap.Insert("City",                          "city");
	FieldsMap.Insert("CityShortForm",                "cityType");
	FieldsMap.Insert("Locality",                "locality");
	FieldsMap.Insert("LocalityShortForm",      "localityType");
	FieldsMap.Insert("Street",                          "street");
	FieldsMap.Insert("StreetShortForm",                "streetType");
	FieldsMap.Insert("StateCode",                     "areaCode");
	FieldsMap.Insert("MunicipalDistrict",             "munDistrict");
	FieldsMap.Insert("MunicipalDistrictShortForm",   "munDistrictType");
	FieldsMap.Insert("Settlement",                      "settlement");
	FieldsMap.Insert("SettlementShortForm",            "settlementType");
	FieldsMap.Insert("CityDistrict",           "cityDistrict");
	FieldsMap.Insert("CityDistrictShortForm", "cityDistrictType");
	FieldsMap.Insert("Territory",                     "territory");
	FieldsMap.Insert("TerritoryShortForm",           "territoryType");
	FieldsMap.Insert("AddressObjectID",  "id");
	FieldsMap.Insert("HouseID",              "houseId");
	FieldsMap.Insert("House",                            "HouseNumber");
	FieldsMap.Insert("HOUSETYPE",                        "HouseType");
	
	ContactInformationDetails.AddressType = AddressManagerClientServer.AdministrativeAndTerritorialAddress();
	
	For each ContactInformationField In ContactInformation Do
		FieldName = FieldsMap.Get(ContactInformationField.Key);
		If FieldName <> Undefined Then
			ContactInformationDetails[FieldName] = ContactInformationField.Value;
		EndIf;
	EndDo;
	
	If ContactInformation.Property("Building") 
		AND TypeOf(ContactInformation.Building) = Type("Structure")
		AND ContactInformation.Building.Property("Number") Then
		
			ContactInformationDetails.HouseNumber = ?(ContactInformation.Building.Property("Number"), ContactInformation.Building.Number, "");
			ContactInformationDetails.HouseType = ?(ContactInformation.Building.Property("BuildingType"), ContactInformation.Building.BuildingType, NStr("ru='Дом'; en = 'House'; pl = 'Nr domu';es_ES = 'Casa';es_CO = 'Casa';tr = 'Bina';it = 'Abitazione';de = 'Haus'"));
		
	EndIf;
	
	If ContactInformation.Property("BuildingUnit")AND ValueIsFilled(ContactInformation.BuildingUnit) Then
		
		BuildingUnitType = ?(ContactInformation.Property("BuildingUnitType"), ContactInformation.BuildingUnitType, NStr("ru='Корпус'; en = 'BuildingUnit'; pl = 'BuildingUnit';es_ES = 'BuildingUnit';es_CO = 'BuildingUnit';tr = 'BuildingUnit';it = 'Blocco';de = 'BuildingUnit'"));
		ContactInformationDetails.buildings.Add(ContactsManagerClientServer.ConstructionOrPremiseValue(BuildingUnitType, ContactInformation.BuildingUnit));
	ElsIf ContactInformation.Property("BuildingUnits")AND TypeOf(ContactInformation.BuildingUnits) = Type("Array") Then
		For each BuildingUnit In ContactInformation.BuildingUnits Do
			ContactInformationDetails.buildings.Add(
				ContactsManagerClientServer.ConstructionOrPremiseValue(BuildingUnit.Type, BuildingUnit.Number));
		EndDo;
		
	EndIf;
	
	If ContactInformation.Property("Apartment") AND ValueIsFilled(ContactInformation.Apartment) Then
		
		ApartmentType = ?(ContactInformation.Property("ApartmentType"), ContactInformation.ApartmentType, NStr("ru='Квартира'; en = 'Apartment'; pl = 'Nr lokalu';es_ES = 'Apartamento';es_CO = 'Apartamento';tr = 'Daire';it = 'Appartamento';de = 'Wohnung'"));
		ContactInformationDetails.apartments.Add(ContactsManagerClientServer.ConstructionOrPremiseValue(ApartmentType, ContactInformation.Apartment));
		
	ElsIf ContactInformation.Property("Premises")AND TypeOf(ContactInformation.Premises) = Type("Array") Then
		
		For each Premise In ContactInformation.Premises Do
			ContactInformationDetails.apartments.Add(
				ContactsManagerClientServer.ConstructionOrPremiseValue(Premise.Type, Premise.Number));
		EndDo;
			
	EndIf;
	
	Return ContactInformationDetails;
	
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
		If XDTODataType = XDTOFactory.Type(Namespace(), "AddressUS") Then
			LocalAddress = XDTOAddress;
		Else
			LocalAddress = XDTOAddress.Content;
		EndIf;
		
		If TypeOf(LocalAddress) = Type("XDTODataObject") Then
			Return ContactsManager.GetXDTOObjectAttribute(LocalAddress, AddressManagerClientServer.DistrictXPath());
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

// Returns the list of states available in the address classifier.
//
// Returns:
//   ValueTable - contains the following columns:
//      * TerritorialEntityCode - Number -                   a state code.
//      * ID - UUID - a state ID.
//      * Presentation - String                  - a description and short form of a state.
//      * Imported     - Boolean                  - True if a classifier for this state is imported.
//      * VersionDate    - Date - an UTC version of imported data.
//   Undefined    - if the address classifier subsystem is unavailable.
// 
Function AllStates()
	
	If Common.SubsystemExists("StandardSubsystems.AddressClassifier") Then
		ModuleAddressClassifierInternal = Common.CommonModule("AddressClassifierInternal");
		Return ModuleAddressClassifierInternal.RegionImportInfo();
	EndIf;
	Return Undefined;
	
EndFunction

// Returns address info as a structure of address parts and ARCA codes.
//
Function AddressesInfoAsStructure(Addresses, AdditionalParameters)
	Result = New Array;
	For each Address In Addresses Do
		Result.Add(AddressInfoAsStructure(Address, AdditionalParameters));
	EndDo;
	Return Result;
EndFunction

// Returns address info as separated address parts and various codes (state code, RNCMT, and so on).
//
// Parameters:
//   Address                  - String - an address in the internal JSON or XML format matching the Address XDTO data package.
//                          - XDTODataObject - an XDTO data object matching the Address XDTO data package.
//   AdditionalParameters - Structure - to clarify the return value:
//       * WithoutPresentations - Boolean - if True, the Presentation field will not be displayed. The default value is False.
//       * ARCACodes - Boolean - if True, the structure of ARCACodes returns. The default value is False.
//       * FullDescriptionsOfShortForms - Boolean - if True, returns full descriptions of address objects.
//       * DescriptionIncludesShortForm - Boolean - if True, the descriptions of address objects contain their short forms.
// ,      * IncludeCountryInPresentation - Boolean - if True, the presentation includes a country description.
//       * CheckAddress   - Boolean - if True, the address is checked for compliance with FIAS.
//
// Returns:
//   Structure - info on the address:
//        * Presentation    - String - a text presentation of an address with administrative and territorial structure.
//        * MunicipalPresentation - String - a text presentation of an address with municipal structure.
//        * AddressType        - String - the main address type (only for local addresses).
//                                      Available options: "Municipal" and "Administrative and territorial".
//        * Country           - String - a text presentation of a country.
//        * CountryCode - String - an ARCC country code.
//        * ZipCode           - String - a zip code.
//        * StateCode       - String - a code of a local state.
//        * State           - String - a text presentation of a local state.
//        * StateShortForm - String - a short form of a state.
//        * County            - String - a text presentation of county (obsolete).
//        * CountyShortForm - String - a short form of "county" (obsolete).
//        * District            - String - a text presentation of a district (for addresses with administrative and territorial structure).
//        * DistrictShortForm - String - a short form of "district" (for addresses with administrative and territorial structure).
//        * MunicipalDistrict - String - a text presentation of a municipal district (for addresses with municipal structure).
//        * MunicipalDistrictShortForm - String - a short form of "municipal district" (for addresses with municipal structure).
//        * City            - String - a text presentation of a city (for addresses with administrative and territorial structure).
//        * CityShortForm - String - a short form of "city" (for addresses with administrative and territorial structure).
//        * Settlement            - String - a text presentation of a settlement (for addresses with municipal division).
//        * SettlementShortForm  - String - a short form of "settlement" (for addresses with municipal division).
//        * CityDistrict - String - a text presentation of a city district.
//        * CityDistrictShortForm - String - a short form of "city district."
//        * Locality - String - a text presentation of a locality.
//        * LocalityShortForm - String - a short form of "locality."
//        * Territory - String - a text presentation of a territory.
//        * TerritoryShortForm - String - a short form of "territory."
//        * Street            - String - a text presentation of a street.
//        * StreetShortForm - String - a short form of "street."
//        * AdditionalTerritory - String - a text presentation of an additional territory (obsolete).
//        * AdditionalTerritoryShortForm - String - a short form of "additional territory" (obsolete).
//        * AdditionalTerritoryItem - String - a text presentation of an additional territory item (obsolete).
//        * AdditionalTerritoryItem - String - a short form of "additional territory item" (obsolete).
//        * Building - Structure - a structure with building address information.
//            ** BuildingType - String - an addressing object type of an RF address in accordance to the order of Ministry of Finance of Russia dated 11/05/2015. N
//                                     171N
//            ** Number - String - a text presentation of a house number (only for local addresses).
//        * BuildingUnit - Array - contains structures (structure fields: BuildingUnitType, Number) that list building units of an address.
//        * Premises - Array - contains structures (structure fields: PremiseType and Number) that list address premises.
//        * AddressObjectID - UUID - an identification code of the last address object in the 
//                                        address hierarchy. For example, for the address 9 
//                                        Dmitrovskoye sh., Moscow, the street ID serves as an address object ID.
//        * HouseID            - UUID - an identification code of the house (construction) of the address object.
//        * IDs - Structure - address objects IDs.
//            ** StateID - UUID - a state ID.
//            ** DistrictID - UUID - a district ID.
//            ** MunicipalDistrictID - UUID - a municipal district ID.
//            ** CityID - UUID - a city ID.
//            ** SettlementID - UUID - a settlement ID.
//            ** CityDistrictID - UUID - a city district ID.
//            ** TerritoryID - UUID - a territory ID.
//            ** TerritoryID - UUID - a territory ID.
//            ** StreetID      - UUID - a street ID.
//        * ARCACodes           - Structure - ARCA codes if the ARCACodes parameter is set.
//           ** State          - String - an ARCA code of a state.
//           ** District           - String - an ARCA code of a district.
//           ** City           - String - an ARCA code of a city.
//           ** Locality - String - an ARCA code of a locality.
//           ** Street           - String - an ARCA code of a street.
//        * Additional codes - Structure - the following codes: RNCMT, RNCPS, IFTSICode, IFTSLECode, IFTSIAreaCode, and IFTSLEAreaCode.
//        * AddressCheckResult - String - "Success" if the address is correct, "Error" if there are some check errors,
//                                             "Cancel" if cannot validate the address as the classifier is unavailable.
//                                             Blank string if the CheckAddress check box is not 
//                                             selected in the AdditionalParameters.CheckAddress parameter.
//        * AddressCheckErrors - String - details of address errors detected upon the check.
//
Function AddressInfoAsStructure(Val AddressAsString, AdditionalParameters)
	
	Result = New Structure();
	
	Parameters = New Structure();
	Parameters.Insert("NoPresentations",               False);
	Parameters.Insert("DescriptionIncludesShortForm", False);
	Parameters.Insert("ARCACodes",                      False);
	Parameters.Insert("FullDescriptionOfShortForms",   False);
	Parameters.Insert("CheckAddress",                 False);
	Parameters.Insert("IncludeCountryInPresentation",   False);
	Parameters.Insert("AddressCodes",                     False);
	
	If TypeOf(AdditionalParameters) = Type("Structure") Then
		
		FillPropertyValues(Parameters, AdditionalParameters);
		
	EndIf;
	
	ShortFormsMap = New Map;
	
	If NOT (TypeOf(AddressAsString) = Type("Structure") AND AddressAsString.Property("Value")) Then
		
		If NOT ContactsManagerClientServer.IsJSONContactInformation(AddressAsString) Then
			AddressAsString = ContactsManager.ContactInformationInJSON(AddressAsString, Enums.ContactInformationTypes.Address);
		EndIf;
		
	EndIf;
	
	ReceivedAddress = ContactsManagerInternal.JSONStringToStructure(AddressAsString);
	Address = AddressManagerClientServer.NewContactInformationDetails(Enums.ContactInformationTypes.Address);
	FillPropertyValues(Address, ReceivedAddress);
	Address.type = ContactsManagerClientServer.ContactInformationTypeToString(Enums.ContactInformationTypes.Address);
	
	If IsBlankString(Address.ID) AND (Parameters.AddressCodes Or Parameters.ARCACodes) Then
		
		If Common.SubsystemExists("StandardSubsystems.AddressClassifier") Then
			ModuleAddressClassifierInternal = Common.CommonModule("AddressClassifierInternal");
			ModuleAddressClassifierInternal.SetAddressIDs(Address);
		EndIf;
		
	EndIf;
	
	// Main additional data
	Result.Insert("Comment", Address.Comment);
	Result.Insert("IndexOf",      Address.ZipCode);
	Result.Insert("AddressType",   Address.AddressType);
	Result.Insert("Country",      Address.Country);
	
	If ValueIsFilled(Address.CountryCode) Then
		Result.Insert("CountryCode", Address.CountryCode);
	Else
		CountryInfo = ContactsManager.WorldCountryData(Undefined, Address.Country);
		Result.Insert("CountryCode", ?(CountryInfo <> Undefined, CountryInfo.Code, ""));
	EndIf;
	
	IsNationalAddress = ?(StrCompare(Address.Country, AddressManagerClientServer.MainCountry().Description) = 0, True, False);
	StateCode = ?(IsNationalAddress, StateCode(Address["Area"] + " " +Address["AreaType"]), "");
	Result.Insert("StateCode", StateCode);
	
	// Backward compatibility, levels are obsolete.
	Result.Insert("County",                                     "");
	Result.Insert("CountyShortForm",                           "");
	Result.Insert("AdditionalTerritory",                  "");
	Result.Insert("AdditionalTerritoryShortForm",        "");
	Result.Insert("AdditionalTerritoryItem",           "");
	Result.Insert("AdditionalTerritoryItemShortForm", "");
	
	LevelsMap = New Map;
	LevelsMap.Insert("area",         New Structure("Name, Level", "State", 1));
	LevelsMap.Insert("district",     New Structure("Name, Level", "District", 3));
	LevelsMap.Insert("munDistrict",  New Structure("Name, Level", "MunicipalDistrict", 31));
	LevelsMap.Insert("city",         New Structure("Name, Level", "City", 4));
	LevelsMap.Insert("settlement",   New Structure("Name, Level", "Settlement", 41));
	LevelsMap.Insert("cityDistrict", New Structure("Name, Level", "CityDistrict", 5));
	LevelsMap.Insert("locality",     New Structure("Name, Level", "Locality", 6));
	LevelsMap.Insert("territory",    New Structure("Name, Level", "Territory", 65));
	LevelsMap.Insert("street",       New Structure("Name, Level", "Street", 7));
	
	If Parameters.AddressCodes Or Parameters.ARCACodes Then
		IDs = New Structure();
		Result.Insert("IDs", IDs);
	EndIf;
	
	AddressObjectID = "";
	MaxIDLevel = 0;
	For each AddressPart In LevelsMap Do
		
		CurrentLevelID = Address[AddressPart.Key + "Id"];
		
		ShortForm = Address[AddressPart.Key + "Type"];
		LevelDescription = ?(Parameters.DescriptionIncludesShortForm, TrimAll(Address[AddressPart.Key] + " " + ShortForm),
			Address[AddressPart.Key]);
		
		Result.Insert(AddressPart.Value.Name, LevelDescription);
		Result.Insert(AddressPart.Value.Name + "ShortForm", ShortForm);
		ShortFormsMap.Insert(AddressPart.Value.Level, ShortForm);
		
		If Parameters.AddressCodes Or Parameters.ARCACodes Then
			IDs.Insert(AddressPart.Value.Name + "ID", CurrentLevelID);
			IDs.Insert(AddressPart.Value.Name, CurrentLevelID);
		EndIf;
		
		IDLevel = ?(AddressPart.Value.Level < 10, AddressPart.Value.Level * 10, AddressPart.Value.Level);
		If ValueIsFilled(CurrentLevelID) AND MaxIDLevel < IDLevel Then
			AddressObjectID = CurrentLevelID;
		EndIf;
		
	EndDo;
	
	If Parameters.AddressCodes Then
		Result.Insert("AddressObjectID", AddressObjectID);
	EndIf;
	
	// Set full short forms if the parameter is defined.
	If Parameters.FullDescriptionOfShortForms  = True Then
		If Common.SubsystemExists("StandardSubsystems.AddressClassifier") Then
			ModuleAddressClassifierInternal = Common.CommonModule("AddressClassifierInternal");
			ModuleAddressClassifierInternal.FullDescriptionsOfShortForms(ShortFormsMap);
			
			For each AddressPart In LevelsMap Do
				
				Result.Insert(AddressPart.Value.Name + "ShortForm", ShortFormsMap[AddressPart.Value.Level]);
				
			EndDo;
			
		EndIf;
	EndIf;
	
	// Houses, buildings, and constructions
	Result.Insert("Building", New Structure("BuildingType, Number"));
	Result.Insert("BuildingUnits", New Array);
	Result.Insert("Premises", New Array);
	
	Result.Building.Insert("BuildingType", Address.HouseType);
	Result.Building.Insert("Number",     Address.HouseNumber);
	
	For each BuildingUnit In Address.Buildings Do
		Result.BuildingUnits.Add(New Structure("BuildingUnitType, Number", BuildingUnit.Type, BuildingUnit.Number));
	EndDo;
	
	For each BuildingUnit In Address.Apartments Do
		Result.Premises.Add(New Structure("PremiseType, Number", BuildingUnit.Type, BuildingUnit.Number));
	EndDo;
	
	If Parameters.AddressCodes Then
		Result.Insert("HouseID", "");
	EndIf;
	
	AddressCheckResult = "";
	ErrorsList            = "";
	
	If IsNationalAddress Then
		
		If Common.SubsystemExists("StandardSubsystems.AddressClassifier") Then
			ModuleAddressClassifierInternal = Common.CommonModule("AddressClassifierInternal");
			If Parameters.ARCACodes Or Parameters.AddressCodes Then
				AdditionalCodes = ModuleAddressClassifierInternal.AddressCodesAndARCACodes(Address, AddressObjectID);
				Result.Insert("AdditionalCodes", AdditionalCodes.AddressCodes);
				Result.Insert("ARCACodes",          AdditionalCodes.ARCACodes);
				If Parameters.AddressCodes AND AdditionalCodes.AddressCodes.Property("HouseID") Then
					Result.HouseID = AdditionalCodes.AddressCodes.HouseID;
				EndIf;
			EndIf;
		Else
			FillAddressCodes(Result, Address);
		EndIf;
		
		If Parameters.CheckAddress Then
			
			CheckResult = CheckAddress(AddressAsString);
			
			If CheckResult.Result = "Correct" Then
				AddressCheckResult = "Success";
			ElsIf CheckResult.Result = "ContainsErrors" Then
				AddressCheckResult = "Error";
				ErrorsList = CheckResult.ErrorsList;
			Else
				AddressCheckResult = "Cancel";
				ErrorsList = CheckResult.ErrorsList;
			EndIf;
			
		EndIf;
		
		Result.Insert("AddressCheckResult", AddressCheckResult);
		Result.Insert("AddressCheckErrors", ErrorsList);
		
		
	EndIf;
	
	If Not Parameters.NoPresentations Then
		
		Result.Insert("Presentation", AddressManagerClientServer.AddressPresentation(Address,
			Parameters.IncludeCountryInPresentation, AddressManagerClientServer.AdministrativeAndTerritorialAddress()));
		If IsBlankString(Result.Presentation) Then
			Result.Insert("Presentation", Address.value);
		EndIf;
		
		Result.Insert("MunicipalPresentation", AddressManagerClientServer.AddressPresentation(Address,
			Parameters.IncludeCountryInPresentation, AddressManagerClientServer.MunicipalAddress()));
		If IsBlankString(Result.MunicipalPresentation) Then
			Result.Insert("MunicipalPresentation", Address.value);
		EndIf;
		
	EndIf;
	
	ContactsManagerInternal.ReplaceInStructureUndefinedWithEmptyString(Result);
	
	Return Result;
	
EndFunction

// Returns a code of a state by its full description.
//
//  Parameters:
//      StateDescription - String - a full description and short form of a state.
//
// Returns:
//      String - a two-digit state code. Blank string if the description cannot be determined.
//      Undefined - if the address classifier subsystem is unavailable.
// 
Function StateCode(Val FullDescription) Export
	
	If Common.SubsystemExists("StandardSubsystems.AddressClassifier") Then
		ModuleAddressClassifier = Common.CommonModule("AddressClassifier");
		Code = ModuleAddressClassifier.StateCodeByDescription(FullDescription);
		Return Format(Code, "ND=2; NZ=; NLZ=");
	EndIf;
	
	Return Undefined;
	
EndFunction

// Fills codes by address structure.
//
Procedure FillAddressCodes(Result, Address)
	
	AdditionalCodes = New Structure();
	AdditionalCodes.Insert("RNCMT", "");
	AdditionalCodes.Insert("RNCPS", "");
	AdditionalCodes.Insert("IndividualFTSCode", "");
	AdditionalCodes.Insert("BusinessIFTSCode", "");
	AdditionalCodes.Insert("IndividualFTSAreaCode", "");
	AdditionalCodes.Insert("BusinessIFTSAreaCode", "");
	AdditionalCodes.Insert("HouseID", "");
	AdditionalCodes.Insert("BusinessIFTSAreaCode", "");
	
	Result.Insert("AdditionalCodes", AdditionalCodes);

	SetFieldValues(Result, Address, "RNCMT", "OKTMO");
	SetFieldValues(Result, Address, "RNCPS", "OKATO");
	SetFieldValues(Result, Address, "IndividualFTSCode", "IFNSFLCode");
	SetFieldValues(Result, Address, "BusinessIFTSCode", "IFNSULCode");
	SetFieldValues(Result, Address, "IndividualFTSAreaCode", "IFNSFLAreaCode");
	SetFieldValues(Result, Address, "BusinessIFTSAreaCode", "IFNSULAreaCode");
	SetFieldValues(Result, Address, "HouseID", "HouseId");
	
	ACRACode = "";
	If Address.Property("CodeKLADR") AND ValueIsFilled(Address.CodeKLADR) Then
		ACRACode = Address.CodeKLADR;
	EndIf;
	Result.Insert("ARCACodes", DefineCodesARCACodes(Address, ACRACode));
	
EndProcedure

Procedure SetFieldValues(Destination, Source, DestinationFieldName, SourceFieldName)
	If Source.Property(SourceFieldName) Then
		Value = ?(ValueIsFilled(Source), Source[SourceFieldName], ""); // Undefined, Null and so on to a blank string
	EndIf;
	Destination[DestinationFieldName] = Value;
EndProcedure

// Fills codes by address structure.
//
Function DefineCodesARCACodes(Address, Val ACRACode)
	
	ARCACodes = New Structure();
	ARCACodes.Insert("State",               "");
	ARCACodes.Insert("County",                "");
	ARCACodes.Insert("City",                "");
	ARCACodes.Insert("CityDistrict", "");
	ARCACodes.Insert("Locality",      "");
	ARCACodes.Insert("Street",                "");
	
	// Fill in ARCA codes.
	If ValueIsFilled(ACRACode) Then
		ACRACode = Format(ACRACode, "NGS=''; NG=0");
		
		If StrLen(ACRACode) = 17 Then
			ARCACodes.Street = ACRACode;
		EndIf;
		ACRACode = Left(ACRACode, 13);
		
		If StrLen(ACRACode) = 12 Then
			ACRACode = "0" + ACRACode;
		EndIf;
		
		If StrLen(ACRACode) = 13 Then
			If ValueIsFilled(Address.Area) Then
				ARCACodes.State = Left(ACRACode, 2) + "00000000000";
			EndIf;
			If ValueIsFilled(Address.District) Then
				ARCACodes.District = Left(ACRACode, 5) + "00000000";
			EndIf;
			If ValueIsFilled(Address.City) Then
				ARCACodes.City = Left(ACRACode, 8) + "00000";
			EndIf;
			If ValueIsFilled(Address.Settlement) Then
				ARCACodes.Locality = Left(ACRACode, 11) + "00";
			EndIf;
			
		EndIf;
	EndIf;
	
	Return ARCACodes;
	
EndFunction

Function SeparateHousesAndConstructions(Value, DefaultType)
	
	Result = New Structure("Number, Type");
	
	Number = TrimAll(Value);
	Position = StrFind(Number, " ");
	If Position > 0 Then
		Result.Type = Left(Number, Position);
		Result.Number = Mid(Number, Position + 1);
	Else
		Result.Type = DefaultType;
		Result.Number = Number;
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion