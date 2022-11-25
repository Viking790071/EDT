///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
	
	Topic = Parameters.Topic;
	Email  = Parameters.Email;
	DoNotChangePresentationOnChangeContact = (TypeOf(Email) = Type("DocumentRef.IncomingEmail"));
	
	For each SelectedListItem In Parameters.SelectedItemsList Do
	
		For each ArrayElement In SelectedListItem.Value Do
			
			SearchParameters = New Structure;
			SearchParameters.Insert("Address", ArrayElement.Address);
			
			FoundRows = ContactsTable.FindRows(SearchParameters);
			
			If FoundRows.Count() > 0 Then
				
				ContactRow = FoundRows[0];
				
				If Not ValueIsFilled(ContactRow.Contact)
					AND ValueIsFilled(ArrayElement.Contact) Then
					
					ContactRow.Contact = ArrayElement.Contact;
					
				EndIf;
				
			Else
				
				NewRow = ContactsTable.Add();
				FillPropertyValues(NewRow,ArrayElement);
				NewRow.Group = SelectedListItem.Presentation;
				NewRow.FullPresentation = InteractionsClientServer.GetAddresseePresentation(
				ArrayElement.Presentation,ArrayElement.Address, "");
				
			EndIf;
			
		EndDo;
	
	EndDo;
	
	FillFoundContactsListsByEmail();
	FillCurrentEmailContactsTables();
	DefineEditAvailabilityForContacts();
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	Notification = New NotifyDescription("SaveAndLoad", ThisObject);
	CommonClient.ShowFormClosingConfirmation(Notification, Cancel, Exit);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "ContactSelected" Then
		
		CurrentData = Items.ContactsTable.CurrentData;
		CurrentData.Contact = Parameter.SelectedContact;
		FillContactAddresses(Items.ContactsTable.CurrentRow);
		SetClearFlagChangeIfRequired(CurrentData);
		Modified = True;
	
	EndIf;

EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ContactsTableOnActivateCell(Item)
	
	CurrentData = Items.ContactsTable.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If Item.CurrentItem.Name = "ContactsTableContact" Then
		
		Items.ContactsTableContact.ChoiceList.Clear();
		If CurrentData.FoundContactsList.Count() > 0 Then
			Items.ContactsTableContact.ChoiceList.LoadValues(
			CurrentData.FoundContactsList.UnloadValues());
		EndIf;
		
	ElsIf Item.CurrentItem.Name = "ContactsTableContactCurrentAddress" Then
		
		Items.ContactsTableContactCurrentAddress.ChoiceList.Clear();
		If CurrentData.ContactAddressesTable.Count() > 0 Then
			For each AddressesTableRow In CurrentData.ContactAddressesTable Do
				Items.ContactsTableContactCurrentAddress.ChoiceList.Add(
				   New Structure("Kind,Address",AddressesTableRow.Kind, AddressesTableRow.EMAddress),
				   GenerateAddressPresentationAndKind(AddressesTableRow.EMAddress, AddressesTableRow.DescriptionKind));
			EndDo;
			
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure ContactsTableCurrentContactAddressClearing(Item, StandardProcessing)
	
	StandardProcessing = False;
	
EndProcedure

&AtClient
Procedure ContactsTableCurrentContactAddressChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	
	CurrentData = Items.ContactsTable.CurrentData;
	If CurrentData = Undefined Then
		Return ;
	EndIf;
	
	If TypeOf(ValueSelected) = Type("Structure") 
		AND (ValueSelected.Address <> CurrentData.CurrentContactAddress 
		OR ValueSelected.Kind <> CurrentData.CurrentContactInformationKind) Then
			
		CurrentData.CurrentContactAddress = ValueSelected.Address;
		CurrentData.CurrentContactInformationKind = ValueSelected.Kind;
		CurrentData.CurrentContactAddressPresentation = GenerateAddressPresentationAndKind(
			ValueSelected.Address,ValueSelected.Kind);
			
		SetClearFlagChangeIfRequired(CurrentData);
		
	EndIf;
	
