#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

// Reports the details required for importing data from a file.
//
// Returns
//  Structure - contains structure with the following properties:
//     * Presentation - String - a presentation in the list of import options.
//     * DataStructureTemplateName						 - String - a template name with data structure (optional 
//                                           parameter, default value is ImportDataFromFile).
//     * RequiredTemplateColumns - Array - contains the list of required fields.
//     * MappingColumnHeader	  		 - String - a mapping column presentation in the data mapping table 
//                                                     header (optional parameter, its default value 
//                                                     is formed as follows: "Catalog: <catalog synonym>").
//     * ObjectName								 - String - an object name.
//
Function ImportFromFileParameters(CatalogMetadata = Undefined) Export
	
	RequiredTemplateColumns = New Array;
	For each Attribute In CatalogMetadata.Attributes Do
		If Attribute.FillChecking=FillChecking.ShowError Then
			RequiredTemplateColumns.Add(Attribute.Name);
		EndIf;
	EndDo;
		
	DefaultParameters = New Structure;
	DefaultParameters.Insert("Title", CatalogMetadata.Presentation());
	DefaultParameters.Insert("RequiredColumns", RequiredTemplateColumns);
	DefaultParameters.Insert("ColumnDataType", New Map);
	Return DefaultParameters;
EndFunction

// Reports the details required for importing data from a file for an external data processor.
//
// Parameters:
//    CommandName - String - a command name (ID).
//    DataProcessorRef - Ref - a link to the data processor.
//    DataStructureTemplateName - String - a name of the template with the column layout used for data import.
// Returns
//  Structure - contains structure with the following properties:
//     * Presentation - String - a presentation in the list of import options.
//     * DataStructureTemplateName - String - a name of the template that stores the data structure 
//                                                          (optional parameter, its default value is ImportDataFromFile).
//     * RequiredTemplateColumns - Array - contains the list of required fields.
//     * MappingColumnHeader - String - a mapping column presentation in the data mapping table 
//                                                           header (an optional parameter, its 
//                                                           default value is formed as follows: 
//                                                           "Catalog: <catalog synonym>").
//     * Object name - String - an object name.
//
Procedure ParametersOfImportFromFileExternalDataProcessor(CommandName, DataProcessorRef, ImportParameters) Export
	
	If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		ModuleAdditionalReportsAndDataProcessors = Common.CommonModule("AdditionalReportsAndDataProcessors");
		ExternalObject = ModuleAdditionalReportsAndDataProcessors.ExternalDataProcessorObject(DataProcessorRef);
		ExternalObject.GetDataImportFromFileParameters(CommandName, ImportParameters);
		ImportParameters.Insert("Template", ExternalObject.GetTemplate(ImportParameters.DataStructureTemplateName));
	EndIf;
	
EndProcedure

#EndRegion

#Region UtilityFunctions

// Reports the details required for importing data from a file into the Tabular section.
Function FileToTSImportParameters(TabularSectionName, AdditionalParameters)
	
	DefaultParameters= New Structure;
	DefaultParameters.Insert("RequiredColumns", New Array);
	DefaultParameters.Insert("DataStructureTemplateName", "ImportFromFile");
	DefaultParameters.Insert("TabularSectionName", TabularSectionName);
	DefaultParameters.Insert("ColumnDataType", New Map);
	DefaultParameters.Insert("AdditionalParameters", AdditionalParameters);
	
	Return DefaultParameters;
	
EndFunction

Procedure CreateCatalogsListForImport(CatalogsListForImport) Export
	
	StringType = New TypeDescription("String");
	BooleanType = New TypeDescription("Boolean");

	CatalogsInformation = New ValueTable;
	CatalogsInformation.Columns.Add("FullName", StringType);
	CatalogsInformation.Columns.Add("Presentation", StringType);
	CatalogsInformation.Columns.Add("AppliedImport", BooleanType);
	
	For each MetadataObjectForOutput In Metadata.Catalogs Do
		If NOT CatalogContainsExclusionAttribute(MetadataObjectForOutput) Then
			Row = CatalogsInformation.Add();
			Row.Presentation = MetadataObjectForOutput.Presentation();
			Row.FullName = MetadataObjectForOutput.FullName();
		EndIf;
	EndDo;
	
	SSLSubsystemsIntegration.OnDefineCatalogsForDataImport(CatalogsInformation);
	ImportDataFromFileOverridable.OnDefineCatalogsForDataImport(CatalogsInformation);
	
	CatalogsInformation.Columns.Add("ImportTypeInformation");
	
	For each CatalogInformation In CatalogsInformation Do
		ImportTypeInformation = New Structure;
		If CatalogInformation.AppliedImport Then
			ImportTypeInformation.Insert("Type", "AppliedImport");
		Else
			ImportTypeInformation.Insert("Type", "UniversalImport");
		EndIf;
		ImportTypeInformation.Insert("FullMetadataObjectName", CatalogInformation.FullName);
		CatalogInformation.ImportTypeInformation = ImportTypeInformation;
	EndDo;
	
	If Common.SubsystemExists("StandardSubsystems.AdditionalReportsAndDataProcessors") Then
		ModuleAdditionalReportsAndDataProcessors = Common.CommonModule("AdditionalReportsAndDataProcessors");
		Query = ModuleAdditionalReportsAndDataProcessors.NewQueryByAvailableCommands(Enums["AdditionalReportsAndDataProcessorsKinds"].AdditionalDataProcessor,
			Undefined, False, Enums["AdditionalDataProcessorsCallMethods"].ImportDataFromFile);
		CommandsTable = Query.Execute().Unload();
		
		For Each TableRow In CommandsTable Do
			ImportTypeInformation = New Structure("Type", "ExternalImport");
			ImportTypeInformation.Insert("FullMetadataObjectName", TableRow.Modifier);
			ImportTypeInformation.Insert("Ref", TableRow.Ref);
			ImportTypeInformation.Insert("ID", TableRow.ID);
			ImportTypeInformation.Insert("Presentation", TableRow.Presentation);
			
			Row = CatalogsInformation.Add();
			Row.FullName = MetadataObjectForOutput.FullName();
			Row.ImportTypeInformation = ImportTypeInformation;
			Row.Presentation = TableRow.Presentation;
		EndDo;
	EndIf;
	
	CatalogsListForImport.Clear();
	For each Row In CatalogsInformation Do 
		CatalogsListForImport.Add(Row.ImportTypeInformation, Row.Presentation);
	EndDo;
		
	CatalogsListForImport.SortByPresentation();
	
EndProcedure 

Function CatalogContainsExclusionAttribute(Catalog)
	
	For each Attribute In Catalog.TabularSections Do
		If Attribute.Name <> "ContactInformation"
			AND Attribute.Name <> "AdditionalAttributes"
			AND Attribute.Name <> "EncryptionCertificates" Then
				Return True;
		EndIf;
	EndDo;
	
	For each Attribute In Catalog.Attributes Do 
		For each AttributeType In Attribute.Type.Types() Do
			If AttributeType = Type("ValueStorage") Then
				Return True;
			EndIf;
		EndDo;
	EndDo;
	
	If Upper(Left(Catalog.Name, 7)) = "DELETE" Then
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

#Region RefsSearch

Procedure SetInsertModeFromClipboard(TemplateWithData, ColumnsInformation, TypesDetails) Export
	ColumnsMap = New Map;
	ColumnHeader    = "";
	Separator         = "";
	ObjectsTypesSupportingInputByString = ObjectsTypesSupportingInputByString();
	
	For each Type In TypesDetails.Types() Do
		MetadataObject = Metadata.FindByType(Type);
		
		If MetadataObject <> Undefined Then
			ObjectStructure = SplitFullObjectName(MetadataObject.FullName());
			
			If ObjectsTypesSupportingInputByString[ObjectStructure.ObjectType] = True Then
				
				For each Column In MetadataObject.InputByString Do
					
					If ColumnsMap.Get(Column.Name) = Undefined Then
						ColumnHeader = ColumnHeader + Separator + Column.Name;
						Separator = ", ";
						ColumnsMap.Insert(Column.Name, Column.Name);
					EndIf;
					
				EndDo;
				
			EndIf;
			
			If ObjectStructure.ObjectType = "Document" Then
				ColumnHeader = ColumnHeader + Separator + "Presentation";
			EndIf;
		EndIf;
		
		ColumnHeader = NStr("ru = 'Введенные данные'; en = 'Entered data'; pl = 'Wprowadzone dane';es_ES = 'Datos introducidos';es_CO = 'Datos introducidos';tr = 'Girilen veri';it = 'Dati inseriti';de = 'Daten eingegeben'");
		
	EndDo;
	
	AddInformationByColumn(ColumnsInformation, "References", ColumnHeader, New TypeDescription("String"), False, 1);
	
	Header = HeaderOfTemplateForFillingColumnsInformation(ColumnsInformation);
	TemplateWithData.Clear();
	TemplateWithData.Put(Header);
	
EndProcedure

Function ObjectsTypesSupportingInputByString()
	
	ObjectsList = New Map;
	ObjectsList.Insert("BusinessProcess",          True);
	ObjectsList.Insert("Document",               True);
	ObjectsList.Insert("Task",                 True);
	ObjectsList.Insert("ChartOfCalculationTypes",       True);
	ObjectsList.Insert("ChartOfCharacteristicTypes", True);
	ObjectsList.Insert("ExchangePlan",             True);
	ObjectsList.Insert("ChartOfAccounts",             True);
	ObjectsList.Insert("Catalog",             True);
	
	Return ObjectsList;
	
EndFunction

