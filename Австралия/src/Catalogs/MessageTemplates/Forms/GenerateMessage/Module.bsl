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
	
	Topic            = Parameters.Topic;
	MessageKind       = Parameters.MessageKind;
	ChoiceMode        = Parameters.ChoiceMode;
	TemplateOwner    = Parameters.TemplateOwner;
	MessageParameters = Parameters.MessageParameters;
	PrepareTemplate  = Parameters.PrepareTemplate;
	
	If TypeOf(MessageParameters) = Type("Structure") AND MessageParameters.Property("MessageSourceFormName") Then
		MessageSourceFormName = MessageParameters.MessageSourceFormName;
	EndIf;
	
	If ValueIsFilled(Topic) AND TypeOf(Topic) <> Type("String") Then
		FullBasisTypeName = Topic.Metadata().FullName();
	EndIf;
	
	If MessageKind = "SMSMessage" Then
		ForSMSMessages = True;
		ForEmails = False;
		Title = NStr("ru = 'Шаблоны сообщений SMS'; en = 'Text message templates'; pl = 'Szablony wiadomości SMS';es_ES = 'Plantillas de SMS';es_CO = 'Plantillas de SMS';tr = 'SMS şablonları';it = 'Modelli di messaggio di testo';de = 'Vorlagen für Textnachrichten'");
	Else
		ForSMSMessages = False;
		ForEmails = True;
	EndIf;
	
	If NOT AccessRight("Update", Metadata.Catalogs.MessageTemplates) Then
		HasUpdateRight = False;
		Items.FormChange.Visible = False;
		Items.FormCreate.Visible  = False;
	Else
		HasUpdateRight = True;
	EndIf;
	
	If ChoiceMode Then
		Items.FormGenerateAndSend.Visible = False;
		Items.FormGenerate.Title = NStr("ru = 'Выбрать'; en = 'Select'; pl = 'Wybierz';es_ES = 'Seleccionar';es_CO = 'Seleccionar';tr = 'Seç';it = 'Selezionare';de = 'Auswählen'");
	ElsIf PrepareTemplate Then
		Items.FormGenerateAndSend.Visible = False;
	EndIf;
	
	FillAvailableTemplatesList();
	FillPrintFormsList();
	
	If Common.SubsystemExists("StandardSubsystems.Print") Then
		ModulePrintManager = Common.CommonModule("PrintManagement");
		For Each SaveFormat In ModulePrintManager.SpreadsheetDocumentSaveFormatsSettings() Do
			SelectedSaveFormats.Add(SaveFormat.SpreadsheetDocumentFileType, String(SaveFormat.Ref), False, SaveFormat.Picture);
		EndDo;
		Items.SignatureAndSeal.Visible = ModulePrintManager.PrintSettings().UseSignaturesAndSeals;
	EndIf;
	
	Items.TransliterateFilesNames.Visible = False;
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	If EventName = "Write_MessagesTemplates" Then
		SelectedItemRef = Undefined;
		If Items.Templates.CurrentData <> Undefined Then
			SelectedItemRef = Items.Templates.CurrentData.Ref;
		EndIf;
		FillAvailableTemplatesList();
		FoundRows = Templates.FindRows(New Structure("Ref", SelectedItemRef));
		If FoundRows.Count() > 0 Then
			Items.Templates.CurrentRow = FoundRows[0].GetID();
		EndIf;
	EndIf;
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If ShowTemplatesChoiceForm Then
		SetFormatSelection();
		GeneratePresentationForSelectedFormats();
	Else
		SendOptions = SendOptionsConstructor();
		SendOptions.AdditionalParameters.ConvertHTMLForFormattedDocument = False;
		GenerateMessageToSend(SendOptions);
	EndIf;
	
EndProcedure

#EndRegion

#Region TemplatesFormTableItemsEventHandlers

&AtClient
Procedure TemplatesBeforeAddRow(Item, Cancel, Clone, Parent, Folder, Parameter)
	Cancel = True;
	If Clone AND NOT Folder Then
		CreateNewTemplate(Item.CurrentData.Ref);
	Else
		CreateNewTemplate();
	EndIf;