EndProcedure 

&AtClient
Procedure ContactsTableContactChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	
	CurrentData = Items.ContactsTable.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If CurrentData.Contact <> ValueSelected Then
		
		CurrentData.Contact = ValueSelected;
		Modified    = True;
		
		SetClearFlagChangeIfRequired(CurrentData);
		
		If NOT ValueIsFilled(ValueSelected) Then
			
			OnClearContact(CurrentData);
			
		Else
			
			FillContactAddresses(Items.ContactsTable.CurrentRow);
			
		EndIf;
		
		Modified = True;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ContactsTableContactClearing(Item, StandardProcessing)
	
	CurrentData = Items.ContactsTable.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	OnClearContact(CurrentData);
	SetClearFlagChangeIfRequired(CurrentData);
	Modified = True;
	
EndProcedure

&AtClient
Procedure ContactsTableContactOnChange(Item)
	
	CurrentData = Items.ContactsTable.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If Not ValueIsFilled(CurrentData.Contact) Then
		OnClearContact(CurrentData);
	Else
		FillContactAddresses(Items.ContactsTable.CurrentRow);
	EndIf;
	
	SetClearFlagChangeIfRequired(CurrentData);
	
	Modified = True;
	
EndProcedure

&AtClient
Procedure ContactsTableContactStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	CurrentData = Items.ContactsTable.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	OpeningParameters = New Structure;
	OpeningParameters.Insert("EmailOnly",                       True);
	OpeningParameters.Insert("PhoneOnly",                     False);
	OpeningParameters.Insert("ReplaceEmptyAddressAndPresentation", False);
	OpeningParameters.Insert("ForContactSpecificationForm",        True);
	OpeningParameters.Insert("FormID",                UUID);
	
	InteractionsClient.SelectContact(
			Topic, CurrentData.Address, CurrentData.Presentation,
			CurrentData.Contact, OpeningParameters);
	
EndProcedure

&AtClient
Procedure ContactsTableBeforeDeleteRow(Item, Cancel)
	
	Cancel = True;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure OKCommandExecute()
	
	SaveAndLoad();
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ContactsTable.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ContactsTable.Address");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotFilled;
	Item.Appearance.SetParameterValue("Enabled", False);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ContactsTableChange.Name);

	FIlterGroup1 = Item.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	FIlterGroup1.GroupType = DataCompositionFilterItemsGroupType.OrGroup;

	ItemFilter = FIlterGroup1.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ContactsTable.Address");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = New DataCompositionField("ContactsTable.CurrentContactAddress");

	ItemFilter = FIlterGroup1.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ContactsTable.Contact");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotFilled;

	ItemFilter = FIlterGroup1.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ContactsTable.Address");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotFilled;
	Item.Appearance.SetParameterValue("Enabled", False);
	
	//

	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ContactsTableChange.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue  = New DataCompositionField("ContactsTable.UpdateAvailable");
	ItemFilter.ComparisonType   = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;
	
	Item.Appearance.SetParameterValue("ReadOnly", True);

EndProcedure

&AtClient
Procedure SaveAndLoad(Result = Undefined, AdditionalParameters = Undefined) Export
	
	SelectionResult = New Array;
	HasContactInformationForUpdate = False;
	For each ContactsTableRow In ContactsTable Do
		
		If ContactsTableRow.Change Then
			HasContactInformationForUpdate = True;
		EndIf;
	
		DataStructure = New Structure;
		
		DataStructure.Insert("Presentation", ContactsTableRow.Presentation);
		DataStructure.Insert("Address", ContactsTableRow.Address);
		DataStructure.Insert("Contact", ContactsTableRow.Contact);
		DataStructure.Insert("Group", ContactsTableRow.Group);
		
		SelectionResult.Add(DataStructure);
		
	EndDo;
	
	If HasContactInformationForUpdate Then
		ChangeContactInformationForSelectedContacts();
	EndIf;
	
	CloseCommandExecuted = True;
	
	If Not Modified Then
		Close();
		Return;
	Else
		Modified = False;
	EndIf;
	
	NotifyChoice(SelectionResult);
	