Procedure MapAutoColumnValue(MappingTable, ColumnName) Export
	
	Types = MappingTable.Columns.MappingObject.ValueType.Types();
	ObjectsTypesSupportingInputByString = ObjectsTypesSupportingInputByString();
	
	QueryText = "";
	For each Type In Types Do
		MetadataObject = Metadata.FindByType(Type);
		If MetadataObject <> Undefined AND AccessRight("Read", MetadataObject) Then
			ObjectStructure = SplitFullObjectName(MetadataObject.FullName());
			
			ColumnsArray = New Array;
			If ObjectsTypesSupportingInputByString[ObjectStructure.ObjectType] = True Then
				For each Field In MetadataObject.InputByString Do
					ColumnsArray.Add(Field.Name);
				EndDo;
				If ObjectStructure.ObjectType = "Document" Then
					ColumnsArray.Add("Ref");
				EndIf;
			EndIf;
			
			QueryText = QueryString(QueryText, ObjectStructure.ObjectType,
			ObjectStructure.ObjectName, ColumnsArray);
		EndIf;
	EndDo;
	
	For each Row In MappingTable Do 
		If NOT ValueIsFilled(Row[ColumnName]) Then 
			Continue;
		EndIf;
		
		If ValueIsFilled(QueryText) Then
			Value = DocumentByPresentation(Row[ColumnName], Types);
			If Value = Undefined Then
				Value = Row[ColumnName];
			EndIf;
			RefsArray = FindRefsByFilterParameters(QueryText, Value);
			If RefsArray.Count() = 1 Then
				Row.MappingObject = RefsArray[0];
				Row.RowMappingResult = "RowMapped";
			ElsIf RefsArray.Count() > 1 Then
				Row.ConflictsList.LoadValues(RefsArray);
				Row.RowMappingResult = "Conflict";
			Else
				Row.RowMappingResult = "NotMapped";
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

// Recognizes the document by presentation for reference search mode.
//
Function DocumentByPresentation(Presentation, Types)
	
	For each Type In Types Do
		MetadataObject = Metadata.FindByType(Type);
		If MetadataObject = Undefined Then
			Continue;
		EndIf;
		ObjectNameStructure = SplitFullObjectName(MetadataObject.FullName());
		If ObjectNameStructure.ObjectType <> "Document" Then
			Continue;
		EndIf;
		
		StandardProperties = New Structure("ObjectPresentation, ExtendedObjectPresentation, ListPresentation, ExtendedListPresentation");
		FillPropertyValues(StandardProperties, MetadataObject);
		
		If ValueIsFilled(StandardProperties.ObjectPresentation) Then
			ItemPresentation = StandardProperties.ObjectPresentation;
		ElsIf ValueIsFilled(StandardProperties.ExtendedObjectPresentation) Then
			ItemPresentation = StandardProperties.ExtendedObjectPresentation;
		Else
			ItemPresentation = MetadataObject.Presentation();
		EndIf;
		
		If StrFind(Presentation, ItemPresentation) > 0 Then
			PresentationNumberAndDate = TrimAll(Mid(Presentation, StrLen(ItemPresentation) + 1));
			NumberEndPosition = StrFind(PresentationNumberAndDate, " ");
			Number = Left(PresentationNumberAndDate, NumberEndPosition - 1);
			PositionFrom = StrFind(Lower(PresentationNumberAndDate), "from");
			PresentationDate = TrimL(Mid(PresentationNumberAndDate, PositionFrom + 2));
			DateEndPosition = StrFind(PresentationDate, " ");
			DateRoundedToDay = Left(PresentationDate, DateEndPosition - 1) + " 00:00:00";
			NumberDocument = Number;
			DocumentDate = StringFunctionsClientServer.StringToDate(DateRoundedToDay);
		EndIf;
		
		SetPrivilegedMode(True);
		Document = Documents[MetadataObject.Name].FindByNumber(NumberDocument, DocumentDate);
		SetPrivilegedMode(False);
		
		If Document = Undefined OR Document = Documents[MetadataObject.Name].EmptyRef() Then
			Return Undefined;
		EndIf;
		
		Query = New Query; // Document availability check considering restrictions on the record level.
		Query.Text = 
			"SELECT ALLOWED
			|	DocumentToCheck.Ref
			|FROM
			|	Document." + MetadataObject.Name + " AS DocumentToCheck
			|WHERE
			|	DocumentToCheck.Ref = &Ref";
		
		Query.SetParameter("Ref", Document.Ref);
		QueryResult = Query.Execute().Select();
		
		If QueryResult.Next() Then
			Return Document;
		EndIf;
	EndDo;
	
	Return Undefined;
	
EndFunction

Function QueryString(QueryText, ObjectType, ObjectName, ColumnsArray)
	
	If ColumnsArray.Count() > 0 Then
		WhereText = "";
		WhereSeparator = "";
		For Each Field In ColumnsArray Do 
			WhereText = WhereText + WhereSeparator + ObjectName + "." + Field + " = &SearchParameter";
			WhereSeparator = " OR ";
		EndDo;
		
		AllowedText = ?(IsBlankString(QueryText), "ALLOWED ", "");
		TextPattern = "SELECT " + AllowedText + "%1.Ref AS ObjectRef FROM %2.%1 AS %1 WHERE " + WhereText;
		If ValueIsFilled(QueryText) Then 
			UnionAllText = Chars.LF + "UNION ALL" + Chars.LF;
		Else
			UnionAllText = "";
		EndIf;
		QueryText = QueryText + UnionAllText + StringFunctionsClientServer.SubstituteParametersToString(TextPattern, ObjectName, ObjectType);
	EndIf;
	Return QueryText;
	
EndFunction

Function FindRefsByFilterParameters(QueryText, Value)
	Query = New Query(QueryText);
	Query.SetParameter("SearchParameter", Value);
	
	ResultsTable = Query.Execute().Unload();
	ResultingArray = ResultsTable.UnloadColumn("ObjectRef");
	Return ResultingArray;
EndFunction

// Adding information by column for reference search mode.
//
Procedure AddInformationByColumn(ColumnsInformation, Name, Presentation, Type, Required, Position, Folder = "")
	ColumnsInfoRow = ColumnsInformation.Add();
	ColumnsInfoRow.ColumnName = Name;
	ColumnsInfoRow.ColumnPresentation = Presentation;
	ColumnsInfoRow.ColumnType = Type;
	ColumnsInfoRow.Required = Required;
	ColumnsInfoRow.Position = Position;
	ColumnsInfoRow.Group = ?(ValueIsFilled(Folder), Folder, Name);
	ColumnsInfoRow.Visible = True;
EndProcedure

#EndRegion

// Fills in the data mapping value table by template data.
//
Procedure FillMappingTableWithDataFromTemplateBackground(ExportParameters, StorageAddress) Export
	
	TemplateWithData = ExportParameters.TemplateWithData;
	MappingTable = ExportParameters.MappingTable;
	ColumnsInformation = ExportParameters.ColumnsInformation;
	
	MappingTable.Clear();
	FillMappingTableWithDataToImport(TemplateWithData, ColumnsInformation, MappingTable, True);
	
	PutToTempStorage(MappingTable, StorageAddress);
	
EndProcedure

Procedure FillMappingTableWithDataFromTemplate(TemplateWithData, MappingTable, ColumnsInformation) Export
	
	DetermineColumnsPositionsInTemplate(TemplateWithData, ColumnsInformation);
	MappingTable.Clear();
	FillMappingTableWithDataToImport(TemplateWithData, ColumnsInformation, MappingTable);
	
EndProcedure

Procedure FillMappingTableWithDataToImport(TemplateWithData, TableColumnsInformation, MappingTable, BackgroundJob = False)
	
	FirstTableRow = ?(ImportDataFromFileClientServer.ColumnsHaveGroup(TableColumnsInformation), 3, 2);
	
	IDAdjustment = FirstTableRow - 2;
	For RowNumber = FirstTableRow To TemplateWithData.TableHeight Do 
		EmptyTableRow = True;
		NewRow = MappingTable.Add();
		NewRow.ID = RowNumber - 1 - IDAdjustment;
		NewRow.RowMappingResult = "NotMapped";
		
		For ColumnNumber = 1 To TemplateWithData.TableWidth Do
			
			Cell = TemplateWithData.GetArea(RowNumber, ColumnNumber, RowNumber, ColumnNumber).CurrentArea;
			Column = FindColumnInfo(TableColumnsInformation, "Position", ColumnNumber);
			
			If Column <> Undefined Then
				ColumnName = Column.ColumnName;
				DataType = TypeOf(NewRow[ColumnName]);
				
				If DataType <> Type("String") AND DataType <> Type("Boolean") AND DataType <> Type("Number") AND DataType <> Type("Date")  AND DataType <> Type("UUID") Then 
					CellData = CellValue(Column, Cell.Text);
				Else
					CellData = Cell.Text;
				EndIf;
				If EmptyTableRow Then
					EmptyTableRow = NOT ValueIsFilled(CellData);
				EndIf;
				NewRow[ColumnName] = CellData;
			EndIf;
		EndDo;
		If EmptyTableRow Then
			MappingTable.Delete(NewRow);
			IDAdjustment = IDAdjustment + 1;
		EndIf;
		
		If BackgroundJob Then
			Percent = Round(RowNumber *100 / TemplateWithData.TableHeight);
			ModuleTimeConsumingOperations = Common.CommonModule("TimeConsumingOperations");
			ModuleTimeConsumingOperations.ReportProgress(Percent);
		EndIf;
		
	EndDo;
	
EndProcedure

Function CellValue(Column, CellValue)
	
	CellData = "";
	For each DataType In Column.ColumnType.Types() Do 
		Object = Metadata.FindByType(DataType);
		ObjectDetails = SplitFullObjectName(Object.FullName());
		If ObjectDetails.ObjectType = "Catalog" Then
			If NOT Object.Autonumbering AND Object.CodeLength > 0 Then 
				CellData = Catalogs[ObjectDetails.ObjectName].FindByCode(CellValue, True);
			EndIf;
			If NOT ValueIsFilled(CellData) Then 
				CellData = Catalogs[ObjectDetails.ObjectName].FindByDescription(CellValue, True);
			EndIf;
			If NOT ValueIsFilled(CellData) Then 
				CellData = Catalogs[ObjectDetails.ObjectName].FindByCode(CellValue, True);
			EndIf;
		ElsIf ObjectDetails.ObjectType = "Enum" Then 
			For each EnumValue In Enums[ObjectDetails.ObjectName] Do 
				If String(EnumValue) = TrimAll(CellValue) Then 
					CellData = EnumValue; 
				EndIf;
			EndDo;
		ElsIf ObjectDetails.ObjectType = "ChartOfAccounts" Then
			CellData = ChartsOfAccounts[ObjectDetails.ObjectName].FindByCode(CellValue);
			If CellData.IsEmpty() Then 
				CellData = ChartsOfAccounts[ObjectDetails.ObjectName].FindByDescription(CellValue, True);
			EndIf;
		ElsIf ObjectDetails.ObjectType = "ChartOfCharacteristicTypes" Then
			If NOT Object.Autonumbering AND Object.CodeLength > 0 Then 
				CellData = ChartsOfCharacteristicTypes[ObjectDetails.ObjectName].FindByCode(CellValue, True);
			EndIf;
			If NOT ValueIsFilled(CellData) Then 
				CellData = ChartsOfCharacteristicTypes[ObjectDetails.ObjectName].FindByDescription(CellValue, True);
			EndIf;
		Else
			CellData =  String(CellValue);
		EndIf;
		If ValueIsFilled(CellData) Then 
			Break;
		EndIf;
	EndDo;
	
	Return CellData;
	
