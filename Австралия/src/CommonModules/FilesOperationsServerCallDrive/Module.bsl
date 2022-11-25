
#Region Public

Function AttachPrintFormsToObject(SpreadsheetDocuments, ObjectToAttach, FormUUID, TransliterateFilesNames = False) Export
	
	Result = New Array;
	
	If ArchivePrintForms(ObjectToAttach) Then
		
		// preparing a temporary folder
		TempFolderName = GetTempFileName();
		CreateDirectory(TempFolderName);
		
		FormatsTable = PrintManagement.SpreadsheetDocumentSaveFormatsSettings();
		SearchingStructure = New Structure("Ref", Constants.FileFormatArchiving.Get());
		FormatsTableRows = FormatsTable.FindRows(SearchingStructure);
		If FormatsTableRows.Count() > 0 Then
			FormatSettings = FormatsTableRows[0];
		Else
			FormatSettings = New Structure;
			FormatSettings.Insert("SpreadsheetDocumentFileType", SpreadsheetDocumentFileType.MXL);
			FormatSettings.Insert("Extension", "mxl");
		EndIf;
		
		CompareBeforeArchiving = (Lower(FormatSettings.Extension) = "mxl" AND Constants.CompareBeforeArchiving.Get());
		
		// Saving print forms
		ProcessedPrintForms = New Array;
		
		For Each PrintFormListItem In SpreadsheetDocuments Do
			
			PrintForm = PrintFormListItem.Value;
			If ProcessedPrintForms.Find(PrintForm) = Undefined Then
				ProcessedPrintForms.Add(PrintForm);
			Else
				Continue;
			EndIf;
			
			If EvalOutputUsage(PrintForm) = UseOutput.Disable
				OR PrintForm.Protection
				OR PrintForm.TableHeight = 0 Then
				Continue;
			EndIf;
			
			If CompareBeforeArchiving AND NOT IsDiffersFromPrevious(PrintForm, ObjectToAttach, FormUUID) Then
				Continue;
			EndIf;
			
			FileName = DefaultPrintFormFileName(ObjectToAttach, PrintFormListItem.Presentation);
			FileName = CommonClientServer.ReplaceProhibitedCharsInFileName(FileName);
			
			If TransliterateFilesNames Then
				FileName = StringFunctionsClientServer.LatinString(FileName);
			EndIf;
			
			FileName = FileName + "." + FormatSettings.Extension;
			
			FullFileName = UniqueFileName(CommonClientServer.AddLastPathSeparator(TempFolderName) + FileName);
			PrintForm.Write(FullFileName, FormatSettings.SpreadsheetDocumentFileType);
			
			If FormatSettings.SpreadsheetDocumentFileType = SpreadsheetDocumentFileType.HTML Then
				InsertPicturesToHTML(FullFileName);
			EndIf;
			
			BinaryData = New BinaryData(FullFileName);
			PathInTempStorage = PutToTempStorage(BinaryData, FormUUID);
			
			FileParameters = New Structure;
			FileParameters.Insert("FilesOwner", ObjectToAttach);
			FileParameters.Insert("Author", Undefined);
			FileParameters.Insert("BaseName", FileName);
			FileParameters.Insert("ExtensionWithoutPoint", Undefined);
			FileParameters.Insert("Modified", Undefined);
			FileParameters.Insert("ModificationTimeUniversal", Undefined);
			
			AttachedFile = FilesOperations.AppendFile(FileParameters, PathInTempStorage, , NStr("en = 'Print form'; ru = 'Печатная форма';pl = 'Formularz wydruku';es_ES = 'Versión impresa';es_CO = 'Versión impresa';tr = 'Yazdırma formu';it = 'Stampa modulo';de = 'Formular drucken'"));
			
			Result.Add(AttachedFile);
			
		EndDo;
		
		DeleteFiles(TempFolderName);
		
	EndIf;
	
	Return Result;
	
EndFunction

Function GetArchivePrintFormsOption() Export
	
	Return GetFunctionalOption("ArchivePrintForms");
	
EndFunction

