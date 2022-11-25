//////////////////////////////////////////////////////////////////////////////////
// Printing using templates in the Microsoft Word (doc) format on the client. For backward compatibility.
//
// Data structure description:
//
// Handler - a structure used for connecting to COM objects.
//  - COMConnection - COMObject
//  - Type - String - either DOC or odt.
//  - FileName - String - a template file name (filled only for the template).
//  - LastOutputType - a type of the last output area
//  - (see. AreaType).
//
// Document area
//  - COMConnection - COMObject
//  - Type - String - either DOC or odt.
//  - Start - an area start position.
//  - End - an area end position.
//

#Region Private

// Creates a COM connection to a Word.Application COM object, creates a single document in it.
// 
//
Function InitializeMSWordPrintForm(Template) Export
	
	Handler = New Structure("Type", "DOC");
	
	Try
		COMObject = New COMObject("Word.Application");
	Except
		EventLogClient.AddMessageForEventLog(EventLogEvent(), "Error",
			DetailErrorDescription(ErrorInfo()),,True);
		FailedToGeneratePrintForm(ErrorInfo());
	EndTry;
	
	Handler.Insert("COMConnection", COMObject);
	Try
		COMObject.Documents.Add();
	Except
		COMObject.Quit(0);
		COMObject = 0;
		EventLogClient.AddMessageForEventLog(EventLogEvent(), "Error",
			DetailErrorDescription(ErrorInfo()),,True);
		FailedToGeneratePrintForm(ErrorInfo());
	EndTry;
	
	
	TemplatePagesSettings = Template; // For backward compatibility (a type of the function input parameter is changed).
	If TypeOf(Template) = Type("Structure") Then
		TemplatePagesSettings = Template.TemplatePagesSettings;
		// Copying styles from the template.
		Template.COMConnection.ActiveDocument.Close();
		Handler.COMConnection.ActiveDocument.CopyStylesFromTemplate(Template.FileName);
		
		Template.COMConnection.WordBasic.DisableAutoMacros(1);
		Template.COMConnection.Documents.Open(Template.FileName);
	EndIf;
	
	// Copying page settings.
	If TemplatePagesSettings <> Undefined Then
		For Each Setting In TemplatePagesSettings Do
			Try
				COMObject.ActiveDocument.PageSetup[Setting.Key] = Setting.Value;
			Except
				// Skipping if the setting is not supported in this application version.
			EndTry;
		EndDo;
	EndIf;
	// Remembering a document view kind.
	Handler.Insert("ViewType", COMObject.Application.ActiveWindow.View.Type);
	
	Return Handler;
	
EndFunction

// Creates a COM connection to a Word.Application COM object and opens a template in it.
//  The template file is saved based on the binary data passed in the function parameters.
// 
//
// Parameters:
// BinaryTemplateData - BinaryData - binary data of a template.
// Returns:
// structure - a template reference.
//
Function GetMSWordTemplate(Val BinaryTemplateData, Val TempFileName) Export
	
	Handler = New Structure("Type", "DOC");
	Try
		COMObject = New COMObject("Word.Application");
	Except
		EventLogClient.AddMessageForEventLog(EventLogEvent(), "Error",
			DetailErrorDescription(ErrorInfo()),,True);
		FailedToGeneratePrintForm(ErrorInfo());
	EndTry;
	
#If WebClient Then
	FilesDetails = New Array;
	FilesDetails.Add(New TransferableFileDescription(TempFileName, PutToTempStorage(BinaryTemplateData)));
	TemporaryDirectory = PrintManagementInternalClient.CreateTemporaryDirectory("MSWord");
	If NOT GetFiles(FilesDetails, , TemporaryDirectory, False) Then
		Return Undefined;
	EndIf;
	TempFileName = CommonClientServer.AddLastPathSeparator(TemporaryDirectory) + TempFileName;
#Else
	TempFileName = GetTempFileName("DOC");
	BinaryTemplateData.Write(TempFileName);
