#Region Public

// The procedure for updating / refilled with predefined kinds of contact information. Initial filling of the base.
//
Procedure SetPropertiesPredefinedContactInformationTypes() Export
	
	Counterparties_SetKindProperties();
	ContactPersons_SetKindProperties();
	Companies_SetKindProperties();
	Individuals_SetKindProperties();
	BusinessUnits_SetKindProperties();
	Users_SetKindProperties();
	ShippingAddresses_SetKindProperties();
	Leads_SetKindProperties();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Add, change, and get contact information.

// Returns a table containing contact information for multiple objects.
//
// Parameters:
//    ReferencesOrObjects - Array - contact information owners.
//    ContactInformationTypes - Array, EnumRef.ContactInformationTypes - if types are specified, 
//        only contact information of these types is got.
//    ContactInformationKinds - Array, CatalogRef.ContactInformationKinds - if kinds are specified, 
//        only contact information of these kinds is got.
//    Date                     - Date - an optional parameter, a date, from which contact 
//                              information is recorded, it is used for storing contact information change history.
//                              If the owner stores the change history, an exception is thrown if 
//                              the parameter does not match the date.
//
// Returns:
//  ValueTable - a table with object contact information that contains the following columns:
//    * ReferencesOrObjects - Reference - a contact information owner.
//    * Kind              - CatalogRef.ContactInformationKinds - a contact information kind.
//    * Type              - EnumRef.ContactInformationTypes - a contact information type.
//    * Value         - String - contact information in the internal JSON format.
//    * Presentation    - String - a contact information presentation.
//    * Date             - Date - a date, from which contact information is recorded.
//    * FieldsValues    - String - an obsolete XML file matching the ContactInformation or Address XDTO data packages. 
//                                  For backward compatibility.
//
Function ObjectsContactInformation(ReferencesOrObjects, Val ContactInformationTypes = Undefined, Val ContactInformationKinds = Undefined, Date = Undefined) Export
	
	Query = New Query;
	Query.TempTablesManager = New TempTablesManager;
	
	If TypeOf(ContactInformationTypes) = Type("EnumRef.ContactInformationTypes") Then
		ContactInformationTypes = CommonClientServer.ValueInArray(ContactInformationTypes);
	EndIf;
	
	If TypeOf(ContactInformationKinds) = Type("CatalogRef.ContactInformationKinds") Then
		ContactInformationKinds = CommonClientServer.ValueInArray(ContactInformationKinds);
	EndIf;
	
	CreateContactInformationTemporaryTable(Query.TempTablesManager, ReferencesOrObjects, ContactInformationTypes, ContactInformationKinds, Date);
	
	If TypeOf(Date) = Type("Date") Then
		ValidFrom = "ContactInformation.ValidFrom";
	Else
		ValidFrom = "DATETIME(1, 1, 1, 0, 0, 0)";
	EndIf;
	
	Query.Text =
	"SELECT
	|	ContactInformation.Object AS Object,
	|	ContactInformation.Kind AS Kind,
	|	ContactInformation.Type AS Type,
	|	ContactInformation.FieldsValues AS FieldsValues,
	|	ContactInformation.Value AS Value,
	|	" + ValidFrom +" AS Date,
	|	ContactInformation.Presentation AS Presentation
	|FROM
	|	TTContactInformation AS ContactInformation";
	
	Result = Query.Execute().Unload();
	For each ContactInformationRow In Result Do
		If IsBlankString(ContactInformationRow.Value) 
			 AND ValueIsFilled(ContactInformationRow.FieldsValues) Then
			ContactInformationRow.Value = ContactInformationInJSON(ContactInformationRow.FieldsValues);
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

// Returns a table that contains an object contact information.
//
// Parameters:
//  ReferenceOrObject - AnyRef, Object - Reference or object - a contact information owner (company, 
//                                            counterparty, partner, and so on).
//  ContactInformationKind - CatalogRef.ContactInformationKinds - an optional parameter, a filter by contact information kind.
//  Date                     - Date - an optional parameter, a date, from which contact information 
//                              is recorded, it is used for storing contact information change history.
//                              If the owner stores the change history, an exception is thrown if 
//                              the parameter does not match the date.
//  OnlyPresentation - Boolean - if True, it returns only a presentation, otherwise, a value table.
//                                      To get a presentation, use the ObjectContactInformationPresentation function.
// 
// Returns:
//  String - a string presentation of a value if the OnlyPresentation parameter is set to True, otherwise,
//  ValueTable - a table with object contact information that contains the following columns:
//    * ReferencesOrObjects - Reference - a contact information owner.
//    * Kind              - CatalogRef.ContactInformationKinds - a contact information kind.
//    * Type              - EnumRef.ContactInformationTypes - a contact information type.
//    * FieldsValues    - String - an XML file matching the ContactInformation or Address XDTO data packages.
//    * Value         - String - contact information in the internal JSON format.
//    * Presentation    - String - a contact information presentation.
//    * Date             - Date - a date, from which a contact information is recorded.
//
Function ObjectContactInformation(ReferenceOrObject, ContactInformationKind = Undefined, Date = Undefined, OnlyPresentation = True) Export
	
	ObjectType = TypeOf(ReferenceOrObject);
	If NOT Common.IsReference(ObjectType) Then
		ObjectMetadata = Metadata.FindByType(ObjectType);
		Result = NewContactInformation();
		If ObjectMetadata <> Undefined 
			AND ObjectMetadata.TabularSections.Find("ContactInformation") <> Undefined Then
			
			For each ContactInformationRow In ReferenceOrObject.ContactInformation Do
				If ContactInformationKind = Undefined 
					OR ContactInformationRow.Kind = ContactInformationKind Then
					NewRow = Result.Add();
					FillPropertyValues(NewRow, ContactInformationRow);
					If IsBlankString(NewRow.Value)
						 AND ValueIsFilled(NewRow.FieldsValues) Then
							NewRow.Value = ContactInformationInJSON(NewRow.FieldsValues);
					EndIf;
					NewRow.Object = ReferenceOrObject;
				EndIf;
			EndDo;
			
		EndIf;
		
		If OnlyPresentation Then
			If Result.Count() > 0 Then
				Return Result[0].Presentation;
			EndIf;
			Return "";
		EndIf;
		
		Return Result;
		
	EndIf;
	
	If OnlyPresentation Then
		// Left for backward compatibility.
		ObjectsArray = New Array;
		ObjectsArray.Add(ReferenceOrObject.Ref);
		
		If NOT ValueIsFilled(ContactInformationKind) Then
			Return "";
		EndIf;
		
		ObjectContactInformation = ObjectsContactInformation(ObjectsArray,, ContactInformationKind, Date);
		
		If ObjectContactInformation.Count() > 0 Then
			Return ObjectContactInformation[0].Presentation;
		EndIf;
		
		Return "";
	Else
		ReferencesOrObjects = New Array;
		ReferencesOrObjects.Add(ReferenceOrObject);
		
		If TypeOf(ContactInformationKind) = Type("CatalogRef.ContactInformationKinds") Then
			ContactInformationKinds = New Array;
			ContactInformationKinds.Add(ContactInformationKind);
			ContactInformationTypes = New Array;
			ContactInformationTypes.Add(ContactInformationKind.Type);
		Else
			ContactInformationKinds = Undefined;
		EndIf;
		
		Return ObjectsContactInformation(ReferencesOrObjects, ContactInformationTypes, ContactInformationKinds, Date);
	EndIf;
	
EndFunction

// Returns a presentation of object contact information.
//
// Parameters:
//  ReferenceOrObject         - Arbitrary - a contact information owner.
//  ContactInformationKind - CatalogRef.ContactInformationKinds - a contact information kind.
//  Separator             - String - a separator that is added to a presentation between contact information records.
//                                     By default, this is a comma followed by a space; to exclude a 
//                                     space, use the WithoutSpaces flag of the AdditionalParameters parameter.
//  Date                    - Date - a date, from which contact information is recorded. If contact 
//                                   information stores change history, the date is to be passed.
//  AdditionalParameters - Structure - optional parameters for generating a contact information presentation.
//   * OnlyFirst         - Boolean - if True, only presentation of the main (first) contact 
//                                     information record returns. Default value is False.
//   * WithoutSpaces          - Boolean - if True, a space is not added automatically after the separator.
//                                     Default value is False.
// 
// Returns:
//  String - a generated contact information presentation.
//
Function ObjectContactInformationPresentation(ReferenceOrObject, ContactInformationKind, Separator = ",", Date = Undefined, AdditionalParameters = Undefined) Export
	
	OnlyFirst = False;
	WithoutSpaces = False;
	If TypeOf(AdditionalParameters) = Type("Structure") Then
		If AdditionalParameters.Property("OnlyFirst") Then
			OnlyFirst = AdditionalParameters.OnlyFirst;
		EndIf;
		If AdditionalParameters.Property("WithoutSpaces") Then
			WithoutSpaces = AdditionalParameters.WithoutSpaces;
		EndIf;
	EndIf;
	SeparatorInPresentation = ?(WithoutSpaces, Separator, Separator + " ");
	
	FirstPass = True;
	ContactInformation = ObjectContactInformation(ReferenceOrObject, ContactInformationKind, Date, False);
	For each ContactInformationRecord In ContactInformation Do
		If FirstPass Then
			Presentation = ContactInformationRecord.Presentation;
			If OnlyFirst Then
				Return Presentation;
			EndIf;
			FirstPass = False;
		Else
			Presentation = Presentation + SeparatorInPresentation + ContactInformationRecord.Presentation;
		EndIf;
	EndDo;
	
	Return Presentation;
	
EndFunction

// Generates a new contact information table.
//
// Parameters:
//  ObjectColumn - Boolean - if True, the table will contain the Object column.
//                           It is necessary if you need to store contact information for multiple objects.
// 
// Returns:
//  ValueTable - a table with the following columns:
//       * Object        - AnyRef - a contact information owner.
//       * Kind           - CatalogRef.ContactInformationKinds - a contact information kind.
//       * Type           - EnumRef.ContactInformationTypes - a contact information type.
//       * Value      - String - a JSON file matching contact information structure.
//       * FieldsValues - String - an XML file matching the ContactInformation or Address XDTO data package.
//       * Presentation - String - a contact information presentation.
//       * Date          - Date - a date, from which contact information is recorded.
//
Function NewContactInformation(ObjectColumn = True) Export
	
	ContactInformation = New ValueTable;
	TypesDetailsString1500 = New TypeDescription("String",, New StringQualifiers(1500));
	
	If ObjectColumn Then
		ContactInformation.Columns.Add("Object");
	EndIf;
	
	ContactInformation.Columns.Add("Presentation", TypesDetailsString1500);
	ContactInformation.Columns.Add("FieldsValues", New TypeDescription("String"));
	ContactInformation.Columns.Add("Value",      New TypeDescription("String"));
	ContactInformation.Columns.Add("Kind",           New TypeDescription("CatalogRef.ContactInformationKinds"));
	ContactInformation.Columns.Add("Type",           New TypeDescription("EnumRef.ContactInformationTypes"));
	ContactInformation.Columns.Add("Date",          New TypeDescription("Date"));
	
	Return ContactInformation;
	
EndFunction

// Adds contact information to an object by presentation or JSON file.
//
// Parameters:
//  ReferenceOrObject          - Arbitrary - a reference or an object of an owner containing contact information.
//                                            For references, after adding contact information, the owner is recorded.
//                                            If the object is passed, the contact information is added without being recorded.
//                                            To save changes, it is necessary to record the object separately.
//  ValueOrPresentation - String - a presentation, JSON, or XML file matching the ContactInformation 
//                                      or Address XDTO data package.
//  ContactInformationKind - CatalogRef.ContactInformationKinds - a kind of contact information being added.
//  Date                     - Date - a date, from which contact information will be recorded.
//                                       Required for contact information, for which the change history is stored.
//                                       If the value is not specified, the current session date is taken.
//  Replace                 - Boolean - if True (by default), all contact information of the passed 
//                                      contact information kind will be replaced.
//                                      If False, a record will be added. If the contact information 
//                                      kind does not allow entering multiple values and object 
//                                      contact information already contains a record, the record will not be added.
//
Procedure AddContactInformation(ReferenceOrObject, ValueOrPresentation, ContactInformationKind, Date = Undefined, Replace = True) Export
	
	If Common.IsReference(TypeOf(ReferenceOrObject)) Then
		Object = ReferenceOrObject.GetObject();
		Write = True;
	Else
		Object = ReferenceOrObject;
		Write = False;
	EndIf;
	
	ContactInformation                  = Object.ContactInformation;
	IsXMLContactInformation           = ContactsManagerClientServer.IsXMLContactInformation(ValueOrPresentation);
	IsJSONContactInformation          = ContactsManagerClientServer.IsJSONContactInformation(ValueOrPresentation);
	IsContactInformationInJSONStructure = TypeOf(ValueOrPresentation) = Type("Structure");
	ContactInformationKindProperties      = Common.ObjectAttributesValues(ContactInformationKind, "Type, StoreChangeHistory");
	
	ObjectMetadata = Metadata.FindByType(TypeOf(Object));
	If ObjectMetadata = Undefined
		Or ObjectMetadata.TabularSections.Find("ContactInformation") = Undefined Then
		Raise NStr("ru = 'Добавление контактной информации невозможно, у объекта нет таблицы с контактной информацией.'; en = 'Cannot add contact information. The object does not have a contact information table.'; pl = 'Dodawanie informacji kontaktowych nie jest możliwe, obiekt nie ma tabeli z danymi kontaktowymi.';es_ES = 'Es imposible añadir la información de contacto, el objeto no tiene tablas con la información de contacto.';es_CO = 'Es imposible añadir la información de contacto, el objeto no tiene tablas con la información de contacto.';tr = 'İletişim bilgileri eklenemiyor. Nesnenin iletişim bilgleri tablosu yok.';it = 'Non è possiible aggiungere l''informazione di contatto. L''oggetto non ha una tabella di informazioni di contatto.';de = 'Das Hinzufügen von Kontaktinformationen ist nicht möglich, das Objekt hat keine Tabelle mit Kontaktinformationen.'");;
	EndIf;
	
	If IsContactInformationInJSONStructure Then
		
		ContactInformationObject = ValueOrPresentation;
		Value = ContactsManagerInternal.ToJSONStringStructure(ValueOrPresentation);
		FieldsValues = ContactInformationToXML(Value);
		Presentation = ContactInformationObject.Value;
		
	Else
		
		If IsXMLContactInformation Then
			
			FieldsValues = ValueOrPresentation;
			Value = ContactInformationInJSON(ValueOrPresentation, ContactInformationKindProperties.Type);
			ContactInformationObject = ContactsManagerInternal.JSONStringToStructure(Value);
			Presentation = ContactInformationObject.Value;
			
		ElsIf IsJSONContactInformation Then
			
			Value = ValueOrPresentation;
			FieldsValues = ContactInformationToXML(Value);
			ContactInformationObject = ContactsManagerInternal.JSONStringToStructure(Value);
			Presentation = ContactInformationPresentation(ValueOrPresentation, ContactInformationKind);
			
		Else
			
			ContactInformationObject = ContactsManagerInternal.ContactsByPresentation(ValueOrPresentation, ContactInformationKindProperties.Type);
			Value = ContactsManagerInternal.ToJSONStringStructure(ContactInformationObject);
			FieldsValues = ContactInformationToXML(Value);
			Presentation = ValueOrPresentation;
			
		EndIf;
		
	EndIf;
	
	If Replace Then
		FoundRows = FindContactsStrings(ContactInformationKind, Date, ContactInformation);
		For Each TabularSectionRow In FoundRows Do
			ContactInformation.Delete(TabularSectionRow);
		EndDo;
		ContactInformationRow = ContactInformation.Add();
	Else
		If MultipleValuesEnterProhibited(ContactInformationKind, ContactInformation, Date) Then
			If IsXMLContactInformation Then
				ContactInformationRow = Object.ContactInformation.Find(ValueOrPresentation, "FieldsValues");
			ElsIf IsJSONContactInformation Then
				ContactInformationRow = Object.ContactInformation.Find(ValueOrPresentation, "Value");
			Else
				ContactInformationRow = Object.ContactInformation.Find(ValueOrPresentation, "Presentation");
			EndIf;
			If ContactInformationRow <> Undefined Then
				Return; // Only one value of this contact information kind is allowed.
			EndIf;
		EndIf;
		ContactInformationRow = ContactInformation.Add();
	EndIf;
	
	ContactInformationRow.Value      = Value;
	ContactInformationRow.Presentation = Presentation;
	ContactInformationRow.FieldsValues = FieldsValues;
	ContactInformationRow.Kind           = ContactInformationKind;
	ContactInformationRow.Type           = ContactInformationKindProperties.Type ;
	If ContactInformationKindProperties.StoreChangeHistory AND ValueIsFilled(Date) Then
		ContactInformationRow.ValidFrom = Date;
	EndIf;
	
	FillContactsTechnicalFields(ContactInformationRow, ContactInformationObject, ContactInformationKindProperties.Type);
	
	If Write Then
		Object.Write();
	EndIf;
	
EndProcedure

// Adds or changes contact information for multiple contact information owners.
//
// Parameters:
//  ContactInformation - ValueTable - a table containing contact information
//                                           See column details in the NewContactInformation function.
//                                           Warning! If a reference is specified in the Object 
//                                           column, the owner is recorded after adding contact information.
//                                           If the Object column contains an object of the contact 
//                                           information owner, objects are to be saved separately in order to save changes.
//  Replace             - Boolean - if True (by default), all contact information of the passed 
//                                   contact information kind will be replaced.
//                                   If False, a record will be added. If the contact information 
//                                   kind does not allow entering multiple values and object contact 
//                                   information already contains a record, the record will not be added.
//
Procedure SetObjectsContactInformation(ContactInformation, Replace = True) Export
	
	If ContactInformation.Count() = 0 Then
		Return;
	EndIf;
	
	ContactInformationOwners = New Map;
	For each ContactInformationRow In ContactInformation Do
		ContactInformationParameters = ContactInformationOwners[ContactInformationRow.Object];
		If ContactInformationParameters = Undefined Then
			ObjectMetadata = Metadata.FindByType(TypeOf(ContactInformationRow.Object));
			If ObjectMetadata = Undefined
				Or ObjectMetadata.TabularSections.Find("ContactInformation") = Undefined Then
				Raise NStr("ru = 'Добавление контактной информации невозможно, у объекта нет таблицы с контактной информацией.'; en = 'Cannot add contact information. The object does not have a contact information table.'; pl = 'Dodawanie informacji kontaktowych nie jest możliwe, obiekt nie ma tabeli z danymi kontaktowymi.';es_ES = 'Es imposible añadir la información de contacto, el objeto no tiene tablas con la información de contacto.';es_CO = 'Es imposible añadir la información de contacto, el objeto no tiene tablas con la información de contacto.';tr = 'İletişim bilgileri eklenemiyor. Nesnenin iletişim bilgleri tablosu yok.';it = 'Non è possiible aggiungere l''informazione di contatto. L''oggetto non ha una tabella di informazioni di contatto.';de = 'Das Hinzufügen von Kontaktinformationen ist nicht möglich, das Objekt hat keine Tabelle mit Kontaktinformationen.'");;
			EndIf;
			
			ContactInformationParameters = New Structure;
			IsReference = Common.RefTypeValue(ContactInformationRow.Object);
			ContactInformationParameters.Insert("IsReference", IsReference);
			ContactInformationParameters.Insert("Periodic", ObjectMetadata.TabularSections.ContactInformation.Attributes.Find("ValidFrom") <> Undefined);
			
			ContactInformationOwners.Insert(ContactInformationRow.Object, ContactInformationParameters);
		EndIf;
		
		RestoreEmptyValuePresentation(ContactInformationRow);
		
	EndDo;
	
	For each ContactInformationOwner In ContactInformationOwners Do
		Filter = New Structure("Object", ContactInformationOwner.Key);
		ObjectContactInformationRows = ContactInformation.FindRows(Filter);
		
		If ContactInformationOwner.Value["IsReference"] Then
			Object = ContactInformationOwner.Key.GetObject();
		Else
			Object = ContactInformationOwner.Key;
		EndIf;
		
		If Replace Then
			Object.ContactInformation.Clear();
		EndIf;
		
		For each ObjectContactInformationRow In ObjectContactInformationRows Do
			
			StoreChangeHistory = ContactInformationOwner.Value["Periodic"] AND ObjectContactInformationRow.Kind.StoreChangeHistory;
			
			If Replace Then
				
				If MultipleValuesEnterProhibited(ObjectContactInformationRow.Kind, Object.ContactInformation, ObjectContactInformationRow.Date) Then
					Continue;
				EndIf;
				ContactInformationRow = Object.ContactInformation.Add();
				
			Else
				
				Filter = New Structure();
				Filter.Insert("Kind", ObjectContactInformationRow.Kind);
				
				If StoreChangeHistory Then
					Filter.Insert("ValidFrom", ObjectContactInformationRow.Date);
					FoundRows = Object.ContactInformation.FindRows(Filter);
				ElsIf ValueIsFilled(ObjectContactInformationRow.Value) Then
					Filter.Insert("Value", ObjectContactInformationRow.Value);
					FoundRows = Object.ContactInformation.FindRows(Filter);
				Else
					Filter.Insert("FieldsValues", ObjectContactInformationRow.FieldsValues);
					FoundRows = Object.ContactInformation.FindRows(Filter);
				EndIf;
				
				If NOT StoreChangeHistory
					 AND MultipleValuesEnterProhibited(ObjectContactInformationRow.Kind, Object.ContactInformation, ObjectContactInformationRow.Date)
					 OR FoundRows.Count() > 0 Then
						Continue;
				EndIf;
				
				ContactInformationRow = Object.ContactInformation.Add();
			EndIf;
			
			FillObjectContactsFromString(ObjectContactInformationRow, StoreChangeHistory, ContactInformationRow);
		EndDo;
		
		If ContactInformationOwner.Value["IsReference"] Then
			Object.Write();
		EndIf;
		
	EndDo;
	
EndProcedure

// Adds or changes contact information for the contact information owner.
//
// Parameters:
//  ReferenceOrObject      - Arbitrary    - a reference or an object of the contact information owner.
//                                           For references, after adding contact information, the owner is recorded.
//                                           If the object is passed, the contact information is added without being recorded.
//                                           To save changes, it is necessary to record the object separately.
//  ContactInformation - ValueTable - a table containing contact information
//                                           See column details in the NewContactInformation function.
//                                           Warning! If a blank value table is passed and the 
//                                           replacement mode is set, all contact information of the contact information owner will be cleared.
//  Replace             - Boolean - if True (by default), all contact information of the passed 
//                                           contact information kind will be replaced.
//                                           If False, a record will be added. If the contact 
//                                           information kind does not allow entering multiple 
//                                           values and object contact information already contains a record, the record will not be added.
//
Procedure SetObjectContactInformation(ReferenceOrObject, Val ContactInformation, Replace = True) Export
	
	IsReference = Common.RefTypeValue(ReferenceOrObject);
	Object =?(IsReference, ReferenceOrObject.GetObject(), ReferenceOrObject);
	
	ObjectMetadata = Metadata.FindByType(TypeOf(ReferenceOrObject));
	If ObjectMetadata = Undefined
		Or ObjectMetadata.TabularSections.Find("ContactInformation") = Undefined Then
		Raise NStr("ru = 'Добавление контактной информации невозможно, у объекта нет таблицы с контактной информацией.'; en = 'Cannot add contact information. The object does not have a contact information table.'; pl = 'Dodawanie informacji kontaktowych nie jest możliwe, obiekt nie ma tabeli z danymi kontaktowymi.';es_ES = 'Es imposible añadir la información de contacto, el objeto no tiene tablas con la información de contacto.';es_CO = 'Es imposible añadir la información de contacto, el objeto no tiene tablas con la información de contacto.';tr = 'İletişim bilgileri eklenemiyor. Nesnenin iletişim bilgleri tablosu yok.';it = 'Non è possiible aggiungere l''informazione di contatto. L''oggetto non ha una tabella di informazioni di contatto.';de = 'Das Hinzufügen von Kontaktinformationen ist nicht möglich, das Objekt hat keine Tabelle mit Kontaktinformationen.'");;
	EndIf;
	
	// Clearing contact information using a blank table.
	If ContactInformation.Count() = 0 Then
		If Replace Then
			Object.ContactInformation.Clear();
			If IsReference Then
				Object.Write();
			EndIf;
		EndIf;
		Return;
	EndIf;
	
	Periodic = ObjectMetadata.TabularSections.ContactInformation.Attributes.Find("ValidFrom") <> Undefined;
	
	For each ContactInformationRow In ContactInformation Do
		RestoreEmptyValuePresentation(ContactInformationRow);
	EndDo;
	
	If Replace Then
		If Periodic Then
			For each ObjectContactInformationRow In ContactInformation Do
				FoundRows = FindContactsStrings(ObjectContactInformationRow.Kind, ObjectContactInformationRow.Date, Object.ContactInformation);
				For each Row In FoundRows Do
					Object.ContactInformation.Delete(Row);
				EndDo;
			EndDo;
		Else
			Object.ContactInformation.Clear();
		EndIf;
	EndIf;
	
	For each ObjectContactInformationRow In ContactInformation Do
		
		StoreChangeHistory = Periodic AND ObjectContactInformationRow.Kind.StoreChangeHistory;
		
		If Replace Then
			
			If MultipleValuesEnterProhibited(ObjectContactInformationRow.Kind, Object.ContactInformation, ObjectContactInformationRow.Date) Then
				Continue;
			EndIf;
			ContactInformationRow = Object.ContactInformation.Add();
			
		Else
			
			Filter = New Structure();
			Filter.Insert("Kind", ObjectContactInformationRow.Kind);
			
			If StoreChangeHistory Then
				Filter.Insert("ValidFrom", ObjectContactInformationRow.Date);
				FoundRows = Object.ContactInformation.FindRows(Filter);
			ElsIf ValueIsFilled(ObjectContactInformationRow.Value) Then
				Filter.Insert("Value", ObjectContactInformationRow.Value);
				FoundRows = Object.ContactInformation.FindRows(Filter);
			Else
				Filter.Insert("FieldsValues", ObjectContactInformationRow.FieldsValues);
				FoundRows = Object.ContactInformation.FindRows(Filter);
			EndIf;
			
			If NOT StoreChangeHistory
				 AND MultipleValuesEnterProhibited(ObjectContactInformationRow.Kind, Object.ContactInformation, ObjectContactInformationRow.Date)
				 OR FoundRows.Count() > 0 Then
					Continue;
			EndIf;
			
			ContactInformationRow = Object.ContactInformation.Add();
			
		EndIf;
		
		FillObjectContactsFromString(ObjectContactInformationRow, StoreChangeHistory, ContactInformationRow);
		
	EndDo;
	
	If IsReference Then
		Object.Write();
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Contact information management from other subsystems.

// Converts all incoming contact information formats to JSON.
//
// Parameters:
//    ContactInformation - String, Structure - details of contact information fields.
//                    For a string, the internal JSON format matches the structure described in function
//                    AddressManagerClientServer.NewContactInformationDetails (for a configuration 
//                    that supports Russian Federation specifics) or ContactInformationManagementClientServer.NewContactInformationDetails.
//                    For a string with XML matching the ContactInformation or Address XDTO data package.
//                    Fields of the structure must match returned fields of the following functions:
//                    AddressManager.AddressFields or AddressManagerClientServer.
//                    ContactsStructureByType for a configuration with support of RF specific or
//                    ContactsControlClientServer.ContactsStructureByType for an international configuration.
//    ExpectedKind - CatalogRef.ContactsKinds, EnumRef.ContactsTypes - 
//                    used to determine a type if it is impossible to determine it by the FieldsValues field.
//
// Returns:
//     String - contacts in JSON format matching the structure described in the
//              ContactsControlClientServer.NewContactInformationDetails function.
//              Fields can be extended by national specific in the homonymous function of the AddressManagerClientServer module.
//
Function ContactInformationInJSON(Val ContactInformation, Val ExpectedKind = Undefined) Export
	
	If ContactsManagerClientServer.IsJSONContactInformation(ContactInformation) Then
		Return ContactInformation;
	EndIf;
	
	ContactsByFields = ContactsManagerInternal.ContactInformationToJSONStructure(ContactInformation, ExpectedKind,, False);
	Return ContactsManagerInternal.ToJSONStringStructure(ContactsByFields);
	
EndFunction

// Converts all incoming contact information formats to XML.
//
// Parameters:
//    FieldsValues - String, Structure, Map, ValueList - details of contact information fields.
//                    For an XML string matching XDTO package ContactInformation or Address.
//                    Structure, Map, ValueList must contain fields in accordance with the stucture
//                    of XDTO packages ContactInformation or Address (for a configuration with support of local specifics).
//    Presentation - String - a contact information presentation. Used if it is impossible to 
//                    determine a presentation based on the FieldsValues parameter (the Presentation field is missing).
//    ExpectedKind - CatalogRef.ContactsKinds, EnumRef.ContactsTypes - 
//                    used to determine a type if it is impossible to determine it by the FieldsValues field.
//
// Returns:
//     String - contact information in the XML format matching the structure of the XDTO packages ContactInformation and Address.
//
Function ContactInformationToXML(Val FieldsValues, Val Presentation = "", Val ExpectedKind = Undefined) Export
	
	Result = ContactsManagerInternal.TransformContactInformationXML(New Structure(
		"FieldsValues, Presentation, ContactInformationKind",
	FieldsValues, Presentation, ExpectedKind));
	Return Result.XMLData;
	
EndFunction

// Returns a contact information type.
//
// Parameters:
//    ContactInformation - String - contact information as an XML matching the structure of
//                                    XDTO packages ContactInformation and Address.
//
// Returns:
//    EnumRef.ContactsTypes - matching type.
//
Function ContactInformationType(Val ContactInformation) Export
	
	If ContactsManagerClientServer.IsJSONContactInformation(ContactInformation) Then
		
		ContactsStructure = ContactsManagerInternal.JSONStringToStructure(ContactInformation);
		If TypeOf(ContactsStructure) = Type("Structure") AND ContactsStructure.Property("type") Then
			Return Enums.ContactInformationTypes[ContactsStructure.type];
		EndIf;
	
	EndIf;
	
	Return ContactsManagerInternal.ContactInformationType(ContactInformation);
EndFunction

// Converts a presentation of contacts into the internal JSON format.
//
// Correct conversion is not guaranteed for the addresses entered in free form.
//
//  Parameters:
//      Presentatin - String - a string presentation of contact information displayed to a user.
//      ExpectedKind - CatalogRef.ContactsKinds, EnumRef.ContactsTypes,
//                      Structure - a kind or a type of contact information.
//
// Returns:
//      String - contact information in the JSON format.
//
Function ContactsByPresentation(Presentation, ExpectedKind) Export
	
	Return ContactsManagerInternal.ToJSONStringStructure(
		ContactsManagerInternal.ContactsByPresentation(Presentation, ExpectedKind));
	
EndFunction

// Returns a presentation of a contact information (an address, a phone, an email, and so on).
//
// Parameters:
//    ContactInformation - String, XDTOObject - a JSON or XML string of contact information matching 
//                                                     XDTO packages ContactInformation or Address.
//    ContactsKind - Structure - additional parameters affecting the generation of address presentation:
//      * IncludeCountryInPresentation - Boolean - an address country will be included in the presentation;
//      * AddressFormat - String - FIAS or ARCA options.
//                                                If set to "ARCA", the address presentation does 
//                                                not include values of county and city district levels.
//
// Returns:
//    String - contact information presentation.
//
Function ContactInformationPresentation(Val ContactInformation, Val ContactInformationKind = Undefined) Export
	
	Return ContactsManagerInternal.ContactInformationPresentation(ContactInformation, ContactInformationKind);
	
EndFunction

// Returns contact information comment.
//
// Parameters:
//  ContactInformation - String - a JSON or XML string or XDTO object matching XDTO packages
//                                   ContactInformation or Address.
//
// Returns:
//  String - a contact information comment or an empty string if the parameter value is not contact 
//           information.
//
Function ContactInformationComment(ContactInformation) Export
	
	If IsBlankString(ContactInformation) Then
		Return "";
	EndIf;

	If ContactsManagerClientServer.IsXMLContactInformation(ContactInformation) Then
		ContactsStructure = ContactsManagerInternal.ContactInformationToJSONStructure(ContactInformation);
	ElsIf ContactsManagerClientServer.IsJSONContactInformation(ContactInformation) Then
		ContactsStructure = ContactsManagerInternal.JSONStringToStructure(ContactInformation);
	Else
		ContactInformationToXML = ContactInformationToXML(ContactInformation);
		ContactsStructure = ContactsManagerInternal.ContactInformationToJSONStructure(ContactInformationToXML);
	EndIf;
	
	If ContactsStructure.Property("Comment") Then
		Return ContactsStructure.Comment;
	EndIf;
	
	Return "";
	
EndFunction

// Sets a new comment for contact information.
//
// Parameters:
//   ContactInformation - String, XDTOObject - a JSON or XML string of contact information matching 
//                                      XDTO packages ContactInformation or Address.
//   Comment - String - a new comment value.
//
Procedure SetContactInformationComment(ContactInformation, Val Comment) Export
	
	IsString = TypeOf(ContactInformation) = Type("String");
	
	If ContactsManagerClientServer.IsJSONContactInformation(ContactInformation) Then
		
		ContactsStructure = ContactsManagerInternal.JSONStringToStructure(ContactInformation);
		
		If TypeOf(ContactsStructure) = Type("Structure") AND ContactsStructure.Property("comment") Then
			ContactsStructure.comment = Comment;
			ContactInformation = ContactsManagerInternal.ToJSONStringStructure(ContactsStructure);
		EndIf;
		
		Return;
		
	ElsIf IsString AND Not ContactsManagerClientServer.IsXMLContactInformation(ContactInformation) Then
		// The previous format of field values, no comment.
		Return;
	EndIf;
	
	XDTODataObject = ?(IsString, ContactsManagerInternal.ContactsFromXML(ContactInformation), ContactInformation);
	XDTODataObject.Comment = Comment;
	If IsString Then
		ContactInformation = ContactsManagerInternal.XDTOContactsInXML(XDTODataObject);
	EndIf;
	
