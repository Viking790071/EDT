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
	
	If Object.Ref.IsEmpty() Then
		Object.State = Enums.SMSMessageStatusDocument.Draft;
		Reviewed = True;
		OnCreatReadAtServer();
		Interactions.SetSubjectByFillingData(Parameters, Topic);
		ContactsChanged = True;
	EndIf;
	
	If NOT FileInfobase Then
		Items.AddresseesCheckDeliveryStatuses.Visible = False;
	EndIf;
	
	Items.SendInTransliteration.Visible = False;
	
	Interactions.FillChoiceListForReviewAfter(Items.ReviewAfter.ChoiceList);
	
	// Determining types of contacts that can be created.
	ContactsToInteractivelyCreateList = Interactions.CreateValueListOfInteractivelyCreatedContacts();
	Items.CreateContact.Visible      = ContactsToInteractivelyCreateList.Count() > 0;
	
	// Preparing interaction notifications.
	Interactions.PrepareNotifications(ThisObject, Parameters);
	
	// StandardSubsystems.AttachableCommands
	If Common.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommands = Common.CommonModule("AttachableCommands");
		ModuleAttachableCommands.OnCreateAtServer(ThisObject);
	EndIf;
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.Properties
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("ItemForPlacementName", "AdditionalAttributesPage");
		AdditionalParameters.Insert("DeferredInitialization", True);
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.OnCreateAtServer(ThisObject, AdditionalParameters);
	EndIf;
	// End StandardSubsystems.Properties
	
	// StandardSubsystems.FilesOperations
	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperations = Common.CommonModule("FilesOperations");
		FilesHyperlink = ModuleFilesOperations.FilesHyperlink();
		FilesHyperlink.Placement = "CommandBar";
		ModuleFilesOperations.OnCreateAtServer(ThisObject, FilesHyperlink);
	EndIf;
	// End StandardSubsystems.FilesOperations
	
	// StandardSubsystems.MessagesTemplates
	DeterminePossibilityToFillEmailByTemplate();
	// End StandardSubsystems.MessagesTemplates
	
EndProcedure

&AtServer
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	Interactions.OnWriteInteractionFromForm(CurrentObject, ThisObject);
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)

	// StandardSubsystems.AccessManagement
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.AfterWriteAtServer(ThisObject, CurrentObject, WriteParameters);
	EndIf;
	// End StandardSubsystems.AccessManagement
	
	Items.CommentPage.Picture = CommonClientServer.CommentPicture(Object.Comment);

EndProcedure 

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	Interactions.SetInteractionFormAttributesByRegisterData(ThisObject);
	
	// StandardSubsystems.Properties
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.OnReadAtServer(ThisObject, CurrentObject);
	EndIf;
	// End StandardSubsystems.Properties
	
	OnCreatReadAtServer();
	
	// StandardSubsystems.AttachableCommands
	If Common.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommandsClientServer = Common.CommonModule("AttachableCommandsClientServer");
		ModuleAttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
	EndIf;
	// End StandardSubsystems.AttachableCommands

	// StandardSubsystems.AccessManagement
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.OnReadAtServer(ThisObject, CurrentObject);
	EndIf;
	// End StandardSubsystems.AccessManagement

EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	Items.MessageText.UpdateEditText();
	
	// StandardSubsystems.Properties
	If CommonClient.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerClient = CommonClient.CommonModule("PropertyManagerClient");
		ModulePropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	EndIf;
	// End StandardSubsystems.Properties
	
	CheckContactCreationAvailability();
	
	// StandardSubsystems.AttachableCommands
	If CommonClient.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleAttachableCommandsClient = CommonClient.CommonModule("AttachableCommandsClient");
		ModuleAttachableCommandsClient.StartCommandUpdate(ThisObject);
	EndIf;
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.FilesOperations
	If CommonClient.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsClient = CommonClient.CommonModule("FilesOperationsClient");
		ModuleFilesOperationsClient.OnOpen(ThisObject, Cancel);
	EndIf;
	// End StandardSubsystems.FilesOperations

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
	InteractionsClientServer.CheckContactsFilling(Object, ThisObject, "SMSMessage");
	CheckContactCreationAvailability();
	AddresseesCount = Object.Recipients.Count();
	
	// StandardSubsystems.FilesOperations
	If CommonClient.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsClient = CommonClient.CommonModule("FilesOperationsClient");
		ModuleFilesOperationsClient.NotificationProcessing(ThisObject, EventName);
	EndIf;
	// End StandardSubsystems.FilesOperations
	
	// StandardSubsystems.MessagesTemplates
	If EventName = "Write_MessagesTemplates" Then
		DeterminePossibilityToFillEmailByTemplate();
	EndIf;
	// End StandardSubsystems.MessagesTemplates
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteMode)
	
	// StandardSubsystems.Properties
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.BeforeWriteAtServer(ThisObject, CurrentObject);
	EndIf;
	// End StandardSubsystems.Properties
	
	Interactions.BeforeWriteInteractionFromForm(ThisObject, CurrentObject, ContactsChanged);
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)

	InteractionsClient.InteractionSubjectAfterWrite(ThisObject, Object, WriteParameters, "SMSMessage");
	CheckContactCreationAvailability();
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.Properties
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		ModulePropertyManager.FillCheckProcessing(ThisObject, Cancel, CheckedAttributes);
	EndIf;
	// End StandardSubsystems.Properties
	
	CheckAddresseesListFilling(Cancel);
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	If Object.State = PredefinedValue("Enum.SMSMessageStatusDocument.Draft")
		OR Object.State = PredefinedValue("Enum.SMSMessageStatusDocument.Outgoing") Then
		InteractionsClient.CheckOfDeferredSendingAttributesFilling(Object, Cancel);
	EndIf;
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	InteractionsClient.ChoiceProcessingForm(ThisObject, SelectedValue, ChoiceSource, ChoiceContext);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure PagesContactsAddAttributesCommentOnChangePage(Item, CurrentPage)
	
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
Procedure OnControlOnChange()
	
	Reviewed = NOT UnderControl;
	AvailabilityControl(ThisObject);
	Modified = True;
	
EndProcedure

&AtClient
Procedure EditingTextChangeMessageText(Item, Text, StandardProcessing)
	
	CharsLeft = InteractionsClientServer.GenerateInfoLabelMessageCharsCount(
	                   Object.SendInTransliteration,
	                   Text);
	
EndProcedure

&AtClient
Procedure SendInTranslitOnChange(Item)
	
	CharsLeft = InteractionsClientServer.GenerateInfoLabelMessageCharsCount(
	                        Object.SendInTransliteration,
	                        Object.MessageText)
	
EndProcedure

&AtClient
Procedure SubjectStartChoice(Item, ChoiceData, StandardProcessing)
	
	InteractionsClient.SubjectStartChoice(ThisObject, Item, ChoiceData, StandardProcessing);
	
EndProcedure

// StandardSubsystems.FilesOperations
&AtClient
Procedure Attachable_PreviewFieldClick(Item, StandardProcessing)
	
	If CommonClient.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsClient = CommonClient.CommonModule("FilesOperationsClient");
		ModuleFilesOperationsClient.PreviewFieldClick(ThisObject, Item, StandardProcessing);
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_PreviewFieldDragCheck(Item, DragParameters, StandardProcessing)
	
	If CommonClient.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsClient = CommonClient.CommonModule("FilesOperationsClient");
		ModuleFilesOperationsClient.PreviewFieldCheckDragging(ThisObject, Item,
			DragParameters, StandardProcessing);
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_PreviewFieldDrag(Item, DragParameters, StandardProcessing)
	
	If CommonClient.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsClient = CommonClient.CommonModule("FilesOperationsClient");
		ModuleFilesOperationsClient.PreviewFieldDrag(ThisObject, Item,
			DragParameters, StandardProcessing);
	EndIf;
	
EndProcedure
// End StandardSubsystems.FilesOperations

#EndRegion

#Region AddresseesFormTableItemsEventHandlers

