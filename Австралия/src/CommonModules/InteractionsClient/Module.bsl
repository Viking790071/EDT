///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#Region Public

// Opens the form of a new document "SMS" containing the passed parameters.
//
// Parameters:
//   FormParameters - Structure  - see InteractionsClient.SMSSendingFormParameters. 
//   DeleteText - String - not used.
//   DeleteSubject - Reference - not used.
//   DeleteSendInTransliteration - Boolean - not used.
//
Procedure OpenSMSMessageSendingForm(Val FormParameters = Undefined,
    Val DeleteText = "", Val DeleteSubject = Undefined, Val DeleteSendInTransliteration = False) Export
	
	If TypeOf(FormParameters) <> Type("Structure") Then
		Parameters = SMSMessageSendingFormParameters();
		Parameters.Recipients = FormParameters;
		Parameters.Text = DeleteText;
		Parameters.Topic = DeleteSubject;
		Parameters.SendInTransliteration = DeleteSendInTransliteration;
		FormParameters = Parameters;
	EndIf;								  
	OpenForm("Document.SMSMessage.ObjectForm", FormParameters);
	
EndProcedure

// Returns the parameters to pass to InteractionsClient.OpenSMSSendingForm.
//
// Returns:
//  Structure - with the following properties:
//   * Addressees - String, ValueList, Array - a list of email recipients.
//   * Text - String - an email text.
//   * Subject - Ref - an email subject.
//   * SendInTransliteration - Boolean - indicates that a message must be transformed into Latin 
//                                     characters when sending it.
Function SMSMessageSendingFormParameters() Export
	
	Result = New Structure;
	Result.Insert("Recipients", Undefined);
	Result.Insert("Text", "");
	Result.Insert("Topic", Undefined);
	Result.Insert("SendInTransliteration", False);
	Return Result;
	
EndFunction

// AfterWriteAtServer form event handler. This procedure is called for a contact.
//
// Parameters:
//  Form                         - ClientApplicationForm - a form for which the event is being processed.
//  Object - FormDataCollection - an object data stored in the form.
//  WriteParameters                - Structure - a structure that gets parameters that will be sent 
//                                               with a notification.
//  MessageSenderObjectName - String - a metadata object name, for whose form an event is processed.
//  SendNotification  - Boolean   - indicates that it is necessary to send a notification from this procedure.
//
Procedure ContactAfterWrite(Form,Object,WriteParameters,MessageSenderObjectName,SendNotification = True) Export
	
	If Form.NotificationRequired Then
		
		If ValueIsFilled(Form.BasisObject) Then
			WriteParameters.Insert("Ref",Object.Ref);
			WriteParameters.Insert("Description",Object.Description);
			WriteParameters.Insert("Basis",Form.BasisObject);
			WriteParameters.Insert("NotificationType","WriteContact");
		EndIf;
		
		If SendNotification Then
			Notify("Write_" + MessageSenderObjectName,WriteParameters,Object.Ref);
			Form.NotificationRequired = False
		EndIf;
		
	EndIf;
	
EndProcedure

// AfterWriteAtServer form event handler. This procedure is called for an interaction or an interaction subject.
//
// Parameters:
//  Form                         - ClientApplicationForm - a form for which the event is being processed.
//  Object - FormDataCollection - an object data stored in the form.
//  WriteParameters                - Structure - a structure that gets parameters that will be sent 
//                                               with a notification.
//  MessageSenderObjectName - String - a metadata object name, for whose form an event is processed.
//  SendNotification  - Boolean   - indicates that it is necessary to send a notification from this procedure.
// 
Procedure InteractionSubjectAfterWrite(Form,Object,WriteParameters,MessageSenderObjectName = "",SendNotification = True) Export
		
	If ValueIsFilled(Form.InteractionBasis) Then
		WriteParameters.Insert("Basis",Form.InteractionBasis);
	Else
		WriteParameters.Insert("Basis",Undefined);
	EndIf;
	
	If InteractionsClientServer.IsInteraction(Object.Ref) Then
		WriteParameters.Insert("Topic",Form.Topic);
		WriteParameters.Insert("NotificationType","WriteInteraction");
	ElsIf InteractionsClientServer.IsSubject(Object.Ref) Then
		WriteParameters.Insert("Topic",Object.Ref);
		WriteParameters.Insert("NotificationType","WriteSubject");
	EndIf;
	
	If SendNotification Then
		Notify("Write_" + MessageSenderObjectName,WriteParameters,Object.Ref);
		Form.NotificationRequired = False;
	EndIf;
	