EndProcedure

&AtClient
Procedure TemplatesBeforeDeleteRow(Item, Cancel)
	Cancel = True;
EndProcedure

&AtClient
Procedure TemplatesOnActivateRow(Item)
	If Item.CurrentData <> Undefined Then
		TemplateSelected = Item.CurrentData.Name <> "<NoTemplate>";
		Items.FormGenerateAndSend.Enabled = TemplateSelected;
		If TemplateSelected Then
			If Item.CurrentData.MailTextType = PredefinedValue("Enum.EmailEditingMethods.HTML") Then
				Items.PreviewPages.CurrentPage = Items.FormattedDocumentPage;
				AttachIdleHandler("UpdatePreviewData", 0.2, True);
			Else
				Items.PreviewPages.CurrentPage = Items.PlainTextPage;
				PreviewPlainText.SetText(Item.CurrentData.TemplateText);
			EndIf;
		Else
			Items.PreviewPages.CurrentPage = Items.PrintFormsPage;
		EndIf;
	EndIf;
EndProcedure

&AtClient
Procedure TemplatesBeforeChangeStart(Item, Cancel)
	Cancel = True;
	If Item.CurrentData <> Undefined Then
		FormParameters = New Structure("Key", Item.CurrentData.Ref);
		OpenForm("Catalog.MessageTemplates.ObjectForm", FormParameters);
	EndIf;
EndProcedure

