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
	
	SetConditionalAppearance();
	
	If Parameters.Property("MessageParameters") Then
		MessageParameters = Parameters.MessageParameters;
	EndIf;
	
	Items.InputOnBasisParameterTypeFullName.ChoiceList.Add(MessageTemplatesClientServer.CommonID(),
		MessageTemplatesClientServer.CommonIDPresentation());
	MessagesTemplatesSettings = MessagesTemplatesInternalCachedModules.OnDefineSettings();
	For each TemplateSubject In MessagesTemplatesSettings.TemplateSubjects Do
		Items.InputOnBasisParameterTypeFullName.ChoiceList.Add(TemplateSubject.Name, TemplateSubject.Presentation);
	EndDo;
	
	If Parameters.Key = Undefined Or Parameters.Key.IsEmpty() Then
		
		If Parameters.CopyingValue = Catalogs.MessageTemplates.EmptyRef() Then
			
			InitializeNewMessagesTemplate(MessagesTemplatesSettings);
			
		Else
			
			For each CopyingValueParameters In Parameters.CopyingValue.Parameters Do
				Filter = New Structure("ParameterName", CopyingValueParameters.ParameterName);
				FoundRows = Object.Parameters.FindRows(Filter);
				If FoundRows.Count() > 0 Then
					FoundRows[0].TypeDetails = CopyingValueParameters.ParameterType.Get();
				EndIf
			EndDo;
			
			SetTemplateText(Object, CopyAttachmentsFromSource());
		EndIf;
		
	EndIf;
	
	ShowFormItems(MessagesTemplatesSettings.EmailFormat);
	
	InitializeSaveFormats();
	GenerateAttributesAndPrintFormsList();
	
	UseArbitraryParameters = MessagesTemplatesSettings.UseArbitraryParameters;
	
	If NOT UseArbitraryParameters Then
		Items.AttributesGroupCommandBar.Visible = False;
		Items.AttributesContextMenuAdd.Visible = False;
		Items.AttributesContextMenuChange.Visible = False;
		Items.AttributesContextMenuDelete.Visible = False;
	EndIf;
	
	If Parameters.Property("TemplateOwner") Then
		Items.AssignmentGroup.Visible                = False;
		Items.FormMessageToGenerateGroup.Visible = False;
		Items.Purpose.Visible                      = False;
	EndIf;
	
	If Common.IsMobileClient() Then
		Items.EmailSubject.MultiLine = True;
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.Print") Then
		ModulePrintManager = Common.CommonModule("PrintManagement");
		Items.SignatureAndSeal.Visible = ModulePrintManager.PrintSettings().UseSignaturesAndSeals;
	EndIf;
	
	Items.TransliterateFileNames.Visible = False;
	Items.SendInTransliteration.Visible = False;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	SetTemplateText(CurrentObject);
	
	If Common.SubsystemExists("StandardSubsystems.Print") Then
		ModulePrintManager = Common.CommonModule("PrintManagement");
		If SelectedSaveFormats.Count() = 0 Then
			For Each SaveFormat In ModulePrintManager.SpreadsheetDocumentSaveFormats() Do
				SelectedSaveFormats.Add(SaveFormat.SpreadsheetDocumentFileType, String(SaveFormat.Ref), False, SaveFormat.Picture);
			EndDo;
		EndIf;

		FormatsList = CurrentObject.AttachmentFormat.Get();
		If FormatsList <> Undefined Then
			SelectedSaveFormats.FillChecks(False);
			For Each ListItem In FormatsList Do
				ValueFound = SelectedSaveFormats.FindByValue(ListItem.Value);
				If ValueFound <> Undefined Then
					ValueFound.Check = True;
				EndIf;
			EndDo;
		EndIf;
	EndIf;
	
	FillArbitraryParametersFromObject(CurrentObject);
	
	If IsBlankString(Object.InputOnBasisParameterTypeFullName) Then
		Object.Purpose = MessageTemplatesClientServer.CommonIDPresentation();
		Object.ForInputOnBasis = False;
		Object.InputOnBasisParameterTypeFullName = MessageTemplatesClientServer.CommonID();
	EndIf;
	
	// StandardSubsystems.AccessManagement
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.OnReadAtServer(ThisObject, CurrentObject);
	EndIf;
	// End StandardSubsystems.AccessManagement

EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	PlaceFilesFromLocalFSInTempStorage(Attachments, UUID, Cancel);
	
	If Not Object.ForInputOnBasis Then
		Object.InputOnBasisParameterTypeFullName = "";
		Object.Purpose = MessageTemplatesClientServer.CommonID();
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	CheckResultTemplates = CheckResultTemplates();
	If ValueIsFilled(CheckResultTemplates) Then
		CommonClientServer.MessageToUser(NStr("ru = 'Шаблон сообщения не может быть записан.'; en = 'Cannot save template.'; pl = 'Nie można zapisać szablonu.';es_ES = 'No se ha podido guardar la plantilla.';es_CO = 'No se ha podido guardar la plantilla.';tr = 'Şablon kaydedilemiyor.';it = 'Impossibile salvare modello.';de = 'Vorlage kann nicht gespeichert werden.'")
			+ Chars.LF + CheckResultTemplates);
		Cancel = True;
		Return;
	EndIf;
	
	If CurrentObject.ForSMSMessages Then
		CurrentObject.SMSTemplateText = MessageBodyPlainText.GetText();
		CurrentObject.AttachmentFormat = Undefined;
	Else
		If CurrentObject.MailTextType = Enums.EmailEditingMethods.HTML Then
			HTMLWrappedText = "";
			HTMLAttachments = New Structure();
			EmailBodyInHTML.GetHTML(HTMLWrappedText, HTMLAttachments);
			CurrentObject.HTMLMessageTemplateText = HTMLWrappedText;
			CurrentObject.MessageTemplateText = EmailBodyInHTML.GetText();
		Else
			CurrentObject.MessageTemplateText = MessageBodyPlainText.GetText();
			If IsBlankString(CurrentObject.MessageTemplateText) Then
				CurrentObject.MessageTemplateText = EmailBodyInHTML.GetText();
			EndIf;
			CurrentObject.HTMLMessageTemplateText = CurrentObject.MessageTemplateText;
		EndIf;
		
		FormatsList = New ValueList;
		For each ListItem In SelectedSaveFormats Do
			If ListItem.Check Then
				FillPropertyValues(FormatsList.Add(), ListItem);
			EndIf;
		EndDo;
		CurrentObject.AttachmentFormat = New ValueStorage(FormatsList);
		
	EndIf;
	
	AttachmentsNamesToIDsMapsTable = New ValueList;
	AttachmentsStructure = New Structure;
	EmailBodyInHTML.GetHTML(CurrentObject.HTMLMessageTemplateText, AttachmentsStructure);
	For each Attachment In AttachmentsStructure Do
		AttachmentsNamesToIDsMapsTable.Add(Attachment.Key, New UUID,, Attachment.Value);
	EndDo;
	
	WriteParameters.Insert("HTMLAttachments", AttachmentsNamesToIDsMapsTable);
	
	If AttachmentsNamesToIDsMapsTable.Count() > 0 Then
			
			DocumentHTML = MessageTemplatesInternal.GetHTMLDocumentObjectFromHTMLText(CurrentObject.HTMLMessageTemplateText);
			ChangePicturesNamesToMailAttachmentsIDsInHTML( DocumentHTML, AttachmentsNamesToIDsMapsTable);
			CurrentObject.HTMLMessageTemplateText = MessageTemplatesInternal.GetHTMLTextFromHTMLDocumentObject(DocumentHTML);
			
	EndIf;
	
	CurrentObject.PrintFormsAndAttachments.Clear();
	For each Attachment In Attachments Do
		If Attachment.Selected = 1 Then
			NewRow = CurrentObject.PrintFormsAndAttachments.Add();
			NewRow.ID = Attachment.ID;
			NewRow.Name = Attachment.ParameterName;
		EndIf;
	EndDo;
	
	CurrentObject.Parameters.Clear();
	For each TemplateParameter In Object.Parameters Do
		NewRow = CurrentObject.Parameters.Add();
		FillPropertyValues(NewRow, TemplateParameter);
		NewRow.ParameterType = New ValueStorage(TemplateParameter.TypeDetails);
	EndDo;
	
EndProcedure