EndProcedure

// DragCheck form event handler. It is called for a list of subjects when dragging interactions to it.
//
// Parameters:
//  Item - FormTable - a table, for which the event is being processed.
//  DragParameters   - DragParameters - contains a dragged value, an action type, and possible 
//                                                        values when dragging.
//  StandardProcessing - Boolean - indicates a standard event processing.
//  String                    - TableRow -  a table row, on which the pointer is positioned.
//  Field                      - Field - a managed form item, to which this table column is connected.
//
Procedure ListSubjectDragCheck(Item, DragParameters, StandardProcessing, Row, Field) Export
	
	If (Row = Undefined) OR (DragParameters.Value = Undefined) Then
		Return;
	EndIf;
	
	StandardProcessing = False;
	
	If TypeOf(DragParameters.Value) = Type("Array") Then
		
		For each ArrayElement In DragParameters.Value Do
			If InteractionsClientServer.IsInteraction(ArrayElement) Then
				Return;
			EndIf;
		EndDo;
	EndIf;
	
	DragParameters.Action = DragAction.Cancel;
	
EndProcedure

// Drag form event handler. It is called for the list of values when dragging interactions to it.
//
// Parameters:
//  Item - FormTable - a table, for which the event is being processed.
//  DragParameters   - DragParameters - contains a dragged value, an action type, and possible 
//                                                        values when dragging.
//  StandardProcessing - Boolean - indicates a standard event processing.
//  String                    - TableRow -  a table row, on which the pointer is positioned.
//  Field                      - Field - a managed form item, to which this table column is connected.
//
Procedure ListSubjectDrag(Item, DragParameters, StandardProcessing, Row, Field) Export
	
	StandardProcessing = False;
	
	If TypeOf(DragParameters.Value) = Type("Array") Then
		
		InteractionsServerCall.SetSubjectForInteractionsArray(DragParameters.Value,
			Row, True);
			
	EndIf;
	
	Notify("InteractionSubjectEdit");
	
EndProcedure

// Saves an email to hard drive.
//
// Parameters:
//  Email - DocumentRef.IncomingEmail,
//                            DocumentRef.OutgoingEmail - an email that will be saved.
//  UUID - UUID - an UUID of a form, from which a saving command was called.
//
Procedure SaveEmailToHardDrive(Email, UUID) Export
	
	FileData = InteractionsServerCall.EmailDataToSaveAsFile(Email, UUID);
	
	If FileData = Undefined Then
		Return;
	EndIf;
	
	FilesOperationsClient.SaveFileAs(FileData);

EndProcedure

#EndRegion

#Region Internal

// Opens a new form of the "Outgoing email" document
// with parameters passed to the procedure.
//
// Parameters:
//  EmailParameters - Structure - see EmailOperationsClient.EmailSendOptions. 
//  OnCloseNotifyDescription - NotifyDescription - details of notification on closing an email form.
//
Procedure OpenEmailSendingForm(Val EmailParameters = Undefined, Val OnCloseNotifyDescription = Undefined) Export
	
	OpenForm("Document.OutgoingEmail.ObjectForm", EmailParameters, , , , , OnCloseNotifyDescription);
	
EndProcedure

#EndRegion

#Region Private

