///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#Region Public

// Returns new interaction contact details.
// To use in InteractionsClientServerOverridable.OnDeterminePossibleContacts.
//
// Returns:
//   Structure - interaction contact properties:
//     * Type                                - Type     - a contact reference type.
//     * Name                                 - String - a contact type name as it is defined in metadata.
//     * Presentation                       - String - a contact type presentation to be displayed to a user.
//     * Hierarchical                       - Boolean - indicates that this catalog is hierarchical.
//     * HasOwner                        - Boolean - indicates that the contact has an owner.
//     * OwnerName                                 - String - a contact owner name as it is defined in metadata.
//     * SearchByDomain                      - Boolean - indicates that contacts of this type will 
//                                                      be picked by the domain map and not by the full email address.
//     * Link                               - String - describes a possible link of this contact 
//                                                      with some other contact when the current contact is an attribute of other contact.
//                                                      It is described with the "TableName.AttributeName" string.
//     * ContactPresentationAttributeName   - String - a contact attribute name, from which a 
//                                                      contact presentation will be received. If it 
//                                                      is not specified, the standard Description attribute is used.
//     * InteractiveCreationPossibility - Boolean - indicates that a contact can be created 
//                                                      interactively from interaction documents.
//     * NewContactFormName              - String - a full form name to create a new contact, for 
//                                                      example, "Catalog.Partners.Form.NewContactWizard".
//                                                      If it is not filled in, a default item form is opened.
Function NewContactDetails() Export
	
	Result = New Structure;
	Result.Insert("Type",                               "");
	Result.Insert("Name",                               "");
	Result.Insert("Presentation",                     "");
	Result.Insert("Hierarchical",                     False);
	Result.Insert("HasOwner",                      False);
	Result.Insert("OwnerName",                      "");
	Result.Insert("SearchByDomain",                    True);
	Result.Insert("Link",                             "");
	Result.Insert("ContactPresentationAttributeName", "Description");
	Result.Insert("InteractiveCreationPossibility", True);
	Result.Insert("NewContactFormName",            "");
	Return Result;
	
EndFunction	

#Region ObsoleteProceduresAndFunctions

// Obsolete. Use InteractionsClientServer.NewContactDetails.
// Adds an element to a contact structure array.
//
// Parameters:
//  DetailsArray                     - Array - an array, to which a contact description structure will be added.
//  Type                                - Type    - a contact reference type.
//  InteractiveCreationPossibility  - Boolean - indicates that a contact can be created 
//                                                interactively from interaction documents.
//  Name                                 - String - a contact type name as it is defined in metadata.
//  Presentation                       - String - a contact type presentation to be displayed to a user.
//  Hierarchical                       - Boolean - indicates that this catalog is hierarchical.
//  HasOwner                        - Boolean - indicates that the contact has an owner.
//  OwnerName                                 - String - a contact owner name as it is defined in metadata.
//  SearchByDomain                      - Boolean - indicates that this contact type will be 
//                                                 searched by domain.
//  Link                               - String - describes a possible link of this contact with 
//                                                 some other contact when the current contact is an attribute of other contact.
//                                                 It is described with the "TableName.AttributeName" string.
//  ContactPresentationAttributeName   - String - a contact attribute name, from which a contact presentation will be received.
//
Procedure AddPossibleContactsTypesDetailsArrayElement(
	DetailsArray,
	Type,
	InteractiveCreationPossibility,
	Name,
	Presentation,
	Hierarchical,
	HasOwner,
	OwnerName,
	SearchByDomain,
	Link,
	ContactPresentationAttributeName = "Description") Export
	
	DetailsStructure = New Structure;
	DetailsStructure.Insert("Type",                               Type);
	DetailsStructure.Insert("InteractiveCreationPossibility", InteractiveCreationPossibility);
	DetailsStructure.Insert("Name",                               Name);
	DetailsStructure.Insert("Presentation",                     Presentation);
	DetailsStructure.Insert("Hierarchical",                     Hierarchical);
	DetailsStructure.Insert("HasOwner",                      HasOwner);
	DetailsStructure.Insert("OwnerName",                      OwnerName);
	DetailsStructure.Insert("SearchByDomain",                    SearchByDomain);
	DetailsStructure.Insert("Link",                             Link);
	DetailsStructure.Insert("ContactPresentationAttributeName", ContactPresentationAttributeName);

	
	DetailsArray.Add(DetailsStructure);
	
