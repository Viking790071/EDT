///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#Region Variables

&AtClient
Var ChoiceContext;

#EndRegion

#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
	
	InfobaseUpdate.CheckObjectProcessed(Object, ThisObject);
	
	If Object.Ref.IsEmpty() Then
		Reviewed = True;
		OnCreateAndOnReadAtServer();
		Interactions.SetSubjectByFillingData(Parameters, Topic);
		ContactsChanged = True;
	EndIf;
	
	Interactions.FillChoiceListForReviewAfter(Items.ReviewAfter.ChoiceList);
	RestrictedExtensions = FilesOperationsInternal.DeniedExtensionsList();
	
	// Preparing interaction notifications.
	Interactions.PrepareNotifications(ThisObject,Parameters);
	
	// StandardSubsystems.Properties
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("ItemForPlacementName", "AdditionalAttributesPage");
		AdditionalParameters.Insert("DeferredInitialization", True);
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.OnCreateAtServer(ThisObject, AdditionalParameters);
	EndIf;
	// End StandardSubsystems.Properties
	
	// StandardSubsystems.MessagesTemplates
	DeterminePossibilityToFillEmailByTemplate();
	// End StandardSubsystems.MessagesTemplates
	
	// StandardSubsystems.AttachableCommands
	If Common.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommands = Common.CommonModule("AttachableCommands");
		ModuleAttachableCommands.OnCreateAtServer(ThisObject);
	EndIf;
	// End StandardSubsystems.AttachableCommands
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// StandardSubsystems.Properties
	If CommonClient.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerClient = CommonClient.CommonModule("PropertyManagerClient");
		ModulePropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	EndIf;
	// End StandardSubsystems.Properties
	
	// StandardSubsystems.AttachableCommands
	If CommonClient.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommandsClient = CommonClient.CommonModule("AttachableCommandsClient");
		ModuleAttachableCommandsClient.StartCommandUpdate(ThisObject);
	EndIf;
	// End StandardSubsystems.AttachableCommands
	
	AvailabilityControl();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)

	// StandardSubsystems.Properties
	If CommonClient.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerClient = CommonClient.CommonModule("PropertyManagerClient");
		If ModulePropertyManagerClient.ProcessNofifications(ThisObject, EventName, Parameter) Then
			UpdateAdditionalAttributesItems();
			ModulePropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
		EndIf;
	EndIf;
	// End StandardSubsystems.Properties
	
	InteractionsClient.ProcessNotification(ThisObject, EventName, Parameter, Source);

	If EventName = "Write_AttachedFile" Then
		If TypeOf(Source) = Type("CatalogRef.OutgoingEmailAttachedFiles") Then
			
			AttachmentsCurrentData = Items.Attachments.CurrentData;
			If AttachmentsCurrentData = Undefined Then
				Return;
			EndIf;
			FileAttributes = FileAttributes(Source);
			FillPropertyValues(AttachmentsCurrentData, FileAttributes);
			AttachmentsCurrentData.SizePresentation = 
				InteractionsClientServer.GetFileSizeStringPresentation(FileAttributes.Size);
			AttachmentsCurrentData.FileName = ?(IsBlankString(FileAttributes.Extension),
			                                   FileAttributes.Description,
			                                   FileAttributes.Description + "." + FileAttributes.Extension);
		EndIf;
	EndIf;
	
	// StandardSubsystems.MessagesTemplates
	If EventName = "Write_MessagesTemplates" Then
		DeterminePossibilityToFillEmailByTemplate();
	EndIf;
	// End StandardSubsystems.MessagesTemplates
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	Var RowStart, RowEnd, ColumnStart, ColumnEnd;
	Var BoldBeginning, BoldEnd;
	
	If Upper(ChoiceSource.FormName) = Upper("Document.OutgoingEmail.Form.ExternalObjectRefGeneration") Then
		
		If MessageFormat = PredefinedValue("Enum.EmailEditingMethods.NormalText") Then
			Items.EmailText.GetTextSelectionBounds(RowStart, ColumnStart, RowEnd, ColumnEnd);
			
			EmailText = TextInsertionInEmailResult(EmailText, RowStart, ColumnStart, ColumnEnd, SelectedValue);
			
		Else
			
			Items.EmailTextFormattedDocument.GetTextSelectionBounds(BoldBeginning, BoldEnd);
			EmailTextFormattedDocument.Insert(BoldBeginning, SelectedValue);
			
		EndIf;
	
	ElsIf Upper(ChoiceSource.FormName) = Upper("DocumentJournal.Interactions.Form.EmailMessageParameters") Then
		
		If SelectedValue <> Undefined AND Object.EmailStatus <> PredefinedValue("Enum.OutgoingEmailStatuses.Sent") Then
			
			Object.RequestDeliveryReceipt          = SelectedValue.RequestDeliveryReceipt;
			Object.RequestReadReceipt         = SelectedValue.RequestReadReceipt;
			Object.IncludeOriginalEmailBody = SelectedValue.IncludeOriginalEmailBody;
			Modified = True;
			
		EndIf;
		
	ElsIf Upper(ChoiceSource.FormName) = Upper("CommonForm.AddressBookForEmail")
		OR Upper(ChoiceSource.FormName) = Upper("CommonForm.ContactsClarification") Then
		
		FillSelectedRecipientsAfterChoice(SelectedValue);
		
	Else
		
		InteractionsClient.ChoiceProcessingForm(ThisObject, SelectedValue, ChoiceSource, ChoiceContext);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	EnableUnsafeContent = False;
	
	Interactions.SetInteractionFormAttributesByRegisterData(ThisObject);
	OnCreateAndOnReadAtServer();
	
	// StandardSubsystems.Properties
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.OnReadAtServer(ThisObject, CurrentObject);
	EndIf;
	// End StandardSubsystems.Properties
	
	// StandardSubsystems.AccessManagement
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.OnReadAtServer(ThisObject, CurrentObject);
	EndIf;
	// End StandardSubsystems.AccessManagement
	
	// StandardSubsystems.AttachableCommands
	If Common.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommandsClientServer = Common.CommonModule("AttachableCommandsClientServer");
		ModuleAttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
	EndIf;
	// End StandardSubsystems.AttachableCommands
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	ClearMessages();
	
	If Not Sending Then
		
		If CheckAddresseesListFilling() Then
			Cancel = True;
		EndIf;
		
		If Object.EmailStatus = PredefinedValue("Enum.OutgoingEmailStatuses.Draft") 
			OR Object.EmailStatus = PredefinedValue("Enum.OutgoingEmailStatuses.Sent") Then
			InteractionsClient.CheckOfDeferredSendingAttributesFilling(Object, Cancel);
		EndIf;
		
		If Cancel Then
			Return;
		EndIf;
		
	EndIf;
	
	#If Not WebClient Then
		For Each AttachmentsTableRow In Attachments Do
			If AttachmentsTableRow.Placement = 2 Then
				Try
					Data = New BinaryData(AttachmentsTableRow.FileNameOnComputer);
					AttachmentsTableRow.FileNameOnComputer = PutToTempStorage(Data, "");
					AttachmentsTableRow.Placement = 4;
				Except
					CommonClientServer.MessageToUser(BriefErrorDescription(ErrorInfo()),,"Attachments",, Cancel);
				EndTry;
			EndIf;
		EndDo;
	#EndIf
	
	Object.HasAttachments = (Attachments.Count() <> 0);
	
	FillTabularSectionsByRecipientsList();
	
	Object.EmailRecipientsList =
		InteractionsClientServer.GetAddressesListPresentation(Object.EmailRecipients, False);
	Object.CcRecipientsList =
		InteractionsClientServer.GetAddressesListPresentation(Object.CCRecipients, False);
	Object.BccRecipientsList = 
		InteractionsClientServer.GetAddressesListPresentation(Object.BccRecipients, False);
		
	For Each Attachment In Attachments Do
		
		If Attachment.Placement = 0 
			AND Attachment.IsBeingEdited Then
			
			PutFileNotifyDescription = New NotifyDescription("AfterPutFile", ThisObject);
			FilesOperationsClient.PutAttachedFile(PutFileNotifyDescription, Attachment.Ref, UUID);
			
		EndIf;

	EndDo;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	If Not Exit
		AND Modified
		AND Object.EmailStatus = PredefinedValue("Enum.OutgoingEmailStatuses.Draft") Then
		
		HasFilesToEdit = False;
		FilesToEditArray = New Array;
		
		For Each Attachment In Attachments Do
			
			If Attachment.IsBeingEdited Then
				HasFilesToEdit = True;
				FilesToEditArray.Add(Attachment.Ref);
			EndIf;
			
		EndDo;
		
		If HasFilesToEdit Then
			
			Cancel                = True;
			StandardProcessing = False;
			
			QuestionText = NStr("ru = 'Данные были изменены, Записать?'; en = 'Data was changed. Write?'; pl = 'Dane zostały zmienione. Zapisać?';es_ES = 'Los datos se han cambiado. ¿Guardar?';es_CO = 'Los datos se han cambiado. ¿Guardar?';tr = 'Veriler değişti. Kaydedilsin mi?';it = 'Dati modificati. Scrivere?';de = 'Die Daten wurden geändert. Speichern?'");
			AdditionalParameters = New Structure;
			AdditionalParameters.Insert("FilesToEditArray", FilesToEditArray);
			NotificationAfterClosingPrompt = New NotifyDescription("AfterQuestionOnClose", ThisObject, AdditionalParameters);
			
			ShowQueryBox(NotificationAfterClosingPrompt, QuestionText, QuestionDialogMode.YesNoCancel);
			
		EndIf;
		
	EndIf;
		
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteMode, PostingMode)
	
	DocumentHTMLOfCurrentEmailPrepared = False;
	
	// Preparing an HTML document from the formatted document content.
	If MessageFormat = Enums.EmailEditingMethods.HTML
		 AND CurrentObject.EmailStatus = Enums.OutgoingEmailStatuses.Draft Then
		
		AttachmentsNamesToIDsMapsTable.Clear();
		
		AttachmentsStructure = New Structure;
		EmailTextFormattedDocument.GetHTML(CurrentObject.HTMLText, AttachmentsStructure);
		For each Attachment In AttachmentsStructure Do
			
			NewRow = AttachmentsNamesToIDsMapsTable.Add();
			NewRow.FileName = Attachment.Key;
			NewRow.FileIDForHTML = New UUID;
			NewRow.Picture = Attachment.Value;
			
		EndDo;
		
		If AttachmentsNamesToIDsMapsTable.Count() > 0 Then
			
			DocumentHTML = Interactions.GetHTMLDocumentObjectFromHTMLText(CurrentObject.HTMLText);
			Interactions.ChangePicturesNamesToMailAttachmentsIDsInHTML(
			    DocumentHTML, AttachmentsNamesToIDsMapsTable.Unload());
			DocumentHTMLOfCurrentEmailPrepared = True;
			
		EndIf;
		
	Else
		
		CurrentObject.Text = EmailText;
		
	EndIf;
	
	If BaseEmailProcessingRequired() Then
		
		If MessageFormat = Enums.EmailEditingMethods.HTML Then
			
			CurrentObject.HTMLText = GenerateEmailTextIncludingBaseEmail(
				?(DocumentHTMLOfCurrentEmailPrepared,DocumentHTML,Undefined), CurrentObject);
				
			CurrentObject.Text = Interactions.GetPlainTextFromHTML(CurrentObject.HTMLText);
			
		Else
			
			CurrentObject.Text = GenerateEmailTextIncludingBaseEmail(Undefined, CurrentObject);
			
		EndIf;
		
	Else
		
		If DocumentHTMLOfCurrentEmailPrepared Then
			
			CurrentObject.HTMLText = Interactions.GetHTMLTextFromHTMLDocumentObject(DocumentHTML);
			CurrentObject.Text     = Interactions.GetPlainTextFromHTML(CurrentObject.HTMLText);
			
		EndIf;
		
	EndIf;
	
	If Object.EmailStatus = Enums.OutgoingEmailStatuses.Draft Then
		
		CurrentObject.EmailAttachments.Clear();
		RowIndex = 1;
		For Each Attachment In Attachments Do
			
			If Attachment.Placement = 5 AND ValueIsFilled(Attachment.Email) Then
				NewRow = CurrentObject.EmailAttachments.Add();
				NewRow.Email                     = Attachment.Email;
				NewRow.SequenceNumberInAttachments = RowIndex;
			EndIf;
			
			RowIndex =  RowIndex + 1;
			
		EndDo;
		
	EndIf;
	
	If Sending AND Not SendMessagesImmediately Then
		
		CurrentObject.EmailStatus = Enums.OutgoingEmailStatuses.Outgoing;
		
	EndIf;
	
	If Object.EmailStatus <> CurrentEmailStatus 
		AND CurrentObject.EmailStatus = Enums.OutgoingEmailStatuses.Outgoing 
		AND Not GetFunctionalOption("SendEmailsInHTMLFormat")
		AND (TypeOf(InteractionBasis) = Type("DocumentRef.IncomingEmail")
		OR TypeOf(InteractionBasis) = Type("DocumentRef.OutgoingEmail"))
		AND IncomingEmailTextType = Enums.EmailTextTypes.HTML Then
		
		CurrentObject.HasAttachments = True;
		
	EndIf;
	
	CurrentObject.Size = EstimateEmailSize();
	
	// StandardSubsystems.Properties
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.BeforeWriteAtServer(ThisObject, CurrentObject);
	EndIf;
	// End StandardSubsystems.Properties
	
	Interactions.BeforeWriteInteractionFromForm(ThisObject, CurrentObject, ContactsChanged);
	
EndProcedure

