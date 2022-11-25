#Region Public

// Returns structure of address fields for address generation from 1C:Enterprise script.
//
// Result:
//    Structure - address fields:
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
//        * HouseID - UUID - an identification code of the house (construction) of the address object.
//        * IDs - Structure - address objects IDs.
//            ** StateID - UUID, Undefined - a state ID.
//            ** DistrictID - UUID, Undefined - a district ID.
//            ** MunicipalDistrictID - UUID, Undefined - a municipal district ID.
//            ** CityID - UUID, Undefined - a city ID.
//            ** SettlementID - UUID, Undefined - a settlement ID.
//            ** CityDistrictID - UUID, Undefined - a city district ID.
//                                                                                           
//            ** LocalityID - UUID, Undefined - a locality ID.
//            ** TerritoryID - UUID, Undefined - a territory ID.
//            ** StreetID - UUID, Undefined - a street ID.
//        * ARCACodes           - Structure - ARCA codes if the ARCACodes parameter is set.
//           ** State          - String - an ARCA code of a state.
//           ** District           - String - an ARCA code of a district.
//           ** City           - String - an ARCA code of a city.
//           ** Locality - String - an ARCA code of a locality.
//           ** Street           - String - an ARCA code of a street.
//        * Additional codes - Structure - the following codes: RNCMT, RNCPS, IFTSICode, IFTSLECode, IFTSIAreaCode, and IFTSLEAreaCode.
//        * Comment - String - a comment to an address.
//
Function AddressFields() Export
	
	Result = New Structure;
	
	Result.Insert("AddressType"                 , "");
	Result.Insert("Comment"               , "");
	
	Result.Insert("Presentation"             , "");
	Result.Insert("MunicipalPresentation", "");
	
	Result.Insert("Country"   , "");
	Result.Insert("CountryCode", "");
	Result.Insert("IndexOf"   , "");
	
	Result.Insert("StateCode"                               , "");
	Result.Insert("State"                                   , "");
	Result.Insert("StateShortForm"                         , "");
	Result.Insert("County"                                    , "");
	Result.Insert("CountyShortForm"                          , "");
	Result.Insert("District"                                    , "");
	Result.Insert("DistrictShortForm"                          , "");
	Result.Insert("MunicipalDistrict"                       , "");
	Result.Insert("MunicipalDistrictShortForm"             , "");
	Result.Insert("City"                                    , "");
	Result.Insert("CityShortForm"                          , "");
	Result.Insert("Settlement"                                , "");
	Result.Insert("SettlementShortForm"                      , "");
	Result.Insert("CityDistrict"                     , "");
	Result.Insert("CityDistrictShortForm"           , "");
	Result.Insert("Locality"                          , "");
	Result.Insert("LocalityShortForm"                , "");
	Result.Insert("Territory"                               , "");
	Result.Insert("TerritoryShortForm"                     , "");
	Result.Insert("Street"                                    , "");
	Result.Insert("StreetShortForm"                          , "");
	Result.Insert("AdditionalTerritory"                 , "");
	Result.Insert("AdditionalTerritoryShortForm"       , "");
	Result.Insert("AdditionalTerritoryItem"          , "");
	Result.Insert("AdditionalTerritoryItemShortForm", "");
	
	Building = New Structure;
	Building.Insert("BuildingType", "");
	Building.Insert("Number"    , "");
	Result.Insert("Building", Building);
	
	Result.Insert("BuildingUnits"  , New Array);
	Result.Insert("Premises", New Array);
	
	Result.Insert("AddressObjectID", Undefined);
	Result.Insert("HouseID"            , Undefined);
	
	IDs = New Structure;
	IDs.Insert("StateID"              , Undefined);
	IDs.Insert("DistrictID"               , Undefined);
	IDs.Insert("MunicipalDistrictID"  , Undefined);
	IDs.Insert("CityID"               , Undefined);
	IDs.Insert("SettlementID"           , Undefined);
	IDs.Insert("CityDistrictID", Undefined);
	IDs.Insert("LocalityID"     , Undefined);
	IDs.Insert("TerritoryID"          , Undefined);
	IDs.Insert("StreetID"               , Undefined);
	Result.Insert("IDs", IDs);
	
	AdditionalCodes = New Structure;
	AdditionalCodes.Insert("RNCMT"           , "");
	AdditionalCodes.Insert("RNCPS"           , "");
	AdditionalCodes.Insert("IndividualFTSCode"       , "");
	AdditionalCodes.Insert("BusinessIFTSCode"       , "");
	AdditionalCodes.Insert("IndividualFTSAreaCode", "");
	AdditionalCodes.Insert("BusinessIFTSAreaCode", "");
	Result.Insert("AdditionalCodes", AdditionalCodes);
	
	ARCACodes = New Structure;
	ARCACodes.Insert("State"         , "");
	ARCACodes.Insert("District"          , "");
	ARCACodes.Insert("City"          , "");
	ARCACodes.Insert("Locality", "");
	ARCACodes.Insert("Street"          , "");
	Result.Insert("ARCACodes", ARCACodes);
	
	Return Result;
	
EndFunction

// Returns contact information structure by type.
// To get address fields, use AddressManagerClientServer.AddressFields.
//
// Parameters:
//  CIType - EnumRef.ContactInformationTypes	 - a contact information type.
//  AddressFormat - String - a type of structure being returned depending on the address format: ARCA or FIAS information.
// 
// Returns:
//  Structure - a blank contact information structure, keys - field names and field values.
//
Function ContactInformationStructureByType(CIType, AddressFormat = "ARCA") Export
	
	If CIType = PredefinedValue("Enum.ContactInformationTypes.Address") Then
		Return AddressFieldsStructure(AddressFormat);
	ElsIf CIType = PredefinedValue("Enum.ContactInformationTypes.Phone") Then
		Return ContactsManagerClientServer.PhoneFieldStructure();
	Else
		Return New Structure;
	EndIf;
	
EndFunction