&AtServer
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	// Adding to the list of deleted attachments previously saved pictures displayed in the body of a formatted document.
	
	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperations = Common.CommonModule("FilesOperations");
		FileList = New Array;
		ModuleFilesOperations.FillFilesAttachedToObject(CurrentObject.Ref, FileList);
		For each Attachment In FileList Do
			If ValueIsFilled(Attachment.EmailFileID) Then
				DeleteAttachedFile(Attachment.Ref);
			EndIf;
		EndDo;
	EndIf;
	
	SaveFormattedDocumentPicturesAsAttachedFiles(CurrentObject.Ref, 
		CurrentObject.MailTextType, WriteParameters.HTMLAttachments, UUID);
	
	Index = Attachments.Count() - 1;
	While Index >= 0 Do
		AttachmentsTableRow = Attachments.Get(Index);
		If AttachmentsTableRow.Status = "ExternalToDelete" Then
			If Not AttachmentsTableRow.Ref.IsEmpty() Then
				DeleteAttachedFile(AttachmentsTableRow.Ref);
			EndIf;
			If IsBlankString(AttachmentsTableRow.Attribute) Then
				Attachments.Delete(Index)
			Else
				AttachmentsTableRow.Status  = "";
				AttachmentsTableRow.Selected = 2;
			EndIf;
		ElsIf AttachmentsTableRow.Status = "ExternalNew" Then
			FileName = ?(IsBlankString(AttachmentsTableRow.Attribute), AttachmentsTableRow.Presentation, AttachmentsTableRow.Attribute);
			RefToFile = MessageTemplatesInternal.WriteEmailAttachmentFromTempStorage(CurrentObject.Ref, AttachmentsTableRow, FileName, 0);
			AttachmentsTableRow.Ref = RefToFile;
			AttachmentsTableRow.Status ="ExternalAttached";
		EndIf;
		Index = Index - 1;
	EndDo;
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)

	// StandardSubsystems.AccessManagement
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.AfterWriteAtServer(ThisObject, CurrentObject, WriteParameters);
	EndIf;
	// End StandardSubsystems.AccessManagement
	
	FillArbitraryParametersFromObject(CurrentObject);
	ShowFormItems();
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	Notify("Write_MessagesTemplates", Object.Ref, ThisObject);
	
	If IsBlankString(Object.InputOnBasisParameterTypeFullName) Then
		Object.Purpose = MessageTemplatesClientServer.CommonIDPresentation();
		Object.ForInputOnBasis = False;
		Object.InputOnBasisParameterTypeFullName = MessageTemplatesClientServer.CommonID();
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SetFormatSelection();
	GeneratePresentationForSelectedFormats();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Write_File" AND TypeOf(Source) = Type("CatalogRef.MessageTemplatesAttachedFiles") Then
		RefreshPrintFormsList();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure FullInputOnBasisParameterTypeNameOnChange(Item)
	If IsBlankString(Object.InputOnBasisParameterTypeFullName) Then
		Object.InputOnBasisParameterTypeFullName = MessageTemplatesClientServer.CommonID();
	EndIf;
	Object.ForInputOnBasis = (Object.InputOnBasisParameterTypeFullName <> MessageTemplatesClientServer.CommonID());
	Object.Purpose = Items.InputOnBasisParameterTypeFullName.EditText;
	GenerateAttributesAndPrintFormsList();
EndProcedure

&AtClient
Procedure FullInputOnBasisParameterTypeNameClearing(Item, StandardProcessing)
	StandardProcessing = False;
EndProcedure

&AtClient
Procedure ExternalDataProcessorOnChange(Item)
	ShowFormItems();
EndProcedure

&AtClient
Procedure AttachmentFormatClick(Item, StandardProcessing)
	StandardProcessing    = False;
	
	If CommonClient.SubsystemExists("StandardSubsystems.Print") Then
		ModulePrintManagerInternalClient = CommonClient.CommonModule("PrintManagementInternalClient");
		Notification = New NotifyDescription("AttachmentFormatClickCompletion", ThisObject);
		ModulePrintManagerInternalClient.OpenAttachmentsFormatSelectionForm(SelectedFormatSettings(), Notification);
	EndIf
	
EndProcedure

&AtClient
Procedure HTMLEmailBodyOnChange(Item)
	EmailBodyInHTML.GetHTML(Object.HTMLMessageTemplateText, New Structure);
EndProcedure

&AtClient
Procedure MessageBodyPlainTextOnChange(Item)
	Object.MessageTemplateText = MessageBodyPlainText.GetText();
EndProcedure

&AtClient
Procedure MessageBodyPlainSMSMessageTextOnChange(Item)
	Object.SMSTemplateText = MessageBodyPlainText.GetText();
	MessageBodyPlainText.SetText(Object.SMSTemplateText); // Text message must not exceed 1024 characters.
EndProcedure

&AtClient
Procedure AuthorOnChange(Item)
	Object.AvailableToAuthorOnly = ValueIsFilled(Object.Author);
EndProcedure

#EndRegion

#Region AttachmentsFormTableItemsEventHandlers

&AtClient
Procedure AttachmentsBeforeAddRow(Item, Cancel, Clone, Parent, Folder, Parameter)
	Cancel = True;
	If Not Clone Then
		AddAttachmentExecute();
	EndIf;
EndProcedure

&AtClient
Procedure AttachmentsBeforeDeleteRow(Item, Cancel)
	DeleteAttachmentExecute();
	Cancel = True;
EndProcedure

&AtClient
Procedure AttachmentsOnActivateRow(Item)
	
	CurrentData = Items.Attachments.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If CurrentData.Status = "PrintForm" Or ValueIsFilled(CurrentData.Attribute) Then
		Items.AttachmentsContextMenuDelete.Enabled             = False;
		Items.AttachmentsContextMenuChangeAttachment.Enabled    = False;
		Items.AttachmentsChange.Enabled                           = False;
		Items.AttachmentsDelete.Enabled                            = False;
		Items.AttachmentsCopyAttachment.Enabled                = False;
		Items.AttachmentsContextMenuCopyAttachment.Enabled = False;
	Else
		Items.AttachmentsContextMenuDelete.Enabled             = True;
		Items.AttachmentsContextMenuChangeAttachment.Enabled    = True;
		Items.AttachmentsChange.Enabled                           = False;
		Items.AttachmentsDelete.Enabled                            = True;
		Items.AttachmentsCopyAttachment.Enabled                = True;
		Items.AttachmentsContextMenuCopyAttachment.Enabled = True;
	EndIf;

EndProcedure

&AtClient
Procedure AttachmentsSelectedOnChange(Item)
	CurrentData = Items.Attachments.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;

	If IsBlankString(CurrentData.Attribute) Then
		If CurrentData.Selected = 2 Then
			CurrentData.Selected = 0;
		EndIf;
	Else
		If CurrentData.Selected = 0 Then
			CurrentData.Selected = 2;
			AddAttachmentExecute(CurrentData.ID);
		ElsIf CurrentData.Selected = 2 Then
			CurrentData.Status = "ExternalToDelete";
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region AttributesFormTableItemsEventHandlers

&AtClient
Procedure AttributesBeforeAddRow(Item, Cancel, Clone, Parent, Folder, Parameter)
	Cancel = True;
	If UseArbitraryParameters Then
		AdditionalParameters = New Structure("Insert", True);
		ClosingNotification = New NotifyDescription("AfterCloseParameterForm", ThisObject, AdditionalParameters);
		FormParameters = New Structure("ParametersList, InputOnBasisParameterTypeFullName", Object.Parameters, Object.InputOnBasisParameterTypeFullName);
		OpenForm("Catalog.MessageTemplates.Form.ArbitraryParameter", FormParameters,,,,, ClosingNotification);
	EndIf;
EndProcedure

&AtClient
Procedure AttributesOnActivateRow(Item)
	CurrentData = Items.Attributes.CurrentData;
	FormattedOutputAvailability = False;
	If CurrentData <> Undefined Then
		If CurrentData.ArbitraryParameter Then
			Items.AttributesContextMenuDelete.Enabled = True;
			Items.Delete.Enabled = True;
			Items.AttributesContextMenuChange.Enabled = True;
		Else
			Items.AttributesContextMenuDelete.Enabled = False;
			Items.Delete.Enabled = False;
			Items.AttributesContextMenuChange.Enabled = False;
		EndIf;
		If CurrentData.GetItems().Count() > 0 Then
			ChangeAttributesContextMenuAvailability(False);
		Else
			ChangeAttributesContextMenuAvailability(True);
			For each Type In CurrentData.Type.Types() Do
				If Type = Type("Date") Or Type = Type("Number") Or Type = Type("Boolean") Then
					FormattedOutputAvailability = True;
					Break;
				EndIf;
			EndDo;
		EndIf;
	EndIf;
	If Items.AttributePresentationFormat.Enabled <> FormattedOutputAvailability Then
		Items.AttributePresentationFormat.Enabled = FormattedOutputAvailability;
	EndIf;
	
EndProcedure

&AtClient
Procedure AttributesChoice(Item, RowSelected, Field, StandardProcessing)
	
	Attribute = Attributes.FindByID(RowSelected);
	TreeItem = Attributes.FindByID(Attribute.GetID());
	If TreeItem.GetItems().Count() = 0 Then
		AddParameterToMessageText();
	EndIf;
	
EndProcedure

&AtClient
Procedure AttributesDragStart(Item, DragParameters, Perform)
	ObjectsToDrag = DragParameters.Value;
	TextForInsert = "";
	Separator = "";
	For each ObjectToDrag In ObjectsToDrag Do
		TreeItem = Attributes.FindByID(ObjectToDrag);
		If TreeItem.GetItems().Count() = 0 Then
			OutputFormat = ?(IsBlankString(TreeItem.Format), "", "{" + TreeItem.Format +"}");
			TextForInsert = TextForInsert + Separator + "[" + TreeItem.Name + OutputFormat + "]";
			Separator = " ";
		EndIf;
	EndDo;
	DragParameters.Value = TextForInsert;
	
	
EndProcedure

