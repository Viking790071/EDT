
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// StandardSubsystems.AttachableCommands
	AttachableCommands.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.ObjectVersioning
	ObjectsVersioning.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.ObjectVersioning
	
	TypeArray = New Array;
	TypeArray.Add(Type("String"));
	TypeRestriction = New TypeDescription(TypeArray, New StringQualifiers(100));
	
	Items.ContactRecipients.TypeRestriction = TypeRestriction;
	Items.Subject.TypeRestriction			= TypeRestriction;
	
	SMSProvider = Constants.SMSProvider.Get();
	SMSSettingsComplete = SMS.SMSMessageSendingSetupCompleted();
	AvailableRightSettingsSMS = Users.IsFullUser();
	
	If Parameters.Key.IsEmpty() Then
		FillNewEmailDefault();
	EndIf;
	
	DriveClientServer.SetPictureForComment(Items.GroupAdditional, Object.Comment);
	
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentSessionDate();
	EndIf;
	
	FormManagement(ThisObject);
	
	UseDocumentEvent = GetFunctionalOption("UseDocumentEvent");
	
	Items.CreateEvents.Visible = UseDocumentEvent; 
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	DocumentDate = CurrentObject.Date;
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.EditProhibitionDates
	PeriodClosingDates.ObjectOnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.EditProhibitionDates
	
	If CurrentObject.SendingMethod = Enums.MessageType.Email Then
		
		Images = CurrentObject.ImagesHTML.Get();
		If Images = Undefined Then
			Images = New Structure;
		EndIf;
		FormattedDocument.SetHTML(CurrentObject.ContentHTML, Images);
		
		Attachments.Clear();
		
		Query = New Query;
		Query.Text =
			"SELECT
			|	BulkMailAttachedFiles.Ref,
			|	BulkMailAttachedFiles.Description,
			|	BulkMailAttachedFiles.Extension,
			|	BulkMailAttachedFiles.PictureIndex
			|FROM
			|	Catalog.BulkMailAttachedFiles AS BulkMailAttachedFiles
			|WHERE
			|	BulkMailAttachedFiles.FileOwner = &FileOwner
			|	AND BulkMailAttachedFiles.DeletionMark = FALSE";
		
		Query.SetParameter("FileOwner", CurrentObject.Ref);
		
		Selection = Query.Execute().Select();
		
		While Selection.Next() Do
			
			NewRow = Attachments.Add();
			NewRow.Ref                    = Selection.Ref;
			NewRow.Presentation             = Selection.Description + ?(IsBlankString(Selection.Extension), "", "." + Selection.Extension);
			NewRow.PictureIndex            = Selection.PictureIndex;
			NewRow.AddressInTemporaryStorage = PutToTempStorage(AttachedFiles.GetBinaryFileData(Selection.Ref), UUID);
			
		EndDo;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If CurrentObject.SendingMethod = Enums.MessageType.Email Then
		
		HTMLText = "";
		Images = New Structure;
		FormattedDocument.GetHTML(HTMLText, Images);
		
		CurrentObject.ContentHTML = HTMLText;
		CurrentObject.ImagesHTML = New ValueStorage(Images);
		CurrentObject.Content = FormattedDocument.GetText();
		
	Else
		
		CheckAndConvertRecipientNumbers(CurrentObject, Cancel);
		CurrentObject.ContentHTML = "";
		CurrentObject.ImagesHTML = Undefined;
		Attachments.Clear();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	SaveAttachments(CurrentObject.Ref);
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	If Object.SendingMethod = Enums.MessageType.Email Then
		CheckEmailAddressCorrectness(Cancel);
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	FilesOperationsClient.ShowConfirmationForClosingFormWithFiles(ThisObject, Cancel, Exit, Object.Ref);
EndProcedure

#EndRegion

#Region FormAttributesEventsHandlers

&AtClient
Procedure SendingMethodOnChange(Item)
	
	FormManagement(ThisForm);
	
EndProcedure

&AtClient
Procedure SubjectStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	FormParameters = New Structure;
	If TypeOf(Object.Subject) = Type("CatalogRef.EventsSubjects") AND ValueIsFilled(Object.Subject) Then
		FormParameters.Insert("CurrentRow", Object.Subject);
	EndIf;
	
	OpenForm("Catalog.EventsSubjects.ChoiceForm", FormParameters, Item);
	
EndProcedure

&AtClient
Procedure SubjectChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	Modified = True;
	
	If ValueIsFilled(ValueSelected) Then
		Object.Subject = ValueSelected;
		FillContentEvents(ValueSelected);
	EndIf;
	
EndProcedure

