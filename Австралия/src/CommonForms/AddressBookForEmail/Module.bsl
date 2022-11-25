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
	
	UseUserGroups = GetFunctionalOption("UseUserGroups");
	UsersList.Parameters.SetParameterValue("UseUserGroups", UseUserGroups);
	UsersList.Parameters.SetParameterValue("UsersGroup", Catalogs.UserGroups.EmptyRef());
	
	Interactions.AddContactsPickupFormPages(ThisObject);
	FillRecipientsTable();
	SetDefaultGroup();

	ContactInformationKinds = ContactsManager.ObjectContactInformationKinds(
		Catalogs.Users.EmptyRef(), Enums.ContactInformationTypes.EmailAddress);
	If ContactInformationKinds.Count() > 0 Then
		KindEmail = ContactInformationKinds[0].Ref;
	Else
		KindEmail = Undefined;
	EndIf;	
	UsersList.Parameters.SetParameterValue("Email", KindEmail);
	
	// Filling in contacts by the subject.
	Topic = Parameters.Topic;
	Interactions.FillContactsBySubject(Items, Topic, ContactsBySubject, True);
	
	SearchOptions = "Everywhere";
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)

	UpdateSearchOptionsMenu();
	PagesManagement();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	InteractionsClient.ProcessNotification(ThisObject, EventName, Parameter, Source);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure PageOnChangePage(Item, CurrentPage)
	
	PagesManagement();
	
EndProcedure

&AtClient
Procedure ContactStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	CurrentData = Items.EmailRecipients.CurrentData;
	OpeningParameters = New Structure;
	OpeningParameters.Insert("EmailOnly",                       True);
	OpeningParameters.Insert("PhoneOnly",                     False);
	OpeningParameters.Insert("ReplaceEmptyAddressAndPresentation", True);
	OpeningParameters.Insert("ForContactSpecificationForm",        False);
	OpeningParameters.Insert("FormID",                UUID);

	InteractionsClient.SelectContact(Topic, CurrentData.Address, CurrentData.Presentation,
	                                    CurrentData.Contact,OpeningParameters)
	
EndProcedure

&AtClient
Procedure EmailRecipientsOnStartEdit(Item, NewRow, Clone)
	
	If NewRow Then
		Item.CurrentData.Group = "SendTo";
	EndIf;
	
EndProcedure

&AtClient
Procedure EmailRecipientsOnActivateCell(Item)
	
	If Item.CurrentItem.Name = "Address" Then
		Items.Address.ChoiceList.Clear();
		
		CurrentData = Items.EmailRecipients.CurrentData;
		If CurrentData = Undefined Then
			Return;
		EndIf;
		
		If NOT IsBlankString(CurrentData.AddressesList) Then
			Items.Address.ChoiceList.LoadValues(
				StrSplit(CurrentData.AddressesList, ";"));
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure ContactsBySubjectChoice(Item, RowSelected, Field, StandardProcessing)

	AddRecipientFromListBySubject();

EndProcedure

