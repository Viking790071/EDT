///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	AccountUser = Common.ObjectAttributeValue(Record.EmailAccount, "AccountOwner");
	IsPersonalAccount = ValueIsFilled(AccountUser);
	If Not IsPersonalAccount Then
		AccountUser = Record.EmployeeResponsibleForFoldersMaintenance;
	EndIf;
	
	If NOT Record.DoNotUseInIntegratedMailClient Then
		UseInDefaultEmailClient = 1;
	EndIf;
		
	RefreshFormItemsState(ThisObject);
	
	OnCreatReadAtServer();
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If CurrentObject.NewMessageSignatureFormat = Enums.EmailEditingMethods.HTML Then
		
		CurrentObject.SignatureForNewMessagesPlainText =
			NewMessageFormattedDocument.GetText();
		
		CurrentObject.SignatureForNewMessagesFormattedDocument =
			New ValueStorage(NewMessageFormattedDocument);
		
	Else
		
		CurrentObject.SignatureForNewMessagesFormattedDocument = Undefined;
		
	EndIf;
	
	If CurrentObject.ReplyForwardSignatureFormat = Enums.EmailEditingMethods.HTML Then
		
		CurrentObject.ReplyForwardSignaturePlainText = OnReplyForwardFormattedDocument.GetText();
		CurrentObject.ReplyForwardSignatureFormattedDocument = 
			New ValueStorage(OnReplyForwardFormattedDocument);
		
	Else
		
		CurrentObject.ReplyForwardSignatureFormattedDocument = Undefined;
		
	EndIf;
	
	If IsPersonalAccount Then
		CurrentObject.EmployeeResponsibleForProcessingEmails = Catalogs.Users.EmptyRef();
		CurrentObject.EmployeeResponsibleForFoldersMaintenance   = Catalogs.Users.EmptyRef();
		CurrentObject.DeleteEmailsAfterSend    = False;
	EndIf;
	
	CurrentObject.MailHandlingInOtherMailClient = ?(MailHandlingInOtherMailClient = 1, True, False);
	
	OnCreatReadAtServer();
	
EndProcedure 

&AtServer
Procedure OnReadAtServer(CurrentObject)

	// StandardSubsystems.AccessManagement
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.OnReadAtServer(ThisObject, CurrentObject);
	EndIf;
	// End StandardSubsystems.AccessManagement

	If CurrentObject.AddSignatureForNewMessages 
		AND CurrentObject.NewMessageSignatureFormat = Enums.EmailEditingMethods.HTML Then
		
		NewMessageFormattedDocument = CurrentObject.SignatureForNewMessagesFormattedDocument.Get();
		
	EndIf;
	
	If CurrentObject.AddSignatureOnReplyForward 
		AND CurrentObject.ReplyForwardSignatureFormat = Enums.EmailEditingMethods.HTML Then
		
		OnReplyForwardFormattedDocument = 
			CurrentObject.ReplyForwardSignatureFormattedDocument.Get();
		
	EndIf;
		
	If Record.MailHandlingInOtherMailClient Then
		MailHandlingInOtherMailClient = 1;
	EndIf;
	
	SetPagesPictures();
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	If IsPersonalAccount Or Record.DoNotUseInIntegratedMailClient Then
		CheckedAttributes.Clear();
	EndIf;
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	If EventName = "Write_EmailAccount" 
		AND Source = Record.EmailAccount Then
		
		Items.WhereEmailsBeingProcessedGroup.Visible = EmailsProcessingSettingInAnotherClientAvailable();
	ElsIf EventName = "OnChangeEmailAccountKind" AND Source = FormOwner Then
		IsPersonalAccount = Parameter;
		OnChangeEmailAccountKind();
	EndIf;
EndProcedure 

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)

	// StandardSubsystems.AccessManagement
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.AfterWriteAtServer(ThisObject, CurrentObject, WriteParameters);
	EndIf;
	// End StandardSubsystems.AccessManagement
	
	SetPagesPictures();
	
EndProcedure