EndProcedure

#EndRegion

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Defining a referenec type.

// Determines whether a reference passed to the function is an interaction or not.
//
// Parameters:
//  ObjectRef  - Ref - a reference, to which a check is required.
//
// Returns:
//   Boolean   - true if the passed reference is an interaction.
//
Function IsInteraction(ObjectRef) Export
	
	If TypeOf(ObjectRef) = Type("Type") Then
		ObjectType = ObjectRef;
	Else
		ObjectType = TypeOf(ObjectRef);
	EndIf;
	
	Return ObjectType = Type("DocumentRef.Meeting")
		OR ObjectType = Type("DocumentRef.PlannedInteraction")
		OR ObjectType = Type("DocumentRef.PhoneCall")
		OR ObjectType = Type("DocumentRef.IncomingEmail")
		OR ObjectType = Type("DocumentRef.OutgoingEmail")
		OR ObjectType = Type("DocumentRef.SMSMessage");
	
EndFunction

// Determines whether a reference passed to the function is an attached interaction file.
//
// Parameters:
//  ObjectRef  - Ref - a reference, to which a check is required.
//
// Returns:
//   Boolean   - true if the passed reference is an attached interaction file.
//
Function IsAttachedInteractionsFile(ObjectRef) Export
	
	Return TypeOf(ObjectRef) = Type("CatalogRef.MeetingAttachedFiles")
		OR TypeOf(ObjectRef) = Type("CatalogRef.PlannedInteractionAttachedFiles")
		OR TypeOf(ObjectRef) = Type("CatalogRef.PhoneCallAttachedFiles")
		OR TypeOf(ObjectRef) = Type("CatalogRef.IncomingEmailAttachedFiles")
		OR TypeOf(ObjectRef) = Type("CatalogRef.OutgoingEmailAttachedFiles")
		OR TypeOf(ObjectRef) = Type("CatalogRef.SMSMessageAttachedFiles");
	
EndFunction

// Checks if the passed reference is an interaction subject.
//
// Parameters:
//  ObjectRef - Ref - a reference, which is checked if it is a reference to an interaction subject.
//                          
//
// Returns:
//   Boolean   - true if it is a reference to an interaction subject, false otherwise.
//
Function IsSubject(ObjectRef) Export
	
	InteractionsSubjects = InteractionsClientServerServiceCached.InteractionsSubjects();
	For each Topic In InteractionsSubjects Do
		If TypeOf(ObjectRef) = Type(Topic) Then
			Return True;
		EndIf;
	EndDo;
	Return False;	
	
EndFunction 

////////////////////////////////////////////////////////////////////////////////
// Other procedures and functions

// Checks if a file is an email by file extension.
//
// Parameters:
//  FileName  - String - a checked file name.
//
// Returns:
//   Boolean   - True if it is a file extension, indicates that it is an email.
//
Function IsFileEmail(FileName) Export

	FileExtensionsArray = EmailFileExtensionsArray();
	FileExtention       = CommonClientServer.GetFileNameExtension(FileName);
	Return (FileExtensionsArray.Find(FileExtention) <> Undefined);
	
EndFunction

// Sets the "Outgoing" status for the SMS message document and all messages that it includes.
//
// Parameters:
//  Object       - Document.SMSMessage - a document, for which a state is set.
//
Procedure SetStateOutgoingDocumentSMSMessage(Object) Export
	
	For each Recipient In Object.Recipients Do
		
		Recipient.MessageState = PredefinedValue("Enum.SMSStatus.Outgoing");
		
	EndDo;
	
	Object.State = PredefinedValue("Enum.SMSMessageStatusDocument.Outgoing");
	