&AtClient
Procedure Attachable_CatalogListChoice(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	If Not ValueIsFilled(RowSelected) Then
		Return;
	EndIf;
	
	Result = InteractionsServerCall.ContactDescriptionAndEmailAddresses(RowSelected);
	If Result = Undefined Then
		Return;
	EndIf;
	
	Address = Result.Addresses[0];
	AddressesList = StrConcat(Result.Addresses.UnloadValues(), ";");
	
	AddRecipient(Address, Result.Description, RowSelected, AddressesList);
	
EndProcedure

// Universal handler of a dynamic list line activation with subordinate lists.
&AtClient
Procedure Attachable_ListOwnerOnActivateRow(Item)
	
	InteractionsClient.ContactOwnerOnActivateRow(Item, ThisObject);
	
EndProcedure

&AtClient
Procedure FoundContactsChoice(Item, RowSelected, Field, StandardProcessing)
	
	CurrentData = Items.FoundContacts.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	Result = InteractionsServerCall.ContactDescriptionAndEmailAddresses(CurrentData.Ref);
	If Result <> Undefined AND Result.Addresses.Count() > 0 Then
		AddressesList = StrConcat(Result.Addresses.UnloadValues(), ";");
	Else
		AddressesList = "";
	EndIf;
	
	AddRecipient(CurrentData.Presentation, CurrentData.ContactDescription, CurrentData.Ref, AddressesList);
	
EndProcedure

&AtClient
Procedure UserGroupsOnActivateRow(Item)
	
	UsersList.Parameters.SetParameterValue("UsersGroup", Items.UserGroups.CurrentRow);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

// Passes to an owner a structure array with selected recipient addresses and closes the form.
// 
//
&AtClient
Procedure OKCommandExecute()
	
	Result = New Array;
	
	For Each TableRow In EmailRecipients Do
		
		If IsBlankString(TableRow.Address) Then
			Continue;
		EndIf;
		Folder = ?(IsBlankString(TableRow.Group), "SendTo", TableRow.Group);
		
		Contact = New Structure;
		Contact.Insert("Address", TableRow.Address);
		Contact.Insert("Presentation", TableRow.Presentation);
		Contact.Insert("Contact", TableRow.Contact);
		Contact.Insert("Group", Folder);
		Result.Add(Contact);
		
	EndDo;
	
	NotifyChoice(Result);
	
EndProcedure

// Moves the contact from the Contacts by subject list to the Email recipients list.
//
&AtClient
Procedure AddFromSubjectListExecute()

	AddRecipientFromListBySubject();

EndProcedure

// Changes the current group of email recipients to To group.
//
&AtClient
Procedure ChangeGroupToExecute()

	ChangeGroup("SendTo");

EndProcedure

// Changes the current group of email recipients to CC group.
//
&AtClient
Procedure ChangeGroupCCExecute()

	ChangeGroup("Cc");

EndProcedure 

// Changes the current group of email recipients to BCC group.
//
&AtClient
Procedure ChangeGroupBCCExecute()

	ChangeGroup("Hidden");

EndProcedure

// Initiates a contact search process.
//
&AtClient
Procedure FindContactsExecute()
	
	If IsBlankString(SearchString) Then
		CommonClientServer.MessageToUser(NStr("ru = 'Не задано, что нужно найти.'; en = 'Please enter the search string.'; pl = 'Wpisz frazę do wyszukiwania.';es_ES = 'Por favor, introduzca la línea de búsqueda.';es_CO = 'Por favor, introduzca la línea de búsqueda.';tr = 'Lütfen, arama dizesi girin.';it = 'Inserire la stringa di ricerca.';de = 'Bitte geben Sie die Suchzeichenfolge an.'"),, "SearchString");
		Return;
	EndIf;
	
	Result = "";
	FoundContacts.Clear();
	
	If SearchOptions = "Everywhere" Then
		Result = FindContacts();
	ElsIf SearchOptions = "ByEmail" Then
		FindByEmail(False);
	ElsIf SearchOptions = "ByDomain" Then
		FindByEmail(True);
	ElsIf SearchOptions = "ByLine" Then
		Result = ContactsFoundByString();
	ElsIf SearchOptions = "BeginsWith" Then
		FindByDescriptionBeginning();
	EndIf;
	
	If Not IsBlankString(Result) Then
		ShowMessageBox(, Result);
	EndIf;
	
EndProcedure

// Positions in the dynamic list position for the current contact from the Found contacts list.
// 
//
&AtClient
Procedure FindInListFromFoundContactsListExecute()
	
	CurrentData = Items.FoundContacts.CurrentData;
	If CurrentData <> Undefined AND ValueIsFilled(CurrentData.Ref) Then
		SetContactAsCurrent(CurrentData.Ref);
	EndIf;
	
EndProcedure

// Positions in the dynamic list for the current contact from the Email recipients list.
// 
//
&AtClient
Procedure FindInListFromRecipientsListExecute()
	
	CurrentData = Items.EmailRecipients.CurrentData;
	If CurrentData <> Undefined AND ValueIsFilled(CurrentData.Contact) Then
		SetContactAsCurrent(CurrentData.Contact);
	EndIf;
	
EndProcedure

// Positions in the dynamic list for the current contact from Contacts by subject list.
// 
//
&AtClient
Procedure FindInListFromSubjectListExecute()
	
	CurrentData = Items.ContactsBySubject.CurrentData;
	If CurrentData <> Undefined Then
		SetContactAsCurrent(CurrentData.Ref);
	EndIf;
	
EndProcedure 

// Initiates a contacts search by email address of the current line of the Email recipients list.
//
&AtClient
Procedure FindByAddressExecute()
	
	Items.PagesLists.CurrentPage = Items.SearchContactsPage;
	FoundContacts.Clear();

	CurrentData = Items.EmailRecipients.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;

	SearchString = CurrentData.Address;
	If Not IsBlankString(SearchString) Then
		FindByEmail(False);
	EndIf;

EndProcedure

// Initiates a contacts search by presentation of current line of the Email recipients list.
//
&AtClient
Procedure FindByPresentationExecute()
	
	Items.PagesLists.CurrentPage = Items.SearchContactsPage;
	FoundContacts.Clear();
	
	CurrentData = Items.EmailRecipients.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	SearchString = CurrentData.Presentation;
	If Not IsBlankString(SearchString) Then
		Result = ContactsFoundByString();
		If Not IsBlankString(Result) Then
			ShowMessageBox(,Result);
		EndIf;
	EndIf;
	
EndProcedure 

// Searches all contact email addresses from the Email recipients list and prompts the user to 
 // choose when a contact has more than one email address.
&AtClient
Procedure SetContactAddressExecute()
	
	CurrentData = Items.EmailRecipients.CurrentData;
	If CurrentData = Undefined Then
		ShowMessageBox(, NStr("ru = 'Необходимо выбрать адрес получателя в списке справа.'; en = 'Please select the recipient''s address in the list on the right.'; pl = 'Wybierz adres odbiorcy na liście z prawej strony.';es_ES = 'Por favor, seleccione la dirección del destinatario en la lista de la derecha.';es_CO = 'Por favor, seleccione la dirección del destinatario en la lista de la derecha.';tr = 'Lütfen, sağdaki listede alıcının adresini seçin.';it = 'Selezionare l''indirizzo del destinatario nell''elenco a destra.';de = 'Bitte wählen Sie die Adresse des Empfängers in der Liste rechts.'"));
		Return;
	EndIf;
	
	If Not ValueIsFilled(CurrentData.Contact) Then
		ContactStartChoice(Items.EmailRecipients, Undefined, True);
		Return;
	EndIf;
	
	Result = InteractionsServerCall.GetContactEmailAddresses(CurrentData.Contact);
	If Result.Count() = 0 Then
		ShowMessageBox(, 
			StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'У контакта ""%1"" нет адресов электронной почты.'; en = 'The following contact does not include email addresses: ""%1.""'; pl = 'Kontakt ""%1"" nie zawiera adresów e-mail';es_ES = 'El siguiente contacto no incluye direcciones de correo electrónico: ""%1.""';es_CO = 'El siguiente contacto no incluye direcciones de correo electrónico: ""%1.""';tr = 'Kişinin e-posta adresi yok: ""%1"".';it = 'Il contatto seguente non include indirizzi email: ""%1.""';de = 'Der folgende Kontakt enthält keine E-Mail-Adresse: ""%1.""'"),
				CurrentData.Contact));
		Return;
	EndIf;

	If Result.Count() = 1 Then
		Address = Result[0].EMAddress;
		Presentation = Result[0].Presentation;
		SetSelectedContactAddressAndPresentation(CurrentData, Presentation, Address);
	Else
		ChoiceList = New ValueList;
		Number = 0;
		For Each Item In Result Do
			ChoiceList.Add(Number, Item.DescriptionKind + ": " + Item.EMAddress);
			Number = Number + 1;
		EndDo;
		
		ChoiceProcessingParameters = New Structure;
		ChoiceProcessingParameters.Insert("Result", Result);
		ChoiceProcessingParameters.Insert("CurrentData", CurrentData);

		OnCloseNotifyHandler = New NotifyDescription("DSAddressChoiceListAfterCompletion", ThisObject, ChoiceProcessingParameters);

		ChoiceList.ShowChooseItem(OnCloseNotifyHandler);
	EndIf;

