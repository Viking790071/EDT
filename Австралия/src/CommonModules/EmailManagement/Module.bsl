///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#Region Internal

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See JobsQueueOverridable.OnGetTemplatesList. 
Procedure OnGetTemplateList(JobTemplates) Export
	
	JobTemplates.Add("SendReceiveEmails");
	
EndProcedure

Function EmailAttachments(Email, FormID) Export
	
	Result = New ValueTable;
	Result.Columns.Add("Description", Common.StringTypeDetails(256));
	Result.Columns.Add("EmailFileID", Common.StringTypeDetails(32));
	Result.Columns.Add("Ref");
	
	Attachments = GetEmailAttachments(Email, False);
	For each Attachments In Attachments Do
		
		NewAttachments                           = Result.Add();
		NewAttachments.Description              = Attachments.FileName;
		NewAttachments.EmailFileID = Attachments.EmailFileID;
		NewAttachments.Ref                    = Attachments.Ref;
		
	EndDo;
	
	Return Result;
	
EndFunction

Function IsEmailOrMessage(Ref) Export
	
	ObjectType = TypeOf(Ref);
	
	Return ObjectType = Type("DocumentRef.IncomingEmail")
		OR ObjectType = Type("DocumentRef.OutgoingEmail")
		OR ObjectType = Type("DocumentRef.SMSMessage");
	
EndFunction

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Receiving and sending emails

// Sends and receives emails.
Procedure SendReceiveEmails() Export
	
	Common.OnStartExecuteScheduledJob(Metadata.ScheduledJobs.SendReceiveEmails);
	
	If NOT GetFunctionalOption("UseEmailClient") Then
		Return;
	EndIf;
		
	SetPrivilegedMode(True);
	
	WriteLogEvent(EventLogEvent(), 
		EventLogLevel.Information, , ,
		NStr("ru = 'Начато регламентное получение и отправка электронной почты'; en = 'Scheduled email receiving and sending is started'; pl = 'Rozpoczęto wysyłkę i otrzymanie zaplanowanych wiadomości e-mail';es_ES = 'Se ha iniciado la recepción y el envío programado del correo electrónico';es_CO = 'Se ha iniciado la recepción y el envío programado del correo electrónico';tr = 'Programlı e-posta alımı ve gönderimi başlatıldı';it = 'La ricezione e invio programmati delle email è iniziato';de = 'Geplanter E-Mail-Empfangen und -senden ist gestartet'", CommonClientServer.DefaultLanguageCode()));
		
	EmailsReceived = EmailsReceived();
	Account = LoadEmails(EmailsReceived);
	SendEmails(EmailsReceived.EmailsToDefineFolders, EmailsReceived.AllRecievedEmails);
	DeterminePreviouslyImportedSubordinateEmails(Account, EmailsReceived.AllRecievedEmails);
	
	Interactions.FillInteractionsArrayContacts(EmailsReceived.AllRecievedEmails);
	Interactions.SetFoldersForEmailsArray(EmailsReceived.EmailsToDefineFolders);
	Interactions.CalculateReviewedBySubjects(EmailsReceived.AllRecievedEmails);
	Interactions.CalculateReviewedByContacts(EmailsReceived.AllRecievedEmails);

	SendNotoficationsOnReading(False);
	
	WriteLogEvent(EventLogEvent(), 
		EventLogLevel.Information, , ,
		NStr("ru = 'Закончено регламентное получение и отправка электронной почты'; en = 'Scheduled receiving and sending of emails is completed'; pl = 'Zakończono zaplanowany odbiór i wysyłanie wiadomości e-mail';es_ES = 'Se ha finalizado la recepción y el envío programado de correos electrónicos';es_CO = 'Se ha finalizado la recepción y el envío programado de correos electrónicos';tr = 'Programlı e-posta alımı ve gönderimi tamamlandı';it = 'La ricezione e invio programmati delle email è completato';de = 'Geplanter E-Mail-Empfangen und -senden ist abgeschlossen'", CommonClientServer.DefaultLanguageCode()));
	
EndProcedure

Function LoadEmails(EmailsReceived)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	EmailAccounts.Ref                                                        AS Ref,
	|	EmailAccounts.EmailAddress                                         AS EmailAddress,
	|	EmailAccounts.Description                                                  AS Description,
	|	ISNULL(EmailAccountSettings.PutEmailInBaseEmailFolder, FALSE) AS PutEmailInBaseEmailFolder,
	|	CASE
	|		WHEN EmailAccounts.AccountOwner = VALUE(Catalog.Users.EmptyRef)
	|			THEN ISNULL(EmailAccountSettings.EmployeeResponsibleForProcessingEmails, VALUE(Catalog.Users.EmptyRef))
	|		ELSE EmailAccounts.AccountOwner
	|	END                                                                                       AS EmployeeResponsibleForProcessingEmails,
	|	EmailAccounts.KeepMessageCopiesAtServer                              AS KeepCopies,
	|	EmailAccounts.KeepMailAtServerPeriod                              AS KeepDays,
	|	EmailAccounts.UserName                                               AS UserName,
	|	EmailAccounts.ProtocolForIncomingMail                                         AS ProtocolForIncomingMail,
	|	ISNULL(LastEmailImportDate.EmailsImportDate, DATETIME(1, 1, 1))      AS EmailsImportDate,
	|	CASE
	|		WHEN EmailAccounts.ProtocolForIncomingMail = ""IMAP""
	|			THEN ISNULL(EmailAccountSettings.MailHandlingInOtherMailClient, FALSE)
	|		ELSE FALSE
	|	END                                                                                        AS MailHandledInOtherMailClient
	|FROM
	|	Catalog.EmailAccounts AS EmailAccounts
	|		LEFT JOIN InformationRegister.EmailAccountSettings AS EmailAccountSettings
	|		ON (EmailAccountSettings.EmailAccount = EmailAccounts.Ref)
	|		LEFT JOIN InformationRegister.LastEmailImportDate AS LastEmailImportDate
	|		ON (LastEmailImportDate.Account = EmailAccounts.Ref)
	|WHERE
	|	EmailAccounts.UseForReceiving
	|	AND NOT ISNULL(EmailAccountSettings.DoNotUseInIntegratedMailClient, FALSE)
	|	AND EmailAccounts.EmailAddress <> """"
	|	AND EmailAccounts.IncomingMailServer <> """"";
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		ReceivedEmails = 0;
		GetEmails(Selection, False, ReceivedEmails, EmailsReceived);
	EndDo;

	Return Selection.Ref;
	
EndFunction

Procedure SendEmails(EmailsToDefineFolders, AllRecievedEmails)
	
	Query = New Query;
	Query.Text = "
	|SELECT
	|	OutgoingEmail.Ref                                                  AS Ref,
	|	PRESENTATION(OutgoingEmail.Ref)                                   AS EmailPresentation,
	|	OutgoingEmail.DeleteAfterSend                                    AS DeleteAfterSend,
	|	OutgoingEmail.Account                                           AS Account,
	|	ISNULL(EmailMessageFolders.PredefinedFolder, TRUE)                      AS FolderDefinitionRequired,
	|	ISNULL(OutgoingMailNotAcceptedByMailServer.AttemptCount, 0) AS AttemptCount
	|FROM
	|	Document.OutgoingEmail AS OutgoingEmail
	|		INNER JOIN Catalog.EmailAccounts AS EmailAccounts
	|		ON OutgoingEmail.Account = EmailAccounts.Ref
	|		LEFT JOIN InformationRegister.InteractionsFolderSubjects AS InteractionsFolderSubjects
	|			LEFT JOIN Catalog.EmailMessageFolders AS EmailMessageFolders
	|			ON InteractionsFolderSubjects.EmailMessageFolder = EmailMessageFolders.Ref
	|		ON (InteractionsFolderSubjects.Interaction = OutgoingEmail.Ref)
	|		LEFT JOIN InformationRegister.OutgoingMailNotAcceptedByMailServer AS OutgoingMailNotAcceptedByMailServer
	|		ON (OutgoingMailNotAcceptedByMailServer.Email = OutgoingEmail.Ref)
	|WHERE
	|	NOT OutgoingEmail.DeletionMark
	|	AND EmailAccounts.EmailAddress <> """"
	|	AND EmailAccounts.OutgoingMailServer <> """"
	|	AND EmailAccounts.UseForSending
	|	AND OutgoingEmail.EmailStatus = VALUE(Enum.OutgoingEmailStatuses.Outgoing)
	|	AND CASE
	|			WHEN OutgoingEmail.DateToSendEmail = DATETIME(1, 1, 1)
	|				THEN TRUE
	|			ELSE OutgoingEmail.DateToSendEmail < &CurrentDate
	|		END
	|	AND CASE
	|			WHEN OutgoingEmail.EmailSendingRelevanceDate = DATETIME(1, 1, 1)
	|				THEN TRUE
	|			ELSE OutgoingEmail.EmailSendingRelevanceDate > &CurrentDate
	|		END
	|	AND ISNULL(OutgoingMailNotAcceptedByMailServer.AttemptCount, 0) < 5
	|TOTALS BY
	|	Account";
	
	Query.SetParameter("CurrentDate", CurrentSessionDate());
	
	AccountsSelection = Query.Execute().Select(QueryResultIteration.ByGroups);
	While AccountsSelection.Next() Do
		
		Connection = ConnectToEmailServer(AccountsSelection.Account, False);
		If Not Connection.Success Then
			Continue;
		EndIf;	
		
		Try
			
			EmailSelection = AccountsSelection.Select();
			While EmailSelection.Next() Do
				
				If Not SendEmail(EmailSelection, Connection, False) Then
					Continue;
				EndIf;	
				
				If Not EmailSelection.DeleteAfterSend Then
					If EmailSelection.FolderDefinitionRequired Then
						EmailsToDefineFolders.Add(EmailSelection.Ref);
					EndIf;
					AllRecievedEmails.Add(EmailSelection.Ref);
				EndIf;
				
			EndDo;
			Connection.Connection.Logoff();
			
		Except
			Connection.Connection.Logoff();
			Raise;
		EndTry;	
		
	EndDo;
	
EndProcedure

Function SendEmail(EmailSelection, Connection, Interactively)

	EmailObject = EmailSelection.Ref.GetObject();
	If EmailObject = Undefined Then
		Return False;
	EndIf;
	
	Try
		
		EmailParameters = Undefined;
		If Connection.ConnectionProtocol = InternetMailProtocol.IMAP 
			AND NOT OutgoingMailServerNotRequireAdditionalSendingByIMAP(Connection.Profile.SMTPServerAddress)
			AND Not EmailSelection.DeleteAfterSend Then
			MailProtocol = "All";
		Else
			MailProtocol = "";
		EndIf;
		
		Interactions.ExecuteEmailSending(EmailObject, Connection.Connection, EmailParameters, MailProtocol);
		
	Except
		If Not ProcessEmailSendingError(EmailObject, EmailSelection, EmailParameters, Interactively) Then
			Return False;
		EndIf;	
	EndTry;
	
	BeginTransaction();
	Try
		Lock = New DataLock;
		LockItem = Lock.Add("Document.OutgoingEmail");
		LockItem.SetValue("Ref", EmailSelection.Ref);
		Lock.Lock();
		
		If EmailSelection.DeleteAfterSend Then
			EmailObject = EmailSelection.Ref.GetObject();
			EmailObject.Delete();
		Else
			MessageID             = EmailObject.MessageID; 
			MessageIDIMAPSending = EmailObject.MessageIDIMAPSending;
			
			EmailObject = EmailSelection.Ref.GetObject();
			EmailObject.MessageID             = MessageID;
			EmailObject.MessageIDIMAPSending = MessageIDIMAPSending;
			
			EmailObject.EmailStatus                       = Enums.OutgoingEmailStatuses.Sent;
			EmailObject.Size                             = Interactions.EvaluateOutgoingEmailSize(EmailObject.Ref);
			EmailObject.PostingDate                    = CurrentSessionDate();
			EmailObject.AdditionalProperties.Insert("DoNotSaveContacts", True);
			EmailObject.Write(DocumentWriteMode.Write);
		EndIf;
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	Return True;
	
EndFunction	