#EndRegion

#Region Internal

Function MainCountry() Export
	Return PredefinedValue("Catalog.WorldCountries.EmptyRef");
EndFunction

// Returns an XPath for a district.
//
// Returns:
//      String - XPath
//
Function DistrictXPath() Export
	
	Return "MunicipalEntityDistrictProperty/District";
	
EndFunction

// Returns an array of structures containing information on address parts in accordance with the Order of FTS No. MMV-7-1/525 dated 08/31/2011.
//
// Returns:
//      Array - contains structures - details.
//
Function LocalAddressesAddressingObjectsTypes() Export
	
	Result = New Array;
	
	// Code, Description, Type, Order, and FIASCode
	// Type: 1 - household, 2 - building, 3 - premise.
	
	Result.Add(AddressingObjectString("1010", NStr("ru = 'Дом'; en = 'House'; pl = 'Dom';es_ES = 'Casa';es_CO = 'Casa';tr = 'Bina';it = 'Abitazione';de = 'Haus'"),          1, 1, 2));
	Result.Add(AddressingObjectString("1020", NStr("ru = 'Владение'; en = 'Ownership'; pl = 'Własność';es_ES = 'Propiedad';es_CO = 'Propiedad';tr = 'Sahiplik';it = 'Proprietà';de = 'Eigentumsverhältnisse'"),     1, 2, 1));
	Result.Add(AddressingObjectString("1030", NStr("ru = 'Домовладение'; en = 'Home-ownership'; pl = 'Własność dom';es_ES = 'Propiedad de la casa';es_CO = 'Propiedad de la casa';tr = 'Özel mülk';it = 'Proprietà della casa';de = 'Wohnungseigentum'"), 1, 3, 3));
	
	Result.Add(AddressingObjectString("1050", NStr("ru = 'Корпус'; en = 'BuildingUnit'; pl = 'BuildingUnit';es_ES = 'BuildingUnit';es_CO = 'BuildingUnit';tr = 'BuildingUnit';it = 'Blocco';de = 'BuildingUnit'"),     2, 1));
	Result.Add(AddressingObjectString("1060", NStr("ru = 'Строение'; en = 'Building'; pl = 'Budynek';es_ES = 'Edificio';es_CO = 'Edificio';tr = 'Bina';it = 'Costruzione';de = 'Gebäude'"),   2, 2, 1));
	Result.Add(AddressingObjectString("1080", NStr("ru = 'Литера'; en = 'Letter'; pl = 'Litera';es_ES = 'Carta';es_CO = 'Carta';tr = 'Yazı';it = 'Lettera';de = 'Brief'"),     2, 3, 3));
	Result.Add(AddressingObjectString("1090", NStr("ru = 'Литера'; en = 'Letter'; pl = 'Litera';es_ES = 'Carta';es_CO = 'Carta';tr = 'Yazı';it = 'Lettera';de = 'Brief'"),      2, 6, 3));
	Result.Add(AddressingObjectString("1070", NStr("ru = 'Сооружение'; en = 'Facility'; pl = 'Obiekt';es_ES = 'Facilidad';es_CO = 'Facilidad';tr = 'Tesis';it = 'Struttura';de = 'Einrichtung'"), 2, 4, 2));
	Result.Add(AddressingObjectString("1040", NStr("ru = 'Участок'; en = 'Lot'; pl = 'Ilość';es_ES = 'Lote';es_CO = 'Lote';tr = 'Lot';it = 'Lotto';de = 'Grundstück'"),    2, 5));
	
	Result.Add(AddressingObjectString("2010", NStr("ru = 'Квартира'; en = 'Apartment'; pl = 'Mieszkanie';es_ES = 'Apartamento';es_CO = 'Apartamento';tr = 'Daire';it = 'Appartamento';de = 'Wohnung'"),  3, 1));
	Result.Add(AddressingObjectString("2030", NStr("ru = 'Офис'; en = 'Office'; pl = 'Biuro';es_ES = 'Oficina';es_CO = 'Oficina';tr = 'Ofis';it = 'Ufficio';de = 'Büro'"),      3, 2));
	Result.Add(AddressingObjectString("2040", NStr("ru = 'Бокс'; en = 'Box'; pl = 'Skrzynka';es_ES = 'Caja';es_CO = 'Caja';tr = 'Kutu';it = 'Box';de = 'Kasten'"),      3, 3));
	Result.Add(AddressingObjectString("2020", NStr("ru = 'Помещение'; en = 'Premise'; pl = 'Lokal';es_ES = 'Local';es_CO = 'Local';tr = 'Mekan';it = 'Edificio';de = 'Raum'"), 3, 4));
	Result.Add(AddressingObjectString("2050", NStr("ru = 'Комната'; en = 'Room'; pl = 'Pokój';es_ES = 'Habitación';es_CO = 'Habitación';tr = 'Oda';it = 'Stanza';de = 'Zimmer'"),   3, 5));
	Result.Add(AddressingObjectString("2060", NStr("ru = 'Этаж'; en = 'Floor'; pl = 'Piętro';es_ES = 'Piso';es_CO = 'Piso';tr = 'Kat';it = 'Piano';de = 'Stockwerk'"),      3, 6));
	Result.Add(AddressingObjectString("2070", NStr("ru = 'А/я'; en = 'P.o. box'; pl = 'Skrytka pocztowa';es_ES = 'P.o. caja';es_CO = 'P.o. caja';tr = 'Posta kutusu';it = 'Casella postale';de = 'Postfach'"),       3, 7));
	Result.Add(AddressingObjectString("2080", NStr("ru = 'В/ч'; en = 'Military unit'; pl = 'Jednostka wojskowa';es_ES = 'Unidad militar';es_CO = 'Unidad militar';tr = 'Askeri birim';it = 'Unità militare';de = 'Militäreinheit'"),       3, 8));
	Result.Add(AddressingObjectString("2090", NStr("ru = 'П/о'; en = 'PO'; pl = 'PO';es_ES = 'PO';es_CO = 'PO';tr = 'PO';it = 'PO';de = 'PO'"),       3, 9));
	//  Short forms required for backward compatibility of parsing.
	Result.Add(AddressingObjectString("2010", NStr("ru = 'кв.'; en = 'Apt.'; pl = 'Apart.';es_ES = 'Apart.';es_CO = 'Apart.';tr = 'Apartman';it = 'App.';de = 'Apt.'"),       3, 6));
	Result.Add(AddressingObjectString("2030", NStr("ru = 'оф.'; en = 'off.'; pl = 'b.';es_ES = 'ofic.';es_CO = 'ofic.';tr = 'ofis';it = 'uff.';de = 'Büro'"),       3, 7));
	// Premise to be entered manually.
	Result.Add(AddressingObjectString("2000", "", 3, 0));
	
	// Clarifying objects
	Result.Add(AddressingObjectString("10100000", NStr("ru = 'Почтовый индекс'; en = 'Zip code'; pl = 'Kod pocztowy';es_ES = 'Código zip';es_CO = 'Código zip';tr = 'Posta kodu';it = 'Codice Postale';de = 'Postleitzahl'")));
	Result.Add(AddressingObjectString("10200000", NStr("ru = 'Адресная точка'; en = 'Address point'; pl = 'Punkt adresowy';es_ES = 'Punto de dirección';es_CO = 'Punto de dirección';tr = 'Adres noktası';it = 'Indirizzo del punto';de = 'Adresspunkt'")));
	Result.Add(AddressingObjectString("10300000", NStr("ru = 'Садовое товарищество'; en = 'Gardeners'' partnership'; pl = 'Ogródki działkowe';es_ES = 'Colaboración con jardineros';es_CO = 'Colaboración con jardineros';tr = 'Bahçıvanlar ortaklığı';it = 'Collaborazione Giardinieri';de = 'Gartengemeinschaft'")));
	Result.Add(AddressingObjectString("10400000", NStr("ru = 'Элемент улично-дорожной сети, планировочной структуры дополнительного адресного элемента'; en = 'Item of street-road network, planning structure of additional address element'; pl = 'Element sieci drogowo-ulicznej, struktura planowa dodatkowego elementu adresu';es_ES = 'Artículo de la red de carretera-calle, estructura de planificación del elemento de dirección adicional';es_CO = 'Artículo de la red de carretera-calle, estructura de planificación del elemento de dirección adicional';tr = 'Sokak yol ağı unsuru, ek adres elemanının planlama yapısı';it = 'Elemento della rete stradale/via, ulteriore elemento di pianificazione che fa parte dell''indirizzo';de = 'Gegenstand des Straßennetzes, Planungsstruktur des zusätzlichen Adresselements'")));
	Result.Add(AddressingObjectString("10500000", NStr("ru = 'Промышленная зона'; en = 'Industrial area'; pl = 'Tereny przemysłowe';es_ES = 'Zona industrial';es_CO = 'Zona industrial';tr = 'Sanayi alan';it = 'Area industriale';de = 'Industriegebiet'")));
	Result.Add(AddressingObjectString("10600000", NStr("ru = 'Гаражно-строительный кооператив'; en = 'Garage construction co-operative'; pl = 'Spółdzielnia garażowa';es_ES = 'Cooperativa de construcción de garajes';es_CO = 'Cooperativa de construcción de garajes';tr = 'Garaj inşaat kooperatifi';it = 'Società di costruzione cooperativa';de = 'Garagenbau Genossenschaft'")));
	Result.Add(AddressingObjectString("10700000", NStr("ru = 'Территория'; en = 'Territory'; pl = 'Terytorium';es_ES = 'Teritorio';es_CO = 'Teritorio';tr = 'Bölge';it = 'Territorio';de = 'Territorium'")));
	
	Return Result;
