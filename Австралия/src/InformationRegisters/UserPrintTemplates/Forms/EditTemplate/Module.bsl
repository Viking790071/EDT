
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	If Parameters.SpreadsheetDocument <> Undefined Then
		TemplateToChange = Parameters.SpreadsheetDocument;
	EndIf;
	
	TemplateMetadataObjectName = Parameters.TemplateMetadataObjectName;
	
	NameParts = StrSplit(TemplateMetadataObjectName, ".");
	TemplateName = NameParts[NameParts.UBound()];
	
	OwnerName = "";
	For PartNumber = 0 To NameParts.UBound()-1 Do
		If Not IsBlankString(OwnerName) Then
			OwnerName = OwnerName + ".";
		EndIf;
		OwnerName = OwnerName + NameParts[PartNumber];
	EndDo;
	
	TemplateType = Parameters.TemplateType;
	TemplatePresentation = TemplatePresentation();
	TemplateFileName = CommonClientServer.ReplaceProhibitedCharsInFileName(TemplatePresentation) + "." + Lower(TemplateType);
	
	If Parameters.OpenOnly Then
		Title = NStr("ru = 'Открытие макета печатной формы'; en = 'Open print form template'; pl = 'Otwórz szablon formularza wydruku';es_ES = 'Abrir el modelo de la versión impresa';es_CO = 'Abrir el modelo de la versión impresa';tr = 'Yazdırma formu şablonunu aç';it = 'Aprire template modulo stampa';de = 'Öffnen Sie die Druckformularvorlage'");
	EndIf;
	
	ClientType = ?(CommonClientServer.IsWebClient(), "", "Not") + "WebClient";
	WindowOptionsKey = ClientType + Upper(TemplateType);
	
	If Not CommonClientServer.IsWebClient() AND TemplateType = "MXL" Then
		Items.ApplyChangesLabelNotWebClient.Title = NStr(
			"ru = 'После внесения необходимых изменений в макет нажмите на кнопку ""Завершить изменение""'; en = 'Once you finish editing the template, click ""Apply changes""'; pl = 'Po dokonaniu zmian w szablonie kliknij ""Zakończ edycję""';es_ES = 'Después de haber hecho los cambios en el modelo, hacer clic en ""Finalizar la edición""';es_CO = 'Después de haber hecho los cambios en el modelo, hacer clic en ""Finalizar la edición""';tr = 'Şablonda değişiklik yaptıktan sonra ""Sonlandırmayı düzenle"" i tıklayın.';it = 'Dopo aver apportato le modifiche necessarie al layout, clicca sul pulsante ""Completa la modifica""';de = 'Nachdem Sie Änderungen an der Vorlage vorgenommen haben, klicken Sie auf ""Bearbeitung beenden""'");
	EndIf;
	
	SetApplicationNameForTemplateOpening();
	
	Items.Dialog.CurrentPage = Items["ImportToComputerPage" + ClientType];
	Items.CommandBar.CurrentPage = Items.ImportPanel;
	Items.ChangeButton.DefaultButton = True;
	
	If CommonClientServer.IsMobileClient() Then // This is a temporary solution for mobile client. It will be removed from next versions.
		
		CommandBarLocation = FormCommandBarLabelLocation.Auto;
		
		CommonClientServer.SetFormItemProperty(Items, "CancelImportButton", "Visible", False);
		CommonClientServer.SetFormItemProperty(Items, "CancelEditButton", "Visible", False);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	#If Not WebClient AND NOT MobileClient Then
		If Parameters.OpenOnly Then
			Cancel = True;
		EndIf;
		If Parameters.OpenOnly Or TemplateType = "MXL" Then
			OpenTemplate();
		EndIf;
	#EndIf
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If Not IsBlankString(TempFolder) Then
		BeginDeletingFiles(New NotifyDescription, TempFolder);
	EndIf;
	
	If Exit Then
		Return;
	EndIf;
	
	EventName = "CancelTemplateChange";
	If TemplateImported Then
		EventName = "Write_UserPrintTemplates";
	EndIf;
	
	Notify(EventName, New Structure("TemplateMetadataObjectName", TemplateMetadataObjectName), ThisObject);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure LinkToApplicationPageClick(Item)
	CommonClient.OpenURL(TemplateOpeningApplicationAddress);
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Change(Command)
	OpenTemplate();
	If Parameters.OpenOnly Then
		Close();
	EndIf;