// Creates an interaction or an interaction subject.
// Parameters:
//  ObjectFormName - item form name of the object being created,
//  Basis - a base object,
//  Source        - a base object form.
//
Procedure CreateInteractionOrSubject(ObjectFormName, Basis, Source) Export

	FormOpenParameters = New Structure("Basis", Basis);
	If (TypeOf(Basis) = Type("DocumentRef.Meeting") 
	    OR  TypeOf(Basis) = Type("DocumentRef.PlannedInteraction"))
		AND Source.Items.Find("Members") <> Undefined
		AND Source.Items.Members.CurrentData <> Undefined Then
	
	    ParticipantDataSource = Source.Items.Members.CurrentData;
	    FormOpenParameters.Insert("ParticipantData",New Structure("Contact,HowToContact,Presentation",
	                                                                      ParticipantDataSource.Contact,
	                                                                      ParticipantDataSource.HowToContact,
	                                                                      ParticipantDataSource.ContactPresentation));
	
	ElsIf (TypeOf(Basis) = Type("DocumentRef.SMSMessage") 
		AND Source.Items.Find("Recipients") <> Undefined
		AND Source.Items.Recipients.CurrentData <> Undefined) Then
		
		ParticipantDataSource = Source.Items.Recipients.CurrentData;
		FormOpenParameters.Insert("ParticipantData",New Structure("Contact,HowToContact,Presentation",
		                                                                  ParticipantDataSource.Contact,
		                                                                  ParticipantDataSource.HowToContact,
		                                                                  ParticipantDataSource.ContactPresentation));
	
	EndIf;
	
	OpenForm(ObjectFormName, FormOpenParameters, Source);

EndProcedure

// Opens a contact object form filled according to an interaction participant details.
// Parameters:
//  Description  - a text contact details,
//  Address - contact information,
//  Basis - an object, from which a contact is created.
//
Procedure CreateContact(Details, Address, Basis,ContactsTypes) Export

	If ContactsTypes.Count() = 0 Then
		Return;
	EndIf;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("Details", Details);
	AdditionalParameters.Insert("Address", Address);
	AdditionalParameters.Insert("Basis", Basis);
	NotificationHandler = New NotifyDescription("SelectContactTypeOnCompletion", ThisObject, AdditionalParameters);
	ContactsTypes.ShowChooseItem(NotificationHandler, NStr("ru = 'Выбор типа контакта'; en = 'Select contact type'; pl = 'Wybierz typ kontaktu';es_ES = 'Seleccionar tipo de contacto';es_CO = 'Seleccionar tipo de contacto';tr = 'Kişi türü seç';it = 'Selezionare tipo contatto';de = 'Kontakttyp auswählen'"));

EndProcedure

// A notification handler for contact type choice when creating a contact from interaction documents.
// Parameters:
//  SelectionResult - ValueListItem - item value contains a string contact type presentation,
//  AdditionalParameters - Structure - contains fields "Description", "Address" and "Basis".
//
Procedure SelectContactTypeOnCompletion(SelectionResult, AdditionalParameters) Export

	If SelectionResult = Undefined Then
		Return;
	EndIf;
	
	FormParameter = New Structure("Basis", AdditionalParameters);
	Contacts = InteractionsClientServer.ContactsDetails();
	NewContactFormName = "";
	For each Contact In Contacts Do
		If Contact.Name = SelectionResult.Value Then
			NewContactFormName = Contact.NewContactFormName; 
		EndIf;
	EndDo;
	
	If IsBlankString(NewContactFormName) Then
		// ACC:223-off For backward compatibility.
		If InteractionsClientOverridable.CreateContactNonstandardForm(SelectionResult.Value, FormParameter) Then
			Return;
		EndIf;
		// ACC:223-on
		NewContactFormName = "Catalog." + SelectionResult.Value + ".ObjectForm";
	EndIf;
	
	OpenForm(NewContactFormName, FormParameter);

EndProcedure