EndProcedure

// Generates an information row about the number of messages and characters left.
//
// Parameters:
//  SendInTransliteration  - Boolean - indicates that a message will be automatically transformed 
//                                   into Latin characters when sending it.
//  MessageText  - String       - a message text, for which a message is being generated.
//
// Returns:
//   String   - a generated information message.
//
Function GenerateInfoLabelMessageCharsCount(SendInTransliteration, MessageText) Export

	CharsInMessage = ?(SendInTransliteration, 140, 50);
	CountOfChars = StrLen(MessageText);
	MessagesCount   = Int(CountOfChars / CharsInMessage) + 1;
	CharsLeft      = CharsInMessage - CountOfChars % CharsInMessage;
	MessageTextTemplate = NStr("ru = 'Сообщение - %1, осталось символов - %2'; en = 'Message - %1, characters left - %2'; pl = 'Wiadomość - %1, pozostało symboli - %2';es_ES = 'Mensaje - %1, quedan símbolos - %2';es_CO = 'Mensaje - %1, quedan símbolos - %2';tr = 'İleti - %1, kalan karakter - %2';it = 'Messaggio - %1, Caratteri rimanenti - %2';de = 'Nachricht - %1, übrige Zeichen - %2'");
	Return StringFunctionsClientServer.SubstituteParametersToString(MessageTextTemplate, MessagesCount, CharsLeft);

EndFunction

Function ContactsDetails() Export
	
	Return InteractionsClientServerServiceCached.InteractionsContacts();
	
EndFunction

// Checks filling of contacts in the interaction document and updates interaction document form//
// Parameters:
//  Object - DocumentObject - an interaction document being checked.
//  Form - ClientApplicationForm - a form for an interactions document.
//  DocumentKind - String - a string name of an interaction document.
//
Procedure CheckContactsFilling(Object,Form,DocumentKind) Export
	
	ContactsFilled = ContactsFilled(Object,DocumentKind);
	
	If ContactsFilled Then
		Form.Items.ContactsSpecifiedPages.CurrentPage = Form.Items.СтраницаКонтактыЗаполнены;
	Else
		Form.Items.ContactsSpecifiedPages.CurrentPage = Form.Items.СтраницаКонтактыНеЗаполнены;
	EndIf;
	
EndProcedure

// Gets a file size string presentation.
//
// Parameters:
//  SizeInBytes - Number - an email nested file size in bytes.
//
// Returns:
//   String   - string presentation of an email nested file size.
//
Function GetFileSizeStringPresentation(SizeInBytes) Export
	
	SizeMB = SizeInBytes / (1024*1024);
	If SizeMB > 1 Then
		StringSize = Format(SizeMB,"NFD=1") + " " + NStr("ru = 'Мб'; en = 'MB'; pl = 'MB';es_ES = 'MB';es_CO = 'MB';tr = 'MB';it = 'MB';de = 'MB'");
	Else
		StringSize = Format(SizeInBytes /1024,"NFD=0; NZ=0") + " " + NStr("ru = 'Кб'; en = 'KB'; pl = 'KB';es_ES = 'kB';es_CO = 'kB';tr = 'KB';it = 'KB';de = 'KB'");
	EndIf;
	
	Return StringSize;
	
EndFunction

