#Region Internal

// Intended for moving passwords to a secure storage.
// This procedure is used in the infobase update handler.
Procedure MovePasswordsToSecureStorage() Export
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	EmailAccounts.Ref, EmailAccounts.DeletePassword,
	|	EmailAccounts.DeleteSMTPPassword
	|FROM
	|	Catalog.EmailAccounts AS EmailAccounts";
	
	QueryResult = Query.Execute().Select();
	
	While QueryResult.Next() Do
		If NOT IsBlankString(QueryResult.DeletePassword) 
			OR NOT IsBlankString(QueryResult.DeleteSMTPPassword) Then
			BeginTransaction();
			Try
				SetPrivilegedMode(True);
				Common.WriteDataToSecureStorage(QueryResult.Ref, QueryResult.DeletePassword);
				Common.WriteDataToSecureStorage(QueryResult.Ref, QueryResult.DeleteSMTPPassword, "SMTPPassword");
				SetPrivilegedMode(False);
				EmailAccount = QueryResult.Ref.GetObject();
				EmailAccount.DeletePassword = "";
				EmailAccount.DeleteSMTPPassword = "";
				EmailAccount.Write();
				CommitTransaction();
			Except
				RollbackTransaction();
			EndTry;
		EndIf;
	EndDo;
	
EndProcedure

// Creates the profile of the passed account for connection to the mail server.
//
// Parameters:
//  Account - CatalogRef.EmailAccounts - account.
//
// Returns:
//  InternetMailProfile - account profile.
//  Undefined - сannot get the account by reference.
//
Function InternetMailProfile(Account, ForReceiving = False) Export
	
	QueryText =
	"SELECT ALLOWED
	|	EmailAccounts.IncomingMailServer AS IMAPServerAddress,
	|	EmailAccounts.IncomingMailServerPort AS IMAPPort,
	|	EmailAccounts.UseSecureConnectionForIncomingMail AS IMAPUseSSL,
	|	EmailAccounts.User AS IMAPUser,
	|	EmailAccounts.UseSafeAuthorizationAtIncomingMailServer AS IMAPSecureAuthenticationOnly,
	|	EmailAccounts.IncomingMailServer AS POP3ServerAddress,
	|	EmailAccounts.IncomingMailServerPort AS POP3Port,
	|	EmailAccounts.UseSecureConnectionForIncomingMail AS POP3UseSSL,
	|	EmailAccounts.User AS User,
	|	EmailAccounts.UseSafeAuthorizationAtIncomingMailServer AS POP3SecureAuthenticationOnly,
	|	EmailAccounts.OutgoingMailServer AS SMTPServerAddress,
	|	EmailAccounts.OutgoingMailServerPort AS SMTPPort,
	|	EmailAccounts.UseSecureConnectionForOutgoingMail AS SMTPUseSSL,
	|	EmailAccounts.SignInBeforeSendingRequired AS POP3BeforeSMTP,
	|	EmailAccounts.SMTPUser AS SMTPUser,
	|	EmailAccounts.UseSafeAuthorizationAtOutgoingMailServer AS SMTPSecureAuthenticationOnly,
	|	EmailAccounts.Timeout AS Timeout,
	|	EmailAccounts.ProtocolForIncomingMail AS Protocol
	|FROM
	|	Catalog.EmailAccounts AS EmailAccounts
	|WHERE
	|	EmailAccounts.Ref = &Ref";
	
	Query = New Query(QueryText);
	Query.SetParameter("Ref", Account);
	Selection = Query.Execute().Select();
	
	Result = Undefined;
	If Selection.Next() Then
		IMAPPropertyList = "IMAPServerAddress,IMAPPort,IMAPUseSSL,IMAPUser,IMAPSecureAuthenticationOnly";
		POP3PropertyList = "POP3ServerAddress,POP3Port,POP3UseSSL,User,POP3SecureAuthenticationOnly";
		SMTPPropertyList = "SMTPServerAddress,SMTPPort,SMTPUseSSL,SMTPUser,SMTPSecureAuthenticationOnly";
		
		SetPrivilegedMode(True);
		Passwords = Common.ReadDataFromSecureStorage(Account, "Password,SMTPPassword");
		SetPrivilegedMode(False);
		
		Result = New InternetMailProfile;
		If ForReceiving Then
			If Selection.Protocol = "IMAP" Then
				RequiredProperties = IMAPPropertyList;
				Result.IMAPPassword = Passwords.Password;
			Else
				RequiredProperties = POP3PropertyList;
				Result.Password = Passwords.Password;
			EndIf;
		Else
			RequiredProperties = SMTPPropertyList;
			Result.SMTPPassword = Passwords.SMTPPassword;
			If Selection.Protocol <> "IMAP" AND Selection.POP3BeforeSMTP Then
				RequiredProperties = RequiredProperties + ",POP3BeforeSMTP," + POP3PropertyList;
				Result.Password = Passwords.Password;
			EndIf;
			If Selection.Protocol = "IMAP" Then
				RequiredProperties = RequiredProperties + "," + IMAPPropertyList;
				Result.IMAPPassword =Passwords.Password;
			EndIf;
		EndIf;
		RequiredProperties = RequiredProperties + ",Timeout";
		FillPropertyValues(Result, Selection, RequiredProperties);
	EndIf;
	
	Return Result;
	
EndFunction

// The function is used for integration with the Data exchange subsystem.
// Returns the reference to the infobase  email account that matches the email account of the 
// correspondent infobase for data exchange setup (see parameters).
// Account search is performed by a predefined item name or by address, or a new account is created if search fails.
// Attribute values of account of this infobase are matched with attribute values of correspondent account.
// Parameters:
//   ExchangePlanNode - CatalogObject.EmailAccounts - correspondent infobase email account obtained 
//                   from the data synchronization settings file deserialization by using the 
//                   ReadXML method.
//
// Returns:
//  CatalogObject.EmailAccounts - reference to this infobase account.
//
Function ThisInfobaseAccountByCorrespondentAccountData(CorrespondentAccount) Export
	
	ThisInfobaseAccount = Undefined;
	// For a predefined account - overwriting the predefined item of the current infobase.
	If CorrespondentAccount.Predefined Then
		ThisInfobaseAccount = Catalogs.EmailAccounts[CorrespondentAccount.PredefinedDataName].GetObject();
	Else
		// For a regular account - searching for an existing account with the same address.
		Query = New Query;
		Query.Text = "SELECT TOP 1
		|	Ref
		|FROM Catalog.EmailAccounts
		|WHERE EmailAddress = &EmailAddress";
		Query.SetParameter("EmailAddress", CorrespondentAccount.EmailAddress);
		Selection = Query.Execute().Select();
		If Selection.Next() Then
			ThisInfobaseAccount = Selection.Ref.GetObject();
		EndIf;
	EndIf;
	
	If ThisInfobaseAccount <> Undefined Then
		FillPropertyValues(ThisInfobaseAccount, CorrespondentAccount,,"PredefinedDataName, Parent, Owner, Ref");
	Else
		ThisInfobaseAccount = CorrespondentAccount;
	EndIf;
	
	ThisInfobaseAccount.Write();
	
	Return ThisInfobaseAccount;
	
EndFunction

// Returns email text types by description.
//
Function EmailTextTypes(Description) Export
	
	Return Enums.EmailTextTypes[Description];
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See BatchObjectModificationOverridable.OnDetermineObjectsWithEditableAttributes. 
Procedure OnDefineObjectsWithEditableAttributes(Objects) Export
	Objects.Insert(Metadata.Catalogs.EmailAccounts.FullName(), "AttributesToEditInBatchProcessing");
EndProcedure

// See SafeModeManagerOverridable.OnFillPermissionsToAccessExternalResources. 
Procedure OnFillPermissionsToAccessExternalResources(PermissionRequests) Export

	If Common.DataSeparationEnabled()
	   AND Not Common.SeparatedDataUsageAvailable() Then
		Return;
	EndIf;
	
	ModuleSafeModeManager = Common.CommonModule("SafeModeManager");
	AccountPermissions = Catalogs.EmailAccounts.AccountPermissions();
	For Each PermissionDetails In AccountPermissions Do
		PermissionRequests.Add(ModuleSafeModeManager.RequestToUseExternalResources(
			PermissionDetails.Value, PermissionDetails.Key));
	EndDo;

EndProcedure

// See StandardSubsystemsServer.OnReceiveDataFromMaster. 
Procedure OnReceiveDataFromMaster(DataItem, GetItem, SendBack, Sender) Export
	
	OnGetData(DataItem, GetItem, SendBack, Sender);
	
EndProcedure

// See StandardSubsystemsServer.OnReceiveDataFromSlave. 
Procedure OnReceiveDataFromSlave(DataItem, GetItem, SendBack, Sender) Export
	
	OnGetData(DataItem, GetItem, SendBack, Sender);
	
EndProcedure

// See DataExchangeOverridable.OnSetUpSubordinateDIBNode. 
Procedure OnSetUpSubordinateDIBNode() Export
	
	DisableAccounts();
	
EndProcedure