// NotificationProcessing form event handler. This procedure is called for an interaction.
Procedure ProcessNotification(Form,EventName, Parameter, Source) Export
	
	If TypeOf(Parameter) = Type("Structure") AND Parameter.Property("NotificationType") Then
		If (Parameter.NotificationType = "WriteInteraction" OR Parameter.NotificationType = "WriteSubject")
			AND Parameter.Basis = Form.Object.Ref Then
			
			If (Form.Topic = Undefined OR InteractionsClientServer.IsInteraction(Form.Topic))
				AND Form.Topic <> Parameter.Topic Then
				Form.Topic = Parameter.Topic;
				Form.RepresentDataChange(Form.Topic, DataChangeType.Update);
			EndIf;
			
		ElsIf Parameter.NotificationType = "WriteContact" AND Parameter.Basis = Form.Object.Ref Then
			
			If TypeOf(Form.Object.Ref)=Type("DocumentRef.PhoneCall") Then
				Form.Object.SubscriberContact = Parameter.Ref;
				If IsBlankString(Form.Object.SubscriberPresentation) Then
					Form.Object.SubscriberPresentation = Parameter.Description;
				EndIf;
			ElsIf TypeOf(Form.Object.Ref)=Type("DocumentRef.Meeting") 
				OR TypeOf(Form.Object.Ref)=Type("DocumentRef.PlannedInteraction")Then
				Form.Items.Members.CurrentData.Contact = Parameter.Ref;
				If IsBlankString(Form.Items.Members.CurrentData.ContactPresentation) Then
					Form.Items.Members.CurrentData.ContactPresentation = Parameter.Description;
				EndIf;
			ElsIf TypeOf(Form.Object.Ref)=Type("DocumentRef.SMSMessage") Then
				Form.Items.Recipients.CurrentData.Contact = Parameter.Ref;
				If IsBlankString(Form.Items.Recipients.CurrentData.ContactPresentation) Then
					Form.Items.Recipients.CurrentData.ContactPresentation = Parameter.Description;
				EndIf;
			EndIf;
			
			Form.Items.CreateContact.Enabled = False;
			Form.Modified = True;
			
		EndIf;
		
	ElsIf EventName = "ContactSelected" Then
		
		If Form.FormName = "Document.OutgoingEmail.Form.DocumentForm" 
			OR Form.FormName = "Document.IncomingEmail.Form.DocumentForm" Then
			Return;
		EndIf;
		
		If Form.UUID <> Parameter.FormID Then
			Return;
		EndIf;
		
		ContactChanged = (Parameter.Contact <> Parameter.SelectedContact) AND ValueIsFilled(Parameter.Contact);
		Contact = Parameter.SelectedContact;
		If Parameter.EmailOnly Then
			ContactInformationType = PredefinedValue("Enum.ContactInformationTypes.EmailAddress");
		ElsIf Parameter.PhoneOnly Then
			ContactInformationType = PredefinedValue("Enum.ContactInformationTypes.Phone");
		Else
			ContactInformationType = Undefined;
		EndIf;
		
		If ContactChanged Then
			
			If NOT Parameter.ForContactSpecificationForm Then
				InteractionsServerCall.PresentationAndAllContactInformationOfContact(
				             Contact, Parameter.Presentation, Parameter.Address, ContactInformationType);
			EndIf;
			
			Address         = Parameter.Address;
			Presentation = Parameter.Presentation;
			
		ElsIf Parameter.ReplaceEmptyAddressAndPresentation AND (IsBlankString(Parameter.Address) OR IsBlankString(Parameter.Presentation)) Then
			
			nPresentation = ""; 
			nAddress = "";
			InteractionsServerCall.PresentationAndAllContactInformationOfContact(
			             Contact, nPresentation, nAddress, ContactInformationType);
			
			Presentation = ?(IsBlankString(Parameter.Presentation), nPresentation, Parameter.Presentation);
			Address         = ?(IsBlankString(Parameter.Address), nAddress, Parameter.Address);
			
		Else
			
			Address         = Parameter.Address;
			Presentation = Parameter.Presentation;
			
		EndIf;
		
		If Form.FormName = "CommonForm.AddressBookForEmail" Then

			CurrentData = Form.Items.EmailRecipients.CurrentData;
			If CurrentData = Undefined Then
				Return;
			EndIf;
			
			CurrentData.Contact       = Contact;
			CurrentData.Address         = Address;
			CurrentData.Presentation = Presentation;
			
			Form.Modified = True;
			
		ElsIf TypeOf(Form.Object.Ref)=Type("DocumentRef.SMSMessage") Then
			CurrentData = Form.Items.Recipients.CurrentData;
			If CurrentData = Undefined Then
				Return;
			EndIf;
			
			Form.ContactsChanged = True;
			
			CurrentData.Contact               = Contact;
			CurrentData.HowToContact          = Address;
			CurrentData.ContactPresentation = Presentation;
			
			InteractionsClientServer.CheckContactsFilling(Form.Object,Form,"SMSMessage");
			
		ElsIf TypeOf(Form.Object.Ref)=Type("DocumentRef.PlannedInteraction") Then
			CurrentData = Form.Items.Members.CurrentData;
			If CurrentData = Undefined Then
				Return;
			EndIf;
			
			Form.ContactsChanged = True;
			
			CurrentData.Contact               = Contact;
			CurrentData.HowToContact          = Address;
			CurrentData.ContactPresentation = Presentation;
			
			InteractionsClientServer.CheckContactsFilling(Form.Object,Form,"PlannedInteraction");
			Form.Modified = True;
			
		ElsIf TypeOf(Form.Object.Ref)=Type("DocumentRef.Meeting") Then
			CurrentData = Form.Items.Members.CurrentData;
			If CurrentData = Undefined Then
				Return;
			EndIf;
			
			Form.ContactsChanged = True;
			
			CurrentData.Contact               = Contact;
			CurrentData.HowToContact          = Address;
			CurrentData.ContactPresentation = Presentation;
			
			InteractionsClientServer.CheckContactsFilling(Form.Object,Form,"PlannedInteraction");
			Form.Modified = True;
			
		ElsIf TypeOf(Form.Object.Ref)=Type("DocumentRef.PhoneCall") Then
			
			Form.ContactsChanged = True;
			
			Form.Object.SubscriberContact       = Contact;
			Form.Object.HowToContactSubscriber  = Address;
			Form.Object.SubscriberPresentation = Presentation;
			
			InteractionsClientServer.CheckContactsFilling(Form.Object,Form,"PhoneCall");
			Form.Modified = True;
			
		EndIf;
		
	ElsIf EventName = "WriteInteraction"
		AND Parameter = Form.Object.Ref Then
		
		Form.Read();
		
	EndIf;
	