#EndIf
	
	Try
		COMObject.WordBasic.DisableAutoMacros(1);
		COMObject.Documents.Open(TempFileName);
	Except
		COMObject.Quit(0);
		COMObject = 0;
		DeleteFiles(TempFileName);
		EventLogClient.AddMessageForEventLog(EventLogEvent(), "Error",
			DetailErrorDescription(ErrorInfo()),,True);
		Raise(NStr("ru = 'Ошибка при открытии файла шаблона.'; en = 'An error occurred when opening the template file.'; pl = 'Podczas otwierania pliku z szablonu wystąpił błąd.';es_ES = 'Ha ocurrido un error al abrir un archivo de modelo.';es_CO = 'Ha ocurrido un error al abrir un archivo de modelo.';tr = 'Değişim dosyası açılırken bir hata oluştu';it = 'Si è registrato un errore durante l''apertura del file di template.';de = 'Beim Öffnen einer Vorlagendatei ist ein Fehler aufgetreten.'") + Chars.LF 
			+ BriefErrorDescription(ErrorInfo()));
	EndTry;
	
	Handler.Insert("COMConnection", COMObject);
	Handler.Insert("FileName", TempFileName);
	Handler.Insert("IsTemplate", True);
	
	Handler.Insert("TemplatePagesSettings", New Map);
	
	For Each SettingName In PageParametersSettings() Do
		Try
			Handler.TemplatePagesSettings.Insert(SettingName, COMObject.ActiveDocument.PageSetup[SettingName]);
		Except
			// Skipping if the setting is not supported in this application version.
		EndTry;
	EndDo;
	
	Return Handler;
	
EndFunction

// Closes connection to the Word.Application COM object.
// Parameters:
// Handler - a reference to a print form or a template.
// CloseApplication - boolean - shows whether it is necessary to close the application.
//
Procedure CloseConnection(Handler, Val CloseApplication) Export
	
	If CloseApplication Then
		Handler.COMConnection.Quit(0);
	EndIf;
	
	Handler.COMConnection = 0;
	
	#If Not WebClient Then
	If Handler.Property("FileName") Then
		DeleteFiles(Handler.FileName);
	EndIf;
	#EndIf
	
EndProcedure

// Sets a visibility property for the Microsoft Word application.
// Handler - a reference to a print form.
//
Procedure ShowMSWordDocument(Val Handler) Export
	
	COMConnection = Handler.COMConnection;
	COMConnection.Application.Selection.Collapse();
	
	// Restoring a document view kind.
	If Handler.Property("ViewType") Then
		COMConnection.Application.ActiveWindow.View.Type = Handler.ViewType;
	EndIf;
	
	COMConnection.Application.Visible = True;
	COMConnection.Activate();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Functions for getting areas from a template.

// Gets an area from the template.
//
// Parameters:
//  Handler - a reference to a template
//  AreaName - an area name in the template.
//  OffsetStart - Number - overrides an area start boundary when the area starts not after the 
//                              operator parenthesis but after a few characters.
//                              Default value: 1 - a newline character is expected after the 
//                                                         operator parenthesis of the area opening. 
//                                                         The newline character is not to be included in the area.
//  OffsetEnd - Number - overrides an area end boundary when the area ends not directly before the 
//                              operator parenthesis but a few characters before. The value must be 
//                              negative.
//                              Default value:- 1 - a newline character is expected before the 
//                                                         operator parenthesis of the area closing. 
//                                                         The newline character is not to be included in the area.
//
Function GetMSWordTemplateArea(Val Handler,
									Val AreaName,
									Val OffsetStart = 1,
									Val OffsetEnd = -1) Export
	
	Result = New Structure("Document,Start,End");
	
	PositionStart = OffsetStart + GetAreaStartPosition(Handler.COMConnection, AreaName);
	PositionEnd = OffsetEnd + GetAreaEndPosition(Handler.COMConnection, AreaName);
	
	If PositionStart >= PositionEnd Or PositionStart < 0 Then
		Return Undefined;
	EndIf;
	
	Result.Document = Handler.COMConnection.ActiveDocument;
	Result.Start = PositionStart;
	Result.End   = PositionEnd;
	
	Return Result;
	
EndFunction

