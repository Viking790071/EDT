#Region Private

// Validating email account.
//
// See procedure EmailOperationsInternal.CheckCanSendReceiveEmail.
//
Procedure CheckSendReceiveEmailAvailability(Account, ErrorMessage, AdditionalMessage) Export
	
	EmailOperationsInternal.CheckSendReceiveEmailAvailability(Account, ErrorMessage, AdditionalMessage);
	
EndProcedure

// Returns True if the current user has at least one account available for sending.
Function HasAvailableAccountsForSending() Export
	Return EmailOperations.AvailableEmailAccounts(True).Count() > 0;
EndFunction

// Checks whether a user can add new accounts.
Function CanAddNewAccounts() Export 
	Return AccessRight("Insert", Metadata.Catalogs.EmailAccounts);
EndFunction

Function AccountSetUp(Account) Export
	Return EmailOperations.AccountSetUp(Account, False, False);
EndFunction

Function InfoForSending(SendOptions) Export
	Var Attachments;
	
	SendOptions.Property("Attachments", Attachments);
	SendOptions.Attachments = EmailOperationsInternal.AttachmentsDetails(Attachments);
	
	Result = New Structure;
	Result.Insert("HasAvailableAccountsForSending", HasAvailableAccountsForSending());
	Result.Insert("CanAddNewAccounts", CanAddNewAccounts());
	Result.Insert("ShowAttachmentSaveFormatSelectionDialog", AttachmentsContainSpreadsheetDocuments(SendOptions.Attachments));
	
	Return Result;
EndFunction

Function AttachmentsContainSpreadsheetDocuments(Attachments)
	If Attachments = Undefined Then
		Return False;
	EndIf;
	
	For Each AttachmentDetails In Attachments Do
		If TypeOf(GetFromTempStorage(AttachmentDetails.AddressInTempStorage)) = Type("SpreadsheetDocument") Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
EndFunction

Function PrepareAttachments(Attachments, SettingsForSaving) Export
	EmailOperationsInternal.PrepareAttachments(Attachments, SettingsForSaving);
EndFunction

#EndRegion