EndProcedure

&AtClient
Procedure ApplyChanges(Command)
	
	#If WebClient OR MobileClient Then
		NotifyDescription = New NotifyDescription("PutFileCompletion", ThisObject);
		BeginPutFile(NotifyDescription, TemplateFileAddressInTemporaryStorage, TemplateFileName);
	#Else
		If Lower(TemplateType) = "mxl" Then
			TemplateToChange.Hide();
			TemplateFileAddressInTemporaryStorage = PutToTempStorage(TemplateToChange);
			TemplateImported = True;
		Else
			File = New File(PathToTemplateFile);
			If File.Exist() Then
				BinaryData = New BinaryData(PathToTemplateFile);
				TemplateFileAddressInTemporaryStorage = PutToTempStorage(BinaryData);
				TemplateImported = True;
			EndIf;
		EndIf;
		WriteTemplateAndClose();
	#EndIf
	
EndProcedure


&AtClient
Procedure Cancel(Command)
	Close();
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetApplicationNameForTemplateOpening()
	
	ApplicationNameForTemplateOpening = "";
	
	FileType = Lower(TemplateType);
	If FileType = "mxl" Then
		ApplicationNameForTemplateOpening = NStr("ru = '""1С:Предприятие - Работа с файлами""'; en = '1C:Enterprise - File operations'; pl = '1C:Enterprise - Praca z plikami';es_ES = '1C:Empresa - Operaciones de archivos';es_CO = '1C:Empresa - Operaciones de archivos';tr = '1C:Enterprise - Dosya işlemleri';it = '1C: Enterprise - Lavorare con i file';de = '1C:Enterprise - Dateioperationen'");
		TemplateOpeningApplicationAddress = "http://v8.1c.ru/metod/fileworkshop.htm";
	ElsIf FileType = "doc" Then
		ApplicationNameForTemplateOpening = NStr("ru = '""Microsoft Word""'; en = '""Microsoft Word""'; pl = '""Microsoft Word""';es_ES = '""Microsoft Word""';es_CO = '""Microsoft Word""';tr = '""Microsoft Word""';it = '""Microsoft Word""';de = '""Microsoft Word""'");
		TemplateOpeningApplicationAddress = "http://office.microsoft.com/ru-ru/word";
	ElsIf FileType = "odt" Then
		ApplicationNameForTemplateOpening = NStr("ru = '""OpenOffice Writer""'; en = '""OpenOffice Writer""'; pl = '""OpenOffice Writer""';es_ES = '""OpenOffice Writer""';es_CO = '""OpenOffice Writer""';tr = '""OpenOffice Writer""';it = '""OpenOffice Writer""';de = '""OpenOffice Writer""'");
		TemplateOpeningApplicationAddress = "http://www.openoffice.org/product/writer.html";
	ElsIf FileType = "docx" Then
		ApplicationNameForTemplateOpening = NStr("ru = 'один из офисных пакетов или редактор документов формата Office Open XML'; en = 'one of the office suites or editor of Office Open XML documents'; pl = 'jeden z pakietów biurowych lub edytor dokumentów formatu Office Open XML';es_ES = 'uno de los paquetes de oficina o de los editores de documentos del formato Office Open XML';es_CO = 'uno de los paquetes de oficina o de los editores de documentos del formato Office Open XML';tr = 'Ofis paketlerinden biri veya Office Open XML belge düzenleyicisi';it = 'una delle suite per ufficio o un editor di documenti Office Open XML';de = 'eines der Office-Suites oder des Editors der Office Open XML-Dokumente'");
		TemplateOpeningApplicationAddress = "";
	EndIf;
	
	AdditionalInfoForFilling = New Structure;
	AdditionalInfoForFilling.Insert("TemplateName", TemplatePresentation);
	AdditionalInfoForFilling.Insert("ApplicationName", ApplicationNameForTemplateOpening);
	AdditionalInfoForFilling.Insert("ActionDetails", ?(Parameters.OpenOnly, NStr("ru = 'открытия'; en = 'opening'; pl = 'otwarcia';es_ES = 'aperturas';es_CO = 'aperturas';tr = 'açılışlar';it = 'apertura';de = 'Öffnungen'"), NStr("ru = 'внесения изменений'; en = 'make changes'; pl = 'wprowadzanie zmian';es_ES = 'hacer cambios';es_CO = 'hacer cambios';tr = 'değişiklikler yap';it = 'Fare cambiamenti';de = 'Änderungen vornehmen'")));
	
	ItemsToFill = New Array;
	ItemsToFill.Add(Items.LinkToApplicationPageBeforeImportWebClient);
	ItemsToFill.Add(Items.LinkToApplicationPageBeforeImportNotWebClient);
	ItemsToFill.Add(Items.LinkToApplyChangesApplicationPageWebClient);
	ItemsToFill.Add(Items.LinkToApplyChangesApplicationPageNotWebClient);
	ItemsToFill.Add(Items.LabelBeforeImportTemplateApplicationWebClient);
	ItemsToFill.Add(Items.LabelBeforeImportTemplateApplicationNotWebClient);
	ItemsToFill.Add(Items.ApplyChangesLabelWebClient);
	ItemsToFill.Add(Items.ApplyChangesLabelNotWebClient);
	
	For Each Item In ItemsToFill Do
		Item.Title = StringFunctionsClientServer.InsertParametersIntoString(Item.Title, AdditionalInfoForFilling);
	EndDo;
	
	LinkToAplicationPageVisibility = (CommonClientServer.IsWebClient() Or FileType <> "mxl") AND FileType <> "docx";
	Items.LinkToApplicationPageBeforeImportWebClient.Visible = LinkToAplicationPageVisibility;
	Items.LinkToApplicationPageBeforeImportNotWebClient.Visible = LinkToAplicationPageVisibility;
	Items.LinkToApplyChangesApplicationPageWebClient.Visible = LinkToAplicationPageVisibility;
	Items.LinkToApplyChangesApplicationPageNotWebClient.Visible = LinkToAplicationPageVisibility;
	
	Items.LabelBeforeImportTemplateApplicationNotWebClient.Visible = FileType <> "mxl";
	
	Items.ImportToComputerWebClientPage.Visible = CommonClientServer.IsWebClient();
	Items.ImportToInfobaseWebClientPage.Visible = CommonClientServer.IsWebClient();
	Items.ImportToComputerNotWebClientPage.Visible = Not CommonClientServer.IsWebClient();
	Items.ImportToInfobaseNotWebClientPage.Visible = Not CommonClientServer.IsWebClient();
	