&AtClient
Procedure AttributesBeforeDeleteRow(Item, Cancel)
	If UseArbitraryParameters Then
		
		CurrentData = Items.Attributes.CurrentData;
		If CurrentData = Undefined OR NOT CurrentData.ArbitraryParameter Then
			Cancel = True;
			Return;
		EndIf;
		
		If StrStartsWith(CurrentData.Name, MessageTemplatesClientServer.ArbitraryParametersTitle()) Then
			Filter = New Structure("ParameterName", Mid(CurrentData.Name, StrLen(MessageTemplatesClientServer.ArbitraryParametersTitle()) + 2));
		Else
			Filter = New Structure("ParameterName", CurrentData.Name);
		EndIf;
		FoundRows = Object.Parameters.FindRows(Filter);
		If FoundRows.Count() > 0 Then
			Object.Parameters.Delete(FoundRows[0]);
		EndIf;
	EndIf;
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure EmailPlainText(Command)
	If Not Items.FormEmailPlainText.Check Then
		SetEmailPlainText(True);
	EndIf;
EndProcedure

&AtClient
Procedure HTMLEmail(Command)
	If Not Items.FormEmailHTML.Check Then
		SetHTMLEmail(True);
	EndIf;
EndProcedure

&AtClient
Procedure CheckTemplate(Command)
	
	ClearMessages();
	CheckResultTemplates = CheckResultTemplates();
	If ValueIsFilled(CheckResultTemplates) Then
		CommonClientServer.MessageToUser(CheckResultTemplates);
	Else
		ShowMessageBox(, NStr("ru = 'Шаблон заполнен корректно'; en = 'Template is valid.'; pl = 'Szablon jest prawidłowy.';es_ES = 'La plantilla es válida.';es_CO = 'La plantilla es válida.';tr = 'Şablon geçerli.';it = 'Modello valido.';de = 'Vorlage ist gültig.'"));
	EndIf;
	
EndProcedure

&AtClient
Procedure ByExternalDataProcessor(Command)
	
	If CommonClient.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		Notification = New NotifyDescription("AfterAdditionalReportsAndDataProcessorsChoice", ThisObject);
		KindName = "AdditionalReportsAndDataProcessorsKinds.MessageTemplate";
		FilterValue = New Structure("Kind", PredefinedValue("Enum." + KindName));
		FormParameters = New Structure("Filter", FilterValue);
		AdditionalReportsAndDataProcessorsFormName = "AdditionalReportsAndDataProcessors.ChoiceForm";
		OpenForm("Catalog." + AdditionalReportsAndDataProcessorsFormName, FormParameters, ThisObject,,,, Notification);
	EndIf
	
EndProcedure

&AtClient
Procedure ByTemplate(Command)
	
	Items.Pages.CurrentPage         = Items.EmailMessageHTML;
	
	Items.ExternalDataProcessorGroup.Visible = False;
	Items.ParametersGroup.Visible        = True;
	Items.FormFromTemplate.Check           = True;
	Items.FormByExternalDataProcessor.Check   = False;
	Items.EmailSubject.ReadOnly        = False;
	Object.TemplateByExternalDataProcessor           = False;
	Object.ExternalDataProcessor                   = Undefined;
	ShowFormItems();
	
EndProcedure

&AtClient
Procedure SetOutputFormat(Command)
	
	CurrentData = Items.Attributes.CurrentData;
	If CurrentData <> Undefined Then
		AdditionalParameters = New Structure("RowID", CurrentData.GetID());
		Handler = New NotifyDescription("AfterAttributeFormatChoice", ThisObject, AdditionalParameters);
		
		Dialog = New FormatStringWizard;
		Dialog.AvailableTypes = CurrentData.Type;
		Dialog.Text         = CurrentData.Format;
		Dialog.Show(Handler);
	EndIf;

EndProcedure

&AtClient
Procedure AfterAttributeFormatChoice(Result, AdditionalParameters) Export
	If Result <> Undefined Then
		Attribute = Attributes.FindByID(AdditionalParameters.RowID);
		If Attribute <> Undefined Then
			Attribute.Format = Result;
		EndIf;
	EndIf;
EndProcedure

&AtClient
Procedure AddParameterToMessageTextCommand(Command)
	
	AddParameterToMessageText();
	
EndProcedure

&AtClient
Procedure ChangeAttribute(Command)
	
	CurrentData = Items.Attributes.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If UseArbitraryParameters AND CurrentData.ArbitraryParameter Then
		RowIDs = CurrentData.GetID();
		AdditionalParameters = New Structure("Insert, SelectedRow", False, RowIDs);
		FormParameters = New Structure("ParameterName, ParameterPresentation, TypeDetails", CurrentData.Name, CurrentData.Presentation, CurrentData.Type);
		FormParameters.Insert("ParametersList", Object.Parameters);
		FormParameters.Insert("InputOnBasisParameterTypeFullName", Object.InputOnBasisParameterTypeFullName);
		
		ClosingNotification = New NotifyDescription("AfterCloseParameterForm", ThisObject, AdditionalParameters);
		OpenForm("Catalog.MessageTemplates.Form.ArbitraryParameter", FormParameters,,,,, ClosingNotification);
	EndIf;
	
EndProcedure

&AtClient
Procedure AddParameterToMessageSubject(Command)
	
	CurrentData = Items.Attributes.CurrentData;
	If CurrentData <> Undefined Then
		OutputFormat = ?(IsBlankString(CurrentData.Format), "", "{" + CurrentData.Format +"}");
		ParameterStart = ?(Right(Object.EmailSubject, 1) = " ", "[", " [");
		Object.EmailSubject = Object.EmailSubject + ParameterStart + CurrentData.Name + OutputFormat + "]";
	EndIf;
	
EndProcedure

&AtClient
Procedure ChangeAttachment(Command)
	
	CurrentData = Items.Attachments.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	CurrentIDInCollection = Items.Attachments.CurrentRow;
	
	If CurrentData.Ref = PredefinedValue("Catalog.MessageTemplatesAttachedFiles.EmptyRef") Then
		AdditionalParameters = New Structure("CurrentIndexInCollection", CurrentIDInCollection);
		OnCloseNotifyHandler = New NotifyDescription("ChangeAttachmentCompletion", ThisObject, AdditionalParameters);
		QuestionText = NStr("ru = 'Свойства файла доступны только после его записи. Записать?'; en = 'The file properties will be available after you save the file. Do you want to save it?'; pl = 'Właściwości pliku będą dostępne po zapisaniu pliku. Czy chcesz zapisać go?';es_ES = 'Las propiedades del archivo estarán disponibles después de guardar el archivo. ¿Quiere guardarlo?';es_CO = 'Las propiedades del archivo estarán disponibles después de guardar el archivo. ¿Quiere guardarlo?';tr = 'Dosya kaydedildikten sonra özelliklerine erişilebilir. Dosya kaydedilsin mi?';it = 'Le proprietà del file saranno disponibili dopo aver salvato il file. Salvare il file?';de = 'Die Dateieigenschaften sind nach dem Speichern der Datei verfügbar. Möchten Sie sie speichern?'");
		ShowQueryBox(OnCloseNotifyHandler, QuestionText, QuestionDialogMode.YesNo);
	Else
		OpenAttachmentProperties(CurrentIDInCollection);
	EndIf;

EndProcedure

&AtClient
Procedure CopyAttachment(Command)
	CurrentData = Items.Attachments.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	ID = Items.Attachments.CurrentRow;
	
	If CurrentData.Ref = PredefinedValue("Catalog.MessageTemplatesAttachedFiles.EmptyRef") Then
		AdditionalParameters = New Structure("CurrentIndexInCollection", ID);
		OnCloseNotifyHandler = New NotifyDescription("CopyAttachmentCompletion", ThisObject, AdditionalParameters);
		QuestionText = NStr("ru = 'Файл возможно скопировать только после записи шаблона сообщения. Записать?'; en = 'You can copy the file after you save the template. Do you want to save it?'; pl = 'Skopiować plik można tylko po zapisaniu szablonu. Czy chcesz zapisać go?';es_ES = 'Se puede copiar el archivo después de guardar la plantilla. ¿Quiere guardarlo?';es_CO = 'Se puede copiar el archivo después de guardar la plantilla. ¿Quiere guardarlo?';tr = 'Şablon kaydedildikten sonra dosya kopyalanabilir. Şablonu kaydetmek istiyor musunuz?';it = 'È possibile copiare il file dopo aver salvato il modello. Salvare il modello?';de = 'Sie können die Datei kopieren, nachdem Sie die Vorlage gespeichert haben. Möchten Sie sie speichern?'");
		ShowQueryBox(OnCloseNotifyHandler, QuestionText, QuestionDialogMode.YesNo);
	Else
		CopyAttachmentFile(ID);
	EndIf;
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure AfterCloseParameterForm(ParameterDetails, AdditionalParameters) Export
	If TypeOf(ParameterDetails) = Type("Structure") Then
		Modified = True;
		If AdditionalParameters.Insert Then
			AddArbitraryParameter(ParameterDetails);
		Else
			Attribute = Attributes.FindByID(AdditionalParameters.SelectedRow);
			If StrStartsWith(Attribute.Name, MessageTemplatesClientServer.ArbitraryParametersTitle()) Then
				Filter = New Structure("ParameterName", Mid(Attribute.Name, StrLen(MessageTemplatesClientServer.ArbitraryParametersTitle()) + 2));
			Else
				Filter = New Structure("ParameterName", Attribute.Name);
			EndIf;
			FoundRows = Object.Parameters.FindRows(Filter);
			If FoundRows.Count() > 0 Then
				Object.Parameters.Delete(FoundRows[0]);
			EndIf;
			AddArbitraryParameter(ParameterDetails);
		EndIf;
	EndIf;
