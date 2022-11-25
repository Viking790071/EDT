///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#Region Public

// Defines an assignment composition and common attributes in message templates
//
// Parameters:
//  Settings - Structure - a structure with keys:
//    * TemplatesSubjects - ValueTable - contains subject options for templates. Columns:
//         ** Name           - String - a unique assignment name.
//         ** Presentation - String - an option presentation.
//         ** Template         - String - a name of the DCS template if the composition of attributes is defined using DCS.
//         ** DCSParametersValues - Structure - DCS parameter values for the current message template subject.
//    * CommonAttributes - ValueTree - contains details of common attributes available in all templates. Columns:
//         ** Name            - String - a unique name of a common attribute.
//         ** Presentation  - String - a common attribute presentation.
//         ** Type            - Type - a common attribute type. It is a string by default.
//    * UseArbitraryParameters  - Boolean - indicates whether it is possible to use arbitrary user 
//                                                    parameters in message templates.
//    * DCSParametersValues - Structure - common values of DCS parameters for all templates, where 
//                                          the attribute composition is defined using DCS.
//
Procedure OnDefineSettings(Settings) Export
	
	
	
EndProcedure

// It is called when preparing message templates and allows you to override a list of attributes and attachments.
//
// Parameters:
//  Attributes - ValueTree - a list of template attributes.
//    * Name            - String - a unique name of a common attribute.
//    * Presentation  - String - a common attribute presentation.
//    * Type            - Type - an attribute type. It is a string by default.
//    * Hint      - String - extended attribute information.
//    * Format         - String - a value output format for numbers, dates, strings, and boolean values.
//  Attachments - ValueTable - print forms and attachments, where:
//    * Name           - String - a unique attachment name.
//    * ID - String - an attachment ID.
//    * Presentation - String - an option presentation.
//    * Hint     - String - extended attachment information.
//    * FileType      - String - an attachment type that matches the file extension: pdf, png, jpg, mxl, and so on.
//  TemplateAssignment       - String - a message template assignment name.
//  AdditionalParameters - Structure - additional information on the message template.
//
Procedure OnPrepareMessageTemplate(Attributes, Attachments, TemplateAssignment, AdditionalParameters) Export
	
	

EndProcedure

// It is called upon creating messages from template to fill in values of attributes and attachments.
//
// Parameters:
//  Message - Structure - a structure with the following keys:
//    * AttributesValues - Map - a list of attributes used in the template.
//      ** Key     - String - an attribute name in the template.
//      ** Value - String - a filling value in the template.
//    * CommonAttributesValues - Map - a list of common attributes used in the template.
//      ** Key     - String - an attribute name in the template.
//      ** Value - String - a filling value in the template.
//    * Attachments - Map - attribute values
//      ** Key     - String - an attachment name in the template.
//      ** Value - BinaryData, String - binary data or an address in a temporary storage of the attachment.
//    * AdditionalParameters - Structure - additional message parameters.
//  TemplateAssignment - String - a full name of a message template assignment.
//  MessageSubject - AnyRef - a reference to an object that is a data source.
//  TemplateParameters - Structure - additional information on the message template.
//
Procedure OnCreateMessage(Message, TemplateAssignment, MessageSubject, TemplateParameters) Export
	
	
	
EndProcedure

// Fills in a list of text message recipients when sending a message generated from template.
//
// Parameters:
//   SMSMessageRecipients - ValueTable - a list of text message recipients.
//     * PhoneNumber - String - a phone number to send a text message to.
//     * Presentation - String - a text message recipient presentation.
//     * Contact       - Arbitrary - a contact that owns the phone number.
//  TemplateAssignment - String - a template assignment ID.
//  MessageSubject - AnyRef - a reference to an object that is a data source.
//                   - Structure  - a structure describing template parameters:
//    * Subject               - AnyRef - a reference to an object that is a data source.
//    * MessageKind - String - a kind of a message being generated: Email or SMSMessage.
//    * ArbitraryParameters - Map - a filled list of arbitrary parameters.
//    * SendImmediately - Boolean - indicates whether to send a text message immediately.
//    * MessageParameters - Structure - additional message parameters.
//
Procedure OnFillRecipientsPhonesInMessage(SMSMessageRecipients, TemplateAssignment, MessageSubject) Export
	
	Var SubjectRef;
	
	If TypeOf(MessageSubject) = Type("Structure") Then
		MessageSubject.Property("Topic", SubjectRef);
	Else
		SubjectRef = MessageSubject;
	EndIf;
	
	MessageTemplatesDrive.OnFillRecipientsPhonesInMessage(SMSMessageRecipients, SubjectRef);
	
EndProcedure

// Fills in a list of email recipients upon sending a message generated from a template.
//
// Parameters:
//   MailRecipients - ValueTable - a list of mail recipients.
//     * Address           - String - a recipient email address.
//     * Presentation   - String - an email recipient presentation.
//     * Contact         - Arbitrary - a contact that owns the email address.
//  TemplateAssignment - String - a template assignment ID.
//  MessageSubject - AnyRef - a reference to an object that is a data source.
//                   - Structure  - a structure describing template parameters:
//    * Subject               - AnyRef - a reference to an object that is a data source.
//    * MessageKind - String - a kind of a message being generated: Email or SMSMessage.
//    * ArbitraryParameters - Map - a filled list of arbitrary parameters.
//    * SendImmediately - Boolean - indicates whether to send an email immediately.
//    * MessageParameters - Structure - additional message parameters.
//    * ConvertHTMLForFormattedDocument - Boolean - indicates whether to convert an HTML text of a 
//             message that contains pictures in an email text because of specifics of displaying 
//             pictures in a formatted document.
//    * Account - CatalogRef.EmailAccounts - an account used to send an email.
//
Procedure OnFillRecipientsEmailsInMessage(EmailRecipients, TemplateAssignment, MessageSubject) Export
	
	Var SubjectRef;
	
	If TypeOf(MessageSubject) = Type("Structure") Then
		MessageSubject.Property("Topic", SubjectRef);
	Else
		SubjectRef = MessageSubject;
	EndIf;
	
	MessageTemplatesDrive.OnFillRecipientsEmailsInMessage(EmailRecipients, SubjectRef);
	
EndProcedure

#EndRegion