&AtServer
Procedure SetPagesPictures()

	Items.SignatureOnReplyPage.Picture = Interactions.SignaturePagesPIcture(Record.AddSignatureOnReplyForward);
	Items.SignatureForNewMessagePage.Picture = Interactions.SignaturePagesPIcture(Record.AddSignatureForNewMessages);

EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	If TypeOf(FormOwner) = Type("ClientApplicationForm") AND FormOwner.FormName = "Catalog.EmailAccounts.Form.ItemForm" Then
		IsPersonalAccount = FormOwner.UserAccountKind = "Personal";
	EndIf;
	RefreshFormItemsState(ThisObject);
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure EnableSignatureForNewMessagesOnChange(Item)
	
	RefreshFormItemsState(ThisObject);
	
EndProcedure

&AtClient
Procedure EnableSignatureOnReplyForwardOnChange(Item)
	
	RefreshFormItemsState(ThisObject);
	
EndProcedure

&AtClient
Procedure SignatureFormatForNewMessagesOnChange(Item)
	
	If Record.NewMessageSignatureFormat = PredefinedValue(
		"Enum.EmailEditingMethods.HTML") 
		AND Items.PagesSignatureForNewMessages.CurrentPage = Items.NewMessageFormattedTextPage Then
		
		Return;
		
	EndIf;
	
	If Record.NewMessageSignatureFormat = PredefinedValue(
		"Enum.EmailEditingMethods.NormalText") 
		AND Items.PagesSignatureForNewMessages.CurrentPage = Items.NewMessagePlainTextPage Then
		
		Return;
		
	EndIf;
	
	If Record.NewMessageSignatureFormat = PredefinedValue(
		"Enum.EmailEditingMethods.HTML") Then
		
		If Not IsBlankString(Record.SignatureForNewMessagesPlainText) Then
			NewMessageFormattedDocument.Delete();
			NewMessageFormattedDocument.Add(Record.SignatureForNewMessagesPlainText);
		EndIf;
		
		RefreshFormItemsState(ThisObject);
		
	Else
		
		AdditionalParameters = New Structure("CallContext", "ForNewMessages");
		InteractionsClient.PromptOnChangeMessageFormatToPlainText(ThisObject, AdditionalParameters);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SignatureFormatOnReplyForwardOnChange(Item)
	
	If Record.ReplyForwardSignatureFormat = PredefinedValue(
			"Enum.EmailEditingMethods.HTML") 
			AND Items.PagesSignatureOnReplyForward.CurrentPage = Items.PageOnReplyForwardFormattedDocument Then
		
		Return;
		
	EndIf;
	
	If Record.ReplyForwardSignatureFormat = PredefinedValue(
			"Enum.EmailEditingMethods.NormalText") 
			AND Items.PagesSignatureOnReplyForward.CurrentPage = Items.PageOnReplyForwardPlainText Then
		
		Return;
		
	EndIf;
	
	If Record.ReplyForwardSignatureFormat = PredefinedValue(
			"Enum.EmailEditingMethods.HTML") Then
		
		If Not IsBlankString(Record.ReplyForwardSignaturePlainText) Then
			OnReplyForwardFormattedDocument.Delete();
			OnReplyForwardFormattedDocument.Add(Record.ReplyForwardSignaturePlainText);
		EndIf;
		
		RefreshFormItemsState(ThisObject);
		
	Else
		
		AdditionalParameters = New Structure("CallContext", "OnReplyForward");
		InteractionsClient.PromptOnChangeMessageFormatToPlainText(ThisObject, AdditionalParameters);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure UseInDefaultEmailClientOnChange(Item)
	
	Record.DoNotUseInIntegratedMailClient = ?(UseInDefaultEmailClient = 1, False, True);
	RefreshFormItemsState(ThisObject);
	
EndProcedure

#EndRegion

#Region Private