// See InfobaseUpdateSSL.OnAddUpdateHandlers. 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.InitialFilling = True;
	Handler.Procedure = "EmailOperationsInternal.FillSystemAccount";
	Handler.Version = "1.0.0.1";
	
	Handler = Handlers.Add();
	Handler.Procedure = "EmailOperationsInternal.FillNewAccountsAttributes";
	Handler.Version = "2.2.2.5";
	
	If Common.SubsystemExists("StandardSubsystems.Interactions") Then
		Handler = Handlers.Add();
		Handler.Version = "2.4.1.1";
		Handler.Procedure = "Catalogs.EmailAccounts.ProcessDataForMigrationToNewVersion";
		Handler.ExecutionMode = "Deferred";
		Handler.ID = New UUID("d57f7a36-46ca-4a52-baab-db960e3d376d");
		Handler.Comment = NStr("ru = 'Обновляет сведения о персональных учетных записях электронной почты.
			|До завершения обработки список персональных учетных записей электронной почты может быть неполным.'; 
			|en = 'Updates information on personal email accounts.
			|Until the processing is complete, the list of personal email accounts may be incomplete.'; 
			|pl = 'Zaktualizuje informacje o osobistych kontach e-mail.
			|Do zakończenia przetwarzania lista osobistych kont e-mail może być niepełna.';
			|es_ES = 'Actualiza la información de las cuentas personales del correo electrónico.
			|Antes de terminar los procesamientos de la lista de las cuentas del correo electrónico no puede ser completo.';
			|es_CO = 'Actualiza la información de las cuentas personales del correo electrónico.
			|Antes de terminar los procesamientos de la lista de las cuentas del correo electrónico no puede ser completo.';
			|tr = 'Kişisel e-posta hesaplarıyla ilgili bilgileri günceller. 
			|İşleme tamamlanmadan önce, kişisel e-posta hesaplarının listesi eksik olabilir.';
			|it = 'Aggiorna le informazioni sugli account email personali.
			|Fino al completamento dell''elaborazione, l''elenco di account email personali potrebbe essere incompleto.';
			|de = 'Aktualisiert persönliche E-Mail-Kontoinformationen.
			|Bevor die Verarbeitung abgeschlossen ist, ist die Liste der persönlichen E-Mail-Konten möglicherweise nicht vollständig.'");
		Handler.DeferredProcessingQueue = 1;
		Handler.UpdateDataFillingProcedure = "Catalogs.EmailAccounts.RegisterDataToProcessForMigrationToNewVersion";
		Handler.ObjectsToChange    = "Catalog.EmailAccounts";
		
		ObjectsToRead = New Array;
		ObjectsToRead.Add("Catalog.EmailAccounts");
		ModuleInteractions = Common.CommonModule("Interactions");
		ModuleInteractions.OnReceiveObjectsToReadOfEmailAccountsUpdateHandler(ObjectsToRead);
		
		Handler.ObjectsToRead = StrConcat(ObjectsToRead, ",");
	EndIf;
EndProcedure

// See AccessManagementOverridable.OnFillAccessKinds. 
Procedure OnFillAccessKinds(AccessKinds) Export
	
	AccessKind = AccessKinds.Add();
	AccessKind.Name = "EmailAccounts";
	AccessKind.Presentation = NStr("ru = 'Учетные записи электронной почты'; en = 'Email accounts'; pl = 'Konta poczty e-mail';es_ES = 'Cuentas de correos electrónicos';es_CO = 'Cuentas de correos electrónicos';tr = 'E-posta hesapları';it = 'Account email';de = 'E-Mail Konten'");
	AccessKind.ValuesType   = Type("CatalogRef.EmailAccounts");
	
EndProcedure

// See AccessManagementOverridable.OnFillListsWithAccessRestriction. 
Procedure OnFillListsWithAccessRestriction(Lists) Export
	
	Lists.Insert(Metadata.Catalogs.EmailAccounts, True);
	
EndProcedure

// See AccessManagementOverridable.OnFillMetadataObjectsAccessRestrictionsKinds. 
Procedure OnFillMetadataObjectsAccessRestrictionKinds(Details) Export
	
	If NOT Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		Return;
	EndIf;
	
	ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
	
	If ModuleAccessManagementInternal.AccessKindExists("EmailAccounts") Then
		
		Details = Details + "
		|Catalog.EmailAccounts.Read.EmailAccounts
		|Catalog.EmailAccounts.Read.Users
		|Catalog.EmailAccounts.Update.Users
		|";
		
	EndIf;
	
EndProcedure

// See CommonOverridable.OnAddMetadataObjectsRenaming. 
Procedure OnAddMetadataObjectsRenaming(Total) Export
	
	Library = "StandardSubsystems";
	
	OldName = "Role.EmailAccountsUsage";
	NewName  = "Role.ReadEmailAccounts";
	Common.AddRenaming(Total, "2.3.3.11", OldName, NewName, Library);
	
	OldName = "Role.ReadEmailAccounts";
	NewName  = "Role.AddEditEmailAccounts";
	Common.AddRenaming(Total, "2.4.1.1", OldName, NewName, Library);
	
EndProcedure

// See EmailOperations.SendEmail. 
Function SendEmail(Account, Email) Export
	
	Emails = CommonClientServer.ValueInArray(Email);
	Return SendEmails(Account, Emails)[Email];
	
EndFunction

// See EmailOperations.SendEmails. 
Function SendEmails(Account, Emails, ErrorText = Undefined) Export
	
	SenderAttributes = Common.ObjectAttributesValues(Account, "UserName,EmailAddress,SendBCCToThisAddress,UseForReceiving");
	
	SetSafeModeDisabled(True);
	Profile = InternetMailProfile(Account);
	SetSafeModeDisabled(False);
	
	SetSafeModeDisabled(True);
	
	EmailReceiptProtocol = InternetMailProtocol.POP3;
	If UseIMAPOnSendingEmails(Profile) Then
		EmailReceiptProtocol = InternetMailProtocol.IMAP;
	EndIf;
	
	ErrorText = "";
	Try
		Connection = New InternetMail;
		Connection.Logon(Profile, EmailReceiptProtocol);
		If EmailReceiptProtocol = InternetMailProtocol.IMAP Then
			DetermineSentEmailsFolder(Connection);
		EndIf;
	Except
		If EmailReceiptProtocol = InternetMailProtocol.IMAP AND Not SenderAttributes.UseForReceiving Then
			ErrorText = NStr("ru = 'Не удалось подключиться к серверу IMAP. Проверьте настройки учетной записи.'; en = 'Cannot connect to the IMAP server. Please check your account settings.'; pl = 'Nie można połączyć się z serwerem IMAP. Sprawdź ustawienia konta.';es_ES = 'No se puede conectar al servidor IMAP. Por favor, compruebe la configuración de su cuenta.';es_CO = 'No se puede conectar al servidor IMAP. Por favor, compruebe la configuración de su cuenta.';tr = 'IMAP sunucusuna bağlanamadı. Lütfen hesap ayarlarınızı kontrol edin.';it = 'Non è stato possibile al server IMAP. Verificare le impostazioni dell''account.';de = 'Keine Verbindung mit IMAP-Server. Bitte prüfen Sie Ihre Account-Einstellungen.'", CommonClientServer.DefaultLanguageCode());
			WriteLogEvent(EventNameSendEmail(), EventLogLevel.Error, Metadata.Catalogs.EmailAccounts,
				Account, ErrorText + Chars.LF + DetailErrorDescription(ErrorInfo()));
			EmailReceiptProtocol = InternetMailProtocol.POP3;
			Connection.Logon(Profile, EmailReceiptProtocol);
		Else
			Raise;
		EndIf;
	EndTry;
	
	EmailsSendingResults = New Map;
	
	ProcessTexts = InternetMailTextProcessing.DontProcess;
	
	Try
		For Each Email In Emails Do
			Email.SenderName = SenderAttributes.UserName;
			Email.From.DisplayName = SenderAttributes.UserName;
			Email.From.Address = SenderAttributes.EmailAddress;
			
			If SenderAttributes.SendBCCToThisAddress Then
				Recipient = Email.Bcc.Add(SenderAttributes.EmailAddress);
				Recipient.DisplayName = SenderAttributes.UserName;
			EndIf;
			
			EmailSendingResult = New Structure;
			EmailSendingResult.Insert("WrongRecipients", New Map);
			EmailSendingResult.Insert("SMTPEmailID", "");
			EmailSendingResult.Insert("IMAPEmailID", "");
			
			If EmailReceiptProtocol = InternetMailProtocol.IMAP Then
				Connection.Send(Email, ProcessTexts, InternetMailProtocol.IMAP);
				EmailSendingResult.Insert("IMAPEmailID", Email.MessageID);
				
				EmailFlags = New InternetMailMessageFlags;
				EmailFlags.Seen = True;
				EmailsFlags = New Map;
				EmailsFlags.Insert(Email.MessageID, EmailFlags);
				Connection.SetMessagesFlags(EmailsFlags);
			EndIf;
			
			WrongRecipients = Connection.Send(Email, ProcessTexts, InternetMailProtocol.SMTP);
			EmailSendingResult.Insert("WrongRecipients", WrongRecipients);
			EmailSendingResult.Insert("SMTPEmailID", Email.MessageID);
			
			If WrongRecipients.Count() > 0 Then
				ErrorsTexts = New Array;
				For Each WrongRecipient In WrongRecipients Do
					Recipient = WrongRecipient.Key;
					ErrorText = WrongRecipient.Value;
					ErrorsTexts.Add(StringFunctionsClientServer.SubstituteParametersToString(
						NStr("ru = '%1: %2'; en = '%1: %2'; pl = '%1: %2';es_ES = '%1: %2';es_CO = '%1: %2';tr = '%1: %2';it = '%1: %2';de = '%1: %2'"), Recipient, ErrorText));
				EndDo;
				ErrorText = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Отправка письма следующим получателям не выполнена:
					|%1'; 
					|en = 'The email was not sent to the following recipients:
					|%1'; 
					|pl = 'Wiadomość e-mail nie została wysłana do następujących odbiorców:
					|%1';
					|es_ES = 'El correo electrónico no fue enviado a los siguientes destinatarios:
					|%1';
					|es_CO = 'El correo electrónico no fue enviado a los siguientes destinatarios:
					|%1';
					|tr = 'Bu alıcılara e-posta gönderilmemiştir:
					|%1';
					|it = 'Invio della lettera ai seguenti mittenti non eseguito:
					|%1';
					|de = 'Die E-Mail ist zu den folgenden Empfängern nicht gesendet:
					|%1'", CommonClientServer.DefaultLanguageCode()), StrConcat(ErrorsTexts, Chars.LF));
				WriteLogEvent(EventNameSendEmail(), EventLogLevel.Error, , Account, ErrorText);
			EndIf;
			
			EmailsSendingResults.Insert(Email, EmailSendingResult);
		EndDo;
	Except
		Try
			Connection.Logoff();
		Except
			// Exception handling and logging is not required because
			// the original exception is passed to the calling code which handles the exception.
		EndTry;
		
		If EmailsSendingResults.Count() = 0 Then
			Raise;
		Else
			WriteLogEvent(EventNameSendEmail(), EventLogLevel.Error, ,
				Account, DetailErrorDescription(ErrorInfo()));
			ErrorText = BriefErrorDescription(ErrorInfo());
			Return EmailsSendingResults;
		EndIf;
	EndTry;
	
	Connection.Logoff();
	SetSafeModeDisabled(False);
	
	Return EmailsSendingResults;
	
EndFunction

Function PrepareEmail(Account, EmailParameters) Export
	
	Email = New InternetMailMessage;
	
	SenderAttributes = Common.ObjectAttributesValues(Account, "UserName,EmailAddress");
	Email.SenderName              = SenderAttributes.UserName;
	Email.From.DisplayName = SenderAttributes.UserName;
	Email.From.Address           = SenderAttributes.EmailAddress;
	
	If EmailParameters.Property("Subject") Then
		Email.Subject = EmailParameters.Subject;
	EndIf;
	
	SendTo = EmailParameters.SendTo;
	If TypeOf(SendTo) = Type("String") Then
		SendTo = CommonClientServer.ParseStringWithEmailAddresses(SendTo);
	EndIf;
	For Each RecipientEmailAddress In SendTo Do
		Recipient = Email.To.Add(RecipientEmailAddress.Address);
		Recipient.DisplayName = RecipientEmailAddress.Presentation;
	EndDo;
	
	If EmailParameters.Property("Cc") Then
		For Each CcRecipientEmailAddress In EmailParameters.Cc Do
			Recipient = Email.Cc.Add(CcRecipientEmailAddress.Address);
			Recipient.DisplayName = CcRecipientEmailAddress.Presentation;
		EndDo;
	EndIf;
	
	If EmailParameters.Property("BCC") Then
		For Each RecipientInfo In EmailParameters.BCC Do
			Recipient = Email.Bcc.Add(RecipientInfo.Address);
			Recipient.DisplayName = RecipientInfo.Presentation;
		EndDo;
	EndIf;
	
	If EmailParameters.Property("ReplyToAddress") Then
		For Each ReplyToEmailAddress In EmailParameters.ReplyToAddress Do
			ReturnEmailAddress = Email.ReplyTo.Add(ReplyToEmailAddress.Address);
			ReturnEmailAddress.DisplayName = ReplyToEmailAddress.Presentation;
		EndDo;
	EndIf;
	
	Attachments = Undefined;
	EmailParameters.Property("Attachments", Attachments);
	If Attachments <> Undefined Then
		For Each Attachment In Attachments Do
			If TypeOf(Attachment) = Type("Structure") Then
				FileData = Undefined;
				If IsTempStorageURL(Attachment.AddressInTempStorage) Then
					FileData = GetFromTempStorage(Attachment.AddressInTempStorage);
				Else
					FileData = Attachment.AddressInTempStorage;
				EndIf;
				NewAttachment = Email.Attachments.Add(FileData, Attachment.Presentation);
				If Attachment.Property("Encoding") AND Not IsBlankString(Attachment.Encoding) Then
					NewAttachment.Encoding = Attachment.Encoding;
				EndIf;
				If Attachment.Property("ID") Then
					NewAttachment.CID = Attachment.CID;
				EndIf;
			Else // For backward compatibility with version 2.2.1.
				If TypeOf(Attachment.Value) = Type("Structure") Then
					NewAttachment = Email.Attachments.Add(Attachment.Value.BinaryData, Attachment.Key);
					If Attachment.Value.Property("ID") Then
						NewAttachment.CID = Attachment.Value.ID;
					EndIf;
					If Attachment.Value.Property("Encoding") Then
						NewAttachment.Encoding = Attachment.Value.Encoding;
					EndIf;
					If Attachment.Value.Property("MIMEType") Then
						NewAttachment.MIMEType = Attachment.Value.MIMEType;
					EndIf;
					If Attachment.Value.Property("Name") Then
						NewAttachment.Name = Attachment.Value.Name;
					EndIf;
				Else
					InternetMailAttachment = Email.Attachments.Add(Attachment.Value, Attachment.Key);
					If TypeOf(Attachment.Value) = Type("InternetMailMessage") Then
						InternetMailAttachment.MIMEType = "message/rfc822";
					EndIf;
				EndIf;
			EndIf;
		EndDo;
	EndIf;
	
	For Each Attachment In Email.Attachments Do
		If Not ValueIsFilled(Attachment.MIMEType) Then
			MIMEType = DetermineMIMETypeByFileName(Attachment.Name);
			If ValueIsFilled(MIMEType) Then
				Attachment.MIMEType = MIMEType;
			EndIf;
		EndIf;
	EndDo;
	
	If EmailParameters.Property("BasisIDs") Then
		Email.SetField("References", EmailParameters.BasisIDs);
	EndIf;
	
	Body = "";
	EmailParameters.Property("Body", Body);
	
	TextType = Undefined;
	If TypeOf(Body) = Type("FormattedDocument") Then
		EmailContent = GetFormattedDocumentHTMLForEmail(Body);
		Body = EmailContent.HTMLText;
		Pictures = EmailContent.Pictures;
		TextType = InternetMailTextType.HTML;
		
		For Each Picture In Pictures Do
			PictureName = Picture.Key;
			PictureData = Picture.Value;
			Attachment = Email.Attachments.Add(PictureData.GetBinaryData(), PictureName);
			Attachment.CID = PictureName;
		EndDo;
	EndIf;
	Text = Email.Texts.Add(Body);
	If ValueIsFilled(TextType) Then
		Text.TextType = TextType;
	EndIf;
	
	If TextType = Undefined Then
		If EmailParameters.Property("TextType", TextType) Then
			If TypeOf(TextType) = Type("String") Then
				If      TextType = "HTML" Then
					Text.TextType = InternetMailTextType.HTML;
				ElsIf TextType = "RichText" Then
					Text.TextType = InternetMailTextType.RichText;
				Else
					Text.TextType = InternetMailTextType.PlainText;
				EndIf;
			ElsIf TypeOf(TextType) = Type("EnumRef.EmailTextTypes") Then
				If      TextType = Enums.EmailTextTypes.HTML
					OR TextType = Enums.EmailTextTypes.HTMLWithPictures Then
					Text.TextType = InternetMailTextType.HTML;
				ElsIf TextType = Enums.EmailTextTypes.RichText Then
					Text.TextType = InternetMailTextType.RichText;
				Else
					Text.TextType = InternetMailTextType.PlainText;
				EndIf;
			Else
				Text.TextType = TextType;
			EndIf;
		Else
			Text.TextType = InternetMailTextType.PlainText;
		EndIf;
	EndIf;
	
	Importance = Undefined;
	If EmailParameters.Property("Importance", Importance) Then
		Email.Importance = Importance;
	EndIf;
	
	Encoding = Undefined;
	If EmailParameters.Property("Encoding", Encoding) Then
		Email.Encoding = Encoding;
	EndIf;
	
	If EmailParameters.Property("RequestDeliveryReceipt") Then
		Email.RequestDeliveryReceipt = EmailParameters.RequestDeliveryReceipt;
	EndIf;
	
	If EmailParameters.Property("RequestReadReceipt") Then
		Email.RequestReadReceipt = EmailParameters.RequestReadReceipt;
		Email.ReadReceiptAddresses.Add(SenderAttributes.EmailAddress);
	EndIf;
	
	If Not EmailParameters.Property("ProcessTexts") Or EmailParameters.ProcessTexts Then
		Email.ProcessTexts();
	EndIf;
	
	Return Email;
	
EndFunction

// See InfobaseUpdateOverridable.OnDefineSettings 
Procedure OnDefineObjectsWithInitialFilling(Objects) Export
	
	Objects.Add(Metadata.Catalogs.EmailAccounts);
	
EndProcedure

#EndRegion

#Region Private

// Checks whether the predefined system email account is available for use.
// 
//
Function CheckSystemAccountAvailable() Export
	
	If NOT AccessRight("Read", Metadata.Catalogs.EmailAccounts) Then
		Return False;
	EndIf;
	
	QueryText =
		"SELECT ALLOWED
		|	EmailAccounts.Ref AS Ref
		|FROM
		|	Catalog.EmailAccounts AS EmailAccounts
		|WHERE
		|	EmailAccounts.Ref = &Ref";
	
	Query = New Query;
	Query.Text = QueryText;
	Query.Parameters.Insert("Ref", EmailOperations.SystemAccount());
	If Query.Execute().IsEmpty() Then
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

Procedure SendMessage(Val Account, Val SendOptions) Export
	Var SendTo, MailSubject, Body, Attachments, ReplyToAddress, TextType, Cc, BCC, MailProtocol, Connection;
	
	SendOptions.Property("Connection", Connection);
	SendOptions.Property("MailProtocol", MailProtocol);
	SendOptions.Insert("MessageID", "");
	SendOptions.Insert("WrongRecipients", New Map);
	
	If Not SendOptions.Property("Subject", MailSubject) Then
		MailSubject = "";
	EndIf;
	
	If Not SendOptions.Property("Body", Body) Then
		Body = "";
	EndIf;
	
	SendTo = SendOptions.SendTo;
	
	If TypeOf(SendTo) = Type("String") Then
		SendTo = CommonClientServer.ParseStringWithEmailAddresses(SendTo);
	EndIf;
	
	SendOptions.Property("Attachments", Attachments);
	
	Email = New InternetMailMessage;
	Email.Subject = MailSubject;
	
	// Generating recipient address.
	For Each RecipientEmailAddress In SendTo Do
		Recipient = Email.To.Add(RecipientEmailAddress.Address);
		Recipient.DisplayName = RecipientEmailAddress.Presentation;
	EndDo;
	
	// Generating recipient addresses for the Cc field.
	If SendOptions.Property("Cc", Cc) Then
		For Each CcRecipientEmailAddress In Cc Do
			Recipient = Email.Cc.Add(CcRecipientEmailAddress.Address);
			Recipient.DisplayName = CcRecipientEmailAddress.Presentation;
		EndDo;
	EndIf;
	
	// Generating recipient addresses for the BCC field.
	If SendOptions.Property("BCC", BCC) Then
		For Each RecipientInfo In BCC Do
			Recipient = Email.Bcc.Add(RecipientInfo.Address);
			Recipient.DisplayName = RecipientInfo.Presentation;
		EndDo;
	EndIf;
	
	// Generating reply address, if required.
	If SendOptions.Property("ReplyToAddress", ReplyToAddress) Then
		For Each ReplyToEmailAddress In ReplyToAddress Do
			ReturnEmailAddress = Email.ReplyTo.Add(ReplyToEmailAddress.Address);
			ReturnEmailAddress.DisplayName = ReplyToEmailAddress.Presentation;
		EndDo;
	EndIf;
	
	// Getting sender attributes.
	SenderAttributes = Common.ObjectAttributesValues(Account, "UserName,EmailAddress,SendBCCToThisAddress");
	
	// Adding sender name to the message.
	Email.SenderName              = SenderAttributes.UserName;
	Email.From.DisplayName = SenderAttributes.UserName;
	Email.From.Address           = SenderAttributes.EmailAddress;
	
	// Adding sender address to BCC.
	If SenderAttributes.SendBCCToThisAddress Then
		Recipient = Email.Bcc.Add(SenderAttributes.EmailAddress);
		Recipient.DisplayName = SenderAttributes.UserName;
	EndIf;
	
	// Adding attachments to the email.
	If Attachments <> Undefined Then
		For Each Attachment In Attachments Do
			If TypeOf(Attachment) = Type("Structure") Then
				FileData = Undefined;
				If IsTempStorageURL(Attachment.AddressInTempStorage) Then
					FileData = GetFromTempStorage(Attachment.AddressInTempStorage);
				Else
					FileData = Attachment.AddressInTempStorage;
				EndIf;
				NewAttachment = Email.Attachments.Add(FileData, Attachment.Presentation);
				If Attachment.Property("Encoding") AND Not IsBlankString(Attachment.Encoding) Then
					NewAttachment.Encoding = Attachment.Encoding;
				EndIf;
				If Attachment.Property("ID") Then
					NewAttachment.CID = Attachment.ID;
				EndIf;
			Else // For backward compatibility with version 2.2.1.
				If TypeOf(Attachment.Value) = Type("Structure") Then
					NewAttachment = Email.Attachments.Add(Attachment.Value.BinaryData, Attachment.Key);
					If Attachment.Value.Property("ID") Then
						NewAttachment.CID = Attachment.Value.ID;
					EndIf;
					If Attachment.Value.Property("Encoding") Then
						NewAttachment.Encoding = Attachment.Value.Encoding;
					EndIf;
					If Attachment.Value.Property("MIMEType") Then
						NewAttachment.MIMEType = Attachment.Value.MIMEType;
					EndIf;
					If Attachment.Value.Property("Name") Then
						NewAttachment.Name = Attachment.Value.Name;
					EndIf;
				Else
					InternetMailAttachment = Email.Attachments.Add(Attachment.Value, Attachment.Key);
					If TypeOf(Attachment.Value) = Type("InternetMailMessage") Then
						InternetMailAttachment.MIMEType = "message/rfc822";
					EndIf;
				EndIf;
			EndIf;
		EndDo;
	EndIf;
	
	For Each Attachment In Email.Attachments Do
		If Not ValueIsFilled(Attachment.MIMEType) Then
			MIMEType = DetermineMIMETypeByFileName(Attachment.Name);
			If ValueIsFilled(MIMEType) Then
				Attachment.MIMEType = MIMEType;
			EndIf;
		EndIf;
	EndDo;
	
	If SendOptions.Property("BasisIDs") Then
		Email.SetField("References", SendOptions.BasisIDs);
	EndIf;
	
	TextType = Undefined;
	If TypeOf(Body) = Type("FormattedDocument") Then
		EmailContent = GetFormattedDocumentHTMLForEmail(Body);
		Body = EmailContent.HTMLText;
		Pictures = EmailContent.Pictures;
		TextType = InternetMailTextType.HTML;
		
		AdditionalAttachments = New Array;
		For Each Picture In Pictures Do
			PictureName = Picture.Key;
			PictureData = Picture.Value;
			Attachment = Email.Attachments.Add(PictureData.GetBinaryData(), PictureName);
			Attachment.CID = PictureName;
		EndDo;
	EndIf;
	Text = Email.Texts.Add(Body);
	If ValueIsFilled(TextType) Then
		Text.TextType = TextType;
	EndIf;
	
	If TextType = Undefined Then
		If SendOptions.Property("TextType", TextType) Then
			If TypeOf(TextType) = Type("String") Then
				If      TextType = "HTML" Then
					Text.TextType = InternetMailTextType.HTML;
				ElsIf TextType = "RichText" Then
					Text.TextType = InternetMailTextType.RichText;
				Else
					Text.TextType = InternetMailTextType.PlainText;
				EndIf;
			ElsIf TypeOf(TextType) = Type("EnumRef.EmailTextTypes") Then
				If      TextType = Enums.EmailTextTypes.HTML
					  OR TextType = Enums.EmailTextTypes.HTMLWithPictures Then
					Text.TextType = InternetMailTextType.HTML;
				ElsIf TextType = Enums.EmailTextTypes.RichText Then
					Text.TextType = InternetMailTextType.RichText;
				Else
					Text.TextType = InternetMailTextType.PlainText;
				EndIf;
			Else
				Text.TextType = TextType;
			EndIf;
		Else
			Text.TextType = InternetMailTextType.PlainText;
		EndIf;
	EndIf;

	Importance = Undefined;
	If SendOptions.Property("Importance", Importance) Then
		Email.Importance = Importance;
	EndIf;
	
	Encoding = Undefined;
	If SendOptions.Property("Encoding", Encoding) Then
		Email.Encoding = Encoding;
	EndIf;

	If SendOptions.Property("ProcessTexts") AND NOT SendOptions.ProcessTexts Then
		ProcessMessageText = InternetMailTextProcessing.DontProcess;
	Else
		ProcessMessageText = InternetMailTextProcessing.Process;
	EndIf;
	
	If SendOptions.Property("RequestDeliveryReceipt") Then
		Email.RequestDeliveryReceipt = SendOptions.RequestDeliveryReceipt;
		Email.DeliveryReceiptAddresses.Add(SenderAttributes.EmailAddress);
	EndIf;
	
	If SendOptions.Property("RequestReadReceipt") Then
		Email.RequestReadReceipt = SendOptions.RequestReadReceipt;
		Email.ReadReceiptAddresses.Add(SenderAttributes.EmailAddress);
	EndIf;
	
	NewConnection = TypeOf(Connection) <> Type("InternetMail");
	If NewConnection Then
		SetSafeModeDisabled(True);
		Profile = InternetMailProfile(Account);
		Connection = New InternetMail;
		Connection.Logon(Profile);
	EndIf;

	Try
		WrongRecipients = Connection.Send(Email, ProcessMessageText, 
			?(MailProtocol = "IMAP", InternetMailProtocol.IMAP, InternetMailProtocol.SMTP));
	Except
		If NewConnection Then	
			Try
				Connection.Logoff();
			Except
				// Exception handling and logging is not required because
				// the original exception is passed to the calling code which handles the exception.
			EndTry;
		EndIf;
		Raise;
	EndTry;
		
	If NewConnection Then	
		Connection.Logoff();
		SetSafeModeDisabled(False);
	EndIf;
		
	SendOptions.Insert("MessageID", Email.MessageID);
	SendOptions.Insert("WrongRecipients", WrongRecipients);
	
EndProcedure

Function DownloadMessages(Val Account, Val ImportParameters = Undefined) Export
	
	// Used to check whether authorization at the mail server can be performed.
	Var TestMode;
	
	// Receive only message headers.
	Var GetHeaders;
	
	// Convert messages to simple type
	Var CastMessagesToType;
	
	// Headers or IDs of messages whose full texts are to be retrieved.
	Var HeadersIDs;
	
	If ImportParameters.Property("TestMode") Then
		TestMode = ImportParameters.TestMode;
	Else
		TestMode = False;
	EndIf;
	
	If ImportParameters.Property("GetHeaders") Then
		GetHeaders = ImportParameters.GetHeaders;
	Else
		GetHeaders = False;
	EndIf;
	
	SetSafeModeDisabled(True);
	Profile = InternetMailProfile(Account, True);
	SetSafeModeDisabled(False);
	
	If ImportParameters.Property("HeadersIDs") Then
		HeadersIDs = ImportParameters.HeadersIDs;
	Else
		HeadersIDs = New Array;
	EndIf;
	
	MessageSetToDelete = New Array;
	
	Protocol = InternetMailProtocol.POP3;
	If Common.ObjectAttributeValue(Account, "ProtocolForIncomingMail") = "IMAP" Then
		Protocol = InternetMailProtocol.IMAP;
	EndIf;
	
	SetSafeModeDisabled(True);
	Connection = New InternetMail;
	Connection.Logon(Profile, Protocol);
	Try
		If GetHeaders Then
			EmailSet = Connection.GetHeaders();
		ElsIf Not TestMode Then
			TransportSettings = Common.ObjectAttributesValues(Account, "ProtocolForIncomingMail,KeepMessageCopiesAtServer,KeepMailAtServerPeriod");
			If TransportSettings.ProtocolForIncomingMail = "IMAP" Then
				TransportSettings.KeepMessageCopiesAtServer = True;
				TransportSettings.KeepMailAtServerPeriod = 0;
			EndIf;
			
			If TransportSettings.KeepMessageCopiesAtServer Then
				If HeadersIDs.Count() = 0 AND TransportSettings.KeepMailAtServerPeriod > 0 Then
					Headers = Connection.GetHeaders();
					MessageSetToDelete = New Array;
					For Each ItemHeader In Headers Do
						CurrentDate = CurrentSessionDate();
						DateDifference = (CurrentDate - ItemHeader.PostingDate) / (3600*24);
						If DateDifference >= TransportSettings.KeepMailAtServerPeriod Then
							MessageSetToDelete.Add(ItemHeader);
						EndIf;
					EndDo;
				EndIf;
				AutomaticallyDeleteMessagesOnChoiceFromServer = False;
			Else
				AutomaticallyDeleteMessagesOnChoiceFromServer = True;
			EndIf;
			
			EmailSet = Connection.Get(AutomaticallyDeleteMessagesOnChoiceFromServer, HeadersIDs);
			
			If MessageSetToDelete.Count() > 0 Then
				Connection.DeleteMessages(MessageSetToDelete);
			EndIf;
		EndIf;
	
		Connection.Logoff();
	Except
		Try
			Connection.Logoff();
		Except
			// Exception handling and logging is not required because
			// the original exception is passed to the calling code which handles the exception.
		EndTry;
		Raise;
	EndTry;
	SetSafeModeDisabled(False);
	
	If TestMode Then
		Return True;
	EndIf;
	
	If ImportParameters.Property("CastMessagesToType") Then
		CastMessagesToType = ImportParameters.CastMessagesToType;
	Else
		CastMessagesToType = True;
	EndIf;
	
	MessageSet = EmailSet;
	If CastMessagesToType Then
		If ImportParameters.Property("Columns") Then
			MessageSet = ConvertedEmailSet(EmailSet, ImportParameters.Columns);
		Else
			MessageSet = ConvertedEmailSet(EmailSet);
		EndIf;
	EndIf;
	
	Return MessageSet;
	
EndFunction

// Converts a set of emails to a value table with columns of simple types.
// Column values of the types not supported on the client are converted to the String type.
//
Function ConvertedEmailSet(Val EmailSet, Val Columns = Undefined)
	
	Result = CreateAdaptedEmailMessageDetails(Columns);
	
	For Each EmailMessage In EmailSet Do
		NewRow = Result.Add();
		For Each ColumnDescription In Columns Do
			EmailField = EmailMessage[ColumnDescription];
			
			If TypeOf(EmailField) = Type("String") Then
				EmailField = CommonClientServer.DeleteProhibitedXMLChars(EmailField);
			ElsIf TypeOf(EmailField) = Type("InternetMailAddresses") Then
				EmailField = AddressesPresentation(EmailField);
			ElsIf TypeOf(EmailField) = Type("InternetMailAddress") Then
				EmailField = AddressPresentation(EmailField);
			ElsIf TypeOf(EmailField) = Type("InternetMailAttachments") Then
				Attachments = New Map;
				For Each Attachment In EmailField Do
					If TypeOf(Attachment.Data) = Type("BinaryData") Then
						Attachments.Insert(Attachment.Name, Attachment.Data);
					Else
						FillEmailAttachments(Attachments, Attachment.Data);
					EndIf;
				EndDo;
				EmailField = Attachments;
			ElsIf TypeOf(EmailField) = Type("InternetMailTexts") Then
				Texts = New Array;
				For Each NextText In EmailField Do
					TextDetails = New Map;
					TextDetails.Insert("Data", NextText.Data);
					TextDetails.Insert("Encoding", NextText.Encoding);
					TextDetails.Insert("Text", CommonClientServer.DeleteProhibitedXMLChars(NextText.Text));
					TextDetails.Insert("TextType", String(NextText.TextType));
					Texts.Add(TextDetails);
				EndDo;
				EmailField = Texts;
			ElsIf TypeOf(EmailField) = Type("InternetMailMessageImportance")
				Or TypeOf(EmailField) = Type("InternetMailMessageNonASCIISymbolsEncodingMode") Then
				EmailField = String(EmailField);
			EndIf;
			
			NewRow[ColumnDescription] = EmailField;
		EndDo;
	EndDo;
	
	Return Result;
	
EndFunction

Function AddressPresentation(InternetMailAddress)
	Result = InternetMailAddress.Address;
	If Not IsBlankString(InternetMailAddress.DisplayName) Then
		Result = InternetMailAddress.DisplayName + " <" + Result + ">";
	EndIf;
	Return Result;
EndFunction

Function AddressesPresentation(InternetMailAddresses)
	Result = "";
	For Each InternetMailAddress In InternetMailAddresses Do
		Result = ?(IsBlankString(Result), "", Result + "; ") + AddressPresentation(InternetMailAddress);
	EndDo;
	Return Result;
EndFunction

Procedure FillEmailAttachments(Attachments, Email)
	
	For Each Attachment In Email.Attachments Do
		AttachmentName = Attachment.Name;
		If TypeOf(Attachment.Data) = Type("BinaryData") Then
			Attachments.Insert(Attachment.Name, Attachment.Data);
		Else
			FillEmailAttachments(Attachments, Attachment.Data);
		EndIf;
	EndDo;
	
	EmailPresentation = EmailPresentation(Email.Subject, Email.PostingDate);
	
	Index = 0;
	For Each Text In Email.Texts Do
		If Text.TextType = InternetMailTextType.HTML Then
			Extension = "html";
		ElsIf Text.TextType = InternetMailTextType.PlainText Then
			Extension = "txt";
		Else
			Extension = "rtf";
		EndIf;
		AttachmentsTextName = "";
		While AttachmentsTextName = "" Or Attachments.Get(AttachmentsTextName) <> Undefined Do
			Index = Index + 1;
			AttachmentsTextName = StringFunctionsClientServer.SubstituteParametersToString("%1 - (%2).%3", EmailPresentation, Index, Extension);
		EndDo;
		Attachments.Insert(AttachmentsTextName, Text.Data);
	EndDo;
	
EndProcedure

// Prepares a table for storing messages retrieved from the mail server.
// 
// 
// Parameters:
// Columns - String - list of message fields (comma-separated) to be written to the table.
//                     The parameter changes the type to Array.
// Returns
// ValueTable - empty value table with columns.
//
Function CreateAdaptedEmailMessageDetails(Columns = Undefined)
	
	If Columns <> Undefined
	   AND TypeOf(Columns) = Type("String") Then
		Columns = StrSplit(Columns, ",");
		For Index = 0 To Columns.Count()-1 Do
			Columns[Index] = TrimAll(Columns[Index]);
		EndDo;
	EndIf;
	
	DefaultColumnArray = New Array;
	DefaultColumnArray.Add("Importance");
	DefaultColumnArray.Add("Attachments");
	DefaultColumnArray.Add("PostingDate");
	DefaultColumnArray.Add("DateReceived");
	DefaultColumnArray.Add("Header");
	DefaultColumnArray.Add("SenderName");
	DefaultColumnArray.Add("UID");
	DefaultColumnArray.Add("Cc");
	DefaultColumnArray.Add("ReplyTo");
	DefaultColumnArray.Add("From");
	DefaultColumnArray.Add("To");
	DefaultColumnArray.Add("Size");
	DefaultColumnArray.Add("Subject");
	DefaultColumnArray.Add("Texts");
	DefaultColumnArray.Add("Encoding");
	DefaultColumnArray.Add("NonASCIISymbolsEncodingMode");
	DefaultColumnArray.Add("Partial");
	
	If Columns = Undefined Then
		Columns = DefaultColumnArray;
	EndIf;
	
	Result = New ValueTable;
	
	For Each ColumnDescription In Columns Do
		Result.Columns.Add(ColumnDescription);
	EndDo;
	
	Return Result;
	
EndFunction

// Fills a system account with default values.
//
Procedure FillSystemAccount() Export
	
	Account = EmailOperations.SystemAccount().GetObject();
	Account.FillObjectWithDefaultValues();
	InfobaseUpdate.WriteData(Account);
	
EndProcedure

// Fills new attributes of the EmailAccounts catalog.
Procedure FillNewAccountsAttributes() Export
	
	QueryText = 
	"SELECT
	|	""POP"" AS ProtocolForIncomingMail,
	|	CASE
	|		WHEN EmailAccounts.SMTPAuthentication = VALUE(Enum.SMTPAuthenticationOptions.POP3BeforeSMTP)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS SignInBeforeSendingRequired,
	|	CASE
	|		WHEN EmailAccounts.POP3AuthenticationMode <> VALUE(Enum.POP3AuthenticationMethods.General)
	|				AND EmailAccounts.POP3AuthenticationMode <> VALUE(Enum.POP3AuthenticationMethods.EmptyRef)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS UseSafeAuthorizationAtIncomingMailServer,
	|	CASE
	|		WHEN EmailAccounts.SMTPAuthenticationMode = VALUE(Enum.SMTPAuthenticationMethods.CramMD5)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS UseSafeAuthorizationAtOutgoingMailServer,
	|	EmailAccounts.Ref AS Ref
	|FROM
	|	Catalog.EmailAccounts AS EmailAccounts
	|WHERE
	|	EmailAccounts.DeletionMark = FALSE";
	
	Query = New Query(QueryText);
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		Account = Selection.Ref.GetObject();
		FillPropertyValues(Account, Selection, , "Ref");
		InfobaseUpdate.WriteData(Account);
	EndDo;
	
EndProcedure

// Internal function, used for checking email accounts.
//
Procedure CheckSendReceiveEmailAvailability(Account, ErrorMessage, AdditionalMessage) Export
	
	AccountSettings = Common.ObjectAttributesValues(Account, "UseForSending,UseForReceiving");
	
	ErrorMessage = "";
	AdditionalMessage = "";
	
	If AccountSettings.UseForSending Then
		Try
			CheckCanConnectToMailServer(Account, False);
		Except
			ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Ошибка в настройках исходящей почты: %1'; en = 'An error occurred in outgoing mail settings: %1'; pl = 'Błąd w ustawieniach poczty wychodzącej: %1';es_ES = 'Error en los ajustes del correo saliente: %1';es_CO = 'Error en los ajustes del correo saliente: %1';tr = 'Giden posta ayarlarında hata var: %1';it = 'Si è registrato un errore nelle impostazioni email in uscita: %1';de = 'Fehler in den Einstellungen für ausgehende E-Mails: %1'"), BriefErrorDescription(ErrorInfo()));
		EndTry;
		If Not AccountSettings.UseForReceiving Then
			AdditionalMessage = Chars.LF + NStr("ru = '(Выполнена проверка отправки электронных сообщений.)'; en = '(Email message sending check is performed.)'; pl = '(Sprawdzanie wysyłania wiadomości e-mail zostało zakończone.)';es_ES = '(Revisión del envío del correo electrónico se ha finalizado.)';es_CO = '(Revisión del envío del correo electrónico se ha finalizado.)';tr = '(Eposta gönderme kontrolü tamamlandı.)';it = '(Il messaggio Email di controllo invio è stato effettuato).';de = '(E-Mail-Sendeprüfung ist abgeschlossen.)'");
		EndIf;
	EndIf;
	
	If AccountSettings.UseForReceiving Then
		Try
			CheckCanConnectToMailServer(Account, True);
		Except
			If ValueIsFilled(ErrorMessage) Then
				ErrorMessage = ErrorMessage + Chars.LF;
			EndIf;
			
			ErrorMessage = ErrorMessage + StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Ошибка в настройках входящей почты: %1'; en = 'An error occurred in incoming mail settings: %1'; pl = 'Błąd w ustawieniach poczty przychodzącej: %1';es_ES = 'Error en los ajustes del correo entrante: %1';es_CO = 'Error en los ajustes del correo entrante: %1';tr = 'Gelen posta ayarlarında hata var: %1';it = 'Si è registrato un errore nelle impostazioni email in ingresso: %1';de = 'Fehler in den Einstellungen für eingehende E-Mails: %1'"),
				BriefErrorDescription(ErrorInfo()) );
		EndTry;
		If Not AccountSettings.UseForSending Then
			AdditionalMessage = Chars.LF + NStr("ru = '(Выполнена проверка получения электронных сообщений.)'; en = '(Email message receiving check is performed.)'; pl = '(Sprawdzanie otrzymania wiadomości e-mail zostało zakończone.)';es_ES = '(Revisión de la recepción de correos electrónicos se ha finalizado).';es_CO = '(Revisión de la recepción de correos electrónicos se ha finalizado).';tr = '(E-posta alma kontrolü tamamlandı).';it = '(Il controllo della ricezione del messaggio Email è stato eseguito)';de = '(E-Mail Empfangsprüfung ist abgeschlossen).'");
		EndIf;
	EndIf;
	