EndFunction

Function IsMunicipalAddress(AddressType) Export
	Return StrCompare(AddressType, MunicipalAddress()) = 0;
EndFunction

Function IsAdministrativeAndTerritorialAddress(AddressType) Export
	Return StrCompare(AddressType, AdministrativeAndTerritorialAddress()) = 0;
EndFunction

Function IsMainCountry(Country) Export
	Return StrCompare(MainCountry(), Country) = 0;
EndFunction

Function AdministrativeAndTerritorialAddress() Export
	Return "Administrative-territorial";
EndFunction

Function MunicipalAddress() Export
	Return "Municipal";
EndFunction

#EndRegion

#Region Private

// Details of contacts structure for storing it in the JSON format.
// Fields list can be extended by national fields in the homonymous function of the AddressManagerClientServer module.
//
// Parameters:
//    ContactInformationType - EnumRef.ContactInformationTypes -
//                               The type of contacts that determines the components of contacts fields.
//
// Returns:
//   Structure - contacts fields with the fields:
//     * Value - String - presentation of contacts.
//     * Comment - String - a comment.
//     * Type - String - a contacts type.
//     For the type of contacts address:
//     * Type - String - a contacts type.
//     * Country - String - country description.
//     * CountryCode - String - a country code.
//     * ZIPcoce - String - a zip code.
//     * Area - String - state presentation
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
		
		Result.Insert("AddressType",	AddressInFreeForm());
		Result.Insert("AddressLine1",	"");
		Result.Insert("AddressLine2",	"");
		Result.Insert("City",			"");
		Result.Insert("State",			"");
		Result.Insert("PostalCode",		"");
		Result.Insert("Country",		"");
		Result.Insert("CountryCode",	"");
		Result.Insert("ID",				"");
		
	ElsIf ContactInformationType = PredefinedValue("Enum.ContactInformationTypes.Phone")
		Or ContactInformationType = PredefinedValue("Enum.ContactInformationTypes.Fax") Then
		
		Result.Insert("CountryCode", "");
		Result.Insert("AreaCode", "");
		Result.Insert("Number", "");
		Result.Insert("ExtNumber", "");
		
	EndIf;
	
	Return Result;
	
