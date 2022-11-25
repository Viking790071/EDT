
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not ValueIsFilled(Object.ClosureDate) Then
		CurrentItem = Items.ContactInformation0_Presentation;
	EndIf;
	
	If Parameters.Key.IsEmpty() Then
		SetFormAttrubitesAtServer();
	EndIf;
	FormManagement();
	
	// StandardSubsystems.Interactions
	Interactions.PrepareNotifications(ThisObject, Parameters, False);
	// End StandardSubsystems.Interactions
	
	// StandardSubsystems.Properties
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ItemForPlacementName", "GroupAdditionalAttributes");
	PropertyManager.OnCreateAtServer(ThisObject, AdditionalParameters);
	// End StandardSubsystems.Properties
	
	// StandardSubsystems.ContactInformation
	CIParameters = New Structure;
	CIParameters.Insert("ItemForPlacementName", "ContactInformation");
	CIParameters.Insert("FormItemTitleLocation", FormItemTitleLocation.Left);
	CIParameters.Insert("ContactsKindsGroup", "Catalog.Leads.Contacts");
	CIParameters.Insert("ContactLineIdentifier", 0);
	CIParameters.Insert("ObjectIndex", 0);
	For Each ContactPerson In Object.Contacts Do
		CIParameters.ItemForPlacementName = "ContactInformation" + ContactPerson.ContactLineIdentifier;
		CIParameters.ObjectIndex = ContactPerson.ContactLineIdentifier;
		CIParameters.ContactLineIdentifier = ContactPerson.ContactLineIdentifier;
		ContactsManager.OnCreateAtServer(ThisObject, Object, CIParameters);
	EndDo;
	// End StandardSubsystems.ContactInformation
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject, Object);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SetLeadDescription();
	
	DescriptionList = Items.LeadDescription.ChoiceList;
	FirstRep = Object.Contacts[0].Representation;
	
	GenerateDescriptionAutomatically = IsBlankString(Object.Description)
		OR DescriptionList.FindByValue(Object.Description) <> Undefined
		OR (Object.Contacts.Count() > 0
			AND ValueIsFilled(FirstRep)
			AND DescriptionList.FindByValue(FirstRep) = Undefined);
		
	SetActivityChoiseList(Campaign);
	
	// StandardSubsystems.Properties
	PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// StandardSubsystems.Properties
	If PropertyManagerClient.ProcessNofifications(ThisObject, EventName, Parameter) Then
		UpdateAdditionalAttributeItems();
		PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	EndIf;
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)

	SetFormAttrubitesAtServer();
	
	// StandardSubsystems.Properties
	PropertyManager.OnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
	// StandardSubsystems.ContactInformation
	For Each ContactPerson In Object.Contacts Do
		DeleteCommandsAndFormItems("ContactInformation" + ContactPerson.ContactLineIdentifier);
		ContactsManager.OnReadAtServer(ThisObject, Object, "ContactInformation" + ContactPerson.ContactLineIdentifier, ContactPerson.ContactLineIdentifier);
	EndDo;
	// End StandardSubsystems.ContactInformation

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
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
	
	WriteParameters.Insert("EmptyContactsAtForm", New Array);
	
	LinesToDelete = New Array;
	For Each ContactData In CurrentObject.Contacts Do
		If ValueIsFilled(ContactData.Representation) Then
			Continue;
		EndIf;
		WriteParameters.EmptyContactsAtForm.Add(New Structure("ContactLineIdentifier", ContactData.ContactLineIdentifier));
		LinesToDelete.Add(ContactData);
	EndDo;
	
	For Each DelLine In LinesToDelete Do
		CurrentObject.Contacts.Delete(DelLine);
	EndDo;
	
	If CurrentObject.IsNew() Then
		WriteParameters.Insert("NewLead", True);
	EndIf;
	
	WriteTagsData(CurrentObject);
	
	If ActivityHasChanged Then
		CurrentObject.AdditionalProperties.Insert("ActivityHasChanged", ActivityHasChanged);
		NewState = New Structure();
		NewState.Insert("Campaign", Campaign);
		NewState.Insert("SalesRep", SalesRep);
		NewState.Insert("Activity", Activity);
		CurrentObject.AdditionalProperties.Insert("NewState", NewState);
		ActivityHasChanged = False;
	EndIf;
	
	// StandardSubsystems.ContactInformation
	ContactsManager.BeforeWriteAtServer(ThisObject, CurrentObject, Cancel);
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
	InteractionsClient.ContactAfterWrite(ThisObject, Object, WriteParameters, "Leads");
	// End StandardSubsystems.Interactions
	
	If WriteParameters.Property("NewLead") Then
		NotifyWritingNew(Object.Ref);
	EndIf;
	
	Notify("Write_Lead", Object.Ref);
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	If WriteParameters.Property("EmptyContactsAtForm") Then
		For Each ContactData In WriteParameters.EmptyContactsAtForm Do
			FillPropertyValues(Object.Contacts.Add(), ContactData);
		EndDo;
	EndIf;
	
	// StandardSubsystems.ContactInformation
	ContactsManager.AfterWriteAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.ContactInformation

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	For Each ContactData In Object.Contacts Do
		
		If ValueIsFilled(ContactData.Representation) Then
			Continue;
		EndIf;
		
		ContactInformationIsFilled = False;
		
		ContactInformationOfContact = ThisObject.ContactInformationAdditionalAttributeDetails.FindRows(
			New Structure("ItemForPlacementName", "ContactInformation" + ContactData.ContactLineIdentifier));
		For Each ContactInformation In ContactInformationOfContact Do
			If ValueIsFilled(ContactInformation.Presentation) Then
				ContactInformationIsFilled = True;
				Break;
			EndIf;
		EndDo;
		
		If Not ContactInformationIsFilled Then
			Continue;
		EndIf;
		
		AttributeName = StringFunctionsClientServer.SubstituteParametersToString("ContactInformation%1_Presentation", Object.Contacts.IndexOf(ContactData));
		CommonClientServer.MessageToUser(NStr("en = 'Contact name is empty.'; ru = 'Не заполнено наименование контакта';pl = 'Nazwa kontaktu jest pusta.';es_ES = 'El nombre de contacto está vacío.';es_CO = 'El nombre de contacto está vacío.';tr = 'İlgili kişi adı boş.';it = 'Il nome contatto è vuoto.';de = 'Der Kontaktname ist leer.'"), , AttributeName, , Cancel);
		
	EndDo;
	
	If ValueIsFilled(Campaign) And Not ValueIsFilled(Activity) Then
		CommonClientServer.MessageToUser(NStr("en = 'Activity is empty.'; ru = 'Не заполнен вид деятельности';pl = 'Rodzaj działalności jest pusty.';es_ES = 'Actividad está vacía.';es_CO = 'Actividad está vacía.';tr = 'Faaliyet boş.';it = 'L''attività è vuota.';de = 'Aktivität ist leer.'"), , "Activity", , Cancel);
	EndIf;
	
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
Procedure CampaignOnChange(Item)
	
	Activity = GetActivityAtServer(Campaign);
	SetActivityChoiseList(Campaign);
	ActivityHasChanged = True;
	
