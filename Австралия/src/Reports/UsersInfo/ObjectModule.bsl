#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure OnComposeResult(ResultDocument, DetailsData, StandardProcessing)
	
	StandardProcessing = False;
	
	ResultDocument.Clear();
	
	TemplateComposer = New DataCompositionTemplateComposer;
	Settings = SettingsComposer.GetSettings();
	
	NonExistingIBUsersIDs = New Array;
	
	ExternalDataSets = New Structure;
	ExternalDataSets.Insert("IBUsers", IBUsers(NonExistingIBUsersIDs));
	ExternalDataSets.Insert("ContactInformation", ContactInformation(Settings));
	
	Settings.DataParameters.SetParameterValue(
		"NonExistingIBUsersIDs", NonExistingIBUsersIDs);
	
	CompositionTemplate = TemplateComposer.Execute(DataCompositionSchema, Settings, DetailsData);
	
	CompositionProcessor = New DataCompositionProcessor;
	CompositionProcessor.Initialize(CompositionTemplate, ExternalDataSets, DetailsData, True);
	
	OutputProcessor = New DataCompositionResultSpreadsheetDocumentOutputProcessor;
	OutputProcessor.SetDocument(ResultDocument);
	
	OutputProcessor.BeginOutput();
	ResultItem = CompositionProcessor.Next();
	While ResultItem <> Undefined Do
		OutputProcessor.OutputItem(ResultItem);
		ResultItem = CompositionProcessor.Next();
	EndDo;
	OutputProcessor.EndOutput();
	
EndProcedure

#EndRegion

#Region Private

Function IBUsers(NonExistingIBUsersIDs)
	
	EmptyUniqueID = New UUID("00000000-0000-0000-0000-000000000000");
	NonExistingIBUsersIDs.Add(EmptyUniqueID);
	
	Query = New Query;
	Query.SetParameter("EmptyUniqueID", EmptyUniqueID);
	Query.Text =
	"SELECT
	|	Users.IBUserID,
	|	Users.IBUserProperies
	|FROM
	|	Catalog.Users AS Users
	|WHERE
	|	Users.IBUserID <> &EmptyUniqueID
	|
	|UNION ALL
	|
	|SELECT
	|	ExternalUsers.IBUserID,
	|	ExternalUsers.IBUserProperies
	|FROM
	|	Catalog.ExternalUsers AS ExternalUsers
	|WHERE
	|	ExternalUsers.IBUserID <> &EmptyUniqueID";
	
	DataExported = Query.Execute().Unload();
	DataExported.Indexes.Add("IBUserID");
	DataExported.Columns.Add("Mapped", New TypeDescription("Boolean"));
	
	IBUsers = New ValueTable;
	IBUsers.Columns.Add("UUID", New TypeDescription("UUID"));
	IBUsers.Columns.Add("Name", New TypeDescription("String", , New StringQualifiers(100)));
	IBUsers.Columns.Add("CanSignIn",    New TypeDescription("Boolean"));
	IBUsers.Columns.Add("StandardAuthentication", New TypeDescription("Boolean"));
	IBUsers.Columns.Add("ShowInList",   New TypeDescription("Boolean"));
	IBUsers.Columns.Add("CannotChangePassword",   New TypeDescription("Boolean"));
	IBUsers.Columns.Add("OpenIDAuthentication",      New TypeDescription("Boolean"));
	IBUsers.Columns.Add("OSAuthentication",          New TypeDescription("Boolean"));
	IBUsers.Columns.Add("OSUser", New TypeDescription("String", , New StringQualifiers(1024)));
	IBUsers.Columns.Add("Language",           New TypeDescription("String", , New StringQualifiers(100)));
	IBUsers.Columns.Add("RunMode",   New TypeDescription("String", , New StringQualifiers(100)));
	
	SetPrivilegedMode(True);
	AllIBUsers = InfoBaseUsers.GetUsers();
	
	For each InfobaseUser In AllIBUsers Do
		
		PropertiesIBUser = Users.IBUserProperies(InfobaseUser.UUID);
		
		NewRow = IBUsers.Add();
		FillPropertyValues(NewRow, PropertiesIBUser);
		Language = PropertiesIBUser.Language;
		NewRow.Language = ?(ValueIsFilled(Language), Metadata.Languages[Language].Synonym, "");
		NewRow.CanSignIn = Users.CanSignIn(PropertiesIBUser);
		
		Row = DataExported.Find(PropertiesIBUser.UUID, "IBUserID");
		If Row <> Undefined Then
			Row.Mapped = True;
			If Not NewRow.CanSignIn Then
				FillPropertyValues(NewRow,
					UsersInternal.StoredIBUserProperties(Row));
			EndIf;
		EndIf;
	EndDo;
	
	Filter = New Structure("Mapped", False);
	Rows = DataExported.FindRows(Filter);
	For each Row In Rows Do
		NonExistingIBUsersIDs.Add(Row.IBUserID);
	EndDo;
	
	Return IBUsers;
	