EndProcedure

&AtServer
Function TemplatePresentation()
	
	Result = TemplateName;
	
	Owner = Metadata.FindByFullName(OwnerName);
	If Owner <> Undefined Then
		Template = Owner.Templates.Find(TemplateName);
		If Template <> Undefined Then
			Result = Template.Synonym;
		EndIf;
	EndIf;
	
	Return Result;
	
EndFunction

&AtClient
Procedure OpenTemplate()
	#If WebClient OR MobileClient Then
		OpenWebClientTemplate();
	#Else
		OpenThinClientTemplate();
	#EndIf
EndProcedure

&AtClient
Procedure OpenThinClientTemplate()
	
#If Not WebClient AND NOT MobileClient Then
	Template = PrintFormTemplate(TemplateMetadataObjectName);
	TempFolder = GetTempFileName();
	CreateDirectory(TempFolder);
	PathToTemplateFile = CommonClientServer.AddLastPathSeparator(TempFolder) + TemplateFileName;
	
	If TemplateType = "MXL" Then
		If Parameters.OpenOnly Then
			Template.ReadOnly = True;
			Template.Show(TemplatePresentation,,True);
		Else
			Template.Write(PathToTemplateFile);
			Template.Show(TemplatePresentation, PathToTemplateFile, True);
			
			TemplateToChange = Template;
		EndIf;
	Else
		Template.Write(PathToTemplateFile);
		If Parameters.OpenOnly Then
			TemplateFile = New File(PathToTemplateFile);
			TemplateFile.SetReadOnly(True);
		EndIf;
		CommonClient.OpenFileInViewer(PathToTemplateFile);
	EndIf;
	
	GoToApplyChanges();
