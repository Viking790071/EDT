// ------------------------------------------------------------------------------
// PARAMETERS SPECIFICATION PASSED TO FORM
//
// see CommonForms.EmailMessage
// ------------------------------------------------------------------------------
//FORM FUNCTIONING SPECIFICATION
//
//   If the accounts are not passed, then the account is filled out with the default user setting. If setting is not
//   specified, then the available user accounts are suggested to the user.
//
//   If files for attachments exists on 1C:Enterprise
// server as the parameter it is necessary non binary data, but
// the data link in temporary storage.
//
// ------------------------------------------------------------------------------

#Region Variables

#Region ModuleVariables

&AtClient
Var NormalizedPostalAddress; // Converted mail address

#EndRegion

#EndRegion

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	TypeArray = New Array;
	TypeArray.Add(Type("String"));
	Items.ContactRecipients.TypeRestriction	= New TypeDescription(TypeArray, New StringQualifiers(100));
	Items.Subject.TypeRestriction			= New TypeDescription(TypeArray, New StringQualifiers(200));
	
	If Parameters.Key.IsEmpty() Then
		FillNewEmailDefault();
		HandlePassedParameters(Parameters, Cancel);
	EndIf;
	
	SetBasisDocumentHyperlinkTitle();
	
	// Subject history for automatic selection
	ImportSubjectHistoryByString();
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Properties
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ItemForPlacementName", "AdditionalAttributesGroup");
	PropertyManager.OnCreateAtServer(ThisObject, AdditionalParameters);
	// End StandardSubsystems.Properties

EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	// StandardSubsystems.Properties
	PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	// End StandardSubsystems.Properties
EndProcedure

&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If Upper(ChoiceSource.FormName) = Upper("CommonForm.PasswordConfirmation") Then
		
		ContinueSendingEmailsWithPassword(ValueSelected);
		
	EndIf;
	
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
	
	Images = CurrentObject.ImagesHTML.Get();
	If Images = Undefined Then
		Images = New Structure;
	EndIf;
	FormattedDocument.SetHTML(CurrentObject.ContentHTML, Images);
	
	Attachments.Clear();
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	EventAttachedFiles.Ref,
	|	EventAttachedFiles.Description,
	|	EventAttachedFiles.Extension,
	|	EventAttachedFiles.PictureIndex
	|FROM
	|	Catalog.EventAttachedFiles AS EventAttachedFiles
	|WHERE
	|	EventAttachedFiles.FileOwner = &FileOwner
	|	AND EventAttachedFiles.DeletionMark = FALSE";
	
	Query.SetParameter("FileOwner", Object.Ref);
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		NewRow = Attachments.Add();
		NewRow.Ref                    = Selection.Ref;
		NewRow.Presentation             = Selection.Description + ?(IsBlankString(Selection.Extension), "", "." + Selection.Extension);
		NewRow.PictureIndex            = Selection.PictureIndex;
		NewRow.AddressInTemporaryStorage = PutToTempStorage(AttachedFiles.GetBinaryFileData(Selection.Ref), UUID);
		
	EndDo;
	
	// StandardSubsystems.Properties
	PropertyManager.OnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
	// StandardSubsystems.EditProhibitionDates
	PeriodClosingDates.ObjectOnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.EditProhibitionDates
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	HTMLText = "";
	Images = New Structure;
	FormattedDocument.GetHTML(HTMLText, Images);
	
	CurrentObject.ContentHTML = HTMLText;
	CurrentObject.ImagesHTML = New ValueStorage(Images);
	CurrentObject.Content = FormattedDocument.GetText();
	
	If TypeOf(CurrentObject.Subject) = Type("String") Then
	// Save subjects in history for automatic selection
		
		HistoryItem = SubjectRowHistory.FindByValue(TrimAll(CurrentObject.Subject));
		If HistoryItem <> Undefined Then
			SubjectRowHistory.Delete(HistoryItem);
		EndIf;
		SubjectRowHistory.Insert(0, TrimAll(CurrentObject.Subject));
		
		While SubjectRowHistory.Count() > 30 Do
			SubjectRowHistory.Delete(SubjectRowHistory.Count() - 1);
		EndDo;
		
		Common.CommonSettingsStorageSave("ThemeEventsChoiceList", "", SubjectRowHistory.UnloadValues());
		
	EndIf;
	
	// StandardSubsystems.Properties
	PropertyManager.BeforeWriteAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	Attachments.Ref AS Ref,
		|	Attachments.AddressInTemporaryStorage,
		|	Attachments.Presentation
		|INTO secAttachments
		|FROM
		|	&Attachments AS Attachments
		|
		|INDEX BY
		|	Ref
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	EventAttachedFiles.Ref
		|INTO ttAttachedFiles
		|FROM
		|	Catalog.EventAttachedFiles AS EventAttachedFiles
		|WHERE
		|	EventAttachedFiles.FileOwner = &EventRef
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	secAttachments.Ref AS AttachmentRefs,
		|	ttAttachedFiles.Ref AS AttachedFileRef,
		|	secAttachments.AddressInTemporaryStorage,
		|	secAttachments.Presentation
		|FROM
		|	secAttachments AS secAttachments
		|		Full JOIN ttAttachedFiles AS ttAttachedFiles
		|		ON secAttachments.Ref = ttAttachedFiles.Ref";
	
	Query.SetParameter("Attachments", Attachments.Unload());
	Query.SetParameter("EventRef", CurrentObject.Ref);
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		If Selection.AttachedFileRef = NULL Then
		// Add attachment to the attached files
			
			If Not IsBlankString(Selection.AddressInTemporaryStorage) Then
				
				FileNameParts = StringFunctionsClientServer.SplitStringIntoSubstringsArray(Selection.Presentation, ".", False);
				If FileNameParts.Count() > 1 Then
					ExtensionWithoutDot = FileNameParts[FileNameParts.Count()-1];
					NameWithoutExtension = Left(Selection.Presentation, StrLen(Selection.Presentation) - (StrLen(ExtensionWithoutDot)+1));
				Else
					ExtensionWithoutDot = "";
					NameWithoutExtension = Selection.Presentation;
				EndIf;
				
				Attachments.FindRows(New Structure("Presentation, AddressInTemporaryStorage", Selection.Presentation, Selection.AddressInTemporaryStorage))[0].Ref =
					AttachedFiles.AppendFile(CurrentObject.Ref, NameWithoutExtension, ExtensionWithoutDot, , , Selection.AddressInTemporaryStorage);
				
			EndIf;
			
		ElsIf Selection.AttachmentRefs = NULL Then
		// Delete attachment from the attached files
			
			AttachedFileObject = Selection.AttachedFileRef.GetObject();
			AttachedFileObject.SetDeletionMark(True);
			
		Else
		// Update attachment in attached files
			
			AttachedFiles.UpdateAttachedFile(Selection.AttachedFileRef, 
				New Structure("FileAddressInTempStorage, TempTextStorageAddress", Selection.AddressInTemporaryStorage, ""));
		EndIf;
		
	EndDo;
	