EndProcedure

&AtClient
Procedure ChangeAttributesContextMenuAvailability(NewValue)
	
	If Items.AttributesContextMenuAddParameterToMessageText.Enabled <> NewValue Then
		Items.AttributesContextMenuAddParameterToMessageText.Enabled = NewValue;
		Items.AttributesContextMenuAddParameterToMessageSubject.Enabled = NewValue;
		Items.AddParameterToMessageSubject.Enabled = NewValue;
		Items.AttributesAddParameterToMessageText.Enabled = NewValue;
		Items.AttributesContextMenuAddParameterToSMSMessageText.Enabled = NewValue;
		Items.AttributesMenuAddParameterToSMSMessageText.Enabled = NewValue;
	EndIf;
	
EndProcedure

&AtClient
Function SelectedFormatSettings()
	
	SaveFormats = New Array;
	
	For Each SelectedFormat In SelectedSaveFormats Do
		If SelectedFormat.Check Then
			SaveFormats.Add(SelectedFormat.Value);
		EndIf;
	EndDo;
	
	Result = New Structure;
	Result.Insert("PackToArchive", Object.PackToArchive);
	Result.Insert("SaveFormats", SaveFormats);
	Result.Insert("To", New Array);
	Result.Insert("TransliterateFilesNames", Object.TransliterateFileNames);
	
	Return Result;
	
EndFunction

&AtClient
Procedure SetFormatSelection(Val SaveFormats = Undefined)
	
	If Object.ForSMSMessages Then
		Return;
	EndIf;
	
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
		SelectedSaveFormats[0].Check = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure AttachmentFormatClickCompletion(Result, AdditionalParameters) Export
	
	FormatsChoiceResult = Result;
	If FormatsChoiceResult <> DialogReturnCode.Cancel AND FormatsChoiceResult <> Undefined Then
		SetFormatSelection(FormatsChoiceResult.SaveFormats);
		Object.PackToArchive = FormatsChoiceResult.PackToArchive;
		Object.TransliterateFileNames = FormatsChoiceResult.TransliterateFilesNames;
		GeneratePresentationForSelectedFormats();
		Modified = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure GeneratePresentationForSelectedFormats()
	
	PrintFormsFormat = "";
	FormatsCount = 0;
	For Each SelectedFormat In SelectedSaveFormats Do
		If SelectedFormat.Check Then
			If Not IsBlankString(PrintFormsFormat) Then
				PrintFormsFormat = PrintFormsFormat + ", ";
			EndIf;
			PrintFormsFormat = PrintFormsFormat + SelectedFormat.Presentation;
			FormatsCount = FormatsCount + 1;
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Procedure AddArbitraryParameter(ParameterDetails)
	NewParameter = Object.Parameters.Add();
	FillPropertyValues(NewParameter, ParameterDetails);
	
	TypesArray = New Array;
	TypesArray.Add(ParameterDetails.ParameterType);
	TypeDetails = New TypeDescription(TypesArray);
	NewParameter.TypeDetails = TypeDetails;
	
	GenerateAttributesAndPrintFormsList();
EndProcedure

&AtServer
Procedure InitializeNewMessagesTemplate(Val MessagesTemplatesSettings)
	
	MessageKind = Parameters.MessageKind;
	
	If ValueIsFilled(Parameters.FullBasisTypeName)
		 AND MessageTemplatesInternal.ObjectIsTemplateSubject(Parameters.FullBasisTypeName) Then
		
		// Context call
		Object.InputOnBasisParameterTypeFullName = Parameters.FullBasisTypeName;
		If Not Parameters.CanChangeAssignment Then
			Items.AssignmentGroup.Visible = False;
		EndIf;
		
		Object.ForInputOnBasis = True;
		
		NameToAssignment = Parameters.FullBasisTypeName;
		TemplateAssignment = MessagesTemplatesSettings.TemplateSubjects.Find(NameToAssignment, "Presentation");
		If TemplateAssignment = Undefined Then
			TemplateAssignment = MessagesTemplatesSettings.TemplateSubjects.Find(NameToAssignment, "Name");
		EndIf;
		If TemplateAssignment <> Undefined Then
			Object.InputOnBasisParameterTypeFullName = TemplateAssignment.Name;
			Object.Purpose                             = TemplateAssignment.Presentation;
		Else
			Object.InputOnBasisParameterTypeFullName = NameToAssignment;
			Object.Purpose                             = NameToAssignment;
		EndIf;
		
	ElsIf Parameters.ChoiceParameters.Count() > 0 Then
		
		NameToAssignment = ?(Parameters.ChoiceParameters.Property("Purpose"), Parameters.ChoiceParameters.Purpose, "");
		
		If Parameters.ChoiceParameters.Property("InputOnBasisParameterTypeFullName") Then
			NameToAssignment = Parameters.ChoiceParameters.InputOnBasisParameterTypeFullName;
		EndIf;
			
		If ValueIsFilled(NameToAssignment) Then
			TemplateAssignment = MessagesTemplatesSettings.TemplateSubjects.Find(NameToAssignment, "Presentation");
			If TemplateAssignment = Undefined Then
				TemplateAssignment = MessagesTemplatesSettings.TemplateSubjects.Find(NameToAssignment, "Name");
			EndIf;
			If TemplateAssignment <> Undefined Then
				Object.InputOnBasisParameterTypeFullName = TemplateAssignment.Name;
				Object.Purpose                             = TemplateAssignment.Presentation;
				Object.ForInputOnBasis        = True;
				Items.AssignmentGroup.Visible           = False;
			EndIf;
		EndIf;
		
		If Parameters.ChoiceParameters.Property("ForEmails") 
			AND Parameters.ChoiceParameters.ForEmails Then
			MessageKind = "Email"
		ElsIf Parameters.ChoiceParameters.Property("ForSMSMessages")
			AND Parameters.ChoiceParameters.ForSMSMessages Then
			MessageKind = "SMSMessage"
		EndIf;
		
	ElsIf Parameters.Basis = Undefined Then
		
		Object.ForInputOnBasis = False;
		Object.InputOnBasisParameterTypeFullName = MessageTemplatesClientServer.CommonID();
		
	EndIf;
	
	If Parameters.Basis = Undefined Then
		
		If MessageKind = "SMSMessage" Then
			Object.ForSMSMessages = True;
			Object.ForEmails = False;
		Else
			Object.ForSMSMessages = False;
			Object.ForEmails = True;
			Object.MailTextType = Enums.EmailEditingMethods.HTML;
		EndIf;
		Object.AvailableToAuthorOnly = False;
		
	Else
		
		TemplateGenerated = False;
		If Common.SubsystemExists("StandardSubsystems.Interactions") Then
			
			ModuleEmailManager = Common.CommonModule("EmailManagement");
			If ModuleEmailManager.IsEmailOrMessage(Parameters.Basis) Then
				TemplateBasedOnInteractionDocument();
				TemplateGenerated = True;
			EndIf;
		
		EndIf;
		
		If Not TemplateGenerated Then
			
			If Object.MailTextType = Enums.EmailEditingMethods.HTML Then
				EmailBodyInHTML.SetHTML(Object.HTMLMessageTemplateText, New Structure);
			Else
				MessageBodyPlainText.SetText(Object.MessageTemplateText);
			EndIf;
			
		EndIf;
		
	EndIf;
	
	Parameters.Property("TemplateOwner", Object.TemplateOwner);
	
EndProcedure

&AtServer
Procedure TemplateBasedOnInteractionDocument()
	
	If Not Common.SubsystemExists("StandardSubsystems.Interactions")
		Or Not Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
			Return;
	EndIf;
	
	ModuleEmailManager = Common.CommonModule("EmailManagement");
	ModuleStoredFiles = Common.CommonModule("FilesOperations");
	ModuleStoredFilesClientServer = Common.CommonModule("FilesOperationsClientServer");
	
	EmailAttachments = ModuleEmailManager.EmailAttachments(Parameters.Basis, UUID);
	
	AdditionalFileParameters = ModuleStoredFilesClientServer.FileDataParameters();
	AdditionalFileParameters.FormID = UUID;
	AdditionalFileParameters.RaiseException = False;
	
	For each Attachment In EmailAttachments Do
		If IsBlankString(Attachment.EmailFileID) Then
			
			Extension                 = GetFileExtension(Attachment.Description);
			NewRow                = Attachments.Add();
			NewRow.Status         = "ExternalNew";
			NewRow.Selected        = 1;
			NewRow.Presentation  = Attachment.Description;
			NewRow.ID  = Attachment.Description;
			NewRow.PictureIndex = GetFileIconIndex(Extension);
			NewRow.Name           =  ModuleStoredFiles.FileData(Attachment.Ref,
				AdditionalFileParameters).BinaryFileDataRef;
		EndIf;
	EndDo;
	
	If Object.MailTextType = Enums.EmailEditingMethods.HTML Then
		
		TemplateParameter = New Structure("Template, UUID");
		TemplateParameter.Template = Object.Ref;
		TemplateParameter.UUID = UUID;
		Message = MessageTemplatesInternal.MessageConstructor();
		Message.Text = Object.HTMLMessageTemplateText;
		MessageTemplatesInternal.ProcessHTMLForFormattedDocument(TemplateParameter, Message, True, EmailAttachments);
		AttachmentsStructure = New Structure();
		For each HTMLAttachment In Message.Attachments Do
			Picture = New Picture(GetFromTempStorage(HTMLAttachment.AddressInTempStorage));
			AttachmentsStructure.Insert(HTMLAttachment.Presentation, Picture);
		EndDo;
		EmailBodyInHTML.SetHTML(Message.Text, AttachmentsStructure);
		
	Else
		MessageBodyPlainText.SetText(Object.MessageTemplateText);
	EndIf;