// Gets a header area of the first template area.
// Parameters:
// Handler - a reference to a template
// Return value is a reference to the header.
// 
//
Function GetHeaderArea(Val Handler) Export
	
	Return New Structure("Header", Handler.COMConnection.ActiveDocument.Sections(1).Headers.Item(1));
	
EndFunction

// Gets a footer area of the first template area.
// Parameters:
// Handler - a reference to a template
// Return value is a reference to the footer.
// 
//
Function GetFooterArea(Handler) Export
	
	Return New Structure("Footer", Handler.COMConnection.ActiveDocument.Sections(1).Footers.Item(1));
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Functions for adding areas to the print form.

// Start: operations with Microsoft Word document headers and footers.

// Adds a footer from a template to a print form.
// Parameters:
// PrintForm - a reference to a print form.
// AreaHandler - a reference to an area in the template.
// Parameters - a list of parameters to be replaced with values.
// ObjectData - object data to fill in.
//
Procedure AddFooter(Val PrintForm, Val HandlerArea) Export
	
	HandlerArea.Footer.Range.Copy();
	Footer(PrintForm).Paste();
	
EndProcedure

// Adds a header from a template to a print form.
// Parameters:
// PrintForm - a reference to a print form.
// AreaHandler - a reference to an area in the template.
// Parameters - a list of parameters to be replaced with values.
// ObjectData - object data to fill in.
//
Procedure FillFooterParameters(Val PrintForm, Val ObjectData = Undefined) Export
	
	If ObjectData = Undefined Then
		Return;
	EndIf;
	
	For Each ParameterValue In ObjectData Do
		If TypeOf(ParameterValue.Value) <> Type("Array") Then
			Replace(Footer(PrintForm), ParameterValue.Key, ParameterValue.Value);
		EndIf;
	EndDo;
	
EndProcedure

Function Footer(PrintForm)
	Return PrintForm.COMConnection.ActiveDocument.Sections(1).Footers.Item(1).Range;
EndFunction

// Adds a header from a template to a print form.
// Parameters:
// PrintForm - a reference to a print form.
// AreaHandler - a reference to an area in the template.
// Parameters - a list of parameters to be replaced with values.
// ObjectData - object data to fill in.
//
Procedure AddHeader(Val PrintForm, Val HandlerArea) Export
	
	HandlerArea.Header.Range.Copy();
	Header(PrintForm).Paste();
	
EndProcedure

// Adds a header from a template to a print form.
// Parameters:
// PrintForm - a reference to a print form.
// AreaHandler - a reference to an area in the template.
// Parameters - a list of parameters to be replaced with values.
// ObjectData - object data to fill in.
//
Procedure FillHeaderParameters(Val PrintForm, Val ObjectData = Undefined) Export
	
	If ObjectData = Undefined Then
		Return;
	EndIf;
	
	For Each ParameterValue In ObjectData Do
		If TypeOf(ParameterValue.Value) <> Type("Array") Then
			Replace(Header(PrintForm), ParameterValue.Key, ParameterValue.Value);
		EndIf;
	EndDo;
	
EndProcedure

Function Header(PrintForm)
	Return PrintForm.COMConnection.ActiveDocument.Sections(1).Headers.Item(1).Range;
EndFunction

// End: operations with Microsoft Word document headers and footers.

// Adds an area from a template to a print form, replacing the area parameters with the object data 
// values.
// The procedure is used upon output of a single area.
//
// Parameters:
// PrintForm - a reference to a print form.
// AreaHandler - a reference to an area in the template.
// GoToNextRow - boolean, shows if it is required to add a line break after the area output.
//
// Returns:
// AreaCoordinates
//
Function AttachArea(Val PrintForm,
							Val HandlerArea,
							Val GoToNextRow = True,
							Val JoinTableRow = False) Export
	
	HandlerArea.Document.Range(HandlerArea.Start, HandlerArea.End).Copy();
	
	PF_ActiveDocument = PrintForm.COMConnection.ActiveDocument;
	DocumentEndPosition	= PF_ActiveDocument.Range().End;
	InsertionArea				= PF_ActiveDocument.Range(DocumentEndPosition-1, DocumentEndPosition-1);
	
	If JoinTableRow Then
		InsertionArea.PasteAppendTable();
	Else
		InsertionArea.Paste();
	EndIf;
	
	// Returning boundaries of the inserted area.
	Result = New Structure("Document, Start, End",
							PF_ActiveDocument,
							DocumentEndPosition-1,
							PF_ActiveDocument.Range().End-1);
	
	If GoToNextRow Then
		InsertBreakAtNewLine(PrintForm);
	EndIf;
	
	Return Result;
	