EndFunction

Procedure DetermineColumnsPositionsInTemplate(TemplateWithData, ColumnsInformation)
	
	HeaderArea = TableTemplateHeaderArea(TemplateWithData);
	
	ColumnsMap = New Map;
	For ColumnNumber = 1 To HeaderArea.TableWidth Do 
		Cell=TemplateWithData.GetArea(1, ColumnNumber, 1, ColumnNumber).CurrentArea;
		ColumnNameInTemplate = Cell.Text;
		ColumnsMap.Insert(ColumnNameInTemplate, ColumnNumber);
	EndDo;
	
	For each Column In ColumnsInformation Do 
		Position = ColumnsMap.Get(Column.ColumnPresentation);
		If Position <> Undefined Then 
			Column.Position = Position;
		Else
			Column.Position = -1;
		EndIf;
	EndDo;
	
EndProcedure


#Region PrepareToImportData

Function TableTemplateHeaderArea(Template)
	
	HeaderHeight = 1;
	For ColumnNumber = 1 To Template.TableWidth Do
		Cell = Template.GetArea(2, ColumnNumber, 2, ColumnNumber).CurrentArea;
		If ValueIsFilled(Cell.Text) Then
			HeaderHeight = 2;
			Break;
		EndIf;
	EndDo;
	TableHeaderArea = Template.GetArea(1, 1, HeaderHeight, Template.TableWidth);
	
	Return TableHeaderArea;
	
EndFunction

// Generates a spreadsheet document template based on catalog attributes for universal import.
//
Procedure ColumnsInformationFromCatalogAttributes(ImportParameters, ColumnsInformation)
	
	ColumnsInformation.Clear();
	Position = 1;
	
	CatalogMetadata= Metadata.FindByFullName(ImportParameters.FullObjectName);
	
	If NOT CatalogMetadata.Autonumbering AND CatalogMetadata.CodeLength > 0  Then
		CreateStandardAttributesColumn(ColumnsInformation, CatalogMetadata, "Code", Position);
		Position = Position + 1;
	EndIf;
	
	If CatalogMetadata.DescriptionLength > 0  Then
		CreateStandardAttributesColumn(ColumnsInformation, CatalogMetadata, "Description", Position);
		Position = Position + 1;
	EndIf;
	
	If CatalogMetadata.Hierarchical Then
		CreateStandardAttributesColumn(ColumnsInformation, CatalogMetadata, "Parent", Position);
		Position = Position + 1;
	EndIf;
	 
	If CatalogMetadata.Owners.Count() > 0 Then
		CreateStandardAttributesColumn(ColumnsInformation, CatalogMetadata, "Owner", Position);
		Position = Position + 1;
	EndIf;
	
	For each Attribute In CatalogMetadata.Attributes Do
		
		If Attribute.Name = "ID" Then
			Continue;
		EndIf;
		
		If Attribute.Type.ContainsType(Type("ValueStorage")) Then
			Continue;
		EndIf;
		
		ColumnTypeDetails = "";
		
		If Attribute.Type.ContainsType(Type("Boolean")) Then 
			ColumnTypeDetails = NStr("ru = 'Флаг, Да или 1 / Нет или 0'; en = 'Check box, Yes or 1 / No or 0'; pl = 'Pole wyboru, Tak lub 1 / Nie lub 0';es_ES = 'Casilla de verificación, Sí o 1 / No o 0';es_CO = 'Casilla de verificación, Sí o 1 / No o 0';tr = 'Onay kutusu, Evet veya 1 / Hayır veya 0';it = 'Casella di controllo, Sì o 1 / No o 0';de = 'Kontrollkästchen, Ja oder 1 / Nein oder 0'");
		ElsIf Attribute.Type.ContainsType(Type("Number")) Then 
			ColumnTypeDetails =  StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Число, Длина: %1, Точность: %2'; en = 'Digit, Length: %1, Accuracy: %2'; pl = 'Cyfra, Długość: %1, Dokładność: %2';es_ES = 'Dígito, Longitud: %1, Exactitud: %2';es_CO = 'Dígito, Longitud: %1, Exactitud: %2';tr = 'Basamak, Uzunluk:%1, Doğruluk:%2';it = 'Digit, Lunghezza: %1, Accuratezza: %2';de = 'Ziffer, Länge: %1, Genauigkeit: %2'"),
				String(Attribute.Type.NumberQualifiers.Digits),
				String(Attribute.Type.NumberQualifiers.FractionDigits));
		ElsIf Attribute.Type.ContainsType(Type("String")) Then
			If Attribute.Type.StringQualifiers.Length > 0 Then
				StringLength = String(Attribute.Type.StringQualifiers.Length);
				ColumnTypeDetails =  StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Строка, макс. количество символов: %1'; en = 'Line, maximum characters: %1'; pl = 'Ciąg, maksimum znaków: %1';es_ES = 'Línea, máximo de símbolos: %1';es_CO = 'Línea, máximo de símbolos: %1';tr = 'Dize, maksimum karakterler:%1';it = 'Linea, massimo caratteri: %1';de = 'Zeichenfolge, maximale Zeichen: %1'"), StringLength);
			Else
				ColumnTypeDetails = NStr("ru = 'Строка неограниченной длины'; en = 'Line of unlimited length'; pl = 'Ciąg o nieograniczonej długości';es_ES = 'Línea de longitud no limitada';es_CO = 'Línea de longitud no limitada';tr = 'Sınırsız uzunluk';it = 'Riga di lunghezza illimitata';de = 'Zeichenfolge von unbegrenzter Länge'");
			EndIf;
		ElsIf Attribute.Type.ContainsType(Type("Date")) Then
			ColumnTypeDetails = String(Attribute.Type.DateQualifiers.DateFractions);
		ElsIf Attribute.Type.ContainsType(Type("UUID")) Then
			ColumnTypeDetails = NStr("ru = 'Уникальный идентификатор'; en = 'UUID'; pl = 'UUID';es_ES = 'UUID';es_CO = 'UUID';tr = 'Evrensel Özgün Tanımlayıcı (UUID)';it = 'UUID';de = 'Eindeutige Kennung'");
		EndIf;
		
		ColumnWidth = ColumnWidthByType(Attribute.Type);
		Tooltip = ?(ValueIsFilled(Attribute.ToolTip), Attribute.ToolTip, Attribute.Presentation()) +  Chars.LF + ColumnTypeDetails;
		RequiredField = ?(Attribute.FillChecking = FillChecking.ShowError, True, False);
		
		ColumnsInfoRow = ColumnsInformation.Add();
		ColumnsInfoRow.ColumnName = Attribute.Name;
		ColumnsInfoRow.ColumnPresentation = Attribute.Presentation();
		ColumnsInfoRow.ColumnType = Attribute.Type;
		ColumnsInfoRow.Required = RequiredField;
		ColumnsInfoRow.Position = Position;
		ColumnsInfoRow.Group = CatalogMetadata.Presentation();
		ColumnsInfoRow.Visible = True;
		ColumnsInfoRow.Comment = Tooltip;
		ColumnsInfoRow.Width = ColumnWidth;

		Position = Position + 1;
		
	EndDo;
	
	If Common.SubsystemExists("StandardSubsystems.ContactInformation") Then
		ModuleContactsManager = Common.CommonModule("ContactsManager");
		ModuleContactsManager.ColumnsForDataImport(CatalogMetadata, ColumnsInformation);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManagerInternal = Common.CommonModule("PropertyManagerInternal");
		ModulePropertyManagerInternal.ColumnsForDataImport(CatalogMetadata, ColumnsInformation);
	EndIf;
	
EndProcedure

// Adding information on a column for a standard attribute upon universal import.
//
Procedure CreateStandardAttributesColumn(ColumnsInformation, CatalogMetadata, ColumnName, Position)
	
	Attribute = CatalogMetadata.StandardAttributes[ColumnName];
	Presentation = CatalogMetadata.StandardAttributes[ColumnName].Presentation();
	DataType = CatalogMetadata.StandardAttributes[ColumnName].Type.Types()[0];
	TypeDetails = CatalogMetadata.StandardAttributes[ColumnName].Type;
	
	ColumnWidth = 11;
	
	If DataType = Type("String") Then 
		TypePresentation = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Строка (не более %1 символов)'; en = 'Line (no more than %1 characters)'; pl = 'Wiersz (nie więcej niż %1 znaki)';es_ES = 'Fila (no más de %1 símbolos)';es_CO = 'Fila (no más de %1 símbolos)';tr = 'Satır (en fazla%1 karakter içermez)';it = 'Linea (non più di %1 caratteri)';de = 'Reihe (nicht mehr als %1 Zeichen)'"), TypeDetails.StringQualifiers.Length);
		ColumnWidth = ?(TypeDetails.StringQualifiers.Length < 30, TypeDetails.StringQualifiers.Length + 1, 30);
	ElsIf DataType = Type("Number") Then
		TypePresentation = NStr("ru = 'Номер'; en = 'Number'; pl = 'Numer';es_ES = 'Número';es_CO = 'Número';tr = 'Numara';it = 'Numero';de = 'Nummer'");
	Else
		If CatalogMetadata.StandardAttributes[ColumnName].Type.Types().Count() = 1 Then 
			TypePresentation = String(DataType); 
		Else
			TypePresentation = "";
			Separator = "";
			For each TypeData In CatalogMetadata.StandardAttributes[ColumnName].Type.Types() Do 
				TypePresentation = TypePresentation  + Separator + String(TypeData);
				Separator = " or ";
			EndDo;
		EndIf;
	EndIf;
	NoteText = Attribute.ToolTip + Chars.LF + TypePresentation;
	
	Required = ?(Attribute.FillChecking = FillChecking.ShowError, True, False);
	ColumnsInfoRow = ColumnsInformation.Add();
	ColumnsInfoRow.ColumnName = ColumnName;
	ColumnsInfoRow.ColumnPresentation = Presentation;
	ColumnsInfoRow.ColumnType = TypeDetails;
	ColumnsInfoRow.Required = Required;
	ColumnsInfoRow.Position = Position;
	ColumnsInfoRow.Group = CatalogMetadata.Presentation();
	ColumnsInfoRow.Visible = True;
	ColumnsInfoRow.Comment = NoteText;
	ColumnsInfoRow.Width = ColumnWidth;
	