EndProcedure

&AtServer
Procedure InitializeSaveFormats()
	
	If Common.SubsystemExists("StandardSubsystems.Print") Then
		ModulePrintManager = Common.CommonModule("PrintManagement");
		If SelectedSaveFormats.Count() = 0 Then
			For Each SaveFormat In ModulePrintManager.SpreadsheetDocumentSaveFormats() Do
				SelectedSaveFormats.Add(SaveFormat.SpreadsheetDocumentFileType, String(SaveFormat.Ref), False, SaveFormat.Picture);
			EndDo;
		EndIf;
	EndIf;

EndProcedure

&AtServer
Procedure SetTemplateText(CurrentObject, FileList = Undefined)
	
	If CurrentObject.ForSMSMessages Then
		MessageBodyPlainText.SetText(CurrentObject.SMSTemplateText);
	Else
		If CurrentObject.MailTextType = Enums.EmailEditingMethods.HTML Then
			SetHTMLForFormattedDocument(CurrentObject.HTMLMessageTemplateText, CurrentObject.Ref, FileList);
		Else
			MessageBodyPlainText.SetText(CurrentObject.MessageTemplateText);
		EndIf;
	EndIf;

EndProcedure

&AtServer
Procedure ShowFormItems(EmailFormat = "")
	
	If Object.ForSMSMessages Then
		TitleSuffix = NStr("ru = 'Шаблон сообщения SMS'; en = 'Text message template'; pl = 'Szablon wiadomości SMS';es_ES = 'Modelo del SMS';es_CO = 'Modelo del SMS';tr = 'SMS şablonu';it = 'Modello messaggio di testo';de = 'Vorlage der Textnachricht'");
		Items.FormEmailTextKind.Visible = False;
		Items.Pages.CurrentPage = Items.SMSMessage;
		Items.EmailSubject.Visible = False;
		Items.HiddenTitleParameters.Visible = False;
		Items.AttachmentsGroup.Visible = False;
		Items.AttributesContextMenuAddMailParameter.Visible = False;
		Items.AttributesMenuAddMailParameter.Visible = False;
		Items.AttributesContextMenuAddParameterToSMSMessageText.Visible = True;
		Items.AttributesMenuAddParameterToSMSMessageText.Visible = True;
		Items.HiddenTilteSMSMessage.Visible = True;
	Else
		TitleSuffix = NStr("ru = 'Шаблон сообщения электронного письма'; en = 'Email message template'; pl = 'Szablon wiadomości e-mail';es_ES = 'Modelo de mensaje de correo electrónico';es_CO = 'Modelo de mensaje de correo electrónico';tr = 'E-posta şablonu';it = 'Modello messaggio email';de = 'Vorlage der E-Mail-Nachricht'");
		Items.AttachmentsGroup.Visible = True;
		Items.AttributesContextMenuAddMailParameter.Visible = True;
		Items.AttributesMenuAddMailParameter.Visible = True;
		Items.AttributesContextMenuAddParameterToSMSMessageText.Visible = False;
		Items.AttributesMenuAddParameterToSMSMessageText.Visible = False;
		
		If NOT EmailFormatPredefined(EmailFormat) Then
			If Object.MailTextType = Enums.EmailEditingMethods.HTML Then
				SetHTMLEmail();
			Else
				SetEmailPlainText();
			EndIf;
		EndIf;
		
	EndIf;
	
	If ValueIsFilled(Object.Ref) Then
		Title = Object.Description + " (" + TitleSuffix + ")";
	Else
		Title = TitleSuffix + " (" + NStr("ru = 'создание'; en = 'create'; pl = 'utwórzenie';es_ES = 'crear';es_CO = 'crear';tr = 'oluştur';it = 'creare';de = 'erstellen'")+ ")";
	EndIf;
	
	If Object.TemplateByExternalDataProcessor Then
		Items.AssignmentGroup.Enabled = False;
		Items.EmailSubject.ReadOnly = True;
		Items.ExternalDataProcessorGroup.Visible = True;
		Items.ParametersGroup.Visible = False;
		Items.FormByExternalDataProcessor.Check = True;
		Items.FormFromTemplate.Check = False;
		FillTemplateByExternalDataProcessor();
	Else
		Items.InputOnBasisParameterTypeFullName.Enabled = True;
		Items.EmailSubject.ReadOnly = False;
		Items.ExternalDataProcessorGroup.Visible = False;
		Items.ParametersGroup.Visible = True;
		Items.FormByExternalDataProcessor.Check = False;
		Items.FormFromTemplate.Check = True;
	EndIf;
	
	Items.AccessGroup.Visible = 
		NOT AccessParameters("Update", Metadata.Catalogs.MessageTemplates, "Ref").RestrictionByCondition;
		
	If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		ModuleAdditionalReportsAndDataProcessors = Common.CommonModule("AdditionalReportsAndDataProcessors");
		Items.FormMessageToGenerateGroup.Visible = ModuleAdditionalReportsAndDataProcessors.AdditionalReportsAndDataProcessorsAreUsed();
	Else
		Items.FormMessageToGenerateGroup.Visible = False;
	EndIf;
	
	If NOT Common.SubsystemExists("StandardSubsystems.Print") Then
		Items.AttachmentsSettingsGroup.Visible = False;
	EndIf;
	
EndProcedure

&AtServer
Function EmailFormatPredefined(Val EmailFormat)
	
	If ValueIsFilled(EmailFormat) Then
		If EmailFormat = "HTMLOnly" Then
			Object.MailTextType = Enums.EmailEditingMethods.HTML;
			SetHTMLEmail();
			Items.FormEmailHTML.Visible = False;
			Return True;
		ElsIf EmailFormat = "PlainTextOnly" Then
			Object.MailTextType = Enums.EmailEditingMethods.NormalText;
			SetEmailPlainText();
			Items.FormEmailHTML.Visible = False;
			Return True;
		EndIf;
	EndIf;
	
	Return False;

EndFunction

&AtServer
Procedure SetHTMLForFormattedDocument(HTMLEmailTemplateText, CurrentObjectRef, FileList = Undefined)
	
	TemplateParameter = New Structure("Template, UUID");
	TemplateParameter.Template = CurrentObjectRef;
	TemplateParameter.UUID = UUID;
	Message = MessageTemplatesInternal.MessageConstructor();
	Message.Text = HTMLEmailTemplateText;
	MessageTemplatesInternal.ProcessHTMLForFormattedDocument(TemplateParameter, Message, True, FileList);
	AttachmentsStructure = New Structure();
	If FileList <> Undefined Then
		
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("FormID", UUID);
		AdditionalParameters.Insert("RaiseException", False);
		
		For each Attachment In FileList Do
				If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
					If ValueIsFilled(Attachment.EmailFileID) Then
						ModuleFilesOperations = Common.CommonModule("FilesOperations");
						FileInfo = ModuleFilesOperations.FileData(Attachment, AdditionalParameters);
						Picture = New Picture(GetFromTempStorage(FileInfo.BinaryFileDataRef));
						AttachmentsStructure.Insert(FileInfo.Description, Picture);
					EndIf;
				EndIf;
		EndDo;
	Else
		For each HTMLAttachment In Message.Attachments Do
			Picture = New Picture(GetFromTempStorage(HTMLAttachment.AddressInTempStorage));
			AttachmentsStructure.Insert(HTMLAttachment.Presentation, Picture);
		EndDo;
	EndIf;
	EmailBodyInHTML.SetHTML(Message.Text, AttachmentsStructure);
	
EndProcedure

// business logic

&AtServer
Procedure GenerateAttributesAndPrintFormsList()
	
	TemplateParameters = MessageTemplatesInternal.TemplateParameters(Object);
	TemplateInfo = MessageTemplatesInternal.TemplateInfo(TemplateParameters);
	TemplateParameters.MessageParameters = MessageParameters;
	
	Attributes.GetItems().Clear();
	AttributesList = FormAttributeToValue("Attributes");
	FIllAttributeTree(AttributesList, TemplateInfo.Attributes);
	FIllAttributeTree(AttributesList, TemplateInfo.CommonAttributes, True);
	ValueToFormAttribute(AttributesList, "Attributes");
	
	GeneratePrintFormsList(TemplateInfo);
	
EndProcedure