EndProcedure

// Creates a new interaction document.
//
// Parameters:
//  ObjectType - String - a type of the object to be created.
//  CreationParameters - Structure - parameters of a document to be created.
//  ItemList    - FormTable - a form item, where a document is created.
//
Procedure CreateNewInteraction(ObjectType,CreationParameters = Undefined, Form = Undefined) Export

	OpenForm("Document."+ ObjectType+".ObjectForm",CreationParameters, Form);

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Common event handlers of interaction documents

// Calls a contact choice form and processes the choice result.
//
// Parameters:
//  Subject                           - Ref - a reference to an interaction subject.
//  Address - String - a contact address.
//  Presentation - String - a contact presentation.
//  Contact - Ref - a contact.
//  Parameters - Structure - a structure of form opening parameters, consists of:
//                                                EmailOnly,
//                                                PhoneOnly,
//                                                ReplaceEmptyAddressAndPresentation,
//                                                ForRefineContactsForm.
//
Procedure SelectContact(Topic, Address, Presentation, Contact, Parameters) Export

	OpeningParameters = New Structure;
	OpeningParameters.Insert("Topic",                           Topic);
	OpeningParameters.Insert("Address",                             Address);
	OpeningParameters.Insert("Presentation",                     Presentation);
	OpeningParameters.Insert("Contact",                           Contact);
	OpeningParameters.Insert("EmailOnly",                       Parameters.EmailOnly);
	OpeningParameters.Insert("PhoneOnly",                     Parameters.PhoneOnly);
	OpeningParameters.Insert("ReplaceEmptyAddressAndPresentation", Parameters.ReplaceEmptyAddressAndPresentation);
	OpeningParameters.Insert("ForContactSpecificationForm",        Parameters.ForContactSpecificationForm);
	OpeningParameters.Insert("FormID",                Parameters.FormID);
	
	OpenForm("CommonForm.SelectContactPerson", OpeningParameters);

EndProcedure