EndFunction

// Adds a list area from a template to a print form, replacing the area parameters with the values 
// from the object data.
// It is applied upon list data output (bullet or numbered list).
//
// Parameters:
// PrintFormArea - a reference to an area in a print form.
// ObjectData - ObjectData.
//
Procedure FillParameters(Val PrintFormArea, Val ObjectData = Undefined) Export
	
	If ObjectData = Undefined Then
		Return;
	EndIf;
	
	For Each ParameterValue In ObjectData Do
		If TypeOf(ParameterValue.Value) <> Type("Array") Then
			Replace(PrintFormArea.Document.Content, ParameterValue.Key, ParameterValue.Value);
		EndIf;
	EndDo;
	
EndProcedure

// Start: operations with collections.

// Adds a list area from a template to a print form, replacing the area parameters with the values 
// from the object data.
// It is applied upon list data output (bullet or numbered list).
//
// Parameters:
// PrintForm - a reference to a print form.
// AreaHandler - a reference to an area in the template.
// Parameters - string, a list of parameters to be replaced.
// ObjectData - ObjectData
// GoToNextRow - boolean, shows if it is required to add a line break after the area output.
//
Procedure JoinAndFillSet(Val PrintForm,
									  Val HandlerArea,
									  Val ObjectData = Undefined,
									  Val GoToNextRow = True) Export
	
	HandlerArea.Document.Range(HandlerArea.Start, HandlerArea.End).Copy();
	
	ActiveDocument = PrintForm.COMConnection.ActiveDocument;
	
	If ObjectData <> Undefined Then
		For Each RowData In ObjectData Do
			InsertPosition = ActiveDocument.Range().End;
			InsertionArea = ActiveDocument.Range(InsertPosition-1, InsertPosition-1);
			InsertionArea.Paste();
			
			If TypeOf(RowData) = Type("Structure") Then
				For Each ParameterValue In RowData Do
					Replace(ActiveDocument.Content, ParameterValue.Key, ParameterValue.Value);
				EndDo;
			EndIf;
		EndDo;
	EndIf;
	
	If GoToNextRow Then
		InsertBreakAtNewLine(PrintForm);
	EndIf;
	
EndProcedure

// Adds a list area from a template to a print form, replacing the area parameters with the values 
// from the object data.
// Used when outputting a table row.
//
// Parameters:
// PrintForm - a reference to a print form.
// AreaHandler - a reference to an area in the template.
// TableName - a table name (for data access).
// ObjectData - ObjectData
// GoToNextRow - boolean, shows if it is required to add a line break after the area output.
//
Procedure JoinAndFillTableArea(Val PrintForm,
												Val HandlerArea,
												Val ObjectData = Undefined,
												Val GoToNextRow = True) Export
	
	If ObjectData = Undefined Or ObjectData.Count() = 0 Then
		Return;
	EndIf;
	
	FirstRow = True;
	
	HandlerArea.Document.Range(HandlerArea.Start, HandlerArea.End).Copy();
	
	ActiveDocument = PrintForm.COMConnection.ActiveDocument;
	
	// Inserting the first row. The following rows are inserted with formatting based on the first one.
	// 
	InsertBreakAtNewLine(PrintForm); 
	InsertPosition = ActiveDocument.Range().End;
	InsertionArea = ActiveDocument.Range(InsertPosition-1, InsertPosition-1);
	InsertionArea.Paste();
	ActiveDocument.Range(InsertPosition-2, InsertPosition-2).Delete();
	
	If TypeOf(ObjectData[0]) = Type("Structure") Then
		For Each ParameterValue In ObjectData[0] Do
			Replace(ActiveDocument.Content, ParameterValue.Key, ParameterValue.Value);
		EndDo;
	EndIf;
	
	For Each TableRowData In ObjectData Do
		If FirstRow Then
			FirstRow = False;
			Continue;
		EndIf;
		
		NewInsertionPosition = ActiveDocument.Range().End;
		ActiveDocument.Range(InsertPosition-1, ActiveDocument.Range().End-1).Select();
		PrintForm.COMConnection.Selection.InsertRowsBelow();
		
		ActiveDocument.Range(NewInsertionPosition-1, ActiveDocument.Range().End-2).Select();
		PrintForm.COMConnection.Selection.Paste();
		InsertPosition = NewInsertionPosition;
		
		If TypeOf(TableRowData) = Type("Structure") Then
			For Each ParameterValue In TableRowData Do
				Replace(ActiveDocument.Content, ParameterValue.Key, ParameterValue.Value);
			EndDo;
		EndIf;
		
	EndDo;
	
	If GoToNextRow Then
		InsertBreakAtNewLine(PrintForm);
	EndIf;
	