EndProcedure

// Positions in the dynamic list for the current contact from Contacts by subject list.
// 
//
&AtClient
Procedure SetContactFromSubjectsListExecute()
	
	CurrentData = Items.ContactsBySubject.CurrentData;
	If CurrentData <> Undefined Then
		SetContactInRecipientsList(CurrentData.Ref);
	EndIf;
	
EndProcedure 

&AtClient
Procedure DeleteAllRecipients(Command)
	
	EmailRecipients.Clear();
	
EndProcedure

&AtClient
Procedure DeleteRecipient(Command)
	
	SelectedRows = Items.EmailRecipients.SelectedRows;
	For each SelectedRow In SelectedRows Do
		EmailRecipients.Delete(EmailRecipients.FindByID(SelectedRow));
	EndDo;
	
EndProcedure

&AtClient
Procedure IncludeInRecipientsList(Command)
	
	If Items.PagesLists.CurrentPage = Items.SearchContactsPage Then
		For each SelectedRow In Items.FoundContacts.SelectedRows Do
			RowData = Items.FoundContacts.RowData(SelectedRow);
			AddRecipient(RowData.Presentation, RowData.ContactDescription, RowData.Ref);
		EndDo;
		Return;
	EndIf;
	
	FormItemNumber = Undefined;
	
	If Items.PagesLists.CurrentPage.ChildItems.Count() = 1 Then
		
		FormItemNumber = 0;
		
	ElsIf Items.PagesLists.CurrentPage.ChildItems.Count() = 2 Then
		
		If CurrentItem.Name = "MoveFromTopListToSelected" Then
			FormItemNumber = 0;
		Else
			FormItemNumber = 1;
		EndIf;
		
	EndIf;
	
	If FormItemNumber = Undefined Then
		Return;
	EndIf;
	
	MoveSelectedRows(
		Items.PagesLists.CurrentPage.ChildItems[FormItemNumber].SelectedRows);
	