// Processing the "review after" field choice in interaction documents.
//
// Parameters:
//  FieldValue         - Date - "Process after" field value.
//  SelectedValue    - Date, number - either the selected value or a numeric increment of the current date.
//  StandardProcessing - Boolean - indicates a standard processing of a form event handler.
//  Modified  - Boolean - indicates that the form was modified.
//
Procedure ProcessSelectionInReviewAfterField(FieldValue, SelectedValue, StandardProcessing, Modified) Export
	
	StandardProcessing = False;
	Modified = True;
	
	If TypeOf(SelectedValue) = Type("Number") Then
		FieldValue = CommonClient.SessionDate() + SelectedValue;
	Else
		FieldValue = SelectedValue;
	EndIf;
	
EndProcedure

// Sets filter by owner in the subordinate catalog dynamic list when activating a row of parent 
// catalog dynamic list.
 //
// Parameters:
 //  Item  		- FormTable - a table, where the event has happened.
 //  Form		 	 - ClientApplicationForm - a form where the items are located.
 //
Procedure ContactOwnerOnActivateRow(Item,Form)  Export
	
	TableNameWithoutPrefix = Right(Item.Name,StrLen(Item.Name)-8);
	FilterValue = ?(Item.CurrentData = Undefined, Undefined, Item.CurrentData.Ref);
	
	ContactsDetailsArray = InteractionsClientServer.ContactsDetails();
	For each DetailsArrayElement In ContactsDetailsArray  Do
		If DetailsArrayElement.OwnerName = TableNameWithoutPrefix Then
			FiltersCollection = Form["List_" + DetailsArrayElement.Name].SettingsComposer.FixedSettings.Filter;
			FiltersCollection.Items[0].RightValue = FilterValue;
		EndIf;
	EndDo;
 
EndProcedure 

// Asks the user when changing an email formatting mode from HTML to plain text.
Procedure PromptOnChangeMessageFormatToPlainText(Form, AdditionalParameters = Undefined) Export
	
	OnCloseNotifyHandler = New NotifyDescription("PromptOnChangeFormatOnClose", Form, AdditionalParameters);
	MessageText = NStr("ru = 'При преобразовании этого сообщения в обычный текст будут утеряны все элементы оформления, картинки и прочие вставленные элементы. Продолжить?'; en = 'When converting this message into plain text, all appearance items, pictures and other added items will be lost. Do you want to continue?'; pl = 'Przy konwertowaniu tej wiadomości do tekstu zwykłego, wszystkie zastosowane pozycje, obrazy i inne dodane elementy zostaną stracone. Czy chcesz kontynuować?';es_ES = 'Al convertir este mensaje en texto sin formato, se perderán todos los elementos de apariencia, imágenes y otros elementos añadidos. ¿Quiere continuar?';es_CO = 'Al convertir este mensaje en texto sin formato, se perderán todos los elementos de apariencia, imágenes y otros elementos añadidos. ¿Quiere continuar?';tr = 'Bu ileti düz metne dönüştürülürken tüm görsel öğeler, resimler ve eklenen diğer öğeler kaybolacak. Devam edilsin mi?';it = 'Durante la conversione di questo messaggio in testo semplice, tutti gli elementi, immagini e altri elementi aggiuntivi andranno persi. Continuare?';de = 'Beim Konvertieren dieser Nachricht in den reinen Text werden alle Sichtteile, Bilder und weiteren hinzugefügten Teile verloren. Möchten Sie fortfahren?'");
	ShowQueryBox(OnCloseNotifyHandler, MessageText, QuestionDialogMode.YesNo, , DialogReturnCode.No, NStr("ru = 'Изменение формата письма'; en = 'Change email format'; pl = 'Zmień format wiadomości e-maila';es_ES = 'Cambiar el formato del correo electrónico';es_CO = 'Cambiar el formato del correo electrónico';tr = 'E-posta formatını değiştir';it = 'Cambia formato email';de = 'E-Mail-Format ändern'"));
	
EndProcedure

