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
	
	FillPropertyValues(ThisObject, Parameters, "MailingRecipientType, RecipientEmailAddressKind");
	Title = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("ru = 'Получатели рассылки (%1)'; en = 'Bulk email recipients (%1)'; pl = 'Odbiorcy masowej wysyłki e-mail (%1)';es_ES = 'Destinatarios del newsletter (%1)';es_CO = 'Destinatarios del newsletter (%1)';tr = 'Toplu e-posta alıcıları (%1)';it = 'Destinatari email massiva (%1)';de = 'Bulk-Mail-Empfänger (%1)'"),
		Parameters.BulkEmailDescription);
	
	For Each TableRow In Parameters.Recipients Do
		NewRow = Recipients.Add();
		NewRow.Recipient = TableRow.Recipient;
		NewRow.Excluded = TableRow.Excluded;
	EndDo;
	
	Items.RecipientsRecipient.TypeRestriction = MailingRecipientType;
	
	FillRecipientsTypeInfo(Cancel);
	FillMailAddresses();
	
	If Not Common.SubsystemExists("StandardSubsystems.ImportDataFromFile") Then
		Items.PasteFromClipboard.Visible = False;
	EndIf;
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure RecipientsMailAddressKindOnChange(Item)
	FillMailAddresses();
EndProcedure

#EndRegion

#Region RecipientsFormTableItemsEventHandlers

&AtClient
Procedure PickRecipients(Command)
	OpenAddRecipientsForm(True);
EndProcedure

&AtClient
Procedure OpenAddRecipientsForm(IsPick)
	SelectedUsers = New Array;
	For Each Row In Recipients Do
		SelectedUsers.Add(Row.Recipient);
	EndDo;
	
	ChoiceFormParameters = New Structure;
	
	// Standard selection form attributes (see Managed form extension for dynamic list).
	ChoiceFormParameters.Insert("ChoiceFoldersAndItems", FoldersAndItemsUse.FoldersAndItems);
	ChoiceFormParameters.Insert("CloseOnChoice", ?(IsPick, False, True));
	ChoiceFormParameters.Insert("CloseOnOwnerClose", True);
	ChoiceFormParameters.Insert("MultipleChoice", IsPick);
	ChoiceFormParameters.Insert("ChoiceMode", True);
	
	// Estimated attributes
	ChoiceFormParameters.Insert("WindowOpeningMode", FormWindowOpeningMode.LockOwnerWindow);
	ChoiceFormParameters.Insert("SelectFolders", True);
	ChoiceFormParameters.Insert("UsersGroupsSelection", True);
	
	// Opening parameters of the extended pickup form (attributes description see in the list form of 
	// the Users catalog).
	If IsPick Then
		ChoiceFormParameters.Insert("AdvancedPick", True);
		ChoiceFormParameters.Insert("PickFormHeader", NStr("ru = 'Подбор получателей рассылки'; en = 'Bulk email recipient selection'; pl = 'Wybór odbiorców masowej wysyłki e-mail';es_ES = 'Seleccionar el destinatario del newsletter';es_CO = 'Seleccionar el destinatario del newsletter';tr = 'Toplu e-posta alıcı seçimi';it = 'Email multipla selezione destinatario';de = 'Auswahl von Bulk-Mail-Empfängers'"));
		ChoiceFormParameters.Insert("SelectedUsers", SelectedUsers);
	EndIf;
	
	OpenForm(ChoiceFormPath, ChoiceFormParameters, Items.Recipients);
EndProcedure

&AtClient
Procedure RecipientsChoiceProcessing(Item, ValueSelected, StandardProcessing)
	StandardProcessing = False;
	AddDragRecipient(ValueSelected);
EndProcedure

&AtClient
Procedure BeforeAddRowRecipients(Item, Cancel, Clone, Parent, Folder, Parameter)
	Cancel = True;
	OpenAddRecipientsForm(False);
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure OK(Command)
	Result = New Structure;
	Result.Insert("Recipients", Recipients);
	Result.Insert("RecipientEmailAddressKind", RecipientEmailAddressKind);
	Close(Result);