&AtServer
Procedure GeneratePrintFormsList(TemplateInfo)
	
	SelectedPrintFormsAndAttachments = Object.PrintFormsAndAttachments.Unload(, "ID").UnloadColumn("ID");
	
	Filter = New Structure("Status", "ExternalNew");
	UnsavedFiles = Attachments.FindRows(Filter);
	Attachments.Clear();
	
	For each Attachment In TemplateInfo.Attachments Do
		
		Selected = 0;
		If SelectedPrintFormsAndAttachments.Find(Attachment.ID) <> Undefined Then
			Selected = 1;
		ElsIf ValueIsFilled(Attachment.Attribute) Then
			Selected = 2;
		EndIf;
		
		NewRow = Attachments.Add();
		FillPropertyValues(NewRow, Attachment);
		Extension = ?(IsBlankString(Attachment.FileType), "mxl", Attachment.FileType);
		NewRow.PictureIndex = GetFileIconIndex(Extension);
		NewRow.Selected        = Selected;
		
	EndDo;
	
	FillAttachments();
	For each UnsavedFile In UnsavedFiles Do
		If SelectedPrintFormsAndAttachments.Find(UnsavedFile.ID) = Undefined Then
			NewRow = Attachments.Add();
			FillPropertyValues(NewRow, UnsavedFile);
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Procedure RefreshPrintFormsList()
	
	TemplateParameters = MessageTemplatesInternal.TemplateParameters(Object);
	TemplateInfo = MessageTemplatesInternal.TemplateInfo(TemplateParameters);
	
	GeneratePrintFormsList(TemplateInfo);
	
EndProcedure

&AtServer
Function GetFileIconIndex(Extension)
	
	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsInternalClientServer = Common.CommonModule("FilesOperationsInternalClientServer");
		Return ModuleFilesOperationsInternalClientServer.GetFileIconIndex(Extension);
	EndIf;
	
	Return 0;
	
EndFunction

&AtClient
Function GetFileIconIndexClient(Extension)
	
	If CommonClient.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsInternalClientServer = CommonClient.CommonModule("FilesOperationsInternalClientServer");
		Return ModuleFilesOperationsInternalClientServer.GetFileIconIndex(Extension);
	EndIf;
	
	Return 0;
	
EndFunction

&AtServer
Procedure FIllAttributeTree(Destination, Source, AreCommonOrArbitraryAttributes = Undefined)
	
	For Each TreeRow In Source.Rows Do
		
		If AreCommonOrArbitraryAttributes = Undefined Then
			If TreeRow.Name = MessageTemplatesClientServer.ArbitraryParametersTitle()
				OR TreeRow.Name = MessageTemplatesInternal.CommonAttributesTitle() Then
				CommonOrArbitraryAttributes = True;
			Else
				
				CommonOrArbitraryAttributes = False;
			EndIf;
		Else
			CommonOrArbitraryAttributes = AreCommonOrArbitraryAttributes;
		EndIf;
		
		PictureIndexItem = ?(CommonOrArbitraryAttributes, 1, 3);
		PictureIndexNode = ?(CommonOrArbitraryAttributes, 0, 2);
		
		NewRow = Destination.Rows.Add();
		FillPropertyValues(NewRow, TreeRow);
		
		If TreeRow.Rows.Count() > 0 Then
			NewRow.PictureIndex = PictureIndexNode;
			FIllAttributeTree(NewRow, TreeRow, CommonOrArbitraryAttributes);
		Else
			NewRow.PictureIndex = PictureIndexItem;
		EndIf;
	EndDo;
	Destination.Rows.Sort("Presentation", True);
	
EndProcedure

// test template
&AtServer
Function CheckResultTemplates()
	
	TemplateParameters = MessageTemplatesInternal.TemplateParameters(Object);
	TemplateInfo = MessageTemplatesInternal.TemplateInfo(TemplateParameters);
	
	ErrorAttributes = New Array;
	MessageTextParameters = MessageTemplatesInternal.ParametersFromMessageText(TemplateParameters);
	MessageTemplatesInternal.DetermineErrorAttributes(MessageTextParameters, ErrorAttributes, TemplateInfo);
	
	ErrorText = "";
	If ErrorAttributes.Count() > 0 Then
		ErrorText = ?(ErrorAttributes.Count() = 1,
			NStr("ru = 'Некорректный параметр:'; en = 'Invalid placeholder:'; pl = 'Niepoprawny symbol zastępczy:';es_ES = 'Marcador de posición no válido:';es_CO = 'Marcador de posición no válido:';tr = 'Geçersiz yer tutucu:';it = 'Segnaposto non valido:';de = 'Ungültiger Platzhalter:'"),
			NStr("ru = 'Некорректные параметры:'; en = 'Invalid placeholders:'; pl = 'Niepoprawne symbole zastępcze:';es_ES = 'Marcadores de posición no válidos:';es_CO = 'Marcadores de posición no válidos:';tr = 'Geçersiz yer tutucular:';it = 'Segnaposto non validi:';de = 'Ungültige Platzhalter:'")) + " ";
		Separator = "";
		For each ErrorAttribute In ErrorAttributes Do
			ErrorText = ErrorText + Separator + TrimAll(ErrorAttribute);
			Separator = ", ";
		EndDo;
	EndIf;
	
	Return ErrorText;
	
EndFunction

// Forced setting of properties on the server

&AtServer
Procedure SetHTMLEmail(TextWrappingRequired = False)
	
	Items.FormEmailTextKind.Title = "HTML";
	Items.EmailMessage.Visible       = False;
	Items.EmailMessageHTML.Visible   = True;
	Items.Pages.CurrentPage                   = Items.EmailMessageHTML;
	Items.FormEmailPlainText.Check = False;
	Items.FormEmailHTML.Check         = True;
	
	Object.MailTextType = PredefinedValue("Enum.EmailEditingMethods.HTML");
	If TextWrappingRequired Then
		AttachmentsFormattedDocument = New Structure;
		MessageBodyNormalHTMLWrappedText = StrReplace(MessageBodyPlainText.GetText(), Chars.LF, "<br>");
		EmailBodyInHTML.SetHTML(MessageBodyNormalHTMLWrappedText, AttachmentsFormattedDocument);
	EndIf;
	
	Items.HiddenTitleParameters.Visible = True;
	Items.TitleParametersPages.CurrentPage = Items.TitleParametersPage;
	
EndProcedure

&AtServer
Procedure SetEmailPlainText(TextWrappingRequired = False)
	Items.FormEmailTextKind.Title = NStr("ru = 'Обычный текст'; en = 'Plain text'; pl = 'Zwykły tekst';es_ES = 'Texto regular';es_CO = 'Texto regular';tr = 'Düz metin';it = 'Testo semplice';de = 'Reiner Text'");
	Items.EmailMessageHTML.Visible = False;
	Items.EmailMessage.Visible = True;
	Items.Pages.CurrentPage = Items.EmailMessage;
	Items.FormEmailPlainText.Check = True;
	Items.FormEmailHTML.Check = False;
	Object.MailTextType = PredefinedValue("Enum.EmailEditingMethods.NormalText");
	If TextWrappingRequired Then
		MessageBodyPlainText.SetText(EmailBodyInHTML.GetText());
	EndIf;
	
	Items.HiddenTitleParameters.Visible = False;
	Items.HiddenTilteSMSMessage.Visible = False;
	Items.TitleParametersPages.CurrentPage = Items.TitleParametersPage;
EndProcedure

// Attachments

&AtClient
Procedure AddAttachmentExecute(ID = Undefined)
	
	AdditionalParameters = New Structure("ID", ID);
	NotifyDescription = New NotifyDescription("FileSelectionDialogAfterChoice", ThisObject, AdditionalParameters);
	
	FileImportParameters = FileSystemClient.FileImportParameters();
	FileImportParameters.FormID = ThisObject.UUID;
	FileSystemClient.ImportFiles(NotifyDescription, FileImportParameters);
	
EndProcedure

&AtClient
Procedure FileSelectionDialogAfterChoice(SelectedFiles, AdditionalParameters) Export
	
	If SelectedFiles = Undefined Then
		Return;
	EndIf;
	
	For Each SelectedFile In SelectedFiles Do
		
		FileName                   = "";
		Extension                 = GetFileExtension(SelectedFile.Name);
		
		NewString                = Attachments.Add();
		NewString.Status         = "ExternalNew";
		NewString.Selected        = 1;
		NewString.Name            = SelectedFile.Location;
		NewString.Presentation  = SelectedFile.Name;
		NewString.ID  = SelectedFile.Name;
		NewString.PictureIndex = GetFileIconIndexClient(Extension);
		
	EndDo;
	
	Modified = True;
	
EndProcedure

// Receives an extension for the passed file name.
//
// Parameters:
//  FileName - String - a name of the file to get the extension for.
//
// Returns:
//   String - an extension received from the passed file.
//
&AtClientAtServerNoContext
Function GetFileExtension(Val FileName)
	
	FileExtention = "";
	RowsArray = StrSplit(FileName, ".", False);
	If RowsArray.Count() > 1 Then
		FileExtention = RowsArray[RowsArray.Count() - 1];
	EndIf;
	
	Return FileExtention;
	
EndFunction

&AtClient
Procedure PlaceFilesFromLocalFSInTempStorage(Attachments, UUID, Cancel)
	
#If Not WebClient Then
	
	For Each AttachmentsTableRow In Attachments Do
		If AttachmentsTableRow.Status = "ExternalNew" Then
			Try
				
				If Not StrStartsWith(AttachmentsTableRow.Name, "e1cib") Then
					Data = New BinaryData(AttachmentsTableRow.Name);
					AttachmentsTableRow.Name = PutToTempStorage(Data, UUID);
				EndIf;
				
			Except
				CommonClientServer.MessageToUser(BriefErrorDescription(ErrorInfo()),, "Attachments",, Cancel);
			EndTry;
		EndIf;
	EndDo;
	