// Handler before adding dynamic lists of interaction log.
//
// Parameters:
//  Item - FormItem - a list, to which items are added.
//  Cancel  - Boolean - indicates that adding is canceled.
//  Copy  - Boolean - a copying flag.
//  EmailOnly  - EmailOnly - shows that only an email client is used.
//  DocumentsAvailableForCreation - ValueList - a list of documents available for creation.
//  CreationParameters - Structure - new document creation parameters.
//
Procedure ListBeforeAddRow(Item, Cancel, Clone,EmailOnly,DocumentsAvailableForCreation,CreationParameters = Undefined) Export
	
	If Clone Then
		
		CurrentData = Item.CurrentData;
		If CurrentData = Undefined Then
			Cancel = True;
			Return;
		EndIf;
		
		If TypeOf(CurrentData.Ref) = Type("DocumentRef.IncomingEmail") 
			Or TypeOf(CurrentData.Ref) = Type("DocumentRef.OutgoingEmail") Then
			Cancel = True;
			If Not EmailOnly Then
				ShowMessageBox(, NStr("ru = 'Копирование электронных писем запрещено'; en = 'Email copying is not allowed.'; pl = 'Kopiowanie wiadomości e-mail jest zabronione.';es_ES = 'No está permitido copiar el correo electrónico.';es_CO = 'No está permitido copiar el correo electrónico.';tr = 'E-posta kopyalamaya izin verilmiyor.';it = 'Non è permesso copiare le email.';de = 'Kopieren von E-Mails ist nicht gestattet.'"));
			EndIf;
		EndIf;
		
	EndIf;
	
EndProcedure

// Handler for the OnClick form event of the HTML document field.
//
// Parameters:
//  Item - FormItem - a form, for which the event is being processed.
//  EventData                  - FixedStructure - data contains event parameters.
//  StandardProcessing           - Boolean - indicates a standard event processing.
//
Procedure HTMLFieldOnClick(Item, EventData, StandardProcessing) Export
	
	If EventData.Href <> Undefined Then
		StandardProcessing = FALSE;
		
		FileSystemClient.OpenURL(EventData.Href);
		
	EndIf;
	
EndProcedure

// Checks if the DateWhenToSendEmail and EmailSendingRelevance attributes in the document form are 
// filled in correctly.
//
// Parameters:
//  Object - DocumentObject - a document being checked.
//  Cancel  - Boolean - sets to true if attributes are filled incorrectly.
//
Procedure CheckOfDeferredSendingAttributesFilling(Object, Cancel) Export
	
	If Object.DateToSendEmail > Object.EmailSendingRelevanceDate AND (Not Object.EmailSendingRelevanceDate = Date(1,1,1)) Then
		
		Cancel = True;
		MessageText= NStr("ru = 'Дата актуальности отправки меньше чем дата отправки.'; en = 'The sending relevance date is earlier than the sending date.'; pl = 'Data aktualności wysyłki jest wcześniejsza niż data wysyłki.';es_ES = 'La fecha de relevancia del envío es anterior a la fecha de envío.';es_CO = 'La fecha de relevancia del envío es anterior a la fecha de envío.';tr = 'Gönderim uygunluğu tarihi gönderim tarihinden önce.';it = 'La data rilevante per l''invio è precedente alla data di invio.';de = 'Das Sendewichtigkeitsdatum ist früher als das Sendedatum.'");
		CommonClientServer.MessageToUser(MessageText,, "Object.EmailSendingRelevanceDate");
		
	EndIf;
	
	If NOT Object.EmailSendingRelevanceDate = Date(1,1,1)
			AND Object.EmailSendingRelevanceDate < CommonClient.SessionDate() Then
	
		Cancel = True;
		MessageText= NStr("ru = 'Указанная дата актуальности меньше текущей даты, такое сообщение никогда не будет отправлено'; en = 'The specified relevance date is less than the current date. The message will never be sent.'; pl = 'Podana data aktualności jest mniejsza niż bieżąca data. Taka wiadomość nie może być wysłana.';es_ES = 'La fecha de relevancia especificada es menor que la fecha actual. Este mensaje no se enviará nunca.';es_CO = 'La fecha de relevancia especificada es menor que la fecha actual. Este mensaje no se enviará nunca.';tr = 'Belirtilen uygunluk tarihi mevcut tarihten önce. İleti gönderilemez.';it = 'La data rilevante specificata è precedente alla data corrente. Il messaggio non sarà più inviato.';de = 'Das angegebene Wichtigkeitsdatum ist weniger als das aktuelles Datum. Die Nachricht wird niemals gesendet.'");
		CommonClientServer.MessageToUser(MessageText,, "Object.EmailSendingRelevanceDate");
	
	EndIf;
	