EndProcedure

// Returns information about the address country.
// If the passed string does not contain information on the address, an exception is thrown.
// If an empty string is passed, an empty structure is returned.
// If the country is not found in the catalog but it is found in the ARCC, the "Ref" field of the result is blank.
// If the country is found neither in the address nor in the ARCC, only the Description field is filled in.
//
// Parameters:
//    Address - Structure, String - an address in a JSON format or XML string matching XDTO 
//                                packages ContactInformation or Address.
//
// Returns:
//    Structure - description of an address country. Contains fields:
//        * Reference - CatalogRef.WorldCountry, Undefined - a reference to the item of the world country catalog.
//        * Description - String - a country description.
//        * Code - String - a country code.
//        * FullDescription - String - a full description of the country.
//        * CodeAlpha2 - String - a two-character alpha-2 country code.
//        * CodeAlpha3 - String - a three-character alpha-3 country code.
//
Function ContactInformationAddressCountry(Val Address) Export
	
	Result = New Structure("Ref, Code, Description, DescriptionFull, CodeAlpha2, CodeAlpha3");
	
	If TypeOf(Address) = Type("String") Then
		
		If IsBlankString(Address) Then
			Return Result;
		EndIf;
	
		If ContactsManagerClientServer.IsXMLContactInformation(Address) Then
			Address = ContactInformationInJSON(Address, Enums.ContactInformationTypes.Address);
		EndIf;
		
		Address = ContactsManagerInternal.JSONStringToStructure(Address);
		
	ElsIf TypeOf(Address) <> Type("Structure") Then
		
		Raise NStr("ru = 'Невозможно определить страну, ожидается адрес.'; en = 'Cannot determine country. Address expected.'; pl = 'Nie można ustalić państwa, oczekiwanie adresu.';es_ES = 'No se puede determinar el país; dirección pendiente.';es_CO = 'No se puede determinar el país; dirección pendiente.';tr = 'Ülke belirlenemiyor; adres bekleniyor.';it = 'Impossibile determinare la Nazione. Indirizzo atteso.';de = 'Land kann nicht ermittelt werden; Adresse ausstehend.'");
		
	EndIf;
	
	Result.Description = TrimAll(Address.Country);
	CountryData = WorldCountryData(, Result.Description);
	Return ?(CountryData = Undefined, Result, CountryData);
	
EndFunction

// Returns a domain of the network address for a web link or an email address.
//
// Parameters:
//    ContactInformation - String - a JSON or XML string of contact information matching XDTO package ContactInformation.
//
// Returns:
//    String - an address domain.
//
Function ContactInformationAddressDomain(Val ContactInformation) Export
	
	If IsBlankString(ContactInformation) Then
		Return "";
	EndIf;
	
	If ContactsManagerClientServer.IsXMLContactInformation(ContactInformation) Then
		ContactsStructure = ContactsManagerInternal.ContactInformationToJSONStructure(ContactInformation,,, False);
	ElsIf ContactsManagerClientServer.IsJSONContactInformation(ContactInformation) Then
		ContactsStructure = ContactsManagerInternal.JSONStringToStructure(ContactInformation);
	EndIf;
	
	If ContactsStructure.Property("Type") AND ContactsStructure.Property("Value") Then
		
		AddressDomain = TrimAll(ContactsStructure.Value);
		If String(ContactsStructure.Type) = String(Enums.ContactInformationTypes.WebPage) Then
			
			Position = StrFind(AddressDomain, "://");
			If Position > 0 Then
				AddressDomain = Mid(AddressDomain, Position + 3);
			EndIf;
			Position = StrFind(AddressDomain, "/");
			Return ?(Position = 0, AddressDomain, Left(AddressDomain, Position - 1));
			
		ElsIf String(ContactsStructure.Type) = String(Enums.ContactInformationTypes.EmailAddress) Then
			
			Position = StrFind(AddressDomain, "@");
			Return ?(Position = 0, AddressDomain, Mid(AddressDomain, Position + 1));
			
		EndIf;
		
	EndIf;
	
	Raise NStr("ru = 'Невозможно определить домен, ожидается электронная почта или веб-ссылка.'; en = 'Cannot determine domain. An email address or URL expected.'; pl = 'Nie można określić domeny; oczekiwanie wiadomości e-mail lub łącza internetowego.';es_ES = 'No se puede determinar el dominio; correo electrónico o enlace web pendientes.';es_CO = 'No se puede determinar el dominio; correo electrónico o enlace web pendientes.';tr = 'Alan adı belirlenemiyor. E-posta adresi veya URL bekleniyor.';it = 'Impossibile determinare il dominio. Un indirizzo email o URL è atteso.';de = 'Domain kann nicht ermittelt werden; E-Mail oder Web-Link ausstehend.'");
EndFunction

// Returns a string containing a phone number without an area code and an extension.
//
// Parameters:
//    ContactInformation - String - a JSON or XML string of contact information matching XDTO package ContactInformation.
//
// Returns:
//    String - a phone number.
//
Function ContactInformationPhoneNumber(Val ContactInformation) Export
	
	If IsBlankString(ContactInformation) Then
		Return "";
	EndIf;
	
	If ContactsManagerClientServer.IsXMLContactInformation(ContactInformation) Then
		ContactsStructure = ContactsManagerInternal.ContactInformationToJSONStructure(ContactInformation,,, False);
	ElsIf ContactsManagerClientServer.IsJSONContactInformation(ContactInformation) Then
		ContactsStructure = ContactsManagerInternal.JSONStringToStructure(ContactInformation);
	EndIf;
	
	If ContactsStructure.Property("Number") Then
		
		Return TrimAll(ContactsStructure.Number);
		
	EndIf;
	
	Raise NStr("ru = 'Невозможно определить номер, ожидается телефона или факс.'; en = 'Cannot determine number. Phone or fax number expected.'; pl = 'Nie można określić numeru. Oczekiwany jest numer telefonu lub faksu.';es_ES = 'No se puede determinar el número; llamada telefónica o fax pendientes.';es_CO = 'No se puede determinar el número; llamada telefónica o fax pendientes.';tr = 'Numara belirlenemiyor, telefon veya faks bekleniyor.';it = 'Impossibile determinare il numero. Numero di telefono o fax è atteso.';de = 'Nummer kann nicht ermittelt werden; Telefonanruf oder Fax anstehend.'");
	
EndFunction

// Compares two instances of contact information.
//
// Parameters:
//    Data1 - XTDOObject - an object with contact information.
//            - String - contact information in XML format.
//            - Structure - contact information details. The following fields are expected:
//                 * FieldsValues - String, Structure, ValueList, Map - contact information fields.
//                 * Presentation - String - a presentation. Used when presentation cannot be 
//                                            extracted from FieldsValues (the Presentation field is not available).
//                 * Comment - String - a comment. Used when a comment cannot be extracted from 
//                                          FieldsValues.
//                 * ContactsKind - CatalogRef.ContactsKinds,
//                                             EnumRef.ContactsTypes, Structure - 
//                                             Used when a type cannot be extracted from FieldsValues.
//    Data2 - XTDOObject, String, Structure - similar to Data1.
//
// Returns:
//     ValueTable: - a table of different fields with the following columns:
//        * Path - String - XPath identifying the value difference. The "ContactInformationType" value
//                               means that passed contact information sets have different types.
//        * Details - String - details of a different attribute in terms of the subject field.
//        * Value1 - String - a value matching the object passed in the Data1 parameter.
//        * Value2 - String - a value matching the object passed in Data2 parameter.
//
Function ContactInformationDifferences(Val Data1, Val Data2) Export
	Return ContactsManagerInternal.ContactInformationDifferences(Data1, Data2);
EndFunction