EndFunction

// Returns a code of an additional address part for serialization.
//
//  Parameters:
//      ValueString - String - a search value, for example, House, Building unit, or Letter).
//
// Returns:
//      Number - a code
// 
Function AddressingObjectSerializationCode(ValueRow) Export
	
	varKey = Upper(TrimAll(ValueRow));
	For Each Item In LocalAddressesAddressingObjectsTypes() Do
		If Item.Key = varKey Then
			Return Item.Code;
		EndIf;
	EndDo;
	
	Return Undefined;
EndFunction

// Returns a code of an additional address part for a zip code.
//
// Returns:
//      String - a code
//
Function ZipCodeSerializationCode() Export
	
	Return AddressingObjectSerializationCode(NStr("ru = 'Почтовый индекс'; en = 'Zip code'; pl = 'Kod pocztowy';es_ES = 'Código zip';es_CO = 'Código zip';tr = 'Posta kodu';it = 'Codice Postale';de = 'Postleitzahl'"));
	
EndFunction

// Returns XPath for a zip code.
//
// Returns:
//      String - XPath
//
Function ZipCodeXPath() Export
	
	Return "AdditionalAddressItem[AddressItemType='" + ZipCodeSerializationCode() + "']";
	
EndFunction

Function AdditionalAddressingObjectSerializationCode(Level, AddressItemType = "")
	
	If Level = 90 Then
		If Upper(AddressItemType) = "GCC" Then
			Return "10600000";
		ElsIf Upper(AddressItemType) = "HS" Then
			Return "10300000";
		ElsIf Upper(AddressItemType) = "TER" Then
			Return "10700000";
		Else
			Return "10200000";
		EndIf;
	ElsIf Level = 91 Then
		Return "10400000";
	EndIf;
	
	// Considering everything else as  a landmark.
	Return "Location";
EndFunction

// Returns XPath for the default additional addressing object.
//
//  Parameters.
//      Level - Number - an object level. 90 - additional(Options: GCC, HS, and TER), 91 - subordinate, -1 -
//                        a landmark.
//
// Returns:
//      String - XPath
//
Function AdditionalAddressingObject(Level, AddressItemType = "") Export
	SerializationCode = AdditionalAddressingObjectSerializationCode(Level, AddressItemType);
	Return "AdditionalAddressItem[AddressItemType='" + SerializationCode + "']";
EndFunction

// Returns XPath for an additional addressing object number.
//
//  Parameters.
//      ValueString - String - a type being searched, for example, House or Building unit.
//
// Returns:
//      String - XPath
//
Function AdditionalAddressingObjectNumberXPath(ValueRow) Export
	
	Code = AddressingObjectSerializationCode(ValueRow);
	If Code = Undefined Then
		Code = StrReplace(ValueRow, "'", "");
	EndIf;
	
	Return "AdditionalAddressItem/Number[Type='" + Code + "']";
EndFunction

// Returns a string with type details by an address part code.
//  The opposite of the AddressingObjectSerializationCode function.
//
// Parameters:
//      Code - String - a code
//
// Returns:
//      Number - Type
//
Function ObjectTypeBySerializationCode(Code) Export
	For Each Item In LocalAddressesAddressingObjectsTypes() Do
		If Item.Code = Code Then
			Return Item;
		EndIf;
	EndDo;
	
	Return Undefined;
EndFunction

// Returns an array of description options by type (by the flag of a household, construction, and so on).
//
// Parameters:
//      Type                 - Number - a type being requested.
//      AllowCodeDuplicates - Boolean - True - all options with duplicates are returned (apartment - apt, and so on).
//
// Returns:
//      Array - contains structures - details.
//
Function AddressingObjectsDescriptionsByType(Type, AllowCodeDuplicates = True) Export
	Result = New Array;
	Duplicates   = New Map;
	
	For Each Item In LocalAddressesAddressingObjectsTypes() Do
		If Item.Type = Type Then
			If AllowCodeDuplicates Then
				Result.Add(Item.Description);
			Else
				If Duplicates.Get(Item.Code) = Undefined Then
					Result.Add(Item.Description);
				EndIf;
				Duplicates.Insert(Item.Code, True);
			EndIf;
		EndIf;
	EndDo;
	
	Return Result;
EndFunction    

