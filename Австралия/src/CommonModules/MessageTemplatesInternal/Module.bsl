///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#Region Internal

// Creating a message from template
// Parameters:
//  SendingParameters - Structure - a structure, where:
//    * AdditionalParameters - Structure -
//
// Returns:
//   Structure - details:
//   * Attachments - ValueTable - where:
//     ** Presentation - String -
//     ** AddressInTempStorage - String -
//     ** Encoding - String -
//     ** ID - String -
//   * UserMessages - FixedArray -
//   * AdditionalParameters - Structure - where:
//     ** Sender - String -
//   * Recipient - Undefined -
//   * Text - String -
//   * Subject - String -
//
Function GenerateMessage(SendOptions) Export
	
	If SendOptions.Template = Catalogs.MessageTemplates.EmptyRef() Then
		Return MessageWithoutTemplate(SendOptions);
	EndIf;
	
	TemplateParameters = TemplateParameters(SendOptions.Template);
	If SendOptions.AdditionalParameters.Property("MessageParameters") Then
		TemplateParameters.MessageParameters = SendOptions.AdditionalParameters.MessageParameters;
	EndIf;
	
	If SendOptions.Template = Undefined Then
		If SendOptions.Property("AdditionalParameters")
			AND SendOptions.AdditionalParameters.Property("MessageKind") Then
			TemplateParameters.TemplateType = SendOptions.AdditionalParameters.MessageKind;
		EndIf;
	Else
		If SendOptions.Template.ForSMSMessages Then
			SendOptions.AdditionalParameters.Insert("MessageKind", "SMSMessage");
		Else
			SendOptions.AdditionalParameters.Insert("MessageKind", "Email");
		EndIf;
	EndIf;
	
	ObjectManager = Undefined;
	TemplateInfo = Undefined;
	If SendOptions.Topic <> Undefined Then
		TemplateInfo = TemplateInfo(TemplateParameters);
		TemplateParameters.Insert("Topic", SendOptions.Topic);
	EndIf;
	If ValueIsFilled(TemplateParameters.FullAssignmentTypeName) Then
		ObjectMetadata = Metadata.FindByFullName(TemplateParameters.FullAssignmentTypeName);
		If ObjectMetadata <> Undefined Then
			ObjectManager = Common.ObjectManagerByFullName(TemplateParameters.FullAssignmentTypeName);
		EndIf;
	EndIf;
	
	GeneratedMessage = MessageConstructor(TemplateParameters);
	If TemplateParameters = Undefined Then
		Return GeneratedMessage;
	EndIf;
	
	If TemplateParameters.TemplateByExternalDataProcessor Then
		Return GenerateMesageByExternalDataProcessor(TemplateParameters, TemplateInfo, SendOptions);
	EndIf;
	
	// Extracting parameters from the template
	MessageTextParameters = ParametersFromMessageText(TemplateParameters);
	
	// Filling in parameters
	Message = FillMessageParameters(TemplateParameters, MessageTextParameters, SendOptions);
	Message.AdditionalParameters = SendOptions.AdditionalParameters;
	
	// Attachments
	If TemplateParameters.TemplateType = "Email" AND TemplateInfo <> Undefined Then
		AddSelectedPrintFormsToAttachments(SendOptions, TemplateInfo, Message.Attachments, TemplateParameters);
	EndIf;
	AddAttachedFilesToAttachments(SendOptions, Message);
	
	MessageTemplatesOverridable.OnCreateMessage(Message, TemplateParameters.FullAssignmentTypeName, SendOptions.Topic, TemplateParameters);
	If ObjectManager <> Undefined Then
		ObjectManager.OnCreateMessage(Message, SendOptions.Topic, TemplateParameters);
	EndIf;
	
	// Filling in parameter values
	MessageResult = SetAttributesValuesToMessageText(TemplateParameters, MessageTextParameters, SendOptions.Topic);
	
	GeneratedMessage.Subject = MessageResult.Subject;
	GeneratedMessage.Text = MessageResult.Text;
	
	For each Attachment In Message.Attachments Do
		NewAttachment = GeneratedMessage.Attachments.Add();
		If TemplateParameters.TransliterateFileNames Then
			NewAttachment.Presentation = StringFunctionsClientServer.LatinString(Attachment.Key);
		Else
			NewAttachment.Presentation = Attachment.Key;
		EndIf;
		NewAttachment.AddressInTempStorage = Attachment.Value;
	EndDo;
	
	If TemplateParameters.TemplateType = "Email" AND TemplateParameters.EmailFormat = Enums.EmailEditingMethods.HTML Then
		ProcessHTMLForFormattedDocument(SendOptions, GeneratedMessage, SendOptions.AdditionalParameters.ConvertHTMLForFormattedDocument);
	EndIf;
	
	FillMessageRecipients(SendOptions, TemplateParameters, GeneratedMessage, ObjectManager);
	GeneratedMessage.UserMessages = GetUserMessages(True);
	
	Return GeneratedMessage;
	
EndFunction

// Generate a message and send it immediately.
// 
// Parameters:
//   SendingParameters - Structure - contains:
//   * AdditionalParameters - Structure -
//
// Returns:
//  Structure - contains:
//    * Sent - Boolean -
//    * ErrorDescription - String - 
// 
Function GenerateMessageAndSend(SendOptions) Export
	
	Result = New Structure("Sent, ErrorDescription", False);
	
	Message = GenerateMessage(SendOptions);
	
	If SendOptions.Template.ForSMSMessages Then
		If Message.Recipient.Count() = 0 Then
			Result.ErrorDescription  = NStr("ru = 'Для отправки сообщения необходимо ввести номер телефонов получателей.'; en = 'To send the message, enter recipient phone numbers.'; pl = 'Aby wysłać wiadomość, wpisz numery telefonów odbiorcy.';es_ES = 'Para enviar el mensaje, introduce los números de teléfono de los destinatarios.';es_CO = 'Para enviar el mensaje, introduce los números de teléfono de los destinatarios.';tr = 'İletiyi göndermek için alıcı telefon numaralarını girin.';it = 'Per inviare il messaggio, inserire il numero di telefono del destinatario.';de = 'Um die Nachricht zu senden, geben Sie die Rufnummern der Empfänger ein.'");
			Return Result;
		EndIf;
		
		If Common.SubsystemExists("StandardSubsystems.SMS") Then
			ModuleSMS = Common.CommonModule("SMS");
			If ModuleSMS.CanSendSMSMessage() Then
				
				If Common.SubsystemExists("StandardSubsystems.Interactions") Then
					
					ModuleInteractions = Common.CommonModule("Interactions");
					If ModuleInteractions.OtherInteractionsUsed() Then
						
						ModuleInteractions.CreateAndSendSMSMessage(Message);
						Result.Sent = True;
						Return Result;
						
					EndIf;
				EndIf;
				
				RecipientsNumbers = New Array;
				For each Recipient In Message.Recipient Do
					RecipientsNumbers.Add(Recipient.Value);
				EndDo;
				
				SMSMessageSendingResult = ModuleSMS.SendSMSMessage(RecipientsNumbers, Message.Text, Message.AdditionalParameters.Sender, Message.AdditionalParameters.Transliterate);
				Result.Sent = IsBlankString(SMSMessageSendingResult.ErrorDescription);
				Result.ErrorDescription = SMSMessageSendingResult.ErrorDescription;
				
			Else
				
				Result.ErrorDescription = NStr("ru = 'Сообщение SMS не может быть отправлено сразу.'; en = 'Cannot send the text message right away.'; pl = 'Nie można wysłać wiadomości SMS od razu.';es_ES = 'No se puede enviar el SMS de inmediato.';es_CO = 'No se puede enviar el SMS de inmediato.';tr = 'SMS hemen gönderilemiyor.';it = 'Impossibile inviare il messaggio di testo subito.';de = 'Die Textnachricht kann nicht sofort gesendet werden.'");
				
			EndIf;
			
			Return Result;
			
		EndIf;
		
	Else
		If Message.Recipient.Count() = 0 Then
			Result.ErrorDescription  = NStr("ru = 'Сообщение не может быть отправлено сразу, т.к необходимо ввести адрес электронной почты.'; en = 'Cannot send the message right away. An email address is required.'; pl = 'Nie można wysłać wiadomości od razu. Wymagany jest adres e-mail.';es_ES = 'No se puede enviar el mensaje de inmediato. Se requiere una dirección de correo electrónico.';es_CO = 'No se puede enviar el mensaje de inmediato. Se requiere una dirección de correo electrónico.';tr = 'İleti gönderilemiyor. E-posta adresi gerekli.';it = 'Impossibile inviare il messaggio di testo subito. Richiesto indirizzo email.';de = 'Die Nachricht kann nicht sofort gesendet werden. Eine E-Mail-Adresse ist erforderlich.'");
			Return Result;
		EndIf;
		
		EmailParameters = New Structure();
		EmailParameters.Insert("Subject",      Message.Subject);
		EmailParameters.Insert("Body",      Message.Text);
		EmailParameters.Insert("Attachments",  New Map);
		EmailParameters.Insert("Encoding", "utf-8");
		
		For each Attachment In Message.Attachments Do
			NewAttachment = New Structure("BinaryData, ID");
			NewAttachment.BinaryData = GetFromTempStorage(Attachment.AddressInTempStorage);
			NewAttachment.ID = Attachment.ID;
			EmailParameters.Attachments.Insert(Attachment.Presentation, NewAttachment);
		EndDo;
		
		If Common.SubsystemExists("StandardSubsystems.EmailOperations") Then
			ModuleEmailOperationsInternal = Common.CommonModule("EmailOperationsInternal");
			If Message.AdditionalParameters.EmailFormat = Enums.EmailEditingMethods.HTML Then
				TextType = ModuleEmailOperationsInternal.EmailTextTypes("HTMLWithPictures");
			Else
				TextType = ModuleEmailOperationsInternal.EmailTextTypes("PlainText");
			EndIf;
		Else
			TextType = "";
		EndIf;
		
		EmailParameters.Insert("TextType", TextType);
		SendTo = GenerateMessageRecipientsList(Message.Recipient);
		
		EmailParameters.Insert("SendTo", SendTo);
		
		If Common.SubsystemExists("StandardSubsystems.EmailOperations") Then
			ModuleEmailOperations = Common.CommonModule("EmailOperations");
			If ModuleEmailOperations.CanSendEmails() Then
				
				If SendOptions.AdditionalParameters.Account = Undefined Then
					Account = ModuleEmailOperations.SystemAccount();
				Else
					Account = SendOptions.AdditionalParameters.Account;
				EndIf;
				
				If Common.SubsystemExists("StandardSubsystems.Interactions") Then
					
					ModuleInteractions = Common.CommonModule("Interactions");
					If ModuleInteractions.EmailClientUsed() Then
						
						SendingResult = ModuleInteractions.CreateEmail(Message, Account);
						FillPropertyValues(Result, SendingResult);
						Return Result;
						
					EndIf;
					
				EndIf;
				
				Email = ModuleEmailOperations.PrepareEmail(Account, EmailParameters);
				ModuleEmailOperations.SendEmail(Account, Email);
				
				Result.Sent = True;
				
			Else
				
				Result.ErrorDescription  = NStr("ru = 'Сообщение не может быть отправлено сразу.'; en = 'Cannot send the message right away.'; pl = 'Nie można wysłać wiadomości od razu.';es_ES = 'No se puede enviar el mensaje de inmediato.';es_CO = 'No se puede enviar el mensaje de inmediato.';tr = 'İleti gönderilemiyor.';it = 'Impossibile inviare il messaggio di testo subito.';de = 'Die Nachricht kann nicht sofort gesendet werden.'");
				Return Result;
				
			EndIf;
		EndIf
		
	EndIf;
	
	Return Result;
	
EndFunction

Function HasAvailableTemplates(TemplateType, Topic = Undefined) Export
	Query = PrepareQueryToGetTemplatesList(TemplateType, Topic);
	Return NOT Query.Execute().IsEmpty();
EndFunction

// Returns a list of metadata objects the "Message templates" subsystem is attached to.
//
// Returns:
//  Array - a list of items of the MetadataObject type.
Function MessagesTemplatesSources() Export
	
	TypesOrMetadataArray = Metadata.DefinedTypes.MessageTemplateSubject.Type.Types();
	
	MetadataObjectsIDsTypeIndex = TypesOrMetadataArray.Find(Type("CatalogRef.MetadataObjectIDs"));
	If MetadataObjectsIDsTypeIndex <> Undefined Then
		TypesOrMetadataArray.Delete(MetadataObjectsIDsTypeIndex);
	EndIf;
	
	Return TypesOrMetadataArray;
	
EndFunction

Function MessagesTemplatesUsed() Export
	Return GetFunctionalOption("UseMessageTemplates");
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See InfobaseUpdateSSL.OnAddUpdateHandlers. 
// 
// Parameters:
//  Handlers - see InfobaseUpdateSSL.OnAddUpdateHandlers.Handlers 
// 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version = "3.0.1.35";
	Handler.Procedure = "MessageTemplatesInternal.AddAddEditPersonalTemplatesRoleToBasicRightsProfiles";
	Handler.ExecutionMode = "Seamless";
	
EndProcedure

// See AccessManagementOverridable.OnFillListsWithAccessRestriction. 
Procedure OnFillListsWithAccessRestriction(Lists) Export
	
	Lists.Insert(Metadata.Catalogs.MessageTemplates, True);
	Lists.Insert(Metadata.Catalogs.MessageTemplatesAttachedFiles, True);
	