EndProcedure

Procedure CheckCanConnectToMailServer(Val Account, IncomingMail)
	
	SetSafeModeDisabled(True);
	Profile = InternetMailProfile(Account, IncomingMail);
	Connection = New InternetMail;
	
	If IncomingMail Then
		Protocol = InternetMailProtocol.POP3;
		If Common.ObjectAttributeValue(Account, "ProtocolForIncomingMail") = "IMAP" Then
			Protocol = InternetMailProtocol.IMAP;
		EndIf;
		Connection.Logon(Profile, Protocol);
	Else
		Connection.Logon(Profile);
	EndIf;
	
	Connection.Logoff();
	
EndProcedure

// Disables all acounts. The procedure is used on DIB node initial setup.
Procedure DisableAccounts()
	
	QueryText =
	"SELECT
	|	EmailAccounts.Ref
	|FROM
	|	Catalog.EmailAccounts AS EmailAccounts
	|WHERE
	|	EmailAccounts.UseForReceiving
	|
	|UNION ALL
	|
	|SELECT
	|	EmailAccounts.Ref
	|FROM
	|	Catalog.EmailAccounts AS EmailAccounts
	|WHERE
	|	EmailAccounts.UseForSending";
	
	Query = New Query(QueryText);
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		Account = Selection.Ref.GetObject();
		Account.UseForSending = False;
		Account.UseForReceiving = False;
		Account.DataExchange.Load = True;
		Account.Write();
	EndDo;
	