// Generates a temporary table with contact information of multiple objects.
//
// Parameters:
//    TempTablesManager - TempTablesManager - a temporary table is created in the manager.
//     TTContacts with the fields:
//     * Object - Ref - a contact information owner.
//     * Kind - CatalogRef.ContactsKind - a reference to the contacts kind.
//     * Type           - EnumRef.ContactInformationTypes - a contact information type.
//     * FieldsValues - String - an XML file matching the ContactInformation or Address XDTO data package.
//     * Presentation - String - a contact information presentation.
//    ObjectsArray - Array - contact information owners.
//    ContactsType - Array - if specified, a temporary table will contain only contacts of these 
//                                        types.
//    ContactsKind - Array - if specified, a temporary table will contain only contacts of these 
//                                        kinds.
//    Date - Date - the date, from which contact information record is valid. It is used for storing 
//                                        the history of contact information changes. If the owner 
//                                        stores the change history, an exception is thrown if the parameter does not match the date.
//
Procedure CreateContactInformationTemporaryTable(TempTablesManager, ObjectsArray, ContactInformationTypes = Undefined, ContactInformationKinds = Undefined, Date = Undefined) Export
	
	If TypeOf(ObjectsArray) <> Type("Array") OR ObjectsArray.Count() = 0 Then
		Raise NStr("ru = 'Неверное значение для массива владельцев контактной информации.'; en = 'Invalid value for the array of contact information owners.'; pl = 'Niepoprawna wartość dla tablicy właścicieli informacji kontaktowych.';es_ES = 'Valor incorrecto para el conjunto de los propietarios de la información de contacto.';es_CO = 'Valor incorrecto para el conjunto de los propietarios de la información de contacto.';tr = 'İletişim bilgisi sahiplerinin dizisi için yanlış değer.';it = 'Il valore errato per il flusso di proprietari dell''informazione di contatto.';de = 'Falscher Wert für die Anordnung der Kontaktinformation Eigentümer.'");
	EndIf;
	
	ObjectsGroupedByTypes = New Map;
	For each Ref In ObjectsArray Do
		ObjectType = TypeOf(Ref);
		FoundObject = ObjectsGroupedByTypes.Get(ObjectType);
		If FoundObject = Undefined Then
			RefSet = New Array;
			RefSet.Add(Ref);
			ObjectsGroupedByTypes.Insert(ObjectType, RefSet);
		Else
			FoundObject.Add(Ref);
		EndIf;
	EndDo;
	
	Query = New Query();
	QueryTextPreparingData = "";
	StringALLOWED = " ALLOWED ";
	TemporaryTableString = "INTO TTContactInformation";
	
	For each ObjectWithContacts In ObjectsGroupedByTypes Do
		ObjectMetadata = Metadata.FindByType(ObjectWithContacts.Key);
		If ObjectMetadata.TabularSections.Find("ContactInformation") = Undefined Then
			Raise  ObjectMetadata.Name + " " + NStr("ru = 'не содержит контактную информацию.'; en = 'does not contain contact information.'; pl = 'nie zawiera informacji kontaktowej.';es_ES = 'no contiene información de contacto.';es_CO = 'no contiene información de contacto.';tr = 'iletişim bilgileri içermemektedir.';it = 'non contiene informazioni di contatto.';de = 'enthält keine Kontaktinformationen.'");
		EndIf;
		TableName = ObjectMetadata.Name;
		If ObjectMetadata.TabularSections.ContactInformation.Attributes.Find("ValidFrom") <> Undefined Then
			QueryTextPreparingData = QueryTextPreparingData + "SELECT ALLOWED
			|	ContactInformation.Ref AS Object,
			|	ContactInformation.Kind AS Kind,
			|	MAX(ContactInformation.ValidFrom) AS ValidFrom
			|INTO ContactInformationSlice" + TableName + "
			|FROM
			|	" + ObjectMetadata.FullName() + ".ContactInformation AS ContactInformation
			|WHERE
			|	ContactInformation.Ref IN (&ObjectsArray" + TableName + ")
			|	AND ContactInformation.ValidFrom <= &ValidFrom
			|	AND ContactInformation.Kind <> VALUE(Catalog.ContactInformationKinds.EmptyRef)
			|	AND ContactInformation.Type <> VALUE(Enum.ContactInformationTypes.EmptyRef)
			|
			|GROUP BY
			|	ContactInformation.Kind, ContactInformation.Ref
			|;"
		EndIf;
	EndDo;
	
	QueryText = "";
	For each ObjectWithContacts In ObjectsGroupedByTypes Do
		QueryText = QueryText + ?(NOT IsBlankString(QueryText), Chars.LF + " UNION ALL " + Chars.LF, "");
		ObjectMetadata = Metadata.FindByType(ObjectWithContacts.Key);
		TableName = ObjectMetadata.Name;
		
		If ObjectMetadata.TabularSections.ContactInformation.Attributes.Find("ValidFrom") <> Undefined Then
			If TypeOf(Date) <> Type("Date") Then
				Raise NStr("ru = 'Для получения контактной информации, хранящей историю изменений,
					|требуется указывать дату, с которой действует запись контактной информации.'; 
					|en = 'To receive contact information storing the change history,
					|specify the date from which contact information record is valid.'; 
					|pl = 'Aby uzyskać informację kontaktową, przechowującą historię zmian,
					|należy podać datę, od której obowiązuje wpis informacji kontaktowej.';
					|es_ES = 'Para recibir la información de contacto que guarda el historial de cambios,
					|se requiere indicar la fecha de la que la información de contacto está vigente.';
					|es_CO = 'Para recibir la información de contacto que guarda el historial de cambios,
					|se requiere indicar la fecha de la que la información de contacto está vigente.';
					|tr = 'Değişiklik geçmişini 
					|muhafaza eden iletişim bilgilerini almak için iletişim bilgilerinin kaydedildiği tarihi belirtmeniz gerekir.';
					|it = 'Per ricevere informazioni di contatto contenenti la cronologia delle modifiche,
					|indicare la data a partire dalla quale la registrazione delle informazioni di contatto è valida.';
					|de = 'Um Kontaktinformationen zu erhalten, die die Änderungshistorie speichern,
					|muss das Datum angegeben werden, an dem die Kontaktinformationen erfasst werden.'");
			EndIf;
			
			FilterConditions = ?(ContactInformationKinds = Undefined, "", " ContactInformation.Kind IN (&ContactInformationKinds)");
			If IsBlankString(FilterConditions) Then
				ConditionsAnd = "";
			Else
				ConditionsAnd = " AND ";
			EndIf;
			FilterConditions = FilterConditions + ?(ContactInformationTypes = Undefined, "", ConditionsAnd + " ContactInformation.Type IN (&ContactInformationTypes)");
			If NOT IsBlankString(FilterConditions) Then
				FilterConditions = " WHERE " + FilterConditions;
			EndIf;
			
			QueryText = QueryText + "SELECT " + StringALLOWED + "
			|	ContactInformation.Ref AS Object,
			|	ContactInformation.Kind AS Kind,
			|	ContactInformation.Type AS Type,
			|	ContactInformation.ValidFrom AS ValidFrom,
			|	ContactInformation.Presentation AS Presentation,
			|	ContactInformation.Value,
			|	ContactInformation.FieldsValues
			|	" + TemporaryTableString + "
			|FROM
			|	ContactInformationSlice" + TableName + " AS ContactInformationSlice
			|		LEFT JOIN " + ObjectMetadata.FullName() + ".ContactInformation AS ContactInformation
			|		ON ContactInformationSlice.Kind = ContactInformation.Kind
			|			AND ContactInformationSlice.ValidFrom = ContactInformation.ValidFrom
			|			AND ContactInformationSlice.Object = ContactInformation.Ref " + FilterConditions;
		Else
			QueryText = QueryText + "SELECT " + StringALLOWED + "
			|	ContactInformation.Ref AS Object,
			|	ContactInformation.Kind AS Kind,
			|	ContactInformation.Type AS Type,
			|	DATETIME(1,1,1) AS ValidFrom,
			|	ContactInformation.Presentation AS Presentation,
			|	ContactInformation.Value,
			|	ContactInformation.FieldsValues AS FieldsValues
			|	" + TemporaryTableString + "
			|FROM
			|	" + ObjectMetadata.FullName() + ".ContactInformation AS ContactInformation
			|WHERE
			| ContactInformation.Kind <> VALUE(Catalog.ContactInformationKinds.EmptyRef)
			| AND ContactInformation.Type <> VALUE(Enum.ContactInformationTypes.EmptyRef)
			| AND ContactInformation.Ref IN (&ObjectsArray" + TableName + ")
			|	" + ?(ContactInformationTypes = Undefined, "", "AND ContactInformation.Type IN (&ContactInformationTypes)") + "
			|	" + ?(ContactInformationKinds = Undefined, "", "AND ContactInformation.Kind IN (&ContactInformationKinds)") + "
			|";
		EndIf;
		StringALLOWED ="";
		TemporaryTableString = "";
		
		Query.SetParameter("ObjectsArray" + TableName, ObjectWithContacts.Value);
	EndDo;
	
	Query.Text = QueryTextPreparingData + QueryText;
	Query.TempTablesManager = TempTablesManager;
	
	Query.SetParameter("ValidFrom", Date);
	Query.SetParameter("ContactInformationTypes", ContactInformationTypes);
	Query.SetParameter("ContactInformationKinds", ContactInformationKinds);
	Query.Execute();
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// World countries

// Returns country data from the countries catalog or from the ARCC.
//
// Parameters:
//    CountryCode    - String, Number - an ARCC country code. If not specified, search by code is not performed.
//    Description - String - a country description. If not specified, search by description is not performed.
//
// Returns:
//    Structure - country details. Contains fields:
//        * Reference - CatalogRef.WorldCountry, Undefined - a matching world country item.
//        * Description - String - a country description.
//        * Code - String - a country code.
//        * FullDescription - String - a full description of the country.
//        * CodeAlpha2 - String - a two-character alpha-2 country code.
//        * CodeAlpha3 - String - a three-character alpha-3 country code.
//        * EEUMember - Boolean - a EEU member country.
//    Undefined - the country is found neither in the address nor in the ARCC.
//
Function WorldCountryData(Val CountryCode = Undefined, Val Description = Undefined) Export
	Result = Undefined;
	
	If CountryCode = Undefined AND Description = Undefined Then
		Return Result;
	EndIf;
	
	StandardizedCode = WorldCountryCode(CountryCode);
	If CountryCode = Undefined Then
		SearchCondition = "TRUE";
		ClassifierFilter = New Structure;
	Else
		SearchCondition = "Code=" + CheckQuotesInString(StandardizedCode);
		ClassifierFilter = New Structure("Code", StandardizedCode);
	EndIf;
	
	If Description<>Undefined Then
		SearchCondition = SearchCondition + " AND Description=" + CheckQuotesInString(Description);
		ClassifierFilter.Insert("Description", Description);
	EndIf;
	
	Result = New Structure("Ref, Code, Description, DescriptionFull, CodeAlpha2, CodeAlpha3, EEUMember");
	
	Query = New Query("
	|SELECT TOP 1
	|	Ref, Code, Description, DescriptionFull, CodeAlpha2, CodeAlpha3, EEUMember
	|FROM
	|	Catalog.WorldCountries
	|WHERE
	|	" + SearchCondition + "
	|ORDER BY
	|	Description
	|");
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then 
		FillPropertyValues(Result, Selection);
	Else
		ClassifierData = ClassifierTable();
		DataRows = ClassifierData.FindRows(ClassifierFilter);
		If DataRows.Count()=0 Then
			Result = Undefined;
		Else
			FillPropertyValues(Result, DataRows[0]);
		EndIf;
		
	EndIf;
	
	Return Result;
EndFunction

// Returns a country data by code.
//
// Parameters:
//  Code     - String, Number - an ARCC country code.
//  CodeType - String - Options: CountryCode (by default), Alpha2, Alpha3.
// 
// Returns:
//  Structure - country details. Contains fields:
//     * Description - String - a country description.
//     * Code - String - a country code.
//     * FullDescription - String - a full description of the country.
//     * CodeAlpha2 - String - a two-character alpha-2 country code.
//     * CodeAlpha3 - String - a three-character alpha-3 country code.
//     * EEUMember - Boolean - a EEU member country.
//  Undefined - the country is found neither in the address nor in the ARCC.
//
Function WorldCountryClassifierDataByCode(Val Code, Val CodeType = "CountryCode") Export
	
	ClassifierData = ClassifierTable();
	If StrCompare(CodeType, "Alpha2") = 0 Then
		DataString = ClassifierData.Find(Upper(Code), "CodeAlpha2");
	ElsIf StrCompare(CodeType, "Alpha3") = 0 Then
		DataString = ClassifierData.Find(Upper(Code), "CodeAlpha3");
	Else
		DataString = ClassifierData.Find(WorldCountryCode(Code), "Code");
	EndIf;
	
	If DataString=Undefined Then
		Result = Undefined;
	Else
		Result = New Structure("Code, Description, DescriptionFull, CodeAlpha2, CodeAlpha3, EEUMember");
		FillPropertyValues(Result, DataString);
	EndIf;
	
	Return Result;
	
EndFunction

// Returns country data by country description.
//
// Parameters:
//    Description - String - a country description.
//
// Returns:
//    Structure - country details. Contains fields:
//       * Description - String - a country description.
//       * Code - String - a country code.
//       * FullDescription - String - a full description of the country.
//       * CodeAlpha2 - String - a two-character alpha-2 country code.
//       * CodeAlpha3 - String - a three-character alpha-3 country code.
//       * EEUMember - Boolean - a EEU member country.
//    Undefined - the country is not found in the classifier.
//
Function WorldCountryClassifierDataByDescription(Val Description) Export
	ClassifierData = ClassifierTable();
	DataString = ClassifierData.Find(Description, "Description");
	If DataString=Undefined Then
		Result = Undefined;
	Else
		Result = New Structure("Code, Description, DescriptionFull, CodeAlpha2, CodeAlpha3, EEUMember");
		FillPropertyValues(Result, DataString);
	EndIf;
	
	Return Result;
EndFunction

// Returns a reference to the world country catalog item by code or description.
// If the item of the WorldCountry catalog is not found, it will be generated based on the filling data.
//
// Parameters:
//  CodeOrDescription - String - a country code, code alpha2, code alpha3, or country description.
//  FillingData - Structure - optional. Data for filling when creating a new item.
//                                   The structure keys match the attribute of the WorldCountry catalog.
// 
// Returns:
//  CatalogRef.WorldCountry - a reference to the item of the WorldCountry catalog.
//                                If several values are found, the first value will be returned.
//                                If no values are found, filling data is not specified, an empty reference will be returned.
//
Function WorldCountryByCodeOrDescription(CodeOrDescription, FillingData = Undefined) Export
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	WorldCountries.Ref AS Ref
	|FROM
	|	Catalog.WorldCountries AS WorldCountries
	|WHERE
	|	(WorldCountries.Code = &CodeOrDescription
	|			OR WorldCountries.CodeAlpha2 = &CodeOrDescription
	|			OR WorldCountries.CodeAlpha3 = &CodeOrDescription
	|			OR WorldCountries.Description = &CodeOrDescription
	|			OR WorldCountries.DescriptionFull = &CodeOrDescription)";
	
	Query.SetParameter("CodeOrDescription", CodeOrDescription);
	QueryResult = Query.Execute().Select();
	
	If QueryResult.Next() Then
		Return QueryResult.Ref;
	EndIf;
	
	ClassifierData = ClassifierTable();
	
	Query = New Query;
	Query.Text = "SELECT
	|	TableClassifier.Code,
	|	TableClassifier.CodeAlpha2,
	|	TableClassifier.CodeAlpha3,
	|	TableClassifier.Description,
	|	TableClassifier.DescriptionFull,
	|	TableClassifier.EEUMember,
	|	TableClassifier.NonRelevant
	|INTO TableClassifier
	|FROM
	|	&TableClassifier AS TableClassifier
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	WorldCountry.Code,
	|	WorldCountry.CodeAlpha2,
	|	WorldCountry.CodeAlpha3,
	|	WorldCountry.Description,
	|	WorldCountry.DescriptionFull,
	|	WorldCountry.EEUMember,
	|	WorldCountry.NonRelevant
	|FROM
	|	TableClassifier AS WorldCountry
	|WHERE
	|	(WorldCountry.Code = &CodeOrDescription
	|			OR WorldCountry.CodeAlpha2 = &CodeOrDescription
	|			OR WorldCountry.CodeAlpha3 = &CodeOrDescription
	|			OR WorldCountry.Description = &CodeOrDescription
	|			OR WorldCountry.DescriptionFull = &CodeOrDescription)";
	
	Query.SetParameter("TableClassifier", ClassifierData);
	Query.SetParameter("CodeOrDescription",   CodeOrDescription);
	QueryResult = Query.Execute().Select();
	
	If QueryResult.Next() Then
		FillingData = Common.ValueTableRowToStructure(QueryResult);
	EndIf;
	
	If FillingData = Undefined 
		OR NOT FillingData.Property("Description")
		OR IsBlankString(FillingData.Description) Then
		Return Catalogs.WorldCountries.EmptyRef();
	EndIf;
	
	SetPrivilegedMode(True);
	CountryObject = Catalogs.WorldCountries.CreateItem();
	FillPropertyValues(CountryObject, FillingData);
	CountryObject.Write();
	Return CountryObject.Ref;
	
EndFunction

// Returns a list of the Eurasian Economic Union countries (EEU).
//
// Returns:
//  - ValueTable - a list of the Eurasian Economic Union countries (EEU).
//     * Reference - CatalogRef.WorldCountry - a reference to the item of the WorldCountry catalog.
//     * Description - String - a country description.
//     * Code - String - a country code.
//     * FullDescription - String - a full description of the country.
//     * CodeAlpha2 - String - a two-character alpha-2 country code.
//     * CodeAlpha3 - String - a three-character alpha-3 country code.
Function EEUMemberCountries() Export
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	WorldCountries.Ref AS Ref,
		|	WorldCountries.Description AS Description,
		|	WorldCountries.Code AS Code,
		|	WorldCountries.DescriptionFull AS DescriptionFull,
		|	WorldCountries.CodeAlpha2 AS CodeAlpha2,
		|	WorldCountries.CodeAlpha3 AS CodeAlpha3
		|FROM
		|	Catalog.WorldCountries AS WorldCountries
		|WHERE
		|	WorldCountries.EEUMember = TRUE";
	
	EEUCountries = Query.Execute().Unload();
	
	ClassifierData = ClassifierTable();
	
	For each Country In ClassifierData Do
		If Country.EEUMember Then
			Filter = New Structure();
			Filter.Insert("Description", Country.Description);
			Filter.Insert("Code", Country.Code);
			Filter.Insert("DescriptionFull", Country.DescriptionFull);
			Filter.Insert("CodeAlpha2", Country.CodeAlpha2);
			Filter.Insert("CodeAlpha3", Country.CodeAlpha3);
			FoundRows = EEUCountries.FindRows(Filter);
			If FoundRows.Count() = 0 Then
				NewRow = EEUCountries.Add();
				FillPropertyValues(NewRow, Filter);
			EndIf;
		EndIf;
	EndDo;
	
	Return EEUCountries;

EndFunction

// Determines whether a country is the Eurasian Economic Union member (EEU).
//
// Parameters:
//  Country - String - CatalogRef.WorldCountry - a country code, code alpha2, code alpha3, country 
//                  description or a reference to the item of the WorldCountry catalog.
// Returns:
//    Boolean - if True, a country is the EEU country member.
Function IsEEUMemberCountry(Country) Export
	
	If TypeOf(Country) = TypeOf(Catalogs.WorldCountries.EmptyRef()) Then
		Query = New Query;
		Query.Text = 
			"SELECT
			|	WorldCountries.EEUMember AS EEUMember
			|FROM
			|	Catalog.WorldCountries AS WorldCountries
			|WHERE
			|	WorldCountries.Ref = &Ref";
		
		Query.SetParameter("Ref", Country);
		
		QueryResult = Query.Execute();
		
		If NOT QueryResult.IsEmpty() Then
			ResultString = QueryResult.Select();
			If ResultString.Next() Then
				Return (ResultString.EEUMember = TRUE);
			EndIf;
		EndIf;
		
	Else
		FoundCountry =  WorldCountryByCodeOrDescription(Country);
		If ValueIsFilled(FoundCountry) Then
			Return FoundCountry.EEUMember;
		EndIf;
		
	EndIf;
	
	Return False;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Handlers of form events and object module called upon the subsystem integration.

// OnCreateAtServer form event handler.
// Called from the module of contact information owner object form upon the subsystem integration.
//
// Parameters:
//    Form - ClientApplicationForm - an owner object form used for displaying contact information.
//    Object - Arbitrary - an owner object of contact information. If it is a reference, contact 
//                                          information will be received from the object by reference, otherwise, from the ContactInformation table of the object.
//    AdditionalParameters - Structure - details of contact information settings - see  ContactsParameters.
//                                          The previous name of the ItemForPlacementName parameter. 
//                                          Obsolete, use AdditionalParameters. The group, to which 
//                                          contact information items will be placed.
//    DeleteContactsTitleLocation - FormItemTitleLocation - obsolete, use AdditionalParameters.
//                                                             Can take the following values:
//                                                             FormItemTitleLocation.Top or
//                                                             FormItemTitleLocation.Left (by default).
//    DeleteExcludedKinds - Array - obsolete, use AdditionalParameters.
//    DeleteDeferredInitialization - Array - obsolete, use AdditionalParameters.
//
Procedure OnCreateAtServer(Form, Object, AdditionalParameters = Undefined, DeleteContactsTitleLocation = "",
	Val DeleteExcludedKinds = Undefined, DeleteDeferredInitialization = False) Export
	
	PremiseType = Undefined;
	If TypeOf(AdditionalParameters) = Type("Structure") Then
		
		AdditionalParameters.Property("PremiseType", PremiseType);
		DeferredInitialization  = ?(AdditionalParameters.Property("DeferredInitialization"), AdditionalParameters.DeferredInitialization, False);
		TitleLocationContactInformation     = ?(AdditionalParameters.Property("TitleLocationContactInformation"), AdditionalParameters.TitleLocationContactInformation, "");
		ExcludedKinds          = ?(AdditionalParameters.Property("ExcludedKinds"), AdditionalParameters.ExcludedKinds, Undefined);
		HiddenKinds           = ?(AdditionalParameters.Property("HiddenKinds"), AdditionalParameters.HiddenKinds, Undefined);
		ItemForPlacementName = ?(AdditionalParameters.Property("ItemForPlacementName"), AdditionalParameters.ItemForPlacementName, "ContactInformationGroup");
		ObjectIndex = ?(AdditionalParameters.Property("ObjectIndex"), AdditionalParameters.ObjectIndex, 0);
	Else
		ItemForPlacementName = ?(AdditionalParameters = Undefined, "ContactInformationGroup", AdditionalParameters);
		DeferredInitialization  = DeleteDeferredInitialization;
		ExcludedKinds          = DeleteExcludedKinds;
		HiddenKinds           = Undefined;
		TitleLocationContactInformation     = DeleteContactsTitleLocation;
		ObjectIndex = 0;
	EndIf;
	
	If ExcludedKinds = Undefined Then
		ExcludedKinds = New Array;
	EndIf;
	
	If HiddenKinds = Undefined Then
		HiddenKinds = New Array;
	EndIf;
	
	AttributesToAdd = New Array;
	CheckAvailabilityOfContactsAttributes(Form, AttributesToAdd);
	
	// Caching of frequently used values
	ObjectRef             = Object.Ref;
	ObjectMetadata          = ObjectRef.Metadata();
	FullMetadataObjectName = ObjectMetadata.FullName();
	ObjectName                 = ObjectMetadata.Name;
	
	If TypeOf(AdditionalParameters) = Type("Structure") And AdditionalParameters.Property("ContactsKindsGroup") Then
		ContactsKindsGroup  = ObjectContactsKindsGroup(AdditionalParameters.ContactsKindsGroup);
	Else
		ContactsKindsGroup  = ObjectContactsKindsGroup(FullMetadataObjectName);
	EndIf;

	UsedContacts = Common.ObjectAttributeValue(ContactsKindsGroup, "Used");
	If UsedContacts = False Then
		HideContacts(Form, AttributesToAdd, ItemForPlacementName, ExcludedKinds, 
			DeferredInitialization, TitleLocationContactInformation, ObjectRef);
		Return;
	EndIf;
	
	AlwaysShowKinds = AlwaysShowKinds(ContactsKindsGroup);
	
	ObjectAttributes           = ObjectMetadata.TabularSections.ContactInformation.Attributes;
	HasColumnValidFrom      = (ObjectAttributes.Find("ValidFrom") <> Undefined);
	HasColumnContactLineIdentifier = (ObjectAttributes.Find("ContactLineIdentifier") <> Undefined);
	
	If Common.IsReference(TypeOf(Object)) Then
		QueryText = "SELECT
		|	ContactInformation.Presentation AS Presentation,
		|	ContactInformation.LineNumber AS LineNumber,
		|	ContactInformation.Kind AS Kind, 
		|	ContactInformationKinds.StoreChangeHistory AS StoreChangeHistory,
		|	ContactInformation.FieldsValues,
		|	ContactInformation.Value,
		|	"""" AS ValidFrom,
		|	0 AS ContactLineIdentifier,
		|	FALSE AS IsHistoricalContactInformation
		|FROM
		|	Catalog.ContactInformationKinds AS ContactInformationKinds
		|		LEFT JOIN " +  FullMetadataObjectName + ".ContactInformation AS ContactInformation
		|		ON (ContactInformation.Kind = ContactInformationKinds.Ref)
		|WHERE
		|	ContactInformation.Ref = &Ref ORDER BY Kind, ValidFrom";
		
		If HasColumnContactLineIdentifier Then
			QueryText = StrReplace(QueryText, "0 AS ContactLineIdentifier",
			"ISNULL(ContactInformation.ContactLineIdentifier, 0) AS ContactLineIdentifier");
		EndIf;
		
		If HasColumnValidFrom Then
			QueryText = StrReplace(QueryText, """"" AS ValidFrom", "ContactInformation.ValidFrom AS ValidFrom");
		EndIf;
		Query = New Query(QueryText);
		Query.SetParameter("Ref", ObjectRef);
		ContactInformation = Query.Execute().Unload();
	Else
		ContactInformation = Object.ContactInformation.Unload();
		
		If HasColumnValidFrom Then
			BooleanType = New TypeDescription("Boolean");
			ContactInformation.Columns.Add("StoreChangeHistory", BooleanType);
			ContactInformation.Columns.Add("IsHistoricalContactInformation", BooleanType);
			ContactInformation.Sort("Kind, ValidFrom");
			For each ContactInformationRow In ContactInformation Do
				ContactInformationRow.StoreChangeHistory = ContactInformationRow.Kind.StoreChangeHistory;
			EndDo;
		EndIf;
	EndIf;
	
	If HasColumnValidFrom Then
		PreviousKind = Undefined;
		For each ContactInformationRow In ContactInformation Do
			If ContactInformationRow.StoreChangeHistory
				AND (PreviousKind = Undefined OR PreviousKind <> ContactInformationRow.Kind) Then
				Filter = New Structure("Kind", ContactInformationRow.Kind);
				FoundRows = ContactInformation.FindRows(Filter);
				LastDate = FoundRows.Get(FoundRows.Count() - 1).ValidFrom;
				For each FoundRow In FoundRows Do
					If FoundRow.ValidFrom < LastDate Then
						FoundRow.IsHistoricalContactInformation = True;
					EndIf;
				EndDo;
				PreviousKind = ContactInformationRow.Kind;
			EndIf;
		EndDo;
		QueryTextHistoricalInformation = " ContactInformation.IsHistoricalContactInformation AS IsHistoricalContactInformation,
		|	ContactInformation.ValidFrom                  AS ValidFrom,";
	Else
		QueryTextHistoricalInformation = "FALSE AS IsHistoricalContactInformation,0 AS ValidFrom, ";
	EndIf;
	
	QueryText = " SELECT
	|	ContactInformation.Presentation               AS Presentation,
	|	ContactInformation.Value                    AS Value,
	|	ContactInformation.FieldsValues               AS FieldsValues,
	|	ContactInformation.LineNumber                 AS LineNumber, " + QueryTextHistoricalInformation + "
	|	ContactInformation.Kind                         AS Kind,
	|	0 AS ContactLineIdentifier
	|INTO
	|	ContactInformation
	|FROM
	|	&ContactInformationTable AS ContactInformation
	|WHERE
	|	&ContactLineIdentifierCondition
	|INDEX BY
	|	Kind
	|;////////////////////////////////////////////////////////////////////////////////
	|
	|SELECT
	|	ContactInformationKinds.Ref                       AS Kind,
	|	ContactInformationKinds.PredefinedDataName    AS PredefinedDataName,
	|	ContactInformationKinds.Type                          AS Type,
	|	ContactInformationKinds.Mandatory       AS Mandatory,
	|	ContactInformationKinds.FieldKindOther                AS FieldKindOther,
	|	ContactInformationKinds.Description                 AS Description,
	|	ContactInformationKinds.StoreChangeHistory      AS StoreChangeHistory,
	|	ContactInformationKinds.EditOnlyInDialog AS EditOnlyInDialog,
	|	ContactInformationKinds.IsFolder                    AS IsTabularSectionAttribute,
	|	ContactInformationKinds.AdditionalOrderingAttribute    AS AdditionalOrderingAttribute,
	|	ContactInformationKinds.InternationalAddressFormat    AS InternationalAddressFormat,
	|	ISNULL(ContactInformation.IsHistoricalContactInformation, FALSE)    AS IsHistoricalContactInformation,
	|	ISNULL(ContactInformation.Presentation, """")    AS Presentation,
	|	ISNULL(ContactInformation.FieldsValues, """")    AS FieldsValues,
	|	ISNULL(ContactInformation.Value, """")         AS Value,
	|	ISNULL(ContactInformation.ValidFrom, 0)          AS ValidFrom,
	|	ISNULL(ContactInformation.LineNumber, 0)         AS LineNumber,
	|	0 AS ContactLineIdentifier,
	|	CAST("""" AS STRING(200))                        AS AttributeName,
	|	ContactInformationKinds.DeletionMark              AS DeletionMark,
	|	CAST("""" AS STRING)                             AS Comment
	|FROM
	|	Catalog.ContactInformationKinds AS ContactInformationKinds
	|LEFT JOIN
	|	ContactInformation AS ContactInformation
	|ON
	|	ContactInformationKinds.Ref = ContactInformation.Kind
	|WHERE
	|	ContactInformationKinds.Used
	|	AND ISNULL(ContactInformationKinds.Parent.Used, TRUE)
	|	AND (
	|		ContactInformationKinds.Parent = &CIKindsGroup
	|		OR ContactInformationKinds.Parent.Parent = &CIKindsGroup)
	|	AND ContactInformationKinds.Ref NOT IN (&HiddenKinds)
	|ORDER BY
	|	ContactInformationKinds.Ref HIERARCHY
	|";
	
	If HasColumnContactLineIdentifier Then
		QueryText = StrReplace(QueryText, "0 AS ContactLineIdentifier",
			"ISNULL(ContactInformation.ContactLineIdentifier, 0) AS ContactLineIdentifier");
		QueryText = StrReplace(QueryText, "&ContactLineIdentifierCondition",
			"ContactInformation.ContactLineIdentifier = &ContactLineIdentifier");
	Else
		QueryText = StrReplace(QueryText, "&ContactLineIdentifierCondition", "TRUE");
	EndIf;
	
	Query = New Query(QueryText);
	Query.SetParameter("ContactInformationTable", ContactInformation);
	Query.SetParameter("CIKindsGroup", ContactsKindsGroup);
	Query.SetParameter("Owner", ObjectRef);
	Query.SetParameter("HiddenKinds", HiddenKinds);
	
	If HasColumnContactLineIdentifier Then
		If TypeOf(AdditionalParameters) = Type("Structure") And AdditionalParameters.Property("ContactLineIdentifier") Then
			Query.SetParameter("ContactLineIdentifier", AdditionalParameters.ContactLineIdentifier);
		Else
			Query.SetParameter("ContactLineIdentifier", 0);
		EndIf;
	EndIf;
	
	SetPrivilegedMode(True);
	ContactInformation = Query.Execute().Unload(QueryResultIteration.ByGroupsWithHierarchy).Rows;
	SetPrivilegedMode(False);
	
	RowsToDelete = New Array;
	
	// Conversion
	For Each CIRow In ContactInformation Do
		If IsBlankString(CIRow.Value) Then
			If ValueIsFilled(CIRow.Presentation) Then
				
				CIRow.Value = ContactsByPresentation(CIRow.Presentation, CIRow.Type);
				
			Else
				
				If AlwaysShowKinds.Find(CIRow.Kind) = Undefined Then
					
					ExcludedKinds.Add(CIRow.Kind);
					RowsToDelete.Add(CIRow);
					
				EndIf;
				
			EndIf;
		EndIf;
	EndDo;
	
	// Value cache of all contact information kinds of the object.
	ContactsKindsData = ContactsManagerInternal.ContactsKindsData(
		ContactInformation.UnloadColumn("Kind"));

	For Each RowToDelete In RowsToDelete Do
		
		ContactInformation.Delete(RowToDelete);
		
	EndDo;
	
	ContactInformation.Sort("AdditionalOrderingAttribute, LineNumber");
	GenerateContactInformationAttributes(Form, AttributesToAdd, ObjectName, ExcludedKinds, ContactInformation, DeferredInitialization, ObjectIndex);
	
	ContactInformationParameters = ContactsOutputParameters(Form, ItemForPlacementName, TitleLocationContactInformation,
		DeferredInitialization, ExcludedKinds);
	ContactInformationParameters.Owner                     = ObjectRef;
	ContactInformationParameters.AddressParameters.PremiseType = PremiseType;
	
	Filter = New Structure("Type", Enums.ContactInformationTypes.Address);
	AddressCount = ContactInformation.FindRows(Filter).Count();
	
	// Creating form items, filling in the attribute values.
	CreateItems = CommonClientServer.CopyArray(ExcludedKinds);
	PreviousKind = Undefined;
	
	For Each CIRow In ContactInformation Do
		
		If CIRow.IsTabularSectionAttribute Then
			CreateTabularSectionItems(Form, ObjectName, ItemForPlacementName, CIRow, ContactsKindsData);
			Continue;
		EndIf;
		
		If CIRow.DeletionMark AND IsBlankString(CIRow.FieldsValues) AND IsBlankString(CIRow.Value) Then
			Continue;
		EndIf;
		
		ItemIndex     = CreateItems.Find(CIRow.Kind);
		StaticItem = ItemIndex <> Undefined;
		IsNewCIKind      = (CIRow.Kind <> PreviousKind);
		
		If DeferredInitialization Then
			
			AddAttributeToDetails(Form, CIRow, ContactsKindsData, IsNewCIKind,, 
				StaticItem, ItemForPlacementName);
			If StaticItem Then
				CreateItems.Delete(ItemIndex);
			EndIf;
			Continue;
		EndIf;
		
		AddAttributeToDetails(Form, CIRow, ContactsKindsData, IsNewCIKind,, 
			NOT CIRow.IsHistoricalContactInformation, ItemForPlacementName);
		
		If StaticItem Then
			CreateItems.Delete(ItemIndex);
		Else
			
			NextRow = ?(CreateItems.Count() = 0, Undefined,
			DefineNextString(Form, ContactInformation, CIRow));
			
			If NOT CIRow.IsHistoricalContactInformation Then
				AddContactInformationString(Form, CIRow, ItemForPlacementName, IsNewCIKind, AddressCount, NextRow);
			EndIf;
			
		EndIf;
		
		If NOT CIRow.IsHistoricalContactInformation  Then
			PreviousKind = CIRow.Kind;
		EndIf;
		
	EndDo;
	
	For Each ExcludedKind In ExcludedKinds Do
		
		ContactsKindData = ContactsKindsData[ExcludedKind];
		ContactsKindData.Insert("Ref", ExcludedKind);
	
		ContactInformationParameters = FormContactsParameters(Form.ContactInformationParameters, ItemForPlacementName);
		ContactInformationParameters.ItemsToAddList.Add(ContactsKindData, ExcludedKind.Description);
		
	EndDo;
	
	UpdateConextMenu(Form, ItemForPlacementName);
	
	If Not DeferredInitialization 
		AND Form.ContactInformationParameters[ItemForPlacementName].ItemsToAddList.Count() > 0 Then
		AddButtonOfAdditionalContactsField(Form, ItemForPlacementName);
	Else
		AddNoteOnResettingFormSettings(Form, ItemForPlacementName, DeferredInitialization);
	EndIf;
	
EndProcedure

// OnReadAtServer form event handler.
// Called from the module of contact information owner object form upon the subsystem integration.
//
// Parameters:
//    Form - ClientApplicationForm - an owner object form used for displaying contact information.
//    Object - Arbitrary - an owner object of contact information.
//    ItemForPlacementName - String - a group, to which the contact information items will be placed.
//
Procedure OnReadAtServer(Form, Object, ItemForPlacementName = "ContactInformationGroup", ObjectIndex = 0) Export
	
	FormAttributeList = Form.GetAttributes();
	
	FirstRun = True;
	For Each Attribute In FormAttributeList Do
		If Attribute.Name = "ContactInformationParameters" AND TypeOf(Form.ContactInformationParameters) = Type("Structure") Then
			FirstRun = False;
			Break;
		EndIf;
	EndDo;
	
	If FirstRun Then
		Return;
	EndIf;
	
	Parameters = FormContactsParameters(Form.ContactInformationParameters, ItemForPlacementName);
	
	ObjectRef = Object.Ref;
	ObjectMetadata = ObjectRef.Metadata();
	FullMetadataObjectName = ObjectMetadata.FullName();
	CIKindGroupName = StrReplace(FullMetadataObjectName, ".", "");
	CIKindsGroup = Catalogs.ContactInformationKinds[CIKindGroupName];
	ItemForPlacementName = Parameters.GroupForPlacement;
	
	TitleLocationContactInformation = ?(ValueIsFilled(Parameters.TitleLocation), PredefinedValue(Parameters.TitleLocation), FormItemTitleLocation.Left);
	DeferredInitializationExecuted = Parameters.DeferredInitializationExecuted;
	DeferredInitialization = Parameters.DeferredInitialization AND Not DeferredInitializationExecuted;
	
	UsedContacts = Common.ObjectAttributeValue(CIKindsGroup, "Used");
	If UsedContacts = False Then
		AttributesToDeleteArray = Parameters.AddedAttributes;
	Else
		DeleteCommandsAndFormItems(Form, ItemForPlacementName);
		
		AttributesToDeleteArray = New Array;
		ObjectName = Object.Ref.Metadata().Name;
		
		StaticAttributes = CommonClientServer.CopyArray(Parameters.ExcludedKinds);
		NamesOfTabularSectionsByContactsKinds = Undefined;
		
		Filter = New Structure("ItemForPlacementName", ItemForPlacementName);
		ContactInformationAdditionalAttributeDetails = Form.ContactInformationAdditionalAttributeDetails.FindRows(Filter);
		For Each FormAttribute In ContactInformationAdditionalAttributeDetails Do
			
			If FormAttribute.IsTabularSectionAttribute Then
				
				If NamesOfTabularSectionsByContactsKinds = Undefined Then
					Filter = New Structure("IsTabularSectionAttribute", True);
					ContactsKindsOfTabularSection = Form.ContactInformationAdditionalAttributeDetails.Unload(Filter, "Kind");
					NamesOfTabularSectionsByContactsKinds = NamesOfTabularSectionsByContactsKinds(ContactsKindsOfTabularSection, ObjectName);
				EndIf;
				
				TabularSectionName = NamesOfTabularSectionsByContactsKinds[FormAttribute.Kind];
				AttributesToDeleteArray.Add("Object." + TabularSectionName + "." + FormAttribute.AttributeName);
				AttributesToDeleteArray.Add("Object." + TabularSectionName + "." + FormAttribute.AttributeName + "Value");
				
			ElsIf NOT FormAttribute.Property("IsHistoricalContactInformation")
				OR NOT FormAttribute.IsHistoricalContactInformation Then
				
				Index = StaticAttributes.Find(FormAttribute.Kind);
				
				If Index = Undefined Then // Attribute is created dynamically.
					If Not DeferredInitialization AND ValueIsFilled(FormAttribute.AttributeName) Then
						AttributesToDeleteArray.Add(FormAttribute.AttributeName);
					EndIf;
				Else
					StaticAttributes.Delete(Index);
				EndIf;
				
			EndIf;
		EndDo;
		For Each FormAttribute In ContactInformationAdditionalAttributeDetails Do
			Form.ContactInformationAdditionalAttributeDetails.Delete(FormAttribute);
		EndDo;
	EndIf;
	Form.ChangeAttributes(, AttributesToDeleteArray);
	
	CIParameters = New Structure;
	CIParameters.Insert("ItemForPlacementName", ItemForPlacementName);
	CIParameters.Insert("ObjectIndex", ObjectIndex);
	
	If ObjectMetadata.TabularSections.Find("Contacts") <> Undefined Then
		CIParameters.Insert("ContactsKindsGroup", "Catalog.Leads.Contacts");
		CIParameters.Insert("ContactLineIdentifier", ObjectIndex);
	EndIf;
	
	OnCreateAtServer(Form, Object, CIParameters, TitleLocationContactInformation, Parameters.ExcludedKinds, DeferredInitialization);
	Parameters = FormContactsParameters(Form.ContactInformationParameters, ItemForPlacementName);
	Parameters.DeferredInitializationExecuted = DeferredInitializationExecuted;
	
EndProcedure

// AfterWriteAtServer form event handler.
// Called from the module of contact information owner object form upon the subsystem integration.
//
// Parameters:
//    Form - ClientApplicationForm - an owner object form used for displaying contact information.
//    Object - Arbitrary - an owner object of contact information.
//
Procedure AfterWriteAtServer(Form, Object) Export
	
	ObjectName = Object.Ref.Metadata().Name;
	
	// Only for contact information of the tabular section.
	Filter = New Structure("IsTabularSectionAttribute", True);
	TabularSectionRows = Form.ContactInformationAdditionalAttributeDetails.Unload(Filter);
	NamesOfTabularSectionsByContactsKinds = NamesOfTabularSectionsByContactsKinds(TabularSectionRows, ObjectName);
	
	For Each TableRow In TabularSectionRows Do
		InformationKind = TableRow.Kind;
		AttributeName = TableRow.AttributeName;
		FormTabularSection = Form.Object[NamesOfTabularSectionsByContactsKinds[InformationKind]];
		
		For Each FormTabularSectionRow In FormTabularSection Do
			
			Filter = New Structure;
			Filter.Insert("Kind", InformationKind);
			Filter.Insert("ContactLineIdentifier", FormTabularSectionRow.ContactLineIdentifier);
			FoundRows = Object.ContactInformation.FindRows(Filter);
			
			If FoundRows.Count() = 1 Then
				
				CIRow = FoundRows[0];
				FormTabularSectionRow[AttributeName] = CIRow.Presentation;
				FormTabularSectionRow[AttributeName + "FieldsValues"] = CIRow.FieldsValues;
				
			EndIf;
		EndDo;
	EndDo;
	
EndProcedure

// FillCheckProcessingAtServer form event handler.
// Called from the module of contact information owner object form upon the subsystem integration.
//
// Parameters:
//    Form - ClientApplicationForm - an owner object form used for displaying contact information.
//    Object - Arbitrary - an owner object of contact information.
//    Cancel - Boolean - if True, errors were detected during the check.
//
Procedure FillCheckProcessingAtServer(Form, Object, Cancel) Export
	
	ObjectName = Object.Ref.Metadata().Name;
	ErrorsLevel = 0;
	PreviousKind = Undefined;
	
	NamesOfTabularSectionsByContactsKinds = Undefined;
	
	For Each TableRow In Form.ContactInformationAdditionalAttributeDetails Do
		
		InformationKind = TableRow.Kind;
		InformationType = TableRow.Type;
		Comment   = TableRow.Comment;
		AttributeName  = TableRow.AttributeName;
		InformationKindProperty = Common.ObjectAttributesValues(InformationKind, "Mandatory, EditOnlyInDialog");
		Mandatory = InformationKindProperty.Mandatory;
		
		If TableRow.IsTabularSectionAttribute Then
			
			If NamesOfTabularSectionsByContactsKinds = Undefined Then
				Filter = New Structure("IsTabularSectionAttribute", True);
				ContactsKindsOfTabularSection = Form.ContactInformationAdditionalAttributeDetails.Unload(Filter , "Kind");
				NamesOfTabularSectionsByContactsKinds = NamesOfTabularSectionsByContactsKinds(ContactsKindsOfTabularSection, ObjectName);
			EndIf;
			
			TabularSectionName = NamesOfTabularSectionsByContactsKinds[InformationKind];
			FormTabularSection = Form.Object[TabularSectionName];
			
			For Each FormTabularSectionRow In FormTabularSection Do
				
				Presentation = FormTabularSectionRow[AttributeName];
				Field = "Object." + TabularSectionName + "[" + (FormTabularSectionRow.LineNumber - 1) + "]." + AttributeName;
				
				If Mandatory AND IsBlankString(Presentation) AND Not InformationKind.DeletionMark Then
					
					CommonClientServer.MessageToUser(
					StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Поле ""%1"" не заполнено.'; en = 'The ""%1"" field is required.'; pl = 'Pole ""%1"" nie jest wypełnione.';es_ES = 'El ""%1"" campo no está rellenado.';es_CO = 'El ""%1"" campo no está rellenado.';tr = '""%1"" alanı zorunlu.';it = 'Il campo ""%1"" è richiesto.';de = 'Das ""%1"" Feld ist nicht ausgefüllt.'"), InformationKind.Description),,Field);
					CurrentErrorLevel = 2;
					
				Else
					
					Value = FormTabularSectionRow[AttributeName + "Value"];
					
					CurrentErrorLevel = CheckFillingContacts(Presentation, Value, InformationKind,
						InformationType, AttributeName, , Field);
					
					FormTabularSectionRow[AttributeName] = Presentation;
					FormTabularSectionRow[AttributeName + "Value"] = Value;
					
				EndIf;
				
				ErrorsLevel = ?(CurrentErrorLevel > ErrorsLevel, CurrentErrorLevel, ErrorsLevel);
				
			EndDo;
			
		Else
			
			FormItem = Form.Items.Find(AttributeName);
			If FormItem = Undefined Or InformationKind.DeletionMark Then
				Continue; // Item was not created. Deferred initialization was not called.
			EndIf;
			
			If InformationKindProperty.EditOnlyInDialog AND Not ContactsManagerClientServer.ContactsFilledIn(Form[AttributeName]) Then
				Presentation = "";
			Else
				Presentation = Form[AttributeName];
			EndIf;
			
			If InformationKind <> PreviousKind AND Mandatory AND IsBlankString(Presentation)
				AND Not HasOtherStringsFilledWithThisContactInformationKind(Form, TableRow, InformationKind) Then
				// And no other strings with data for contact information kinds with multiple values.
				
				CommonClientServer.MessageToUser(
				StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Поле ""%1"" не заполнено.'; en = 'The ""%1"" field is required.'; pl = 'Pole ""%1"" nie jest wypełnione.';es_ES = 'El ""%1"" campo no está rellenado.';es_CO = 'El ""%1"" campo no está rellenado.';tr = '""%1"" alanı zorunlu.';it = 'Il campo ""%1"" è richiesto.';de = 'Das ""%1"" Feld ist nicht ausgefüllt.'"), InformationKind.Description),,, AttributeName);
				CurrentErrorLevel = 2;
				
			Else
				
				CurrentErrorLevel = CheckFillingContacts(Presentation, TableRow.Value,
					InformationKind, InformationType, AttributeName, Comment);
				
			EndIf;
			
			ErrorsLevel = ?(CurrentErrorLevel > ErrorsLevel, CurrentErrorLevel, ErrorsLevel);
			
		EndIf;
		
		PreviousKind = InformationKind;
		
	EndDo;
	
	If ErrorsLevel <> 0 Then
		Cancel = True;
	EndIf;
	
EndProcedure

// BeforeWriteAtServer form event handler.
// Called from the module of contact information owner object form upon the subsystem integration.
//
// Parameters:
//    Form - ClientApplicationForm - an owner object form used for displaying contact information.
//    Object - Arbitrary - an owner object of contact information.
//    Cancel - Boolean - if True, the object was not written as errors occurred while recording.
//
Procedure BeforeWriteAtServer(Form, Object, Cancel = False, ItemForPlacementName = "") Export
	
	Object.ContactInformation.Clear();
	
	ObjectMetadata = Object.Ref.Metadata();
	MetadataObjectName = ObjectMetadata.Name;
	FullMetadataObjectName = ObjectMetadata.FullName();
	ContactsKindsGroup = ObjectContactsKindsGroup(FullMetadataObjectName);
	NamesOfTabularSectionsByContactsKinds = Undefined;
	FillContactLineIdentifier = ObjectMetadata.TabularSections.Find("Contacts") <> Undefined;
	
	For Each TableRow In Form.ContactInformationAdditionalAttributeDetails Do
		
		InformationKind = TableRow.Kind;
		InformationType = TableRow.Type;
		AttributeName  = TableRow.AttributeName;
		
		If NOT Form.Items.Find(TableRow.AttributeName) = Undefined Then
			Item = Form.Items[TableRow.AttributeName];
			If Item.Type = FormFieldType.LabelField AND Item.Hyperlink Then
				If IsBlankString(TableRow.Presentation)
					OR TableRow.Presentation = ContactsManagerClientServer.EmptyAddressTextAsHiperlink() Then
					Continue;
				EndIf;
			EndIf;
		EndIf;
		
		RestoreEmptyValuePresentation(TableRow);
		
		If TableRow.IsTabularSectionAttribute Then
			
			If NamesOfTabularSectionsByContactsKinds = Undefined Then
				Filter = New Structure("IsTabularSectionAttribute", True);
				ContactsKindsOfTabularSection = Form.ContactInformationAdditionalAttributeDetails.Unload(Filter, "Kind");
				NamesOfTabularSectionsByContactsKinds = NamesOfTabularSectionsByContactsKinds(ContactsKindsOfTabularSection, MetadataObjectName);
			EndIf;
			
			TabularSectionName = NamesOfTabularSectionsByContactsKinds[InformationKind];
			FormTabularSection = Form.Object[TabularSectionName];
			For Each FormTabularSectionRow In FormTabularSection Do
				
				RowID = FormTabularSectionRow.GetID();
				FormTabularSectionRow.ContactLineIdentifier = RowID;
				
				TabularSectionRow = Object[TabularSectionName][FormTabularSectionRow.LineNumber - 1];
				TabularSectionRow.ContactLineIdentifier = RowID;
				
				Value = FormTabularSectionRow[AttributeName + "Value"];
				WriteContactInformation(Object, Value, InformationKind, InformationType, RowID);
				
			EndDo;
			
		ElsIf FillContactLineIdentifier Then
			
			ValidFrom = ?(TableRow.Property("ValidFrom"), TableRow.ValidFrom, Undefined);
			ItemForPlacementName = TableRow.ItemForPlacementName;
			StrLineId = Right(ItemForPlacementName, StrLen(ItemForPlacementName) - StrLen("ContactInformation"));
			LineId = 0;
			If StringFunctionsClientServer.OnlyNumbersInString(StrLineID) Then
				LineId = Number(StrLineId);
			EndIf;
			
			WriteContactInformation(Object, TableRow.Value, InformationKind, InformationType, LineId, ValidFrom);
			
		Else
			If InformationKind.Parent <> ContactsKindsGroup Then
				Continue;
			EndIf;
			
			If ValueIsFilled(ItemForPlacementName) AND TableRow.ItemForPlacementName <> ItemForPlacementName Then
				Continue;
			EndIf;
			
			ValidFrom = ?(TableRow.Property("ValidFrom"), TableRow.ValidFrom, Undefined);
			WriteContactInformation(Object, TableRow.Value, InformationKind, InformationType,, ValidFrom);
		EndIf;
		
	EndDo;
	
EndProcedure

// Adds (deletes) an input field or a comment to a form, updating data.
// Called from the form module of the contact information owner object.
//
// Parameters:
//    Form - ClientApplicationForm - an owner object form used for displaying contact information.
//    Object - Arbitrary - an owner object of contact information.
//    Result - Arbitrary - an optional internal attribute received from the previous event handler.
//
// Returns:
//    Undefined - a value is not used, backward compatibility.
//
Function UpdateContactInformation(Form, Object, Result = Undefined) Export
	
	If Result = Undefined Then
		Return Undefined;
	EndIf;
	
	If Result.Property("IsCommentAddition") Then
		ModifyComment(Form, Result.AttributeName, Result.ItemForPlacementName);
	ElsIf Result.Property("KindToAdd") Then
		AddContactInformationString(Form, Result, Result.ItemForPlacementName);
		
		KindToAdd = Result.KindToAdd.Ref;
		ItemsToAddList = Form.ContactInformationParameters[Result.ItemForPlacementName].ItemsToAddList;
		AlwaysShowKinds = AlwaysShowKinds(Common.ObjectAttributeValue(KindToAdd, "Parent"));
		
		If AlwaysShowKinds.Find(KindToAdd) = Undefined
			And Not Common.ObjectAttributeValue(KindToAdd, "AllowMultipleValueInput") Then
			
			For Each ItemInAddList In ItemsToAddList Do
				If ItemInAddList.Presentation = KindToAdd.Description Then
					ItemsToAddList.Delete(ItemInAddList);
					Break;	
				EndIf;
			EndDo;
			
			If Not Result.Property("UpdateConextMenu") Then
				Result.Insert("UpdateConextMenu", True);
			EndIf;
			
		EndIf;

	ElsIf Result.Property("ReorderItems") Then
		
		Filter = New Structure("AttributeName", Result.FirstItem);
		ContactInformationDetails = Form.ContactInformationAdditionalAttributeDetails;
		FirstItem = ContactInformationDetails.FindRows(Filter)[0];
		Filter = New Structure("AttributeName", Result.SecondItem);
		SecondItem = ContactInformationDetails.FindRows(Filter)[0];
		
		TransferPropertyList = "Comment,Presentation,Value";
		TemporaryBuffer = New Structure(TransferPropertyList);
		
		FillPropertyValues(TemporaryBuffer, FirstItem);
		FillPropertyValues(FirstItem, SecondItem, TransferPropertyList);
		FillPropertyValues(SecondItem, TemporaryBuffer);
		
		Form[Result.FirstItem] = FirstItem.Presentation;
		Form[Result.SecondItem] = SecondItem.Presentation;
		
		Form.Items[Result.FirstItem].ExtendedTooltip.Title = FirstItem.Comment;
		Form.Items[Result.SecondItem].ExtendedTooltip.Title = SecondItem.Comment;
		
	EndIf;
	
	If Result.Property("UpdateConextMenu") Then
		If Result.Property("ItemForPlacementName") Then
			UpdateConextMenu(Form, Result.ItemForPlacementName);
			
			If Result.Property("AttributeName") Then
				ContactInformationDetails = Form.ContactInformationAdditionalAttributeDetails;
				Filter = New Structure("AttributeName", Result.AttributeName);
				FoundRow = ContactInformationDetails.FindRows(Filter)[0];
				If ContactsManagerClientServer.IsJSONContactInformation(FoundRow.Value) Then
					ContactsByFields = ContactsManagerInternal.JSONStringToStructure(FoundRow.Value);
					ContactsByFields.Comment = ?(Result.Property("Comment"), Result.Comment, "");
					FoundRow.Value = ContactsManagerInternal.ToJSONStringStructure(ContactsByFields);
				EndIf;
			EndIf;
			
		Else
			For each PlacementItemName In Form.ContactInformationParameters Do
				UpdateConextMenu(Form, PlacementItemName.Key);
			EndDo;
		EndIf;
	EndIf;
	
	Return Undefined;
	
EndFunction

// FillingProcessing event subscription handler.
//
// Parameters:
//  Source - Arbitrary - an object containing contact information.
//  FillingData - Structure - data with contact information to fill in the object.
//  FillingText - String - not used.
//  StandardProcessing - Boolean - not used.
//
Procedure FillContactInformationProcessing(Source, FillingData, FillingText, StandardProcessing) Export
	
	ObjectContactInformationFilling(Source, FillingData);
	
EndProcedure

// The BeforeWrite event subscription handler for updating contact information for lists.
//
// Parameters:
//  Object - Arbitrary - an object containing contact information.
//  Cancel - Boolean - not used, backward compatibility.
//
Procedure ProcessingContactsUpdating(Object, Cancel) Export
	
	If Object.DataExchange.Load Then
		Return;
	EndIf;
	
	UpdateContactInformationForLists(Object);
	
EndProcedure

// FillingProcessing event subscription handler for documents.
//
// Parameters:
//  Source - Arbitrary - an object containing contact information.
//  FillingData - Structure - data with contact information to fill in the object.
//  FillingText - String, Undefined - filling data of the Description attribute.
//  StandardProcessing - Boolean - not used.
//
Procedure DocumentContactInformationFilling(Source, FillingData, FillingText, StandardProcessing) Export
	
	ObjectContactInformationFilling(Source, FillingData);
	
EndProcedure

// Executes deferred initialization of attributes and contact information items.
//
// Parameters:
//  Form - ClientApplicationForm - an owner object form used for displaying contact information.
//  Object - Arbitrary - an owner object of contact information.
//  ItemForPlacementName - String - a group name where the contact information is placed.
//
Procedure ExecuteDeferredInitialization(Form, Object, ItemForPlacementName = "ContactInformationGroup") Export
	
	ContactInformationStub = Form.Items.Find("ContactInformationStub"); // temporary item
	If ContactInformationStub <> Undefined Then
		Form.Items.Delete(ContactInformationStub);
	EndIf;
	
	ContactInformationParameters = FormContactsParameters(Form.ContactInformationParameters, ItemForPlacementName);
	
	ContactInformationAdditionalAttributeDetails = Form.ContactInformationAdditionalAttributeDetails.Unload(, "Kind, Presentation, Value, Comment");
	Form.ContactInformationAdditionalAttributeDetails.Clear();
	
	TitleLocationContactInformation = ?(ValueIsFilled(ContactInformationParameters.TitleLocation), PredefinedValue(ContactInformationParameters.TitleLocation), FormItemTitleLocation.Left);
	OnCreateAtServer(Form, Object, ItemForPlacementName, TitleLocationContactInformation, ContactInformationParameters.ExcludedKinds);
	ContactInformationParameters = FormContactsParameters(Form.ContactInformationParameters, ItemForPlacementName);
	
	For Each ContactInformationKind In ContactInformationParameters.ExcludedKinds Do
		
		Filter = New Structure("Kind", ContactInformationKind);
		RowsArray = Form.ContactInformationAdditionalAttributeDetails.FindRows(Filter);
		
		If RowsArray.Count() > 0 Then
			SavedValue = ContactInformationAdditionalAttributeDetails.FindRows(Filter)[0];
			CurrentValue = RowsArray[0];
			FillPropertyValues(CurrentValue, SavedValue);
			Form[CurrentValue.AttributeName] = SavedValue.Presentation;
		EndIf;
	EndDo;
	
	If Form.Items.Find("EmptyDecorationContactInformation") <> Undefined Then
		Form.Items.EmptyDecorationContactInformation.Visible = False;
	EndIf;
	
	ContactInformationParameters.DeferredInitializationExecuted = True;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Auxiliary functions and constructors.

// Returns a reference to a contact information kind.
// If a kind is not found by name, then the search is executed by names of predefined items.
//
// Parameters:
//  Name - String - a unique name of a contact information kind.
// 
// Returns:
//  CatalogRef.ContactInformationKinds - a reference to an item of the contact information kind catalog.
//
Function ContactInformationKindByName(Name) Export
	
	Kind = Undefined;
	If Not InfobaseUpdate.InfobaseUpdateInProgress() Then
		Kinds = ContactInformationManagementInternalCached.ContactInformationKindsByName();
		Kind = Kinds.Get(Name);
	Else
		Kinds = PredefinedContactInformationKinds(Name);
		If Kinds.Count() > 0 Then
			Kind = Kinds[0].Ref;
		EndIf;
	EndIf;
	
	If Kind <> Undefined Then
		Return Kind;
	EndIf;
	
	Return Catalogs.ContactInformationKinds[Name];
	
EndFunction

// Details of contact information parameters used in the OnCreateAtServer handler.
// 
// Returns:
//  Structure - contact information parameters.
//   * ZipCode - String - an address postal code.
//   * Country - String - an address country.
//   * PremiseType             - String - a description of premise type that will be set in the 
//                                         address input form. Apartment by default.
//   * ItemForPlacementName - String - a group, to which the contact information items will be placed.
//   * ExcludedKinds - Array - contact information kinds that do not need to be displayed on the form.
//   * HiddenKinds - Array - contact information kinds that do not need to be displayed on the form.
//   * DeferredInitialization - Boolean - if True, generation of contact information fields on the form will be deferred.
//   * ContactsTitleLocation - FormItemTitleLocation - can take the following values:
//                                                             FormItemTitleLocation.Top or
//                                                             FormItemTitleLocation.Left (by default).
//
Function ContactInformationParameters() Export

	Result = New Structure;
	Result.Insert("PremiseType", "Apartment");
	Result.Insert("IndexOf", Undefined);
	Result.Insert("Country", Undefined);
	Result.Insert("DeferredInitialization", False);
	Result.Insert("TitleLocationContactInformation", "");
	Result.Insert("ExcludedKinds", Undefined);
	Result.Insert("HiddenKinds", Undefined);
	Result.Insert("ItemForPlacementName", "ContactInformationGroup");
	
	Return Result;

EndFunction 

////////////////////////////////////////////////////////////////////////////////
// Check and information about the address

// Checks contact information.
//
// Parameters:
//  Presentation - String - a contact information presentation. Used if it is impossible to 
//                           determine a presentation based on the FieldsValues parameter (the Presentation field is not available).
//  FieldsValues - String, Structure, Map, ValueList - details of contact information fields.
//  InformationKind - CatalogRef.ContactsKinds - used for determining a type if it cannot by 
//                                                               determined by the FieldsValues parameter.
//  InformationType - EnumRef.ContactsTypes - a contacts type.
//  AttributeName - String - an attribute name on the form.
//  Comment - String - a comment text.
//  PathToAttribute - String - a path to the attribute.
// 
// Returns:
//  Number - an error level, 0 - no errors.
//
Function ValidateContactInformation(Presentation, FieldsValues, InformationKind, InformationType,
	AttributeName, Comment = Undefined, AttributePath = "") Export
	
	SerializationText = ?(IsBlankString(FieldsValues), Presentation, FieldsValues);

	If ContactsManagerClientServer.IsXMLContactInformation(SerializationText) Then
		CIObject = ContactInformationInJSON(SerializationText);
	Else
		CIObject = FieldsValues;
	EndIf;
	
	// CheckSSL
	If InformationType = Enums.ContactInformationTypes.EmailAddress Then
		ErrorsLevel = EmailFIllingErrors(CIObject, InformationKind, AttributeName, AttributePath);
	ElsIf InformationType = Enums.ContactInformationTypes.Address Then
		ErrorsLevel = AddressFillErrors(CIObject, InformationKind, AttributeName);
	ElsIf InformationType = Enums.ContactInformationTypes.Phone Then
		ErrorsLevel = PhoneFillingErrors(CIObject, InformationKind, AttributeName);
	ElsIf InformationType = Enums.ContactInformationTypes.Fax Then
		ErrorsLevel = PhoneFillingErrors(CIObject, InformationKind, AttributeName);
	ElsIf InformationType = Enums.ContactInformationTypes.WebPage Then
		ErrorsLevel = WebpageFillingErrors(CIObject, InformationKind, AttributeName);
	Else
		// No other checks are made.
		ErrorsLevel = 0;
	EndIf;
	
	Return ErrorsLevel;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Updating an infobase.

// Sets properties of a contact information kind.
// Note. When using the Order parameter, make sure that the assigned values are unique.
//  If any non-unique order values are identified in this same group after update, users cannot 
//  further edit order values.
//  Generally, it is recommend that you do not use this parameter (the order will not change) or set it to 0
//  (in this case, the order will be assigned automatically in the Item ordering subsystem upon the procedure execution).
//  To reassign several contacts kinds in a given relative order without moving them to the 
//  beginning of the list, you only need to call the procedure in sequence for each required contacts kind (with order value set to 0).
//  If a predefined contact information kind is added to the infobase, do not assign its order explicitly.
//
// Parameters:
//    Parameters - Structure - contains a structure with the following fields:
//        * Kind - Reference - CatalogRef.ContactsKinds, String -  a reference to the contacts kind 
//                                                                      or a predefined item ID.
//        * Type - EnumRef.ContactsTypees - a type of contacts or its ID.
//                                                                      
//        * Order - Number, Undefined - contact information kind order, a relative position in the 
//                                                                      list:
//                                                                          Undefined - do not reassign;
//                                                                          0 - assign automatically;
//                                                                          Number > 0 - assign the specified order.
//        * CanChangeEditingMethod - Boolean - True if you can change the editing method only in the 
//                                                                      dialog box, otherwise, False.
//        * EditingOnlyInDialogBox - Boolean - True if data can only be edited in the dialog box,
//                                                                      otherwise, False.
//        * Mandatory - Boolean - True if the field is mandatory, False - otherwise.
//                                                                      
//        * AllowMultipleValuesInput - Boolean - indicates whether additional input fields are used 
//                                                                      for this kind.
//        * DenyEditingByUser - Boolean - indicates that editing of contact information kind 
//                                                                      properties by a user is 
//                                                                      unavailable.
//        * StoreChangeHistory - Boolean - a flag of storing the history of contacts kinds changes.
//                                                                      
//                                                                      Default value is False.
//        * IsInUse - Boolean - a flag shows whether contacts kind is used.
//                                                                      Default value is True.
//        * FieldKindOther - String - appearance of the Other type field. Possible values:
//                                                                      MultilineWide, SingleLineWide, SingleLineNarrow.
//                                                                      The default value is SingleLineWide.
//        * ValidationSettings - Structure, Undefined - validation settings of a contact information kind.
//            For the Address type - a structure containing the following fields:
//                * OnlyNationalAddres - Boolean - True if you can enter only local addresses.
//                * CheckValidity - Boolean - True if it is required to prevent the user from saving
//                * ProhibitInvalidEntry - Boolean - obsolete. All passed values are ignored.
//                                                          To prevent users from saving incorrect 
//                                                          addresses, use the CheckValidity parameter.
//                * HideObsoleteAddress   - Boolean - if True, hide obsolete addresses during input 
//                                                          (only if OnlyNationalAddress = True).
//                * IncludeCountryInPresentation - Boolean - True if the country description must be 
//                                                          included in the address presentation.
//            For the EmailAddress type - a structure containing the following fields:
//                * CheckValidity - Boolean - True if it is required to prevent users from saving an 
//                                                          incorrect email address.
//                * ProhibitInvalidEntry - Boolean - obsolete. All passed values are ignored.
//                                                          To prevent users from saving incorrect 
//                                                          addresses, use the CheckValidity parameter.
//            For any other types and default settings, Undefined is used.
//
Procedure SetContactInformationKindProperties(Parameters) Export
	
	If TypeOf(Parameters.Kind) = Type("String") Then
		Object = Catalogs.ContactInformationKinds[Parameters.Kind].GetObject();
	Else
		Object = Parameters.Kind.GetObject();
	EndIf;
	
	Object.Type                                  = Parameters.Type;
	Object.CanChangeEditMethod    = Parameters.CanChangeEditMethod;
	Object.EditOnlyInDialog         = Parameters.EditOnlyInDialog;
	Object.Mandatory               = Parameters.Mandatory;
	Object.AllowMultipleValueInput      = Parameters.AllowMultipleValueInput;
	Object.DenayEditingByUser = Parameters.DenayEditingByUser;
	Object.Used                         = Parameters.Used;
	Object.StoreChangeHistory              = Parameters.StoreChangeHistory;
	Object.InternationalAddressFormat            = Parameters.InternationalAddressFormat;
	
	If Parameters.Type = Enums.ContactInformationTypes.Other Then
		Object.FieldKindOther = Parameters.FieldKindOther;
	EndIf;
	
	ValidationSettings = Parameters.ValidationSettings;
	ValidateSettings = TypeOf(ValidationSettings) = Type("Structure");
	
	If ValidateSettings AND Parameters.Type = Enums.ContactInformationTypes.Address Then
		FillPropertyValues(Object, ValidationSettings);
	ElsIf ValidateSettings AND Parameters.Type = Enums.ContactInformationTypes.EmailAddress Then
		SetValidationAttributeValues(Object, ValidationSettings);
	ElsIf ValidateSettings AND Parameters.Type = Enums.ContactInformationTypes.Phone Then
		Object.PhoneWithExtension = ValidationSettings.PhoneWithExtension;
	Else
		SetValidationAttributeValues(Object);
	EndIf;
	
	Result = ContactsManagerInternal.CheckContactsKindParameters(Object);
	
	If Result.HasErrors Then
		Raise Result.ErrorText;
	EndIf;
	
	If Parameters.Order <> Undefined Then
		Object.AdditionalOrderingAttribute = Parameters.Order;
	EndIf;
	
	InfobaseUpdate.WriteData(Object);
	
EndProcedure

// Returns a structure of contact information kind parameters for a particular type.
// 
// Parameters:
//    Type - EnumRef.ContactsTypes, String - a type of contacts for filling the ValidationSettings 
//                                                                properties.
// 
// Returns:
//    Structure - contains a structure with the following fields:
//        * Kind - Reference - CatalogRef.ContactsKinds, String -  a reference to the contacts kind 
//                                                                      or a predefined item ID.
//        * Type - EnumRef.ContactsTypees - a type of contacts or its ID.
//                                                                      
//        * Order - Number, Undefined - contact information kind order, a relative position in the 
//                                                                      list:
//                                                                          Undefined - do not reassign;
//                                                                          0 - assign automatically;
//                                                                          Number > 0 - assign the specified order.
//        * CanChangeEditingMethod - Boolean - True if you can change the editing method only in the 
//                                                                      dialog box, otherwise, False.
//        * EditingOnlyInDialogBox - Boolean - True if data can only be edited in the dialog box,
//                                                                      otherwise, False.
//        * Mandatory - Boolean - True if the field is mandatory, False - otherwise.
//                                                                      
//        * AllowMultipleValuesInput - Boolean - indicates whether additional input fields are used 
//                                                                      for this kind.
//        * DenyEditingByUser - Boolean - indicates that editing of contact information kind 
//                                                                      properties by a user is 
//                                                                      unavailable.
//        * IsInUse - Boolean - a flag shows whether contacts kind is used.
//                                                                      Default value is True.
//        * ValidationSettings - Structure, Undefined - validation settings of a contact information kind.
//            For the Address type - a structure containing the following fields:
//                * OnlyNationalAddres - Boolean - True if you can enter only local addresses.
//                * CheckValidity - Boolean - True if it is required to prevent users from saving an 
//                                                          incorrect address (if OnlyNationalAddress = True).
//                * HideObsoleteAddress   - Boolean - if True, hide obsolete addresses during input 
//                                                          (only if OnlyNationalAddress = True).
//                * IncludeCountryInPresentation - Boolean - True if the country description must be 
//                                                          included in the address presentation.
//            For the EmailAddress type - a structure containing the following fields:
//                * CheckValidity - Boolean - True if it is required to prevent users from saving an 
//                                                          incorrect email address.
//            For any other types and default settings, Undefined is used.
//
Function ContactInformationKindParameters(Type = Undefined) Export
	
	If TypeOf(Type) = Type("String") Then
		TypeToSet = Enums.ContactInformationTypes[Type];
	Else
		TypeToSet = Type;
	EndIf;
	
	KindParameters = New Structure;
	KindParameters.Insert("Kind");
	KindParameters.Insert("Type", TypeToSet);
	KindParameters.Insert("Order");
	KindParameters.Insert("CanChangeEditMethod", False);
	KindParameters.Insert("EditOnlyInDialog", False);
	KindParameters.Insert("Mandatory", False);
	KindParameters.Insert("AllowMultipleValueInput", False);
	KindParameters.Insert("DenayEditingByUser", False);
	KindParameters.Insert("StoreChangeHistory", False);
	KindParameters.Insert("InternationalAddressFormat", False);
	KindParameters.Insert("Used", True);
	
	If TypeToSet = Enums.ContactInformationTypes.Address Then
		ValidationSettings = New Structure;
		ValidationSettings.Insert("OnlyNationalAddress", False);
		ValidationSettings.Insert("CheckValidity", False);
		ValidationSettings.Insert("HideObsoleteAddresses", False);
		ValidationSettings.Insert("CheckByFIAS", True);
		ValidationSettings.Insert("IncludeCountryInPresentation", False);
		ValidationSettings.Insert("SpecifyRNCMT", False);
	ElsIf TypeToSet = Enums.ContactInformationTypes.EmailAddress Then
		ValidationSettings = New Structure;
		ValidationSettings.Insert("CheckValidity", False);
	ElsIf TypeToSet = Enums.ContactInformationTypes.Phone Then
		ValidationSettings = New Structure;
		ValidationSettings.Insert("PhoneWithExtension", True);
	Else
		If TypeToSet = Enums.ContactInformationTypes.Other Then
			KindParameters.Insert("FieldKindOther", "SingleLineWide");
		EndIf;
		ValidationSettings = Undefined;
	EndIf;
	
	KindParameters.Insert("ValidationSettings", ValidationSettings);
	
	Return KindParameters;
	
EndFunction

// Writes contact information from XML to the fields of the Object contact information tabular section.
//
// Parameters:
//    Object - AnyRef - a reference to the configuration object containing contact information tabular section.
//    Value - String - contact information in the internal JSON format.
//    InformationKind - Catalog.ContactsKinds - a reference to a contacts kind.
//    InformationType - Enumeration.ContactsTypes - a contacts type.
//    RowID - Number - a row ID of the tabular section.
//    Date - Date - the date, from which contact information record is valid, used for storing the 
//                  history of contact information changes.
Procedure WriteContactInformation(Object, Val Value, InformationKind, InformationType, RowID = 0, Date = Undefined) Export
	
	If IsBlankString(Value) Then
		Return;
	EndIf;
	
	If ContactsManagerClientServer.IsXMLContactInformation(Value) Then
		CIObject = ContactsManagerInternal.ContactInformationToJSONStructure(Value, InformationType);
	Else
		CIObject = ContactsManagerInternal.JSONStringToStructure(Value);
	EndIf;
	
	If Not ContactsManagerInternal.ContactsFilledIn(CIObject) Then
		Return;
	EndIf;
	
	NewRow = Object.ContactInformation.Add();
	NewRow.Presentation = CIObject.Value;
	NewRow.Value      = ContactsManagerInternal.ToJSONStringStructure(CIObject);
	NewRow.FieldsValues = ContactsManagerInternal.ContactsFromJSONToXML(CIObject, InformationType);
	NewRow.Kind           = InformationKind;
	NewRow.Type           = InformationType;
	If ValueIsFilled(Date) Then
		NewRow.ValidFrom    = Date;
	EndIf;
	
	If ValueIsFilled(RowID) Then
		NewRow.ContactLineIdentifier = RowID;
	EndIf;
	
	// Filling in additional attributes of the tabular section.
	FillContactsTechnicalFields(NewRow, CIObject, InformationType);
	
EndProcedure

// Updates a presentation in the KindForList aggregate field for displaying in contact information, 
//  dynamic lists, and reports.
//
// Parameters:
//  Object - ObjectRef - a reference to the configuration object containing the contact information tabular section.
//
Procedure UpdateContactInformationForLists(Object = Undefined) Export
	
	If Object = Undefined Then
		ContactsManagerInternal.UpdateContactInformationForLists();
	Else
		If Object.Metadata().TabularSections.ContactInformation.Attributes.Find("KindForList") <> Undefined Then
			ContactsManagerInternal.UpdateCotactsForListsForObject(Object);
		EndIf;
	EndIf;
	
EndProcedure

// Executes deferred update of contact information for lists.
//
// Parameters:
//  Parameters	 - Structure - update handler parameters.
//  BatchSize - Number - an optional parameter of batch size of data being processed in one startup.
//
Procedure UpdateContactsForListDeferred(Parameters, BatchSize = 1000) Export
	
	ObjectsWithKindForList = Undefined;
	Parameters.Property("ObjectsWithKindForList", ObjectsWithKindForList);
	
	If Parameters.ExecutionProgress.TotalObjectCount = 0 Then
		// calculating quantity
		Query = New Query;
		Query.Text = 
		"SELECT
		|	ContactInformationKinds.Ref,
		|	ContactInformationKinds.PredefinedDataName
		|FROM
		|	Catalog.ContactInformationKinds AS ContactInformationKinds
		|WHERE
		|	ContactInformationKinds.IsFolder = TRUE";
		
		QueryResult = Query.Execute();
		DetailedRecordsSelection = QueryResult.Select();
		ObjectsWithKindForList = New Array;
		QueryText = "";
		Separator = "";
		
		QueryTemplate = "SELECT
		| COUNT(TableWithContactInformation.Ref) AS Count,
		| VALUETYPE(TableWithContactInformation.Ref) AS Ref
		|FROM
		| %1.%2 AS TableWithContactInformation
		| GROUP BY
		|	VALUETYPE(TableWithContactInformation.Ref)";
		
		While DetailedRecordsSelection.Next() Do
			If StrStartsWith(DetailedRecordsSelection.PredefinedDataName, "Catalog") Then
				ObjectName = Mid(DetailedRecordsSelection.PredefinedDataName, 11);
				
				If Metadata.Catalogs.Find(ObjectName) <> Undefined Then
					ContactInformation = Metadata.Catalogs[ObjectName].TabularSections.ContactInformation;
					If ContactInformation.Attributes.Find("KindForList") <> Undefined Then
						QueryText = QueryText + Separator + StringFunctionsClientServer.SubstituteParametersToString(QueryTemplate, "Catalog", ObjectName);
						Separator = " UNION ALL ";
					EndIf;
				EndIf;
			ElsIf StrStartsWith(DetailedRecordsSelection.PredefinedDataName, "Document") Then
				ObjectName = Mid(DetailedRecordsSelection.PredefinedDataName, 9);
				
				If Metadata.Documents.Find(ObjectName) <> Undefined Then
					ContactInformation = Metadata.Documents[ObjectName].TabularSections.ContactInformation;
					If ContactInformation.Attributes.Find("KindForList") <> Undefined Then
						QueryText = QueryText + Separator + StringFunctionsClientServer.SubstituteParametersToString(QueryTemplate, "Document", ObjectName);
						Separator = " UNION ALL ";
					EndIf;
				EndIf;
			EndIf;
		EndDo;
		
		If IsBlankString(QueryText) Then
			Parameters.ProcessingCompleted = False;
			Return;
		EndIf;
		Query = New Query(QueryText);
		QueryResult = Query.Execute().Select();
		Count = 0;
		ObjectsWithKindForList = New Array;
		While QueryResult.Next() Do
			Count = Count + QueryResult.Count;
			ObjectsWithKindForList.Add(QueryResult.Ref);
		EndDo;
		Parameters.ExecutionProgress.TotalObjectCount = Count;
		Parameters.Insert("ObjectsWithKindForList", ObjectsWithKindForList);
	EndIf;
	
	If ObjectsWithKindForList = Undefined OR ObjectsWithKindForList.Count() = 0 Then
		Return;
	EndIf;
	
	FullObjectNameWithKindForList = Metadata.FindByType(ObjectsWithKindForList.Get(0)).FullName();
	QueryText = " SELECT TOP " + Format(BatchSize, "NG=0") + "
	|	ContactInformation.Ref AS Ref
	|FROM
	|	" + FullObjectNameWithKindForList + ".ContactInformation AS ContactInformation
	|
	|GROUP BY
	|	ContactInformation.Ref
	|
	|HAVING
	|	SUM(CASE
	|			WHEN ContactInformation.KindForList = VALUE(Catalog.ContactInformationKinds.EmptyRef)
	|				THEN 0
	|				ELSE 1
	|		END) = 0";
	
	Query = New Query(QueryText);
	QueryResult = Query.Execute().Select();
	Count = QueryResult.Count();
	If Count > 0 Then
		While QueryResult.Next() Do
			Object = QueryResult.Ref.GetObject();
			UpdateContactInformationForLists(Object);
			InfobaseUpdate.WriteData(Object);
		EndDo;
		If Count < 1000 Then
			ObjectsWithKindForList.Delete(0);
		EndIf;
		Parameters.ExecutionProgress.ProcessedObjectsCount = Parameters.ExecutionProgress.ProcessedObjectsCount + Count;
	Else
		ObjectsWithKindForList.Delete(0);
	EndIf;
	
	If ObjectsWithKindForList.Count() > 0 Then
		Parameters.ProcessingCompleted = False;
	EndIf;
	
	Parameters.Insert("ObjectsWithKindForList", ObjectsWithKindForList);
	
EndProcedure

#Region ObsoleteProceduresAndFunctions

////////////////////////////////////////////////////////////////////////////////
// Backward compatibility.

// Obsolete. Use ContactsControl.ContactsByPresentation instead.
// Converts a contact information presentation into an XML string matching the structure
// of XDTO packages ContactInformation and Address.
// Correct conversion is not guaranteed for the addresses entered in free form.
//
// Parameters:
//    Presentatin - String - a string presentation of contact information displayed to a user.
//    ExpectedKind - CatalogRef.ContactsKinds, EnumRef.ContactsTypes,
//                      Structure - a kind or a type of contact information.
//
// Returns:
//   String - contact information in the XML format matching the structure of the XDTO packages ContactInformation and Address.
//
Function ContactsXMLByPresentation(Presentation, ExpectedKind) Export
	
	Return ContactsManagerInternal.XDTOContactsInXML(
	ContactsManagerInternal.XDTOContactsByPresentation(Presentation, ExpectedKind));
	
EndFunction

// Obsolete. Use AddressManager.PreviousFormatOfContactXML instead.
// Converts XML data to the previous contact information format.
//
// Parameters:
//    Data - String - contact information XML.
//    ShortFieldsComposition - Boolean - if False, fields missing in SSL versions earlier than 2.1.3 
//                                      are excluded from the fields composition.
//
// Returns:
//    String - a set of key-value pairs separated by line breaks.
//
Function PreviousContactInformationXMLFormat(Val Data, Val ShortFieldsComposition = False) Export
	
	If Metadata.CommonModules.Find("AddressManager") <> Undefined Then
		ModuleAddressManager = Common.CommonModule("AddressManager");
		Return ModuleAddressManager.PreviousContactInformationXMLFormat(Data, ShortFieldsComposition);
	EndIf;
	
	Return "";
	
EndFunction

// Obsolete. Use AddressManager.AddressInfo.PreviousContactsXMLStructure instead.
// Converts data of a new contact information XML format to the structure of the old format.
//
// Parameters:
//   Data - String - contact information XML or a key-value pair.
//   ContactsKind - CatalogRef.ContactsKind, Structure - contacts parameters.
//
// Returns:
//   Structure - a set of key-value pairs. Composition of properties for the address:
//        ** Country           - String - a text presentation of a country.
//        ** CountryCode - String - an ARCC country code.
//        ** ZipCode           - String - a postal code (only for local addresses).
//        ** State - String - a text presentation of the state (only for local addresses).
//        ** StateCode       - String - a code of a local state (only for local addresses).
//        ** StateShortForm - String - a short form of "state" (if OldFieldsComposition = False).
//        ** District - String - a text presentation of a district (only for local addresses).
//        ** DistrictShortForm - String - a short form of "district" (if OldFieldsComposition = False).
//        ** City - String - a text presentation of a city (only for local addresses).
//        ** CityShortForm - String - a short form of "city" (only for local addresses).
//        ** Locality  - String - a presentation of a locality (only for local addresses).
//        ** LocalityShortForm - String - a short form of "locality" (if OldFieldsComposition = False).
//        ** Street - String - a text presentation of a street (only for local addresses).
//        ** StreetShortForm - String - a short form of "street" (if OldFieldsComposition = False).
//        ** HouseType - String - see AddressManagerClientServer.TypeOfAddressingObjectOfRFAddress(). 
//        ** House - String - a text presentation of a house (only for local addresses).
//        ** BlockType - String - see AddressManagerClientServer.TypeOfAddressingObjectOfRFAddress(). 
//        ** Block - String - text presentation of a block (only for local addresses).
//        ** ApartmentType - String - see AddressManagerClientServer. TypeOfAddressingObjectOfRFAddress().
//        ** Apartment - String - a text presentation of an apartment (only for local addresses).
//       Composition of properties for a phone:
//        ** CountryCode        - String - a country code. For example, +7.
//        ** CityCode        - String - a city code. For example, 495.
//        ** PhoneNumber    - String - a phone number.
//        ** Additional       - String - an additional phone number.
//
Function PreviousContactInformationXMLStructure(Val Data, Val ContactInformationKind = Undefined) Export
	
	If Metadata.CommonModules.Find("AddressManager") <> Undefined Then
		ModuleAddressManager = Common.CommonModule("AddressManager");
		Return ModuleAddressManager.PreviousContactInformationXMLStructure(Data, ContactInformationKind);
	EndIf;
	
	Return New Structure;
	
EndFunction

// Obsolete. Use AddressManager.AddressInARCAFormat instead.
// Converts addresses of a new FIAS XML format to addresses of the ARCA format.
//
// Parameters:
//   Data - String - contact information XML or a key-value pair.
//
// Returns:
//   Structure - a set of key-value pairs. Composition of properties for the address:
//        ** Country           - String - a text presentation of a country.
//        ** CountryCode - String - an ARCC country code.
//        ** ZipCode           - String - a postal code (only for local addresses).
//        ** State - String - a text presentation of the state (only for local addresses).
//        ** StateCode       - String - a code of a local state (only for local addresses).
//        ** StateShortForm - String - a short form of "state" (if OldFieldsComposition = False).
//        ** District - String - a text presentation of a district (only for local addresses).
//        ** DistrictShortForm - String - a short form of "district" (if OldFieldsComposition = False).
//        ** City - String - a text presentation of a city (only for local addresses).
//        ** CityShortForm - String - a short form of "city" (only for local addresses).
//        ** Locality  - String - a presentation of a locality (only for local addresses).
//        ** LocalityShortForm - String - a short form of "locality" (if OldFieldsComposition = False).
//        ** Street - String - a text presentation of a street (only for local addresses).
//        ** StreetShortForm - String - a short form of "street" (if OldFieldsComposition = False).
//        ** HouseType - String - see AddressManagerClientServer.TypeOfAddressingObjectOfRFAddress. 
//        ** House - String - a text presentation of a house (only for local addresses).
//        ** BlockType - String - see AddressManagerClientServer.TypeOfAddressingObjectOfRFAddress. 
//        ** Block - String - text presentation of a block (only for local addresses).
//        ** ApartmentType - String - see AddressManagerClientServer. TypeOfAddressingObjectOfRFAddress.
//        ** Apartment - String - a text presentation of an apartment (only for local addresses).
//        ** LocalAddress          - Boolean - if True, it is a local address.
//        ** Presentation - String - text presentation of an address .
//
Function AddressInARCAFormat(Val Data) Export
	
	If Metadata.CommonModules.Find("AddressManager") <> Undefined Then
		ModuleAddressManager = Common.CommonModule("AddressManager");
		Return ModuleAddressManager.AddressInARCAFormat(Data);
	EndIf;
	
	Return New Structure;
	
EndFunction

// Obsolete. Use AddressManager.AddressInfo instead.
// Returns address info as a structure of address parts and ARCA codes.
//
// Parameters:
//   Address - Array - XDTO objects or XML string of contacts.
//   AdditionalParameters - Structure - contacts parameters.
//       * WithoutPresentation - Boolean - if True, the Address presentation field will not be displayed.
//       * ARCACodes - Boolean - if True, it returns the structure with ARCA codes for all address parts.
//       * ShortFormsFullDescription - Boolean - if True, the full description of address objects is returned.
//       * DescriptionIncludesShortForm - Boolean - if True, the descriptions of address objects contain their short forms.
// Returns:
//   Array - contains structures array, structure content, see details of the AddressManager.AddressInfo function.
//
Function AddressesInfo(Addresses, AdditionalParameters = Undefined) Export
	
	If Metadata.CommonModules.Find("AddressManager") <> Undefined Then
		ModuleAddressManager = Common.CommonModule("AddressManager");
		Return ModuleAddressManager.AddressesInfo(Addresses, AdditionalParameters);
	EndIf;
	
	Return New Array;
	
EndFunction

// Obsolete. Use AddressManager.AddressInfo.
// Returns address info as a structure of address parts and ARCA codes.
//
// Parameters:
//   Address - String, XDTOObject - XDTO object or XML string of contacts.
//   AdditionalParameters - Structure - contacts parameters.
//       * WithoutPresentation - Boolean - if True, the Address presentation field will not be displayed.
//       * ARCACodes - Boolean - if True, it returns the structure with ARCA codes for all address parts.
//       * ShortFormsFullDescription - Boolean - if True, the full description of address objects is returned.
//       * DescriptionIncludesShortForm - Boolean - if True, the descriptions of address objects contain their short forms.
// Returns:
//   Structure - a set of key-value pairs. Composition of properties for the address:
//        * Country           - String - a text presentation of a country.
//        * CountryCode - String - an ARCC country code.
//        * ZipCode           - String - a postal code.
//        * StateCode       - String - a code of a local state.
//        * State           - String - a text presentation of a local state.
//        * StateShortForm - String - a short form of a state.
//        * County            - String - a text presentation of county.
//        * CountyShortForm - String - a short form of "county."
//        * District - String - text presentation of a district.
//        * DistrictShortForm - String - a short form of "district."
//        * City - String - text presentation of a city.
//        * CityShortForm - String - a short form of "city."
//        * CityDistrict - String - a text presentation of a city district.
//        * CityDistrictShortForm - String - a short form of "city district."
//        * Locality - String - a text presentation of a locality.
//        * LocalityShortForm - String - a short form of "locality."
//        * Street            - String - a text presentation of a street.
//        * StreetShortForm - String - a short form of "street."
//        * AdditionalTerritory - String - text presentation of an additional territory.
//        * AdditionalTerritoryShortForm - String - a short form of "additional territory."
//        * AdditionalTerritoryItem - String - text presentation of an additional territory item.
//        * AdditionalTerritoryShortForm - String - a short form of "additional territory."
//        * Building - Structure - a structure with building address information.
//            ** BuildingType - String - a type of addressing object of the RF address in accordance to the order of the FTS  MMV-7-1/525 dated 08/31/2011.
//            ** Number - String - a text presentation of a house number (only for local addresses).
//        * BuildingUnit - Array - contains structures (structure fields: BuildingUnitType, Number) that list building units of an address.
//        * Premises - Array - contains structures (structure fields: PremiseType and Number) that list address premises.
//        * ARCACodes           - Structure - ARCA codes if the ARCACodes parameter is set.
//           ** State          - String - an ARCA code of a state.
//           ** District           - String - an ARCA code of a district.
//           ** City           - String - an ARCA code of a city.
//           ** Locality - String - an ARCA code of a locality.
//           ** Street           - String - an ARCA code of a street.
//        * Additional codes - Structure - the following codes: RNCMT, RNCPS, IFTSICode, IFTSLECode, IFTSIAreaCode, and IFTSLEAreaCode.
Function AddressInfo(Address, AdditionalParameters = Undefined) Export
	
	If Metadata.CommonModules.Find("AddressManager") <> Undefined Then
		ModuleAddressManager = Common.CommonModule("AddressManager");
		Return ModuleAddressManager.AddressInfo(Address, AdditionalParameters);
	EndIf;
	
EndFunction

// Obsolete. Use AddressManager.ContactsAddressState instead.
// Returns a description of a local territorial entity for an address or a blank string if the territorial entity is not defined.
// If the passed string does not contain information on the address, an exception is thrown.
//
// Parameters:
//    XMLString - String - contacts XML.
//
// Returns:
//    String - description
//
Function ContactInformationAddressState(Val XMLString) Export
	
	If Metadata.CommonModules.Find("AddressManager") <> Undefined Then
		ModuleAddressManager = Common.CommonModule("AddressManager");
		Return ModuleAddressManager.ContactInformationAddressState(XMLString);
	EndIf;
	
	Return "";
	
EndFunction

// Obsolete. Use AddressManager.ContactsAddressCity instead.
// Returns a city description for a local address and a blank string for a foreign address.
// If the passed string does not contain information on the address, an exception is thrown.
//
// Parameters:
//    XMLString - String - contacts XML.
//
// Returns:
//    String - description
//
Function ContactInformationAddressCity(Val XMLString) Export
	
	If Metadata.CommonModules.Find("AddressManager") <> Undefined Then
		ModuleAddressManager = Common.CommonModule("AddressManager");
		Return ModuleAddressManager.ContactInformationAddressCity(XMLString);
	EndIf;
	
	Return "";
	
EndFunction

// Obsolete. Use ContactsControl.ObjectContacts instead.
// Gets values for a specified contact information type from an object.
//
// Parameters:
//    Ref - AnyRef - a reference to an  owner object of contacts (company, counterparty, partner, 
//                                            and so on).
//    ContactInformationType - EnumRef.ContactInformationTypes - the contact information type.
//
// Returns:
//    ValueTable - columns.
//        * Value - String - a string presentation of a value.
//        * Kind - String - presentation of a contacts kind.
//
Function ObjectContactInformationValues(Ref, ContactInformationType) Export
	
	ObjectsArray = New Array;
	ObjectsArray.Add(Ref);
	
	ObjectContactInformation = ObjectsContactInformation(ObjectsArray, ContactInformationType);
	
	Query = New Query;
	
	Query.SetParameter("ObjectContactInformation", ObjectContactInformation);
	
	Query.Text =
	"SELECT
	|	ObjectContactInformation.Presentation,
	|	ObjectContactInformation.Kind
	|INTO TTObjectContactInformation
	|FROM
	|	&ObjectContactInformation AS ObjectContactInformation
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ObjectContactInformation.Presentation AS Value,
	|	PRESENTATION(ObjectContactInformation.Kind) AS Kind
	|FROM
	|	TTObjectContactInformation AS ObjectContactInformation";
	
	Return Query.Execute().Unload();
	
EndFunction

// Obsolete. Use ContactsControl.ObjectContacts instead.
//  Returns values of all contacts of a particular type for the owner object.
//
//  Parameters:
//    Ref - AnyRef - a reference to an  owner object of contacts (company, counterparty, partner, 
//                                              and so on).
//    ContactsKind - CatalogRef.ContactsKinds - processing parameters.
//    Date - Date - optional, the date, from which contacts record is valid, is used for storing the 
//                                     history of contacts changes.
//
//  Returns:
//      Value table - information. Columns:
//          * RowNumber - Number - a row number of the additional tabular section of the owner object.
//          * Presentation - String - presentation of contacts entered by a user.
//          * FieldStrucure - Structure - key-value information pairs.
//
Function ObjectContactInformationTable(Ref, ContactInformationKind, Date = Undefined) Export
	
	ObjectMetadata = Ref.Metadata();
	
	Query = New Query;
	If ObjectMetadata.TabularSections.ContactInformation.Attributes.Find("ValidFrom") <> Undefined Then
		ValidFrom = ?(ValueIsFilled(Date), Date, CurrentSessionDate());
		QueryText = StringFunctionsClientServer.SubstituteParametersToString("SELECT ALLOWED 
		|	ContactInformation.Ref AS Object,
		|	ContactInformation.Kind AS Kind,
		|	MAX(ContactInformation.ValidFrom) AS ValidFrom
		|INTO ContactInformationSlice
		|FROM
		|	%1.ContactInformation AS ContactInformation
		|WHERE
		|	ContactInformation.Ref = &Ref
		|	AND ContactInformation.ValidFrom <= &ValidFrom
		|	AND ContactInformation.Kind <> VALUE(Catalog.ContactInformationKinds.EmptyRef)
		|	AND ContactInformation.Kind = &Kind
		|
		|GROUP BY
		|	ContactInformation.Kind,
		|	ContactInformation.Ref
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	ContactInformation.ContactLineIdentifier AS LineNumber,
		|	ContactInformation.Presentation AS Presentation,
		|	ContactInformation.FieldsValues
		|FROM
		|	ContactInformationSlice AS ContactInformationSlice
		|		LEFT JOIN %1.ContactInformation AS ContactInformation
		|		ON ContactInformationSlice.Kind = ContactInformation.Kind
		|			AND ContactInformationSlice.ValidFrom = ContactInformation.ValidFrom
		|			AND ContactInformationSlice.Object = ContactInformation.Ref 
		|ORDER BY 
		| ContactInformation.ContactLineIdentifier", ObjectMetadata.FullName());
		
		Query.SetParameter("ValidFrom", ValidFrom);
	Else
		QueryText = StringFunctionsClientServer.SubstituteParametersToString("SELECT 
		|	ContactInformation.ContactLineIdentifier AS LineNumber,
		|	ContactInformation.Presentation                     AS Presentation,
		|	ContactInformation.FieldsValues                     AS FieldsValues
		|FROM
		|	%1.ContactInformation AS ContactInformation
		|WHERE
		|	ContactInformation.Ref = &Ref
		|	AND ContactInformation.Kind = &Kind
		|ORDER BY 
		| ContactInformation.ContactLineIdentifier", ObjectMetadata.FullName());
		
	EndIf;
	
	Query.Text = QueryText;
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("Kind", ContactInformationKind);
	
	Result = New ValueTable;
	Result.Columns.Add("LineNumber");
	Result.Columns.Add("Presentation");
	Result.Columns.Add("FieldStructure");
	Result.Indexes.Add("LineNumber");
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		DataString = Result.Add();
		FillPropertyValues(DataString, Selection, "LineNumber, Presentation");
		DataString.FieldStructure = PreviousContactInformationXMLStructure(
		Selection.FieldsValues, ContactInformationKind);
	EndDo;
	
	Return  Result;
EndFunction

// Obsolete. Use ContactsControl.SetObjectsContacts instead.
// Fills in contact information for the objects.
//
// Parameters:
//  FillingDta - ValueTable - describes objects to be filled in. Contains the following columns:
//     * Destination - Arbitrary - a reference or an object whose contacts must be filled in.
//     * CIKind - CatalogRef.ContactsKinds - a contacts kind filled in the target.
//     * CIStructure - ValueList, String, Structure - data of contacts field values.
//     * RowKey - Structure - a filter for searching rows in the tabular section, where Key - a name 
//                                 of the column in the tabular section, Value - filter value.
//  Date - Date - optional, the date, from which contacts record is valid, is used for storing the 
//                              history of contacts changes.
//                              If not specified, the current date will be set.
//
Procedure FillObjectsContactInformation(FillingData, Date = Undefined) Export
	
	PreviousDestination = Undefined;
	FillingData.Sort("Destination, CIKind");
	
	For Each FillString In FillingData Do
		
		Destination = FillString.Destination;
		If Common.IsReference(TypeOf(Destination)) Then
			Destination = Destination.GetObject();
		EndIf;
		
		If PreviousDestination <> Undefined AND PreviousDestination <> Destination Then
			If PreviousDestination.Ref = Destination.Ref Then
				Destination = PreviousDestination;
			Else
				PreviousDestination.Write();
			EndIf;
		EndIf;
		
		CIKind = FillString.CIKind;
		DestinationObjectName = Destination.Metadata().Name;
		TabularSectionName = TabularSectionNameByCIKind(CIKind, DestinationObjectName);
		
		If IsBlankString(TabularSectionName) Then
			FillTabularSectionContactInformation(Destination, CIKind, FillString.CIStructure,, Date);
		Else
			If TypeOf(FillString.RowKey) <> Type("Structure") Then
				Continue;
			EndIf;
			
			If FillString.RowKey.Property("LineNumber") Then
				TabularSectionLineCount = Destination[TabularSectionName].Count();
				RowNumber = FillString.RowKey.LineNumber;
				If RowNumber > 0 AND RowNumber <= TabularSectionLineCount Then
					TabularSectionRow = Destination[TabularSectionName][RowNumber - 1];
					FillTabularSectionContactInformation(Destination, CIKind, FillString.CIStructure, TabularSectionRow, Date);
				EndIf;
			Else
				TabularSectionRows = Destination[TabularSectionName].FindRows(FillString.RowKey);
				For each TabularSectionRow In TabularSectionRows Do
					FillTabularSectionContactInformation(Destination, CIKind, FillString.CIStructure, TabularSectionRow, Date);
				EndDo;
			EndIf;
		EndIf;
		
		PreviousDestination = Destination;
		
	EndDo;
	
	If PreviousDestination <> Undefined Then
		PreviousDestination.Write();
	EndIf;
	
EndProcedure

// Obsolete. Use ContactsControl.SetObjectContacts.
// Fills in contact information for an object.
//
// Parameters:
//  Destination - Arbitrary - a reference or an object whose contacts must be filled in.
//  CIKind - CatalogRef.ContactsKinds - a contacts kind filled in the target.
//  CIStructure - Structure - a filled contacts structure.
//  RowKey - Structure - a filter for searching rows in the tabular section.
//    * Key - String - a column name in the tabular section.
//    * Value - String - a filter value.
//  Date - Date - optional, the date, from which contacts record is valid, is used for storing the 
//                       history of contacts changes.
//                       If not specified, the current date will be set.
//
Procedure FillObjectContactInformation(Destination, CIKind, CIStructure, RowKey = Undefined, Date = Undefined) Export
	
	FillingData = New ValueTable;
	FillingData.Columns.Add("Destination");
	FillingData.Columns.Add("CIKind");
	FillingData.Columns.Add("CIStructure");
	FillingData.Columns.Add("RowKey");
	
	FillString = FillingData.Add();
	FillString.Destination = Destination;
	FillString.CIKind = CIKind;
	FillString.CIStructure = CIStructure;
	FillString.RowKey = RowKey;
	
	FillObjectsContactInformation(FillingData, Date);
	
EndProcedure

// Obsolete. Use AddressManager.CheckAddress instead.
// Checks an address for compliance with address information requirements.
//
// Parameters:
//   AddressInXML - String - XML string of contacts.
//   CheckParameters - Structure - CatalogRef.ContantsType - check boxes of address check:
//          OnlyNationalAddress - Boolean - an address is to be only local. Default value is True.
//          AddressFormat - String - the classifier used for validation: "ARCA" or "FIAS". Default value is "ARCA".
// Returns:
//   Structure - contains a structure with the following fields:
//        * Result - String - a check result: Correct, NotChecked, ConainsErrors.
//        * ErrorsList - ValueList - information on errors.
Function CheckAddress(Val AddressInXML, CheckParameters = Undefined) Export
	Return ContactsManagerInternal.CheckAddress(AddressInXML, CheckParameters);
EndFunction

// Obsolete. Use ContactsParameters instead.
// Details of contact information parameters used in the OnCreateAtServer handler.
// 
// Returns:
//  Structure - contact information parameters.
//   * ZipCode - String - an address postal code.
//   * Country - String - an address country.
//   * PremiseType             - String - a description of premise type that will be set in the 
//                                         address input form. Apartment by default.
//   * ItemForPlacementName - String - a group, to which the contact information items will be placed.
//   * ExcludedKinds - Array - contact information kinds that do not need to be displayed on the form.
//   * DeferredInitialization - Boolean - if True, generation of contact information fields on the form will be deferred.
//   * ContactsTitleLocation - FormItemTitleLocation - can take the following values:
//                                                             FormItemTitleLocation.Top or
//                                                             FormItemTitleLocation.Left (by default).
//
Function ContactsParameters() Export

	Result = New Structure;
	Result.Insert("PremiseType", "Apartment");
	Result.Insert("IndexOf", Undefined);
	Result.Insert("Country", Undefined);
	Result.Insert("DeferredInitialization", False);
	Result.Insert("TitleLocationContactInformation", "");
	Result.Insert("ExcludedKinds", Undefined);
	Result.Insert("ItemForPlacementName", "ContactInformationGroup");
	
	Return Result;

EndFunction 

#EndRegion

#EndRegion

#Region Internal

// Returns info about the phone and fax number.
//
// Parameters:
//  ContactInformation - String - an address in the internal JSON or XML format matching the XDTO package Address.
// 
// Returns:
//  Structure - info about the phone:
//    * Presentation - String - phone presentation.
//    * CountryCode - String - a country code. For example, +7.
//    * CityCode - String - a city code. For example, 495.
//    * PhoneNumber - String - a phone number.
//    * Additional - String - an additional phone number.
//    * Comment - String - a comment to the phone number.
//
Function InfoAboutPhone(ContactInformation) Export
	
	PhoneByFields         = ContactsManagerInternal.ContactInformationToJSONStructure(ContactInformation, Enums.ContactInformationTypes.Phone);
	Result               = ContactsManagerClientServer.PhoneFieldStructure();
	Result.Presentation = String(PhoneByFields.Value);
	Result.CountryCode     = String(PhoneByFields.CountryCode);
	Result.CityCode     = String(PhoneByFields.AreaCode);
	Result.PhoneNumber = String(PhoneByFields.Number);
	Result.Extension    = String(PhoneByFields.ExtNumber);
	Result.Comment   = String(PhoneByFields.Comment);
	
	Return Result;
	
EndFunction

// Sets the availability of contacts items in form.
//
// Parameters:
//    Form - ManagedFrom - a passed form.
//    Items - Map - a list of contacts kinds for which access is set.
//        ** Key - MetadataObject - a subsystem where a report or a report version is placed.
//        ** Value - Boolean - if False, the item is available for viewing only.
//
Procedure SetContactInformationItemAvailability(Form, Items, ItemForPlacementName = "ContactInformationGroup") Export
	For each Item In Items Do
		
		Filter = New Structure("Kind", Item.Key);
		FoundRows = Form.ContactInformationAdditionalAttributeDetails.FindRows(Filter);
		If FoundRows <> Undefined Then
			For Each FoundRow In FoundRows Do
				CIItem = Form.Items[FoundRow.AttributeName];
				CIItem.ReadOnly = NOT Item.Value;
			EndDo;
			// If the item is available for viewing only, delete the option of adding this item to the form.
			ContactInformationParameters = FormContactsParameters(Form.ContactInformationParameters, ItemForPlacementName);
			If NOT Item.Value Then
				For each ContextMenuItem In ContactInformationParameters.ItemsToAddList Do
					If ContextMenuItem.Value.Ref = Item.Key Then
						ContactInformationParameters.ItemsToAddList.Delete(ContextMenuItem);
						Continue;
					EndIf;
				EndDo;
			EndIf;
		EndIf;
		
	EndDo;
	
	If Form.Items.Find("ContactInformationAddInputField") <> Undefined Then
		ContactInformationParameters = FormContactsParameters(Form.ContactInformationParameters, ItemForPlacementName);
		If ContactInformationParameters.ItemsToAddList.Count() = 0 Then
			// Create the Add unavailable botton as the context menu is empty.
			Form.Items.ContactInformationAddInputField.Enabled = False;
		EndIf;
	EndIf;
	
EndProcedure

// Extends the list of columns for data import by the contacts columns.
//
// Parameters:
//  CatalogMetadata	 - MetadataObject - a catalog metadata.
//  ColumnsInformation	 - ValueTable - template columns.
//
Procedure ColumnsForDataImport(CatalogMetadata, ColumnsInformation) Export
	
	If CatalogMetadata.TabularSections.Find("ContactInformation") = Undefined Then
		Return;
	EndIf;
	
	Position = ColumnsInformation.Count() + 1;
	
	ContactInformationKinds = ObjectContactInformationKinds(Catalogs[CatalogMetadata.Name].EmptyRef());
	
	For each ContactInformationKind In ContactInformationKinds Do
		ColumnName = "ContactInformation_" + StandardSubsystemsServer.TransformStringToValidColumnDescription(ContactInformationKind.Description);
		If ColumnsInformation.Find(ColumnName, "ColumnName") = Undefined Then
			ColumnsInfoRow = ColumnsInformation.Add();
			ColumnsInfoRow.ColumnName = ColumnName;
			ColumnsInfoRow.ColumnPresentation = ContactInformationKind.Presentation;
			ColumnsInfoRow.ColumnType = New TypeDescription("String");
			ColumnsInfoRow.Required = False;
			ColumnsInfoRow.Position = Position;
			ColumnsInfoRow.Group = NStr("ru = 'Контактная информация'; en = 'Contact information'; pl = 'Informacje kontaktowe';es_ES = 'Información de contacto';es_CO = 'Información de contacto';tr = 'İletişim bilgileri';it = 'Informazioni di contatto';de = 'Kontakt Informationen'");
			ColumnsInfoRow.Visible = True;
			ColumnsInfoRow.Width = 30;
			Position = Position + 1;
		EndIf;
	EndDo;
	
EndProcedure

// Contacts kinds of an object.
//
// Parameters:
//  ContactsOwner - a reference to the contacts owner.
//                                 Object of contacts owner.
//                                 FormStructureData (by type of property owner object).
// Returns:
//  ValueTable - contacts kinds.
//
Function ObjectContactInformationKinds(ContactInformationOwner, ContactInformationType = Undefined) Export
	
	If TypeOf(ContactInformationOwner) = Type("FormDataStructure") Then
		RefType = TypeOf(ContactInformationOwner.Ref)
		
	ElsIf Common.IsReference(TypeOf(ContactInformationOwner)) Then
		RefType = TypeOf(ContactInformationOwner);
	Else
		RefType = TypeOf(ContactInformationOwner.Ref)
	EndIf;
	
	CatalogMetadata = Metadata.FindByType(RefType);
	FullMetadataObjectName = CatalogMetadata.FullName();
	CIKindGroupName = StrReplace(FullMetadataObjectName, ".", "");
	CIKindsGroup = Undefined;
	
	Query = New Query;
	Query.Text = "SELECT
	|	ContactInformationKinds.Ref AS Ref,
	|	ContactInformationKinds.PredefinedDataName AS PredefinedDataName
	|FROM
	|	Catalog.ContactInformationKinds AS ContactInformationKinds
	|WHERE
	|	ContactInformationKinds.IsFolder = TRUE
	|	AND ContactInformationKinds.DeletionMark = FALSE
	|	AND ContactInformationKinds.Used = TRUE";
	
	QueryResult = Query.Execute().Select();
	While QueryResult.Next() Do 
		If StrCompare(QueryResult.PredefinedDataName, CIKindGroupName) = 0 Then
			CIKindsGroup = QueryResult.Ref;
			Break;
		EndIf;
	EndDo;
	
	If NOT ValueIsFilled(CIKindsGroup) Then
		Return New ValueTable;
	EndIf;
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	ContactInformationKinds.Ref,
	|	ContactInformationKinds.Presentation,
	|	ContactInformationKinds.Description,
	|	ContactInformationKinds.AllowMultipleValueInput,
	|	ContactInformationKinds.AdditionalOrderingAttribute AS AdditionalOrderingAttribute,
	|	ContactInformationKinds.Type
	|FROM
	|	Catalog.ContactInformationKinds AS ContactInformationKinds
	|WHERE
	|	ContactInformationKinds.Parent = &CIKindsGroup
	|	AND ContactInformationKinds.DeletionMark = FALSE
	|	AND ContactInformationKinds.Used = TRUE
	|	AND &ContactInformationTypeFilter
	|
	|ORDER BY
	|	AdditionalOrderingAttribute";
	
	If ContactInformationType <> Undefined Then
		Query.Text = StrReplace(Query.Text, "&ContactInformationTypeFilter", 
			"ContactInformationKinds.Type = &ContactInformationType");
		Query.SetParameter("ContactInformationType", ContactInformationType);
	Else
		Query.Text = StrReplace(Query.Text, "&ContactInformationTypeFilter", "True");
	EndIf;
	
	Query.SetParameter("CIKindsGroup", CIKindsGroup);
	QueryResult = Query.Execute().Unload();
	Return QueryResult;
	
EndFunction

// Returns full data from the ARCC.
//
// Returns:
//     ValueTable - classifier data with the following columns:
//         * Code - String - country data.
//         * Description - String - country data.
//         * FullDescription - String - country data.
//         * CodeAlpha2 - String - country data.
//         * CodeAlpha3 - String - country data.
//
//     The value table is indexed by Code and Description fields.
//
Function ClassifierTable() Export
	Template = Catalogs.WorldCountries.GetTemplate("Classifier");
	
	Read = New XMLReader;
	Read.SetString(Template.GetText());
	
	Return XDTOSerializer.ReadXML(Read);
EndFunction

// Returns a contact information type.
//
// Parameters:
//    Description - String - a contacts type as a string.
//
// Returns:
//    EnumRef.ContactsTypes - matching type.
//
Function ContactInformationTypeByDescription(Val Description) Export
	Return Enums.ContactInformationTypes[Description];
EndFunction

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Initialization of items on the form of a contacts owner object.

Procedure GenerateContactInformationAttributes(Val Form, Val AttributesToAdd, Val ObjectName, Val ExcludedKinds, 
	Val ContactInformation, Val DeferredInitialization, ObjectIndex = 0)
	
	String1500 = New TypeDescription("String", , New StringQualifiers(1500));
	GeneratedAttributes = CommonClientServer.CopyArray(ExcludedKinds);
	PreviousKind      = Undefined;
	SequenceNumber    = 1;
	
	For Each ContactInformationObject In ContactInformation Do
		
		If ContactInformationObject.IsTabularSectionAttribute Then
			
			CIKindName = ContactInformationObject.PredefinedDataName;
			Position = StrFind(CIKindName, ObjectName);
			TabularSectionName = Mid(CIKindName, Position + StrLen(ObjectName));
			
			PreviousKind = Undefined;
			AttributeName = "";
			
			ContactInformationObject.Rows.Sort("AdditionalOrderingAttribute");
			
			For Each CIRow In ContactInformationObject.Rows Do
				
				CurrentKind = CIRow.Kind;
				If CurrentKind <> PreviousKind Then
					
					AttributeName = "ContactInformationField" + TabularSectionName + StrReplace(CurrentKind.UUID(), "-", "x")
						+ ContactInformationObject.Rows.IndexOf(CIRow);
					AttributesPath = "Object." + TabularSectionName;
					
					AttributesToAdd.Add(New FormAttribute(AttributeName, String1500, AttributesPath, CIRow.Description, True));
					AttributesToAdd.Add(New FormAttribute(AttributeName + "Value", New TypeDescription("String"), AttributesPath,, True));
					PreviousKind = CurrentKind;
					
				EndIf;
				
				CIRow.AttributeName = AttributeName;
				
			EndDo;
			
		Else
			
			If ContactInformationObject.IsHistoricalContactInformation Then
				CorrectContacts(Form, ContactInformationObject);
				Continue;
			EndIf;
			
			CurrentKind = ContactInformationObject.Kind;
			
			If CurrentKind <> PreviousKind Then
				PreviousKind = CurrentKind;
				SequenceNumber = 1;
			Else
				SequenceNumber = SequenceNumber + 1;
			EndIf;
			
			Index = GeneratedAttributes.Find(CurrentKind);
			If Index = Undefined Then
				ContactInformationObject.AttributeName = "ContactInformationField" + StrReplace(CurrentKind.UUID(), "-", "x")
					+ SequenceNumber;
					
				If ObjectIndex <> 0 Then
					ContactInformationObject.AttributeName = ContactInformationObject.AttributeName + "_" + ObjectIndex;
				EndIf;
					
				If Not DeferredInitialization Then
					AttributesToAdd.Add(
						New FormAttribute(ContactInformationObject.AttributeName, String1500, , ContactInformationObject.Description, True));
				Continue;
				
			EndIf;
					
				If Not DeferredInitialization Then
					AttributesToAdd.Add(
						New FormAttribute(ContactInformationObject.AttributeName, String1500, , ContactInformationObject.Description, True));
				EndIf;
			Else
				ContactInformationObject.AttributeName = "ContactInformationField" + ContactInformationObject.PredefinedDataName;
				GeneratedAttributes.Delete(Index);
			EndIf;
			
			CorrectContacts(Form, ContactInformationObject);
		EndIf;
	EndDo;
	
	// Adding new attributes
	If AttributesToAdd.Count() > 0 Then
		Form.ChangeAttributes(AttributesToAdd);
	EndIf;

EndProcedure

Procedure HideContacts(Val Form, Val AttributesToAdd, Val ItemForPlacementName, Val ExcludedKinds, 
	Val DeferredInitialization, Val TitleLocationContactInformation, Val ObjectRef)
	
	If AttributesToAdd.Count() > 0 Then
		Form.ChangeAttributes(AttributesToAdd);
	EndIf;
	AddedAttributes = New Array;
	For Each AddedAttribute In AttributesToAdd Do
		If IsBlankString(AddedAttribute.Path) Then
			AddedAttributes.Add(AddedAttribute.Name);
		EndIf;
	EndDo;
	
	ContactInformationParameters = ContactsOutputParameters(Form, ItemForPlacementName, TitleLocationContactInformation,
		DeferredInitialization, ExcludedKinds);
	ContactInformationParameters.AddedAttributes = AddedAttributes;
	ContactInformationParameters.Owner = ObjectRef;
	
	If Not IsBlankString(ItemForPlacementName) Then
		Form.Items[ItemForPlacementName].Visible = False;
	EndIf;

EndProcedure

Function AlwaysShowKinds(CIGroup)
	
	Query = New Query;
	Query.Text =
		"SELECT
		|	ContactInformationVisibilitySettings.Kind AS Kind
		|FROM
		|	InformationRegister.ContactInformationVisibilitySettings AS ContactInformationVisibilitySettings
		|WHERE
		|	ContactInformationVisibilitySettings.ShowInFormAlways
		|	AND ContactInformationVisibilitySettings.Kind IN HIERARCHY(&CIGroup)";
	
	Query.SetParameter("CIGroup", CIGroup);
	
	Result = Query.Execute().Unload();
	
	Return Result.UnloadColumn("Kind");
	
EndFunction

Procedure AddButtonOfAdditionalContactsField(Val Form, Val ItemForPlacementName)
	
	Details = NStr("ru = 'Добавить дополнительное поле контактной информации'; en = 'Add an additional contact information field'; pl = 'Dodaj dodatkowe pole informacji kontaktowych';es_ES = 'Añadir el campo de la información de contacto adicional';es_CO = 'Añadir el campo de la información de contacto adicional';tr = 'İletişim kanalı ekle';it = 'Aggiungere un campo ulteriori informazioni contattare';de = 'Fügen Sie ein zusätzliches Kontaktinformationsfeld hinzu'");
	CommandsGroup             = Folder("ContactInformationGroupAddInputField" + ItemForPlacementName, Form, Details, ItemForPlacementName);
	CommandsGroup.Representation = UsualGroupRepresentation.NormalSeparation;
	
	CommandName          = "ContactInformationAddInputField" + ItemForPlacementName;
	Command             = Form.Commands.Add(CommandName);
	Command.ToolTip   = Details;
	Command.Representation = ButtonRepresentation.PictureAndText;
	Command.Action    = "Attachable_ContactInformationExecuteCommand";
	
	Form.ContactInformationParameters[ItemForPlacementName].AddedItems.Add(CommandName, 9, True);
	
	Button             = Form.Items.Add(CommandName,Type("FormButton"), CommandsGroup);
	Button.Enabled = NOT Form.Items[ItemForPlacementName].ReadOnly;
	Button.Title   = NStr("ru = 'Добавить'; en = '+ phone, address'; pl = '+ telefon, adres';es_ES = '+ teléfono, dirección';es_CO = '+ teléfono, email';tr = '+ telefon, adres';it = '+ telefono, indirizzo';de = '+ Telefon, Adresse'");
	Command.ModifiesStoredData = True;
	Button.CommandName                 = CommandName;
	Button.ShapeRepresentation = ButtonShapeRepresentation.None;
	Form.ContactInformationParameters[ItemForPlacementName].AddedItems.Add(CommandName, 2, False);

EndProcedure

Procedure AddNoteOnResettingFormSettings(Val Form, Val ItemForPlacementName, Val DeferredInitialization)
	
	GroupForPlacement = Form.Items[ItemForPlacementName];
	// If there is a deferred initialization and no items on the page, the platform hides the page, so 
	// you need to create a temporary item that will be deleted when you go to the page.
	If DeferredInitialization
		AND GroupForPlacement.Type = FormGroupType.Page 
		AND Form.Items.Find("ContactInformationStub") = Undefined Then
		
		PageGroup = GroupForPlacement.Parent;
		PageHeader = ?(ValueIsFilled(GroupForPlacement.Title), GroupForPlacement.Title, GroupForPlacement.Name);
		PageGroupHeader = ?(ValueIsFilled(PageGroup.Title), PageGroup.Title, PageGroup.Name);
		
		PlacementWarning = NStr("ru = 'Для отображения контактной информации необходимо разместить группу ""%1"" не первым элементом (после любой другой группы) в группе ""%2"" (меню Еще - Изменить форму).'; en = 'To show the contact information, place the ""%1"" group not as the first item (after any other group) in the ""%2"" group (menu More - Change form).'; pl = 'Aby wyświetlić informację kontaktową należy umieścić grupę ""%1"" nie pierwszym elementem (po każdej innej grupie) w grupie ""%2"" (menu Więcej -Zmienić formularz).';es_ES = 'Para visualizar la información de contacto es necesario colocar en el grupo ""%1"" no como el primer elemento (después del cualquier otro grupo) en el grupo ""%2"" (menú Más - Cambiar el formulario).';es_CO = 'Para visualizar la información de contacto es necesario colocar en el grupo ""%1"" no como el primer elemento (después del cualquier otro grupo) en el grupo ""%2"" (menú Más - Cambiar el formulario).';tr = 'İletişim bilgileri görüntülemek için, ""%1""grubu ""%2"" grubunda (başka bir gruptan sonra) ilk öğe şeklinde yerleştirmemeniz gerekir (menü Daha fazla-Formu değiştirin).';it = 'Per mostrare le informazioni di contatto, posizionare il gruppo ""%1"" non come primo elemento (dopo ciascun altro gruppo) nel gruppo ""%2"" (menu Altro - Modificare modulo).';de = 'Um Kontaktinformationen anzuzeigen, sollten Sie die Gruppe ""%1"" nicht als erstes Element (nach einer anderen Gruppe) in der Gruppe ""%2"" (Menü Mehr- Formular ändern) platzieren.'");
		PlacementWarning = StringFunctionsClientServer.SubstituteParametersToString(PlacementWarning,
		PageHeader, PageGroupHeader);
		TooltipText = NStr("ru = 'Также можно установить стандартные настройки формы:
		|   • в меню Еще выбрать пункт Изменить форму...;
		|   • в открывшейся форме ""Настройка формы"" в меню Еще выбрать пункт ""Установить стандартные настройки"".'; 
		|en = 'You can also set default form settings:
		| • In the ""More actions"" menu, click ""Change form"".
		| • In the opened ""Customize form"" window, in the ""More actions"" menu, click ""Use standard settings"".'; 
		|pl = 'Można również ustawić domyślne ustawienia formularzu:
		| • w menu Więcej wybrać punkt Zmień formularz...;
		| • w otwartym formularzu ""Ustawienia formularza"" w menu Więcej wybrać opcję ""Ustaw domyślne ustawienia"".';
		|es_ES = 'Además se puede instalar los ajustes estándares del formulario:
		| • en el menú Más hay que seleccionar el punto Cambiar el formulario...;
		| • en el formulario que se abrirá ""Ajustes del formulario"" en el menú Más hay que seleccionar el punto ""Establecer los ajustes estándares"".';
		|es_CO = 'Además se puede instalar los ajustes estándares del formulario:
		| • en el menú Más hay que seleccionar el punto Cambiar el formulario...;
		| • en el formulario que se abrirá ""Ajustes del formulario"" en el menú Más hay que seleccionar el punto ""Establecer los ajustes estándares"".';
		|tr = 'Ayrıca standart biçim ayarları belirlenebilir:
		|   • Daha fazla menüsünde Biçim değiştir alt menüyü seçin...;
		|   • açılan formda ""Biçim ayarları"" ""Daha fazla menüsünde ""Standart ayarları belirle"" alt menüyü seçin.';
		|it = 'Potete anche impostare impostazioni modulo predefinite:
		| • Nel menu ""Più azioni"", premi ""Modifica modulo"".
		| • nella finestra aperta ""Personalizza modulo"", nel menu ""Più azioni"", premi ""Utilizza impostazioni standard"".';
		|de = 'Sie können auch die Standardeinstellungen für das Formular festlegen:
		| • im Menü Mehr, den Punkt ""Formular ändern"" wählen;
		| • im geöffneten Formular ""Formulareinstellung"" im Menü Mehr, den Punkt ""Standardeinstellungen einstellen"" wählen.'");
		
		Decoration = Form.Items.Add("ContactInformationStub", Type("FormDecoration"), GroupForPlacement);
		Decoration.Title              = PlacementWarning;
		Decoration.ToolTipRepresentation   = ToolTipRepresentation.Button;
		Decoration.ToolTip              = TooltipText;
		Decoration.TextColor             = StyleColors.ErrorNoteText;
		Decoration.AutoMaxHeight = False;
	EndIf;

EndProcedure

Function TitleLeft(Val TitleLocationContactInformation = Undefined)
	
	If ValueIsFilled(TitleLocationContactInformation) Then
		TitleLocationContactInformation = PredefinedValue(TitleLocationContactInformation);
	Else
		TitleLocationContactInformation = FormItemTitleLocation.Left;
	EndIf;
	
	Return (TitleLocationContactInformation = FormItemTitleLocation.Left);
	
EndFunction

Procedure ModifyComment(Form, AttributeName, ItemForPlacementName)
	
	ContactInformationParameters = FormContactsParameters(Form.ContactInformationParameters, ItemForPlacementName);
	If ContactInformationParameters.AddedItems.FindByValue(AttributeName) = Undefined Then
		Return;
	EndIf;
	
	ContactInformationDetails = Form.ContactInformationAdditionalAttributeDetails;
	
	Filter = New Structure("AttributeName", AttributeName);
	FoundRow = ContactInformationDetails.FindRows(Filter)[0];
	
	If ContactsManagerClientServer.IsJSONContactInformation(FoundRow.Value) Then
		ContactsByFields = ContactsManagerInternal.JSONStringToStructure(FoundRow.Value);
		ContactsByFields.Comment = FoundRow.Comment;
		FoundRow.Value = ContactsManagerInternal.ToJSONStringStructure(ContactsByFields);
	EndIf;
	
	InputField = Form.Items.Find(AttributeName);
	InputField.ExtendedToolTip.Title = FoundRow.Comment;
	
EndProcedure

Procedure AddContactInformationString(Form, Result, ItemForPlacementName, IsNewCIKind = False, AddressCount = Undefined, NextRow = Undefined)
	
	AddNewValue = TypeOf(Result) = Type("Structure");
	
	If AddNewValue Then
		Result.Property("ItemForPlacementName", ItemForPlacementName);
		
		KindToAdd = Result.KindToAdd;
		If TypeOf(KindToAdd)= Type("CatalogRef.ContactInformationKinds") Then
			CIKindInformation = Common.ObjectAttributesValues(KindToAdd, "Type, Description, EditOnlyInDialog, FieldKindOther");
		Else
			CIKindInformation = KindToAdd;
			KindToAdd    = KindToAdd.Ref;
		EndIf;
	Else
		CIKindInformation = Result;
		KindToAdd    = Result.Kind;
	EndIf;
	
	ContactInformationTable = Form.ContactInformationAdditionalAttributeDetails;
	FilterByKind = New Structure("Kind, IsHistoricalContactInformation", KindToAdd, False);
	
	AlwaysShowKinds = AlwaysShowKinds(KindToAdd.Parent);
	
	If AddNewValue Then
		
		FoundRows = ContactInformationTable.FindRows(FilterByKind);
		
		KindStringNumber = FoundRows.Count();
		If KindStringNumber > 0 Then
			LastRow = FoundRows.Get(KindStringNumber - 1);
			AddedRowIndex = ContactInformationTable.IndexOf(LastRow) + 1;
		ElsIf AlwaysShowKinds.Find(KindToAdd) = Undefined Then
			AddedRowIndex = ContactInformationTable.Count();
		Else
			AddedRowIndex = 0;
		EndIf;
		
		IsLastRow = False;
		If AddedRowIndex = ContactInformationTable.Count() Then
			IsLastRow = True;
		EndIf;
		
		NewRow  = ContactInformationTable.Insert(AddedRowIndex);
		AttributeName = StringFunctionsClientServer.SubstituteParametersToString("%1%2%3",
			"ContactInformationField",
			StrReplace(KindToAdd.UUID(), "-", "x"),
			KindStringNumber + 1);
		NewRow.AttributeName              = AttributeName;
		NewRow.Kind                       = KindToAdd;
		NewRow.Type                       = CIKindInformation.Type;
		NewRow.ItemForPlacementName  = ItemForPlacementName;
		NewRow.IsTabularSectionAttribute = False;
		
		AttributesToAddArray = New Array;
		AttributesToAddArray.Add(New FormAttribute(AttributeName, New TypeDescription("String", , New StringQualifiers(500)), , CIKindInformation.Description, True));
		Form.ChangeAttributes(AttributesToAddArray);
		
		HasComment = False;
		Mandatory = False;
	Else
		IsLastRow = NextRow = Undefined;
		AttributeName = CIKindInformation.AttributeName;
		HasComment = ValueIsFilled(CIKindInformation.Comment);
		Mandatory = CIKindInformation.Mandatory;
	EndIf;
	
	// Displaying form items
	StringGroup = Folder("Group" + AttributeName, Form, KindToAdd.Description, ItemForPlacementName);
	
	Parent = Parent(Form, ItemForPlacementName);
	If Not IsLastRow Then
		If NextRow = Undefined Then
			NextGroupName = "Group" + LastRow.AttributeName;
			If Form.Items.Find(NextGroupName) <> Undefined Then
				NextGroupIndex = Parent.ChildItems.IndexOf(Form.Items[NextGroupName]) + 1;
				NextGroup = Parent.ChildItems.Get(NextGroupIndex);
			EndIf;
		Else
			NameOfGroup = "Group" + NextRow.AttributeName;
			If Form.Items.Find(NameOfGroup) <> Undefined Then
				NextGroup = Form.Items[NameOfGroup];
			EndIf;
		EndIf;
		Form.Items.Move(StringGroup, Parent, NextGroup);
	ElsIf AddNewValue Then
		NextGroup = Form.Items[Result.CommandName].Parent;
		Form.Items.Move(StringGroup, Parent, NextGroup);
	EndIf;
	
	// Handling situations when multiple dynamic and static contact information is displayed on the form at the same time.
	NameOfNextGroupOfCurrentKind = "Group" + AttributeName;
	If Form.Items.Find(NameOfNextGroupOfCurrentKind) <> Undefined Then
		
		Filter = New Structure("AttributeName", AttributeName);
		FoundStringsOfCurrentKind = ContactInformationTable.FindRows(Filter);
		If FoundStringsOfCurrentKind.Count() > 0 Then
			CurrentKind = FoundStringsOfCurrentKind[0].Kind;
		EndIf;
		
		IndexOfPreviousKindGroup = Parent.ChildItems.IndexOf(Form.Items[NameOfNextGroupOfCurrentKind]) - 1;
		If IndexOfPreviousKindGroup >= 0 Then
			PreviousKindGroup = Parent.ChildItems.Get(IndexOfPreviousKindGroup);
			
			If PreviousKindGroup <> Undefined Then
			
			Filter = New Structure("AttributeName", StrReplace(PreviousKindGroup.Name, "Group", ""));
			FoundStringsOfPreviousKind = ContactInformationTable.FindRows(Filter);
			If FoundStringsOfPreviousKind.Count() > 0 Then
				PreviousKind = FoundStringsOfPreviousKind[0].Kind;
			EndIf;
			
			If CurrentKind <> PreviousKind Then
				IsNewCIKind = True;
			EndIf;
			EndIf;
		Else
			IsNewCIKind = True;
		EndIf;
	EndIf;
	
	InputField = GenerateInputField(Form, StringGroup, CIKindInformation, AttributeName, ItemForPlacementName, IsNewCIKind, Mandatory);
	If HasComment Then
		InputField.ExtendedTooltip.Title              = CIKindInformation.Comment;
		InputField.ExtendedTooltip.AutoMaxWidth = False;
		InputField.ExtendedTooltip.MaxWidth     = InputField.Width;
		InputField.ExtendedTooltip.Width                 = InputField.Width;
	EndIf;
	
	If AddressCount = Undefined Then
		FIlterByType = New Structure("Type", Enums.ContactInformationTypes.Address);
		AddressCount = ContactInformationTable.FindRows(FIlterByType).Count();
	EndIf;
	
	CreateAction(Form, CIKindInformation, AttributeName, StringGroup, AddressCount, HasComment, ItemForPlacementName);
	
	If Not IsNewCIKind Then
		If ContactInformationTable.Count() > 1 AND ContactInformationTable[0].Property("IsHistoricalContactInformation") Then
			ItemOfContextMenuMove(InputField, Form, 1, ItemForPlacementName);
			FoundRows = ContactInformationTable.FindRows(FilterByKind);
			If FoundRows.Count() > 1 Then
				PreviousString = FoundRows.Get(FoundRows.Count() - 2);
				ItemOfContextMenuMove(Form.Items[PreviousString.AttributeName], Form, - 1, ItemForPlacementName);
			EndIf;
		EndIf;
	EndIf;
	
	If AddNewValue Then
		Form.CurrentItem = Form.Items[AttributeName];
		If CIKindInformation.Type = Enums.ContactInformationTypes.Address
			AND CIKindInformation.EditOnlyInDialog Then
			Result.Insert("AddressFormItem", AttributeName);
		EndIf;
	EndIf;
	
EndProcedure

Function GenerateInputField(Form, Parent, CIKindInformation, AttributeName, ItemForPlacementName,IsNewCIKind = False, Mandatory = False)
	
	ContactInformationParameters = FormContactsParameters(Form.ContactInformationParameters, ItemForPlacementName);
	
	TitleLeft = TitleLeft(ContactInformationParameters.TitleLocation);
	Item = Form.Items.Add(AttributeName, Type("FormField"), Parent);
	Item.DataPath = AttributeName;
	
	If CIKindInformation.EditOnlyInDialog AND CIKindInformation.Type = Enums.ContactInformationTypes.Address Then
		Item.Type = FormFieldType.LabelField;
		Item.Hyperlink = True;
		Item.SetAction("Click", "Attachable_ContactInformationOnClick");
		If IsBlankString(Form[AttributeName]) Then
			Form[AttributeName] = ContactsManagerClientServer.EmptyAddressTextAsHiperlink();
		EndIf;
	Else
		Item.Type = FormFieldType.InputField;
		Item.SetAction("Clearing",         "Attachable_ContactInformationClearing");
		
		If CIKindInformation.Type = Enums.ContactInformationTypes.Address Then
			Item.SetAction("AutoComplete",      "Attachable_ContactInformationAutoComplete");
			Item.SetAction("ChoiceProcessing", "Attachable_ContactInformationChoiceProcessing");
		EndIf;
		
	EndIf;
	
	Item.ToolTipRepresentation = ToolTipRepresentation.ShowBottom;
	Item.HorizontalStretch = False;
	Item.VerticalStretch = False;
	Item.TitleHeight = 2;
	
	If CIKindInformation.Type = Enums.ContactInformationTypes.Address Then
		//Item.Width = 70;
	ElsIf CIKindInformation.Type = Enums.ContactInformationTypes.Other Then
		If CIKindInformation.FieldKindOther = "MultilineWide" Then
			Item.Height = 3;
			//Item.Width = 70;
			Item.MultiLine = True;
		ElsIf CIKindInformation.FieldKindOther = "SingleLineWide" Then
			Item.Height = 1;
			//Item.Width = 70;
			Item.MultiLine = False;
		Else // SingleLineNarrow
			Item.Height = 1;
			//Item.Width = 35;
			Item.MultiLine = False;
		EndIf;
	Else
		//Item.Width = 35;
	EndIf;
	
	If Not IsNewCIKind Then
		Item.HorizontalAlignInGroup = ItemHorizontalLocation.Right;
		Item.TitleTextColor = StyleColors.FormBackColor;
	EndIf;
	
	Item.TitleLocation = ?(TitleLeft, FormItemTitleLocation.Left, FormItemTitleLocation.Top);
	If TitleLeft Then
		Item.TitleLocation = FormItemTitleLocation.Left;
	Else
		Item.TitleLocation = FormItemTitleLocation.Top;
	EndIf;
	
	ContactInformationParameters.AddedItems.Add(AttributeName, 2, False);
	
	// Sets properties of the input field.
	If CIKindInformation.Type <> Enums.ContactInformationTypes.Other AND Not CIKindInformation.DeletionMark Then
		// Entering comment via context menu.
		CommandName = "ContextMenu" + AttributeName;
		Button = Form.Items.Add(CommandName,Type("FormButton"), Item.ContextMenu);
		Button.Title = NStr("ru = 'Ввести комментарий'; en = 'Enter comment'; pl = 'Wpisz komentarz';es_ES = 'Introducir un comentario';es_CO = 'Introducir un comentario';tr = 'Yorumu girin';it = 'Inserisci commento';de = 'Geben Sie einen Kommentar ein'");
		Command = Form.Commands.Add(CommandName);
		Command.ToolTip = NStr("ru = 'Ввести комментарий'; en = 'Enter comment'; pl = 'Wpisz komentarz';es_ES = 'Introducir un comentario';es_CO = 'Introducir un comentario';tr = 'Yorumu girin';it = 'Inserisci commento';de = 'Geben Sie einen Kommentar ein'");
		Command.Picture = PictureLib.Comment;
		Command.Action = "Attachable_ContactInformationExecuteCommand";
		Command.ModifiesStoredData = True;
		Button.CommandName = CommandName;
		
		ContactInformationParameters.AddedItems.Add(CommandName, 1);
		ContactInformationParameters.AddedItems.Add(CommandName, 9, True);
	EndIf;
	
	If CIKindInformation.StoreChangeHistory AND Not CIKindInformation.DeletionMark Then
		// Contacts history output via context menu.
		CommandName = "ContextMenuHistory" + AttributeName;
		Button = Form.Items.Add(CommandName, Type("FormButton"), Item.ContextMenu);
		Button.Title = NStr("ru = 'История изменений...'; en = 'Change history...'; pl = 'Historia zmian...';es_ES = 'Historia de cambios...';es_CO = 'Historia de cambios...';tr = 'Değişiklik geçmişi...';it = 'Modifica storico...';de = 'Der Verlauf der Änderung...'");
		Command = Form.Commands.Add(CommandName);
		Command.Picture = PictureLib.ChangeHistory;
		Command.ToolTip = NStr("ru = 'Показывает историю изменения контактной информации'; en = 'Shows change history of contact information'; pl = 'Pokazuje historię zmian informacji kontaktowej';es_ES = 'Muestra el historial del cambio de la información de contacto';es_CO = 'Muestra el historial del cambio de la información de contacto';tr = 'Iletişim bilgilerin değişim geçmişini gösterir';it = 'Mostra lo storico cambiamenti delle informazioni di contatto';de = 'Zeigt den Verlauf der Änderungen in den Kontaktinformationen an'");
		Command.Action = "Attachable_ContactInformationExecuteCommand";
		Command.ModifiesStoredData = False;
		Button.CommandName = CommandName;
		
		ContactInformationParameters.AddedItems.Add(CommandName, 1);
		ContactInformationParameters.AddedItems.Add(CommandName, 9, True);
	EndIf;
	
	If CIKindInformation.Type = Enums.ContactInformationTypes.Address Then
		GroupMapSeparator = Form.Items.Add("SubmenuSeparatorContextMaps" + AttributeName, Type("FormGroup"), Item.ContextMenu);
		GroupMapSeparator.Type = FormGroupType.ButtonGroup;
		
		CommandName = "ContextMenuGoogleMap" + AttributeName;
		Button = Form.Items.Add(CommandName,Type("FormButton"), GroupMapSeparator);
		Button.Title = NStr("ru = 'Адрес на Google Maps'; en = 'Address on Google Maps'; pl = 'Adres w Mapach Google';es_ES = 'Dirección en Google Maps';es_CO = 'Dirección en Google Maps';tr = 'Google Maps'' te adres';it = 'Indirizzo su Google Maps';de = 'Adresse in Google Maps'");
		Command = Form.Commands.Add(CommandName);
		Command.Picture = PictureLib.GoogleMaps;
		Command.ToolTip = NStr("ru = 'Показывает адрес на карте Google Maps'; en = 'Shows address on Google Maps'; pl = 'Pokaż adres w Mapach Google';es_ES = 'Mostrar la dirección en Google Maps';es_CO = 'Mostrar la dirección en Google Maps';tr = 'Google Maps'' ta adresi göster';it = 'Mostra indirizzo su Google Maps';de = 'Adresse in Google Maps anzeigen'");
		Command.Action = "Attachable_ContactInformationExecuteCommand";
		Button.CommandName = CommandName;
		
		ContactInformationParameters.AddedItems.Add(CommandName, 1);
		ContactInformationParameters.AddedItems.Add(CommandName, 9, True);
		
		SeparatorButtonGroup = Form.Items.Add("SubmenuSeparatorMaps" + AttributeName, Type("FormGroup"), Item.ContextMenu);
		SeparatorButtonGroup.Type = FormGroupType.ButtonGroup;
		
		If Not CIKindInformation.DeletionMark Then
			// Fill in
			GroupAddressSubmenu = Form.Items.Add("ContextSubmenuCopyAddresses" + AttributeName, Type("FormGroup"), SeparatorButtonGroup);
			GroupAddressSubmenu.Type = FormGroupType.Popup;
			GroupAddressSubmenu.Representation = ButtonRepresentation.Text;
			GroupAddressSubmenu.Title = NStr("ru='Заполнить'; en = 'Fill in'; pl = 'Wypełnij';es_ES = 'Rellenar';es_CO = 'Rellenar';tr = 'Doldur';it = 'Compila';de = 'Ausfüllen'");
		EndIf;
		
	EndIf;
	
	If Mandatory AND IsNewCIKind AND Item.Type = FormFieldType.InputField Then
		Item.AutoMarkIncomplete = True;
	EndIf;
	
	// Editing in dialog
	If CanEditContactInformationTypeInDialog(CIKindInformation.Type) 
		AND Item.Type = FormFieldType.InputField Then
		
		Item.ChoiceButton = Not CIKindInformation.DeletionMark;;
		If CIKindInformation.EditOnlyInDialog Then
			Item.TextEdit = False;
			Item.BackColor = StyleColors.ContactInformationEditedInDialogColor;
		EndIf;
		Item.SetAction("StartChoice", "Attachable_ContactInformationStartChoice");
		
	EndIf;
	Item.SetAction("OnChange", "Attachable_ContactInformationOnChange");
	
	If CIKindInformation.DeletionMark Then
		
		Item.TitleFont       = New Font(,,,,, True);
		If Not CIKindInformation.EditOnlyInDialog Then
			Item.ClearButton        = True;
			Item.TextEdit = False;
		Else
			Item.ReadOnly       = True;
		EndIf;
		
	EndIf;
	
	Return Item;
	
EndFunction

Procedure ItemOfContextMenuMove(PreviousItem, Form, Direction, ItemForPlacementName)
	
	If Direction > 0 Then
		CommandName = "ContextMenuUp" + PreviousItem.Name;
	Else
		CommandName = "ContextMenuDown" + PreviousItem.Name;
	EndIf;
	
	Command = Form.Commands.Add(CommandName);
	Button = Form.Items.Add(CommandName, Type("FormButton"), PreviousItem.ContextMenu);
	
	Command.Action = "Attachable_ContactInformationExecuteCommand";
	If Direction > 0 Then 
		CommandText = NStr("ru = 'Переместить вверх'; en = 'Move up'; pl = 'Przenieś do góry';es_ES = 'Mover hacia arriba';es_CO = 'Mover hacia arriba';tr = 'Yukarı taşı';it = 'Sposta in alto';de = 'Nach oben gehen'");
		Button.Picture = PictureLib.MoveUp;
	Else
		CommandText = NStr("ru = 'Переместить вниз'; en = 'Move down'; pl = 'Przenieś w dół';es_ES = 'Mover hacia abajo';es_CO = 'Mover hacia abajo';tr = 'Aşağı taşı';it = 'Sposta in basso';de = 'Nach unten gehen'");
		Button.Picture = PictureLib.MoveDown;
	EndIf;
	Button.Title = CommandText;
	Command.ToolTip = CommandText;
	Button.CommandName = CommandName;
	Command.ModifiesStoredData = True;
	Button.Enabled = True;
	ContactInformationParameters = FormContactsParameters(Form.ContactInformationParameters, ItemForPlacementName);
	ContactInformationParameters.AddedItems.Add(CommandName, 1);
	ContactInformationParameters.AddedItems.Add(CommandName, 9, True);
	
EndProcedure

// Removes separators from a phone number.
//
// Parameters:
//    PhoneNumber - String - a phone or fax number.
//
// Returns:
//     String - phone or fax number with separators removed.
//
Function RemoveSeparatorsFromPhoneNumber(Val PhoneNumber)
	
	Pos = StrFind(PhoneNumber, ",");
	If Pos <> 0 Then
		PhoneNumber = Left(PhoneNumber, Pos-1);
	EndIf;
	
	PhoneNumber = StrReplace(PhoneNumber, "-", "");
	PhoneNumber = StrReplace(PhoneNumber, " ", "");
	PhoneNumber = StrReplace(PhoneNumber, "+", "");
	
	Return PhoneNumber;
	
EndFunction

Function Folder(NameOfGroup, Form, Header, ItemForPlacementName)
	
	Folder = Form.Items.Find(NameOfGroup);
	
	If Folder = Undefined Then
		Folder = Form.Items.Add(NameOfGroup, Type("FormGroup"), Parent(Form, ItemForPlacementName));
		Folder.Type = FormGroupType.UsualGroup;
		Folder.Title = Header;
		Folder.ShowTitle = False;
		Folder.EnableContentChange = False;
		Folder.Representation = UsualGroupRepresentation.None;
		Folder.Group = ChildFormItemsGroup.Horizontal;
		ContactInformationParameters = FormContactsParameters(Form.ContactInformationParameters, ItemForPlacementName);
		ContactInformationParameters.AddedItems.Add(NameOfGroup, 5);
	EndIf;
	
	Return Folder;
	
EndFunction

Procedure CheckAvailabilityOfContactsAttributes(Form, AttributesToAddArray)
	
	FormAttributeList = Form.GetAttributes();
	
	CreateContactsParameters = True;
	CreateContactsTable = True;
	For Each Attribute In FormAttributeList Do
		If Attribute.Name = "ContactInformationParameters" Then
			CreateContactsParameters = False;
		ElsIf Attribute.Name = "ContactInformationAdditionalAttributeDetails" Then
			CreateContactsTable = False;
		EndIf;
	EndDo;
	
	String500 = New TypeDescription("String", , New StringQualifiers(500));
	DetailsName = "ContactInformationAdditionalAttributeDetails";
	
	If CreateContactsTable Then
		
		// Creating a value table
		DetailsName = "ContactInformationAdditionalAttributeDetails";
		AttributesToAddArray.Add(New FormAttribute(DetailsName, New TypeDescription("ValueTable")));
		AttributesToAddArray.Add(New FormAttribute("AttributeName", String500, DetailsName));
		AttributesToAddArray.Add(New FormAttribute("Kind", New TypeDescription("CatalogRef.ContactInformationKinds"), DetailsName));
		AttributesToAddArray.Add(New FormAttribute("Type", New TypeDescription("EnumRef.ContactInformationTypes"), DetailsName));
		AttributesToAddArray.Add(New FormAttribute("Value", New TypeDescription("String"), DetailsName));
		AttributesToAddArray.Add(New FormAttribute("Presentation", String500, DetailsName));
		AttributesToAddArray.Add(New FormAttribute("Comment", New TypeDescription("String"), DetailsName));
		AttributesToAddArray.Add(New FormAttribute("IsTabularSectionAttribute", New TypeDescription("Boolean"), DetailsName));
		AttributesToAddArray.Add(New FormAttribute("IsHistoricalContactInformation", New TypeDescription("Boolean"), DetailsName));
		AttributesToAddArray.Add(New FormAttribute("ValidFrom", New TypeDescription("Date"), DetailsName));
		AttributesToAddArray.Add(New FormAttribute("StoreChangeHistory", New TypeDescription("Boolean"), DetailsName));
		AttributesToAddArray.Add(New FormAttribute("ItemForPlacementName", String500, DetailsName));
		AttributesToAddArray.Add(New FormAttribute("InternationalAddressFormat", New TypeDescription("Boolean"), DetailsName));
		
	Else
		TableAttributes = Form.GetAttributes("ContactInformationAdditionalAttributeDetails");
		AttributesForCreating = New Map;
		AttributesForCreating.Insert("ItemForPlacementName",            True);
		AttributesForCreating.Insert("StoreChangeHistory",             True);
		AttributesForCreating.Insert("ValidFrom",                          True);
		AttributesForCreating.Insert("IsHistoricalContactInformation", True);
		AttributesForCreating.Insert("Value",                            True);
		AttributesForCreating.Insert("InternationalAddressFormat",           True);
		
		For Each Attribute In TableAttributes Do
			If AttributesForCreating[Attribute.Name] <> Undefined Then
				AttributesForCreating[Attribute.Name] = False;
			EndIf;
		EndDo;
		
		If AttributesForCreating["Value"] Then
			AttributesToAddArray.Add(New FormAttribute("Value", New TypeDescription("String"), DetailsName));
		EndIf;
		
		If AttributesForCreating["InternationalAddressFormat"] Then
			AttributesToAddArray.Add(New FormAttribute("InternationalAddressFormat", New TypeDescription("Boolean"), DetailsName));
		EndIf;
		
		If AttributesForCreating["ItemForPlacementName"] Then
			AttributesToAddArray.Add(New FormAttribute("ItemForPlacementName", String500, DetailsName));
		EndIf;
		
		If AttributesForCreating["StoreChangeHistory"] Then
			AttributesToAddArray.Add(New FormAttribute("StoreChangeHistory", New TypeDescription("Boolean"), DetailsName));
		EndIf;
		
		If AttributesForCreating["ValidFrom"] Then
			AttributesToAddArray.Add(New FormAttribute("ValidFrom", New TypeDescription("Date"), DetailsName));
		EndIf;
		
		If AttributesForCreating["IsHistoricalContactInformation"] Then
			AttributesToAddArray.Add(New FormAttribute("IsHistoricalContactInformation", New TypeDescription("Boolean"), DetailsName));
		EndIf;
		
	EndIf;
	
	If CreateContactsParameters Then
		AttributesToAddArray.Add(New FormAttribute("ContactInformationParameters", New TypeDescription()));
	EndIf;
	
EndProcedure

Procedure SetValidationAttributeValues(Object, ValidationSettings = Undefined)
	
	Object.CheckValidity = ?(ValidationSettings = Undefined, False, ValidationSettings.CheckValidity);
	
	Object.OnlyNationalAddress = False;
	Object.IncludeCountryInPresentation = False;
	Object.HideObsoleteAddresses = False;
	
EndProcedure

Procedure AddAttributeToDetails(Form, ContactInformationRow, ContactsKindsData, IsNewCIKind,
	IsTabularSectionAttribute = False, FillAttributeValue = True, ItemForPlacementName = "ContactInformationGroup")
	
	NewRow = Form.ContactInformationAdditionalAttributeDetails.Add();
	NewRow.AttributeName  = ContactInformationRow.AttributeName;
	NewRow.Kind           = ContactInformationRow.Kind;
	NewRow.Type           = ContactInformationRow.Type;
	NewRow.ItemForPlacementName  = ItemForPlacementName;
	NewRow.IsTabularSectionAttribute = IsTabularSectionAttribute;
	
	If NewRow.Property("IsHistoricalContactInformation") Then
		NewRow.IsHistoricalContactInformation = ContactInformationRow.IsHistoricalContactInformation;
	EndIf;
	
	If NewRow.Property("ValidFrom") Then
		NewRow.ValidFrom = ContactInformationRow.ValidFrom;
	EndIf;
	
	If NewRow.Property("StoreChangeHistory") Then
		NewRow.StoreChangeHistory = ContactInformationRow.StoreChangeHistory;
	EndIf;
	
	If NewRow.Property("InternationalAddressFormat") Then
		NewRow.InternationalAddressFormat = ContactInformationRow.InternationalAddressFormat;
	EndIf;
	
	NewRow.Value      = ContactInformationRow.Value;
	NewRow.Presentation = ContactInformationRow.Presentation;
	NewRow.Comment   = ContactInformationRow.Comment;
	
	If FillAttributeValue AND Not IsTabularSectionAttribute Then
		If ContactInformationRow.Type = Enums.ContactInformationTypes.Address 
			AND ContactInformationRow.EditOnlyInDialog
			AND IsBlankString(ContactInformationRow.Presentation) Then
			Form[ContactInformationRow.AttributeName] = ContactsManagerClientServer.EmptyAddressTextAsHiperlink();
		Else
			Form[ContactInformationRow.AttributeName] = ContactInformationRow.Presentation;
		EndIf;
		
	EndIf;
	
	ContactsKindData = ContactsKindsData[ContactInformationRow.Kind];
	ContactsKindData.Insert("Ref", ContactInformationRow.Kind);
	
	If IsNewCIKind
		AND Not IsTabularSectionAttribute
		AND ContactsKindData.AllowMultipleValueInput
		AND Not ContactsKindData.DeletionMark Then
		ContactInformationParameters = FormContactsParameters(Form.ContactInformationParameters, ItemForPlacementName);
		ContactInformationParameters.ItemsToAddList.Add(ContactsKindData, ContactInformationRow.Kind.Description);
	EndIf;
	
EndProcedure

Procedure DeleteCommandsAndFormItems(Form, ItemForPlacementName)
	
	ContactInformationParameters = FormContactsParameters(Form.ContactInformationParameters, ItemForPlacementName);
	AddedItems = ContactInformationParameters.AddedItems;
	AddedItems.SortByPresentation();
	
	For Each ItemToRemove In AddedItems Do
		
		If ItemToRemove.Check Then
			Form.Commands.Delete(Form.Commands[ItemToRemove.Value]);
		Else
			Form.Items.Delete(Form.Items[ItemToRemove.Value]);
		EndIf;
		
	EndDo;
	
EndProcedure

// Returns the flag specifying whether contact information can be edited in a dialog.
//
// Parameters:
//    Type - EnumRef.ContactInformationTypes - a contact information type.
//
// Returns:
//    Boolean - dialog information edit flag.
//
Function CanEditContactInformationTypeInDialog(Type)
	
	If Type = Enums.ContactInformationTypes.Address Then
		Return True;
	ElsIf Type = Enums.ContactInformationTypes.Phone Then
		Return True;
	ElsIf Type = Enums.ContactInformationTypes.Fax Then
		Return True;
	Else
		Return False;
	EndIf;
	
EndFunction

// Returns the name of the document tabular section by the contacts kind.
//
// Parameters:
//    CIKind - CatalogRef.ContactsKinds - a kind of contacts.
//    ObjectName - String - a full name of a metadata object.
//
// Returns:
//    String - a tabular section name, or an empty string if tabular section is not available.
//
Function TabularSectionNameByCIKind(CIKind, ObjectName)
	
	Query = New Query;
	Query.Text = "SELECT
	|	ContactInformationKinds.Parent.PredefinedDataName AS ContactsKindName
	|FROM
	|	Catalog.ContactInformationKinds AS ContactInformationKinds
	|WHERE
	|	ContactInformationKinds.Ref = &Ref";
	
	Query.SetParameter("Ref", CIKind);
	QueryResult = Query.Execute().Select();
	
	If QueryResult.Next() Then
		Return Mid(QueryResult.ContactsKindName, 
		StrFind(QueryResult.ContactsKindName, ObjectName) + StrLen(ObjectName));
	EndIf;
	
	Return "";
	
EndFunction

// Returns the names of document tabular sections by the contacts kind.
//
// Parameters:
//    ContactsKindsTable = ValurTable - a list of contacts kinds.
//     * Kind - CatalogRef.ContactsKinds - a kind of contacts.
//    ObjectName - String - a full name of a metadata object.
//
// Returns:
//    Map - tabular section names, or an empty string if tabular section is not available.
//
Function NamesOfTabularSectionsByContactsKinds(ContactsKindsTable, ObjectName)
	
	Query = New Query;
	Query.Text = "SELECT
	|	ContactInformationKinds.Kind AS CIKind
	|INTO CIKinds
	|FROM
	|	&ContactInformationKindsTable AS ContactInformationKinds
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ContactInformationKinds.Parent.PredefinedDataName AS TabularSectionName,
	|	CIKinds.CIKind AS ContactInformationKind
	|FROM
	|	CIKinds AS CIKinds
	|		LEFT JOIN Catalog.ContactInformationKinds AS ContactInformationKinds
	|		ON CIKinds.CIKind = ContactInformationKinds.Ref";
	
	Query.SetParameter("ContactInformationKindsTable", ContactsKindsTable);
	QueryResult = Query.Execute().Select();
	
	Result = New Map;
	While QueryResult.Next() Do
		
		If ValueIsFilled(QueryResult.TabularSectionName) Then
			TabularSectionName = Mid(QueryResult.TabularSectionName, StrFind(QueryResult.TabularSectionName, ObjectName) + StrLen(ObjectName));
		Else
			TabularSectionName = "";
		EndIf;
		
		Result.Insert(QueryResult.ContactInformationKind, TabularSectionName);
	EndDo;
	
	Return Result;
	
EndFunction

// Checks if the form contains filled CI strings of the same type (except for the current one).
//
Function HasOtherStringsFilledWithThisContactInformationKind(Val Form, Val StringToValidate, Val ContactInformationKind)
	
	AllRowsOfThisKind = Form.ContactInformationAdditionalAttributeDetails.FindRows(
	New Structure("Kind", ContactInformationKind));
	
	For Each RowOfThisKind In AllRowsOfThisKind Do
		
		If RowOfThisKind <> StringToValidate Then
			Presentation = Form[RowOfThisKind.AttributeName];
			If Not IsBlankString(Presentation) Then 
				Return True;
			EndIf;
		EndIf;
		
	EndDo;
	
	Return False;
EndFunction

Procedure OutputUserMessage(MessageText, AttributeName, AttributeField)
	
	AttributeName = ?(IsBlankString(AttributeField), AttributeName, "");
	CommonClientServer.MessageToUser(MessageText,, AttributeField, AttributeName);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Filling additional attributes of Contact information tabular section.

Procedure CreateTabularSectionItems(Val Form, Val ObjectName, ItemForPlacementName, 
	Val ContactInformationRow, Val ContactsKindsData)
	
	TabularSectionContactsKinds = New Array;
	For Each TabularSectionRow In ContactInformationRow.Rows Do
		TabularSectionContactsKinds.Add(TabularSectionRow.Kind);
	EndDo;
	DataOfTabularSectionContactsKinds = ContactsManagerInternal.ContactsKindsData(
		TabularSectionContactsKinds);
	
	ContactsKindName = ContactsKindsData[ContactInformationRow.Kind].PredefinedDataName;
	Position = StrFind(ContactsKindName, ObjectName);
	TabularSectionName = Mid(ContactsKindName, Position + StrLen(ObjectName));
	PreviousTabularSectionKind = Undefined;
	
	For Each TabularSectionRow In ContactInformationRow.Rows Do
		
		TabularSectionContactsKind = TabularSectionRow.Kind;
		If TabularSectionContactsKind <> PreviousTabularSectionKind Then
			
			TabularSectionGroup = Form.Items[TabularSectionName + "ContactInformationGroup"];
			
			Item = Form.Items.Add(TabularSectionRow.AttributeName, Type("FormField"), TabularSectionGroup);
			Item.Type = FormFieldType.InputField;
			Item.DataPath = "Object." + TabularSectionName + "." + TabularSectionRow.AttributeName;
			
			If CanEditContactInformationTypeInDialog(TabularSectionRow.Type) Then
				Item.ChoiceButton = Not TabularSectionRow.DeletionMark;;
				If TabularSectionContactsKind.EditOnlyInDialog Then
					Item.TextEdit = False;
				EndIf;
				
				Item.SetAction("StartChoice", "Attachable_ContactInformationStartChoice");
			EndIf;
			Item.SetAction("OnChange", "Attachable_ContactInformationOnChange");
			
			If TabularSectionRow.DeletionMark Then
				Item.Font = New Font(,,,,, True);
				Item.TextEdit = False;
			EndIf;
			
			If TabularSectionContactsKind.Mandatory Then
				Item.AutoMarkIncomplete = Not TabularSectionRow.DeletionMark;
			EndIf;
			
			Form.ContactInformationParameters[ItemForPlacementName].AddedItems.Add(TabularSectionRow.AttributeName,
				2, False);
			
			AddAttributeToDetails(Form, TabularSectionRow, DataOfTabularSectionContactsKinds, False, True,, ItemForPlacementName);
			PreviousTabularSectionKind = TabularSectionContactsKind;
			
		EndIf;
		
		Filter = New Structure;
		Filter.Insert("ContactLineIdentifier", TabularSectionRow.ContactLineIdentifier);
		
		TableRows = Form.Object[TabularSectionName].FindRows(Filter);
		
		If TableRows.Count() = 1 Then
			TableRow = TableRows[0];
			TableRow[TabularSectionRow.AttributeName]                   = TabularSectionRow.Presentation;
			TableRow[TabularSectionRow.AttributeName + "Value"]      = TabularSectionRow.Value;
		EndIf;
	EndDo;

EndProcedure

Procedure FillContactsTechnicalFields(ContactInformationRow, Object, ContactInformationType)
	
	// Filling in additional attributes of the tabular section.
	If ContactInformationType = Enums.ContactInformationTypes.EmailAddress Then
		FillTabularSectionAttributesForEmailAddress(ContactInformationRow, Object);
		
	ElsIf ContactInformationType = Enums.ContactInformationTypes.Address Then
		FillTabularSectionAttributesForAddress(ContactInformationRow, Object);
		
	ElsIf ContactInformationType = Enums.ContactInformationTypes.Phone Then
		FillTabularSectionAttributesForPhone(ContactInformationRow, Object);
		
	ElsIf ContactInformationType = Enums.ContactInformationTypes.Fax Then
		FillTabularSectionAttributesForPhone(ContactInformationRow, Object);
		
	ElsIf ContactInformationType = Enums.ContactInformationTypes.WebPage Then
		FillTabularSectionAttributesForWebPage(ContactInformationRow, Object);
	EndIf;
	
EndProcedure

// Fills the additional attributes of Contact information tabular section for an address.
//
// Parameters:
//    TabularSectionRow - TabularSectionRow - the Contact information tabular section row to be filled.
//    Source - XDTOObject - contact information.
//
Procedure FillTabularSectionAttributesForAddress(TabularSectionRow, Address)
	
	// Default preferences
	TabularSectionRow.Country = "";
	TabularSectionRow.State = "";
	TabularSectionRow.City  = "";
	
	Namespace = ContactsManagerClientServer.Namespace();
	If Address.Property("Country") Then
		TabularSectionRow.Country =  Address.Country;
		
		If Metadata.DataProcessors.Find("AdvancedContactInformationInput") <> Undefined Then
			DataProcessors["AdvancedContactInformationInput"].FillExtendedTabularSectionAttributesForAddress(Address, TabularSectionRow);
		EndIf;
		
	EndIf;
	
EndProcedure

// Fills the additional attributes of Contact information tabular section for an email address.
//
// Parameters:
//    TabularSectionRow - TabularSectionRow - the Contact information tabular section row to be filled.
//    Source - XDTOObject - contact information.
//
Procedure FillTabularSectionAttributesForEmailAddress(TabularSectionRow, Source)
	
	Result = CommonClientServer.ParseStringWithEmailAddresses(TabularSectionRow.Presentation, False);
	
	If Result.Count() > 0 Then
		TabularSectionRow.EMAddress = Result[0].Address;
		
		Pos = StrFind(TabularSectionRow.EMAddress, "@");
		If Pos <> 0 Then
			TabularSectionRow.ServerDomainName = Mid(TabularSectionRow.EMAddress, Pos+1);
		EndIf;
	EndIf;
	
EndProcedure

// Fills the additional attributes of Contact information tabular section for phone and fax numbers.
//
// Parameters:
//    TabularSectionRow - TabularSectionRow - the Contact information tabular section row to be filled.
//    Source - XDTOObject - contact information.
//
Procedure FillTabularSectionAttributesForPhone(TabularSectionRow, Phone)
	
	If NOT ValueIsFilled(Phone) Then
		Return;
	EndIf;
	
	// Default preferences
	TabularSectionRow.PhoneNumberWithoutCodes = "";
	TabularSectionRow.PhoneNumber         = "";
	
	CountryCode     = Phone.CountryCode;
	CityCode     = Phone.AreaCode;
	PhoneNumber = Phone.Number;
	
	If StrStartsWith(CountryCode, "+") Then
		CountryCode = Mid(CountryCode, 2);
	EndIf;
	
	Pos = StrFind(PhoneNumber, ",");
	If Pos <> 0 Then
		PhoneNumber = Left(PhoneNumber, Pos-1);
	EndIf;
	
	Pos = StrFind(PhoneNumber, Chars.LF);
	If Pos <> 0 Then
		PhoneNumber = Left(PhoneNumber, Pos-1);
	EndIf;
	
	TabularSectionRow.PhoneNumberWithoutCodes = RemoveSeparatorsFromPhoneNumber(PhoneNumber);
	TabularSectionRow.PhoneNumber         = RemoveSeparatorsFromPhoneNumber(String(CountryCode) + CityCode + PhoneNumber);
	
EndProcedure

// Fills the additional attributes of Contact information tabular section for phone and fax numbers.
//
// Parameters:
//    TabularSectionRow - TabularSectionRow - the Contact information tabular section row to be filled.
//    Source - Structure, XDTOObject - contact information.
//
Procedure FillTabularSectionAttributesForWebPage(TabularSectionRow, Source)
	
// Default preferences
	TabularSectionRow.ServerDomainName = "";
	PageAddress = "";
	
	If TypeOf(Source) = Type("Structure") Then
		
		If Source.Property("value") Then
			AddressAsString = Source.value;
		EndIf;
		
	Else
		
		PageAddress = Source.Content;
		Namespace = ContactsManagerClientServer.Namespace();
		If PageAddress <> Undefined AND PageAddress.Type() = XDTOFactory.Type(Namespace, "Website") Then
			AddressAsString = PageAddress.Value;
		EndIf;
		
	EndIf;
	
	// Deleting the protocol
	Position = StrFind(AddressAsString, "://");
	ServerAddress = ?(Position = 0, AddressAsString, Mid(AddressAsString, Position + 3));
	
	TabularSectionRow.ServerDomainName = ServerAddress;
	
EndProcedure

// Fills contacts in the Contact information tabular section of the target.
//
// Parameters:
//        * Destination - Arbitrary - an object whose contacts must be filled in.
//        * CIKind - CatalogRef.ContactsKinds - a contacts kind filled in the target.
//                                                                    
//        * CIStructure - ValueList, String, Structure - data of contacts field values.
//        * TabularSectionRow - TabularSectionRow, Undefined - target data if contacts are filled 
//                                 for a row.
//                                                                      Undefined if contacts are 
//                                                                      filled for the target.
//        * Date - Date - a date for which contacts are valid. Used only if the StoreChangeHistory 
//                                check box is selected for the CI kind.
//
Procedure FillTabularSectionContactInformation(Destination, CIKind, CIStructure, TabularSectionRow = Undefined, Date = Undefined)
	
	FilterParameters = New Structure;
	If TabularSectionRow <> Undefined Then
		FilterParameters.Insert("ContactLineIdentifier", TabularSectionRow.ContactLineIdentifier);
	EndIf;
	
	FilterParameters.Insert("Kind", CIKind);
	FoundCIRows = Destination.ContactInformation.FindRows(FilterParameters);
	If FoundCIRows.Count() = 0 Then
		CIRow = Destination.ContactInformation.Add();
		If TabularSectionRow <> Undefined Then
			CIRow.ContactLineIdentifier = TabularSectionRow.ContactLineIdentifier;
		EndIf;
	Else
		CIRow = FoundCIRows[0];
	EndIf;
	
	// Converting from any readable format in XML.
	FieldsValues = ContactInformationToXML(CIStructure, , CIKind);
	Presentation = ContactInformationPresentation(FieldsValues);
	
	CIRow.Type           = CIKind.Type;
	CIRow.Kind           = CIKind;
	CIRow.Presentation = Presentation;
	CIRow.FieldsValues = FieldsValues;
	
	If CIKind.StoreChangeHistory Then
		CIRow.ValidFrom = ?(ValueIsFilled(Date), Date, CurrentSessionDate());
	EndIf;
	
	FillContactInformationAdditionalAttributes(CIRow, Presentation, FieldsValues);
EndProcedure

// Validates an email contact information and reports any errors.
//
// Parameters:
//     EmailAddress - Structure, String - contacts.
//     InformationKind - CatalogRef.ContactsKinds - a contact information kind with with validation settings.
//     AttributeName - String - an optional name of the attribute used to link the error message.
//
// Returns:
//     Number - error level: 0 - no, 1 - noncritical, 2 - critical.
//
Function EmailFIllingErrors(EMAddress, InformationKind, Val AttributeName = "", AttributeField = "")
	
	If Not InformationKind.CheckValidity Then
		Return 0;
	EndIf;
	
	If Not ValueIsFilled(EMAddress) Then
		Return 0;
	EndIf;
	
	ErrorRow = "";
	Email = ContactsManagerInternal.JSONStringToStructure(EMAddress);
	
	Try
		Result = CommonClientServer.ParseStringWithEmailAddresses(Email.Value);
		If Result.Count() > 1 Then
			
			ErrorRow = NStr("ru = 'Допускается ввод только одного адреса электронной почты'; en = 'Only one email address is allowed'; pl = 'Możesz wpisać tylko jeden adres e-mail';es_ES = 'Usted puede introducir sola la dirección de correo electrónico';es_CO = 'Usted puede introducir sola la dirección de correo electrónico';tr = 'Sadece bir e-posta adresini girebilirsiniz';it = 'Solo un indirizzo email è permesso';de = 'Sie können nur eine E-Mail-Adresse eingeben'");
			
		EndIf;
	Except
		ErrorRow = BriefErrorDescription(ErrorInfo());
	EndTry;
	
	If Not IsBlankString(ErrorRow) Then
		OutputUserMessage(ErrorRow, AttributeName, AttributeField);
		ErrorLevel = ?(InformationKind.CheckValidity, 2, 1);
	Else
		ErrorLevel = 0;
	EndIf;
	
	Return ErrorLevel;
	
EndFunction

// Fills the additional attributes of the Contact information tabular section row.
//
// Parameters:
//    CIRow - TabularSectionRow - a Contact information row.
//    Presentation - String - value presentation.
//    FieldsValues - ValueList, XDTOObject - field values.
//
Procedure FillContactInformationAdditionalAttributes(CIRow, Presentation, FieldsValues)
	
	If TypeOf(FieldsValues) = Type("XDTODataObject") Then
		CIObject = FieldsValues;
	Else
		CIObject = ContactsManagerInternal.ContactsFromXML(FieldsValues, CIRow.Kind);
	EndIf;
	
	InformationType = CIRow.Type;
	
	If InformationType = Enums.ContactInformationTypes.EmailAddress Then
		FillTabularSectionAttributesForEmailAddress(CIRow, CIObject);
		
	ElsIf InformationType = Enums.ContactInformationTypes.Address Then
		FillTabularSectionAttributesForAddress(CIRow, CIObject);
		
	ElsIf InformationType = Enums.ContactInformationTypes.Phone Then
		FillTabularSectionAttributesForPhone(CIRow, CIObject);
		
	ElsIf InformationType = Enums.ContactInformationTypes.Fax Then
		FillTabularSectionAttributesForPhone(CIRow, CIObject);
		
	ElsIf InformationType = Enums.ContactInformationTypes.WebPage Then
		FillTabularSectionAttributesForWebPage(CIRow, CIObject);
		
	EndIf;
	
EndProcedure

// Checks contact information.
//
Function CheckFillingContacts(Presentation, Value, InformationKind, InformationType,
	AttributeName, Comment = Undefined, AttributePath = "")
	
	If IsBlankString(Value) Then
		
		If IsBlankString(Presentation) Then
			Return 0;
		EndIf;
		
		EditingOnlyInDialog = Common.ObjectAttributeValue(InformationKind, "EditOnlyInDialog");
		If EditingOnlyInDialog AND StrCompare(Presentation, ContactsManagerClientServer.EmptyAddressTextAsHiperlink()) = 0 Then
			Return 0;
		EndIf;
		
		ContactInformation = ContactsManagerInternal.ContactsByPresentation(Presentation, InformationKind);
		Value = ?(TypeOf(ContactInformation) = Type("Structure"), ContactsManagerInternal.ToJSONStringStructure(ContactInformation), "");
		
	ElsIf ContactsManagerClientServer.IsXMLContactInformation(Value) Then
		
		Value = ContactInformationInJSON(Value, InformationKind);
		
	EndIf;
	
	// CheckSSL
	If InformationType = Enums.ContactInformationTypes.EmailAddress Then
		ErrorsLevel = EmailFIllingErrors(Value, InformationKind, AttributeName, AttributePath);
	ElsIf InformationType = Enums.ContactInformationTypes.Address Then
		ErrorsLevel = AddressFillErrors(Value, InformationKind, AttributeName, AttributePath);
	ElsIf InformationType = Enums.ContactInformationTypes.Phone Then
		ErrorsLevel = PhoneFillingErrors(Value, InformationKind, AttributeName);
	ElsIf InformationType = Enums.ContactInformationTypes.Fax Then
		ErrorsLevel = PhoneFillingErrors(Value, InformationKind, AttributeName);
	ElsIf InformationType = Enums.ContactInformationTypes.WebPage Then
		ErrorsLevel = WebpageFillingErrors(Value, InformationKind, AttributeName);
	Else
		// No other checks are made.
		ErrorsLevel = 0;
	EndIf;
	
	Return ErrorsLevel;
	
EndFunction

// Getting and correcting contacts
Procedure CorrectContacts(Form, CIRow)
	
	ConversionResult = New Structure;
	
	If IsBlankString(CIRow.Value) Then
		
		If IsBlankString(CIRow.Presentation) AND ValueIsFilled(CIRow.FieldsValues) Then
			CIRow.Presentation = ContactsManagerInternal.ContactInformationPresentation(CIRow.FieldsValues, CIRow.Kind);
		EndIf;
		
		Result = ContactsManagerInternal.ContactsFromXML(CIRow.FieldsValues, CIRow.Kind, ConversionResult, CIRow.Presentation);
		CIRow.Comment = ?(ValueIsFilled(Result.Comment), Result.Comment, "");
		
		If ConversionResult.Count() = 0 Then
			Return;
		EndIf;
			
		If Not ConversionResult.Property("InfoCorrected") OR ConversionResult.InfoCorrected = False Then
			Return;
		EndIf;
		
		If ConversionResult.InfoCorrected Then
			CIRow.FieldsValues = ContactsManagerInternal.XDTOContactsInXML(Result);
		EndIf;

		If ConversionResult.Property("ErrorText") Then
			CommonClientServer.MessageToUser(ConversionResult.ErrorText, , CIRow.AttributeName);
		EndIf;
		
		Form.Modified = True;
		
	Else
		
		CIRow.Comment = ContactInformationComment(CIRow.Value);
		
		If IsBlankString(CIRow.Presentation) Then
			CIRow.Presentation = ContactInformationPresentation(CIRow.Value);
		EndIf;
		
	EndIf;
	
EndProcedure

// Validates an address contact information and reports any errors. Returns the flag of errors.
//
// Parameters:
//     Source - XDTOObject - contact information.
//     InformationKind - CatalogRef.ContactsKinds - a contact information kind with with validation settings.
//     AttributeName - String - an optional name of the attribute used to link the error message.
//
// Returns:
//     Number - error level: 0 - no, 1 - noncritical, 2 - critical.
//
Function AddressFillErrors(Source, InformationKind, AttributeName = "", AttributeField = "")
	
	If Not InformationKind.CheckValidity Then
		Return 0;
	EndIf;
	HasErrors = False;
	
	If NOT ContactsManagerInternal.IsNationalAddress(Source) Then
		Return 0;
	EndIf;
	
	If Metadata.DataProcessors.Find("AdvancedContactInformationInput") <> Undefined Then
		ErrorsList = DataProcessors["AdvancedContactInformationInput"].XDTOAddressFillingErrors(Source, InformationKind);
		For Each Item In ErrorsList Do
			OutputUserMessage(Item.Presentation, AttributeName, AttributeField);
			HasErrors = True;
		EndDo;
	EndIf;
	
	If HasErrors AND InformationKind.CheckValidity Then
		Return 2;
	ElsIf HasErrors Then
		Return 1;
	EndIf;
	
	Return 0;
EndFunction

// Validates a phone contact information and reports any errors. Returns the flag of errors.
//
// Parameters:
//     Source - XDTOObject - contact information.
//     InformationKind - CatalogRef.ContactsKinds - a contact information kind with with validation settings.
//     AttributeName - String - an optional name of the attribute used to link the error message.
//
// Returns:
//     Number - error level: 0 - no, 1 - noncritical, 2 - critical.
//
Function PhoneFillingErrors(Source, InformationKind, AttributeName = "")
	Return 0;
EndFunction

// Validates a webpage contact information and reports any errors. Returns the flag of errors.
//
// Parameters:
//     Source - XDTOObject - contact information.
//     InformationKind - CatalogRef.ContactsKinds - a contact information kind with with validation settings.
//     AttributeName - String - an optional name of the attribute used to link the error message.
//
// Returns:
//     Number - error level: 0 - no, 1 - noncritical, 2 - critical.
//
Function WebpageFillingErrors(Source, InformationKind, AttributeName = "")
	Return 0;
EndFunction

Procedure ObjectContactInformationFilling(Object, Val FillingData)
	
	If TypeOf(FillingData) <> Type("Structure") Then
		Return;
	EndIf;
	
	// Description, if available in the вestination object.
	Description = Undefined;
	If FillingData.Property("Description", Description)
		AND CommonClientServer.HasAttributeOrObjectProperty(Object, "Description") Then
		Object.Description = Description;
	EndIf;
	
	// Contacts table, filled only if CI is not in another tabular section.
	ContactInformation = Undefined;
	If FillingData.Property("ContactInformation", ContactInformation) 
		AND CommonClientServer.HasAttributeOrObjectProperty(Object, "ContactInformation") Then
		
		If TypeOf(ContactInformation) = Type("ValueTable") Then
			TableColumns = ContactInformation.Columns;
		Else
			TableColumns = ContactInformation.UnloadColumns().Columns;
		EndIf;
		
		If TableColumns.Find("ContactLineIdentifier") = Undefined Then
			
			For Each CIRow In ContactInformation Do
				NewCIRow = Object.ContactInformation.Add();
				FillPropertyValues(NewCIRow, CIRow, , "FieldsValues");
				NewCIRow.FieldsValues = ContactInformationToXML(CIRow.FieldsValues, CIRow.Presentation, CIRow.Kind);
			EndDo;
			
		EndIf;
		
	EndIf;
	
EndProcedure

Function Parent(Form, ItemForPlacementName)
	
	Return ?(IsBlankString(ItemForPlacementName), Form, Form.Items[ItemForPlacementName])
	
EndFunction

Function ContactsOutputParameters(Form, ItemForPlacementName, TitleLocationContactInformation, DeferredInitialization, ExcludedKinds)
	
	If TypeOf(Form.ContactInformationParameters) <> Type("Structure") Then
		Form.ContactInformationParameters = New Structure;
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.SMS") Then
		ModuleSMS  = Common.CommonModule("SMS");
		CanSendSMSMessage = ModuleSMS.CanSendSMSMessage();
	Else
		CanSendSMSMessage = False;
	EndIf;
	
	ContactInformationParameters = New Structure;
	ContactInformationParameters.Insert("GroupForPlacement",              ItemForPlacementName);
	ContactInformationParameters.Insert("TitleLocation",               ValueOfCITitleLocation(TitleLocationContactInformation));
	ContactInformationParameters.Insert("AddedAttributes",             New ValueList); 
	ContactInformationParameters.Insert("DeferredInitialization",          DeferredInitialization);
	ContactInformationParameters.Insert("ExcludedKinds",                  ExcludedKinds);
	ContactInformationParameters.Insert("DeferredInitializationExecuted", False);
	ContactInformationParameters.Insert("AddedItems",              New ValueList);
	ContactInformationParameters.Insert("ItemsToAddList",       New ValueList);
	ContactInformationParameters.Insert("CanSendSMSMessage",               CanSendSMSMessage);
	ContactInformationParameters.Insert("Owner",                         Undefined);
	
	AddressParameters = New Structure("PremiseType, Country, IndexOf", "Apartment");
	ContactInformationParameters.Insert("AddressParameters", AddressParameters);
	
	Form.ContactInformationParameters.Insert(ItemForPlacementName, ContactInformationParameters);
	Return Form.ContactInformationParameters[ItemForPlacementName];
	
EndFunction

Function ObjectContactsKindsGroup(Val FullMetadataObjectName)
	
	Return Catalogs.ContactInformationKinds[StrReplace(FullMetadataObjectName, ".", "")];
	
EndFunction

// Defines the value of title location. To support localized configurations.
//
// Parameters:
//  CITitleLocation - String - a title location in text presentation in the localization language.
// 
// Returns:
//  String - title location.
//
Function ValueOfCITitleLocation(TitleLocationContactInformation)
	
	If FormItemTitleLocation.Left = TitleLocationContactInformation Then
		Return "FormItemTitleLocation.Left";
	ElsIf FormItemTitleLocation.Top = TitleLocationContactInformation Then
		Return "FormItemTitleLocation.Top";
	ElsIf FormItemTitleLocation.Bottom = TitleLocationContactInformation Then
		Return "FormItemTitleLocation.Bottom";
	ElsIf FormItemTitleLocation.Right = TitleLocationContactInformation Then
		Return "FormItemTitleLocation.Right";
	ElsIf FormItemTitleLocation.None = TitleLocationContactInformation Then
		Return "FormItemTitleLocation.None";
	ElsIf FormItemTitleLocation.Auto = TitleLocationContactInformation Then
		Return "FormItemTitleLocation.Auto";
	EndIf;
	
	Return "";
	
EndFunction

// Returns contact information kinds by a name.
// If no name is specified, a full list of predefined kinds is returned by the application.
//
// Returns:
//  ValueTable  - contact information kinds, where:
//    * Name - String - a name of a contact information kind.
//    * Ref - CatalogRef.ContactInformationKinds - a reference to an item of the contact information kind catalog.
//
Function PredefinedContactInformationKinds(Name = "") Export
	
	QueryText = "SELECT
		|	ContactInformationKinds.PredefinedKindName AS Name,
		|	ContactInformationKinds.Ref AS Ref
		|FROM
		|	Catalog.ContactInformationKinds AS ContactInformationKinds
		|WHERE
		|	&Filter";
	
	Query = New Query();
	If ValueIsFilled(Name) Then
		QueryText = StrReplace(QueryText, "&Filter", "ContactInformationKinds.PredefinedKindName = &Name");
		Query.SetParameter("Name", Name);
	Else
		QueryText = StrReplace(QueryText, "&Filter", "ContactInformationKinds.PredefinedKindName <> """"");
	EndIf;
	
	Query.Text = QueryText;
	Return Query.Execute().Unload();
	
EndFunction

Procedure CreateAction(Form, ContactInformationKind, AttributeName, ActionGroup, AddressCount, HasComment = False, ItemForPlacementName = "ContactInformationGroup")
	
	Type = ContactInformationKind.Type;
	CreateActionForType = New Map();
	CreateActionForType.Insert(Enums.ContactInformationTypes.WebPage, True);
	CreateActionForType.Insert(Enums.ContactInformationTypes.EmailAddress, True);
	CreateActionForType.Insert(Enums.ContactInformationTypes.Phone, True);
	CreateActionForType.Insert(Enums.ContactInformationTypes.Address, ?(AddressCount > 0, True, False));
	CreateActionForType.Insert(Enums.ContactInformationTypes.Skype, True);
	
	If Type = Enums.ContactInformationTypes.EmailAddress Then
		If Common.SubsystemExists("StandardSubsystems.EmailOperations") Then
			ModuleEmail = Common.CommonModule("EmailOperations");
			If NOT ModuleEmail.CanSendEmails() Then
				CreateActionForType[Type] = False;
			EndIf;
		Else
			CreateActionForType[Type] = False;
		EndIf;
	ElsIf Type = Enums.ContactInformationTypes.Address AND ContactInformationKind.EditOnlyInDialog Then
		CreateActionForType[Type] = False;
	EndIf;
	
	ContactInformationParameters = FormContactsParameters(Form.ContactInformationParameters, ItemForPlacementName);
	If CreateActionForType[Type] = True Then
		
		If Type = Enums.ContactInformationTypes.Address Then
			GroupTopLevelSubmenu = Form.Items.Add("CommandBar" + AttributeName, Type("FormGroup"), ActionGroup);
			GroupTopLevelSubmenu.Type = FormGroupType.CommandBar;
			SubmenuGroup = Form.Items.Add("Popup" + AttributeName, Type("FormGroup"), GroupTopLevelSubmenu);
			SubmenuGroup.Type = FormGroupType.Popup;
			SubmenuGroup.Picture = PictureLib.MenuAdditionalFunctions;
			SubmenuGroup.Representation = ButtonRepresentation.Picture;
		Else
			SubmenuGroup = ActionGroup;
			
			// Action is available
			CommandName = "Command" + AttributeName;
			Command = Form.Commands.Add(CommandName);
			
			ContactInformationParameters.AddedItems.Add(CommandName, 9, True);
			Command.Representation = ButtonRepresentation.Picture;
			Command.Action = "Attachable_ContactInformationExecuteCommand";
			
			Item = Form.Items.Add(CommandName,Type("FormButton"), SubmenuGroup);
			ContactInformationParameters.AddedItems.Add(CommandName, 2);
			Item.CommandName = CommandName;
		EndIf;
		
		If Type = Enums.ContactInformationTypes.Address Then
			
			If Not ContactInformationKind.DeletionMark Then
				// Entering comment via context menu.
				CommandName = "ContextMenuSubmenu" + AttributeName;
				Button = Form.Items.Add(CommandName,Type("FormButton"), SubmenuGroup);
				Button.Title = NStr("ru = 'Ввести комментарий'; en = 'Enter comment'; pl = 'Wpisz komentarz';es_ES = 'Introducir un comentario';es_CO = 'Introducir un comentario';tr = 'Yorum gir';it = 'Inserisci commento';de = 'Geben Sie einen Kommentar ein'");
				Command = Form.Commands.Add(CommandName);
				Command.ToolTip = NStr("ru = 'Ввести комментарий'; en = 'Enter comment'; pl = 'Wpisz komentarz';es_ES = 'Introducir un comentario';es_CO = 'Introducir un comentario';tr = 'Yorum gir';it = 'Inserisci commento';de = 'Geben Sie einen Kommentar ein'");
				Command.Picture = PictureLib.Comment;
				Command.Action = "Attachable_ContactInformationExecuteCommand";
				Command.ModifiesStoredData = True;
				Button.CommandName = CommandName;
				
				ContactInformationParameters.AddedItems.Add(CommandName, 1);
				ContactInformationParameters.AddedItems.Add(CommandName, 9, True);
			EndIf;
			
			// Change history
			If ContactInformationKind.StoreChangeHistory AND Not ContactInformationKind.DeletionMark Then
				
				CommandName = "ContextMenuSubmenuHistory" + AttributeName;
				Button = Form.Items.Add(CommandName, Type("FormButton"), SubmenuGroup);
				Button.Title = NStr("ru = 'История изменений...'; en = 'Change history...'; pl = 'Historia zmian...';es_ES = 'Historia de cambios...';es_CO = 'Historia de cambios...';tr = 'Değişiklik geçmişi...';it = 'Modifica storico...';de = 'Der Verlauf der Änderung...'");
				Command = Form.Commands.Add(CommandName);
				Command.Picture = PictureLib.ChangeHistory;
				Command.ToolTip = NStr("ru = 'Показывает историю изменения контактной информации'; en = 'Shows change history of contact information'; pl = 'Pokazuje historię zmian informacji kontaktowej';es_ES = 'Muestra el historial del cambio de la información de contacto';es_CO = 'Muestra el historial del cambio de la información de contacto';tr = 'İletişim bilgilerinin değişiklik geçmişini gösterir';it = 'Mostra lo storico cambiamenti delle informazioni di contatto';de = 'Zeigt den Verlauf der Änderungen in den Kontaktinformationen an'");
				Command.Action = "Attachable_ContactInformationExecuteCommand";
				Command.ModifiesStoredData = False;
				Button.CommandName = CommandName;
				
				ContactInformationParameters.AddedItems.Add(CommandName, 1);
				ContactInformationParameters.AddedItems.Add(CommandName, 9, True);
			EndIf;
			
			// Sets properties of the input field.
			SeparatorGroup = Form.Items.Add("SubmenuSeparatorAddress" + AttributeName, Type("FormGroup"), SubmenuGroup);
			SeparatorGroup.Type = FormGroupType.ButtonGroup;
			
			CommandName = "GoogleMapMenu" + AttributeName;
			Button = Form.Items.Add(CommandName,Type("FormButton"), SeparatorGroup);
			Button.Title = NStr("ru = 'Адрес на Google Картах'; en = 'Address on Google Maps'; pl = 'Adres w Mapach Google';es_ES = 'Dirección en Google Maps';es_CO = 'Dirección en Google Maps';tr = 'Google Maps''te adres';it = 'Indirizzo su Google Maps';de = 'Adresse in Google Maps'");
			Command = Form.Commands.Add(CommandName);
			Command.Picture = PictureLib.GoogleMaps;
			Command.ToolTip = NStr("ru = 'Показывает адрес на карте Google Maps'; en = 'Shows address on Google Maps'; pl = 'Pokaż adres w Mapach Google';es_ES = 'Mostrar la dirección en Google Maps';es_CO = 'Mostrar la dirección en Google Maps';tr = 'Adresi Google Maps''te gösterir';it = 'Mostra indirizzo su Google Maps';de = 'Adresse in Google Maps anzeigen'");
			Command.Action = "Attachable_ContactInformationExecuteCommand";
			Button.CommandName = CommandName;
			
			ContactInformationParameters.AddedItems.Add(CommandName, 1);
			ContactInformationParameters.AddedItems.Add(CommandName, 9, True);
			
			If Not ContactInformationKind.DeletionMark Then
				
				SeparatorGroup = Form.Items.Add("SubmenuSeparator" + AttributeName, Type("FormGroup"), SeparatorGroup);
				SeparatorGroup.Type = FormGroupType.ButtonGroup;
				
				GroupAddressSubmenu = Form.Items.Add("SubmenuCopyAddresses" + AttributeName, Type("FormGroup"), SeparatorGroup);
				GroupAddressSubmenu.Type = FormGroupType.Popup;
				GroupAddressSubmenu.Representation = ButtonRepresentation.Text;
				GroupAddressSubmenu.Title = NStr("ru='Заполнить'; en = 'Fill in'; pl = 'Wypełnij';es_ES = 'Rellenar';es_CO = 'Rellenar';tr = 'Doldur';it = 'Compila';de = 'Ausfüllen'");
			
			EndIf;
			
		ElsIf Type = Enums.ContactInformationTypes.WebPage Then
			
			Item.Title = NStr("ru = 'Перейти'; en = 'Navigate'; pl = 'Przejdź';es_ES = 'Navegar';es_CO = 'Navegar';tr = 'Geçiş yapın';it = 'Navigare';de = 'Navigieren'");
			Command.ToolTip = NStr("ru = 'Перейти по ссылке'; en = 'Go to URL'; pl = 'Kliknij URL';es_ES = 'Hacer clic en URL';es_CO = 'Hacer clic en URL';tr = 'Adrese git';it = 'Andare a URL';de = 'Klicken Sie auf URL'");
			Command.Picture = PictureLib.ContactInformationGoToURL;
			
		ElsIf Type = Enums.ContactInformationTypes.EmailAddress Then
			
			Item.Title = NStr("ru = 'Написать письмо'; en = 'Create an email message'; pl = 'Napisz e-mail';es_ES = 'Escribir un correo electrónico';es_CO = 'Escribir un correo electrónico';tr = 'E-posta yaz';it = 'Creare un messaggio email';de = 'Eine E-Mail schreiben'");
			Command.ToolTip = NStr("ru = 'Написать письмо'; en = 'Create an email message'; pl = 'Napisz e-mail';es_ES = 'Escribir un correo electrónico';es_CO = 'Escribir un correo electrónico';tr = 'E-posta yaz';it = 'Creare un messaggio email';de = 'Eine E-Mail schreiben'");
			Command.Picture = PictureLib.SendEmail;
			
		ElsIf Type = Enums.ContactInformationTypes.Phone Then
			If Form.ContactInformationParameters[ItemForPlacementName].CanSendSMSMessage Then
				Item.Title = NStr("ru = 'Позвонить или отправить SMS'; en = 'Call or send text message'; pl = 'Zadzwoń lub wyślij SMS''a';es_ES = 'Llamar o enviar SMS';es_CO = 'Llamar o enviar SMS';tr = 'Ara veya SMS gönder';it = 'Chiama o invia un messaggio di testo';de = 'Anrufen oder SMS senden'");
				Command.ToolTip = NStr("ru = 'Позвонить или отправить SMS'; en = 'Call or send text message'; pl = 'Zadzwoń lub wyślij SMS''a';es_ES = 'Llamar o enviar SMS';es_CO = 'Llamar o enviar SMS';tr = 'Ara veya SMS gönder';it = 'Chiama o invia un messaggio di testo';de = 'Anrufen oder SMS senden'");
				Command.Picture = PictureLib.CallOrSendSMS;
			Else
				Item.Title = NStr("ru = 'Позвонить'; en = 'Call'; pl = 'Zadzwoń';es_ES = 'Llamada';es_CO = 'Llamada';tr = 'Ara';it = 'Call';de = 'Anruf'");
				Command.ToolTip = NStr("ru = 'Позвонить по телефону'; en = 'Telephone'; pl = 'Zatelefonować';es_ES = 'Llamar por teléfono';es_CO = 'Llamar por teléfono';tr = 'Telefonla ara';it = 'Telefono';de = 'Telefonisch anrufen'");
				Command.Picture = PictureLib.Call;
			EndIf;
			
		ElsIf Type = Enums.ContactInformationTypes.Skype Then
			Item.Title = NStr("ru = 'Skype'; en = 'Skype'; pl = 'Skype';es_ES = 'Skype';es_CO = 'Skype';tr = 'Skype';it = 'Skype';de = 'Skype'");
			Command.ToolTip = NStr("ru = 'Skype'; en = 'Skype'; pl = 'Skype';es_ES = 'Skype';es_CO = 'Skype';tr = 'Skype';it = 'Skype';de = 'Skype'");
			Command.Picture = PictureLib.Skype;
		EndIf;
		
	EndIf;
	
EndProcedure

Function FormContactsParameters(ContactInformationParameters, ItemForPlacementName)
	If NOT ValueIsFilled(ItemForPlacementName) OR NOT ContactInformationParameters.Property(ItemForPlacementName) Then
		For each FirstRecord In ContactInformationParameters Do
			Return FirstRecord.Value;
		EndDo;
		Return ContactInformationParameters;
	EndIf;
	Return ContactInformationParameters[ItemForPlacementName];
EndFunction

Function DefineNextString(Form, ContactInformation, CIRow)
	
	Position = ContactInformation.IndexOf(CIRow) + 1;
	While Position < ContactInformation.Count() Do
		NextRow = ContactInformation.Get(Position);
		If NextRow = Undefined Then
			Return Undefined;
		EndIf;
		If Form.Items.Find(NextRow.AttributeName) <> Undefined Then
			Return NextRow;
		EndIf;
		Position = Position + 1;
	EndDo;
	
	Return Undefined;
EndFunction

Function FindContactsStrings(ContactInformationKind, Date, ContactInformation)
	
	Filter = New Structure("Kind", ContactInformationKind);
	If ContactInformationKind.StoreChangeHistory Then
		Filter.Insert("ValidFrom", Date);
	EndIf;
	FoundRows = ContactInformation.FindRows(Filter);
	Return FoundRows;
	
EndFunction

Function MultipleValuesEnterProhibited(ContactInformationKind, ContactInformation, Date)
	
	If ContactInformationKind.AllowMultipleValueInput Then
		Return False;
	EndIf;
	
	Filter = New Structure("Kind", ContactInformationKind);
	If ContactInformationKind.StoreChangeHistory Then
		Filter.Insert("ValidFrom", Date);
	EndIf;
	
	FoundRows = ContactInformation.FindRows(Filter);
	Return FoundRows.Count() > 0;
	
EndFunction

Procedure FillObjectContactsFromString(ObjectContactInformationRow, Periodic, ContactInformationRow)
	
	FillPropertyValues(ContactInformationRow, ObjectContactInformationRow);
	If Periodic Then
		ContactInformationRow.ValidFrom = ObjectContactInformationRow.Date;
	EndIf;
	
	If ValueIsFilled(ContactInformationRow.Value) Then
		ContactInformationObject = ContactsManagerInternal.JSONStringToStructure(ContactInformationRow.Value);
		FillContactsTechnicalFields(ContactInformationRow, ContactInformationObject, ObjectContactInformationRow.Type);
	EndIf;
	
EndProcedure

Procedure RestoreEmptyValuePresentation(ContactInformationRow)
	
		If IsBlankString(ContactInformationRow.Type) Then
		ContactInformationRow.Type = ContactInformationManagementInternalCached.ContactInformationKindType(
			ContactInformationRow.Kind);
	EndIf;
	
	// FieldsValues can be absent in the contacts string.
	FieldsInfo = New Structure("FieldsValues", Undefined);
	FillPropertyValues(FieldsInfo, ContactInformationRow);
	HasFieldsValues = (FieldsInfo.FieldsValues <> Undefined);
	
	EmptyPresentation = IsBlankString(ContactInformationRow.Presentation);
	EmptyValue      = IsBlankString(ContactInformationRow.Value);
	EmptyFieldsValues = ?(HasFieldsValues, IsBlankString(FieldsInfo.FieldsValues), True);
	
	AllFieldsEmpty = EmptyPresentation AND EmptyValue AND EmptyFieldsValues;
	AllFieldsFilled = Not EmptyPresentation AND Not EmptyValue AND NOT EmptyFieldsValues;
	
	If AllFieldsEmpty Or AllFieldsFilled Then
		Return;
	EndIf;
	
	If EmptyPresentation Then
		
		ContactsFormat = Common.ObjectAttributesValues(ContactInformationRow.Kind, 
			"Type, IncludeCountryInPresentation, CheckByFIAS");
		ContactsFormat.Insert("AddressFormat", "FIAS");
		
		ValueSource = ?(EmptyFieldsValues, ContactInformationRow.Value, ContactInformationRow.FieldsValues);
		
		ContactInformationRow.Presentation = ContactsManagerInternal.ContactInformationPresentation(
			ValueSource, ContactsFormat);
		
	EndIf;
	
	If EmptyValue Then
		
		If Not EmptyPresentation AND EmptyFieldsValues Then
			
			AddressByFields = ContactsManagerInternal.ContactsByPresentation(
				ContactInformationRow.Presentation, ContactInformationRow.Type);
			ContactInformationRow.Value = ContactsManagerInternal.ToJSONStringStructure(AddressByFields);
			
			If HasFieldsValues Then
				ContactInformationRow.FieldsValues = ContactsManagerInternal.ContactsFromJSONToXML(
					ContactInformationRow.Value, ContactInformationRow.Type);
			EndIf;
			
		ElsIf Not EmptyFieldsValues Then
			
			ContactInformationRow.Value = ContactInformationInJSON(ContactInformationRow.FieldsValues,
				ContactInformationRow.Type);
			
		EndIf;
	
	ElsIf EmptyFieldsValues AND HasFieldsValues Then
		
		ContactInformationRow.FieldsValues = ContactInformationToXML(ContactInformationRow.Value,
			ContactInformationRow.Presentation, ContactInformationRow.Kind);
			
	EndIf;
	
EndProcedure

// Converts a country code to the standard format - a three-character string.
//
Function WorldCountryCode(Val CountryCode)
	
	If TypeOf(CountryCode)=Type("Number") Then
		Return Format(CountryCode, "ND=3; NZ=; NLZ=; NG=");
	EndIf;
	
	Return Right("000" + CountryCode, 3);
EndFunction

// Returns a string enclosed in quotes.
//
Function CheckQuotesInString(Val Row)
	Return """" + StrReplace(Row, """", """""") + """";
EndFunction

Procedure UpdateConextMenu(Form, ItemForPlacementName)
	
	ContactInformationParameters = Form.ContactInformationParameters[ItemForPlacementName];
	AllRows = Form.ContactInformationAdditionalAttributeDetails;
	FoundRows = AllRows.FindRows( 
		New Structure("Type, IsTabularSectionAttribute", Enums.ContactInformationTypes.Address, False));
		
	TotalNumberOfCommands = 0;
	For Each CIRow In AllRows Do
		
		If TotalNumberOfCommands > 50 Then // Restriction for a large number of addresses on the form
			Break;
		EndIf;
		
		If CIRow.Type <> Enums.ContactInformationTypes.Address Then
			Continue;
		EndIf;
		
		SubmenuCopyAddresses = Form.Items.Find("SubmenuCopyAddresses" + CIRow.AttributeName);
		ContextSubmenuCopyAddresses = Form.Items.Find("ContextSubmenuCopyAddresses" + CIRow.AttributeName);
		If SubmenuCopyAddresses <> Undefined AND ContextSubmenuCopyAddresses = Undefined Then
			Continue;
		EndIf;
			
		CommandNumerInSubmenu = 0;
		AddressListInSubmenu = New Map();
		AddressListInSubmenu.Insert(Upper(CIRow.Presentation), True);
		
		For Each Address In FoundRows Do
			
			If CommandNumerInSubmenu > 7 Then // Restriction for a large number of addresses on the form
				Break;
			EndIf;
			
			If Address.IsHistoricalContactInformation Or Address.AttributeName = CIRow.AttributeName Then
				Continue;
			EndIf;
			
			CommandName = "MenuSubmenuAddress" + CIRow.AttributeName + "_" + Address.AttributeName;
			Command = Form.Commands.Find(CommandName);
			If Command = Undefined Then
				Command = Form.Commands.Add(CommandName);
				Command.ToolTip = NStr("ru = 'Скопировать адрес'; en = 'Copy address'; pl = 'Skopiować adres';es_ES = 'Copiar la dirección';es_CO = 'Copiar la dirección';tr = 'Adresi kopyala';it = 'Copia indirizzo';de = 'Adresse kopieren'");
				Command.Action = "Attachable_ContactInformationExecuteCommand";
				Command.ModifiesStoredData = True;
				
				ContactInformationParameters.AddedItems.Add(CommandName, 9, True);
				CommandNumerInSubmenu = CommandNumerInSubmenu + 1;
			EndIf;
			
			AddressPresentation = ?(CIRow.InternationalAddressFormat,
				StringFunctionsClientServer.LatinString(Address.Presentation), Address.Presentation);
			
			If AddressListInSubmenu[Upper(Address.Presentation)] <> Undefined Then
				AddressPresentation = "";
			Else
				AddressListInSubmenu.Insert(Upper(Address.Presentation), True);
			EndIf;
			
			If SubmenuCopyAddresses <> Undefined Then
				AddButtonCopeAddress(Form, CommandName, 
					AddressPresentation, ContactInformationParameters, SubmenuCopyAddresses);
				EndIf;
				
			If ContextSubmenuCopyAddresses <> Undefined Then
				AddButtonCopeAddress(Form, CommandName, 
					AddressPresentation, ContactInformationParameters, ContextSubmenuCopyAddresses);
			EndIf;
			
		EndDo;
		TotalNumberOfCommands = TotalNumberOfCommands + CommandNumerInSubmenu;
	EndDo;
	
EndProcedure

Procedure AddButtonCopeAddress(Form, CommandName, ItemTitle, ContactInformationParameters, Submenu)
	
	ItemName = Submenu.Name + "_" + CommandName;
	Button = Form.Items.Find(ItemName);
	If Button = Undefined Then
		Button = Form.Items.Add(ItemName, Type("FormButton"), Submenu);
		Button.CommandName = CommandName;
		ContactInformationParameters.AddedItems.Add(ItemName, 1);
	EndIf;
	Button.Title = ItemTitle;
	Button.Visible = ValueIsFilled(ItemTitle);

EndProcedure

Function NewContactInformationDetails(Val Type) Export
	
	If Metadata.CommonModules.Find("AddressManagerClientServer") <> Undefined Then
		ModuleAddressManagerClientServer = Common.CommonModule("AddressManagerClientServer");
		Return ModuleAddressManagerClientServer.NewContactInformationDetails(Type);
	EndIf;
	
	Return ContactsManagerClientServer.NewContactInformationDetails(Type);
	
EndFunction

// Getting object deep property. 
//
Function GetXDTOObjectAttribute(XTDOObject, XPath) Export
	
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

// The procedure sets the setting of contact information "ShowInFormAlways"
//
// Parameters:
//  ContactInformationKind	 - CatalogRef.ContactInformationKinds	 - kind for which the setting is set
//  SwitchOn				 - boolean	 - setting value
//
Procedure SetFlagShowInFormAlways(ContactInformationKind, SwitchOn = True)
	
	RecordSet = InformationRegisters.ContactInformationVisibilitySettings.CreateRecordSet();
	
	// Read record set.
	RecordSet.Filter.Kind.Set(ContactInformationKind);
	RecordSet.Read();
	
	If RecordSet.Count() = 0 Then
		Record = RecordSet.Add();
	ElsIf RecordSet[0].ShowInFormAlways = SwitchOn Then
		Return; // Setting already, additional action is not required
	Else
		Record = RecordSet[0];
	EndIf;
	
	Record.Kind = ContactInformationKind;
	Record.ShowInFormAlways = SwitchOn;
	
	RecordSet.Write();
	
EndProcedure

#Region UpdateResults

Procedure Counterparties_SetKindProperties()
	
	KindParameters = ContactInformationKindParameters("Phone");
	KindParameters.Kind						= Catalogs.ContactInformationKinds.CounterpartyPhone;
	KindParameters.Order					= 1;
	KindParameters.CanChangeEditMethod		= True;
	KindParameters.EditOnlyInDialog			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= True;
	SetContactInformationKindProperties(KindParameters);
	SetFlagShowInFormAlways(KindParameters.Kind);
	
	KindParameters = ContactInformationKindParameters("EmailAddress");
	KindParameters.Kind						= Catalogs.ContactInformationKinds.CounterpartyEmail;
	KindParameters.Order					= 2;
	KindParameters.CanChangeEditMethod		= True;
	KindParameters.EditOnlyInDialog			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= True;
	KindParameters.ValidationSettings.CheckValidity	= True;
	SetContactInformationKindProperties(KindParameters);
	SetFlagShowInFormAlways(KindParameters.Kind);
	
	KindParameters = ContactInformationKindParameters("Address");
	KindParameters.Kind						= Catalogs.ContactInformationKinds.CounterpartyLegalAddress;
	KindParameters.Order					= 3;
	KindParameters.CanChangeEditMethod		= True;
	KindParameters.EditOnlyInDialog			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= False;
	KindParameters.ValidationSettings.OnlyNationalAddress				= False;
	KindParameters.ValidationSettings.CheckValidity					= False;
	KindParameters.ValidationSettings.HideObsoleteAddresses			= False;
	KindParameters.ValidationSettings.IncludeCountryInPresentation	= True;
	ContactsManager.SetContactInformationKindProperties(KindParameters);
	SetFlagShowInFormAlways(KindParameters.Kind);
	
	KindParameters = ContactInformationKindParameters("Address");
	KindParameters.Kind						= Catalogs.ContactInformationKinds.CounterpartyActualAddress;
	KindParameters.Order					= 4;
	KindParameters.CanChangeEditMethod		= True;
	KindParameters.EditOnlyInDialog			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= False;
	KindParameters.ValidationSettings.OnlyNationalAddress				= False;
	KindParameters.ValidationSettings.CheckValidity					= False;
	KindParameters.ValidationSettings.HideObsoleteAddresses			= False;
	KindParameters.ValidationSettings.IncludeCountryInPresentation	= True;
	ContactsManager.SetContactInformationKindProperties(KindParameters);
	
	KindParameters = ContactInformationKindParameters("Address");
	KindParameters.Kind						= Catalogs.ContactInformationKinds.CounterpartyDeliveryAddress;
	KindParameters.Order					= 5;
	KindParameters.CanChangeEditMethod		= True;
	KindParameters.EditOnlyInDialog			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= True;
	KindParameters.ValidationSettings.OnlyNationalAddress				= False;
	KindParameters.ValidationSettings.CheckValidity					= False;
	KindParameters.ValidationSettings.HideObsoleteAddresses			= False;
	KindParameters.ValidationSettings.IncludeCountryInPresentation	= False;
	ContactsManager.SetContactInformationKindProperties(KindParameters);
	
	KindParameters = ContactInformationKindParameters("Skype");
	KindParameters.Kind						= Catalogs.ContactInformationKinds.CounterpartySkype;
	KindParameters.Order					= 6;
	KindParameters.CanChangeEditMethod		= True;
	KindParameters.EditOnlyInDialog			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= False;
	ContactsManager.SetContactInformationKindProperties(KindParameters);
	
	KindParameters = ContactInformationKindParameters("WebPage");
	KindParameters.Kind						= Catalogs.ContactInformationKinds.CounterpartyWebpage;
	KindParameters.Order					= 7;
	KindParameters.CanChangeEditMethod		= True;
	KindParameters.EditOnlyInDialog			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= False;
	ContactsManager.SetContactInformationKindProperties(KindParameters);
	
	KindParameters = ContactInformationKindParameters("Fax");
	KindParameters.Kind						= Catalogs.ContactInformationKinds.CounterpartyFax;
	KindParameters.Order					= 8;
	KindParameters.CanChangeEditMethod		= True;
	KindParameters.EditOnlyInDialog			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= False;
	ContactsManager.SetContactInformationKindProperties(KindParameters);
	
	KindParameters = ContactInformationKindParameters("Address");
	KindParameters.Kind						= Catalogs.ContactInformationKinds.CounterpartyPostalAddress;
	KindParameters.Order					= 9;
	KindParameters.CanChangeEditMethod		= True;
	KindParameters.EditOnlyInDialog			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= False;
	KindParameters.ValidationSettings.OnlyNationalAddress				= False;
	KindParameters.ValidationSettings.CheckValidity					= False;
	KindParameters.ValidationSettings.HideObsoleteAddresses			= False;
	KindParameters.ValidationSettings.IncludeCountryInPresentation	= False;
	ContactsManager.SetContactInformationKindProperties(KindParameters);
	
	KindParameters = ContactInformationKindParameters("Other");
	KindParameters.Kind						= Catalogs.ContactInformationKinds.CounterpartyOtherInformation;
	KindParameters.Order					= 10;
	KindParameters.CanChangeEditMethod		= True;
	KindParameters.EditOnlyInDialog			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= False;
	ContactsManager.SetContactInformationKindProperties(KindParameters);
	
EndProcedure

Procedure ContactPersons_SetKindProperties()
	
	KindParameters = ContactInformationKindParameters("Phone");
	KindParameters.Kind						= Catalogs.ContactInformationKinds.ContactPersonPhone;
	KindParameters.Order					= 1;
	KindParameters.CanChangeEditMethod		= True;
	KindParameters.EditOnlyInDialog			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= True;
	ContactsManager.SetContactInformationKindProperties(KindParameters);
	SetFlagShowInFormAlways(KindParameters.Kind);
	
	KindParameters = ContactInformationKindParameters("EmailAddress");
	KindParameters.Kind						= Catalogs.ContactInformationKinds.ContactPersonEmail;
	KindParameters.Order					= 2;
	KindParameters.CanChangeEditMethod		= True;
	KindParameters.EditOnlyInDialog			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= True;
	KindParameters.ValidationSettings.CheckValidity	= True;
	ContactsManager.SetContactInformationKindProperties(KindParameters);
	SetFlagShowInFormAlways(KindParameters.Kind);
	
	KindParameters = ContactInformationKindParameters("Skype");
	KindParameters.Kind						= Catalogs.ContactInformationKinds.ContactPersonSkype;
	KindParameters.Order					= 3;
	KindParameters.CanChangeEditMethod		= True;
	KindParameters.EditOnlyInDialog			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= False;
	ContactsManager.SetContactInformationKindProperties(KindParameters);
	
	KindParameters = ContactInformationKindParameters("WebPage");
	KindParameters.Kind						= Catalogs.ContactInformationKinds.ContactPersonSocialNetwork;
	KindParameters.Order					= 4;
	KindParameters.CanChangeEditMethod		= True;
	KindParameters.EditOnlyInDialog			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= True;
	ContactsManager.SetContactInformationKindProperties(KindParameters);
	
	KindParameters = ContactInformationKindParameters("Other");
	KindParameters.Kind						= Catalogs.ContactInformationKinds.ContactPersonMessenger;
	KindParameters.Order					= 5;
	KindParameters.CanChangeEditMethod		= True;
	KindParameters.EditOnlyInDialog			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= True;
	ContactsManager.SetContactInformationKindProperties(KindParameters);
	
EndProcedure

Procedure Companies_SetKindProperties()
	
	KindParameters = ContactInformationKindParameters("Address");
	KindParameters.Kind						= Catalogs.ContactInformationKinds.CompanyLegalAddress;
	KindParameters.Order					= 1;
	KindParameters.CanChangeEditMethod		= True;
	KindParameters.EditOnlyInDialog			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= False;
	KindParameters.ValidationSettings.OnlyNationalAddress				= False;
	KindParameters.ValidationSettings.CheckValidity					= False;
	KindParameters.ValidationSettings.HideObsoleteAddresses			= False;
	KindParameters.ValidationSettings.IncludeCountryInPresentation	= True;
	ContactsManager.SetContactInformationKindProperties(KindParameters);
	SetFlagShowInFormAlways(KindParameters.Kind);
	
	KindParameters = ContactInformationKindParameters("Address");
	KindParameters.Kind						= Catalogs.ContactInformationKinds.CompanyActualAddress;
	KindParameters.Order					= 2;
	KindParameters.CanChangeEditMethod		= True;
	KindParameters.EditOnlyInDialog			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= False;
	KindParameters.ValidationSettings.OnlyNationalAddress				= False;
	KindParameters.ValidationSettings.CheckValidity					= False;
	KindParameters.ValidationSettings.HideObsoleteAddresses			= False;
	KindParameters.ValidationSettings.IncludeCountryInPresentation	= True;
	ContactsManager.SetContactInformationKindProperties(KindParameters);
	SetFlagShowInFormAlways(KindParameters.Kind);
	
	KindParameters = ContactInformationKindParameters("Address");
	KindParameters.Kind						= Catalogs.ContactInformationKinds.CompanyPostalAddress;
	KindParameters.Order					= 3;
	KindParameters.CanChangeEditMethod		= True;
	KindParameters.EditOnlyInDialog			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= False;
	KindParameters.ValidationSettings.OnlyNationalAddress				= False;
	KindParameters.ValidationSettings.CheckValidity					= False;
	KindParameters.ValidationSettings.HideObsoleteAddresses			= False;
	KindParameters.ValidationSettings.IncludeCountryInPresentation	= False;
	ContactsManager.SetContactInformationKindProperties(KindParameters);
	SetFlagShowInFormAlways(KindParameters.Kind);
	
	KindParameters = ContactInformationKindParameters("Phone");
	KindParameters.Kind						= Catalogs.ContactInformationKinds.CompanyPhone;
	KindParameters.Order					= 4;
	KindParameters.CanChangeEditMethod		= True;
	KindParameters.EditOnlyInDialog			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= True;
	ContactsManager.SetContactInformationKindProperties(KindParameters);
	SetFlagShowInFormAlways(KindParameters.Kind);
	
	KindParameters = ContactInformationKindParameters("EmailAddress");
	KindParameters.Kind						= Catalogs.ContactInformationKinds.CompanyEmail;
	KindParameters.Order					= 5;
	KindParameters.CanChangeEditMethod		= True;
	KindParameters.EditOnlyInDialog			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= True;
	KindParameters.ValidationSettings.CheckValidity	= True;
	ContactsManager.SetContactInformationKindProperties(KindParameters);
	SetFlagShowInFormAlways(KindParameters.Kind);
	
	KindParameters = ContactInformationKindParameters("WebPage");
	KindParameters.Kind						= Catalogs.ContactInformationKinds.CompanyWebpage;
	KindParameters.Order					= 6;
	KindParameters.CanChangeEditMethod		= True;
	KindParameters.EditOnlyInDialog			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= False;
	ContactsManager.SetContactInformationKindProperties(KindParameters);
	SetFlagShowInFormAlways(KindParameters.Kind);
	
	KindParameters = ContactInformationKindParameters("Fax");
	KindParameters.Kind						= Catalogs.ContactInformationKinds.CompanyFax;
	KindParameters.Order					= 6;
	KindParameters.CanChangeEditMethod		= True;
	KindParameters.EditOnlyInDialog			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= False;
	ContactsManager.SetContactInformationKindProperties(KindParameters);
	
	KindParameters = ContactInformationKindParameters("Other");
	KindParameters.Kind						= Catalogs.ContactInformationKinds.CompanyOtherInformation;
	KindParameters.Order					= 7;
	KindParameters.CanChangeEditMethod		= True;
	KindParameters.EditOnlyInDialog			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= False;
	ContactsManager.SetContactInformationKindProperties(KindParameters);
	
EndProcedure

Procedure Individuals_SetKindProperties()
	
	KindParameters = ContactInformationKindParameters("Phone");
	KindParameters.Kind						= Catalogs.ContactInformationKinds.IndividualPhone;
	KindParameters.Order					= 1;
	KindParameters.CanChangeEditMethod		= True;
	KindParameters.EditOnlyInDialog			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= True;
	ContactsManager.SetContactInformationKindProperties(KindParameters);
	SetFlagShowInFormAlways(KindParameters.Kind);
	
	KindParameters = ContactInformationKindParameters("Address");
	KindParameters.Kind						= Catalogs.ContactInformationKinds.IndividualActualAddress;
	KindParameters.Order					= 2;
	KindParameters.CanChangeEditMethod		= False;
	KindParameters.EditOnlyInDialog			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= False;
	KindParameters.ValidationSettings.OnlyNationalAddress				= False;
	KindParameters.ValidationSettings.CheckValidity					= False;
	KindParameters.ValidationSettings.HideObsoleteAddresses			= False;
	KindParameters.ValidationSettings.IncludeCountryInPresentation	= True;
	ContactsManager.SetContactInformationKindProperties(KindParameters);
	SetFlagShowInFormAlways(KindParameters.Kind);
	
	KindParameters = ContactInformationKindParameters("Address");
	KindParameters.Kind						= Catalogs.ContactInformationKinds.IndividualPostalAddress;
	KindParameters.Order					= 4;
	KindParameters.CanChangeEditMethod		= False;
	KindParameters.EditOnlyInDialog			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= False;
	KindParameters.ValidationSettings.OnlyNationalAddress				= False;
	KindParameters.ValidationSettings.CheckValidity					= False;
	KindParameters.ValidationSettings.HideObsoleteAddresses			= False;
	KindParameters.ValidationSettings.IncludeCountryInPresentation	= True;
	ContactsManager.SetContactInformationKindProperties(KindParameters);
	
	KindParameters = ContactInformationKindParameters("EmailAddress");
	KindParameters.Kind						= Catalogs.ContactInformationKinds.IndividualEmail;
	KindParameters.Order					= 6;
	KindParameters.CanChangeEditMethod		= True;
	KindParameters.EditOnlyInDialog			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= True;
	KindParameters.ValidationSettings.CheckValidity	= True;
	ContactsManager.SetContactInformationKindProperties(KindParameters);
	SetFlagShowInFormAlways(KindParameters.Kind);
	
	KindParameters = ContactInformationKindParameters("Other");
	KindParameters.Kind						= Catalogs.ContactInformationKinds.IndividualOtherInformation;
	KindParameters.Order					= 7;
	KindParameters.CanChangeEditMethod		= True;
	KindParameters.EditOnlyInDialog			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= False;
	ContactsManager.SetContactInformationKindProperties(KindParameters);
	
EndProcedure

Procedure BusinessUnits_SetKindProperties()
	
	KindParameters = ContactInformationKindParameters("Phone");
	KindParameters.Kind						= Catalogs.ContactInformationKinds.BusinessUnitsPhone;
	KindParameters.Order					= 1;
	KindParameters.CanChangeEditMethod		= True;
	KindParameters.EditOnlyInDialog			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= True;
	ContactsManager.SetContactInformationKindProperties(KindParameters);
	SetFlagShowInFormAlways(KindParameters.Kind);
	
	KindParameters = ContactInformationKindParameters("Address");
	KindParameters.Kind						= Catalogs.ContactInformationKinds.BusinessUnitsActualAddress;
	KindParameters.Order					= 2;
	KindParameters.CanChangeEditMethod		= True;
	KindParameters.EditOnlyInDialog			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= False;
	KindParameters.ValidationSettings.OnlyNationalAddress				= False;
	KindParameters.ValidationSettings.CheckValidity					= False;
	KindParameters.ValidationSettings.HideObsoleteAddresses			= False;
	KindParameters.ValidationSettings.IncludeCountryInPresentation	= False;
	ContactsManager.SetContactInformationKindProperties(KindParameters);
	SetFlagShowInFormAlways(KindParameters.Kind);
	
EndProcedure

Procedure Users_SetKindProperties()
	
	KindParameters = ContactInformationKindParameters("Phone");
	KindParameters.Kind						= Catalogs.ContactInformationKinds.UserPhone;
	KindParameters.Order					= 1;
	KindParameters.CanChangeEditMethod		= True;
	KindParameters.EditOnlyInDialog			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= True;
	ContactsManager.SetContactInformationKindProperties(KindParameters);
	SetFlagShowInFormAlways(KindParameters.Kind);
	
	KindParameters = ContactInformationKindParameters("EmailAddress");
	KindParameters.Kind						= Catalogs.ContactInformationKinds.UserEmail;
	KindParameters.Order					= 2;
	KindParameters.CanChangeEditMethod		= True;
	KindParameters.EditOnlyInDialog			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= True;
	KindParameters.ValidationSettings.CheckValidity		= True;
	ContactsManager.SetContactInformationKindProperties(KindParameters);
	SetFlagShowInFormAlways(KindParameters.Kind);
	
	KindParameters = ContactInformationKindParameters("WebPage");
	KindParameters.Kind						= Catalogs.ContactInformationKinds.UserWebpage;
	KindParameters.Order					= 3;
	KindParameters.CanChangeEditMethod		= True;
	KindParameters.EditOnlyInDialog			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= True;
	ContactsManager.SetContactInformationKindProperties(KindParameters);
	SetFlagShowInFormAlways(KindParameters.Kind);
	
EndProcedure

Procedure Leads_SetKindProperties() Export
	
	KindParameters = ContactInformationKindParameters("Phone");
	KindParameters.Kind						= Catalogs.ContactInformationKinds.LeadPhone;
	KindParameters.Order					= 1;
	KindParameters.CanChangeEditMethod		= True;
	KindParameters.EditOnlyInDialog			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= True;
	ContactsManager.SetContactInformationKindProperties(KindParameters);
	SetFlagShowInFormAlways(KindParameters.Kind);
	
	KindParameters = ContactInformationKindParameters("EmailAddress");
	KindParameters.Kind						= Catalogs.ContactInformationKinds.LeadEmail;
	KindParameters.Order					= 2;
	KindParameters.CanChangeEditMethod		= True;
	KindParameters.EditOnlyInDialog			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= True;
	KindParameters.ValidationSettings.CheckValidity	= True;
	ContactsManager.SetContactInformationKindProperties(KindParameters);
	SetFlagShowInFormAlways(KindParameters.Kind);

	KindParameters = ContactInformationKindParameters("Skype");
	KindParameters.Kind						= Catalogs.ContactInformationKinds.LeadSkype;
	KindParameters.Order					= 3;
	KindParameters.CanChangeEditMethod		= True;
	KindParameters.EditOnlyInDialog			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= False;
	ContactsManager.SetContactInformationKindProperties(KindParameters);
	
	KindParameters = ContactInformationKindParameters("WebPage");
	KindParameters.Kind						= Catalogs.ContactInformationKinds.LeadSocialNetwork;
	KindParameters.Order					= 4;
	KindParameters.CanChangeEditMethod		= True;
	KindParameters.EditOnlyInDialog			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= True;
	ContactsManager.SetContactInformationKindProperties(KindParameters);
	
	KindParameters = ContactInformationKindParameters("Other");
	KindParameters.Kind						= Catalogs.ContactInformationKinds.LeadMessenger;
	KindParameters.Order					= 5;
	KindParameters.CanChangeEditMethod		= True;
	KindParameters.EditOnlyInDialog			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= True;
	ContactsManager.SetContactInformationKindProperties(KindParameters);
	
EndProcedure

// Updates with predefined kinds of contact information for Shipping addresses.
//
Procedure ShippingAddresses_SetKindProperties() Export
	
	KindParameters = ContactInformationKindParameters("Address");
	KindParameters.Kind						= Catalogs.ContactInformationKinds.ShippingAddress;
	KindParameters.Order					= 1;
	KindParameters.CanChangeEditMethod		= True;
	KindParameters.EditOnlyInDialog			= False;
	KindParameters.Mandatory				= False;
	KindParameters.AllowMultipleValueInput	= False;
	VerificationSettings = KindParameters.ValidationSettings;
	VerificationSettings.OnlyNationalAddress			= False;
	VerificationSettings.CheckValidity					= False;
	VerificationSettings.HideObsoleteAddresses			= False;
	VerificationSettings.IncludeCountryInPresentation	= True;
	ContactsManager.SetContactInformationKindProperties(KindParameters);
	SetFlagShowInFormAlways(KindParameters.Kind);
	
EndProcedure

#EndRegion

#EndRegion