EndProcedure

&AtClient
Procedure ActivityOnChange(Item)
	
	ActivityHasChanged = True;
	
EndProcedure

&AtClient
Procedure Attachable_Contacts0RepresentationOnChange(Item)
	
	If Item.Name <> "Contacts0_Representation" Then
		Return;
	EndIf;

	SetLeadDescription();
	
	If GenerateDescriptionAutomatically AND Items.LeadDescription.ChoiceList.Count() > 0  Then
		Object.Description = Items.LeadDescription.ChoiceList[0].Value;
	EndIf;
	
EndProcedure

&AtClient
Procedure TagsCloudURLProcessing(Item, FormattedStringURL, StandardProcessing)
	
	StandardProcessing = False;
	
	TagID = Mid(FormattedStringURL, StrLen("Tag_")+1);
	TagsRow = TagsData.FindByID(TagID);
	TagsData.Delete(TagsRow);
	
	RefreshTagsItems();
	
	Modified = True;
	
EndProcedure

&AtClient
Procedure SalesRepOnChange(Item)
	
	ActivityHasChanged = True;
	
EndProcedure

&AtClient
Procedure Attachable_Open(Item, StandardProcessing)
	NativeLanguagesSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure ConvertIntoCustomer(Command)
	
	DontAskUser = DriveReUse.GetValueByDefaultUser(UsersClientServer.CurrentUser(), "ConvertLeadWithoutMessage");
	
	If Not DontAskUser Then
		
		QuestionParameters = StandardSubsystemsClient.QuestionToUserParameters();
		QuestionParameters.DoNotAskAgain = True;
		QuestionParameters.Title = "Lead finalizing";
		
		Notify = New NotifyDescription("ConvertIntoCustomerClickEnd", ThisObject);
		QuestionText = NStr("en = 'Are you sure you want to convert the lead to the customer? This is an irreversible action.'; ru = 'Перенести лид в справочник покупателей? Это действие нельзя изменить.';pl = 'Czy na pewno chcesz przekształcić lead w nabywcę? Jest to działanie nieodwracalne.';es_ES = '¿Está seguro de que quiere convertir lead en cliente? Esta acción es irreversible.';es_CO = '¿Está seguro de que quiere convertir lead en cliente? Esta acción es irreversible.';tr = 'Müşteri adayını müşteriye dönüştürmek istediğinize emin misiniz? Bu işlem geri alınamaz.';it = 'Convertire il Potenziale Cliente in un cliente? Questa è una azione non reversibile.';de = 'Sind Sie sicher, dass Sie den Lead auf den Kunden umstellen wollen? Dies ist eine unumkehrbare Aktion.'");
		StandardSubsystemsClient.ShowQuestionToUser(Notify, QuestionText, QuestionDialogMode.OKCancel, QuestionParameters);
		
	Else
		
		Response = New Structure;
		Response.Insert("Value", DialogReturnCode.OK);
		Response.Insert("DoNotAskAgain", False);
		ConvertIntoCustomerClickEnd(Response, Undefined);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ConvertIntoRejectedLead(Command)
	
	If ValueIsFilled(Object.Ref) Then
		ConverIntoRejectedLeadAtServer();
		Return;
	EndIf;
	
	Notify = New NotifyDescription("ConvertIntoRejectedLeadClickEnd", ThisObject);
	QuestionText = NStr("en = 'You can convert lead into rejected only after saving. Do you want to save?'; ru = 'Лид можно отклонить только после записи. Сохранить лид?';pl = 'Możesz przekształcić status leadu na odrzucony tylko po zapisaniu. Czy chcesz zapisać?';es_ES = 'No puede convertir lead en rechazado solo al guardar. ¿Quiere guardar?';es_CO = 'No puede convertir lead en rechazado solo al guardar. ¿Quiere guardar?';tr = 'Müşteri adayı sadece kaydedildikten sonra Reddedildi olarak dönüştürülebilir. Kaydetmek istiyor musunuz?';it = 'È possibile convertire un Potenziale Cliente in rifiutato solo dopo aver salvato. Salvare?';de = 'Erst nach dem Speichern können Sie den Lead in abgelehnt umwandeln. Möchten Sie speichern?'");
	ShowQueryBox(Notify, QuestionText, QuestionDialogMode.OKCancel);
	