EndProcedure

&AtClient
Procedure PasteFromClipboard(Command)
	SearchParameters = New Structure;
	SearchParameters.Insert("TypeDescription", MailingRecipientType);
	SearchParameters.Insert("ChoiceParameters", Undefined);
	SearchParameters.Insert("FieldPresentation", "Recipients");
	SearchParameters.Insert("Scenario", "RefsSearch");
	
	ExecutionParameters = New Structure;
	Handler = New NotifyDescription("PasteFromClipboardCompletion", ThisObject, ExecutionParameters);
	
	ModuleImportDataFromFileClient = CommonClient.CommonModule("ImportDataFromFileClient");
	ModuleImportDataFromFileClient.ShowRefFillingForm(SearchParameters, Handler);
EndProcedure

&AtClient
Procedure SelectAll(Command)
	
	For each Recipient In Recipients Do
		Recipient.Excluded = True;
	EndDo;
	
EndProcedure

&AtClient
Procedure ClearAll(Command)
	
	For each Recipient In Recipients Do
		Recipient.Excluded = False;
	EndDo;
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure AddDragRecipient(RecipientOrRecipientsSet)
	// Delete users who have been deleted in the pickup form or who are already in the list.
	If IsPickupUsersOrGroup(RecipientOrRecipientsSet) Then
		Count = Recipients.Count();
		For Number = 1 To Count Do
			ReverseIndex = Count - Number;
			RecipientRow = Recipients.Get(ReverseIndex);
			
			IndexInArray = RecipientOrRecipientsSet.Find(RecipientRow.Recipient);
			If IndexInArray = Undefined Then
				Recipients.Delete(RecipientRow); // User is deleted in the pickup form.
			Else
				RecipientOrRecipientsSet.Delete(IndexInArray); // User is already in the list.
			EndIf;
		EndDo;
	EndIf;
	
	// Add selected rows.
	NewRowArray = ChoicePickupDragToTabularSection(RecipientOrRecipientsSet);
	
	// Prepare notification text.
	If NewRowArray.Count() > 0 Then
		If NewRowArray.Count() = 1 Then
			NotificationTitle = NStr("ru = 'Получатель добавлен в рассылку'; en = 'Recipient was added to bulk email'; pl = 'Odbiorca został dodany do masowej wysyłki e-mail';es_ES = 'El destinatario fue añadido al newsletter';es_CO = 'El destinatario fue añadido al newsletter';tr = 'Toplu e-postaya alıcı eklendi';it = 'Destinatario aggiunto all''email multipla';de = 'Der Empfänger ist zu Bulk-Mail hinzugefügt'");
		Else
			NotificationTitle = NStr("ru = 'Получатели добавлены в рассылку'; en = 'Recipients added to the bulk email'; pl = 'Odbiorcy dodani do masowej wysyłki e-mail';es_ES = 'Destinatarios añadidos al newsletter';es_CO = 'Destinatarios añadidos al newsletter';tr = 'Toplu e-postaya eklenen alıcılar';it = 'Destinatari aggiunti all''email multipla';de = 'Zu Massen-E-Mail hinzugefügte Empfänger'");
		EndIf;
		
		NotificationText = "";
		For Each RecipientRow In NewRowArray Do
			NotificationText = NotificationText + ?(NotificationText = "", "", ", ") + RecipientRow;
		EndDo;
		ShowUserNotification(NotificationTitle,, NotificationText, PictureLib.ExecuteTask);
		
		FillMailAddresses();
	EndIf;
EndProcedure

&AtClient
Function IsPickupUsersOrGroup(RecipientOrRecipientsSet)
	Return TypeOf(RecipientOrRecipientsSet) = Type("Array")
		AND MailingRecipientType.ContainsType(Type("CatalogRef.Users"));