#EndIf
	
EndProcedure

&AtClient
Procedure OpenWebClientTemplate()
	GetFile(PutTemplateInTempStorage(), TemplateFileName);
	GoToApplyChanges();
EndProcedure

&AtServer
Function PutTemplateInTempStorage()
	
	Return PutToTempStorage(BinaryTemplateData());
	
EndFunction

&AtServer
Function BinaryTemplateData()
	
	TemplateData = TemplateToChange;
	If TemplateToChange.TableHeight = 0 Then
		TemplateData = PrintManagement.PrintFormTemplate(TemplateMetadataObjectName);
	EndIf;
	
	If TypeOf(TemplateData) = Type("SpreadsheetDocument") Then
		TempFileName = GetTempFileName();
		TemplateData.Write(TempFileName);
		TemplateData = New BinaryData(TempFileName);
		DeleteFiles(TempFileName);
	EndIf;
	
	Return TemplateData;
	
EndFunction

&AtClient
Procedure GoToApplyChanges()
	Items.Dialog.CurrentPage = Items["ImportToInfobasePage" + ClientType];
	Items.CommandBar.CurrentPage = Items.ApplyChangesPanel;
	Items.ApplyChangesButton.DefaultButton = True;
EndProcedure

&AtServer
Function TemplateFromTempStorage()
	Template = GetFromTempStorage(TemplateFileAddressInTemporaryStorage);
	If Lower(TemplateType) = "mxl" AND TypeOf(Template) <> Type("SpreadsheetDocument") Then
		TempFileName = GetTempFileName();
		Template.Write(TempFileName);
		SpreadsheetDocument = New SpreadsheetDocument;
		SpreadsheetDocument.Read(TempFileName);
		Template = SpreadsheetDocument;
		DeleteFiles(TempFileName);
	EndIf;
	Return Template;
EndFunction

&AtServer
Procedure WriteTemplate(Template)
	Record = InformationRegisters.UserPrintTemplates.CreateRecordManager();
	Record.Object = OwnerName;
	Record.TemplateName = TemplateName;
	Record.Use = True;
	Record.Template = New ValueStorage(Template, New Deflation(9));
	Record.Write();
EndProcedure

&AtServerNoContext
Function PrintFormTemplate(TemplateMetadataObjectName)
	Return PrintManagement.PrintFormTemplate(TemplateMetadataObjectName);
EndFunction

&AtClient
Procedure PutFileCompletion(Result, Address, SelectedFileName, AdditionalParameters) Export
	
	TemplateImported = Result;
	TemplateFileAddressInTemporaryStorage = Address;
	TemplateFileName = SelectedFileName;

	WriteTemplateAndClose();
	
EndProcedure

&AtClient
Procedure WriteTemplateAndClose()
	Template = Undefined;
	If TemplateImported Then
		Template = TemplateFromTempStorage();
		If Not ValueIsFilled(Parameters.SpreadsheetDocument) Then
			WriteTemplate(Template);
		EndIf;
	EndIf;
	
	Close(Template);
EndProcedure

#EndRegion