// Processes quick filter change of the dynamic interaction document list.
//
// Parameters:
//  Form - ClientApplicationForm - a form for which an action is performed.
//  FilterName - String - name of a filter being changed.
//  FilterBySubject - Boolean - indicates that the list form is parametrical and it is filtered by subject.
//
Procedure QuickFilterListOnChange(Form, FilterName, DateForFilter = Undefined, FilterBySubject = True) Export
	
	Filter = DynamicListFilter(Form.List);
	
	If FilterName = "Status" Then
		
		// clear linked filters
		CommonClientServer.DeleteFilterItems(Filter, "ReviewAfter");
		CommonClientServer.DeleteFilterItems(Filter, "Reviewed");
		If NOT FilterBySubject Then
			CommonClientServer.DeleteFilterItems(Filter, "Topic");
		EndIf;
		
		// Set filters for the mode.
		If Form[FilterName] = "ToReview" Then
			
			CommonClientServer.SetFilterItem(Filter, "Reviewed", False,,, True);
			CommonClientServer.SetFilterItem(
				Filter, "ReviewAfter", DateForFilter, DataCompositionComparisonType.LessOrEqual,, True);
			
		ElsIf Form[FilterName] = "Deferred" Then
			CommonClientServer.SetFilterItem(Filter, "Reviewed", False,,, True);
			CommonClientServer.SetFilterItem(
			Filter, "ReviewAfter", , DataCompositionComparisonType.Filled,, True);
		ElsIf Form[FilterName] = "Reviewed" Then
			CommonClientServer.SetFilterItem(Filter, "Reviewed", True,,, True);
		EndIf;
		
	Else
		
		CommonClientServer.SetFilterItem(
			Filter,FilterName,Form[FilterName],,, ValueIsFilled(Form[FilterName]));
		
	EndIf;
	
EndProcedure