&AtServer
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	Interactions.OnWriteInteractionFromForm(CurrentObject, ThisObject);
	
	If Object.EmailStatus <> Enums.OutgoingEmailStatuses.Draft Then
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	
	Email = CurrentObject.Ref;
	
	Lock = New DataLock;
	DataLockItem = Lock.Add("Catalog.OutgoingEmailAttachedFiles");
	DataLockItem.SetValue("FileOwner", Email);
	InformationRegisters.InteractionsFolderSubjects.BlockInteractionFoldersSubjects(Lock, Email);
	Lock.Lock();
	
	// Adding to the list of deleted attachments previously saved pictures displayed in the body of a formatted document.
	FormattedDocumentPicturesAttachmentsTable = Interactions.GetEmailAttachmentsWithNonBlankIDs(Email);
	For each Attachment In FormattedDocumentPicturesAttachmentsTable Do
		DeletedAttachments.Add(Attachment.Ref);
	EndDo;
	
	// Deleting deleted attachments
	For Each DeletedAttachment In DeletedAttachments Do
		ObjectAttachment = DeletedAttachment.Value.GetObject();
		ObjectAttachment.Delete();
	EndDo;
	DeletedAttachments.Clear();
	
	If MessageFormat = Enums.EmailEditingMethods.HTML Then
		
		For each Attachment In AttachmentsNamesToIDsMapsTable Do
			
			BinaryPictureData = Attachment.Picture.GetBinaryData();
			PictureAddressInTempStorage = PutToTempStorage(BinaryPictureData, UUID);
			
			AttachmentParameters = New Structure;
			AttachmentParameters.Insert("FileName", "_" + StrReplace(Attachment.FileIDForHTML, "-", "_"));
			AttachmentParameters.Insert("Size", BinaryPictureData.Size());
			AttachmentParameters.Insert("EmailFileID", Attachment.FileIDForHTML);
			
			AttachedFile = EmailManagement.WriteEmailAttachmentFromTempStorage(
				Email, PictureAddressInTempStorage, AttachmentParameters);
			
		EndDo;
		
	EndIf;
	
	If BaseEmailProcessingRequired() Then
		
		BaseEmailAttachments = Interactions.GetEmailAttachmentsWithNonBlankIDs(Object.InteractionBasis);
		
		For Each Attachment In BaseEmailAttachments Do
			
			BinaryPictureData = FilesOperations.FileBinaryData(Attachment.Ref);
			PictureAddressInTempStorage = PutToTempStorage(BinaryPictureData, UUID);
			
			AttachmentParameters = New Structure;
			AttachmentParameters.Insert("FileName", Attachment.Description);
			AttachmentParameters.Insert("Size", Attachment.Size);
			AttachmentParameters.Insert("EmailFileID", Attachment.EmailFileID);
			
			AttachedFile = EmailManagement.WriteEmailAttachmentFromTempStorage(
				Email, PictureAddressInTempStorage, AttachmentParameters);
			
		EndDo;
		
	EndIf;
	
	For Each AttachmentsTableRow In Attachments Do
		
		Size = 0;
		FileName = AttachmentsTableRow.FileName;
		
		If AttachmentsTableRow.Placement = 4 Then
			// from a temporary storage
			
			AttachmentParameters = New Structure;
			AttachmentParameters.Insert("FileName", FileName);
			AttachmentParameters.Insert("Size", Size);
			
			EmailManagement.WriteEmailAttachmentFromTempStorage(
				Email, AttachmentsTableRow.FileNameOnComputer, AttachmentParameters);
			
		ElsIf AttachmentsTableRow.Placement = 3 Then
			// from a file on server
			
		ElsIf AttachmentsTableRow.Placement = 1 Then
			
			EmailManagement.WriteEmailAttachmentByCopyOtherEmailAttachment(
				Email, AttachmentsTableRow.Ref, UUID);
			
		ElsIf AttachmentsTableRow.Placement = 0 Then
			// rewriting an attachment
			
		EndIf;
		
		AttachmentsTableRow.Placement = 0;
		
	EndDo;
	
	If Object.EmailStatus <> CurrentEmailStatus Then
		AttachIncomingBaseEmailAsAttachmentIfNecessary(CurrentObject);
		Interactions.SetEmailFolder(Email, 
			Interactions.DefineDefaultFolderForEmail(Email, True));
		CurrentEmailStatus = Object.EmailStatus;
	EndIf;
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)

	// StandardSubsystems.AccessManagement
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.AfterWriteAtServer(ThisObject, CurrentObject, WriteParameters);
	EndIf;
	// End StandardSubsystems.AccessManagement
	
	FillAttachments();
	Interactions.SetEmailFormHeader(ThisObject);
	SetButtonTitleByDefault();
	
	Items.CommentPage.Picture = CommonClientServer.CommentPicture(Object.Comment);
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)

	InteractionsClient.InteractionSubjectAfterWrite(ThisObject,
		Object,
		WriteParameters,
		"OutgoingEmail");
	
	RefreshDataRepresentation();

EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.Properties
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.FillCheckProcessing(ThisObject, Cancel, CheckedAttributes);
	EndIf;
	// End StandardSubsystems.Properties
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure PagesDetailsAdditionallyOnChangePage(Item, CurrentPage)
	
	// StandardSubsystems.Properties
	If CommonClient.SubsystemExists("StandardSubsystems.Properties")
		AND CurrentPage.Name = "AdditionalAttributesPage"
		AND Not ThisObject.PropertiesParameters.DeferredInitializationExecuted Then
		
		PropertiesExecuteDeferredInitialization();
		ModulePropertyManagerClient = CommonClient.CommonModule("PropertyManagerClient");
		ModulePropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	EndIf;
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure ReviewAfterProcessSelection(Item, ValueSelected, StandardProcessing)
	
	InteractionsClient.ProcessSelectionInReviewAfterField(
		ReviewAfter, ValueSelected, StandardProcessing, Modified);
	
EndProcedure

&AtClient
Procedure SenderPresentationChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	If Object.Account <> ValueSelected Then
		ChangeSignature(Object.Account, ValueSelected);
		Object.Account = ValueSelected;
		ListItem = Item.ChoiceList.FindByValue(ValueSelected);
		If ListItem <> Undefined Then
			StandardProcessing = False;
			Object.SenderPresentation = ListItem.Presentation;
		EndIf;
		Modified = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure EmailTextOnClick(Item, EventData, StandardProcessing)
	
	InteractionsClient.HTMLFieldOnClick(Item, EventData, StandardProcessing);
	
EndProcedure

&AtClient
Procedure IncomingEmailTextOnClick(Item, EventData, StandardProcessing)
	
	InteractionsClient.HTMLFieldOnClick(Item, EventData, StandardProcessing);
	
EndProcedure

&AtClient
Procedure SubjectStartChoice(Item, ChoiceData, StandardProcessing)
	
	InteractionsClient.SubjectStartChoice(ThisObject, Item, ChoiceData, StandardProcessing);
	
EndProcedure

&AtClient
Procedure WarningAboutUnsafeContentURLProcessing(Item, FormattedStringURL, StandardProcessing)
	If FormattedStringURL = "EnableUnsafeContent" Then
		StandardProcessing = False;
		EnableUnsafeContent = True;
		ReadOutgoingHTMLEmailText();
	EndIf;
EndProcedure

#EndRegion

#Region AttachmentsFormTableItemsEventHandlers

