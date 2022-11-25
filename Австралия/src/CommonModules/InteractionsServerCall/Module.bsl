///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#Region Private

////////////////////////////////////////////////////////////////////////////////
//  Main procedures and functions of contact search.

// Gets contact presentation and all its contact information.
//
// Parameters:
//  Contact - Ref - a contact, for which the information is being received.
//  Presentation           - String - the received presentation will be placed to this parameter.
//  CIRow                - String - the received contact information will be placed to this parameter.
//  ContactInformationType - Enums.ContactInformationTypes - an optional filter by contact 
//                                                                    information type.
//
Procedure PresentationAndAllContactInformationOfContact(Contact, Presentation, CIRow,ContactInformationType = Undefined) Export
	
	Presentation = "";
	CIRow = "";
	If Not ValueIsFilled(Contact) 
		OR TypeOf(Contact) = Type("CatalogRef.StringContactInteractions") Then
		Contact = Undefined;
		Return;
	EndIf;
	
	TableName = Contact.Metadata().Name;
	FieldNameForOwnerDescription = Interactions.FieldNameForOwnerDescription(TableName);
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	CatalogContact.Description          AS Description,
	|	" + FieldNameForOwnerDescription + " AS OwnerDescription
	|FROM
	|	Catalog." + TableName + " AS CatalogContact
	|WHERE
	|	CatalogContact.Ref = &Contact
	|";
	
	Query.SetParameter("Contact", Contact);
	Query.SetParameter("ContactInformationType", ContactInformationType);
	Selection = Query.Execute().Select();
	If Not Selection.Next() Then
		Return;
	EndIf;
	
	Presentation = Selection.Description;
	
	If Not IsBlankString(Selection.OwnerDescription) Then
		Presentation = Presentation + " (" + Selection.OwnerDescription + ")";
	EndIf;
	
	ContactsArray = CommonClientServer.ValueInArray(Contact);
	CITable = ContactsManager.ObjectsContactInformation(ContactsArray, ContactInformationType, Undefined, CurrentSessionDate());
	
	For Each TableRow In CITable Do
		If TableRow.Type <> Enums.ContactInformationTypes.Other Then
			CIRow = CIRow + ?(IsBlankString(CIRow), "", "; ") + TableRow.Presentation;
		EndIf;
	EndDo;
	
EndProcedure

