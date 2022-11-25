#Region Public

// Sends emails.
// The function might throw an exception which must be handled.
//
// Parameters:
//  Account - CatalogRef.EmailAccounts - reference to an email account.
//                 
//  SendingParameters - Structure - contains all email data:
//
//   * To - Array, String - recipient email addresses.
//          - Array - collection of address structures:
//              * Address         - String - email address (required).
//              * Presentation - String - recipient's name.
//          - String - recipient email addresses, separator - ";".
//
//   * MessageRecipients - Array - array of structures describing recipients:
//      ** Address - String - recipient email address.
//      ** Presentation - String - addressee presentation.
//
//   * Cc        - Array, String - email addresses of copy recipients. See the "To" field description.
//
//   * BCC - Array, String - email addresses of BCC recipients. See the "To" field description.
//
//   * MailSubject       - String - (mandatory) email subject.
//   * Body       - String - (mandatory) email text (plain text, win1251 encoded).
//   * Importance   - InternetMailMessageImportance.
//
//   * Attachments - Array - attached files (described as structures):
//     ** Presentation - String - attachment file name.
//     ** AddressInTempStorage - String - binary attachment data address in temporary storage.
//     ** Encoding - String - an attachment encoding (used if it differs from the message encoding).
//     ** ID - String - (optional) used to store images displayed in the message body.
//
//   * ReplyAddress - Map - see the "To" field description.
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
//   * Connection - InternetMail - an existing connection to a mail server. If not specified, a new one is created.
//   * MailProtocol - String - if "IMAP" is specified, IMAP is used, otherwise SMTP.
//                              
//   * MessageID - String - (return parameter) ID of the sent email on SMTP server;
//                                       
//   * WrongRecipients - Map - (return parameter) list of addresses that sending was failed to.
//                                          See return value of method InternetMail.Send() in Syntax Assistant.
//
//  DeleteConnection - InternetMail - obsolete, see parameter SendingParameters.Connection.
//  DeleteMailProtocol - String - obsolete, see parameter SendingParameters.MailProtocol.
//
// Returns:
//  String - sent message ID.
//
Function SendEmailMessage(Val Account, Val SendOptions,
	Val DeleteConnection = Undefined, DeleteMailProtocol = "") Export
	
	If DeleteConnection <> Undefined Then
		SendOptions.Insert("Connection", DeleteConnection);
	EndIf;
	
	If Not IsBlankString(DeleteMailProtocol) Then
		SendOptions.Insert("MailProtocol", DeleteMailProtocol);
	EndIf;
	
	If TypeOf(Account) <> Type("CatalogRef.EmailAccounts")
		Or NOT ValueIsFilled(Account) Then
		Raise NStr("ru = 'Учетная запись не заполнена или заполнена неправильно.'; en = 'Account not filled or filled incorrectly.'; pl = 'Konto nie jest wypełnione lub zostało wypełnione nieprawidłowo.';es_ES = 'Cuenta no está rellenada o está rellenada de forma incorrecta.';es_CO = 'Cuenta no está rellenada o está rellenada de forma incorrecta.';tr = 'Hesap yanlış dolduruldu veya doldurulmadı.';it = 'Account non compilato o compilato non in maniera corretta.';de = 'Das Konto ist nicht ausgefüllt oder nicht korrekt ausgefüllt.'");
	EndIf;
	
	If SendOptions = Undefined Then
		Raise NStr("ru = 'Не заданы параметры отправки.'; en = 'The form sending parameters are not set.'; pl = 'Nie określono parametrów wysyłki.';es_ES = 'Parámetros de envío no están especificados.';es_CO = 'Parámetros de envío no están especificados.';tr = 'Gönderme parametreleri belirtilmemiş.';it = 'Il modulo parametri di invio non è impostato.';de = 'Sendeparameter sind nicht angegeben.'");
	EndIf;
	
	RecipientType = ?(SendOptions.Property("SendTo"), TypeOf(SendOptions.SendTo), Undefined);
	CcType = ?(SendOptions.Property("Cc"), TypeOf(SendOptions.Cc), Undefined);
	BCC = CommonClientServer.StructureProperty(SendOptions, "BCC");
	If BCC = Undefined Then
		BCC = CommonClientServer.StructureProperty(SendOptions, "Bcc");
	EndIf;
	
	If RecipientType = Undefined AND CcType = Undefined AND BCC = Undefined Then
		Raise NStr("ru = 'Не указано ни одного получателя.'; en = 'No recipient is selected.'; pl = 'Nie określono odbiorcy.';es_ES = 'No hay un destinatario especificado.';es_CO = 'No hay un destinatario especificado.';tr = 'Hiçbir alıcı belirtilmemiş.';it = 'Nessun destinatario è stato selezionato.';de = 'Kein Empfänger ist angegeben.'");
	EndIf;
	
	If RecipientType = Type("String") Then
		SendOptions.SendTo = CommonClientServer.ParseStringWithEmailAddresses(SendOptions.SendTo);
	ElsIf RecipientType <> Type("Array") Then
		SendOptions.Insert("SendTo", New Array);
	EndIf;
	
	If CcType = Type("String") Then
		SendOptions.Cc = CommonClientServer.ParseStringWithEmailAddresses(SendOptions.Cc);
	ElsIf CcType <> Type("Array") Then
		SendOptions.Insert("Cc", New Array);
	EndIf;
	
	If TypeOf(BCC) = Type("String") Then
		SendOptions.BCC = CommonClientServer.ParseStringWithEmailAddresses(BCC);
	ElsIf TypeOf(BCC) <> Type("Array") Then
		SendOptions.Insert("BCC", New Array);
	EndIf;
	
	If SendOptions.Property("ReplyToAddress") AND TypeOf(SendOptions.ReplyToAddress) = Type("String") Then
		SendOptions.ReplyToAddress = CommonClientServer.ParseStringWithEmailAddresses(SendOptions.ReplyToAddress);
	EndIf;
	
	EmailOperationsInternal.SendMessage(Account, SendOptions);
	EmailOverridable.AfterEmailSending(SendOptions);
	
	If SendOptions.WrongRecipients.Count() > 0 Then
		ErrorText = NStr("ru = 'Следующие почтовые адреса не были приняты почтовым сервером:'; en = 'The following email addresses were declined by mail server:'; pl = 'Następujące adresy e-mail nie zostały przyjęte przez serwer pocztowy:';es_ES = 'Las direcciones del correo electrónico siguientes no han sido aceptadas por el servidor de correo:';es_CO = 'Las direcciones del correo electrónico siguientes no han sido aceptadas por el servidor de correo:';tr = 'Posta sunucusu aşağıdaki posta adreslerini kabul etmedi;';it = 'I seguenti indirizzi email sono stati rifiutati dal server di posta:';de = 'Die folgenden E-Mail-Adressen wurden vom Mailserver nicht akzeptiert:'");
		For Each WrongRecipient In SendOptions.WrongRecipients Do
			ErrorText = ErrorText + Chars.LF + StringFunctionsClientServer.SubstituteParametersToString("%1: %2",
				WrongRecipient.Key, WrongRecipient.Value);
		EndDo;
		Raise ErrorText;
	EndIf;
	
	Return SendOptions.MessageID;
	
EndFunction

// Sends one email.
// The function might throw an exception which must be handled.
//
// Parameters:
//  Account - CatalogRef.EmailAccounts - a mailbox to send an email from.
//                                                                   
//  Email - InternetMailMessage - an email to be sent.
//
// Returns:
//  Structure - an email sending result:
//   * WrongRecipients - Map - recipient addresses with errors:
//    ** Key     - String - a recipient address.
//    ** Value - String - an error text.
//   * SMTPEmailID - String - an email UUID assigned upon sending using SMTP.
//   * IMAPEmailID - String - an email UUID assigned upon sending using IMAP.
//
Function SendEmail(Account, Email) Export
	
	Return EmailOperationsInternal.SendEmail(Account, Email);
	
EndFunction

// Sends multiple emails.
// The function might throw an exception which must be handled.
// If at least one email was successfully sent before an error occurred, an exception is not thrown. 
// On function result processing, check which emails were not sent.
//
// Parameters:
//  Account - CatalogRef.EmailAccounts - a mailbox to send an email from.
//                                                                   
//  Emails - Array - a collection of email messages. Collection item - InternetMailMessage.
//  ErrorText - String - an error massage if not all emails are sent.
//
// Returns:
//  Map - sent emails:
//   * Key     - InternetMailMessage - an email to be sent.
//   * Value - Structure - an email sending result:
//    ** WrongRecipients - Map - recipient addresses with errors:
//     *** Key     - String - a recipient address.
//     *** Value - String - an error text.
//    ** SMTPEmailID - String - an email UUID assigned upon sending using SMTP.
//    ** IMAPEmailID - String - an email UUID assigned upon sending using IMAP.
//
Function SendEmails(Account, Emails, ErrorText = Undefined) Export
	
	Return EmailOperationsInternal.SendEmails(Account, Emails, ErrorText);
	
