#Region Private

//////////////////////////////////////////////////////////////////////////////////
// Printing using templates in Office Open XML format.
//
// Data structure description:
//
// Template - structure used for storing areas, sections, footers, and headers from the initial template.
//  - DirectoryName - String - a path, to which the DOCX template container is unpacked for further analysis.
//  - DocumentStructure - Structure - collection, where information on areas, sections, headers, and 
//                                     footers included in the template is gathered.
//
// PrintForm - a structure used to display and fill in areas from the Template structure.
//  - DirectoryName - String - a path, where a directory structure of the final document is placed 
//                           for further assembly of the DOCX container.
//  - DocumentStructure - Structure - a collection that gathers information on areas, sections, 
//                                     headers, and footers displayed in the final document.
//
// Document structure
//  - DocumentAreas - Map - a collection of area templates, in which a key is an area name in the original template.
//  - Sections - Map - a collection of template sections, in which a key is a section number in the original template.
//  - HeaderFooter - Map - a collection of page headers and footers, in which a key is a header or a 
//                                 footer name generated from the original template.
//  - AttachedAreas - Array - a collection of filled and output areas in the final document.
//  - ContentTypes - String - the [Content_Types].xml file text from the DOCX container.
//  - ContentLinks - String - the document.xml.rels file text from the DOCX container.
//  - ContentLinksTable - a value table - a parsed document.xml.rels file by names and IDs of 
//                                               resources.
//  - PicturesDirectory - String - a path to save pictures in the final document.
//  - ImagesExtensions - Array - extensions of the images added to the final document.
//  - DocumentID - String - a document revision ID.
//
// Section structure
//  - HeadersFooters - Map - a collection of template headers and footers for a certain section, 
//                                 where a key is a header or a footer name in the initial template.
//  - Text - String - a section text in the initial template.
//  - Number - Number - a section number in the initial template.
//
// Area structure
//  - Name - String - an area name specified in the initial template.
//  - Text - String - an area text specified in the initial template.
//  - SectionName - Number - a section number in the initial template, to which the area belongs.
//
// Header or footer structure
//  - Name - String - a header or a footer name generated from the initial template.
//  - InternalName - String - a header or a footer file from the DOCX container structure of the initial template.
//  - Text - String - a header or a footer text specified in the initial template.
//  - SectionName - Number - a section number in the initial template, to which the header or the footer belongs.
//

// Returns a print form structure to generate the final document.
//
// Parameters:
//  Template - a print form template.
//
// Returns:
//  Structure - a print form.
//
Function InitializePrintForm(Template) Export
	
	TempDirectoryName = Common.CreateTemporaryDirectory();
	
	CopyDirectoryContent(Template.DirectoryName, TempDirectoryName);
	
	DocumentStructure = InitializeDocument();
	
	PrintForm = New Structure;
	PrintForm.Insert("DirectoryName", TempDirectoryName);
	PrintForm.Insert("DocumentStructure", DocumentStructure);
	
	InitializePrintFormStructure(PrintForm, Template);
	
	Return PrintForm;
	
EndFunction

// Returns a structure of a print form template.
// The template file is filled in based on the binary data passed in the function parameters.
//
// Parameters:
//  BinaryTemplateData - BinaryData - binary data of a template.
//
// Returns:
//  Structure - a print form template.
//
Function GetTemplate(BinaryTemplateData) Export
	
	Extension = DefineDataFileExtensionBySignature(BinaryTemplateData);
	If NOT Extension = "docx" Then
		WriteEventsToEventLog(EventLogEvent(), "Error", NStr("ru = 'Макет шаблона офисного документа имеет не верный формат.'; en = 'Office document template has an incorrect format.'; pl = 'Makieta szablonu dokumentu biurowego ma nieprawidłowy format.';es_ES = 'Modelo de la plantilla del documento de oficina no es de formato incorrecto.';es_CO = 'Modelo de la plantilla del documento de oficina no es de formato incorrecto.';tr = 'Ofis belgenin şablonun maketinin biçimi yanlış.';it = 'Modello di documento office non è in formato corretto.';de = 'Das Layout der Office-Dokumentvorlage ist nicht korrekt.'"));
		Raise(NStr("ru = 'Ошибка анализа макета шаблона. Макет шаблона офисного документа имеет не верный формат.'; en = 'An error occurred while analyzing the template. Office document template has an incorrect format.'; pl = 'Błąd analizy makiety szablonu. Makieta szablonu dokumentu biurowego ma nieprawidłowy format.';es_ES = 'Error al analizar el modelo de la plantilla. El modelo de la plantilla del documento de oficina no es de formato incorrecto.';es_CO = 'Error al analizar el modelo de la plantilla. El modelo de la plantilla del documento de oficina no es de formato incorrecto.';tr = 'Şablon maketin analiz hatası. Ofis belgesinin şablon maketin biçimi yanlış.';it = 'Si è verificato un errore durante l''analisi del modello. Il modello di documento office non è in formato corretto.';de = 'Fehler in der Layout-Analyse. Das Layout einer Vorlage eines Office-Dokuments hat ein falsches Format.'"));
	EndIf;
	
	TempFileName    = GetTempFileName("docx");
	TempDirectoryName = Common.CreateTemporaryDirectory();
	
	BinaryTemplateData.Write(TempFileName);
	
	ParseDOCXDocumentContainer(TempFileName, TempDirectoryName);
	
	DeleteFiles(TempFileName);
	
	DocumentStructure = InitializeDocument();
	
	Template = New Structure;
	Template.Insert("DirectoryName",        TempDirectoryName);
	Template.Insert("DocumentStructure", DocumentStructure);
	
	InitializeTemplateStructure(Template);
	
	Return Template;
	
EndFunction

// Clears all files connected to the print form or its template.
// Parameters:
//  PrintForm - Structure - a print form or its template.
//
Procedure CloseConnection(PrintForm) Export
	
	Try
		Common.DeleteTemporaryDirectory(PrintForm.DirectoryName);
	Except
		WriteEventsToEventLog(EventLogEvent(), "Error", DetailErrorDescription(ErrorInfo()));
		Raise(NStr("ru = 'Не удалось удалить временный каталог шаблона печатной формы по причине:'; en = 'Cannot delete a temporary directory of the print form template due to:'; pl = 'Nie udało się usunąć katalog tymczasowy szablonu formularzu wydruku z powodu:';es_ES = 'No se ha podido eliminar el catálogo temporal de la plantilla del formulario de impresión a causa de:';es_CO = 'No se ha podido eliminar el catálogo temporal de la plantilla del formulario de impresión a causa de:';tr = 'Yazdırma formun şablonun geçici dizini aşağıdaki nedenle silinemedi:';it = 'Impossibile eliminare la directory temporanea dei modelli di stampa a causa di:';de = 'Der temporäre Katalog der gedruckten Formularvorlage konnte aus diesem Grund nicht gelöscht werden:'") + Chars.LF 
			+ BriefErrorDescription(ErrorInfo()));
	EndTry;
	
EndProcedure

// Generates a final document from the print form structure and generates a data file of the DOCX format.
// The data file is placed to a temporary storage.
//
// Parameters:
//  PrintForm - Structure - a print form.
//
// Returns:
//  String - an address of the generated document in a temporary storage.
//
Function GenerateDocument(PrintForm) Export
	
	AreasCount = PrintForm.DocumentStructure.AttachedAreas.Count();
	
	If AreasCount = 0 Then
		DeleteFiles(PrintForm.DirectoryName);
		Return Undefined;
	EndIf;
	
	PathToDocument = AssembleDOCXDocumentFile(PrintForm);
	
	BinaryData = New BinaryData(PathToDocument);
	
	PrintFormStorageAddress = PutToTempStorage(BinaryData, New UUID);
	
	DeleteFiles(PathToDocument);
	DeleteFiles(PrintForm.DirectoryName);
	
	Return PrintFormStorageAddress;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Functions for getting areas from a template.

// Gets an area from the template.
//
// Parameters:
//  Template - Structure - a print form template.
//  AreaName - String - an area name in the template.
//
// Returns:
//  Structure - a template area.
//
Function GetTemplateArea(Template, Val AreaName) Export
	
	Return GetDocumentAreaFromDocumentStructure(Template.DocumentStructure, AreaName);
	
EndFunction

// Gets a header area of the first template area.
//
// Parameters:
//  Template - Structure - a print form template.
//  HeaderFooterType - String - a header or a footer type in the template.
//  AreaNumber - Number - a number of the section, to which the header or the footer belongs.
//
// Returns:
//  Structure - a header or a footer area.
//
Function GetHeaderArea(Template, Val HeaderOrFooterType = "Header", Val SectionName = 1) Export
	
	Parameters = StrSplit(HeaderOrFooterType, "_");
	If Parameters.Count() = 2 Then
		HeaderOrFooterType = Parameters[0];
		Try
			SectionName = Number(Parameters[1]);
		Except
			SectionName = 1;
		EndTry;
	EndIf;
	
	Return GetHeaderOrFooterFromDocumentStructure(Template.DocumentStructure, HeaderOrFooterType, SectionName);
	
EndFunction

// Gets a footer area of the first template area.
//
// Parameters:
//  Template - Structure - a print form template.
//  HeaderOrFooterType - String - a header or a footer type in the template.
//  AreaNumber - Number - a number of the section, to which the header or the footer belongs.
//
// Returns:
//  Structure - a header or a footer area.
//
Function GetFooterArea(Template, Val HeaderOrFooterType = "Footer", Val SectionName = 1) Export
	
	Parameters = StrSplit(HeaderOrFooterType, "_");
	If Parameters.Count() = 2 Then
		HeaderOrFooterType = Parameters[0];
		Try
			SectionName = Number(Parameters[1]);
		Except
			SectionName = 1;
		EndTry;
	EndIf;
	
	HeaderOrFooterArea = GetHeaderOrFooterFromDocumentStructure(Template.DocumentStructure, HeaderOrFooterType, SectionName);
	
	Return HeaderOrFooterArea;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Functions for adding areas to the print form.

// Adds a footer from a template to a print form.
//
// Parameters:
//  PrintForm - Structure - a print form.
//  HeaderOrFooter - Structure - a header or a footer area.
//
// Returns:
//  Structure - an added header or footer area.
//
Function AddFooter(PrintForm, Footer) Export
	
	AddHeaderFooterToDocumentStructure(PrintForm.DocumentStructure, Footer);
	HeaderOrFooterStructure = AttachHeaderOrFooterToDocumentStructure(PrintForm.DocumentStructure, Footer);
	
	Return HeaderOrFooterStructure;
	
EndFunction

// Fills in parameters of a footer in the print form from a template.
//
// Parameters:
//  PrintForm - Structure - a print form.
//  HeaderOrFooter - Structure - a header or a footer area.
//  ObjectData - Structure - an object data to fill in.
//
Procedure FillFooterParameters(PrintForm, Footer, ObjectData = Undefined) Export
	
	If NOT TypeOf(ObjectData) = Type("Structure") Then
		Return;
	EndIf;
	
	FillAreaParameters(PrintForm, Footer, ObjectData);
	
EndProcedure

// Adds a header from a template to a print form.
//
// Parameters:
//  PrintForm - Structure - a print form.
//  HeaderOrFooter - Structure - a header or a footer area.
//
// Returns:
//  Structure - an added header or footer area.
//
Function AddHeader(PrintForm, Header) Export
	
	AddHeaderFooterToDocumentStructure(PrintForm.DocumentStructure, Header);
	HeaderOrFooterStructure = AttachHeaderOrFooterToDocumentStructure(PrintForm.DocumentStructure, Header);
	
	Return HeaderOrFooterStructure;
	
EndFunction

// Fills in parameters of the header in the print form from the template.
//
// Parameters:
//  PrintForm - Structure - a print form.
//  HeaderOrFooter - Structure - a header or a footer area.
//  ObjectData - Structure - an object data to fill in.
//
Procedure FillHeaderParameters(PrintForm, Header, ObjectData = Undefined) Export
	
	If NOT TypeOf(ObjectData) = Type("Structure") Then
		Return;
	EndIf;
	
	FillAreaParameters(PrintForm, Header, ObjectData);
	
EndProcedure

// Adds an area from a template to a print form, replacing the area parameters with the object data 
// values.
// The procedure is used upon output of a single area.
//
// Parameters:
//  PrintForm - Structure - a print form.
//  TemplateArea - Structure - a template area.
//  GoToNextRow - Boolean - determines whether you need to add a line break after the area output.
//
// Returns:
//  Structure - an attached area.
//
Function AttachArea(PrintForm, TemplateArea, Val GoToNextRow = False) Export
	
	AddDocumentAreaToDocumentStructure(PrintForm.DocumentStructure, TemplateArea);
	AreaStructure = AttachDocumentAreaToDocumentStructure(PrintForm.DocumentStructure, TemplateArea);
	
	If GoToNextRow Then
		InsertBreakAtNewLine(PrintForm);
	EndIf;
	
	Return AreaStructure;
	
EndFunction

// Replaces parameters in the area with the object data values.
//
// Parameters:
//  PrintForm - Structure - a print form.
//  TemplateArea - Structure - a template area.
//  ObjectData - Structure - an object data to fill in.
//
Procedure FillParameters(PrintForm, TemplateArea, ObjectData = Undefined) Export
	
	If NOT TypeOf(ObjectData) = Type("Structure") Then
		Return;
	EndIf;
	
	FillAreaParameters(PrintForm, TemplateArea, ObjectData);
	
EndProcedure

// Adds a collection area from a template to a print form, replacing the area parameters with the 
// object data values.
// Applied upon output of list data (bullet or numbered) or a table.
//
// Parameters:
//  PrintForm - Structure - a print form.
//  TemplateArea - Structure - a template area.
//  ObjectData - Structure - object data to fill in.
//  GoToNextRow - Boolean - determines whether you need to add a line break after the output of the whole collection areas.
//
Procedure JoinAndFillSet(PrintForm, TemplateArea, ObjectData = Undefined,
	Val GoToNextRow = False) Export
	
	If NOT TypeOf(ObjectData) = Type("Array") Then
		Return;
	EndIf;
	
	If ObjectData.Count() = 0 Then
		Return;
	EndIf;
	
	For Each RowData In ObjectData Do
		
		If NOT TypeOf(RowData) = Type("Structure") Then
			Continue;
		EndIf;
		
		Area = AttachArea(PrintForm, TemplateArea);
		FillParameters(PrintForm, Area, RowData);
		
	EndDo;
	
	If GoToNextRow Then
		InsertBreakAtNewLine(PrintForm);
	EndIf;
	
EndProcedure

// Inserts a line break to the next row.
//
// Parameters:
//  PrintForm - Structure - a print form.
//
Procedure InsertBreakAtNewLine(PrintForm) Export
	
	Paragraph = PrintForm.DocumentStructure.DocumentAreas.Get("Paragraph");
	
	If Paragraph <> Undefined Then
		
		Paragraph.SectionName = 1;
		
		Count = PrintForm.DocumentStructure.AttachedAreas.Count();
		
		If Count <> 0 Then
			Paragraph.SectionName = PrintForm.DocumentStructure.AttachedAreas[Count - 1].SectionName;
		EndIf;
		
		AttachArea(PrintForm, Paragraph, False);
		
	EndIf;
	
