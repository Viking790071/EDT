#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If Parameters.Property("Title") Then
		AutoTitle = False;
		Title = Parameters.Title;
	EndIf;
	
	Parameters.Property("SpreadsheetDocuments", SpreadsheetDocuments);
	Parameters.Property("Subject", Subject);
	
	// Checking file names for uniqueness and prohibited characters.
	UsedDocumentNames = New Array;
	For Each ListItem In SpreadsheetDocuments Do
		Presentation = TrimAll(CommonClientServer.ReplaceProhibitedCharsInFileName(ListItem.Presentation));
		Number = 0;
		While UsedDocumentNames.Find(PresentationNumber(Presentation, Number)) <> Undefined Do
			Number = Number + 1;
		EndDo;
		ListItem.Presentation = PresentationNumber(Presentation, Number);
		UsedDocumentNames.Add(ListItem.Presentation);
	EndDo;
	
	FillFormatTable();
	
	For Each SaveFormat In FormatsTable Do
		SaveFormats.Add(SaveFormat.SpreadsheetDocumentFileType, SaveFormat.Presentation, False, SaveFormat.Picture);
	EndDo;
	SaveFormats[0].Check = True;
	
EndProcedure

&AtServer
Procedure BeforeLoadDataFromSettingsAtServer(Settings)
	SaveFormatsFromSettings = Settings["SaveFormats"];
	If SaveFormatsFromSettings <> Undefined Then
		For Each SelectedFormat In SaveFormats Do 
			FormatFromSettings = SaveFormatsFromSettings.FindByValue(SelectedFormat.Value);
			If FormatFromSettings <> Undefined Then
				SelectedFormat.Check = FormatFromSettings.Check;
			EndIf;
		EndDo;
		Settings.Delete("SaveFormats");
	EndIf;
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Attach(Command)
	MarkedFormats = New Array;
	For Each SelectedFormat In SaveFormats Do
		If SelectedFormat.Check Then
			MarkedFormats.Add(SelectedFormat.Value);
		EndIf;
	EndDo;
	
	If MarkedFormats.Count() = 0 Then
		ShowMessageBox(, NStr("ru = 'Необходимо указать как минимум один из предложенных форматов.'; en = 'Specify at least one of the suggested formats.'; pl = 'Wybierz co najmniej jeden z podanych formatów.';es_ES = 'Especificar como mínimo uno de los formatos dados.';es_CO = 'Especificar como mínimo uno de los formatos dados.';tr = 'Verilen formatların en az birini belirleyin.';it = 'Specifica almeno uno dei formati suggeriti.';de = 'Geben Sie mindestens eines der angegebenen Formate an.'"));
		Return;
	EndIf;
	
	SavedDocuments = PutSpreadsheetDocumentsInTempStorage(MarkedFormats);
	NotifyChoice(SavedDocuments);
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure FillFormatTable()
	
	AttributesToAdd = New Array;
	AttributesToAdd.Add(New FormAttribute("SpreadsheetDocumentFileType", New TypeDescription(), "FormatsTable"));
	AttributesToAdd.Add(New FormAttribute("Ref", New TypeDescription(), "FormatsTable"));
	AttributesToAdd.Add(New FormAttribute("Presentation", New TypeDescription(), "FormatsTable"));
	AttributesToAdd.Add(New FormAttribute("Extension", New TypeDescription(), "FormatsTable"));
	AttributesToAdd.Add(New FormAttribute("Picture", New TypeDescription(), "FormatsTable"));
	ChangeAttributes(AttributesToAdd, New Array);
	
	// DocumentDF document (.pdf)
	NewFormat = FormatsTable.Add();
	NewFormat.SpreadsheetDocumentFileType = SpreadsheetDocumentFileType.PDF;
	NewFormat.Ref = Enums.ReportSaveFormats.PDF;
	NewFormat.Extension = "pdf";
	NewFormat.Picture = PictureLib.PDFFormat;
	
	// Microsoft Excel Worksheet 2007 (.xlsx)
	NewFormat = FormatsTable.Add();
	NewFormat.SpreadsheetDocumentFileType = SpreadsheetDocumentFileType.XLSX;
	NewFormat.Ref = Enums.ReportSaveFormats.XLSX;
	NewFormat.Extension = "xlsx";
	NewFormat.Picture = PictureLib.Excel2007Format;

	// Microsoft Excel 97-2003 worksheet (.xls)
	NewFormat = FormatsTable.Add();
	NewFormat.SpreadsheetDocumentFileType = SpreadsheetDocumentFileType.XLS;
	NewFormat.Ref = Enums.ReportSaveFormats.XLS;
	NewFormat.Extension = "xls";
	NewFormat.Picture = PictureLib.ExcelFormat;

	// OpenDocument spreadsheet (.ods).
	NewFormat = FormatsTable.Add();
	NewFormat.SpreadsheetDocumentFileType = SpreadsheetDocumentFileType.ODS;
	NewFormat.Ref = Enums.ReportSaveFormats.ODS;
	NewFormat.Extension = "ods";
	NewFormat.Picture = PictureLib.OpenOfficeCalcFormat;
	
	// Spreadsheet document (.mxl)
	NewFormat = FormatsTable.Add();
	NewFormat.SpreadsheetDocumentFileType = SpreadsheetDocumentFileType.MXL;
	NewFormat.Ref = Enums.ReportSaveFormats.MXL;
	NewFormat.Extension = "mxl";
	NewFormat.Picture = PictureLib.MXLFormat;

	// Document 2007 document (.docx)
	NewFormat = FormatsTable.Add();
	NewFormat.SpreadsheetDocumentFileType = SpreadsheetDocumentFileType.DOCX;
	NewFormat.Ref = Enums.ReportSaveFormats.DOCX;
	NewFormat.Extension = "docx";
	NewFormat.Picture = PictureLib.Word2007Format;
	
	// Web page (.html)
	NewFormat = FormatsTable.Add();
	NewFormat.SpreadsheetDocumentFileType = SpreadsheetDocumentFileType.HTML;
	NewFormat.Ref = Enums.ReportSaveFormats.HTML;
	NewFormat.Extension = "html";
	NewFormat.Picture = PictureLib.HTMLFormat;
	
	// Text document, UTF-8 (.txt).
	NewFormat = FormatsTable.Add();
	NewFormat.SpreadsheetDocumentFileType = SpreadsheetDocumentFileType.TXT;
	NewFormat.Ref = Enums.ReportSaveFormats.TXT;
	NewFormat.Extension = "txt";
	NewFormat.Picture = PictureLib.TXTFormat;
	
	// Text document, ANSI (.txt).
	NewFormat = FormatsTable.Add();
	NewFormat.SpreadsheetDocumentFileType = SpreadsheetDocumentFileType.ANSITXT;
	NewFormat.Ref = Enums.ReportSaveFormats.ANSITXT;
	NewFormat.Extension = "txt";
	NewFormat.Picture = PictureLib.TXTFormat;

	// Adding formats or changing the current ones.
	For Each SaveFormat In FormatsTable Do
		SaveFormat.Presentation = String(SaveFormat.Ref);
	EndDo;
	