EndFunction

Function ContactInformation(Settings)
	
	ReferenceTypes = New Array;
	ReferenceTypes.Add(Type("CatalogRef.Users"));
	ReferenceTypes.Add(Type("CatalogRef.ExternalUsers"));
	
	Contacts = New ValueTable;
	Contacts.Columns.Add("Ref", New TypeDescription(ReferenceTypes));
	Contacts.Columns.Add("Phone", New TypeDescription("String"));
	Contacts.Columns.Add("EmailAddress", New TypeDescription("String"));
	
	If Not Common.SubsystemExists("StandardSubsystems.ContactInformation") Then
		Return Contacts;
	EndIf;
	
	FillContacts = False;
	PhoneField          = New DataCompositionField("Phone");
	EmailAddressField = New DataCompositionField("EmailAddress");
	
	For each Item In Settings.Selection.Items Do
		If TypeOf(Item) = Type("DataCompositionSelectedField")
		   AND (Item.Field = PhoneField Or Item.Field = EmailAddressField)
		   AND Item.Use Then
			
			FillContacts = True;
			Break;
		EndIf;
	EndDo;
	
	If Not FillContacts Then
		Return Contacts;
	EndIf;
	
	ContactInformationKinds = New Array;
	ContactInformationKinds.Add(Catalogs["ContactInformationKinds"].UserEmail);
	ContactInformationKinds.Add(Catalogs["ContactInformationKinds"].UserPhone);
	Query = New Query;
	Query.SetParameter("ContactInformationKinds", ContactInformationKinds);
	Query.Text =
	"SELECT
	|	UsersContactInformation.Ref AS Ref,
	|	UsersContactInformation.Kind,
	|	UsersContactInformation.Presentation
	|FROM
	|	Catalog.Users.ContactInformation AS UsersContactInformation
	|WHERE
	|	UsersContactInformation.Kind IN (&ContactInformationKinds)
	|
	|ORDER BY
	|	UsersContactInformation.Ref,
	|	UsersContactInformation.Type.Order,
	|	UsersContactInformation.Kind";
	
	Selection = Query.Execute().Select();
	
	CurrentRef = Undefined;
	Phones = "";
	EmailAddresses = "";
	
	While Selection.Next() Do
		If CurrentRef <> Selection.Ref Then
			If CurrentRef <> Undefined Then
				If ValueIsFilled(Phones) Or ValueIsFilled(EmailAddresses) Then
					NewRow = Contacts.Add();
					NewRow.Ref = CurrentRef;
					NewRow.Phone = Phones;
					NewRow.EmailAddress = EmailAddresses;
				EndIf;
			EndIf;
			Phones = "";
			EmailAddresses = "";
			CurrentRef = Selection.Ref;
		EndIf;
		If Selection.Kind = Catalogs["ContactInformationKinds"].UserPhone Then
			Phones = Phones + ?(ValueIsFilled(Phones), ", ", "");
			Phones = Phones + Selection.Presentation;
		EndIf;
		If Selection.Kind = Catalogs["ContactInformationKinds"].UserEmail Then
			EmailAddresses = EmailAddresses + ?(ValueIsFilled(EmailAddresses), ", ", "");
			EmailAddresses = EmailAddresses + Selection.Presentation;
		EndIf;
	EndDo;
	
	Return Contacts;
	
EndFunction

#EndRegion

#EndIf