// Processes quick filter change by interaction type of the dynamic interaction document list.
//
// Parameters:
//  Form - ClientApplicationForm - Contains a dynamic list where the changed filter is located.
//  InteractionType - String - an applied filter name.
//
Procedure OnChangeFilterInteractionType(Form,InteractionType) Export
	
	Filter = DynamicListFilter(Form.List);
	
	// clear linked filters
	FilterGroup = CommonClientServer.CreateFilterItemGroup(
		Filter.Items, NStr("ru = 'Отбор по типу взаимодействий'; en = 'Filter by interaction type'; pl = 'Filtruj według typu interakcji';es_ES = 'Selección por tipo de interacción';es_CO = 'Selección por tipo de interacción';tr = 'Etkileşim türüne göre filtrele';it = 'Filtro per tipo di interazione';de = 'Filter nach Interaktionstyp'"), DataCompositionFilterItemsGroupType.AndGroup);
	
	// set filters for type
	If InteractionType = "AllMessages" Then
		
		EmailTypesList = New ValueList;
		EmailTypesList.Add(Type("DocumentRef.IncomingEmail"));
		EmailTypesList.Add(Type("DocumentRef.OutgoingEmail"));
		CommonClientServer.SetFilterItem(
			FilterGroup, "Type", EmailTypesList, DataCompositionComparisonType.InList,, True);
		
	ElsIf InteractionType = "IncomingMessages" Then
		
		CommonClientServer.SetFilterItem(FilterGroup,
			"Type", Type("DocumentRef.IncomingEmail"), DataCompositionComparisonType.Equal,, True);
		CommonClientServer.SetFilterItem(FilterGroup,
			"DeletionMark", False, DataCompositionComparisonType.Equal, , True);
		
	ElsIf InteractionType = "MessageDrafts" Then
		
		CommonClientServer.SetFilterItem(FilterGroup,
			"Type", Type("DocumentRef.OutgoingEmail"), DataCompositionComparisonType.Equal, , True);
		CommonClientServer.SetFilterItem(
			FilterGroup, "DeletionMark", False, DataCompositionComparisonType.Equal, , True);
		CommonClientServer.SetFilterItem(FilterGroup,
			"OutgoingEmailStatus", PredefinedValue("Enum.OutgoingEmailStatuses.Draft"),
			DataCompositionComparisonType.Equal,, True);
		
	ElsIf InteractionType = "OutgoingMessages" Then
		
		CommonClientServer.SetFilterItem(FilterGroup,
		"Type", Type("DocumentRef.OutgoingEmail"),DataCompositionComparisonType.Equal,, True);
		CommonClientServer.SetFilterItem(FilterGroup,
			"DeletionMark", False,DataCompositionComparisonType.Equal,, True);
		CommonClientServer.SetFilterItem(FilterGroup,
			"OutgoingEmailStatus", PredefinedValue("Enum.OutgoingEmailStatuses.Outgoing"),DataCompositionComparisonType.Equal,, True);
		
	ElsIf InteractionType = "Sent" Then
		
		CommonClientServer.SetFilterItem(FilterGroup,
			"Type", Type("DocumentRef.OutgoingEmail"),DataCompositionComparisonType.Equal,, True);
		CommonClientServer.SetFilterItem(FilterGroup,
			"DeletionMark", False,DataCompositionComparisonType.Equal,, True);
		CommonClientServer.SetFilterItem(FilterGroup,
			"OutgoingEmailStatus", PredefinedValue("Enum.OutgoingEmailStatuses.Sent"),
			DataCompositionComparisonType.Equal,, True);
		
	ElsIf InteractionType = "DeletedMessages" Then
		
		EmailTypesList = New ValueList;
		EmailTypesList.Add(Type("DocumentRef.IncomingEmail"));
		EmailTypesList.Add(Type("DocumentRef.OutgoingEmail"));
		CommonClientServer.SetFilterItem(FilterGroup,
			"Type", EmailTypesList, DataCompositionComparisonType.InList,, True);
		CommonClientServer.SetFilterItem(FilterGroup,
			"DeletionMark", True,DataCompositionComparisonType.Equal,, True);
		
	ElsIf InteractionType = "Meetings" Then
		
		CommonClientServer.SetFilterItem(FilterGroup, 
			"Type", Type("DocumentRef.Meeting"),DataCompositionComparisonType.Equal,, True);
		
	ElsIf InteractionType = "PlannedInteractions" Then
		
		CommonClientServer.SetFilterItem(FilterGroup,
			"Type", Type("DocumentRef.PlannedInteraction"),DataCompositionComparisonType.Equal,, True);
		
	ElsIf InteractionType = "PhoneCalls" Then
		
		CommonClientServer.SetFilterItem(FilterGroup, 
			"Type", Type("DocumentRef.PhoneCall"),DataCompositionComparisonType.Equal,, True);
		
	ElsIf InteractionType = "OutgoingCalls" Then
		
		CommonClientServer.SetFilterItem(FilterGroup,
			"Type", Type("DocumentRef.PhoneCall"),DataCompositionComparisonType.Equal,, True);
		CommonClientServer.SetFilterItem(FilterGroup, 
			"Incoming",False,DataCompositionComparisonType.Equal,, True);
		
	ElsIf InteractionType = "IncomingCalls" Then
		
		CommonClientServer.SetFilterItem(FilterGroup, 
			"Type", Type("DocumentRef.PhoneCall"),DataCompositionComparisonType.Equal,, True);
		CommonClientServer.SetFilterItem(FilterGroup,
			"Incoming", True, DataCompositionComparisonType.Equal,, True);
			
	ElsIf InteractionType = "SMSMessages" Then
		
		CommonClientServer.SetFilterItem(FilterGroup, 
			"Type", Type("DocumentRef.SMSMessage"),DataCompositionComparisonType.Equal,, True);
	Else
			
		Filter.Items.Delete(FilterGroup);
		
	EndIf;
	
EndProcedure

// Generates an email addressee presentation.
//
// Parameters:
//  Name - String - an addressee name.
//  Address - String - an addressee email address.
//  Contact - CatalogRef - a contact that owns the name and email address.
//
// Returns:
//   String - a generated email addressee presentation.
//
Function GetAddresseePresentation(Name, Address, Contact) Export
	
	Result = ?(Name = Address OR Name = "", Address,?(IsBlankString(Address),Name, ?(StrFind(Name, Address) > 0, Name, Name + " <" + Address + ">")));
	If ValueIsFilled(Contact) AND TypeOf(Contact) <> Type("String") Then
		Result = Result + " [" + GetContactPresentation(Contact) + "]";
	EndIf;
	
	Return Result;
	