EndFunction

// Loads messages from email server for the specified account.
// Before loading, checks account filling for validity.
// The function might throw an exception which must be handled.
//
// Parameters:
//   Account - CatalogRef.EmailAccounts - email account.
//
//   ImportParameters - Structure - with the following properties:
//     * Columns - Array - array of strings of column names. The column names must match the fields 
//                          of object
//                          InternetMailMessage.
//     * TestMode - Boolean - if True, the call is made in the account testing mode. At this, the 
//                            messages are selected, but not included in the return values. The test 
//                            mode is disabled by default.
//                            
//     * GetHeaders - Boolean - if True, the returned set only includes message headers.
//                                       
//     * HeadersIDs - Array - headers or IDs of the messages whose full texts are to be retrieved.
//                                    
//     * CastMessagesToType - Boolean - return a set of received email messages as a value table 
//                                    with simple types. Default value is True.
//
// Returns:
//   MessageSet - ValueTable, Boolean - list of emails with the following columns:
//                 Importance, Attachments**, SentDate, ReceivedDate, Title, SenderName,
//                 ID, Cc, Return address, Sender, Recipients, Size, Texts,
//                 Encoding, NonASCIISymbolsEncodingMode, Partial is filled in if the Status is True.
//                 
//
//                 In test mode, True is returned.
//
//                 Note. ** - If any of the attachments are email messages, they are not returned, 
//                 but their attachments - binary data and texts are returned (as binary data, 
//                 recursively).
//
Function DownloadEmailMessages(Val Account, Val ImportParameters = Undefined) Export
	
	UseForReceiving = Common.ObjectAttributeValue(Account, "UseForReceiving");
	If NOT UseForReceiving Then
		Raise NStr("ru = 'Учетная запись не предназначена для получения сообщений.'; en = 'Account not intended for get messages.'; pl = 'Konto nie jest przeznaczone do odbierania wiadomości.';es_ES = 'Cuenta no está destinada para recibir mensajes.';es_CO = 'Cuenta no está destinada para recibir mensajes.';tr = 'Hesap mesaj almak için uygun değildir.';it = 'Account non inteso per ricevere messaggi.';de = 'Das Konto ist nicht für den Empfang von Nachrichten vorgesehen.'");
	EndIf;
	
	If ImportParameters = Undefined Then
		ImportParameters = New Structure;
	EndIf;
	
	Result = EmailOperationsInternal.DownloadMessages(Account, ImportParameters);
	Return Result;
	
EndFunction