EndProcedure

&AtServer
Procedure FillFoundContactsListsByEmail()
	
	// Getting an address list, for which emails are not specified.
	AddressesArray = New Array;
	For Each TableRow In ContactsTable Do
		If Not IsBlankString(TableRow.Address) Then
			AddressesArray.Add(TableRow.Address);
		EndIf;
	EndDo;
	
	// If emails are specified for all addresses, do not search.
	If AddressesArray.Count() = 0 Then
		Return;
	EndIf;
	
	// Finding contacts by emails.
	FoundContacts = Interactions.GetAllContactsByEmailList(AddressesArray);
	If FoundContacts.Rows.Count() = 0 Then
		Return;
	EndIf;
	
	For each Row In FoundContacts.Rows Do
		Row.Presentation = Upper(Row.Presentation);
	EndDo;
	
	// Filling in each row with a found contact list.
	For Each TableRow In ContactsTable Do
		If Not IsBlankString(TableRow.Address)  Then
			Folder = FoundContacts.Rows.Find(Upper(TableRow.Address), "Presentation");
			If Folder = Undefined Then
				Continue;
			EndIf;
			
			For Each Folder In Folder.Rows Do
				If TableRow.FoundContactsList.FindByValue(Folder.Contact) = Undefined Then
					ContactPresentation = Folder.Description + ?(IsBlankString(Folder.OwnerDescription), "", " (" + Folder.OwnerDescription + ")");
					TableRow.FoundContactsList.Add(Folder.Contact, ContactPresentation);
				EndIf;
			EndDo;
		EndIf;
	EndDo;
	
EndProcedure

&AtClientAtServerNoContext
Function GenerateAddressPresentationAndKind(Address, CIKind)

	If IsBlankString(Address) Then
		Return String(CIKind);
	Else
		Return String(CIKind) + " (" + Address + ")";
	EndIf;
	
EndFunction