// Gets description and addresses of the contact email.
//
// Parameters:
//  Contact - Ref - a contact, for which the data is being received.
//
// Returns:
//  Structure - contains a contact name and a list of values of the contact email.
//
Function ContactDescriptionAndEmailAddresses(Contact) Export
	
	If Not ValueIsFilled(Contact) 
		Or TypeOf(Contact) = Type("CatalogRef.StringContactInteractions") Then
		Return Undefined;
	EndIf;
	
	ContactMetadata = Contact.Metadata();
	
	If ContactMetadata.Hierarchical Then
		If Contact.IsFolder Then
			Return Undefined;
		EndIf;
	EndIf;
	
	ContactsTypesDetailsArray = InteractionsClientServer.ContactsDetails();
	DetailsArrayElement = Undefined;
	For Each ArrayElement In ContactsTypesDetailsArray Do
		
		If ArrayElement.Name = ContactMetadata.Name Then
			DetailsArrayElement = ArrayElement;
			Break;
		EndIf;
		
	EndDo;
	
	If DetailsArrayElement = Undefined Then
		Return Undefined;
	EndIf;
	
	TableName = ContactMetadata.FullName();
	
	QueryText =
	"SELECT ALLOWED DISTINCT
	|	ISNULL(ContactInformationTable.EMAddress,"""") AS EMAddress,
	|	CatalogContact." + DetailsArrayElement.ContactPresentationAttributeName + " AS Description
	|FROM
	|	" + TableName + " AS CatalogContact
	|		LEFT JOIN " + TableName + ".ContactInformation AS ContactInformationTable
	|		ON (ContactInformationTable.Ref = CatalogContact.Ref)
	|			AND (ContactInformationTable.Type = VALUE(Enum.ContactInformationTypes.EmailAddress))
	|WHERE
	|	CatalogContact.Ref = &Contact
	|TOTALS BY
	|	Description";
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("Contact", Contact);
	Selection = Query.Execute().Select(QueryResultIteration.ByGroups);
	
	If Not Selection.Next() Then
		Return Undefined;
	EndIf;
	
	Addresses = New Structure("Description,Addresses", Selection.Description, New ValueList);
	AddressesSelection = Selection.Select();
	While AddressesSelection.Next() Do
		Addresses.Addresses.Add(AddressesSelection.EMAddress);
	EndDo;
	
	Return Addresses;
	
EndFunction

// Gets contact email addresses.
//
// Parameters:
//  Contact - Ref - a contact, for which the data is being received.
//
// Returns:
//  Array - an array of structures that contain addresses with their kinds and presentations.
//
Function GetContactEmailAddresses(Contact, IncludeBlankKinds = False) Export
	
	If Not ValueIsFilled(Contact) Then
		Return Undefined;
	EndIf;
	
	Query = New Query;
	ContactMetadataName = Contact.Metadata().Name;
	
	If IncludeBlankKinds Then
		
		Query.Text =
		"SELECT
		|	ContactInformationKinds.Ref AS Kind,
		|	ContactInformationKinds.Description AS DescriptionKind,
		|	Contacts.Ref AS Contact
		|INTO ContactCIKinds
		|FROM
		|	Catalog.ContactInformationKinds AS ContactInformationKinds,
		|	Catalog." + ContactMetadataName + " AS Contacts
		|WHERE
		|	ContactInformationKinds.Parent = &ContactInformationKindGroup
		|	AND Contacts.Ref = &Contact
		|	AND ContactInformationKinds.Type = VALUE(Enum.ContactInformationTypes.EmailAddress)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	Presentation(ContactCIKinds.Contact) AS Presentation,
		|	ISNULL(ContactInformation.EMAddress, """") AS EMAddress,
		|	ContactCIKinds.Kind,
		|	ContactCIKinds.DescriptionKind
		|FROM
		|	ContactCIKinds AS ContactCIKinds
		|		LEFT JOIN Catalog." + ContactMetadataName + ".ContactInformation AS ContactInformation
		|		ON (ContactInformation.Ref = ContactCIKinds.Contact)
		|			AND (ContactInformation.Kind = ContactCIKinds.Kind)";
		
		ContactInformationKindGroup = ContactsManager.ContactInformationKindByName("Catalog" + ContactMetadataName);
		Query.SetParameter("ContactInformationKindGroup", ContactInformationKindGroup);
	Else
		
		Query.Text =
		"SELECT
		|	Tables.EMAddress,
		|	Tables.Kind,
		|	Tables.Presentation,
		|	Tables.Kind.Description AS DescriptionKind
		|FROM
		|	Catalog." + ContactMetadataName + ".ContactInformation AS Tables
		|WHERE
		|	Tables.Ref = &Contact
		|	AND Tables.Type = VALUE(Enum.ContactInformationTypes.EmailAddress)";
		
	EndIf;
	
	Query.SetParameter("Contact", Contact);
	
	Selection = Query.Execute().Select();
	If Selection.Count() = 0 Then
		Return New Array;
	EndIf;
	
	Result = New Array;
	While Selection.Next() Do
		Address = New Structure;
		Address.Insert("EMAddress",         Selection.EMAddress);
		Address.Insert("Kind",             Selection.Kind);
		Address.Insert("Presentation",   Selection.Presentation);
		Address.Insert("DescriptionKind", Selection.DescriptionKind);
		Result.Add(Address);
	EndDo;
	
	Return Result;
	
EndFunction

Function SendReceiveUserEmailInBackground(UUID) Export
	
	ProcedureParameters = New Structure;
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	ExecutionParameters.BackgroundJobDescription = NStr("ru = 'Получение и отправка электронной почты пользователя'; en = 'Receive and send user emails'; pl = 'Odbieraj i wysyłaj wiadomości e-mail użytkownika';es_ES = 'Recibir y enviar correos electrónicos del usuario';es_CO = 'Recibir y enviar correos electrónicos del usuario';tr = 'Kullanıcı e-postalarını al ve gönder';it = 'Ricevere e inviare email utenti';de = 'Benutzer-E-Mails empfengen und senden'");
	
	TimeConsumingOperation = TimeConsumingOperations.ExecuteInBackground("EmailManagement.SendReceiveUserEmail",
		ProcedureParameters,	ExecutionParameters);
	Return TimeConsumingOperation;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
//  Miscellaneous

// Sets a subject for the interaction array.
//
// Parameters:
//  InteractionsArray - Array - an array of intersations, for which a subject will be set.
//  Subject  - Ref - a subject that will replace the previous one.
//  CheckIfThereAreOtherChains - Boolean - if True, a subject will be also replaced for those 
//                                           interactions that are included into interaction chains 
//                                           whose first interaction is an interaction included in the array.
//
Procedure SetSubjectForInteractionsArray(InteractionsArray, Topic, CheckIfThereAreOtherChains = False) Export

	If CheckIfThereAreOtherChains Then
		
		Query = New Query;
		Query.Text = "SELECT DISTINCT
		|	InteractionsSubjects.Interaction AS Ref
		|FROM
		|	InformationRegister.InteractionsFolderSubjects AS InteractionsSubjects
		|WHERE
		|	NOT (NOT InteractionsSubjects.Topic IN (&InteractionsArray)
		|			AND NOT InteractionsSubjects.Interaction IN (&InteractionsArray))";
		
		Query.SetParameter("InteractionsArray", InteractionsArray);
		InteractionsArray = Query.Execute().Unload().UnloadColumn("Ref");
		
	EndIf;
	
	BeginTransaction();
	Try
		Lock = New DataLock;
		InformationRegisters.InteractionsFolderSubjects.BlockInteractionFoldersSubjects(Lock, InteractionsArray);
		Lock.Lock();
		
		If TypeOf(Topic) = Type("InformationRegisterRecordKey.InteractionsSubjectsStates") Then
			Topic = Topic.Topic;
		EndIf;
		
		Query = New Query;
		Query.Text = "SELECT DISTINCT
		|	InteractionsFolderSubjects.Topic
		|FROM
		|	InformationRegister.InteractionsFolderSubjects AS InteractionsFolderSubjects
		|WHERE
		|	InteractionsFolderSubjects.Interaction IN(&InteractionsArray)
		|
		|UNION ALL
		|
		|SELECT
		|	&Topic";
		
		Query.SetParameter("Topic", Topic);
		Query.SetParameter("InteractionsArray", InteractionsArray);
		
		SubjectsSelection = Query.Execute().Select();
		
		For Each Interaction In InteractionsArray Do
			Interactions.SetSubject(Interaction, Topic, False);
		EndDo;
		
		Interactions.CalculateReviewedBySubjects(Interactions.TableOfDataForReviewedCalculation(SubjectsSelection, "Topic"));
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;	
EndProcedure

// Transforms an email into binary data and prepares it for saving to the hard drive.
//
// Parameters:
//  Email - DocumentRef.IncomingEmail,
//                            DocumentRef.OutgoingEmail - an email that is being prepared for saving.
//  UUID - UUID - an UUID of a form, from which a saving command was called.
//
// Returns:
//  Structure - a structure that contains the prepared email data.
//
Function EmailDataToSaveAsFile(Email, UUID) Export

	FileData = FileDataStructure();
	
	EmailData = Interactions.InternetEmailMessageFromEmail(Email);
	If EmailData <> Undefined Then
		
		BinaryData = EmailData.InternetMailMessage.GetSourceData();
		FileData.BinaryFileDataRef = PutToTempStorage(BinaryData, UUID);

		FileData.Description = Interactions.EmailPresentation(EmailData.InternetMailMessage.Subject,
			EmailData.EmailDate);
		
		FileData.Extension  = "eml";
		FileData.FileName    = FileData.Description + "." + FileData.Extension;
		FileData.Size      = BinaryData.Size();
		FolderForSaveAs = Common.CommonSettingsStorageLoad("ApplicationSettings", "FolderForSaveAs");
		FileData.Insert("FolderForSaveAs", FolderForSaveAs);
		FileData.UniversalModificationDate = CurrentSessionDate();
		FileData.FullVersionDescription = FileData.FileName;
		
	EndIf;
	
	Return FileData;

EndFunction

Function FileDataStructure()

	FileDataStructure = New Structure;
	FileDataStructure.Insert("BinaryFileDataRef",        "");
	FileDataStructure.Insert("RelativePath",                  "");
	FileDataStructure.Insert("UniversalModificationDate",       Date(1, 1, 1));
	FileDataStructure.Insert("FileName",                           "");
	FileDataStructure.Insert("Description",                       "");
	FileDataStructure.Insert("Extension",                         "");
	FileDataStructure.Insert("Size",                             "");
	FileDataStructure.Insert("BeingEditedBy",                        Undefined);
	FileDataStructure.Insert("SignedWithDS",                         False);
	FileDataStructure.Insert("Encrypted",                         False);
	FileDataStructure.Insert("FileBeingEdited",                  False);
	FileDataStructure.Insert("CurrentUserEditsFile", False);
	FileDataStructure.Insert("FullVersionDescription",           "");
	
	Return FileDataStructure;

EndFunction 

#EndRegion