EndProcedure

// Determines column content for data import.
//
Procedure DetermineColumnsInformation(ImportParameters, ColumnsInformation, NamesOfColumnsToAdd = Undefined) Export
	
	If ImportParameters.ImportType = "AppliedImport" Then
		
		If ImportParameters.Property("Template") Then
			Template = ImportParameters.Template;
		Else
			Template = ObjectManager(ImportParameters.FullObjectName).GetTemplate("ImportFromFile");
		EndIf;
		
		TableHeaderArea = TableTemplateHeaderArea(Template);
		
		If ColumnsInformation.Count() = 0 Then
			CreateColumnsInformationFromTemplate(TableHeaderArea, ImportParameters, ColumnsInformation, Undefined);
		EndIf;
		
	ElsIf ImportParameters.ImportType = "UniversalImport" Then
		
		ColumnsInformationBasedOnAttributes = ColumnsInformation.CopyColumns();
		
		If ColumnsInformation.Count() = 0 Then
			ColumnsInformationFromCatalogAttributes(ImportParameters, ColumnsInformation);
		Else
			ColumnsInformationFromCatalogAttributes(ImportParameters, ColumnsInformationBasedOnAttributes);
		EndIf;
		
	ElsIf ImportParameters.ImportType = "ExternalImport" Then
		
		TableHeaderArea = TableTemplateHeaderArea(ImportParameters.Template);
		TableHeaderArea.Protection = True;
		
		If ColumnsInformation.Count() = 0 Then
			CreateColumnsInformationFromTemplate(TableHeaderArea, ImportParameters, ColumnsInformation);
		EndIf;
		
	ElsIf ImportParameters.ImportType = "TabularSection" Then
		
		If ColumnsInformation.Count() = 0 Then
			DetermineColumnsInformationTabularSection(ColumnsInformation, Template, TableHeaderArea, ImportParameters);
		Else
			Template = ObjectManager(ImportParameters.FullObjectName).GetTemplate(ImportParameters.Template);
			TableHeaderArea = TableTemplateHeaderArea(Template);
		EndIf;
		
	EndIf;
	
	PositionsRecalculationRequired = False;
	ColumnsListWithFunctionalOptions = ColumnsDependentOnFunctionalOptions(ImportParameters.FullObjectName);
	For each ColumnFunctionalOptionOn In ColumnsListWithFunctionalOptions Do 
		RowWithColumnInformation = ColumnsInformation.Find(ColumnFunctionalOptionOn.Key, "ColumnName");
		If RowWithColumnInformation <> Undefined Then
			If NOT ColumnFunctionalOptionOn.Value Then
				ColumnsInformation.Delete(RowWithColumnInformation);
				PositionsRecalculationRequired = True;
			EndIf;
		Else
			If ColumnFunctionalOptionOn.Value Then
				If ImportParameters.ImportType = "UniversalImport" Then
					RowWithColumn = ColumnsInformationBasedOnAttributes.Find(ColumnFunctionalOptionOn.Key, "ColumnName");
					NewRow = ColumnsInformation.Add();
					FillPropertyValues(NewRow, RowWithColumn);
				Else
					CreateColumnsInformationFromTemplate(TableHeaderArea, ImportParameters, ColumnsInformation, ColumnFunctionalOptionOn.Key);
				EndIf;
				PositionsRecalculationRequired = True;
			EndIf;
		EndIf;
	EndDo;
	
	If PositionsRecalculationRequired Then
		ColumnsInformation.Sort("Position");
		Position = 1;
		For each Column In ColumnsInformation Do
			Column.Position = Position;
			Position = Position + 1;
		EndDo;
	EndIf;
	
EndProcedure

Procedure DetermineColumnsInformationTabularSection(Val ColumnsInformation, Template, TableHeaderArea, Val ImportParameters)
	
	ObjectDescriptionStructure = SplitFullObjectName(ImportParameters.FullObjectName);
	MetadataObjectName = ObjectDescriptionStructure.ObjectType + "." + ObjectDescriptionStructure.ObjectName;
	
	MetadataObject = Metadata.FindByFullName(MetadataObjectName);
	If MetadataObject = Undefined Then
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru='Загрузка данных из файла в табличную часть не поддерживается для объектов типа: %1'; en = 'Data import from file to tabular section is not supported for the objects of type: %1'; pl = 'Pobieranie danych z pliku do części tabelarycznej nie jest obsługiwane dla obiektów typu: %1';es_ES = 'La carga del archivo a la parte de tabla no se admite para los objetos del tipo: %1';es_CO = 'La carga del archivo a la parte de tabla no se admite para los objetos del tipo: %1';tr = 'Dosyadan tablo bölümüne veri aktarma %1 türü nesneler için desteklenmiyor';it = 'Importazione dati da file a sezione tabellare non è supportata per gli oggetti del tipo: %1';de = 'Das Laden von Daten aus einer Datei in das Tabellenteil wird für Objekte des Typs nicht unterstützt: %1'"),
				MetadataObjectName);
		Raise ErrorText;
	EndIf;
	
	MetadataObjectTemplates = MetadataObject.Templates;
	
	ImportFromFileParameters = FileToTSImportParameters(ImportParameters.FullObjectName, ImportParameters.AdditionalParameters);
	ImportFromFileParameters.Insert("FullObjectName", ImportParameters.FullObjectName);
	
	ObjectManager = Common.ObjectManagerByFullName(ImportParameters.FullObjectName);
	ObjectManager.SetFileToTSImportParameters(ImportFromFileParameters);
	
	MetadataTemplate = MetadataObjectTemplates.Find(ImportParameters.Template);
	If MetadataTemplate = Undefined Then
		MetadataTemplate= MetadataObjectTemplates.Find("ImportFromFile" + ObjectDescriptionStructure.TabularSectionName);
		If MetadataTemplate = Undefined Then
			MetadataTemplate = MetadataObjectTemplates.Find("ImportFromFile");
		EndIf;
	EndIf;
	
	If MetadataTemplate <> Undefined Then
		Template = ObjectManager.GetTemplate(MetadataTemplate.Name);
	Else
		Raise NStr("ru = 'Не найден макет для загрузки данных из файла'; en = 'Template for data import from file is not found'; pl = 'Szablon do importu danych z pliku nie został znaleziony';es_ES = 'Modelo para la importación de datos desde el archivo no se ha encontrado';es_CO = 'Modelo para la importación de datos desde el archivo no se ha encontrado';tr = 'Dosyadan veri içe aktarma için şablon bulunamadı';it = 'Nessun layout trovato per il caricamento dei dati dal file';de = 'Vorlage für Datenimport aus Datei wurde nicht gefunden'");
	EndIf;
	
	TableHeader = TableTemplateHeaderArea(Template);
	If ColumnsInformation.Count() = 0 Then
		CreateColumnsInformationFromTemplate(TableHeader, ImportFromFileParameters, ColumnsInformation);
	EndIf;
	
	TableHeaderArea = TableTemplateHeaderArea(Template);

EndProcedure