&AtClient
Procedure AddresseesOnChange(Item)
	
	InteractionsClientServer.CheckContactsFilling(Object, ThisObject, "SMSMessage");
	AddresseesCount = Object.Recipients.Count();
	ContactsChanged = True;
	
EndProcedure

&AtClient
Procedure AddresseesOnActivateRow(Item)
	
	CheckContactCreationAvailability();
	
EndProcedure

&AtClient
Procedure ContactStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	curData = Items.Recipients.CurrentData;
	
	OpeningParameters = New Structure;
	OpeningParameters.Insert("EmailOnly",                       False);
	OpeningParameters.Insert("PhoneOnly",                     True);
	OpeningParameters.Insert("ReplaceEmptyAddressAndPresentation", True);
	OpeningParameters.Insert("ForContactSpecificationForm",        False);
	OpeningParameters.Insert("FormID",                UUID);
	
	InteractionsClient.SelectContact(Topic, curData.HowToContact, curData.ContactPresentation,
	                                    curData.Contact, OpeningParameters); 
	
EndProcedure

&AtClient
Procedure ContactPresentationOnChange(Item)
	
	CheckContactCreationAvailability();
	
EndProcedure

&AtClient
Procedure ContactOnChange(Item)
	
	CheckContactCreationAvailability();
	InteractionsClientServer.CheckContactsFilling(Object, ThisObject, "SMSMessage");
	
EndProcedure

&AtClient
Procedure AddresseesOnEditEnd(Item, NewRow, CancelEdit)
	
	CurrentData = Items.Recipients.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If NOT ValueIsFilled(CurrentData.MessageState) Then
		CurrentData.MessageState = PredefinedValue("Enum.SMSStatus.Draft");
	EndIf;
	
EndProcedure 

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure CreateContactComplete()
	
	curData = Items.Recipients.CurrentData;
	If curData <> Undefined Then
		InteractionsClient.CreateContact(
			curData.ContactPresentation, curData.HowToContact, Object.Ref, ContactsToInteractivelyCreateList);
	EndIf;
	
EndProcedure

&AtClient
Procedure Send(Command)
	
	ClearMessages();
	
	If CheckFilling() Then
		SendExecute();
	EndIf;
	
EndProcedure

&AtClient
Procedure CheckDeliveryStatuses(Command)
	
	ClearMessages();
	CheckDeliveryStatusesServer();
	
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

// StandardSubsystems.FilesOperations
&AtClient
Procedure Attachable_AttachedFilesPanelCommand(Command)
	
	If CommonClient.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsClient = CommonClient.CommonModule("FilesOperationsClient");
		ModuleFilesOperationsClient.AttachmentsControlCommand(ThisObject, Command);
	EndIf;
	
EndProcedure
// End StandardSubsystems.FilesOperations

// StandardSubsystems.MessagesTemplates

&AtClient
Procedure GenerateFromTemplate(Command)
	
	If CommonClient.SubsystemExists("StandardSubsystems.MessageTemplates") Then
		ModuleMessagesTemplatesClient = CommonClient.CommonModule("MessageTemplatesClient");
		Notification = New NotifyDescription("FillByTemplateAfterTemplateChoice", ThisObject);
		MessageSubject = ?(ValueIsFilled(Topic), Topic, "Common");
		ModuleMessagesTemplatesClient.PrepareMessageFromTemplate(MessageSubject, "SMSMessage", Notification);
	EndIf
	
EndProcedure

// End StandardSubsystems.MessagesTemplates

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

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


///////////////////////////////////////////////////////////////////////////////
// Other procedures and functions

&AtClient
Procedure CheckContactCreationAvailability()
	
	curData = Items.Recipients.CurrentData;
	Items.CreateContact.Enabled = (Not Object.Ref.IsEmpty())
	                                       AND ((curData <> Undefined) 
	                                       AND (NOT ValueIsFilled(curData.Contact)));
	
EndProcedure