EndProcedure

&AtClient
Procedure SearchEverywhereOption(Command)
	SearchOptions = "Everywhere";
	UpdateSearchOptionsMenu();
EndProcedure

&AtClient
Procedure SearchInAddressesOption(Command)
	SearchOptions = "ByEmail";
	UpdateSearchOptionsMenu();
EndProcedure

&AtClient
Procedure SearchInContactsDescriptionsOption(Command)
	SearchOptions = "ByLine";
	UpdateSearchOptionsMenu();
EndProcedure

&AtClient
Procedure SearchByDomainNameOption(Command)
	SearchOptions = "ByDomain";
	UpdateSearchOptionsMenu();
EndProcedure

&AtClient
Procedure View(Command)
	If Items.PagesLists.CurrentPage = Items.UsersPage Then
		CurrentData = Items.UsersList.CurrentData;
	ElsIf TypeOf(CurrentItem) = Type("FormTable") Then
		CurrentData = CurrentItem.CurrentData;
	Else
		Return;
	EndIf;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	ShowValue(, CurrentData.Ref);
	
EndProcedure

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Search procedures and functions.

&AtServer
Function FindContacts()
	
	Return Interactions.FindContacts(SearchString, ThisObject);
	
EndFunction

&AtServer
Procedure FindByEmail(ByDomain)
	
	Interactions.FindByEmail(SearchString, ByDomain, ThisObject);
	