EndProcedure

// Handler for OnReceiveDataFromMaster and OnReceiveDataFromSlave events that occur during data 
// exchange in a distributed infobase.
//
// Parameters:
// see descriptions of the relevant event handlers in the Syntax Assistant.
// 
Procedure OnGetData(DataItem, GetItem, SendBack, Sender)
	
	If TypeOf(DataItem) = Type("CatalogObject.EmailAccounts") Then
		If DataItem.IsNew() Then
			DataItem.UseForReceiving = False;
			DataItem.UseForSending = False;
		Else
			DataItem.UseForReceiving = Common.ObjectAttributeValue(DataItem.Ref, "UseForReceiving");
			DataItem.UseForSending = Common.ObjectAttributeValue(DataItem.Ref, "UseForSending");
		EndIf;
	EndIf;
	
EndProcedure

Function PrepareAttachments(Attachments, SettingsForSaving) Export
	Var ZipFileWriter, ArchiveName;
	
	Result = New Array;
	
	// Preparing the archive
	HasFilesAddedToArchive = False;
	If SettingsForSaving.PackToArchive Then
		ArchiveName = GetTempFileName("zip");
		ZipFileWriter = New ZipFileWriter(ArchiveName);
	EndIf;
	
	// preparing a temporary folder
	TempFolderName = GetTempFileName();
	CreateDirectory(TempFolderName);
	UsedFilesNames = New Map;
	
	SelectedSaveFormats = SettingsForSaving.SaveFormats;
	FormatsTable = StandardSubsystemsServer.SpreadsheetDocumentSaveFormatsSettings();
	
	FileNameForArchive = Undefined;
	For Index = -Attachments.UBound() To 0 Do
		Attachment = Attachments[-Index];
		SpreadsheetDocument = GetFromTempStorage(Attachment.AddressInTempStorage);
		If TypeOf(SpreadsheetDocument) = Type("SpreadsheetDocument") Then 
			AddressInTempStorage = Attachment.AddressInTempStorage;
			Attachments.Delete(-Index);
		Else
			Continue;
		EndIf;
		
		If EvalOutputUsage(SpreadsheetDocument) = UseOutput.Disable Then
			Continue;
		EndIf;
		
		If SpreadsheetDocument.Protection Then
			Continue;
		EndIf;
		
		If SpreadsheetDocument.TableHeight = 0 Then
			Continue;
		EndIf;
		
		For Each FileType In SelectedSaveFormats Do
			FormatSettings = FormatsTable.FindRows(New Structure("SpreadsheetDocumentFileType", FileType))[0];
			FileName = CommonClientServer.ReplaceProhibitedCharsInFileName(Attachment.Presentation);
			If FileNameForArchive = Undefined Then
				FileNameForArchive = FileName + ".zip";
			Else
				FileNameForArchive = NStr("ru = 'Документы'; en = 'Documents'; pl = 'Dokumenty';es_ES = 'Documentos';es_CO = 'Documentos';tr = 'Belgeler';it = 'Documenti';de = 'Dokumente'") + ".zip";
			EndIf;
			FileName = FileName + "." + FormatSettings.Extension;
			
			If SettingsForSaving.TransliterateFilesNames Then
				FileName = StringFunctionsClientServer.LatinString(FileName);
			EndIf;
			
			FullFileName = UniqueFileName(CommonClientServer.AddLastPathSeparator(TempFolderName) + FileName);
			SpreadsheetDocument.Write(FullFileName, FileType);
			
			If FileType = SpreadsheetDocumentFileType.HTML Then
				InsertPicturesToHTML(FullFileName);
			EndIf;
			
			If ZipFileWriter <> Undefined Then 
				HasFilesAddedToArchive = True;
				ZipFileWriter.Add(FullFileName);
			Else
				BinaryData = New BinaryData(FullFileName);
				AddressInTempStorage = PutToTempStorage(BinaryData, New UUID);
				FileDetails = New Structure;
				FileDetails.Insert("Presentation", FileName);
				FileDetails.Insert("AddressInTempStorage", AddressInTempStorage);
				If FileType = SpreadsheetDocumentFileType.ANSITXT Then
					FileDetails.Insert("Encoding", "windows-1251");
				EndIf;
				Result.Add(FileDetails);
			EndIf;
		EndDo;
	EndDo;
	
	// If the archive is prepared, writing it and putting in the temporary storage.
	If HasFilesAddedToArchive Then 
		ZipFileWriter.Write();
		ArchiveFile = New File(ArchiveName);
		BinaryData = New BinaryData(ArchiveName);
		
		// Using the existing temporary storage address related to the form.
		PutToTempStorage(BinaryData, AddressInTempStorage);
		
		FileDetails = New Structure;
		FileDetails.Insert("Presentation", FileNameForArchive);
		FileDetails.Insert("AddressInTempStorage", AddressInTempStorage);
		Result.Add(FileDetails);
	EndIf;
	
	For Each FileDetails In Result Do
		Attachments.Add(FileDetails);
	EndDo;
		
	DeleteFiles(TempFolderName);
	If ValueIsFilled(ArchiveName) Then
		DeleteFiles(ArchiveName);
	EndIf;
	
	Return Result;
	