&AtServer
Procedure FillCurrentEmailContactsTables()
	
	ContactsTypesDetailsArray = InteractionsClientServer.ContactsDetails();
	PredefinedItemsNames = Metadata.Catalogs.ContactInformationKinds.GetPredefinedNames();
	
	QueryText = "SELECT ALLOWED DISTINCT
	|	Contacts.Contact
	|INTO AllContacts
	|FROM
	|	&Contacts AS Contacts
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Contacts.Contact
	|INTO Contacts
	|FROM
	|	AllContacts AS Contacts
	|WHERE
	|	Contacts.Contact <> UNDEFINED
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ContactInformationKinds.Ref AS Kind,
	|	ContactInformationKinds.Description AS DescriptionKind,
	|	ContactsTable.Ref AS Contact
	|INTO UsersContactInformationKinds
	|FROM
	|	Catalog.ContactInformationKinds AS ContactInformationKinds,
	|	Catalog.Users AS ContactsTable
	|WHERE
	|	ContactInformationKinds.Parent = VALUE(Catalog.ContactInformationKinds.CatalogUsers)
	|	AND ContactInformationKinds.Type = VALUE(Enum.ContactInformationTypes.EmailAddress)
	|	AND ContactsTable.Ref IN
	|			(SELECT
	|				Contacts.Contact
	|			FROM
	|				Contacts AS Contacts)
	|;"; 
	
	For each DetailsArrayElement In ContactsTypesDetailsArray Do

		If DetailsArrayElement.Name = "Users" Then
			Continue;
		EndIf;
		
		OptionName = "Catalog" + DetailsArrayElement.Name;
		If PredefinedItemsNames.Find(OptionName) <> Undefined Then
			FilterOption = "VALUE(Catalog.ContactInformationKinds." + OptionName + ")";
		Else
			FilterOption = """" + OptionName +"""";
		EndIf;
		
		QueryText = QueryText + "
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	ContactInformationKinds.Ref AS Kind,
		|	ContactInformationKinds.Description AS DescriptionKind,
		|	ContactsTable.Ref AS Contact
		|INTO " + DetailsArrayElement.Name + "CIKinds
		|FROM
		|	Catalog.ContactInformationKinds AS ContactInformationKinds,
		|	Catalog." + DetailsArrayElement.Name + " AS ContactsTable
		|WHERE
		|	ContactInformationKinds.NameOfGroup = " + FilterOption + "
		|	AND ContactInformationKinds.Type = VALUE(Enum.ContactInformationTypes.EmailAddress)
		|	AND ContactsTable.Ref IN
		|			(SELECT
		|				Contacts.Contact
		|			FROM
		|				Contacts AS Contacts)
		|	" + ?(DetailsArrayElement.Hierarchical,"AND (NOT ContactsTable.IsFolder)","") + "
		|;";
		
	EndDo;
	
	QueryText = QueryText + "
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ContactsCIKinds.Contact,
	|	ISNULL(ContactInformation.EMAddress, """") AS EMAddress,
	|	ContactsCIKinds.Kind,
	|	ContactsCIKinds.DescriptionKind AS DescriptionKind
	|FROM
	|	UsersContactInformationKinds AS ContactsCIKinds
	|		LEFT JOIN Catalog.Users.ContactInformation AS ContactInformation
	|		ON ContactsCIKinds.Contact = ContactInformation.Ref
	|			AND ContactsCIKinds.TYPE = ContactInformation.Kind";
	
	For each DetailsArrayElement In ContactsTypesDetailsArray Do
		
		If DetailsArrayElement.Name = "Users" Then
			Continue;
		EndIf;
		
		QueryText = QueryText + "
		|
		|UNION ALL
		|
		|SELECT
		|	ContactsCIKinds.Contact,
		|	ISNULL(ContactInformation.EMAddress, """"),
		|	ContactsCIKinds.Kind,
		|	ContactsCIKinds.DescriptionKind
		|
		|FROM
		|	" + DetailsArrayElement.Name + "CIKinds AS ContactsCIKinds
		|		LEFT JOIN Catalog." + DetailsArrayElement.Name + ".ContactInformation AS ContactInformation
		|		ON ContactsCIKinds.TYPE = ContactInformation.Kind
		|			AND ContactsCIKinds.Contact = ContactInformation.Ref";
		
	EndDo;
	
	QueryText = QueryText + "
		|
		|TOTALS BY
		|	Contact";

	Query = New Query(QueryText);
	Query.SetParameter("Contacts",ContactsTable.Unload());
	
	Result = Query.Execute();
	If Result.IsEmpty() Then
		Return;
	EndIf;
	
	ResultsTree = Result.Unload(QueryResultIteration.ByGroups);
	
	For each ContactsTableRow In ContactsTable Do
		If ValueIsFilled(ContactsTableRow.Contact) Then
			FoundRow = ResultsTree.Rows.Find(ContactsTableRow.Contact, "Contact");
			If FoundRow <> Undefined Then
				
				FillAddressesTableFromCollection(ContactsTableRow, FoundRow.Rows);
				
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Procedure FillAddressesTableFromCollection(ContactsTableRow, Collection)
	
	ContactsTableRow.ContactAddressesTable.Clear();
	ContactsTableRow.CurrentContactAddress              = "";
	ContactsTableRow.CurrentContactInformationKind    = Catalogs.ContactInformationKinds.EmptyRef();
	ContactsTableRow.CurrentContactAddressPresentation = "";
	
	If Collection = Undefined Then
		Return;
	EndIf;
	
	AddressesMappingWasFound = False;
	
	For each CollectionRow In Collection Do
		
		NewAddressesTableRow = ContactsTableRow.ContactAddressesTable.Add();
		FillPropertyValues(NewAddressesTableRow, CollectionRow);
		If Upper(ContactsTableRow.Address) = Upper(CollectionRow.EMAddress) Then
			ContactsTableRow.CurrentContactAddress              = ContactsTableRow.Address;
			ContactsTableRow.CurrentContactInformationKind    = CollectionRow.Kind;
			ContactsTableRow.CurrentContactAddressPresentation = 
				GenerateAddressPresentationAndKind(ContactsTableRow.Address, CollectionRow.DescriptionKind);
			AddressesMappingWasFound = True;
		EndIf;
		
	EndDo;
	
	If (NOT AddressesMappingWasFound) AND Collection.Count() > 0 Then
		
		ContactsTableRow.CurrentContactAddress              = Collection[0].EMAddress;
		ContactsTableRow.CurrentContactInformationKind    = Collection[0].Kind;
		ContactsTableRow.CurrentContactAddressPresentation = 
			GenerateAddressPresentationAndKind(Collection[0].EMAddress,Collection[0].Kind);
		ContactsTableRow.Change                          = True;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnClearContact(CurrentData)

	CurrentData.FoundContactsList.Clear();
	CurrentData.ContactAddressesTable.Clear();
	CurrentData.Presentation                     = "";
	CurrentData.CurrentContactAddress              = "";
	CurrentData.CurrentContactInformationKind    =
		PredefinedValue("Catalog.ContactInformationKinds.EmptyRef");
	CurrentData.CurrentContactAddressPresentation = "";

EndProcedure

&AtServer
Procedure ChangeContactInformationForSelectedContacts()
	
	OutgoingEmailMetadata = Metadata.Documents.OutgoingEmail;
	IncomingEmailMetadata = Metadata.Documents.IncomingEmail;
	
	Query = New Query;
	Query.Text = "SELECT
	|	ContactsTable.Contact,
	|	ContactsTable.Address,
	|	ContactsTable.CurrentContactInformationKind,
	|	ContactsTable.Change
	|INTO AllContacts
	|FROM
	|	&ContactsTable AS ContactsTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AllContacts.Contact,
	|	AllContacts.Address,
	|	AllContacts.CurrentContactInformationKind AS Kind
	|FROM
	|	AllContacts AS AllContacts
	|WHERE
	|	AllContacts.Change";
	
	Query.SetParameter("ContactsTable", ContactsTable.Unload());
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		BeginTransaction();
		Try
			
			ContactMetadata = Selection.Contact.Metadata();
			Lock = New DataLock;
			LockItem = Lock.Add(ContactMetadata.FullName());
			LockItem.SetValue("Ref", Selection.Contact);
			Lock.Lock();
			
			ContactObject = Selection.Contact.GetObject();
			
			ContactsManager.AddContactInformation(Selection.Contact, Selection.Address, Selection.Kind, , True);
			
			Query = New Query;
			Query.Text = "
			|SELECT
			|	EmailMessageIncomingMessageRecipients.Ref AS Ref,
			|	EmailMessageIncomingMessageRecipients.Address,
			|	EmailMessageIncomingMessageRecipients.Contact,
			|	""EmailRecipients"" AS TabularSectionName
			|FROM
			|	Document.IncomingEmail.EmailRecipients AS EmailMessageIncomingMessageRecipients
			|WHERE
			|	EmailMessageIncomingMessageRecipients.Address = &Address
			|	AND EmailMessageIncomingMessageRecipients.Contact = UNDEFINED
			|	AND EmailMessageIncomingMessageRecipients.Ref <> &Email
			|
			|UNION ALL
			|
			|SELECT
			|	EmailMessageIncomingCCRecipients.Ref,
			|	EmailMessageIncomingCCRecipients.Address,
			|	EmailMessageIncomingCCRecipients.Contact,
			|	""CCRecipients""
			|FROM
			|	Document.IncomingEmail.CCRecipients AS EmailMessageIncomingCCRecipients
			|WHERE
			|	EmailMessageIncomingCCRecipients.Address = &Address
			|	AND EmailMessageIncomingCCRecipients.Contact = UNDEFINED
			|	AND EmailMessageIncomingCCRecipients.Ref <> &Email
			|
			|UNION ALL
			|
			|SELECT
			|	IncomingEmail.Ref,
			|	IncomingEmail.SenderAddress,
			|	IncomingEmail.SenderContact,
			|	""From""
			|FROM
			|	Document.IncomingEmail AS IncomingEmail
			|WHERE
			|	IncomingEmail.SenderAddress = &Address
			|	AND IncomingEmail.SenderContact = UNDEFINED
			|	AND IncomingEmail.Ref <> &Email
			|
			|UNION ALL
			|
			|SELECT
			|	EmailMessageOutgoingMessageRecipients.Ref,
			|	EmailMessageOutgoingMessageRecipients.Address,
			|	EmailMessageOutgoingMessageRecipients.Contact,
			|	""EmailRecipients""
			|FROM
			|	Document.OutgoingEmail.EmailRecipients AS EmailMessageOutgoingMessageRecipients
			|WHERE
			|	EmailMessageOutgoingMessageRecipients.Address = &Address
			|	AND EmailMessageOutgoingMessageRecipients.Contact = UNDEFINED
			|	AND EmailMessageOutgoingMessageRecipients.Ref <> &Email
			|
			|UNION ALL
			|
			|SELECT
			|	EmailMessageOutgoingCCRecipients.Ref,
			|	EmailMessageOutgoingCCRecipients.Address,
			|	EmailMessageOutgoingCCRecipients.Contact,
			|	""CCRecipients""
			|FROM
			|	Document.OutgoingEmail.CCRecipients AS EmailMessageOutgoingCCRecipients
			|WHERE
			|	EmailMessageOutgoingCCRecipients.Address = &Address
			|	AND EmailMessageOutgoingCCRecipients.Contact = UNDEFINED
			|	AND EmailMessageOutgoingCCRecipients.Ref <> &Email
			|
			|UNION ALL
			|
			|SELECT
			|	EmailMessageOutgoingBCCRecipients.Ref,
			|	EmailMessageOutgoingBCCRecipients.Address,
			|	EmailMessageOutgoingBCCRecipients.Contact,
			|	""BccRecipients""
			|FROM
			|	Document.OutgoingEmail.BccRecipients AS EmailMessageOutgoingBCCRecipients
			|WHERE
			|	EmailMessageOutgoingBCCRecipients.Address = &Address
			|	AND EmailMessageOutgoingBCCRecipients.Contact = UNDEFINED
			|	AND EmailMessageOutgoingBCCRecipients.Ref <> &Email
			|TOTALS BY
			|	Ref";
			
			Query.SetParameter("Address",Selection.Address);
			Query.SetParameter("Email",Email);
			
			Result = Query.Execute();
			OutgoingEmailsArray = New Array;
			IncomingEmailsArray  = New Array;
			
			EmailSelection = Result.Select(QueryResultIteration.ByGroups);
			While EmailSelection.Next() Do
				
				If TypeOf(EmailSelection.Ref) = Type("DocumentRef.IncomingEmail") Then
					IncomingEmailsArray.Add(EmailSelection.Ref);
				Else
					OutgoingEmailsArray.Add(EmailSelection.Ref);
				EndIf;
				
			EndDo;
			
			If IncomingEmailsArray.Count() > 0 Then
				
				Lock = New DataLock;
				LockItem = Lock.Add(IncomingEmailMetadata.FullName());
				
				LockSource = New ValueTable;
				LockSource.Columns.Add("Email", New TypeDescription("DocumentRef.IncomingEmail"));
				LockSource.LoadColumn(IncomingEmailsArray, "Email");
				
				LockItem.DataSource = LockSource;
				LockItem.UseFromDataSource("Ref", "Email");
				
				Lock.Lock();
				
			EndIf;
			
			If OutgoingEmailsArray.Count() > 0 Then
				
				Lock = New DataLock;
				LockItem = Lock.Add(OutgoingEmailMetadata.FullName());
				
				LockSource = New ValueTable;
				LockSource.Columns.Add("Email", New TypeDescription("DocumentRef.OutgoingEmail"));
				LockSource.LoadColumn(OutgoingEmailsArray, "Email");
				
				LockItem.DataSource = LockSource;
				LockItem.UseFromDataSource("Ref", "Email");
				
				Lock.Lock();
				
			EndIf;
			
			EmailSelection.Reset();
			
			EmailSelection = Result.Select(QueryResultIteration.ByGroups);
			While EmailSelection.Next() Do
				
				EmailObject = EmailSelection.Ref.GetObject();
				EmailDetailsSelection = EmailSelection.Select();
				While EmailDetailsSelection.Next() Do
					If EmailDetailsSelection.TabularSectionName = "From" Then
						EmailObject.SenderContact = ContactObject.Ref;
					Else
						FoundRows = 
							EmailObject[EmailDetailsSelection.TabularSectionName].FindRows(New Structure("Address", Selection.Address));
						For each FoundRow In FoundRows Do
							If Not ValueIsFilled(FoundRow.Contact) Then
								FoundRow.Contact = ContactObject.Ref;
							EndIf;
						EndDo;
					EndIf;
				EndDo;
				
				EmailObject.Write();
				
			EndDo;
			
			CommitTransaction();
			
		Except
			
			RollbackTransaction();
			
			ErrorMessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Во время обновления контактной информации %1 произошла ошибка
				|%2'; 
				|en = 'The following error occurred when updating contact information%1:
				|%2'; 
				|pl = 'Podczas aktualizacji informacji kontaktowych wystąpił błąd%1:
				|%2';
				|es_ES = 'Ha ocurrido el siguiente error al actualizar la información de contacto%1:
				|%2';
				|es_CO = 'Ha ocurrido el siguiente error al actualizar la información de contacto%1:
				|%2';
				|tr = 'İletişim bilgisi güncellenirken hata oluştu%1:
				|%2';
				|it = 'L''errore seguente si è verificato durante l''aggiornamento delle informazioni del contatto%1: 
				|%2';
				|de = 'Beim Aktualisieren von Kontaktinformationen ist das folgende Fehler aufgetreten%1:
				|%2'", CommonClientServer.DefaultLanguageCode()),
				Selection.Contact, DetailErrorDescription(ErrorInfo()));
			
			WriteLogEvent(EmailManagement.EventLogEvent(),
				EventLogLevel.Error, , , ErrorMessageText);
			
			Continue;
		EndTry;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure SetClearFlagChangeIfRequired(CurrentData)
	
	If (NOT ValueIsFilled(CurrentData.Address) OR Not ValueIsFilled(CurrentData.Contact) 
		OR Upper(CurrentData.Address) = Upper(CurrentData.CurrentContactAddress)) Then
		
		CurrentData.Change = False;
		
	Else
		
		CurrentData.Change = True;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FillContactAddresses(CurrentRow)
	
	CurrentData  = ContactsTable.FindByID(CurrentRow);
	AddressesTable = InteractionsServerCall.GetContactEmailAddresses(CurrentData.Contact,True);
	
	If (Not DoNotChangePresentationOnChangeContact) OR IsBlankString(CurrentData.Presentation) Then
		CurrentData.Presentation = String(CurrentData.Contact);
	EndIf;
	FillAddressesTableFromCollection(CurrentData, AddressesTable);
	
	DefineEditAvailabilityForContacts();

EndProcedure

&AtServer
Procedure DefineEditAvailabilityForContacts()

	For each RowContact In ContactsTable Do
	
		If Not ValueIsFilled(RowContact.Contact) Then
			
			RowContact.Change          = False;
			RowContact.UpdateAvailable = False;
			
		Else
			
			RightToEdit = AccessRight("Update", Metadata.FindByType(TypeOf(RowContact.Contact)));
			RowContact.UpdateAvailable = RightToEdit;
			If Not RightToEdit Then
				RowContact.Change = False;
			EndIf;
			
		EndIf;
	
	EndDo;

EndProcedure

#EndRegion