EndProcedure

&AtClient
Procedure BackToWork(Command)
	
	BackToWorkAtServer();
	
EndProcedure

&AtClient
Procedure AddNewContact(Command)
	
	AddNewContactAtServer();
	
EndProcedure

&AtClient
Procedure AddAdditionalAttributes(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("CurrentPropertiesSet", PredefinedValue("Catalog.AdditionalAttributesAndInfoSets.Catalog_Leads"));
	FormParameters.Insert("IsAdditionalInfo", False);
	OpenForm("ChartOfCharacteristicTypes.AdditionalAttributesAndInfo.ObjectForm", FormParameters,,,,,, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

#EndRegion

#Region Private

#Region LeadDescription

&AtClient
Procedure SetLeadDescription()
	
	ChoiceList = Items.LeadDescription.ChoiceList;
	ChoiceList.Clear();
	
	If Object.Contacts.Count() = 0 Then
		Return;
	EndIf;
	
	For Each Contact In Object.Contacts Do
		
		If Not IsBlankString(Contact.Representation) 
			AND ChoiceList.FindByValue(Contact.Representation) = Undefined Then
			ChoiceList.Add(Contact.Representation);
		EndIf;
		
		If Object.ContactInformation.Count() = 0 Then
			Continue;
		EndIf;
		
		For Each ObjectContactInformationLine In Object.ContactInformation Do
			If (ObjectContactInformationLine.ContactLineIdentifier <> Contact.ContactLineIdentifier
				OR IsBlankString(ObjectContactInformationLine.Presentation))
				OR ChoiceList.FindByValue(ObjectContactInformationLine.Presentation) <> Undefined Then
				Continue;
			EndIf;
			ChoiceList.Add(ObjectContactInformationLine.Presentation);
		EndDo;
	
	EndDo;
	
	Items.LeadDescription.ChoiceListButton = ChoiceList.Count() > 0;
	
	AdditionalParameters = New Structure;
	NotifyDescription = New NotifyDescription("AfterSelectionLeadDescription", ThisObject, AdditionalParameters);
	
EndProcedure

&AtClient
Procedure AfterSelectionLeadDescription(SelectedItem, Parameters) Export
	
	Object.Description = SelectedItem.Value;
	
EndProcedure

#EndRegion

#Region Tags

&AtServer
Procedure ReadTagsData()
	
	TagsData.Clear();
	
	If Not ValueIsFilled(Object.Ref) Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	LeadsTags.Tag AS Tag,
		|	LeadsTags.Tag.DeletionMark AS DeletionMark,
		|	LeadsTags.Tag.Description AS Description
		|FROM
		|	Catalog.Leads.Tags AS LeadsTags
		|WHERE
		|	LeadsTags.Ref = &Ref";
	
	Query.SetParameter("Ref", Object.Ref);
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		NewTagData	= TagsData.Add();
		URLFS	= "Tag_" + NewTagData.GetID();
		
		NewTagData.Tag				= Selection.Tag;
		NewTagData.DeletionMark		= Selection.DeletionMark;
		NewTagData.TagPresentation	= FormattedStringTagPresentation(Selection.Description, Selection.DeletionMark, URLFS);
		NewTagData.TagLength		= StrLen(Selection.Description);
		
	EndDo;
	
EndProcedure

&AtServer
Procedure RefreshTagsItems()
	
	FS = TagsData.Unload(, "TagPresentation").UnloadColumn("TagPresentation");
	
	Index = FS.Count()-1;
	While Index > 0 Do
		FS.Insert(Index, "  ");
		Index = Index - 1;
	EndDo;
	
	Items.TagsCloud.Title	= New FormattedString(FS);
	Items.TagsCloud.Visible	= FS.Count() > 0;
	
EndProcedure

&AtServer
Procedure WriteTagsData(CurrentObject)
	
	CurrentObject.Tags.Load(TagsData.Unload(,"Tag"));
	
EndProcedure

&AtServer
Procedure AttachTagAtServer(Tag)
	
	If TagsData.FindRows(New Structure("Tag", Tag)).Count() > 0 Then
		Return;
	EndIf;
	
	TagData = Common.ObjectAttributesValues(Tag, "Description, DeletionMark");
	
	TagsRow = TagsData.Add();
	URLFS = "Tag_" + TagsRow.GetID();
	
	TagsRow.Tag = Tag;
	TagsRow.DeletionMark = TagData.DeletionMark;
	TagsRow.TagPresentation = FormattedStringTagPresentation(TagData.Description, TagData.DeletionMark, URLFS);
	TagsRow.TagLength = StrLen(TagData.Description);
	
	RefreshTagsItems();
	
	Modified = True;
	
EndProcedure

&AtServer
Procedure CreateAndAttachTagAtServer(Val TagTitle)
	
	Tag = FindCreateTag(TagTitle);
	AttachTagAtServer(Tag);
	
EndProcedure

&AtServerNoContext
Function FindCreateTag(Val TagTitle)
	
	Tag = Catalogs.Tags.FindByDescription(TagTitle, True);
	
	If Tag.IsEmpty() Then
		
		TagObject = Catalogs.Tags.CreateItem();
		TagObject.Description = TagTitle;
		TagObject.Write();
		Tag = TagObject.Ref;
		
	EndIf;
	
	Return Tag;
	
EndFunction

&AtClientAtServerNoContext
Function FormattedStringTagPresentation(TagDescription, DeletionMark, URLFS)
	
	#If Client Then
	Color		= CommonClientCached.StyleColor("MinorInscriptionText");
	BaseFont	= CommonClientCached.StyleFont("NormalTextFont");
	#Else
	Color		= StyleColors.MinorInscriptionText;
	BaseFont	= StyleFonts.NormalTextFont;
	#EndIf
	
	Font	= New Font(BaseFont,,,True,,?(DeletionMark, True, Undefined));
	
	ComponentsFS = New Array;
	ComponentsFS.Add(New FormattedString(TagDescription + Chars.NBSp, Font, Color));
	ComponentsFS.Add(New FormattedString(PictureLib.Clear, , , , URLFS));
	
	Return New FormattedString(ComponentsFS);
	
EndFunction

&AtClient
Procedure TagInputFieldChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	If Not ValueIsFilled(SelectedValue) Then
		Return;
	EndIf;
	
	StandardProcessing = False;
	
	If TypeOf(SelectedValue) = Type("CatalogRef.Tags") Then
		AttachTagAtServer(SelectedValue);
	EndIf;
	Item.UpdateEditText();
	
EndProcedure

&AtClient
Procedure TagInputFieldTextEditEnd(Item, Text, ChoiceData, DataGetParameters, StandardProcessing)
	
	If Not IsBlankString(Text) Then
		StandardProcessing = False;
		CreateAndAttachTagAtServer(Text);
		CurrentItem = Items.TagInputField;
	EndIf;
	
EndProcedure

#EndRegion

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

#Region ServiceProceduresAndFunctions

&AtServer
Procedure DeleteCommandsAndFormItems(ItemForPlacementName)
	
	FormAttributeList = ThisObject.GetAttributes();
	
	FirstRun = True;
	For Each Attribute In FormAttributeList Do
		If Attribute.Name = "ContactInformationParameters" Then
			FirstRun = False;
			Break;
		EndIf;
	EndDo;
	
	If FirstRun Then
		Return;
	EndIf;
	
	If ThisObject.ContactInformationParameters.Property(ItemForPlacementName) Then
		
		FormContactInformationParameters = ThisObject.ContactInformationParameters[ItemForPlacementName];
		AddedItems = FormContactInformationParameters.AddedItems;
		AddedItems.SortByPresentation();
		
		For Each ItemToRemove In AddedItems Do
			
			If ItemToRemove.Check Then
				If ThisObject.Commands.Find(ItemToRemove.Value) <> Undefined Then
					ThisObject.Commands.Delete(ThisObject.Commands[ItemToRemove.Value]);
				EndIf;
			Else
				If ThisObject.Items.Find(ItemToRemove.Value) <> Undefined Then
					ThisObject.Items.Delete(ThisObject.Items[ItemToRemove.Value]);
				EndIf;
			EndIf;
			
		EndDo;
		
		FormContactInformationParameters.AddedItems.Clear();
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function GetActivityAtServer(Campaign)
	Return Catalogs.Campaigns.GetFirstActivity(Campaign);
EndFunction

&AtServer
Procedure SetFormAttrubitesAtServer()
	
	ReadContactsData();
	
	ReadTagsData();
	RefreshTagsItems();
	
	ReplaceAddNewContactButton();
	
	DescriptionList = Items.LeadDescription.ChoiceList;
	FirstRep = Object.Contacts[0].Representation;
	
	GenerateDescriptionAutomatically = IsBlankString(Object.Description)
		OR DescriptionList.FindByValue(Object.Description) <> Undefined
		OR Object.Contacts.Count() > 0
			AND (ValueIsFilled(FirstRep)
			AND DescriptionList.FindByValue(FirstRep) = Undefined);
	
EndProcedure

&AtServer
Procedure FormManagement()
	
	StateStructure = WorkWithLeads.LeadState(Object.Ref);
	FillPropertyValues(ThisObject, StateStructure);
	
	CanBeEdited = AccessRight("Edit", Metadata.Catalogs.Leads);
	
	Rejected = ValueIsFilled(Object.RejectionReason)
		OR Object.ClosureResult = Enums.LeadClosureResult.Rejected;
	ConvertedIntoCustomer = ValueIsFilled(Object.ClosureDate)
		AND Object.ClosureResult = Enums.LeadClosureResult.ConvertedIntoCustomer;
	
	If Rejected OR ConvertedIntoCustomer Then
		Items.TextField.Visible = True;
		Items.GroupClosure.Title = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Finalized on ""%1""'; ru = 'Переведен в ""%1""';pl = 'Sfinalizowane w dniu ""%1""';es_ES = 'Finalizado el ""%1""';es_CO = 'Finalizado el ""%1""';tr = '""%1"" tarihinde sonuçlandı';it = 'Finalizzato il ""%1""';de = 'Finalisiert am ""%1""'"),
			Format(Object.ClosureDate,"DLF=D"));
	Else
		Items.TextField.Visible = False;
		Items.GroupClosure.Title = NStr("en = 'Finalize'; ru = 'Завершить работу';pl = 'Finalizacja';es_ES = 'Finalizar';es_CO = 'Finalizar';tr = 'Sonuçlandır';it = 'Finalizzare';de = 'Finalisieren'");
	EndIf;
	
	If ConvertedIntoCustomer Then
		
		Text = New FormattedString(NStr("en = 'Lead is converted into customer'; ru = 'Лид был переведен в список покупателей';pl = 'Lead został przekształcony w nabywcę';es_ES = 'Lead está convertido en cliente';es_CO = 'Lead está convertido en cliente';tr = 'Müşteri adayı müşteriye dönüştürüldü';it = 'Il Potenziale Cliente è convertito in cliente';de = 'Lead wird in Kunde umgewandelt'"));
		If ValueIsFilled(Object.Counterparty) Then
			StringCounterparty = New FormattedString(String(Object.Counterparty),,,,GetURL(Object.Counterparty));
			TextField = New FormattedString(Text, " ", StringCounterparty);
		Else
			TextField = Text;
		EndIf;
		
		Items.TextField.AutoMaxWidth = True;
		
	EndIf;
	
	If Rejected Then
		TextField= New FormattedString(NStr("en = 'Rejected lead'; ru = 'Лид отклонен';pl = 'Odrzucony lead';es_ES = 'Lead rechazado';es_CO = 'Lead rechazado';tr = 'Reddedilmiş müşteri adayı';it = 'Potenziale Cliente rifiutato';de = 'Abgelehnter Lead'"));
	EndIf;
	
	ThisObject.ReadOnly = ConvertedIntoCustomer OR Not CanBeEdited;
	
	Items.TagsCloud.Enabled = Not Rejected;
	Items.ButtonsGroup.Visible = Not (Rejected OR ConvertedIntoCustomer);
	Items.BackToWork.Visible = Rejected;
	Items.RejectionReason.Visible = Rejected;
	Items.ClosureNote.Visible = Rejected;
	Items.LeftColumn.Enabled = Not Rejected;
	Items.AdditionalInformation.Enabled = Not Rejected;
	
EndProcedure

&AtServer
Function ConvertIntoCustomerAtServer()
	
	If Not CheckFilling() Then
		Return Undefined;
	EndIf;
	
	ObjectLead = FormAttributeToValue("Object");
	WriteTagsData(ObjectLead);
	
	ContactsManager.BeforeWriteAtServer(ThisObject, ObjectLead);
	
	Return Catalogs.Leads.GetCreateCounterparty(ObjectLead);
	
EndFunction

&AtServer
Procedure ConverIntoRejectedLeadAtServer()
	
	If Not CheckFilling() Then
		Return;
	EndIf;
	
	Write();
	
	Object.ClosureDate = CurrentSessionDate();
	Object.ClosureResult = Enums.LeadClosureResult.Rejected;
	
	Modified = True;
	FormManagement();
	
EndProcedure

&AtServer
Procedure BackToWorkAtServer()
	
	Object.ClosureResult = Undefined;
	Object.RejectionReason = Undefined;
	Object.ClosureDate = Date('00010101');
	Object.ClosureNote = Undefined;
	FormManagement();
	
EndProcedure

&AtClient
Procedure ConvertIntoRejectedLeadClickEnd(Response, Parameter) Export
	
	If Response = DialogReturnCode.Cancel Then
		Return;
	EndIf;
	
	ConverIntoRejectedLeadAtServer();
	
EndProcedure

&AtClient
Procedure SetActivityChoiseList(NewCampaign)

	Items.Activity.ChoiceList.Clear();
	
	Items.Activity.Enabled = ValueIsFilled(NewCampaign);
	
	ActivitiesChoiceList = GetAvailableActivities(NewCampaign);
	
	For Each ActivityValue In ActivitiesChoiceList Do
		Items.Activity.ChoiceList.Add(ActivityValue.Value);
	EndDo;
	
EndProcedure

&AtServerNoContext
Function GetAvailableActivities(Campaign)
	
	Return WorkWithLeads.GetAvailableActivities(Campaign);
	
EndFunction

&AtClient
Procedure ConvertIntoCustomerClickEnd(Response, Parameter) Export
	
	If Response.Value = DialogReturnCode.Cancel Then
		Return;
	EndIf;
	
	If Response.DoNotAskAgain Then
		SetUserSettingAtServer(True, "ConvertLeadWithoutMessage");
	EndIf;
	
	NewCounterparty = ConvertIntoCustomerAtServer();
	
	If Not ValueIsFilled(NewCounterparty) Then
		Return;
	EndIf;
	
	Notify("Write_Lead", Object.Ref);
	
	FormParameters = New Structure("Key", NewCounterparty);
	OpenForm("Catalog.Counterparties.ObjectForm", FormParameters);
	
	Modified = False;
	Close();
	
EndProcedure

&AtServerNoContext
Procedure SetUserSettingAtServer(SettingValue, SettingName)
	DriveServer.SetUserSetting(SettingValue, SettingName, Users.CurrentUser());
EndProcedure

#EndRegion

#Region Contacts

&AtServer
Procedure CreateContactGroup(ID)
	
	ContactGroup = Items.Add("ContactInformation" + ID, Type("FormGroup"), Items.ContactInformation);
	ContactGroup.Type = FormGroupType.UsualGroup;
	ContactGroup.ShowTitle = False;
	ContactGroup.Representation = UsualGroupRepresentation.None;
	ContactGroup.Group = ChildFormItemsGroup.Vertical;
	
	LineIdentifier = LineIdentifiers.FindRows(New Structure("Value", ID));
	
	ContactField = Items.Add("ContactInformation" + ID + "Presentation", Type("FormField"), ContactGroup);
	ContactField.Type = FormFieldType.InputField;
	If LineIdentifier.Count() <> 0 Then
		ContactField.DataPath = StrTemplate("Object.Contacts[%1].Representation", LineIdentifiers.IndexOf(LineIdentifier[0]));
	EndIf;
	FillPropertyValues(ContactField, Items.ContactInformation0_Presentation, "TitleLocation,InputHint,HorizontalStretch,AutoMaxWidth,MaxWidth");
	
EndProcedure

&AtServer
Procedure UpdateContactsIDs()
	
	IDs = Object.Contacts.Unload(, "ContactLineIdentifier");
	IDs.GroupBy("ContactLineIdentifier");
	IDs.Sort("ContactLineIdentifier Asc");
	IDs = IDs.UnloadColumn("ContactLineIdentifier");
	
	LineIdentifiers.Clear();
	
	For Each ID In IDs Do
		NewLine = LineIdentifiers.Add();
		NewLine.Value = ID;
	EndDo;
	
EndProcedure

&AtServer
Function LastRowID()
	
	If LineIdentifiers.Count() = 0 Then
		Return Undefined;
	EndIf;
	
	Return LineIdentifiers[LineIdentifiers.Count() - 1].Value;
	
EndFunction

&AtServer
Function NewRowID()
	
	NewID = 0;
	If LineIdentifiers.Count() <> 0 Then
		NewID = LastRowID() + 1;
	EndIf;
	
	NewRow = LineIdentifiers.Add();
	NewRow.Value = NewID;
	
	Return NewID;
	
EndFunction

&AtServer
Procedure ReadContactsData()
	
	If Object.Contacts.Count() = 0 Then
		Object.Contacts.Add();
	EndIf;
	
	UpdateContactsIDs();
	
	Items.Move(Items.AddNewContact, Items.Contacts);
	
	DeletingItems = New Array;
	
	For Each LineID In LineIdentifiers Do
		If LineID.Value = 0 Then
			Continue;
		EndIf;
		DeletingItem = Items.Find("ContactInformation" + LineID.Value);
		If DeletingItem <> Undefined Then
			DeletingItems.Add(DeletingItem);
		EndIf;
	EndDo;
	
	For Each DeletingItem In DeletingItems Do
		Items.Delete(DeletingItem);
	EndDo;
	
	For Each LineID In LineIdentifiers Do
		If LineID.Value = 0 Then
			Continue;
		EndIf;
		CreateContactGroup(LineID.Value);
	EndDo;
	
EndProcedure

&AtServer
Procedure ReplaceAddNewContactButton(ContactID = Undefined)
	
	If ContactID = Undefined Then
		ContactID = LastRowID();
	EndIf;
	
	LastGroupWithComands = Items.Find("GroupAddFieldContactInformation_" + ContactID);
	
	If LastGroupWithComands = Undefined Then
		Return;
	EndIf;
	
	Location = Undefined;
	If LastGroupWithComands.ChildItems.Count() <> 0 Then
		Location = LastGroupWithComands.ChildItems[0];
	EndIf;
	
	Items.Move(Items.AddNewContact, LastGroupWithComands, Location);
	
EndProcedure

&AtServer
Procedure AddNewContactAtServer()
	
	NewID = NewRowID();
	
	NewRow = Object.Contacts.Add();
	NewRow.ContactLineIdentifier = NewID;
	
	CreateContactGroup(NewID);
	
	RefreshContactInformationOfItem(NewID);
	
	FieldContactRepresentation = Items["ContactInformation" + NewID + "Presentation"];
	FieldContactRepresentation.SetAction("OnChange", "Attachable_Contacts0RepresentationOnChange");
	
	ReplaceAddNewContactButton(NewID);
	
	CurrentItem = FieldContactRepresentation;
	
EndProcedure

&AtServer
Procedure RefreshContactInformationOfItem(NewID)
	
	// StandardSubsystems.ContactInformation
	CIParameters = New Structure;
	CIParameters.Insert("ItemForPlacementName", "ContactInformation" + NewID);
	CIParameters.Insert("FormItemTitleLocation", FormItemTitleLocation.Left);
	CIParameters.Insert("ContactsKindsGroup", "Catalog.Leads.Contacts");
	CIParameters.Insert("ContactLineIdentifier",NewID);
	CIParameters.Insert("ObjectIndex", NewID);
	ContactsManager.OnCreateAtServer(ThisObject, Object, CIParameters);
	// End StandardSubsystems.ContactInformation
	
EndProcedure

#EndRegion

#Region LibrariesHandlers

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

#EndRegion

#EndRegion