EndFunction

Function EvalOutputUsage(SpreadsheetDocument)
	If SpreadsheetDocument.Output = UseOutput.Auto Then
		Return ?(AccessRight("Output", Metadata), UseOutput.Enable, UseOutput.Disable);
	Else
		Return SpreadsheetDocument.Output;
	EndIf;
EndFunction

Function UniqueFileName(FileName)
	
	File = New File(FileName);
	NameWithoutExtension = File.BaseName;
	Extension = File.Extension;
	Folder = File.Path;
	
	Counter = 1;
	While File.Exist() Do
		Counter = Counter + 1;
		File = New File(Folder + NameWithoutExtension + " (" + Counter + ")" + Extension);
	EndDo;
	
	Return File.FullName;

EndFunction

Procedure InsertPicturesToHTML(HTMLFileName)
	
	TextDocument = New TextDocument();
	TextDocument.Read(HTMLFileName, TextEncoding.UTF8);
	HTMLText = TextDocument.GetText();
	
	HTMLFile = New File(HTMLFileName);
	
	PicturesFolderName = HTMLFile.BaseName + "_files";
	PathToPicturesFolder = StrReplace(HTMLFile.FullName, HTMLFile.Name, PicturesFolderName);
	
	// The folder is only for pictures.
	PicturesFiles = FindFiles(PathToPicturesFolder, "*");
	
	For Each PictureFile In PicturesFiles Do
		PictureInText = Base64String(New BinaryData(PictureFile.FullName));
		PictureInText = "data:image/" + Mid(PictureFile.Extension,2) + ";base64," + Chars.LF + PictureInText;
		
		HTMLText = StrReplace(HTMLText, PicturesFolderName + "\" + PictureFile.Name, PictureInText);
	EndDo;
		
	TextDocument.SetText(HTMLText);
	TextDocument.Write(HTMLFileName, TextEncoding.UTF8);
	
EndProcedure

Function SubsystemSettings() Export
	Settings = New Structure;
	Settings.Insert("CanReceiveEmails", Not StandardSubsystemsServer.IsBaseConfigurationVersion());
	EmailOverridable.OnDefineSettings(Settings);
	Return Settings;
EndFunction

Function DetermineMIMETypeByFileName(FileName)
	Extension = "";
	Position = StrFind(FileName, ".", SearchDirection.FromEnd);
	If Position > 0 Then
		Extension = Lower(Mid(FileName, Position + 1));
	EndIf;
	Return MIMETypes()[Extension];
EndFunction

Function MIMETypes()
	Result = New Map;
	
	Result.Insert("json", "application/json");
	Result.Insert("pdf", "application/pdf");
	Result.Insert("xhtml", "application/xhtml+xml");
	Result.Insert("zip", "application/zip");
	Result.Insert("gzip", "application/gzip");
	
	Result.Insert("aac", "audio/aac");
	Result.Insert("ogg", "audio/ogg");
	Result.Insert("wma", "audio/x-ms-wma");
	Result.Insert("wav", "audio/vnd.wave");
	
	Result.Insert("gif", "image/gif");
	Result.Insert("jpeg", "image/jpeg");
	Result.Insert("png", "image/png");
	Result.Insert("svg", "image/svg");
	Result.Insert("tiff", "image/tiff");
	Result.Insert("ico", "image/vnd.microsoft.icon");
	
	Result.Insert("html", "text/html");
	Result.Insert("txt", "text/plain");
	Result.Insert("xml", "text/xml");
	
	Result.Insert("mpeg", "video/mpeg");
	Result.Insert("mp4", "video/mp4");
	Result.Insert("mov", "video/quicktime");
	Result.Insert("wmv", "video/x-ms-wmv");
	Result.Insert("flv", "video/x-flv");
	Result.Insert("3gpp", "video/3gpp");
	Result.Insert("3gp", "video/3gpp");
	Result.Insert("3gpp2", "video/3gpp2");
	Result.Insert("3g2", "video/3gpp2");
	
	Result.Insert("odt", "application/vnd.oasis.opendocument.text");
	Result.Insert("ods", "application/vnd.oasis.opendocument.spreadsheet");
	Result.Insert("odp", "application/vnd.oasis.opendocument.presentation");
	Result.Insert("odg", "application/vnd.oasis.opendocument.graphics");
	
	Result.Insert("doc", "application/msword");
	Result.Insert("docx", "application/vnd.openxmlformats-officedocument.wordprocessingml.document");
	Result.Insert("xls", "application/vnd.ms-excel");
	Result.Insert("xlsx", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet");
	Result.Insert("ppt", "application/vnd.ms-powerpoint");
	Result.Insert("pptx", "application/vnd.openxmlformats-officedocument.presentationml.presentation");
	
	Result.Insert("rar", "application/x-rar-compressed");
	
	Result.Insert("p7m", "application/x-pkcs7-mime");
	Result.Insert("p7s", "application/x-pkcs7-signature");
	
	Return Result;
EndFunction

Function GetFormattedDocumentHTMLForEmail(FormattedDocument)
	
	// Exports formatted document to HTML text and pictures.
	HTMLText = "";
	Pictures = New Structure;
	FormattedDocument.GetHTML(HTMLText, Pictures);
	
	// Converting HTML text to HTMLDocument.
	Builder = New DOMBuilder;
	HTMLReader = New HTMLReader;
	HTMLReader.SetString(HTMLText);
	DocumentHTML = Builder.Read(HTMLReader);
	
	// Replacing picture names in the HTML document with IDs.
	For Each Picture In DocumentHTML.Images Do
		AttributePictureSource = Picture.Attributes.GetNamedItem("src");
		AttributePictureSource.TextContent = "cid:" + AttributePictureSource.TextContent;
	EndDo;
	
	// Converting HTMLDocument back to HTML text
	DOMWriter = New DOMWriter;
	HTMLWriter = New HTMLWriter;
	HTMLWriter.SetString();
	DOMWriter.Write(DocumentHTML, HTMLWriter);
	HTMLText = HTMLWriter.Close();
	
	// Preparing the result.
	Result = New Structure;
	Result.Insert("HTMLText", HTMLText);
	Result.Insert("Pictures", Pictures);
	
	Return Result;
	
EndFunction

Function EmailPresentation(EmailSubject, EmailDate)
	
	PresentationTemplate = NStr("ru = '%1 от %2'; en = '%1, %2'; pl = '%1, %2';es_ES = '%1, %2';es_CO = '%1, %2';tr = '%1, %2';it = '%1, %2';de = '%1, %2'");
	
	Return StringFunctionsClientServer.SubstituteParametersToString(PresentationTemplate,
		?(IsBlankString(EmailSubject), NStr("ru = '<Нет темы>'; en = '<No subject>'; pl = '<Bez tematu>';es_ES = '<Sin Tema>';es_CO = '<No subject>';tr = '<Konu yok>';it = '<Nessun oggetto>';de = '<Kein Thema>'"), EmailSubject),
		Format(EmailDate, "DLF=D"));
	
EndFunction

// Converts the collection of passed attachments to a standard format.
// It is used to bypass the situations when the source form does not consider lifetime of the 
// temporary storage where attachments are uploaded to. The attachments are uploaded to the temporary storage for the session time.
Function AttachmentsDetails(AttachmentCollection) Export
	If TypeOf(AttachmentCollection) <> Type("ValueList") AND TypeOf(AttachmentCollection) <> Type("Array") Then
		Return AttachmentCollection;
	EndIf;
	
	Result = New Array;
	For Each Attachment In AttachmentCollection Do
		AttachmentDetails = AttachmentDetails();
		If TypeOf(AttachmentCollection) = Type("ValueList") Then
			AttachmentDetails.Presentation = Attachment.Presentation;
			BinaryData = Undefined;
			If TypeOf(Attachment.Value) = Type("BinaryData") Then
				BinaryData = Attachment.Value;;
			Else
				If IsTempStorageURL(Attachment.Value) Then
					BinaryData = GetFromTempStorage(Attachment.Value);
				Else
					PathToFile = Attachment.Value;
					BinaryData = New BinaryData(PathToFile);
				EndIf;
			EndIf;
		Else // TypeOf(Parameters.Attachments) = "array of structures"
			BinaryData = GetFromTempStorage(Attachment.AddressInTempStorage);
			FillPropertyValues(AttachmentDetails, Attachment, , "AddressInTempStorage");
		EndIf;
		AttachmentDetails.AddressInTempStorage = PutToTempStorage(BinaryData, New UUID);
		Result.Add(AttachmentDetails);
	EndDo;
	
	Return Result;
EndFunction

Function AttachmentDetails()
	Result = New Structure;
	Result.Insert("Presentation");
	Result.Insert("AddressInTempStorage");
	Result.Insert("Encoding");
	Result.Insert("ID");
	
	Return Result;
EndFunction

Function MailServerKeepsMailsSentBySMTP(InternetMailProfile)
	
	Return Lower(InternetMailProfile.SMTPServerAddress) = "smtp.gmail.com"
		Or StrEndsWith(Lower(InternetMailProfile.SMTPServerAddress), ".outlook.com") > 0;
	
EndFunction

Function HasExternalResources(DocumentHTML) Export
	
	Filters = New Array;
	Filters.Add(FilterByAttribute("src", "^(http|https)://"));
	
	Filter = CombineFilters(Filters);
	FoundNodes = DocumentHTML.FindByFilter(ValueToJSON(Filter));
	
	Return FoundNodes.Count() > 0;
	
EndFunction

Procedure DisableUnsafeContent(DocumentHTML, DisableExternalResources = True) Export
	
	Filters = New Array;
	Filters.Add(FilterByNodeName("script"));
	Filters.Add(FilterByNodeName("link"));
	Filters.Add(FilterByNodeName("iframe"));
	Filters.Add(FilterByAttributeName("onerror"));
	Filters.Add(FilterByAttributeName("onmouseover"));
	Filters.Add(FilterByAttributeName("onmouseout"));
	Filters.Add(FilterByAttributeName("onclick"));
	Filters.Add(FilterByAttributeName("onload"));
	
	Filter = CombineFilters(Filters);
	DocumentHTML.DeleteByFilter(ValueToJSON(Filter));
	
	If DisableExternalResources Then
		Filter = FilterByAttribute("src", "^(http|https)://");
		FoundNodes = DocumentHTML.FindByFilter(ValueToJSON(Filter));
		For Each Node In FoundNodes Do
			Node.Value = "";
		EndDo;
	EndIf;
	
EndProcedure

Function FilterByNodeName(NodeName)
	
	Result = New Structure;
	Result.Insert("type", "elementname");
	Result.Insert("value", New Structure("value, operation", NodeName, "equals"));
	
	Return Result;
	
EndFunction

Function CombineFilters(Filters, CombinationType = "Or")
	
	If Filters.Count() = 1 Then
		Return Filters[0];
	EndIf;
	
	Result = New Structure;
	Result.Insert("type", ?(CombinationType = "AND", "intersection", "union"));
	Result.Insert("value", Filters);
	
	Return Result;
	
EndFunction

Function FilterByAttribute(AttributeName, ValueTemplate)
	
	Filters = New Array;
	Filters.Add(FilterByAttributeName(AttributeName));
	Filters.Add(FilterByAttributeValue(ValueTemplate));
	
	Result = CombineFilters(Filters, "AND");
	
	Return Result;
	
EndFunction

Function FilterByAttributeName(AttributeName)
	
	Result = New Structure;
	Result.Insert("type", "attribute");
	Result.Insert("value", New Structure("value, operation", AttributeName, "nameequals"));
	
	Return Result;
	
EndFunction

Function FilterByAttributeValue(ValueTemplate)
	
	Result = New Structure;
	Result.Insert("type", "attribute");
	Result.Insert("value", New Structure("value, operation", ValueTemplate, "valuematchesregex"));
	
	Return Result;
	
EndFunction

Function ValueToJSON(Value)
	
	JSONWriter = New JSONWriter;
	JSONWriter.SetString();
	WriteJSON(JSONWriter, Value);
	
	Return JSONWriter.Close();
	
EndFunction

Procedure DetermineSentEmailsFolder(Connection)
	
	Mailboxes = Connection.GetMailboxes();
	For Each Mailbox In Mailboxes Do
		If Lower(Mailbox) = "sent"
			Or Lower(Mailbox) = "sent" Then
			
			Connection.CurrentMailbox = Mailbox;
			Break;
			
		EndIf;
	EndDo;
	
EndProcedure

Function UseIMAPOnSendingEmails(Profile)
	
	Return Not MailServerKeepsMailsSentBySMTP(Profile)
		AND ValueIsFilled(Profile.IMAPServerAddress)
		AND ValueIsFilled(Profile.IMAPPort)
		AND ValueIsFilled(Profile.IMAPUser)
		AND Profile.IMAPPassword <> "";
	
EndFunction

Function EventNameSendEmail()
	
	Return NStr("ru = 'Работа с почтовыми сообщениями.Отправка почты'; en = 'Email operations. Send mail'; pl = 'Operacje e-mail.Wyślij e-mail';es_ES = 'Operaciones de correo electrónico. Enviar correo electrónico';es_CO = 'Operaciones de correo electrónico. Enviar correo electrónico';tr = 'E-posta işlemleri. E-posta gönder';it = 'Operazioni email. Inviare email';de = 'E-Mail-Operationen. E-Mail senden'", CommonClientServer.DefaultLanguageCode());

EndFunction

#EndRegion