EndProcedure

Procedure SubjectStartChoice(Form, Item, ChoiceData, StandardProcessing) Export
	
	StandardProcessing = False;
	
	OpenForm("DocumentJournal.Interactions.Form.SelectSubjectType", ,Form);
	
EndProcedure

Procedure ChoiceProcessingForm(Form, SelectedValue, ChoiceSource, ChoiceContext) Export
	
	 If Upper(ChoiceSource.FormName) = Upper("DocumentJournal.Interactions.Form.SelectSubjectType") Then
		
		FormParameters = New Structure;
		FormParameters.Insert("ChoiceMode", True);
		
		ChoiceContext = "SelectSubject";
		
		OpenForm(SelectedValue + ".ChoiceForm", FormParameters, Form);
		
	ElsIf ChoiceContext = "SelectSubject" Then
		
		If InteractionsClientServer.IsSubject(SelectedValue)
			Or InteractionsClientServer.IsInteraction(SelectedValue) Then
		
			Form.Topic = SelectedValue;
			Form.Modified = True;
		
		EndIf;
		
		ChoiceContext = Undefined;
		
	EndIf;
	
EndProcedure

Procedure OpenAttachmentEmail(EmailAttachmentFile, OpeningParameters , Form) Export
	
	ClearMessages();
	FormParameters = New Structure;
	FormParameters.Insert("Email",                       EmailAttachmentFile);
	FormParameters.Insert("DoNotCallPrintCommand",      OpeningParameters.DoNotCallPrintCommand);
	FormParameters.Insert("UserAccountUsername", OpeningParameters.UserAccountUsername);
	FormParameters.Insert("DisplayEmailAttachments",     OpeningParameters.DisplayEmailAttachments);
	FormParameters.Insert("BaseEmailDate",          OpeningParameters.BaseEmailDate);
	FormParameters.Insert("EmailBasis",              OpeningParameters.EmailBasis);
	FormParameters.Insert("BaseEmailSubject",          OpeningParameters.BaseEmailSubject);
	
	OpenForm("DocumentJournal.Interactions.Form.PrintEmail", FormParameters, Form);
	
EndProcedure

// Generates a default attachment email structure that is passed to the view and print form.
//
// Parameters:
//
// Returns:
//   Structure   - contains the following parameters.
//     *BaseEmailDate          - Date - a base email date.
//     *UserAccountUserName - String - user of an account that received a base email.
//     *DoNotCallPrintCommand      - Boolean - indicates that it is not required to call OS print 
//                                              command when opening a form.
//     *BaseEmail              - Undefined,
//                                   - Row,
//                                   - DocumentRef.IncomingEmail,
//                                   - DocumentRef.OutgoingEmail - a reference to a base email or 
//                                                                                 its presentation.
//     *BaseEmailSubject          - String - a base email subject.
//
Function EmptyStructureOfAttachmentEmailParameters() Export

	OpeningParameters = New Structure;
	OpeningParameters.Insert("BaseEmailDate", Date(1, 1, 1));
	OpeningParameters.Insert("UserAccountUsername", "");
	OpeningParameters.Insert("DoNotCallPrintCommand", True);
	OpeningParameters.Insert("DisplayEmailAttachments", True);
	OpeningParameters.Insert("EmailBasis", Undefined);
	OpeningParameters.Insert("BaseEmailSubject", "");
	
	Return OpeningParameters;

EndFunction 

////////////////////////////////////////////////////////////////////////////////
// Defining a referenec type.

// Determines whether a reference passed to the function is an interaction or not.
//
// Parameters:
//  ObjectRef - Ref - a reference, to which a check is required.
//
// Returns:
//   Boolean   - True if the passed reference is an interaction.
//
Function IsEmail(ObjectRef) Export
	
	Return TypeOf(ObjectRef) = Type("DocumentRef.IncomingEmail")
		OR TypeOf(ObjectRef) = Type("DocumentRef.OutgoingEmail");
	
EndFunction

#EndRegion