Function DefaultPrintFormFileName(PrintObject, PrintFormName) Export
	
	If Common.IsDocument(Metadata.FindByType(TypeOf(PrintObject))) Then
		
		DocumentContainsNumber = PrintObject.Metadata().NumberLength > 0;
		
		ParametersValues = New Array;
		ParametersValues.Add(PrintFormName);
		
		If DocumentContainsNumber Then
			ParametersToInsert = Common.ObjectAttributesValues(PrintObject, "Date, Number");
			ParametersToInsert.Number = ObjectPrefixationClientServer.NumberForPrinting(ParametersToInsert.Number);
			Template = "%1 %2 %3 %4";
			ParametersValues.Add(ParametersToInsert.Number);
		Else
			ParametersToInsert = Common.ObjectAttributesValues(PrintObject, "Date");
			Template = "%1 %2 %3";
		EndIf;
		
		ParametersToInsert.Date = Format(ParametersToInsert.Date, "DLF=D");
		
		ParametersValues.Add(NStr("en = 'dated'; ru = 'от';pl = 'z dn.';es_ES = 'fechado';es_CO = 'fechado';tr = 'tarihli';it = 'con data';de = 'datiert'"));
		ParametersValues.Add(ParametersToInsert.Date);
		
	Else
		
		ParametersValues.Add(Common.SubjectString(PrintObject));
		ParametersValues.Add(Format(CurrentSessionDate(), "DLF=D"));
		Template = "%1 - %2 - %3";
		
	EndIf;
	
	FileName = StringFunctionsClientServer.SubstituteParametersToStringFromArray(Template, ParametersValues);
	
	Return CommonClientServer.ReplaceProhibitedCharsInFileName(FileName);
	
EndFunction

#EndRegion

#Region Private

Function EvalOutputUsage(SpreadsheetDocument)
	
	If SpreadsheetDocument.Output = UseOutput.Auto Then
		Return ?(AccessRight("Output", Metadata), UseOutput.Enable, UseOutput.Disable);
	Else
		Return SpreadsheetDocument.Output;
	EndIf;
	
EndFunction

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

Function ArchivePrintForms(ObjectToAttach)
	
	Result = False;
	
	If GetArchivePrintFormsOption() Then
		
		MetadataObject = Metadata.FindByType(TypeOf(ObjectToAttach));
		
		If Common.IsDocument(MetadataObject) Then
			
			If Common.HasObjectAttribute("Company", MetadataObject) Then
				
				Query = New Query;
				Query.Text = 
				"SELECT ALLOWED TOP 1
				|	TRUE AS VrtField
				|FROM
				|	InformationRegister.PrintFormsArchivingSettings AS PrintFormsArchivingSettings
				|		INNER JOIN Catalog.MetadataObjectIDs AS MetadataObjectIDs
				|		ON PrintFormsArchivingSettings.DocumentType = MetadataObjectIDs.Ref
				|WHERE
				|	MetadataObjectIDs.FullName = &FullName
				|	AND PrintFormsArchivingSettings.Company = &Company";
				
				Query.SetParameter("FullName", MetadataObject.FullName());
				Query.SetParameter("Company", ObjectToAttach.Company);
				
				QueryResult = Query.Execute();
				
				If NOT QueryResult.IsEmpty() Then
					Result = True;
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	Return Result;
	
EndFunction

Function IsDiffersFromPrevious(SpreadsheetDocument, FileOwner, FormUUID, Extension = "mxl")
	
	Var PreviousSpreadsheetDocument;
	
	IsDiffers = True;
	
	PreviousAttachedFile = GetLastFilesAttachedToObject(FileOwner, Extension);
	If PreviousAttachedFile = Undefined Then
		
		Return IsDiffers;
		
	EndIf;
	
	PreviousFileData = GetFileData(PreviousAttachedFile, FormUUID);
	If NOT PreviousFileData.Property("SpreadsheetDocument", PreviousSpreadsheetDocument) Then
		
		Return IsDiffers;
		
	EndIf;
	
	IsDiffers = Compare(PreviousSpreadsheetDocument, SpreadsheetDocument);
	
	Return IsDiffers;
	
EndFunction