EndProcedure

&AtServer
Function ContactsFoundByString()
	
	Return Interactions.FullTextContactsSearchByRow(SearchString, ThisObject, True);
	
EndFunction

&AtServer
Procedure FindByDescriptionBeginning()
	
	Interactions.FindContactsWithAddressesByDescription(SearchString, ThisObject);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Other procedures and functions

&AtServer
Procedure FillRecipientsTable()
	
	RecipientsTab = FormAttributeToValue("EmailRecipients");
	
	For Each SelectedRecipientsGroup In Parameters.SelectedItemsList Do
		If SelectedRecipientsGroup.Value <> Undefined Then
			For Each Item In SelectedRecipientsGroup.Value Do
				NewRow = RecipientsTab.Add();
				NewRow.Group = SelectedRecipientsGroup.Presentation;
				FillPropertyValues(NewRow, Item);
			EndDo;
		EndIf;
	EndDo;
	
	RecipientsTab.Sort("Group");
	
	If RecipientsTab.Count() > 0 Then
		AddressesTable =
			Interactions.ContactsEmailAddresses(RecipientsTab.UnloadColumn("Contact"));
			
			Query = New Query;
			Query.Text = "
			|SELECT
			|	EmailRecipients.Address,
			|	EmailRecipients.Presentation,
			|	EmailRecipients.Contact,
			|	EmailRecipients.Group
			|INTO EmailRecipients
			|FROM
			|	&EmailRecipients AS EmailRecipients
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT
			|	AddressContacts.Contact,
			|	AddressContacts.AddressesList
			|INTO ContactsAddressList
			|FROM
			|	&AddressContacts AS AddressContacts
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT
			|	EmailRecipients.Address,
			|	EmailRecipients.Presentation,
			|	EmailRecipients.Contact,
			|	EmailRecipients.Group,
			|	ISNULL(ContactsAddressList.AddressesList, """") AS AddressesList
			|FROM
			|	EmailRecipients AS EmailRecipients
			|		LEFT JOIN ContactsAddressList AS ContactsAddressList
			|		ON ContactsAddressList.Contact = EmailRecipients.Contact";
			
			Query.SetParameter("EmailRecipients", RecipientsTab);
			Query.SetParameter("AddressContacts", AddressesTable);
			
			RecipientsTab = Query.Execute().Unload();
		
	EndIf;
	
	ValueToFormAttribute(RecipientsTab, "EmailRecipients");
	
EndProcedure

&AtClient
Procedure AddRecipient(Address, Description, Contact, AddressesList = "")
	
	DeleteBlankRecipient(EmailRecipients);
	
	NewRow = EmailRecipients.Add();
	NewRow.Address         = Address;
	NewRow.Presentation = Description;
	NewRow.Contact       = Contact;
	NewRow.AddressesList = AddressesList;
	NewRow.Group        = DefaultGroup;
	
EndProcedure

&AtClientAtServerNoContext
Procedure DeleteBlankRecipient(EmailRecipients)
	
	If EmailRecipients.Count() = 0 Then
		Return;
	EndIf;	
		
	EmailRecipient = EmailRecipients[0];
	If IsBlankString(EmailRecipient.Address) AND IsBlankString(EmailRecipient.Presentation) AND Not ValueIsFilled(EmailRecipient.Contact) Then
		EmailRecipients.Delete(0);
	EndIf;	

EndProcedure

&AtClient
Procedure AddRecipientFromListBySubject()
	
	CurrentData = Items.ContactsBySubject.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	Result = InteractionsServerCall.ContactDescriptionAndEmailAddresses(CurrentData.Ref);
	If Result <> Undefined AND Result.Addresses.Count() > 0 Then
		AddressesList = StrConcat(Result.Addresses.UnloadValues(), ";");
	Else
		AddressesList = "";
	EndIf;
	
	AddRecipient(CurrentData.Address, CurrentData.Description, CurrentData.Ref, AddressesList);
	
EndProcedure

&AtClient
Procedure SetContactInRecipientsList(Contact)
	
	If ValueIsFilled(Contact) AND Items.EmailRecipients.CurrentData <> Undefined Then
		Items.EmailRecipients.CurrentData.Contact = Contact;
	EndIf;
	
EndProcedure

&AtServer
Procedure SetContactAsCurrent(Contact)
	
	Interactions.SetContactAsCurrent(Contact, ThisObject);
	
EndProcedure

&AtClient
Procedure ChangeGroup(NameOfGroup)
	
	For Each SelectedRow In Items.EmailRecipients.SelectedRows Do
		Item = EmailRecipients.FindByID(SelectedRow);
		Item.Group = NameOfGroup;
	EndDo;
	
EndProcedure

&AtServer
Procedure MoveSelectedRows(Val SelectedRows)

	Result = Interactions.ContactsEmailAddresses(SelectedRows, DefaultGroup);
	If Result <> Undefined Then
		DeleteBlankRecipient(EmailRecipients);
		CommonClientServer.SupplementTable(Result, EmailRecipients);
	EndIf;
	
EndProcedure

&AtServer
Procedure SetDefaultGroup()
	
	If Parameters.Property("DefaultGroup") Then
		DefaultGroup = Parameters.DefaultGroup;
	EndIf;
	If IsBlankString(DefaultGroup) Then
		DefaultGroup = NStr("ru = 'Кому'; en = 'To'; pl = 'Do';es_ES = 'Para';es_CO = 'Para';tr = 'Kime';it = 'A';de = 'An'");
	EndIf;
	
EndProcedure 

&AtClient
Procedure PagesManagement()

	If Items.PagesLists.CurrentPage = Items.AllContactsBySubjectPage 
		OR Items.PagesLists.CurrentPage = Items.SearchContactsPage 
		OR Items.PagesLists.CurrentPage.ChildItems.Count() = 1 
		OR (Items.PagesLists.CurrentPage = Items.UsersPage 
		AND (NOT UseUserGroups))Then
		
		Items.MovePages.CurrentPage = Items.MoveOneTablePage;
		
	Else
		
		Items.MovePages.CurrentPage = Items.MoveTwoTablesPage;
		
	EndIf;

EndProcedure 

&AtClient
Procedure DSAddressChoiceListAfterCompletion(SelectedItem, AdditionalParameters) Export

	If SelectedItem = Undefined Then
		Return;
	EndIf;
	
	Index = SelectedItem.Value;
	Address = AdditionalParameters.Result[Index].EMAddress;
	Presentation = AdditionalParameters.Result[Index].Presentation;
	SetSelectedContactAddressAndPresentation(AdditionalParameters.CurrentData, Presentation, Address);

EndProcedure

&AtClient
Procedure SetSelectedContactAddressAndPresentation(CurrentData, Presentation, Address)

	Position = StrFind(Presentation, "<");
	Presentation = ?(Position= 0, "", TrimAll(Left(Presentation, Position-1)));

	CurrentData.Address = Address;
	If Not IsBlankString(Presentation) Then
		CurrentData.Presentation = Presentation;
	EndIf;

EndProcedure

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	
	Interactions.SetChoiceListConditionalAppearance(ThisObject, "Group", "EmailRecipients.Group");
	
EndProcedure 

&AtClient
Procedure UpdateSearchOptionsMenu()
	
	Items.SearchEverywhereOption.Check = (SearchOptions = "Everywhere");
	Items.SearchInAddressesOption.Check = (SearchOptions = "ByEmail");
	Items.SearchInContactsDescriptionsOption.Check = (SearchOptions = "ByLine");
	Items.SearchByDomainNameOption.Check = (SearchOptions = "ByDomain");

EndProcedure

#EndRegion