EndProcedure

// Procedure - event handler AfterWriting.
//
&AtClient
Procedure AfterWrite(WriteParameters)
	
	Title = "";
	AutoTitle = True;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	FilesOperationsClient.ShowConfirmationForClosingFormWithFiles(ThisObject, Cancel, Exit, Object.Ref);
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.Properties
	PropertyManager.FillCheckProcessing(ThisObject, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties

EndProcedure

#EndRegion

#Region FormAttributesEventsHandlers

&AtClient
Procedure UserAccountStartChoice(Item, ChoiceData, StandardProcessing)
	
	If AccountSpecified Then
		// if the account was passed as the parameter, we do not allow to select another
		StandardProcessing = False;
	EndIf;
	
EndProcedure

// Procedure - event handler SelectionStart of attribute Subject.
//
&AtClient
Procedure SubjectStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	FormParameters = New Structure;
	If TypeOf(Object.Subject) = Type("CatalogRef.EventsSubjects") AND ValueIsFilled(Object.Subject) Then
		FormParameters.Insert("CurrentRow", Object.Subject);
	EndIf;
	
	OpenForm("Catalog.EventsSubjects.ChoiceForm", FormParameters, Item);
	
EndProcedure

// Procedure - event handler SelectionDataProcessor of attribute Subject.
//
&AtClient
Procedure SubjectChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	Modified = True;
	
	If ValueIsFilled(ValueSelected) Then
		Object.Subject = ValueSelected;
		FillContentEvents(ValueSelected);
	EndIf;
	
EndProcedure

// Procedure - events handler AutoPick of attribute Subject.
//
&AtClient
Procedure SubjectAutoSelection(Item, Text, ChoiceData, Parameters, Wait, StandardProcessing)
	
	If Wait <> 0 AND Not IsBlankString(Text) Then
		
		StandardProcessing = False;
		ChoiceData = GetSubjectChoiceList(Text, SubjectRowHistory);
		
	EndIf;
	
EndProcedure

// Procedure - event handler SelectionStart of RecipientsContact item.
//
&AtClient
Procedure RecipientsContactStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	FormParameters = New Structure;
	FormParameters.Insert("CIType", "Email");
	If ValueIsFilled(Items.Recipients.CurrentData.Contact) Then
		Contact = Object.Participants.FindByID(Items.Recipients.CurrentRow).Contact;
		If TypeOf(Contact) = Type("CatalogRef.Counterparties") Then
			FormParameters.Insert("CurrentCounterparty", Contact);
		EndIf;
	EndIf;
	NotifyDescription = New NotifyDescription("RecipientsContactSelectionEnd", ThisForm);
	OpenForm("CommonForm.AddressBook", FormParameters, ThisForm, , , , NotifyDescription, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

// Procedure - event handler Open item RecipientsContact.
//
&AtClient
Procedure ContactRecipientsOpen(Item, StandardProcessing)
	
	StandardProcessing = False;
	If ValueIsFilled(Items.Recipients.CurrentData.Contact) Then
		Contact = Object.Participants.FindByID(Items.Recipients.CurrentRow).Contact;
		ShowValue(,Contact);
	EndIf;
	
EndProcedure

// Procedure - event handler SelectionDataProcessor of RecipientsContact item.
//
&AtClient
Procedure RecipientsContactChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	Modified = True;
	
	If TypeOf(ValueSelected) = Type("CatalogRef.Counterparties") Or TypeOf(ValueSelected) = Type("CatalogRef.ContactPersons") Then
	// Selection is implemented by automatic selection mechanism
		
		Object.Participants.FindByID(Items.Recipients.CurrentRow).Contact = ValueSelected;
		
	EndIf;
	
EndProcedure

// Procedure - event handler AutomaticSelection of RecipientsContact item.
//
&AtClient
Procedure ContactRecipientsAutoPick(Item, Text, ChoiceData, Parameters, Wait, StandardProcessing)
	
	If Wait <> 0 AND Not IsBlankString(Text) Then
		StandardProcessing = False;
		ChoiceData = GetContactChoiceList(Text);
	EndIf;
	
EndProcedure

// Procedure - event handler Attribute selection Attachments.
//
&AtClient
Procedure AttachmentsSelection(Item, SelectedRow, Field, StandardProcessing)
	
	OpenAttachment();
	
EndProcedure

// Procedure - event handler BeforeAddStart of attribute Attachments.
//
&AtClient
Procedure AttachmentsBeforeAdd(Item, Cancel, Copy, Parent, Group, Parameter)
	
	Cancel = True;
	AddFileToAttachments();
	
EndProcedure

// Procedure - event handler CheckDragAndDrop of attribute Attachments.
//
&AtClient
Procedure AttachmentsDragCheck(Item, DragParameters, StandardProcessing, String, Field)
	
	StandardProcessing = False;
	
EndProcedure

// Procedure - DragAndDrop event handler of the Attachments attribute.
//
&AtClient
Procedure AttachmentsDrag(Item, DragParameters, StandardProcessing, String, Field)
	
	StandardProcessing = False;
	
	If TypeOf(DragParameters.Value) = Type("File") Then
		NotifyDescription = New NotifyDescription("AttachmentsDragAndDropEnd", ThisObject, New Structure("Name", DragParameters.Value.Name));
		BeginPutFile(NotifyDescription, , DragParameters.Value.DescriptionFull, False);
		Modified = True;
	EndIf;
	
EndProcedure

// Procedure - notification handler.
//
&AtClient
Procedure AttachmentsDragAndDropEnd(Result, TemporaryStorageAddress, SelectedFileName, AdditionalParameters) Export
	
	Files = New Array;
	PassedFile = New TransferableFileDescription(AdditionalParameters.Name, TemporaryStorageAddress);
	Files.Add(PassedFile);
	AddFilesToList(Files);
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

// Procedure - Send command handler.
//
&AtClient
Procedure Send(Command)
	
	If Not CheckFilling() Then
		Return;
	EndIf;
	
	If Not ValueIsFilled(Object.UserAccount) Then
		CommonClientServer.MessageToUser(
			NStr("en = 'Select an account to send emails.'; ru = 'Выберите учетную запись для отправки почты.';pl = 'Wybierz konto do wysłania poczty.';es_ES = 'Seleccionar una cuenta para enviar correos electrónicos.';es_CO = 'Seleccionar una cuenta para enviar correos electrónicos.';tr = 'E-posta göndermek için bir hesap seçin.';it = 'Selezionare un account per mandare la posta';de = 'Wählen Sie ein Konto aus, um E-Mails zu versenden.'"), ,
			"Object.UserAccount");
		Return;
	EndIf;
	
	ClearMessages();
	
	RecipientEmailAddress = "";
	For Each Recipient In Object.Participants Do
		RecipientEmailAddress = RecipientEmailAddress + Recipient.HowToContact + "; ";
	EndDo;
	
	Try
		NormalizedPostalAddress = CommonClientServer.ParseStringWithEmailAddresses(RecipientEmailAddress);
	Except
		CommonClientServer.MessageToUser(BriefErrorDescription(ErrorInfo()));
		Return;
	EndTry;
	
	If ((TypeOf(PasswordIsAssigned) = Type("Boolean") AND Not PasswordIsAssigned)
		Or (TypeOf(PasswordIsAssigned) = Type("FixedArray") AND PasswordIsAssigned.Find(Object.UserAccount) = Undefined)) Then
		FormParameters = New Structure;
		FormParameters.Insert("UserAccount", Object.UserAccount);
		OpenForm("CommonForm.PasswordConfirmation", FormParameters, ThisObject);
	Else
		ContinueSendingEmailsWithPassword();
	EndIf;
	
EndProcedure

// Procedure - command handler FillContent.
//
&AtClient
Procedure FillContent(Command)
	
	If ValueIsFilled(Object.Subject) Then
		FillContentEvents(Object.Subject);
	EndIf;
	
EndProcedure

// Procedure - command handler OpenFile.
//
&AtClient
Procedure OpenFile(Command)
	
	OpenAttachment();
	
EndProcedure

// Procedure - command handler OpenBasisDocuments.
//
&AtClient
Procedure OpenBasisDocuments(Command)
	
	Modified = True;
	AddressInBasisDocumentsStorage = PutBasisDocumentsToStorage();
	FormParameters = New Structure("AddressInBasisDocumentsStorage", AddressInBasisDocumentsStorage);
	OpenForm("Document.Event.Form.BasisDocumentsEmail", FormParameters
		,,,,, New NotifyDescription("OpenDocumentsBasesEnd", ThisObject, New Structure("AddressInBasisDocumentsStorage", AddressInBasisDocumentsStorage)), FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

#EndRegion

#Region CommonProceduresAndFunctions

// Procedure fills the attribute values of a new email by default.
//
&AtServer
Procedure FillNewEmailDefault()
	
	AutoTitle = False;
	Title = "Event: " + Object.EventType + " (Create)";
	
	Object.EventBegin = '00010101';
	Object.EventEnding = '00010101';
	Object.Author = Users.AuthorizedUser();
	Object.Responsible = Drivereuse.GetValueByDefaultUser(Object.Author, "MainResponsible");
	
	Object.UserAccount = Drivereuse.GetValueByDefaultUser(Object.Author, "DefaultEmailAccount");
	If ValueIsFilled(Object.UserAccount) Then
		PasswordIsAssigned = ValueIsFilled(Object.UserAccount.DeletePassword);
		Items.UserAccount.ChoiceButton = True;
	EndIf;
	
	If Interactions.EmailClientUsed() Then
		
		EmailOperationSettings = Interactions.GetEmailOperationsSetting();
		If EmailOperationSettings.Property("AddSignatureForNewMessages")
			And EmailOperationSettings.AddSignatureForNewMessages Then
			
			If EmailOperationSettings.NewMessageSignatureFormat = Enums.EmailEditingMethods.NormalText Then
				FormattedDocument.Add(EmailOperationSettings.SignatureForNewMessagesPlainText);
			Else
				FormattedDocument = EmailOperationSettings.NewMessageFormattedDocument;
			EndIf;
			
		EndIf;
		
	Else
		
		AddSignatureForNewMessages = Common.CommonSettingsStorageLoad("EmailSettings", "AddSignatureForNewMessages", False);
		
		If AddSignatureForNewMessages = True Then
			HTMLSignature = Common.CommonSettingsStorageLoad("EmailSettings", "HTMLSignature", "");
			FormattedDocument.SetHTML(HTMLSignature, New Structure);
		EndIf;
		
	EndIf;
	
EndProcedure

// Procedure fills attributes by passed to the form parameters.
//
// Parameters:
//  Parameters	 - Structure	 - Refusal form parameters		 - Boolean	 - Refusal flag
&AtServer
Procedure HandlePassedParameters(Parameters, Cancel)
	
	Object.Subject = Parameters.Subject;
	Object.Content = Parameters.Body;
	If Not IsBlankString(Object.Content) Then
		FormattedDocument.SetHTML(Object.Content, New Structure);
	EndIf;
	
	If TypeOf(Parameters.BasisDocuments) = Type("Array") Then
		ValidBasisTypes = Metadata.Documents.Event.TabularSections.BasisDocuments.Attributes.BasisDocument.Type;
		For Each BasisDocument In Parameters.BasisDocuments Do
			If ValidBasisTypes.ContainsType(TypeOf(BasisDocument)) Then
				NewRow = Object.BasisDocuments.Add();
				NewRow.BasisDocument = BasisDocument;
			EndIf;
		EndDo;
	EndIf;

	If Not ValueIsFilled(Parameters.UserAccount) Then
		If Not ValueIsFilled(Object.UserAccount) Then
		// account is not transferred - select the first available
		
			Items.UserAccount.ChoiceButton = True;
			AvailableAccounts = EmailOperations.AvailableEmailAccounts(True);
			
			If AvailableAccounts.Count() > 0 Then
				
				Object.UserAccount = AvailableAccounts[0].Ref;
				PasswordIsSetMac = New Array;
				
				For Each ItemAccount In AvailableAccounts Do
					If ValueIsFilled(ItemAccount.Ref.DeletePassword) Then
						PasswordIsSetMac.Add(ItemAccount.Ref);
					EndIf;
				EndDo;
				PasswordIsAssigned = New FixedArray(PasswordIsSetMac);
				
			EndIf;
		EndIf;
		
	ElsIf TypeOf(Parameters.UserAccount) = Type("CatalogRef.EmailAccounts") Then
		
		Object.UserAccount = Parameters.UserAccount;
		PasswordIsAssigned = ValueIsFilled(Object.UserAccount.DeletePassword);
		AccountSpecified = True;
		
	ElsIf TypeOf(Parameters.UserAccount) = Type("ValueList") Then
		
		AccountsSet = Parameters.UserAccount;
		
		If AccountsSet.Count() > 0 Then
			PasswordIsSetMac = New Array;
			
			For Each ItemAccount In AccountsSet Do
				Items.UserAccount.ChoiceList.Add(ItemAccount.Value, ItemAccount.Presentation);
				If ValueIsFilled(ItemAccount.Value.Password) Then
					PasswordIsSetMac.Add(ItemAccount.Value);
				EndIf;
			EndDo;
			PasswordIsAssigned = New FixedArray(PasswordIsSetMac);
			Items.UserAccount.ChoiceList.SortByPresentation();
			Object.UserAccount = AccountsSet[0].Value;
			
			// for the passed account list select it from the selection list
			Items.UserAccount.DropListButton = True;
			
			AccountSpecified = True;
			
			If Items.UserAccount.ChoiceList.Count() <= 1 Then
				Items.UserAccount.Visible = False;
			EndIf;
		EndIf;
		
	EndIf;
	
	If TypeOf(Parameters.SendTo) = Type("ValueList") Then
		RecipientEmailAddress = "";
		For Each ItemEmail In Parameters.SendTo Do
			NewRow = Object.Participants.Add();
			NewRow.HowToContact = ItemEmail.Value;
			If ValueIsFilled(ItemEmail.Presentation) Then
				NewRow.Contact = ItemEmail.Presentation;
			EndIf;
		EndDo;
	ElsIf TypeOf(Parameters.SendTo) = Type("String") Then
		NewRow = Object.Participants.Add();
		NewRow.HowToContact = Parameters.SendTo;
	ElsIf TypeOf(Parameters.SendTo) = Type("Array") Then
		For Each StructureRecipient In Parameters.SendTo Do
			NewRow = Object.Participants.Add();
			NewRow.Contact = StructureRecipient.Presentation;
			NewRow.HowToContact = StructureRecipient.Address;
		EndDo;
	EndIf;
	
	If TypeOf(Parameters.Attachments) = Type("ValueList") Or TypeOf(Parameters.Attachments) = Type("Array") Then
		For Each Attachment In Parameters.Attachments Do
			AttachmentDescription = Attachments.Add();
			
			If TypeOf(Parameters.Attachments) = Type("ValueList") Then
				
				AttachmentDescription.Presentation = Attachment.Presentation;
				FileNameParts = StringFunctionsClientServer.SplitStringIntoSubstringsArray(Attachment.Presentation, ".", False);
				
				If FileNameParts.Count() > 1 Then
					ExtensionWithoutDot = FileNameParts[FileNameParts.Count()-1];
					AttachmentDescription.PictureIndex = FilesOperationsInternalClientServer.GetFileIconIndex(ExtensionWithoutDot);
				EndIf;
				
				If TypeOf(Attachment.Value) = Type("BinaryData") Then
					AttachmentDescription.AddressInTemporaryStorage = PutToTempStorage(Attachment.Value, UUID);
				ElsIf IsTempStorageURL(Attachment.Value) Then
					AttachmentDescription.AddressInTemporaryStorage = PutToTempStorage(GetFromTempStorage(Attachment.Value), UUID);
				Else
					AttachmentDescription.PathToFile = Attachment.Value;
				EndIf;
				
			Else // ValueType(Parameters.Attachments) = "structure array"
				
				FillPropertyValues(AttachmentDescription, Attachment);
				
				FileNameParts = StringFunctionsClientServer.SplitStringIntoSubstringsArray(AttachmentDescription.Presentation, ".", False);
				If FileNameParts.Count() > 1 Then
					ExtensionWithoutDot = FileNameParts[FileNameParts.Count()-1];
					AttachmentDescription.PictureIndex = FilesOperationsInternalClientServer.GetFileIconIndex(ExtensionWithoutDot);
				EndIf;
				
				If Not IsBlankString(AttachmentDescription.AddressInTemporaryStorage) Then
					AttachmentDescription.AddressInTemporaryStorage = PutToTempStorage(GetFromTempStorage(AttachmentDescription.AddressInTemporaryStorage), UUID);
				EndIf;
				
			EndIf;
		EndDo;
	EndIf;
	
EndProcedure

// Procedure - letter sending completion.
&AtClient
Procedure ContinueSendingEmailsWithPassword(Password = Undefined)
	
	EmailParameters = GenerateLetterParameters(Password);
	
	If EmailParameters = Undefined Then
		CommonClientServer.MessageToUser(NStr("en = 'An error occurred while generating email message parameters'; ru = 'Ошибка формирования параметров почтового сообщения';pl = 'Podczas generowania parametrów wiadomości e-mail wystąpił błąd';es_ES = 'Ha ocurrido un error al generar los parámetros del mensaje de correo electrónico';es_CO = 'Ha ocurrido un error al generar los parámetros del mensaje de correo electrónico';tr = 'E-posta mesaj parametreleri oluşturulurken hata oluştu';it = 'Si è verificato un errore durante la generazione parametri di messaggi di posta elettronica';de = 'Beim Generieren von E-Mail-Nachrichten ist ein Fehler aufgetreten'"));
		Return;
	EndIf;
	
	Try
		SendEMail(Object.UserAccount, EmailParameters);
		Successfully = True;
	Except
		CommonClientServer.MessageToUser(BriefErrorDescription(ErrorInfo()));
		Successfully = False;
	EndTry;
	
	If Successfully Then
		Object.State = PredefinedValue("Catalog.JobAndEventStatuses.Completed");
		Object.Date = CommonClient.SessionDate();
		Object.EventBegin = Object.Date;
		Object.EventEnding = Object.Date;
		Write();
		ShowUserNotification(NStr("en = 'Message is sent successfully'; ru = 'Сообщение успешно отправлено';pl = 'Wiadomość została wysłana pomyślnie';es_ES = 'Mensaje se ha enviado con éxito';es_CO = 'Mensaje se ha enviado con éxito';tr = 'Mesaj başarı ile gönderildi';it = 'Messaggio inviato con successo';de = 'Die Nachricht wurde erfolgreich gesendet'"), GetURL(Object.Ref), String(Object.Ref), PictureLib.Information32);
		Close(Successfully);
	EndIf;
	
EndProcedure

// Checks letter sending option and
// if this is possible - forms sending parameters
//
&AtClient
Function GenerateLetterParameters(Val Password = Undefined)
	
	EmailParameters = New Structure;
	
	If ValueIsFilled(Password) Then
		EmailParameters.Insert("Password", Password);
	EndIf;
	
	If ValueIsFilled(NormalizedPostalAddress) Then
		EmailParameters.Insert("SendTo", NormalizedPostalAddress);
	EndIf;
	
	If ValueIsFilled(Object.Subject) Then
		EmailParameters.Insert("Subject", String(Object.Subject));
	EndIf;
	
	EmailAttachments = New Map;
	EmailBody = "";
	AttachmentsImages = New Structure;
	FormattedDocument.GetHTML(EmailBody, AttachmentsImages);
	
	If AttachmentsImages.Count() > 0 Then
		AddAttachmentsImagesOnServer(EmailBody, EmailAttachments, AttachmentsImages);
	EndIf;
	
	AddAttachmentsFiles(EmailAttachments);
	
	EmailParameters.Insert("Body", EmailBody);
	EmailParameters.Insert("TextType", "HTML");
	EmailParameters.Insert("Attachments", EmailAttachments);
	
	Return EmailParameters;
	
EndFunction

&AtServerNoContext
Procedure AddAttachmentsImagesOnServer(HTMLText, EmailAttachments, AttachmentsImages)
	
	DriveInteractions.AddAttachmentsImagesInEmail(HTMLText, EmailAttachments, AttachmentsImages);
	
EndProcedure

&AtServerNoContext
Function SendEMail(Val UserAccount, Val EmailParameters)
	
	Return EmailOperations.SendEmailMessage(UserAccount, EmailParameters);
	
EndFunction

&AtClient
Procedure RecipientsContactSelectionEnd(AddressInStorage, AdditionalParameters) Export
	
	If IsTempStorageURL(AddressInStorage) Then
		
		LockFormDataForEdit();
		Modified = True;
		FillContactsByAddressBook(AddressInStorage);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FillContactsByAddressBook(AddressInStorage)
	
	RecipientsTable = GetFromTempStorage(AddressInStorage);
	CurrentRowDataProcessor = True;
	For Each SelectedRow In RecipientsTable Do
		
		If CurrentRowDataProcessor Then
			RowParticipants = Object.Participants.FindByID(Items.Recipients.CurrentRow);
			CurrentRowDataProcessor = False;
		Else
			RowParticipants = Object.Participants.Add();
		EndIf;
		
		RowParticipants.Contact = SelectedRow.Contact;
		RowParticipants.HowToContact = SelectedRow.HowToContact;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure AddAttachmentsFiles(EmailAttachments)
	
	For Each Attachment In Attachments Do
		AttachmentDescription = New Structure("BinaryData, ID");
		AttachmentDescription.BinaryData = GetFromTempStorage(Attachment.AddressInTemporaryStorage);
		AttachmentDescription.ID = "";
		EmailAttachments.Insert(Attachment.Presentation, AttachmentDescription);
	EndDo;
	
EndProcedure

// Procedure attachment interactive add.
//
&AtClient
Procedure AddFileToAttachments()
	
	DialogueParameters = New Structure;
	DialogueParameters.Insert("Mode", FileDialogMode.Open);
	DialogueParameters.Insert("Multiselect", True);
	
	NotifyDescription = New NotifyDescription("AddFileToAttachmentsWhenFilePlace", ThisObject);
	
	StandardSubsystemsClient.ShowPutFile(NotifyDescription, UUID, "", DialogueParameters);
	
EndProcedure

&AtClient
Procedure AddFileToAttachmentsWhenFilePlace(PlacedFiles, AdditionalParameters) Export
	
	If PlacedFiles = Undefined Or PlacedFiles.Count() = 0 Then
		Return;
	EndIf;
	
	AddFilesToList(PlacedFiles);
	Modified = True;
	
EndProcedure

// Procedure adds files to attachments.
//
// Parameters:
//  PlacedFiles	 - Array	 - Array of objects of the TransferredFileDescription type 
&AtServer
Procedure AddFilesToList(PlacedFiles)
	
	For Each FileDescription In PlacedFiles Do
		
		File = New File(FileDescription.Name);
		DotPosition = Find(File.Extension, ".");
		ExtensionWithoutDot = Mid(File.Extension, DotPosition + 1);
		
		Attachment = Attachments.Add();
		Attachment.Presentation = File.Name;
		Attachment.AddressInTemporaryStorage = PutToTempStorage(GetFromTempStorage(FileDescription.Location), UUID);
		Attachment.PictureIndex = FilesOperationsInternalClientServer.GetFileIconIndex(ExtensionWithoutDot);
		
	EndDo;
	
EndProcedure

// Procedure in dependence on the client type opens or saves the selected file
//
&AtClient
Procedure OpenAttachment()
	
	If Items.Attachments.CurrentRow = Undefined Then
		Return;
	EndIf;
	
	SelectedAttachment = Attachments.FindByID(Items.Attachments.CurrentRow);
	
	#If WebClient Then
		GetFile(SelectedAttachment.AddressInTemporaryStorage, SelectedAttachment.Presentation, True);
	#Else
		TempFolderName = GetTempFileName();
		CreateDirectory(TempFolderName);
		
		TempFileName = CommonClientServer.AddLastPathSeparator(TempFolderName) + SelectedAttachment.Presentation;
		
		BinaryData = GetFromTempStorage(SelectedAttachment.AddressInTemporaryStorage);
		BinaryData.Write(TempFileName);
		
		File = New File(TempFileName);
		File.SetReadOnly(True);
		If File.Extension = ".mxl" Then
			SpreadsheetDocument = GetSpreadsheetDocumentByBinaryData(SelectedAttachment.AddressInTemporaryStorage);
			OpenParameters = New Structure;
			OpenParameters.Insert("DocumentName", SelectedAttachment.Presentation);
			OpenParameters.Insert("SpreadsheetDocument", SpreadsheetDocument);
			OpenParameters.Insert("PathToFile", TempFileName);
			OpenForm("CommonForm.EditSpreadsheetDocument", OpenParameters, ThisObject);
		Else
			RunApp(TempFileName);
		EndIf;
	#EndIf
	
EndProcedure

&AtServerNoContext
Function GetSpreadsheetDocumentByBinaryData(Val BinaryData)
	
	If TypeOf(BinaryData) = Type("String") Then
		// binary data address is transferred for temporary storage
		BinaryData = GetFromTempStorage(BinaryData);
	EndIf;
	
	FileName = GetTempFileName("mxl");
	BinaryData.Write(FileName);
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.Read(FileName);
	
	Try
		DeleteFiles(FileName);
	Except
		WriteLogEvent(NStr("en = 'Receive spreadsheet document'; ru = 'Получение табличного документа';pl = 'Uzyskać dokument tabelaryczny';es_ES = 'Recibir el documento de la hoja de cálculo';es_CO = 'Recibir el documento de la hoja de cálculo';tr = 'Elektronik çizelge belgesini al';it = 'Ricevere foglio elettronico';de = 'Kalkulationstabellen-Dokument erhalten'", CommonClientServer.DefaultLanguageCode()), EventLogLevel.Error, , , 
			DetailErrorDescription(ErrorInfo()));
	EndTry;
	
	Return SpreadsheetDocument;
	
EndFunction

// Function places tabular section BasisDocuments in temporary
// storage and returns the address
//
&AtServer
Function PutBasisDocumentsToStorage()
	
	Return PutToTempStorage(
		Object.BasisDocuments.Unload(,
			"BasisDocument"
		),
		UUID
	);
	
EndFunction

&AtClient
Procedure OpenDocumentsBasesEnd(Result, AdditionalParameters) Export
	
	AddressInBasisDocumentsStorage = AdditionalParameters.AddressInBasisDocumentsStorage;
	
	If Result = DialogReturnCode.OK Then
		GetBasisDocumentsFromStorage(AddressInBasisDocumentsStorage);
	EndIf;
	
EndProcedure

// Function receives the BasisDocuments tabular section from the temporary storage.
//
&AtServer
Procedure GetBasisDocumentsFromStorage(AddressInBasisDocumentsStorage)
	
	TableBasisDocuments = GetFromTempStorage(AddressInBasisDocumentsStorage);
	Object.BasisDocuments.Clear();
	For Each RowDocumentsBases In TableBasisDocuments Do
		String = Object.BasisDocuments.Add();
		FillPropertyValues(String, RowDocumentsBases);
	EndDo;
	
	SetBasisDocumentHyperlinkTitle();
	
EndProcedure

// Procedure sets the header text of the hyperlink from the reference document presentation.
//
&AtServer
Procedure SetBasisDocumentHyperlinkTitle()
	
	Result = "";
	
	For Each RowBasisDocument In Object.BasisDocuments Do
		Result = "" + Result + ?(Result = "", "", "; ") + String(RowBasisDocument.BasisDocument);
	EndDo;
	
	Items.OpenBasisDocuments.Title = ?(Result = "", NStr("en = 'Base documents'; ru = 'Список документов-оснований';pl = 'Dokumenty źródłowe';es_ES = 'Documentos de base';es_CO = 'Documentos de base';tr = 'Temel belgeler';it = 'Documenti di base';de = 'Basisbelege'"), Result);
	
EndProcedure

#EndRegion

#Region ProceduresAndFunctionsForAutomaticSelection

// Procedure fills contact selection data.
//
// Parameters:
//  SearchString - String	 - Text being typed
&AtServerNoContext
Function GetContactChoiceList(val SearchString)
	
	ContactSelectionData = New ValueList;
	
	ChoiceParameters = New Structure;
	ChoiceParameters.Insert("Filter", New Structure("DeletionMark", False));
	ChoiceParameters.Insert("SearchString", SearchString);
	
	CounterpartySelectionData = Catalogs.Counterparties.GetChoiceData(ChoiceParameters);
	
	For Each ItemOfList In CounterpartySelectionData Do
		ContactSelectionData.Add(ItemOfList.Value, New FormattedString(ItemOfList.Presentation, " (counterparty)"));
	EndDo;
	
	ContactPersonSelectionData = Catalogs.ContactPersons.GetChoiceData(ChoiceParameters);
	
	For Each ItemOfList In ContactPersonSelectionData Do
		ContactSelectionData.Add(ItemOfList.Value, New FormattedString(ItemOfList.Presentation, " (contact person)"));
	EndDo;
	
	Return ContactSelectionData;
	
EndFunction

// Procedure fills subject selection data.
//
// Parameters:
//  SearchString - String	 - The SubjectHistoryByRow text being typed - ValueList	 - Used subjects in the row form
&AtServerNoContext
Function GetSubjectChoiceList(val SearchString, val SubjectRowHistory)
	
	ListChoiceOfTopics = New ValueList;
	
	ChoiceParameters = New Structure;
	ChoiceParameters.Insert("Filter", New Structure("DeletionMark", False));
	ChoiceParameters.Insert("SearchString", SearchString);
	ChoiceParameters.Insert("ChoiceFoldersAndItems", FoldersAndItemsUse.Items);
	
	SubjectSelectionData = Catalogs.EventsSubjects.GetChoiceData(ChoiceParameters);
	
	For Each ItemOfList In SubjectSelectionData Do
		ListChoiceOfTopics.Add(ItemOfList.Value, New FormattedString(ItemOfList.Presentation, " (event subject)"));
	EndDo;
	
	For Each HistoryItem In SubjectRowHistory Do
		If Left(HistoryItem.Value, StrLen(SearchString)) = SearchString Then
			ListChoiceOfTopics.Add(HistoryItem.Value, 
				New FormattedString(New FormattedString(SearchString,New Font(,,True),WebColors.Green), Mid(HistoryItem.Value, StrLen(SearchString)+1)));
		EndIf;
	EndDo;
	
	Return ListChoiceOfTopics;
	
EndFunction

// Procedure imports the event subject automatic selection history.
//
&AtServer
Procedure ImportSubjectHistoryByString()
	
	ListChoiceOfTopics = Common.CommonSettingsStorageLoad("ThemeEventsChoiceList", "");
	If ListChoiceOfTopics <> Undefined Then
		SubjectRowHistory.LoadValues(ListChoiceOfTopics);
	EndIf;
	
EndProcedure

#EndRegion

#Region SecondaryDataFilling

// Procedure fills the event content from the subject template.
//
&AtClient
Procedure FillContentEvents(EventSubject)
	
	If TypeOf(EventSubject) <> Type("CatalogRef.EventsSubjects") Then
		Return;
	EndIf;
	
	If Not IsBlankString(FormattedDocument.GetText()) Then
		
		ShowQueryBox(New NotifyDescription("FillEventContentEnd", ThisObject, New Structure("EventSubject", EventSubject)),
			NStr("en = 'Refill the content by the selected topic?'; ru = 'Перезаполнить содержание по выбранной теме?';pl = 'Wypełnić ponownie zawartość według wybranego tematu?';es_ES = '¿Volver a rellenar el contenido por el tema seleccionado?';es_CO = '¿Volver a rellenar el contenido por el tema seleccionado?';tr = 'İçerik seçilen konuya göre doldurulsun mu?';it = 'Ricarica il contenuto per l''argomento selezionato?';de = 'Den Inhalt mit dem ausgewählten Thema erneut ausfüllen?'"), QuestionDialogMode.YesNo, 0);
		Return;
		
	EndIf;
	
	FillEventContentFragment(EventSubject);
	
EndProcedure

&AtClient
Procedure FillEventContentEnd(Result, AdditionalParameters) Export
	
	If Result <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	FillEventContentFragment(AdditionalParameters.EventSubject);
	
EndProcedure

&AtClient
Procedure FillEventContentFragment(Val EventSubject)
	
	SetHTMLContentByEventSubject(FormattedDocument, EventSubject);
	
EndProcedure

// Procedure sets the formatted document content by the selected subject.
//
&AtServerNoContext
Procedure SetHTMLContentByEventSubject(FormattedDocument, EventSubject)
	
	FormattedDocument.SetFormattedString(New FormattedString(EventSubject.Content));
	
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

#EndRegion