&AtServer
Procedure OnCreatReadAtServer()
	
	FileInfobase = Common.FileInfobase();
	ProcessPassedParameters(Parameters);
	InteractionsClientServer.CheckContactsFilling(Object, ThisObject, "SMSMessage");
	Items.ReviewAfter.Enabled = NOT Reviewed;
	CharsLeft = InteractionsClientServer.GenerateInfoLabelMessageCharsCount(
	                     Object.SendInTransliteration,
	                     Object.MessageText);
	Items.CommentPage.Picture = CommonClientServer.CommentPicture(Object.Comment);
	UnderControl = NOT Reviewed;
	AvailabilityControl(ThisObject);
	AddresseesCount = Object.Recipients.Count();
	
EndProcedure

&AtClient
Procedure SendExecute()
	
	ClearMessages();
	
	If FileInfobase 
		AND (Object.DateToSendEmail = Date(1,1,1) OR Object.DateToSendEmail < CommonClient.SessionDate())
		AND (Object.EmailSendingRelevanceDate = Date(1,1,1) OR Object.EmailSendingRelevanceDate > CommonClient.SessionDate()) Then
			SentEmailsCount = ExecuteSendingAtServer();
			If NOT SentEmailsCount > 0 Then
				Return;
			EndIf;
	Else
		InteractionsClientServer.SetStateOutgoingDocumentSMSMessage(Object);
	EndIf;
	
	Write();
	Close();

EndProcedure

&AtServer
Procedure CheckAddresseesListFilling(Cancel)

	For Each Recipient In Object.Recipients Do
		CheckPhoneFilling(Recipient, Cancel);
	EndDo;
	
EndProcedure