&AtClient
Procedure AttachmentsChoice(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	OpenAttachmentExecute();
	
EndProcedure

&AtClient
Procedure AttachmentsDragCheck(Item, DragParameters, StandardProcessing, Row, Field)
	
	StandardProcessing = False;
	If Object.EmailStatus <> PredefinedValue("Enum.OutgoingEmailStatuses.Draft") Then
		DragParameters.Action = DragAction.Cancel;
	EndIf;
	
EndProcedure

&AtClient
Procedure AttachmentsDrag(Item, DragParameters, StandardProcessing, Row, Field)
	
	StandardProcessing = False;
	
	FilesArray = New Array;
	
	If TypeOf(DragParameters.Value) = Type("File") Then
		
		FilesArray.Add(DragParameters.Value);
		
	ElsIf TypeOf(DragParameters.Value) = Type("Array") Then
		
		If DragParameters.Value.Count() >= 1
			AND TypeOf(DragParameters.Value[0]) = Type("File") Then
			
			For Each ReceivedFile In DragParameters.Value Do
				If TypeOf(ReceivedFile) = Type("File") Then
					FilesArray.Add(ReceivedFile);
				EndIf;
			EndDo;
		EndIf;
		
	EndIf;
	
	For Each SelectedFile In FilesArray Do
		
		AdditionalParameters = New Structure("SelectedFile", SelectedFile);
		NotifyDescription = New NotifyDescription("IsFileAfterCompletionCheck", ThisObject, AdditionalParameters);
		SelectedFile.BeginCheckingIsFile(NotifyDescription);
		
	EndDo;
	
EndProcedure

#EndRegion

#Region RecipientsListFormTableItemsEventHandlers

&AtClient
Procedure RecipientsListPresentationStartChoice(Item, ChoiceData, StandardProcessing)
	
	ClearMessages();
	
	If Items.RecipientsList.CurrentData = Undefined Then
		Return;
	EndIf;
	
	If Object.EmailStatus <> PredefinedValue("Enum.OutgoingEmailStatuses.Sent") Then
		
		SendingOption = Items.RecipientsList.CurrentData.SendingOption;
		If SendingOption  = "SendTo:" Then
			SelectionGroup = NStr("ru = 'Кому'; en = 'SendTo'; pl = 'Wyślij do';es_ES = 'Envía a';es_CO = 'Envía a';tr = 'Kime';it = 'Invia a';de = 'Gesendet an'");
		ElsIf SendingOption  = "Copy:" Then
			SelectionGroup = NStr("ru = 'Копии'; en = 'Cc'; pl = 'Kopia';es_ES = 'Copia';es_CO = 'Copia';tr = 'Cc';it = 'Cc';de = 'Cc'");
		ElsIf SendingOption = "BCC:" Then
			SelectionGroup = NStr("ru = 'Скрытые'; en = 'Hidden'; pl = 'Ukryte';es_ES = 'Ocultado';es_CO = 'Ocultado';tr = 'Gizli';it = 'Nascosto';de = 'Ausgeblendet'");
		EndIf;
		
		EditRecipientsList(True, SelectionGroup);
	Else
		EditRecipientsList(False);
	EndIf;

EndProcedure

&AtClient
Procedure RecipientsListBeforeEditEnd(Item, NewRow, CancelEdit, Cancel)
	
	If CancelEdit Then
		Return;
	EndIf;
	
	RowData = Item.CurrentData;
	If RowData = Undefined Then
		Return;
	EndIf;
	
	Address = "";
	PositionStart = StrFind(RowData.Presentation, "<");
	If PositionStart > 0 Then
		PositionEnd = StrFind(RowData.Presentation, ">", SearchDirection.FromBegin, PositionStart);
		If PositionEnd > 0 Then
			Address = Mid(RowData.Presentation, PositionStart + 1, PositionEnd - PositionStart - 1);
		EndIf;
	EndIf;
	
	If IsBlankString(Address) Then
		Address = RowData.Presentation;
	EndIf;
	
	If IsBlankString(Address) Then
		Return;
	EndIf;
	
	If StrFind(Address, "@") = 0 OR StrFind(Address, ".") = 0 Then
		AttachIdleHandler("ShowEmailAddressRequiredMessage", 0.1, True);
		Cancel = True;
		Return;
	EndIf;
	
	Item.CurrentData.Address = TrimAll(Address);

	Filter = New Structure("Address", Address);
	FoundRows = RecipientsList.FindRows(Filter);
	If FoundRows.Count() > 1 Then
		ErrorTextTemplate = NStr("ru = 'Адрес %1 уже есть в списке.'; en = 'Address %1 already exists in the list.'; pl = 'Adres %1 jest już na liście.';es_ES = 'La dirección %1 ya existe en la lista.';es_CO = 'La dirección %1 ya existe en la lista.';tr = '%1 adresi listede zaten var.';it = 'L''indirizzo %1 esiste già nell''elenco.';de = 'Die Adresse %1 existiert bereits in der Liste.'");
		CommonClientServer.MessageToUser(StringFunctionsClientServer.SubstituteParametersToString(ErrorTextTemplate, Address)
			,, "RecipientsList[" + String(RecipientsList.IndexOf(FoundRows[0])) + "].Presentation");
		Cancel = True;
		Return;
	EndIf;
	
	ContactsChanged = True;

EndProcedure

&AtClient
Procedure RecipientsListPresentationAutoComplete(Item, Text, ChoiceData, DataGetParameters, Waiting, StandardProcessing)
	If Waiting = 0 Then
		Return;
	EndIf;
	
	If IsBlankString(Text) Then
		Return;
	EndIf;
	
	ChoiceData = FindContacts(Text);
	If ChoiceData.Count() > 0 Then
		StandardProcessing = False;
	Else
		ChoiceData = Undefined;
	EndIf;
	
EndProcedure

&AtClient
Procedure RecipientsListOnStartEdit(Item, NewRow, Clone)
	If NewRow Then
		Item.CurrentData.SendingOption = Items.RecipientsListSendingOption.ChoiceList.FindByValue("SendTo:");
		Item.CurrentItem = Items.RecipientsListPresentation;
	EndIf;
EndProcedure

&AtClient
Procedure RecipientsListPresentationChoiceProcessing(Item, ValueSelected, StandardProcessing)
	StandardProcessing = False;
	
	If TypeOf(ValueSelected) = Type("Structure") Then
		CurrentData = Items.RecipientsList.CurrentData;
		CurrentData.Address         = ValueSelected.Address;
		CurrentData.Presentation = InteractionsClientServer.GetAddresseePresentation(ValueSelected.Presentation, ValueSelected.Address, "");
		CurrentData.Contact       = ValueSelected.Contact;
	EndIf;
	
EndProcedure

&AtClient
Procedure RecipientsListBeforeDeleteRow(Item, Cancel)
	If RecipientsList.Count() = 1 Then
		Cancel = True;
		RecipientsList[0].Presentation = "";
		RecipientsList[0].Address = "";
		RecipientsList[0].Contact = Undefined;
	EndIf;
EndProcedure

&AtClient
Procedure RecipientsListOnChange(Item)
	
	FillTabularSectionsByRecipientsList();
	InteractionsClientServer.CheckContactsFilling(Object, ThisObject, "OutgoingEmail");
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure SendForwardExecute(Command)
	
	ClearMessages();
	
	If Object.EmailStatus = PredefinedValue("Enum.OutgoingEmailStatuses.Sent") Then
		ForwardExecute();
		Return;
	EndIf;
		
	If CheckAddresseesListFilling() Then
		Return;
	EndIf;
	
	If RecipientsList.Count() = 0 Then
		
		CommonClientServer.MessageToUser(
			NStr("ru = 'Необходимо указать хотя бы одного получателя письма.'; en = 'Specify at least one email recipient.'; pl = 'Określ co najmniej jednego odbiorcę wiadomości e-mail.';es_ES = 'Especifique al menos un destinatario de correo electrónico.';es_CO = 'Especifique al menos un destinatario de correo electrónico.';tr = 'En az bir e-posta alıcısı belirtin.';it = 'Specificare almeno un destinatario della email.';de = 'Zumindest einen E-Mail-Empfänger angeben.'"),, "RecipientsList");
		Return;
		
	ElsIf (RecipientsList.Count() = 1 AND IsBlankString(RecipientsList[0].Address)) Then
		
		CommonClientServer.MessageToUser(
			NStr("ru = 'Необходимо указать хотя бы одного получателя письма.'; en = 'Specify at least one email recipient.'; pl = 'Określ co najmniej jednego odbiorcę wiadomości e-mail.';es_ES = 'Especifique al menos un destinatario de correo electrónico.';es_CO = 'Especifique al menos un destinatario de correo electrónico.';tr = 'En az bir e-posta alıcısı belirtin.';it = 'Specificare almeno un destinatario della email.';de = 'Zumindest einen E-Mail-Empfänger angeben.'"),, "RecipientsList[0].Presentation");
		Return;
		
	EndIf;
	
	SendExecute();
	
EndProcedure

&AtClient
Procedure HTML(Command)
	
	If MessageFormat <> PredefinedValue("Enum.EmailEditingMethods.HTML") Then
		
		MessageFormat = PredefinedValue("Enum.EmailEditingMethods.HTML");
		MessageFormatOnChange();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure NormalText(Command)
	
	If MessageFormat <> PredefinedValue("Enum.EmailEditingMethods.NormalText") Then
		
		MessageFormat = PredefinedValue("Enum.EmailEditingMethods.NormalText");
		MessageFormatOnChange();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure DisplayBaseEmailText(Command)
	
	Items.DisplayBaseEmailText.Check = NOT Items.DisplayBaseEmailText.Check;
	Items.IncomingGroup.Visible = Items.DisplayBaseEmailText.Check;
	Object.DisplaySourceEmailBody = Not Object.DisplaySourceEmailBody;
	
EndProcedure

&AtClient
Procedure SpecifyContacts(Command)
	
	If Object.EmailStatus <> PredefinedValue("Enum.OutgoingEmailStatuses.Sent") Then
		
		EditRecipientsList(True, NStr("ru = 'Копии'; en = 'Cc'; pl = 'Kopia';es_ES = 'Copia';es_CO = 'Copia';tr = 'Cc';it = 'Cc';de = 'Cc'"));
		
	Else
		
		EditRecipientsList(False);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure EmailParameters(Command)
	
	TextIDs = New Array;
	TextIDs.Add("ID messages:  " + Object.MessageID);
	TextIDs.Add("ID basis:  " + Object.BasisID);
	TextIDs.Add("IDs basis: " 
	                                   + GetBaseIDsPresentation(Object.BasisIDs));
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("Created", Object.Date);
	ParametersStructure.Insert("Sent", Object.PostingDate);
	ParametersStructure.Insert("RequestDeliveryReceipt", Object.RequestDeliveryReceipt);
	ParametersStructure.Insert("RequestReadReceipt", Object.RequestReadReceipt);
	ParametersStructure.Insert("InternetTitles", StrConcat(TextIDs, Chars.LF));
	ParametersStructure.Insert("Email", Object.Ref);
	ParametersStructure.Insert("EmailType", "OutgoingEmail");
	ParametersStructure.Insert("Encoding", Object.Encoding);
	ParametersStructure.Insert("InternalNumber", Object.Number);
	ParametersStructure.Insert("IncludeOriginalEmailBody", Object.IncludeOriginalEmailBody);
	ParametersStructure.Insert("Account", Object.Account);
	
	OpenForm("DocumentJournal.Interactions.Form.EmailMessageParameters", ParametersStructure, ThisObject);
	
EndProcedure

&AtClient
Procedure InsertExternalRefToInfobaseObject(Command)
	
	OpenForm("Document.OutgoingEmail.Form.ExternalObjectRefGeneration",,ThisObject);
	
EndProcedure

// StandardSubsystems.Properties

&AtClient
Procedure Attachable_PropertiesExecuteCommand(ItemOrCommand, URL = Undefined, StandardProcessing = Undefined)
	
	If CommonClient.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerClient = CommonClient.CommonModule("PropertyManagerClient");
		ModulePropertyManagerClient.ExecuteCommand(ThisObject, ItemOrCommand, StandardProcessing);
	EndIf;
	
EndProcedure

// End StandardSubsystems.Properties

// StandardSubsystems.MessagesTemplates

&AtClient
Procedure GenerateFromTemplate(Command)
	
	If CommonClient.SubsystemExists("StandardSubsystems.MessageTemplates") Then
		ModuleMessagesTemplatesClient = CommonClient.CommonModule("MessageTemplatesClient");
		Notification = New NotifyDescription("FillByTemplateAfterTemplateChoice", ThisObject);
		MessageSubject = ?(ValueIsFilled(Topic), Topic, "Common");
		ModuleMessagesTemplatesClient.PrepareMessageFromTemplate(MessageSubject, "Email", Notification);
	EndIf
	
EndProcedure

// End StandardSubsystems.MessagesTemplates

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();
	
	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.Subject.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Object.EmailStatus");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotEqual;
	ItemFilter.RightValue = Enums.OutgoingEmailStatuses.Sent;

	Item.Appearance.SetParameterValue("ReadOnly", False);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.AttachmentsContextMenuAttachmentProperties.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Object.EmailStatus");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = Enums.OutgoingEmailStatuses.Draft;

	Item.Appearance.SetParameterValue("ReadOnly", True);
	
	// Sending options list
	Interactions.SetChoiceListConditionalAppearance(ThisObject, "RecipientsListSendingOption", "RecipientsList.SendingOption");

EndProcedure

&AtClient
Procedure OnControlOnChange()
	
	AvailabilityControl();
	
	Reviewed = NOT UnderControl;
	Modified = True;
	
EndProcedure

&AtClient
Function CheckAddresseesListFilling()
	
	Cancel = False;
	AddressesByPresentations = New Map;
	AddressesByValues = New Map;
	ErrorTextTemplate = NStr("ru = 'Адрес %1 уже есть в списке.'; en = 'Address %1 already exists in the list.'; pl = 'Adres %1 jest już na liście.';es_ES = 'La dirección %1 ya existe en la lista.';es_CO = 'La dirección %1 ya existe en la lista.';tr = '%1 adresi listede zaten var.';it = 'L''indirizzo %1 esiste già nell''elenco.';de = 'Die Adresse %1 existiert bereits in der Liste.'");
	
	For each AddressString In RecipientsList Do
		
		Result = CommonClientServer.EmailsFromString(AddressString.Presentation);
		For Each AddressStructure In Result Do
			
			If Not IsBlankString(AddressStructure.ErrorDescription) Then
				Cancel = True;
				CommonClientServer.MessageToUser(AddressStructure.ErrorDescription, , "RecipientsList[" + String(RecipientsList.IndexOf(AddressString)) + "].Presentation");
			EndIf;
			
			If AddressesByPresentations.Get(AddressStructure.Address) <> Undefined Then
				Cancel = True;
				CommonClientServer.MessageToUser(StringFunctionsClientServer.SubstituteParametersToString(ErrorTextTemplate,
					AddressStructure.Address),, "RecipientsList[" + String(RecipientsList.IndexOf(AddressString)) + "].Presentation");
			Else
				AddressesByPresentations.Insert(AddressStructure.Address, AddressString.GetID());
			EndIf;
			
		EndDo;
		
		If NOT Cancel Then
			Result = CommonClientServer.EmailsFromString(AddressString.Address);
			For Each AddressStructure In Result Do
				
				If Not IsBlankString(AddressStructure.ErrorDescription) Then
					Cancel = True;
					CommonClientServer.MessageToUser(AddressStructure.ErrorDescription, , "RecipientsList[" + String(RecipientsList.IndexOf(AddressString)) + "].Presentation");
				EndIf;
				
				If AddressesByValues.Get(AddressStructure.Address) <> Undefined Then
					Cancel = True;
					CommonClientServer.MessageToUser(StringFunctionsClientServer.SubstituteParametersToString(ErrorTextTemplate,
						AddressStructure.Address),, "RecipientsList[" + String(RecipientsList.IndexOf(AddressString)) + "].Presentation");
				Else
					AddressesByValues.Insert(AddressStructure.Address, AddressString.GetID());
				EndIf;
			
			EndDo;
		EndIf;
		
	EndDo;
	
	If NOT Cancel Then
		
		For each AddressByValue In AddressesByValues Do
			If AddressesByPresentations.Get(AddressByValue.Key) <> Undefined
				AND AddressesByPresentations.Get(AddressByValue.Key) <> AddressByValue.Value Then
					Cancel = True;
					Index = RecipientsList.IndexOf(RecipientsList.FindByID(AddressByValue.Value));
					CommonClientServer.MessageToUser(StringFunctionsClientServer.SubstituteParametersToString(ErrorTextTemplate,
						AddressByValue.Key),, "RecipientsList[" + String(Index) + "].Presentation");
			EndIf;
		EndDo;
	EndIf;
	
	Return Cancel;
	
EndFunction

&AtServer
Function BaseEmailProcessingRequired()

	Return Sending AND Object.IncludeOriginalEmailBody AND GetFunctionalOption("SendEmailsInHTMLFormat") 
	        AND (Not Object.InteractionBasis = Undefined) AND (Not Object.InteractionBasis.IsEmpty()) 
	        AND Object.EmailStatus = Enums.OutgoingEmailStatuses.Draft;

EndFunction

/////////////////////////////////////////////////////////////////////////////////
//  Managing form item availability.

&AtClient
Procedure AvailabilityControl()

	Items.ReviewAfter.Enabled = UnderControl;
	
	If Object.EmailStatus = PredefinedValue("Enum.OutgoingEmailStatuses.Outgoing") 
		AND (NOT FileInfobase
		OR (Object.DateToSendEmail <> Date(1,1,1) AND Object.DateToSendEmail > CommonClient.SessionDate())
		OR (Object.EmailSendingRelevanceDate <> Date(1,1,1) AND Object.EmailSendingRelevanceDate < CommonClient.SessionDate())) Then
		Items.Send.Visible = False;
	Else
		Items.Send.Visible = True;
	EndIf;
	Items.FormWriteAndClose.Visible = Not Items.Send.Visible;
	
	Items.SendingDateRelevanceGroup.Enabled = (Object.EmailStatus <> PredefinedValue("Enum.OutgoingEmailStatuses.Sent")); 

EndProcedure

&AtServer
Procedure DefineItemsVisibilityAvailabilityDependingOnEmailStatus()

	If Object.EmailStatus <> Enums.OutgoingEmailStatuses.Sent Then
		EmailManagement.GetAvailableAccountsForSending(
			Items.SenderPresentation.ChoiceList,AvailableAccountsForSending);
			
		If Object.Account.IsEmpty()
			AND AvailableAccountsForSending.Count() > 0
			AND Object.Ref.IsEmpty() Then
			
			Object.Account = AvailableAccountsForSending[0].Account;
			
		EndIf;
		
		ListItem = Items.SenderPresentation.ChoiceList.FindByValue(Object.Account);
		If ListItem <> Undefined Then
			Object.SenderPresentation = ListItem.Presentation;
		EndIf;
		
	Else
		
		Items.SenderPresentation.ReadOnly             = True;
		Items.RecipientsListSendingOption.ReadOnly     = True;
		Items.RecipientsListPresentation.TextEdit = False;
		Items.RecipientsList.ReadOnly                    = True;
		
	EndIf;
	
	If Object.EmailStatus <> Enums.OutgoingEmailStatuses.Draft Then
		
		If Attachments.Count() > 0 Then
			Items.AddAttachment.Enabled = False;
			Items.DeleteAttachment.Enabled  = False;
			Items.AddEmail.Enabled   = False;
		Else
			Items.Attachments.Visible = False;
		EndIf;
		
		If Object.TextType = Enums.EmailTextTypes.HTML Then
			EmailText = Object.HTMLText;
			EmailText = Interactions.ProcessHTMLText(Object.Ref);
			Items.EmailText.Type = FormFieldType.HTMLDocumentField;
			Items.EmailText.ReadOnly = False;
		Else
			EmailText = Object.Text;
			Items.EmailText.Type = FormFieldType.TextDocumentField;
			Items.EmailText.ReadOnly = True;
		EndIf;
		
		If Object.EmailStatus = Enums.OutgoingEmailStatuses.Outgoing 
			AND (NOT FileInfobase 
			OR (Object.DateToSendEmail <> Date(1,1,1) AND Object.DateToSendEmail > CurrentSessionDate())
			OR (Object.EmailSendingRelevanceDate <> Date(1,1,1) AND Object.EmailSendingRelevanceDate < CurrentSessionDate())) Then
			
			Items.Send.Enabled = False;
			
		EndIf;
		
	Else
		
		DetermineEmailEditMethod();
		
	EndIf;

EndProcedure

#Region AttachmentsOperations

&AtServer
Procedure AddEmailAttachment(Email)
	
	If Attachments.FindRows(New Structure("Email", Email)).Count() > 0 Then
		Return;
	EndIf;
	
	AttributesString = "Size, Subject";
	If TypeOf(Email) = Type("DocumentRef.IncomingEmail") Then
		AttributesString =  AttributesString + ", DateReceived";
	ElsIf TypeOf(Email) = Type("DocumentRef.OutgoingEmail") Then
		AttributesString =  AttributesString + ", Date, PostingDate";
	Else
		Return;
	EndIf;
	
	EmailAttributes = Common.ObjectAttributesValues(Email, AttributesString);
	
	If TypeOf(Email) = Type("DocumentRef.IncomingEmail") Then
		EmailDate = EmailAttributes.DateReceived;
	Else
		EmailDate = ?(ValueIsFilled(EmailAttributes.PostingDate), EmailAttributes.PostingDate, EmailAttributes.Date);
	EndIf;

	EmailPresentation = Interactions.EmailPresentation(EmailAttributes.Subject, EmailDate);
	
	NewRow = Attachments.Add();
	NewRow.Email               = Email;
	NewRow.FileName             = EmailPresentation;
	NewRow.PictureIndex       = FilesOperationsInternalClientServer.GetFileIconIndex("eml");
	NewRow.FileNameOnComputer = "";
	NewRow.SignedWithDS           = False;
	NewRow.Size               = EmailAttributes.Size;
	NewRow.SizePresentation  = InteractionsClientServer.GetFileSizeStringPresentation(NewRow.Size);
	NewRow.Placement         = 5;

EndProcedure

&AtServer
Procedure AddEmailsAttachments()

	AttachmentEmailsTable = Interactions.DataStoredInAttachmentsEmailsDatabase(Object.Ref);
	
	For Each AttachmentEmail In AttachmentEmailsTable Do
			
		EmailPresentation = Interactions.EmailPresentation(AttachmentEmail.Subject, AttachmentEmail.Date);
		
		NewRow = Attachments.Add();
		NewRow.Email               = AttachmentEmail.Email;
		NewRow.FileName             = EmailPresentation;
		NewRow.PictureIndex       = FilesOperationsInternalClientServer.GetFileIconIndex("eml");
		NewRow.FileNameOnComputer = "";
		NewRow.SignedWithDS           = False;
		NewRow.Size               = AttachmentEmail.Size;
		NewRow.SizePresentation  = InteractionsClientServer.GetFileSizeStringPresentation(NewRow.Size);
		NewRow.Placement         = 5;
		
	EndDo;

EndProcedure

&AtClient
Procedure AddEmail(Command)
	
	OpeningParameters = New Structure;
	OpeningParameters.Insert("ChoiceMode", True);
	OpeningParameters.Insert("CloseOnChoice", True);
	OpeningParameters.Insert("EmailOnly", True);
	NotifyDescription = New NotifyDescription("AddEmailCompletion", ThisObject);
	OpenForm("DocumentJournal.Interactions.ListForm",
	             OpeningParameters,
	             ThisObject,,,,
	             NotifyDescription,
	             FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure AddEmailCompletion(Result, Parameters) Export
	
	If InteractionsClient.IsEmail(Result) Then
		AddEmailAttachment(Result);
		Modified = True;
	EndIf;
	
EndProcedure 

&AtClient
Procedure AttachmentsBeforeAddRow(Item, Cancel, Clone, Parent, Folder)
	
	Cancel = True;
	AddAttachmentExecute();

EndProcedure

&AtClient
Procedure AttachmentsBeforeDeleteRow(Item, Cancel)
	
	If Object.EmailStatus = PredefinedValue("Enum.OutgoingEmailStatuses.Draft") Then
		DeleteAttachmentExecute();
	EndIf;
	
	Cancel = True;
	
EndProcedure

&AtClient
Procedure AttachmentsOnActivateCell(Item)
	
	CurrentData = Items.Attachments.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	Items.AttachmentsContextMenuAttachmentProperties.Enabled = (CurrentData.Placement <> 5);
	
EndProcedure

&AtClient
Procedure AddAttachmentExecute()
	
	#If Not WebClient Then
		
		Dialog = New FileDialog(FileDialogMode.Open);
		Dialog.Multiselect = True;
		NotifyDescription = New NotifyDescription("FileSelectionDialogAfterChoice", ThisObject);
		Dialog.Show(NotifyDescription);
		
	#Else

		Address = "";
		SelectedFile = "";
		OnCloseNotifyHandler = New NotifyDescription("PutFileOnEnd", ThisObject);
		BeginPutFile(OnCloseNotifyHandler, Address, SelectedFile, True, UUID);
		
	#EndIf
	
EndProcedure

&AtClient
Procedure DeleteAttachmentExecute()

	AddAttachmentToDeletedAttachmentsList();
	
	CurrentData = Items.Attachments.CurrentData;
	If CurrentData <> Undefined Then
		Index = Attachments.IndexOf(CurrentData);
		Attachments.Delete(Index);
		RefreshDataRepresentation();
	EndIf;
	
EndProcedure

&AtClient
Procedure AddAttachmentToDeletedAttachmentsList()

	CurrentData = Items.Attachments.CurrentData;
	If (CurrentData <> Undefined) AND (CurrentData.Placement = 0) Then
		DeletedAttachments.Add(CurrentData.Ref);
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenAttachmentExecute()
	
	CurrentData = Items.Attachments.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If (CurrentData.Placement = 0) OR (CurrentData.Placement = 1) Then
		
		If InteractionsClientServer.IsFileEmail(CurrentData.FileName) Then
			
			InteractionsClient.OpenAttachmentEmail(CurrentData.Ref, EmailAttachmentParameters(), ThisObject);
			
		Else
			
			ForEditing = Object.EmailStatus = PredefinedValue("Enum.OutgoingEmailStatuses.Draft");
			
			EmailManagementClient.OpenAttachment(CurrentData.Ref,
			                                                  ThisObject,
			                                                  ForEditing);
			
			If ForEditing Then
				CurrentData.IsBeingEdited = True;
				Modified = True;
			EndIf;
			
		EndIf;
		
	ElsIf CurrentData.Placement = 2 Then
		
		PathToFile = CurrentData.FileNameOnComputer;
		#If Not WebClient Then
			
			If InteractionsClientServer.IsFileEmail(CurrentData.FileName) Then
				
				Try
					
					Data = New BinaryData(CurrentData.FileNameOnComputer);
					
					InteractionsClient.OpenAttachmentEmail(PutToTempStorage(Data, UUID), 
					                                           EmailAttachmentParameters(),
					                                           ThisObject);
					
				Except
					FileSystemClient.OpenFile(PathToFile);
				EndTry;
			Else
				FileSystemClient.OpenFile(PathToFile);
			EndIf;
			
		#Else
			GetFile(PathToFile, CurrentData.FileName, True);
		#EndIf
		
	ElsIf CurrentData.Placement = 4 Then
		
		PathToFile = CurrentData.FileNameOnComputer;
		#If Not WebClient Then
			If IsTempStorageURL(CurrentData.FileNameOnComputer) Then
				TempFolderName = GetTempFileName();
				CreateDirectory(TempFolderName);
				PathToFile = TempFolderName + "\" + CurrentData.FileName;
				BinaryData = GetFromTempStorage(CurrentData.FileNameOnComputer);
				BinaryData.Write(PathToFile);
			EndIf;
			FileSystemClient.OpenFile(PathToFile);
		#Else
			GetFile(PathToFile, CurrentData.FileName, True);
		#EndIf
		
	ElsIf CurrentData.Placement = 5 Then
		
		AttachmentParameters = InteractionsClient.EmptyStructureOfAttachmentEmailParameters();
		AttachmentParameters.BaseEmailDate = ?(ValueIsFilled(Object.PostingDate), Object.PostingDate , Object.Date);
		AttachmentParameters.EmailBasis     = Object.Ref;
		AttachmentParameters.BaseEmailSubject = Object.Subject;
		
		InteractionsClient.OpenAttachmentEmail(CurrentData.Email,
		                                           EmailAttachmentParameters(),
		                                           ThisObject);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FillAttachments(PassedParameters = Undefined)
	
	If Object.Ref.IsEmpty() AND PassedParameters <> Undefined Then
		If PassedParameters.Property("Basis") 
			AND TypeOf(PassedParameters.Basis) = Type("Structure") 
			AND PassedParameters.Basis.Property("Command") Then 
			
			If  PassedParameters.Basis.Command = "Forward" Then
			
				AttachmentTab = EmailManagement.GetEmailAttachments(PassedParameters.Basis.Basis, True);
				For Each AttachmentsTableRow In AttachmentTab Do
					If IsBlankString(AttachmentsTableRow.EmailFileID) Then
						NewRow = Attachments.Add();
						NewRow.Ref              = AttachmentsTableRow.Ref;
						NewRow.FileName            = AttachmentsTableRow.FileName;
						NewRow.PictureIndex      = AttachmentsTableRow.PictureIndex;
						NewRow.Size              = AttachmentsTableRow.Size;
						NewRow.SizePresentation = AttachmentsTableRow.SizePresentation;
						NewRow.Placement        = 1;
					EndIf;
				EndDo;
				
				DataStoredInAttachmentsEmailsDatabase = Interactions.DataStoredInAttachmentsEmailsDatabase(PassedParameters.Basis.Basis);
				For Each TableRow In DataStoredInAttachmentsEmailsDatabase Do
					AddEmailAttachment(TableRow.Email);
				EndDo;
				
			ElsIf PassedParameters.Basis.Command = "ForwardAsAttachment"
				AND Parameters.Basis.Property("Basis")  Then

				AddEmailAttachment(Parameters.Basis.Basis);
				
			EndIf;
			
		EndIf;
	Else
		
		Attachments.Clear();
		AttachmentTab = EmailManagement.GetEmailAttachments(Object.Ref, True);
		For Each AttachmentsTableRow In AttachmentTab Do
			If IsBlankString(AttachmentsTableRow.EmailFileID) Then
				NewRow = Attachments.Add();
				NewRow.Ref              = AttachmentsTableRow.Ref;
				NewRow.FileName            = AttachmentsTableRow.FileName;
				NewRow.PictureIndex      = AttachmentsTableRow.PictureIndex;
				NewRow.Size              = AttachmentsTableRow.Size;
				NewRow.SizePresentation = AttachmentsTableRow.SizePresentation;
				NewRow.SignedWithDS          = AttachmentsTableRow.SignedWithDS;
				NewRow.Placement        = 0;
			EndIf;
		EndDo;
		
		AddEmailsAttachments();
		
	EndIf;
	
	Attachments.Sort("FileName");
	
EndProcedure

&AtServer
Procedure AttachIncomingBaseEmailAsAttachmentIfNecessary(CurrentObject)
	
	If CurrentObject.EmailStatus = Enums.OutgoingEmailStatuses.Outgoing 
		AND Not GetFunctionalOption("SendEmailsInHTMLFormat") 
		AND (TypeOf(InteractionBasis) = Type("DocumentRef.IncomingEmail") 
		OR TypeOf(InteractionBasis) = Type("DocumentRef.OutgoingEmail")) 
		AND IncomingEmailTextType = Enums.EmailTextTypes.HTML Then
		
		If TypeOf(InteractionBasis) = Type("DocumentRef.IncomingEmail") Then
			HTMLTextIncomingEmail = Interactions.GenerateHTMLTextForIncomingEmail(InteractionBasis, True, True, False);
		Else
			HTMLTextIncomingEmail = Interactions.GenerateHTMLTextForOutgoingEmail(InteractionBasis, True, True, False);
		EndIf;
		
		FileName = GetTempFileName("html");
		FileSourceMessage = New TextWriter(FileName,TextEncoding.UTF16);
		FileSourceMessage.Write(HTMLTextIncomingEmail);
		FileSourceMessage.Close();
		BinaryData       = New BinaryData(FileName);
		FileAddressInStorage = PutToTempStorage(BinaryData);
		
		FileOnHardDrive = New File(FileName);
		If FileOnHardDrive.Exist() Then
			DeleteFiles(FileName);
		EndIf;
		
		FileParameters = FilesOperations.FileAddingOptions();
		FileParameters.FilesOwner = CurrentObject.Ref;
		FileParameters.BaseName = NStr("ru = 'Пересылаемое сообщение'; en = 'Forwarded message'; pl = 'Wiadomość przekazana dalej';es_ES = 'Mensaje reenviado';es_CO = 'Mensaje reenviado';tr = 'Yönlendirilmiş ileti';it = 'Messaggio inoltrato';de = 'Weitergeleitete Nachricht'");
		FileParameters.ExtensionWithoutPoint = "html";
		FileParameters.ModificationTimeUniversal = Undefined;
		
		FilesOperations.AppendFile(FileParameters, FileAddressInStorage);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AttachmentProperties(Command)
	
	CurrentData = Items.Attachments.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	CurrentIndexInCollection = Attachments.IndexOf(CurrentData);
	
	If CurrentData.Ref = Undefined Then
		AdditionalParameters = New Structure("CurrentIndexInCollection", CurrentIndexInCollection);
		OnCloseNotifyHandler = New NotifyDescription("QuestionOfFileRecordAfterClose", ThisObject, AdditionalParameters);
		QuestionText = NStr("ru = 'Свойства файла доступны только после его записи. Записать?'; en = 'The file properties will be available when you save the file. Do you want to save it?'; pl = 'Właściwości pliku będą dostępne kiedy zapiszesz plik. Czy chcesz zapisać go?';es_ES = 'Las propiedades del archivo estarán disponibles al guardar el archivo. ¿Quiere guardarlo?';es_CO = 'Las propiedades del archivo estarán disponibles al guardar el archivo. ¿Quiere guardarlo?';tr = 'Dosya kaydedildikten sonra özelliklerine erişilebilir. Dosya kaydedilsin mi?';it = 'Le proprietà del file saranno disponibili al salvataggio del file. Salvare il file?';de = 'Die Dateieigenschaften sind nach dem Speichern der Datei verfügbar. Möchten Sie sie speichern?'");
		ShowQueryBox(OnCloseNotifyHandler, QuestionText, QuestionDialogMode.YesNo);
	Else
		OpenAttachmentProperties(CurrentIndexInCollection);
	EndIf;
	
EndProcedure

&AtClient
Procedure PutFileOnEnd(ResultOfPutting, Address, SelectedFileName, AdditionalParameters) Export

	If ResultOfPutting = False Then
		Return;
	EndIf;
	
	NewRow = Attachments.Add();
	NewRow.Placement = 4;
	NewRow.FileNameOnComputer = Address;
	NewRow.FileName = SelectedFileName;
	
	Extension = CommonClientServer.GetFileNameExtension(SelectedFileName);
	NewRow.PictureIndex = FilesOperationsInternalClientServer.GetFileIconIndex(Extension);
	
	Items.Attachments.CurrentRow = NewRow.GetID();
	
	RefreshDataRepresentation();

EndProcedure

&AtClient
Procedure QuestionOfFileRecordAfterClose(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult = DialogReturnCode.Yes Then
		Write();
	Else
		Return;
	EndIf;
	
	OpenAttachmentProperties(AdditionalParameters.CurrentIndexInCollection);
	
EndProcedure

&AtClient
Procedure ReceivingSizeCompletion(Size, AdditionalParameters) Export

	AttachmentsTableRow  = AdditionalParameters.AttachmentsTableRow;
	AttachmentsTableRow.Size = Size;
	AttachmentsTableRow.SizePresentation = InteractionsClientServer.GetFileSizeStringPresentation(Size); 

EndProcedure

&AtClient
Procedure FileSelectionDialogAfterChoice(SelectedFiles, AdditionalParameters) Export
	
	If SelectedFiles = Undefined Then
		Return;
	EndIf;
	
	For Each SelectedFile In SelectedFiles Do
		NewRow = Attachments.Add();
		NewRow.Placement = 2;
		NewRow.FileNameOnComputer = SelectedFile;
		
		FileName = FileNameWithoutDirectory(SelectedFile);
		NewRow.FileName = FileName;
		
		Extension                      = CommonClientServer.GetFileNameExtension(FileName);
		NewRow.PictureIndex      = FilesOperationsInternalClientServer.GetFileIconIndex(Extension);
		AdditionalParameters = New Structure("AttachmentsTableRow", NewRow);
		File = New File(SelectedFile);
		File.BeginGettingSize(New NotifyDescription("ReceivingSizeCompletion", ThisObject, AdditionalParameters));
	EndDo;
	
	If SelectedFiles.Count() > 0 Then
		Items.Attachments.CurrentRow = NewRow.GetID();
	EndIf;
	
EndProcedure

&AtClient
Procedure IsFileAfterCompletionCheck(IsFile, AdditionalParameters) Export

	If NOT IsFile Then
		Return;
	EndIf;
	
	FullName = AdditionalParameters.SelectedFile.FullName;
	
	NewRow = Attachments.Add();
	NewRow.Placement = 2;
	NewRow.FileNameOnComputer = FullName;
	
	FileName = FileNameWithoutDirectory(FullName);
	NewRow.FileName = FileName;
	
	Extension                      = CommonClientServer.GetFileNameExtension(FileName);
	NewRow.PictureIndex      = FilesOperationsInternalClientServer.GetFileIconIndex(Extension);
	AdditionalParameters         = New Structure("AttachmentsTableRow", NewRow);
	File = New File(FullName);
	File.BeginGettingSize(New NotifyDescription("ReceivingSizeCompletion", ThisObject, AdditionalParameters));

EndProcedure

&AtClient
Function FileNameWithoutDirectory(Val FullFileName)
	
	FileName = FullFileName;
	While True Do
		
		Position = Max(StrFind(FileName, "\"), StrFind(FileName, "/"));
		If Position = 0 Then
			Return FileName;
		EndIf;
		
		FileName = Mid(FileName, Position + 1);
		
	EndDo;
	Return FileName;
	
EndFunction

#EndRegion

#Region EmailBodyGeneration

&AtServer
Function GenerateEmailTextIncludingBaseEmail(DocumentHTMLCurrentEditing, CurrentObject)
	
	Selection = Interactions.GetBaseEmailData(Object.InteractionBasis);
	
	If MessageFormat = Enums.EmailEditingMethods.NormalText Then
		
		Return GenerateOutgoingMessagePlainText(Selection, CurrentObject);
		
	Else
		
		Return GenerateOutgoingMessageHTML(Selection,DocumentHTMLCurrentEditing, CurrentObject);
		
	EndIf;
	
EndFunction

&AtServer
Function GenerateOutgoingMessageHTML(Selection,DocumentHTMLCurrentEditing, CurrentObject)
	
	// Getting HTMLDocument of the incoming email.
	If Selection.TextType = Enums.EmailTextTypes.PlainText Then
		DocumentHTML = Interactions.GetHTMLDocumentFromPlainText(Selection.Text);
	Else
		DocumentHTML = Interactions.GetHTMLDocumentObjectFromHTMLText(Selection.HTMLText);
	EndIf;
	
	EmailBodyItem = DocumentHTML.Body;
	If EmailBodyItem = Undefined Then
		If DocumentHTMLCurrentEditing = Undefined Then
			Return CurrentObject.HTMLText;
		Else
			Return Interactions.GetHTMLTextFromHTMLDocumentObject(DocumentHTMLCurrentEditing);
		EndIf
	EndIf;
	
	If DocumentHTMLCurrentEditing = Undefined Then
		DocumentHTMLCurrentEditing = Interactions.GetHTMLDocumentObjectFromHTMLText(CurrentObject.HTMLText);
	EndIf;
	
	BodyChildNodesArray = Interactions.ArrayOfChildNodesContainingHTML(EmailBodyItem);
	
	// Adding a text edited in the formatted document field.
	If DocumentHTMLCurrentEditing.Body <> Undefined Then
		For each ChildNode In DocumentHTMLCurrentEditing.Body.ChildNodes Do
			
			EmailBodyItem.AppendChild(DocumentHTML.ImportNode(ChildNode,True));
			
		EndDo;
	EndIf;
	
	DIVElement = Interactions.AddElementWithAttributes(
		EmailBodyItem,
		"div",
		New Structure("style", "border:none;border-left:solid blue 1.5pt;padding:0cm 0cm 0cm 4.0pt"));
		
	For each ChildNode In BodyChildNodesArray Do
		
		DIVElement.AppendChild(ChildNode);
		
	EndDo;

	// Preparing a base email header.
	// Horizontal separator.
	AttributesStructure = New Structure;
	AttributesStructure.Insert("size", "2");
	AttributesStructure.Insert("width", "100%");
	AttributesStructure.Insert("align", "center");
	AttributesStructure.Insert("tabindex", "-1");
	
	HRElement = Interactions.AddElementWithAttributes(
		DIVElement,
		"hr",
		AttributesStructure);
	Interactions.InsertHTMLElementAsFirstChildElement(DIVElement ,HRElement, BodyChildNodesArray);
	
	// Base email data
	FontItem = Interactions.GenerateEmailHeaderDataItem(DIVElement, Selection);
	Interactions.InsertHTMLElementAsFirstChildElement(DIVElement, FontItem, BodyChildNodesArray);
	
	Return Interactions.GetHTMLTextFromHTMLDocumentObject(DocumentHTML);
	
EndFunction

&AtServer
Function GenerateOutgoingMessagePlainText(SelectionIncomingEmailData, CurrentObject)

	// Generating an incoming email header.
	StringHeader = NStr("ru = '-----Пересылаемое сообщение-----'; en = '-----Forwarded message-----'; pl = '-----Przesłana wiadomość-----';es_ES = '-----Mensaje reenviado-----';es_CO = '-----Mensaje reenviado-----';tr = '-----Yönlendirilmiş ileti-----';it = '-----Messaggio inoltrato-----';de = '-----Weitergeleitete Nachricht-----'");
	
	StringHeader = StringHeader + Chars.LF+ NStr("ru = 'От'; en = 'From'; pl = 'Od';es_ES = 'Desde';es_CO = 'Desde';tr = 'Kimden';it = 'Da';de = 'Von'") + ": "+ SelectionIncomingEmailData.SenderPresentation
		          + ?(SelectionIncomingEmailData.MetadataObjectName = "IncomingEmail",
		          "[" + SelectionIncomingEmailData.SenderAddress +"]",
		          "");
		
	StringHeader = StringHeader + Chars.LF+ NStr("ru = 'Отправлено'; en = 'Sent'; pl = 'Wysłano';es_ES = 'Enviar';es_CO = 'Enviar';tr = 'Gönderilen';it = 'Inviato';de = 'Gesendet'") + ": " 
	              + Format(SelectionIncomingEmailData.Date,"DLF=DT");
	
	StringHeader = StringHeader + Chars.LF+ NStr("ru = 'Кому'; en = 'SendTo'; pl = 'Wyślij do';es_ES = 'Envía a';es_CO = 'Envía a';tr = 'Kime';it = 'Invia a';de = 'Gesendet an'") + ": " 
	    + Interactions.GetIncomingEmailRecipientsPresentations(SelectionIncomingEmailData.EmailRecipients.Unload());
		
	CCRecipientsTable = SelectionIncomingEmailData.CCRecipients.Unload();
	
	If CCRecipientsTable.Count() > 0 Then
		StringHeader = StringHeader + Chars.LF+ NStr("ru = 'Копии'; en = 'Cc'; pl = 'Kopia';es_ES = 'Copia';es_CO = 'Copia';tr = 'Cc';it = 'Cc';de = 'Cc'") + ": "
		+ Interactions.GetIncomingEmailRecipientsPresentations(CCRecipientsTable);
	EndIf;
	
	StringHeader = StringHeader + Chars.LF+ NStr("ru = 'Тема'; en = 'Subject'; pl = 'Temat';es_ES = 'Tema';es_CO = 'Tema';tr = 'Konu';it = 'Soggetto';de = 'Thema'") + ": " + SelectionIncomingEmailData.Subject;
	
	// Transforming an HTML text to a plain text if necessary.
	If SelectionIncomingEmailData.TextType <> Enums.EmailTextTypes.PlainText Then
		
		IncomingEmailText =  Interactions.GetPlainTextFromHTML(SelectionIncomingEmailData.HTMLText);
		
	Else
		
		IncomingEmailText = SelectionIncomingEmailData.Text
		
	EndIf;
	
	Return CurrentObject.Text + Chars.LF + Chars.LF + StringHeader + Chars.LF + Chars.LF + IncomingEmailText;

EndFunction

#Region OtherProceduresAndFunctions

// Determines an email edit method and displays the email text according to the edit method.
// 
&AtServer
Procedure DetermineEmailEditMethod()

	If Object.TextType.IsEmpty() Then
		
		MessageFormat = Interactions.DefaultMessageFormat(Users.CurrentUser());
		
		// If a text type is not filled in, the format might have been selected incorrectly, that is why:
		// 1) If the text is filled but HTML is not filled, correct the message format to "text".
		// 2) If HTML is filled but the text is not filled, correct the message format to HTML.
		If MessageFormat = Enums.EmailEditingMethods.NormalText 
			AND TrimAll(Object.Text) = "" AND TrimAll(Object.HTMLText) <> "" Then
			MessageFormat = Enums.EmailEditingMethods.HTML;
		ElsIf MessageFormat = Enums.EmailEditingMethods.HTML
			AND TrimAll(Object.Text) <> "" AND TrimAll(Object.HTMLText) = "" Then
			MessageFormat = Enums.EmailEditingMethods.NormalText;
		EndIf;
		
	Else
		If Object.TextType = Enums.EmailTextTypes.PlainText Then
			MessageFormat = Enums.EmailEditingMethods.NormalText;
		Else
			MessageFormat = Enums.EmailEditingMethods.HTML;
		EndIf;
		
	EndIf;
	
	If Object.Ref.IsEmpty() Then
		
		If Not GetFunctionalOption("SendEmailsInHTMLFormat") 
			AND MessageFormat = Enums.EmailEditingMethods.HTML Then
			MessageFormat = Enums.EmailEditingMethods.NormalText;
		EndIf;
		
		UserUserSessionParameters =
			Interactions.GetUserParametersForOutgoingEmail(
			Object.Account,
			MessageFormat,
			?(Object.InteractionBasis = Undefined, True, False));
		
		Object.RequestDeliveryReceipt            = UserUserSessionParameters.RequestDeliveryReceipt;
		Object.RequestReadReceipt           = UserUserSessionParameters.RequestReadReceipt;
		Object.IncludeOriginalEmailBody   = UserUserSessionParameters.IncludeOriginalEmailBody;
		Object.DisplaySourceEmailBody = UserUserSessionParameters.DisplaySourceEmailBody;
		
	EndIf;
	
	If MessageFormat = Enums.EmailEditingMethods.HTML Then
		
		Items.EmailTextPages.CurrentPage = Items.FormattedDocumentPage;
		Object.TextType = Enums.EmailTextTypes.HTML;
		If Not Object.Ref.IsEmpty() Or ValueIsFilled(Object.HTMLText) Then
			
			If IsTempStorageURL(Object.HTMLText) Then
				
				HTMLEmailBody   = GetFromTempStorage(Object.HTMLText);
				Object.HTMLText = HTMLEmailBody.HTMLText;
				EmailTextFormattedDocument.SetHTML(HTMLEmailBody.HTMLText, HTMLEmailBody.AttachmentsStructure);
				Object.TextType = Enums.EmailTextTypes.HTMLWithPictures;
				Object.Text     = EmailTextFormattedDocument.GetText();
				
			Else
				AttachmentsStructure  = New Structure;
				Object.HTMLText   = Interactions.ProcessHTMLTextForFormattedDocument(
					Object.Ref, Object.HTMLText, AttachmentsStructure);
				EmailTextFormattedDocument.SetHTML(Object.HTMLText, AttachmentsStructure);
			EndIf;
			
		EndIf;
		
		If Object.Ref.IsEmpty() AND UserUserSessionParameters.Signature <> Undefined Then
			AddFormattedDocumentToFormattedDocument(EmailTextFormattedDocument, UserUserSessionParameters.Signature);
		EndIf;
		
	Else
		
		Items.EmailTextPages.CurrentPage = Items.PlainTextPage;
		Items.EmailText.Type = FormFieldType.TextDocumentField;
		Object.TextType = Enums.EmailTextTypes.PlainText;
		EmailText = Object.Text;
		If Object.Ref.IsEmpty() AND UserUserSessionParameters.Signature <> Undefined Then
			EmailText = EmailText + UserUserSessionParameters.Signature;
		EndIf;
		Object.Encoding = "UTF-8";
		
	EndIf;
	
	Items.MessageFormat.Visible = True;
	Items.MessageFormat.Title = MessageFormat;
	
EndProcedure

// Processes passed parameters when creating an email.
&AtServer
Procedure ProcessPassedParameters(PassedParameters)
	
	If NOT Object.Ref.IsEmpty() Then
		Return;
	EndIf;
	
	SetEmailText();
	
	If PassedParameters.Property("Attachments") AND PassedParameters.Attachments <> Undefined Then
		
		If TypeOf(PassedParameters.Attachments) = Type("ValueList") Or TypeOf(PassedParameters.Attachments) = Type("Array") Then
			For Each Attachment In PassedParameters.Attachments Do
				AttachmentDetails = Attachments.Add();
				If TypeOf(PassedParameters.Attachments) = Type("ValueList") Then
					If IsTempStorageURL(Attachment.Value) Then
						AttachmentDetails.Placement = 4;
						AttachmentDetails.FileNameOnComputer = PutToTempStorage(GetFromTempStorage(Attachment.Value), UUID);
					ElsIf TypeOf(Attachment.Value) = Type("BinaryData") Then
						AttachmentDetails.Placement = 4;
						AttachmentDetails.FileNameOnComputer = PutToTempStorage(Attachment.Value, UUID);
					Else
						AttachmentDetails.Placement = 2;
						AttachmentDetails.FileNameOnComputer = Attachment.Value;
					EndIf;
					AttachmentDetails.FileName = Attachment.Presentation;
				Else // ValueType(PassedParameters.Attachments) = "array of structures"
					If Not IsBlankString(Attachment.AddressInTempStorage) Then
						AttachmentDetails.Placement = 4;
						AttachmentDetails.FileNameOnComputer = PutToTempStorage(
						GetFromTempStorage(Attachment.AddressInTempStorage), UUID);
					Else
						AttachmentDetails.Placement = 2;
						AttachmentDetails.FileNameOnComputer = Attachment.PathToFile;
					EndIf;
				EndIf;
				AttachmentDetails.FileName = Attachment.Presentation;
				Extension = CommonClientServer.GetFileNameExtension(AttachmentDetails.FileName);
				AttachmentDetails.PictureIndex = FilesOperationsInternalClientServer.GetFileIconIndex(Extension);
			EndDo;
		EndIf;
		
	EndIf;
	
	If PassedParameters.Property("Subject") AND NOT IsBlankString(PassedParameters.Subject) Then
		Object.Subject = PassedParameters.Subject;
	EndIf;
	
	If PassedParameters.Property("Recipient") AND PassedParameters.Recipient <> Undefined Then
		
		// If the Recipient parameter is passed, this tabular section is cleared before being filled according to the parameter data.
		Object.EmailRecipients.Clear();
		
		If TypeOf(PassedParameters.Recipient) = Type("String") AND NOT IsBlankString(PassedParameters.Recipient) Then
			Object.EmailRecipientsList = PassedParameters.Recipient;
			NewRow = Object.EmailRecipients.Add();
			NewRow.Address = PassedParameters.Recipient;
			
		ElsIf TypeOf(PassedParameters.Recipient) = Type("ValueList") Then
			
			For Each ListItem In PassedParameters.Recipient Do
				NewRow = Object.EmailRecipients.Add();
				NewRow.Address = ListItem.Value;
				NewRow.Presentation = ProcessedAddresseePresentation(ListItem.Presentation);
				
				NewRow = RecipientsList.Add();
				NewRow.SendingOption = NStr("ru = 'Кому:'; en = 'To:'; pl = 'Do:';es_ES = 'Para:';es_CO = 'Para:';tr = 'Kime:';it = 'A:';de = 'An:'");
				NewRow.Address = ListItem.Value;
				NewRow.Presentation = ProcessedAddresseePresentation(ListItem.Presentation);
			EndDo;
			
			Object.EmailRecipientsList = InteractionsClientServer.GetAddressesListPresentation(Object.EmailRecipients, False);
			
		ElsIf TypeOf(PassedParameters.Recipient) = Type("Array") Then
			
			For Each ArrayElement In PassedParameters.Recipient Do
				
				AddressesArray = StrSplit(ArrayElement.Address, ";");
				
				For Each Address In AddressesArray Do
					If IsBlankString(Address) Then 
						Continue;
					EndIf;
					NewRow = Object.EmailRecipients.Add();
					NewRow.Address = TrimAll(Address);
					NewRow.Presentation = ProcessedAddresseePresentation(ArrayElement.Presentation);
					NewRow.Contact = ArrayElement.ContactInformationSource;
				EndDo;
				
			EndDo;
			
			Object.EmailRecipientsList = InteractionsClientServer.GetAddressesListPresentation(Object.EmailRecipients, False);
			
		EndIf;
		
	EndIf;
	
	ClearAddresseesDuplicates(Object.EmailRecipients);
	
	If PassedParameters.Property("From") AND NOT PassedParameters.From.IsEmpty() Then
		
		Object.Account = PassedParameters.From;
		SenderAttributes = Common.ObjectAttributesValues(
		PassedParameters.From,"Ref, UserName, EmailAddress");
		Object.SenderPresentation = InteractionsClientServer.GetAddresseePresentation(
		SenderAttributes.UserName, SenderAttributes.EmailAddress, "");
		
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Function ProcessedAddresseePresentation(AddresseePresentation)

	AddresseePresentation = StrReplace(AddresseePresentation, ",", "");
	AddresseePresentation = StrReplace(AddresseePresentation, ";", "");
	
	Return AddresseePresentation;

EndFunction

&AtServer
Procedure SetEmailText()
	
	If NOT Parameters.Property("Text") Then
		Return;
	EndIf;
	
	Text = Parameters.Text;
	
	If TypeOf(Text) = Type("Structure") Then
		
		EmailTextFormattedDocument.SetHTML(Text.HTMLText, Text.AttachmentsStructure);
		Object.TextType = Enums.EmailTextTypes.HTMLWithPictures;
		Object.Text = EmailTextFormattedDocument.GetText();
		
	ElsIf TypeOf(Text) = Type("String") AND Not IsBlankString(Text) Then
		
		If StrStartsWith(Lower(Text), Lower("<!DOCTYPE html")) Then
			Pictures = New Structure;
			If TypeOf(Parameters.Attachments) = Type("Array") Then
				For Index = -Parameters.Attachments.UBound() To 0 Do
					Attachment = Parameters.Attachments[-Index];
					If Attachment.Property("ID") AND ValueIsFilled(Attachment.ID) Then
						PictureAttachment = New Picture(GetFromTempStorage(Attachment.AddressInTempStorage));
						Pictures.Insert(Attachment.Presentation, PictureAttachment);
						If Interactions.SendEmailsInHTMLFormat() Then
							Parameters.Attachments.Delete(-Index);
						EndIf;
					EndIf;
				EndDo;
			EndIf;
			EmailTextFormattedDocument.SetHTML(Text, Pictures);
			Object.TextType = Enums.EmailTextTypes.HTMLWithPictures;
			Object.Text = EmailTextFormattedDocument.GetText();
			
		ElsIf Interactions.DefaultMessageFormat(Object.Author) = Enums.EmailEditingMethods.HTML Then
			
			EmailTextFormattedDocument.Add(Text);
			AttachmentPage = New Structure;
			EmailTextFormattedDocument.GetHTML(Object.HTMLText, AttachmentPage);
			
		Else
			Object.Text = Text;
		EndIf;
		
	EndIf;
	
EndProcedure

// Defines whether the base email needs to be displayed.
&AtServer
Procedure DisplayBaseEmail()
	
	If Not Object.InteractionBasis = Undefined AND NOT Object.InteractionBasis.IsEmpty()
		AND Object.EmailStatus = Enums.OutgoingEmailStatuses.Draft 
		AND (TypeOf(Object.InteractionBasis) = Type("DocumentRef.IncomingEmail")
		OR TypeOf(Object.InteractionBasis) = Type("DocumentRef.OutgoingEmail")) Then
		
		IncomingMessageAttributesValues = Common.ObjectAttributesValues(
			Object.InteractionBasis,"TextType,HTMLText,Text");
		
		IncomingEmailTextType = ?(IncomingMessageAttributesValues.TextType = Enums.EmailTextTypes.PlainText,
			Enums.EmailTextTypes.PlainText,
			Enums.EmailTextTypes.HTML);
		
		If GetFunctionalOption("SendEmailsInHTMLFormat") Then
			
			If IncomingMessageAttributesValues.TextType = Enums.EmailTextTypes.PlainText Then
				
				IncomingEmailText = IncomingMessageAttributesValues.Text;
				Items.IncomingEmailText.Type = FormFieldType.TextDocumentField;
				
			Else
				
				ReadOutgoingHTMLEmailText();
				Items.IncomingEmailText.Type = FormFieldType.HTMLDocumentField;
				Items.IncomingEmailText.ReadOnly = False
				
			EndIf;
			
			If Not Object.DisplaySourceEmailBody Then
				Items.IncomingGroup.Visible = False;
			Else
				Items.DisplayBaseEmailText.Check = True;
			EndIf;
			
		Else
			
			Items.IncomingGroup.Visible = False;
			EmailText = GenerateEmailTextIncludingBaseEmail(Undefined, Object);
			
		EndIf;
		
	Else
		
		Items.IncomingGroup.Visible = False;
		Items.DisplayBaseEmailText.Visible = False;
		
	EndIf;
	
EndProcedure

&AtServer
Function TextInsertionInEmailResult(EmailText, RowStart, ColumnStart, ColumnEnd, SelectedValue)
	
	TextDocument = New TextDocument;
	TextDocument.SetText(EmailText);
	InsertionRow = TextDocument.GetLine(RowStart);
	InsertionRow = Left(InsertionRow, ColumnStart - 1) + SelectedValue + Right(InsertionRow,StrLen(InsertionRow) - ColumnEnd + 1);
	TextDocument.ReplaceLine(RowStart, InsertionRow);
	Return TextDocument.GetText();
	
EndFunction

#EndRegion

&AtClient
Procedure SendExecute()
	
	ClearMessages();
	
	FoundRows = AvailableAccountsForSending.FindRows(New Structure("Account", Object.Account));
	If FoundRows.Count() = 0 Then
		CommonClientServer.MessageToUser(
			NStr("ru = 'Выбранная учетная запись не доступна для отправки писем'; en = 'The selected account is not available for sending emails'; pl = 'Wybrane konto nie jest dostępne do wysyłki wiadomości';es_ES = 'La cuenta seleccionada no está disponible para enviar correos electrónicos';es_CO = 'La cuenta seleccionada no está disponible para enviar correos electrónicos';tr = 'Seçilen hesap e-posta göndermek için kullanılamaz';it = 'L''account selezionato non è disponibile per l''invio di email';de = 'Das ausgewählte Konto ist für Senden von E-Mails nicht verfügbar'"),, "SenderPresentation", "Object");
		Return;
	EndIf;
	
	If FoundRows[0].DeleteAfterSend Then
			
		ButtonsList = New ValueList;
		ButtonsList.Add(DialogReturnCode.Yes, NStr("ru = 'Отправить'; en = 'Send'; pl = 'Wyślij';es_ES = 'Enviar';es_CO = 'Enviar';tr = 'Gönder';it = 'Inviare';de = 'Senden'"));
		ButtonsList.Add(DialogReturnCode.No, NStr("ru = 'Отправить и сохранить'; en = 'Send and save'; pl = 'Wyślij i zapisz';es_ES = 'Enviar y guardar';es_CO = 'Enviar y guardar';tr = 'Gönder ve kaydet';it = 'Inviare e salvare';de = 'Senden und speichern'"));
		ButtonsList.Add(DialogReturnCode.Cancel, NStr("ru = 'Отмена'; en = 'Cancel'; pl = 'Anuluj';es_ES = 'Cancelar';es_CO = 'Cancelar';tr = 'İptal';it = 'Annullare';de = 'Abbrechen'"));
		
		QuestionText = NStr("ru = 'Для данной учетной записи не предусмотрено сохранение отправленных писем в системе.
		                    |Продолжить?'; 
		                    |en = 'It is not required to save the sent emails for this account.
		                    |Continue?'; 
		                    |pl = 'Dla tego konta nie jest wymagane zapisywanie wysłanych wiadomości e-mail.
		                    |Kontynuować?';
		                    |es_ES = 'No se requiere guardar los correos electrónicos enviados a esta cuenta.
		                    | ¿Continuar?';
		                    |es_CO = 'No se requiere guardar los correos electrónicos enviados a esta cuenta.
		                    | ¿Continuar?';
		                    |tr = 'Bu hesap için, gönderilen e-postaların kaydedilmesi gerekmiyor.
		                    |Devam edilsin mi?';
		                    |it = 'Per questo account non è richiesto di salvare le email inviate. 
		                    |Continuare?';
		                    |de = 'Für dieses Konto ist Speichern der gesendeten E-Mails nicht erforderlich.
		                    |Fortfahren?'");
		
		CloseNotificationHandler = New NotifyDescription("PromptForNotSavingSentEmail", ThisObject);
		ShowQueryBox(CloseNotificationHandler,QuestionText, ButtonsList,, DialogReturnCode.Yes, NStr("ru = 'Отправка письма'; en = 'Sending email'; pl = 'Wysyłane wiadomości e-mail';es_ES = 'Envío de correo electrónico';es_CO = 'Envío de correo electrónico';tr = 'E-posta gönderiliyor';it = 'Invio email';de = 'E-Mail wird gesendet'"));
	Else
		SendEmailClient();
	EndIf;
	
EndProcedure

&AtClient
Procedure ForwardExecute()
	
	Basis = New Structure("Basis,Command", Object.Ref, "Forward");
	OpeningParameters = New Structure("Basis", Basis);
	OpenForm("Document.OutgoingEmail.Form.DocumentForm", OpeningParameters);

EndProcedure

&AtServer
Procedure SetButtonTitleByDefault()
	
	If Object.EmailStatus = Enums.OutgoingEmailStatuses.Sent Then
		Items.Send.Title = NStr("ru = 'Переслать'; en = 'Forward'; pl = 'Przekaż dalej';es_ES = 'Reenviar';es_CO = 'Reenviar';tr = 'Yönlendir';it = 'Inoltrare';de = 'Weiterleiten'");
	ElsIf Object.EmailStatus = Enums.OutgoingEmailStatuses.Outgoing Then
		Items.Send.Title = NStr("ru = 'Отправить сейчас'; en = 'Send now'; pl = 'Wyślij teraz';es_ES = 'Enviar ahora';es_CO = 'Enviar ahora';tr = 'Şimdi gönder';it = 'Inviare adesso';de = 'Jetzt senden'");
	ElsIf Object.EmailStatus = Enums.OutgoingEmailStatuses.Draft Then
		If Common.FileInfobase() Then
			EmailOperationSettings = Interactions.GetEmailOperationsSetting();
			If EmailOperationSettings.Property("SendMessagesImmediately") AND EmailOperationSettings.SendMessagesImmediately Then
				SendMessagesImmediately = True;
			EndIf;
		EndIf;
		
		Items.Send.Title = NStr("ru = 'Отправить'; en = 'Send'; pl = 'Wyślij';es_ES = 'Enviar';es_CO = 'Enviar';tr = 'Gönder';it = 'Inviare';de = 'Senden'");
		
	EndIf;
	
EndProcedure

&AtClient
Procedure MessageFormatOnChange()
	
	If Object.TextType <> PredefinedValue("Enum.EmailTextTypes.PlainText") 
		AND MessageFormat = PredefinedValue("Enum.EmailEditingMethods.NormalText") Then
		
		InteractionsClient.PromptOnChangeMessageFormatToPlainText(ThisObject);
		
	Else
		
		EmailTextFormattedDocument.Add(EmailText);
		Object.Text = "";
		Object.TextType =  PredefinedValue("Enum.EmailTextTypes.HTML");
		Items.EmailTextPages.CurrentPage = Items.FormattedDocumentPage;
		Items.MessageFormat.Title = MessageFormat;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure OnCreateAndOnReadAtServer()
	
	FileInfobase = Common.FileInfobase();
	Interactions.SetEmailFormHeader(ThisObject);
	SetButtonTitleByDefault();
	ProcessPassedParameters(Parameters);
	FillAttachments(Parameters);
	
	For Each EmailRecipient In Object.EmailRecipients Do
		If ValueIsFilled(EmailRecipient.Contact) Then
			AddressesAndContactsMaps.Add(EmailRecipient.Contact, EmailRecipient.Address);
		EndIf;
	EndDo;
	
	DefineItemsVisibilityAvailabilityDependingOnEmailStatus();
	DisplayBaseEmail();
	
	If Not Object.Ref.IsEmpty() Then
		Interactions.SetInteractionFormAttributesByRegisterData(ThisObject);
		CurrentEmailStatus = Object.EmailStatus;
	EndIf;
	
	UnderControl = NOT Reviewed;
	
	InteractionsClientServer.CheckContactsFilling(Object, ThisObject, "OutgoingEmail");
	
	If Object.EmailStatus = Enums.OutgoingEmailStatuses.Sent Then
		Items.Subject.TextEdit                  = False;
	EndIf;
	
	Items.CommentPage.Picture = CommonClientServer.CommentPicture(Object.Comment);
	
	GenerateEmailRecipientsLists();
	
EndProcedure 

&AtServerNoContext
Function FindContacts(Val SearchString)
	
	Result = New ValueList;
	ContactsTable = Interactions.FindContactsWithAddresses(SearchString);
	For each Selection In ContactsTable Do
		ChoiceValue = New Structure;
		ChoiceValue.Insert("Contact", Selection.Contact);
		ChoiceValue.Insert("Address", Selection.Presentation);
		ChoiceValue.Insert("Presentation", Selection.Description);
		ChoiceValue.Insert("IndexInRecipientsList", 0);
		Result.Add(ChoiceValue, 
			InteractionsClientServer.GetAddresseePresentation(Selection.Description, Selection.Presentation, ""));
	EndDo;
	Return Result;
	
EndFunction 

&AtClient
Function GetBaseIDsPresentation(Val IDs)

	IDs = StrReplace(IDs, "<",  " ");
	IDs = StrReplace(IDs, ">",  " ");
	IDs = StrReplace(IDs, "  ", " ");
	IDs = TrimAll(StrReplace(IDs, "  ", " "));
	IDs = StrReplace(IDs, " ", Chars.LF + "                          ");
	
	Return IDs;

EndFunction

&AtClient
Procedure EditRecipientsList(ToSelect, SelectionGroup = "")
	
	Object.EmailRecipients.Clear();
	Object.CCRecipients.Clear();
	Object.BccRecipients.Clear();
	Object.ReplyRecipients.Clear();
	For each Recipient In RecipientsList Do
		If Recipient.SendingOption = NStr("ru = 'Обратный адрес:'; en = 'Return address:'; pl = 'Adres zwrotny:';es_ES = 'Dirección de devolución:';es_CO = 'Dirección de devolución:';tr = 'İade adresi:';it = 'Indirizzo di ritorno:';de = 'Rücksendeadresse:'") Then
			NewRow = Object.ReplyRecipients.Add();
		ElsIf Recipient.SendingOption = NStr("ru = 'Копия:'; en = 'Copy:'; pl = 'Kopia:';es_ES = 'Copia:';es_CO = 'Copia:';tr = 'Kopya:';it = 'Copia:';de = 'Kopie:'") Then
			NewRow = Object.CCRecipients.Add();
		ElsIf Recipient.SendingOption = NStr("ru = 'Скрытая копия:'; en = 'BCC:'; pl = 'UDW:';es_ES = 'Copia oculta:';es_CO = 'Copia oculta:';tr = 'Bcc:';it = 'Ccn:';de = 'BCC:'") Then
			NewRow = Object.BccRecipients.Add();
		Else
			NewRow = Object.EmailRecipients.Add();
		EndIf;
		FillPropertyValues(NewRow, Recipient);
	EndDo;
	
	// Getting an addressee list
	TabularSectionsMap = New Map;
	TabularSectionsMap.Insert("SendTo", Object.EmailRecipients);
	TabularSectionsMap.Insert("Cc", Object.CCRecipients);
	TabularSectionsMap.Insert("Hidden", Object.BccRecipients);
	TabularSectionsMap.Insert("Response", Object.ReplyRecipients);
	
	SelectedItemsList = New ValueList;
	For Each TabularSection In TabularSectionsMap Do
		SelectedItemsList.Add(
			EmailManagementClient.ContactsTableToArray(TabularSection.Value), TabularSection.Key);
	EndDo;

	OpeningParameters = New Structure;
	OpeningParameters.Insert("Account", Object.Account);
	OpeningParameters.Insert("SelectedItemsList", SelectedItemsList);
	OpeningParameters.Insert("Topic", Topic);
	OpeningParameters.Insert("Email", Object.Ref);
	OpeningParameters.Insert("DefaultGroup", ?(IsBlankString(SelectionGroup), NStr("ru = 'Кому'; en = 'SendTo'; pl = 'Wyślij do';es_ES = 'Envía a';es_CO = 'Envía a';tr = 'Kime';it = 'Invia a';de = 'Gesendet an'"), SelectionGroup));
	
	// Opening a form to edit an addressee list.
	NotificationAfterClose = New NotifyDescription("AfterFillAddressBook", ThisObject);
	CommonFormName = ?(ToSelect, "CommonForm.AddressBookForEmail", "CommonForm.ContactsClarification");
	
	OpenForm(CommonFormName, OpeningParameters, ThisObject,,,, NotificationAfterClose);
	
EndProcedure

&AtClient
Procedure AfterFillAddressBook(SelectedValue, AdditionalParameters) Export
	
	FillSelectedRecipientsAfterChoice(SelectedValue);
	
EndProcedure

&AtClient
Procedure FillSelectedRecipientsAfterChoice(SelectedValue)
	
	If TypeOf(SelectedValue) <> Type("Array") AND TypeOf(SelectedValue) <> Type("Map") Then
		Return;
	EndIf;
	
	// Getting an addressee list
	TabularSectionsMap = New Map;
	TabularSectionsMap.Insert("SendTo", Object.EmailRecipients);
	TabularSectionsMap.Insert("Cc", Object.CCRecipients);
	TabularSectionsMap.Insert("Hidden", Object.BccRecipients);
	TabularSectionsMap.Insert("To", Object.ReplyRecipients);
	
	ToSelect = (Object.EmailStatus <> PredefinedValue("Enum.OutgoingEmailStatuses.Sent"));
	
	// Filling in addressees
	If ToSelect Then
		FillSelectedRecipients(TabularSectionsMap, SelectedValue);
	Else
		FillClarifiedContacts(SelectedValue);
	EndIf;
	
	// Setting a modification flag.
	InteractionsClientServer.CheckContactsFilling(Object, ThisObject, "OutgoingEmail");
	ContactsChanged = True;
	Modified = True;

EndProcedure

&AtClient
Procedure FillSelectedRecipients(TabularSectionsMap, Result)

	For Each TabularSection In TabularSectionsMap Do
		TabularSection.Value.Clear();
	EndDo;
	
	AddressesAddedEarlierArray = New Array;
	
	For Each Item In Result Do
		
		TabularSection = TabularSectionsMap.Get(Item.Group);
		If TabularSection = Undefined Then
			TabularSection = Object.EmailRecipients;
		EndIf;
		
		If AddressesAddedEarlierArray.Find(Item.Address) <> Undefined Then
			Continue;
		EndIf;
		
		NewRow = TabularSection.Add();
		NewRow.Address         = Item.Address;
		NewRow.Presentation = ProcessedAddresseePresentation(Item.Presentation);
		NewRow.Contact       = Item.Contact;
		
		AddressesAddedEarlierArray.Add(NewRow.Address);
		
	EndDo;
	
	ClearAddresseesDuplicates(Object.EmailRecipients);
	
	GenerateRecipientsLists();
	
EndProcedure

&AtClient
Procedure GenerateRecipientsLists()

	Object.EmailRecipientsList =
		InteractionsClientServer.GetAddressesListPresentation(Object.EmailRecipients, False);
	Object.CcRecipientsList =
		InteractionsClientServer.GetAddressesListPresentation(Object.CCRecipients, False);
	Object.BccRecipientsList = 
		InteractionsClientServer.GetAddressesListPresentation(Object.BccRecipients, False);

	GenerateEmailRecipientsLists();
	
EndProcedure

&AtServer
Procedure GenerateEmailRecipientsLists()
	
	RecipientsList.Clear();
	
	AddAddressToRecipientsList(RecipientsList, Object.EmailRecipients, NStr("ru = 'Кому:'; en = 'To:'; pl = 'Do:';es_ES = 'Para:';es_CO = 'Para:';tr = 'Kime:';it = 'A:';de = 'An:'"));
	AddAddressToRecipientsList(RecipientsList, Object.CCRecipients, NStr("ru = 'Копия:'; en = 'Copy:'; pl = 'Kopia:';es_ES = 'Copia:';es_CO = 'Copia:';tr = 'Kopya:';it = 'Copia:';de = 'Kopie:'"));
	AddAddressToRecipientsList(RecipientsList, Object.BccRecipients, NStr("ru = 'Скрытая копия:'; en = 'BCC:'; pl = 'UDW:';es_ES = 'Copia oculta:';es_CO = 'Copia oculta:';tr = 'Bcc:';it = 'Ccn:';de = 'BCC:'"));
	AddAddressToRecipientsList(RecipientsList, Object.ReplyRecipients, NStr("ru = 'Обратный адрес:'; en = 'Return address:'; pl = 'Adres zwrotny:';es_ES = 'Dirección de devolución:';es_CO = 'Dirección de devolución:';tr = 'İade adresi:';it = 'Indirizzo di ritorno:';de = 'Rücksenderadresse:'"));
	
	If RecipientsList.Count() = 0 Then
		NewRow = RecipientsList.Add();
		NewRow.SendingOption = "SendTo:";
	EndIf;
	
EndProcedure

&AtServer
Procedure AddAddressToRecipientsList(RecipientsList, EmailRecipients, SendTo)

	For each RecipientRow In EmailRecipients Do
		NewRow = RecipientsList.Add();
		NewRow.SendingOption = SendTo;
		NewRow.Address           = RecipientRow.Address;
		NewRow.Contact         = RecipientRow.Contact;
		NewRow.Presentation   = InteractionsClientServer.GetAddresseePresentation(RecipientRow.Presentation, 
			RecipientRow.Address, "");
	EndDo;
		
EndProcedure

&AtClient
Procedure FillClarifiedContacts(Result)
	
	Object.CCRecipients.Clear();
	Object.ReplyRecipients.Clear();
	Object.EmailRecipients.Clear();
	Object.BccRecipients.Clear();
	
	For each ArrayElement In Result Do
	
		If ArrayElement.Group = "SendTo" Then
			RecipientsTable = Object.EmailRecipients;
		ElsIf ArrayElement.Group = "Cc" Then
			RecipientsTable = Object.CCRecipients;
		ElsIf ArrayElement.Group = "Hidden" Then
			RecipientsTable = Object.BccRecipients;
		Else
			RecipientsTable = Object.ReplyRecipients;
		EndIf;
		
		RowRecipients = RecipientsTable.Add();
		FillPropertyValues(RowRecipients, ArrayElement);
	
	EndDo;
	
	GenerateRecipientsLists();

EndProcedure

&AtClient
Procedure ShowEmailAddressRequiredMessage()
	ShowMessageBox(, NStr("ru = 'Необходимо ввести адрес электронной почты'; en = 'Enter an email address'; pl = 'Wprowadź adres e-mail';es_ES = 'Es necesario introducir la dirección de correo electrónico';es_CO = 'Es necesario introducir la dirección de correo electrónico';tr = 'E-posta adresi girin';it = 'Inserire un indirizzo email';de = 'Eine E-Mail-Adresse eingeben'"));
EndProcedure

&AtServer
Function ExecuteSendingAtServer()
	
	EmailObject = FormAttributeToValue("Object");
	
	Result = New Structure;
	Result.Insert("MessageText", "");
	Result.Insert("EmailSent", False);
	
	Try
		
		EmailParameters = Undefined;
		OutgoingMailServerName = Common.ObjectAttributeValue(Object.Account, "OutgoingMailServer", True);
		Interactions.ExecuteEmailSending(EmailObject,, EmailParameters);
		
	Except
		
		WrongRecipientsAnalysisData = EmailManagement.WrongRecipientsAnalysisResult(EmailObject, EmailParameters.WrongRecipients);
		IsIssueOfEmailAddressesServerRejection = WrongRecipientsAnalysisData.IsIssueOfEmailAddressesServerRejection;
		AllEmailAddresseesRejectedByServer           = WrongRecipientsAnalysisData.AllEmailAddresseesRejectedByServer;
		WrongAddresseesPresentation               = WrongRecipientsAnalysisData.WrongAddresseesPresentation;
		
		If IsIssueOfEmailAddressesServerRejection AND Not AllEmailAddresseesRejectedByServer Then
			Result.MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Следующие адресаты электронного письма не приняты почтовым сервером:
				|%1. Письмо отправлено остальным адресатам.'; 
				|en = 'The following email addressees are not accepted by the mail server:
				|%1. Email is sent to other addressees.'; 
				|pl = 'Następujące adresy e-mail nie są przyjęte przez serwer pocztowy:
				|%1. Wiadomość e-mail wysłana na pozostałe adresy.';
				|es_ES = 'Los siguientes destinatarios de correo electrónico no son aceptados por el servidor de correo:
				|%1. El correo electrónico se enviará a otros destinatarios.';
				|es_CO = 'Los siguientes destinatarios de correo electrónico no son aceptados por el servidor de correo:
				|%1. El correo electrónico se enviará a otros destinatarios.';
				|tr = 'Şu e-posta alıcıları posta sunucusu tarafından kabul edilmedi:
				|%1. E-posta diğer alıcılara gönderildi.';
				|it = 'I seguenti destinatari email non sono accettati dal server mail: 
				|%1. L''email è inviata ad altri destinatari.';
				|de = 'Die folgenden E-Mail-Adressen sind durch den Mail-Server nicht akzeptiert:
				|%1. E-Mail ist an andere Adressen gesendet.'", CommonClientServer.DefaultLanguageCode()),
				WrongAddresseesPresentation);
		Else
			ValueToFormAttribute(EmailObject, "Object");
			Result.MessageText = BriefErrorDescription(ErrorInfo());
			Return Result;
		EndIf;
		
	EndTry;
	
	EmailID = EmailParameters.MessageID;
	Result.EmailSent = True;
	
	BeginTransaction();
	Try
		Lock = New DataLock;
		LockItem = Lock.Add("Document.OutgoingEmail");
		LockItem.SetValue("Ref", Object.Ref);
		InformationRegisters.InteractionsFolderSubjects.BlockInteractionFoldersSubjects(Lock, Object.Ref);
		Lock.Lock();
		
		If NOT EmailObject.DeleteAfterSend Then
			EmailObject.EmailStatus    = Enums.OutgoingEmailStatuses.Sent;
			EmailObject.PostingDate = CurrentSessionDate();
			EmailObject.Write(DocumentWriteMode.Write);
			ValueToFormAttribute(EmailObject, "Object");
			
			Interactions.SetEmailFolder(Object.Ref, Interactions.DefineFolderForEmail(Object.Ref));
			CurrentEmailStatus = Object.EmailStatus;
		Else
			EmailObject.Read();
			EmailObject.Delete();
		EndIf;
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;	
	Return Result;
	
EndFunction

&AtServer
Function EstimateEmailSize()

	Size = StrLen(Object.Subject)*2;
	Size = Size + ?(Object.TextType = Enums.EmailTextTypes.HTML,
	                    StrLen(Object.HTMLText),
	                    StrLen(Object.Text)) * 2;
	
	For each Attachment In Attachments Do
		Size = Size + Attachment.Size * 1.5;
	EndDo;
	
	For each MapsTableRow In AttachmentsNamesToIDsMapsTable Do
		Size = Size + MapsTableRow.Picture.GetBinaryData().Size()*1.5;
	EndDo;
	
	Return Size;

EndFunction

&AtServer
Function FileAttributes(File)
	
	RequiredAttributes = "Description, Extension, PictureIndex, Size";
	
	If Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		RequiredAttributes = RequiredAttributes + ", SignedWithDS";
	EndIf;
	
	Return Common.ObjectAttributesValues(File, RequiredAttributes);
	
EndFunction

&AtClient
Procedure SendEmailClient()
	
	If Not SendMessagesImmediately Then
		SendMessagesImmediately = (
			Object.EmailStatus = PredefinedValue("Enum.OutgoingEmailStatuses.Outgoing"));
	EndIf;
	
	Sending = True;
	
	If Object.Ref.IsEmpty() 
		Or Modified 
		Or Object.IncludeOriginalEmailBody 
		Or (Object.EmailStatus = PredefinedValue("Enum.OutgoingEmailStatuses.Draft")) Then
		Write();
	EndIf;
	
	Sending = False;
	
	If Modified Then
		Return;
	EndIf;
	
	If SendMessagesImmediately Then
		Result = ExecuteSendingAtServer();
	Else
		Close();
		Return;
	EndIf;
	
	If Result.EmailSent 
		AND Result.MessageText = "" Then
		
		Close();
	
	ElsIf Result.EmailSent 
		AND Result.MessageText <> "" Then
		
		Read();
		ShowMessageBox(, Result.MessageText);
		
	ElsIf Result.MessageText <> "" Then
		
		ShowMessageBox(, Result.MessageText);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure PromptForNotSavingSentEmail(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult = DialogReturnCode.Yes Then
		Object.DeleteAfterSend = True;
	ElsIf QuestionResult = DialogReturnCode.No Then
		Object.DeleteAfterSend = False;
	ElsIf QuestionResult = DialogReturnCode.Cancel Then
		Return;
	EndIf;
	
	SendEmailClient();
	
EndProcedure

&AtClient
Procedure PromptOnChangeFormatOnClose(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult <> DialogReturnCode.Yes Then
		MessageFormat = PredefinedValue("Enum.EmailEditingMethods.HTML");
	Else
		EmailText = EmailTextFormattedDocument.GetText();
		Object.TextType = PredefinedValue("Enum.EmailTextTypes.PlainText");
		EmailTextFormattedDocument.Delete();
		Items.EmailText.Type = FormFieldType.TextDocumentField;
		Object.HTMLText = "";
		Object.Encoding = "UTF-8";
		Items.EmailTextPages.CurrentPage = Items.PlainTextPage;
	EndIf;
		
	Items.MessageFormat.Title = MessageFormat;
	
EndProcedure

&AtClient
Procedure OpenAttachmentProperties(CurrentIndexInCollection)
	
	CurrentData = Attachments.Get(CurrentIndexInCollection);
	If CurrentData = Undefined Then
		Return;
	EndIf;
	Items.Attachments.CurrentRow = CurrentData.GetID();
		
	FileAvailableForEditing = 
		(Object.EmailStatus = PredefinedValue("Enum.OutgoingEmailStatuses.Draft"));
	FormParameters = New Structure("AttachedFile, ReadOnly", 
		CurrentData.Ref,NOT FileAvailableForEditing);
	OpenForm("DataProcessor.FilesOperations.Form.AttachedFile", FormParameters,, CurrentData.Ref);
	
EndProcedure

&AtServer
Procedure ChangeSignature(PreviousAccount, NewAccount)

	ParametersPreviousAccount =
			Interactions.GetUserParametersForOutgoingEmail(
			PreviousAccount,
			MessageFormat,
			?(Object.InteractionBasis = Undefined, True, False));
			
	ParametersNewAccount =
			Interactions.GetUserParametersForOutgoingEmail(
			NewAccount,
			MessageFormat,
			?(Object.InteractionBasis = Undefined, True, False));
	
	If MessageFormat = Enums.EmailEditingMethods.NormalText Then
		If IsBlankString(EmailText) Then
			EmailText = ParametersNewAccount.Signature;
		Else
			If StrOccurrenceCount(EmailText, ParametersPreviousAccount.Signature) > 0 Then
				EmailText = StrReplace(EmailText, ParametersPreviousAccount.Signature, ParametersNewAccount.Signature);
			Else
				EmailText = EmailText + ParametersNewAccount.Signature;
			EndIf;
		EndIf;
	Else
		
		
		TextEmail = EmailTextFormattedDocument.GetText();
		If IsBlankString(TextEmail) Then
			
			EmailTextFormattedDocument = ParametersNewAccount.Signature;
			
		Else
			
			If TypeOf(ParametersPreviousAccount.Signature) = Type("FormattedDocument") Then
				
				TextPreviousAccount = ParametersPreviousAccount.Signature.GetText();
				
				If StrOccurrenceCount(TextEmail, TextPreviousAccount) > 0 Then
					
					DeleteOldSignatureItems(EmailTextFormattedDocument,ParametersPreviousAccount.Signature);
					
				EndIf;
				
				If TypeOf(ParametersNewAccount.Signature) = Type("FormattedDocument") Then
					AddFormattedDocumentToFormattedDocument(EmailTextFormattedDocument, ParametersNewAccount.Signature);
				EndIf;
			
			EndIf;
			
		EndIf;
		
	EndIf;

EndProcedure

&AtServer
Procedure DeleteOldSignatureItems(EmailTextFormattedDocument, OldSignature)

	HTMLTextFormattedDocument = "";
	AttachmentsFormattedDocument = New Structure;
	
	EmailTextFormattedDocument.GetHTML(HTMLTextFormattedDocument, AttachmentsFormattedDocument);
	
	HTMLTextOldSignature = "";
	AttachmentsOldSignature = New Structure;
	
	OldSignature.GetHTML(HTMLTextOldSignature, AttachmentsOldSignature);

	HTMLTextOldSignature = Interactions.HTMLTagContent(HTMLTextOldSignature,"body");
	HTMLTextFormattedDocument = StrReplace(HTMLTextFormattedDocument, HTMLTextOldSignature, "");
	EmailTextFormattedDocument.SetHTML(HTMLTextFormattedDocument, AttachmentsFormattedDocument);
	
EndProcedure

&AtServer
Procedure AddFormattedDocumentToFormattedDocument(DocumentRecipient, DocumentToAdd)

	For Ind = 0 To DocumentToAdd.Items.Count() -1 Do
		ItemToAdd = DocumentToAdd.Items[Ind];
		If TypeOf(ItemToAdd) = Type("FormattedDocumentParagraph") Then
			NewParagraph = DocumentRecipient.Items.Add();
			FillPropertyValues(NewParagraph, ItemToAdd, "ParagraphType, HorizontalAlign, LineSpacing,Indent");
			AddFormattedDocumentToFormattedDocument(NewParagraph, ItemToAdd);
		Else
			If TypeOf(ItemToAdd) = Type("FormattedDocumentText")
				AND Not ItemToAdd.Text = "" Then
				NewItem = DocumentRecipient.Items.Add(ItemToAdd.Text, Type("FormattedDocumentText"));
				FillPropertyValues(NewItem,ItemToAdd,,"EndBookmark, BeginBookmark, Parent");
			ElsIf TypeOf(ItemToAdd) = Type("FormattedDocumentPicture") Then
				NewItem = DocumentRecipient.Items.Add(ItemToAdd.Picture, Type("FormattedDocumentPicture"));
				FillPropertyValues(NewItem,ItemToAdd,,"EndBookmark, BeginBookmark, Parent");
			ElsIf TypeOf(ItemToAdd) = Type("FormattedDocumentLinefeed") Then
				If TypeOf(DocumentToAdd) = Type("FormattedDocumentParagraph") 
					AND (DocumentToAdd.ParagraphType = ParagraphType.BulletedList
					Or DocumentToAdd.ParagraphType = ParagraphType.NumberedList) Then
					Continue;
				EndIf;
				NewItem = DocumentRecipient.Items.Add( , Type("FormattedDocumentLinefeed"));
			EndIf;
		EndIf;
	EndDo;

EndProcedure

&AtClientAtServerNoContext
Procedure ClearAddresseesDuplicates(RecipientsTable)
	
	MapOfRowsAddressesToDelete = New Map;
	
	For Each RecipientRow In RecipientsTable Do
		If MapOfRowsAddressesToDelete.Get(RecipientRow.Address) <> Undefined Then
			Continue;
		EndIf;
		FoundRows =  RecipientsTable.FindRows(New Structure("Address", RecipientRow.Address));
		If FoundRows.Count() > 1 Then
			ArrayToDelete = New Array;
			For Ind = 0 To FoundRows.Count() - 1 Do
				If Ind = 0 Then
					If NOT ValueIsFilled(FoundRows[Ind].Contact) Then
						ArrayToDelete.Add(FoundRows[Ind]);
					EndIf;
				Else
					If ArrayToDelete.Count() = 0 OR (NOT ValueIsFilled(FoundRows[Ind].Contact)) Then
						ArrayToDelete.Add(FoundRows[Ind]);
					ElsIf ValueIsFilled(FoundRows[Ind].Contact) AND NOT (Ind = ArrayToDelete.Count()) Then
						ArrayToDelete.Add(FoundRows[Ind]);
					EndIf;
				EndIf;
				
			EndDo;
			
			If FoundRows.Count() = ArrayToDelete.Count() Then
				ArrayToDelete.Delete(0);
			EndIf;
			
			MapOfRowsAddressesToDelete.Insert(RecipientRow.Address,ArrayToDelete);
			
		EndIf;
	EndDo;
	
	For Each MapRow In MapOfRowsAddressesToDelete Do
		For Each RowToDelete In MapRow.Value Do
			RecipientsTable.Delete(RowToDelete);
		EndDo;
	EndDo;

EndProcedure

&AtClient
Function EmailAttachmentParameters()
	
	AttachmentParameters = InteractionsClient.EmptyStructureOfAttachmentEmailParameters();
	AttachmentParameters.BaseEmailDate = ?(ValueIsFilled(Object.PostingDate), Object.PostingDate , Object.Date);
	AttachmentParameters.EmailBasis     = Object.Ref;
	AttachmentParameters.BaseEmailSubject = Object.Subject;
	
	Return AttachmentParameters;
	
EndFunction

&AtClient
Procedure AfterPutFile(Result, AdditionalParameters) Export
	
	If Result <> Undefined Then
		If Not IsBlankString(Result.ErrorDescription) Then
			Raise Result.ErrorDescription;
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterQuestionOnClose(Result, AdditionalParameters) Export

	If Result = DialogReturnCode.Yes Then
		WrittenSuccessfully = Write();
		If WrittenSuccessfully Then
			Close();
		EndIf;
	ElsIf Result = DialogReturnCode.No 
		AND AdditionalParameters.FilesToEditArray.Count() > 0 Then
		
		FilesOperationsInternalServerCall.UnlockFiles(AdditionalParameters.FilesToEditArray);
		Modified = False;
		Close();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure FillTabularSectionsByRecipientsList()
	
	Object.EmailRecipients.Clear();
	Object.CCRecipients.Clear();
	Object.BccRecipients.Clear();
	Object.ReplyRecipients.Clear();
	For each Recipient In RecipientsList Do
		
		MailAddresses = CommonClientServer.EmailsFromString(Recipient.Presentation);
		
		For each EmailAddress In MailAddresses Do
			
			If Recipient.SendingOption = NStr("ru = 'Обратный адрес:'; en = 'Return address:'; pl = 'Adres zwrotny:';es_ES = 'Dirección de devolución:';es_CO = 'Dirección de devolución:';tr = 'İade adresi:';it = 'Indirizzo di ritorno:';de = 'Rücksendeadresse:'") Then
				NewString = Object.ReplyRecipients.Add();
			ElsIf Recipient.SendingOption = NStr("ru = 'Копия:'; en = 'Copy:'; pl = 'Kopia:';es_ES = 'Copia:';es_CO = 'Copia:';tr = 'Kopya:';it = 'Copia:';de = 'Kopie:'") Then
				NewString = Object.CCRecipients.Add();
			ElsIf Recipient.SendingOption = NStr("ru = 'Скрытая копия:'; en = 'BCC:'; pl = 'UDW:';es_ES = 'Copia oculta:';es_CO = 'Copia oculta:';tr = 'Bcc:';it = 'Ccn:';de = 'BCC:'") Then
				NewString = Object.BccRecipients.Add();
			Else
				NewString = Object.EmailRecipients.Add();
			EndIf;
			
			NewString.Address = EmailAddress.Address;
			NewString.Presentation = EmailAddress.Alias;
			NewString.Contact = Recipient.Contact;
		EndDo;
		
	EndDo;
	
EndProcedure

// StandardSubsystems.Properties

&AtServer
Procedure PropertiesExecuteDeferredInitialization()
	
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.FillAdditionalAttributesInForm(ThisObject);
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_OnChangeAdditionalAttribute(Item)
	
	If CommonClient.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerClient = CommonClient.CommonModule("PropertyManagerClient");
		ModulePropertyManagerClient.UpdateAdditionalAttributesDependencies(ThisObject);
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdateAdditionalAttributesItems()
	
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.UpdateAdditionalAttributesItems(ThisObject);
	EndIf;
	
EndProcedure

&AtClient
Procedure UpdateAdditionalAttributesDependencies()
	
	If CommonClient.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerClient = CommonClient.CommonModule("PropertyManagerClient");
		ModulePropertyManagerClient.UpdateAdditionalAttributesDependencies(ThisObject);
	EndIf;
	
EndProcedure

// End StandardSubsystems.Properties

// StandardSubsystems.MessagesTemplates

&AtClient
Procedure FillByTemplateAfterTemplateChoice(Result, AdditionalParameters) Export
	If Result <> Undefined AND TypeOf(Result) = Type("Structure") AND Result.Property("Template") Then
		FillTemplateAfterChoice(Result.Template);
	EndIf;
EndProcedure

&AtServer
Procedure FillTemplateAfterChoice(TemplateRef)
	
	ObjectEmail = FormAttributeToValue("Object");
	ObjectEmail.Fill(TemplateRef);
	ValueToFormAttribute(ObjectEmail, "Object");
	OnCreateAndOnReadAtServer();
	
EndProcedure

&AtServer
Procedure DeterminePossibilityToFillEmailByTemplate()
	
	MessagesTemplatesUsed = False;
	If Object.EmailStatus = Enums.OutgoingEmailStatuses.Draft
		AND Common.SubsystemExists("StandardSubsystems.MessageTemplates") Then
		ModuleMessagesTemplatesInternal = Common.CommonModule("MessageTemplatesInternal");
		If ModuleMessagesTemplatesInternal.MessagesTemplatesUsed() Then
			MessagesTemplatesUsed = ModuleMessagesTemplatesInternal.HasAvailableTemplates("Email", Topic);
		EndIf;
	EndIf;
	Items.FormGenerateFromTemplate.Visible = MessagesTemplatesUsed;
	
EndProcedure

// End StandardSubsystems.MessagesTemplates

&AtServer
Procedure SetSecurityWarningVisiblity()
	UnsafeContentDisplayInEmailsProhibited = Interactions.UnsafeContentDisplayInEmailsProhibited();
	Items.SecurityWarning.Visible = Not UnsafeContentDisplayInEmailsProhibited
		AND HasUnsafeContent AND Not EnableUnsafeContent;
EndProcedure

&AtServer
Procedure ReadOutgoingHTMLEmailText()
	IncomingEmailText = Interactions.ProcessHTMLText(Object.InteractionBasis,
		Not EnableUnsafeContent, HasUnsafeContent);
	SetSecurityWarningVisiblity();
EndProcedure

#EndRegion

// StandardSubsystems.AttachableCommands
&AtClient
Procedure Attachable_ExecuteCommand(Command)
	ModuleAttachableCommandsClient = CommonClient.CommonModule("AttachableCommandsClient");
	ModuleAttachableCommandsClient.StartCommandExecution(ThisObject, Command, Object);
EndProcedure

&AtClient
Procedure Attachable_ContinueCommandExecutionAtServer(ExecutionParameters, AdditionalParameters) Export
	ExecuteCommandAtServer(ExecutionParameters);
EndProcedure

&AtServer
Procedure ExecuteCommandAtServer(ExecutionParameters)
	ModuleAttachableCommands = Common.CommonModule("AttachableCommands");
	ModuleAttachableCommands.ExecuteCommand(ThisObject, ExecutionParameters, Object);
EndProcedure

&AtClient
Procedure Attachable_UpdateCommands()
	ModuleAttachableCommandsClientServer = CommonClient.CommonModule("AttachableCommandsClientServer");
	ModuleAttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
EndProcedure
// End StandardSubsystems.AttachableCommands

#EndRegion