&AtClientAtServerNoContext
Procedure RefreshFormItemsState(Form)
	
	InteractionsClientServer.SetGroupItemsProperty(Form.Items.MainSettingsGroup, "Enabled", NOT Form.Record.DoNotUseInIntegratedMailClient);
	Form.Items.SignatureForNewMessagePage.Enabled = NOT Form.Record.DoNotUseInIntegratedMailClient;
	Form.Items.SignatureOnReplyPage.Enabled = NOT Form.Record.DoNotUseInIntegratedMailClient;

	If Form.Record.NewMessageSignatureFormat = PredefinedValue(
		"Enum.EmailEditingMethods.HTML") Then
		
		Form.Items.PagesSignatureForNewMessages.CurrentPage =
			Form.Items.NewMessageFormattedTextPage;
		Form.Items.NewMessageFormattedDocument.Enabled =
			Form.Record.AddSignatureForNewMessages;
		
	Else
		
		Form.Items.PagesSignatureForNewMessages.CurrentPage =
			Form.Items.NewMessagePlainTextPage;
		Form.Items.SignatureForNewMessagesPlainText.Enabled =
			Form.Record.AddSignatureForNewMessages;
		
	EndIf;
	
	If Form.Record.ReplyForwardSignatureFormat = PredefinedValue(
			"Enum.EmailEditingMethods.HTML") Then
		
		Form.Items.PagesSignatureOnReplyForward.CurrentPage = 
			Form.Items.PageOnReplyForwardFormattedDocument;
		Form.Items.OnReplyForwardFormattedDocument.Enabled = 
			Form.Record.AddSignatureOnReplyForward;
		
	Else
		
		Form.Items.PagesSignatureOnReplyForward.CurrentPage = 
			Form.Items.PageOnReplyForwardPlainText;
		Form.Items.ReplyForwardSignaturePlainText.Enabled = 
			Form.Record.AddSignatureOnReplyForward;
		
	EndIf;
	
	Form.Items.EmployeesResponsibleGroup.Visible = Not Form.IsPersonalAccount;
	
	Form.Items.NewMessageSignatureFormat.Enabled  = Form.Record.AddSignatureForNewMessages;
	Form.Items.ReplyForwardSignatureFormat.Enabled = Form.Record.AddSignatureOnReplyForward;

EndProcedure

&AtClient
Procedure PromptOnChangeFormatOnClose(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult <> DialogReturnCode.Yes Then
		If AdditionalParameters.CallContext = "ForNewMessages" Then
			Record.NewMessageSignatureFormat  = PredefinedValue("Enum.EmailEditingMethods.HTML");
		ElsIf AdditionalParameters.CallContext = "OnReplyForward" Then
			Record.ReplyForwardSignatureFormat = PredefinedValue("Enum.EmailEditingMethods.HTML");
		EndIf;
		Return;
	EndIf;
	
	If AdditionalParameters.CallContext = "ForNewMessages" Then
		
		Record.SignatureForNewMessagesPlainText = NewMessageFormattedDocument.GetText();
		NewMessageFormattedDocument.Delete();
		
	ElsIf AdditionalParameters.CallContext = "OnReplyForward" Then
		
		Record.ReplyForwardSignaturePlainText = OnReplyForwardFormattedDocument.GetText();
		OnReplyForwardFormattedDocument.Delete();
		
	EndIf;
	
	RefreshFormItemsState(ThisObject);
	
EndProcedure

&AtServer
Function EmailsProcessingSettingInAnotherClientAvailable()
	
	UseReviewedFlag = GetFunctionalOption("UseReviewedFlag");
	AccountAttributes = Common.ObjectAttributesValues(
	                 Record.EmailAccount,
	                 "UseForReceiving, ProtocolForIncomingMail");
	
	Return UseReviewedFlag
	        AND AccountAttributes.UseForReceiving
	        AND AccountAttributes.ProtocolForIncomingMail = "IMAP";
	
EndFunction

&AtServer
Procedure OnCreatReadAtServer()

	Items.WhereEmailsBeingProcessedGroup.Visible = EmailsProcessingSettingInAnotherClientAvailable();

EndProcedure

&AtClient
Procedure OnChangeEmailAccountKind()
	
	If IsPersonalAccount Then
		AccountUser = FormOwner.Object.AccountOwner;
		Record.EmployeeResponsibleForFoldersMaintenance = AccountUser;
		Record.EmployeeResponsibleForProcessingEmails = AccountUser;
		Modified = True;
	EndIf;
	
	RefreshFormItemsState(ThisObject);
	
EndProcedure

#EndRegion