EndProcedure

&AtServer
Function PresentationNumber(Presentation, Number)
	Return Presentation + ?(Number = 0, "", " " + Format(Number, "NG="));
EndFunction

&AtServer
Function PutSpreadsheetDocumentsInTempStorage(MarkedFormats)
	Result = New ValueList;
	
	// Archive
	If PackToArchive Then
		ArchiveName = GetTempFileName("zip");
		ZipFileWriter = New ZipFileWriter(ArchiveName);
	EndIf;
	
	// Temporary directory
	TempFolderName = GetTempFileName();
	CreateDirectory(TempFolderName);
	FullFilePath = CommonClientServer.AddLastPathSeparator(TempFolderName);
	
	// Saving spreadsheet documents.
	For Each SpreadsheetDocument In SpreadsheetDocuments Do
		
		If SpreadsheetDocument.Value.Output = UseOutput.Disable Then
			Continue;
		EndIf;
		
		For Each FileType In MarkedFormats Do
			FormatParameters = FormatsTable.FindRows(New Structure("SpreadsheetDocumentFileType", FileType))[0];
			
			FileName = SpreadsheetDocument.Presentation + "." + FormatParameters.Extension;
			FullFileName = FullFilePath + FileName;
			
			SpreadsheetDocument.Value.Write(FullFileName, FileType);
			
			If FileType = SpreadsheetDocumentFileType.HTML Then
				InsertPicturesToHTML(FullFileName);
			EndIf;
			
			If PackToArchive Then 
				ZipFileWriter.Add(FullFileName);
			Else
				Result.Add(PutToTempStorage(New BinaryData(FullFileName), UUID), FileName);
			EndIf;
		EndDo;
		
	EndDo;
	
	// If the archive is prepared, writing it and putting in the temporary storage.
	If PackToArchive Then 
		ZipFileWriter.Write();
		
		ArchiveFile = New File(ArchiveName);
		Result.Add(PutToTempStorage(New BinaryData(ArchiveName), UUID), ArchiveFile.Name);
		
		DeleteFiles(ArchiveName);
	EndIf;
	
	DeleteFiles(TempFolderName);
	
	Return Result;
	
EndFunction

&AtServerNoContext
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

#EndRegion