EndProcedure

// End: operations with collections.

// Inserts a line break to the next row.
// Parameters:
// Handler - a reference to a Microsoft Word document. A line break is to be added to this document.
//
Procedure InsertBreakAtNewLine(Val Handler) Export
	ActiveDocument = Handler.COMConnection.ActiveDocument;
	DocumentEndPosition = ActiveDocument.Range().End;
	ActiveDocument.Range(DocumentEndPosition-1, DocumentEndPosition-1).InsertParagraphAfter();
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Other procedures and functions

Function GetAreaStartPosition(Val COMConnection, Val AreaID)
	
	AreaID = "{v8 Area." + AreaID + "}";
	
	EntireDocument = COMConnection.ActiveDocument.Content;
	EntireDocument.Select();
	
	Search = COMConnection.Selection.Find;
	Search.Text = AreaID;
	Search.ClearFormatting();
	Search.Forward = True;
	Search.execute();
	
	If Search.Found Then
		Return COMConnection.Selection.End;
	EndIf;
	
	Return -1;
	
EndFunction

Function GetAreaEndPosition(Val COMConnection, Val AreaID)
	
	AreaID = "{/v8 Area." + AreaID + "}";
	
	EntireDocument = COMConnection.ActiveDocument.Content;
	EntireDocument.Select();
	
	Search = COMConnection.Selection.Find;
	Search.Text = AreaID;
	Search.ClearFormatting();
	Search.Forward = True;
	Search.execute();
	
	If Search.Found Then
		Return COMConnection.Selection.Start;
	EndIf;
	
	Return -1;

	
EndFunction

Function PageParametersSettings()
	
	SettingsArray = New Array;
	SettingsArray.Add("Orientation");
	SettingsArray.Add("TopMargin");
	SettingsArray.Add("BottomMargin");
	SettingsArray.Add("LeftMargin");
	SettingsArray.Add("RightMargin");
	SettingsArray.Add("Gutter");
	SettingsArray.Add("HeaderDistance");
	SettingsArray.Add("FooterDistance");
	SettingsArray.Add("PageWidth");
	SettingsArray.Add("PageHeight");
	SettingsArray.Add("FirstPageTray");
	SettingsArray.Add("OtherPagesTray");
	SettingsArray.Add("SectionStart");
	SettingsArray.Add("OddAndEvenPagesHeaderFooter");
	SettingsArray.Add("DifferentFirstPageHeaderFooter");
	SettingsArray.Add("VerticalAlignment");
	SettingsArray.Add("SuppressEndnotes");
	SettingsArray.Add("MirrorMargins");
	SettingsArray.Add("TwoPagesOnOne");
	SettingsArray.Add("BookFoldPrinting");
	SettingsArray.Add("BookFoldRevPrinting");
	SettingsArray.Add("BookFoldPrintingSheets");
	SettingsArray.Add("GutterPos");
	
	Return SettingsArray;
	
EndFunction

