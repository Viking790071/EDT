
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;

	If Parameters.WindowOpeningMode <> Undefined Then
		WindowOpeningMode = Parameters.WindowOpeningMode;
	EndIf;
	
	If Parameters.SpreadsheetDocument = Undefined Then
		If Not IsBlankString(Parameters.TemplateMetadataObjectName) Then
			EditingDenied = Not Parameters.Edit;
			LoadSpreadsheetDocumentFromMetadata();
		EndIf;
		
	ElsIf TypeOf(Parameters.SpreadsheetDocument) = Type("SpreadsheetDocument") Then
		SpreadsheetDocument = Parameters.SpreadsheetDocument;
	Else
		BinaryData = GetFromTempStorage(Parameters.SpreadsheetDocument);
		TempFileName = GetTempFileName("mxl");
		BinaryData.Write(TempFileName);
		SpreadsheetDocument.Read(TempFileName);
		DeleteFiles(TempFileName);
	EndIf;
	
	Items.SpreadsheetDocument.Edit = Parameters.Edit;
	Items.SpreadsheetDocument.ShowGroups = True;
	
	IsTemplate = Not IsBlankString(Parameters.TemplateMetadataObjectName);
	Items.Warning.Visible = IsTemplate AND Parameters.Edit;
	
	Items.EditInExternalApplication.Visible = CommonClientServer.IsWebClient() 
		AND Not IsBlankString(Parameters.TemplateMetadataObjectName) AND Common.SubsystemExists("StandardSubsystems.Print");
	
	If Not IsBlankString(Parameters.DocumentName) Then
		DocumentName = Parameters.DocumentName;
	EndIf;
	
	If CommonClientServer.IsMobileClient() Then
		
		CommonClientServer.SetFormItemProperty(Items, "CommandBar",	"Visible", False);
		CommonClientServer.SetFormItemProperty(Items, "Warning",	"Visible", False);
		CommonClientServer.SetFormItemProperty(Items, "SpreadsheetDocument", "ShowRowAndColumnNames", False);
		CommonClientServer.SetFormItemProperty(Items, "SpreadsheetDocument", "ShowCellNames", False);
		
	Else
		
		Items.SpreadsheetDocument.ShowRowAndColumnNames = SpreadsheetDocument.Template;
		Items.SpreadsheetDocument.ShowCellNames = SpreadsheetDocument.Template;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If Not IsBlankString(Parameters.PathToFile) Then
		NotifyDescription = New NotifyDescription("OnCompleteInitializeFile", ThisObject);
		File = New File();
		File.BeginInitialization(NotifyDescription, Parameters.PathToFile);
		Return;
	EndIf;
	
	SetInitialFormSettings();
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	NotifyDescription = New NotifyDescription("ConfirmAndClose", ThisObject);
	QuestionText = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Сохранить изменения в %1?'; en = 'Do you want to save the changes you made to %1?'; pl = 'Czy chcesz zapisać zmiany do %1?';es_ES = '¿Quiere guardar los cambios en %1?';es_CO = '¿Quiere guardar los cambios en %1?';tr = '%1'' de değişiklikleri kaydetmek istiyor musunuz?';it = 'Salvare le modifiche in %1?';de = 'Möchten Sie Änderungen speichern in %1?'"), DocumentName);
	CommonClient.ShowFormClosingConfirmation(NotifyDescription, Cancel, Exit, QuestionText);
	
	If Modified Or Exit Then
		Return;
	EndIf;
	
	NotificationParameters = New Structure;
	NotificationParameters.Insert("PathToFile", Parameters.PathToFile);
	NotificationParameters.Insert("TemplateMetadataObjectName", Parameters.TemplateMetadataObjectName);
	If WritingCompleted Then
		EventName = "Write_SpreadsheetDocument";
		NotificationParameters.Insert("SpreadsheetDocument", SpreadsheetDocument);
	Else
		EventName = "CancelEditSpreadsheetDocument";
	EndIf;
	Notify(EventName, NotificationParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure ConfirmAndClose(Result = Undefined, AdditionalParameters = Undefined) Export
	NotifyDescription = New NotifyDescription("CloseFormAfterWriteSpreadsheetDocument", ThisObject);
	WriteSpreadsheetDocument(NotifyDescription);
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	If EventName = "SpreadsheetDocumentsToEditNameRequest" AND Source <> ThisObject Then
		Parameter.Add(DocumentName);
	ElsIf EventName = "OwnerFormClosing" AND Source = FormOwner Then
		Close();
		If IsOpen() Then
			Parameter.Cancel = True;
		EndIf;
	EndIf;
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure SpreadsheetDocumentOnActivate(Item)
	UpdateCommandBarButtonMarks();
EndProcedure

#EndRegion

#Region FormCommandHandlers

// Operations with document

&AtClient
Procedure WriteAndClose(Command)
	NotifyDescription = New NotifyDescription("CloseFormAfterWriteSpreadsheetDocument", ThisObject);
	WriteSpreadsheetDocument(NotifyDescription);
EndProcedure

&AtClient
Procedure Write(Command)
	WriteSpreadsheetDocument();
EndProcedure

&AtClient
Procedure Edit(Command)
	Items.SpreadsheetDocument.Edit = Not Items.SpreadsheetDocument.Edit;
	SetUpCommandPresentation();
	SetUpSpreadsheetDocumentRepresentation();
EndProcedure

&AtClient
Procedure EditInExternalApplication(Command)
	If CommonClient.SubsystemExists("StandardSubsystems.Print") Then
		OpeningParameters = New Structure;
		OpeningParameters.Insert("SpreadsheetDocument", SpreadsheetDocument);
		OpeningParameters.Insert("TemplateMetadataObjectName", Parameters.TemplateMetadataObjectName);
		OpeningParameters.Insert("TemplateType", "MXL");
		NotifyDescription = New NotifyDescription("EditInExternalApplicationCompletion", ThisObject);
		ModulePrintManagerClient = CommonClient.CommonModule("PrintManagementClient");
		ModulePrintManagerClient.EditTemplateInExternalApplication(NotifyDescription, OpeningParameters, ThisObject);
	EndIf;
EndProcedure

// Formatting

&AtClient
Procedure IncreaseFontSize(Command)
	
	For Each Area In AreaListForChangingFont() Do
		Size = Area.Font.Size;
		Size = Size + IncreaseFontSizeChangeStep(Size);
		Area.Font = New Font(Area.Font,,Size);
	EndDo;
	
EndProcedure

&AtClient
Procedure DecreaseFontSize(Command)
	
	For Each Area In AreaListForChangingFont() Do
		Size = Area.Font.Size;
		Size = Size - DecreaseFontSizeChangeStep(Size);
		If Size < 1 Then
			Size = 1;
		EndIf;
		Area.Font = New Font(Area.Font,,Size);
	EndDo;
	
EndProcedure

&AtClient
Procedure Strikethrough(Command)
	
	ValueToSet = Undefined;
	For Each Area In AreaListForChangingFont() Do
		If ValueToSet = Undefined Then
			ValueToSet = Not Area.Font.Strikeout = True;
		EndIf;
		Area.Font = New Font(Area.Font,,,,,,ValueToSet);
	EndDo;
	
	UpdateCommandBarButtonMarks();
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure LoadSpreadsheetDocumentFromMetadata()
	If Common.SubsystemExists("StandardSubsystems.Print") Then
		ModulePrintManager = Common.CommonModule("PrintManagement");
		SpreadsheetDocument = ModulePrintManager.PrintFormTemplate(Parameters.TemplateMetadataObjectName);
	EndIf;
EndProcedure

&AtClient
Procedure SetUpSpreadsheetDocumentRepresentation()
	Items.SpreadsheetDocument.ShowHeaders = Items.SpreadsheetDocument.Edit;
	Items.SpreadsheetDocument.ShowGrid = Items.SpreadsheetDocument.Edit;
EndProcedure

&AtClient
Procedure UpdateCommandBarButtonMarks();
	
#If Not WebClient AND NOT MobileClient Then
	Area = Items.SpreadsheetDocument.CurrentArea;
	If TypeOf(Area) <> Type("SpreadsheetDocumentRange") Then
		Return;
	EndIf;
	
	// Font
	Font = Area.Font;
	Items.SpreadsheetDocumentBold.Check = Font <> Undefined AND Font.Bold = True;
	Items.SpreadsheetDocumentItalic.Check = Font <> Undefined AND Font.Italic = True;
	Items.SpreadsheetDocumentUnderline.Check = Font <> Undefined AND Font.Underline = True;
	Items.Strikeout.Check = Font <> Undefined AND Font.Strikeout = True;
	
	// Horizontal alighment
	Items.SpreadsheetDocumentAlignLeft.Check = Area.HorizontalAlign = HorizontalAlign.Left;
	Items.SpreadsheetDocumentAlignCenter.Check = Area.HorizontalAlign = HorizontalAlign.Center;
	Items.SpreadsheetDocumentAlignRight.Check = Area.HorizontalAlign = HorizontalAlign.Right;
	Items.SpreadsheetDocumentJustify.Check = Area.HorizontalAlign = HorizontalAlign.Justify;
	
#EndIf
	
EndProcedure

&AtClient
Function IncreaseFontSizeChangeStep(Size)
	If Size = -1 Then
		Return 10;
	EndIf;
	
	If Size < 10 Then
		Return 1;
	ElsIf 10 <= Size AND  Size < 20 Then
		Return 2;
	ElsIf 20 <= Size AND  Size < 48 Then
		Return 4;
	ElsIf 48 <= Size AND  Size < 72 Then
		Return 6;
	ElsIf 72 <= Size AND  Size < 96 Then
		Return 8;
	Else
		Return Round(Size / 10);
	EndIf;
EndFunction

&AtClient
Function DecreaseFontSizeChangeStep(Size)
	If Size = -1 Then
		Return -8;
	EndIf;
	
	If Size <= 11 Then
		Return 1;
	ElsIf 11 < Size AND Size <= 23 Then
		Return 2;
	ElsIf 23 < Size AND Size <= 53 Then
		Return 4;
	ElsIf 53 < Size AND Size <= 79 Then
		Return 6;
	ElsIf 79 < Size AND Size <= 105 Then
		Return 8;
	Else
		Return Round(Size / 11);
	EndIf;
EndFunction

&AtClient
Function AreaListForChangingFont()
	
	Result = New Array;
	
	For Each AreaToProcess In Items.SpreadsheetDocument.GetSelectedAreas() Do
		If AreaToProcess.Font <> Undefined Then
			Result.Add(AreaToProcess);
			Continue;
		EndIf;
		
		AreaToProcessTop = AreaToProcess.Top;
		AreaToProcessBottom = AreaToProcess.Bottom;
		AreaToProcessLeft = AreaToProcess.Left;
		AreaToProcessRight = AreaToProcess.Right;
		
		If AreaToProcessTop = 0 Then
			AreaToProcessTop = 1;
		EndIf;
		
		If AreaToProcessBottom = 0 Then
			AreaToProcessBottom = SpreadsheetDocument.TableHeight;
		EndIf;
		
		If AreaToProcessLeft = 0 Then
			AreaToProcessLeft = 1;
		EndIf;
		
		If AreaToProcessRight = 0 Then
			AreaToProcessRight = SpreadsheetDocument.TableWidth;
		EndIf;
		
		If AreaToProcess.AreaType = SpreadsheetDocumentCellAreaType.Columns Then
			AreaToProcessTop = AreaToProcess.Bottom;
			AreaToProcessBottom = SpreadsheetDocument.TableHeight;
		EndIf;
			
		For ColumnNumber = AreaToProcessLeft To AreaToProcessRight Do
			ColumnWidth = Undefined;
			For RowNumber = AreaToProcessTop To AreaToProcessBottom Do
				Cell = SpreadsheetDocument.Area(RowNumber, ColumnNumber, RowNumber, ColumnNumber);
				If AreaToProcess.AreaType = SpreadsheetDocumentCellAreaType.Columns Then
					If ColumnWidth = Undefined Then
						ColumnWidth = Cell.ColumnWidth;
					EndIf;
					If Cell.ColumnWidth <> ColumnWidth Then
						Continue;
					EndIf;
				EndIf;
				If Cell.Font <> Undefined Then
					Result.Add(Cell);
				EndIf;
			EndDo;
		EndDo;
	EndDo;
	
	Return Result;
	
EndFunction

&AtClient
Procedure CloseFormAfterWriteSpreadsheetDocument(Close, AdditionalParameters) Export
	If Close Then
		Close();
	EndIf;
EndProcedure

&AtClient
Procedure WriteSpreadsheetDocument(CompletionHandler = Undefined)
	
	If IsNew() Or EditingDenied Then
		StartFileSavingDialog(CompletionHandler);
		Return;
	EndIf;
		
	WriteSpreadsheetDocumentFileNameSelected(CompletionHandler);
	
EndProcedure

&AtClient
Procedure WriteSpreadsheetDocumentFileNameSelected(Val CompletionHandler)
	If Not IsBlankString(Parameters.PathToFile) Then
		SpreadsheetDocument.BeginWriting(
			New NotifyDescription("ProcessSpreadsheetDocumentWritingResult", ThisObject, CompletionHandler),
			Parameters.PathToFile);
	Else
		AfterWriteSpreadsheetDocument(CompletionHandler);
	EndIf;
EndProcedure

&AtClient
Procedure ProcessSpreadsheetDocumentWritingResult(Result, CompletionHandler) Export 
	If Result <> True Then 
		Return;
	EndIf;
	
	EditingDenied = False;
	AfterWriteSpreadsheetDocument(CompletionHandler);
EndProcedure

&AtClient
Procedure AfterWriteSpreadsheetDocument(CompletionHandler)
	WritingCompleted = True;
	Modified = False;
	SetTitle();
	
	If CommonClient.SubsystemExists("StandardSubsystems.FilesOperations") Then
		If ValueIsFilled(Parameters.AttachedFile) Then
			ModuleStoredFilesInternalClient = CommonClient.CommonModule("FilesOperationsInternalClient");
			FileUpdateParameters = ModuleStoredFilesInternalClient.FileUpdateParameters(CompletionHandler, Parameters.AttachedFile, UUID);
			ModuleStoredFilesInternalClient.EndEditAndNotify(FileUpdateParameters);
			Return;
		EndIf;
	EndIf;
	
	ExecuteNotifyProcessing(CompletionHandler, True);
EndProcedure

&AtClient
Procedure StartFileSavingDialog(Val CompletionHandler)
	
	Var SaveFileDialog, NotifyDescription;
	
	SaveFileDialog = New FileDialog(FileDialogMode.Save);
	SaveFileDialog.FullFileName = CommonClientServer.ReplaceProhibitedCharsInFileName(DocumentName);
	SaveFileDialog.Filter = NStr("ru = 'Табличные документы'; en = 'Spreadsheet documents'; pl = 'Arkusze kalkulacyjne';es_ES = 'Documentos de la hoja de cálculo';es_CO = 'Documentos de la hoja de cálculo';tr = 'E-tablo belgeleri';it = 'Fogli elettronici';de = 'Tabellenkalkulationsdokumente'") + " (*.mxl)|*.mxl";
	
	NotifyDescription = New NotifyDescription("OnCompleteFileSelectionDialog", ThisObject, CompletionHandler);
	SaveFileDialog.Show(NotifyDescription);
	
EndProcedure

&AtClient
Procedure OnCompleteFileSelectionDialog(SelectedFiles, CompletionHandler) Export
	
	If SelectedFiles = Undefined Then
		Return;
	EndIf;
	
	FullFileName = SelectedFiles[0];
	
	Parameters.PathToFile = FullFileName;
	DocumentName = Mid(FullFileName, StrLen(FileDetails(FullFileName).Path) + 1);
	If Lower(Right(DocumentName, 4)) = ".mxl" Then
		DocumentName = Left(DocumentName, StrLen(DocumentName) - 4);
	EndIf;
	
	WriteSpreadsheetDocumentFileNameSelected(CompletionHandler);
	
EndProcedure

&AtClient
Function FileDetails(FullName)
	
	SeparatorPosition = StrFind(FullName, GetPathSeparator(), SearchDirection.FromEnd);
	
	Name = Mid(FullName, SeparatorPosition + 1);
	Path = Left(FullName, SeparatorPosition);
	
	ExtensionPosition = StrFind(Name, ".", SearchDirection.FromEnd);
	
	NameWithoutExtension = Left(Name, ExtensionPosition - 1);
	Extension = Mid(Name, ExtensionPosition + 1);
	
	Result = New Structure;
	Result.Insert("FullName", FullName);
	Result.Insert("Name", Name);
	Result.Insert("Path", Path);
	Result.Insert("BaseName", NameWithoutExtension);
	Result.Insert("Extension", Extension);
	
	Return Result;
	
EndFunction
	
&AtClient
Function NewDocumentName()
	Return NStr("ru = 'Новая'; en = 'New'; pl = 'Nowy';es_ES = 'Nuevo';es_CO = 'Nuevo';tr = 'Yeni';it = 'Nuovo';de = 'Neu'");
EndFunction

&AtClient
Procedure SetTitle()
	
	Title = DocumentName;
	If IsNew() Then
		Title = Title + " (" + NStr("ru = 'создание'; en = 'create'; pl = 'utwórz';es_ES = 'crear';es_CO = 'crear';tr = 'oluştur';it = 'crea';de = 'erstellen'") + ")";
	ElsIf EditingDenied Then
		Title = Title + " (" + NStr("ru = 'только просмотр'; en = 'read-only'; pl = 'tylko podgląd';es_ES = 'solo ver';es_CO = 'solo ver';tr = 'sadece görüntüleme';it = 'Solo lettura';de = 'nur ansehen'") + ")";
	EndIf;
	
EndProcedure

&AtClient
Procedure SetUpCommandPresentation()
	
	DocumentCanEdit = Items.SpreadsheetDocument.Edit;
	Items.Edit.Check = DocumentCanEdit;
	Items.EditingCommands.Enabled = DocumentCanEdit;
	Items.WriteAndClose.Enabled = DocumentCanEdit Or Modified;
	Items.Write.Enabled = DocumentCanEdit Or Modified;
	
	If DocumentCanEdit AND Not IsBlankString(Parameters.TemplateMetadataObjectName) Then
		Items.Warning.Visible = True;
	EndIf;
	
EndProcedure

&AtClient
Function IsNew()
	Return IsBlankString(Parameters.TemplateMetadataObjectName) AND IsBlankString(Parameters.PathToFile);
EndFunction

&AtClient
Procedure EditInExternalApplicationCompletion(ImportedSpreadsheetDocument, AdditionalParameters) Export
	If ImportedSpreadsheetDocument = Undefined Then
		Return;
	EndIf;
	
	Modified = True;
	UpdateSpreadsheetDocument(ImportedSpreadsheetDocument);
EndProcedure

&AtServer
Procedure UpdateSpreadsheetDocument(ImportedSpreadsheetDocument)
	SpreadsheetDocument = ImportedSpreadsheetDocument;
EndProcedure


&AtClient
Procedure SetInitialFormSettings()
	
	If Not IsBlankString(Parameters.PathToFile) AND Not EditingDenied Then
		Items.SpreadsheetDocument.Edit = True;
	EndIf;
	
	SetDocumentName();
	SetTitle();
	SetUpCommandPresentation();
	SetUpSpreadsheetDocumentRepresentation();
	
EndProcedure

&AtClient
Procedure SetDocumentName()

	If IsBlankString(DocumentName) Then
		UsedNames = New Array;
		Notify("SpreadsheetDocumentsToEditNameRequest", UsedNames, ThisObject);
		
		Index = 1;
		While UsedNames.Find(NewDocumentName() + Index) <> Undefined Do
			Index = Index + 1;
		EndDo;
		
		DocumentName = NewDocumentName() + Index;
	EndIf;

EndProcedure

&AtClient
Procedure OnCompleteInitializeFile(File, AdditionalParameters) Export
	
	If IsBlankString(DocumentName) Then
		DocumentName = File.BaseName;
	EndIf;
	
	NotifyDescription = New NotifyDescription("OnCompleteGetReadOnly", ThisObject);
	File.BeginGettingReadOnly(NotifyDescription);
	
EndProcedure

&AtClient
Procedure OnCompleteGetReadOnly(ReadOnly, AdditionalParameters) Export
	
	EditingDenied = ReadOnly;
	SetInitialFormSettings();
	
EndProcedure

#EndRegion