#EndIf
	
EndProcedure

&AtClient
Procedure OpenAttachmentProperties(ID)
	
	CurrentData = Attachments.FindByID(ID);
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	Items.Attachments.CurrentRow = ID;
	
	If CommonClient.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsClient = CommonClient.CommonModule("FilesOperationsClient");
		ModuleFilesOperationsClient.OpenFileForm(CurrentData.Ref);
	EndIf
	
EndProcedure

&AtClient
Procedure CopyAttachmentFile(ID)
	
	CurrentData = Attachments.FindByID(ID);
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	Items.Attachments.CurrentRow = ID;
	
	If CommonClient.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperationsClient = CommonClient.CommonModule("FilesOperationsClient");
		ModuleFilesOperationsClient.CopyFile(Object.Ref, CurrentData.Ref);
	EndIf
	
EndProcedure

&AtClient
Procedure ChangeAttachmentCompletion(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult = DialogReturnCode.Yes Then
		Write();
		OpenAttachmentProperties(AdditionalParameters.CurrentIndexInCollection);
	EndIf;
	
EndProcedure

&AtClient
Procedure CopyAttachmentCompletion(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult = DialogReturnCode.Yes Then
		If Write() Then
			CopyAttachmentFile(AdditionalParameters.CurrentIndexInCollection);
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure FillAttachments(PassedParameters = Undefined)
	
	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperations = Common.CommonModule("FilesOperations");
		
		FileList = New Array;
		ModuleFilesOperations.FillFilesAttachedToObject(Object.Ref, FileList);
		For Each RefToFile In FileList Do
			FileInfo = Common.ObjectAttributesValues(RefToFile, "EmailFileID, PictureIndex, Description, Extension");
			If IsBlankString(FileInfo.EmailFileID) Then
				Filter = New Structure("Attribute", FileInfo.Description);
				FoundRows = Attachments.FindRows(Filter);
				If FoundRows.Count() = 0 Then
					NewRow = Attachments.Add();
					NewRow.Presentation = FileInfo.Description + "." + FileInfo.Extension;
					NewRow.PictureIndex = FileInfo.PictureIndex;
					NewRow.Ref = RefToFile;
					NewRow.Status = "ExternalAttached";
				Else
					FoundRows[0].Ref = RefToFile;
				EndIf;
			EndIf;
		EndDo;
		
	EndIf
EndProcedure

&AtServer
Function CopyAttachmentsFromSource()
	
	FileList = New Array;
	ErrorsList = Undefined;
	ErrorDescription = NStr("ru = 'Не удалось скопировать вложение по причине: %1'; en = 'Cannot copy the attachment due to: %1'; pl = 'Nie można skopiować załącznika z powodu: %1';es_ES = 'No se puede copiar el adjunto debido a: %1';es_CO = 'No se puede copiar el adjunto debido a: %1';tr = 'Eklenti şu nedenle kaydedilemiyor: %1';it = 'Impossibile copiare l''allegato a causa di: %1';de = 'Der Anhang kann nicht kopiert werden wegen: %1'");
	
	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperations = Common.CommonModule("FilesOperations");
		ModuleFilesOperations.FillFilesAttachedToObject(Parameters.CopyingValue, FileList);
		For each Attachment In FileList Do
			If IsBlankString(Attachment.EmailFileID) Then
				Try
					FileData = ModuleFilesOperations.FileData(Attachment, UUID, True);
				Except
					ErrorInformation = ErrorInfo();
					
					WriteErrorToEventLog(EventNameMessagesTemplates(), ErrorInformation, NStr("ru = 'Не удалось извлечь и записать присоединенный файл для копирования'; en = 'Failed to extract and save the file'; pl = 'Nie udało się wyciągnąć tekstu i zapisać go do pliku';es_ES = 'No se ha podido extraer y guardar el archivo';es_CO = 'No se ha podido extraer y guardar el archivo';tr = 'Dosya çıkarılamadı ve kaydedilemedi';it = 'Estrazione e salvataggio del file non riusciti';de = 'Extrahieren und Speichern der Datei fehlgeschlagen'"));
					ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorDescription, BriefErrorDescription(ErrorInformation));
					CommonClientServer.AddUserError(ErrorsList, "Attachments", ErrorText, "Attachments",, ErrorText);
					Continue;
				EndTry;
				NewRow                = Attachments.Add();
				NewRow.Name            = FileData.BinaryFileDataRef;
				NewRow.Presentation  = Attachment.Description + "." + Attachment.Extension;
				NewRow.PictureIndex = GetFileIconIndex(Attachment.Extension);
				NewRow.Status         = "ExternalNew";
				NewRow.ID  = Attachment.Details;
			EndIf;
		EndDo;
	EndIf;
	
	CommonClientServer.ReportErrorsToUser(ErrorsList);
	
	Return FileList;
	
EndFunction

&AtClient
Procedure DeleteAttachmentExecute()

	Attachment = Items.Attachments.CurrentData;
	If Attachment <> Undefined Then
		If Attachment.Status = "ExternalAttached" OR Attachment.Status = "ExternalNew" Then
			Attachment.Status = "ExternalToDelete";
			Attachment.PictureIndex = Attachment.PictureIndex + 1;
			Modified = True;
		ElsIf Attachment.Status = "ExternalToDelete" Then
			Attachment.PictureIndex = Attachment.PictureIndex - 1;
			Attachment.Status = ?(ValueIsFilled(Attachment.Ref), "ExternalAttached", "ExternalNew");
		EndIf;
		Modified = True;
	EndIf;
	
EndProcedure

&AtServer
Procedure DeleteAttachedFile(AttachedFile)
	
	SetPrivilegedMode(True);
	
	Lock = New DataLock;
	LockItem = Lock.Add("Catalog.MessageTemplatesAttachedFiles");
	LockItem.SetValue("Ref", AttachedFile);
	Lock.Lock();
	
	ObjectAttachment = AttachedFile.GetObject();
	ObjectAttachment.Lock();
	
	ObjectAttachment.Delete();
	
EndProcedure

&AtServer
Procedure ChangePicturesNamesToMailAttachmentsIDsInHTML(DocumentHTML, MapsTable)
	
	For each Picture In DocumentHTML.Images Do
		
		AttributePictureSource = Picture.Attributes.GetNamedItem("src");
		FoundRow = MapsTable.FindByValue(AttributePictureSource.TextContent);
		If FoundRow <> Undefined Then
			
			NewAttributePicture = AttributePictureSource.CloneNode(False);
			NewAttributePicture.TextContent = String("cid:" + FoundRow.Presentation);
			Picture.Attributes.SetNamedItem(NewAttributePicture);
			
		EndIf;
	EndDo;
	
EndProcedure

// Saves formatted document pictures as attached object files.
//
// Parameters:
//  Ref  - DocumentRef - a reference to the attached file owner.
//  EmailTextType  - Enum.EmailEditingMethods - to define whether transformations are necessary.
//  AttachmentsNamesToIDsMapsTable  - ValueTable - it allows to determine, which picture matches 
//                                                                      which attachment.
//  UUID  - UUID - a form UUID used for saving.
//
&AtServer
Procedure SaveFormattedDocumentPicturesAsAttachedFiles(Ref, EmailTextType,
	                                                                        AttachmentsNamesToIDsMapsTable,
	                                                                        UUID)
	
	If EmailTextType = Enums.EmailEditingMethods.HTML Then
		
		For each Attachment In AttachmentsNamesToIDsMapsTable Do
			
			BinaryPictureData = Attachment.Picture.GetBinaryData();
			PictureAddressInTempStorage = PutToTempStorage(BinaryPictureData, UUID);
			AttachedFile = WriteEmailAttachmentFromTempStorage(Ref, PictureAddressInTempStorage,
				"_" + StrReplace(Attachment.Presentation, "-", "_"), BinaryPictureData.Size());
			
			If AttachedFile <> Undefined Then
				
				Lock = New DataLock;
				LockItem = Lock.Add("Catalog.MessageTemplatesAttachedFiles");
				LockItem.SetValue("Ref", AttachedFile);
				Lock.Lock();
				
				AttachedFileObject = AttachedFile.GetObject();
				AttachedFileObject.Lock();
				
				AttachedFileObject.EmailFileID = Attachment.Presentation;
				AttachedFileObject.Write();
				
			EndIf;
		EndDo;
	EndIf;
	
EndProcedure

&AtServer
Function WriteEmailAttachmentFromTempStorage(Email, AddressInTempStorage, FileName,
		Size, CountOfBlankNamesInAttachments = 0)
		
	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleFilesOperations = Common.CommonModule("FilesOperations");
		
		FileNameToParse = FileName;
		ExtensionWithoutPoint = GetFileExtension(FileNameToParse);
		NameWithoutExtension = CommonClientServer.ReplaceProhibitedCharsInFileName(FileNameToParse);
		If IsBlankString(NameWithoutExtension) Then
			
			CountOfBlankNamesInAttachments = CountOfBlankNamesInAttachments + 1;
			
		Else
			NameWithoutExtension = ?(ExtensionWithoutPoint = "", NameWithoutExtension,
				Left(NameWithoutExtension, StrLen(NameWithoutExtension) - StrLen(ExtensionWithoutPoint) - 1));
		EndIf;
			
		FileParameters = ModuleFilesOperations.FileAddingOptions();
		FileParameters.FilesOwner = Email;
		FileParameters.BaseName = NameWithoutExtension;
		FileParameters.ExtensionWithoutPoint = ExtensionWithoutPoint;
		Return ModuleFilesOperations.AppendFile(FileParameters, AddressInTempStorage, "");
	EndIf;
	
	Return Undefined;
	
EndFunction

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	
	//
	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.AttachmentsSelected.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Attachments.Status");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Contains;
	ItemFilter.RightValue = "External";
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Attachments.Attribute");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotFilled;

	Item.Appearance.SetParameterValue("Enabled", False);
	Item.Appearance.SetParameterValue("Show", False);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.AttachmentsPresentation.Name);
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.AttachmentsSelected.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Attachments.Status");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Contains;
	ItemFilter.RightValue = "ExternalToDelete";

	Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleCellTextColor);
	
EndProcedure

&AtClient
Procedure AfterAdditionalReportsAndDataProcessorsChoice(Result, AddtnlParameters) Export
	If Result <> Undefined Then
		Items.ExternalDataProcessorGroup.Visible = True;
		Items.Pages.CurrentPage = Items.MessageExternalDataProcessor;
		Items.ParametersGroup.Visible = False;
		Items.FormFromTemplate.Check = False;
		Items.FormByExternalDataProcessor.Check = True;
		Object.TemplateByExternalDataProcessor = True;
		Object.ExternalDataProcessor = Result;
		ShowFormItems();
	EndIf;
EndProcedure

&AtServer
Procedure WriteErrorToEventLog(EventName, ErrorInformation, EventText)
	
	Comment = EventText + Chars.LF + DetailErrorDescription(ErrorInformation);
	WriteLogEvent(EventName, EventLogLevel.Error, Metadata.Catalogs.MessageTemplates,, Comment);
	
EndProcedure

&AtServer
Function EventNameMessagesTemplates()
	
	Return NStr("ru = 'Шаблоны сообщений'; en = 'Message templates'; pl = 'Szablony wiadomości';es_ES = 'Modelos de los mensajes';es_CO = 'Modelos de los mensajes';tr = 'İleti şablonları';it = 'Modelli di messaggio';de = 'Nachrichtenvorlagen'", CommonClientServer.DefaultLanguageCode());
	
EndFunction

&AtServer
Procedure FillArbitraryParametersFromObject(Val CurrentObject)
	
	Var FoundRows, Filter, TemplateParameterCurrentObject;
	
	For each TemplateParameterCurrentObject In CurrentObject.Parameters Do
		Filter = New Structure("ParameterName", TemplateParameterCurrentObject.ParameterName);
		FoundRows = Object.Parameters.FindRows(Filter);
		If FoundRows.Count() > 0 Then
			FoundRows[0].TypeDetails = TemplateParameterCurrentObject.ParameterType.Get();
		EndIf;
	EndDo;

EndProcedure

// External data processor

&AtServer
Procedure FillTemplateByExternalDataProcessor()
	
		If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		ModuleAdditionalReportsAndDataProcessors = Common.CommonModule("AdditionalReportsAndDataProcessors");
		
		ClearTemplate(ThisObject);
		ExternalObject = ModuleAdditionalReportsAndDataProcessors.ExternalDataProcessorObject(Object.ExternalDataProcessor);
		If Object.ExternalDataProcessor.Kind <> Enums["AdditionalReportsAndDataProcessorsKinds"].MessageTemplate Then
			Return;
		EndIf;
		
		MessagesTemplatesSettings = MessagesTemplatesInternalCachedModules.OnDefineSettings();
		ExternalDataProcessorDataStructure = ExternalObject.DataStructureToDisplayInTemplate();
		
		TemplateSubject = DefineMessagesTemplateSubject(ExternalDataProcessorDataStructure.InputOnBasisParameterTypeFullName, MessagesTemplatesSettings);
		
		If TemplateSubject <> Undefined Then
			
			Object.InputOnBasisParameterTypeFullName = TemplateSubject.Name;
			Object.Purpose                             = TemplateSubject.Presentation;
			
		Else
			
			ErrorDescription = NStr("ru = 'Предмет %1 определенный в внешней обработке не найдено. Внешняя обработка не может быть подключена.'; en = 'Topic ""%1"" specified in the external data processor is not found. Cannot attach the external data processor.'; pl = 'Nie znaleziono tematu ""%1"" określonego w przetwarzaniu zewnętrznym. Nie można załączyć przetwarzania zewnętrznego.';es_ES = 'No se ha encontrado el tema ""%1"" especificado en el procesador de datos externo. No se puede adjuntar al procesamiento de datos externo.';es_CO = 'No se ha encontrado el tema ""%1"" especificado en el procesador de datos externo. No se puede adjuntar al procesamiento de datos externo.';tr = 'Harici veri işlemcisinde belirtilen ""%1"" konusu bulunamadı. Harici veri işlemcisi eklenemiyor.';it = 'L''argomento ""%1"" specificato nell'' elaboratore dati esterno non è stato trovato. Impossibile allegare l''elaboratore dati esterno.';de = 'Das im externen Datenprozessor angegebene Thema ""%1"" ist nicht gefunden worden. Der externe Datenprozessor kann nicht angeschlossen werden.'");
			Raise StringFunctionsClientServer.SubstituteParametersToString(ErrorDescription, ExternalDataProcessorDataStructure.InputOnBasisParameterTypeFullName);
			
		EndIf;
		
		Object.TemplateByExternalDataProcessor = True;
		Object.ForInputOnBasis = True;
		
		If ExternalDataProcessorDataStructure.ForSMSMessages Then
			
			MessageBodyPlainText.SetText(ExternalDataProcessorDataStructure.SMSTemplateText);
			Object.ForSMSMessages              = True;
			Object.ForEmails = False;
			
		Else
			
			Object.EmailSubject = ExternalDataProcessorDataStructure.EmailSubject;
			If ExternalDataProcessorDataStructure.MailTextType = Enums.EmailEditingMethods.HTML Then
				SetHTMLEmail(True);
				AttachmentStructure = New Structure;
				EmailBodyInHTML.SetHTML(ExternalDataProcessorDataStructure.HTMLMessageTemplateText, AttachmentStructure);
			Else
				SetEmailPlainText(True);
				MessageBodyPlainText.SetText(ExternalDataProcessorDataStructure.HTMLMessageTemplateText);
			EndIf;
			
			Object.ForEmails = True;
			Object.ForSMSMessages              = False;
			
		EndIf
		
	EndIf
	
EndProcedure

&AtClientAtServerNoContext
Function DefineMessagesTemplateSubject(NameToAssignment, Val MessagesTemplatesSettings)
	
	Var TemplateAssignment;
	
	TemplateAssignment = MessagesTemplatesSettings.TemplateSubjects.Find(NameToAssignment, "Presentation");
	If TemplateAssignment = Undefined Then
		TemplateAssignment = MessagesTemplatesSettings.TemplateSubjects.Find(NameToAssignment, "Name");
	EndIf;
	
	Return TemplateAssignment;

EndFunction

&AtClientAtServerNoContext
Procedure ClearTemplate(Form)
	
	Form.Object.Parameters.Clear();
	Form.Object.ForEmails        = True;
	Form.Object.ForSMSMessages                     = False;
	Form.Object.ForInputOnBasis        = False;
	Form.Object.InputOnBasisParameterTypeFullName = "";
	Form.Object.EmailSubject                             = "";
	Form.Object.SMSTemplateText                        = "";
	Form.Object.MessageTemplateText                     = "";
	Form.Object.HTMLMessageTemplateText                 = "<html></html>";
	Form.Object.MailTextType                        = PredefinedValue("Enum.EmailEditingMethods.NormalText");
	
EndProcedure

&AtClient
Procedure AddParameterToMessageText()
	
	If Items.Attributes.SelectedRows <> Undefined Then
		Text = "";
		For each RowNumber In Items.Attributes.SelectedRows Do
			FoundRow = Attributes.FindByID(RowNumber);
			If FoundRow <> Undefined Then
				OutputFormat = ?(IsBlankString(FoundRow.Format), "", "{" + FoundRow.Format +"}");
				Text = Text + "[" + FoundRow.Name + OutputFormat + "] ";
			EndIf;
		EndDo;
		If Object.MailTextType = PredefinedValue("Enum.EmailEditingMethods.HTML") Then
			If IsBlankString(Items.EmailBodyInHTML.SelectedText) Then
				BookmarkToInsertStart = Undefined;
				BookmarkToInsertEnd = Undefined;
				Items.EmailBodyInHTML.GetTextSelectionBounds(BookmarkToInsertStart, BookmarkToInsertEnd);
				EmailBodyInHTML.Insert(BookmarkToInsertEnd, Text);
			Else
				Items.EmailBodyInHTML.SelectedText = Text;
			EndIf;
		Else
			If Object.ForSMSMessages Then
				Items.MessageBodySMSMessagePlainText.SelectedText = Text;
			Else
				Items.MessageBodyPlainText.SelectedText = Text;
			EndIf;
		EndIf;
	EndIf;

EndProcedure


#EndRegion