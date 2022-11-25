///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.Interactions

// It is called when filling a document on the basis.
//
// Parameters:
//  Contacts - Array - an array containing interaction participants.
//
Procedure FillContacts(Contacts) Export
	
	If Not Interactions.ContactsFilled(Contacts) Then
		Return;
	EndIf;
	
	For Each TableRow In Contacts Do
		
		Address = Undefined;
		
		If TypeOf(TableRow) = Type("Structure") Then
			// Only those contacts which have their email addresses specified will get to the document.
			AddressesArray = StrSplit(TableRow.Address, ",");
			For each AddressesArrayElement In AddressesArray Do
				Try
					Result = CommonClientServer.ParseStringWithEmailAddresses(AddressesArrayElement);
				Except
					// The row with email addresses is entered incorrectly.
					Continue;
				EndTry;
				If Result.Count() > 0 AND NOT IsBlankString(Result[0]) Then
					Address = Result[0];
				EndIf;
				If Address <> Undefined Then
					Break;
				EndIf;
			EndDo;
			
			If Address = Undefined AND ValueIsFilled(TableRow.Contact) Then
				DSAddressesArray = InteractionsServerCall.GetContactEmailAddresses(TableRow.Contact);
				If DSAddressesArray.Count() > 0 Then
					Address = New Structure("Address",DSAddressesArray[0].EMAddress);
				EndIf;
			EndIf;
			
			If NOT Address = Undefined Then
				
				NewRow = EmailRecipients.Add();
				
				NewRow.Contact = TableRow.Contact;
				NewRow.Presentation = TableRow.Presentation;
				NewRow.Address = Address.Address;
			Else
				Continue;
			EndIf;
			
		Else
			NewRow = EmailRecipients.Add();
			NewRow.Contact = TableRow;
		EndIf;
		
		Interactions.FinishFillingContactsFields(NewRow.Contact, NewRow.Presentation,
			NewRow.Address, Enums.ContactInformationTypes.EmailAddress);
			
	EndDo;
	
	GenerateContactsPresentation();
	
EndProcedure

// End StandardSubsystems.Interactions

// StandardSubsystems.AccessManagement

// See AccessManagement.FillAccessValuesSets. 
Procedure FillAccessValuesSets(Table) Export
	
	InteractionsEvents.FillAccessValuesSets(ThisObject, Table);
	
EndProcedure

// End StandardSubsystems.AccessManagement

#EndRegion

#EndRegion

#Region EventHandlers

Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	InfobaseUpdate.CheckObjectProcessed(ThisObject);
	
	PreviousDeletionMark = False;
	If Not IsNew() Then
		PreviousDeletionMark = Common.ObjectAttributeValue(Ref, "DeletionMark");
	EndIf;
	AdditionalProperties.Insert("DeletionMark", PreviousDeletionMark);
	
	If DeletionMark <> PreviousDeletionMark Then
		HasAttachments = ?(DeletionMark, False, FilesOperationsInternalServerCall.AttachedFilesCount(Ref) > 0);
	EndIf;
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	Interactions.OnWriteDocument(ThisObject);
	Interactions.ProcessDeletionMarkChangeFlagOnWriteEmail(ThisObject);
	
EndProcedure