// Returns short forms of address parts.
//
// Returns:
//      Map - a list of short forms.
//
Function ShortFormsOfRFAddressAddressingObjects() Export
	
	Result = New Map;
	
	Result.Insert(NStr("ru = 'Дом'; en = 'House'; pl = 'Dom';es_ES = 'Casa';es_CO = 'Casa';tr = 'Bina';it = 'Abitazione';de = 'Haus'"), NStr("ru = 'Д.'; en = 'HSE'; pl = 'HSE';es_ES = 'HSE';es_CO = 'HSE';tr = 'HSE';it = 'HSE';de = 'HSE'"));
	Result.Insert(NStr("ru = 'Владение'; en = 'Ownership'; pl = 'Własność';es_ES = 'Propiedad';es_CO = 'Propiedad';tr = 'Sahiplik';it = 'Proprietà';de = 'Eigentumsverhältnisse'"), NStr("ru = 'Владение'; en = 'Ownership'; pl = 'Własność';es_ES = 'Propiedad';es_CO = 'Propiedad';tr = 'Sahiplik';it = 'Proprietà';de = 'Eigentumsverhältnisse'"));
	Result.Insert(NStr("ru = 'Домовладение'; en = 'Home-ownership'; pl = 'Własność dom';es_ES = 'Propiedad de la casa';es_CO = 'Propiedad de la casa';tr = 'Özel mülk';it = 'Proprietà della casa';de = 'Wohnungseigentum'"), NStr("ru = 'Домовладение'; en = 'Home-ownership'; pl = 'Własność dom';es_ES = 'Propiedad de la casa';es_CO = 'Propiedad de la casa';tr = 'Özel mülk';it = 'Proprietà della casa';de = 'Wohnungseigentum'"));
	
	Result.Insert(NStr("ru = 'Корпус'; en = 'BuildingUnit'; pl = 'BuildingUnit';es_ES = 'BuildingUnit';es_CO = 'BuildingUnit';tr = 'BuildingUnit';it = 'Blocco';de = 'BuildingUnit'"), NStr("ru = 'Корп.'; en = 'Build.'; pl = 'Bud.';es_ES = 'Edificio.';es_CO = 'Edificio.';tr = 'Bina';it = 'Edif.';de = 'Gebäude'"));
	Result.Insert(NStr("ru = 'Строение'; en = 'Building'; pl = 'Budynek';es_ES = 'Edificio';es_CO = 'Edificio';tr = 'Bina';it = 'Costruzione';de = 'Gebäude'"), NStr("ru = 'Стр.'; en = 'Const.'; pl = 'Budowa';es_ES = 'Const.';es_CO = 'Const.';tr = 'İnş.';it = 'Costr.';de = 'Const.'"));
	Result.Insert(NStr("ru = 'Литера'; en = 'Letter'; pl = 'Litera';es_ES = 'Carta';es_CO = 'Carta';tr = 'Yazı';it = 'Lettera';de = 'Brief'"), NStr("ru = 'Литера'; en = 'Letter'; pl = 'Litera';es_ES = 'Carta';es_CO = 'Carta';tr = 'Yazı';it = 'Lettera';de = 'Brief'"));
	Result.Insert(NStr("ru = 'Сооружение'; en = 'Facility'; pl = 'Obiekt';es_ES = 'Facilidad';es_CO = 'Facilidad';tr = 'Tesis';it = 'Struttura';de = 'Einrichtung'"), NStr("ru = 'Сооруж.'; en = 'Facil.'; pl = 'Obiekt';es_ES = 'Facil.';es_CO = 'Facil.';tr = 'Tesis';it = 'Strutt.';de = 'Einrichtung'"));
	Result.Insert(NStr("ru = 'Участок'; en = 'Lot'; pl = 'Ilość';es_ES = 'Lote';es_CO = 'Lote';tr = 'Lot';it = 'Lotto';de = 'Grundstück'"), NStr("ru = 'Уч.'; en = 'Land'; pl = 'Kraj';es_ES = 'Tierra';es_CO = 'Tierra';tr = 'Arazi';it = 'Terreno';de = 'Land'"));
	
	Result.Insert(NStr("ru = 'Квартира'; en = 'Apartment'; pl = 'Nr lokalu';es_ES = 'Apartamento';es_CO = 'Apartamento';tr = 'Daire';it = 'Appartamento';de = 'Wohnung'"), NStr("ru = 'Кв.'; en = 'Apt.'; pl = 'Apart.';es_ES = 'Apart.';es_CO = 'Apart.';tr = 'Apartman';it = 'App.';de = 'Apt.'"));
	Result.Insert(NStr("ru = 'Офис'; en = 'Office'; pl = 'Biuro';es_ES = 'Oficina';es_CO = 'Oficina';tr = 'Ofis';it = 'Ufficio';de = 'Büro'"), NStr("ru = 'Оф.'; en = 'Off.'; pl = 'B.';es_ES = 'Ofic.';es_CO = 'Ofic.';tr = 'Ofis';it = 'Uff.';de = 'Büro'"));
	Result.Insert(NStr("ru = 'Бокс'; en = 'Box'; pl = 'Skrzynka';es_ES = 'Caja';es_CO = 'Caja';tr = 'Kutu';it = 'Box';de = 'Kasten'"), NStr("ru = 'Бокс'; en = 'Box'; pl = 'Skrzynka';es_ES = 'Caja';es_CO = 'Caja';tr = 'Kutu';it = 'Box';de = 'Kasten'"));
	Result.Insert(NStr("ru = 'Помещение'; en = 'Premise'; pl = 'Lokal';es_ES = 'Local';es_CO = 'Local';tr = 'Mekan';it = 'Edificio';de = 'Raum'"), NStr("ru = 'Пом.'; en = 'Wareroom'; pl = 'Magazyn';es_ES = 'Wareroom';es_CO = 'Wareroom';tr = 'Depo';it = 'Magazzino';de = 'Lagerraum'"));
	Result.Insert(NStr("ru = 'Комната'; en = 'Room'; pl = 'Pokój';es_ES = 'Habitación';es_CO = 'Habitación';tr = 'Oda';it = 'Stanza';de = 'Zimmer'"), NStr("ru = 'Комната'; en = 'Room'; pl = 'Pokój';es_ES = 'Habitación';es_CO = 'Habitación';tr = 'Oda';it = 'Stanza';de = 'Zimmer'"));
	Result.Insert(NStr("ru = 'Этаж'; en = 'Floor'; pl = 'Piętro';es_ES = 'Piso';es_CO = 'Piso';tr = 'Kat';it = 'Piano';de = 'Stockwerk'"), NStr("ru = 'Этаж'; en = 'Floor'; pl = 'Piętro';es_ES = 'Piso';es_CO = 'Piso';tr = 'Kat';it = 'Piano';de = 'Stockwerk'"));
	Result.Insert(NStr("ru = 'А/я'; en = 'P.o. box'; pl = 'Skrytka pocztowa';es_ES = 'P.o. caja';es_CO = 'P.o. caja';tr = 'Posta kutusu';it = 'Casella postale';de = 'Postfach'"), NStr("ru = 'а/я'; en = 'p.o. box'; pl = 'Skrytka pocztowa';es_ES = 'p.o. caja';es_CO = 'p.o. caja';tr = 'posta kutusu';it = 'casella postale';de = 'postfach'"));
	Result.Insert(NStr("ru = 'П/о'; en = 'PO'; pl = 'PO';es_ES = 'PO';es_CO = 'PO';tr = 'PO';it = 'PO';de = 'PO'"), NStr("ru = 'п/о'; en = 'po'; pl = 'po';es_ES = 'po';es_CO = 'po';tr = 'po';it = 'po';de = 'po'"));
	Result.Insert(NStr("ru = 'В/ч'; en = 'Military unit'; pl = 'Jednostka wojskowa';es_ES = 'Unidad militar';es_CO = 'Unidad militar';tr = 'Askeri birim';it = 'Unità militare';de = 'Militäreinheit'"), NStr("ru = 'в/ч'; en = 'military unit'; pl = 'jednostka wojskowa';es_ES = 'unidad militar';es_CO = 'unidad militar';tr = 'askeri birim';it = 'unità militare';de = 'militäreinheit'"));
	
	Return Result;