EndProcedure

// See AccessManagementOverridable.OnFillMetadataObjectsAccessRestrictionsKinds. 
Procedure OnFillMetadataObjectsAccessRestrictionKinds(Details) Export
	
	Details = Details + "
	|Catalog.MessageTemplates.Read.Users
	|Catalog.MessageTemplates.Update.Users
	|";
	
	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		Details = Details + "
			|Catalog.MessageTemplatesAttachedFiles.Read.Users
			|Catalog.MessageTemplatesAttachedFiles.Update.Users
			|";
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

Function TemplateByOwner(TemplateOwner) Export
	
	Query = New Query;
	Query.Text = 
		"SELECT TOP 1
		|	MessageTemplates.Ref AS Ref
		|FROM
		|	Catalog.MessageTemplates AS MessageTemplates
		|WHERE
		|	MessageTemplates.TemplateOwner = &TemplateOwner";
	
	Query.SetParameter("TemplateOwner", TemplateOwner);
	
	QueryResult = Query.Execute();
	
	If NOT QueryResult.IsEmpty() Then
		Return QueryResult.Unload()[0].Ref;
	Else
		Return Catalogs.MessageTemplates.EmptyRef();
	EndIf;
	
EndFunction

// A function creating message parameters.
// 
// Parameters:
//  TemplateParameters - Structure, Undefined - 
// 
// Returns:
//  Structure - details:
//    * Subject - String -
//    * Text - String -
//    * Recipient - ValueList -
//    * Attachments - ValueTable - where:
//      ** Presentation - String -  
//      ** AddressInTempStorage - String -  
//      ** Encoding - String - 
//      ** ID - String -
//   * UserMessages - FixedArray -
//   * AdditionalParameters - Undefined, Structure -
//
Function MessageConstructor(TemplateParameters = Undefined) Export
	
	Message = New Structure();
	Message.Insert("Subject", "");
	Message.Insert("Text", "");
	Message.Insert("Recipient", Undefined);
	Message.Insert("AdditionalParameters",
		?(TemplateParameters <> Undefined, TemplateParameters, New Structure()));
	Message.Insert("UserMessages", New FixedArray(New Array()));
	
	StringType = New TypeDescription("String");
	Attachments = New ValueTable;
	Attachments.Columns.Add("Presentation", StringType);
	Attachments.Columns.Add("AddressInTempStorage", StringType);
	Attachments.Columns.Add("Encoding", StringType);
	Attachments.Columns.Add("ID", StringType);
	Message.Insert("Attachments", Attachments);
	
	If TemplateParameters <> Undefined Then
		FillPropertyValues(Message, TemplateParameters);
	EndIf;
	
	Return Message;
EndFunction

Function TemplateInfo(TemplateParameters) Export
	
	TemplateInfo = TemplateInfoConstructor();
	
	CommonAttributesNodeName = CommonAttributesNodeName();
	
	If TypeOf(TemplateInfo.CommonAttributes) = Type("ValueTree") Then
		For each CommonAttribute In CommonAttributes(TemplateInfo.CommonAttributes).Rows Do
			If Not StrStartsWith(CommonAttribute.Name, CommonAttributesNodeName + ".") Then
				CommonAttribute.Name = CommonAttributesNodeName + "." + CommonAttribute.Name;
			EndIf;
		EndDo;
	Else
		TemplateInfo.CommonAttributes = AttributeTree();
		CommonAttributesTree = DetermineCommonAttributes();
		TemplateInfo.CommonAttributes = CommonAttributes(CommonAttributesTree);
	EndIf;
	
	DefineAttributesAndAttachmentsList(TemplateInfo, TemplateParameters);
	
	Return TemplateInfo;
	
EndFunction

// A function creating template information.
// 
// Returns:
//  Structure - details:
//    * Assignment - String -
//    * Attachments - ValueTable - where:
//       ** Name - String -
//       ** ID - String -
//       ** Presentation - String -
//       ** PrintManager - String -
//       ** PrintParameters - Structure -
//       ** FileType - String -
//       ** Status - String -
//       ** Attribute - String -
//       ** ParameterName - String -
//   * CommonAttributes 
//   * Attributes - ValueTree - where:
//       ** Name - String -
//       ** Presentation - String -
//       ** Hint - String -
//       ** Format - String -
//       ** Type - TypesDetails -
//       ** ArbitraryParameter - Boolean -
// 
Function TemplateInfoConstructor()
	
	TemplateInfo = New Structure();
	
	MessagesTemplatesSettings = MessagesTemplatesInternalCachedModules.OnDefineSettings();
	
	TemplateInfo.Insert("Attributes", AttributeTree());
	TemplateInfo.Insert("CommonAttributes", MessagesTemplatesSettings.CommonAttributes);
	TemplateInfo.Insert("Attachments", AttachmentsTable());
	TemplateInfo.Insert("Purpose", "");
	
	Return TemplateInfo;
	
EndFunction

