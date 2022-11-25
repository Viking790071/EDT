#Region Public

// Overrides subsystem settings.
//
// Parameters:
//  Settings - Structure - subsystem settings:
//   * CanReceiveEmails - Boolean - show email receiving settings in accounts.
//                                       Default value : False - for basic configuration versions , 
//                                       True - for other versions.
//
Procedure OnDefineSettings(Settings) Export
	
EndProcedure

// Allows executing additional operations after sending email.
//
// Parameters:
//  EmailParameters - Structure - contains all email data:
//   * To      - Array of Structures, String - (mandatory) email address of the recipient.
//                 Address         - String - email address.
//                 Presentation - string - recipient's name.
//
//   * MessageRecipients - Array - array of structures describing recipients:
//                            * ContactInformationSource - CatalogRef - contact information owner.
//                            * Address - String - recipient email address.
//                            * Presentation - String - addressee presentation.
//
//   * Cc      - Array - collection of address structures:
//                   * Address         - string - email address (required).
//                   * Presentation - string - recipient's name.
//                  
//                - String - recipient email addresses, separator - ";".
//
//   * BCC - Array, String - see the "Cc" field description.
//
//   * MailSubject       - String - (mandatory) email subject.
//   * Body       - String - (mandatory) email text (plain text, win1251 encoded).
//   * Importance   - InternetMailMessageImportance.
//   * Attachments   - Map - list of attachments where:
//                   * key     - String - an attachment description.
//                   * value - BinaryData, AddressInTempStorage - attachment data.
//                              - Structure -    contains the following properties:
//                                 * BinaryData - BinaryData - attachment binary data.
//                                 * ID  - String - attachment ID. It is used to store images 
//                                                             displayed in the message body.
//
//   * ReplyAddress - Map - see the "To" field description.
//   * Password      - String - account password.
//   * BasisIDs - String - IDs of the message basis objects.
//   * ProcessTexts  - Boolean - shows whether message text processing is required on sending.
//   * RequestDeliveryReceipt  - Boolean - shows whether a delivery notification is required.
//   * RequestReadReceipt - Boolean - shows whether a read notification is required.
//   * TextType   - String, Enum.EmailTextTypes, InternetMailTextType - specifies the type of the 
//                  passed text, possible values:
//                  HTML/EmailTextTypes.HTML - email text in HTML format.
//                  PlainText/EmailTextTypes.PlainText - plain text of email message.
//                                                                          Displayed "as is" 
//                                                                          (default value).
//                  MarkedUpText/EmailTextTypes.MarkedUpText - email message in
//                                                                                  Rich Text.
//
Procedure AfterEmailSending(EmailParameters) Export
	
	
	
EndProcedure

#EndRegion