EndFunction

Function AddressingObjectString(Code, Description, Type = 0, Order = 0, FIASCode = 0)
	
	AddressingObjectStructure = New Structure;
	AddressingObjectStructure.Insert("Code", Code);
	AddressingObjectStructure.Insert("Description", Description);
	AddressingObjectStructure.Insert("Type", Type);
	AddressingObjectStructure.Insert("Order", Order);
	AddressingObjectStructure.Insert("FIASCode", FIASCode);
	AddressingObjectStructure.Insert("ShortForm", Lower(Description));
	AddressingObjectStructure.Insert("Key", Upper(Description));
	Return AddressingObjectStructure;
	
EndFunction

Function AddressLevelAndDescriptionMap(AddressType, IncludeStreet)
	Levels = New Map;
	
	Levels.Insert(1, "Area");
	If IsMunicipalAddress(AddressType) Then
		Levels.Insert(31, "MunDistrict");
		Levels.Insert(41, "Settlement");
	Else
		Levels.Insert(3, "District");
		Levels.Insert(4, "City");
	EndIf;
	
	Levels.Insert(5, "CityDistrict");
	Levels.Insert(6, "Locality");
	Levels.Insert(65, "Territory");
	
	If IncludeStreet Then
		Levels.Insert(7, "Street");
	EndIf;
	
	Return Levels;
EndFunction

Function DescriptionAndAddressLevelMap(LevelName) Export
	Levels = New Map;
	
	Levels.Insert("Area", 1);
	Levels.Insert("MunDistrict", 31);
	Levels.Insert("Settlement", 41);
	Levels.Insert("District", 3);
	Levels.Insert("City", 4);
	Levels.Insert("CityDistrict", 5);
	Levels.Insert("Locality", 6);
	Levels.Insert("Territory", 65);
	Levels.Insert("Street", 7);
	
	Return Levels[LevelName];
EndFunction

Function AddressLevelsNames(AddressType, IncludeStreet) Export
	Levels = New Array;
	
	If AddressType = ContactsManagerClientServer.ForeignAddress() Then
		
		Levels.Add("City");
		
	Else
		
		Levels.Add("Area");
		If AddressType = ContactsManagerClientServer.EEUAddress() Then
			
			Levels.Add("District");
			Levels.Add("City");
			Levels.Add("Locality");
			
		Else
			
			If AddressType = "All" Then
				Levels.Add("District");
				Levels.Add("City");
				Levels.Add("MunDistrict");
				Levels.Add("Settlement");
			Else
				If IsMunicipalAddress(AddressType) Then
					Levels.Add("MunDistrict");
					Levels.Add("Settlement");
				Else
					Levels.Add("District");
					Levels.Add("City");
				EndIf;
			EndIf;
			
			Levels.Add("CityDistrict");
			Levels.Add("Locality");
			Levels.Add("Territory");
			
		EndIf;
		
	EndIf;
	
	If IncludeStreet Then
			Levels.Add("Street");
		EndIf;
	Return Levels;
	
EndFunction

Function LevelPresentationNoShortForm(LevelName) Export
	
	If StrCompare(LevelName, "MunDistrict") = 0 Or StrCompare(LevelName, "Settlement") = 0 Then
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

Function AdsressID(Address, IncludeStreet) Export
	
	AdsressID = Undefined;
	MaxLevel = 0;
	Levels = AddressLevelAndDescriptionMap(Address.AddressType, IncludeStreet);
	
	For each Level In Levels Do
		LevelKey = ?(Level.Key < 10, Level.Key * 10, Level.Key);
		If LevelKey > MaxLevel
			AND Address.Property(Level.Value + "Id")
			AND ValueIsFilled(Address[Level.Value + "Id"]) Then
				AdsressID = Address[Level.Value + "Id"];
				MaxLevel = LevelKey;
		EndIf;
		
	EndDo;
	
	Return AdsressID;
	
EndFunction

// Converts entered English letters to the Russian layout upon selecting an address
//
Procedure ConvertAdressInput(Text) Export
	RussianKeys = "ЙЦУКЕНГШЩЗХЪФЫВАПРОЛДЖЭЯЧСМИТЬБЮЁ";
	EnglishKeys = "QWERTYUIOP[]ASDFGHJKL;'ZXCVBNM,.`";
	Text = Upper(Text);
	For Position = 0 To StrLen(Text) Do
		Char = Mid(Text, Position, 1);
		CharPosition = StrFind(EnglishKeys, Char);
		If CharPosition > 0 Then
			Text = StrReplace(Text, Char, Mid(RussianKeys, CharPosition, 1));
		EndIf;
	EndDo;
	
EndProcedure

Function LocalityAddressPresentation(Address) Export
	
	FilledLevelsList = New Array;
	
	For each LevelName In AddressLevelsNames(Address.AddressType, False) Do
		
		If ValueIsFilled(Address[LevelName]) Then
			If NOT LevelPresentationNoShortForm(LevelName) Then
				FilledLevelsList.Add(Address[LevelName] + " " + Address[LevelName + "Type"]);
			Else
				FilledLevelsList.Add(Address[LevelName]);
			EndIf;
		EndIf;
	EndDo;
	
	Return StrConcat(FilledLevelsList, ", ");
	