Procedure DefineAttributesAndAttachmentsList(TemplateInfo, TemplateParameters)
	
	If ValueIsFilled(TemplateParameters.FullAssignmentTypeName) Then
		
		// Attributes
		MetadataObject = Metadata.FindByFullName(TemplateParameters.FullAssignmentTypeName);
		RelatedObjectAttributes = RelatedObjectAttributes(TemplateInfo.Attributes, TemplateParameters.FullAssignmentTypeName, TemplateParameters.Purpose);
		
		If MetadataObject <> Undefined Then
			ObjectManager = Common.ObjectManagerByFullName(MetadataObject.FullName());
			If IsBlankString(TemplateParameters.Template) Then
				AttributesByObjectMetadata(RelatedObjectAttributes, MetadataObject,,, MetadataObject.Name + ".");
			Else
				DCSTemplate = ObjectManager.GetTemplate(TemplateParameters.Template);
				AttributesByDCS(RelatedObjectAttributes, DCSTemplate, MetadataObject.Name);
			EndIf;
			
			DefinePrintFormsList(MetadataObject, TemplateInfo);
			
			Prefix = MetadataObject.Name + ".";
			Presentation = MetadataObject.Presentation();
			
			ObjectRef = RelatedObjectAttributes.Add();
			ObjectRef.Presentation = NStr("ru = 'Ссылка на'; en = 'Ref to'; pl = 'Odnośnik do';es_ES = 'Enlace a';es_CO = 'Enlace a';tr = 'Referans';it = 'Riferimento a';de = 'Bezug auf'") + " """ + Presentation + """";
			ObjectRef.Name           = Prefix + "ExternalObjectRef";
			ObjectRef.Type  = New TypeDescription("String");
			
		Else
			Prefix = TemplateParameters.FullAssignmentTypeName +".";
			Presentation = TemplateParameters.Purpose;
		EndIf;
		
		MessageTemplatesOverridable.OnPrepareMessageTemplate(RelatedObjectAttributes, TemplateInfo.Attachments, TemplateParameters.FullAssignmentTypeName, TemplateParameters);
		
		If MetadataObject <> Undefined Then
			ObjectManager.OnPrepareMessageTemplate(RelatedObjectAttributes, TemplateInfo.Attachments, TemplateParameters);
		EndIf;
		
		For each RelatedObjectAttribute In RelatedObjectAttributes Do
			If Not StrStartsWith(RelatedObjectAttribute.Name, Prefix) Then
				RelatedObjectAttribute.Name = Prefix + RelatedObjectAttribute.Name;
			EndIf;
			If TemplateParameters.ExpandRefAttributes Then
				If RelatedObjectAttribute.Type.Types().Count() = 1 Then
					ObjectType = Metadata.FindByType(RelatedObjectAttribute.Type.Types()[0]);
					If ObjectType <> Undefined AND StrStartsWith(ObjectType.FullName(), "Catalog") Then
						ExpandAttribute(RelatedObjectAttribute.Name, RelatedObjectAttributes);
					EndIf;
				EndIf;
			EndIf;
		EndDo;
		
	EndIf;
	
	For each ArbitraryParameter In TemplateParameters.Parameters Do
		
		If ArbitraryParameter.Value.TypeDetails.Types().Count() > 0 Then
			Type = ArbitraryParameter.Value.TypeDetails.Types()[0];
			MetadataObject = Metadata.FindByType(Type);
			If MetadataObject <> Undefined Then
				ObjectManager = Common.ObjectManagerByFullName(MetadataObject.FullName());
				If ObjectManager <> Undefined Then
					RelatedObjectAttributes = RelatedObjectAttributes(TemplateInfo.Attributes, ArbitraryParameter.Key);
					RelatedObjectAttributes.Parent.Presentation = ArbitraryParameter.Value.Presentation;
					RelatedObjectAttributes.Parent.Type = ArbitraryParameter.Value.TypeDetails;
					RelatedObjectAttributes.Parent.ArbitraryParameter = True;
					AttributesByObjectMetadata(RelatedObjectAttributes, MetadataObject,,, MetadataObject.Name + ".");
				EndIf;
				DefinePrintFormsList(MetadataObject, TemplateInfo, ArbitraryParameter.Key);
			Else
				ArbitraryAttributesPresentation = NStr("ru = 'Пользовательский'; en = 'Custom'; pl = 'Wariant użytkownika';es_ES = 'De usuario';es_CO = 'De usuario';tr = 'Özel';it = 'Personalizzato';de = 'Benutzerdefiniert'");
				Prefix = "Arbitrary";
				RelatedObjectAttributes = RelatedObjectAttributes(TemplateInfo.Attributes, Prefix, ArbitraryAttributesPresentation);
				NewString = RelatedObjectAttributes.Add();
				NewString.Name = Prefix + "." + ArbitraryParameter.Key;
				NewString.Presentation = ArbitraryParameter.Value.Presentation;
				NewString.Type = ArbitraryParameter.Value.TypeDetails;
				NewString.ArbitraryParameter = True;
			EndIf;
		Else
			ArbitraryAttributesPresentation = NStr("ru = 'Пользовательский'; en = 'Custom'; pl = 'Wariant użytkownika';es_ES = 'De usuario';es_CO = 'De usuario';tr = 'Özel';it = 'Personalizzato';de = 'Benutzerdefiniert'");
			Prefix = "Arbitrary";
			RelatedObjectAttributes = RelatedObjectAttributes(TemplateInfo.Attributes, Prefix, ArbitraryAttributesPresentation);
			NewString = RelatedObjectAttributes.Add();
			NewString.Name = Prefix + "." + ArbitraryParameter.Key;
			NewString.Presentation = ArbitraryParameter.Value.Presentation;
			NewString.Type = Common.StringTypeDetails(150);
			NewString.ArbitraryParameter = True;
		EndIf;
	EndDo;
	
EndProcedure

Function ObjectIsTemplateSubject(FullAssignmentTypeName) Export
	
	Result = MessagesTemplatesInternalCachedModules.OnDefineSettings().TemplateSubjects.Find(FullAssignmentTypeName, "Name");
	Return Result <> Undefined;
	
EndFunction

Function GenerateMesageByExternalDataProcessor(TemplateParameters, TemplateInfo, SendOptions)
	
	If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		
		ModuleAdditionalReportsAndDataProcessors = Common.CommonModule("AdditionalReportsAndDataProcessors");
		
		GeneratedMessage = MessageConstructor(TemplateParameters);
		ExternalObject = ModuleAdditionalReportsAndDataProcessors.ExternalDataProcessorObject(TemplateParameters.ExternalDataProcessor);
		TemplateParameters = ExternalObject.TemplateParameters();
		
		Values = New Structure;
		For each TemplateParameter In TemplateParameters Do
			IsArbitraryParameter = True;
			For each TypeDetails In TemplateParameter.TypeDetails.Types() Do
				If TypeDetails = TypeOf(SendOptions.Topic) Then
					Values.Insert(SendOptions.Topic.Metadata().Name, SendOptions.Topic);
					IsArbitraryParameter = False;
					Break;
				EndIf;
			EndDo;
			If IsArbitraryParameter Then
				Value = SendOptions.AdditionalParameters.ArbitraryParameters[TemplateParameter.ParameterName];
				Values.Insert(TemplateParameter.ParameterName, Value);
			EndIf;
		EndDo;
		
		Message = ExternalObject.GenerateMessageByTemplate(Values);
		
		If TypeOf(Message) = Type("Structure") AND SendOptions.AdditionalParameters.MessageKind = "SMSMessage" Then
			
			GeneratedMessage.Text = Message.SMSMessageText;
			
		ElsIf TypeOf(Message) = Type("Structure") AND Message.Property("AttachmentsStructure") Then
			
			GeneratedMessage.Text = Message.HTMLEmailText;
			GeneratedMessage.Subject  = Message.EmailSubject;
			
			For each Attachment In Message.AttachmentsStructure Do
				NewAttachment = GeneratedMessage.Attachments.Add();
				NewAttachment.AddressInTempStorage = PutToTempStorage(Attachment.Value.GetBinaryData(), SendOptions.UUID);
				NewAttachment.ID = Attachment.Key;
				NewAttachment.Presentation = Attachment.Key;
			EndDo;
			
		EndIf;
		
		StandardProcessing = False;
		Recipients = ExternalObject.DataStructureRecipients(Values, StandardProcessing);
		For each Recipient In Recipients Do
			GeneratedMessage.Recipient.Add(Recipient.Address, Recipient.Presentation);
		EndDo;
		
		Return GeneratedMessage;
		
	EndIf;
	
EndFunction

Function MessageWithoutTemplate(SendOptions)
	
	TemplateParameters = MessageTemplatesClientServer.TemplateParametersDetails();
	If SendOptions.AdditionalParameters.Property("MessageKind")
		AND SendOptions.AdditionalParameters.MessageKind = "SMSMessage" Then
			TemplateParameters.TemplateType = "SMS";
	EndIf;
	
	ObjectManager =  Undefined;
	If SendOptions.Property("Topic") AND ValueIsFilled(SendOptions.Topic) Then
	ObjectMetadata = Metadata.FindByType(TypeOf(SendOptions.Topic));
	If ObjectMetadata <> Undefined Then
			ObjectManager = Common.ObjectManagerByFullName(ObjectMetadata.FullName());
		EndIf;
	EndIf;
	
	GeneratedMessage = MessageConstructor();
	FillMessageRecipients(SendOptions, TemplateParameters, GeneratedMessage, ObjectManager);
	
	If Common.SubsystemExists("StandardSubsystems.Print") Then
		ModulePrintManager = Common.CommonModule("PrintManagement");
		If TemplateParameters.TemplateType = "Email" AND ValueIsFilled(SendOptions.AdditionalParameters.PrintForms) Then
			PrintForms = SendOptions.AdditionalParameters.PrintForms;
			ObjectsList = CommonClientServer.ValueInArray(SendOptions.Topic);
			SettingsForSaving = SendOptions.AdditionalParameters.SettingsForSaving;
			Files = ModulePrintManager.PrintToFile(PrintForms, ObjectsList, SettingsForSaving);
			For Each File In Files Do
				Attachment = GeneratedMessage.Attachments.Add();
				Attachment.AddressInTempStorage = PutToTempStorage(File.BinaryData, SendOptions.UUID);
				Attachment.Presentation = File.FileName;
			EndDo;
		EndIf;
	EndIf;
	
	Return GeneratedMessage;
	
EndFunction

Function GenerateMessageRecipientsList(RecipientsList)
	
	RecipientsWithContactList = (TypeOf(RecipientsList)= Type("Array"));
	
	SendTo = New Array;
	For each Recipient In RecipientsList Do
		MessageRecipient = New Structure();
		MessageRecipient.Insert("Presentation", Recipient.Presentation);
		
		If RecipientsWithContactList Then
			MessageRecipient.Insert("Address",   Recipient.Address);
			MessageRecipient.Insert("Contact", Recipient.ContactInformationSource);
		Else
			MessageRecipient.Insert("Address",   Recipient.Value);
		EndIf;
		
		SendTo.Add(MessageRecipient);
	EndDo;
	
	Return SendTo;

EndFunction

// Settings

Function DefineTemplatesSubjects() Export
	DefaultTemplateName = "MessagesTemplateData";
	
	BasisForMessagesTemplates = New ValueTable;
	BasisForMessagesTemplates.Columns.Add("Name", New TypeDescription("String"));
	BasisForMessagesTemplates.Columns.Add("Presentation", New TypeDescription("String"));
	BasisForMessagesTemplates.Columns.Add("Template", New TypeDescription("String"));
	BasisForMessagesTemplates.Columns.Add("DCSParametersValues", New TypeDescription("Structure"));
	
	MessagesTemplatesSubjectsTypes = Metadata.DefinedTypes.MessageTemplateSubject.Type.Types();
	For each MessageTemplateSubjectType In MessagesTemplatesSubjectsTypes Do
		If MessageTemplateSubjectType <> Type("CatalogRef.MetadataObjectIDs") Then
			Assignment = BasisForMessagesTemplates.Add();
			MetadataObject = Metadata.FindByType(MessageTemplateSubjectType);
			Assignment.Name = MetadataObject.FullName();
			Assignment.Presentation = MetadataObject.Presentation();
			If MetadataObject.Templates.Find(DefaultTemplateName) <> Undefined Then
				Assignment.Template = DefaultTemplateName;
				
				// DCS parameters
				ObjectManager = Common.ObjectManagerByFullName(Assignment.Name);
				DCSTemplate = ObjectManager.GetTemplate(DefaultTemplateName);
				SchemaURL = PutToTempStorage(DCSTemplate);
				SettingsComposer = New DataCompositionSettingsComposer;
				SettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(SchemaURL));
				For Each AvailableParameter In SettingsComposer.Settings.DataParameters.AvailableParameters.Items Do
					ParameterName = String(AvailableParameter.Parameter);
					If NOT (StrCompare(ParameterName , "Period") = 0 
								OR StrCompare(ParameterName, MetadataObject.Name) = 0) Then
									Assignment.DCSParametersValues.Insert(ParameterName, NULL);
					EndIf;
				EndDo;
			EndIf;
		EndIf;
	EndDo;
	
	Return BasisForMessagesTemplates;
	
EndFunction

Function TemplatesKinds() Export
	TemplatesTypes = New ValueList;
	TemplatesTypes.Add("Email", NStr("ru = 'Электронные письма'; en = 'Email message'; pl = 'Wiadomość e-mail';es_ES = 'Mensaje de correo electrónico';es_CO = 'Mensaje de correo electrónico';tr = 'E-posta iletisi';it = 'Messaggio email';de = 'E-Mail-Nachricht'"));
	TemplatesTypes.Add("SMS", NStr("ru = 'Сообщения SMS'; en = 'Text message'; pl = 'Wiadomość SMS';es_ES = 'SMS';es_CO = 'SMS';tr = 'SMS';it = 'Messaggio di testo';de = 'Textnachricht'"));
	Return TemplatesTypes;
EndFunction

Function PrepareQueryToGetTemplatesList(TemplateType, Topic = Undefined, TemplateOwner = Undefined, OutputCommonTemplates = True) Export
	
	If TemplateType = "SMS" Then
		ForSMSMessages = True;
		ForEmails = False;
	Else
		ForSMSMessages = False;
		ForEmails = True;
	EndIf;
	
	Query = New Query;
	Query.Text = "SELECT ALLOWED
	|	MessageTemplates.Ref,
	|	MessageTemplates.Presentation,
	|	MessageTemplates.Description AS Name,
	|	MessageTemplates.ExternalDataProcessor AS ExternalDataProcessor,
	|	MessageTemplates.TemplateByExternalDataProcessor AS TemplateByExternalDataProcessor,
	|	CASE
	|		WHEN MessageTemplates.ForEmails
	|			THEN CASE
	|					WHEN MessageTemplates.MailTextType = VALUE(Enum.EmailEditingMethods.HTML)
	|						THEN MessageTemplates.HTMLMessageTemplateText
	|					ELSE MessageTemplates.MessageTemplateText
	|				END
	|		ELSE MessageTemplates.SMSTemplateText
	|	END AS TemplateText,
	|	MessageTemplates.MailTextType,
	|	MessageTemplates.EmailSubject,
	|		CASE
	|			WHEN COUNT(MessageTemplates.Parameters.ParameterName) > 0
	|				THEN TRUE
	|			ELSE FALSE
	|		END AS HasArbitraryParameters
	|FROM
	|	Catalog.MessageTemplates AS MessageTemplates
	|WHERE
	|	(MessageTemplates.AvailableToAuthorOnly = FALSE OR MessageTemplates.Author = &User) AND
	|	MessageTemplates.ForSMSMessages = &ForSMSMessages
	|	AND MessageTemplates.ForEmails = &ForEmails
	|	AND MessageTemplates.Purpose <> ""Internal""
	|	%TemplateOwner%
	|	AND MessageTemplates.DeletionMark = FALSE";
	
	If ValueIsFilled(TemplateOwner) Then
		FilterByOwner = "AND MessageTemplates.TemplateOwner = &TemplateOwner";
		Query.SetParameter("TemplateOwner", TemplateOwner);
	Else
		FilterByOwner = "";
	EndIf;
	Query.Text = StrReplace(Query.Text, "%TemplateOwner%", FilterByOwner);
	
	Query.SetParameter("ForSMSMessages", ForSMSMessages);
	Query.SetParameter("ForEmails", ForEmails);
	Query.SetParameter("User", Users.AuthorizedUser());
	
	FilterCommonTemplates = ?(OutputCommonTemplates, "MessageTemplates.ForInputOnBasis = FALSE", "");
	
	If ValueIsFilled(Topic) Then
		Query.Text = Query.Text + " AND (MessageTemplates.InputOnBasisParameterTypeFullName = &FullSubjectTypeName "
		+ ?(ValueIsFilled(FilterCommonTemplates), " OR " + FilterCommonTemplates, "") + ")";
		Query.SetParameter("FullSubjectTypeName", 
			?(TypeOf(Topic) = Type("String"), Topic, Topic.Metadata().FullName()));
	Else 
		Query.Text = Query.Text + ?(ValueIsFilled(FilterCommonTemplates), " AND " + FilterCommonTemplates, "");
	EndIf;
	
	Return Query;
	
EndFunction

// Base object attributes.
//
// Parameters:
//  Attributes - ValueTree - where:
//   * Name - String - 
//   * Presentation - String -
//  FullAssignmentTypeName - String -
//  Presentation - String -
// 
// Returns:
//  ValueTree - where:
//    * Name - String - 
//    * Presentation - String -
//
Function RelatedObjectAttributes(Attributes, FullAssignmentTypeName, Val Presentation = "")
	
	MetadataObject = Metadata.FindByFullName(FullAssignmentTypeName);
	If MetadataObject <> Undefined Then
		ParentName = MetadataObject.Name;
		Presentation = ?(ValueIsFilled(Presentation), Presentation, MetadataObject.Presentation());
	Else
		ParentName = FullAssignmentTypeName;
		Presentation = ?(ValueIsFilled(Presentation), Presentation, FullAssignmentTypeName);
	EndIf;
	
	RelatedObjectAttributesNode = Attributes.Rows.Find(ParentName, "Name");
	If RelatedObjectAttributesNode = Undefined Then
		RelatedObjectAttributesNode = Attributes.Rows.Add();
		RelatedObjectAttributesNode.Name = ParentName;
		RelatedObjectAttributesNode.Presentation = Presentation;
	EndIf;
	
	Return RelatedObjectAttributesNode.Rows;
	
EndFunction

Procedure StandardAttributesToHide(Array)
	
	AddUniqueValueToArray(Array, "DeletionMark");
	AddUniqueValueToArray(Array, "Posted");
	AddUniqueValueToArray(Array, "Ref");
	AddUniqueValueToArray(Array, "Predefined");
	AddUniqueValueToArray(Array, "PredefinedDataName");
	AddUniqueValueToArray(Array, "IsFolder");
	AddUniqueValueToArray(Array, "Parent");
	AddUniqueValueToArray(Array, "Owner");
	
EndProcedure

Procedure AddUniqueValueToArray(Array, Value)
	If Array.Find(Value) = Undefined Then
		Array.Add(Upper(Value));
	EndIf;
EndProcedure

// Print forms and attachments

Procedure DefinePrintFormsList(MetadataObject, Val TemplateParameters, ParameterName = "")
	
	If Common.SubsystemExists("StandardSubsystems.Print") Then
		ModulePrintManager = Common.CommonModule("PrintManagement");
		
		PrintCommandsSources   = ModulePrintManager.PrintCommandsSources();
		If PrintCommandsSources.Find(MetadataObject) <> Undefined Then
			
			ObjectPrintCommands = ModulePrintManager.ObjectPrintCommandsAvailableForAttachments(MetadataObject);
			CheckForDuplicates      = New Map;
			
			For each Attachment In ObjectPrintCommands Do
				If NOT Attachment.Disabled
					AND StrFind(Attachment.ID, ",") = 0
					AND NOT IsBlankString(Attachment.PrintManager)
					AND NOT Attachment.SkipPreview
					AND NOT Attachment.HiddenByFunctionalOptions
					AND CheckForDuplicates[Attachment.UUID] = Undefined Then
						NewRow                 = TemplateParameters.Attachments.Add();
						NewRow.Name             = Attachment.ID;
						NewRow.ID   = Attachment.UUID;
						NewRow.Presentation   = Attachment.Presentation;
						NewRow.PrintManager  = Attachment.PrintManager;
						NewRow.FileType        = "MXL";
						NewRow.Status          = "PrintForm";
						NewRow.ParameterName    = ParameterName;
						NewRow.PrintParameters = Attachment.AdditionalParameters;
						CheckForDuplicates.Insert(Attachment.UUID, True);
				EndIf;
			EndDo;
			
		EndIf;
	EndIf;

EndProcedure

// Writes an email attachment located in a temporary storage to a file.
Function WriteEmailAttachmentFromTempStorage(Owner, Info, FileName, Size, CountOfBlankNamesInAttachments = 0) Export
	
	AddressInTempStorage = Info.Name;
	Details = Info.ID;
	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperations = Common.CommonModule("FilesOperations");
		
		FileNameToParse = FileName;
		ExtensionWithoutPoint = GetFileExtension(FileNameToParse);
		NameWithoutExtension = CommonClientServer.ReplaceProhibitedCharsInFileName(FileNameToParse);
		If IsBlankString(NameWithoutExtension) Then
			
			NameWithoutExtension = NStr("ru = 'Вложение без имени'; en = 'Untitled attachment'; pl = 'Załącznik bez tytułu';es_ES = 'Adjunto sin título';es_CO = 'Adjunto sin título';tr = 'Başlıksız eklenti';it = 'Allegato senza titolo';de = 'Unbenannter Anhang'") + ?(CountOfBlankNamesInAttachments = 0, ""," " + String(CountOfBlankNamesInAttachments + 1));
			CountOfBlankNamesInAttachments = CountOfBlankNamesInAttachments + 1;
			
		Else
			NameWithoutExtension =  ?(ExtensionWithoutPoint = "", NameWithoutExtension, Left(NameWithoutExtension, StrLen(NameWithoutExtension) - StrLen(ExtensionWithoutPoint) - 1));
		EndIf;
		
		FileParameters = ModuleFilesOperations.FileAddingOptions();
		FileParameters.FilesOwner = Owner;
		FileParameters.BaseName = NameWithoutExtension;
		FileParameters.ExtensionWithoutPoint = ExtensionWithoutPoint;
		Return ModuleFilesOperations.AppendFile(FileParameters, AddressInTempStorage, "", Details);
		
	EndIf;
	
	Return Undefined;
	
EndFunction

// Procedure - add a print form attachment
//
// Parameters:
//  SendOptions	 - 	 - 
//  TemplateInfo	 - 	 - 
//  Attachments			 - 	 - 
//  TemplatesParameters	 - 	 - 
//
Procedure AddSelectedPrintFormsToAttachments(SendOptions, TemplateInfo, Attachments, TemplateParameters)
	
	If TemplateInfo.Attachments.Count() = 0 Then
		Return;
	EndIf;
	
	SaveFormats = New Array;
	If TypeOf(TemplateParameters.AttachmentsFormats) = Type("ValueList") Then
		For each AttachmentFormat In TemplateParameters.AttachmentsFormats Do
			SaveFormats.Add(?(TypeOf(AttachmentFormat.Value) = Type("SpreadsheetDocumentFileType"),
				AttachmentFormat.Value,
				SpreadsheetDocumentFileType[AttachmentFormat.Value]));
		EndDo;
	Else
		SaveFormats.Add(SpreadsheetDocumentFileType.PDF);
	EndIf;
	
	For each AttachmentPrintForm In TemplateInfo.Attachments Do
		NameOfParameterWithPrintFormInTemplate = TemplateParameters.SelectedAttachments[AttachmentPrintForm.ID];
		If AttachmentPrintForm.Status = "PrintForm" AND NameOfParameterWithPrintFormInTemplate <> Undefined Then
			PrintManagerName = AttachmentPrintForm.PrintManager;
			PrintParameters    = AttachmentPrintForm.PrintParameters;
			ObjectsArray     = New Array;
			
			// If there is an additional (arbitrary) parameter that has its own print forms defined in the 
			// message template, defining a subject (an object) by the name of the parameter, based on which these print forms will be generated.
			Topic = SendOptions.AdditionalParameters.ArbitraryParameters[NameOfParameterWithPrintFormInTemplate];
			If Topic = Undefined Then
				ObjectsArray.Add(SendOptions.Topic);
			Else
				ObjectsArray.Add(Topic);
			EndIf;
			
			TemplatesNames       = ?(IsBlankString(AttachmentPrintForm.Name), AttachmentPrintForm.ID, AttachmentPrintForm.Name);
			
			If Common.SubsystemExists("StandardSubsystems.Print") Then
				ModulePrintManager = Common.CommonModule("PrintManagement");
				
				Try
					PrintCommand = New Structure;
					PrintCommand.Insert("ID", TemplatesNames);
					PrintCommand.Insert("PrintManager", PrintManagerName);
					PrintCommand.Insert("AdditionalParameters", PrintParameters);
					
					SettingsForSaving = ModulePrintManager.SettingsForSaving();
					SettingsForSaving.SaveFormats = SaveFormats;
					SettingsForSaving.PackToArchive = TemplateParameters.PackToArchive;
					SettingsForSaving.TransliterateFilesNames = TemplateParameters.TransliterateFileNames;
					SettingsForSaving.SignatureAndSeal = TemplateParameters.SignatureAndSeal;
					
					PrintFormsCollection = ModulePrintManager.PrintToFile(PrintCommand, ObjectsArray, SettingsForSaving);
					
				Except
					// An error occurred when creating an external print form. Then creating an email without this print form.
					ErrorInformation = ErrorInfo();
					
					WriteLogEvent(
						EventLogEventName(),
						EventLogLevel.Error,,, NStr("ru = 'Ошибка при создании внешней печатной формы. По причине:'; en = 'Error creating external print form due to:'; pl = 'Błąd podczas utworzenia zewnętrznego formularza wydruku z powodu:';es_ES = 'Error al crear la versión impresa externa debido a:';es_CO = 'Error al crear la versión impresa externa debido a:';tr = 'Harici yazdırma formu şu nedenle oluşturulamadı:';it = 'Errore durante la creazione di un form di stampa esterno a causa di:';de = 'Fehler beim Erstellen eines externen Druckformulars wegen:'") + Chars.LF
							+ DetailErrorDescription(ErrorInformation));
						
					CommonClientServer.MessageToUser(ErrorInformation.Description) // messages are processed in GenerateMessage
				EndTry;
				
				For Each PrintForm In PrintFormsCollection Do
					
					AddressInTempStorage = PutToTempStorage(PrintForm.BinaryData, SendOptions.UUID);
					Attachments.Insert(PrintForm.FileName, AddressInTempStorage);
				EndDo;
				
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

// A function creating the attachment table.
// 
// Returns:
//  ValueTable - contains the following columns:
//   * Name - String - 
//   * ID - String -  
//   * Presentation - String - 
//   * PrintManager - String - 
//   * PrintParameters - Structure -
//   * FileType - String - 
//   * Status - String - 
//   * Attribute - String -  
//   * ParameterName - String - 
// 
Function AttachmentsTable()
	
	StringType = New TypeDescription("String");
	Attachments = New ValueTable;
	Attachments.Columns.Add("Name",             StringType);
	Attachments.Columns.Add("ID",   StringType);
	Attachments.Columns.Add("Presentation",   StringType);
	Attachments.Columns.Add("PrintManager",  StringType);
	Attachments.Columns.Add("PrintParameters", New TypeDescription("Structure"));
	Attachments.Columns.Add("FileType",        StringType);
	Attachments.Columns.Add("Status",          StringType);
	Attachments.Columns.Add("Attribute",        StringType);
	Attachments.Columns.Add("ParameterName",    StringType);
	
	Return Attachments;
	
EndFunction

// Receives an extension for the passed file name.
//
// Parameters:
//  FileName - String - a name of the file to get the extension for.
//
// Returns:
//   String - an extension received from the passed file.
//
Function GetFileExtension(Val FileName)
	
	FileExtention = "";
	RowsArray = StrSplit(FileName, ".", False);
	If RowsArray.Count() > 1 Then
		FileExtention = RowsArray[RowsArray.Count() - 1];
	EndIf;
	
	Return FileExtention;
	
EndFunction

// Defining and filling in parameters (attributes) in the message text
// 
// Parameters:
//  Template - FormDataStructure, CatalogRef.MessagesTemplates - 
//   * Sender - String -
//   * PrintFormsAndAttachments - Structure - where:
//      ** ID - String -  
//  
// Returns:
//  See MessagesTemplatesClientServer.TemplateParametersDetails 
Function TemplateParameters(Template) Export
	
	Result = MessageTemplatesClientServer.TemplateParametersDetails();
	
	If TypeOf(Template) = Type("FormDataStructure") Then
		
		Result.TemplateType                  = ?(Template.ForSMSMessages, "SMS", "Email");
		Result.Subject                        = Template.EmailSubject;
		
		If Template.ForInputOnBasis Then
			Result.FullAssignmentTypeName  = Template.InputOnBasisParameterTypeFullName;
			Result.Purpose               = Template.Purpose;
		EndIf;
		Result.EmailFormat                 = Template.MailTextType;
		Result.PackToArchive              = Template.PackToArchive;
		Result.Transliterate           = Template.SendInTransliteration;
		Result.Sender                  = Template.Sender;
		If Result.TemplateType = "SMS" Then
			Result.Text                    = Template.SMSTemplateText;
		ElsIf Template.MailTextType = Enums.EmailEditingMethods.HTML Then
			Result.Text                    = Template.HTMLMessageTemplateText;
		Else
			Result.Text                    = Template.MessageTemplateText;
		EndIf;
		Result.TransliterateFileNames = Template.TransliterateFileNames;
		Result.SignatureAndSeal               = Template.SignatureAndSeal;
		
		FillPropertyValues(Result, Template,, "Parameters");
		
		For each PrintFormsAndAttachments In Template.PrintFormsAndAttachments Do
			Result.SelectedAttachments.Insert(PrintFormsAndAttachments.ID, PrintFormsAndAttachments.Name);
		EndDo;
		
		For each StringParameter In Template.Parameters Do
			Result.Parameters.Insert(StringParameter.ParameterName, New Structure("TypeDetails, Presentation", StringParameter.TypeDetails, StringParameter.ParameterPresentation));
		EndDo;
		
	ElsIf TypeOf(Template) = Type("CatalogRef.MessageTemplates") Then
		Query = New Query;
		Query.Text = "SELECT ALLOWED
		|	MessageTemplates.ForInputOnBasis,
		|	MessageTemplates.InputOnBasisParameterTypeFullName,
		|	MessageTemplates.Purpose,
		|	MessageTemplates.Description,
		|	MessageTemplates.ForEmails,
		|	MessageTemplates.MailTextType,
		|	CASE
		|		WHEN MessageTemplates.ForEmails
		|			THEN CASE
		|					WHEN MessageTemplates.MailTextType = VALUE(Enum.EmailEditingMethods.HTML)
		|						THEN MessageTemplates.HTMLMessageTemplateText
		|					ELSE MessageTemplates.MessageTemplateText
		|				END
		|		ELSE MessageTemplates.SMSTemplateText
		|	END AS TemplateText,
		|	MessageTemplates.EmailSubject,
		|	MessageTemplates.PackToArchive,
		|	MessageTemplates.TransliterateFileNames,
		|	MessageTemplates.AttachmentFormat,
		|	MessageTemplates.ForSMSMessages,
		|	MessageTemplates.SendInTransliteration,
		|	MessageTemplates.SignatureAndSeal,
		|	MessageTemplates.TemplateByExternalDataProcessor,
		|	MessageTemplates.ExternalDataProcessor,
		|	MessageTemplates.Ref,
		|	MessageTemplates.TemplateOwner
		|FROM
		|	Catalog.MessageTemplates AS MessageTemplates
		|WHERE
		|	MessageTemplates.Ref = &Template
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	MessagesTemplatesPrintFormsAndAttachments.ID,
		|	MessagesTemplatesPrintFormsAndAttachments.Name
		|FROM
		|	Catalog.MessageTemplates.PrintFormsAndAttachments AS MessagesTemplatesPrintFormsAndAttachments
		|WHERE
		|	MessagesTemplatesPrintFormsAndAttachments.Ref = &Template
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	MessagesTemplatesParameters.ParameterPresentation,
		|	MessagesTemplatesParameters.ParameterType,
		|	MessagesTemplatesParameters.ParameterName
		|FROM
		|	Catalog.MessageTemplates.Parameters AS MessagesTemplatesParameters
		|WHERE
		|	MessagesTemplatesParameters.Ref = &Template";
		
		Query.SetParameter("Template", Template);
		
		QueryResult = Query.ExecuteBatch();
		TemplateInfo = QueryResult[0].Unload();
		
		If TemplateInfo.Count() > 0 Then
			
			TemplateInfoString = TemplateInfo[0];
			For each SelectedPrintForm In QueryResult[1].Unload() Do
				Result.SelectedAttachments.Insert(SelectedPrintForm.ID, SelectedPrintForm.Name);
			EndDo;
			Result.Text                      = TemplateInfoString.TemplateText;
			Result.TemplateType                 = ?(TemplateInfoString.ForSMSMessages, "SMS", "Email");
			
			If TemplateInfoString.ForInputOnBasis Then
				Result.Purpose              = TemplateInfoString.Purpose;
				Result.FullAssignmentTypeName = TemplateInfoString.InputOnBasisParameterTypeFullName;
			EndIf;
			Result.EmailFormat                = TemplateInfoString.MailTextType;
			
			If Result.TemplateType = "SMS" Then
				Result.Transliterate      = TemplateInfoString.SendInTransliteration;
			Else
				Result.Subject                    = TemplateInfoString.EmailSubject;
				Result.PackToArchive         = TemplateInfoString.PackToArchive;
				Result.EmailFormat            = TemplateInfoString.MailTextType;
				Result.SignatureAndSeal          = TemplateInfoString.SignatureAndSeal;
			EndIf;
			
			FillPropertyValues(Result, TemplateInfoString);
			Result.AttachmentsFormats             = TemplateInfoString.AttachmentFormat.Get();
			
			For each StringParameter In QueryResult[2].Unload() Do
				Result.Parameters.Insert(StringParameter.ParameterName, New Structure("TypeDetails, Presentation", StringParameter.ParameterType.Get(), StringParameter.ParameterPresentation));
			EndDo;
			
		EndIf;
	EndIf;
	
	If ValueIsFilled(Result.FullAssignmentTypeName) 
		AND NOT ObjectIsTemplateSubject(Result.FullAssignmentTypeName) Then
		// The object does not belong to the list of template objects, that is why the template can be common only.
		Result.FullAssignmentTypeName = "";
		Result.Purpose              = "";
	EndIf;
	
	MessagesTemplatesSettings = MessagesTemplatesInternalCachedModules.OnDefineSettings();
	Result.Insert("ExtendedRecipientsList", MessagesTemplatesSettings.ExtendedRecipientsList);
	SubjectInfo = MessagesTemplatesSettings.TemplateSubjects.Find(Result.FullAssignmentTypeName, "Name");
	If SubjectInfo <> Undefined Then
		Result.Template = SubjectInfo.Template;
		Result.DCSParameters = SubjectInfo.DCSParametersValues;
		Result.Purpose   = SubjectInfo.Presentation;
	EndIf;
	
	Return Result;
	
EndFunction

// Returns mapping of template message text parameters.
//
// Parameters:
//  TemplateParameters - Structure - template information.
//
// Returns:
//  Map   - mapping of message text parameters.
//
Function ParametersFromMessageText(TemplateParameters) Export
	
	If TemplateParameters.TemplateType = "Email" Then
		Return DefineMessageTextParameters(TemplateParameters.Text + " " + TemplateParameters.Subject);
	ElsIf TemplateParameters.TemplateType = "SMS" Then
		Return DefineMessageTextParameters(TemplateParameters.Text);
	Else
		Return New Map;
	EndIf;
	
EndFunction

Function DefineMessageTextParameters(MessageText)
	
	ParametersArray = New Map;
	
	MessageLength = StrLen(MessageText);
	
	Text = MessageText;
	Position = StrFind(Text, "[");
	While Position > 0 Do
		If Position + 1 > MessageLength Then
			Break;
		EndIf;
		PositionEnd = StrFind(Text, "]", SearchDirection.FromBegin, Position + 1);
		If PositionEnd > 0 Then
			FoundParameter = Mid(Text, Position + 1, PositionEnd - Position - 1);
			ParametersArray.Insert(FoundParameter, "");
		ElsIf PositionEnd = 0 Then
			PositionEnd = Position + 1;
		EndIf;
		If PositionEnd > MessageLength Then
			Break;
		EndIf;
		Position = StrFind(Text, "[", SearchDirection.FromBegin, PositionEnd);
	EndDo;
	
	ParametersMap = New Map;
	For each ParametersArrayElement In ParametersArray Do
		PositionFormat = StrFind(ParametersArrayElement.Key, "{");
		If PositionFormat > 0 Then
			ParameterName  = Left(ParametersArrayElement.Key, PositionFormat - 1);
			FormatLine = Mid(ParametersArrayElement.Key, PositionFormat );
		Else
			ParameterName  = ParametersArrayElement.Key;
			FormatLine = "";
		EndIf;
		ArrayParsedParameter = StrSplit(ParameterName, ".", False);
		If ArrayParsedParameter.Count() < 2 Then
			Continue;
		EndIf;
		
		SetMapItem(ParametersMap, ArrayParsedParameter, FormatLine);
	EndDo;
	
	Return ParametersMap;
	
EndFunction

Procedure SetMapItem(ParametersMap, Val ArrayParsedParameter, FormatLine)
	MapItem = ParametersMap.Get(ArrayParsedParameter[0]);
	If MapItem = Undefined Then
		If ArrayParsedParameter.Count() > 1 Then
			InternalMapItem = New Map;
			ParametersMap.Insert(ArrayParsedParameter[0], InternalMapItem);
			ArrayParsedParameter.Delete(0);
			SetMapItem(InternalMapItem, ArrayParsedParameter, FormatLine)
		Else
			If ParametersMap[ArrayParsedParameter[0] + FormatLine] = Undefined Then
				ParametersMap.Insert(ArrayParsedParameter[0] + FormatLine, "");
			EndIf;
		EndIf;
	Else
		If ArrayParsedParameter.Count() > 1 Then
			ArrayParsedParameter.Delete(0);
			SetMapItem(MapItem, ArrayParsedParameter, FormatLine)
		Else
			If ParametersMap[ArrayParsedParameter[0] + FormatLine] = Undefined Then
				ParametersMap.Insert(ArrayParsedParameter[0] + FormatLine, "");
			EndIf;
		EndIf;
	EndIf;
EndProcedure

Function ParametersList(MessageTextParameters, Prefix = "")
	
	AttributesList = "";
	For each Attribute In MessageTextParameters Do
		If TypeOf(Attribute.Value) = Type("Map") Then
			AttributesList = AttributesList + ParametersList(Attribute.Value, Attribute.Key + ".");
		Else
			If IsBlankString(Attribute.Value) Then
				AttributeName = Attribute.Key;
				PositionFormat = StrFind(AttributeName, "{");
				If PositionFormat > 0 Then
					AttributeName = Left(AttributeName, PositionFormat - 1);
				EndIf;
				AttributesList = AttributesList + ", " + Prefix + AttributeName + " AS " + StrReplace(Prefix + AttributeName, ".", "_");
			EndIf;
		EndIf;
	EndDo;
	
	Return AttributesList;
	
EndFunction

Function FillMessageParameters(TemplateParameters, MessageTextParameters, SendOptions)
	
	Topic = SendOptions.Topic;
	Message = New Structure("AttributesValues, CommonAttributesValues, Attachments, AdditionalParameters");
	Message.Attachments = New Map;
	Message.CommonAttributesValues = New Map;
	Message.AttributesValues = New Map;
	ObjectName = "";
	
	If Topic <> Undefined 
		AND ValueIsFilled(TemplateParameters.FullAssignmentTypeName) Then
		SubjectMetadata = Topic.Metadata(); // MetadataObject
		ObjectName = SubjectMetadata.Name;
		
		If MessageTextParameters[ObjectName] <> Undefined Then
			
			FillAttributesValuesByParameters(Message, MessageTextParameters[ObjectName], TemplateParameters, Topic);
			
		Else
			Message.AttributesValues = ?(MessageTextParameters[TemplateParameters.FullAssignmentTypeName] <> Undefined,
				MessageTextParameters[TemplateParameters.FullAssignmentTypeName], New Map);
		EndIf;
		
	EndIf;
	
	If SendOptions.AdditionalParameters.Property("ArbitraryParameters") Then
		For each ArbitraryTemplateParameter In MessageTextParameters Do
			
			ParameterKey = ArbitraryTemplateParameter.Key;
			If StrCompare(ParameterKey, ObjectName) = 0 Then
				Continue;
			EndIf;
			
			If ParameterKey = MessageTemplatesClientServer.ArbitraryParametersTitle() Then
				ArbitraryAttributes = MessageTextParameters[MessageTemplatesClientServer.ArbitraryParametersTitle()];
				If TypeOf(ArbitraryAttributes ) = Type("Map") Then
					For Each ArbitraryAttribute In ArbitraryAttributes Do
						ArbitraryAttributes[ArbitraryAttribute.Key] = SendOptions.AdditionalParameters.ArbitraryParameters[ArbitraryAttribute.Key];
					EndDo;
				EndIf;
				Continue;
			EndIf;
			
			If ParameterKey = CommonAttributesNodeName() Then
				Continue;
			EndIf;
			
			ArbitraryParameterValue =  SendOptions.AdditionalParameters.ArbitraryParameters[ParameterKey];
			If ArbitraryParameterValue <> Undefined Then
				
				If NOT ValueIsFilled(ArbitraryParameterValue) Then
					Continue;
				EndIf;
				
				If TypeOf(ArbitraryParameterValue) = Type("String")
					Or TypeOf(ArbitraryParameterValue) = Type("Date") Then
					ArbitraryAttributes = MessageTextParameters[MessageTemplatesClientServer.ArbitraryParametersTitle()];
					If TypeOf(ArbitraryAttributes ) = Type("Map") Then
						MessageTextParameters[MessageTemplatesClientServer.ArbitraryParametersTitle()][ParameterKey] = ArbitraryParameterValue;
					EndIf;
				Else
					ArbitraryParameterValueMetadata = ArbitraryParameterValue.Metadata(); // MetadataObject
					ObjectName = ArbitraryParameterValueMetadata.Name;
					
					If MessageTextParameters[ObjectName] <> Undefined Then
						FillAttributesBySubject(MessageTextParameters[ObjectName], ArbitraryParameterValue);
						FillPropertiesAndContactInformationAttributes(MessageTextParameters[ObjectName], ArbitraryParameterValue);
					EndIf;
				EndIf;
			Else
				SendOptions.AdditionalParameters.ArbitraryParameters.Insert(ParameterKey, ArbitraryTemplateParameter.Value);
				
			EndIf;

		EndDo;
	EndIf;
	
	If MessageTextParameters[CommonAttributesNodeName()] <> Undefined Then
		FillCommonAttributes(MessageTextParameters[CommonAttributesNodeName()]);
		Message.CommonAttributesValues = MessageTextParameters[MessageTemplatesInternal.CommonAttributesNodeName()];
	EndIf;
	
	Return Message;
	
EndFunction

Procedure FillAttributesValuesByParameters(Message, Val MessageTextParameters, Val TemplateParameters, Topic)
	
	If MessageTextParameters["ExternalObjectRef"] <> Undefined Then
		MessageTextParameters["ExternalObjectRef"] = ExternalObjectRef(Topic);
		If MessageTextParameters.Count() = 1 Then
			Return;
		EndIf;
	EndIf;
	
	If ValueIsFilled(TemplateParameters.Template) Then
		FillAttributesByDCS(MessageTextParameters, Topic, TemplateParameters);
	Else
		FillAttributesBySubject(MessageTextParameters, Topic);
	EndIf;
	FillPropertiesAndContactInformationAttributes(MessageTextParameters, Topic);
	Message.AttributesValues = MessageTextParameters;

EndProcedure

Function SetAttributesValuesToMessageText(TemplateParameters, MessageTextParameters, Topic)
	
	Result = New Structure("Subject, Text, Attachments");
	
	If TemplateParameters.TemplateType = "Email" Then
		Result.Subject = InsertParametersInRowAccordingToParametersTable(TemplateParameters.Subject, MessageTextParameters);
	EndIf;
	Result.Text = InsertParametersInRowAccordingToParametersTable(TemplateParameters.Text, MessageTextParameters);
	
	Return Result;
	
EndFunction

Procedure SetParametersFromQuery(Parameters, Result, Val Prefix = "")
	
	If ValueIsFilled(Prefix) Then
		Prefix = Prefix + "_";
	EndIf;
	For each ParameterValue In Parameters Do
		If TypeOf(Parameters[ParameterValue.Key]) = Type("Map") Then
			SetParametersFromQuery(Parameters[ParameterValue.Key], Result, Prefix + ParameterValue.Key);
		Else
			If IsBlankString(ParameterValue.Value) Then
				FormatPosition = StrFind(ParameterValue.Key, "{");
				If FormatPosition > 0 Then
					ParameterName = Left(ParameterValue.Key, FormatPosition - 1);
					FormatLine =Mid(ParameterValue.Key, FormatPosition + 1, StrLen(ParameterValue.Key) - StrLen(ParameterName) -2);
					Value = Result.Get(Prefix + ParameterName);
					If StrStartsWith(FormatLine , "A") Then
						Parameters[ParameterValue.Key] = Format(ConvertStringsToType(Value, "Date"), FormatLine);
					ElsIf StrStartsWith(FormatLine , "H") Then
						Parameters[ParameterValue.Key] = Format(ConvertStringsToType(Value, "Number"), FormatLine);
					ElsIf StrStartsWith(FormatLine , "B") Then
						Parameters[ParameterValue.Key] = Format(ConvertStringsToType(Value, "Boolean"), FormatLine);
					Else
						Parameters[ParameterValue.Key] = Format(Result.Get(Prefix + ParameterName), FormatLine);
					EndIf;
				Else
					Parameters[ParameterValue.Key] = ?(Result[Prefix + ParameterValue.Key] <> Undefined, Result[Prefix + ParameterValue.Key], "");
				EndIf;
			EndIf;
		EndIf;
	EndDo;
EndProcedure

Function ConvertStringsToType(Value, Type)
	TypeDetails = New TypeDescription(Type);
	Return TypeDetails.AdjustValue(Value);
EndFunction

Procedure FillCommonAttributes(CommonAttributes)
	
	If TypeOf(CommonAttributes) = Type("Map") Then
		If CommonAttributes.Get("CurrentDate") <> Undefined Then
			CommonAttributes["CurrentDate"] = CurrentSessionDate();
		EndIf;
		If CommonAttributes.Get("SystemTitle") <> Undefined Then
			CommonAttributes["SystemTitle"] = ThisInfobaseName();
		EndIf;
		If CommonAttributes.Get("InfobaseInternetAddress") <> Undefined Then
			CommonAttributes["InfobaseInternetAddress"] = Common.InfobasePublicationURL();
		EndIf;
		If CommonAttributes.Get("InfobaseLocalAddress") <> Undefined Then
			CommonAttributes["InfobaseLocalAddress"] = Common.LocalInfobasePublishingURL();
		EndIf;
		
		If TypeOf(CommonAttributes.Get("CurrentUser")) = Type("Map") Then
			CurrentUser = Users.AuthorizedUser();
			FillAttributesBySubject(CommonAttributes.Get("CurrentUser"), CurrentUser);
			FillPropertiesAndContactInformationAttributes(CommonAttributes.Get("CurrentUser"), CurrentUser);
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure FillAttributesByDCS(Attributes, Topic, TemplateParameters) Export
	
	TemplateName = TemplateParameters.Template;
	
	QueryParameters = New Array;
	ObjectMetadata = Topic.Metadata();
	ObjectName = ObjectMetadata.Name;
	ObjectManager = Common.ObjectManagerByFullName(ObjectMetadata.FullName());
	DCSTemplate = ObjectManager.GetTemplate(TemplateName);
	
	SchemaURL = PutToTempStorage(DCSTemplate);
	SettingsComposer = New DataCompositionSettingsComposer;
	SettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(SchemaURL));
	For Each AvailableParameter In SettingsComposer.Settings.DataParameters.AvailableParameters.Items Do
		If StrCompare(AvailableParameter.Title, "Period") <> 0 Then
			QueryParameters.Add(String(AvailableParameter.Parameter));
		EndIf;
	EndDo;
	
	SettingsComposer.LoadSettings(DCSTemplate.DefaultSettings);
	TemplateComposer = New DataCompositionTemplateComposer();
	
	For Each Attribute In Attributes Do
		SelectedField = SettingsComposer.Settings.Selection.Items.Add(Type("DataCompositionSelectedField"));
		
		FieldName = Attribute.Key;
		If StrEndsWith(FieldName, "}") AND StrFind(FieldName, "{") > 0 Then
			FieldName = Left(FieldName, StrFind(FieldName, "{") - 1);
		EndIf;
		
		SelectedField.Field = New DataCompositionField(FieldName);
	EndDo;
	
	DataCompositionTemplate = TemplateComposer.Execute(DCSTemplate, SettingsComposer.GetSettings(),,, Type("DataCompositionValueCollectionTemplateGenerator"));
	
	If DataCompositionTemplate.DataSets.Count() = 0 Then
		Return;
	EndIf;
	
	QueryTextTemplate = DataCompositionTemplate.DataSets.Data.Query;
	
	Query = New Query;
	Query.Text = QueryTextTemplate;
	
	HasBlankParameter = False;
	For each RequiredParameter In QueryParameters Do
		If StrCompare(RequiredParameter, "CurrentDate") = 0 Then
			Query.SetParameter(RequiredParameter, CurrentSessionDate());
		ElsIf StrCompare(RequiredParameter, ObjectName) = 0 Then
			Query.SetParameter(RequiredParameter, Topic);
		Else
			If TemplateParameters.DCSParameters.Property(RequiredParameter) Then
				Query.SetParameter(RequiredParameter, TemplateParameters.DCSParameters[RequiredParameter]);
			Else
				HasBlankParameter = True;
				Break;
			EndIf;
			
		EndIf;
	EndDo;
	
	If HasBlankParameter Then
		Raise NStr("ru = 'Не удалось сформировать сообщение, т.к. отсутствуют необходимые параметры.'; en = 'Cannot generate the message. Required placeholders are missing.'; pl = 'Nie można wygenerować wiadomości. Brakuje wymaganych symboli zastępczych.';es_ES = 'No se puede generar el mensaje. Faltan los marcadores de posición requeridos.';es_CO = 'No se puede generar el mensaje. Faltan los marcadores de posición requeridos.';tr = 'İleti oluşturulamıyor. Gerekli yer tutucular eksik.';it = 'Impossibile generare il messaggio. I segnaposto richiesti sono mancanti.';de = 'Die Nachricht kann nicht generiert werden. Erforderliche Platzhalter fehlen.'");
	EndIf;
	
	QueryResult = Query.Execute().Unload();
	If QueryResult.Count() > 0 Then
		QueryResult = ValueTableRowToMap(QueryResult[0]);
		SetParametersFromQuery(Attributes, QueryResult);
	EndIf;
	
EndProcedure

Procedure FillAttributesBySubject(Attributes, Topic)
	
	ObjectMetadata = Topic.Metadata();
	BasisParameters = DefineAttributesForMetadataQuery(Attributes, ObjectMetadata);
	
	AttributesList = Mid(ParametersList(BasisParameters), 3);
	If ValueIsFilled(AttributesList) Then
		Query = New Query;
		QueryText = 
		"SELECT ALLOWED TOP 1
		|	%1
		|FROM
		|	%2 AS %3
		|WHERE
		|	%3.Ref = &Ref";

		QueryText = StringFunctionsClientServer.SubstituteParametersToString(QueryText, AttributesList, ObjectMetadata.FullName(), ObjectMetadata.Name);
		
		Query.SetParameter("Ref", Topic);
		Query.Text = QueryText;
		
		QueryResult = Query.Execute().Unload();
		If QueryResult.Count() > 0 Then
			QueryResult = ValueTableRowToMap(QueryResult[0]);
			SetParametersFromQuery(Attributes, QueryResult);
		EndIf;
	EndIf;
	
EndProcedure

Function ValueTableRowToMap(ValueTableRow)
	
	Map = New Map;
	For each Column In ValueTableRow.Owner().Columns Do
		Map.Insert(Column.Name, ValueTableRow[Column.Name]);
	EndDo;
	
	Return Map;
	
EndFunction

// Inserts message parameter values into a template and generates a message text.
//
Function InsertParametersInRowAccordingToParametersTable(Val StringPattern, ValuesToInsert, Val Prefix = "") Export
	
	Result = StringPattern;
	For each AttributesList In ValuesToInsert Do
		If TypeOf(AttributesList.Value) = Type("Map") Then
			Result = InsertParametersInRowAccordingToParametersTable(Result, AttributesList.Value, Prefix + AttributesList.Key + ".");
		Else
			Result = StrReplace(Result, "[" + Prefix + AttributesList.Key + "]", AttributesList.Value);
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

// Processes HTML text for storing to a formatted document.
//
Procedure ProcessHTMLForFormattedDocument(TemplateParameters, GeneratedMessage, ConvertHTMLForFormattedDocument, FileList = Undefined) Export

	If IsBlankString(GeneratedMessage.Text) Then
		Return;
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperations = Common.CommonModule("FilesOperations");
		
		If FileList = Undefined Then
			FileList = New Array;
			ModuleFilesOperations.FillFilesAttachedToObject(TemplateParameters.Template, FileList);
		EndIf;
		
		DocumentHTML = GetHTMLDocumentObjectFromHTMLText(GeneratedMessage.Text);
		For each Picture In DocumentHTML.Images Do
			
			AttributePictureSource = Picture.Attributes.GetNamedItem("src");
			
			AdditionalParameters = New Structure;
			AdditionalParameters.Insert("FormID", TemplateParameters.UUID);
			AdditionalParameters.Insert("RaiseException", False);
			
			PictureMissingInAttachedFiles = True;
			
			For Each AttachedFile In FileList Do
				If StrOccurrenceCount(AttributePictureSource.Value, AttachedFile.EmailFileID) > 0 Then
					FileData = ModuleFilesOperations.FileData(AttachedFile.Ref, AdditionalParameters);
					ProcessPictureInHTMLTextForFormattedDocument(Picture, FileData, GeneratedMessage, 
					AttributePictureSource, AttachedFile.Description, AttachedFile.EmailFileID);
					PictureMissingInAttachedFiles = False;
					Break;
				ElsIf StrStartsWith(AttributePictureSource.Value, "cid:" + AttachedFile.Description) Then
					FoundRow = GeneratedMessage.Attachments.Find(AttachedFile.Description, "Presentation");
					If FoundRow <> Undefined Then
						GeneratedMessage.Attachments.Delete(FoundRow);
					EndIf;
					
					FileData = ModuleFilesOperations.FileData(AttachedFile.Ref, AdditionalParameters);
					ProcessPictureInHTMLTextForFormattedDocument(Picture, FileData, GeneratedMessage,
						AttributePictureSource, AttachedFile.Description, AttachedFile.Description);
					PictureMissingInAttachedFiles = False;
					Break;
				EndIf;
			EndDo;
			If PictureMissingInAttachedFiles Then
				PictureName = Mid(AttributePictureSource.Value, 5);
				FoundRow = GeneratedMessage.Attachments.Find(PictureName, "Presentation");
				If FoundRow <> Undefined Then
					BinaryData = GetFromTempStorage(FoundRow.AddressInTempStorage);
					AddressInTempStorage = PutToTempStorage(BinaryData, TemplateParameters.UUID);
					
					FoundRow.ID = PictureName;
					FoundRow.AddressInTempStorage = AddressInTempStorage;
					NewAttributePicture = AttributePictureSource.CloneNode(False);
					NewAttributePicture.TextContent = PictureName;
					Picture.Attributes.SetNamedItem(NewAttributePicture);
				EndIf;
			EndIf;
		EndDo;
		
		If ConvertHTMLForFormattedDocument Then
			HTMLText = GetHTMLTextFromHTMLDocumentObject(DocumentHTML);
			GeneratedMessage.Text = HTMLText;
		EndIf;
	EndIf;
	
EndProcedure

Procedure ProcessPictureInHTMLTextForFormattedDocument(Picture, AttachedFile, GeneratedMessage, AttributePictureSource, Presentation, ID)
	
	NewAttributePicture = AttributePictureSource.CloneNode(False);
	NewAttributePicture.TextContent = AttachedFile.Description;
	Picture.Attributes.SetNamedItem(NewAttributePicture);
	
	NewAttachment = GeneratedMessage.Attachments.Add();
	NewAttachment.Presentation = Presentation;
	NewAttachment.AddressInTempStorage = AttachedFile.BinaryFileDataRef;
	NewAttachment.ID = ID;

EndProcedure

// Receives an HTML text from the HTMLDocument object.
//
// Parameters:
//  DocumentHTML - HTMLDocument - a document, from which the text will be extracted.
//
// Returns:
//   String - an HTML text
//
Function GetHTMLTextFromHTMLDocumentObject(DocumentHTML) Export
	
	DOMWriter = New DOMWriter;
	HTMLWriter = New HTMLWriter;
	HTMLWriter.SetString();
	DOMWriter.Write(DocumentHTML, HTMLWriter);
	Return HTMLWriter.Close();
	
EndFunction

// Receives the HTMLDocument object from an HTML text.
//
// Parameters:
//  HTMLText  - String - an HTML text.
//
// Returns:
//   DocumentHTML - a created HTML document.
Function GetHTMLDocumentObjectFromHTMLText(HTMLText,Encoding = Undefined) Export
	
	Builder = New DOMBuilder;
	HTMLReader = New HTMLReader;
	
	NewHTMLText = HTMLText;
	PositionOpenXML = StrFind(NewHTMLText,"<?xml");
	
	If PositionOpenXML > 0 Then
		
		PositionCloseXML = StrFind(NewHTMLText,"?>");
		If PositionCloseXML > 0 Then
			
			NewHTMLText = Left(NewHTMLText,PositionOpenXML - 1) + Right(NewHTMLText,StrLen(NewHTMLText) - PositionCloseXML -1);
			
		EndIf;
		
	EndIf;
	
	If Encoding = Undefined Then
		HTMLReader.SetString(HTMLText);
	Else
		HTMLReader.SetString(HTMLText, Encoding);
	EndIf;
	Return Builder.Read(HTMLReader);
	
EndFunction

// Operations with attributes

Procedure AttributesByDCS(Attributes, Template, Val Prefix = "") Export
	
	If ValueIsFilled(Prefix) Then
		If NOT StrEndsWith(Prefix, ".") Then
			Prefix = Prefix + ".";
		EndIf;
	EndIf;
	
	SchemaURL = PutToTempStorage(Template);
	SettingsComposer = New DataCompositionSettingsComposer;
	SettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(SchemaURL));
	
	For Each AvailableField In SettingsComposer.Settings.SelectionAvailableFields.Items Do
		
		If AvailableField.Folder Then
			Continue;
		EndIf;
		
		NewString = AddAttribute(Prefix + AvailableField.Field, Attributes);
		NewString.Presentation = AvailableField.Title;
		NewString.Type           = AvailableField.ValueType;
		
	EndDo;
	
EndProcedure

Procedure AttributesByObjectMetadata(Attributes, MetadataObject, AttributesList = "", ExcludingAttributes = "", Val Prefix = "")
	
	AttributesListInfo = New Structure("AttributesList, ListContainsData");
	AttributesListInfo.AttributesList  = StrSplit(Upper(AttributesList), ",", False);
	AttributesListInfo.ListContainsData = (AttributesListInfo.AttributesList.Count() > 0);
	
	AttributesToExcludeInfo = New Structure("AttributesList, ListContainsData");
	AttributesToExcludeInfo.AttributesList = StrSplit(Upper(ExcludingAttributes), ",", False);
	AttributesToExcludeInfo.ListContainsData = (AttributesToExcludeInfo.AttributesList.Count() > 0);
	
	If NOT Common.IsEnum(MetadataObject) Then
		For each Attribute In MetadataObject.Attributes Do
			If NOT StrStartsWith(Attribute.Name, "Delete") Then
				If Attribute.Type.Types().Count() = 1 AND Attribute.Type.Types()[0] = Type("ValueStorage") Then
					Continue;
				EndIf;
				AddAttributeByObjectMetadata(Attributes, Attribute, Prefix, AttributesListInfo, AttributesToExcludeInfo);
			EndIf;
		EndDo;
	EndIf;
	
	StandardAttributesToHide(AttributesToExcludeInfo.AttributesList);
	AttributesToExcludeInfo.ListContainsData = True;
	For each Attribute In MetadataObject.StandardAttributes Do
		AddAttributeByObjectMetadata(Attributes, Attribute, Prefix, AttributesListInfo, AttributesToExcludeInfo);
	EndDo;
	
	If NOT Common.IsEnum(MetadataObject) Then
		AddPropertiesAttributes(MetadataObject, Prefix, Attributes, AttributesToExcludeInfo, AttributesListInfo);
		AddContactInformationAttributes(MetadataObject, Prefix, Attributes, AttributesToExcludeInfo, AttributesListInfo);
	EndIf;
	
EndProcedure

Procedure AddContactInformationAttributes(MetadataObject, Prefix, Attributes, AttributesToExcludeInfo, AttributesListInfo)
	
	If Common.SubsystemExists("StandardSubsystems.ContactInformation") Then
		Ref = Common.ObjectManagerByFullName(MetadataObject.FullName()).EmptyRef();
		ModuleContactsManager = Common.CommonModule("ContactsManager");
		ContactInformationKinds = ModuleContactsManager.ObjectContactInformationKinds(Ref);
		If ContactInformationKinds.Count() > 0 Then
			For each ContactInformationKind In ContactInformationKinds Do
				AddAttributeByObjectMetadata(Attributes, ContactInformationKind.Ref, Prefix, AttributesListInfo, AttributesToExcludeInfo);
			EndDo;
		EndIf;
	EndIf;

EndProcedure

Procedure AddPropertiesAttributes(MetadataObject, Prefix, Attributes, AttributesToExcludeInfo, AttributesListInfo)
	
	Properties = New Array;
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		EmptyRef = Common.ObjectManagerByFullName(MetadataObject.FullName()).EmptyRef();
		GetAddlInfo = ModulePropertyManager.UseAddlInfo(EmptyRef);
		GetAddlAttributes = ModulePropertyManager.UseAddlAttributes(EmptyRef);
		
		If GetAddlAttributes Or GetAddlInfo Then
			Properties = ModulePropertyManager.ObjectProperties(EmptyRef, GetAddlAttributes, GetAddlInfo);
			For each Property In Properties Do
				AddAttributeByObjectMetadata(Attributes, Property, Prefix, AttributesListInfo, AttributesToExcludeInfo);
			EndDo;
		EndIf;
	EndIf;
	
EndProcedure

Procedure AddAttributeByObjectMetadata(Attributes, Attribute, Prefix, AttributesListInfo, AttributesToExcludeInfo);
	
	If TypeOf(Attribute) = Type("ChartOfCharacteristicTypesRef.AdditionalAttributesAndInfo") Then
		AttributeName = Attribute.Description;
		Presentation = Attribute.Description;
		Type = Attribute.ValueType;
		Format = Attribute.FormatProperties;
	ElsIf TypeOf(Attribute) = Type("CatalogRef.ContactInformationKinds") Then
		AttributeName = Attribute.Description;
		Presentation = Attribute.Description;
		Type = New TypeDescription("String");
		Format = "";
	Else
		AttributeName = Attribute.Name;
		Presentation = Attribute.Presentation();
		Type = Attribute.Type;
		Format = Attribute.Format;
	EndIf;
	
	If AttributesListInfo.ListContainsData
		AND AttributesListInfo.AttributesList.Find(Upper(TrimAll(AttributeName))) = Undefined Then
		Return;
	EndIf;
	
	If AttributesToExcludeInfo.ListContainsData
		AND AttributesToExcludeInfo.AttributesList.Find(Upper(TrimAll(AttributeName))) <> Undefined Then
		Return;
	EndIf;
	
	NewString = Attributes.Add();
	NewString.Name = Prefix + AttributeName;
	NewString.Presentation = Presentation;
	NewString.Type = Type;
	NewString.Format = Format;
	
EndProcedure

Function PropertiesAttributesValues(Topic)
	
	PropertiesValues = New ValueTable;
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		GetAddlInfo = ModulePropertyManager.UseAddlInfo(Topic);
		GetAddlAttributes = ModulePropertyManager.UseAddlAttributes(Topic);
		
		If GetAddlAttributes Or GetAddlInfo Then
			PropertiesValues = ModulePropertyManager.PropertiesValues(Topic, GetAddlAttributes, GetAddlInfo);
		EndIf;
		
	EndIf;
	
	Return PropertiesValues;
	
EndFunction

Function DefineAttributesForMetadataQuery(Val MessageTextParameters, ObjectMetadata)
	
	BasisParameters = CopyMap(MessageTextParameters);
	ProcessDefineAttributesForMetadataQuery(BasisParameters, ObjectMetadata);
	Return BasisParameters;
	
EndFunction

Procedure ProcessDefineAttributesForMetadataQuery(BasisParameters, ObjectMetadata)
	
	For each BasisParameter In BasisParameters Do
		Position = StrFind(BasisParameter.Key, "{");
		If Position > 0 Then
			ParameterName = Left(BasisParameter.Key, Position - 1);
		Else
			ParameterName = BasisParameter.Key;
		EndIf;
		If TypeOf(BasisParameter.Value) = Type("Map") Then
			ObjectMetadataByKey = ObjectMetadata.Attributes.Find(ParameterName);
			If ObjectMetadataByKey <> Undefined Then
				For each Type In ObjectMetadataByKey.Type.Types() Do
					ProcessDefineAttributesForMetadataQuery(BasisParameter.Value, Metadata.FindByType(Type));
				EndDo;
			Else
				BasisParameters.Delete(BasisParameter.Key);
			EndIf;
		ElsIf ObjectMetadata.Attributes.Find(ParameterName) = Undefined Then
			AttributeNotFound = True;
				For each StandardAttributes In ObjectMetadata.StandardAttributes Do
				If StrCompare(StandardAttributes.Name, ParameterName) = 0 Then
					AttributeNotFound = False;
					Break;
				EndIf;
			EndDo;
			
			If AttributeNotFound Then
				BasisParameters.Delete(BasisParameter.Key);
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

Procedure DetermineErrorAttributes(MessageTextParameters, ErrorAttributes, TemplateInfo, Prefix = "") Export
	
	CommonAttributesNodeName = CommonAttributesNodeName();
	For each Attribute In MessageTextParameters Do
		If TypeOf(Attribute.Value) = Type("Map") Then
			DetermineErrorAttributes(Attribute.Value, ErrorAttributes, TemplateInfo, Prefix + Attribute.Key + ".");
		Else
			PositionFormatText = StrFind(Attribute.Key, "{", SearchDirection.FromEnd);
			If PositionFormatText > 0 Then 
				ParameterName = Prefix + Left(Attribute.Key, PositionFormatText - 1);
			Else
				ParameterName = Prefix + Attribute.Key;
			EndIf;
			If StrStartsWith(Prefix, CommonAttributesNodeName) Then
				FoundAttribute = TemplateInfo.CommonAttributes.Rows.Find(ParameterName, "Name", True);
			Else
				FoundAttribute = TemplateInfo.Attributes.Rows.Find(ParameterName, "Name", True);
			EndIf;
			If FoundAttribute = Undefined Then 
				ErrorAttributes.Add(ParameterName);
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

Procedure FillPropertiesAndContactInformationAttributes(MessageTextParameters, Topic);
	
	ObjectMetadata = Topic.Metadata();
	PropertiesValues = PropertiesAttributesValues(Topic);
	ObjectsContactInformation = ContactInformationAttributesValues(Topic);
	
	For each BasisParameter In MessageTextParameters Do
		If TypeOf(BasisParameter.Value) = Type("Map") Then
			ObjectMetadataByKey = ObjectMetadata.Attributes.Find(BasisParameter.Key);
			If ObjectMetadataByKey <> Undefined Then
				FillPropertiesAndContactInformationAttributes(BasisParameter.Value, Topic[BasisParameter.Key]);
			EndIf;
		Else
			AttributeNotFound = True;
			If PropertiesValues <> Undefined Then
				For each RowProperty In PropertiesValues Do
					If StrCompare(RowProperty.Property.Description, BasisParameter.Key) = 0 Then
						MessageTextParameters[BasisParameter.Key] = String(RowProperty.Value);
						AttributeNotFound = False;
						Break;
					EndIf;
				EndDo;
			EndIf;
			
			If AttributeNotFound AND ObjectsContactInformation <> Undefined Then
				For each ObjectContactInformation In ObjectsContactInformation Do
					If StrCompare(ObjectContactInformation.Kind.Description, BasisParameter.Key) = 0 Then
						If ValueIsFilled(MessageTextParameters[BasisParameter.Key]) Then
							PreviousValue = MessageTextParameters[BasisParameter.Key] +", ";
						Else
							PreviousValue = "";
						EndIf;
						MessageTextParameters[BasisParameter.Key] = PreviousValue + String(ObjectContactInformation.Presentation);
					EndIf;
				EndDo;
			EndIf;
			
		EndIf;
	EndDo;
	
EndProcedure

Function ContactInformationAttributesValues(Topic)
	
	ObjectsContactInformation = Undefined;
	If Common.SubsystemExists("StandardSubsystems.ContactInformation") Then
		ModuleContactsManager = Common.CommonModule("ContactsManager");	
		
		ObjectsWithContactInformation = New Array;
		ObjectsWithContactInformation.Add(Topic);
		ContactInformationKinds = ModuleContactsManager.ObjectContactInformationKinds(Topic.Ref);
		If ContactInformationKinds.Count() > 0 Then
			ObjectsContactInformation = ModuleContactsManager.ObjectsContactInformation(ObjectsWithContactInformation,,, CurrentSessionDate());
		EndIf;
	EndIf;
	
	Return ObjectsContactInformation;
	
EndFunction

Function CommonAttributesTitle() Export
	Return NStr("ru = 'Общие реквизиты'; en = 'Common attributes'; pl = 'Wspólne atrybuty';es_ES = 'Atributos comunes';es_CO = 'Atributos comunes';tr = 'Ortak öznitelikler';it = 'Attributi comuni';de = 'Allgemeine Attribute'");
EndFunction

// Operations with auxiliary methods attributes
// 
// Returns:
//  ValueTree - contains the following columns:
//    * Name - String - 
//    * Presentation - String - 
//    * Hint - String - 
//    * Format - String -  
//    * Type - TypesDetails -
//    * ArbitraryParameter - Boolean -
//
Function AttributeTree()
	
	StringType = New TypeDescription("String");
	Attributes = New ValueTree;
	Attributes.Columns.Add("Name", StringType);
	Attributes.Columns.Add("Presentation", StringType);
	Attributes.Columns.Add("ToolTip", StringType);
	Attributes.Columns.Add("Format", StringType);
	Attributes.Columns.Add("Type", New TypeDescription("TypeDescription"));
	Attributes.Columns.Add("ArbitraryParameter", New TypeDescription("Boolean"));
	
	Return Attributes;
	
EndFunction

Function CommonAttributesNodeName() Export
	Return NStr("ru = 'ОбщиеРеквизиты'; en = 'CommonAttributes'; pl = 'CommonAttributes';es_ES = 'CommonAttributes';es_CO = 'CommonAttributes';tr = 'CommonAttributes';it = 'CommonAttributes';de = 'CommonAttributes'");
EndFunction

Function CommonAttributes(Attributes) Export
	
	AttributesNode = Attributes.Rows.Find(CommonAttributesNodeName(), "Name");
	If AttributesNode = Undefined Then
		AttributesNode = Attributes.Rows.Add();
		AttributesNode.Name = CommonAttributesNodeName();
		AttributesNode.Presentation = CommonAttributesTitle();
	EndIf;
	
	Return AttributesNode;
	
EndFunction

Function DetermineCommonAttributes() Export
	
	CommonAttributes = AttributeTree();
	CommonRowAttributes = CommonAttributes(CommonAttributes);
	
	AddCommonAttribute(CommonRowAttributes, "CurrentDate", NStr("ru = 'Текущая дата'; en = 'Current date'; pl = 'Data bieżąca';es_ES = 'Fecha actual';es_CO = 'Fecha actual';tr = 'Geçerli tarih';it = 'Data corrente';de = 'Aktuelles Datum'"), New TypeDescription("Date"));
	AddCommonAttribute(CommonRowAttributes, "SystemTitle", NStr("ru = 'Заголовок системы'; en = 'Application title'; pl = 'Tytuł aplikacji';es_ES = 'Título de aplicación';es_CO = 'Título de aplicación';tr = 'Uygulama başlığı';it = 'Titolo applicazione';de = 'Titel der Anwendung'"));
	AddCommonAttribute(CommonRowAttributes, "InfobaseInternetAddress", NStr("ru = 'Адрес базы в Интернете'; en = 'Infobase web address'; pl = 'Adres sieciowy bazy informacyjnej';es_ES = 'Dirección web de la base de información';es_CO = 'Dirección web de la base de información';tr = 'Infobase web adresi';it = 'Indirizzo web infobase';de = 'Infobase Webadresse'"), New TypeDescription("String"));
	AddCommonAttribute(CommonRowAttributes, "InfobaseLocalAddress", NStr("ru = 'Адрес базы в локальной сети'; en = 'Infobase LAN address'; pl = 'Adres LAN bazy informacyjnej';es_ES = 'Dirección LAN de la base de información';es_CO = 'Dirección LAN de la base de información';tr = 'Infobase LAN adresi';it = 'Indirizzo LAN infobase';de = 'Infobase LAN-Adresse'"), New TypeDescription("String"));
	AddCommonAttribute(CommonRowAttributes, "CurrentUser", NStr("ru = 'Текущий пользователь'; en = 'Current user'; pl = 'Bieżący użytkownik';es_ES = 'Usuario actual';es_CO = 'Usuario actual';tr = 'Mevcut kullanıcı';it = 'Utente corrente';de = 'Aktueller Benutzer'"), New TypeDescription("CatalogRef.Users"));
	ExpandAttribute(CommonAttributesNodeName() + ".CurrentUser", CommonRowAttributes.Rows,, "Invalid, IBUserID, ServiceUserID, Prepared, Internal");
	
	Return CommonAttributes;
	
EndFunction

Procedure AddCommonAttribute(CommonAttributes, Name, Presentation, Type = Undefined)
	
	NewAttribute = CommonAttributes.Rows.Add();
	NewAttribute.Name = CommonAttributesNodeName() + "." + Name;
	NewAttribute.Presentation = Presentation;
	If Type = Undefined Then
		NewAttribute.Type = New TypeDescription("String");
	Else
		NewAttribute.Type = Type;
	EndIf;
	
EndProcedure

Function AddAttribute(Val Name, Node)
	
	NodeName = Node.Parent.Name;
	If NOT StrStartsWith(Name, NodeName + ".") Then
		Name = NodeName + "." + Name;
	EndIf;
	
	NewAttribute = Node.Add();
	NewAttribute.Name = Name;
	NewAttribute.Presentation = Name;
	
	Return NewAttribute;
	
EndFunction

Function ExpandAttribute(Val Name, Node, AttributesList = "", ExcludingAttributes = "") Export
	
	Attribute = Node.Find(Name, "Name", False);
	If Attribute <> Undefined Then
		ExpandAttributeByObjectMetadata(Attribute, AttributesList, ExcludingAttributes, Name);
	Else
		Name = Node.Parent.Name + "." + Name;
		Attribute = Node.Find(Name, "Name", False);
		If StrOccurrenceCount(Name, ".") > 1 Then
			Return Attribute.Rows;
		EndIf;
		
		If Attribute <> Undefined Then
			ExpandAttributeByObjectMetadata(Attribute, AttributesList, ExcludingAttributes, Name);
		EndIf;
	EndIf;
	
	Return Attribute.Rows;
	
EndFunction

Procedure ExpandAttributeByObjectMetadata(Attribute, AttributesList, ExcludingAttributes, Val Prefix)
	
	If TypeOf(Attribute.Type) = Type("TypeDescription") Then
		AttributesNode = Attribute.Rows;
		Prefix = Prefix + ?(Right(Prefix, 1) <> ".", ".", "");
		For each Type In Attribute.Type.Types() Do
			MetadataObject = Metadata.FindByType(Type);
			If MetadataObject <> Undefined Then
				AttributesByObjectMetadata(AttributesNode, MetadataObject, AttributesList, ExcludingAttributes, Prefix);
			EndIf;
		EndDo;
	EndIf;
	
EndProcedure

// Files
Procedure AddAttachedFilesToAttachments(Val SendOptions, Val Message)
	
	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperations = Common.CommonModule("FilesOperations");
		AttachedFilesList = New Array;
		ModuleFilesOperations.FillFilesAttachedToObject(SendOptions.Template, AttachedFilesList);
		
		For each AttachedFile In AttachedFilesList Do
			If IsBlankString(AttachedFile.EmailFileID) Then
				FileDetails = ModuleFilesOperations.FileData(AttachedFile.Ref, SendOptions.UUID);
				If Right(FileDetails.FileName, 1) = "." Then
					FileDetailsFileName = Left(FileDetails.FileName, StrLen(FileDetails.FileName) - 1);
				Else
					FileDetailsFileName = FileDetails.FileName;
				EndIf;
				Message.Attachments.Insert(FileDetailsFileName,  FileDetails.BinaryFileDataRef);
			EndIf;
		EndDo;
	EndIf;

EndProcedure

// Gets an application title. If it is not specified, gets a configuration metadata synonym.
Function ThisInfobaseName()
	
	SetPrivilegedMode(True);
	
	Result = Constants.SystemTitle.Get();
	
	If IsBlankString(Result) Then
		
		Result = Metadata.Synonym;
		
	EndIf;
	
	Return Result;
EndFunction

Function ExternalObjectRef(Parameter)
	
	Return Common.InfobasePublicationURL() + "#" +  GetURL(Parameter);
	
EndFunction

Procedure FillMessageRecipients(SendOptions, TemplateParameters, Result, ObjectManager)
	
	If SendOptions.Property("AdditionalParameters")
		AND SendOptions.AdditionalParameters.Property("ArbitraryParameters") Then
		
		MessageSubject = New Structure("Topic, ArbitraryParameters");
		MessageSubject.Topic               = SendOptions.Topic;
		MessageSubject.ArbitraryParameters = SendOptions.AdditionalParameters.ArbitraryParameters;
		CommonClientServer.SupplementStructure(MessageSubject, SendOptions.AdditionalParameters, False);
		
	Else
		
		MessageSubject = SendOptions.Topic;
		
	EndIf;
	
	If TemplateParameters.TemplateType = "Email" Then
		Recipients = GenerateRecipientsByDefault(SendOptions.Topic, TemplateParameters.TemplateType);
		MessageTemplatesOverridable.OnFillRecipientsEmailsInMessage(Recipients, TemplateParameters.FullAssignmentTypeName, MessageSubject);
		If ObjectManager <> Undefined Then
				ObjectManager.OnFillRecipientsEmailsInMessage(Recipients, MessageSubject);
		EndIf;
		
		If TemplateParameters.Property("ExtendedRecipientsList")
			AND TemplateParameters.ExtendedRecipientsList Then
			
			Result.Recipient = New Array;
			For each Recipient In Recipients Do
				If ValueIsFilled(Recipient.Address) Then
					RecipientValue = New Structure("Address, Presentation, ContactInformationSource", 
					Recipient.Address, Recipient.Presentation, Recipient.Contact);
					Result.Recipient.Add(RecipientValue);
				EndIf;
			EndDo;
			
		Else
			
			Result.Recipient = New ValueList();
			For each Recipients In Recipients Do
				If ValueIsFilled(Recipients.Address) Then
					Result.Recipient.Add(Recipients.Address, Recipients.Presentation);
				EndIf;
			EndDo;
			
		EndIf;
		
	Else
		
		Recipients = GenerateRecipientsByDefault(SendOptions.Topic, TemplateParameters.TemplateType);
		MessageTemplatesOverridable.OnFillRecipientsPhonesInMessage(Recipients, TemplateParameters.FullAssignmentTypeName, MessageSubject);
		If ObjectManager <> Undefined Then
			ObjectManager.OnFillRecipientsPhonesInMessage(Recipients, MessageSubject);
		EndIf;
		
		ExtendedRecipientsList = SendOptions.AdditionalParameters.Property("ExtendedRecipientsList") AND SendOptions.AdditionalParameters.ExtendedRecipientsList;
		
		If ExtendedRecipientsList Or (TemplateParameters.Property("ExtendedRecipientsList")
			AND TemplateParameters.ExtendedRecipientsList) Then
			
			Result.Recipient = New Array;
			For each Recipient In Recipients Do
				If ValueIsFilled(Recipient.PhoneNumber) Then
					RecipientValue = New Structure("PhoneNumber, Presentation, ContactInformationSource", 
					Recipient.PhoneNumber, Recipient.Presentation, Recipient.Contact);
					Result.Recipient.Add(RecipientValue);
				EndIf;
			EndDo;
			
		Else
			
			Result.Recipient = New ValueList;
			For each Recipients In Recipients Do
				If ValueIsFilled(Recipients.PhoneNumber) Then
					Result.Recipient.Add(Recipients.PhoneNumber, Recipients.Presentation);
				EndIf;
			EndDo;
			
		EndIf;
		
	EndIf;
	
EndProcedure

Function GenerateRecipientsByDefault(Topic, TemplateType);
	
	Recipients = New ValueTable;
	Recipients.Columns.Add("Presentation", New TypeDescription("String"));
	Recipients.Columns.Add("Contact");
	If StrCompare(TemplateType, "SMS") = 0 Then
		Recipients.Columns.Add("PhoneNumber", New TypeDescription("String"));
		ColumnName = "PhoneNumber";
	Else
		Recipients.Columns.Add("Address", New TypeDescription("String"));
		ColumnName = "Address";
	EndIf;
	
	If Topic = Undefined Then
		Return Recipients;
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ContactInformation") Then
		ModuleContactsManager = Common.CommonModule("ContactsManager");
		
		ContactInformationType = ?(StrCompare(TemplateType, "SMS") = 0,
			ModuleContactsManager.ContactInformationTypeByDescription("Phone"),
			ModuleContactsManager.ContactInformationTypeByDescription("EmailAddress"));
	
			If Common.SubsystemExists("StandardSubsystems.Interactions") Then
				ModuleInteractions = Common.CommonModule("Interactions");
				
				If ModuleInteractions.EmailClientUsed() Then
					Contacts = ModuleInteractions.GetContactsBySubject(Topic, ContactInformationType);
					
					For each ContactInformation In Contacts Do
						NewRow = Recipients.Add();
						NewRow.Contact       = ContactInformation.Contact;
						NewRow.Presentation = ContactInformation.Presentation;
						NewRow[ColumnName]   = ContactInformation.Address;
					EndDo;
				EndIf;
				
		EndIf;
	
		// If the contact list is blank and the object has contact information.
		If Recipients.Count() = 0 AND TypeOf(Topic) <> Type("String") Then
			ObjectsWithContactInformation = CommonClientServer.ValueInArray(Topic);
			
			ObjectContactInformationKinds = ModuleContactsManager.ObjectContactInformationKinds(Topic);
			If ObjectContactInformationKinds.Count() > 0 Then
				ObjectsContactInformation = ModuleContactsManager.ObjectsContactInformation(ObjectsWithContactInformation, ContactInformationType,, CurrentSessionDate());
				If ObjectsContactInformation.Count() > 0 Then
					For each ObjectContactInformation In ObjectsContactInformation Do
						NewRow= Recipients.Add();
						NewRow[ColumnName]   = ObjectContactInformation.Presentation;
						NewRow.Presentation = StrReplace(String(ObjectContactInformation.Object), ",", "");
						NewRow.Contact       = Topic;
					EndDo;
				EndIf;
			EndIf;
			
		EndIf;
		
	EndIf;
	
	Return Recipients;
	
EndFunction

Function CopyMap(Source)
	
	Recipient = New Map;
	
	For each Item In Source Do
		If TypeOf(Item.Value) = Type("Map") Then
			Recipient[Item.Key] = CopyMap(Item.Value);
		Else
			Recipient[Item.Key] = Item.Value;
		EndIf;
	EndDo;
	
	Return Recipient;
	
EndFunction

Function EventLogEventName()
	
	Return NStr("ru = 'Формирование шаблона сообщений'; en = 'Create message template'; pl = 'Utwórz szablon wiadomości';es_ES = 'Crear plantilla de mensaje';es_CO = 'Crear plantilla de mensaje';tr = 'İleti şablonu oluştur';it = 'Creare modello messaggio';de = 'Nachrichtenvorlage erstellen'", CommonClientServer.DefaultLanguageCode());
	
EndFunction

Procedure GenerateMessageInBackground(ServerCallParameters, StorageAddress) Export

	SendOptions = ServerCallParameters.SendOptions;
	MessageKind = ServerCallParameters.MessageKind;
	
	If SendOptions.AdditionalParameters.SendImmediately Then
		Result = GenerateMessageAndSend(SendOptions);
		PutToTempStorage(Result, StorageAddress);
	Else
		TemplateOptions = MessageTemplates.GenerateSendOptions(SendOptions.Template,
			SendOptions.Topic,
			SendOptions.UUID,
			SendOptions.AdditionalParameters.MessageParameters);
		
		CommonClientServer.SupplementStructure(TemplateOptions.AdditionalParameters,
			SendOptions.AdditionalParameters,
			True);
		
		Message = GenerateMessage(TemplateOptions);
		
		If MessageKind = "Email" Then
			Message = ConvertEmailParameters(Message);
		Else
			Message.Attachments = Undefined;
		EndIf;
		
		PutToTempStorage(Message, StorageAddress);
	EndIf;

EndProcedure

Function ConvertEmailParameters(Message)
	
	EmailParameters = New Structure();
	EmailParameters.Insert("Sender");
	EmailParameters.Insert("Subject", Message.Subject);
	EmailParameters.Insert("Text", Message.Text);
	EmailParameters.Insert("UserMessages", Message.UserMessages);
	EmailParameters.Insert("DeleteFilesAfterSend", False);
	
	If Message.Recipient = Undefined OR Message.Recipient.Count() = 0 Then
		EmailParameters.Insert("Recipient", "");
	Else
		EmailParameters.Insert("Recipient", Message.Recipient);
	EndIf;
	
	AttachmentsArray = New Array;
	For Each AttachmentDetails In Message.Attachments Do
		AttachmentInformation = New Structure("Presentation, AddressInTempStorage, Encoding, ID");
		FillPropertyValues(AttachmentInformation, AttachmentDetails);
		AttachmentsArray.Add(AttachmentInformation);
	EndDo;
	EmailParameters.Insert("Attachments", AttachmentsArray);
	
	Return EmailParameters;
	
EndFunction

// Update

// Adds the AddEditPersonalMessagesTemplates role to all profiles that have the BasicSSLRights role.
Procedure AddAddEditPersonalTemplatesRoleToBasicRightsProfiles() Export
	
	If Not Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		Return;
	EndIf;
	
	ModuleAccessManagement = Common.CommonModule("AccessManagement");
	
	NewRoles = New Array;
	NewRoles.Add(Metadata.Roles.BasicSSLRights.Name);
	NewRoles.Add(Metadata.Roles.AddEditPersonalMessagesTemplates.Name);
	
	RolesToReplace = New Map;
	RolesToReplace.Insert(Metadata.Roles.BasicSSLRights.Name, NewRoles);
	
	ModuleAccessManagement.ReplaceRolesInProfiles(RolesToReplace);
	
EndProcedure


#EndRegion