&AtClient
Procedure SubjectAutoSelection(Item, Text, ChoiceData, Parameters, Wait, StandardProcessing)
	
	If Wait <> 0 AND Not IsBlankString(Text) Then
		
		StandardProcessing = False;
		ChoiceData = GetSubjectChoiceList(Text);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure RecipientsContactStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	FormParameters = New Structure;
	FormParameters.Insert("CIType", "Email");
	If ValueIsFilled(Items.Recipients.CurrentData.Contact) Then
		Contact = Object.Recipients.FindByID(Items.Recipients.CurrentRow).Contact;
		If TypeOf(Contact) = Type("CatalogRef.Counterparties") Then
			FormParameters.Insert("CurrentCounterparty", Contact);
		EndIf;
	EndIf;
	NotifyDescription = New NotifyDescription("RecipientsContactSelectionEnd", ThisForm);
	OpenForm("CommonForm.AddressBook", FormParameters, ThisForm, , , , NotifyDescription, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure ContactRecipientsOpen(Item, StandardProcessing)
	
	StandardProcessing = False;
	If ValueIsFilled(Items.Recipients.CurrentData.Contact) Then
		Contact = Object.Recipients.FindByID(Items.Recipients.CurrentRow).Contact;
		ShowValue(,Contact);
	EndIf;
	
EndProcedure

&AtClient
Procedure RecipientsContactChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	Modified = True;
	
	If TypeOf(ValueSelected) = Type("CatalogRef.Counterparties") Or TypeOf(ValueSelected) = Type("CatalogRef.ContactPersons") Then
	// Selection is implemented by automatic selection mechanism
		
		Object.Recipients.FindByID(Items.Recipients.CurrentRow).Contact = ValueSelected;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ContactRecipientsAutoPick(Item, Text, ChoiceData, Parameters, Wait, StandardProcessing)
	
	If Wait <> 0 AND Not IsBlankString(Text) Then
		StandardProcessing = False;
		ChoiceData = GetContactChoiceList(Text);
	EndIf;
	
EndProcedure

&AtClient
Procedure CommentOnChange(Item)
	
	AttachIdleHandler("Attachable_SetPictureForComment", 0.5, True);
	
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

&AtClient
Procedure DateOnChange(Item)
	
	DriveClient.ProcessDateChange(ThisObject, "");
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure SendMailing(Command)
	
	If Write() Then
		
		If Object.SendingMethod = PredefinedValue("Enum.MessageType.Email") Then
			SuccessfullySent = SendEmailMailing();
		Else
			If SMSSettingsComplete Then
				SuccessfullySent = SendSMSMailing();
			ElsIf AvailableRightSettingsSMS Then
				MessageText = NStr("en = 'To send SMS, it is necessary to configure sending parameters.
				                   |You can adjust the settings in the Settings - Personal organizer - SMS sending section.'; 
				                   |ru = 'Для отправки SMS требуется настройка параметров отправки.
				                   |Настройка осуществляется в разделе Настройки - Органайзер - Настройка отправки SMS.';
				                   |pl = 'Aby przesłać SMS należy skonfigurować parametry wysyłania.
				                   | Możesz to zrobić w rozdziale Ustawienia - Organizer osobisty - Wysyłanie wiadomości SMS.';
				                   |es_ES = 'Para enviar un SMS, es necesario configurar los parámetros de envío.
				                   |Usted puede modificar las configuraciones en Configuraciones - Organizador personal - Sección de envío de SMS.';
				                   |es_CO = 'Para enviar un SMS, es necesario configurar los parámetros de envío.
				                   |Usted puede modificar las configuraciones en Configuraciones - Organizador personal - Sección de envío de SMS.';
				                   |tr = 'SMS göndermek için gönderme parametrelerini yapılandırmak gereklidir. 
				                   |Ayarları Ayarlar - Ajanda - SMS gönderme bölümünde ayarlayabilirsiniz.';
				                   |it = 'Per inviare SMS, è necessario configurare i parametri di invio.
				                   |È possibile regolare le impostazioni in Impostazioni - Organizzatore personale - Sezione invio SMS.';
				                   |de = 'Um SMS zu versenden, ist es notwendig, die Sendeparameter zu konfigurieren.
				                   |Sie können die Einstellungen im Bereich Einstellungen - Persönlicher Organizer - SMS-Versand anpassen.'");
				ShowMessageBox(, MessageText);
				Return;
			Else
				MessageText = NStr("en = 'To send SMS, it is necessary to configure sending parameters.
				                   |Address to the administrator to perform settings.'; 
				                   |ru = 'Для отправки SMS требуется настройка параметров отправки.
				                   |Для выполнения настроек обратитесь к администратору.';
				                   |pl = 'Aby przesłać SMS należy skonfigurować parametry wysyłania.
				                   |W celu wybrania ustawień skontaktuj się z administratorem.';
				                   |es_ES = 'Para enviar un SMS, es necesario configurar los parámetros de envío.
				                   |Dirección al administrador para realizar las configuraciones.';
				                   |es_CO = 'Para enviar un SMS, es necesario configurar los parámetros de envío.
				                   |Dirección al administrador para realizar las configuraciones.';
				                   |tr = 'SMS göndermek için gönderme parametrelerini yapılandırmak gereklidir. 
				                   |Ayarları gerçekleştirmek için yöneticiye başvurun.';
				                   |it = 'Per inviare SMS, è necessario configurare i parametri di invio.
				                   |Chiedete all''amministrato di inserire le impostazioni.';
				                   |de = 'Um SMS zu senden, müssen Sendeparameter konfiguriert werden.
				                   |Wenden Sie sich an den Administrator, um Einstellungen vorzunehmen.'");
				ShowMessageBox(, MessageText);
				Return;
			EndIf;
		EndIf;
		
		NotificationText = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Successfully sent: %1 messages'; ru = 'Успешно отправлено: %1 сообщений';pl = 'Pomyślnie wysłano: %1 wiadomości';es_ES = 'Enviado con éxito: %1 mensajes';es_CO = 'Enviado con éxito: %1 mensajes';tr = 'Başarıyla gönderildi: %1 mesajlar';it = 'Inviata con successo: %1 messaggi';de = 'Erfolgreich gesendet: %1 Nachrichten'"), SuccessfullySent);
		ShowUserNotification(NotificationText, GetURL(Object.Ref), String(Object.Ref), PictureLib.Information32);
		If SuccessfullySent = Object.Recipients.Count() Then
			Object.State = PredefinedValue("Enum.MailStatus.Sent");
			Object.DateMailings = CommonClient.SessionDate();
			Write();
			Close(SuccessfullySent);
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure FillContentBySubject(Command)
	
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

&AtClient
Procedure PickContacts(Command)
	
	FormParameters = New Structure;
	If Object.SendingMethod = PredefinedValue("Enum.MessageType.Email") Then
		FormParameters.Insert("CIType", "Email");
	Else
		FormParameters.Insert("CIType", "Phone");
	EndIf;
	NotifyDescription = New NotifyDescription("ContactPickEnd", ThisForm);
	OpenForm("CommonForm.AddressBook", FormParameters, ThisForm, , , , NotifyDescription, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure DeleteBlank(Command)
	
	DeletedRecipients = New Array;
	
	For Each RecipientRow In Object.Recipients Do
		If IsBlankString(RecipientRow.HowToContact) Then
			DeletedRecipients.Add(RecipientRow);
		EndIf;
	EndDo;
	
	For Each DeletedRecipient In DeletedRecipients Do
		Object.Recipients.Delete(DeletedRecipient);
	EndDo;
	
EndProcedure

&AtClient
Procedure RefreshDeliveryStatuses(Command)
	
	UpdateDeliveryStatusesAtServer();
	
EndProcedure

&AtClient
Procedure ParameterTime(Command)
	
	InsertParameter("{Time}");
	
EndProcedure

&AtClient
Procedure ParameterDate(Command)
	
	InsertParameter("{Date}");
	
EndProcedure

&AtClient
Procedure ParameterRecipientName(Command)
	
	InsertParameter("{Recipient name}");
	
EndProcedure

#EndRegion

#Region CommonProceduresAndFunctions

&AtServer
Procedure CheckAndConvertRecipientNumbers(CurrentObject, Cancel)
	
	For Each Recipient In CurrentObject.Recipients Do
		
		If IsBlankString(Recipient.HowToContact) Then
			CommonClientServer.MessageToUser(
				NStr("en = 'Phone number is not populated.'; ru = 'Поле ""Номер телефона"" не заполнено.';pl = 'Nie wypełniono pola ""Numer telefonu""';es_ES = 'Número de teléfono no está poblado.';es_CO = 'Número de teléfono no está poblado.';tr = 'Telefon numarası doldurulmadı.';it = 'Numero di telefono non viene popolata.';de = 'Die Telefonnummer ist nicht ausgefüllt.'"),
				,
				CommonClientServer.PathToTabularSection("Object.Recipients", Recipient.LineNumber, "HowToContact"),
				,
				Cancel);
			Continue;
		EndIf;
		
		If StringFunctionsClientServer.SplitStringIntoSubstringsArray(Recipient.HowToContact, ";", True).Count() > 1 Then
			CommonClientServer.MessageToUser(
				NStr("en = 'Only one phone number should be specified.'; ru = 'Должен быть указан только один номер телефона.';pl = 'Należy określić tylko jeden numer telefonu.';es_ES = 'Solo un número de teléfono tiene que estar especificado.';es_CO = 'Solo un número de teléfono tiene que estar especificado.';tr = 'Sadece bir telefon numarası belirtilmelidir.';it = 'Un solo numero di telefono deve essere specificato.';de = 'Es sollte nur eine Telefonnummer angegeben werden.'"),
				,
				CommonClientServer.PathToTabularSection("Object.Recipients", Recipient.LineNumber, "HowToContact"),
				,
				Cancel);
			Continue;
		EndIf;
		
		Recipient.NumberForSending = DriveClientServer.ConvertNumberForSMSSending(Recipient.HowToContact);
			
	EndDo;
	
EndProcedure

&AtServer
Procedure CheckEmailAddressCorrectness(Cancel)
	
	For Each RecipientRow In Object.Recipients Do
		
		Try
			CommonClientServer.ParseStringWithEmailAddresses(RecipientRow.HowToContact);
		Except
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Recipient email is specified incorrectly: %1, due to: %2'; ru = 'Некорректно указан E-mail получателя: %1, по причине: %2';pl = 'Nieprawidłowy e-mail odbiorcy: %1, przyczyna: %2';es_ES = 'Correo electrónico del destinatario está especificado de forma incorrecta: %1, debido a: %2';es_CO = 'Correo electrónico del destinatario está especificado de forma incorrecta: %1, debido a: %2';tr = 'Alıcı e-postası yanlış belirtildi: %1, nedeni: %2';it = 'E-mail errata del destinatario: %1, a causa di: %2';de = 'Empfänger-E-Mail-Adresse wird falsch angegeben: %1, aufgrund: %2'"),
				RecipientRow.Contact,
				BriefErrorDescription(ErrorInfo()),
				);
			CommonClientServer.MessageToUser(ErrorText, ,
				CommonClientServer.PathToTabularSection("Recipients", RecipientRow.LineNumber, "HowToContact"), "Object", Cancel);
		EndTry;
		
	EndDo;
	
EndProcedure

&AtClientAtServerNoContext
Procedure FormManagement(Form)
	
	Items = Form.Items;
	Object = Form.Object;
	
	If Object.SendingMethod = PredefinedValue("Enum.MessageType.Email") Then
		Items.ContentKind.CurrentPage = Items.ForEmail;
		Items.FormSendMessaging.Picture = PictureLib.SendByEmail;
		Items.FormattedDocumentStandardCommands.Visible	= True;
		Items.UserAccount.Visible								= True;
		Items.GroupInformationSMS.Visible							= False;
		Items.AttachmentsGroup.Visible								= True;
		Items.RecipientsRefreshDeliveryStatuses.Visible			= False;
		Items.RecipientsDeliveryStatus.Visible						= False;
	Else
		Items.ContentKind.CurrentPage = Items.ForSMS;
		Items.FormSendMessaging.Picture = PictureLib.SendingSMS;
		Items.FormattedDocumentStandardCommands.Visible	= False;
		Items.UserAccount.Visible								= False;
		Items.GroupInformationSMS.Visible							= True;
		Items.AttachmentsGroup.Visible								= False;
		Items.RecipientsRefreshDeliveryStatuses.Visible			= True;
		Items.RecipientsDeliveryStatus.Visible						= True;
	EndIf;
	
	Items.SMSProvider.Visible = ValueIsFilled(Form.SMSProvider);
	
EndProcedure

// Procedure fills attribute values of new letters default.
//
&AtServer
Procedure FillNewEmailDefault()
	
	Object.Author = Users.AuthorizedUser();
	Object.Responsible = Drivereuse.GetValueByDefaultUser(Object.Author, "MainResponsible");
	Object.UserAccount = Drivereuse.GetValueByDefaultUser(Object.Author, "DefaultEmailAccount");
	
	SMSMessageSendingSettings = SendSMSMessagesCached.SMSMessageSendingSettings();
	If SMSMessageSendingSettings.SenderName = Undefined Then
		Object.SMSSenderName = "";
	Else
		Object.SMSSenderName = SMSMessageSendingSettings.SenderName;
	EndIf;
	
	Object.State = Enums.MailStatus.Draft;
	
	FillByRequestForQuotation();
	
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

&AtServer
Procedure FillByRequestForQuotation()

	If Not ValueIsFilled(Object.BasisDocument) Then
		Return;
	EndIf;
	
	AddHTMLToFormattedDocument(Object.ContentHTML);	
	
	FillByRequestForQuotation_AddAttachment()	
	
EndProcedure

&AtServer
Procedure FillByRequestForQuotation_AddAttachment()

	Arr = New Array;
	Arr.Add(Object.BasisDocument);
	MemoryStream = New MemoryStream();
	SprdDoc = Documents.RequestForQuotation.PrintRequestForQuotation(Arr, New ValueList, "RequestForQuotation");
	SprdDoc.Write(MemoryStream, SpreadsheetDocumentFileType.PDF);
	
	NewRow = Attachments.Add();
	NewRow.Ref = Undefined;
	NewRow.Presentation = NStr("en = 'Request for quotation'; ru = 'Запрос коммерческого предложения';pl = 'Zapytanie ofertowe';es_ES = 'Solicitud de presupuesto';es_CO = 'Solicitud de presupuesto';tr = 'Satın alma talebi';it = 'Richiesta di offerta';de = 'Angebotsanfrage'") + ".pdf";
	NewRow.PictureIndex = FilesOperationsInternalClientServer.GetFileIconIndex(".pdf");
	NewRow.AddressInTemporaryStorage = PutToTempStorage(MemoryStream.CloseAndGetBinaryData(), UUID);

EndProcedure

&AtServer
Procedure AddHTMLToFormattedDocument(HTML)
	
	FormattedDocumentPart = New FormattedDocument;
	FormattedDocumentPart.SetHTML(HTML, New Structure);
	FormattedStringPart = FormattedDocumentPart.GetFormattedString();
	FormattedDocument.Add(FormattedStringPart);

EndProcedure

&AtServer
Function SendEmailMailing()
	
	SuccessfullySent = 0;
	SetPrivilegedMode(True);
	
	For Each RecipientRow In Object.Recipients Do
		
		EmailBody = "";
		AttachmentsImages = New Structure;
		FormattedDocument.GetHTML(EmailBody, AttachmentsImages);
		
		SetMessageParameters(EmailBody, RecipientRow.Contact);
		EmailParameters = GenerateEmailParameters(RecipientRow.Contact, RecipientRow.HowToContact, EmailBody, AttachmentsImages, RecipientRow.UseBcc);
		
		Try
			EmailOperations.SendEmailMessage(Object.UserAccount, EmailParameters);
			Successfully = True;
			SuccessfullySent = SuccessfullySent + 1;
		Except
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Cannot send Email to recipient: %1, due to: %2'; ru = 'Не удалось отправить E-mail получателю: %1. Причина: %2';pl = 'Nie można wysłać e-maila do odbiorcy: %1, przyczyna: %2';es_ES = 'No se puede enviar un Correo electrónico al destinatario: %1, debido a: %2';es_CO = 'No se puede enviar un Correo electrónico al destinatario: %1, debido a: %2';tr = 'Alıcıya e-posta gönderilemiyor:%1, nedeni:%2';it = 'Non è possibile inviare l''E-mail al destinatario: %1, a causa di: %2';de = 'E-Mail kann nicht an den Empfänger gesendet werden: %1, aufgrund von: %2'"),
				RecipientRow.Contact,
				BriefErrorDescription(ErrorInfo()),
				);
			CommonClientServer.MessageToUser(ErrorText, , , CommonClientServer.PathToTabularSection("Recipients", RecipientRow.LineNumber, "Contact"));
			Successfully = False;
		EndTry;
		
		If Successfully AND Object.CreateEvents And UseDocumentEvent Then
		
			Event = Documents.Event.CreateDocument();
			Event.Date = CurrentSessionDate();
			Event.EventBegin = Event.Date;
			Event.EventEnding = Event.Date;
			Event.SetNewNumber();
			Event.EventType = Enums.EventTypes.Email;
			
			Event.ContentHTML = EmailBody;
			Event.ImagesHTML = New ValueStorage(AttachmentsImages);
			Event.Content = DriveInteractions.GetTextFromHTML(Event.ContentHTML);
			
			BasisRow = Event.BasisDocuments.Add();
			BasisRow.BasisDocument = Object.Ref;
			
			Event.UserAccount = Object.UserAccount;
			Event.State = Catalogs.JobAndEventStatuses.Completed;
			Event.Subject = Object.Subject;
			Event.Responsible = Object.Responsible;
			Event.Author = Object.Author;
			RowParticipants = Event.Participants.Add();
			FillPropertyValues(RowParticipants, RecipientRow);
			Event.Write();
			
		EndIf;
		
	EndDo;
	
	SetPrivilegedMode(False);
	
	Return SuccessfullySent;
	
EndFunction

&AtServer
Function SendSMSMailing()
	
	SuccessfullySent = 0;
	SetPrivilegedMode(True);
	
	For Each RecipientRow In Object.Recipients Do
		
		SMSText = Object.Content;
		SetMessageParameters(SMSText, RecipientRow.Contact);
		
		ArrayOfNumbers     = New Array;
		ArrayOfNumbers.Add(RecipientRow.NumberForSending);
		SendingResult = SMS.SendSMSMessage(ArrayOfNumbers, SMSText, Object.SMSSenderName);
		
		For Each SentMessage In SendingResult.SentMessages Do
			If RecipientRow.NumberForSending = SentMessage.RecipientNumber Then
				RecipientRow.MessageID = SentMessage.MessageID;
				RecipientRow.DeliveryStatus         = Enums.SMSStatus.Outgoing;
			EndIf;;
		EndDo;
	
		If IsBlankString(SendingResult.ErrorDescription) Then
			Successfully = True;
			SuccessfullySent = SuccessfullySent + 1;
		Else
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Cannot send SMS to recipient: %1, due to: %2'; ru = 'Не удалось отправить SMS получателю: %1, по причине: %2';pl = 'Nie można wysłać SMS do odbiorcy: %1, przyczyna: %2';es_ES = 'No se puede enviar un SMS al destinatario: %1, debido a: %2';es_CO = 'No se puede enviar un SMS al destinatario: %1, debido a: %2';tr = 'Alıcıya e-posta gönderilemiyor:%1, nedeni: %2';it = 'Non è possibile inviare il SMS al destinatario: %1, a causa di: %2';de = 'SMS kann nicht an den Empfänger gesendet werden: %1, aufgrund von %2'"),
				RecipientRow.Contact,
				SendingResult.ErrorDescription,
				);
			CommonClientServer.MessageToUser(ErrorText, , , CommonClientServer.PathToTabularSection("Recipients", RecipientRow.LineNumber, "Contact"));
			Successfully = False;
		EndIf;
		
		If Successfully AND Object.CreateEvents And UseDocumentEvent Then
		
			Event = Documents.Event.CreateDocument();
			
			Event.Date = CurrentSessionDate();
			Event.EventBegin = Event.Date;
			Event.EventEnding = Event.Date;
			Event.SetNewNumber();
			
			Event.EventType = Enums.EventTypes.SMS;
			Event.Content = SMSText;
			Event.BasisDocument = Object.Ref;
			Event.State = Catalogs.JobAndEventStatuses.Completed;
			Event.Subject = Object.Subject;
			Event.Responsible = Object.Responsible;
			Event.Author = Object.Author;
			
			RowParticipants = Event.Participants.Add();
			FillPropertyValues(RowParticipants, RecipientRow);
			
			Event.Write();
			
		EndIf;
		
	EndDo;
	
	SetPrivilegedMode(False);
	
	Return SuccessfullySent;
	
EndFunction

&AtServer
Function GenerateEmailParameters(Contact, RecipientAddress, EmailBody, AttachmentsImages, UseBcc)
	
	EmailParameters = New Structure;
	
	If ValueIsFilled(Object.UserAccount.DeletePassword) Then
		EmailParameters.Insert("Password", Object.UserAccount.DeletePassword);
	EndIf;
	
	Whom = "SendTo";
	If UseBcc Then
		Whom = "Bcc";
	EndIf;
	
	If ValueIsFilled(RecipientAddress) Then
		EmailParameters.Insert("SendTo", RecipientAddress);
	EndIf;
	
	If ValueIsFilled(Object.Subject) Then
		EmailParameters.Insert("Subject", String(Object.Subject));
	EndIf;
	
	EmailAttachments = New Map;
	
	If AttachmentsImages.Count() > 0 Then
		DriveInteractions.AddAttachmentsImagesInEmail(EmailBody, EmailAttachments, AttachmentsImages);
	EndIf;
	
	AddAttachmentsFiles(EmailAttachments);
	
	EmailParameters.Insert("Body", EmailBody);
	EmailParameters.Insert("TextType", "HTML");
	EmailParameters.Insert("Attachments", EmailAttachments);
	
	Return EmailParameters;
	
EndFunction

&AtServer
Procedure AddAttachmentsFiles(EmailAttachments)
	
	For Each Attachment In Attachments Do
		AttachmentDescription = New Structure("BinaryData, Identifier");
		AttachmentDescription.BinaryData = GetFromTempStorage(Attachment.AddressInTemporaryStorage);
		AttachmentDescription.Identifier = "";
		EmailAttachments.Insert(Attachment.Presentation, AttachmentDescription);
	EndDo;
	
EndProcedure

&AtServerNoContext
Procedure SetMessageParameters(Content, Contact)
	
	AvailableParameters = New Array;
	AvailableParameters.Add("{Time}");
	AvailableParameters.Add("{Date}");
	AvailableParameters.Add("{Recipient name}");
	
	For Each Parameter In AvailableParameters Do
		If Find(Content, Parameter) = 0 Then
			Continue;
		EndIf;
		ParameterValue = GetParameterValue(Parameter, Contact);
		Content = StrReplace(Content, Parameter, ParameterValue);
	EndDo;
	
EndProcedure

&AtServerNoContext
Function GetParameterValue(Parameter, Contact)
	
	ParameterValue = "";
	
	If Parameter = "{Time}" Then
		
		ParameterValue = Format(CurrentSessionDate(), "DF=hh:mm");
		
	ElsIf Parameter = "{Date}" Then
		
		ParameterValue = Format(CurrentSessionDate(), "DLF=D");
		
	ElsIf Left(Parameter, 15) = "{Recipient name" Then
		
		If TypeOf(Contact) = Type("CatalogRef.Counterparties") Then
			ContactName = Contact.DescriptionFull;
		ElsIf TypeOf(Contact) = Type("CatalogRef.ContactPersons") Then
			ContactName = Contact.Description;
		Else
			ContactName = Contact;
		EndIf;
		
		ParameterValue = ContactName;
		
	EndIf;
	
	Return ParameterValue;
	
EndFunction

&AtClient
Procedure InsertParameter(ParameterName)
	
	If Items.ContentKind.CurrentPage = Items.ForEmail Then
		
		BeginningBookmark = 0;
		EndBookmark = 0;
		Items.FormattedDocument.GetTextSelectionBounds(BeginningBookmark, EndBookmark);
		
		Try
			
			BeginningPosition = FormattedDocument.GetBookmarkPosition(BeginningBookmark);
			EndPosition = FormattedDocument.GetBookmarkPosition(EndBookmark);
			
			If BeginningBookmark <> EndBookmark Then 
				FormattedDocument.Delete(BeginningBookmark, EndBookmark);
				Items.FormattedDocument.SetTextSelectionBounds(BeginningBookmark, BeginningBookmark);
			EndIf;
			If BeginningPosition = 0 Then
				FormattedDocument.Add(ParameterName);
			Else
				FormattedDocument.Insert(BeginningBookmark, ParameterName);
			EndIf;
			
			EndPosition = BeginningPosition + StrLen(ParameterName);
			EndBookmark = FormattedDocument.GetPositionBookmark(EndPosition);
			Items.FormattedDocument.SetTextSelectionBounds(BeginningBookmark, EndBookmark);
			
		Except
		EndTry;
		
	Else
		
		BeginRows = 0;
		ColumnBegin = 0;
		RowEnd = 0;
		ColumnEnd = 0;
		Items.Content.GetTextSelectionBounds(BeginRows,ColumnBegin,RowEnd,ColumnEnd);
		
		Object.Content = Left(Object.Content, ColumnBegin - 1) + ParameterName + Mid(Object.Content, ColumnBegin);
		
	EndIf;
	
	Modified = True;
	
EndProcedure

// Function returns the attachments in the form of the structures array to send the email.
//
&AtClient
Function Attachments(AttachmentsDrawings = Undefined)
	
	Result = New Array;
	
	For Each Attachment In Attachments Do
		AttachmentDescription = New Structure;
		AttachmentDescription.Insert("Presentation", Attachment.Presentation);
		AttachmentDescription.Insert("AddressInTemporaryStorage", Attachment.AddressInTemporaryStorage);
		AttachmentDescription.Insert("Encoding", "");
		Result.Add(AttachmentDescription);
	EndDo;
	
	Return Result;
	
EndFunction

// Procedure of interactive addition of attachments.
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

&AtServer
Procedure UpdateDeliveryStatusesAtServer()
	
	For Each Recipient In Object.Recipients Do
		
		DeliveryStatus = SMS.DeliveryStatus(Recipient.MessageID);
		Recipient.DeliveryStatus = DriveInteractions.MapSMSDeliveryStatus(DeliveryStatus);
		
	EndDo;
	
EndProcedure

&AtClient
Procedure Attachable_SetPictureForComment()
	
	DriveClientServer.SetPictureForComment(Items.GroupAdditional, Object.Comment);
	
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

// Function returns the content by selected subject.
//
&AtServerNoContext
Function GetContentSubject(EventSubject)
	
	Return EventSubject.Content;
	
EndFunction

&AtClient
Procedure ContactPickEnd(AddressInStorage, AdditionalParameters) Export
	
	If IsTempStorageURL(AddressInStorage) Then
		
		LockFormDataForEdit();
		Modified = True;
		FillContactsByAddressBook(AddressInStorage)
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FillContactsByAddressBook(AddressInStorage)
	
	RecipientsTable = GetFromTempStorage(AddressInStorage);
	CurrentRowDataProcessor = Items.Recipients.CurrentRow <> Undefined;
	
	For Each SelectedRow In RecipientsTable Do
		
		If CurrentRowDataProcessor Then
			RecipientRow = Object.Recipients.FindByID(Items.Recipients.CurrentRow);
			CurrentRowDataProcessor = False;
		Else
			RecipientRow = Object.Recipients.Add();
		EndIf;
		
		RecipientRow.Contact = SelectedRow.Contact;
		RecipientRow.HowToContact = SelectedRow.HowToContact;
		
	EndDo;
	
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

&AtServer
Procedure SaveAttachments(BulkMail)
	
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
		|SELECT
		|	BulkMailAttachedFiles.Ref
		|INTO ttAttachedFiles
		|FROM
		|	Catalog.BulkMailAttachedFiles AS BulkMailAttachedFiles
		|WHERE
		|	BulkMailAttachedFiles.FileOwner = &BulkMail
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
	Query.SetParameter("BulkMail", BulkMail);
	
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
				
				SearchParameter = New Structure("Presentation, AddressInTemporaryStorage",
					Selection.Presentation,
					Selection.AddressInTemporaryStorage);
				
				AttachmentsRows = Attachments.FindRows(SearchParameter);
				If AttachmentsRows.Count() > 0 Then
					
					FileParameters = New Structure;
					FileParameters.Insert("FilesOwner",				BulkMail);
					FileParameters.Insert("BaseName",				NameWithoutExtension);
					FileParameters.Insert("ExtensionWithoutPoint",	ExtensionWithoutDot);
					FileParameters.Insert("Author",					Users.CurrentUser());
					FileParameters.Insert("ModificationTimeUniversal", CurrentUniversalDate());
					
					AttachmentsRows[0].Ref = FilesOperations.AppendFile(FileParameters, Selection.AddressInTemporaryStorage);
					
				EndIf;
				
			EndIf;
			
		ElsIf Selection.AttachmentRefs = NULL Then
		// Delete attachment from the attached files
			
			AttachedFileObject = Selection.AttachedFileRef.GetObject();
			AttachedFileObject.SetDeletionMark(True);
			
		Else
		// Update attachment in attached files
		
			FilesOperations.RefreshFile(Selection.AttachedFileRef, 
				New Structure("FileAddressInTempStorage, TempTextStorageAddress", Selection.AddressInTemporaryStorage, ""));
		EndIf;
		
	EndDo;
	
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
	
	ThisIsEmail = Object.SendingMethod = PredefinedValue("Enum.MessageType.Email");
	If (ThisIsEmail AND Not IsBlankString(FormattedDocument.GetText())) Or (NOT ThisIsEmail AND Not IsBlankString(Object.Content)) Then
		
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
	
	If Object.SendingMethod = PredefinedValue("Enum.MessageType.Email") Then
		SetHTMLContentByEventSubject(FormattedDocument, EventSubject);
	Else
		Object.Content = GetContentSubject(EventSubject);
	EndIf;
	
EndProcedure

// Procedure sets the formatted document content by the selected subject.
//
&AtServerNoContext
Procedure SetHTMLContentByEventSubject(FormattedDocument, EventSubject)
	
	FormattedDocument.SetFormattedString(New FormattedString(EventSubject.Content));
	
EndProcedure

// Procedure fills subject selection data.
//
// Parameters:
//  SearchString - String	 - The SubjectHistoryByRow text being typed - ValueList	 - Used subjects in the row form
&AtServerNoContext
Function GetSubjectChoiceList(val SearchString)
	
	ListChoiceOfTopics = New ValueList;
	
	ChoiceParameters = New Structure;
	ChoiceParameters.Insert("Filter", New Structure("DeletionMark", False));
	ChoiceParameters.Insert("SearchString", SearchString);
	ChoiceParameters.Insert("ChoiceFoldersAndItems", FoldersAndItemsUse.Items);
	
	SubjectSelectionData = Catalogs.EventsSubjects.GetChoiceData(ChoiceParameters);
	
	For Each ItemOfList In SubjectSelectionData Do
		ListChoiceOfTopics.Add(ItemOfList.Value, New FormattedString(ItemOfList.Presentation, " (event subject)"));
	EndDo;
	
	Return ListChoiceOfTopics;
	
EndFunction

&AtClient
Procedure RecipientsContactSelectionEnd(AddressInStorage, AdditionalParameters) Export
	
	If IsTempStorageURL(AddressInStorage) Then
		
		LockFormDataForEdit();
		Modified = True;
		FillContactsByAddressBook(AddressInStorage);
		
	EndIf;
	
EndProcedure

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

#EndRegion

#Region Internal

#Region LibrariesHandlers

// StandardSubsystems.AttachableCommands
&AtClient
Procedure Attachable_ExecuteCommand(Command)
	AttachableCommandsClient.ExecuteCommand(ThisObject, Command, Object);
EndProcedure

&AtServer
Procedure Attachable_ExecuteCommandAtServer(Context, Result)
	AttachableCommands.ExecuteCommand(ThisObject, Context, Object, Result);
EndProcedure

&AtClient
Procedure Attachable_UpdateCommands()
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
EndProcedure
// End StandardSubsystems.AttachableCommands

#EndRegion

#EndRegion