EndFunction

// Generates a presentation of email addressee list for addressee collection.
//
// Parameters:
//  AddresseesTable    - ValueTable - a table with addressee data.
//  IncludeContactName - Boolean - indicates that it is necessary to include it in contact data presentation.
//  Contact             - CatalogRef - a contact that owns the name and email address.
//
// Returns:
//  String - a generated email addressee list presentation.
//
Function GetAddressesListPresentation(AddresseesTable, IncludeContactName = True) Export

	Presentation = "";
	For Each TableRow In AddresseesTable Do
		Presentation = Presentation 
	              + GetAddresseePresentation(TableRow.Presentation,
	                                              TableRow.Address, 
	                                             ?(IncludeContactName, TableRow.Contact, "")) + "; ";
	EndDo;

	Return Presentation;

EndFunction

// Checks contact filling in interaction documents.
//
// Parameters:
//  InteractionObject    - DocumentObject - an interaction document being checked.
//  DocumentKind - String - a document name.
//
// Returns:
//  Boolean - True if they are filled, otherwise, False.
//
Function ContactsFilled(InteractionObject,DocumentKind)
	
	TabularSectionsArray = New Array;
	
	If DocumentKind = "OutgoingEmail" Then
		
		TabularSectionsArray.Add("EmailRecipients");
		TabularSectionsArray.Add("CCRecipients");
		TabularSectionsArray.Add("ReplyRecipients");
		TabularSectionsArray.Add("BccRecipients");
		
	ElsIf DocumentKind = "IncomingEmail" Then
		
		If NOT ValueIsFilled(InteractionObject.SenderContact) Then
			Return False;
		EndIf;
		
		TabularSectionsArray.Add("EmailRecipients");
		TabularSectionsArray.Add("CCRecipients");
		TabularSectionsArray.Add("ReplyRecipients");
		
	ElsIf DocumentKind = "Meeting" 
		OR DocumentKind = "PlannedInteraction" Then
				
		TabularSectionsArray.Add("Members");
		
	ElsIf DocumentKind = "SMSMessage" Then
		
		TabularSectionsArray.Add("Recipients");
		
	ElsIf DocumentKind = "PhoneCall" Then
		
		If NOT ValueIsFilled(InteractionObject.SubscriberContact) Then
			Return False;
		EndIf;
		
	EndIf;
	
	For each TabularSectionName In TabularSectionsArray Do
		For each TabularSectionRow In InteractionObject[TabularSectionName] Do
			
			If NOT ValueIsFilled(TabularSectionRow.Contact) Then
				Return False;
			EndIf;
			
		EndDo;
	EndDo;
	
	Return True;
	
EndFunction

// Sets property value for all subordinate group elements.
Procedure SetGroupItemsProperty(ItemsGroup, PropertyName, PropertyValue) Export
	
	For each SubordinateItem In ItemsGroup.ChildItems Do
		
		If TypeOf(SubordinateItem) = Type("FormGroup") Then
			
			SetGroupItemsProperty(SubordinateItem, PropertyName, PropertyValue);
			
		Else
			
			SubordinateItem[PropertyName] = PropertyValue;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Function GetContactPresentation(Contact)

	Return String(Contact);

EndFunction

// Determines dynamic list filter based on having the compatibility mode.
//
// Parameters:
//  List  - DynamicList - a list, whose filter has to be determined.
//
// Returns:
//   Filter - a required filter.
//
Function DynamicListFilter(List) Export

	Return List.SettingsComposer.FixedSettings.Filter;

EndFunction