Function EventLogEvent()
	Return NStr("ru = 'Печать'; en = 'Print'; pl = 'Drukuj';es_ES = 'Impresión';es_CO = 'Impresión';tr = 'Yazdır';it = 'Stampa';de = 'Drucken'", CommonClientServer.DefaultLanguageCode());
EndFunction

Procedure FailedToGeneratePrintForm(ErrorInformation)
#If WebClient Then
	ClarificationText = NStr("ru = 'Для формирования этой печатной формы необходимо воспользоваться тонким клиентом.'; en = 'Use a thin client to generate this print from.'; pl = 'Do tworzenia formularzy wydruku, należy skorzystać z cienkiego klienta.';es_ES = 'Para generar este formulario de impresión es necesario usar el cliente ligero.';es_CO = 'Para generar este formulario de impresión es necesario usar el cliente ligero.';tr = 'Bu baskı formunu oluşturmak için ince istemci kullanmanız gerekir.';it = 'Utilizza un thin client per generare questo modulo di stampa.';de = 'Um diese Druckform zu generieren, benötigen Sie einen Thin Client.'");
#Else		
	ClarificationText = "";	
#EndIf
	ExceptionText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("ru = 'Не удалось сформировать печатную форму: %1. 
			|Для вывода печатных форм в формате Microsoft Word требуется, чтобы на компьютере был установлен пакет Microsoft Office. %2'; 
			|en = 'Cannot generate print form: %1.
			|To output print forms in Microsoft Word format, install Microsoft Office package on your computer. %2'; 
			|pl = 'Utworzenie formularza wydruku %1 nie powiodło się.
			|Aby wyświetlić formularze wydruku w formacie Microsoft Word, należy zainstalować na komputerze pakiet Microsoft Office. %2';
			|es_ES = 'Fallado a generar una versión impresa: %1. 
			|Para visualizar las versiones impresas en el formato Microsoft Word, instalar el paquete Microsoft Office en su ordenador. %2';
			|es_CO = 'Fallado a generar una versión impresa: %1. 
			|Para visualizar las versiones impresas en el formato Microsoft Word, instalar el paquete Microsoft Office en su ordenador. %2';
			|tr = 'Bir baskı formu oluşturulamadı: %1. 
			|Microsoft Word biçimindeki yazdırma formlarını görüntülemek için, Microsoft Office paketini bilgisayarınıza yükleyin.%2';
			|it = 'Impossibile generare modulo di stampa: %1.
			|Per stampare moduli di stampa in formato Microsoft Word, installa il pacchetto Microsoft Office sul computer. %2';
			|de = 'Fehler beim Generieren eines Druckformulars: %1.
			|Um Druckformulare im Microsoft Word-Format anzuzeigen, installieren Sie das Microsoft Office-Paket auf Ihrem Computer. %2'"),
		BriefErrorDescription(ErrorInformation), ClarificationText);
	Raise ExceptionText;
EndProcedure

Procedure Replace(Object, Val SearchString, Val ReplacementString)
	
	SearchString = "{v8 " + SearchString + "}";
	ReplacementString = String(ReplacementString);
	
	Object.Select();
	Selection = Object.Application.Selection;
	
	FindObject = Selection.Find;
	FindObject.ClearFormatting();
	While FindObject.Execute(SearchString) Do
		If IsBlankString(ReplacementString) Then
			Selection.Delete();
		ElsIf IsTempStorageURL(ReplacementString) Then
			Selection.Delete();
			TemporaryDirectory = TempFilesDir();
#If WebClient Then
			TempFileName = TemporaryDirectory + String(New UUID) + ".tmp";
#Else
			TempFileName = GetTempFileName("tmp");
#EndIf
			
			FilesDetails = New Array;
			FilesDetails.Add(New TransferableFileDescription(TempFileName, ReplacementString));
			If GetFiles(FilesDetails, , TemporaryDirectory, False) Then
				Selection.Range.InlineShapes.AddPicture(TempFileName);
			Else
				Selection.TypeText("");
			EndIf;
		Else
			Selection.TypeText(ReplacementString);
		EndIf;
	EndDo;
	
	Selection.Collapse();
	
EndProcedure

#EndRegion