Function GetLastFilesAttachedToObject(Val FileOwner, Extension = "mxl")
	
	AttachedFile = Undefined;
	
	OwnersTypes = Metadata.InformationRegisters.FilesExist.Dimensions.ObjectWithFiles.Type.Types();
	If OwnersTypes.Find(TypeOf(FileOwner)) <> Undefined Then
		
		SetPrivilegedMode(True);
		
		If TypeOf(FileOwner) = Type("Type") Then
			FileOwnerType = FileOwner;
		Else
			FileOwnerType = TypeOf(FileOwner);
		EndIf;
		
		OwnerMetadata = Metadata.FindByType(FileOwnerType);
		
		CatalogName = OwnerMetadata.Name
			+ ?(StrEndsWith(OwnerMetadata.Name, "AttachedFiles"), "", "AttachedFiles");
		
		If Metadata.Catalogs.Find(CatalogName) = Undefined Then
			Return AttachedFile;
		EndIf;
		
		Query = New Query;
		Query.Text =
		"SELECT ALLOWED TOP 1
		|	AttachedFiles.Ref AS Ref
		|FROM
		|	&CatalogName AS AttachedFiles
		|WHERE
		|	AttachedFiles.FileOwner = &FilesOwner
		|	AND AttachedFiles.Extension = &Extension
		|
		|ORDER BY
		|	AttachedFiles.CreationDate DESC";
		
		Query.Text = StrReplace(Query.Text, "&CatalogName", "Catalog." + CatalogName);
		
		Query.SetParameter("FilesOwner", FileOwner);
		Query.SetParameter("Extension", Extension);
		
		QueryResultTable = Query.Execute().Unload();
		
		If QueryResultTable.Count() > 0 Then
			AttachedFile = QueryResultTable[0].Ref;
		EndIf;
		
	EndIf;
	
	Return AttachedFile;
	
EndFunction

Function GetFileData(AttachedFile, FormUUID)
	
	FileData = FilesOperations.FileData(AttachedFile, FormUUID);
	
	If Lower(FileData.Extension) = "mxl" Then
		
		FileBinaryData = GetFromTempStorage(FileData.BinaryFileDataRef);
		TempFileName = GetTempFileName();
		FileBinaryData.Write(TempFileName);
		SpreadsheetDocument = New SpreadsheetDocument;
		SpreadsheetDocument.Read(TempFileName);
		DeleteFiles(TempFileName);
		FileData.Insert("SpreadsheetDocument", SpreadsheetDocument);
		
	EndIf;
	
	Return FileData;
	
EndFunction

Function Compare(SpreadsheetDocumentLeft, SpreadsheetDocumentRight)
	
	Result = False;
	
	// Exporting text from spreadsheet document cells to the value tables.
	LeftDocumentTable = ReadSpreadsheetDocument(SpreadsheetDocumentLeft);
	RightDocumentTable = ReadSpreadsheetDocument(SpreadsheetDocumentRight);
	
	// Comparing the spreadsheet documents by lines and selecting the matching lines.
	Matches = GenerateMatches(LeftDocumentTable, RightDocumentTable, True);
	RowsMapLeft = Matches[0];
	RowsMapRight = Matches[1];
	
	// Comparing the spreadsheet documents by columns and selecting the matching columns.
	Matches = GenerateMatches(LeftDocumentTable, RightDocumentTable, False);
	ColumnsMapLeft = Matches[0];
	ColumnsMapRight = Matches[1];

	// Lines that were deleted from the left spreadsheet document.
	For RowNumber = 1 To RowsMapLeft.Count()-1 Do
		
		If RowsMapLeft[RowNumber].Value = Undefined Then
			
			Result = True;
			Break;
			
		EndIf;
		
	EndDo;
	
	// Columns that were deleted from the left spreadsheet document.
	If NOT Result Then
		
		For ColumnNumber = 1 To ColumnsMapLeft.Count()-1 Do
			
			If ColumnsMapLeft[ColumnNumber].Value = Undefined Then
				
				Result = True;
				Break;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	// Lines that were added to the right spreadsheet document.
	If NOT Result Then
		
		For RowNumber = 1 To RowsMapRight.Count()-1 Do
			
			If RowsMapRight[RowNumber].Value = Undefined Then
				
				Result = True;
				Break;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	// Columns that were added to the right spreadsheet document.
	If NOT Result Then
		
		For ColumnNumber = 1 To ColumnsMapRight.Count()-1 Do
			
			If ColumnsMapRight[ColumnNumber].Value = Undefined Then
				
				Result = True;
				Break;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	// Cells that were modified.
	If NOT Result Then
		
		For RowNumber1 = 1 To RowsMapLeft.Count()-1 Do
			
			RowNumber2 = RowsMapLeft[RowNumber1].Value;
			If RowNumber2 = Undefined Then
				Continue;
			EndIf;
			
			For ColumnNumber1 = 1 To ColumnsMapLeft.Count()-1 Do
				
				ColumnNumber2 = ColumnsMapLeft[ColumnNumber1].Value;
				If ColumnNumber2 = Undefined Then
					Continue;
				EndIf;
				
				Area1 = SpreadsheetDocumentLeft.Area(RowNumber1, ColumnNumber1, RowNumber1, ColumnNumber1);
				Area2 = SpreadsheetDocumentRight.Area(RowNumber2, ColumnNumber2, RowNumber2, ColumnNumber2);
				
				If NOT CompareAreas(Area1, Area2) Then
					
					Result = True;
					Break;
					
				EndIf;
				
			EndDo;
			
		EndDo;
		
	EndIf;
	
	Return Result;
	