&AtServer
Procedure CheckPhoneFilling(Recipient, Cancel)
	
	If IsBlankString(Recipient.HowToContact) Then
		CommonClientServer.MessageToUser(
			NStr("ru = 'Поле ""Номер телефона"" не заполнено.'; en = 'Phone number is not populated.'; pl = 'Nie wypełniono pola ""Numer telefonu"".';es_ES = 'Número de teléfono no está poblado.';es_CO = 'Número de teléfono no está poblado.';tr = 'Telefon numarası doldurulmadı.';it = 'Numero di telefono non compilato.';de = 'Die Telefonnummer ist nicht ausgefüllt.'"),
			,
			CommonClientServer.PathToTabularSection("Object.Recipients", Recipient.LineNumber, "HowToContact"),
			,
			Cancel);
			Return;
	EndIf;
		
	If StrSplit(Recipient.HowToContact, ";", False).Count() > 1 Then
		CommonClientServer.MessageToUser(
			NStr("ru = 'Должен быть указан только один номер телефона'; en = 'Enter only one phone number'; pl = 'Wprowadź tylko jeden numer telefonu';es_ES = 'Introduzca sólo un número de teléfono';es_CO = 'Introduzca sólo un número de teléfono';tr = 'Sadece bir telefon numarası girin';it = 'Inserire solo un numero di telefono';de = 'Nur eine Telefonnummer eingeben'"),
			,
			CommonClientServer.PathToTabularSection("Object.Recipients", Recipient.LineNumber, "HowToContact"),
			,
			Cancel);
			Return;
	EndIf;
		
	If Not Interactions.PhoneNumberSpecifiedCorrectly(Recipient.HowToContact) Then
		CommonClientServer.MessageToUser(
			NStr("ru = 'Введите номер телефона в международном формате.
			|Допускается использовать в номере пробелы, скобки и дефисы.
			|Например, ""+7 (123) 456-78-90"".'; 
			|en = 'Enter phone number in the international format. 
			|You can use spaces, brackets, and hyphens.
			|For example, ""+7 (123) 456-78-90"".'; 
			|pl = 'Wpisz numer telefonu w formacie międzynarodowym. 
			|Możesz używać spacji, nawiasów i i kresek.
			|Na przykład, ""+7 (123) 456-78-90"".';
			|es_ES = 'Introduzca el número de teléfono en formato internacional. 
			|Puede utilizar espacios, paréntesis y guiones.
			| Por ejemplo, ""+7 (123) 456-78-90"".';
			|es_CO = 'Introduzca el número de teléfono en formato internacional. 
			|Puede utilizar espacios, paréntesis y guiones.
			| Por ejemplo, ""+7 (123) 456-78-90"".';
			|tr = 'Telefon numarasını uluslararası formatta girin. 
			|Boşluk, parantez ve kısa çizgi kullanılabilir.
			|Örneğin, ""+90 (123) 456-78-90"".';
			|it = 'Inserire numero di telefono nel formato internazionale. 
			| Si possono utilizzare spazi, parentesi e trattini.
			| Ad esempio, ""+7 (123) 456-78-90"".';
			|de = 'Telefonnummer im internationalen Format eingeben. 
			|Sie können Leerzeichen, Klammern und Bindestriche verwenden.
			|Zum Beispiel ""+7 (123) 456-78-90"".'"),
			,
			CommonClientServer.PathToTabularSection("Object.Recipients", Recipient.LineNumber, "HowToContact"),
			,
			Cancel);
			Return;
	EndIf;
	
	Recipient.SendingNumber = FormatNumber(Recipient.HowToContact);
	
EndProcedure

&AtServer
Function FormatNumber(Number)
	Result = "";
	AllowedChars = "+1234567890";
	For Position = 1 To StrLen(Number) Do
		Char = Mid(Number,Position,1);
		If StrFind(AllowedChars, Char) > 0 Then
			Result = Result + Char;
		EndIf;
	EndDo;
	
	If StrLen(Result) > 10 Then
		FirstChar = Left(Result, 1);
		If FirstChar = "8" Then
			Result = "+7" + Mid(Result, 2);
		ElsIf FirstChar <> "+" Then
			Result = "+" + Result;
		EndIf;
	EndIf;
	
	Return Result;
EndFunction

&AtServer
Function ExecuteSendingAtServer()
	
	Return Interactions.SendSMSMessageByDocument(Object);
	
EndFunction

&AtClientAtServerNoContext
Procedure AvailabilityControl(Form)

	MessageSent = MessageSent(Form.Object.State);
	StatusUpperOutgoing = Form.Object.State <> PredefinedValue("Enum.SMSMessageStatusDocument.Draft")
	                      AND Form.Object.State <> PredefinedValue("Enum.SMSMessageStatusDocument.Outgoing");
	
	SendingAvailable = True;
	If Form.FileInfobase Then
		If MessageSent Then
			SendingAvailable = False;
		ElsIf Form.Object.State = PredefinedValue("Enum.SMSMessageStatusDocument.Outgoing") Then
			#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
				SessionDate = CurrentSessionDate();
			#Else
				SessionDate = CommonClient.SessionDate();
			#EndIf
			If (Form.Object.DateToSendEmail) <> Date(1,1,1)
				AND Form.Object.DateToSendEmail > SessionDate Then
				SendingAvailable = False;
			EndIf;
			If (Form.Object.EmailSendingRelevanceDate) <> Date(1,1,1)
				AND Form.Object.EmailSendingRelevanceDate < SessionDate Then
				SendingAvailable = False;
			EndIf;
		EndIf;
	Else
		If Form.Object.State <> PredefinedValue("Enum.SMSMessageStatusDocument.Draft") Then
			SendingAvailable = False;
		EndIf
	EndIf;
	
	Form.Items.FormSend.Enabled                 = SendingAvailable;
	Form.Items.Recipients.ReadOnly                    = StatusUpperOutgoing;
	Form.Items.SendInTransliteration.Enabled           = NOT StatusUpperOutgoing;
	Form.Items.MessageText.ReadOnly              = StatusUpperOutgoing;
	Form.Items.ReviewAfter.Enabled               = Form.UnderControl;
	Form.Items.SendingDateRelevanceGroup.Enabled = NOT StatusUpperOutgoing;
	
	Form.Items.AddresseesCheckDeliveryStatuses.Enabled =
	                 Form.FileInfobase
	                 AND MessageSent
	                 AND Form.Object.State = PredefinedValue("Enum.SMSMessageStatusDocument.Delivering");

EndProcedure

&AtServer
Procedure CheckDeliveryStatusesServer()

	SetPrivilegedMode(True);
	If Not SMS.SMSMessageSendingSetupCompleted() Then
		CommonClientServer.MessageToUser(NStr("ru = 'Не выполнены настройки отправки SMS.'; en = 'Settings of SMS sending are not executed.'; pl = 'Nie wykonano ustawień wysyłki SMS.';es_ES = 'No se han ejecutado las configuraciones del envío del SMS.';es_CO = 'No se han ejecutado las configuraciones del envío del SMS.';tr = 'SMS gönderim ayarları yürütülmedi.';it = 'Le impostazioni di invio SMS non sono state eseguite.';de = 'Einstellungen von SMS-Senden sind nicht ausgeführt.'"),,"Object");
		Return;
	EndIf;
	
	Interactions.CheckSMSMessagesDeliveryStatuses(Object, Modified);
	AvailabilityControl(ThisObject);

EndProcedure

&AtServer
Procedure ProcessPassedParameters(PassedParameters)
	
	If Object.Ref.IsEmpty() Then
		
		If PassedParameters.Property("Text") AND NOT IsBlankString(PassedParameters.Text) Then
			
			Object.MessageText = PassedParameters.Text;
			
		EndIf;
		
		If PassedParameters.Recipients <> Undefined Then
			
			If TypeOf(PassedParameters.Recipients) = Type("String") AND NOT IsBlankString(PassedParameters.Recipients) Then
				
				NewRow = Object.Recipients.Add();
				NewRow.Address = PassedParameters.SendTo;
				NewRow.MessageState = Enums.SMSStatus.Draft;
				
			ElsIf TypeOf(PassedParameters.Recipients) = Type("ValueList") Then
				
				For Each ListItem In PassedParameters.Recipients Do
					NewRow = Object.Recipients.Add();
					NewRow.HowToContact  = ListItem.Value;
					NewRow.Presentation = ListItem.Presentation;
					NewRow.MessageState = Enums.SMSStatus.Draft;
				EndDo;
				
			ElsIf TypeOf(PassedParameters.Recipients) = Type("Array") Then
				
				For Each ArrayElement In PassedParameters.Recipients Do
					
					NewRow = Object.Recipients.Add();
					NewRow.HowToContact          = ArrayElement.Phone;
					NewRow.ContactPresentation = ArrayElement.Presentation;
					NewRow.Contact               = ArrayElement.ContactInformationSource;
					NewRow.MessageState = Enums.SMSStatus.Draft;
					
				EndDo;
				
			EndIf;
			
		EndIf;
		
		If PassedParameters.Property("Topic") Then
			Topic = PassedParameters.Topic;
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Function MessageSent(State)
	
	Return State <> PredefinedValue("Enum.SMSMessageStatusDocument.Draft")
	        AND State <> PredefinedValue("Enum.SMSMessageStatusDocument.Outgoing");
	
EndFunction

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

// StandardSubsystems.MessagesTemplates

&AtClient
Procedure FillByTemplateAfterTemplateChoice(Result, AdditionalParameters) Export
	If TypeOf(Result) = Type("Structure") Then
		FillTemplateAfterChoice(Result.Template);
		Items.MessageText.UpdateEditText();
	EndIf;
EndProcedure

&AtServer
Procedure FillTemplateAfterChoice(TemplateRef)
	
	MessageObject = FormAttributeToValue("Object");
	MessageObject.Fill(TemplateRef);
	ValueToFormAttribute(MessageObject, "Object");
	
EndProcedure

&AtServer
Procedure DeterminePossibilityToFillEmailByTemplate()
	
	MessagesTemplatesUsed = False;
	If Object.State = Enums.SMSMessageStatusDocument.Draft
		AND Common.SubsystemExists("StandardSubsystems.MessageTemplates") Then
		ModuleMessagesTemplatesInternal = Common.CommonModule("MessageTemplatesInternal");
		If ModuleMessagesTemplatesInternal.MessagesTemplatesUsed() Then
			MessagesTemplatesUsed = ModuleMessagesTemplatesInternal.HasAvailableTemplates("SMS");
		EndIf;
	EndIf;
	Items.FormGenerateFromTemplate.Visible = MessagesTemplatesUsed;
	
EndProcedure

// End StandardSubsystems.MessagesTemplates

#EndRegion