&AtClient
Procedure TemplatesChoice(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	GenerateMessageFromSelectedTemplate();
	
EndProcedure

&AtClient
Procedure AttachmentFormatClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	NotifyDescription = New NotifyDescription("OnSelectAttachmentFormat", ThisObject);
	CommonClient.ShowAttachmentsFormatSelection(NotifyDescription, SelectedFormatSettings(), ThisObject);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Generate(Command)
	
	GenerateMessageFromSelectedTemplate();
	
EndProcedure

&AtClient
Procedure GenerateAndSend(Command)
	
	CurrentData = Templates.FindByID(Items.Templates.CurrentRow);
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	SendOptions = SendOptionsConstructor(CurrentData.Ref);
	SendOptions.AdditionalParameters.SendImmediately = True;
	If CurrentData.HasArbitraryParameters Then
		ParametersInput(CurrentData.Ref, SendOptions, True);
	Else
		SendMessage(SendOptions);
	EndIf;
	
EndProcedure

&AtClient
Procedure Create(Command)
	CreateNewTemplate();
EndProcedure

&AtClient
Procedure ParametersInput(Template, SendOptions, SendImmediately)
	
	ParametersToFill = New Structure("Template, Topic", Template, Topic);
	
	Notification = New NotifyDescription("AfterParametersInput", ThisObject, SendOptions);
	OpenForm("Catalog.MessageTemplates.Form.FillArbitraryParameters", ParametersToFill,,,,, Notification);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure GenerateMessageFromSelectedTemplate()
	
	CurrentData = Templates.FindByID(Items.Templates.CurrentRow);
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If ChoiceMode Then
		Close(CurrentData.Ref);
		Return;
	EndIf;
	
	SendOptions = SendOptionsConstructor(CurrentData.Ref);
	SendOptions.AdditionalParameters.ConvertHTMLForFormattedDocument = True;
	
	If CurrentData.HasArbitraryParameters Then
		ParametersInput(CurrentData.Ref, SendOptions, False);
	Else
		GenerateMessageToSend(SendOptions);
	EndIf;
	
EndProcedure

&AtClient
Procedure GenerateMessageToSend(SendOptions)
	
	If Not ValueIsFilled(SendOptions.Template) AND PrintForms.Count() > 0 Then
		SavePrintFormsChoice();
	EndIf;
	
	TempStorageAddress = Undefined;
	TempStorageAddress = PutToTempStorage(Undefined, UUID);
	
	ResultAddress = GenerateMessageAtServer(TempStorageAddress, SendOptions, MessageKind);
	
	Result = GetFromTempStorage(ResultAddress);
	
	Result.Insert("Topic", Topic);
	Result.Insert("Template",  SendOptions.Template);
	If SendOptions.AdditionalParameters.Property("MessageParameters")
		AND TypeOf(SendOptions.AdditionalParameters.MessageParameters) = Type("Structure") Then
		CommonClientServer.SupplementStructure(Result, MessageParameters, False);
	EndIf;
	
	If SendOptions.AdditionalParameters.SendImmediately Then
		AfterGenerateAndSendMessage(Result, SendOptions);
	Else
		If PrepareTemplate Then
			Close(Result);
		Else
			Close();
			ShowMessageForm(Result);
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Function GenerateMessageAtServer(TempStorageAddress, SendOptions, MessageKind)
	
	ServerCallParameters = New Structure();
	ServerCallParameters.Insert("SendOptions", SendOptions);
	ServerCallParameters.Insert("MessageKind",      MessageKind);
	If Common.SubsystemExists("StandardSubsystems.Interactions") Then
		ModuleInteractions = Common.CommonModule("Interactions");
		SendOptions.AdditionalParameters.Insert("ExtendedRecipientsList", ModuleInteractions.OtherInteractionsUsed());
	EndIf;
	
	MessageTemplatesInternal.GenerateMessageInBackground(ServerCallParameters, TempStorageAddress);
	
	Return TempStorageAddress;
	
EndFunction

&AtClient
Procedure AfterParametersInput(Result, SendOptions) Export
	
	If Result <> Undefined AND Result <> DialogReturnCode.Cancel Then
		SendOptions.AdditionalParameters.ArbitraryParameters = Result;
		GenerateMessageToSend(SendOptions);
	EndIf;
	
EndProcedure

&AtClient
Procedure SendMessage(Val MessageSendOptions)
	
	If MessageKind = "Email" Then
		If CommonClient.SubsystemExists("StandardSubsystems.EmailOperations") Then
			NotifyDescription = New NotifyDescription("SendMessageAccountCheckCompleted", ThisObject, MessageSendOptions);
			ModuleEmailOperationsClient = CommonClient.CommonModule("EmailOperationsClient");
			ModuleEmailOperationsClient.CheckAccountForSendingEmailExists(NotifyDescription);
		EndIf;
	Else
		GenerateMessageToSend(MessageSendOptions);
	EndIf;
	
EndProcedure

&AtClient
Procedure SendMessageAccountCheckCompleted(AccountSetUp, SendOptions) Export
	
	If AccountSetUp = True Then
		GenerateMessageToSend(SendOptions);
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterGenerateAndSendMessage(Result, SendOptions)
	
	If Result.Sent Then;
		Close();
	Else
		Notification = New NotifyDescription("AfterQuestionOnOpenMessageForm", ThisObject, SendOptions);
		ErrorDescription = Result.ErrorDescription + Chars.LF + NStr("ru = 'Открыть форму отправки сообщения?'; en = 'Do you want to open the message?'; pl = 'Czy chcesz otworzyć wiadomość?';es_ES = '¿Quiere abrir el mensaje?';es_CO = '¿Quiere abrir el mensaje?';tr = 'İletiyi açmak istiyor musunuz?';it = 'Aprire il messaggio?';de = 'Möchten Sie die Nachricht öffnen?'");
		ShowQueryBox(Notification, ErrorDescription, QuestionDialogMode.YesNo);
	EndIf;

EndProcedure

&AtClient
Procedure ShowMessageForm(Message)
	
	If MessageKind = "SMSMessage" Then
		If CommonClient.SubsystemExists("StandardSubsystems.SMS") Then 
			ModuleSMSClient= CommonClient.CommonModule("SMSClient");
			
			AdditionalParameters = New Structure("Transliterate");
			
			If Message.AdditionalParameters <> Undefined Then
				FillPropertyValues(AdditionalParameters, Message.AdditionalParameters);
			EndIf;
			
			AdditionalParameters.Transliterate = ?(Message.AdditionalParameters.Property("Transliterate"),
				Message.AdditionalParameters.Transliterate, False);
			AdditionalParameters.Insert("Topic", Topic);
			Text      = ?(Message.Property("Text"), Message.Text, "");
			
			Recipient = New Array;
			IsValueList = (TypeOf(Message.Recipient) = Type("ValueList"));
			
			For each RecipientInfo In Message.Recipient Do
				If IsValueList Then
					Phone                      = RecipientInfo.Value;
					ContactInformationSource = "";
				Else 
					Phone                      = RecipientInfo.PhoneNumber;
					ContactInformationSource = RecipientInfo.ContactInformationSource ;
				EndIf;
				
				RecipientData = New Structure();
				RecipientData.Insert("Presentation",                RecipientInfo.Presentation);
				RecipientData.Insert("Phone",                      Phone);
				RecipientData.Insert("ContactInformationSource", ContactInformationSource);
				Recipient.Add(RecipientData);
				
			EndDo;
			
			ModuleSMSClient.SendSMSMessage(Recipient, Text, AdditionalParameters);
		EndIf;
	Else
		If CommonClient.SubsystemExists("StandardSubsystems.EmailOperations") Then
			ModuleEmailOperationsClient = CommonClient.CommonModule("EmailOperationsClient");
			ModuleEmailOperationsClient.CreateNewEmailMessage(Message);
		EndIf;
	EndIf;
	
	If Message.Property("UserMessages")
		AND Message.UserMessages <> Undefined
		AND Message.UserMessages.Count() > 0 Then
			For each UserMessages In Message.UserMessages Do
				CommonClientServer.MessageToUser(UserMessages.Text,
					UserMessages.DataKey, UserMessages.Field, UserMessages.DataPath);
			EndDo;
	EndIf;
	
EndProcedure

&AtClient
Function SendOptionsConstructor(Template = Undefined)
	
	SendOptions = MessageTemplatesClientServer.SendOptionsConstructor(Template, Topic, UUID);
	SendOptions.AdditionalParameters.MessageKind       = MessageKind;
	SendOptions.AdditionalParameters.MessageParameters = MessageParameters;
	
	If Not ValueIsFilled(Template) Then
		For Each PrintForm In PrintForms Do
			If PrintForm.Check Then
				SendOptions.AdditionalParameters.PrintForms.Add(PrintForm.Value);
			EndIf;
		EndDo;
		
		SendOptions.AdditionalParameters.SettingsForSaving = SelectedFormatSettings();
	EndIf;
	
	Return SendOptions;
	
EndFunction

&AtClient
Procedure AfterQuestionOnOpenMessageForm(Result, SendOptions) Export
	If Result = DialogReturnCode.Yes Then
		SendOptions.AdditionalParameters.SendImmediately                                  = False;
		SendOptions.AdditionalParameters.ConvertHTMLForFormattedDocument = True;
		GenerateMessageToSend(SendOptions);
	EndIf;
EndProcedure

&AtClient
Procedure CreateNewTemplate(CopyingValue = Undefined)
	
	FormParameters = New Structure();
	FormParameters.Insert("MessageKind"          , MessageKind);
	FormParameters.Insert("FullBasisTypeName",
		?(ValueIsFilled(FullBasisTypeName), FullBasisTypeName, Topic));
	FormParameters.Insert("AvailableToAuthorOnly",        True);
	FormParameters.Insert("TemplateOwner",        TemplateOwner);
	FormParameters.Insert("CopyingValue",    CopyingValue);
	FormParameters.Insert("New",                  True);
	
	OpenForm("Catalog.MessageTemplates.ObjectForm", FormParameters, ThisObject);
	
EndProcedure

&AtServer
Procedure FillAvailableTemplatesList()
	
	Templates.Clear();
	TemplateType = ?(ForSMSMessages, "SMS", "Email");
	Query = MessageTemplatesInternal.PrepareQueryToGetTemplatesList(TemplateType, Topic, TemplateOwner);
	
	QueryResult = Query.Execute().Select();
		
	While QueryResult.Next() Do
		NewRow = Templates.Add();
		FillPropertyValues(NewRow, QueryResult);
		
		If QueryResult.TemplateByExternalDataProcessor
			AND Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
				ModuleAdditionalReportsAndDataProcessors = Common.CommonModule("AdditionalReportsAndDataProcessors");
				ExternalObject = ModuleAdditionalReportsAndDataProcessors.ExternalDataProcessorObject(QueryResult.ExternalDataProcessor);
				TemplateParameters = ExternalObject.TemplateParameters();
				
				If TemplateParameters.Count() > 1 Then
					HasArbitraryParameters = True;
				Else
					HasArbitraryParameters = False;
				EndIf;
		Else
			ArbitraryParameters = QueryResult.HasArbitraryParameters.Unload();
			HasArbitraryParameters = ArbitraryParameters.Count() > 0;
		EndIf;
		
		NewRow.HasArbitraryParameters = HasArbitraryParameters;
	EndDo;
	
	If Templates.Count() = 0 Then
		MessagesTemplatesSettings = MessagesTemplatesInternalCachedModules.OnDefineSettings();
		ShowTemplatesChoiceForm = MessagesTemplatesSettings.AlwaysShowTemplatesChoiceForm;
	Else
		ShowTemplatesChoiceForm = True;
	EndIf;
	
	Templates.Sort("Presentation");
	
	If NOT ChoiceMode AND NOT PrepareTemplate Then
		FirstRow = Templates.Insert(0);
		FirstRow.Name = "<NoTemplate>";
		FirstRow.Presentation = NStr("ru = '<Без шаблона>'; en = '<No template>'; pl = '<Bez szablonu>';es_ES = '<Sin plantilla>';es_CO = '<Sin plantilla>';tr = '<Şablonsuz>';it = '<Senza un modello>';de = '<Keine Vorlage>'");
	EndIf;
	
	If Templates.Count() = 0 Then
		Items.FormCreate.OnlyInAllActions = False;
		Items.FormCreate.Representation = ButtonRepresentation.PictureAndText;
		Items.FormGenerate.Enabled           = False;
		Items.FormGenerateAndSend.Enabled = False;
	Else
		Items.FormGenerate.Enabled           = True;
		Items.FormGenerateAndSend.Enabled = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure UpdatePreviewData()
	CurrentData = Items.Templates.CurrentData;
	If CurrentData <> Undefined Then
		SetHTMLInFormattedDocument(CurrentData.TemplateText, CurrentData.Ref);
	EndIf;
EndProcedure

&AtServer
Procedure SetHTMLInFormattedDocument(HTMLEmailTemplateText, CurrentObjectRef);
	
	TemplateParameter = New Structure("Template, UUID");
	TemplateParameter.Template = CurrentObjectRef;
	TemplateParameter.UUID = UUID;
	Message = MessageTemplatesInternal.MessageConstructor();
	Message.Text = HTMLEmailTemplateText;
	MessageTemplatesInternal.ProcessHTMLForFormattedDocument(TemplateParameter, Message, True);
	AttachmentsStructure = New Structure();
	For each HTMLAttachment In Message.Attachments Do
		Picture = New Picture(GetFromTempStorage(HTMLAttachment.AddressInTempStorage));
		AttachmentsStructure.Insert(HTMLAttachment.Presentation, Picture);
	EndDo;
	PreviewFormattedDocument.SetHTML(Message.Text, AttachmentsStructure);
	
EndProcedure

&AtClient
Procedure SetFormatSelection(Val SaveFormats = Undefined)
	
	HasSelectedFormat = False;
	For Each SelectedFormat In SelectedSaveFormats Do
		If SaveFormats <> Undefined Then
			SelectedFormat.Check = SaveFormats.Find(SelectedFormat.Value) <> Undefined;
		EndIf;
			
		If SelectedFormat.Check Then
			HasSelectedFormat = True;
		EndIf;
	EndDo;
	
	If Not HasSelectedFormat Then
		SelectedSaveFormats[0].Check = True; // The default choice is the first in the list.
	EndIf;
	
EndProcedure

&AtClient
Procedure GeneratePresentationForSelectedFormats()
	
	AttachmentFormat = "";
	FormatsCount = 0;
	For Each SelectedFormat In SelectedSaveFormats Do
		If SelectedFormat.Check Then
			If Not IsBlankString(AttachmentFormat) Then
				AttachmentFormat = AttachmentFormat + ", ";
			EndIf;
			AttachmentFormat = AttachmentFormat + SelectedFormat.Presentation;
			FormatsCount = FormatsCount + 1;
		EndIf;
	EndDo;
	
EndProcedure

&AtClient
Function SelectedFormatSettings()
	
	Result = Undefined;
	
	If CommonClient.SubsystemExists("StandardSubsystems.Print") Then
		ModulePrintManagerClient = CommonClient.CommonModule("PrintManagementClient");
		Result = ModulePrintManagerClient.SettingsForSaving();

		For Each SelectedFormat In SelectedSaveFormats Do
			If SelectedFormat.Check Then
				Result.SaveFormats.Add(SelectedFormat.Value);
			EndIf;
		EndDo;

		Result.PackToArchive = PackToArchive;
		Result.TransliterateFilesNames = TransliterateFilesNames;
		Result.SignatureAndSeal = SignatureAndSeal;
	EndIf;
	
	Return Result;
	
EndFunction

&AtClient
Procedure OnSelectAttachmentFormat(SelectedValue, AdditionalParameters) Export
	
	If SelectedValue <> DialogReturnCode.Cancel AND SelectedValue <> Undefined Then
		SetFormatSelection(SelectedValue.SaveFormats);
		PackToArchive = SelectedValue.PackToArchive;
		TransliterateFilesNames = SelectedValue.TransliterateFilesNames;
		GeneratePresentationForSelectedFormats();
	EndIf;
		
EndProcedure

&AtServer
Procedure FillPrintFormsList()
	
	If MessageKind = "SMSMessage" Or ChoiceMode Or PrepareTemplate
		Or TypeOf(Topic) = Type("String") Or Not ValueIsFilled(Topic) Then
		Items.SelectPrintForms.Visible = False;
		Return;
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.Print") Then
		ModulePrintManager = Common.CommonModule("PrintManagement");
		
		PrintCommands = Undefined;
		If ValueIsFilled(MessageSourceFormName) Then
			PrintCommands = Common.ValueTableToArray(ModulePrintManager.FormPrintCommands(
				MessageSourceFormName, CommonClientServer.ValueInArray(Topic.Metadata())));
		EndIf;
		
		If Not ValueIsFilled(PrintCommands) Then
			Items.SelectPrintForms.Visible = False;
			Return;
		EndIf;
		
		PrintFormsSelectedEarlier = PrintFormsSelectedEarlier();
		
		For Each PrintCommand In PrintCommands Do
			CheckBox = PrintFormsSelectedEarlier.Find(PrintCommand.UUID) <> Undefined;
			PrintForms.Add(PrintCommand, PrintCommand.Presentation, CheckBox);
		EndDo;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SavePrintFormsChoice()
	
	If Not ValueIsFilled(MessageSourceFormName) Then
		Return;
	EndIf;
	
	IDs = New Array;
	For Each PrintForm In PrintForms Do
		If PrintForm.Check Then
			IDs.Add(PrintForm.Value.UUID);
		EndIf;
	EndDo;
	
	Common.CommonSettingsStorageSave(
		"SendPrintFormsWithoutTemplate", MessageSourceFormName, IDs);
	
EndProcedure

&AtServer
Function PrintFormsSelectedEarlier()
	
	Result = New Array;
	
	If ValueIsFilled("MessageSourceFormName") Then
		Result = Common.CommonSettingsStorageLoad(
			"SendPrintFormsWithoutTemplate", MessageSourceFormName, New Array);
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion