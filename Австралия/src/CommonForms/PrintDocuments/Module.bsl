#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Var PrintFormsCollection;
	
	SetConditionalAppearance();
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	If Not AccessRight("Update", Metadata.InformationRegisters.UserPrintTemplates) Then
		Items.GoToTemplateManagementButton.Visible = False;
	EndIf;
	
	// Checking input parameters.
	If Not ValueIsFilled(Parameters.DataSource) Then 
		CommonClientServer.Validate(TypeOf(Parameters.CommandParameter) = Type("Array") Or Common.RefTypeValue(Parameters.CommandParameter),
			StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Недопустимое значение параметра CommandParameter при вызове метода PrintManagerClient.ExecutePrintCommand.
				|Ожидалось: Array, AnyRef.
				|Передано: %1'; 
				|en = 'Invalid value of the CommandParameter parameter when calling the PrintManagerClient.ExecutePrintCommand method.
				|Expected value: Array or AnyRef.
				|Passed value: %1.'; 
				|pl = 'Niedozwolona wartość parametru CommandParameter przy wywoływaniu metody PrintManagerClient.ExecutePrintCommand.
				|Oczekiwano: Tablica, AnyRef.
				|Przekazano:%1';
				|es_ES = 'Valor inválido del parámetro CommandParameter al llamar el método PrintManagementClient.ExecutePrintCommand.
				|Esperado: Matriz, AnyRef.
				|Actual: %1';
				|es_CO = 'Valor inválido del parámetro CommandParameter al llamar el método PrintManagementClient.ExecutePrintCommand.
				|Esperado: Matriz, AnyRef.
				|Actual: %1';
				|tr = 'PrintManagerClient.ExecutePrintCommand yöntemi çağrıldığında CommandParameter geçersiz değeri. 
				|Beklenen: Dizilim, AnyRef. 
				|Verildi: %1';
				|it = 'Valori non corretti del parametro CommandParameter durante la chiamata della procedura PrintManagerClient.ExecutePrintCommand method.
				|Valore atteso: Array o AnyRef.
				|Valore trasferito: %1.';
				|de = 'Ungültiger Wert für den Parameter CommandParameter beim Aufruf der Methode PrintManagerClient.ExecutePrintCommand.
				|Erwartet: Array, AnyRef.
				|Gesendet: %1.'"), TypeOf(Parameters.CommandParameter)));
	EndIf;

	// Support of backward compatibility with version 2.1.3.
	PrintParameters = Parameters.PrintParameters;
	If Parameters.PrintParameters = Undefined Then
		PrintParameters = New Structure;
	EndIf;
	If Not PrintParameters.Property("AdditionalParameters") Then
		Parameters.PrintParameters = New Structure("AdditionalParameters", PrintParameters);
		For Each PrintParameter In PrintParameters Do
			Parameters.PrintParameters.Insert(PrintParameter.Key, PrintParameter.Value);
		EndDo;
	EndIf;
	
	If Parameters.PrintFormsCollection = Undefined Then
		PrintFormsCollection = GeneratePrintForms(Parameters.TemplatesNames, Cancel);
		If Cancel Then
			Return;
		EndIf;
	Else
		PrintFormsCollection = Parameters.PrintFormsCollection;
		PrintObjects = Parameters.PrintObjects;
		OutputParameters = PrintManagement.PrepareOutputParametersStructure();
	EndIf;
	
	CreateAttributesAndFormItemsForPrintForms(PrintFormsCollection);
	SaveDefaultSetSettings();
	ImportCopiesCountSettings();
	HasOutputAllowed = HasOutputAllowed();
	SetUpFormItemsVisibility(HasOutputAllowed);
	SetOutputAvailabilityFlagInPrintFormsPresentations(HasOutputAllowed);
	SetPrinterNameInPrintButtonTooltip();
	SetFormHeader();
	If IsSetPrinting() Then
		Items.Copies.Title = NStr("ru = 'Копий комплекта'; en = 'Copies of set'; pl = 'Kopie zestawu';es_ES = 'Establecer copias';es_CO = 'Establecer copias';tr = 'Kopyaları ayarlayın';it = 'Copie sono impostate';de = 'Legen Sie Kopien an'");
	EndIf;
	
	AdditionalInformation = New Structure("Picture, Text", New Picture, "");
	RefsArray = Parameters.CommandParameter;
	If Common.RefTypeValue(RefsArray) Then
		RefsArray = CommonClientServer.ValueInArray(RefsArray);
	EndIf;
	If TypeOf(RefsArray) = Type("Array")
		AND RefsArray.Count() > 0
		AND Common.RefTypeValue(RefsArray[0]) Then
			If Common.SubsystemExists("OnlineInteraction") Then 
				ModuleOnlineInteraction = Common.CommonModule("OnlineInteraction");
				ModuleOnlineInteraction.OnDisplayURLInIBObjectForm(AdditionalInformation, RefsArray);
			EndIf;
	EndIf;
	Items.AdditionalInformation.Title = StringFunctionsClientServer.FormattedString(AdditionalInformation.Text);
	Items.InformationPicture.Picture = AdditionalInformation.Picture;
	Items.AdditionalInformationGroup.Visible = Not IsBlankString(Items.AdditionalInformation.Title);
	Items.InformationPicture.Visible = Items.InformationPicture.Picture.Type <> PictureType.Empty;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	If ValueIsFilled(SaveFormatSettings) Then
		Cancel = True; // cancel the form opening
		SavePrintFormToFile();
		Return;
	EndIf;
	AttachIdleHandler("SetCurrentPage", 0.1, True);
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If Upper(ChoiceSource.FormName) = Upper("CommonForm.SavePrintForm") Then
		
		If SelectedValue <> Undefined AND SelectedValue <> DialogReturnCode.Cancel Then
			FilesInTempStorage = PutSpreadsheetDocumentsInTempStorage(SelectedValue);
			If SelectedValue.SavingOption = "SaveToFolder" Then
				SavePrintFormsToFolder(FilesInTempStorage, SelectedValue.FolderForSaving);
			Else
				WrittenObjects = AttachPrintFormsToObject(FilesInTempStorage, SelectedValue.ObjectForAttaching);
				If WrittenObjects.Count() > 0 Then
					NotifyChanged(TypeOf(WrittenObjects[0]));
				EndIf;
				For Each WrittenObject In WrittenObjects Do
					Notify("Write_AttachedFile", New Structure, WrittenObject);
				EndDo;
				ShowUserNotification(, , NStr("ru = 'Записана'; en = 'Saved'; pl = 'Zapisz ukończone';es_ES = 'Se ha guardado';es_CO = 'Se ha guardado';tr = 'Kaydedildi';it = 'Salvato';de = 'Speichern abgeschlossen'"), PictureLib.Information32);
			EndIf;
		EndIf;
		
	ElsIf Upper(ChoiceSource.FormName) = Upper("CommonForm.SelectAttachmentFormat")
		Or Upper(ChoiceSource.FormName) = Upper("CommonForm.ComposeNewMessage") Then
		
		If SelectedValue <> Undefined AND SelectedValue <> DialogReturnCode.Cancel Then
			SendOptions = EmailSendOptions(SelectedValue);
			
			ModuleEmailClient = CommonClient.CommonModule("EmailOperationsClient");
			ModuleEmailClient.CreateNewEmailMessage(SendOptions);
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Function EmailSendOptions(SelectedOptions)
	
	AttachmentsList = PutSpreadsheetDocumentsInTempStorage(SelectedOptions);
	
	// Control of name uniqueness.
	FileNameTemplate = "%1%2.%3";
	UsedFilesNames = New Map;
	For Each Attachment In AttachmentsList Do
		FileName = Attachment.Presentation;
		UsageNumber = ?(UsedFilesNames[FileName] <> Undefined,
			UsedFilesNames[FileName] + 1, 1);
		UsedFilesNames.Insert(FileName, UsageNumber);
		If UsageNumber > 1 Then
			File = New File(FileName);
			FileName = StringFunctionsClientServer.SubstituteParametersToString(FileNameTemplate,
				File.BaseName, " (" + UsageNumber + ")", File.Extension);
		EndIf;
		Attachment.Presentation = FileName;
	EndDo;
	
	Recipients = OutputParameters.SendOptions.Recipient;
	If SelectedOptions.Property("Recipients") Then
		Recipients = SelectedOptions.Recipients;
	EndIf;
	
	Result = New Structure;
	Result.Insert("Recipient", Recipients);
	Result.Insert("Subject", OutputParameters.SendOptions.Subject);
	Result.Insert("Text", OutputParameters.SendOptions.Text);
	Result.Insert("Attachments", AttachmentsList);
	Result.Insert("DeleteFilesAfterSending", True);
	If PrintObjects.Count() > 0 Then
		Result.Insert("Topic", PrintObjects[0].Value);
	Else
		Result.Insert("Topic", Undefined);
	EndIf;
	
	PrintForms = New ValueTable;
	PrintForms.Columns.Add("Name");
	PrintForms.Columns.Add("SpreadsheetDocument");
	
	For Each PrintFormSetting In PrintFormsSettings Do
		If Not PrintFormSetting.Print Then
			Continue;
		EndIf;
		
		SpreadsheetDocument = ThisObject[PrintFormSetting.AttributeName];
		If PrintForms.FindRows(New Structure("SpreadsheetDocument", SpreadsheetDocument)).Count() > 0 Then
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
		
		PrintFormDetails = PrintForms.Add();
		PrintFormDetails.Name = PrintFormSetting.Name;
		PrintFormDetails.SpreadsheetDocument = SpreadsheetDocument;
	EndDo;
	
	PrintManagementOverridable.BeforeSendingByEmail(Result, OutputParameters, Parameters.CommandParameter, PrintForms);
	
	Return Result;
	
EndFunction

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	PrintFormSetting = CurrentPrintFormSetting();
	
	If EventName = "Write_UserPrintTemplates" 
		AND Source.FormOwner = ThisObject
		AND Parameter.TemplateMetadataObjectName = PrintFormSetting.PathToTemplate Then
			AttachIdleHandler("RefreshCurrentPrintForm",0.1,True);
	ElsIf (EventName = "CancelTemplateChange"
		Or EventName = "CancelEditSpreadsheetDocument"
		AND Parameter.TemplateMetadataObjectName = PrintFormSetting.PathToTemplate)
		AND Source.FormOwner = ThisObject Then
			DisplayCurrentPrintFormState();
	ElsIf EventName = "Write_SpreadsheetDocument" 
		AND Parameter.TemplateMetadataObjectName = PrintFormSetting.PathToTemplate 
		AND Source.FormOwner = ThisObject Then
			Template = Parameter.SpreadsheetDocument;
			TemplateAddressInTempStorage = PutToTempStorage(Template);
			WriteTemplate(Parameter.TemplateMetadataObjectName, TemplateAddressInTempStorage);
			AttachIdleHandler("RefreshCurrentPrintForm",0.1,True);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure CopiesOnChange(Item)
	If PrintFormsSettings.Count() = 1 Then
		PrintFormsSettings[0].Count = Copies;
		StartSaveSettings();
	EndIf;
EndProcedure

&AtClient
Procedure AdditionalInformationURLProcessing(Item, FormattedStringURL, StandardProcessing)
	StandardProcessing = False;
	RefsArray = Parameters.CommandParameter;
	If TypeOf(RefsArray) <> Type("Array") Then
		RefsArray = CommonClientServer.ValueInArray(RefsArray);
	EndIf;
	If CommonClient.SubsystemExists("OnlineInteraction") Then 
		ModuleOnlineInteractionClient = CommonClient.CommonModule("OnlineInteractionClient");
		ModuleOnlineInteractionClient.URLProcessingInPrintFormSSL(FormattedStringURL, RefsArray);
	EndIf;
EndProcedure

#EndRegion

#Region PrintFormsSettingsFormTableItemsEventHandlers

&AtClient
Procedure PrintFormsSettingsOnChange(Item)
	CanPrint = False;
	CanSave = False;
	
	For Each PrintFormSetting In PrintFormsSettings Do
		PrintForm = ThisObject[PrintFormSetting.AttributeName];
		SpreadsheetDocumentField = Items[PrintFormSetting.AttributeName];
		
		CanPrint = CanPrint Or PrintFormSetting.Print AND PrintForm.TableHeight > 0
			AND SpreadsheetDocumentField.Output = UseOutput.Enable;
		
		CanSave = CanSave Or PrintFormSetting.Print AND PrintForm.TableHeight > 0
			AND SpreadsheetDocumentField.Output = UseOutput.Enable AND Not SpreadsheetDocumentField.Protection;
	EndDo;
	
	Items.PrintButtonCommandBar.Enabled = CanPrint;
	Items.PrintButtonAllActions.Enabled = CanPrint;
	
	Items.SaveButton.Enabled = CanSave;
	Items.SaveButtonAllActions.Enabled = CanSave;
	
	Items.SendButton.Enabled = CanSave;
	Items.SendButtonAllActions.Enabled = CanSave;
	
	StartSaveSettings();
EndProcedure

&AtClient
Procedure PrintFormSettingsOnActivateRow(Item)
	DetachIdleHandler("SetCurrentPage");
	AttachIdleHandler("SetCurrentPage", 0.1, True);
EndProcedure

&AtClient
Procedure PrintFormSettingsCountTracking(Item, Direction, StandardProcessing)
	PrintFormSetting = CurrentPrintFormSetting();
	PrintFormSetting.Print = PrintFormSetting.Count + Direction > 0;
EndProcedure

&AtClient
Procedure PrintFormSettingsPrintOnChange(Item)
	PrintFormSetting = CurrentPrintFormSetting();
	If PrintFormSetting.Print AND PrintFormSetting.Count = 0 Then
		PrintFormSetting.Count = 1;
	EndIf;
EndProcedure

&AtClient
Procedure PrintFormSettingsBeforeAddRow(Item, Cancel, Clone, Parent, IsFolder)
	Cancel = True;
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Save(Command)
	FormParameters = New Structure;
	FormParameters.Insert("PrintObjects", PrintObjects);
	OpenForm("CommonForm.SavePrintForm", FormParameters, ThisObject);
EndProcedure

&AtClient
Procedure Send(Command)
	SendPrintFormsByEmail();
EndProcedure

&AtClient
Procedure GoToDocument(Command)
	
	ChoiceList = New ValueList;
	For Each PrintObject In PrintObjects Do
		ChoiceList.Add(PrintObject.Presentation, String(PrintObject.Value));
	EndDo;
	
	NotifyDescription = New NotifyDescription("GoToDocumentCompletion", ThisObject);
	ChoiceList.ShowChooseItem(NotifyDescription, NStr("ru = 'Перейти к печатной форме'; en = 'Go to print form'; pl = 'Przejść do formularza wydruku';es_ES = 'Ir a la versión impresa';es_CO = 'Ir a la versión impresa';tr = 'Yazdırma formuna git';it = 'Vai al modulo di stampa';de = 'Gehe zum Druckformular'"));
	
EndProcedure

&AtClient
Procedure GoToTemplatesManagement(Command)
	OpenForm("InformationRegister.UserPrintTemplates.Form.PrintFormTemplates");
EndProcedure

&AtClient
Procedure PrintSpreadsheetDocuments(Command)
	
	SpreadsheetDocuments = SpreadsheetDocumentsToPrint();
	PrintManagementClient.PrintSpreadsheetDocuments(SpreadsheetDocuments, PrintObjects,
		SpreadsheetDocuments.Count() > 1, ?(PrintFormsSettings.Count() > 1, Copies, 1));
	
	For Each PrintObject In PrintObjects Do
		FilesOperationsClientDrive.AttachPrintFormsToObject(SpreadsheetDocuments, PrintObject.Value, UUID);
	EndDo;

EndProcedure

&AtClient
Procedure ShowHideCopiesCountSettings(Command)
	SetCopiesCountSettingsVisibility();
EndProcedure

&AtClient
Procedure SelectAll(Command)
	SelectOrClearAll(True);
EndProcedure

&AtClient
Procedure ClearAll(Command)
	SelectOrClearAll(False);
EndProcedure

&AtClient
Procedure ClearSettings(Command)
	RestorePrintFormsSettings();
	StartSaveSettings();
EndProcedure

&AtClient
Procedure ChangeTemplate(Command)
	OpenTemplateForEditing();
EndProcedure

&AtClient
Procedure ToggleEditing(Command)
	SwitchCurrentPrintFormEditing();
EndProcedure

&AtClient
Procedure CalculateSum(Command)
	StandardSubsystemsClient.ShowCellCalculation(ThisObject, CurrentPrintForm);
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.PrintFormsSettings.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("PrintFormsSettings.Print");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;

	Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleCellTextColor);

EndProcedure

&AtServer
Function GeneratePrintForms(TemplatesNames, Cancel)
	
	Result = Undefined;
	// Generating spreadsheet documents.
	If ValueIsFilled(Parameters.DataSource) Then
		PrintManagement.PrintByExternalSource(
			Parameters.DataSource,
			Parameters.SourceParameters,
			Result,
			PrintObjects,
			OutputParameters);
	Else
		PrintObjectsTypes = New Array;
		Parameters.PrintParameters.Property("PrintObjectsTypes", PrintObjectsTypes);
		PrintForms = PrintManagement.GeneratePrintForms(Parameters.PrintManagerName, TemplatesNames,
			Parameters.CommandParameter, Parameters.PrintParameters.AdditionalParameters, PrintObjectsTypes);
		PrintObjects = PrintForms.PrintObjects;
		OutputParameters = PrintForms.OutputParameters;
		Result = PrintForms.PrintFormsCollection;
	EndIf;
	
	// Setting the flag of saving print forms to a file (do not open the form, save it directly to a file).
	If TypeOf(Parameters.PrintParameters) = Type("Structure") AND Parameters.PrintParameters.Property("SaveFormat") Then
		FoundFormat = PrintManagement.SpreadsheetDocumentSaveFormatsSettings().Find(Parameters.PrintParameters.SaveFormat, "SpreadsheetDocumentFileType");
		If FoundFormat <> Undefined Then
			SaveFormatSettings = New Structure("SpreadsheetDocumentFileType,Presentation,Extension,Filter");
			FillPropertyValues(SaveFormatSettings, FoundFormat);
			SaveFormatSettings.Filter = SaveFormatSettings.Presentation + "|*." + SaveFormatSettings.Extension;
		EndIf;
	EndIf;
	
	Return Result;
	
EndFunction

&AtServer
Procedure ImportCopiesCountSettings()
    
    DisplayPrintOption = DriveServer.GetFunctionalOptionValue("DisplayPrintOptionsBeforePrinting");
	Result = Undefined;
	Parameters.PrintParameters.AdditionalParameters.Property("Result", Result);
	
    If DisplayPrintOption And Result <> Undefined Then
        
        PrintFormSettingsStructure = New Structure;
        
        PrintFormSettingsStructure.Insert("Count", Parameters.PrintParameters.AdditionalParameters.Result.Copies);
        PrintFormSettingsStructure.Insert("DefaultPosition", 0);
        PrintFormSettingsStructure.Insert("TemplateName", Parameters.TemplatesNames);
        
        SavedPrintFormsSettings = New Array;                
        SavedPrintFormsSettings.Add(PrintFormSettingsStructure);
        
        RestorePrintFormsSettings(SavedPrintFormsSettings);
        
        Copies = Parameters.PrintParameters.AdditionalParameters.Result.Copies;
	Else
    	SavedPrintFormsSettings = New Array;
    	
    	UseSavedSettings = True;
    	If TypeOf(Parameters.PrintParameters) = Type("Structure") AND Parameters.PrintParameters.Property("OverrideCopiesUserSetting") Then
    		UseSavedSettings = Not Parameters.PrintParameters.OverrideCopiesUserSetting;
    	EndIf;
    	
    	If UseSavedSettings Then
    		If ValueIsFilled(Parameters.DataSource) Then
    			SettingsKey = String(Parameters.DataSource.UUID()) + "-" + Parameters.SourceParameters.CommandID;
    		Else
    			TemplatesNames = Parameters.TemplatesNames;
    			If TypeOf(TemplatesNames) = Type("Array") Then
    				TemplatesNames = StrConcat(TemplatesNames, ",");
    			EndIf;
    			
    			SettingsKey = Parameters.PrintManagerName + "-" + TemplatesNames;
    		EndIf;
    		SavedPrintFormsSettings = Common.CommonSettingsStorageLoad("PrintFormsSettings", SettingsKey, New Array);
    	EndIf;

    	
    	RestorePrintFormsSettings(SavedPrintFormsSettings);
    	
    	If IsSetPrinting() Then
    		Copies = 1;
    	Else
    		If PrintFormsSettings.Count() > 0 Then
    			Copies = PrintFormsSettings[0].Count;
    		EndIf;
    	EndIf;
	EndIf
EndProcedure

&AtServer
Procedure CreateAttributesAndFormItemsForPrintForms(PrintFormsCollection)
	
	// Creating attributes for spreadsheet documents.
	NewFormAttributes = New Array;
	For PrintFormNumber = 1 To PrintFormsCollection.Count() Do
		AttributeName = "PrintForm" + Format(PrintFormNumber,"NG=0");
		FormAttribute = New FormAttribute(AttributeName, New TypeDescription("SpreadsheetDocument"),,PrintFormsCollection[PrintFormNumber - 1].TemplateSynonym);
		NewFormAttributes.Add(FormAttribute);
	EndDo;
	ChangeAttributes(NewFormAttributes);
	
	// Creating pages with spreadsheet documents on a form.
	PrintFormNumber = 0;
	PrintOfficeDocuments = False;
	AddedPrintFormsSettings = New Map;
	For Each FormAttribute In NewFormAttributes Do
		PrintFormDetails = PrintFormsCollection[PrintFormNumber];
		
		// Print form settings table (beginning).
		NewPrintFormSetting = PrintFormsSettings.Add();
		NewPrintFormSetting.Presentation = PrintFormDetails.TemplateSynonym;
		NewPrintFormSetting.Print = PrintFormDetails.Copies > 0;
		NewPrintFormSetting.Count = PrintFormDetails.Copies;
		NewPrintFormSetting.TemplateName = PrintFormDetails.TemplateName;
		NewPrintFormSetting.DefaultPosition = PrintFormNumber;
		NewPrintFormSetting.Name = PrintFormDetails.TemplateSynonym;
		NewPrintFormSetting.PathToTemplate = PrintFormDetails.FullPathToTemplate;
		NewPrintFormSetting.PrintFormFileName = Common.ValueToXMLString(PrintFormDetails.PrintFormFileName);
		NewPrintFormSetting.OfficeDocuments = ?(IsBlankString(PrintFormDetails.OfficeDocuments), "", Common.ValueToXMLString(PrintFormDetails.OfficeDocuments));
		
		PrintOfficeDocuments = PrintOfficeDocuments Or Not IsBlankString(NewPrintFormSetting.OfficeDocuments);
		
		PreviouslyAddedPrintFormSetting = AddedPrintFormsSettings[PrintFormDetails.TemplateName];
		If PreviouslyAddedPrintFormSetting = Undefined Then
			// Copying a spreadsheet document to a form attribute.
			AttributeName = FormAttribute.Name;
			ThisObject[AttributeName] = PrintFormDetails.SpreadsheetDocument;
			
			// Creating pages for spreadsheet documents.
			PageName = "Page" + AttributeName;
			Page = Items.Add(PageName, Type("FormGroup"), Items.Pages);
			Page.Type = FormGroupType.Page;
			Page.Picture = PictureLib.SpreadsheetInsertPageBreak;
			Page.Title = PrintFormDetails.TemplateSynonym;
			Page.ToolTip = PrintFormDetails.TemplateSynonym;
			Page.Visible = ThisObject[AttributeName].TableHeight > 0;
			
			// Creating items for displaying spreadsheet documents.
			NewItem = Items.Add(AttributeName, Type("FormField"), Page);
			NewItem.Type = FormFieldType.SpreadsheetDocumentField;
			NewItem.TitleLocation = FormItemTitleLocation.None;
			NewItem.DataPath = AttributeName;
			NewItem.Output = EvalOutputUsage(PrintFormDetails.SpreadsheetDocument);
			NewItem.Edit = NewItem.Output = UseOutput.Enable And Not PrintFormDetails.SpreadsheetDocument.ReadOnly;
			NewItem.Protection = PrintFormDetails.SpreadsheetDocument.Protection 
				Or (Not Users.RolesAvailable("PrintFormsEdit") And Not Users.RolesAvailable("PrintFormsEditForExternalUsers"));
			
			// Print form settings table (continued).
			NewPrintFormSetting.PageName = PageName;
			NewPrintFormSetting.AttributeName = AttributeName;
			
			AddedPrintFormsSettings.Insert(NewPrintFormSetting.TemplateName, NewPrintFormSetting);
		Else
			NewPrintFormSetting.PageName = PreviouslyAddedPrintFormSetting.PageName;
			NewPrintFormSetting.AttributeName = PreviouslyAddedPrintFormSetting.AttributeName;
		EndIf;
		
		PrintFormNumber = PrintFormNumber + 1;
	EndDo;
	
	If PrintOfficeDocuments AND NOT ValueIsFilled(SaveFormatSettings) Then
		SaveFormatSettings = New Structure("SpreadsheetDocumentFileType,Presentation,Extension,Filter")
	EndIf;
	
EndProcedure

&AtServer
Function SaveDefaultSetSettings()
	For Each PrintFormSetting In PrintFormsSettings Do
		FillPropertyValues(DefaultSetSettings.Add(), PrintFormSetting);
	EndDo;
EndFunction

&AtServer
Procedure SetUpFormItemsVisibility(Val HasOutputAllowed)
	
	HasEditingAllowed = HasEditingAllowed();
	
	CanSendEmails = False;
	If Common.SubsystemExists("StandardSubsystems.EmailOperations") Then
		ModuleEmail = Common.CommonModule("EmailOperations");
		CanSendEmails = ModuleEmail.CanSendEmails();
	EndIf;
	CanSendByEmail = HasOutputAllowed AND CanSendEmails;
	
	HasDataToPrint = HasDataToPrint();
	
	Items.GoToDocumentButton.Visible = PrintObjects.Count() > 1;
	
	Items.SaveButton.Visible = HasDataToPrint AND HasOutputAllowed AND HasEditingAllowed;
	Items.SaveButtonAllActions.Visible = Items.SaveButton.Visible;
	
	Items.SendButton.Visible = CanSendByEmail AND HasDataToPrint AND HasEditingAllowed;
	Items.SendButtonAllActions.Visible = Items.SendButton.Visible;
	
	Items.PrintButtonCommandBar.Visible = HasOutputAllowed AND HasDataToPrint;
	Items.PrintButtonAllActions.Visible = Items.PrintButtonCommandBar.Visible;
	
	Items.Copies.Visible = HasOutputAllowed AND HasDataToPrint;
	Items.EditButton.Visible = HasOutputAllowed AND HasDataToPrint AND HasEditingAllowed;
	
	If Items.Find("PreviewButton") <> Undefined Then
		Items.PreviewButton.Visible = HasOutputAllowed;
	EndIf;
	If Items.Find("PreviewButtonAllActions") <> Undefined Then
		Items.PreviewButtonAllActions.Visible = HasOutputAllowed;
	EndIf;
	If Items.Find("AllActionsPageParametersButton") <> Undefined Then
		Items.AllActionsPageParametersButton.Visible = HasOutputAllowed;
	EndIf;
	
	If Not HasDataToPrint Then
		Items.CalculateSum.Visible = False;
		Items.CurrentPrintForm.SetAction("OnActivateArea", "");
	EndIf;
	
	Items.ShowHideSetSettingsButton.Visible = IsSetPrinting();
	Items.PrintFormsSettings.Visible = IsSetPrinting();
	
	SetSettingsAvailable = True;
	If TypeOf(Parameters.PrintParameters) = Type("Structure") AND Parameters.PrintParameters.Property("FixedSet") Then
		SetSettingsAvailable = Not Parameters.PrintParameters.FixedSet;
	EndIf;
	
	Items.SetSettingsGroupContextMenu.Visible = SetSettingsAvailable;
	Items.SetSettingsGroupCommandBar.Visible = IsSetPrinting() AND SetSettingsAvailable;
	Items.PrintFormsSettingsPrint.Visible = SetSettingsAvailable;
	Items.PrintFormsSettingsCount.Visible = SetSettingsAvailable;
	Items.PrintFormsSettings.Header = SetSettingsAvailable;
	Items.PrintFormsSettings.HorizontalLines = SetSettingsAvailable;
	
	If Not SetSettingsAvailable Then
		AddCopiesCountToPrintFormsPresentations();
	EndIf;
	
	CanEditTemplates = AccessRight("Update", Metadata.InformationRegisters.UserPrintTemplates) AND HasTemplatesToEdit();
	Items.ChangeTemplateButton.Visible = CanEditTemplates AND HasDataToPrint;
    
    Items.Settings.Visible = Parameters.PrintParameters.Property("ID")
		And PrintManagementServerCallDrive.CheckPrintFormSettings(Parameters.PrintParameters.ID)
		And Parameters.PrintParameters.Property("PrintObjects");
		
EndProcedure

&AtServer
Procedure AddCopiesCountToPrintFormsPresentations()
	For Each PrintFormSetting In PrintFormsSettings Do
		If PrintFormSetting.Count <> 1 Then
			PrintFormSetting.Presentation = PrintFormSetting.Presentation 
				+ " (" + PrintFormSetting.Count + " " + NStr("ru = 'экз.'; en = 'copies'; pl = 'kopii';es_ES = 'copias';es_CO = 'copias';tr = 'kopyalar';it = 'Copie';de = 'Kopien'") + ")";
		EndIf;
	EndDo;
EndProcedure

&AtServer
Procedure SetOutputAvailabilityFlagInPrintFormsPresentations(HasOutputAllowed)
	If HasOutputAllowed Then
		For Each PrintFormSetting In PrintFormsSettings Do
			SpreadsheetDocumentField = Items[PrintFormSetting.AttributeName];
			If SpreadsheetDocumentField.Output = UseOutput.Disable Then
				PrintFormSetting.Presentation = PrintFormSetting.Presentation + " (" + NStr("ru = 'вывод не доступен'; en = 'output is not available'; pl = 'dane wyjściowe nie są dostępne';es_ES = 'no se puede imprimir';es_CO = 'no se puede imprimir';tr = 'çıkış mevcut değil';it = 'output non disponibile';de = 'Produktionsmenge nicht verfügbar'") + ")";
			ElsIf SpreadsheetDocumentField.Protection Then
				PrintFormSetting.Presentation = PrintFormSetting.Presentation + " (" + NStr("ru = 'только печать'; en = 'print only'; pl = 'tylko drukowanie';es_ES = 'solo imprimir';es_CO = 'solo imprimir';tr = 'sadece yazdırma';it = 'stampare solo';de = 'nur drucken'") + ")";
			EndIf;
		EndDo;
	EndIf;	
EndProcedure

&AtClient
Procedure SetCopiesCountSettingsVisibility(Val Visibility = Undefined)
	If Visibility = Undefined Then
		Visibility = Not Items.PrintFormsSettings.Visible;
	EndIf;
	
	Items.PrintFormsSettings.Visible = Visibility;
	Items.SetSettingsGroupCommandBar.Visible = Visibility AND SetSettingsAvailable;
EndProcedure

&AtServer
Procedure SetPrinterNameInPrintButtonTooltip()
	If PrintFormsSettings.Count() > 0 Then
		PrinterName = ThisObject[PrintFormsSettings[0].AttributeName].PrinterName;
		If Not IsBlankString(PrinterName) Then
			ThisObject.Commands["Print"].ToolTip = NStr("ru = 'Напечатать на принтере'; en = 'Use printer:'; pl = 'Drukowanie przy użyciu drukarki';es_ES = 'Imprimir utilizando la impresora';es_CO = 'Imprimir utilizando la impresora';tr = 'Yazıcı ile yazdırma';it = 'Utilizzare stampante:';de = 'Drucken mit Drucker'") + " (" + PrinterName + ")";
		EndIf;
	EndIf;
EndProcedure

&AtServer
Procedure SetFormHeader()
	Var FormHeader;
	
	If TypeOf(Parameters.PrintParameters) = Type("Structure") Then
		Parameters.PrintParameters.Property("FormCaption", FormHeader);
	EndIf;
	
	If ValueIsFilled(FormHeader) Then
		Title = FormHeader;
	Else
		If IsSetPrinting() Then
			Title = NStr("ru = 'Печать комплекта'; en = 'Print set'; pl = 'Drukowanie zestawu';es_ES = 'Conjunto de impresión';es_CO = 'Conjunto de impresión';tr = 'Küme yazdırma';it = 'Stampa dell''insieme';de = 'Drucksatz'");
		ElsIf TypeOf(Parameters.CommandParameter) <> Type("Array") Or Parameters.CommandParameter.Count() > 1 Then
			Title = NStr("ru = 'Печать документов'; en = 'Print documents'; pl = 'Wydrukuj dokumenty';es_ES = 'Imprimir los documentos';es_CO = 'Imprimir los documentos';tr = 'Belge yazdır';it = 'Stampa documenti';de = 'Dokumente drucken'");
		Else
			Title = NStr("ru = 'Печать документа'; en = 'Print document'; pl = 'Drukowanie dokumentu';es_ES = 'Imprimir el documento';es_CO = 'Imprimir el documento';tr = 'Belgeyi yazdır';it = 'Stampa del documento';de = 'Dokument drucken'");
		EndIf;
	EndIf;
EndProcedure

&AtClient
Procedure SetCurrentPage()
	
	PrintFormSetting = CurrentPrintFormSetting();
	
	CurrentPage = Items.PrintFormUnavailablePage;
	PrintFormAvailable = PrintFormSetting <> Undefined AND ThisObject[PrintFormSetting.AttributeName].TableHeight > 0;
	If PrintFormAvailable Then
		SetCurrentSpreadsheetDocument(PrintFormSetting.AttributeName);
		FillPropertyValues(Items.CurrentPrintForm, Items[PrintFormSetting.AttributeName], 
			"Output, Protection, Edit");
			
		CurrentPage = Items.CurrentPrintFormPage;
	EndIf;
	Items.Pages.CurrentPage = CurrentPage;
	
	Items.CalculateSum.Enabled = PrintFormAvailable;
	
	SwitchEditingButtonMark();
	SetTemplateChangeAvailability();
	SetOutputCommandsAvailability();
	
EndProcedure

&AtServer
Procedure SetCurrentSpreadsheetDocument(AttributeName)
	CurrentPrintForm = ThisObject[AttributeName];
EndProcedure

&AtClient
Procedure SelectOrClearAll(Mark)
	For Each PrintFormSetting In PrintFormsSettings Do
		PrintFormSetting.Print = Mark;
		If Mark AND PrintFormSetting.Count = 0 Then
			PrintFormSetting.Count = 1;
		EndIf;
	EndDo;
	StartSaveSettings();
EndProcedure

&AtServer
Function EvalOutputUsage(SpreadsheetDocument)
	If SpreadsheetDocument.Output = UseOutput.Auto Then
		Return ?(AccessRight("Output", Metadata), UseOutput.Enable, UseOutput.Disable);
	Else
		Return SpreadsheetDocument.Output;
	EndIf;
EndFunction

&AtServerNoContext
Procedure SavePrintFormsSettings(SettingsKey, PrintFormsSettingsToSave)
	Common.CommonSettingsStorageSave("PrintFormsSettings", SettingsKey, PrintFormsSettingsToSave);
EndProcedure

&AtServer
Procedure RestorePrintFormsSettings(SavedPrintFormsSettings = Undefined)
	If SavedPrintFormsSettings = Undefined Then
		SavedPrintFormsSettings = DefaultSetSettings;
	EndIf;
	
	If SavedPrintFormsSettings = Undefined Then
		Return;
	EndIf;
	
    For Each SavedSetting In SavedPrintFormsSettings Do
        
		FoundSettings = PrintFormsSettings.FindRows(New Structure("DefaultPosition", SavedSetting.DefaultPosition));
		For Each PrintFormSetting In FoundSettings Do
			RowIndex = PrintFormsSettings.IndexOf(PrintFormSetting);
			PrintFormsSettings.Move(RowIndex, PrintFormsSettings.Count()-1 - RowIndex); // Moving to the end
            PrintFormSetting.Count = SavedSetting.Count; 
			PrintFormSetting.Print = PrintFormSetting.Count > 0;
		EndDo;
	EndDo;
EndProcedure

&AtServer
Function PutSpreadsheetDocumentsInTempStorage(PassedSettings)
	Var ZipFileWriter, ArchiveName;
	
	SettingsForSaving = SettingsForSaving();
	FillPropertyValues(SettingsForSaving, PassedSettings);
	
	Result = New Array;
	
	// Preparing the archive
	If SettingsForSaving.PackToArchive Then
		ArchiveName = GetTempFileName("zip");
		ZipFileWriter = New ZipFileWriter(ArchiveName);
	EndIf;
	
	// preparing a temporary folder
	TempFolderName = GetTempFileName();
	CreateDirectory(TempFolderName);
	UsedFilesNames = New Map;
	
	SelectedSaveFormats = SettingsForSaving.SaveFormats;
	TransliterateFilesNames = SettingsForSaving.TransliterateFilesNames;
	FormatsTable = PrintManagement.SpreadsheetDocumentSaveFormatsSettings();
	
	// Saving print forms
	ProcessedPrintForms = New Array;
	For Each PrintFormSetting In PrintFormsSettings Do
		
		If NOT IsBlankString(PrintFormSetting.OfficeDocuments) Then
			
			OfficeDocumentsFiles = Common.ValueFromXMLString(PrintFormSetting.OfficeDocuments);
			
			For Each OfficeDocumentFile In OfficeDocumentsFiles Do
				
				If ZipFileWriter <> Undefined Then 
					FullFileName = UniqueFileName(CommonClientServer.AddLastPathSeparator(TempFolderName) 
						+ OfficeDocumentFile.Value);
					BinaryData = GetFromTempStorage(OfficeDocumentFile.Key);
					BinaryData.Write(FullFileName);
					ZipFileWriter.Add(FullFileName);
				Else
					FileDetails = New Structure;
					FileDetails.Insert("Presentation", OfficeDocumentFile.Value);
					FileDetails.Insert("AddressInTempStorage", OfficeDocumentFile.Key);
					FileDetails.Insert("IsOfficeDocument", True);
					Result.Add(FileDetails);
				EndIf;
				
			EndDo;
			
			Continue;
			
		EndIf;
		
		If Not PrintFormSetting.Print Then
			Continue;
		EndIf;
		
		PrintForm = ThisObject[PrintFormSetting.AttributeName];
		If ProcessedPrintForms.Find(PrintForm) = Undefined Then
			ProcessedPrintForms.Add(PrintForm);
		Else
			Continue;
		EndIf;
		
		If EvalOutputUsage(PrintForm) = UseOutput.Disable Then
			Continue;
		EndIf;
		
		If PrintForm.Protection Then
			Continue;
		EndIf;
		
		If PrintForm.TableHeight = 0 Then
			Continue;
		EndIf;
		
		PrintFormsByObjects = PrintFormsByObjects(PrintForm);
		For Each MapBetweenObjectAndPrintForm In PrintFormsByObjects Do
			PrintForm = MapBetweenObjectAndPrintForm.Value;
			For Each FileType In SelectedSaveFormats Do
				FormatSettings = FormatsTable.FindRows(New Structure("SpreadsheetDocumentFileType", FileType))[0];
				
				If MapBetweenObjectAndPrintForm.Key <> "PrintObjectsNotSpecified" Then
					FileName = ObjectPrintFormFileName(MapBetweenObjectAndPrintForm.Key, Common.ValueFromXMLString(PrintFormSetting.PrintFormFileName));
					If FileName = Undefined Then
						FileName = DefaultPrintFormFileName(MapBetweenObjectAndPrintForm.Key, PrintFormSetting.Name);
					EndIf;
				Else
					FileName = PrintFormSetting.Name;
				EndIf;
				FileName = CommonClientServer.ReplaceProhibitedCharsInFileName(FileName);
				
				If TransliterateFilesNames Then
					FileName = StringFunctionsClientServer.LatinString(FileName);
				EndIf;
				
				FileName = FileName + "." + FormatSettings.Extension;
				
				FullFileName = UniqueFileName(CommonClientServer.AddLastPathSeparator(TempFolderName) + FileName);
				PrintForm.Write(FullFileName, FileType);
				
				If FileType = SpreadsheetDocumentFileType.HTML Then
					InsertPicturesToHTML(FullFileName);
				EndIf;
				
				If ZipFileWriter <> Undefined Then 
					ZipFileWriter.Add(FullFileName);
				Else
					BinaryData = New BinaryData(FullFileName);
					PathInTempStorage = PutToTempStorage(BinaryData, ThisObject.UUID);
					FileDetails = New Structure;
					FileDetails.Insert("Presentation", FileName);
					FileDetails.Insert("AddressInTempStorage", PathInTempStorage);
					If FileType = SpreadsheetDocumentFileType.ANSITXT Then
						FileDetails.Insert("Encoding", "windows-1251");
					EndIf;
					Result.Add(FileDetails);
				EndIf;
			EndDo;
		EndDo;
	EndDo;
	
	// If the archive is prepared, writing it and putting in the temporary storage.
	If ZipFileWriter <> Undefined Then 
		ZipFileWriter.Write();
		ArchiveFile = New File(ArchiveName);
		BinaryData = New BinaryData(ArchiveName);
		PathInTempStorage = PutToTempStorage(BinaryData, ThisObject.UUID);
		FileDetails = New Structure;
		FileDetails.Insert("Presentation", GetFileNameForArchive(TransliterateFilesNames));
		FileDetails.Insert("AddressInTempStorage", PathInTempStorage);
		Result.Add(FileDetails);
	EndIf;
	
	DeleteFiles(TempFolderName);
	If ValueIsFilled(ArchiveName) Then
		DeleteFiles(ArchiveName);
	EndIf;
	
	Return Result;
	
EndFunction

&AtServer
Function PrintFormsByObjects(PrintForm)
	If PrintObjects.Count() = 0 Then
		Return New Structure("PrintObjectsNotSpecified", PrintForm);
	EndIf;
		
	Result = New Map;
	For Each PrintObject In PrintObjects Do
		AreaName = PrintObject.Presentation;
		Area = PrintForm.Areas.Find(AreaName);
		If Area = Undefined Then
			Continue;
		EndIf;
		If PrintObjects.Count() = 1 Then
			SpreadsheetDocument = PrintForm;
		Else
			SpreadsheetDocument = PrintForm.GetArea(Area.Top, , Area.Bottom);
			FillPropertyValues(SpreadsheetDocument, PrintForm,
				PrintManagement.SpreadsheetDocumentPropertiesToCopy());
		EndIf;
		Result.Insert(PrintObject.Value, SpreadsheetDocument);
	EndDo;
	Return Result;
EndFunction

&AtServer
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

&AtServer
Function ObjectPrintFormFileName(PrintObject, PrintFormFileName)
	If TypeOf(PrintFormFileName) = Type("Map") Then
		Return String(PrintFormFileName[PrintObject]);
	ElsIf TypeOf(PrintFormFileName) = Type("String") AND Not IsBlankString(PrintFormFileName) Then
		Return PrintFormFileName;
	Else
		Return Undefined;
	EndIf;
EndFunction

&AtServer
Function DefaultPrintFormFileName(PrintObject, PrintFormName)
	
	If Common.IsDocument(Metadata.FindByType(TypeOf(PrintObject))) Then
		
		DocumentContainsNumber = PrintObject.Metadata().NumberLength > 0;
		
		If DocumentContainsNumber Then
			AttributesList = "Date,Number";
			Template = NStr("ru = '[PrintFormName] № [Number] от [Date]'; en = '[PrintFormName] No. [Number] dated [Date]'; pl = '[PrintFormName] nr [Number] z dn. [Date]';es_ES = '[PrintFormName]№ [Number] de [Date]';es_CO = '[PrintFormName]№ [Number] de [Date]';tr = '[PrintFormName] № [Number], [Date]';it = '[PrintFormName] No. [Number] con data [Date]';de = '[PrintFormName] Nr [Number] von [Date]'");
		Else
			AttributesList = "Date";
			Template = NStr("ru = '[PrintFormName] от [Date]'; en = '[PrintFormName] dated [Date]'; pl = '[PrintFormName] od [Date]';es_ES = '[PrintFormName] de [Date]';es_CO = '[PrintFormName] de [Date]';tr = '[PrintFormName], [Date]';it = '[PrintFormName] con data [Date]';de = '[PrintFormName] von[Date]'");
		EndIf;
		
		ParametersToInsert = Common.ObjectAttributesValues(PrintObject, AttributesList);
		If Common.SubsystemExists("StandardSubsystems.ObjectsPrefixes") AND DocumentContainsNumber Then
			ModuleObjectsPrefixesClientServer = Common.CommonModule("ObjectPrefixationClientServer");
			ParametersToInsert.Number = ModuleObjectsPrefixesClientServer.NumberForPrinting(ParametersToInsert.Number);
		EndIf;
		ParametersToInsert.Date = Format(ParametersToInsert.Date, "DLF=D");
		ParametersToInsert.Insert("PrintFormName", PrintFormName);
		
	Else
		ParametersToInsert = New Structure;
		ParametersToInsert.Insert("PrintFormName",PrintFormName);
		ParametersToInsert.Insert("ObjectPresentation", Common.SubjectString(PrintObject));
		ParametersToInsert.Insert("CurrentDate",Format(CurrentSessionDate(), "DLF=D"));
		Template = NStr("ru = '[PrintFormName] - [ObjectPresentation] - [CurrentDate]'; en = '[PrintFormName] - [ObjectPresentation] - [CurrentDate]'; pl = '[PrintFormName] - [ObjectPresentation] - [CurrentDate]';es_ES = '[PrintFormName] - [ObjectPresentation] - [CurrentDate]';es_CO = '[PrintFormName] - [ObjectPresentation] - [CurrentDate]';tr = '[PrintFormName] - [ObjectPresentation] - [CurrentDate]';it = '[PrintFormName] - [ObjectPresentation] - [CurrentDate]';de = '[PrintFormName] - [ObjectPresentation] - [CurrentDate]'");
	EndIf;
	
	Return StringFunctionsClientServer.InsertParametersIntoString(Template, ParametersToInsert);
	
EndFunction

&AtServer
Function GetFileNameForArchive(TransliterateFilesNames)
	
	Result = "";
	
	For Each PrintFormSetting In PrintFormsSettings Do
		
		If Not PrintFormSetting.Print Then
			Continue;
		EndIf;
		
		PrintForm = ThisObject[PrintFormSetting.AttributeName];
		
		If EvalOutputUsage(PrintForm) = UseOutput.Disable Then
			Continue;
		EndIf;
		
		If IsBlankString(Result) Then
			Result = PrintFormSetting.Name;
		Else
			Result = NStr("ru = 'Документы'; en = 'Documents'; pl = 'Dokumenty';es_ES = 'Documentos';es_CO = 'Documentos';tr = 'Belgeler';it = 'Documenti';de = 'Dokumente'");
			Break;
		EndIf;
	EndDo;
	
	If TransliterateFilesNames Then
		Result = StringFunctionsClientServer.LatinString(Result);
	EndIf;
	
	Return Result + ".zip";
	
EndFunction

&AtClient
Procedure SavePrintFormToFile()
	
	SettingsForSaving = New Structure("SaveFormats", CommonClientServer.ValueInArray(
		SaveFormatSettings.SpreadsheetDocumentFileType));
	FilesInTempStorage = PutSpreadsheetDocumentsInTempStorage(SettingsForSaving);
	
	FilesToReceive = New Array;
	
	For Each FileToWrite In FilesInTempStorage Do
		FileName = CommonClientServer.ReplaceProhibitedCharsInFileName(FileToWrite.Presentation, "");
		Extension = SaveFormatSettings.Extension;
		If FileToWrite.Property("IsOfficeDocument") Then
			Extension = "docx";
		EndIf;
		FilesToReceive.Add(New TransferableFileDescription(FileName + "." + Extension, FileToWrite.AddressInTempStorage));
	EndDo;
	
	ChoiceDialog = New FileDialog(FileDialogMode.ChooseDirectory);
	ChoiceDialog.Title = NStr("ru ='Выбор папки для сохранения сформированного документа'; en = 'Select a folder to save the generated document'; pl = 'Wybór folderu dla zapisu utworzonego dokumentu';es_ES = 'Seleccionar la carpeta para guardar el documento generado';es_CO = 'Seleccionar la carpeta para guardar el documento generado';tr = 'Oluşturulan belgenin kaydedilmesi için klasör seçimi';it = 'Selezionare una cartella per salvare il documento generato';de = 'Ordner zum Speichern des generiertes Dokuments auswählen'");
	Notification = New NotifyDescription("SavePrintFormToFileAfterGetFiles", ThisObject);
	BeginGettingFiles(Notification, FilesToReceive, ChoiceDialog, FALSE);
	
EndProcedure

&AtClient
Procedure SavePrintFormToFileAfterGetFiles(ReceivedFiles, AdditionalParameters) Export
	
	If ReceivedFiles = Undefined Then
		Return;
	EndIf;
	
	Notification = New NotifyDescription();
	
	For Each File In ReceivedFiles Do
		CommonClient.OpenFileInViewer(File.Name);
	EndDo;
	
EndProcedure

&AtClient
Procedure SavePrintFormsToFolder(FilesListInTempStorage, Val Folder = "")
	
	#If WebClient Then
		For Each FileToWrite In FilesListInTempStorage Do
			GetFile(FileToWrite.AddressInTempStorage, FileToWrite.Presentation);
		EndDo;
		Return;
	#EndIf
	
	Folder = CommonClientServer.AddLastPathSeparator(Folder);
	For Each FileToWrite In FilesListInTempStorage Do
		BinaryData = GetFromTempStorage(FileToWrite.AddressInTempStorage);
		BinaryData.Write(UniqueFileName(Folder + FileToWrite.Presentation));
	EndDo;
	
	ShowUserNotification(NStr("ru = 'Сохранение успешно завершено'; en = 'Saved successfully'; pl = 'Zapisz zakończono pomyślnie';es_ES = 'Se ha guardado con éxito';es_CO = 'Se ha guardado con éxito';tr = 'Kayıt başarı ile tamamlandı';it = 'Salvato con successo';de = 'Speichern erfolgreich abgeschlossen'"), "file:///" + Folder, NStr("ru = 'в папку:'; en = 'to folder:'; pl = 'do folderu:';es_ES = 'a la carpeta:';es_CO = 'a la carpeta:';tr = 'klasöre:';it = 'nella cartella:';de = 'zum Ordner:'") + " " + Folder, PictureLib.Information32);

EndProcedure

&AtClientAtServerNoContext
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

&AtServer
Function AttachPrintFormsToObject(FilesInTempStorage, ObjectToAttach)
	Result = New Array;
	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		ModuleStoredFiles = Common.CommonModule("FilesOperations");
		For Each File In FilesInTempStorage Do
			FileParameters = New Structure;
			FileParameters.Insert("FilesOwner", ObjectToAttach);
			FileParameters.Insert("Author", Undefined);
			FileParameters.Insert("BaseName", File.Presentation);
			FileParameters.Insert("ExtensionWithoutPoint", Undefined);
			FileParameters.Insert("Modified", Undefined);
			FileParameters.Insert("ModificationTimeUniversal", Undefined);
			Result.Add(ModuleStoredFiles.AppendFile(
				FileParameters, File.AddressInTempStorage, , NStr("ru = 'Печатная форма'; en = 'Print form'; pl = 'Formularz wydruku';es_ES = 'Versión impresa';es_CO = 'Versión impresa';tr = 'Yazdırma formu';it = 'Stampa modulo';de = 'Formular drucken'")));
		EndDo;
	EndIf;
	Return Result;
EndFunction

&AtServer
Function IsSetPrinting()
	Return PrintFormsSettings.Count() > 1;
EndFunction

&AtServer
Function HasOutputAllowed()
	
	For Each PrintFormSetting In PrintFormsSettings Do
		If Items[PrintFormSetting.AttributeName].Output = UseOutput.Enable Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

&AtServer
Function HasEditingAllowed()
	
	For Each PrintFormSetting In PrintFormsSettings Do
		If Items[PrintFormSetting.AttributeName].Protection = False Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

&AtClient
Function MoreThanOneRecipient(Recipient)
	If TypeOf(Recipient) = Type("Array") Or TypeOf(Recipient) = Type("ValueList") Then
		Return Recipient.Count() > 1;
	Else
		Return CommonClientServer.EmailsFromString(Recipient).Count() > 1;
	EndIf;
EndFunction

&AtServer
Function HasDataToPrint()
	Result = False;
	For Each PrintFormSetting In PrintFormsSettings Do
		Result = Result Or ThisObject[PrintFormSetting.AttributeName].TableHeight > 0;
	EndDo;
	Return Result;
EndFunction

&AtServer
Function HasTemplatesToEdit()
	Result = False;
	For Each PrintFormSetting In PrintFormsSettings Do
		Result = Result Or Not IsBlankString(PrintFormSetting.PathToTemplate);
	EndDo;
	Return Result;
EndFunction