Procedure BeforeDelete(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	EmailManagement.DeleteEmailAttachments(Ref);
	
EndProcedure

Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	If Common.SubsystemExists("StandardSubsystems.MessageTemplates") Then
		ModuleMessagesTemplates = Common.CommonModule("MessageTemplates");
		IsTemplate = ModuleMessagesTemplates.IsTemplate(FillingData);
	Else
		IsTemplate = False;
	EndIf;
		
	If IsTemplate Then
		
		FillBasedOnTemplate(FillingData);
		
	ElsIf (TypeOf(FillingData) = Type("Structure")) AND (FillingData.Property("Basis")) 
		 AND (TypeOf(FillingData.Basis) = Type("DocumentRef.IncomingEmail") 
		 OR TypeOf(FillingData.Basis) = Type("DocumentRef.OutgoingEmail")) Then
		
		Interactions.FillDefaultAttributes(ThisObject, Undefined);
		FillBasedOnEmail(FillingData.Basis, FillingData.Command);
		
	Else
		Interactions.FillDefaultAttributes(ThisObject, FillingData);
		
	EndIf;
	
	Importance = Enums.InteractionImportanceOptions.Normal;
	EmailStatus = Enums.OutgoingEmailStatuses.Draft;
	If IsBlankString(Encoding) Then
		Encoding = "utf-8";
	EndIf;
	
	If Not ValueIsFilled(Account) Then
		Account = EmailManagement.GetAccountForDefaultSending();
	EndIf;
	SenderPresentation = GetPresentationForAccount(Account);
	
EndProcedure

#EndRegion

#Region Private

Procedure GenerateContactsPresentation()
	
	EmailRecipientsList =
		InteractionsClientServer.GetAddressesListPresentation(EmailRecipients, False);
	CcRecipientsList =
		InteractionsClientServer.GetAddressesListPresentation(CCRecipients, False);
	BccRecipientsList =
		InteractionsClientServer.GetAddressesListPresentation(BccRecipients, False);
	
EndProcedure

Procedure FillBasedOnEmail(Basis, ReplyType)
	
	MoveSender = True;
	MoveAllRecipients = False;
	MoveAttachments = False;
	AddToSubject = "RE: ";
	
	If ReplyType = "ReplyToAll" Then
		MoveAllRecipients = True;
	ElsIf ReplyType = "Forward" Then
		AddToSubject = "FW: ";
		MoveSender = False;
		MoveAttachments = True;
	ElsIf ReplyType = "ForwardAsAttachment" Then
		AddToSubject = "";
		MoveSender = False;
	EndIf;
	
	FillParametersFromEmail(Basis, MoveSender, MoveAllRecipients,
		AddToSubject, MoveAttachments,ReplyType);
	
EndProcedure

Procedure FillBasedOnTemplate(TemplateRef)
	
	ModuleMessagesTemplates = Common.CommonModule("MessageTemplates");
	Message = ModuleMessagesTemplates.GenerateMessage(TemplateRef, Undefined, New UUID);
	
	If TypeOf(Message.Text) = Type("Structure") Then
		
		ResultText = Message.Text.HTMLText;
		AttachmentsStructure = Message.Text.AttachmentsStructure;
		HTMLEmail             = True;
		
	Else
		
		AttachmentsStructure = New Structure();
		ResultText = Message.Text;
		HTMLEmail = StrStartsWith(ResultText, "<!DOCTYPE html") OR StrStartsWith(ResultText, "<html");
		
	EndIf;
	
	If TypeOf(Message.Attachments) <> Undefined Then
		For each Attachment In Message.Attachments Do
			
			If ValueIsFilled(Attachment.ID) Then
				Picture = New Picture(GetFromTempStorage(Attachment.AddressInTempStorage));
				AttachmentsStructure.Insert(Attachment.Presentation, Picture);
				ResultText = StrReplace(ResultText, "cid:" + Attachment.ID, Attachment.Presentation);
			EndIf;
		EndDo;
		
	EndIf;
	
	If HTMLEmail Then
		If AttachmentsStructure.Count() > 0 Then
			EmailBody = New Structure();
			EmailBody.Insert("HTMLText",         ResultText);
			EmailBody.Insert("AttachmentsStructure", AttachmentsStructure);
			HTMLText = PutToTempStorage(EmailBody);
		Else
			HTMLText = ResultText;
		EndIf;
		TextType = Enums.EmailTextTypes.HTML;
	Else
		Text     = ResultText;
		TextType = Enums.EmailTextTypes.PlainText;
	EndIf;
	Subject = Message.Subject;
	
EndProcedure

Function GetPresentationForAccount(Account)

	If Not ValueIsFilled(Account) Then
		Return "";
	EndIf;

	Query = New Query;
	Query.Text =
	"SELECT
	|	EmailAccounts.UserName,
	|	EmailAccounts.EmailAddress
	|FROM
	|	Catalog.EmailAccounts AS EmailAccounts
	|WHERE
	|	EmailAccounts.Ref = &Account";
	Query.SetParameter("Account", Account);
	Selection = Query.Execute().Select();
	Selection.Next();
	
	Presentation = Selection.UserName;
	If IsBlankString(Presentation) Then
		Return Selection.EmailAddress;
	Else
		Return Presentation + " <" + Selection.EmailAddress + ">";
	EndIf;

EndFunction

Procedure AddRecipient(Address, Presentation, Contact)
	
	NewRow = EmailRecipients.Add();
	NewRow.Address = Address;
	NewRow.Contact = Contact;
	NewRow.Presentation = Presentation;
	
EndProcedure

Procedure AddRecipientsFromTable(Table)
	
	For Each TableRow In Table Do
		NewRow = EmailRecipients.Add();
		FillPropertyValues(NewRow, TableRow);
	EndDo;
	
EndProcedure

Procedure FillParametersFromEmail(Email, MoveSenderToRecipients, 
	
	MoveAllEmailRecipientsToRecipients, AddToSubject, MoveAttachments, ReplyType)
	
	MetadataObjectName = Email.Metadata().Name;
	
	Query = New Query;
	Query.Text ="SELECT
	|	EmailMessage.MessageID,
	|	EmailMessage.BasisIDs,
	|	EmailMessage.Encoding,
	|	ISNULL(InteractionsFolderSubjects.Topic, UNDEFINED) AS Topic,
	|	EmailMessage.Subject,
	|	EmailMessage.Account,
	|	EmailMessage.TextType,
	|	EmailMessage.Ref" +?(MoveSenderToRecipients,",
	|	EmailMessage.SenderAddress,
	|	EmailMessage.SenderContact,
	|	EmailMessage.SenderPresentation", "") + "
	|FROM
	|	Document." + MetadataObjectName + " AS EmailMessage
	|	LEFT JOIN InformationRegister.InteractionsFolderSubjects AS InteractionsFolderSubjects
	|		ON EmailMessage.Ref =  InteractionsFolderSubjects.Interaction
	|WHERE
	|	EmailMessage.Ref = &Ref";
	
	Query.SetParameter("Ref", Email);
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	Selection = QueryResult.Select();
	Selection.Next();
	
	BasisID       = Selection.MessageID;
	BasisIDs      = TrimAll(Selection.BasisIDs + " <" + BasisID + ">");
	Encoding                    = Selection.Encoding;
	Topic                      = Selection.Topic;
	Subject                         = AddToSubject + Selection.Subject;
	Account                = Selection.Account;
	InteractionBasis      = Selection.Ref;
	IncludeOriginalEmailBody  = True;
	TextType                    = Selection.TextType;
	
	If MoveSenderToRecipients Then
		AddRecipient(Selection.SenderAddress, Selection.SenderPresentation, Selection.SenderContact);
	EndIf;
	
	If MoveAllEmailRecipientsToRecipients Then
		
		Query.Text = "SELECT ALLOWED
		|	EmailAccounts.EmailAddress
		|INTO CurrentRecipientAddress
		|FROM
		|	Catalog.EmailAccounts AS EmailAccounts
		|WHERE
		|	EmailAccounts.Ref IN
		|			(SELECT
		|				EmailMessage.Account
		|			FROM
		|				Document." + MetadataObjectName + " AS EmailMessage
		|			WHERE
		|				EmailMessage.Ref = &Ref)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	EmailMessageMessageRecipients.Address,
		|	EmailMessageMessageRecipients.Presentation,
		|	EmailMessageMessageRecipients.Contact
		|FROM
		|	Document." + MetadataObjectName + ".EmailRecipients AS EmailMessageMessageRecipients
		|WHERE
		|	EmailMessageMessageRecipients.Ref = &Ref
		|	AND (NOT EmailMessageMessageRecipients.Address IN
		|				(SELECT
		|					CurrentRecipientAddress.EmailAddress
		|				FROM
		|					CurrentRecipientAddress AS CurrentRecipientAddress))
		|
		|UNION ALL
		|
		|SELECT
		|	EmailMessageCCRecipients.Address,
		|	EmailMessageCCRecipients.Presentation,
		|	EmailMessageCCRecipients.Contact
		|FROM
		|	Document." + MetadataObjectName + ".CCRecipients AS EmailMessageCCRecipients
		|WHERE
		|	EmailMessageCCRecipients.Ref = &Ref
		|	AND (NOT EmailMessageCCRecipients.Address IN
		|				(SELECT
		|					CurrentRecipientAddress.EmailAddress
		|				FROM
		|					CurrentRecipientAddress AS CurrentRecipientAddress))";
		
		Query.SetParameter("ThisMessageSenderAddress",Email.Account.EmailAddress);
		
		QueryResult = Query.Execute();
		
		If NOT QueryResult.IsEmpty() Then
			AddRecipientsFromTable(QueryResult.Unload());
		EndIf;
		
	EndIf;
	
	EmailRecipientsList = InteractionsClientServer.GetAddressesListPresentation(EmailRecipients, False);
	
EndProcedure

#EndRegion

#Else
Raise NStr("ru = 'Недопустимый вызов объекта на клиенте.'; en = 'Invalid object call on the client.'; pl = 'Niepoprawne wywołanie obiektu na kliencie.';es_ES = 'Invalidar la llamada de objeto al cliente.';es_CO = 'Invalidar la llamada de objeto al cliente.';tr = 'İstemcide geçersiz nesne çağrısı.';it = 'Chiamata oggetto non valida per il client.';de = 'Ungültiger Objektaufruf auf dem Client.'");
#EndIf