EndProcedure

#Region OperationsWithDocumentStructure

Function InitializeDocument()
	
	Result = New Structure;
	Result.Insert("DocumentAreas",       New Map);
	Result.Insert("Sections",                New Map);
	Result.Insert("HeadersAndFooters",            New Map);
	Result.Insert("AttachedAreas",  New Array);
	Result.Insert("ContentTypes",           "");
	Result.Insert("ContentRelations",          "");
	Result.Insert("ContentLinksTable",  New ValueTable);
	Result.Insert("PicturesDirectory",        "");
	Result.Insert("PicturesExtensions",     New Array);
	Result.Insert("DocumentID", "");
	
	NumberDetails  = New TypeDescription("Number");
	RowDetails = New TypeDescription("String");
	
	Result.ContentLinksTable.Columns.Add("ResourceName",   RowDetails);
	Result.ContentLinksTable.Columns.Add("ResourceID",    RowDetails);
	Result.ContentLinksTable.Columns.Add("ResourceNumber", NumberDetails);
	
	Return Result;
	
EndFunction

Function SectionArea()
	
	Result = New Structure;
	Result.Insert("HeadersAndFooters", New Map);
	Result.Insert("Text",       "");
	Result.Insert("Number",       1);
	
	Return Result;
	
EndFunction

Function DocumentArea()
	
	Result = New Structure;
	Result.Insert("Name",          "");
	Result.Insert("Text",        "");
	Result.Insert("SectionName", 1);
	
	Return Result;
	
EndFunction

Function HeaderOrFooterArea()
	
	Result = New Structure;
	Result.Insert("Name",          "");
	Result.Insert("InternalName",     "");
	Result.Insert("Text",        "");
	Result.Insert("SectionName", 1);
	
	Return Result;
	
EndFunction

Function AddSectionToDocumentStructure(DocumentStructure, Section)
	
	SectionStructure = SectionArea();
	FillPropertyValues(SectionStructure, Section);
	DocumentStructure.Sections.Insert(SectionStructure.Number, SectionStructure);
	Return SectionStructure;
	
EndFunction

Function AddDocumentAreaToDocumentStructure(DocumentStructure, Area)
	
	AreaStructure = DocumentArea();
	FillPropertyValues(AreaStructure, Area);
	DocumentStructure.DocumentAreas.Insert(AreaStructure.Name, AreaStructure);
	Return AreaStructure;
	
EndFunction

Function AddHeaderFooterToDocumentStructure(DocumentStructure, HeaderOrFooter, Val HeaderOrFooterKey = "")
	
	Section = DocumentStructure.Sections.Get(HeaderOrFooter.SectionName);
	
	If Section = Undefined Then
		HeaderOrFooter.Insert("Number", HeaderOrFooter.SectionName);
		Section = AddSectionToDocumentStructure(DocumentStructure, HeaderOrFooter);
	EndIf;
	
	HeaderOrFooterStructure = HeaderOrFooterArea();
	FillPropertyValues(HeaderOrFooterStructure, HeaderOrFooter);
	
	If IsBlankString(HeaderOrFooterKey) Then
		HeaderOrFooterKey = HeaderOrFooterStructure.Name + "_" + Format(HeaderOrFooterStructure.SectionName, "NG=0");
	EndIf;
	
	DocumentStructure.HeadersAndFooters.Insert(HeaderOrFooterKey, HeaderOrFooterStructure);
	
	Return HeaderOrFooterStructure;
	
EndFunction

Function AttachDocumentAreaToDocumentStructure(DocumentStructure, Area)
	
	AreaStructure = DocumentArea();
	FillPropertyValues(AreaStructure, Area);
	
	DocumentStructure.AttachedAreas.Add(AreaStructure);
	
	Return AreaStructure;
	
EndFunction

Function AttachHeaderOrFooterToDocumentStructure(DocumentStructure, HeaderOrFooter)
	
	HeaderOrFooterStructure = HeaderOrFooterArea();
	FillPropertyValues(HeaderOrFooterStructure, HeaderOrFooter);
	
	Section = DocumentStructure.Sections.Get(HeaderOrFooterStructure.SectionName);
	
	If Section = Undefined Then
		HeaderOrFooterStructure.Insert("SectionName", 1);
		Section = DocumentStructure.Sections.Get(1);
	EndIf;
	
	HeaderOrFooterKey = HeaderOrFooterStructure.Name + "_" + Format(HeaderOrFooterStructure.SectionName, "NG=0");
	Section.HeadersAndFooters.Insert(HeaderOrFooterKey, HeaderOrFooterStructure);
	Return HeaderOrFooterStructure;
	
EndFunction

Function GetDocumentAreaFromDocumentStructure(DocumentStructure, AreaName)
	
	Return DocumentStructure.DocumentAreas.Get(AreaName);
	
EndFunction

Function GetHeaderOrFooterFromDocumentStructure(DocumentStructure, HeaderOrFooterName, SectionName = 1)
	
	HeaderOrFooterKey = HeaderOrFooterName + "_" + Format(SectionName, "NG=0");
	Return DocumentStructure.HeadersAndFooters.Get(HeaderOrFooterKey);
	
EndFunction

Procedure AddRowToContentLinksTable(DocumentStructure, ResourceName, ResourceID, ResourceNumber)
	
	NewRow = DocumentStructure.ContentLinksTable.Add();
	NewRow.ResourceName   = ResourceName;
	NewRow.ResourceID    = ResourceID;
	NewRow.ResourceNumber = ResourceNumber;
	
EndProcedure

#EndRegion

#Region OpenOfficeXMLOperations

Procedure ParseDOCXDocumentContainer(Val FullFileName, Val PathToFileStructure)
	
	Try
		Archiver = New ZipFileReader(FullFileName);
	Except
		DeleteFiles(FullFileName);
		WriteEventsToEventLog(EventLogEvent(), "Error", DetailErrorDescription(ErrorInfo()));
		Raise(NStr("ru = 'Не удалось открыть файла шаблона по причине:'; en = 'Cannot open the template file due to:'; pl = 'Nie udało się otworzyć plik szablonu z powodu:';es_ES = 'No se ha podido abrir el archivo de la plantilla a causa:';es_CO = 'No se ha podido abrir el archivo de la plantilla a causa:';tr = 'Şablon dosyası aşağıdaki nedenle açılamaz:';it = 'Impossibile aprire il file template a causa di:';de = 'Die Vorlagendatei konnte aus diesem Grund nicht geöffnet werden:'") + Chars.LF 
			+ BriefErrorDescription(ErrorInfo()));
	EndTry;
	
	Try
		Archiver.ExtractAll(PathToFileStructure, ZIPRestoreFilePathsMode.Restore);
	Except
		Archiver.Close();
		DeleteFiles(FullFileName);
		WriteEventsToEventLog(EventLogEvent(), "Error", DetailErrorDescription(ErrorInfo()));
		Raise(NStr("ru = 'Не удалось выполнить разбор файла шаблона по причине:'; en = 'Cannot parse the template file due to:'; pl = 'Nie udało się przeanalizować pliku szablonu z powodu:';es_ES = 'No se ha podido analizar la plantilla del modelo a causa de:';es_CO = 'No se ha podido analizar la plantilla del modelo a causa de:';tr = 'Şablon dosyası aşağıdaki nedenle detaylandırılamadı:';it = 'Impossibile analizzare il file modello a causa di:';de = 'Die Vorlagendatei konnte aus diesem Grund nicht analysiert werden:'") + Chars.LF 
			+ BriefErrorDescription(ErrorInfo()));
	EndTry;
	
	Archiver.Close();
	
EndProcedure

Procedure AssembleDOCXDocumentContainer(Val FullFileName, Val PathToFileStructure)
	
	Try
		Archiver = New ZipFileWriter(FullFileName);
	Except
		WriteEventsToEventLog(EventLogEvent(), "Error", DetailErrorDescription(ErrorInfo()));
		Raise(NStr("ru = 'Не удалось создать файл документа по причине:'; en = 'Cannot create the document file due to:'; pl = 'Nie udało się utworzyć pliku dokumentu z powodu:';es_ES = 'No se ha podido crear el archivo del documento a causa de:';es_CO = 'No se ha podido crear el archivo del documento a causa de:';tr = 'Belge dosyası aşağıdaki nedenle oluşturulamadı:';it = 'Impossibile creare il file del documento a causa di:';de = 'Aus diesem Grund konnte keine Dokumentdatei erstellt werden:'") + Chars.LF 
			+ BriefErrorDescription(ErrorInfo()));
	EndTry;
	
	FilesPackingMask = CommonClientServer.AddLastPathSeparator(PathToFileStructure) + "*";
	
	Try
		Archiver.Add(FilesPackingMask, ZIPStorePathMode.StoreRelativePath, ZIPSubDirProcessingMode.ProcessRecursively);
		Archiver.Write();
	Except
		WriteEventsToEventLog(EventLogEvent(), "Error", DetailErrorDescription(ErrorInfo()));
		Raise(NStr("ru = 'Не удалось сформировать файл документа по причине:'; en = 'Cannot generate the document file due to:'; pl = 'Nie udało się sformować pliku dokumentu z powodu:';es_ES = 'No se ha podido generar el archivo del documento a causa de:';es_CO = 'No se ha podido generar el archivo del documento a causa de:';tr = 'Belgenin dosyası aşağıdaki nedenle oluşturulamadı:';it = 'Impossibile generare il file documento a causa di:';de = 'Die Dokumentdatei konnte aus diesem Grund nicht generiert werden:'") + Chars.LF 
			+ BriefErrorDescription(ErrorInfo()));
	EndTry;
	
	BinaryData = New BinaryData(FullFileName);
	DataReading   = New DataReader(BinaryData);
	
	DataWriter = New DataWriter(FullFileName);
	DataWriter.WriteByte(DataReading.ReadByte());
	DataWriter.WriteByte(DataReading.ReadByte());
	DataWriter.WriteByte(DataReading.ReadByte());
	DataWriter.WriteByte(DataReading.ReadByte());
	DataWriter.WriteByte(DataReading.ReadByte());
	DataWriter.WriteByte(0);
	DataWriter.WriteByte(6);
	DataWriter.WriteByte(0);
	
	DataReading.ReadByte();
	DataReading.ReadByte();
	DataReading.ReadByte();
	
	ReadDataResult = DataReading.Read();
	
	DataWriter.Write(ReadDataResult.GetBinaryData());
	DataWriter.Close();
	
EndProcedure