EndFunction

Procedure UpdateAddressPresentation(Address, IncludeCountryInPresentation) Export
	
	If TypeOf(Address) <> Type("Structure") Then
		Raise NStr("ru='Для формирования представления адреса передан некорректный тип адреса'; en = 'Incorrect address type was passed to generate address representation'; pl = 'Do tworzenia prezentacji adresu został przekazany nieprawidłowy rodzaj adresu';es_ES = 'Para generar la presentación de la dirección ha sido enviado un tipo incorrecto de la dirección';es_CO = 'Para generar la presentación de la dirección ha sido enviado un tipo incorrecto de la dirección';tr = 'Bir adres görünümü oluşturmak için yanlış adres türü iletildi';it = 'Un tipo di indirizzo non corretto è stato passato per generare il riepilogo dell''indirizzo';de = 'Es wurde ein falscher Adresstyp übergeben, um eine Adressendarstellung zu generieren'");
	EndIf;
	
	FilledLevelsList = New Array;
	
	If Address.Property("AddressLine1") AND NOT IsBlankString(Address.AddressLine1) Then
		FilledLevelsList.Add(Address.AddressLine1);
	EndIf;
	
	If Address.Property("AddressLine2") AND NOT IsBlankString(Address.AddressLine2) Then
		FilledLevelsList.Add(Address.AddressLine2);
	EndIf;
	
	If Address.Property("City") AND NOT IsBlankString(Address.City) Then
		FilledLevelsList.Add(Address.City);
	EndIf;
	
	If Address.Property("State") AND NOT IsBlankString(Address.State) Then
		FilledLevelsList.Add(Address.State);
	EndIf;
	
	If Address.Property("PostalCode") AND NOT IsBlankString(Address.PostalCode) Then
		FilledLevelsList.Add(Address.PostalCode);
	EndIf;
	
	If IncludeCountryInPresentation AND Address.Property("Country") AND NOT IsBlankString(Address.Country) Then
		FilledLevelsList.Add(Address.Country);
	EndIf;
	
	Address.Value = StrConcat(FilledLevelsList, ", ");
	
EndProcedure

Function AddressPresentation(Address, IncludeCountryInPresentation, AddressType = Undefined) Export
	
	If TypeOf(Address) <> Type("Structure") Then
		Raise NStr("ru='Для формирования представления адреса передан некорректный тип адреса'; en = 'Incorrect address type was passed to generate address representation'; pl = 'Do tworzenia prezentacji adresu został przekazany nieprawidłowy rodzaj adresu';es_ES = 'Para generar la presentación de la dirección ha sido enviado un tipo incorrecto de la dirección';es_CO = 'Para generar la presentación de la dirección ha sido enviado un tipo incorrecto de la dirección';tr = 'Bir adres görünümü oluşturmak için yanlış adres türü iletildi';it = 'Un tipo di indirizzo non corretto è stato passato per generare il riepilogo dell''indirizzo';de = 'Es wurde ein falscher Adresstyp übergeben, um eine Adressendarstellung zu generieren'");
	EndIf;
	
	If AddressType = Undefined Then
		AddressType = Address.AddressType;
	EndIf;
	
	If ContactsManagerClientServer.IsAddressInFreeForm(AddressType) Then
		
		If Not Address.Property("Country") Or IsBlankString(Address.Country) Then
			Return Address.Value;
		EndIf;
		
		PresentationHasCountry = StrStartsWith(Upper(Address.Value), Upper(Address.Country));
		If IncludeCountryInPresentation Then
			If Not PresentationHasCountry Then
				Return Address.Country + ", " + Address.Value;
			EndIf;
		Else
			If PresentationHasCountry AND StrFind(Address.Value, ",") > 0 Then
				FieldsList = StrSplit(Address.Value, ",");
				FieldsList.Delete(0);
				Return StrConcat(FieldsList, ",");
			EndIf;
		EndIf;
		
		Return Address.Value;
		
	EndIf;
	
	If ContactsManagerClientServer.IsAddressInFreeForm(AddressType) Then
		Return AddressPresentationInFreeForm(Address, IncludeCountryInPresentation);
	EndIf;
	
	FilledLevelsList = New Array;
	
	CountryDescription = "";
	If IncludeCountryInPresentation AND Address.Property("Country") AND NOT IsBlankString(Address.Country) Then
		FilledLevelsList.Add(Address.Country);
		CountryDescription = Address.Country;
	EndIf;
	
	If Address.Property("ZipCode") AND NOT IsBlankString(Address.ZipCode) Then
		FilledLevelsList.Add(Address.ZipCode);
	EndIf;
	
	For each LevelName In AddressLevelsNames(AddressType, True) Do
		
		If Address.Property(LevelName) AND NOT IsBlankString(Address[LevelName]) Then
			If NOT LevelPresentationNoShortForm(LevelName) Then
				FilledLevelsList.Add(TrimAll(Address[LevelName] + " " + Address[LevelName + "Type"]));
			Else
				FilledLevelsList.Add(Address[LevelName]);
			EndIf;
		EndIf;
		
	EndDo;
	
	If Address.Property("HouseNumber") AND NOT IsBlankString(Address.HouseNumber) Then
		FilledLevelsList.Add(Lower(Address.HouseType) + " № " + Address.HouseNumber);
	EndIf;
	
	If Address.Property("Buildings") AND Address.Buildings.Count() > 0 Then
		
		For each Building In Address.Buildings Do
			FilledLevelsList.Add(Lower(Building.Type) + " " + Building.Number);
		EndDo;
		
	EndIf;
	
	If Address.Property("Apartments")
		AND Address.Apartments <> Undefined
		AND Address.Apartments.Count() > 0 Then
		
		For each Building In Address.Apartments Do
			If StrCompare(Building.Type, "Other") <> 0 Then
				FilledLevelsList.Add(Lower(Building.Type) + " " + Building.Number);
			Else
				FilledLevelsList.Add(Building.Number);
			EndIf;
		EndDo;
		
	EndIf;
	
	Presentation = StrConcat(FilledLevelsList, ", ");
	
	Return Presentation;
	
