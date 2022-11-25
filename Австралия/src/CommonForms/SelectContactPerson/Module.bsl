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
	
	SaveOpeningParameters(Parameters);
	Interactions.ProcessUserGroupsDisplayNecessity(ThisObject);
	Interactions.AddContactsPickupFormPages(ThisObject);
	
	// Filling in contacts by the subject.
	Interactions.FillContactsBySubject(Items, Parameters.Topic, ContactsBySubject, False);
	
	// Filling in a search option list and performing the first search.
	AllSearchLists = Interactions.AvailableSearchesList(FTSEnabled, Parameters, Items, False);
	ExecuteFirstSearch();
	
	// If a contact is filled in, set the current page as appropriate one and position for the contact.
	If ValueIsFilled(Parameters.Contact) Then
		SetContactAsCurrent(Parameters.Contact)
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	FillChoiceListInSearchString(False);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure FoundContactsChoice(Item, RowSelected, Field, StandardProcessing)
	
	Notify("ContactSelected", NotificationParameters(Item.CurrentData.Ref));
	Close();

EndProcedure

&AtClient
Procedure Attachable_CatalogListChoice(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	CurrentData = Item.CurrentData;
	If CurrentData = Undefined  Then
		Return;
	EndIf;
	
	ContactDetails = New Structure;
	
	ContactDetailsArray = InteractionsClientServer.ContactsDetails();
	For Each ArrayElement In  ContactDetailsArray Do
		If TypeOf(CurrentData.Ref) = ArrayElement.Type Then
			ContactDetails = ArrayElement;
			Break;
		EndIf;
	EndDo;
	
	If ContactDetails.Property("Hierarchical")AND ContactDetails.Hierarchical Then
		IsFolder = IsFolder(CurrentData.Ref);
	Else
		IsFolder = False;
	EndIf;
	
	If Not IsFolder Then
		Notify("ContactSelected", NotificationParameters(CurrentData.Ref));
		Close();
	EndIf;
	
EndProcedure

&AtClient
Procedure ContactsBySubjectChoice(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	If Item.CurrentData <> Undefined Then
		Notify("ContactSelected", NotificationParameters(Item.CurrentData.Ref));
		Close();
	EndIf;
	
EndProcedure

&AtClient
Procedure SearchOptionsOnChange(Item)
	
	FillChoiceListInSearchString(True);
	
EndProcedure 

&AtClient
Procedure Attachable_ListContactsOnActivateRow(Item)
	
	DetermineActivatedContact(Item);
	
EndProcedure

&AtClient
Procedure Attachable_ListOwnerOnActivateRow(Item)
	
	DetermineActivatedContact(Item);
	
	InteractionsClient.ContactOwnerOnActivateRow(Item, ThisObject);

EndProcedure

&AtClient
Procedure UserGroupsOnActivateRow(Item)
	
	UsersList.Parameters.SetParameterValue("UsersGroup", Items.UserGroups.CurrentRow);
	
EndProcedure

&AtClient
Procedure ClearSearchOptions(Item, StandardProcessing)
	
	StandardProcessing = False;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

// Initiates a contact search process.
//
&AtClient
Procedure FindCommandExecute()
	
	If IsBlankString(SearchString) Then
		ShowMessageBox(, NStr("ru = 'Не задана строка поиска.'; en = 'Please enter the search string.'; pl = 'Wpisz frazę do wyszukiwania.';es_ES = 'Por favor, introduzca la línea de búsqueda.';es_CO = 'Por favor, introduzca la línea de búsqueda.';tr = 'Lütfen, arama dizesi girin.';it = 'Inserire la stringa di ricerca.';de = 'Bitte geben Sie die Suchzeichenfolge an.'"));
		Return;
	EndIf;
	
	Result = "";
	FoundContacts.Clear();
	
	If SearchOptions = "ByEmail" Then
		FindByEmail(False);
	ElsIf SearchOptions = "ByDomain" Then
		FindByEmail(True);
	ElsIf SearchOptions = "ByPhone" Then
		FindByPhone();
	ElsIf SearchOptions = "ByLine" Then
		Result = FindByString();
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
	
	If Items.FoundContacts.CurrentData <> Undefined Then
		SetContactAsCurrent(Items.FoundContacts.CurrentData.Ref);
	EndIf;

EndProcedure

// Positions in the dynamic list for the current contact from Contacts by subject list.
// 
//
&AtClient
Procedure FindInListFromSubjectListExecute()
	
	If Items.ContactsBySubject.CurrentData <> Undefined Then
		SetContactAsCurrent(Items.ContactsBySubject.CurrentData.Ref);
	EndIf;

EndProcedure

&AtClient
Procedure SelectCommand(Command)
	
	If Items.PagesLists.CurrentPage = Items.SearchContactsPage Then
		
		CurrentData = Items.FoundContacts.CurrentData;
		If CurrentData <> Undefined Then
			Notify("ContactSelected", NotificationParameters(CurrentData.Ref));
			Close();
		EndIf;
		
		Return;
		
	ElsIf Items.PagesLists.CurrentPage = Items.AllContactsBySubjectPage Then
		
		CurrentData = Items.ContactsBySubject.CurrentData;
		If CurrentData <> Undefined Then
			Notify("ContactSelected", NotificationParameters(CurrentData.Ref));
			Close();
		EndIf;
		
		Return;
		
	EndIf;
	
	ContactForChoice = Undefined;
	
	For ind = 0 To Items.PagesLists.CurrentPage.ChildItems.Count() -1 Do
		
		CurrentData = Items.PagesLists.CurrentPage.ChildItems[ind].CurrentData;
		If CurrentData = Undefined  Then
			Continue;
		Else
			If CurrentData.Property("Ref") AND CurrentData.Ref = LastActivatedContact Then
				ContactForChoice = LastActivatedContact;
				Break;
			EndIf;
		EndIf;
	EndDo;
	
	If ContactForChoice = Undefined Then
		Return;
	EndIf;
		
	ContactDetails = New Structure;
	
	ContactDetailsArray = InteractionsClientServer.ContactsDetails();
	For Each ArrayElement In  ContactDetailsArray Do
		If TypeOf(ContactForChoice) = ArrayElement.Type Then
			ContactDetails = ArrayElement;
			Break;
		EndIf;
	EndDo;
	
	If ContactDetails.Property("Hierarchical")AND ContactDetails.Hierarchical Then
		IsFolder = IsFolder(ContactForChoice);
	Else
		IsFolder = False;
	EndIf;
	
	If Not IsFolder Then
		Notify("ContactSelected", NotificationParameters(CurrentData.Ref));
		Close(ContactForChoice);
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// SEARCH PROCEDURES AND FUNCTIONS

// Generates a value list of the strings, by which search by the current search option will be carried out.
//
// Returns:
//   ValueList   - a list of strings to be searched by.
//
&AtServer
Function SearchStringsListByOption()

	StringsList = New ValueList;
	
	Values = Undefined;
	AllSearchLists.Property(SearchOptions, Values);
	
	If TypeOf(Values) = Type("String") Then
		StringsList.Add(Values);
	ElsIf TypeOf(Values) = Type("ValueList") Then
		For Each Item In Values Do
			StringsList.Add(Item.Value);
		EndDo;
	EndIf;
	
	Return StringsList;

EndFunction

// Performs the first search by all possible search options according to the passed parameters.
//
&AtServer
Procedure ExecuteFirstSearch()
	
	SearchOptions = "ByLine";
	If IsBlankString(Parameters.Address) AND IsBlankString(Parameters.Presentation) Then
		Return;
	EndIf;

	// Searching by email.
	SearchOptions = "ByEmail";
	For Each Option In SearchStringsListByOption() Do
		SearchString = Option.Value;
		If IsBlankString(SearchString) Then
			Continue;
		EndIf;
		If FindByEmail(False) Then
			Return;
		EndIf;
	EndDo;
	
	// Searching by phone number.
	SearchOptions = "ByPhone";
	For Each Option In SearchStringsListByOption() Do
		SearchString = Option.Value;
		If IsBlankString(SearchString) Then
			Continue;
		EndIf;
		If FindByPhone() Then
			Return;
		EndIf;
	EndDo;

	// If a full-text search index is not enabled, cancel search.
	If NOT FTSEnabled Then
		SearchOptions = "ByEmail";
		Return;
	EndIf;

	// Searching by an address and a presentation.
	SearchOptions = "ByLine";
	For Each Option In SearchStringsListByOption() Do
		SearchString = Option.Value;
		If IsBlankString(SearchString) Then
			Continue;
		EndIf;
		FindByString();
		If FoundContacts.Count() > 0 Then
			Return;
		EndIf;
	EndDo;

EndProcedure

// Searches for contacts by a domain name or an email address.
//
&AtServer
Function FindByEmail(ByDomain)

	Return Interactions.FindByEmail(SearchString, ByDomain, ThisObject);

EndFunction

// Searches for contacts by a phone number.
//
&AtServer
Function FindByPhone()
	
	Return Interactions.GetAllContactsByPhone(SearchString, ThisObject);
	
EndFunction

// Searches for contacts by a string.
//
&AtServer
Function FindByString()
	
	Return Interactions.FullTextContactsSearchByRow(SearchString, ThisObject);
	
EndFunction

// Searches for contacts by description beginning.
//
&AtServer
Function FindByDescriptionBeginning()

	ContactsTable = Interactions.AllContactsByDescriptionBeginning(SearchString);

	If ContactsTable = Undefined OR ContactsTable.Count() = 0 Then
		Return False;
	EndIf;
	
	Interactions.FillFoundContacts(ContactsTable, FoundContacts);
	Return True;

EndFunction

////////////////////////////////////////////////////////////////////////////////
// COMMON PROCEDURES AND FUNCTIONS.

// Sets a contact as the current contact in the dynamic list.
//
// Parameters:
//  Contact - CatalogRef - a contact to be positioned on.
// 
&AtServer
Procedure SetContactAsCurrent(Contact)

	Interactions.SetContactAsCurrent(Contact, ThisObject);

EndProcedure

&AtServer
Procedure SaveOpeningParameters(PassedParameters)
	
	Presentation = "";
	If Not IsBlankString(PassedParameters.Presentation) Then
		Presentation = StrGetLine(PassedParameters.Presentation, 1);
	EndIf;
	
	FormParameters.Add( PassedParameters.Address,                             "Address");
	FormParameters.Add( PassedParameters.Contact,                           "Contact");
	FormParameters.Add( PassedParameters.Topic,                           "Topic");
	FormParameters.Add( Presentation,                                         "Presentation");
	FormParameters.Add( PassedParameters.EmailOnly,                       "EmailOnly");
	FormParameters.Add( PassedParameters.PhoneOnly,                     "PhoneOnly");
	FormParameters.Add( PassedParameters.ForContactSpecificationForm,        "ForContactSpecificationForm");
	FormParameters.Add( PassedParameters.ReplaceEmptyAddressAndPresentation, "ReplaceEmptyAddressAndPresentation");
	FormParameters.Add( PassedParameters.FormID,                "FormID");
	
EndProcedure

&AtClient
Function NotificationParameters(SelectedContact)

	NotificationParameters = New Structure;
	
	For each ListItem In FormParameters Do
	
		NotificationParameters.Insert(ListItem.Presentation, ListItem.Value);
	
	EndDo;
	
	NotificationParameters.Insert("SelectedContact", SelectedContact);
	
	Return NotificationParameters;

EndFunction 

&AtClient
Procedure DetermineActivatedContact(Item)
	
	CurrentData = Item.CurrentData;
	If CurrentData <> Undefined Then
		LastActivatedContact = CurrentData.Ref;
	EndIf;
	
EndProcedure

&AtClient
Procedure FillChoiceListInSearchString(ChangeSearchString)

	SearchOptionsList = Undefined;
	AllSearchLists.Property(SearchOptions, SearchOptionsList);
	
	IsList = False;
	If TypeOf(SearchOptionsList) = Type("ValueList") Then
		Count = SearchOptionsList.Count();
		If Count = 0 Then
			SearchOptionsList = "";
		ElsIf Count = 1 Then
			SearchOptionsList = SearchOptionsList.Get(0).Value;
		Else
			IsList = True;
		EndIf;
	EndIf;
	
	Items.SearchString.DropListButton = IsList;
	
	If IsList Then
		Items.SearchString.ChoiceList.Clear();
		For Each OptionItem In SearchOptionsList Do
			Items.SearchString.ChoiceList.Add(OptionItem.Value);
		EndDo;
		If ChangeSearchString Then
			SearchString = SearchOptionsList.Get(0).Value;
		EndIf;
	ElsIf ChangeSearchString Then
		SearchString = SearchOptionsList;
	EndIf;

EndProcedure

&AtServer
Function IsFolder(ObjectRef)
	Return Common.ObjectAttributeValue(ObjectRef, "IsFolder");
EndFunction

#EndRegion