Procedure PresentationGetProcessing(ObjectManager, Data, Presentation, StandardProcessing) Export
	
	InteractionSubject = InteractionSubject(Data.Subject);
	Date = Format(Data.Date, "DLF=D");
	DocumentType = "";
	If TypeOf(ObjectManager) = Type("DocumentManager.Meeting") Then
		DocumentType = NStr("ru = 'Встреча'; en = 'Meeting'; pl = 'Spotkanie';es_ES = 'Reunión';es_CO = 'Reunión';tr = 'Toplantı';it = 'Incontro';de = 'Treffen'");
		Date = Format(Data.StartDate, "DLF=D");
	ElsIf TypeOf(ObjectManager) = Type("DocumentManager.PlannedInteraction") Then
		DocumentType = NStr("ru = 'Запланированное взаимодействие'; en = 'Scheduled interaction'; pl = 'Zaplanowana interakcja';es_ES = 'Interacción programada';es_CO = 'Interacción programada';tr = 'Planlı etkileşim';it = 'Interazione programmata';de = 'Geplante Interaktion'");
	ElsIf TypeOf(ObjectManager) = Type("DocumentManager.SMSMessage") Then
		DocumentType = NStr("ru = 'SMS'; en = 'SMS'; pl = 'SMS';es_ES = 'SMS';es_CO = 'SMS';tr = 'SMS';it = 'SMS';de = 'SMS'");
	ElsIf TypeOf(ObjectManager) = Type("DocumentManager.PhoneCall") Then
		DocumentType = NStr("ru = 'Телефонный звонок'; en = 'Phone call'; pl = 'Połączenie telefoniczne';es_ES = 'Llamada telefónica';es_CO = 'Llamada telefónica';tr = 'Telefon görüşmesi';it = 'Chiamata';de = 'Telefonanruf'");
	ElsIf TypeOf(ObjectManager) = Type("DocumentManager.IncomingEmail") Then
		DocumentType = NStr("ru = 'Входящее письмо'; en = 'Incoming email'; pl = 'Wiadomość przychodząca';es_ES = 'Correo entrante';es_CO = 'Correo entrante';tr = 'Gelen e-posta';it = 'Email in entrata';de = 'Eingehende E-Mail'");
	ElsIf TypeOf(ObjectManager) = Type("DocumentManager.OutgoingEmail") Then
		DocumentType = NStr("ru = 'Исходящее письмо'; en = 'Outgoing email'; pl = 'Wychodząca wiadomość e-mail';es_ES = 'Correo saliente';es_CO = 'Correo saliente';tr = 'Giden e-posta';it = 'Email in uscita';de = 'Ausgehende E-Mail'");
	EndIf;
	
	PresentationTemplate = NStr("ru = '%1 от %2 (%3)'; en = '%1 issued on %2 (%3)'; pl = '%1 wydane dnia %2 (%3)';es_ES = '%1 emitido el %2 (%3)';es_CO = '%1 emitido el %2 (%3)';tr = '%1 düzenlendi %2 (%3)';it = '%1 rilasciato il %2 (%3)';de = '%1 ausgegeben am %2 (%3)'");
	Presentation = StringFunctionsClientServer.SubstituteParametersToString(PresentationTemplate, InteractionSubject, Date, DocumentType);
	
	StandardProcessing = False;
	 
EndProcedure

Procedure PresentationFieldsGetProcessing(ObjectManager, Fields, StandardProcessing) Export
	
	Fields.Add("Subject");
	Fields.Add("Date");
	If TypeOf(ObjectManager) = Type("DocumentManager.Meeting") Then
		Fields.Add("StartDate");
	EndIf;
	StandardProcessing = False;

EndProcedure

Function EmailFileExtensionsArray()
	
	FileExtensionsArray = New Array;
	FileExtensionsArray.Add("msg");
	FileExtensionsArray.Add("eml");
	
	Return FileExtensionsArray;
	
EndFunction

Function InteractionSubject(InteractionSubject) Export

	Return ?(IsBlankString(InteractionSubject), NStr("ru = '<Без темы>'; en = '<No subject>'; pl = '<Bez tematu>';es_ES = '<Sin Tema>';es_CO = '<Sin Tema>';tr = '<Konu yok>';it = '<Nessun soggetto>';de = '<Kein Thema>'"), InteractionSubject);

EndFunction 

#EndRegion