// Fills in the table on template columns. This information is used for generating a mapping table.
//
// Parameters:
//  TableHeaderArea	 - SpreadsheetDocument - a table header area.
//  ImportFromFileParameters - Structure - import parameters.
//  ColumnsInformation	 - ValueTable - a table with column details.
//  NamesOfColumnsToAdd - String - a comma-separated list of columns. If a value is not filled in, 
//                                      then all values are added.
Procedure CreateColumnsInformationFromTemplate(TableHeaderArea, ImportFromFileParameters, ColumnsInformation, NamesOfColumnsToAdd = Undefined)
	
	SelectiveAddition = False;
	If ValueIsFilled(NamesOfColumnsToAdd) Then
		SelectiveAddition = True;
		ColumnsToAddArray = StrSplit(NamesOfColumnsToAdd, ",", False);
		Position = ColumnsInformation.Count() + 1;
	Else
		ColumnsInformation.Clear();
		Position = 1;
	EndIf;
	
	If ImportFromFileParameters.Property("ColumnDataType") Then
		ColumnsDataTypeMap = ImportFromFileParameters.ColumnDataType;
	Else
		ColumnsDataTypeMap = New Map;
	EndIf;
	
	HeaderHeight = TableHeaderArea.TableHeight;
	If HeaderHeight = 2 Then
		ColumnNumber = 1;
		Groups = New Map;
		GroupUsed = True;
		While ColumnNumber <= TableHeaderArea.TableWidth Do
			Area = TableHeaderArea.GetArea(1, ColumnNumber);
			Cell = TableHeaderArea.GetArea(1, ColumnNumber, 1, ColumnNumber).CurrentArea;
			Folder = Cell.Text;
			For Index = ColumnNumber To ColumnNumber + Area.TableWidth -1 Do
				Groups.Insert(Index, Folder);
			EndDo;
			ColumnNumber = ColumnNumber + Area.TableWidth;
		EndDo;
	Else
		GroupUsed = False;
	EndIf;
	
	For ColumnNumber = 1 To TableHeaderArea.TableWidth Do
		Cell = TableHeaderArea.GetArea(HeaderHeight, ColumnNumber, HeaderHeight, ColumnNumber).CurrentArea;
		
		If StrFind(Cell.Name, "R") > 0 AND StrFind(Cell.Name, "C") > 0 Then
			AttributeName = ?(ValueIsFilled(Cell.DetailsParameter), Cell.DetailsParameter, Cell.Text);
			AttributePresentation = ?(ValueIsFilled(Cell.Text), Cell.Text, Cell.DetailsParameter);
			Parent = ?(ValueIsFilled(Cell.DetailsParameter), Cell.DetailsParameter, Cell.Text);
		Else
			AttributeName = Cell.Name;
			AttributePresentation = ?(ValueIsFilled(Cell.Text), Cell.Text, Cell.Name);
			Parent = ?(ValueIsFilled(Cell.DetailsParameter), Cell.DetailsParameter, Cell.Name);
		EndIf;
		
		If AttributePresentation = NStr("ru = '<Дополнительные реквизиты>'; en = '<Additional attributes>'; pl = '<Dodatkowe rekwizyty>';es_ES = '<Requisitos adicionales>';es_CO = '<Additional attributes>';tr = '<Ek öznitelikler>';it = '<Attributi aggiuntivi>';de = '<Zusätzliche Attribute>'") Then
			CatalogMetadata = Metadata.FindByFullName(ImportFromFileParameters.FullObjectName);
			If Common.SubsystemExists("StandardSubsystems.Properties") Then
				ModulePropertyManagerInternal = Common.CommonModule("PropertyManagerInternal");
				ModulePropertyManagerInternal.ColumnsForDataImport(CatalogMetadata, ColumnsInformation);
			EndIf;
		ElsIf AttributePresentation = NStr("ru = '<Контактная информация>'; en = '<Contact information>'; pl = '<Informacje kontaktowe>';es_ES = '<Contactos>';es_CO = '<Contact information>';tr = '<İletişim bilgileri>';it = '<Informazioni di contatto>';de = '<Kontaktinformationen>'") Then
			CatalogMetadata = Metadata.FindByFullName(ImportFromFileParameters.FullObjectName);
			If Common.SubsystemExists("StandardSubsystems.ContactInformation") Then
				ModuleContactsManager = Common.CommonModule("ContactsManager");
				ModuleContactsManager.ColumnsForDataImport(CatalogMetadata, ColumnsInformation);
			EndIf;
		Else
			ColumnDataType = New TypeDescription("String");
			If ColumnsDataTypeMap <> Undefined Then
				ColumnDataTypeOverridden = ColumnsDataTypeMap.Get(AttributeName);
				If ColumnDataTypeOverridden <> Undefined Then
					ColumnDataType = ColumnDataTypeOverridden;
				EndIf;
			EndIf;
			
			If SelectiveAddition AND ColumnsToAddArray.Find(AttributeName) = Undefined Then
				Continue;
			EndIf;
			
			If ValueIsFilled(AttributeName) Then
				ColumnsInfoRow = ColumnsInformation.Add();
				ColumnsInfoRow.ColumnName = AttributeName;
				ColumnsInfoRow.ColumnPresentation = AttributePresentation;
				ColumnsInfoRow.ColumnType = ColumnDataType;
				ColumnsInfoRow.Required = Cell.Font.Bold;
				ColumnsInfoRow.Position = Position;
				ColumnsInfoRow.Parent = Parent;
				If GroupUsed Then
					ColumnsInfoRow.Group = Groups.Get(ColumnNumber);
				EndIf;
				ColumnsInfoRow.Visible = True;
				ColumnsInfoRow.Comment = Cell.Comment.Text;
				ColumnsInfoRow.Width = Cell.ColumnWidth;
				Position = Position + 1;
			EndIf;
		
		EndIf;
	EndDo;
	
EndProcedure

Function ColumnWidthByType(Type) 
	
	ColumnWidth = 20;
	If Type.ContainsType(Type("Boolean")) Then 
		ColumnWidth = 3;
	ElsIf Type.ContainsType(Type("Number")) Then 
		ColumnWidth = Type.NumberQualifiers.Digits + 1;
	ElsIf Type.ContainsType(Type("String")) Then 
		If Type.StringQualifiers.Length > 0 Then 
			ColumnWidth = ?(Type.StringQualifiers.Length > 20, 20, Type.StringQualifiers.Length);
		Else
			ColumnWidth = 20;
		EndIf;
	ElsIf Type.ContainsType(Type("Date")) Then 
		ColumnWidth = 12;
	ElsIf Type.ContainsType(Type("UUID")) Then 
		ColumnWidth = 20;
	Else
		For each ObjectType In  Type.Types() Do
			ObjectMetadata = Metadata.FindByType(ObjectType);
			ObjectStructure = SplitFullObjectName(ObjectMetadata.FullName());
			If ObjectStructure.ObjectType = "Catalog" Then 
				If NOT ObjectMetadata.Autonumbering AND ObjectMetadata.CodeLength > 0  Then
					ColumnWidth = ObjectMetadata.CodeLength + 1;
				EndIf;
				If ObjectMetadata.DescriptionLength > 0  Then
					If ObjectMetadata.DescriptionLength > ColumnWidth Then
						ColumnWidth = ?(ObjectMetadata.DescriptionLength > 30, 30, ObjectMetadata.DescriptionLength + 1);
					EndIf;
			EndIf;
		ElsIf ObjectStructure.ObjectType = "Enum" Then
				PresentationLength =  StrLen(ObjectMetadata.Presentation());
				ColumnWidth = ?( PresentationLength > 30, 30, PresentationLength + 1);
			EndIf;
		EndDo;
	EndIf;
	
	Return ColumnWidth;
	
EndFunction

Procedure FillTemplateHeaderCell(Cell, Text, Width, Tooltip, RequiredField, Name = "")
	
	Cell.CurrentArea.Text = Text;
	Cell.CurrentArea.Name = Name;
	Cell.CurrentArea.DetailsParameter = Name;
	Cell.CurrentArea.BackColor =  StyleColors.ReportHeaderBackColor;
	Cell.CurrentArea.ColumnWidth = Width;
	Cell.CurrentArea.Comment.Text = Tooltip;
	If RequiredField Then 
		Cell.CurrentArea.Font = New Font(,,True);
	Else
		Cell.CurrentArea.Font = New Font(,,False);
	EndIf;
	
EndProcedure

// Generates a template header by column information.
//
Function HeaderOfTemplateForFillingColumnsInformation(ColumnsInformation) Export

	SpreadsheetDocument = New SpreadsheetDocument;
	ColumnsHaveGroup = ImportDataFromFileClientServer.ColumnsHaveGroup(ColumnsInformation);
	If ColumnsHaveGroup Then
		AreaHeader = GetTemplate("SimpleTemplate").GetArea("Line2Header");
		Line = New Line(SpreadsheetDocumentCellLineType.Solid);
		RowNumber = 2;
	Else
		AreaHeader = GetTemplate("SimpleTemplate").GetArea("Title");
		RowNumber = 1;
	EndIf;
	ColumnsInformation.Sort("Position");
	
	Folder = Undefined;
	PositionGroupStart = 1;
	Offset = 0;
	For Position = 0 To ColumnsInformation.Count() -1 Do
		Column = ColumnsInformation.Get(Position);
		
		If Column.Visible = True Then
			If Folder = Undefined Then
				Folder = Column.Group;
			EndIf;
			ColumnNameArea = AreaHeader.Area(RowNumber, 1, RowNumber, 1);
			ColumnNameArea.Name = Column.ColumnName;
			ColumnNameArea.Details = Column.Group;
			ColumnNameArea.Comment.Text = Column.Comment;
			ColumnNameArea.Font = ?(Column.Required, New Font(,, True), New Font(,, False));
			ColumnNameArea.ColumnWidth = ?(Column.Width = 0, ColumnWidthByType(Column.ColumnType), Column.Width);
			AreaHeader.Parameters.Title = ?(IsBlankString(Column.Synonym), Column.ColumnPresentation, Column.Synonym);
			SpreadsheetDocument.Join(AreaHeader);
			
			If ColumnsHaveGroup Then
				If Column.Group <> Folder Then
					Area = SpreadsheetDocument.Area(1, PositionGroupStart, 1, Position - Offset);
					Area.Text = Folder;
					Area.Merge();
					Area.Outline(Line, Line, Line,Line);
					PositionGroupStart = Position + 1 - Offset ;
					Folder = Column.Group;
				ElsIf IsBlankString(Column.Group) Then
					Area = SpreadsheetDocument.Area(1, PositionGroupStart, RowNumber, Position - Offset);
					Area.Merge();
				EndIf;
			EndIf;
		Else
			Offset = Offset + 1;
		EndIf;
	EndDo;
	If ColumnsHaveGroup Then
		Area = SpreadsheetDocument.Area(1, PositionGroupStart, 1, Position - Offset);
		Area.Text = Folder;
		Area.Merge();
		Area.Outline(Line, Line, Line,Line);
	EndIf;
	
	Return SpreadsheetDocument;
EndFunction

#EndRegion

// Creates a value table by the template data and saves it to a temporary storage.
//
Procedure SpreadsheetDocumentIntoValuesTable(TemplateWithData, ColumnsInformation, ImportedDataAddress) Export
	
	TypeDescriptionNumber  = New TypeDescription("Number");
	StringTypeDetails = New TypeDescription("String");
	
	TableColumnsInformation = ColumnsInformation.Copy();
	DataToImport = New ValueTable;
	
	For each Column In TableColumnsInformation Do
		ColumnType = ?(Column.ColumnType.Types()[0] = Type("Date"), Column.ColumnType, StringTypeDetails);
		DataToImport.Columns.Add(Column.ColumnName, ColumnType, Column.ColumnPresentation);
	EndDo;
	
	DataToImport.Columns.Add("ID",                TypeDescriptionNumber,  "ID");
	DataToImport.Columns.Add("RowMappingResult", StringTypeDetails, "Result");
	DataToImport.Columns.Add("ErrorDescription",               StringTypeDetails, "Reason");
	
	IDAdjustment = 0;
	HeaderHeight = ?(ImportDataFromFileClientServer.ColumnsHaveGroup(TableColumnsInformation), 2, 1);
	
	InitializeColumns(TableColumnsInformation, TemplateWithData, HeaderHeight);
	
	For RowNumber = HeaderHeight + 1 To TemplateWithData.TableHeight Do
		EmptyTableRow = True;
		NewRow               = DataToImport.Add();
		NewRow.ID =  RowNumber - IDAdjustment - 1;
		For ColumnNumber = 1 To TemplateWithData.TableWidth Do
			Cell = TemplateWithData.GetArea(RowNumber, ColumnNumber, RowNumber, ColumnNumber).CurrentArea;
			
			FoundColumn = FindColumnInfo(TableColumnsInformation, "Position", ColumnNumber);
			If FoundColumn <> Undefined Then
				ColumnName = FoundColumn.ColumnName;
				NewRow[ColumnName] = AdjustValueToType(Cell.Text, FoundColumn.ColumnType);
				If EmptyTableRow Then
					EmptyTableRow = Not ValueIsFilled(Cell.Text);
				EndIf;
			EndIf;
		EndDo;
		If EmptyTableRow Then
			DataToImport.Delete(NewRow);
			IDAdjustment = IDAdjustment + 1;
		EndIf;
	EndDo;
	
	ImportedDataAddress = PutToTempStorage(DataToImport);