EndFunction

&AtClient
Function ChoicePickupDragToTabularSection(SelectedValue)
	NewRowArray = New Array;
	If TypeOf(SelectedValue) = Type("Array") Then
		For Each PickingItem In SelectedValue Do
			Result = ChoicePickupDragItemToTabularSection(PickingItem);
			AddValueToNotificationArray(Result, NewRowArray);
		EndDo;
	Else
		Result = ChoicePickupDragItemToTabularSection(SelectedValue);
		AddValueToNotificationArray(Result, NewRowArray);
	EndIf;
	Return NewRowArray;
EndFunction

&AtClient
Procedure AddValueToNotificationArray(Text, NewRowArray)
	If ValueIsFilled(Text) Then
		NewRowArray.Add(Text);
	EndIf;
EndProcedure

&AtClient
Function ChoicePickupDragItemToTabularSection(AttributeValue)
	Filter = New Structure("Recipient", AttributeValue);
	FoundRows = Recipients.FindRows(Filter);
	
	If FoundRows.Count() > 0 Then
		Return Undefined;
	EndIf;
	
	Row = Recipients.Add();
	Row.Recipient = AttributeValue;
	
	Return AttributeValue;
EndFunction

&AtClient
Procedure PasteFromClipboardCompletion(Result, Parameter) Export

	If Result <> Undefined Then 
		For each Recipient In Result Do 
			NewRow = Recipients.Add();
			NewRow.Recipient = Recipient;
		EndDo;
		
		FillMailAddresses();
	EndIf;
	

EndProcedure

&AtServer
Procedure FillMailAddresses()
	ParametersSet = "Ref, RecipientEmailAddressKind, Personal, Recipients, MailingRecipientType";
	
	RecipientsParameters = New Structure(ParametersSet);
	FillPropertyValues(RecipientsParameters, ThisObject);
	RecipientsParameters.Personal = False;
	RecipientsParameters.MailingRecipientType = MetadataObjectID;
	RecipientsParameters.Recipients = Recipients;
	
	BulkEmailRecipients = ReportMailing.GenerateMailingRecipientsList(RecipientsParameters);;
	For each BulkEmailRecipient In Recipients Do
		If BulkEmailRecipients.Count() = 0 Then
			If BulkEmailRecipient.Recipient = Undefined Then 
				Continue;
			EndIf;
		Else	
			RecipientEmailAddr = BulkEmailRecipients.Get(BulkEmailRecipient.Recipient);
			BulkEmailRecipient.Address = ?(RecipientEmailAddr <> Undefined, RecipientEmailAddr, "")
		EndIf;
		If BulkEmailRecipient.Recipient.IsFolder Or TypeOf(BulkEmailRecipient.Recipient) = Type("CatalogRef.UserGroups") Then
			BulkEmailRecipient.PictureIndex = 3;
		Else
			BulkEmailRecipient.PictureIndex = 1;
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.RecipientsRecipient.Name);
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.RecipientsExcluded.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Recipients.Excluded");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("TextColor", Metadata.StyleItems.OverdueDataColor.Value);

EndProcedure

&AtServer
Procedure FillRecipientsTypeInfo(Cancel)
	RecipientsTypesTable = ReportMailingCached.RecipientsTypesTable();
	FoundItems = RecipientsTypesTable.FindRows(New Structure("RecipientsType", MailingRecipientType));
	If FoundItems.Count() = 1 Then
		RecipientRow = FoundItems[0];
		MetadataObjectID            = RecipientRow.MetadataObjectID;
		ChoiceFormPath                           = RecipientRow.ChoiceFormPath;
		ContactInformationOfRecipientsTypeGroup = RecipientRow.CIGroup;
		// CI group is used for the RecipientsMailAddressKind field in the ChoiceParameterLinks.Filter.
	Else
		Cancel = True;
	EndIf;
EndProcedure

#EndRegion