Function ProcessEmailSendingError(Val EmailObject, Val EmailSelection, Val EmailParameters, Val Interactively)
	
	AnalysisResult = WrongRecipientsAnalysisResult(EmailObject, EmailParameters.WrongRecipients);
	IsIssueOfEmailAddressesServerRejection = AnalysisResult.IsIssueOfEmailAddressesServerRejection;
	AllEmailAddresseesRejectedByServer           = AnalysisResult.AllEmailAddresseesRejectedByServer;
	WrongAddresseesPresentation               = AnalysisResult.WrongAddresseesPresentation;
	
	If IsIssueOfEmailAddressesServerRejection AND Not AllEmailAddresseesRejectedByServer Then
		ErrorMessageTemplate = NStr("ru = 'Следующие адресаты письма %1 не приняты почтовым сервером:
			|%2. Письмо отправлено остальным адресатам.'; 
			|en = 'The following addressees of the email %1 were declined by the server:
			|%2. The email was sent to other addresses.'; 
			|pl = 'Następujące adresy e-mail %1 zostały odrzucone przez serwer:
			|%2. Wiadomość e-mail została wysłana na pozostałe adresy.';
			|es_ES = 'Los siguientes destinatarios del correo electrónico %1 fueron rechazados por el servidor:
			|%2. El correo electrónico fue enviado a otros destinatarios.';
			|es_CO = 'Los siguientes destinatarios del correo electrónico %1 fueron rechazados por el servidor:
			|%2. El correo electrónico fue enviado a otros destinatarios.';
			|tr = '%1 e-postasının şu alıcıları sunucu tarafından reddedildi:
			|%2. E-posta diğer adreslere gönderildi.';
			|it = 'I seguenti destinatari della email %1 sono stati rifiutati dal server:
			|%2. L''email è stata inviata ad altri indirizzi.';
			|de = 'Die folgenden Adressen der E-Mail %1 werden durch den Server abgelehnt:
			|%2. Die E-Mail wurde an die anderen Adressen gesendet.'", CommonClientServer.DefaultLanguageCode());
		ErrorMessageText = StringFunctionsClientServer.SubstituteParametersToString(ErrorMessageTemplate,
			EmailSelection.EmailPresentation, WrongAddresseesPresentation);
	Else
		ErrorMessageTemplate = NStr("ru = 'Не удалось отправить письмо %1 по причине:
			|%2'; 
			|en = 'Cannot send the email %1 due to:
			|%2'; 
			|pl = 'Nie można wysłać wiadomości e-mail %1 z powodu:
			|%2';
			|es_ES = 'No se ha podido enviar el correo electrónico %1 a causa de:
			|%2';
			|es_CO = 'No se ha podido enviar el correo electrónico %1 a causa de:
			|%2';
			|tr = '%1 e-postası gönderilemiyor. Nedeni:
			|%2';
			|it = 'Impossibile inviare la email %1 a causa di: 
			|%2';
			|de = 'Eine E-Mail %1 kann nicht durch: 
			|%2 gesendet werden'", CommonClientServer.DefaultLanguageCode());
		ErrorMessageText = StringFunctionsClientServer.SubstituteParametersToString(ErrorMessageTemplate,
			EmailSelection.EmailPresentation, DetailErrorDescription(ErrorInfo()));
	EndIf;
	
	WriteLogEvent(EventLogEvent(), EventLogLevel.Error, , , ErrorMessageText);
	
	If Interactively Then
		If Not (IsIssueOfEmailAddressesServerRejection AND Not AllEmailAddresseesRejectedByServer) Then
			ErrorMessageText = StringFunctionsClientServer.SubstituteParametersToString(ErrorMessageTemplate,
				EmailSelection.EmailPresentation, BriefErrorDescription(ErrorInfo()));
		EndIf;	
		CommonClientServer.MessageToUser(ErrorMessageText, EmailSelection.Ref);
	EndIf;	
	
	If NOT IsIssueOfEmailAddressesServerRejection Or AllEmailAddresseesRejectedByServer Then
		
		RecordManager = InformationRegisters.OutgoingMailNotAcceptedByMailServer.CreateRecordManager();
		RecordManager.Email = EmailSelection.Ref;
		RecordManager.AttemptCount = ?(AllEmailAddresseesRejectedByServer, 5, EmailSelection.AttemptCount + 1);
		RecordManager.ErrorInformation = ErrorMessageText;
		RecordManager.Write();
		Return False;
		
	EndIf;
	Return True;

EndFunction

Procedure SendNotoficationsOnReading(ForCurrentUser)
	
	QueryText = 
		"SELECT
		|	ReadReceipts.Email AS Email,
		|	PRESENTATION(ReadReceipts.Email) AS EmailPresentation,
		|	ReadReceipts.ReadDate AS ReadDate,
		|	IncomingEmail.ReadReceiptAddresses.(
		|		Address AS Address,
		|		Presentation AS Presentation,
		|		Contact AS Contact
		|	) AS ReadReceiptAddresses,
		|	IncomingEmail.Account AS Account,
		|	IncomingEmail.SenderPresentation AS SenderPresentation,
		|	IncomingEmail.SenderAddress AS SenderAddress,
		|	IncomingEmail.Date AS Date,
		|	EmailAccounts.UserName AS UserName,
		|	EmailAccounts.EmailAddress AS EmailAddress,
		|	IncomingEmail.Subject AS Subject,
		|	ReadReceipts.User AS User
		|FROM
		|	InformationRegister.ReadReceipts AS ReadReceipts
		|		LEFT JOIN Document.IncomingEmail AS IncomingEmail
		|			LEFT JOIN Catalog.EmailAccounts AS EmailAccounts
		|			ON IncomingEmail.Account = EmailAccounts.Ref
		|		ON ReadReceipts.Email = IncomingEmail.Ref
		|WHERE
		|	ReadReceipts.SendingRequired
		|	AND &ForCurrentUser
		|TOTALS BY
		|	Account";
	
	QueryText = StrReplace(QueryText, "&ForCurrentUser", 
		?(ForCurrentUser, "ReadReceipts.User = &User", "TRUE"));
	Query = New Query(QueryText);
	If ForCurrentUser Then
		Query.SetParameter("User", Users.CurrentUser());
	EndIf;
	
	AccountsSelection = Query.Execute().Select(QueryResultIteration.ByGroups);
	While AccountsSelection.Next() Do
		
		Account = AccountsSelection.Account;
		Emails = New Array;
		EmailsHyperlinks = New Map;
		
		EmailSelection = AccountsSelection.Select();
		While EmailSelection.Next() Do
			EmailParameters = New Structure;
			
			Interactions.AddToAddresseesParameter(EmailSelection, EmailParameters, "SendTo", "ReadReceiptAddresses");
			
			EmailParameters.Insert("Subject",NStr("ru = 'Уведомление о прочтении'; en = 'Read receipt'; pl = 'Potwierdzenie przeczytania';es_ES = 'Un recibo de lectura';es_CO = 'Un recibo de lectura';tr = 'Okundu bilgisi';it = 'Ricevuta di lettura';de = 'Lesebestätigung'"));
			EmailParameters.Insert("Body",GenerateReadReceiptText(EmailSelection));
			EmailParameters.Insert("Encoding","UTF-8");
			EmailParameters.Insert("Importance", InternetMailMessageImportance.Normal);
			EmailParameters.Insert("TextType", Enums.EmailTextTypes.PlainText);
			EmailParameters.Insert("ProcessTexts", False);
			
			Email = EmailOperations.PrepareEmail(Account, EmailParameters);
			Emails.Add(Email);
			
			EmailsHyperlinks.Insert(Email, EmailSelection.Email);
		EndDo;
		
		SentEmails = EmailOperations.SendEmails(Account, Emails);
		For Each Email In EmailsHyperlinks Do
			If SentEmails[Email.Key] = Undefined Then
				Continue;
			EndIf;
			Ref = Email.Value;
			SetNotificationSendingFlag(Ref, False);
		EndDo;
		
	EndDo;

EndProcedure

Function ConnectToEmailServer(Account, Interactively)
	
	Result = New Structure;
	Result.Insert("Success", True);
	Result.Insert("Profile", Undefined);
	Result.Insert("Connection", Undefined);
	Result.Insert("ConnectionProtocol", Undefined);
	
	Result.Profile = EmailOperationsInternal.InternetMailProfile(Account);
	Try
		Result.Connection = New InternetMail;
		Result.ConnectionProtocol = ?(IsBlankString(Result.Profile.IMAPServerAddress), InternetMailProtocol.POP3, InternetMailProtocol.IMAP);
		Result.Connection.Logon(Result.Profile, Result.ConnectionProtocol);
		If Result.ConnectionProtocol = InternetMailProtocol.IMAP Then
			Mailboxes = Result.Connection.GetMailboxes();
			For Each Mailbox In Mailboxes Do
				If Lower(Mailbox) = "sent" Or Lower(Mailbox) = "sent" Then
					Result.Connection.CurrentMailbox = Mailbox;
					Break;
				EndIf;
			EndDo;
		EndIf;
		
	Except
		ErrorMessageTemplate = NStr("ru = 'Во время подключения к учетной записи %1 произошла ошибка
			|%2'; 
			|en = 'An error occurred when connecting to account %1
			|%2'; 
			|pl = 'Wystąpił błąd podczas połączenia z kontem %1
			|%2';
			|es_ES = 'Ha ocurrido un error al conectarse a la cuenta %1
			|%2';
			|es_CO = 'Ha ocurrido un error al conectarse a la cuenta %1
			|%2';
			|tr = 'Hesaba bağlanırken hata oluştu %1
			|%2';
			|it = 'Si è verificato un errore durante la connessione all''account %1
			|%2';
			|de = 'Beim Verbinden des Kontos %1
			|%2 ist ein Fehler aufgetreten'", CommonClientServer.DefaultLanguageCode());
		
		ErrorMessageText = StringFunctionsClientServer.SubstituteParametersToString(ErrorMessageTemplate, 
			Account, DetailErrorDescription(ErrorInfo()));
		WriteLogEvent(EventLogEvent(), EventLogLevel.Error, , , ErrorMessageText);
		
		If Interactively Then
			ErrorMessageText = StringFunctionsClientServer.SubstituteParametersToString(ErrorMessageTemplate, 
				Account, BriefErrorDescription(ErrorInfo()));
			CommonClientServer.MessageToUser(ErrorMessageText, Account);	
		EndIf;
		
		Result.Success = False;
	EndTry;
	
	Return Result;

EndFunction	

// Receives email by accounts available to the user.
//
// Parameters:
//  ReceivedEmails               - Number - the amount of received emails will be returned to this parameter.
//  UserAccountsAvailable - Number - the amount of accounts available to user will be returned to 
//                                   this parameter.
//  HasErrors             - Boolean - indicates that there are errors when receiving emails.
//
Procedure LoadUserEmail(Result)
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	EmailAccounts.Ref                                                        AS Ref,
	|	EmailAccounts.EmailAddress                                         AS EmailAddress,
	|	EmailAccounts.Description                                                  AS Description,
	|	ISNULL(EmailAccountSettings.PutEmailInBaseEmailFolder, FALSE) AS PutEmailInBaseEmailFolder,
	|	CASE
	|		WHEN EmailAccounts.AccountOwner = VALUE(Catalog.Users.EmptyRef)
	|			THEN ISNULL(EmailAccountSettings.EmployeeResponsibleForProcessingEmails, VALUE(Catalog.Users.EmptyRef))
	|		ELSE EmailAccounts.AccountOwner
	|	END AS EmployeeResponsibleForProcessingEmails,
	|	EmailAccounts.KeepMessageCopiesAtServer AS KeepCopies,
	|	EmailAccounts.KeepMailAtServerPeriod AS KeepDays,
	|	EmailAccounts.ProtocolForIncomingMail AS ProtocolForIncomingMail,
	|	EmailAccounts.UserName AS UserName,
	|	ISNULL(LastEmailImportDate.EmailsImportDate, DATETIME(1, 1, 1)) AS EmailsImportDate,
	|	CASE
	|		WHEN EmailAccounts.ProtocolForIncomingMail = ""IMAP""
	|			THEN ISNULL(EmailAccountSettings.MailHandlingInOtherMailClient, FALSE)
	|		ELSE FALSE
	|	END AS MailHandledInOtherMailClient
	|FROM
	|	Catalog.EmailAccounts AS EmailAccounts
	|		LEFT JOIN InformationRegister.EmailAccountSettings AS EmailAccountSettings
	|		ON (EmailAccountSettings.EmailAccount = EmailAccounts.Ref)
	|		LEFT JOIN InformationRegister.LastEmailImportDate AS LastEmailImportDate
	|		ON (LastEmailImportDate.Account = EmailAccounts.Ref)
	|WHERE
	|	EmailAccounts.UseForReceiving
	|	AND NOT EmailAccounts.DeletionMark
	|	AND NOT ISNULL(EmailAccountSettings.DoNotUseInIntegratedMailClient, FALSE)";
	
	Selection = Query.Execute().Select();

	Result.EmailsReceived = 0;
	Result.UserAccountsAvailable = Selection.Count();
	If Result.UserAccountsAvailable = 0 Then
		CommonClientServer.MessageToUser(NStr("ru = 'Нет доступных учетных записей для получения почты.'; en = 'No available accounts to receive emails.'; pl = 'Brak dostępnych kont do odbioru wiadomości e-mail.';es_ES = 'No hay cuentas disponibles para recibir correos electrónicos.';es_CO = 'No hay cuentas disponibles para recibir correos electrónicos.';tr = 'E-postaları alacak hesap yok.';it = 'Nessun account disponibile per la ricezione di email.';de = 'Keine verfügbaren Konten für Empfang von E-Mails.'"));
		Result.HasErrors = True;
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	
	While Selection.Next() Do
		
		ReceivedEmails = 0;
		EmailsReceived = EmailsReceived();
		
		GetEmails(Selection, Result.HasErrors, ReceivedEmails, EmailsReceived);
		Result.EmailsReceived = Result.EmailsReceived + ReceivedEmails;
		
		DeterminePreviouslyImportedSubordinateEmails(Selection.Ref, EmailsReceived.AllRecievedEmails);
		Interactions.FillInteractionsArrayContacts(EmailsReceived.AllRecievedEmails);
		Interactions.SetFoldersForEmailsArray(EmailsReceived.EmailsToDefineFolders);
		Interactions.CalculateReviewedBySubjects(EmailsReceived.AllRecievedEmails);
		Interactions.CalculateReviewedByContacts(EmailsReceived.AllRecievedEmails);
		
	EndDo;
	
EndProcedure

Procedure SendUserEmail(Result)

	Query = New Query;
	Query.Text = "
	|SELECT ALLOWED
	|	EmailAccounts.Ref                                               AS Account,
	|	OutgoingEmail.Ref                                                  AS Ref,
	|	PRESENTATION(OutgoingEmail.Ref)                                   AS EmailPresentation,
	|	OutgoingEmail.DeleteAfterSend                                    AS DeleteAfterSend,
	|	ISNULL(EmailMessageFolders.PredefinedFolder, TRUE)                      AS FolderDefinitionRequired,
	|	ISNULL(OutgoingMailNotAcceptedByMailServer.AttemptCount, 0) AS AttemptCount
	|FROM
	|	Document.OutgoingEmail AS OutgoingEmail
	|		INNER JOIN Catalog.EmailAccounts AS EmailAccounts
	|		ON OutgoingEmail.Account = EmailAccounts.Ref
	|		LEFT JOIN InformationRegister.InteractionsFolderSubjects AS InteractionsFolderSubjects
	|			LEFT JOIN Catalog.EmailMessageFolders AS EmailMessageFolders
	|			ON InteractionsFolderSubjects.EmailMessageFolder = EmailMessageFolders.Ref
	|		ON (InteractionsFolderSubjects.Interaction = OutgoingEmail.Ref)
	|		LEFT JOIN InformationRegister.EmailAccountSettings AS EmailAccountSettings
	|		ON OutgoingEmail.Account = EmailAccountSettings.EmailAccount
	|		LEFT JOIN InformationRegister.OutgoingMailNotAcceptedByMailServer AS OutgoingMailNotAcceptedByMailServer
	|		ON OutgoingMailNotAcceptedByMailServer.Email = OutgoingEmail.Ref
	|WHERE
	|	NOT OutgoingEmail.DeletionMark
	|	AND NOT EmailAccounts.DeletionMark
	|	AND OutgoingEmail.EmailStatus = VALUE(Enum.OutgoingEmailStatuses.Outgoing)
	|	AND OutgoingEmail.Author = &User
	|	AND EmailAccounts.UseForSending
	|	AND NOT ISNULL(EmailAccountSettings.DoNotUseInIntegratedMailClient, FALSE)
	|	AND CASE
	|			WHEN OutgoingEmail.DateToSendEmail = DATETIME(1, 1, 1)
	|				THEN TRUE
	|			ELSE OutgoingEmail.DateToSendEmail < &CurrentDate
	|		END
	|	AND CASE
	|			WHEN OutgoingEmail.EmailSendingRelevanceDate = DATETIME(1, 1, 1)
	|				THEN TRUE
	|			ELSE OutgoingEmail.EmailSendingRelevanceDate > &CurrentDate
	|		END
	|	AND ISNULL(OutgoingMailNotAcceptedByMailServer.AttemptCount, 0) < 5
	|TOTALS BY
	|	Account";
	
	Query.SetParameter("User", Users.CurrentUser());
	Query.SetParameter("CurrentDate", CurrentSessionDate());
	
	EmailsToDefineFolders = New Array;
	AccountsSelection = Query.Execute().Select(QueryResultIteration.ByGroups);
	
	Result.SentEmails = 0;
	
	SetPrivilegedMode(True);
	While AccountsSelection.Next() Do
		
		Connection = ConnectToEmailServer(AccountsSelection.Account, True);
		If Not Connection.Success Then
			Continue;
		EndIf;	
		
		EmailSelection = AccountsSelection.Select();
		While EmailSelection.Next() Do
			
			If Not SendEmail(EmailSelection, Connection, True) Then
				Result.HasErrors = True;
				Result.SentEmails = Result.SentEmails + 1;
				Continue;
			EndIf;
			
			If Not EmailSelection.DeleteAfterSend Then
				If EmailSelection.FolderDefinitionRequired Then
					EmailsToDefineFolders.Add(EmailSelection.Ref);
				EndIf;
			EndIf;
			
		EndDo;
		
		Connection.Connection.Logoff();
		
	EndDo;
	
	Interactions.SetFoldersForEmailsArray(EmailsToDefineFolders);
	SendNotoficationsOnReading(True);
	
EndProcedure

Procedure SendReceiveUserEmail(ExportParameters, StorageAddress) Export
	
	Result = New Structure;
	Result.Insert("SentEmails",        0);
	Result.Insert("EmailsReceived",          0);
	Result.Insert("UserAccountsAvailable", 0);
	Result.Insert("HasErrors",             False);
	
	SendUserEmail(Result);
	LoadUserEmail(Result);
	
	PutToTempStorage(Result, StorageAddress);
	
EndProcedure

Function WrongRecipientsAnalysisResult(EmailObject, WrongRecipients) Export

	Result = New Structure;
	Result.Insert("IsIssueOfEmailAddressesServerRejection",False);
	Result.Insert("AllEmailAddresseesRejectedByServer",False);
	Result.Insert("WrongAddresseesPresentation","");
	
	WrongRecipientsCount = WrongRecipients.Count();
	
	If WrongRecipientsCount > 0 Then
		
		Result.IsIssueOfEmailAddressesServerRejection = True;
		
		EmailRecipientsArray = New Array;
		For Each RecipientString In EmailObject.EmailRecipients Do
			If EmailRecipientsArray.Find(RecipientString.Address) = Undefined Then
				EmailRecipientsArray.Add(RecipientString.Address);
			EndIf;
		EndDo;
		For Each RecipientString In EmailObject.CCRecipients Do
			If EmailRecipientsArray.Find(RecipientString.Address) = Undefined Then
				EmailRecipientsArray.Add(RecipientString.Address);
			EndIf;
		EndDo;
		For Each RecipientString In EmailObject.BccRecipients Do
			If EmailRecipientsArray.Find(RecipientString.Address) = Undefined Then
				EmailRecipientsArray.Add(RecipientString.Address);
			EndIf;
		EndDo;
		
		EmailRecipientsCount = EmailRecipientsArray.Count();
		
		If EmailRecipientsCount = WrongRecipientsCount Then
			Result.AllEmailAddresseesRejectedByServer = True;
		EndIf;
		
		WrongAddresseesPresentation = "";
		For Each WrongAddressee In WrongRecipients Do
			If Not IsBlankString(WrongAddresseesPresentation) Then
				WrongAddresseesPresentation = WrongAddresseesPresentation + ", ";
			EndIf;
			WrongAddresseesPresentation = WrongAddresseesPresentation + WrongAddressee.Key;
		EndDo;
		
		Result.WrongAddresseesPresentation = WrongAddresseesPresentation;
		
	EndIf;
	
	Return Result;
	
EndFunction

// Fills InternetMailAddresses in the InternetMailMessage object by the passed address table.
//
// Parameters:
//  TabularSection  - InternetMailAddresses - addresses that will be filled in the email.
//  Addresses          - ValueTable - a table that contains addresses to specify in the email.
//
Procedure FillInternetEmailAddresses(TabularSection, Addresses) Export
	
	For Each Address In Addresses Do
		NewRow = TabularSection.Add();
		NewRow.Address         = CommonClientServer.ReplaceProhibitedXMLChars(Address.Address, "");
		NewRow.Presentation = CommonClientServer.ReplaceProhibitedXMLChars(Address.DisplayName, "");
	EndDo;
	
EndProcedure

Procedure GetEmails(Val AccountData, HasErrors, ReceivedEmails, EmailsReceived)
	
	// Checking an account lock and setting it if it is available.
	Query = New Query;
	Query.Text = "
	|SELECT
	|	AccountsLockedForReceipt.LockDate
	|FROM
	|	InformationRegister.AccountsLockedForReceipt AS AccountsLockedForReceipt
	|WHERE
	|	AccountsLockedForReceipt.Account = &Account";
	
	Query.SetParameter("Account", AccountData.Ref);
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		If Selection.LockDate + 60 * 60 > CurrentSessionDate() Then
			Return;
		EndIf;
	EndIf;
	
	BeginTransaction();
	Try
		
		Lock = New DataLock;
		LockItem = Lock.Add("InformationRegister.AccountsLockedForReceipt");
		LockItem.SetValue("Account", AccountData.Ref);
		Lock.Lock();
		
		RecordManager = InformationRegisters.AccountsLockedForReceipt.CreateRecordManager();
		RecordManager.Account  = AccountData.Ref;
		RecordManager.LockDate = CurrentSessionDate();
		RecordManager.Write();
		
		CommitTransaction();
		
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	// -----------------------------------------------------------------
	// Generating an email account and connecting to the mail server.
	Profile = EmailOperationsInternal.InternetMailProfile(AccountData.Ref, True);
	
	Protocol = InternetMailProtocol.POP3;
	If AccountData.ProtocolForIncomingMail = "IMAP" Then
		Protocol = InternetMailProtocol.IMAP;
	EndIf;
	
	Mail = New InternetMail;
	Try
		Mail.Logon(Profile, Protocol);
	Except
		
		UnlockAccountForReceiving(AccountData.Ref);
		
		HasErrors = True;
		
		ErrorMessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Во время подключения к учетной записи %1 произошла ошибка
				|%2'; 
				|en = 'An error occurred when connecting to account %1
				|%2'; 
				|pl = 'Wystąpił błąd podczas połączenia z kontem %1
				|%2';
				|es_ES = 'Ha ocurrido un error al conectarse a la cuenta %1
				|%2';
				|es_CO = 'Ha ocurrido un error al conectarse a la cuenta %1
				|%2';
				|tr = 'Hesaba bağlanırken hata oluştu %1
				|%2';
				|it = 'Si è verificato un errore durante la connessione all''account %1
				|%2';
				|de = 'Beim Verbinden des Kontos %1
				|%2 ist ein Fehler aufgetreten'", CommonClientServer.DefaultLanguageCode()),
				AccountData.Ref,
				DetailErrorDescription(ErrorInfo()));
			
			WriteLogEvent(EventLogEvent(),
			                         EventLogLevel.Error, , ,
			                         ErrorMessageText);
		
		Return;
		
	EndTry;
	
	If Protocol = InternetMailProtocol.POP3 Then
		GetEmailByPOP3Protocol(AccountData, Mail, ReceivedEmails, EmailsReceived);
	Else
		GetEmailByIMAPProtocol(AccountData, Mail, ReceivedEmails, EmailsReceived);
		SynchronizeReviewedFlagWithServer(Mail, AccountData, EmailsReceived.AllRecievedEmails);
	EndIf;
	
	Mail.Logoff();
	
	UnlockAccountForReceiving(AccountData.Ref);

EndProcedure

Procedure GetEmailsByIDsArray(Mail,
	                                            AccountData,
	                                            IDImport, 
	                                            ReceivedEmails,
	                                            CreatedEmailsArraysStructure,
	                                            AllIDs = Undefined)
	
	ReceivedEmails = 0;
	
	If IDImport.Count() <> 0 Then
		
		EmployeeResponsibleForProcessingEmails = AccountData.EmployeeResponsibleForProcessingEmails;
		ErrorsCountOnWrite = 0;
		ObsoleteMessagesCount = 0;
		
		While IDImport.Count() > (ReceivedEmails + ErrorsCountOnWrite + ObsoleteMessagesCount) Do
			
			CountInBatch = 0;
			BatchIDsArrayForImport = New Array;
			
			For Ind = (ReceivedEmails + ErrorsCountOnWrite) To IDImport.Count() - 1 Do
				
				BatchIDsArrayForImport.Add(IDImport.Get(Ind));
				CountInBatch = CountInBatch + 1;
				
				If CountInBatch = 10 Then
					Break;
				EndIf;
				
			EndDo;
			
			// Getting the required messages
			Messages = Mail.Get(False, 
			                          BatchIDsArrayForImport,
			                          ?(AccountData.ProtocolForIncomingMail = "IMAP",False, True));
			
			ObsoleteMessagesCount = ObsoleteMessagesCount + (CountInBatch - Messages.Count());
			
			// Writing them
			For Each Message In Messages Do
				
				AddToEmailsArrayToGetFolder = False;
				
				BeginTransaction();
				
				Try
					
					IsOutgoingEmail =  EmailAddressesEqual(AccountData.EmailAddress,
					                                          InternetEmailMessageSenderAddress(Message.From));
					
					CreatedEmail = WriteEmail(AccountData,
					                                           Message,
					                                           EmployeeResponsibleForProcessingEmails,
					                                           AccountData.PutEmailInBaseEmailFolder,
					                                           AddToEmailsArrayToGetFolder,
					                                           IsOutgoingEmail);
					
					ReceivedEmails = ReceivedEmails + 1;
					
					CommitTransaction();
					
				Except
					
					RollbackTransaction();
					ErrorMessageText = StringFunctionsClientServer.SubstituteParametersToString(
					                      NStr("ru = 'Ошибка при получении сообщения.
					                      |Тема: %1
					                      |Дата отправки: %2
					                      |Отправитель: %3
					                      |Подробнее: %4'; 
					                      |en = 'Error receiving email message.
										  |Subject: %1
										  |Date sent: %2
										  |Sender: %3
										  |Details: %4'; 
					                      |pl = 'Błąd przy odbiorze wiadomości e-mail.
					                      |Temat: %1
					                      |Data wysyłki: %2
					                      |Nadawca: %3
					                      |Szczegóły: %4';
					                      |es_ES = 'Error al recibir el mensaje de correo electrónico.
					                      |Tema: %1
					                      |Fecha de envío: %2
					                      |Remitente: %3
					                      |Detalles: %4';
					                      |es_CO = 'Error al recibir el mensaje de correo electrónico.
					                      |Tema: %1
					                      |Fecha de envío: %2
					                      |Remitente: %3
					                      |Detalles: %4';
					                      |tr = 'E-posta alınırken hata oluştu.
					                      |Konu: %1
					                      |Gönderim tarihi: %2
					                      |Gönderen: %3
					                      |Ayrıntılar: %4';
					                      |it = 'Errore di ricezione del messaggio email. 
					                      |Soggetto: %1
					                      |Data di invio: %2
					                      |Mittente: %3
					                      |Dettagli: %4';
					                      |de = 'Fehler beim Empfang einer E-Mail-Nachricht.
					                      |Betreff: %1
					                      |Gesendet am: %2
					                      |Absender: %3
					                      |Details: %4'", CommonClientServer.DefaultLanguageCode()),
					                      Message.Subject,
					                      Message.PostingDate,
					                      Message.From.Address,
					                      DetailErrorDescription(ErrorInfo()));
					
					WriteLogEvent(EventLogEvent(),
					                         EventLogLevel.Error, , ,
					                         ErrorMessageText);
					
					ErrorsCountOnWrite = ErrorsCountOnWrite + 1;
					
					If AllIDs <> Undefined Then
						For Each MessageID In Message.UID Do
							IDArrayInIndex = AllIDs.Find(MessageID);
							If IDArrayInIndex <> Undefined Then
								AllIDs.Delete(IDArrayInIndex);
							EndIf;
							Continue;
						EndDo;
					EndIf;
					
				EndTry;
				
				CreatedEmailsArraysStructure.AllRecievedEmails.Add(CreatedEmail);
				If AddToEmailsArrayToGetFolder Then
					CreatedEmailsArraysStructure.EmailsToDefineFolders.Add(CreatedEmail);
				EndIf;
				
			EndDo;
		
		EndDo;
		
	EndIf;
	
EndProcedure

Procedure GetEmailByIMAPProtocol(AccountData, Mail, ReceivedEmails, EmailsReceived)
	
	ArrayOfActiveFoldersNames = ArrayOfActiveFoldersNames(Mail);
	
	String255Qualifier =  New TypeDescription("String",,,,New StringQualifiers(255,AllowedLength.Variable));
	
	IDsTable = New ValueTable;
	IDsTable.Columns.Add("IDAtServer", String255Qualifier);
	IDsTable.Columns.Add("EmailID", String255Qualifier);
	
	BlankIDsTable  = New ValueTable;
	BlankIDsTable.Columns.Add("IDAtServer", String255Qualifier);
	BlankIDsTable.Columns.Add("HashSum", Common.StringTypeDetails(32));
	
	EmailsImportDate = CurrentSessionDate();
	
	For each ActiveFolderName In ArrayOfActiveFoldersNames Do
			
		Try
			Mail.CurrentMailbox = ActiveFolderName;
		Except
			Continue;
		EndTry;
		
		FilterParameters = New Structure;
		
		If Not AccountData.EmailsImportDate = Date(1,1,1) Then 
			FilterParameters.Insert("AfterSendingDate",AccountData.EmailsImportDate);
		Else
			FilterParameters.Insert("DeletedItems", False);
		EndIf;
		
		Try
			EmailsHeadersForImport = Mail.GetHeaders(FilterParameters);
		Except
			Continue;
		EndTry;
		
		ArrayOfTitlesWithBlankID = New Array;
		IDsTable.Clear();
		For Each EmailHeader In EmailsHeadersForImport Do
			
			If IsBlankString(EmailHeader.MessageID) Then
				ArrayOfTitlesWithBlankID.Add(EmailHeader);
				Continue;
			EndIf;
			
			NewIDsTableRow = IDsTable.Add();
			NewIDsTableRow.IDAtServer = ?(EmailHeader.ID.Count() = 0, "", EmailHeader.ID[0]);
			NewIDsTableRow.EmailID    = EmailHeader.MessageID;
			
		EndDo;
		
		ReceivedEmailsInCurrentMailBox = 0;
		
		If IDsTable.Count() > 0 Then
		
			Query = New Query;
			Query.Text = "
			|SELECT
			|	MessagesToImportIDs.EmailID,
			|	MessagesToImportIDs.IDAtServer
			|INTO MessagesToImportIDs
			|FROM
			|	&MessagesToImportIDs AS MessagesToImportIDs
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT
			|	MessagesToImportIDs.EmailID,
			|	MessagesToImportIDs.IDAtServer
			|FROM
			|	MessagesToImportIDs AS MessagesToImportIDs
			|		LEFT JOIN Document.IncomingEmail AS IncomingEmail
			|		ON MessagesToImportIDs.EmailID = IncomingEmail.MessageID
			|			AND (IncomingEmail.Account = &Account)
			|		LEFT JOIN Document.OutgoingEmail AS OutgoingEmail
			|		ON (OutgoingEmail.Account = &Account)
			|			AND (MessagesToImportIDs.EmailID = OutgoingEmail.MessageID
			|				OR MessagesToImportIDs.EmailID = OutgoingEmail.MessageIDIMAPSending)
			|WHERE
			|	IncomingEmail.Ref IS NULL
			|	AND OutgoingEmail.Ref IS NULL";
			
			Query.SetParameter("MessagesToImportIDs", IDsTable);
			Query.SetParameter("Account", AccountData.Ref);
			
			IDImport = Query.Execute().Unload().UnloadColumn("IDAtServer");
			
			GetEmailsByIDsArray(Mail, 
			                                       AccountData,
			                                       IDImport, 
			                                       ReceivedEmailsInCurrentMailBox, 
			                                       EmailsReceived);
		
		EndIf;
		
		If ArrayOfTitlesWithBlankID.Count() > 0 Then
			
			BlankIDsTable.Clear();
			
			For Each EmailHeader In ArrayOfTitlesWithBlankID Do
				NewString = BlankIDsTable.Add();
				NewString.IDAtServer = EmailHeader.ID[0];
				NewString.HashSum               = EmailHashsum(EmailHeader);
			EndDo;
			
			Query = New Query;
			Query.Text = "
			|SELECT
			|	MessagesToImportIDs.HashSum,
			|	MessagesToImportIDs.IDAtServer
			|INTO MessagesToImportIDs
			|FROM
			|	&MessagesToImportIDs AS MessagesToImportIDs
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT
			|	MessagesToImportIDs.HashSum,
			|	MessagesToImportIDs.IDAtServer
			|FROM
			|	MessagesToImportIDs AS MessagesToImportIDs
			|		LEFT JOIN Document.IncomingEmail AS IncomingEmail
			|		ON MessagesToImportIDs.HashSum = IncomingEmail.HashSum
			|			AND (IncomingEmail.Account = &Account)
			|		LEFT JOIN Document.OutgoingEmail AS OutgoingEmail
			|		ON (OutgoingEmail.Account = &Account)
			|			AND (MessagesToImportIDs.HashSum = OutgoingEmail.HashSum)
			|WHERE
			|	IncomingEmail.Ref IS NULL
			|	AND OutgoingEmail.Ref IS NULL";
			
			Query.SetParameter("MessagesToImportIDs", BlankIDsTable);
			Query.SetParameter("Account", AccountData.Ref);
			
			IDImport = Query.Execute().Unload().UnloadColumn("IDAtServer");
			
			GetEmailsByIDsArray(Mail, 
			                                       AccountData,
			                                       IDImport, 
			                                       ReceivedEmailsInCurrentMailBox,
			                                       EmailsReceived);
			
		EndIf;
		
		ReceivedEmails = ReceivedEmails + ReceivedEmailsInCurrentMailBox; 
	
	EndDo;
	
	SetLastEmailsImportDate(AccountData.Ref, EmailsImportDate);
	
EndProcedure

Procedure GetEmailByPOP3Protocol(AccountData, Mail, ReceivedEmails, EmailsReceived)

	// Getting message IDs on the server.
	IDs = Mail.GetUIDL();
	If IDs.Count() = 0 AND (Not AccountData.KeepCopies) Then
		// If there are no messages on the server, deleting all records by account in the information register.
		// ReceivedEmailsIDs.
		DeleteIDsOfAllPreviouslyReceivedEmails(AccountData.Ref);
		Return;
	EndIf;

	// -----------------------------------------------------------------
	// Defining which messages to get.
	IDImport = GetEmailsIDsForImport(IDs, AccountData.Ref);
	
	RecievedByThisAccount = 0;
	GetEmailsByIDsArray(Mail,
	                                       AccountData,
	                                       IDImport, 
	                                       RecievedByThisAccount, 
	                                       EmailsReceived, 
	                                       IDs);
	
	ReceivedEmails = ReceivedEmails + RecievedByThisAccount;
	
	// -----------------------------------------------------------------
	// Deleting unnecessary messages on the server.
	If Not AccountData.KeepCopies Then
		// delete all
		ArrayToDelete = IDs;
		RemoveAll = True;
	Else
		RemoveAll = False;
		If AccountData.KeepDays > 0 Then
			ArrayToDelete = GetEmailsIDsToDeleteAtServer(
			IDs, 
			AccountData.Ref, 
			CurrentSessionDate() - AccountData.KeepDays * 24 * 60 * 60);
		Else
			ArrayToDelete = New Array;
		EndIf;
	EndIf;
	
	If ArrayToDelete.Count() <> 0 Then
		Mail.DeleteMessages(ArrayToDelete);
	EndIf;
	
	// -----------------------------------------------------------------
	// Deleting unnecessary IDs in the information register.
	If RemoveAll Then
		DeleteIDsOfAllPreviouslyReceivedEmails(AccountData.Ref);
	Else
		DeleteIDsOfPreviouslyReceivedEmails(AccountData.Ref, IDs, ArrayToDelete);
	EndIf;

EndProcedure

Function EmailAddressesEqual(FirstAddress, SecondAddress)

	ProcessedFirstAddress = Lower(TrimAll(FirstAddress));
	ProcessedSecondAddress = Lower(TrimAll(SecondAddress));
	
	ChangeDomainInEmailAddressIfRequired(ProcessedFirstAddress);
	ChangeDomainInEmailAddressIfRequired(ProcessedSecondAddress);
	
	Return (ProcessedFirstAddress = ProcessedSecondAddress);
	
EndFunction

Function MapOfReplaceableEmailDomains()

	DomainsMap = New Map;
	DomainsMap.Insert("yandex.ru","ya.ru");
	
	Return DomainsMap;

EndFunction

Function EmailAddressStructure(EmailAddress)
	
	AddressArray = StringFunctionsClientServer.SplitStringIntoSubstringsArray(EmailAddress,"@");
	
	If AddressArray.Count() = 2 Then
		
		AddressStructure = New Structure;
		AddressStructure.Insert("MailboxName", AddressArray[0]);
		AddressStructure.Insert("Domain"            , AddressArray[1]);
		
		Return AddressStructure;
	Else
		Return Undefined;
	EndIf;
	
EndFunction

Function EmailsReceived()
	
	Result = New Structure;
	Result.Insert("AllRecievedEmails", New Array);
	Result.Insert("EmailsToDefineFolders", New Array);
	Return Result;
	
EndFunction

Procedure SetLastEmailsImportDate(Account, ImportDate)

	RecordManager = InformationRegisters.LastEmailImportDate.CreateRecordManager();
	RecordManager.Account     = Account;
	RecordManager.EmailsImportDate = ImportDate;
	RecordManager.Write();

EndProcedure

Procedure SynchronizeReviewedFlagWithServer(Mail, AccountData, ImportedEmailsArray)

	If NOT AccountData.MailHandledInOtherMailClient Then
		Return;
	EndIf;
	
	ArrayOfActiveFoldersNames = ArrayOfActiveFoldersNames(Mail);
	
	UnreadEmailsArray = New Array;
	
	For each ActiveFolderName In ArrayOfActiveFoldersNames Do
			
		Try
			Mail.CurrentMailbox = ActiveFolderName;
		Except
			Continue;
		EndTry;
		
		FilterParameters = New Structure;
		FilterParameters.Insert("Read", False);
		
		Try
			ReadEmailsHeaders = Mail.GetHeaders(FilterParameters);
		Except
			Continue;
		EndTry;
		
		
		For Each EmailHeader In ReadEmailsHeaders Do
			
			UnreadEmailsArray.Add(EmailHeader.MessageID);
			
		EndDo;
			
	EndDo;
	
	IDsTable = New ValueTable;
	IDsTable.Columns.Add("ID", 
	                                        New TypeDescription("String",,,,New StringQualifiers(150,AllowedLength.Variable)));
	
	CommonClientServer.SupplementTableFromArray(IDsTable,
	                                                       UnreadEmailsArray,
	                                                       "ID");
	
	Query = New Query;
	Query.Text = "
	|SELECT
	|	ReadMessageIDs.ID
	|INTO ReadMessageIDs
	|FROM
	|	&ReadMessageIDs AS ReadMessageIDs
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Interactions.Ref AS Ref,
	|	FALSE AS Reviewed
	|FROM
	|	ReadMessageIDs AS ReadMessageIDs
	|		LEFT JOIN DocumentJournal.Interactions AS Interactions
	|		ON ReadMessageIDs.ID = Interactions.MessageID
	|		LEFT JOIN InformationRegister.InteractionsFolderSubjects AS InteractionsFolderSubjects
	|		ON (Interactions.Ref = InteractionsFolderSubjects.Interaction)
	|WHERE
	|	Interactions.Account = &Account
	|	AND ISNULL(InteractionsFolderSubjects.Reviewed, FALSE) = TRUE
	|
	|UNION ALL
	|
	|SELECT
	|	Interactions.Ref,
	|	TRUE
	|FROM
	|	DocumentJournal.Interactions AS Interactions
	|		LEFT JOIN InformationRegister.InteractionsFolderSubjects AS InteractionsFolderSubjects
	|		ON Interactions.Ref = InteractionsFolderSubjects.Interaction
	|		LEFT JOIN ReadMessageIDs AS ReadMessageIDs
	|		ON ReadMessageIDs.ID = Interactions.MessageID
	|WHERE
	|	ISNULL(InteractionsFolderSubjects.Reviewed, FALSE) = FALSE
	|	AND Interactions.Account = &Account
	|	AND ReadMessageIDs.ID IS NULL";
	
	Query.SetParameter("ReadMessageIDs", IDsTable);
	Query.SetParameter("Account", AccountData.Ref);
	
	Result = Query.Execute();
	If Result.IsEmpty() Then
		Return;
	EndIf;
	
	EmailsArrayReviewed   = New Array;
	EmailsArrayNotReviewed = New Array;
	
	Selection = Result.Select();
	
	BeginTransaction();
	Try
		
		LockAreasTable = New ValueTable;
		LockAreasTable.Columns.Add("Interaction");
		
		While Selection.Next() Do
			If Selection.Reviewed Then
				EmailsArrayReviewed.Add(Selection.Ref);
			Else
				EmailsArrayNotReviewed.Add(Selection.Ref);
			EndIf;
			NewRow = LockAreasTable.Add();
			NewRow.Interaction = Selection.Ref;
		EndDo;
		
		Lock = New DataLock;
		
		LockItem = Lock.Add("InformationRegister.InteractionsFolderSubjects");
		LockItem.DataSource = LockAreasTable;
		Lock.Lock();
	
		HasChanges = False;
		
		Interactions.MarkAsReviewed(EmailsArrayReviewed, True, HasChanges);
		Interactions.MarkAsReviewed(EmailsArrayNotReviewed, False, HasChanges);
		
		CommonClientServer.SupplementArray(ImportedEmailsArray, EmailsArrayReviewed, False);
		CommonClientServer.SupplementArray(ImportedEmailsArray, EmailsArrayNotReviewed, False);
		
		CommitTransaction();
	
	Except
		
		RollbackTransaction();
		MessageText = NStr("ru = 'Не удалось изменить информацию о признаке рассмотрено для писем по причине : %Reason%.'; en = 'Could not change information about the emails consideration parameter for the following reason:  %Reason%.'; pl = 'Nie można zmienić informacji o parametrze uwarunkowania wiadomości e-mail z następującego powodu:  %Reason%.';es_ES = 'No se ha podido cambiar la información sobre el parámetro de consideración de los correos electrónicos por la siguiente causa: %Reason%.';es_CO = 'No se ha podido cambiar la información sobre el parámetro de consideración de los correos electrónicos por la siguiente causa: %Reason%.';tr = 'E-posta değerlendirme parametresi hakkındaki bilgi şu nedenle değiştirilemedi: %Reason%.';it = 'Impossibile modificare le informazioni del parametro di considerazione delle email a causa di: %Reason%.';de = 'Kann die Informationen über die E-Mail-Betrachtungsparameter wegen das Folgende nicht ändern:  %Reason%.'");
		MessageText = StrReplace(MessageText, "%Reason%", DetailErrorDescription(ErrorInfo()));
		WriteLogEvent(EventLogEvent(),
			EventLogLevel.Error,
			Metadata.InformationRegisters.InteractionsFolderSubjects,
			,
			MessageText);
		
	EndTry;
	
EndProcedure

Procedure DeleteIDsOfAllPreviouslyReceivedEmails(Account)
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	ReceivedEmailIDs.ID
	|FROM
	|	InformationRegister.ReceivedEmailIDs AS ReceivedEmailIDs
	|WHERE
	|	ReceivedEmailIDs.Account = &Account";
	Query.SetParameter("Account", Account);
	
	If NOT Query.Execute().IsEmpty() Then
		Set = InformationRegisters.ReceivedEmailIDs.CreateRecordSet();
		Set.Filter.Account.Set(Account);
		Set.Write();
	EndIf;
	
EndProcedure

Procedure DeleteIDsOfPreviouslyReceivedEmails(Account, IDsAtServer, IDsDelete)
	
	// Getting a list of IDs that do not need to be deleted.
	IDsToDelete = New Map;
	For Each Item In IDsDelete Do
		IDsToDelete.Insert(Item, True);
	EndDo;
	
	IDsKeep = New Array;
	For Each Item In IDsAtServer Do
		If IDsToDelete.Get(Item) = Undefined Then
			IDsKeep.Add(Item);
		EndIf;
	EndDo;
	
	// Getting IDs that are located in the register but have to be deleted.
	IDsTable = CreateTableWithIDs(IDsKeep);

	Query = New Query;
	Query.SetParameter("IDsTable", IDsTable);
	Query.SetParameter("Account", Account);
	Query.Text =
	"SELECT
	|	IDsTable.ID
	|INTO IDsTable
	|FROM
	|	&IDsTable AS IDsTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	&Account                                         AS Account,
	|	ReceivedEmailIDs.ID AS ID
	|FROM
	|	InformationRegister.ReceivedEmailIDs AS ReceivedEmailIDs
	|		LEFT JOIN IDsTable AS IDsTable
	|		ON IDsTable.ID = ReceivedEmailIDs.ID
	|WHERE
	|	IDsTable.ID IS NULL
	|	 AND ReceivedEmailIDs.Account = &Account";
	
	UUIDsTable = Query.Execute().Unload();
	
	BeginTransaction();
	Try
		
		Lock = New DataLock;
		LockItem = Lock.Add("InformationRegister.ReceivedEmailIDs");
		LockItem.DataSource = UUIDsTable;
		Lock.Lock();
		
		// Deleting all unnecessary IDs.
		For Each TableRow In UUIDsTable Do
			Set = InformationRegisters.ReceivedEmailIDs.CreateRecordSet();
			Set.Filter.Account.Set(TableRow.Account);
			Set.Filter.ID.Set(TableRow.ID);
			Set.Write();
		EndDo;
		
		CommitTransaction();
	
	Except
		
		RollbackTransaction();
		MessageText = NStr("ru = 'Не удалось очистить информацию о ранее полученных идентификаторах по причине: %Reason%.'; en = 'Could not clear information about the IDs received earlier for the following reason: %Reason%.'; pl = 'Nie można wyczyścić informacji o odebranych identyfikatorach wcześniej z następującego powodu: %Reason%.';es_ES = 'No se ha podido borrar la información sobre los identificadores recibidos anteriormente por la siguiente causa: %Reason%.';es_CO = 'No se ha podido borrar la información sobre los identificadores recibidos anteriormente por la siguiente causa: %Reason%.';tr = 'Daha önce alınan kodlarla ilgili bilgiler şu nedenle temizlenemedi: %Reason%.';it = 'Impossibile cancellare le informazioni su le ID ricevute precedentemente a causa di: %Reason%.';de = 'Kann die Informationen über die bisher empfangenen IDs wegen das Folgende nicht löschen: %Reason%.'");
		MessageText = StrReplace(MessageText, "%Reason%", DetailErrorDescription(ErrorInfo()));
		WriteLogEvent(EventLogEvent(),
			EventLogLevel.Error,
			Metadata.InformationRegisters.ReceivedEmailIDs,
			TableRow.Account,
			MessageText);
	
	EndTry;
	
EndProcedure

Function CreateTableWithIDs(IDs)
	
	IDsTable = New ValueTable;
	IDsTable.Columns.Add("ID", New TypeDescription("String",,, New StringQualifiers(100)));
	For Each ID In IDs Do
		NewRow = IDsTable.Add();
		NewRow.ID = ID;
	EndDo;
	
	Return IDsTable;
	
EndFunction

Function GetEmailsIDsForImport(IDs, Account)

	// Getting the list of messages that have not been received earlier.
	IDsTable = CreateTableWithIDs(IDs);

	Query = New Query;
	Query.SetParameter("IDsTable", IDsTable);
	Query.SetParameter("Account",          Account);
	Query.Text =
	"SELECT
	|	IDsTable.ID
	|INTO IDsTable
	|FROM
	|	&IDsTable AS IDsTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	IDsTable.ID
	|FROM
	|	IDsTable AS IDsTable
	|		LEFT JOIN InformationRegister.ReceivedEmailIDs AS ReceivedEmailIDs
	|		ON IDsTable.ID = ReceivedEmailIDs.ID
	|			AND (ReceivedEmailIDs.Account = &Account)
	|WHERE
	|	ReceivedEmailIDs.Account IS NULL ";

	Return Query.Execute().Unload().UnloadColumn("ID");

EndFunction

Function GetEmailsIDsToDeleteAtServer(IDs, Account, DateToWhichToDelete)

	IDsTable = CreateTableWithIDs(IDs);

	Query = New Query;
	Query.SetParameter("IDsTable", IDsTable);
	Query.SetParameter("Account", Account);
	Query.SetParameter("DateReceived", DateToWhichToDelete);
	Query.Text =
	"SELECT
	|	IDsTable.ID
	|INTO IDsTable
	|FROM
	|	&IDsTable AS IDsTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	IDsTable.ID
	|FROM
	|	IDsTable AS IDsTable
	|		INNER JOIN InformationRegister.ReceivedEmailIDs AS ReceivedEmailIDs
	|		ON IDsTable.ID = ReceivedEmailIDs.ID
	|			AND (ReceivedEmailIDs.Account = &Account)
	|WHERE
	|	ReceivedEmailIDs.DateReceived <= &DateReceived";

	Return Query.Execute().Unload().UnloadColumn("ID");

EndFunction

Function WriteEmail(AccountData,
                                  Message,
                                  EmployeeResponsibleForProcessingEmails,
                                  PutEmailInBaseEmailFolder,
                                  AddToEmailsArrayToGetFolder,
                                  IsOutgoingEmail);
	
	// Creating a document and filling its attributes on the message basis.
	If IsOutgoingEmail Then
		Email = Documents.OutgoingEmail.CreateDocument();
	Else
		Email = Documents.IncomingEmail.CreateDocument();
	EndIf;
	
	
	FillEmailDocument(Email, Message, IsOutgoingEmail);
	Email.Account = AccountData.Ref;
	
	// Searching for an email base, determining a subject and contacts.
	Topic = Undefined;
	Folder   = Undefined;
	
	FillSubjectAndContacts(Email,
		AccountData.Ref,
		Topic,
		Folder,
		IsOutgoingEmail,
		PutEmailInBaseEmailFolder);
	
	// Filling in a person responsible.
	Email.EmployeeResponsible = EmployeeResponsibleForProcessingEmails;
	
	// Writing an email.
	Email.Write();
	
	// Setting email folder and subject.
	If AccountData.MailHandledInOtherMailClient Then 
		ReviewedFlag = True;
	Else
		ReviewedFlag = ?(IsOutgoingEmail, True, False);
	EndIf;
	
	StructureForWrite = InformationRegisters.InteractionsFolderSubjects.InteractionAttributes();
	StructureForWrite.Folder                   = Folder;
	StructureForWrite.Topic                 = ?(ValueIsFilled(Topic), Topic, Email.Ref);
	StructureForWrite.Reviewed             = ReviewedFlag;
	StructureForWrite.CalculateReviewedItems = False;
	InformationRegisters.InteractionsFolderSubjects.WriteInteractionFolderSubjects(Email.Ref, StructureForWrite);
	
	AttachmentsNamesArray              = New Array;
	DuplicateAttachmentsNamesArray = New Array;
	
	// Saving attachments
	For Each Attachment In Message.Attachments Do
		If AttachmentsNamesArray.Find(Attachment.FileName) = Undefined Then 
			AttachmentsNamesArray.Add(Attachment.FileName);
		ElsIf DuplicateAttachmentsNamesArray.Find(Attachment.FileName) = Undefined Then
			DuplicateAttachmentsNamesArray.Add(Attachment.FileName);
		EndIf;
	EndDo;
	
	For Each DuplicateAttachment In DuplicateAttachmentsNamesArray Do
		IndexInArray = AttachmentsNamesArray.Find(DuplicateAttachment);
		If IndexInArray <> Undefined Then
			AttachmentsNamesArray.Delete(IndexInArray);
		EndIf;
	EndDo;
	
	If Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		ModuleDigitalSignatureInternal = Common.CommonModule("DigitalSignatureInternal");
		
		AttachmentsAndSignaturesMap =
			ModuleDigitalSignatureInternal.SignaturesFilesNamesOfDataFilesNames(AttachmentsNamesArray);
	Else
		AttachmentsAndSignaturesMap = New Map;
		For Each AttachmentFileName In AttachmentsNamesArray Do
			AttachmentsAndSignaturesMap.Insert(AttachmentFileName, New Array);
		EndDo;
	EndIf;
	
	CountOfBlankNamesInAttachments = 0;
	For each MapItem In AttachmentsAndSignaturesMap Do
		
		AttachmentFound = Undefined;
		SignaturesArray    = New Array;
		
		For each Attachment In Message.Attachments Do
			If Attachment.FileName = MapItem.Key Then
				AttachmentFound = Attachment;
				Break;
			EndIf
		EndDo;
		
		If AttachmentFound <> Undefined AND MapItem.Value.Count() > 0 Then
			For each Attachment In Message.Attachments Do
				If MapItem.Value.Find(Attachment.FileName) <> Undefined Then
					SignaturesArray.Add(Attachment);
				EndIf;
			EndDo;
		EndIf;
		
		If AttachmentFound <> Undefined Then
			WriteEmailAttachment(
				Email,AttachmentFound,
				SignaturesArray,
				CountOfBlankNamesInAttachments);
		EndIf;
		
	EndDo;
	
	If DuplicateAttachmentsNamesArray.Count() > 0 Then
		For each Attachment In Message.Attachments Do
			If DuplicateAttachmentsNamesArray.Find(Attachment.FileName) <> Undefined Then
				WriteEmailAttachment(
					Email,Attachment,
					New Array,
					CountOfBlankNamesInAttachments);
			EndIf;
		EndDo;
	EndIf;
	
	// Writing an ID
	If Not AccountData.ProtocolForIncomingMail = "IMAP" Then
		
		WriteReceivedEmailID(AccountData.Ref,
			Email.IDAtServer,
			Message.DateReceived);
		
	EndIf;
	
	If Not IsOutgoingEmail AND Email.RequestReadReceipt Then
		
		WriteReadReceiptProcessingRequest(Email.Ref);
		
	EndIf;
	
	If (NOT PutEmailInBaseEmailFolder) OR (NOT ValueIsFilled(Folder)) Then
		AddToEmailsArrayToGetFolder = True;
	EndIf;
	
	Return Email.Ref;
	
EndFunction

Procedure FillEmailDocument(Email, Message, IsOutgoingEmail)
	
	SenderAddress = InternetEmailMessageSenderAddress(Message.From);
	
	If Not IsOutgoingEmail Then
		
		Email.DateReceived    = Message.DateReceived;
		Email.SenderAddress = SenderAddress; 
		
	Else
		
		Email.EmailStatus = Enums.OutgoingEmailStatuses.Sent;
		Email.PostingDate = Message.PostingDate;
		
	EndIf;
	
	SenderName = CommonClientServer.ReplaceProhibitedXMLChars(Message.SenderName, "");
	Email.SenderPresentation = ?(IsBlankString(Message.SenderName),
	                                    SenderAddress,
	                                    SenderName + " <"+ SenderAddress +">");
	
	Email.Importance = GetEmailImportance(Message.Importance);
	Email.Date = ?(Message.PostingDate = Date(1,1,1), CurrentSessionDate(), Message.PostingDate);
	Email.InternalTitle = Message.Header;
	Email.IDAtServer = ?(Message.UID.Count() = 0, "", Message.UID[0]);
	Email.MessageID = Message.MessageID;
	Email.Encoding = Message.Encoding;
	Email.RequestDeliveryReceipt = Message.RequestDeliveryReceipt;
	Email.RequestReadReceipt = Message.RequestReadReceipt;
	
	Email.Size = Message.Size;
	Email.Subject = CommonClientServer.ReplaceProhibitedXMLChars(Message.Subject);
	
	SetEmailText(Email, Message);
	
	FillInternetEmailAddresses(Email.CCRecipients ,  Message.Cc);
	FillInternetEmailAddresses(Email.ReplyRecipients, Message.ReplyTo);
	FillInternetEmailAddresses(Email.EmailRecipients, Message.To);
	
	If IsOutgoingEmail Then
		FillInternetEmailAddresses(Email.BccRecipients,
		                                Message.Bcc);
	Else
		FillInternetEmailAddresses(Email.ReadReceiptAddresses,
		                                Message.ReadReceiptAddresses);
	EndIf;
	
	Email.BasisID    = GetBaseIDFromEmail(Message);
	Email.BasisIDs   = Message.GetField("References", "String");
	Email.HashSum                  = EmailHashsum(Message);
	
	For each Attachment In Message.Attachments Do
		If IsBlankString(Attachment.CID) Then
			Email.HasAttachments = True;
			Break;
		EndIf;
	EndDo;
	
EndProcedure

Function EmailHashsum(Message)
	
	RowsArray = New Array;
	RowsArray.Add(Message.From.Address);
	RowsArray.Add(Message.PostingDate);
	RowsArray.Add(Message.Subject);
	
	Return Common.CheckSumString(StrConcat(RowsArray));
	
EndFunction

Procedure FillSubjectAndContacts(Email,
	                                Account,
	                                Topic,
	                                Folder,
	                                IsOutgoingEmail,
	                                PutEmailInBaseEmailFolder)
	
	// -----------------------------------------------------------------
	// Getting email base IDs.
	IDsArray = New Array;
	IDsString = Email.BasisIDs;
	While Not IsBlankString(IDsString) Do
		Position = StrFind(IDsString, "<");
		If Position = 0 Then
			Break;
		EndIf;
		IDsString = Mid(IDsString, Position+1);
		
		Position = StrFind(IDsString, ">");
		If Position = 0 Then
			Break;
		EndIf;
		
		CurrentID = TrimAll(Left(IDsString, Position-1));
		IDsString = TrimAll(Mid(IDsString, Position+1));
		
		If Not IsBlankString(CurrentID) Then
			IDsArray.Add(CurrentID);
		EndIf;
	EndDo;
	
	If (IDsArray.Find(Email.BasisID) = Undefined) 
		AND (NOT IsBlankString(Email.BasisID)) Then
		IDsArray.Add(Email.BasisID);
	EndIf;
	
	If IDsArray.Find(Email.MessageID) = Undefined 
		AND NOT IsBlankString(Email.MessageID) Then
		IDsArray.Add(Email.MessageID);
	EndIf;
	
	IDsTable = CreateTableWithIDs(IDsArray);

	// -----------------------------------------------------------------
	// Getting all bases.
	Query = New Query;
	Query.Text =
	"SELECT
	|	IDsTable.ID
	|INTO IDsTable
	|FROM
	|	&IDsTable AS IDsTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	IncomingEmail.Ref AS Ref,
	|	IncomingEmail.Date   AS Date,
	|	0                                AS Priority
	|INTO AllEmailMessages
	|FROM
	|	IDsTable AS IDsTable
	|		INNER JOIN Document.IncomingEmail AS IncomingEmail
	|		ON IDsTable.ID = IncomingEmail.MessageID
	|WHERE
	|	IncomingEmail.Account = &Account
	|
	|UNION ALL
	|
	|SELECT
	|	OutgoingEmail.Ref AS Ref,
	|	OutgoingEmail.Date   AS Date,
	|	0                                 AS Priority
	|FROM
	|	IDsTable AS IDsTable
	|		INNER JOIN Document.OutgoingEmail AS OutgoingEmail
	|		ON IDsTable.ID = OutgoingEmail.MessageID
	|WHERE
	|	OutgoingEmail.Account = &Account
	|
	|UNION ALL
	|
	|SELECT
	|	IncomingEmail.Ref AS Ref,
	|	IncomingEmail.Date   AS Date,
	|	1                                AS Priority
	|FROM
	|	Document.IncomingEmail AS IncomingEmail
	|WHERE
	|	IncomingEmail.Account = &Account
	|	AND IncomingEmail.BasisID = &MessageID
	|
	|UNION ALL
	|
	|SELECT
	|	OutgoingEmail.Ref AS Ref,
	|	OutgoingEmail.Date   AS Date,
	|	1                                 AS Priority
	|FROM
	|	Document.OutgoingEmail AS OutgoingEmail
	|WHERE
	|	OutgoingEmail.Account = &Account
	|	AND OutgoingEmail.BasisID = &MessageID
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	AllEmailMessages.Ref,
	|	AllEmailMessages.Priority,
	|	AllEmailMessages.Date AS Date,
	|	ISNULL(InteractionsFolderSubjects.Topic, UNDEFINED) AS Topic,
	|	ISNULL(InteractionsFolderSubjects.EmailMessageFolder, VALUE(Catalog.EmailMessageFolders.EmptyRef)) AS Folder,
	|	ISNULL(EmailMessageFolders.PredefinedFolder, FALSE) AS PredefinedFolder
	|FROM
	|	AllEmailMessages AS AllEmailMessages
	|		LEFT JOIN InformationRegister.InteractionsFolderSubjects AS InteractionsFolderSubjects
	|		ON AllEmailMessages.Ref = InteractionsFolderSubjects.Interaction
	|		LEFT JOIN Catalog.EmailMessageFolders AS EmailMessageFolders
	|		ON (InteractionsFolderSubjects.EmailMessageFolder = EmailMessageFolders.Ref)
	|
	|ORDER BY
	|	AllEmailMessages.Priority Asc,
	|	Date DESC";
	
	Query.SetParameter("IDsTable", IDsTable);
	Query.SetParameter("Account", Account);
	Query.SetParameter("MessageID", Email.MessageID);
	
	Result = Query.Execute();
	If Not Result.IsEmpty() Then
		
		Selection = Result.Select();
		Selection.Next();
		Topic = Selection.Topic;
		If Selection.Priority = 0 Then
			Email.InteractionBasis = Selection.Ref;
			If PutEmailInBaseEmailFolder AND Not Selection.PredefinedFolder Then
				Folder = Selection.Folder;
			EndIf;
		EndIf;
		
	EndIf;
	
	If Topic = Undefined Then
		Topic = Email.Ref;
	EndIf;

	// -----------------------------------------------------------------
	// Getting contacts specified in the subject.
	ContactsMap = ContactsInEmailMap(Email.InteractionBasis);

	// -----------------------------------------------------------------
	// Specifying contacts on the basis of subject.
	UndefinedAddresses = New Array;
	SetContactInEmail(Email, ContactsMap, UndefinedAddresses, IsOutgoingEmail);

	// -----------------------------------------------------------------
	// If there are undefined addresses, search them by contact information.
	ContactsMap = FindEmailsInContactInformation(UndefinedAddresses);
	If ContactsMap.Count() > 0 Then
		SetContactInEmail(Email, ContactsMap, UndefinedAddresses, IsOutgoingEmail);
	EndIf;
	
	Email.EmailRecipientsList = InteractionsClientServer.GetAddressesListPresentation(Email.EmailRecipients, False);
	Email.CcRecipientsList  = InteractionsClientServer.GetAddressesListPresentation(Email.CCRecipients, False);
	
	If TypeOf(Email) = Type("DocumentObject.OutgoingEmail") Then
		Email.CcRecipientsList  = InteractionsClientServer.GetAddressesListPresentation(Email.CCRecipients, False);
	EndIf;
	
EndProcedure

Function FindEmailsInContactInformation(AddressesArray)

	ContactsMap = New Map;

	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	Contacts.Ref,
	|	Contacts.EMAddress AS EMAddress
	|FROM
	|	(SELECT
	|		ContactInformation.Ref AS Ref,
	|		ContactInformation.EMAddress AS EMAddress
	|	FROM
	|		Catalog.Users.ContactInformation AS ContactInformation
	|	WHERE
	|		ContactInformation.EMAddress IN(&AddressesArray)
	|		AND ContactInformation.Type = &Type
	|		AND NOT(ContactInformation.Ref.DeletionMark)
	|";
	
	ContactsTypesDetailsArray = InteractionsClientServer.ContactsDetails();
	For each DetailsArrayElement In ContactsTypesDetailsArray Do
		
		If DetailsArrayElement.Name = "Users" Then
			Continue;
		EndIf;	
		
		Query.Text = Query.Text + "
		|UNION ALL
		|
		|SELECT
		|		ContactInformation.Ref AS Ref,
		|		ContactInformation.EMAddress AS EMAddress
		|FROM
		|	Catalog." + DetailsArrayElement.Name + ".ContactInformation AS ContactInformation
		|WHERE
		|	ContactInformation.EMAddress IN(&AddressesArray)
		|	AND ContactInformation.Type = &Type
		|	AND (NOT ContactInformation.Ref.DeletionMark)
		|";
		
	EndDo;	
	
	Query.Text = Query.Text + ") AS Contacts
	|TOTALS BY
	|	EMAddress";

	Query.SetParameter("AddressesArray", AddressesArray);
	Query.SetParameter("Type", Enums.ContactInformationTypes.EmailAddress);
	
	Selection = Query.Execute().Select(QueryResultIteration.ByGroups);
	While Selection.Next() Do
		SelectionByRefs = Selection.Select(QueryResultIteration.ByGroups);
		If (SelectionByRefs.Next()) Then
			ContactsMap.Insert(Upper(Selection.EMAddress), SelectionByRefs.Ref);
		EndIf;
	EndDo;

	Return ContactsMap;

EndFunction

Procedure SetContactInEmail(Email, ContactsMap, UndefinedAddresses, IsOutgoingEmail)
	
	For Each TableRow In Email.EmailRecipients Do
		ProcessContactAndAddressFields(TableRow.Address, TableRow.Contact, ContactsMap, UndefinedAddresses);
	EndDo;
	
	For Each TableRow In Email.CCRecipients Do
		ProcessContactAndAddressFields(TableRow.Address, TableRow.Contact, ContactsMap, UndefinedAddresses);
	EndDo;
	
	For Each TableRow In Email.ReplyRecipients Do
		ProcessContactAndAddressFields(TableRow.Address, TableRow.Contact, ContactsMap, UndefinedAddresses);
	EndDo;
	
	If IsOutgoingEmail Then
		For Each TableRow In Email.BccRecipients Do
			ProcessContactAndAddressFields(TableRow.Address, TableRow.Contact, ContactsMap, UndefinedAddresses);
		EndDo;
	Else
		ProcessContactAndAddressFields(Email.SenderAddress, Email.SenderContact, ContactsMap, UndefinedAddresses);
	EndIf;

EndProcedure

Procedure ProcessContactAndAddressFields(Address, Contact, ContactsMap, UndefinedAddresses)
	
	If ValueIsFilled(Contact) AND TypeOf(Contact) <> Type("String") Then
		Return;
	EndIf;
	
	FoundContact = ContactsMap.Get(Upper(Address));
	If FoundContact <> Undefined AND TypeOf(FoundContact) <> Type("String") Then
		Contact = FoundContact;
		Return;
	EndIf;
	
	If UndefinedAddresses.Find(Address) = Undefined Then
		UndefinedAddresses.Add(Address);
	EndIf;
	
EndProcedure

Function ContactsInEmailMap(Email)
	
	ContactsMap = New Map;
	If Not ValueIsFilled(Email) Then
		Return ContactsMap;
	EndIf;

	Query = New Query;
	Query.Text =
	"SELECT DISTINCT
	|	Addresses.Address,
	|	Addresses.Contact
	|FROM
	|	(" + ?(TypeOf(Email) = Type("DocumentRef.OutgoingEmail"), "", "SELECT
	|		IncomingEmail.SenderAddress   AS Address,
	|		IncomingEmail.SenderContact AS Contact
	|	FROM
	|		Document.IncomingEmail AS IncomingEmail
	|	WHERE
	|		IncomingEmail.Ref = &Email
	|	
	|	UNION ALL
	|	
	|	") + "SELECT
	|		To.Address,
	|		To.Contact
	|	FROM
	|		Document.IncomingEmail.EmailRecipients AS To
	|	WHERE
	|		To.Ref = &Email
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		To.Address,
	|		To.Contact
	|	FROM
	|		Document.IncomingEmail.CCRecipients AS To
	|	WHERE
	|		To.Ref = &Email
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		To.Address,
	|		To.Contact
	|	FROM
	|		Document.IncomingEmail.ReplyRecipients AS To
	|	WHERE
	|		To.Ref = &Email) AS Addresses";
	
	Query.SetParameter("Email", Email);
	
	If TypeOf(Email) = Type("DocumentRef.OutgoingEmail") Then
		Query.Text = StrReplace(Query.Text, "IncomingEmail", "OutgoingEmail");
	EndIf;
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		If TypeOf(Selection.Contact) <> Type("String") Then
			ContactsMap.Insert(Selection.Address, Selection.Contact);
		EndIf;
	EndDo;

	Return ContactsMap;
	
EndFunction

Procedure WriteReceivedEmailID(Account, ID, ReceivedDate)

	Record = InformationRegisters.ReceivedEmailIDs.CreateRecordManager();
	Record.Account = Account;
	Record.ID = ID;
	Record.DateReceived = ReceivedDate;
	Record.Write();

EndProcedure

Function GetBaseIDFromEmail(Message)

	IDsString = TrimAll(Message.GetField("In-Reply-To", "String"));
	
	Position = StrFind(IDsString, "<");
	If Position <> 0 Then
		IDsString = Mid(IDsString, Position+1);
	EndIf;
	
	Position = StrFind(IDsString, ">");
	If Position <> 0 Then
		IDsString = Left(IDsString, Position-1);
	EndIf;

	Return IDsString;

EndFunction

Procedure SetEmailText(Email, Message) Export
	
	HTMLText = "";
	PlainText = "";
	RichText = "";

	For Each EmailText In Message.Texts Do
		If EmailText.TextType = InternetMailTextType.HTML Then
			
			HTMLText = HTMLText + CommonClientServer.ReplaceProhibitedXMLChars(EmailText.Text);
			
		ElsIf EmailText.TextType = InternetMailTextType.PlainText Then
			
			PlainText = PlainText + CommonClientServer.ReplaceProhibitedXMLChars(EmailText.Text);
			
		ElsIf EmailText.TextType = InternetMailTextType.RichText Then
			RichText = CommonClientServer.ReplaceProhibitedXMLChars(EmailText.Text);
			
		EndIf;
	EndDo;
	
	If HTMLText <> "" Then
		Email.TextType = Enums.EmailTextTypes.HTML;
		Email.HTMLText = HTMLText;
		Email.Text = ?(PlainText <> "", PlainText, GetPlainTextFromHTML(HTMLText));
		
	ElsIf RichText <> "" Then
		Email.TextType = Enums.EmailTextTypes.RichText;
		Email.Text = RichText;
		
	Else
		Email.TextType = Enums.EmailTextTypes.PlainText;
		Email.Text = PlainText;
		
	EndIf;
	
EndProcedure

Function InternetEmailMessageSenderAddress(Sender)
	
	If TypeOf(Sender) = Type("InternetMailAddress") Then
		SenderAddress = Sender.Address;
	Else
		SenderAddress = Sender;
	EndIf;
	
	Return CommonClientServer.ReplaceProhibitedXMLChars(SenderAddress, "");
	
EndFunction

Procedure ChangeDomainInEmailAddressIfRequired(EmailAddress)
	
	AddressStructure =  EmailAddressStructure(EmailAddress);
	If AddressStructure <> Undefined Then
		MapOfDomainsToReplace = MapOfReplaceableEmailDomains();
		DomainToReplaceWith = MapOfDomainsToReplace.Get(AddressStructure.Domain);
		If DomainToReplaceWith <> Undefined Then
			EmailAddress = AddressStructure.MailboxName + "@" + DomainToReplaceWith;
		EndIf;
	EndIf;

EndProcedure

Function ArrayOfActiveFoldersNames(Mail)

	ArrayOfActiveFoldersNames = New Array;
	 
	ActiveFoldersNames     = Mail.GetMailboxesBySubscription();
	If ActiveFoldersNames.Count() = 0 Then
		ActiveFoldersNames = Mail.GetMailboxes();
	EndIf;
	
	Separator = ""; 
	Try
		Separator = Mail.DelimeterChar;
	Except
		// Some mail server do not support this command.
	EndTry;
	
	IgnorableNamesArray  = FoldersNamesArrayForWhichEmailsImportNotExecuted();
	
	For Each ActiveFolderName In ActiveFoldersNames Do
		
		If Not IsBlankString(Separator) Then
			
			FolderNameStringsArray = StringFunctionsClientServer.SplitStringIntoWordArray(ActiveFolderName,Separator);
			If FolderNameStringsArray.Count() = 0 Then
				Continue;
			EndIf;
			FolderNameWithoutSeparator = FolderNameStringsArray[FolderNameStringsArray.Count()-1];
			If IsBlankString(FolderNameWithoutSeparator) Then
				Continue;
			EndIf;
			If Left(FolderNameWithoutSeparator,1) = "[" AND Right(FolderNameWithoutSeparator,1) = "]" Then
				Continue;
			EndIf;
			
			If IgnorableNamesArray.Find(Lower(FolderNameWithoutSeparator)) <> Undefined Then
				Continue;
			EndIf;
			
		Else
			
			If Left(ActiveFolderName,1) = "[" AND Right(ActiveFolderName,1) = "]" Then
				Continue;
			EndIf;
			
			If IgnorableNamesArray.Find(Lower(ActiveFolderName)) <> Undefined Then
				Continue;
			EndIf;
			
		EndIf;
		
		ArrayOfActiveFoldersNames.Add(ActiveFolderName);
		
	EndDo;

	Return ArrayOfActiveFoldersNames;
	
EndFunction

Function FoldersNamesArrayForWhichEmailsImportNotExecuted()

	NamesArray = New Array;
	NamesArray.Add(NStr("en = 'spam'; ru = 'спам';pl = 'spam';es_ES = 'spam';es_CO = 'spam';tr = 'spam';it = 'spam';de = 'spam'"));
	NamesArray.Add(NStr("en = 'trash'; ru = 'корзина';pl = 'kosz';es_ES = 'papelera';es_CO = 'papelera';tr = 'silinenler';it = 'cestino';de = 'papierkorb'"));
	NamesArray.Add(NStr("en = 'drafts'; ru = 'черновики';pl = 'wersje robocze';es_ES = 'borradores';es_CO = 'borradores';tr = 'taslaklar';it = 'bozze';de = 'entwürfe'"));
	NamesArray.Add(NStr("en = 'junk'; ru = 'нежелательная почта';pl = 'spam';es_ES = 'correo no deseado';es_CO = 'correo no deseado';tr = 'gereksiz e-posta';it = 'indesiderate';de = 'junk'"));
	NamesArray.Add("spam");
	NamesArray.Add("trash");
	NamesArray.Add("drafts");
	NamesArray.Add("draftBox");
	NamesArray.Add("deleted");
	NamesArray.Add("junk");
	NamesArray.Add("bulk mail");
	Return NamesArray;

EndFunction

Procedure DeterminePreviouslyImportedSubordinateEmails(Account, EmailsReceived);
	
	If EmailsReceived.Count() = 0 Then
		Return;
	EndIf;
	
	ArrayOfEmailsToAddToProcessing = New Array;
	OutgoingEmailMetadata = Metadata.Documents.OutgoingEmail;
	IncomingEmailMetadata = Metadata.Documents.IncomingEmail;
	
	Query = New Query;
	Query.Text = "
	|SELECT
	|	OutgoingEmail.Ref,
	|	OutgoingEmail.MessageID
	|INTO ReceivedMessagesIDs
	|FROM
	|	Document.OutgoingEmail AS OutgoingEmail
	|WHERE
	|	OutgoingEmail.Ref IN(&EmailsArray)
	|
	|UNION ALL
	|
	|SELECT
	|	IncomingEmail.Ref,
	|	IncomingEmail.MessageID
	|FROM
	|	Document.IncomingEmail AS IncomingEmail
	|WHERE
	|	IncomingEmail.Ref IN(&EmailsArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	OutgoingEmail.Ref                                      AS Email,
	|	OutgoingEmail.InteractionBasis                     AS CurrentBasis,
	|	ReceivedMessagesIDs.Ref                                  AS BaseEmailRef,
	|	ISNULL(InteractionFolderSubjectsBasis.Topic, UNDEFINED)   AS BasisEmailSubject,
	|	ISNULL(InteractionFolderSubjectsSubordinate.Topic, UNDEFINED) AS EmailSubjectSubordinate
	|FROM
	|	ReceivedMessagesIDs AS ReceivedMessagesIDs
	|		INNER JOIN Document.OutgoingEmail AS OutgoingEmail
	|		ON ReceivedMessagesIDs.MessageID = OutgoingEmail.BasisID
	|			AND (OutgoingEmail.InteractionBasis <> ReceivedMessagesIDs.Ref)
	|		LEFT JOIN InformationRegister.InteractionsFolderSubjects AS InteractionFolderSubjectsSubordinate
	|		ON (OutgoingEmail.Ref = InteractionFolderSubjectsSubordinate.Interaction)
	|		LEFT JOIN InformationRegister.InteractionsFolderSubjects AS InteractionFolderSubjectsBasis
	|		ON ReceivedMessagesIDs.Ref = InteractionFolderSubjectsBasis.Interaction
	|WHERE
	|	OutgoingEmail.Account = &Account
	|
	|UNION ALL
	|
	|SELECT
	|	IncomingEmail.Ref,
	|	IncomingEmail.InteractionBasis,
	|	ReceivedMessagesIDs.Ref,
	|	ISNULL(InteractionFolderSubjectsBasis.Topic, UNDEFINED),
	|	ISNULL(InteractionFolderSubjectsSubordinate.Topic, UNDEFINED) 
	|FROM
	|	ReceivedMessagesIDs AS ReceivedMessagesIDs
	|		INNER JOIN Document.IncomingEmail AS IncomingEmail
	|		ON ReceivedMessagesIDs.MessageID = IncomingEmail.BasisID
	|			AND (IncomingEmail.InteractionBasis <> ReceivedMessagesIDs.Ref)
	|		LEFT JOIN InformationRegister.InteractionsFolderSubjects AS InteractionFolderSubjectsSubordinate
	|		ON (IncomingEmail.Ref = InteractionFolderSubjectsSubordinate.Interaction)
	|		LEFT JOIN InformationRegister.InteractionsFolderSubjects AS InteractionFolderSubjectsBasis
	|		ON ReceivedMessagesIDs.Ref = InteractionFolderSubjectsBasis.Interaction
	|WHERE
	|	IncomingEmail.Account = &Account";
	
	Query.SetParameter("Account", Account);
	Query.SetParameter("EmailsArray", EmailsReceived);
	
	Result = Query.Execute();
	If Result.IsEmpty() Then
		Return;
	EndIf;
	
	Selection = Result.Select();
	
	While Selection.Next() Do
		
		BeginTransaction();
		
		Try
			
			DocumentMetadata = ?(TypeOf(Selection.Email) = Type("DocumentRef.IncomingEmail"),
			                        IncomingEmailMetadata, OutgoingEmailMetadata);
			
			Lock = New DataLock;
			LockItem = Lock.Add(DocumentMetadata.FullName());
			LockItem.SetValue("Ref", Selection.Email);
			InformationRegisters.InteractionsFolderSubjects.BlockInteractionFoldersSubjects(Lock, Selection.Email);
			InformationRegisters.InteractionsFolderSubjects.BlockInteractionFoldersSubjects(Lock, Selection.BaseEmailRef);
			Lock.Lock();
			
			EmailObject = Selection.Email.GetObject();
			EmailObject.InteractionBasis = Selection.BaseEmailRef;
			EmailObject.Write();
			
			If Selection.BasisEmailSubject <> Selection.EmailSubjectSubordinate Then
				
				If Selection.EmailSubjectSubordinate = Selection.Email Then
					
					Interactions.SetSubject(Selection.Email, Selection.BasisEmailSubject, False);
					
				ElsIf NOT InteractionsClientServer.IsSubject(Selection.EmailSubjectSubordinate) Then
					
					If InteractionsClientServer.IsSubject(Selection.BasisEmailSubject) Then
						Interactions.SetSubject(Selection.Email, Selection.BasisEmailSubject, False);
						ArrayOfEmailsToAddToProcessing.Add(Selection.Email);
					Else 
						Interactions.SetSubject(Selection.BaseEmailRef, Selection.EmailSubjectSubordinate, False);
					EndIf;
					
				Else
					
					If InteractionsClientServer.IsSubject(Selection.BasisEmailSubject) Then
						Interactions.SetSubject(Selection.Email, Selection.BasisEmailSubject, False);
						ArrayOfEmailsToAddToProcessing.Add(Selection.Email);
					Else 
						Interactions.SetSubject(Selection.BaseEmailRef, Selection.EmailSubjectSubordinate, False);
					EndIf;
					
				EndIf;
				
			EndIf;
			
			CommitTransaction();
		
		Except
			RollbackTransaction();
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Не установить письмо основание у %1 по причине %2'; en = 'Could not determine the basis email for %1 for the following reason: %2'; pl = 'Nie udało się określić podstawy wiadomości e-mail dla %1 po przyczynie: %2';es_ES = 'No se ha podido determinar el correo electrónico básico de %1 por la siguiente causa: %2';es_CO = 'No se ha podido determinar el correo electrónico básico de %1 por la siguiente causa: %2';tr = '%1 için temel e-posta şu nedenle belirlenemedi: %2';it = 'Impossibile determinare l''email base per %1a causa di: %2';de = 'Kann die Basis-E-Mail für %1 wegen: %2 nicht bestimmen'"), 
				Selection.Email, DetailErrorDescription(ErrorInfo()));
			WriteLogEvent(EventLogEvent(), EventLogLevel.Warning,
				DocumentMetadata, Selection.Email, MessageText);
		EndTry;
	
	EndDo;
	 
	CommonClientServer.SupplementArray(EmailsReceived, ArrayOfEmailsToAddToProcessing, True);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Operations with email attachments.

Function InternetEmailMessageFromBinaryData(BinaryData) 
	
	EmailMessage = New InternetMailMessage;
	EmailMessage.SetSourceData(BinaryData);
	
	Return EmailMessage;
	
EndFunction

Procedure WriteEmailAttachment(Object, Attachment,SignaturesArray,CountOfBlankNamesInAttachments)
	
	EmailRef = Object.Ref;
	Size = 0;
	IsAttachmentEmail = False;
	
	If TypeOf(Attachment.Data) = Type("BinaryData") Then
		
		AttachmentData = Attachment.Data;
		FileName = CommonClientServer.ReplaceProhibitedXMLChars(Attachment.FileName, "");
		IsAttachmentEmail = FileIsEmail(FileName, AttachmentData);
		
	Else
		
		AttachmentData = Attachment.Data.GetSourceData();
		FileName = Interactions.EmailPresentation(Attachment.Data.Subject, Attachment.Data.DateReceived) + ".eml";
		IsAttachmentEmail = True;
		
	EndIf;
	
	Size = AttachmentData.Size();
	Address = PutToTempStorage(AttachmentData, "");
	
	If Not IsBlankString(Attachment.CID) Then
		
		If StrFind(Object.HTMLText, Attachment.CID) = 0 Then
			
			Attachment.CID = "";
			
		ElsIf StrFind(Object.HTMLText, Attachment.Name) > 0 
			AND StrFind(Attachment.CID, Attachment.Name + "@") = 0
			AND StrFind(Object.HTMLText, "alt=" + """" + Attachment.Name + """") = 0 Then
			
			Attachment.CID = "";
			
		EndIf;
		
	EndIf;
	
	HasSignatures = (SignaturesArray.Count() > 0)
		AND Common.SubsystemExists("StandardSubsystems.DigitalSignature");
		
	IsDisplayedFile = NOT IsBlankString(Attachment.CID);
	
	AttachmentParameters = New Structure;
	AttachmentParameters.Insert("FileName", FileName);
	AttachmentParameters.Insert("Size", Size);
	If IsDisplayedFile Then
		AttachmentParameters.Insert("EmailFileID", Attachment.CID);
	EndIf;
	If IsAttachmentEmail Then
		AttachmentParameters.Insert("IsAttachmentEmail", True);
	EndIf;
	If HasSignatures Then
		AttachmentParameters.Insert("SignedWithDS", True);
	EndIf;
	
	EmailAttachmentRef = WriteEmailAttachmentFromTempStorage(
		EmailRef, Address, AttachmentParameters, CountOfBlankNamesInAttachments);
		
	If HasSignatures Then
		
		ModuleDigitalSignature = Common.CommonModule("DigitalSignature");
		For Each AttachmentsSignature In SignaturesArray Do
			
			SignatureData = ModuleDigitalSignature.ReadSignatureData(AttachmentsSignature.Data);
			
			SignatureParameters = New Structure;
			SignatureParameters.Insert("Signature", SignatureData.Signature.Get());
			SignatureParameters.Insert("Certificate", SignatureData.Certificate);
			SignatureParameters.Insert("SignatureSetBy", Undefined);
			SignatureParameters.Insert("Comment", NStr("ru = 'Вложение электронного письма'; en = 'Email attachment'; pl = 'Załącznik do wiadomości e-mail';es_ES = 'Adjunto de correo electrónico';es_CO = 'Adjunto de correo electrónico';tr = 'E-posta eki';it = 'Allegato email';de = 'E-Mail-Anhang'"));
			SignatureParameters.Insert("SignatureDate", CurrentSessionDate());
			SignatureParameters.Insert("CertificateOwner", SignatureData.CertificateOwner);
			
			FilesOperations.AddSignatureToFile(EmailAttachmentRef, SignatureParameters);
			
		EndDo;
		
	EndIf;
	
	DeleteFromTempStorage(Address);
	
EndProcedure

// Gets email attachments.
//
// Parameters:
//  Email                         - DocumentRef - an email document, whose attachments need to be received.
//  GenerateSizePresentation - Boolean - indicates that the blank SizePresentation string column will be the query result.
//  OnlyWithBlankID                - Boolean - if True, only attachments without EmailFileID will be got.
//
// Returns:
//  ValueTable   - a value table that contains information about attachments.
//
Function GetEmailAttachments(Email,GenerateSizePresentation = False, OnlyWithBlankID = False) Export
	
	SetPrivilegedMode(True);
	
	AttachedEmailFilesData = Interactions.AttachedEmailFilesData(Email);
	MetadataObjectName = AttachedEmailFilesData.AttachedFilesCatalogName;
	FilesOwner       = AttachedEmailFilesData.FilesOwner;
	
	If MetadataObjectName = Undefined Then
		Return New ValueTable;
	EndIf;
	
	If GenerateSizePresentation Then
		TextSizePresentation = ",
		|CAST("""" AS STRING(20)) AS SizePresentation";
	Else
		TextSizePresentation = "";
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	Files.Ref                    AS Ref,
	|	Files.PictureIndex            AS PictureIndex,
	|	Files.Size                    AS Size,
	|	Files.EmailFileID AS EmailFileID,
	|	&SignedWithDS                     AS SignedWithDS,
	|	CASE
	|		WHEN Files.Extension = &BlankRow
	|			THEN Files.Description
	|		ELSE Files.Description + ""."" + Files.Extension
	|	END AS FileName" + TextSizePresentation + "
	|FROM
	|	Catalog." + MetadataObjectName + " AS Files
	|WHERE
	|	Files.FileOwner = &Email
	|	AND NOT Files.DeletionMark";
	
	If Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		DigitallySignedString = "Files.SignedWithDS";
	Else
		DigitallySignedString = "FALSE";
	EndIf;
	
	Query.Text = StrReplace(Query.Text, "&SignedWithDS", DigitallySignedString);
	
	If OnlyWithBlankID Then
		Query.Text = Query.Text + "
		| AND Files.EmailFileID = """""; 
	EndIf;
	
	Query.SetParameter("Email", FilesOwner);
	Query.SetParameter("BlankRow","");
	
	TableForReturn =  Query.Execute().Unload();
	
	If GenerateSizePresentation Then
		For each TableRow In TableForReturn Do
		
			TableRow.SizePresentation = 
				InteractionsClientServer.GetFileSizeStringPresentation(TableRow.Size);
		
		EndDo;
	EndIf;
	
	TableForReturn.Indexes.Add("EmailFileID");
	
	Return TableForReturn;
	
EndFunction

// Writes an email attachment located in a temporary storage to a file.
Function WriteEmailAttachmentFromTempStorage(
	Email,
	AddressInTempStorage,
	AttachmentParameters,
	CountOfBlankNamesInAttachments = 0) Export
	
	FileNameToParse = AttachmentParameters.FileName;
	ExtensionWithoutPoint = CommonClientServer.GetFileNameExtension(FileNameToParse);
	NameWithoutExtension = CommonClientServer.ReplaceProhibitedCharsInFileName(FileNameToParse);
	
	If IsBlankString(NameWithoutExtension) Then
		
		NameWithoutExtension =
			NStr("ru = 'Вложение без имени'; en = 'Attachment without name'; pl = 'Załącznik bez nazwy';es_ES = 'Adjunto sin nombre';es_CO = 'Adjunto sin nombre';tr = 'Adsız ek';it = 'Allegato senza nome';de = 'Anhänge ohne Name'") + ?(CountOfBlankNamesInAttachments = 0, ""," " + String(CountOfBlankNamesInAttachments + 1));
		CountOfBlankNamesInAttachments = CountOfBlankNamesInAttachments + 1;
		
	Else
		NameWithoutExtension =
			?(ExtensionWithoutPoint = "",
			NameWithoutExtension,
			Left(NameWithoutExtension, StrLen(NameWithoutExtension) - StrLen(ExtensionWithoutPoint) - 1));
	EndIf;
	
	AdditionalParameters = New Array;
	If AttachmentParameters.Property("EmailFileID") Then
		AdditionalParameters.Add("EmailFileID");
	EndIf;
	If AttachmentParameters.Property("IsAttachmentEmail") Then
		AdditionalParameters.Add("IsAttachmentEmail");
	EndIf;
	If AttachmentParameters.Property("SignedWithDS") Then
		AdditionalParameters.Add("SignedWithDS");
	EndIf;
	
	FileParameters = FilesOperations.FileAddingOptions(AdditionalParameters);
	FileParameters.FilesOwner = Email;
	FileParameters.BaseName = NameWithoutExtension;
	FileParameters.ExtensionWithoutPoint = ExtensionWithoutPoint;
	FileParameters.ModificationTimeUniversal = Undefined;
	
	If AttachmentParameters.Property("EmailFileID") Then
		FileParameters.EmailFileID = AttachmentParameters.EmailFileID;
	EndIf;
	If AttachmentParameters.Property("IsAttachmentEmail") Then
		FileParameters.IsAttachmentEmail = AttachmentParameters.IsAttachmentEmail;
	EndIf;
	If AttachmentParameters.Property("SignedWithDS") Then
		FileParameters.SignedWithDS = AttachmentParameters.SignedWithDS;
	EndIf;
	
	Return FilesOperations.AppendFile(
		FileParameters,
		AddressInTempStorage,
		"");
	
EndFunction

// Writes an email attachment by copying another email attachment.
Function WriteEmailAttachmentByCopyOtherEmailAttachment(
	Email,
	RefToFile,
	UUIDOfForm) Export
	
	FileData = FilesOperations.FileData(
		RefToFile, UUIDOfForm, True);
	
	FileParameters = FilesOperations.FileAddingOptions();
	FileParameters.FilesOwner = Email;
	FileParameters.BaseName = FileData.Description;
	FileParameters.ExtensionWithoutPoint = FileData.Extension;
	FileParameters.ModificationTimeUniversal = FileData.UniversalModificationDate;
	
	Return FilesOperations.AppendFile(
		FileParameters,
		FileData.BinaryFileDataRef,
		"");
	
EndFunction

// Deletes email attachments.
//
// Parameters:
//  Email - DocumentRef - an email, whose attachments will be deleted.
//
Procedure DeleteEmailAttachments(Email) Export

	MetadataObjectName = MetadataObjectNameOfAttachedEmailFiles(Email);
	If MetadataObjectName = Undefined Then
		Return;
	EndIf;
	
	Lock = New DataLock;
	LockItem = Lock.Add("Catalog." + MetadataObjectName);
	LockItem.SetValue("FileOwner", Email);
	Lock.Lock();

	Query = New Query;
	Query.Text =
	"SELECT
	|	Files.Ref
	|FROM
	|	Catalog." + MetadataObjectName + " AS Files
	|WHERE
	|	Files.FileOwner = &FileOwner";
	Query.SetParameter("FileOwner", Email);
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		Object = Selection.Ref.GetObject();
		Object.Delete();
	EndDo;
	
EndProcedure

// Checks if binary data upon deserialization is InternetMailMessage.
//
// Parameters:
//  BinaryData  - BinaryData - binary data to be checked.
//
// Returns:
//   Boolean   - True if binary data is deserialized into InternetMailMessage correctly.
//
Function BinaryDataCorrectInternetMailMessage(BinaryData)
	
	EmailMessage = InternetEmailMessageFromBinaryData(BinaryData);
	Return EmailMessage.ParseStatus = InternetMailMessageParseStatus.ErrorsNotDetected;
	
EndFunction

Function FileIsEmail(FileName, BinaryData) Export
	
	If InteractionsClientServer.IsFileEmail(FileName)
		AND BinaryDataCorrectInternetMailMessage(BinaryData) Then
		
		Return True;
		
	Else
		
		Return False;
		
	EndIf;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Read receipts

// Gets an email account used to send emails by default.
//
// Returns:
//  Catalog.EmailAccounts  - an email account to send emails by default.
//
Function GetAccountForDefaultSending() Export
	
	Query = New Query;
	Query.Text = AvailableAccountsQueryText();
	
	Query.SetParameter("CurrentUser", Users.AuthorizedUser());
	
	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then
		Return Catalogs.EmailAccounts.EmptyRef();
	EndIf;
	
	Selection = QueryResult.Select();
	Selection.Next();
	Return Selection.Account;
	
EndFunction

Procedure WriteReadReceiptProcessingRequest(Email)
	
	Record = InformationRegisters.ReadReceipts.CreateRecordManager();
	Record.Email = Email;
	Record.Write();
	
EndProcedure

// Sets a flag indicating that a notification of reading an email is sent.
//
// Parameters:
//  Email  - DocumentRef.IncomingEmail - an email for which the flag is set.
//  Send  - Boolean - if True, the flag will be set, if False, it will be removed.
//
Procedure SetNotificationSendingFlag(Email, Send) Export

	If Send Then
		
		Record = InformationRegisters.ReadReceipts.CreateRecordManager();
		Record.Email = Email;
		Record.SendingRequired = True;
		Record.ReadDate     = GetDateAsStringWithGMTOffset(CurrentSessionDate());
		Record.User      = Users.CurrentUser();
		Record.Write();
		
	Else
		
		RecordSet = InformationRegisters.ReadReceipts.CreateRecordSet();
		RecordSet.Filter.Email.Set(Email);
		RecordSet.Write();
		
	EndIf;

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Other procedures and functions

Function OutgoingMailServerNotRequireAdditionalSendingByIMAP(OutgoingMailServerName) Export
	
	ExceptionsServersArray = New Array;
	ExceptionsServersArray.Add("smtp.gmail.com");
	
	Return ExceptionsServersArray.Find(OutgoingMailServerName) <> Undefined;
	
EndFunction

Function GetEmailImportance(Importance)
	
	If (Importance = InternetMailMessageImportance.High)
		OR (Importance = InternetMailMessageImportance.Highest) Then
		
		Return Enums.InteractionImportanceOptions.High;

	ElsIf (Importance = InternetMailMessageImportance.Lowest)
		OR (Importance = InternetMailMessageImportance.Low) Then
		
		Return Enums.InteractionImportanceOptions.Low;

	Else
		
		Return Enums.InteractionImportanceOptions.Normal;
		
	EndIf;
	
EndFunction

Function GetPlainTextFromHTML(HTMLText)
	
	Builder = New DOMBuilder;
	HTMLReader = New HTMLReader;
	HTMLReader.SetString(HTMLText);
	DocumentHTML = Builder.Read(HTMLReader);
	
	Return DocumentHTML.Body.TextContent;
	
EndFunction

Function GenerateReadReceiptText(Selection)
	
	LocalizedReceipt = Chars.LF + NStr("ru = 'Сообщение от %1 < %2 >
		|Тема: %3
		|Отправленное %4
		|Было прочитано %5
		|Получателем %6 <%7>'; 
		|en = 'Message from %1 < %2 >
		|Subject: %3
		|Sent %4
		|Read %5
		|By receiver %6 <%7>'; 
		|pl = 'Wiadomość od %1 < %2 >
		|Temat: %3
		|Wysłano %4
		|Przeczytano %5
		|Wg odbiorcy %6 <%7>';
		|es_ES = 'Mensaje de %1 < %2 >
		|Tema: %3
		|Enviado%4
		|Leído %5
		|Por el destinatario %6 <%7>';
		|es_CO = 'Mensaje de %1 < %2 >
		|Tema: %3
		|Enviado%4
		|Leído %5
		|Por el destinatario %6 <%7>';
		|tr = '%1 iletisi < %2 >
		|Konu: %3
		|Gönderildi %4
		|Okundu %5
		|Alıcıya göre %6 <%7>';
		|it = 'Messaggio da %1<%2>
		| Oggetto: %3
		|Inviare%4
		|Leggere%5
		|Dal ricevitore %6<%7>';
		|de = 'Nachricht aus %1 < %2 >
		|Thema: %3
		|Gesendet %4
		|Gelesen %5
		|Von Empfänger %6 <%7>'");
	
	LocalizedReceipt = StringFunctionsClientServer.SubstituteParametersToString(LocalizedReceipt,
		Selection.SenderPresentation,
		Selection.SenderAddress,
		Selection.Subject,
		Selection.Date,
		Selection.ReadDate,
		Selection.UserName,
		Selection.EmailAddress);
	
	Return LocalizedReceipt;

EndFunction

Function GetDateAsStringWithGMTOffset(Date)
	
	TimeOffsetInSeconds = ToUniversalTime(Date) - Date; 
	OffsetHours = Int(TimeOffsetInSeconds/3600); 
	OffsetHoursString = ?(OffsetHours > 0,"+","") + Format(OffsetHours,"ND=2; NFD=0; NZ=00; NLZ=");
	OffsetMinutes = TimeOffsetInSeconds%3600;
	If OffsetMinutes < 0 Then
		OffsetMinutes = + OffsetMinutes;
	EndIf;
	OffsetMinutesString = Format(OffsetMinutes,"ND=2; NFD=0; NZ=00; NLZ=");
	
	Return Format(Date,"DLF=DT") + " GMT " + OffsetHoursString + OffsetMinutesString;

EndFunction

Procedure CreatePredefinedEmailsFolder(Description,Owner)

	Folder = Catalogs.EmailMessageFolders.CreateItem();
	Folder.SetNewCode();
	Folder.DataExchange.Load = True;
	Folder.PredefinedFolder = True;
	Folder.Description = Description;
	Folder.Owner = Owner;
	Folder.Write();

EndProcedure 

// Returns the importance of Internet mail message depending on the passed 
// InteractionImportanceVariants enumeration value.
//
// Parameters:
//  InteractionImportance - Enum.InteractionImportanceOptions.
//
// Returns:
//  InternetMailMessageImportance - .
//
Function GetImportance(InteractionImportance) Export
	
	If InteractionImportance = Enums.InteractionImportanceOptions.High Then
		Return InternetMailMessageImportance.High;
	ElsIf InteractionImportance = Enums.InteractionImportanceOptions.Low Then
		Return InternetMailMessageImportance.Low;
	Else
		Return InternetMailMessageImportance.Normal;
	EndIf;
	
EndFunction

// Returns an event name of the Interactions subsystem event log.
Function EventLogEvent() Export
	
	Return NStr("ru = 'Взаимодействия'; en = 'Interactions'; pl = 'Interakcje';es_ES = 'Interacciones';es_CO = 'Interacciones';tr = 'Etkileşimler';it = 'Interazioni';de = 'Interaktionen'", CommonClientServer.DefaultLanguageCode());
	
EndFunction

// Gets and adds to the value list available to user email accounts.
//
// Parameters:
//  ChoiceList  - ValueList - all email accounts available to user will be added here.
//
Procedure GetAvailableAccountsForSending(ChoiceList,AccountDataTable) Export
	
	ChoiceList.Clear();
	
	Query = New Query;
	Query.Text = AvailableAccountsQueryText();
	
	Query.SetParameter("CurrentUser", Users.CurrentUser());
	Result = Query.Execute();
	If Result.IsEmpty() Then
		Return;
	EndIf;
	
	Selection = Result.Select();
	While Selection.Next() Do
		ChoiceList.Add(Selection.Account, 
			InteractionsClientServer.GetAddresseePresentation(Selection.UserName,
			                                                         Selection.EmailAddress,
			                                                         ""));
	EndDo;
	
	CommonClientServer.SupplementTable(Result.Unload(), AccountDataTable);
	
EndProcedure

Function AvailableAccountsQueryText()
	
	Return "
	|SELECT ALLOWED TOP 1
	|	OutgoingEmail.Account AS Account
	|INTO LastUsedAccount
	|FROM
	|	Document.OutgoingEmail AS OutgoingEmail
	|WHERE
	|	OutgoingEmail.EmailStatus <> VALUE(Enum.OutgoingEmailStatuses.Draft)
	|	AND NOT OutgoingEmail.DeletionMark
	|	AND OutgoingEmail.Author = &CurrentUser
	|
	|ORDER BY
	|	OutgoingEmail.Date DESC
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	EmailAccounts.Ref AS Account,
	|	EmailAccounts.UserName AS UserName,
	|	EmailAccounts.EmailAddress AS EmailAddress,
	|	ISNULL(EmailAccountSettings.DeleteEmailsAfterSend, FALSE) AS DeleteAfterSend,
	|	CASE
	|		WHEN NOT LastUsedAccount.Account IS NULL
	|			THEN 0
	|		WHEN EmailAccounts.AccountOwner <> VALUE(Catalog.Users.EmptyRef)
	|				AND EmailAccounts.AccountOwner = &CurrentUser
	|			THEN 1
	|		WHEN EmailAccounts.AccountOwner = VALUE(Catalog.Users.EmptyRef)
	|				AND EmailAccountSettings.EmployeeResponsibleForProcessingEmails = &CurrentUser
	|			THEN 2
	|		ELSE 2
	|	END AS OrderingValue
	|FROM
	|	Catalog.EmailAccounts AS EmailAccounts
	|		LEFT JOIN InformationRegister.EmailAccountSettings AS EmailAccountSettings
	|		ON (EmailAccountSettings.EmailAccount = EmailAccounts.Ref)
	|		LEFT JOIN LastUsedAccount AS LastUsedAccount
	|		ON LastUsedAccount.Account = EmailAccounts.Ref
	|WHERE
	|	EmailAccounts.UseForSending
	|	AND NOT EmailAccounts.DeletionMark
	|	AND NOT ISNULL(EmailAccountSettings.DoNotUseInIntegratedMailClient, FALSE)
	|	AND (EmailAccounts.AccountOwner = &CurrentUser
	|			OR EmailAccounts.AccountOwner = VALUE(Catalog.Users.EmptyRef))
	|
	|ORDER BY
	|	OrderingValue";
	
EndFunction

// Creates predefined folders for an email account.
//
// Parameters:
//  Account  - CatalogRef.EmailAccounts - an email account, for which predefined folders will be 
//                                                                    created.
//
Procedure CreatePredefinedEmailsFoldersForAccount(Account) Export
	
	PredefinedFoldersNamesArray = New Array;
	PredefinedFoldersNamesArray.Add(NStr("ru = 'Входящие'; en = 'Incoming'; pl = 'Przychodzące';es_ES = 'Entrante';es_CO = 'Entrante';tr = 'Gelen';it = 'In entrata';de = 'Eingehend'"));
	PredefinedFoldersNamesArray.Add(NStr("ru = 'Исходящие'; en = 'Outgoing'; pl = 'Wychodzące';es_ES = 'Saliendo';es_CO = 'Saliendo';tr = 'Giden';it = 'In uscita';de = 'Ausgehend'"));
	PredefinedFoldersNamesArray.Add(NStr("ru = 'Нежелательная почта'; en = 'Junk email'; pl = 'Wiadomości spam';es_ES = 'Correo electrónico no deseado';es_CO = 'Correo electrónico no deseado';tr = 'Gereksiz e-posta';it = 'Email indesiderate';de = 'Junk-E-Mail'"));
	PredefinedFoldersNamesArray.Add(NStr("ru = 'Отправленные'; en = 'Sent'; pl = 'Wysłano';es_ES = 'Enviar';es_CO = 'Enviar';tr = 'Gönderilen';it = 'Inviato';de = 'Gesendet'"));
	PredefinedFoldersNamesArray.Add(NStr("ru = 'Удаленные'; en = 'DeletedItems'; pl = 'Usunięte pozycje';es_ES = 'Elementos eliminados';es_CO = 'Elementos eliminados';tr = 'Silinenler';it = 'Elementi eliminati';de = 'Gelöschte Elemente'"));
	PredefinedFoldersNamesArray.Add(NStr("ru = 'Черновики'; en = 'Drafts'; pl = 'Wersje robocze';es_ES = 'Borradores';es_CO = 'Borradores';tr = 'Taslaklar';it = 'Bozze';de = 'Entwürfe'"));
	
	Query = New Query;
	Query.Text = "SELECT
	|	EmailMessageFolders.Description
	|FROM
	|	Catalog.EmailMessageFolders AS EmailMessageFolders
	|WHERE
	|	EmailMessageFolders.PredefinedFolder
	|	AND EmailMessageFolders.Owner = &Owner";
	
	Query.SetParameter("Owner", Account);
	
	ExistingFoldersArray = Query.Execute().Unload().UnloadColumn("Description");
	
	For each PredefinedFolderName In PredefinedFoldersNamesArray Do
		If ExistingFoldersArray.Find(PredefinedFolderName) = Undefined Then
			
			CreatePredefinedEmailsFolder(PredefinedFolderName, Account);
			
		EndIf;
	EndDo;
	
EndProcedure

// Gets a name of metadata object of attached email files.
//
// Parameters:
//  Email  - DocumentRef - an email whose name is defined.
//
// Returns:
//  String, Undefined  - a name of metadata object of attached email files.
Function MetadataObjectNameOfAttachedEmailFiles(Email) Export

	 If TypeOf(Email) = Type("DocumentRef.OutgoingEmail") Then
		
		Return "OutgoingEmailAttachedFiles";
		
	ElsIf TypeOf(Email) = Type("DocumentRef.IncomingEmail") Then
		
		Return "IncomingEmailAttachedFiles";
		
	Else
		
		Return Undefined;
		
	EndIf;

EndFunction

Procedure UnlockAccountForReceiving(Account)
	
	BeginTransaction();
	
	Try
		
		Lock = New DataLock;
		LockItem = Lock.Add("InformationRegister.AccountsLockedForReceipt");
		LockItem.SetValue("Account", Account);
		Lock.Lock();
	
		RecordSet = InformationRegisters.AccountsLockedForReceipt.CreateRecordSet();
		RecordSet.Filter.Account.Set(Account);
		RecordSet.Write();

		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		Raise;
		
	EndTry;
	
EndProcedure

#EndRegion