EndProcedure

Function AdjustValueToType(Value, TypesDetails)
	For each Type In TypesDetails.Types() Do
		If Type = Type("Date") Then
			Return StringFunctionsClientServer.StringToDate(Value);
		ElsIf Type = Type("Number") Then
			TypeDescriptionNumber = New TypeDescription("Number");
			Return TypeDescriptionNumber.AdjustValue(Value);
		EndIf;
	EndDo;
	
	Return Value;
	
EndFunction

Procedure FillTableByDataToImportFromFile(DataFromFile, TemplateWithData, ColumnsInformation)
	
	RowHeader= DataFromFile.Get(0);
	ColumnsMap = New Map;
	
	For each Column In DataFromFile.Columns Do
		FoundColumn = FindColumnInfo(ColumnsInformation, "Synonym", RowHeader[Column.Name]);
		If FoundColumn = Undefined Then
			FoundColumn = FindColumnInfo(ColumnsInformation, "ColumnPresentation", RowHeader[Column.Name]);
		EndIf;
		If FoundColumn <> Undefined Then
			ColumnsMap.Insert(FoundColumn.Position, Column.Name);
		EndIf;
	EndDo;
	
	For Index= 1 To DataFromFile.Count() - 1 Do
		SpecificationRow = DataFromFile.Get(Index);
		NewRow = True;
		For ColumnNumber =1 To TemplateWithData.TableWidth Do
			TableColumn = ColumnsMap.Get(ColumnNumber);
			Column = ColumnsInformation.Find(ColumnNumber, "Position");
			If Column <> Undefined AND Column.Visible = False Then
				Continue;
			EndIf;
			Cell = TemplateWithData.GetArea(2, ColumnNumber, 2, ColumnNumber);
			If TableColumn <> Undefined Then 
				Cell.CurrentArea.Text = SpecificationRow[TableColumn];
				Cell.CurrentArea.TextPlacement = SpreadsheetDocumentTextPlacementType.Cut;
			Else
				Cell.CurrentArea.Text = "";
			EndIf;
			If NewRow Then
				TemplateWithData.Put(Cell);
				NewRow = False;
			Else
				TemplateWithData.Join(Cell);
			EndIf;
		EndDo;
	EndDo;
	
EndProcedure

Function FindColumnInfo(TableColumnsInformation, ColumnName, Value)
	
	Filter = New Structure(ColumnName, Value);
	FoundColumns = TableColumnsInformation.FindRows(Filter);
	Column = Undefined;
	If FoundColumns.Count() > 0 Then 
		Column = FoundColumns[0];
	EndIf;
	
	Return Column;
EndFunction

Function FullTabularSectionObjectName(ObjectName) Export
	
	Result = StrSplit(ObjectName, ".", False);
	If Result.Count() = 4 Then
			Object = Metadata.FindByFullName(ObjectName);
			If Object <> Undefined Then 
				Return ObjectName;
			EndIf;
	ElsIf Result.Count() = 3 Then
		If Result[2] <> "TabularSection" Then 
			ObjectName = Result[0] + "." + Result[1] + ".TabularSection." + Result[2];
			Object = Metadata.FindByFullName(ObjectName);
			If Object <> Undefined Then 
				Return ObjectName;
			EndIf;
		ElsIf Result[1] = "TabularSection" Then 
			ObjectName = "Document." + Result[0] + ".TabularSection." + Result[2];
			Object = Metadata.FindByFullName(ObjectName);
			If Object <> Undefined Then 
				Return ObjectName;
			EndIf;
			ObjectName = "Catalog." + Result[0] + ".TabularSection." + Result[2];
			Object = Metadata.FindByFullName(ObjectName);
			If Object <> Undefined Then 
				Return ObjectName;
			EndIf;
			Return Undefined;
		EndIf;
		
		Return Undefined;
	ElsIf Result.Count() = 2 Then
		If Result[0] <> "Document" OR Result[0] <> "Catalog" Then 
			ObjectName = "Document." + Result[0] + ".TabularSection." + Result[1];
			Object = Metadata.FindByFullName(ObjectName);
			If Object <> Undefined Then 
				Return ObjectName;
			EndIf;
			ObjectName = "Catalog." + Result[0] + ".TabularSection." + Result[1];
			Object = Metadata.FindByFullName(ObjectName);
			If Object <> Undefined Then 
				Return ObjectName;
			EndIf;
			Return Undefined;
		EndIf;
		MetadataObjectName = Result[0];
		MetadataObjectType = Metadata.Catalogs.Find(MetadataObjectName);
		If MetadataObjectType <> Undefined Then 
			MetadataObjectType = "Catalog";
		Else
			MetadataObjectType = Metadata.Documents.Find(MetadataObjectName);
			If MetadataObjectType <> Undefined Then 
				MetadataObjectType = "Document";
			Else 
				Return Undefined;
			EndIf;
		EndIf;
	EndIf;
	
	Return Undefined;
	
EndFunction

// Returns an object name as a structure.
//
// Parameters:
//	FullObjectName - Structure - an object name.
//		* ObjectType - String - an object type.
//		* ObjectName - String - an object name.
//		* TabularSectionName - String - a tabular section name.
Function SplitFullObjectName(FullObjectName) Export
	Result = StrSplit(FullObjectName, ".", False);
	
	ObjectName = New Structure;
	ObjectName.Insert("FullObjectName", FullObjectName);
	ObjectName.Insert("ObjectType");
	ObjectName.Insert("ObjectName");
	ObjectName.Insert("TabularSectionName");
	
	If Result.Count() = 2 Then
		If Result[0] = "Document" OR Result[0] = "Catalog" OR Result[0] = "BusinessProcess" 
			OR Result[0] = "Enum" OR Result[0] = "ChartOfCharacteristicTypes"
			OR Result[0] = "ChartOfAccounts" Then
				ObjectName.ObjectType = Result[0];
				ObjectName.ObjectName = Result[1];
		Else
				ObjectName.ObjectType = GetMetadataObjectTypeByName(Result[0]);
				ObjectName.ObjectName = Result[0];
				ObjectName.TabularSectionName = Result[1];
		EndIf;
	ElsIf Result.Count() = 3 Then
		ObjectName.ObjectType = Result[0];
		ObjectName.ObjectName = Result[1];
		ObjectName.TabularSectionName = Result[2];
	ElsIf Result.Count() = 4 Then 
		ObjectName.ObjectType = Result[0];
		ObjectName.ObjectName = Result[1];
		ObjectName.TabularSectionName = Result[3];
	ElsIf Result.Count() = 1 Then
		ObjectName.ObjectType = GetMetadataObjectTypeByName(Result[0]);
		ObjectName.ObjectName = Result[0];
	EndIf;

	Return ObjectName;
	
EndFunction

Function GetMetadataObjectTypeByName(Name)
	For each Object In Metadata.Catalogs Do 
		If Object.Name = Name Then 
			Return "Catalog";
		EndIf;
	EndDo;
	
	For each Object In Metadata.Documents Do 
		If Object.Name = Name Then 
			Return "Document";
		EndIf;
	EndDo;
	
	Return Undefined;
EndFunction

Function ObjectManager(MappingObjectName)
		ObjectArray = SplitFullObjectName(MappingObjectName);
		If ObjectArray.ObjectType = "Document" Then
			ObjectManager = Documents[ObjectArray.ObjectName];
		ElsIf ObjectArray.ObjectType = "Catalog" Then
			ObjectManager = Catalogs[ObjectArray.ObjectName];
		Else
			Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Объект ""%1"" не найден'; en = '%1 object is not found'; pl = 'Obiekt ""%1"" nie został znaleziony.';es_ES = 'Objeto ""%1"" no se ha encontrado';es_CO = 'Objeto ""%1"" no se ha encontrado';tr = '""%1"" Nesnesi bulunamadı';it = '%1 oggetto non trovato';de = 'Objekt ""%1"" wird nicht gefunden'"), MappingObjectName);
		EndIf;
		
		Return ObjectManager;
EndFunction

/////////////// Data import //////////////////////////

Procedure InitializeColumns(ColumnsInformation, TemplateWithData, HeaderHeight = 1)
	
	For each Row In ColumnsInformation Do
		Row.Position = -1;
	EndDo;
	
	For ColumnNumber = 1 To TemplateWithData.TableWidth Do
		CellHeader = TemplateWithData.GetArea(HeaderHeight, ColumnNumber, HeaderHeight, ColumnNumber).CurrentArea;
		
		If ValueIsFilled(CellHeader.Text) Then
			Filter = New Structure("Synonym", TrimAll(CellHeader.Text));
			FoundColumn = ColumnsInformation.FindRows(Filter);
			If FoundColumn.Count() > 0 Then
				FoundColumn[0].Position = ColumnNumber;
			Else
				Filter = New Structure("ColumnPresentation",  TrimAll(CellHeader.Text));
				FoundColumn = ColumnsInformation.FindRows(Filter);
				If FoundColumn.Count() > 0 Then
					FoundColumn[0].Position = ColumnNumber;
				EndIf;
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