EndFunction

Function GenerateMatches(LeftTable, RightTable, ByRows)
	
	DataFromLeftTable	= GetDataForComparison(LeftTable, ByRows);
	DataFromRightTable	= GetDataForComparison(RightTable, ByRows);
	
	If ByRows Then
		
		MatchResultLeft = New ValueList;
		MatchResultLeft.LoadValues(New Array(LeftTable.Count() + 1));
		
		MatchResultRight = New ValueList;
		MatchResultRight.LoadValues(New Array(RightTable.Count() + 1));
		
	Else
		
		MatchResultLeft = New ValueList;
		MatchResultLeft.LoadValues(New Array(LeftTable.Columns.Count() + 1));
		
		MatchResultRight = New ValueList;
		MatchResultRight.LoadValues(New Array(RightTable.Columns.Count() + 1));
		
	EndIf;
	
	QueryText = "";
	
	QueryText = QueryText + "	SELECT * INTO LeftTable 
								|	FROM &DataFromLeftTable AS DataFromLeftTable;" + Chars.LF;
	
	QueryText = QueryText + "	SELECT * INTO RightTable
								|	FROM &DataFromRightTable AS DataFromRightTable;" + Chars.LF;
	
	QueryText = QueryText + 
	"SELECT
	|	LeftTable.Number AS ItemNumberLeft,
	|	RightTable.Number AS ItemNumberRight,
	|	CASE
	|		WHEN RightTable.Number - LeftTable.Number < 0
	|			THEN LeftTable.Number - RightTable.Number
	|		ELSE RightTable.Number - LeftTable.Number
	|	END AS DistanceFromBeginning,
	|	CASE
	|		WHEN &RowCountRight - RightTable.Number - (&RowCountLeft - LeftTable.Number) < 0
	|			THEN &RowCountLeft - LeftTable.Number - (&RowCountRight - RightTable.Number)
	|		ELSE  &RowCountRight - RightTable.Number - (&RowCountLeft - LeftTable.Number)
	|	END AS DistanceFromEnd,
	|	SUM(CASE
	|			WHEN LeftTable.Value <> """"
	|				THEN CASE
	|						WHEN LeftTable.Count < RightTable.Count
	|							THEN LeftTable.Count
	|						ELSE RightTable.Count
	|					END
	|			ELSE 0
	|		END) AS ValueMatchesCount,
	|	SUM(CASE
	|			WHEN LeftTable.Count < RightTable.Count
	|				THEN LeftTable.Count
	|			ELSE RightTable.Count
	|		END) AS TotalMatchesCount
	|INTO DataCollapsed
	|FROM
	|	LeftTable AS LeftTable
	|		INNER JOIN RightTable AS RightTable
	|		ON LeftTable.Value = RightTable.Value
	|
	|GROUP BY
	|	LeftTable.Number,
	|	RightTable.Number
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DataCollapsed.ItemNumberLeft AS ItemNumberLeft,
	|	DataCollapsed.ItemNumberRight AS ItemNumberRight,
	|	DataCollapsed.ValueMatchesCount AS ValueMatchesCount,
	|	DataCollapsed.TotalMatchesCount AS TotalMatchesCount,
	|	CASE
	|		WHEN DataCollapsed.DistanceFromBeginning < DataCollapsed.DistanceFromEnd
	|			THEN DataCollapsed.DistanceFromBeginning
	|		ELSE DataCollapsed.DistanceFromEnd
	|	END AS MinDistance
	|FROM
	|	DataCollapsed AS DataCollapsed
	|
	|ORDER BY
	|	ValueMatchesCount DESC,
	|	TotalMatchesCount DESC,
	|	MinDistance,
	|	ItemNumberLeft,
	|	ItemNumberRight";
	
	Query = New Query(QueryText);
	Query.SetParameter("DataFromLeftTable", DataFromLeftTable);
	Query.SetParameter("DataFromRightTable", DataFromRightTable);
	Query.SetParameter("RowCountLeft", LeftTable.Count());
	Query.SetParameter("RowCountRight", RightTable.Count());
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		If MatchResultLeft[Selection.ItemNumberLeft].Value = Undefined
			AND MatchResultRight[Selection.ItemNumberRight].Value = Undefined Then
			
			MatchResultLeft[Selection.ItemNumberLeft].Value = Selection.ItemNumberRight;
			MatchResultRight[Selection.ItemNumberRight].Value = Selection.ItemNumberLeft;
			
		EndIf;
		
	EndDo;
	
	Result = New Array;
	Result.Add(MatchResultLeft);
	Result.Add(MatchResultRight);
	
	Return Result;

EndFunction

Function ReadSpreadsheetDocument(SourceSpreadsheetDocument)
	
	ColumnsCount = SourceSpreadsheetDocument.TableWidth;
	
	If ColumnsCount = 0 Then
		Return New ValueTable;
	EndIf;
	
	SpreadsheetDocument = New SpreadsheetDocument;
	
	For ColumnNumber = 1 To ColumnsCount Do
		SpreadsheetDocument.Area(1, ColumnNumber, 1, ColumnNumber).Text = "Number_" + Format(ColumnNumber,"NG=0");
	EndDo;
	
	SpreadsheetDocument.Put(SourceSpreadsheetDocument);
	
	Builder = New QueryBuilder;
	
	Builder.DataSource = New DataSourceDescription(SpreadsheetDocument.Area());
	Builder.Execute();
	
	ValueTableResult = Builder.Result.Unload();
	
	Return ValueTableResult;
	
EndFunction

Function CompareAreas(Area1, Area2)
	
	If Area1.Text <> Area2.Text Then
		Return False;
	EndIf;
	
	If Area1.Comment.Text <> Area2.Comment.Text Then
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

Function GetDataForComparison(SourceValueTable, ByRows)
	
	MaxRowSize = New StringQualifiers(100);
	
	Result = New ValueTable;
	Result.Columns.Add("Number",	New TypeDescription("Number"));
	Result.Columns.Add("Value",		New TypeDescription("String", , MaxRowSize));
	
	Boundary1 = ?(ByRows, SourceValueTable.Count(), SourceValueTable.Columns.Count()) - 1;
	Boundary2 = ?(ByRows, SourceValueTable.Columns.Count(), SourceValueTable.Count()) - 1;
	
	For Index1 = 0 To Boundary1 Do
		
		For Index2 = 0 To Boundary2 Do
			
			NewRow = Result.Add();
			NewRow.Number = Index1+1;
			NewRow.Value = ?(ByRows, SourceValueTable[Index1][Index2], SourceValueTable[Index2][Index1]);
			
		EndDo;
		
	EndDo;
	
	Result.Columns.Add("Count", New TypeDescription("Number"));
	Result.FillValues(1, "Count");
	
	Result.GroupBy("Number, Value", "Count");
	
	Return Result;
	
EndFunction

#EndRegion