Function AssembleDOCXDocumentFile(PrintForm)
	
	FilesToChange = New Map;
	FilesToChange.Insert("ContentRelations", PrintForm.DirectoryName + SetPathSeparator("\word\_rels\document.xml.rels"));
	FilesToChange.Insert("ContentTypes",  PrintForm.DirectoryName + SetPathSeparator("\[Content_Types].xml"));
	FilesToChange.Insert("Document",      PrintForm.DirectoryName + SetPathSeparator("\word\document.xml"));
	
	// Deleting files of blank headers and footers
	HeaderOrFooterOutput = New Map;
	
	For Each Section In PrintForm.DocumentStructure.Sections Do
		
		For Each HeaderOrFooterItem In Section.Value.HeadersAndFooters Do
			
			HeaderOrFooter = HeaderOrFooterItem.Value;
			
			FileName = PrintForm.DirectoryName + SetPathSeparator("\word\") + HeaderOrFooter.InternalName + ".xml";
			If IsBlankString(HeaderOrFooter.Text) Then
				Continue;
			EndIf;
			
			XMLWriter = New TextWriter(FileName, TextEncoding.UTF8);
			XMLWriter.Write(HeaderOrFooter.Text);
			XMLWriter.Close();
			
			HeaderOrFooterOutput.Insert(HeaderOrFooterItem.Key, TRUE);
			
		EndDo;
		
	EndDo;
	
	HeadersOrFootersFilesArray = New Array;
	
	For Each HeaderOrFooterItem In PrintForm.DocumentStructure.HeadersAndFooters Do
		
		If HeaderOrFooterOutput.Get(HeaderOrFooterItem.Key) = TRUE Then
			Continue;
		EndIf;
		
		HeaderOrFooter = HeaderOrFooterItem.Value;
		HeaderOrFooter.Text = "";
		
		FileName = PrintForm.DirectoryName + SetPathSeparator("\word\") + HeaderOrFooter.InternalName + ".xml";
		DeleteFiles(FileName);
		HeadersOrFootersFilesArray.Add(HeaderOrFooter.InternalName);
		
	EndDo;
	
	// Processing content links
	
	XMLReader = InitializeXMLReader(PrintForm.DocumentStructure.ContentRelations);
	XMLWriter = InitializeXMLRecord("", FilesToChange.Get("ContentRelations"));
	
	SkipTag    = False;
	ContinueReading = True;
	
	While True Do
		
		If SkipTag Then
			XMLReader.Skip();
			ContinueReading = XMLReader.Read();
			SkipTag = False;
		Else
			ContinueReading = XMLReader.Read();
		EndIf;
		
		If NOT ContinueReading Then
			Break;
		EndIf;
		
		If XMLReader.NodeType = XMLNodeType.StartElement AND XMLReader.Name = "Relationship" Then
			
			AttributeValue = XMLReader.GetAttribute("Target");
			
			For Each HeaderOrFooterFileName In HeadersOrFootersFilesArray Do
				
				If StrFind(AttributeValue, HeaderOrFooterFileName) > 0 Then
					SkipTag = True;
					Break;
				EndIf;
				
			EndDo;
			
		EndIf;
		
		If NOT SkipTag Then
			WriteXMLItem(XMLReader, XMLWriter);
		EndIf;
		
	EndDo;
	
	PrintForm.DocumentStructure.ContentRelations = XMLWriter.Close(); 
	
	// Processing content types
	
	XMLReader = InitializeXMLReader(PrintForm.DocumentStructure.ContentTypes);
	XMLWriter = InitializeXMLRecord("", FilesToChange.Get("ContentTypes"));
	
	SkipTag    = False;
	ContinueReading = True;
	
	While True Do
		
		If SkipTag Then
			XMLReader.Skip();
			ContinueReading = XMLReader.Read();
			SkipTag = False;
		Else
			ContinueReading = XMLReader.Read();
		EndIf;
		
		If NOT ContinueReading Then
			Break;
		EndIf;
		
		If XMLReader.NodeType = XMLNodeType.StartElement AND XMLReader.Name = "Override" Then
			
			AttributeValue = XMLReader.GetAttribute("PartName");
			
			For Each HeaderOrFooterFileName In HeadersOrFootersFilesArray Do
				
				If StrFind(AttributeValue, HeaderOrFooterFileName) > 0 Then
					SkipTag = True;
					Break;
				EndIf;
				
			EndDo;
			
		EndIf;
		
		If NOT SkipTag Then
			WriteXMLItem(XMLReader, XMLWriter);
		EndIf;
		
	EndDo;
	
	PrintForm.DocumentStructure.ContentTypes = XMLWriter.Close(); 
	
	// Generating a print form document
	
	SequenceNumber = 1;
	
	XMLWriter = InitializeXMLRecord("", FilesToChange.Get("Document"));
	
	SectionName           = Undefined;
	AreasCount     = PrintForm.DocumentStructure.AttachedAreas.Count();
	DocumentID = PrintForm.DocumentStructure.DocumentID;
	
	For Each Area In PrintForm.DocumentStructure.AttachedAreas Do
		
		If Area.SectionName = 0 Then
			Area.SectionName = ?(SectionName = Undefined, 1, SectionName);
		EndIf;
		
		OutputIntermediateSection = ?(SectionName <> Undefined AND SectionName <> Area.SectionName, True, False);
		
		IsLastArea = ?(SequenceNumber = AreasCount, True, False);
		
		// An intermediate section record
		
		If OutputIntermediateSection = True AND IsLastArea = False Then
			
			SectionToOutput = PrintForm.DocumentStructure.Sections.Get(SectionName);
			
			If SectionToOutput <> Undefined Then
				
				SectionText = ProcessDocumentSection(PrintForm.DocumentStructure, SectionToOutput);
				
				SectionOpeningTag = "<w:p w:rsidR=""" + DocumentID + """ w:rsidRDefault=""" + DocumentID + """><w:pPr>";
				SectionClosingTag = "</w:pPr></w:p>";
				SectionText = SectionOpeningTag + SectionText + SectionClosingTag;
				XMLWriter.WriteRaw(SectionText);
				
			EndIf;
			
		EndIf;
		
		// Writing the body
		
		XMLReader = InitializeXMLReader(Area.Text);
		
		While XMLReader.Read() Do
			
			If XMLReader.NodeType = XMLNodeType.EndElement AND XMLReader.Name = "w:body" Then
				Break;
			EndIf;
			
			If SequenceNumber > 1 Then
				
				If XMLReader.NodeType = XMLNodeType.StartElement AND (XMLReader.Name = "w:document" Or XMLReader.Name = "w:body") Then
					Continue;
				EndIf;
				
			EndIf;
			
			WriteXMLItem(XMLReader, XMLWriter);
			
		EndDo;
		
		// Writing the last section
		
		If IsLastArea Then
			
			SectionToOutput = PrintForm.DocumentStructure.Sections.Get(Area.SectionName);
			If SectionToOutput <> Undefined Then
				SectionText = ProcessDocumentSection(PrintForm.DocumentStructure, SectionToOutput);
				XMLWriter.WriteRaw(SectionText);
			EndIf;
			
		EndIf;
		
		SequenceNumber = SequenceNumber + 1;
		SectionName = Area.SectionName;
		
	EndDo;
	
	XMLWriter.WriteEndElement(); // Closing the </w:body> tag
	XMLWriter.WriteEndElement(); // Closing the </w:document> tag
	
	XMLWriter.Close();
	
	PathToDocument = GetTempFileName("DOCX");
	
	AssembleDOCXDocumentContainer(PathToDocument, PrintForm.DirectoryName);
	
	Return PathToDocument;
	
EndFunction

Procedure InitializeTemplateStructure(Template)
	
	DirectoryName            = Template.DirectoryName;
	DocumentStructure     = Template.DocumentStructure;
	ContentLinksTable  = DocumentStructure.ContentLinksTable;
	
	File = New File(DirectoryName + "[Content_Types].xml");
	If File.Exist() Then
		Read = New TextReader(File.FullName, TextEncoding.UTF8);
		FileText = Read.Read();
		DocumentStructure.ContentTypes = FileText;
	EndIf;
	
	LinksFileDirectory = DirectoryName + SetPathSeparator("\word\_rels\");
	
	File = New File(LinksFileDirectory + "document.xml.rels");
	If File.Exist() Then
		XMLReader = New TextReader(File.FullName, TextEncoding.UTF8);
		FileText = XMLReader.Read();
		DocumentStructure.ContentRelations = FileText;
	
		XMLReader = InitializeXMLReader(FileText);
		While XMLReader.Read() Do
			If NOT (XMLReader.NodeType = XMLNodeType.StartElement AND XMLReader.Name = "Relationship") Then
				Continue;
			EndIf;
			
			ResourceID    = XMLReader.GetAttribute("Id");
			ResourceNumber = Number(StrReplace(TrimAll(ResourceID),"rId",""));
			
			NewRow = ContentLinksTable.Add();
			NewRow.ResourceName   = XMLReader.GetAttribute("Target");
			NewRow.ResourceID    = ResourceID;
			NewRow.ResourceNumber = ResourceNumber;
		EndDo;
	EndIf;
	
	// Receiving a table of resource numbers
	
	DirectoryWithFileStructure = DirectoryName + "word" + GetPathSeparator();
	
	File = New File(DirectoryWithFileStructure + "document.xml");
	If File.Exist() Then
		XMLReader = InitializeXMLReader(File.FullName, 1);
		AnalysisParameters = New Structure("AnalysisType", 1);
		SplitTemplateTextToAreas(XMLReader, DocumentStructure, AnalysisParameters);
	EndIf;
	
	For Each Section In DocumentStructure.Sections Do
		XMLReader = InitializeXMLReader(Section.Value.Text);
		SelectHeadersFootersFormSection(XMLReader, DocumentStructure, Section.Value);
	EndDo;
	
	StructureFiles = FindFiles(DirectoryWithFileStructure, "*.xml");
	For Each File In StructureFiles Do
		If NOT (Left(File.BaseName, 6) = "header") AND NOT (Left(File.BaseName, 6) = "footer") Then
			Continue;
		EndIf;
		
		HeaderOrFooter = DocumentStructure.HeadersAndFooters.Get(File.Name);
		If HeaderOrFooter = Undefined Then
			Continue;
		EndIf;
		
		DocumentStructure.HeadersAndFooters.Delete(File.Name);
		DocumentStructure.HeadersAndFooters.Insert(HeaderOrFooter.Name + "_" + Format(HeaderOrFooter.SectionName, "NG=0"), HeaderOrFooter);
		
		XMLReader = InitializeXMLReader(File.FullName, 1);
		AnalysisParameters = New Structure("AnalysisType, AnalysisStructure", 2, HeaderOrFooter);
		SplitTemplateTextToAreas(XMLReader, DocumentStructure, AnalysisParameters);
	EndDo;
	
EndProcedure

Procedure InitializePrintFormStructure(PrintForm, Template)
	
	DirectoryName        = PrintForm.DirectoryName;
	DocumentStructure = PrintForm.DocumentStructure;
	
	DocumentStructure.DocumentID = Template.DocumentStructure.DocumentID;
	DocumentStructure.PicturesDirectory        = DirectoryName + SetPathSeparator("\word\media\");
	DocumentStructure.ContentLinksTable = Template.DocumentStructure.ContentLinksTable.Copy();
	
	File = New File(DirectoryName + "[Content_Types].xml");
	If File.Exist() Then
		XMLReader = New TextReader(File.FullName,TextEncoding.UTF8);
		FileText = XMLReader.Read();
		DocumentStructure.ContentTypes = FileText;
	EndIf;
	
	LinksFileDirectory = DirectoryName + SetPathSeparator("\word\_rels\");
	
	File = New File(LinksFileDirectory + "document.xml.rels");
	If File.Exist() Then
		XMLReader = New TextReader(File.FullName, TextEncoding.UTF8);
		FileText = XMLReader.Read();
		DocumentStructure.ContentRelations = FileText;
	EndIf;
	
	DirectoryWithFileStructure = DirectoryName + "word" + GetPathSeparator();
	FilesMask ="*.xml";
	StructureFiles = FindFiles(DirectoryWithFileStructure, FilesMask);
	
	For Each File In StructureFiles Do
		If File.BaseName = "document" Then
			XMLWriter = New TextWriter(File.FullName, TextEncoding.UTF8);
			XMLWriter.Write("");
		EndIf;
		
		If Left(File.BaseName, 6) = "header" Then
			XMLWriter = New TextWriter(File.FullName,TextEncoding.UTF8);
			XMLWriter.Write("");
		EndIf;
		
		If Left(File.BaseName, 6) = "footer" Then
			XMLWriter = New TextWriter(File.FullName, TextEncoding.UTF8);
			XMLWriter.Write("");
		EndIf;
	EndDo;
	
	// Copying text of headers or footers and sections from the template
	For Each Section In Template.DocumentStructure.Sections Do
		AddSectionToDocumentStructure(DocumentStructure, Section.Value);
	EndDo;
	
	For Each HeaderOrFooter In Template.DocumentStructure.HeadersAndFooters Do
		
		AddHeaderFooterToDocumentStructure(DocumentStructure, HeaderOrFooter.Value);
		HeaderOrFooterStructure = DocumentStructure.HeadersAndFooters.Get(HeaderOrFooter.Key);
		If HeaderOrFooterStructure <> Undefined Then
			HeaderOrFooterStructure.Text = "";
		EndIf;
		
	EndDo;
	
	Paragraph = Template.DocumentStructure.DocumentAreas.Get("Paragraph");
	
	If Paragraph <> Undefined Then
		AddDocumentAreaToDocumentStructure(DocumentStructure, Paragraph);
	EndIf;
	
EndProcedure

Procedure FillAreaParameters(PrintForm, Area, ObjectData)
	
	ProcessText = FALSE;
	XMLParseStructure = InitializeMXLParsing();
	
	TableOpen       = False; 
	TableCellOpen = False;
	
	TableWidth         = 0;
	TableCellWidth   = 0;
	
	MainDisplayResolution = SessionParameters.ClientParametersAtServer.Get("MainDisplayResolution");
	MainDisplayResolution = ?(MainDisplayResolution = Undefined, 72, MainDisplayResolution);
	
	XMLReader = InitializeXMLReader(Area.Text);
	InitializeWriteToStream(XMLParseStructure, "Area", "");
	
	While XMLReader.Read() Do
		
		If ReadStringTextStart(XMLParseStructure, XMLReader) Then
			ProcessText = TRUE;
		EndIf;
		
		If ReadStringTextEnd(XMLParseStructure, XMLReader) Then
			ProcessText = FALSE;
		EndIf;
		
		If ReadTableStart(XMLParseStructure, XMLReader) Then
			TableOpen = True;
		EndIf;
		
		If TableOpen AND ReadTableWidthStart(XMLParseStructure, XMLReader) Then
			SetFieldWidth(XMLReader, TableWidth);
		EndIf;
		
		If TableOpen AND ReadTableCellStart(XMLParseStructure, XMLReader) Then
			TableCellOpen = True;
		EndIf;
		
		If TableCellOpen AND ReadTableCellWidthStart(XMLParseStructure, XMLReader) Then
			SetFieldWidth(XMLReader, TableCellWidth, TableWidth);
		EndIf;
		
		If ReadTableCellEnd(XMLParseStructure, XMLReader) Then
			TableCellOpen = False;
			TableCellWidth  = 0;
		EndIf;
		
		If ReadTableEnd(XMLParseStructure, XMLReader) Then
			TableOpen = False;
			TableWidth  = 0;
		EndIf;
			
		If ProcessText AND XMLReader.NodeType = XMLNodeType.Text Then
			
			NodeText = XMLReader.Value;
			
			ParametersFromText = New Array;
			
			SelectParameters(ParametersFromText, NodeText);
			
			TextOutput = True;
			PictureOutput = False;
			
			For Each ParameterText In ParametersFromText Do
				
				ParameterValue = String(ObjectData[ParameterText]);
				
				If TypeOf(ParameterValue) = Type("String") AND NOT StrStartsWith(ParameterValue, "e1cib/tempstorage") Then
					NodeText = StrReplace(NodeText, "{v8 " + ParameterText + "}", ParameterValue);
				ElsIf TypeOf(ParameterValue) = Type("String") AND StrStartsWith(ParameterValue, "e1cib/tempstorage") Then
					NodeText = ParameterValue;
					TextOutput = False;
					PictureOutput = True;
					Break;
				EndIf;
				
			EndDo;
			
			If TextOutput Then
				
				WriteTextToStreams(XMLParseStructure, XMLReader, "Area", NodeText);
				
			ElsIf PictureOutput Then
				
				BinaryData = GetFromTempStorage(NodeText);
				
				StructurePicture = New Structure;
				StructurePicture.Insert("BinaryData",     BinaryData);
				StructurePicture.Insert("IconName",        "image");
				StructurePicture.Insert("PicturesDirectory",    PrintForm.DocumentStructure.PicturesDirectory);
				
				PictureParameters = GetImageAttributes(BinaryData);
				
				If PictureParameters.Count() = 0 OR PictureParameters.ImageType = Null Then
					WriteTextToStreams(XMLParseStructure, XMLReader, "Area", NodeText);
					Continue;
				EndIf;
				
				If NOT TableCellWidth = 0 Then
					
					HeightToWidthRatio = PictureParameters.Height / PictureParameters.Width;
					
					PictureWidth = TableCellWidth * 914400 / MainDisplayResolution / 20;
					PictureHeight = HeightToWidthRatio * TableCellWidth * 914400 / MainDisplayResolution / 20;
					
				Else
					
					ScaleRatio = 2;
					ProportionsRatio = 914400 / (MainDisplayResolution * ScaleRatio);
					
					PictureWidth = ProportionsRatio * PictureParameters.Width;
					PictureHeight = ProportionsRatio * PictureParameters.Height;
					
				EndIf;
				
				PictureWidth = Round(PictureWidth, 0);
				PictureHeight = Round(PictureHeight, 0);
				
				StructurePicture.Insert("PictureExtension", StrReplace(PictureParameters.ImageType, "image/", ""));
				StructurePicture.Insert("PictureWidth",     PictureWidth);
				StructurePicture.Insert("PictureHeight",     PictureHeight);
				
				
				IncludePictureToDocumentLibrary(PrintForm.DocumentStructure, StructurePicture);
				PictureXMLTemplate = GetPictureTemplate();
				PreparePictureTemplate(PictureXMLTemplate, StructurePicture);
				IncludePictureTextToDocument(XMLParseStructure.WriteStreams.Area.Stream, StructurePicture);
				
			EndIf
			
		Else
			WriteXMLItemToStream(XMLParseStructure, XMLReader, PrintForm.DocumentStructure);
		EndIf;
		
	EndDo;
	
	Area.Text = CompleteWriteToStream(XMLParseStructure, "Area");
	
EndProcedure

Procedure SelectParameters(ParametersArray, Val Text)

	ParameterStart = StrFind(Text, "{v8 ");
	
	If ParameterStart > 0 Then
		
		Text = Right(Text, StrLen(Text) - (ParameterStart+3));
		ParameterEnd = StrFind(Text, "}");
		If ParameterEnd > 0 Then
			ParameterText = Left(Text, ParameterEnd-1);
			ParametersArray.Add(ParameterText);
			Text = Right(Text, StrLen(Text) - (StrLen(ParameterText) + 1));
		EndIf;
		
		ParameterStart = StrFind(Text, "{v8 ");
		If ParameterStart > 0 Then
			SelectParameters(ParametersArray, Text);
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure SetFieldWidth(XMLReader, Width, Val TableWidth = 0)
	
	DXAType = False;
	PCTType = False;
	
	Width    = XMLReader.GetAttribute("w:w");
	WidthType = XMLReader.GetAttribute("w:type");
	
	If WidthType = "auto" Then
		DXAType = False;
	ElsIf WidthType = "dxa" Then
		DXAType = True;
	ElsIf WidthType = "pct" Then
		PCTType = True;
	EndIf;
	
	If NOT DXAType OR (PCTType AND TableWidth = 0) Then
		Width = 0;
	ElsIf PCTType AND NOT TableWidth = 0 Then
		
		// 5,000 is a value equal to 100% for the pct type.
		// ParentField - in dxa values.
		
		Width = TableWidth * Width / 50 / 100;
		
	EndIf;
	
EndProcedure

Function GetPictureTemplate()
	
	PictureXMLTemplate =
	"<w:drawing>
	|	<wp:inline distT=""0"" distB=""0"" distL=""0"" distR=""0"">
	|		<wp:extent cx=""%6"" cy=""%7""/>
	|		<wp:effectExtent l=""0"" t=""0"" r=""0"" b=""0""/>
	|		<wp:docPr id=""%1"" name=""%2""/>
	|		<wp:cNvGraphicFramePr>
	|			<a:graphicFrameLocks xmlns:a=""http://schemas.openxmlformats.org/drawingml/2006/main"" noChangeAspect=""1""/>
	|		</wp:cNvGraphicFramePr>
	|		<a:graphic xmlns:a=""http://schemas.openxmlformats.org/drawingml/2006/main"">
	|			<a:graphicData uri=""http://schemas.openxmlformats.org/drawingml/2006/picture"">
	|				<pic:pic xmlns:pic=""http://schemas.openxmlformats.org/drawingml/2006/picture"">
	|					<pic:nvPicPr>
	|						<pic:cNvPr id=""%1"" name=""%2"" descr=""%3""/>
	|						<pic:cNvPicPr>
	|							<a:picLocks noChangeAspect=""1"" noChangeArrowheads=""1""/>
	|						</pic:cNvPicPr>
	|					</pic:nvPicPr>
	|					<pic:blipFill>
	|						<a:blip r:embed=""%4"">
	|							<a:extLst>
	|								<a:ext uri=""%5"">
	|									<a14:useLocalDpi xmlns:a14=""http://schemas.microsoft.com/office/drawing/2010/main"" val=""0""/>
	|								</a:ext>
	|							</a:extLst>
	|						</a:blip>
	|						<a:srcRect/>
	|						<a:stretch>
	|							<a:fillRect/>
	|						</a:stretch>
	|					</pic:blipFill>
	|					<pic:spPr bwMode=""auto"">
	|						<a:xfrm>
	|							<a:off x=""0"" y=""0""/>
	|							<a:ext cx=""%6"" cy=""%7""/>
	|						</a:xfrm>
	|						<a:prstGeom prst=""rect"">
	|							<a:avLst/>
	|						</a:prstGeom>
	|						<a:noFill/>
	|						<a:ln>
	|							<a:noFill/>
	|						</a:ln>
	|					</pic:spPr>
	|				</pic:pic>
	|			</a:graphicData>
	|		</a:graphic>
	|	</wp:inline>
	|</w:drawing>";
	
	Return PictureXMLTemplate;
	
EndFunction

Procedure PreparePictureTemplate(PictureTemplate, StructurePicture)
	
	// Parameters to insert
	// 1 - id
	// 2 - name
	// 3 - descr
	// 4 - rId
	// 5 - uri
	// 6 - cx
	// 7 - cy
	ProcessedPictureTemplate = StringFunctionsClientServer.SubstituteParametersToString(PictureTemplate, 
		"0",
		StructurePicture.IconName,
		StructurePicture.IconName,
		StructurePicture.rId,
		"{28A0092B-C50C-407E-A947-70E740481C1C}", 
		Format(StructurePicture.PictureWidth, "NG=0"),
		Format(StructurePicture.PictureHeight, "NG=0"));
										   
	StructurePicture.Insert("PictureText", ProcessedPictureTemplate);
	
EndProcedure

Procedure IncludePictureToDocumentLibrary(DocumentStructure, StructurePicture)
	
	MediaDirectory = New File(StructurePicture.PicturesDirectory);
	TypeImage = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/image";
	
	If NOT MediaDirectory.Exist() Then
		CreateDirectory(StructurePicture.PicturesDirectory);
	EndIf;
	
	// Adding a row to the rels file
	XMLReader = InitializeXMLReader(DocumentStructure.ContentRelations);
	XMLWriter = InitializeXMLRecord("");
	
	DocumentStructure.ContentLinksTable.Sort("ResourceNumber Asc");
	MaxResourceNumber = DocumentStructure.ContentLinksTable[DocumentStructure.ContentLinksTable.Count() - 1].ResourceNumber;
	
	While XMLReader.Read() Do
		
		If XMLReader.NodeType = XMLNodeType.EndElement AND XMLReader.Name = "Relationships" Then
			
			ResourceNumber = MaxResourceNumber + 1;
			ResourceID    = "rId" + Format(MaxResourceNumber + 1, "NG=0");
			PictureName  = StructurePicture.IconName + ResourceID;
			ResourceName   = "media/" + PictureName + "." + StructurePicture.PictureExtension;
			
			AddRowToContentLinksTable(DocumentStructure, ResourceName, ResourceID, ResourceNumber);
			
			StructurePicture.Insert("rId", ResourceID);
			StructurePicture.IconName = PictureName;
			
			XMLWriter.WriteStartElement("Relationship");
			XMLWriter.WriteAttribute("Target", ResourceName);
			XMLWriter.WriteAttribute("Type",   TypeImage);
			XMLWriter.WriteAttribute("Id",     ResourceID);
			XMLWriter.WriteEndElement();
			
			WriteXMLItem(XMLReader, XMLWriter);
			
			AddPictureExtensionToContentTypes(DocumentStructure, StructurePicture);
			
		Else
			WriteXMLItem(XMLReader, XMLWriter);
		EndIf;
		
	EndDo;
	
	XMLReader.Close();
	DocumentStructure.ContentRelations = XMLWriter.Close();
	
	// Writing a picture to the media directory
	BinaryData = StructurePicture.BinaryData;
	BinaryData.Write(StructurePicture.PicturesDirectory + StructurePicture.IconName + "." + StructurePicture.PictureExtension);
	
EndProcedure

Procedure IncludePictureTextToDocument(XMLWriter, StructurePicture)
	
	XMLWriter.WriteEndElement(); // Closing a text tag of the w:t parameter.
	XMLWriter.WriteRaw(StructurePicture.PictureText);
	XMLWriter.WriteStartElement("w:t");
	
EndProcedure

Procedure AddPictureExtensionToContentTypes(DocumentStructure, StructurePicture)
	
	AddedExtensions = DocumentStructure.PicturesExtensions;
	PictureExtension    = StructurePicture.PictureExtension; 
	
	If NOT AddedExtensions.Find(PictureExtension) = Undefined Then
		Return;
	EndIf;
	
	XMLReader = InitializeXMLReader(DocumentStructure.ContentTypes);
	
	XMLWriter = InitializeXMLRecord("");
	
	HasExtension = False;
	
	While XMLReader.Read() Do
		
		If XMLReader.NodeType = XMLNodeType.StartElement AND XMLReader.Name = "Default" Then
			
			ExtensionValue = XMLReader.AttributeValue("Extension");
			
			If ExtensionValue = PictureExtension Then
				HasExtension = True;
			EndIf;
			
			WriteXMLItem(XMLReader, XMLWriter);
			
		ElsIf XMLReader.NodeType = XMLNodeType.EndElement AND XMLReader.Name = "Types" Then
			
			If NOT HasExtension Then
			
				XMLWriter.WriteStartElement("Default");
				XMLWriter.WriteAttribute("ContentType", "image/" + PictureExtension);
				XMLWriter.WriteAttribute("Extension", PictureExtension);
				XMLWriter.WriteEndElement();
				
				AddedExtensions.Add(PictureExtension);
			
			EndIf;
			
			WriteXMLItem(XMLReader, XMLWriter);
			
		Else
			
			WriteXMLItem(XMLReader, XMLWriter);
			
		EndIf;
		
	EndDo;
	
	XMLReader.Close();
	DocumentStructure.ContentTypes = XMLWriter.Close();
	
EndProcedure

#Region SimpleOperationsWithXMLData

Function InitializeXMLRecord(RootTag, PathToFile = "", Encoding = "UTF-8", WriteDeclaration = True)
	
	XMLWriter = New XMLWriter;
	If IsBlankString(PathToFile) Then
		XMLWriter.SetString(Encoding);
	Else
		XMLWriter.OpenFile(PathToFile, Encoding)
	EndIf;
	
	If WriteDeclaration Then
		XMLWriter.WriteRaw("<?xml version=""1.0"" encoding=""UTF-8"" standalone=""yes""?>");
	EndIf;
	
	If Not IsBlankString(RootTag) Then
		XMLWriter.WriteStartElement(RootTag);
	EndIf;
	
	Return XMLWriter;
	
EndFunction

Function InitializeXMLReader(ReadingData, DataType = 0)
	
	XMLReader = New XMLReader;
	If DataType = 0 Then
		XMLReader.SetString(ReadingData)
	Else
		XMLReader.OpenFile(ReadingData);
	EndIf;
	
	XMLReader.IgnoreWhitespace = FALSE;
	
	Return XMLReader;
	
EndFunction

Procedure WriteXMLItem(XMLReader, XMLWriter, Text = Undefined)
	
	If XMLReader.NodeType = XMLNodeType.ProcessingInstruction Then
		
		XMLWriter.WriteProcessingInstruction(XMLReader.Name, XMLReader.Value);
		
	ElsIf XMLReader.NodeType = XMLNodeType.StartElement Then
		
		XMLWriter.WriteStartElement(XMLReader.Name);
		
		While XMLReader.ReadAttribute() Do
			
			XMLWriter.WriteStartAttribute(XMLReader.Name);
			XMLWriter.WriteText(XMLReader.Value);
			XMLWriter.WriteEndAttribute();
			
		EndDo;
		
	ElsIf XMLReader.NodeType = XMLNodeType.EndElement Then
		
		XMLWriter.WriteEndElement();
		
	ElsIf XMLReader.NodeType = XMLNodeType.Text Then
		
		If Text = Undefined Then
			XMLWriter.WriteText(XMLReader.Value);
		Else
			XMLWriter.WriteText(Text);
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ParseXMLDocumentToAreas

Procedure InitializeWriteToStream(XMLParseStructure, StreamName, RootTag = "w:next", WriteDeclaration = True)
	
	If Not IsBlankString(XMLParseStructure.LockingStream) AND NOT XMLParseStructure.LockingStream = StreamName Then
		Return;
	EndIf;
	
	If NOT XMLParseStructure.WriteStreams.Property(StreamName) Then
		XMLParseStructure.WriteStreams.Insert(StreamName, New Structure("Stream, WritingAllowed, Level, ThreadTerminated, StreamText"));
	EndIf;
	
	If NOT XMLParseStructure.WriteStreams[StreamName].WritingAllowed = Undefined Then
		ContinueWriteToStream(XMLParseStructure, StreamName);
		Return;
	EndIf;
	
	XMLParseStructure.WriteStreams[StreamName].WritingAllowed  = True;
	XMLParseStructure.WriteStreams[StreamName].Stream            = InitializeXMLRecord(RootTag, , , WriteDeclaration);
	XMLParseStructure.WriteStreams[StreamName].Level          = ?(IsBlankString(RootTag), 0, 1);
	XMLParseStructure.WriteStreams[StreamName].ThreadTerminated      = False;
	XMLParseStructure.WriteStreams[StreamName].StreamText      = "";
	
EndProcedure

Procedure StopWriteToStream(XMLParseStructure, StreamName)
	
	If Not IsBlankString(XMLParseStructure.LockingStream) AND NOT XMLParseStructure.LockingStream = StreamName Then
		Return;
	EndIf;
	
	If NOT XMLParseStructure.WriteStreams.Property(StreamName) Then
		Return;
	EndIf;
	
	If XMLParseStructure.WriteStreams[StreamName].WritingAllowed = Undefined Then
		Return;
	EndIf;
	
	XMLParseStructure.WriteStreams[StreamName].WritingAllowed = False;
	
EndProcedure

Procedure ContinueWriteToStream(XMLParseStructure, StreamName)
	
	If Not IsBlankString(XMLParseStructure.LockingStream) AND NOT XMLParseStructure.LockingStream = StreamName Then
		Return;
	EndIf;
	
	If NOT XMLParseStructure.WriteStreams.Property(StreamName) Then
		Return;
	EndIf;
	
	If XMLParseStructure.WriteStreams[StreamName].WritingAllowed = Undefined Then
		Return;
	EndIf;
	
	XMLParseStructure.WriteStreams[StreamName].WritingAllowed = True;
	
EndProcedure

Procedure ResetWriteToStream(XMLParseStructure, StreamName)
	
	If Not IsBlankString(XMLParseStructure.LockingStream) AND NOT XMLParseStructure.LockingStream = StreamName Then
		Return;
	EndIf;
	
	If NOT XMLParseStructure.WriteStreams.Property(StreamName) Then
		Return;
	EndIf;
	
	XMLParseStructure.WriteStreams[StreamName].WritingAllowed = Undefined;
	
EndProcedure

Function CompleteWriteToStream(XMLParseStructure, StreamName)
	
	If Not IsBlankString(XMLParseStructure.LockingStream) AND NOT XMLParseStructure.LockingStream = StreamName Then
		Return "";
	EndIf;
	
	If NOT XMLParseStructure.WriteStreams.Property(StreamName) Then
		Return "";
	EndIf;
	
	If XMLParseStructure.WriteStreams[StreamName].ThreadTerminated = True Then
		Return "";
	EndIf;
	
	While XMLParseStructure.WriteStreams[StreamName].Level > 0 Do
		XMLParseStructure.WriteStreams[StreamName].Stream.WriteEndElement();
		XMLParseStructure.WriteStreams[StreamName].Level = XMLParseStructure.WriteStreams[StreamName].Level - 1;
	EndDo;
	
	XMLParseStructure.WriteStreams[StreamName].StreamText = XMLParseStructure.WriteStreams[StreamName].Stream.Close();
	XMLParseStructure.WriteStreams[StreamName].WritingAllowed = Undefined;
	XMLParseStructure.WriteStreams[StreamName].ThreadTerminated = True;
	
	Return XMLParseStructure.WriteStreams[StreamName].StreamText;
	
EndFunction

Procedure TransferWriteToStream(XMLParseStructure, SourceStreamName, RecipientStreamName)
	
	If Not IsBlankString(XMLParseStructure.LockingStream) AND NOT XMLParseStructure.LockingStream = RecipientStreamName Then
		Return;
	EndIf;
	
	If NOT XMLParseStructure.WriteStreams.Property(SourceStreamName)
		 OR NOT XMLParseStructure.WriteStreams.Property(RecipientStreamName) Then
		Return;
	EndIf;
	
	CompleteWriteToStream(XMLParseStructure, SourceStreamName);
	
	StreamText = XMLParseStructure.WriteStreams[SourceStreamName].StreamText;
	StreamText = StrReplace(StreamText, "<w:next>", "<w:next " + XMLParseStructure.XMLAttributes + ">");
	
	XMLReader = InitializeXMLReader(StreamText);
	
	While XMLReader.Read() Do
		
		If XMLReader.Name = "w:next" Then
			Continue;
		EndIf;
		
		WriteXMLItem(XMLReader, XMLParseStructure.WriteStreams[RecipientStreamName].Stream);
		
	EndDo;
	
	XMLReader.Close();
	
EndProcedure

Procedure TransferOpeningTagsOfWriteToStream(XMLParseStructure, SourceStreamName, RecipientStreamName, StopTag)
	
	If Not IsBlankString(XMLParseStructure.LockingStream) AND NOT XMLParseStructure.LockingStream = RecipientStreamName Then
		Return;
	EndIf;
	
	If NOT XMLParseStructure.WriteStreams.Property(SourceStreamName)
		 OR NOT XMLParseStructure.WriteStreams.Property(RecipientStreamName) Then
		Return;
	EndIf;
	
	If NOT XMLParseStructure.WriteStreams[SourceStreamName].ThreadTerminated Then
		XMLParseStructure.WriteStreams[SourceStreamName].WritingAllowed = False;
		XMLParseStructure.WriteStreams[SourceStreamName].Stream.WriteEndElement();
		XMLParseStructure.WriteStreams[SourceStreamName].StreamText = XMLParseStructure.WriteStreams[SourceStreamName].Stream.Close();
		XMLParseStructure.WriteStreams[SourceStreamName].ThreadTerminated = True;
	EndIf;
	
	StreamText = XMLParseStructure.WriteStreams[SourceStreamName].StreamText;
	StreamText = StrReplace(StreamText, "<w:next>", "<w:next " + XMLParseStructure.XMLAttributes + ">");
	
	XMLReader = InitializeXMLReader(StreamText);
	
	While XMLReader.Read() Do
		
		If XMLReader.Name = "w:next" Then
			Continue;
		EndIf;
		
		If XMLReader.NodeType = XMLNodeType.Text Then
			Continue;
		EndIf;
		
		If XMLReader.NodeType = XMLNodeType.EndElement AND XMLReader.Name = StopTag Then
			Break;
		EndIf;
		
		If XMLReader.NodeType = XMLNodeType.StartElement Then
			XMLParseStructure.WriteStreams[RecipientStreamName].Level = XMLParseStructure.WriteStreams[RecipientStreamName].Level + 1;
		EndIf;
		
		If XMLReader.NodeType = XMLNodeType.EndElement Then
			XMLParseStructure.WriteStreams[RecipientStreamName].Level = XMLParseStructure.WriteStreams[RecipientStreamName].Level - 1;
		EndIf;
		
		WriteXMLItem(XMLReader, XMLParseStructure.WriteStreams[RecipientStreamName].Stream);
		
	EndDo;
	
	XMLReader.Close();
	
EndProcedure

Procedure AddAttributeToStream(XMLParseStructure, StreamName, AttributeName, AttributeValue)
	
	If Not IsBlankString(XMLParseStructure.LockingStream) AND NOT XMLParseStructure.LockingStream = StreamName Then
		Return;
	EndIf;
	
	If NOT XMLParseStructure.WriteStreams.Property(StreamName) Then
		Return;
	EndIf;
	
	If XMLParseStructure.WriteStreams[StreamName].ThreadTerminated = True Then
		Return;
	EndIf;
	
	XMLParseStructure.WriteStreams[StreamName].Stream.WriteStartAttribute(AttributeName);
	XMLParseStructure.WriteStreams[StreamName].Stream.WriteText(AttributeValue);
	XMLParseStructure.WriteStreams[StreamName].Stream.WriteEndAttribute();
	
EndProcedure

Procedure AddTextToStream(XMLParseStructure, StreamName, Text)
	
	If Not IsBlankString(XMLParseStructure.LockingStream) AND NOT XMLParseStructure.LockingStream = StreamName Then
		Return;
	EndIf;
	
	If NOT XMLParseStructure.WriteStreams.Property(StreamName) Then
		Return;
	EndIf;
	
	If XMLParseStructure.WriteStreams[StreamName].ThreadTerminated = True Then
		Return;
	EndIf;
	
	XMLParseStructure.WriteStreams[StreamName].Stream.WriteText(Text);
	
EndProcedure

Procedure CloseItemsInStream(XMLParseStructure, StreamName, ItemsCount)
	
	If Not IsBlankString(XMLParseStructure.LockingStream) AND NOT XMLParseStructure.LockingStream = StreamName Then
		Return;
	EndIf;
	
	If NOT XMLParseStructure.WriteStreams.Property(StreamName) Then
		Return;
	EndIf;
	
	If XMLParseStructure.WriteStreams[StreamName].ThreadTerminated = True Then
		Return;
	EndIf;
	
	For Index = 1 To ItemsCount Do
		XMLParseStructure.WriteStreams[StreamName].Stream.WriteEndElement();
		XMLParseStructure.WriteStreams[StreamName].Level = XMLParseStructure.WriteStreams.ParamStrings.Level - 1;
	EndDo;
	
EndProcedure

Function StreamActive(XMLParseStructure, StreamName)
	
	If NOT XMLParseStructure.WriteStreams.Property(StreamName) Then
		Return False;
	EndIf;
	
	If XMLParseStructure.WriteStreams[StreamName].WritingAllowed = Undefined Then
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

Procedure WriteProcessingInstructionToStreams(XMLParseStructure, XMLReader, StreamName = "")
	
	For Each StreamItem In XMLParseStructure.WriteStreams Do
		
		If Not IsBlankString(XMLParseStructure.LockingStream) AND NOT StreamItem.Key = XMLParseStructure.LockingStream Then
			Continue;
		EndIf;
		
		If NOT IsBlankString(StreamName) AND NOT StreamItem.Key = StreamName Then
			Continue;
		EndIf;
		
		If NOT StreamItem.Value.WritingAllowed = True Then
			Continue;
		EndIf;
		
		StreamItem.Value.Stream.WriteProcessingInstruction(XMLReader.Name, XMLReader.Value);
		
	EndDo;
	
EndProcedure

Procedure WriteStreamStartToStreams(XMLParseStructure, XMLReader, StreamName = "")
	
	For Each StreamItem In XMLParseStructure.WriteStreams Do
		
		If Not IsBlankString(XMLParseStructure.LockingStream) AND NOT StreamItem.Key = XMLParseStructure.LockingStream Then
			Continue;
		EndIf;
		
		If NOT IsBlankString(StreamName) AND NOT StreamItem.Key = StreamName Then
			Continue;
		EndIf;
		
		If NOT StreamItem.Value.WritingAllowed = True Then
			Continue;
		EndIf;
		
		StreamItem.Value.Stream.WriteStartElement(XMLReader.Name);
		StreamItem.Value.Level = StreamItem.Value.Level + 1;
		
	EndDo;
	
EndProcedure

Procedure WriteAttributeToStreams(XMLParseStructure, XMLReader, StreamName = "", Val Text = Undefined)
	
	For Each StreamItem In XMLParseStructure.WriteStreams Do
		
		If Not IsBlankString(XMLParseStructure.LockingStream) AND NOT StreamItem.Key = XMLParseStructure.LockingStream Then
			Continue;
		EndIf;
		
		If NOT IsBlankString(StreamName) AND NOT StreamItem.Key = StreamName Then
			Continue;
		EndIf;
		
		If NOT StreamItem.Value.WritingAllowed = True Then
			Continue;
		EndIf;
		
		If Text = Undefined Then
			Text = XMLReader.Value;
		EndIf;
		
		StreamItem.Value.Stream.WriteStartAttribute(XMLReader.Name);
		StreamItem.Value.Stream.WriteText(Text);
		StreamItem.Value.Stream.WriteEndAttribute();
		
	EndDo;
	
EndProcedure

Procedure WriteItemEndToStreams(XMLParseStructure, XMLReader, StreamName = "")
	
	For Each StreamItem In XMLParseStructure.WriteStreams Do
		
		If Not IsBlankString(XMLParseStructure.LockingStream) AND NOT StreamItem.Key = XMLParseStructure.LockingStream Then
			Continue;
		EndIf;
		
		If NOT IsBlankString(StreamName) AND NOT StreamItem.Key = StreamName Then
			Continue;
		EndIf;
		
		If NOT StreamItem.Value.WritingAllowed = True Then
			Continue;
		EndIf;
		
		StreamItem.Value.Stream.WriteEndElement();
		StreamItem.Value.Level = StreamItem.Value.Level - 1;
		
	EndDo;
	
EndProcedure

Procedure WriteTextToStreams(XMLParseStructure, XMLReader, StreamName = "", Val Text = Undefined)
	
	For Each StreamItem In XMLParseStructure.WriteStreams Do
		
		If Not IsBlankString(XMLParseStructure.LockingStream) AND NOT StreamItem.Key = XMLParseStructure.LockingStream Then
			Continue;
		EndIf;
		
		If NOT IsBlankString(StreamName) AND NOT StreamItem.Key = StreamName Then
			Continue;
		EndIf;
		
		If NOT StreamItem.Value.WritingAllowed = True Then
			Continue;
		EndIf;
		
		If Text = Undefined Then
			Text = XMLReader.Value;
		EndIf;
		
		StringsCount = ?(IsBlankString(Text), 1, StrLineCount(Text));
		
		If StringsCount > 1 Then
			
			For Ind = 1 To StringsCount Do
				
				TextString = StrGetLine(Text, Ind);
				StreamItem.Value.Stream.WriteText(TextString);
				
				If Ind < StringsCount Then
					StreamItem.Value.Stream.WriteEndElement();
					StreamItem.Value.Stream.WriteStartElement("w:br");
					StreamItem.Value.Stream.WriteEndElement();
					StreamItem.Value.Stream.WriteStartElement("w:t");
				EndIf;
				
			EndDo;
			
		Else
			StreamItem.Value.Stream.WriteText(Text);
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure WriteXMLItemToStream(XMLParseStructure, XMLReader, DocumentStructure)
	
	If XMLReader.NodeType = XMLNodeType.ProcessingInstruction Then
		
		WriteProcessingInstructionToStreams(XMLParseStructure, XMLReader);
		
	ElsIf XMLReader.NodeType = XMLNodeType.StartElement Then
		
		NodeName = XMLReader.Name;
		
		WriteStreamStartToStreams(XMLParseStructure, XMLReader);
		
		While XMLReader.ReadAttribute() Do
			
			If IsBlankString(DocumentStructure.DocumentID) AND (Left(XMLReader.Name, 6) = "w:rsid") Then
				DocumentStructure.DocumentID = XMLReader.Value;
			EndIf;
			
			AttributeValue = XMLReader.Value;
			
			If Left(XMLReader.Name, 6) = "w:rsid" Then
				AttributeValue = DocumentStructure.DocumentID;
			EndIf;
			
			WriteAttributeToStreams(XMLParseStructure, XMLReader,, AttributeValue);
			
			If NodeName = "w:document" OR NodeName = "w:ftr" OR NodeName = "w:hdr" Then
				XMLParseStructure.XMLAttributes = XMLParseStructure.XMLAttributes + " " + XMLReader.Name + "=""" + XMLReader.Value + """";
			EndIf;
			
		EndDo;
		
	ElsIf XMLReader.NodeType = XMLNodeType.EndElement Then
		
		WriteItemEndToStreams(XMLParseStructure, XMLReader);
		
	ElsIf XMLReader.NodeType = XMLNodeType.Text Then
		
		If XMLParseStructure.Property("OneCTagStatus") Then
			AnalyzeParametersInString(XMLReader.Value, XMLParseStructure);
		EndIf;
		
		WriteTextToStreams(XMLParseStructure, XMLReader);
		
	EndIf;
	
EndProcedure

Function ReadAnyBlockStartExceptForParagraph(XMLParseStructure, XMLReader)
	
	If Not IsBlankString(XMLParseStructure.LockingStream) Then
		Return False;
	EndIf;
	
	Return XMLReader.NodeType = XMLNodeType.StartElement AND NOT XMLReader.Name = "w:p";
	
EndFunction

Function ReadAnyBlockEndButParagraph(XMLParseStructure, XMLReader)
	
	If Not IsBlankString(XMLParseStructure.LockingStream) Then
		Return False;
	EndIf;
	
	Return XMLReader.NodeType = XMLNodeType.EndElement AND NOT XMLReader.Name = "w:p";
	
EndFunction

Function ReadDocumentBodyStart(XMLParseStructure, XMLReader)
	
	If Not IsBlankString(XMLParseStructure.LockingStream) Then
		Return False;
	EndIf;
	
	Return XMLReader.NodeType = XMLNodeType.StartElement AND XMLReader.Name = "w:body";
	
EndFunction

Function ReadHeaderOrFooterBodyStart(XMLParseStructure, XMLReader)
	
	If Not IsBlankString(XMLParseStructure.LockingStream) Then
		Return False;
	EndIf;
	
	Return XMLReader.NodeType = XMLNodeType.StartElement AND (XMLReader.Name = "w:ftr" OR XMLReader.Name = "w:hdr");
	
EndFunction

Function ReadParagraphStart(XMLParseStructure, XMLReader)
	
	If Not IsBlankString(XMLParseStructure.LockingStream) Then
		Return False;
	EndIf;
	
	Return XMLReader.NodeType = XMLNodeType.StartElement AND XMLReader.Name = "w:p";
	
EndFunction

Function ReadParagraphEnd(XMLParseStructure, XMLReader)
	
	If Not IsBlankString(XMLParseStructure.LockingStream) Then
		Return False;
	EndIf;
	
	Return XMLReader.NodeType = XMLNodeType.EndElement AND XMLReader.Name = "w:p";
	
EndFunction

Function ReadStringStart(XMLParseStructure, XMLReader)
	
	If Not IsBlankString(XMLParseStructure.LockingStream) Then
		Return False;
	EndIf;
	
	Return XMLReader.NodeType = XMLNodeType.StartElement AND XMLReader.Name = "w:r";
	
EndFunction

Function ReadStringEnd(XMLParseStructure, XMLReader)
	
	If Not IsBlankString(XMLParseStructure.LockingStream) Then
		Return False;
	EndIf;
	
	Return XMLReader.NodeType = XMLNodeType.EndElement AND XMLReader.Name = "w:r";
	
EndFunction

Function ReadStringTextStart(XMLParseStructure, XMLReader)
	
	If Not IsBlankString(XMLParseStructure.LockingStream) Then
		Return False;
	EndIf;
	
	Return XMLReader.NodeType = XMLNodeType.StartElement AND XMLReader.Name = "w:t";
	
EndFunction

Function ReadStringTextEnd(XMLParseStructure, XMLReader)
	
	If Not IsBlankString(XMLParseStructure.LockingStream) Then
		Return False;
	EndIf;
	
	Return XMLReader.NodeType = XMLNodeType.EndElement AND XMLReader.Name = "w:t";
	
EndFunction

Function ReadTableStart(XMLParseStructure, XMLReader)
	
	If Not IsBlankString(XMLParseStructure.LockingStream) Then
		Return False;
	EndIf;
	
	Return XMLReader.NodeType = XMLNodeType.StartElement AND XMLReader.Name = "w:tbl";
	
EndFunction

Function ReadTableEnd(XMLParseStructure, XMLReader)
	
	If Not IsBlankString(XMLParseStructure.LockingStream) Then
		Return False;
	EndIf;
	
	Return XMLReader.NodeType = XMLNodeType.EndElement AND XMLReader.Name = "w:tbl";
	
EndFunction

Function ReadTableWidthStart(XMLParseStructure, XMLReader)
	
	If Not IsBlankString(XMLParseStructure.LockingStream) Then
		Return False;
	EndIf;
	
	Return XMLReader.NodeType = XMLNodeType.StartElement AND XMLReader.Name = "w:tblW";
	
EndFunction

Function ReadTableCellWidthStart(XMLParseStructure, XMLReader)
	
	If Not IsBlankString(XMLParseStructure.LockingStream) Then
		Return False;
	EndIf;
	
	Return XMLReader.NodeType = XMLNodeType.StartElement AND XMLReader.Name = "w:tcW";
	
EndFunction

Function ReadTableCellStart(XMLParseStructure, XMLReader)
	
	If Not IsBlankString(XMLParseStructure.LockingStream) Then
		Return False;
	EndIf;
	
	Return XMLReader.NodeType = XMLNodeType.StartElement AND XMLReader.Name = "w:tc";
	
EndFunction

Function ReadTableCellEnd(XMLParseStructure, XMLReader)
	
	If Not IsBlankString(XMLParseStructure.LockingStream) Then
		Return False;
	EndIf;
	
	Return XMLReader.NodeType = XMLNodeType.EndElement AND XMLReader.Name = "w:tc";
	
EndFunction

Function ReadSectionStart(XMLParseStructure, XMLReader)
	
	If Not IsBlankString(XMLParseStructure.LockingStream) AND NOT XMLParseStructure.LockingStream = "Section" Then
		Return False;
	EndIf;
	
	Return XMLReader.NodeType = XMLNodeType.StartElement AND XMLReader.Name = "w:sectPr";
	
EndFunction

Function ReadSectionEnd(XMLParseStructure, XMLReader)
	
	If Not IsBlankString(XMLParseStructure.LockingStream) AND NOT XMLParseStructure.LockingStream = "Section" Then
		Return False;
	EndIf;
	
	Return XMLReader.NodeType = XMLNodeType.EndElement AND XMLReader.Name = "w:sectPr";
	
EndFunction

Function InitializeMXLParsing()
	
	Result = New Structure;
	Result.Insert("WriteStreams",      New Structure);
	Result.Insert("XMLAttributes",       "");
	Result.Insert("AreaName",        "");
	Result.Insert("AreaStatus",     0);
	Result.Insert("SectionName",      1);
	Result.Insert("LockingStream",  "");
	Result.Insert("ParsedStrings", New Array);
	Result.Insert("FormatStreamName",  "");
	
	Return Result;
	
EndFunction

Function HeadersFootersTypes()
	
	Result = New Map;
	Result.Insert("w:headerReference_even",    "EvenHeader");
	Result.Insert("w:footerReference_even",    "EvenFooter");
	Result.Insert("w:headerReference_first",   "FirstHeader");
	Result.Insert("w:footerReference_first",   "FirstFooter");
	Result.Insert("w:headerReference_default", "Header");
	Result.Insert("w:footerReference_default", "Footer");
	
	Return Result;
	
EndFunction

Procedure Reset1CTagsStatuses(XMLParseStructure, ResetTemplateStringStreams = False)
	
	XMLParseStructure.Insert("OneCTagStatus",     0);
	XMLParseStructure.Insert("OneCTagType",        0);
	XMLParseStructure.Insert("OneCTagName",        "");
	XMLParseStructure.Insert("FullOneCTagName",  "");
	XMLParseStructure.Insert("TextBefore1CTag",    "");
	XMLParseStructure.Insert("TextAfter1CTag", "");
	
	If ResetTemplateStringStreams Then
		ResetTemplateStringStreams(XMLParseStructure)
	EndIf;
	
EndProcedure

Procedure AddParsedString(XMLParseStructure, Row, OneCTagStatus = 0, AreaName = "", FormatStream = "")
	
	StringStructure = New Structure;
	StringStructure.Insert("OneCTagStatus", OneCTagStatus);
	StringStructure.Insert("AreaName",   AreaName);
	StringStructure.Insert("Text",        Row);
	StringStructure.Insert("FormatStream", FormatStream);
	
	XMLParseStructure.ParsedStrings.Add(StringStructure);
	
EndProcedure

Procedure GenerateParsedStrings(XMLParseStructure)
	
	If XMLParseStructure.OneCTagStatus = 7 AND XMLParseStructure.OneCTagType = 0
		 OR XMLParseStructure.OneCTagStatus = 3 AND XMLParseStructure.OneCTagType = 1 AND NOT IsBlankString(XMLParseStructure.AreaName)
		 OR XMLParseStructure.OneCTagStatus = 7 AND XMLParseStructure.OneCTagType = 1 AND NOT XMLParseStructure.OneCTagName = XMLParseStructure.AreaName Then
		
		Reset1CTagsStatuses(XMLParseStructure, True);
		Return;
	EndIf;
	
	If NOT XMLParseStructure.TextBefore1CTag = "" Then
		AddParsedString(XMLParseStructure, XMLParseStructure.TextBefore1CTag,,,"TextFormatBefore");
	EndIf;
	
	If NOT XMLParseStructure.FullOneCTagName = "" Then
		AddParsedString(XMLParseStructure, XMLParseStructure.FullOneCTagName, ?(XMLParseStructure.OneCTagType = 1, XMLParseStructure.OneCTagStatus, 0), ?(XMLParseStructure.OneCTagType = 1, XMLParseStructure.OneCTagName, ""),"1CTagFormat");
	EndIf;
	
	If NOT XMLParseStructure.TextAfter1CTag = "" Then
		AddParsedString(XMLParseStructure, XMLParseStructure.TextAfter1CTag,,,"TextFormatAfter");
	EndIf;
	
	Reset1CTagsStatuses(XMLParseStructure);
	
EndProcedure

Procedure ClearParsedStrings(XMLParseStructure)
	
	XMLParseStructure.ParsedStrings.Clear();
	
EndProcedure

Procedure InitializeTemplateStringStreams(XMLParseStructure)
	
	If XMLParseStructure.OneCTagStatus = 1 OR XMLParseStructure.OneCTagStatus = 5 Then
		
		If NOT StreamActive(XMLParseStructure, "TextFormatBefore") Then
			InitializeWriteToStream(XMLParseStructure, "TextFormatBefore");
			TransferWriteToStream(XMLParseStructure, XMLParseStructure.FormatStreamName, "TextFormatBefore");
			StopWriteToStream(XMLParseStructure, "TextFormatBefore");
		EndIf;
		
	EndIf;
	
	If XMLParseStructure.OneCTagStatus = 2 OR XMLParseStructure.OneCTagStatus = 6 Then
		
		If NOT StreamActive(XMLParseStructure, "TextFormatBefore") Then
			InitializeWriteToStream(XMLParseStructure, "TextFormatBefore");
			TransferWriteToStream(XMLParseStructure, XMLParseStructure.FormatStreamName, "TextFormatBefore");
			StopWriteToStream(XMLParseStructure, "TextFormatBefore");
		EndIf;
		
		If NOT StreamActive(XMLParseStructure, "1CTagFormat") Then
			InitializeWriteToStream(XMLParseStructure, "1CTagFormat");
			TransferWriteToStream(XMLParseStructure, XMLParseStructure.FormatStreamName, "1CTagFormat");
			StopWriteToStream(XMLParseStructure, "1CTagFormat");
		EndIf;
		
	EndIf;
	
	If XMLParseStructure.OneCTagStatus = 3 OR XMLParseStructure.OneCTagStatus = 7 Then
		
		If NOT StreamActive(XMLParseStructure, "TextFormatBefore") Then
			InitializeWriteToStream(XMLParseStructure, "TextFormatBefore");
			TransferWriteToStream(XMLParseStructure, XMLParseStructure.FormatStreamName, "TextFormatBefore");
			StopWriteToStream(XMLParseStructure, "TextFormatBefore");
		EndIf;
		
		If NOT StreamActive(XMLParseStructure, "1CTagFormat") Then
			InitializeWriteToStream(XMLParseStructure, "1CTagFormat");
			TransferWriteToStream(XMLParseStructure, XMLParseStructure.FormatStreamName, "1CTagFormat");
			StopWriteToStream(XMLParseStructure, "1CTagFormat");
		EndIf;
		
		If NOT StreamActive(XMLParseStructure, "TextFormatAfter") Then
			InitializeWriteToStream(XMLParseStructure, "TextFormatAfter");
			TransferWriteToStream(XMLParseStructure, XMLParseStructure.FormatStreamName, "TextFormatAfter");
			StopWriteToStream(XMLParseStructure, "TextFormatAfter");
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure ResetTemplateStringStreams(XMLParseStructure)
	
	ResetWriteToStream(XMLParseStructure, "TextFormatBefore");
	ResetWriteToStream(XMLParseStructure, "1CTagFormat");
	ResetWriteToStream(XMLParseStructure, "TextFormatAfter");
	
EndProcedure

Procedure SplitTemplateTextToAreas(XMLReader, DocumentStructure, AnalysisParameters)
	
	TagLevelLock       = -1;
	TagLevelArea    = -1;
	ParagraphLevel         = "0";
	CurrentLevel        = 0;
	SkipTag         = False;
	RemoveLockingStream = False;
	
	XMLParseStructure = InitializeMXLParsing();
	
	Reset1CTagsStatuses(XMLParseStructure);
	
	InitializeWriteToStream(XMLParseStructure, "Title", "");
	
	If AnalysisParameters.AnalysisType <> 1 Then
		InitializeWriteToStream(XMLParseStructure, "Block", "");
		TagLevelLock = 0;
	EndIf;
	
	While XMLReader.Read() Do
		
		// name space description tag in a temporary xml
		If XMLReader.Name = "w:next" Then
			Continue;
		EndIf;
		
		If (XMLReader.Name = "w:bookmarkStart" OR XMLReader.Name = "w:bookmarkEnd") Then
			
			If XMLReader.NodeType = XMLNodeType.StartElement Then
				SkipTag = True;
			ElsIf XMLReader.NodeType = XMLNodeType.EndElement Then
				SkipTag = False;
			EndIf;
			
			Continue;
			
		EndIf;
		
		If SkipTag Then
			Continue;
		EndIf;
		
		If XMLReader.NodeType = XMLNodeType.StartElement Then
			CurrentLevel = CurrentLevel + 1;
		EndIf;
		
		If ReadSectionStart(XMLParseStructure, XMLReader) Then
			XMLParseStructure.LockingStream = "Section";
			InitializeWriteToStream(XMLParseStructure, "Section", "", False);
			TransferOpeningTagsOfWriteToStream(XMLParseStructure, "Title", "Section", "w:body");
		EndIf;
		
		If ReadAnyBlockStartExceptForParagraph(XMLParseStructure, XMLReader) AND CurrentLevel = TagLevelLock Then
			InitializeWriteToStream(XMLParseStructure, "Block");
		EndIf;
		
		If ReadParagraphStart(XMLParseStructure, XMLReader) Then
			
			If Number(ParagraphLevel) > 0 Then
				StopWriteToStream(XMLParseStructure, "Rows" + ParagraphLevel);
				StopWriteToStream(XMLParseStructure, "Paragraph" + ParagraphLevel);
				StopWriteToStream(XMLParseStructure, "ParamString" + ParagraphLevel);
			EndIf;
			
			ParagraphLevel = Format(Number(ParagraphLevel) + 1, "NZ=0; NG=0");
			
			Reset1CTagsStatuses(XMLParseStructure, True);
			InitializeWriteToStream(XMLParseStructure, "Paragraph" + ParagraphLevel);
			InitializeWriteToStream(XMLParseStructure, "Rows" + ParagraphLevel);
			StopWriteToStream(XMLParseStructure, "Rows" + ParagraphLevel);
			StopWriteToStream(XMLParseStructure, "Block");
			
		EndIf;
		
		If ReadParagraphEnd(XMLParseStructure, XMLReader) Then
			ContinueWriteToStream(XMLParseStructure, "Paragraph" + ParagraphLevel);
		EndIf;
		
		If ReadStringStart(XMLParseStructure, XMLReader) Then
			ContinueWriteToStream(XMLParseStructure, "Rows" + ParagraphLevel);
			InitializeWriteToStream(XMLParseStructure, "ParamString" + ParagraphLevel);
			StopWriteToStream(XMLParseStructure, "Paragraph" + ParagraphLevel);
			XMLParseStructure.FormatStreamName = "ParamString" + ParagraphLevel;
		EndIf;
		
		ReadStringTextStart = ReadStringTextStart(XMLParseStructure, XMLReader);
		
		CompleteWriteToTitle = ReadDocumentBodyStart(XMLParseStructure, XMLReader) OR ReadHeaderOrFooterBodyStart(XMLParseStructure, XMLReader);
		
		WriteXMLItemToStream(XMLParseStructure, XMLReader, DocumentStructure);
		
		If ReadStringTextStart Then
			CompleteWriteToStream(XMLParseStructure, "ParamString" + ParagraphLevel);
		EndIf;
		
		If CompleteWriteToTitle Then
			
			TagLevelLock    = XMLParseStructure.WriteStreams.Title.Level + 1;
			TagLevelArea = XMLParseStructure.WriteStreams.Title.Level + 2;
			
			CompleteWriteToStream(XMLParseStructure, "Title");
			
		EndIf;
		
		If ReadStringEnd(XMLParseStructure, XMLReader) Then
			
			If XMLParseStructure.OneCTagStatus = 0 AND XMLParseStructure.ParsedStrings.Count() = 0 Then
				TransferWriteToStream(XMLParseStructure, "Rows" + ParagraphLevel, "Paragraph" + ParagraphLevel);
			ElsIf XMLParseStructure.ParsedStrings.Count() > 0 Then
				
				InitializeWriteToStream(XMLParseStructure, "ParamStrings");
				
				StringsCount = 0;
				
				For Each StringItem In XMLParseStructure.ParsedStrings Do
					
					If AnalysisParameters.AnalysisType = 1 AND CurrentLevel = TagLevelArea AND StringItem.OneCTagStatus = 3 AND IsBlankString(XMLParseStructure.AreaName) Then
						
						XMLParseStructure.AreaName = StringItem.AreaName;
						XMLParseStructure.AreaStatus = 0;
						StringsCount = 0;
						
						InitializeWriteToStream(XMLParseStructure, "Area", "");
						TransferOpeningTagsOfWriteToStream(XMLParseStructure, "Title", "Area", "w:body");
						StopWriteToStream(XMLParseStructure, "Area");
						ResetWriteToStream(XMLParseStructure, "ParamStrings");
						InitializeWriteToStream(XMLParseStructure, "ParamStrings");
						
						Break;
						
					ElsIf AnalysisParameters.AnalysisType = 1 AND CurrentLevel = TagLevelArea AND StringItem.OneCTagStatus = 7 AND XMLParseStructure.AreaName = StringItem.AreaName Then
						
						AreaText = CompleteWriteToStream(XMLParseStructure, "Area");
						
						AreaStructure = DocumentArea();
						AreaStructure.Name          = XMLParseStructure.AreaName;
						AreaStructure.Text        = AreaText;
						AreaStructure.SectionName = XMLParseStructure.SectionName;
						
						AddDocumentAreaToDocumentStructure(DocumentStructure, AreaStructure);
						
						XMLParseStructure.AreaName = "";
						XMLParseStructure.AreaStatus = 0;
						
						Break;
						
					EndIf;
					
					StringsCount = StringsCount + 1;
					
					CompleteWriteToStream(XMLParseStructure, StringItem.FormatStream);
					
					HasSpaceAttribute = StrFind(XMLParseStructure.WriteStreams[StringItem.FormatStream].StreamText, "w:t xml:space", SearchDirection.FromEnd) > 0;
					
					TransferOpeningTagsOfWriteToStream(XMLParseStructure, StringItem.FormatStream, "ParamStrings", "w:t");
					
					If NOT HasSpaceAttribute AND (IsBlankString(Left(StringItem.Text, 1)) OR IsBlankString(Right(StringItem.Text, 1))) Then
						AddAttributeToStream(XMLParseStructure, "ParamStrings", "xml:space", "preserve");
					EndIf;
					AddTextToStream(XMLParseStructure, "ParamStrings", StringItem.Text);
					CloseItemsInStream(XMLParseStructure, "ParamStrings", 2);
					
				EndDo;
				
				If StringsCount > 0 Then
					TransferWriteToStream(XMLParseStructure, "ParamStrings", "Paragraph" + ParagraphLevel);
				EndIf;
				
				ResetWriteToStream(XMLParseStructure, "ParamStrings");
				ResetTemplateStringStreams(XMLParseStructure);
				ClearParsedStrings(XMLParseStructure);
				
			EndIf;
			
			ResetWriteToStream(XMLParseStructure, "ParamString" + ParagraphLevel);
			
			If XMLParseStructure.OneCTagStatus = 0 AND XMLParseStructure.ParsedStrings.Count() = 0 OR XMLParseStructure.ParsedStrings.Count() > 0 Then
				ResetWriteToStream(XMLParseStructure, "Rows" + ParagraphLevel);
				InitializeWriteToStream(XMLParseStructure, "Rows" + ParagraphLevel);
				StopWriteToStream(XMLParseStructure, "Rows" + ParagraphLevel);
			EndIf;
			
		EndIf;
		
		If ReadParagraphEnd(XMLParseStructure, XMLReader) Then
			
			If NOT XMLParseStructure.OneCTagStatus = 0 Then
				Reset1CTagsStatuses(XMLParseStructure, True);
			EndIf;
			
			If Number(ParagraphLevel) > 1 Then
				WrapStream = "Paragraph" + Format(Number(ParagraphLevel) - 1, "NZ=0; NG=0");
				TransferWriteToStream(XMLParseStructure, "Paragraph" + ParagraphLevel, WrapStream);
			Else
				WrapStream = ?(CurrentLevel = TagLevelLock, "Area", "Block");
			EndIf;
			
			If AnalysisParameters.AnalysisType <> 1 Then
				TransferWriteToStream(XMLParseStructure, "Paragraph" + ParagraphLevel, "Block");
				WrapStream = "Block";
			ElsIf Not IsBlankString(XMLParseStructure.AreaName) AND XMLParseStructure.AreaStatus = 1 Then
				TransferWriteToStream(XMLParseStructure, "Paragraph" + ParagraphLevel, WrapStream);
			EndIf;
			
			If WrapStream = "Block" Then
				ContinueWriteToStream(XMLParseStructure, "Block");
			EndIf;
			
			ResetWriteToStream(XMLParseStructure, "Paragraph" + ParagraphLevel);
			ResetWriteToStream(XMLParseStructure, "Rows" + ParagraphLevel);
			
			If Not IsBlankString(XMLParseStructure.AreaName) AND XMLParseStructure.AreaStatus = 0 Then
				XMLParseStructure.AreaStatus = 1;
			EndIf;
			
			ParagraphLevel = Format(Number(ParagraphLevel) - 1, "NZ=0; NG=0");
			
			If Number(ParagraphLevel) > 1 Then
				ContinueWriteToStream(XMLParseStructure, "Rows" + ParagraphLevel);
				ContinueWriteToStream(XMLParseStructure, "Paragraph" + ParagraphLevel);
				ContinueWriteToStream(XMLParseStructure, "ParamString" + ParagraphLevel);
				XMLParseStructure.FormatStreamName = "ParamString" + ParagraphLevel;
			EndIf;
			
		EndIf;
		
		If ReadAnyBlockEndButParagraph(XMLParseStructure, XMLReader) AND CurrentLevel = TagLevelLock Then
			If Not IsBlankString(XMLParseStructure.AreaName) AND XMLParseStructure.AreaStatus = 1 Then
				TransferWriteToStream(XMLParseStructure, "Block", "Area");
			EndIf;
			ResetWriteToStream(XMLParseStructure, "Block");
		EndIf;
		
		If ReadSectionEnd(XMLParseStructure, XMLReader) Then
			
			SectionText = CompleteWriteToStream(XMLParseStructure, "Section");
			
			SectionStructure = SectionArea();
			SectionStructure.Text = SectionText;
			SectionStructure.Number = XMLParseStructure.SectionName;
			
			AddSectionToDocumentStructure(DocumentStructure, SectionStructure);
			
			XMLParseStructure.SectionName = XMLParseStructure.SectionName + 1;
			
			RemoveLockingStream = True;
			
		EndIf;
		
		If RemoveLockingStream AND CurrentLevel = TagLevelLock Then
			RemoveLockingStream = False;
			XMLParseStructure.LockingStream = "";
		EndIf;
		
		If XMLReader.NodeType = XMLNodeType.EndElement Then
			CurrentLevel = CurrentLevel - 1;
		EndIf;
		
	EndDo;
	
	If AnalysisParameters.AnalysisType = 2 OR AnalysisParameters.AnalysisType = 3 Then
		AreaText = CompleteWriteToStream(XMLParseStructure, "Block");
		AnalysisParameters.AnalysisStructure.Text  = AreaText;
	EndIf;
	
	If AnalysisParameters.AnalysisType = 1  Then
		
		InitializeWriteToStream(XMLParseStructure, "Paragraph", "");
		TransferOpeningTagsOfWriteToStream(XMLParseStructure, "Title", "Paragraph", "w:body");
		
		BreakText = "<w:p w:rsidRDefault=""" + DocumentStructure.DocumentID + """ w:rsidR=""" + DocumentStructure.DocumentID + """></w:p>";
		XMLParseStructure.WriteStreams.Paragraph.Stream.WriteRaw(BreakText);
		
		AreaText = CompleteWriteToStream(XMLParseStructure, "Paragraph");
		
		AreaStructure = DocumentArea();
		AreaStructure.Name          = "Paragraph";
		AreaStructure.Text        = AreaText;
		AreaStructure.SectionName = 0;
		AddDocumentAreaToDocumentStructure(DocumentStructure, AreaStructure);
		
	EndIf;
	
EndProcedure

Procedure AnalyzeParametersInString(Val Row, XMLParseStructure)
	
	// 1 - tag {v8 start
	// 2 - start of tag {v8 parameter
	// 3 - end of tag {v8 parameter
	
	// 5 - tag {/v8 start
	// 6 - start of tag {/v8 parameter
	// 7 - end of tag {/v8 parameter
	
	FlagOf1CTagStart = "{v8 ";
	FlagOf1CTagEnd  = "{/v8 ";
	
	StringLengthOf1CTag       = StrLen(XMLParseStructure.FullOneCTagName);
	StringLength             = StrLen(Row);
	
	For f = 1 To StringLength Do
		
		Char      = Mid(Row, f, 1);
		CharCode  = CharCode(Char);
		
		If Char = "{" AND (XMLParseStructure.OneCTagStatus = 3 OR XMLParseStructure.OneCTagStatus = 7) Then
			InitializeTemplateStringStreams(XMLParseStructure);
			GenerateParsedStrings(XMLParseStructure);
			StringLengthOf1CTag = 0;
		EndIf;
		
		If StringLengthOf1CTag + 1 <= StrLen(FlagOf1CTagStart) AND Left(FlagOf1CTagStart, StringLengthOf1CTag + 1) = XMLParseStructure.FullOneCTagName + Char Then
			
			XMLParseStructure.OneCTagStatus = 1;
			XMLParseStructure.FullOneCTagName = XMLParseStructure.FullOneCTagName + Char;
			StringLengthOf1CTag = StringLengthOf1CTag + 1;
			Continue;
			
		ElsIf StringLengthOf1CTag <= StrLen(FlagOf1CTagEnd) AND Left(FlagOf1CTagEnd, StringLengthOf1CTag + 1) = XMLParseStructure.FullOneCTagName + Char Then
			
			XMLParseStructure.OneCTagStatus = 5;
			XMLParseStructure.FullOneCTagName = XMLParseStructure.FullOneCTagName + Char;
			StringLengthOf1CTag = StringLengthOf1CTag + 1;
			Continue;
			
		EndIf;
		
		If XMLParseStructure.OneCTagStatus = 0 AND StrStartsWith(XMLParseStructure.FullOneCTagName, FlagOf1CTagStart) Then
			XMLParseStructure.OneCTagStatus = 1;
		ElsIf XMLParseStructure.OneCTagStatus = 0 AND StrStartsWith(XMLParseStructure.FullOneCTagName, FlagOf1CTagEnd) Then
			XMLParseStructure.OneCTagStatus = 5;
		EndIf;
		
		If XMLParseStructure.OneCTagStatus = 1 AND NOT StrStartsWith(XMLParseStructure.FullOneCTagName, FlagOf1CTagStart)
			 OR XMLParseStructure.OneCTagStatus = 5 AND NOT StrStartsWith(XMLParseStructure.FullOneCTagName, FlagOf1CTagEnd)
			 OR XMLParseStructure.OneCTagStatus = 5 AND IsBlankString(XMLParseStructure.AreaName) Then
			Text = XMLParseStructure.TextBefore1CTag + XMLParseStructure.FullOneCTagName + XMLParseStructure.TextAfter1CTag;
			Reset1CTagsStatuses(XMLParseStructure);
			XMLParseStructure.TextBefore1CTag = Text;
			StringLengthOf1CTag = 0;
		EndIf;
		
		If XMLParseStructure.OneCTagStatus = 1 OR XMLParseStructure.OneCTagStatus = 5 Then
			XMLParseStructure.OneCTagStatus = XMLParseStructure.OneCTagStatus + 1;
		EndIf;
		
		If XMLParseStructure.OneCTagStatus = 2 OR XMLParseStructure.OneCTagStatus = 6 Then
			
			XMLParseStructure.FullOneCTagName = XMLParseStructure.FullOneCTagName + Char;
			StringLengthOf1CTag = StringLengthOf1CTag + 1;
			
			If((CharCode >= 48 AND CharCode <= 57) OR (CharCode >= 65 AND CharCode <= 90) OR (CharCode >= 97 AND CharCode <= 122) OR (CharCode >= 1040 AND CharCode <= 1103)) Then
				XMLParseStructure.OneCTagName = XMLParseStructure.OneCTagName + Char;
			ElsIf Char = "." AND XMLParseStructure.OneCTagType = 0 AND XMLParseStructure.OneCTagName = "Area" Then
				XMLParseStructure.OneCTagType = 1;
				XMLParseStructure.OneCTagName = "";
			ElsIf Char = "}" Then
				XMLParseStructure.OneCTagStatus = XMLParseStructure.OneCTagStatus + 1;
			Else
				Text = XMLParseStructure.TextBefore1CTag + XMLParseStructure.FullOneCTagName + XMLParseStructure.TextAfter1CTag;
				Reset1CTagsStatuses(XMLParseStructure);
				XMLParseStructure.TextBefore1CTag = Text;
				StringLengthOf1CTag = 0;
			EndIf;
			
		ElsIf XMLParseStructure.OneCTagStatus = 3 OR XMLParseStructure.OneCTagStatus = 7 Then
			XMLParseStructure.TextAfter1CTag = XMLParseStructure.TextAfter1CTag + Char;
		Else
			XMLParseStructure.TextBefore1CTag = XMLParseStructure.TextBefore1CTag + Char;
		EndIf;
		
	EndDo;
	
	If XMLParseStructure.OneCTagStatus = 0 AND XMLParseStructure.ParsedStrings.Count() > 0 Then
		XMLParseStructure.OneCTagStatus = 3;
	EndIf;
	
	If XMLParseStructure.OneCTagStatus = 0 Then
		ResetTemplateStringStreams(XMLParseStructure);
	Else
		InitializeTemplateStringStreams(XMLParseStructure);
	EndIf;
	
	If XMLParseStructure.OneCTagStatus = 3 OR XMLParseStructure.OneCTagStatus = 7 Then
		GenerateParsedStrings(XMLParseStructure);
	EndIf;
	
	If XMLParseStructure.OneCTagStatus = 0 AND XMLParseStructure.ParsedStrings.Count() = 0 Then
		Reset1CTagsStatuses(XMLParseStructure);
	EndIf;
	
EndProcedure

Procedure SelectHeadersFootersFormSection(XMLReader, DocumentStructure, Section)
	
	HeadersFootersTypes = HeadersFootersTypes();
	
	While XMLReader.Read() Do
		
		If NOT (XMLReader.NodeType = XMLNodeType.StartElement AND (XMLReader.Name = "w:headerReference" OR XMLReader.Name = "w:footerReference")) Then
			Continue;
		EndIf;
		
		TagName       = XMLReader.Name;
		Attribute_wtype = XMLReader.GetAttribute("w:type");
		Attribute_rid   = XMLReader.GetAttribute("r:id");
		
		FoundRow = DocumentStructure.ContentLinksTable.Find(Attribute_rid);
		
		If FoundRow = Undefined Then
			Continue;
		EndIf;
		
		HeaderOrFooterType   = HeadersFootersTypes.Get(TagName + "_" + Attribute_wtype);
		
		HeaderOrFooterStructure = HeaderOrFooterArea();
		HeaderOrFooterStructure.Name          = HeaderOrFooterType;
		HeaderOrFooterStructure.InternalName     = StrReplace(FoundRow.ResourceName, ".xml", "");
		HeaderOrFooterStructure.SectionName = Section.Number;
		
		AddHeaderFooterToDocumentStructure(DocumentStructure, HeaderOrFooterStructure, FoundRow.ResourceName);
		
	EndDo;
	
EndProcedure

Function ProcessDocumentSection(DocumentStructure, Section)
	
	HeadersFootersTypes = HeadersFootersTypes();
	
	XMLReader = InitializeXMLReader(Section.Text);
	XMLWriter = InitializeXMLRecord("",,,False);
	
	SkipTag = False;
	While XMLReader.Read() Do
		
		If SkipTag = True Then
			SkipTag = False;
			Continue;
		EndIf;
		
		If XMLReader.NodeType = XMLNodeType.StartElement AND (XMLReader.Name = "w:document" OR XMLReader.Name = "w:body") Then
			Continue;
		EndIf;
		
		If XMLReader.NodeType = XMLNodeType.Text Then
			Continue;
		EndIf;
		
		If XMLReader.NodeType = XMLNodeType.StartElement AND (XMLReader.Name = "w:headerReference" OR XMLReader.Name = "w:footerReference") Then
			
			TagName = XMLReader.Name;
			AttributeValue = XMLReader.GetAttribute("w:type");
			HeaderOrFooterKey = TagName + "_" + AttributeValue;
			HeaderOrFooterType = HeadersFootersTypes.Get(HeaderOrFooterKey);
			KeyInDocumentStructure = HeaderOrFooterType + "_" + Format(Section.Number, "NG=0");
			HeaderOrFooterInStructure = DocumentStructure.HeadersAndFooters.Get(KeyInDocumentStructure);
			
			If HeaderOrFooterInStructure.Text = "" Then
				SkipTag = True;
				Continue;
			EndIf;
			
		EndIf;
		
		If XMLReader.NodeType = XMLNodeType.EndElement AND (XMLReader.Name = "w:document" OR XMLReader.Name = "w:body") Then
			Continue;
		EndIf;
		
		WriteXMLItem(XMLReader, XMLWriter);
		
	EndDo;
	
	SectionText = XMLWriter.Close();
	
	Return SectionText;
	
EndFunction

#EndRegion

#EndRegion

#Region ImagesOperations

////////////////////////////////////////////////////////////////////////////////
// Functions of image files processing

// Returns a width, a height, and a type of image for GIF, JPG, PNG, BMP, and TIFF files.
Function GetImageAttributes(ReadingData)
	
	ImageAttributes = New Structure;
	
	If TypeOf(ReadingData) = Type("String") Then
		
		Try
			DataStream = FileStreams.OpenForRead(ReadingData);
		Except
			Return ImageAttributes;
		EndTry;
		
	ElsIf TypeOf(ReadingData) = Type("BinaryData") Then
		DataStream = ReadingData
	Else
		Return ImageAttributes;
	EndIf;
	
	DataReading = New DataReader(DataStream);
	
	Char1 = DataReading.ReadByte();
	Char2 = DataReading.ReadByte();
	Char3 = DataReading.ReadByte();
	
	// MIME syntax -  "type/subtype"
	MimeType = Null;
	
	Width  = -1;
	Height = -1;
	
	If (Char(Char1) = "G" AND Char(Char2) = "I" AND Char(Char3) = "F") Then // GIF
		
		DataReading.Skip(3);
		Width  = ReadByteValueFromStream(DataReading, 2, False);
		Height = ReadByteValueFromStream(DataReading, 2 , False);
		MimeType = "image/gif";
		
	ElsIf (Char1 = 255 AND Char2 = 216) Then // JPG
		
		While (Char3 = 255) Do 
			
			Token = DataReading.ReadByte();
			Length = ReadByteValueFromStream(DataReading, 2, True);
			
			If (Token = 192 OR Token = 193 OR Token = 194) Then
				
				DataReading.Skip(1);
				Height = ReadByteValueFromStream(DataReading, 2, True);
				Width  = ReadByteValueFromStream(DataReading, 2, True);
				MimeType = "image/jpeg";
				Break;
				
			EndIf;
			
			DataReading.Skip(Length - 2);
			Char3 = DataReading.ReadByte();
			
		EndDo;
		
	ElsIf  (Char1 = 137 AND Char2 = 80 AND Char3 = 78) Then // PNG
		
		DataReading.Skip(15);
		Width = ReadByteValueFromStream(DataReading, 2 , True);
		DataReading.Skip(2);
		Height = ReadByteValueFromStream(DataReading, 2, True);
		MimeType = "image/png";
		
	ElsIf  (Char1 = 66 AND Char2 = 77) Then // BMP
		
		DataReading.Skip(15);
		Width = ReadByteValueFromStream(DataReading, 2, False);
		DataReading.Skip(2);
		Height = ReadByteValueFromStream(DataReading, 2, False);
		MimeType = "image/bmp";
		
	Else
		
		Char4 = DataReading.ReadByte();
		
		If((Char(Char1) = "M" AND Char(Char2) = "M" AND Char3 = 0 AND Char4 = 42) OR (Char(Char1) = "I" AND Char(Char2) = "I" AND Char3 = 42 AND Char4 = 0)) Then //TIFF
			
			BytesOrderBigEndian = Char(Char1) = "M";
			
			// Image header
			ImageFileDirectory = 0;
			ImageFileDirectory = ReadByteValueFromStream(DataReading, 4, BytesOrderBigEndian);
			
			DataReading.Skip(ImageFileDirectory - 8);
			Occurrences = ReadByteValueFromStream(DataReading, 2, BytesOrderBigEndian);
			
			Index = 1;
			While Index <= Occurrences Do
				
				Tag = ReadByteValueFromStream(DataReading, 2, BytesOrderBigEndian);
				FieldType = ReadByteValueFromStream(DataReading, 2, BytesOrderBigEndian);
				ReadByteValueFromStream(DataReading, 4, BytesOrderBigEndian);
				
				If (FieldType = 3 OR FieldType = 8) Then
					
					OffsetValue = ReadByteValueFromStream(DataReading, 2, BytesOrderBigEndian);
					DataReading.Skip(2);
					
				Else
					
					OffsetValue = ReadByteValueFromStream(DataReading, 4, BytesOrderBigEndian);
					
				EndIf;
				
				If (Tag = 256) Then
					
					Width = OffsetValue;
					
				ElsIf (Tag = 257) Then
					
					Height = OffsetValue;
					
				EndIf;
				
				If (Width <> -1 AND Height <> -1) Then
					
					MimeType = "image/tiff";
					Break;
					
				EndIf;
				
				Index = Index + 1;
				
			EndDo;
			
		EndIf;
		
	EndIf;
	
	DataReading.Close();
	
	ImageAttributes.Insert("ImageType", MimeType);
	ImageAttributes.Insert("Height", ?(MimeType = Null, 0, Height));
	ImageAttributes.Insert("Width", ?(MimeType = Null, 0, Width));
	
	Return ImageAttributes;
	
EndFunction

Function ReadByteValueFromStream(InputStream, BytesCount, BytesOrderBigEndian) 
	
	Value = 0;
	
	OffsetSize = ?(BytesOrderBigEndian = True, (BytesCount - 1) * 8, 0);
	Count = ?(BytesOrderBigEndian = True, -8, 8); 
	
	Index = 0;
	While Index < BytesCount Do
		
		Value = BitwiseOr_(Value, BitwiseShiftLeft_(InputStream.ReadByte(), OffsetSize));
		OffsetSize = OffsetSize + Count;
		
		Index = Index + 1;
		
	EndDo;
	
	Return Value;
	
EndFunction

Function BitwiseShiftLeft_(Val Number, Offset = 0)
	
	BinaryPresentation = GetBinaryNumberPresentation(Number);
	BinaryNumberArray  = ParseBinaryPresentation(BinaryPresentation);
	
	For Ind = 0 To Offset - 1 Do
		
		Index = 1;
		While Index <= BinaryNumberArray.UBound() - Ind Do 
			
			BinaryNumberArray[Index-1] = BinaryNumberArray[Index];
			Index = Index + 1;
			
		EndDo;
		
		BinaryNumberArray[BinaryNumberArray.UBound()- Ind] = "0";
		
	EndDo;
	
	
	BinaryNumberArrayPresentation = GetBinaryNumberArrayPresentation(BinaryNumberArray);	
	
	Result = NumberFromBinaryString("0b" + BinaryNumberArrayPresentation);
	
	Return Result;
	
EndFunction

Function BitwiseOr_(Number1, Number2)
	
	BinaryNumber1Presentation = GetBinaryNumberPresentation(Number1);
	BinaryNumber2Presentation = GetBinaryNumberPresentation(Number2);
	
	BinaryNumber1Array = ParseBinaryPresentation(BinaryNumber1Presentation);
	BinaryNumber2Array = ParseBinaryPresentation(BinaryNumber2Presentation);
	
	ArrayLength = BinaryNumber1Array.UBound();
	
	For Ind = 0 To ArrayLength Do
		
		If BinaryNumber1Array[Ind] = "1" OR BinaryNumber2Array[Ind] = "1" Then
			BinaryNumber1Array[Ind] = "1";
		EndIf;
		
	EndDo;
	
	BinaryNumberArrayPresentation = GetBinaryNumberArrayPresentation(BinaryNumber1Array);
	
	Result = NumberFromBinaryString("0b" + BinaryNumberArrayPresentation);
	
	Return Result;
	
EndFunction

Function GetBinaryNumberPresentation(Value, Mask = "00000000000000000000000000000000")
	
	Result = "";
	Template    = "01";
	Base = StrLen(Template);
	
	While Value > 0 Do
		
		Balance    = Value % Base;
		Result1 = Mid(Template, Balance + 1, 1);
		Value   = (Value - Balance) / Base;
		Result  = Result1 + Result;
		
	EndDo;
	
	ZerosCount = StrLen(Mask) - StrLen(Result);
	For Ind = 1 To ZerosCount Do 
		Result = "0" + Result;
	EndDo;
	
	Return Result;
	
EndFunction

Function GetBinaryNumberArrayPresentation(BinaryNumberArray)
	
	Result = "";
	
	For Ind = 0 To BinaryNumberArray.UBound() Do
		Result = Result + BinaryNumberArray[Ind];
	EndDo;
	
	Return Result
	
EndFunction

Function ParseBinaryPresentation(BinaryPresentation)
	
	BinaryNumberArray = New Array(StrLen(BinaryPresentation));
	
	For Ind = 0 To BinaryNumberArray.UBound() Do
		BinaryNumberArray[Ind] = Mid(BinaryPresentation, Ind + 1, 1);
	EndDo;
	
	Return BinaryNumberArray;
	
EndFunction

#EndRegion

////////////////////////////////////////////////////////////////////////////////
// Other procedures and functions

Function EventLogEvent()
	
	Return NStr("ru = 'Печать'; en = 'Print'; pl = 'Drukuj';es_ES = 'Impresión';es_CO = 'Impresión';tr = 'Yazdır';it = 'Stampa';de = 'Drucken'", CommonClientServer.DefaultLanguageCode());
	
EndFunction

Procedure CopyDirectoryContent(WhereFrom, Destination)
	
	PurposeDirectory = New File(Destination);
	
	If PurposeDirectory.Exist() Then
		If PurposeDirectory.IsFile() Then
			DeleteFiles(PurposeDirectory.FullName);
			CreateDirectory(Destination);
		EndIf;
	Else
		CreateDirectory(Destination);
	EndIf;
	
	Files = FindFiles(WhereFrom, GetAllFilesMask());
	
	For Each File In Files Do
		If File.IsDirectory() Then
			CopyDirectoryContent(File.FullName, SetPathSeparator(Destination + "\" + File.Name));
		Else
			FileCopy(File.FullName, SetPathSeparator(Destination + "\" + File.Name));
		EndIf;
	EndDo;
	
EndProcedure

// WriteEventsToEventLog
// Parameters:
//              * EventName  - String - a name of the event to write.
//              * LevelPresentation  - String - a presentation of the EventLogLevel collection values.
//                                       Possible values: Information, Error, Warning, and Note.
//              * Comment - String - an event comment.
Procedure WriteEventsToEventLog(EventName, LevelPresentation, Comment)
	
	EventsList = New ValueList;
	
	EventStructure = New Structure;
	EventStructure.Insert("EventName", EventName);
	EventStructure.Insert("LevelPresentation", LevelPresentation);
	EventStructure.Insert("Comment", Comment);
	
	EventsList.Add(EventStructure);
	
	EventLogOperations.WriteEventsToEventLog(EventsList);
	
EndProcedure

// Defines a data file extension according to its signature. Files are analyzed by the first 8 bytes 
// according to docx, doc, and odt types.
// To call printing forms by templates of office documents from client and server modules.
//
// Parameters:
//  DataOrStructure - BinaryData, Structure - a document file or a command table row.
//
// Returns:
//  Row, Undefined - an extension of binary data file or Undefined, if cannot define an extension.
//
Function DefineDataFileExtensionBySignature(DataOrStructure) Export
	
	If TypeOf(DataOrStructure) = Type("Structure") Then
		Try
			ObjectTemplateAndData = PrintManagement.TemplatesAndObjectsDataToPrint(DataOrStructure.PrintManager,
				DataOrStructure.ID, New Array);
			BinaryTemplateData = ObjectTemplateAndData.Templates.TemplatesBinaryData.Get(DataOrStructure.ID);
		Except
			Return Undefined;
		EndTry;
	Else
		BinaryTemplateData = DataOrStructure;
	EndIf;
	
	If BinaryTemplateData = Undefined Then
		 Return Undefined;
	EndIf;	
	 
	DataStream = BinaryTemplateData.OpenStreamForRead();
	DataReading = New DataReader(DataStream);
	
	Char1 = DataReading.ReadByte();
	Char2 = DataReading.ReadByte();
	Char3 = DataReading.ReadByte();
	Char4 = DataReading.ReadByte();
	Char5 = DataReading.ReadByte();
	Char6 = DataReading.ReadByte();
	Char7 = DataReading.ReadByte();
	Char8 = DataReading.ReadByte();
	
	DataStream.Close();
	
	If Char1 = 208 AND Char2 = 207 AND Char3 = 17 AND Char4 = 224 AND Char5 = 161 AND Char6 = 177 AND Char7 = 26 AND Char8 = 225 Then
		Return "doc";
	ElsIf Char1 = 80 AND Char2 = 75 AND Char3 = 3 AND Char4 = 4 AND Char5 = 20 AND Char6 = 0 AND Char7 = 0 AND Char8 = 8
			  OR Char1 = 80 AND Char2 = 75 AND Char3 = 3 AND Char4 = 4 AND Char5 = 10 AND Char6 = 0 AND Char7 = 0 AND Char8 = 0 Then
		Return "odt";
	ElsIf Char1 = 80 AND Char2 = 75 AND Char3 = 3 AND Char4 = 4 AND Char5 = 20 AND Char6 = 0 Then
		Return "docx";
	Else
		Return Undefined;
	EndIf;
	
EndFunction

Function SetPathSeparator(Val Path)
	Return StrConcat(StrSplit(Path, "\/", True), GetPathSeparator());
EndFunction

#EndRegion