Procedure ImportFileToTable(ServerCallParameters, StorageAddress) Export
	
	Extension = ServerCallParameters.Extension;
	TemplateWithData = ServerCallParameters.TemplateWithData;
	TempFileName = ServerCallParameters.TempFileName;
	ColumnsInformation = ServerCallParameters.ColumnsInformation;
	
	If Extension = "csv" Then
		ImportCSVFileToTable(TempFileName, TemplateWithData, ColumnsInformation);
	Else
		ImportedTemplateWithData = New SpreadsheetDocument;
		ImportedTemplateWithData.Read(TempFileName);
		
		RowNumberWithTableHeader = ?(ImportDataFromFileClientServer.ColumnsHaveGroup(ColumnsInformation), 2, 1);
		
		Address = "";
		SpreadsheetDocumentIntoValuesTable(ImportedTemplateWithData, ColumnsInformation, Address);
		ImportedData = GetFromTempStorage(Address);
		
		OutputArea = TemplateWithData.GetArea(RowNumberWithTableHeader + 1, 1, RowNumberWithTableHeader + 1, ImportedData.Columns.Count());
		
		For Counter = 1 To ImportedData.Columns.Count() Do
			FillingArea = OutputArea.Area(1, Counter, 1, Counter);
			Column = ColumnsInformation.Find(Counter, "Position");
			If Column <> Undefined AND Column.Visible Then
				FillingArea.Parameter = Column.ColumnName;
				FillingArea.FillType = SpreadsheetDocumentAreaFillType.Parameter;
			EndIf;
		EndDo;
		
		TotalRows = ImportedData.Count();
		RowNumber = 1;
		For Each Selection In ImportedData Do
			SetProgressPercent(TotalRows, RowNumber);
			OutputArea.Parameters.Fill(Selection);
			TemplateWithData.Put(OutputArea);
			RowNumber = RowNumber + 1;
		EndDo;
		
	EndIf;
	
	StorageAddress = PutToTempStorage(TemplateWithData, StorageAddress);
	
	ImportDataFromFile.DeleteTempFile(TempFileName);
	
EndProcedure

#Region CSVFilesOperations

Procedure ImportCSVFileToTable(FileName, TemplateWithData, ColumnsInformation)
	
	File = New File(FileName);
	If NOT File.Exist() Then 
		Return;
	EndIf;
	
	TextReader = New TextReader(FileName);
	Row = TextReader.ReadLine();
	If Row = Undefined Then 
		MessageText = NStr("ru = 'Не получилось загрузить данные из этого файла. Убедитесь в корректности данных в файле.'; en = 'Cannot import data from this file. Make sure that data in the file is correct.'; pl = 'Nie można zaimportować danych z tego pliku. Upewnij się, że dane w pliku są poprawne.';es_ES = 'No se puede importar los datos desde este archivo. Asegurarse de que los datos en el archivo sean correctos.';es_CO = 'No se puede importar los datos desde este archivo. Asegurarse de que los datos en el archivo sean correctos.';tr = 'Bu dosyadan veri alınamıyor. Dosyadaki verilerin doğru olduğundan emin olun.';it = 'Non è stato possibile scaricare i dati da questo file. Assicurarsi che i dati nel file siano corretti.';de = 'Kann Daten aus dieser Datei nicht importieren. Stellen Sie sicher, dass die Daten in der Datei korrekt sind.'");
		Raise MessageText;
	EndIf;
	
	HeaderColumns = StrSplit(Row, ";", False);
	Source = New ValueTable;
	ColumnPositionInFile = New Map();
	
	Position = 1;
	For each Column In HeaderColumns Do
		FoundColumn = FindColumnInfo(ColumnsInformation, "Synonym", Column);
		If FoundColumn = Undefined Then
			FoundColumn = FindColumnInfo(ColumnsInformation, "ColumnPresentation", Column);
		EndIf;
		If FoundColumn <> Undefined Then
			NewColumn = Source.Columns.Add();
			NewColumn.Name = FoundColumn.ColumnName;
			NewColumn.Title = Column;
			ColumnPositionInFile.Insert(Position, NewColumn.Name);
			Position = Position + 1;
		EndIf;
	EndDo;
	
	If Source.Columns.Count() = 0 Then
		Return;
	EndIf;
	
	While Row <> Undefined Do
		NewRow = Source.Add();
		Position = StrFind(Row, ";");
		Index = 0;
		While Position > 0 Do
			If Source.Columns.Count() < Index + 1 Then
				Break;
			EndIf;
			ColumnName = ColumnPositionInFile.Get(Index + 1);
			If ColumnName <> Undefined Then
				NewRow[ColumnName] = Left(Row, Position - 1);
			EndIf;
			Row = Mid(Row, Position + 1);
			Position = StrFind(Row, ";");
			Index = Index + 1;
		EndDo;
		If Source.Columns.Count() = Index + 1  Then
			NewRow[Index] = Row;
		EndIf;

		Row = TextReader.ReadLine();
	EndDo;
	
	FillTableByDataToImportFromFile(Source, TemplateWithData, ColumnsInformation);
	
EndProcedure

Procedure SaveTableToCSVFile(PathToFile, ColumnsInformation) Export
	
	HeaderFormatForCSV = "";
	
	For each Column In ColumnsInformation Do 
		HeaderFormatForCSV = HeaderFormatForCSV + Column.ColumnPresentation + ";";
	EndDo;
	
	If StrLen(HeaderFormatForCSV) > 0 Then
		HeaderFormatForCSV = Left(HeaderFormatForCSV, StrLen(HeaderFormatForCSV)-1);
	EndIf;
	
	File = New TextWriter(PathToFile);
	File.WriteLine(HeaderFormatForCSV);
	File.Close();
	
EndProcedure

#EndRegion

#Region TimeConsumingOperations

// Recording mapped data to the application.
//
Procedure WriteMappedData(ExportParameters, StorageAddress) Export
	
	MappedData = ExportParameters.MappedData;
	MappingObjectName =ExportParameters.MappingObjectName;
	ImportParameters = ExportParameters.ImportParameters;
	ColumnsInformation = ExportParameters.ColumnsInformation;
	
	CreateIfUnmapped = ImportParameters.CreateIfUnmapped;
	UpdateExistingItems = ImportParameters.UpdateExistingItems;
	
	CatalogName = SplitFullObjectName(MappingObjectName).ObjectName;
	CatalogManager = Catalogs[CatalogName];
	
	AccessManagementUsed = False;
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement       = Common.CommonModule("AccessManagement");
		AccessManagementUsed = True;
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ContactInformation") Then
		ModuleContactsManager = Common.CommonModule("ContactsManager");
		ContactInformationKinds = ModuleContactsManager.ObjectContactInformationKinds(Catalogs[CatalogName].EmptyRef());
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.Properties") Then
		Properties = New Map;
		ModulePropertyManager = Common.CommonModule("PropertyManager");
		EmptyRefToObject = Catalogs[CatalogName].EmptyRef();
		If ModulePropertyManager.UseAddlAttributes(EmptyRefToObject)
			OR ModulePropertyManager.UseAddlInfo(EmptyRefToObject) Then
			PropertiesList = ModulePropertyManager.ObjectProperties(EmptyRefToObject);
			For each Property In PropertiesList Do
				Properties.Insert(Property.Description, Property);
			EndDo;
		EndIf;
	EndIf;
	
	PropertiesTable = New ValueTable;
	PropertiesTable.Columns.Add("Property");
	PropertiesTable.Columns.Add("Value");
	
	RowNumber = 0;
	TotalRows = MappedData.Count();
	For each TableRow In MappedData Do
		
		ClearContactInfo = False;
		RowNumber = RowNumber + 1;
		
		If (ValueIsFilled(TableRow.MappingObject) AND NOT UpdateExistingItems) 
			OR (NOT ValueIsFilled(TableRow.MappingObject) AND NOT CreateIfUnmapped) Then
				TableRow.RowMappingResult = "Skipped";
				SetProgressPercent(TotalRows, RowNumber);
				Continue;
		EndIf;
		
		If AccessManagementUsed Then
			ModuleAccessManagement.DisableAccessKeysUpdate(True);
		EndIf;
		BeginTransaction();
		Try
			If ValueIsFilled(TableRow.MappingObject) Then
				Lock = New DataLock;
				LockItem = Lock.Add("Catalog." + CatalogName);
				LockItem.SetValue("Ref", TableRow.MappingObject);
				
				CatalogItem = TableRow.MappingObject.GetObject();
				TableRow.RowMappingResult = "Updated";
				ClearContactInfo = True;
				If CatalogItem = Undefined Then
					Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Номенклатура с артикулом %1 не существует.'; en = 'Product with product ID %1 does not exist.'; pl = 'Brak produktów z artykułu (SKU) %1.';es_ES = 'No hay productos con SKU %1.';es_CO = 'No hay productos con SKU %1.';tr = '%1 kodlu ürün mevcut değil.';it = 'L''articolo con cod. articolo %1 non esiste.';de = 'Keine Produkte mit Artikelnummer %1.'"),
					TableRow.SKU);
				EndIf;
			Else
				CatalogItem = CatalogManager.CreateItem();
				TableRow.MappingObject = CatalogItem;
				TableRow.RowMappingResult = "Created";
			EndIf;
			
			For each Column In ColumnsInformation Do 
				If Column.Visible Then
					If StrStartsWith(Column.ColumnName, "ContactInformation_") Then
						CIKindName = StandardSubsystemsServer.TransformAdaptedColumnDescriptionToString(Mid(Column.ColumnName, 22));
						ContactInformationKind = ContactInformationKinds.Find(CIKindName, "Description");
						If ClearContactInfo Then
							CatalogItem.ContactInformation.Clear();
							ClearContactInfo = False;
						EndIf;
						If ContactInformationKind <> Undefined Then
							If Common.SubsystemExists("StandardSubsystems.ContactInformation") Then
								ModuleContactsManager = Common.CommonModule("ContactsManager");
								ContactInformationValue = ModuleContactsManager.ContactsByPresentation(TableRow[Column.ColumnName], ContactInformationKind.Ref);
								ModuleContactsManager.WriteContactInformation(CatalogItem, ContactInformationValue, ContactInformationKind.Ref, ContactInformationKind.Type);
							EndIf;
						EndIf;
					ElsIf StrStartsWith(Column.ColumnName, "AdditionalAttribute_") Then
						AddPropertyValue(PropertiesTable, Properties, "AdditionalAttribute_", Column.ColumnName,  TableRow[Column.ColumnName]);
					ElsIf StrStartsWith(Column.ColumnName, "Property_") Then
						AddPropertyValue(PropertiesTable, Properties, "Property_", Column.ColumnName,  TableRow[Column.ColumnName]);
					Else
						CatalogItem[Column.ColumnName] = TableRow[Column.ColumnName];
					EndIf;
				EndIf;
			EndDo;
			
			SetProgressPercent(TotalRows, RowNumber);
			If NOT CatalogItem.CheckFilling() Then
				UserMessages = GetUserMessages(True);
				MessagesText = "";
				Separator = "";
				For each UserMessage In UserMessages Do
					If ValueIsFilled(UserMessage.Field) Then
						MessagesText = MessagesText + Separator + UserMessage.Text;
						Separator = Chars.LF;
					EndIf;
				EndDo;
				Raise MessagesText;
			EndIf;
			
			CatalogItem.Write();
			// Write properties when an object already exists.
			If PropertiesTable.Count() > 0 AND Common.SubsystemExists("StandardSubsystems.Properties") Then
				ModulePropertyManager = Common.CommonModule("PropertyManager");
				ModulePropertyManager.WriteObjectProperties(CatalogItem.Ref, PropertiesTable);
			EndIf;
			If AccessManagementUsed Then
				ModuleAccessManagement.DisableAccessKeysUpdate(False);
			EndIf;
			CommitTransaction();
		Except
			RollbackTransaction();
			If AccessManagementUsed Then
				ModuleAccessManagement.DisableAccessKeysUpdate(False, False);
			EndIf;
			ErrorInformation = ErrorInfo();
			TableRow.RowMappingResult = "Skipped";
			TableRow.ErrorDescription = BriefErrorDescription(ErrorInformation);
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Не удалось записать элемент справочника %1 по причине:
				|%2'; 
				|en = 'Cannot write the %1 catalog item due to:
				|%2'; 
				|pl = 'Nie udało się zapisać element przewodnika %1 z powodu:
				|%2';
				|es_ES = 'No se ha podido guardar el elemento del catálogo %1a causa de:
				|%2';
				|es_CO = 'No se ha podido guardar el elemento del catálogo %1a causa de:
				|%2';
				|tr = '%1 katalog öğesi şu nedenle yazılamıyor: 
				|%2';
				|it = 'Impossibile scrivere l''elemento del catalogo %1 a causa di:
				|%2';
				|de = 'Verzeichniseintrag %1 konnte nicht geschrieben werden wegen:
				|%2'"), 
				CatalogName, DetailErrorDescription(ErrorInfo()));
			WriteLogEvent(EventLogEvent(), EventLogLevel.Warning,
				CatalogManager, CatalogItem.Ref, MessageText);
		EndTry;
		
	EndDo;
	
	StorageAddress = PutToTempStorage(MappedData, StorageAddress);
	
