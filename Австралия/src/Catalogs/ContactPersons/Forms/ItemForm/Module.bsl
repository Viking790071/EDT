
#Region FormEventHadlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If UsersClientServer.IsExternalUserSession() Then
		
		Cancel = True;
		Return;
		
	EndIf;
	If Parameters.Key.IsEmpty() Then
		
		OnCreateOnReadAtServer();
		
	EndIf;
	
	// StandardSubsystems.Interactions
	Interactions.PrepareNotifications(ThisObject, Parameters, False);
	// End StandardSubsystems.Interactions
	
	// StandardSubsystems.ObjectVersioning
	ObjectsVersioning.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.ObjectVersioning
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Properties
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ItemForPlacementName", "GroupAdditionalAttributes");
	PropertyManager.OnCreateAtServer(ThisObject, AdditionalParameters);
	// End StandardSubsystems.Properties
	
	// StandardSubsystems.ContactInformation
	ContactsManager.OnCreateAtServer(ThisObject, Object, "ContactInformationGroup", FormItemTitleLocation.Left);
	// End StandardSubsystems.ContactInformation
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject, Object);
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	OnCreateOnReadAtServer();
	
	PreviousOwner = Object.Owner;
	
	// StandardSubsystems.Properties
	PropertyManager.OnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
	// StandardSubsystems.ContactInformation
	ContactsManager.OnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.ContactInformation

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtServer
Procedure OnCreateOnReadAtServer()
	
	ReadRolesData();
	RefreshRolesItems();
	
	If Parameters.Property("ContactPersonIndex") Then
		ContactPersonIndex = Parameters.ContactPersonIndex;
	Else
		ContactPersonIndex = -1;
	EndIf;
	If Parameters.Property("Counterparty")
		And Not Object.Owner = Parameters.Counterparty Then
		Object.Owner = Parameters.Counterparty;
		Modified = True;
	EndIf;
	If Parameters.Property("ContactDescription")
		And Not Object.Description = Parameters.ContactDescription Then
		Object.Description = Parameters.ContactDescription;
		Modified = True;
	EndIf;
	If Parameters.Property("Position")
		And Not Object.Position = Parameters.Position Then
		Object.Position = Parameters.Position;
		Modified = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// StandardSubsystems.Properties
	PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Write_ContactPerson_Counterparty" And Object.Ref = Parameter Then
		ReReadObject();
	EndIf;
	
	// StandardSubsystems.Properties
	If PropertyManagerClient.ProcessNofifications(ThisObject, EventName, Parameter) Then
		UpdateAdditionalAttributeItems();
		PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	EndIf;
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	// Duplicates blocking
	If Not WriteParameters.Property("NotToCheckDuplicates") Then
		
		DuplicateCheckingParameters = DriveClient.GetDuplicateCheckingParameters(ThisObject, "ContactInformationAdditionalAttributeDetails");
		DuplicatesTableStructure = DuplicatesTableStructureAtServer(DuplicateCheckingParameters);
		
		If ValueIsFilled(DuplicatesTableStructure.DuplicatesTableAddress) Then
			
			Cancel = True;
			
			FormParameters = New Structure;
			FormParameters.Insert("Ref", DuplicateCheckingParameters.Ref);
			FormParameters.Insert("DuplicatesTableStructure", DuplicatesTableStructure);
			
			NotificationDescriptionOnCloseDuplicateChecking = New NotifyDescription("OnCloseDuplicateChecking", ThisObject);
			
			OpenForm("DataProcessor.DuplicateChecking.Form.DuplicateChecking",
				FormParameters,
				ThisObject,
				True,
				,
				,
				NotificationDescriptionOnCloseDuplicateChecking);
				
		EndIf;
		
	EndIf;
	// End Duplicates blocking

EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	WriteRolesData(CurrentObject);
	
	// StandardSubsystems.ContactInformation
	ContactsManager.BeforeWriteAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.ContactInformation
	
	// StandardSubsystems.Properties
	PropertyManager.BeforeWriteAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
	// Duplicates blocking
	If ValueIsFilled(DuplicateRulesIndexTableAddress) And ValueIsFilled(Object.Ref) Then
		CurrentObject.AdditionalProperties.Insert("DuplicateRulesIndexTableAddress", DuplicateRulesIndexTableAddress);
	EndIf;
	
	If ValueIsFilled(ModificationTableAddress) Then
		CurrentObject.AdditionalProperties.Insert("ModificationTableAddress", ModificationTableAddress);
	EndIf;
	// End Duplicates blocking

	NativeLanguagesSupportServer.BeforeWriteAtServer(CurrentObject);
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	// StandardSubsystems.Interactions
	InteractionsClient.ContactAfterWrite(ThisObject, Object, WriteParameters, "ContactPersons");
	// End StandardSubsystems.Interactions
	
	NotifyParameter = New Structure;
	NotifyParameter.Insert("ContactPerson",	Object.Ref);
	NotifyParameter.Insert("Owner",			Object.Owner);
	NotifyParameter.Insert("PreviousOwner",	PreviousOwner);
	NotifyParameter.Insert("Description",	Object.Description);
	
	If ContactPersonIndex >= 0 Then
		NotifyParameter.Insert("ContactPersonIndex",	ContactPersonIndex);
	EndIf;
	
	Notify("Write_ContactPerson", NotifyParameter, ThisObject);
	
	PreviousOwner = Object.Owner;
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	// StandardSubsystems.ContactInformation
	ContactsManager.AfterWriteAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.ContactInformation

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.ContactInformation
	ContactsManager.FillCheckProcessingAtServer(ThisObject, Object, Cancel);
	// End StandardSubsystems.ContactInformation
	
	// StandardSubsystems.Properties
	PropertyManager.FillCheckProcessing(ThisObject, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure RolesCloudURLProcessing(Item, FormattedStringURL, StandardProcessing)
	
	StandardProcessing = False;
	
	RoleID = Mid(FormattedStringURL, StrLen("Role_")+1);
	RolesRow = RolesData.FindByID(RoleID);
	RolesData.Delete(RolesRow);
	
	RefreshRolesItems();
	
	Modified = True;
	
EndProcedure

&AtClient
Procedure Attachable_Open(Item, StandardProcessing)
	NativeLanguagesSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure ReReadObject()
	
	NewObject = Object.Ref.GetObject();
	ValueToFormAttribute(NewObject, "Object");
	OnCreateOnReadAtServer();
	
EndProcedure

#Region DuplicatesBlocking

// Procedure of processing the results of Duplicate checking closing
//
&AtClient
Procedure OnCloseDuplicateChecking(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) = Type("Structure") Then
		
		If ValueIsFilled(ClosingResult.ActionWithExistingObject) Then
				
			ModificationTableAddress = ClosingResult.ModificationTableAddress;
				
		EndIf;
		
		DuplicateRulesIndexTableAddress = ClosingResult.DuplicateRulesIndexTableAddress;
		
		If ClosingResult.ActionWithNewObject = "Create" Then
			
			NotToCheck = New Structure("NotToCheckDuplicates", True);
			ThisObject.Write(NotToCheck);
			ThisObject.Close();
			
		ElsIf ClosingResult.ActionWithNewObject = "Delete" Then
			
			If ValueIsFilled(Object.Ref) Then
				
				Object.DeletionMark = True;
				NotToCheck = New Structure("NotToCheckDuplicates", True);
				ThisObject.Write(NotToCheck);
				ThisObject.Close();
				
			Else
				
				If ChangeDuplicatesDataAtServer(ModificationTableAddress) Then
					
					ThisObject.Modified = False;
					ThisObject.Close();
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function ChangeDuplicatesDataAtServer(ModificationTableAddress)
	
	Cancel = False;
	ModificationTable = GetFromTempStorage(ModificationTableAddress);
	DuplicatesBlocking.ChangeDuplicatesData(ModificationTable, Cancel);
	
	Return Not Cancel;
	
EndFunction

&AtServerNoContext
Function DuplicatesTableStructureAtServer(DuplicateCheckingParameters)
	
	Return DuplicatesBlocking.DuplicatesTableStructure(DuplicateCheckingParameters);
	
EndFunction

#EndRegion

#Region Roles

&AtServer
Procedure ReadRolesData()
	
	RolesData.Clear();
	
	If Not ValueIsFilled(Object.Ref) Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text = 
		"SELECT ALLOWED
		|	ContactPersonsRoles.Role AS Role,
		|	ContactPersonsRoles.Role.DeletionMark AS DeletionMark,
		|	ContactPersonsRoles.Role.Description AS Description
		|FROM
		|	Catalog.ContactPersons.Roles AS ContactPersonsRoles
		|WHERE
		|	ContactPersonsRoles.Ref = &Ref";
	
	Query.SetParameter("Ref", Object.Ref);
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		NewRoleData = RolesData.Add();
		URLFS	= "Role_" + NewRoleData.GetID();
		
		NewRoleData.Role				= Selection.Role;
		NewRoleData.DeletionMark		= Selection.DeletionMark;
		NewRoleData.RolePresentation	= FormattedStringRolePresentation(Selection.Description, Selection.DeletionMark, URLFS);
		NewRoleData.RoleLength			= StrLen(Selection.Description);
		
	EndDo;
	
EndProcedure

&AtServer
Procedure RefreshRolesItems()
	
	FS = RolesData.Unload(, "RolePresentation").UnloadColumn("RolePresentation");
	
	Index = FS.Count()-1;
	While Index > 0 Do
		FS.Insert(Index, "  ");
		Index = Index - 1;
	EndDo;
	
	Items.RolesCloud.Title			= New FormattedString(FS);
	Items.RolesAndIndent.Visible	= FS.Count() > 0;
	
EndProcedure

&AtServer
Procedure WriteRolesData(CurrentObject)
	
	CurrentObject.Roles.Load(RolesData.Unload(,"Role"));
	
EndProcedure

&AtServer
Procedure AttachRoleAtServer(Role)
	
	If RolesData.FindRows(New Structure("Role", Role)).Count() > 0 Then
		Return;
	EndIf;
	
	RoleData = Common.ObjectAttributesValues(Role, "Description, DeletionMark");
	
	RolesRow = RolesData.Add();
	URLFS = "Role_" + RolesRow.GetID();
	
	RolesRow.Role				= Role;
	RolesRow.DeletionMark		= RoleData.DeletionMark;
	RolesRow.RolePresentation	= FormattedStringRolePresentation(RoleData.Description, RoleData.DeletionMark, URLFS);
	RolesRow.RoleLength			= StrLen(RoleData.Description);
	
	RefreshRolesItems();
	
	Modified = True;
	
EndProcedure

&AtServer
Procedure CreateAndAttachRoleAtServer(Val RoleTitle)
	
	Role = FindCreateRole(RoleTitle);
	AttachRoleAtServer(Role);
	
EndProcedure

&AtServerNoContext
Function FindCreateRole(Val RoleTitle)
	
	Role = Catalogs.ContactPersonsRoles.FindByDescription(RoleTitle, True);
	
	If Role.IsEmpty() Then
		
		RoleObject = Catalogs.ContactPersonsRoles.CreateItem();
		RoleObject.Description = RoleTitle;
		RoleObject.Write();
		Role = RoleObject.Ref;
		
	EndIf;
	
	Return Role;
	
EndFunction

&AtClientAtServerNoContext
Function FormattedStringRolePresentation(RoleDescription, DeletionMark, URLFS)
	
	#If Client Then
	Color		= CommonClientCached.StyleColor("MinorInscriptionText");
	BaseFont	= CommonClientCached.StyleFont("NormalTextFont");
	#Else
	Color		= StyleColors.MinorInscriptionText;
	BaseFont	= StyleFonts.NormalTextFont;
	#EndIf
	
	Font	= New Font(BaseFont,,,True,,?(DeletionMark, True, Undefined));
	
	ComponentsFS = New Array;
	ComponentsFS.Add(New FormattedString(RoleDescription + Chars.NBSp, Font, Color));
	ComponentsFS.Add(New FormattedString(PictureLib.Clear, , , , URLFS));
	
	Return New FormattedString(ComponentsFS);
	
EndFunction

&AtClient
Procedure RoleInputFieldChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	If Not ValueIsFilled(SelectedValue) Then
		Return;
	EndIf;
	
	StandardProcessing = False;
	
	If TypeOf(SelectedValue) = Type("CatalogRef.ContactPersonsRoles") Then
		AttachRoleAtServer(SelectedValue);
	EndIf;
	Item.UpdateEditText();
	
EndProcedure

&AtClient
Procedure RoleInputFieldTextEditEnd(Item, Text, ChoiceData, DataGetParameters, StandardProcessing)
	
	If Not IsBlankString(Text) Then
		StandardProcessing = False;
		CreateAndAttachRoleAtServer(Text);
		CurrentItem = Items.RoleInputField;
	EndIf;
	
EndProcedure

#EndRegion

#Region LibrariesHandlers

// StandardSubsystems.ContactInformation

&AtClient
Procedure Attachable_ContactInformationOnChange(Item)
	ContactsManagerClient.OnChange(ThisObject, Item);
EndProcedure

&AtClient
Procedure Attachable_ContactInformationStartChoice(Item, ChoiceData, StandardProcessing)
	ContactsManagerClient.StartChoice(ThisObject, Item,, StandardProcessing);
EndProcedure

&AtClient
Procedure Attachable_ContactInformationOnClick(Item, StandardProcessing)
	ContactsManagerClient.StartChoice(ThisObject, Item,, StandardProcessing);
EndProcedure

&AtClient
Procedure Attachable_ContactInformationClearing(Item, StandardProcessing)
	ContactsManagerClient.Clearing(ThisObject, Item.Name);
EndProcedure

&AtClient
Procedure Attachable_ContactInformationExecuteCommand(Command)
	ContactsManagerClient.ExecuteCommand(ThisObject, Command.Name);
EndProcedure

&AtClient
Procedure Attachable_ContactInformationAutoComplete(Item, Text, ChoiceData, DataGetParameters, Wait, StandardProcessing)
	ContactsManagerClient.AutoComplete(Text, ChoiceData, StandardProcessing);
EndProcedure

&AtClient
Procedure Attachable_ContactInformationChoiceProcessing(Item, SelectedValue, StandardProcessing)
	ContactsManagerClient.ChoiceProcessing(ThisObject, SelectedValue, Item.Name, StandardProcessing);
EndProcedure

&AtServer
Procedure Attachable_UpdateContactInformation(Result) Export
	ContactsManager.UpdateContactInformation(ThisObject, Object, Result);
EndProcedure

// End StandardSubsystems.ContactInformation

// StandardSubsystems.Properties
&AtClient
Procedure Attachable_PropertiesExecuteCommand(ItemOrCommand, URL = Undefined, StandardProcessing = Undefined)
	PropertyManagerClient.ExecuteCommand(ThisObject, ItemOrCommand, StandardProcessing);
EndProcedure

&AtClient
Procedure UpdateAdditionalAttributesDependencies()
	PropertyManagerClient.UpdateAdditionalAttributesDependencies(ThisObject);
EndProcedure

&AtClient
Procedure Attachable_OnChangeAdditionalAttribute(Item)
	PropertyManagerClient.UpdateAdditionalAttributesDependencies(ThisObject);
EndProcedure

&AtServer
Procedure UpdateAdditionalAttributeItems()
	PropertyManager.UpdateAdditionalAttributesItems(ThisObject);
EndProcedure

// End StandardSubsystems.Properties

#EndRegion

#EndRegion