EndFunction

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
	Return NStr("ru='ВСвободнойФорме'; en = 'FreeForm'; pl = 'FreeForm';es_ES = 'FreeForm';es_CO = 'FreeForm';tr = 'FreeForm';it = 'FreeForm';de = 'FreeForm'");
EndFunction

#Region OtherInternalProceduresAndFunctions

Function AddressPresentationInFreeForm(Val Address, Val IncludeCountryInPresentation)
	
	If IncludeCountryInPresentation AND Address.Property("Country") AND NOT IsBlankString(Address.Country) Then
		AddressParts = StrSplit(Address.Value, ",");
		If ValueIsFilled(Address.Value) AND StrCompare(AddressParts[0], Address.Country) = 0 Then
			AddressParts.Delete(0);
			Address.Value = StrConcat(AddressParts, ",");
		EndIf;
		
	EndIf;
	
	Return Address.Value;
	
EndFunction

Function SelectionResultConstructor() Export
	
	Result = New Structure();
	Result.Insert("StateImported",                   Undefined);
	Result.Insert("ID",                    "");
	Result.Insert("Presentation",                    "");
	Result.Insert("BriefErrorPresentation",       "");
	Result.Insert("Cancel",                            False);
	Result.Insert("Level",                          0);
	Result.Insert("Municipal",                    Undefined);
	Result.Insert("PromptToImportClassifier", False);
	Return Result;

EndFunction

// Returns a blank address structure.
//
// Returns:
//    Structure - address, keys - field names and field values.
//
Function AddressFieldsStructure(AddressFormat)
	
	AddressStructure = New Structure;
	AddressStructure.Insert("Presentation", "");
	AddressStructure.Insert("Country", "");
	AddressStructure.Insert("CountryDescription", "");
	AddressStructure.Insert("CountryCode","");
	AddressStructure.Insert("IndexOf","");
	AddressStructure.Insert("State","");
	AddressStructure.Insert("StateShortForm","");
	AddressStructure.Insert("District","");
	AddressStructure.Insert("DistrictShortForm","");
	AddressStructure.Insert("City","");
	AddressStructure.Insert("CityShortForm","");
	AddressStructure.Insert("Locality","");
	AddressStructure.Insert("LocalityShortForm","");
	AddressStructure.Insert("Street","");
	AddressStructure.Insert("StreetShortForm","");
	AddressStructure.Insert("House","");
	AddressStructure.Insert("BuildingUnit","");
	AddressStructure.Insert("Apartment","");
	AddressStructure.Insert("HOUSETYPE","");
	AddressStructure.Insert("BuildingUnitType","");
	AddressStructure.Insert("ApartmentType","");
	AddressStructure.Insert("KindDescription","");
	
	If Upper(AddressFormat) = "FIAS" Then
		AddressStructure.Insert("County","");
		AddressStructure.Insert("CountyShortForm","");
		AddressStructure.Insert("CityDistrict","");
		AddressStructure.Insert("CityDistrictShortForm","");
	EndIf;
	
	Return AddressStructure;
	
EndFunction

// Returns a string of the fields list.
//
// Parameters:
//    FieldsMap - ValueList - fields maps.
//    WithoutBlankFields    - Boolean - an optional flag for saving fields with blank values.
//
//  Returns:
//     String - a result converted from a list.
//
Function ConvertFieldsListToString(FieldsMap, WithoutBlankFields = True) Export
	
	ApartmentAdded = False;
	BuildingUnitAdded = False;
	PreviousValue = Undefined;
	
	FieldsValuesStructure = New Structure;
	For Each Item In FieldsMap Do
		
		If Item.Presentation = "BuildingUnit" OR Item.Presentation = "BuildingUnitType" Then
			If PreviousValue <> Undefined AND PreviousValue.Presentation = "BuildingUnitType"
				AND PreviousValue.Value = "BuildingUnit" Then
				FieldsValuesStructure.Insert(Item.Presentation, Item.Value);
				BuildingUnitAdded = True;
			ElsIf NOT BuildingUnitAdded Then
				FieldsValuesStructure.Insert(Item.Presentation, Item.Value);
			EndIf;
		ElsIf Item.Presentation = "Apartment" OR Item.Presentation = "ApartmentType" Then
			If PreviousValue <> Undefined AND PreviousValue.Presentation = "ApartmentType"
				AND PreviousValue.Value = "Apartment" Then
				FieldsValuesStructure.Insert(Item.Presentation, Item.Value);
				ApartmentAdded = True;
			ElsIf NOT ApartmentAdded Then
				FieldsValuesStructure.Insert(Item.Presentation, Item.Value);				
			EndIf;
		Else
			FieldsValuesStructure.Insert(Item.Presentation, Item.Value);	
		EndIf;
		PreviousValue = Item;
	EndDo;
	
	Return FieldsString(FieldsValuesStructure, WithoutBlankFields);
EndFunction

//  Returns a string of the fields list.
//
//  Parameters:
//    FieldsValuesStructure - Structure - a structure of fields values.
//    WithoutBlankFields         - Boolean - an optional flag for saving fields with blank values.
//
//  Returns:
///     String - a result of converting from a structure.
//
Function FieldsString(FieldsValuesStructure, WithoutBlankFields = True) Export
	
	Result = "";
	For Each FieldValue In FieldsValuesStructure Do
		If WithoutBlankFields AND IsBlankString(FieldValue.Value) Then
			Continue;
		EndIf;
		
		Result = Result + ?(Result = "", "", Chars.LF)
		            + FieldValue.Key + "=" + StrReplace(FieldValue.Value, Chars.LF, Chars.LF + Chars.Tab);
	EndDo;
	
	Return Result;
EndFunction

#EndRegion

#EndRegion