EndProcedure

Procedure SetProgressPercent(Total, RowNumber)
	Percent = RowNumber * 50 / Total;
	ModuleTimeConsumingOperations = Common.CommonModule("TimeConsumingOperations");
	ModuleTimeConsumingOperations.ReportProgress(Percent);
EndProcedure

Procedure GenerateReportOnBackgroundImport(ExportParameters, StorageAddress) Export
	
	ReportTable = ExportParameters.ReportTable;
	MappedData  = ExportParameters.MappedData;
	ColumnsInformation  = ExportParameters.ColumnsInformation;
	TemplateWithData = ExportParameters.TemplateWithData;
	ReportType = ExportParameters.ReportType;
	CalculateProgressPercent = ExportParameters.CalculateProgressPercent;
	
	If Not ValueIsFilled(ReportType) Then
		ReportType = "AllItems";
	EndIf;
	
	GenerateReportTemplate(ReportTable, TemplateWithData);
	
	CreatedItemsCount = 0;
	UpdatedItemsCount = 0;
	SkippedItemsCount = 0;
	ItemsSkippedWithErrorCount = 0;
	For RowNumber = 1 To MappedData.Count() Do
		Row = MappedData.Get(RowNumber - 1);
		
		Cell = ReportTable.GetArea(RowNumber + 1, 1, RowNumber + 1, 1);
		Cell.CurrentArea.Text = Row.RowMappingResult;
		Cell.CurrentArea.Details = Row.MappingObject;
		Cell.CurrentArea.Comment.Text = Row.ErrorDescription;
		If Row.RowMappingResult = "Created" Then 
			Cell.CurrentArea.TextColor = StyleColors.SuccessResultColor;
			CreatedItemsCount = CreatedItemsCount + 1;
		ElsIf Row.RowMappingResult = "Updated" Then
			Cell.CurrentArea.TextColor = StyleColors.NoteText;
			UpdatedItemsCount = UpdatedItemsCount + 1;
		Else
			Cell.CurrentArea.TextColor = StyleColors.InaccessibleCellTextColor;
			SkippedItemsCount = SkippedItemsCount + 1;
			If ValueIsFilled(Row.ErrorDescription) Then
				ItemsSkippedWithErrorCount = ItemsSkippedWithErrorCount + 1;
			EndIf;
		EndIf;
		
		If ReportType = "NewProperties" AND Row.RowMappingResult <> "Created" Then
			Continue;
		EndIf;
		
		If ReportType = "Updated" AND Row.RowMappingResult <> "Updated" Then 
			Continue;
		EndIf;
		
		If ReportType = "Skipped" AND Row.RowMappingResult <> "Skipped" Then 
			Continue;
		EndIf;
		
		ReportTable.Put(Cell);
		For Index = 1 To ColumnsInformation.Count() Do 
			Cell = ReportTable.GetArea(RowNumber + 1, Index + 1, RowNumber + 1, Index + 1);
			
			Filter = New Structure("Position", Index);
			FoundColumns = ColumnsInformation.FindRows(Filter);
			If FoundColumns.Count() > 0 Then 
				ColumnName = FoundColumns[0].ColumnName;
				Cell.CurrentArea.Details = Row.MappingObject;
				Cell.CurrentArea.Text = Row[ColumnName];
				Cell.CurrentArea.TextPlacement = SpreadsheetDocumentTextPlacementType.Cut;
			EndIf;
			ReportTable.Join(Cell);
			
		EndDo;
		
		If CalculateProgressPercent Then 
			Percent = Round(RowNumber * 50 / MappedData.Count()) + 50;
			ModuleTimeConsumingOperations = Common.CommonModule("TimeConsumingOperations");
			ModuleTimeConsumingOperations.ReportProgress(Percent);
		EndIf;
		
	EndDo;
	
	Result = New Structure;
	Result.Insert("ReportType", ReportType);
	Result.Insert("Total", MappedData.Count());
	Result.Insert("Created", CreatedItemsCount);
	Result.Insert("Updated", UpdatedItemsCount);
	Result.Insert("Skipped", SkippedItemsCount);
	Result.Insert("Invalid", ItemsSkippedWithErrorCount);
	Result.Insert("ReportTable", ReportTable);
	
	StorageAddress = PutToTempStorage(Result, StorageAddress); 
	
EndProcedure

Procedure GenerateReportTemplate(ReportTable, TemplateWithData)
	
	ReportTable.Clear();
	Cell = TemplateWithData.GetArea(1, 1, 1, 1);
	
	TableHeader = TemplateWithData.GetArea("R1");
	FillTemplateHeaderCell(Cell, NStr("ru ='Результат'; en = 'Result'; pl = 'Wynik';es_ES = 'Resultado';es_CO = 'Resultado';tr = 'Sonuç';it = 'Risultato';de = 'Ergebnis'"), 12, NStr("ru ='Результат загрузки данных'; en = 'Data import result'; pl = 'Wynik importu danych';es_ES = 'Resultado de la importación de datos';es_CO = 'Resultado de la importación de datos';tr = 'Veri içe aktarma sonucu';it = 'Risultato di importazione dei dati';de = 'Daten Ladeergebnis'"), True);
	ReportTable.Join(TableHeader); 
	ReportTable.InsertArea(Cell.CurrentArea, ReportTable.Area("C1"), SpreadsheetDocumentShiftType.Horizontal);
	
	ReportTable.FixedTop = 1;
EndProcedure

#EndRegion

//////////////////// Functional options ///////////////////////////////////////

// Returns attribute columns dependent on functional options.
//
// Parameters:
//  FullObjectDescription - String - a full object description.
// Returns:
//   -  Map
//       * Key - String - a column name.
//       * Value - Boolean - an availability flag.
Function ColumnsDependentOnFunctionalOptions(FullObjectName)
	
	FunctionalOptionsInfo = New Map;
	ObjectNameWithSuffixAttribute = FullObjectName + ".Attribute.";
	
	FunctionalOptions = CommonCached.ObjectsEnabledByOption();
	For Each FunctionalOption In FunctionalOptions Do
		
		If StrStartsWith(FunctionalOption.Key, ObjectNameWithSuffixAttribute) Then
			FunctionalOptionsInfo.Insert(Mid(FunctionalOption.Key, StrLen(ObjectNameWithSuffixAttribute) + 1), FunctionalOption.Value);
		EndIf;
		
	EndDo;
	
	Return FunctionalOptionsInfo;
	
EndFunction

//////////////////// Service methods ///////////////////////////////////////////

Procedure AddPropertyValue(PropertiesTable, Properties, Prefix, ColumnName, Value)
	PropertyName = TrimAll(StandardSubsystemsServer.TransformAdaptedColumnDescriptionToString(Mid(ColumnName, StrLen(Prefix) + 1)));
	Property = Properties.Get(PropertyName);
	If Property <> Undefined Then
		NewPropertiesRow = PropertiesTable.Add();
		NewPropertiesRow.Property = Property.Ref;
		NewPropertiesRow.Value = Value;
	EndIf;
EndProcedure

// Returns a string constant for generating event log messages.
//
// Returns:
//   Row
//
Function EventLogEvent() 
	
	Return NStr("ru = 'Загрузка данных из файла'; en = 'Import data from file'; pl = 'Importuj dane z pliku';es_ES = 'Importar los datos del archivo';es_CO = 'Importar los datos del archivo';tr = 'Verileri dosyadan içe aktar';it = 'Importazione dati da file';de = 'Daten aus der Datei importieren'", CommonClientServer.DefaultLanguageCode());
	
EndFunction


#EndRegion



#EndIf