// Get available email accounts.
//
//  Parameters:
//   ForSending                    - Boolean - if set to True, only the accounts that can send 
//                                             emails are selected.
//   ForReceiving                   - Boolean - if set to True, only the accounts that can receive 
//                                             emails are selected.
//   IncludingSystemEmailAccount - Boolean - include the system account if it is configured for sending and receiving emails.
//
// Returns:
//  AvailableEmailAccounts - ValueTable - description of accounts:
//   Reference       - CatalogRef.EmailAccounts - account.
//   Description - String - an account description.
//   Address        - String - an email address.
//
Function AvailableEmailAccounts(Val ForSending = Undefined,
										Val ForReceiving  = Undefined,
										Val IncludingSystemEmailAccount = True) Export
	
	If Not AccessRight("Read", Metadata.Catalogs.EmailAccounts) Then
		Return New ValueTable;
	EndIf;
	
	QueryText = 
	"SELECT ALLOWED
	|	EmailAccounts.Ref AS Ref,
	|	EmailAccounts.Description AS Description,
	|	EmailAccounts.EmailAddress AS Address,
	|	CASE
	|		WHEN EmailAccounts.Ref = VALUE(Catalog.EmailAccounts.SystemEmailAccount)
	|			THEN 0
	|		ELSE 1
	|	END AS Priority
	|FROM
	|	Catalog.EmailAccounts AS EmailAccounts
	|WHERE
	|	EmailAccounts.DeletionMark = FALSE
	|	AND CASE
	|			WHEN &ForSending = UNDEFINED
	|				THEN TRUE
	|			ELSE EmailAccounts.UseForSending = &ForSending
	|		END
	|	AND CASE
	|			WHEN &ForReceiving = UNDEFINED
	|				THEN TRUE
	|			ELSE EmailAccounts.UseForReceiving = &ForReceiving
	|		END
	|	AND CASE
	|			WHEN &IncludeSystemEmailAccount
	|				THEN TRUE
	|			ELSE EmailAccounts.Ref <> VALUE(Catalog.EmailAccounts.SystemEmailAccount)
	|		END
	|	AND EmailAccounts.EmailAddress <> """"
	|	AND CASE
	|			WHEN EmailAccounts.UseForReceiving
	|				THEN EmailAccounts.IncomingMailServer <> """"
	|			ELSE TRUE
	|		END
	|	AND CASE
	|			WHEN EmailAccounts.UseForSending
	|				THEN EmailAccounts.OutgoingMailServer <> """"
	|			ELSE TRUE
	|		END
	|	AND (EmailAccounts.AccountOwner = VALUE(Catalog.Users.EmptyRef)
	|			OR EmailAccounts.AccountOwner = &CurrentUser)
	|
	|ORDER BY
	|	Priority,
	|	Description";
	
	Query = New Query;
	Query.Text = QueryText;
	Query.Parameters.Insert("ForSending", ForSending);
	Query.Parameters.Insert("ForReceiving", ForReceiving);
	Query.Parameters.Insert("IncludeSystemEmailAccount", IncludingSystemEmailAccount);
	Query.Parameters.Insert("CurrentUser", Users.CurrentUser());
	
	Return Query.Execute().Unload();
	
EndFunction

// Gets the reference to the account by the account purpose kind.
//
// Returns:
//  Account- CatalogRef.EmailAccounts  - reference to account description.
//                  
//
Function SystemAccount() Export
	
	Return Catalogs.EmailAccounts.SystemEmailAccount;
	
EndFunction

// Checks that the system account is available (can be used).
//
// Returns:
//  Boolean - True if the account is available.
//
Function CheckSystemAccountAvailable() Export
	
	Return EmailOperationsInternal.CheckSystemAccountAvailable();
	
EndFunction

// Returns True if at least one configured email account is available, or user has sufficient access 
// rights to configure the account.
//
// Returns:
//  Boolean - True if the account is available.
//
Function CanSendEmails() Export
	
	If AccessRight("Update", Metadata.Catalogs.EmailAccounts) Then
		Return True;
	EndIf;
	
	If Not AccessRight("Read", Metadata.Catalogs.EmailAccounts) Then
		Return False;
	EndIf;
		
	QueryText = 
	"SELECT ALLOWED TOP 1
	|	1 AS Count
	|FROM
	|	Catalog.EmailAccounts AS EmailAccounts
	|WHERE
	|	NOT EmailAccounts.DeletionMark
	|	AND EmailAccounts.UseForSending
	|	AND EmailAccounts.EmailAddress <> """"
	|	AND EmailAccounts.OutgoingMailServer <> """"
	|	AND (EmailAccounts.AccountOwner = VALUE(Catalog.Users.EmptyRef)
	|			OR EmailAccounts.AccountOwner = &CurrentUser)";
	
	Query = New Query(QueryText);
	Query.Parameters.Insert("CurrentUser", Users.CurrentUser());
	Selection = Query.Execute().Select();
	
	Return Selection.Next();
	
EndFunction

// Checks whether the account is configured for sending or receiving email.
//
// Parameters:
//  Account - Catalog.EmailAccounts - account to be checked.
//  ForSending  - Boolean - check parameters used to send email.
//  ForReceiving - Boolean - check parameters used to receive email.
// 
// Returns:
//  Boolean - True if the account is configured.
//
Function AccountSetUp(Account, Val ForSending = Undefined, Val ForReceiving = Undefined) Export
	
	Parameters = Common.ObjectAttributesValues(Account, "EmailAddress,IncomingMailServer,OutgoingMailServer,UseForReceiving,UseForSending");
	If ForSending = Undefined Then
		ForSending = Parameters.UseForSending;
	EndIf;
	If ForReceiving = Undefined Then
		ForReceiving = Parameters.UseForReceiving;
	EndIf;
	Return Not (IsBlankString(Parameters.EmailAddress) 
		Or ForReceiving AND IsBlankString(Parameters.IncomingMailServer)
		Or ForSending AND IsBlankString(Parameters.OutgoingMailServer));
		
EndFunction

// Checks email account settings.
//
// Parameters:
//  Account     - CatalogRef.EmailAccounts - account to be checked.
//  ErrorMessage - String - error message text or an empty string if no errors occurred.
//  AdditionalMessage - String - messages containg information on the checks made for the account.
//
Procedure CheckSendReceiveEmailAvailability(Account, ErrorMessage, AdditionalMessage) Export
	
	EmailOperationsInternal.CheckSendReceiveEmailAvailability(Account, 
		ErrorMessage, AdditionalMessage);
	
EndProcedure

// Checks whether a document has HTML links to resources downloaded using HTTP(S).
//
// Parameters:
//  DocumentHTML - HTMLDocument - an HTML document to be checked.
//
// Returns:
//  Boolean - True if an HTML document has external resources.
//
Function HasExternalResources(DocumentHTML) Export
	
	Return EmailOperationsInternal.HasExternalResources(DocumentHTML);
	
EndFunction

// Deletes scripts and event handlers from an HTML document, and clears links to resources downloaded using HTTP(S).
//
// Parameters:
//  DocumentHTML - HTMLDocument - an HTML document to clear unsafe content from.
//  DisableExternalResources - Boolean - indicates whether is is necessary to clear links to resources downloaded using HTTP(S).
// 
Procedure DisableUnsafeContent(DocumentHTML, DisableExternalResources = True) Export
	
	EmailOperationsInternal.DisableUnsafeContent(DocumentHTML, DisableExternalResources);
	
EndProcedure

// Generates an email based on passed parameters.
//
// Parameters:
//  Account - CatalogRef.EmailAccounts - reference to an email account.
//                 
//  EmailParameters - Structure - contains all email data:
//
//   * To - Array, String - recipient email addresses.
//          - Array - collection of address structures:
//              * Address         - String - email address (required).
//              * Presentation - String - recipient's name.
//          - String - email recipient addresses, separator - ";".
//
//   * MessageRecipients - Array - array of structures describing recipients:
//      ** Address - String - an email recipient address.
//      ** Presentation - String - addressee presentation.
//
//   * Cc        - Array, String - email addresses of copy recipients. See the "To" field description.
//
//   * BCC - Array, String - email addresses of BCC recipients. See the "To" field description.
//
//   * MailSubject       - String - (mandatory) email subject.
//   * Body       - String - (mandatory) email text (plain text, win1251 encoded).
//   * Importance   - InternetMailMessageImportance.
//
//   * Attachments - Array - attached files (described as structures):
//     ** Presentation - String - attachment file name.
//     ** AddressInTempStorage - String - binary attachment data address in temporary storage.
//     ** Encoding - String - an attachment encoding (used if it differs from the message encoding).
//     ** ID - String - (optional) used to store images displayed in the message body.
//
//   * ReplyAddress - Map - see the "To" field description.
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
// Returns:
//  InternetMailMessage - a prepared email.
//
Function PrepareEmail(Account, EmailParameters) Export
	
	If TypeOf(Account) <> Type("CatalogRef.EmailAccounts")
		Or NOT ValueIsFilled(Account) Then
		Raise NStr("ru = 'Учетная запись не заполнена или заполнена неправильно.'; en = 'The account is not filled in, or is filled with invalid data.'; pl = 'Konto nie jest wypełnione lub jest wypełnione nieprawidłowymi danymi.';es_ES = 'La cuenta no está rellenada o está rellenada con datos no válidos.';es_CO = 'La cuenta no está rellenada o está rellenada con datos no válidos.';tr = 'Hesap doldurulmamıştır ya da geçersiz veriyle doldurulmuştur.';it = 'L''account non è compilato, o è compilato in modo errato.';de = 'Der Account ist nicht ausgefüllt, oder mit ungültigen Daten ausgefüllt.'");
	EndIf;
	
	If EmailParameters = Undefined Then
		Raise NStr("ru = 'Не заданы параметры отправки.'; en = 'The mail sending parameters are not specified.'; pl = 'Parametry wysyłania e-mail nie są określone.';es_ES = 'Parámetros de envío de correo no están especificados.';es_CO = 'Parámetros de envío de correo no están especificados.';tr = 'E-posta gönderme parametreleri belirtilmemiş.';it = 'I parametri di invio non sono stati impostati.';de = 'Die Mail-Sendeparameter sind nicht angegeben.'");
	EndIf;
	
	RecipientType = ?(EmailParameters.Property("SendTo"), TypeOf(EmailParameters.SendTo), Undefined);
	CcType = ?(EmailParameters.Property("Cc"), TypeOf(EmailParameters.Cc), Undefined);
	BCC = CommonClientServer.StructureProperty(EmailParameters, "BCC");
	
	If RecipientType = Undefined AND CcType = Undefined AND BCC = Undefined Then
		Raise NStr("ru = 'Не указано ни одного получателя.'; en = 'No recipients are selected.'; pl = 'Nie wybrano odbiorców.';es_ES = 'Ningún destinatario está seleccionado.';es_CO = 'Ningún destinatario está seleccionado.';tr = 'Hiçbir alıcı seçilmedi.';it = 'Non è specificato alcun destinatario.';de = 'Keine Empfänger sind gewählt.'");
	EndIf;
	
	If RecipientType = Type("String") Then
		EmailParameters.SendTo = CommonClientServer.ParseStringWithEmailAddresses(EmailParameters.SendTo);
	ElsIf RecipientType <> Type("Array") Then
		EmailParameters.Insert("SendTo", New Array);
	EndIf;
	
	If CcType = Type("String") Then
		EmailParameters.Cc = CommonClientServer.ParseStringWithEmailAddresses(EmailParameters.Cc);
	ElsIf CcType <> Type("Array") Then
		EmailParameters.Insert("Cc", New Array);
	EndIf;
	
	If TypeOf(BCC) = Type("String") Then
		EmailParameters.BCC = CommonClientServer.ParseStringWithEmailAddresses(BCC);
	ElsIf TypeOf(BCC) <> Type("Array") Then
		EmailParameters.Insert("BCC", New Array);
	EndIf;
	
	If EmailParameters.Property("ReplyToAddress") AND TypeOf(EmailParameters.ReplyToAddress) = Type("String") Then
		EmailParameters.ReplyToAddress = CommonClientServer.ParseStringWithEmailAddresses(EmailParameters.ReplyToAddress);
	EndIf;
	
	Return EmailOperationsInternal.PrepareEmail(Account, EmailParameters);
	
EndFunction

#EndRegion