&AtClient
Procedure OpenTemplateForEditing()
	
	PrintFormSetting = CurrentPrintFormSetting();
	
	DisplayCurrentPrintFormState(NStr("ru = 'Макет редактируется'; en = 'Template is being edited'; pl = 'Szablon jest edytowany';es_ES = 'El modelo se está editando';es_CO = 'El modelo se está editando';tr = 'Şablon düzenleniyor';it = 'Il template è stato modificato';de = 'Die Vorlage wird bearbeitet'"));
	
	TemplateMetadataObjectName = PrintFormSetting.PathToTemplate;
	
	OpeningParameters = New Structure;
	OpeningParameters.Insert("TemplateMetadataObjectName", TemplateMetadataObjectName);
	OpeningParameters.Insert("WindowOpeningMode", FormWindowOpeningMode.LockOwnerWindow);
	OpeningParameters.Insert("DocumentName", PrintFormSetting.Presentation);
	OpeningParameters.Insert("TemplateType", "MXL");
	OpeningParameters.Insert("Edit", True);
	
	OpenForm("CommonForm.EditSpreadsheetDocument", OpeningParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure DisplayCurrentPrintFormState(StateText = "")
	
	DisplayState = Not IsBlankString(StateText);
	
	SpreadsheetDocumentField = Items.CurrentPrintForm;
	
	StatePresentation = SpreadsheetDocumentField.StatePresentation;
	StatePresentation.Text = StateText;
	StatePresentation.Visible = DisplayState;
	StatePresentation.AdditionalShowMode = 
		?(DisplayState, AdditionalShowMode.Irrelevance, AdditionalShowMode.DontUse);
		
	SpreadsheetDocumentField.ReadOnly = DisplayState Or SpreadsheetDocumentField.Output = UseOutput.Disable;
	
EndProcedure

&AtClient
Procedure SwitchCurrentPrintFormEditing()
	PrintFormSetting = CurrentPrintFormSetting();
	If PrintFormSetting <> Undefined Then
		SpreadsheetDocumentField = Items[PrintFormSetting.AttributeName];
		SpreadsheetDocumentField.Edit = Not SpreadsheetDocumentField.Edit;
		Items.CurrentPrintForm.Edit = SpreadsheetDocumentField.Edit;
		SwitchEditingButtonMark();
	EndIf;
EndProcedure

&AtClient
Procedure SwitchEditingButtonMark()
	
	PrintFormAvailable = Items.Pages.CurrentPage <> Items.PrintFormUnavailablePage;
	
	CanEdit = False;
	Mark = False;
	
	PrintFormSetting = CurrentPrintFormSetting();
	If PrintFormSetting <> Undefined Then
		SpreadsheetDocumentField = Items[PrintFormSetting.AttributeName];
		CanEdit = PrintFormAvailable AND Not SpreadsheetDocumentField.Protection;
		Mark = SpreadsheetDocumentField.Edit AND CanEdit;
	EndIf;
	
	Items.EditButton.Check = Mark;
	Items.EditButton.Enabled = CanEdit;
	
EndProcedure

&AtClient
Procedure SetTemplateChangeAvailability()
	PrintFormAvailable = Items.Pages.CurrentPage <> Items.PrintFormUnavailablePage;
	PrintFormSetting = CurrentPrintFormSetting();
	Items.ChangeTemplateButton.Enabled = PrintFormAvailable AND Not IsBlankString(PrintFormSetting.PathToTemplate);
EndProcedure

&AtClient
Procedure SetOutputCommandsAvailability()
	
	PrintFormSetting = CurrentPrintFormSetting();
	PrintForm = ThisObject[PrintFormSetting.AttributeName];
	SpreadsheetDocumentField = Items[PrintFormSetting.AttributeName];
	PrintFormAvailable = Items.Pages.CurrentPage <> Items.PrintFormUnavailablePage;
	
	CanPrint = PrintFormAvailable AND SpreadsheetDocumentField.Output = UseOutput.Enable;
	
	If Items.Find("PreviewButton") <> Undefined Then
		Items.PreviewButton.Enabled = CanPrint;
	EndIf;
	If Items.Find("PreviewButtonAllActions") <> Undefined Then
		Items.PreviewButtonAllActions.Enabled = CanPrint;
	EndIf;
	If Items.Find("AllActionsPageParametersButton") <> Undefined Then
		Items.AllActionsPageParametersButton.Enabled = CanPrint;
	EndIf;
	
EndProcedure

&AtClient
Procedure RefreshCurrentPrintForm()
	
	PrintFormSetting = CurrentPrintFormSetting();
	If PrintFormSetting = Undefined Then
		Return;
	EndIf;
	
	RegeneratePrintForm(PrintFormSetting.TemplateName, PrintFormSetting.AttributeName);
	DisplayCurrentPrintFormState();
	
EndProcedure

&AtServer
Procedure RegeneratePrintForm(TemplateName, AttributeName)
	
	Cancel = False;
	PrintFormsCollection = GeneratePrintForms(TemplateName, Cancel);
	If Cancel Then
		Raise NStr("ru = 'Печатная форма не была переформирована.'; en = 'Print form is not generated.'; pl = 'Formularz wydruku nie został zregenerowany.';es_ES = 'Versión impresa no se ha regenerado.';es_CO = 'Versión impresa no se ha regenerado.';tr = 'Yazdırma formu oluşturulmadı.';it = 'Il modulo di stampo non è stato generato.';de = 'Das Druckformular wurde nicht neu generiert.'");
	EndIf;
	
	For Each PrintForm In PrintFormsCollection Do
		If PrintForm.TemplateName = TemplateName Then
			ThisObject[AttributeName] = PrintForm.SpreadsheetDocument;
		EndIf;
	EndDo;
	
	SetCurrentSpreadsheetDocument(AttributeName);
	
EndProcedure

&AtClient
Function CurrentPrintFormSetting()
	Result = Items.PrintFormsSettings.CurrentData;
	If Result = Undefined AND PrintFormsSettings.Count() > 0 Then
		Result = PrintFormsSettings[0];
	EndIf;
	Return Result;
EndFunction

&AtServerNoContext
Procedure WriteTemplate(TemplateMetadataObjectName, TemplateAddressInTempStorage)
	PrintManagement.WriteTemplate(TemplateMetadataObjectName, TemplateAddressInTempStorage);
EndProcedure

&AtClient
Procedure GoToDocumentCompletion(SelectedItem, AdditionalParameters) Export
	
	If SelectedItem = Undefined Then
		Return;
	EndIf;
	
	SpreadsheetDocumentField = Items.CurrentPrintForm;
	SpreadsheetDocument = CurrentPrintForm;
	SelectedDocumentArea = SpreadsheetDocument.Areas.Find(SelectedItem.Value);
	
	SpreadsheetDocumentField.CurrentArea = SpreadsheetDocument.Area("R1C1"); // Moving to the beginning
	
	If SelectedDocumentArea <> Undefined Then
		SpreadsheetDocumentField.CurrentArea = SpreadsheetDocument.Area(SelectedDocumentArea.Top,,SelectedDocumentArea.Bottom,);
	EndIf;
	
EndProcedure

&AtClient
Procedure SendPrintFormsByEmail()
	NotifyDescription = New NotifyDescription("SendPrintFormsByEmailAccountSetupOffered", ThisObject);
	If CommonClient.SubsystemExists("StandardSubsystems.EmailOperations") Then
		ModuleEmailClient = CommonClient.CommonModule("EmailOperationsClient");
		ModuleEmailClient.CheckAccountForSendingEmailExists(NotifyDescription);
	EndIf;
EndProcedure

&AtClient
Procedure SendPrintFormsByEmailAccountSetupOffered(AccountSetUp, AdditionalParameters) Export
	
	If AccountSetUp <> True Then
		Return;
	EndIf;
	
	FormParameters = New Structure;
	NameOfFormToOpen = "CommonForm.SelectAttachmentFormat";
	If CommonClient.SubsystemExists("StandardSubsystems.Interactions") 
		AND StandardSubsystemsClient.ClientRunParameters().UseEmailClient Then
			If MoreThanOneRecipient(OutputParameters.SendOptions.Recipient) Then
				FormParameters.Insert("Recipients", OutputParameters.SendOptions.Recipient);
				NameOfFormToOpen = "CommonForm.ComposeNewMessage";
			EndIf;
	EndIf;
	
	OpenForm(NameOfFormToOpen, FormParameters, ThisObject);
	
EndProcedure

&AtServer
Function SpreadsheetDocumentsToPrint()
	SpreadsheetDocuments = New ValueList;
	
	For Each PrintFormSetting In PrintFormsSettings Do
		If Items[PrintFormSetting.AttributeName].Output = UseOutput.Enable AND PrintFormSetting.Print Then
			PrintForm = ThisObject[PrintFormSetting.AttributeName];
			SpreadsheetDocument = New SpreadsheetDocument;
			SpreadsheetDocument.Put(PrintForm);
			FillPropertyValues(SpreadsheetDocument, PrintForm, PrintManagement.SpreadsheetDocumentPropertiesToCopy());
			SpreadsheetDocument.Copies = PrintFormSetting.Count;
			SpreadsheetDocuments.Add(SpreadsheetDocument, PrintFormSetting.Presentation);
		EndIf;
	EndDo;
	
	Return SpreadsheetDocuments;
EndFunction

&AtClient
Procedure SaveSettings()
	PrintFormsSettingsToSave = New Array;
	For Each PrintFormSetting In PrintFormsSettings Do
		SettingToSave = New Structure;
		SettingToSave.Insert("TemplateName", PrintFormSetting.TemplateName);
		SettingToSave.Insert("Count", ?(PrintFormSetting.Print,PrintFormSetting.Count, 0));
		SettingToSave.Insert("DefaultPosition", PrintFormSetting.DefaultPosition);
		PrintFormsSettingsToSave.Add(SettingToSave);
	EndDo;
	SavePrintFormsSettings(SettingsKey, PrintFormsSettingsToSave);
EndProcedure

&AtClient
Procedure StartSaveSettings()
	DetachIdleHandler("SaveSettings");
	If IsBlankString(SettingsKey) Then
		Return;
	EndIf;
	AttachIdleHandler("SaveSettings", 2, True);
EndProcedure

&AtServer
Function SettingsForSaving()
	SettingsForSaving = New Structure;
	SettingsForSaving.Insert("SaveFormats", New Array);
	SettingsForSaving.Insert("PackToArchive", False);
	SettingsForSaving.Insert("TransliterateFilesNames", False);
	Return SettingsForSaving;
EndFunction

&AtClient
Procedure Settings(Command)
    
    PrintParameters = ThisObject.Parameters.PrintParameters;
    
    OpeningParameters = New Structure("PrintManagerName,TemplatesNames,CommandParameter,PrintParameters");
    OpeningParameters.PrintManagerName = ThisObject.Parameters.PrintManagerName;
    OpeningParameters.TemplatesNames   = ThisObject.Parameters.PrintParameters.ID;
    OpeningParameters.CommandParameter = ThisObject.Parameters.PrintParameters.PrintObjects;
    OpeningParameters.PrintParameters  = ThisObject.Parameters.PrintParameters;
    
    OpeningParameters.PrintParameters.AdditionalParameters.Insert("Result", Undefined);

    Params =  New Structure;
    Params.Insert("OpeningParameters", OpeningParameters);
    Params.Insert("FormOwner", ThisObject);
    Params.Insert("UniqueKey", ThisObject.UniqueKey);
                    
    PrintParameters.AdditionalParameters.Insert("MetadataObject", ?(ThisObject.PrintObjects.Count() = 0,
																	ThisObject.Parameters.PrintParameters.PrintObjects[0],ThisObject.PrintObjects[0].Value));

    NotifyDescription = New NotifyDescription("AfterSettings", ThisObject, Params);
    From = OpenForm("DataProcessor.PrintOptions.Form.Form", PrintParameters,,,,,NotifyDescription);

EndProcedure

&AtClient
// Continues execution of the Settings procedure.
Procedure AfterSettings(Result, Params) Export
	If Result = Undefined Then
		Return;
	EndIf;
    Params.OpeningParameters.PrintParameters.AdditionalParameters.Insert("Result", Result); 
    OpenForm("CommonForm.PrintDocuments", Params.OpeningParameters, Params.FormOwner, Params.UniqueKey);  
    Close();
EndProcedure    

#EndRegion

