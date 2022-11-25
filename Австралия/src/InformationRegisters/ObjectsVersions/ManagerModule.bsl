#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.AccessManagement

// See AccessManagementOverridable.OnFillListsWithAccessRestriction. 
Procedure OnFillAccessRestriction(Restriction) Export
	
	Restriction.Text =
	"AllowReadUpdate
	|WHERE
	|	ObjectReadingAllowed(Object)";
	
	Restriction.ByOwnerWithoutSavingAccessKeys = True;
	
EndProcedure

// End StandardSubsystems.AccessManagement

#EndRegion

#EndRegion

#Region Private

Procedure DeleteVersionAuthorInfo(Val VersionAuthor) Export
	
	If Not Common.SeparatedDataUsageAvailable() Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text = "SELECT
	|	ObjectsVersions.Object,
	|	ObjectsVersions.VersionNumber,
	|	ObjectsVersions.ObjectVersion,
	|	UNDEFINED AS VersionAuthor,
	|	ObjectsVersions.VersionDate,
	|	ObjectsVersions.Comment,
	|	ObjectsVersions.ObjectVersionType,
	|	ObjectsVersions.VersionIgnored
	|FROM
	|	InformationRegister.ObjectsVersions AS ObjectsVersions
	|WHERE
	|	ObjectsVersions.VersionAuthor = &VersionAuthor";
	
	Query.SetParameter("VersionAuthor", VersionAuthor);
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		RecordSet = CreateRecordSet();
		
		RecordSet.Filter["Object"].Set(Selection["Object"]);
		RecordSet.Filter["VersionNumber"].Set(Selection["VersionNumber"]);
		
		FillPropertyValues(RecordSet.Add(), Selection);
		
		RecordSet.Write();
		
	EndDo;
	
EndProcedure


Procedure GenerateReportOnChanges(ReportParameters, ResultAddress) Export
	// Stores a temporary parsed object version that can be used to reduce the number of XML parse 
	// cycles.
	Var ObjectVersion;
	
	// Global ID used for string changes between versions.
	Var counterUniqueID;
	
	ObjectRef = ReportParameters.ObjectRef;
	VersionList = ReportParameters.VersionsList;
	
	CommonTemplate = GetTemplate("StandardObjectPresentationTemplate");
	ReportTS = New SpreadsheetDocument;
	
	// Creating an array of version numbers sorted in ascending order (this is necessary because 
	// initially some versions can be missing and some can be in mixed order).
	VersionNumberArray = VersionList.UnloadValues();
	
	// Number of object versions (k) stored in the infobase.
	// Report generation requires (k-1) comparison operations.
	// It actually means that update tables will have (k) columns.
	ObjectVersionCount = VersionNumberArray.Count();
	
	// This table stores all attribute changes and has two dimensions:
	// The first dimension (rows) contains values of object attribute descriptions. The second dimension 
	// (columns) contains object version ID and change characteristic. Version ID is a unique string ID 
	// assigned to each object version and containing additional change information.
	// 
	AttributeChangeTable = New ValueTable;
	PrepareAttributeChangeTableColumns(AttributeChangeTable, VersionNumberArray);
	
	// Contains tabular section changes mapping object value table names to the change history of each 
	// value table. Each mapping is a tabular section where rows contain the descriptions of the tabular 
	// section fields, and columns contain the object version IDs. Version ID is a unique string ID 
	// assigned to each object version and containing additional change information.
	// 
	// 
	// 
	TabularSectionChangeTable = New Map;
	
	SpreadsheetDocuments = New ValueList;
	SpreadsheetDocumentChangeTable = New ValueTable;
	SpreadsheetDocumentChangeTable.Columns.Add("Description");
	SpreadsheetDocumentChangeTable.Columns.Add("Presentation");
	//
	
	// Generating initial object versions. The values of these versions are always shown if any further 
	// changes are made.
	ObjectVersion_Prev = CountInitialAttributeAndTabularSectionValues(AttributeChangeTable, TabularSectionChangeTable,
		ObjectVersionCount, VersionNumberArray, ObjectRef);
	
	SpreadsheetDocuments.Add(ObjectVersion_Prev.SpreadsheetDocuments);
	SpreadsheetDocumentChangeTable.Columns.Add("Version" + Format(VersionNumberArray[0], "NG=0"));
	
	counterUniqueID = GetUUID(TabularSectionChangeTable, "Version" + Format(VersionNumberArray[0], "NG=0"));
	
	For VersionIndex = 2 To VersionNumberArray.Count() Do
		VersionNumber = VersionNumberArray[VersionIndex-1];
		PreviousVersionNumber = "Version" + (Format(VersionNumberArray[VersionIndex-2], "NG=0"));
		CurrentVersionColumnName = "Version" + Format(VersionNumber, "NG=0");
		
		ComparisonResult = CalculateChanges(VersionNumber, ObjectVersion_Prev, ObjectVersion, ObjectRef);
		
		SpreadsheetDocuments.Add(ObjectVersion.SpreadsheetDocuments);
		
		// Filling the attribute report table.
		FillAttributeChangingCharacteristic(ComparisonResult["Attributes"]["and"],
			"AND", AttributeChangeTable, CurrentVersionColumnName, ObjectVersion);
		FillAttributeChangingCharacteristic(ComparisonResult["Attributes"]["village"],
			"A", AttributeChangeTable, CurrentVersionColumnName, ObjectVersion);
		FillAttributeChangingCharacteristic(ComparisonResult["Attributes"]["u"],
			"U", AttributeChangeTable, CurrentVersionColumnName, ObjectVersion);
		
		// Changes in tabular sections.
		TabularSectionChanges = ComparisonResult["TabularSections"]["and"];
		
		// This functionality is not yet implemented.
		AddedTabularSections = ComparisonResult["TabularSections"]["village"];
		DeletedTabularSections = ComparisonResult["TabularSections"]["u"];
		
		For Each MapItem In ObjectVersion.TabularSections Do
			TableName = MapItem.Key;
			
			If TabularSectionChangeTable[TableName] = Undefined Then
				Continue;
			EndIf;
			
			TabularSectionChangeTable[TableName][CurrentVersionColumnName] = 
				ObjectVersion.TabularSections[TableName].Copy();
				
			TableVersionRef = TabularSectionChangeTable[TableName][CurrentVersionColumnName];
			TableVersionRef.Columns.Add("Versioning_RowID");
			For Each TableRow In TableVersionRef Do
				TableRow.Versioning_RowID = TableRow.LineNumber;
			EndDo;
			
			TableVersionRef.Columns.Add("Versioning_Modification");
			TableVersionRef.FillValues(False, "Versioning_Modification");
			
			TableVersionRef.Columns.Add("Versioning_Changes", New TypeDescription("Array"));
			
			TableWithChanges = TabularSectionChanges.Get(TableName);
			If TableWithChanges <> Undefined Then
				ModifiedRows = TableWithChanges["AND"];
				AddedRows = TableWithChanges["A"];
				DeletedRows = TableWithChanges["U"];
				
				For Each TSItem In ModifiedRows Do
					VCTRow = TabularSectionChangeTable[TableName][PreviousVersionNumber][TSItem.IndexInTS0-1];
					TableVersionRef[TSItem.IndexInTS1-1].Versioning_RowID = VCTRow.Versioning_RowID;
					TableVersionRef[TSItem.IndexInTS1-1].Versioning_Modification = "AND";
					TableVersionRef[TSItem.IndexInTS1-1].Versioning_Changes = TSItem.Differences;
				EndDo;
				
				For Each TSItem In AddedRows Do
					TableVersionRef[TSItem.IndexInTS1-1].Versioning_RowID = IncreaseCounter(counterUniqueID, TableName);
					TableVersionRef[TSItem.IndexInTS1-1].Versioning_Modification = "A";
				EndDo;
				
				// UniqueID must be assigned for each item, for comparison with previous versions.
				For Index = 1 To TableVersionRef.Count() Do
					If TableVersionRef[Index-1].Versioning_RowID = Undefined Then
						// Found a row that must be looked up for mapping in the previous table.
						TSRow = TableVersionRef[Index-1];
						
						FilterParameters = New Structure;
						CommonColumns = FindCommonColumns(TableVersionRef, TabularSectionChangeTable[TableName][PreviousVersionNumber]);
						For Each ColumnName In CommonColumns Do
							If (ColumnName <> "Versioning_RowID") AND (ColumnName <> "Versioning_Modification") Then
								FilterParameters.Insert(ColumnName, TSRow[ColumnName]);
							EndIf;
						EndDo;
						
						PreviousTSRowArray = TabularSectionChangeTable[TableName][PreviousVersionNumber].FindRows(FilterParameters);
						
						FilterParameters.Insert("Versioning_Modification", Undefined);
						CurrentTSRowArray = TableVersionRef.FindRows(FilterParameters);
						
						For IDByTS_Current = 1 To CurrentTSRowArray.Count() Do
							If IDByTS_Current <= PreviousTSRowArray.Count() Then
								CurrentTSRowArray[IDByTS_Current-1].Versioning_RowID = PreviousTSRowArray[IDByTS_Current-1].Versioning_RowID;
							EndIf;
							CurrentTSRowArray[IDByTS_Current-1].Versioning_Modification = False;
						EndDo;
					EndIf;
				EndDo;
				For Each TSItem In DeletedRows Do
					RowImaginary = TableVersionRef.Add();
					RowImaginary.Versioning_RowID = TabularSectionChangeTable[TableName][PreviousVersionNumber][TSItem.IndexInTS0-1].Versioning_RowID;
					RowImaginary.Versioning_Modification = "U";
				EndDo;
			EndIf;
		EndDo;
		
		SpreadsheetDocumentChangeTable.Columns.Add(CurrentVersionColumnName);
		
		ResultTable  = ComparisonResult["SpreadsheetDocuments"]["and"];
		For Each curRow In ResultTable Do
			ChangeTableRow = SpreadsheetDocumentChangeTable.Find(curRow.Value, "Description");
			If ChangeTableRow = Undefined Then
				ChangeTableRow = SpreadsheetDocumentChangeTable.Add();
				ChangeTableRow.Description = curRow.Value;
				ChangeTableRow.Presentation = curRow.Presentation;
			EndIf;
			ChangeTableRow[CurrentVersionColumnName] = "AND";
		EndDo;
		
		ResultTable  = ComparisonResult["SpreadsheetDocuments"]["village"];
		For Each curRow In ResultTable Do
			ChangeTableRow = SpreadsheetDocumentChangeTable.Find(curRow.Value, "Description");
			If ChangeTableRow = Undefined Then
				ChangeTableRow = SpreadsheetDocumentChangeTable.Add();
				ChangeTableRow.Description = curRow.Value;
				ChangeTableRow.Presentation = curRow.Presentation;
			EndIf;
			ChangeTableRow[CurrentVersionColumnName] = "A";
		EndDo;
		
		ResultTable  = ComparisonResult["SpreadsheetDocuments"]["u"];
		For Each curRow In ResultTable Do
			ChangeTableRow = SpreadsheetDocumentChangeTable.Find(curRow.Value, "Description");
			If ChangeTableRow = Undefined Then
				ChangeTableRow = SpreadsheetDocumentChangeTable.Add();
				ChangeTableRow.Description = curRow.Value;
				ChangeTableRow.Presentation = curRow.Presentation;
			EndIf;
			ChangeTableRow[CurrentVersionColumnName] = "U";
		EndDo;
		
		ObjectVersion_Prev = ObjectVersion;
	EndDo;
	
	Parameters = New Structure;
	Parameters.Insert("AttributeChangeTable", AttributeChangeTable);
	Parameters.Insert("TabularSectionChangeTable", TabularSectionChangeTable);
	Parameters.Insert("SpreadsheetDocumentChangeTable", SpreadsheetDocumentChangeTable);
	Parameters.Insert("counterUniqueID", counterUniqueID);
	Parameters.Insert("VersionsList", VersionList);
	Parameters.Insert("ReportTS", ReportTS);
	Parameters.Insert("CommonTemplate", CommonTemplate);
	Parameters.Insert("ObjectRef", ObjectRef);
	OutputCompositionResultsInReportLayout(Parameters);
	
	TemplateLegend = CommonTemplate.GetArea("Legend");
	ReportTS.Put(TemplateLegend);
	
	PutToTempStorage(ReportTS, ResultAddress);
EndProcedure

Procedure OutputAttributeChanges(ReportTS, AttributeChangeTable, VersionNumberArray, CommonTemplate, ObjectRef)
	
	AttributeHeaderArea = CommonTemplate.GetArea("AttributeHeader");
	ReportTS.Put(AttributeHeaderArea);
	ReportTS.StartRowGroup("AttributeGroup");
	
	For Each ModAttributeItem In AttributeChangeTable Do
		If ModAttributeItem.Versioning_Modification = True Then
			
			DescriptionDetailsStructure = ObjectsVersioning.DisplayedAttributeDescription(ObjectRef, ModAttributeItem.Description);
			If Not DescriptionDetailsStructure.OutputAttribute Then
				Continue;
			EndIf;
			
			DisplayedDescription = DescriptionDetailsStructure.DisplayedDescription;
			
			EmptyCell = CommonTemplate.GetArea("EmptyCell");
			ReportTS.Put(EmptyCell);;
			
			AttributeDescription = CommonTemplate.GetArea("FieldAttributeDescription");
			AttributeDescription.Parameters.FieldAttributeDescription = DisplayedDescription;
			ReportTS.Join(AttributeDescription);
			
			IndexByAttributeVersions = VersionNumberArray.Count();
			
			While IndexByAttributeVersions >= 1 Do
				ChangeCharacteristicStructure = ModAttributeItem["Version" + Format(VersionNumberArray[IndexByAttributeVersions-1], "NG=0")];
				
				AttributeValuePresentation = "";
				AttributeValue = "";
				Update = Undefined;
				
				// Skipping to the next version if the attribute was not changed in the current version.
				If TypeOf(ChangeCharacteristicStructure) = Type("String") Then
					
					AttributeValuePresentation = String(AttributeValue);
					
				ElsIf ChangeCharacteristicStructure <> Undefined Then
					If ChangeCharacteristicStructure.ChangeType = "U" Then
					Else
						AttributeValue = ChangeCharacteristicStructure.Value.AttributeValue;
						AttributeValuePresentation = String(AttributeValue);
					EndIf;
					// Getting the attribute change structure for the current version.
					Update = ChangeCharacteristicStructure.ChangeType;
				EndIf;
				
				If AttributeValuePresentation = "" Then
					AttributeValuePresentation = AttributeValue;
					If AttributeValuePresentation = "" Then
						AttributeValuePresentation = " ";
					EndIf;
				EndIf;
				
				If      Update = Undefined Then
					AttributeValueArea = CommonTemplate.GetArea("InitialAttributeValue");
					AttributeValueArea.Parameters.AttributeValue = AttributeValuePresentation;
				ElsIf Update = "AND" Then
					AttributeValueArea = CommonTemplate.GetArea("ModifiedAttributeValue");
					AttributeValueArea.Parameters.AttributeValue = AttributeValuePresentation;
				ElsIf Update = "U" Then
					AttributeValueArea = CommonTemplate.GetArea("DeletedAttribute");
					AttributeValueArea.Parameters.AttributeValue = AttributeValuePresentation;
				ElsIf Update = "A" Then
					AttributeValueArea = CommonTemplate.GetArea("AddedAttribute");
					AttributeValueArea.Parameters.AttributeValue = AttributeValuePresentation;
				EndIf;
				
				ReportTS.Join(AttributeValueArea);
				
				IndexByAttributeVersions = IndexByAttributeVersions - 1;
			EndDo;
		EndIf;
	EndDo;
	
	ReportTS.EndRowGroup();
	
EndProcedure

Procedure OutputTabularSectionChanges(ReportTS, TabularSectionChangeTable, VersionNumberArray,
	counterUniqueID, CommonTemplate, ObjectRef)
	
	InternalColumnPrefix = "Versioning_";
	TabularSectionAreaHeaderDisplayed = False;
	
	EmptyRowTemplate = CommonTemplate.GetArea("EmptyRow");
	
	ReportTS.Put(EmptyRowTemplate);
	
	// Repeating for each changed item 
	For Each ChangedTSItem In TabularSectionChangeTable Do
		TabularSectionName = ChangedTSItem.Key;
		CurrentTSVersions = ChangedTSItem.Value;
		
		ObjectMetadata = ObjectRef.Metadata();
		TabularSectionPresentation = TabularSectionName;
		TabularSectionDetails = ObjectsVersioning.TabularSectionMetadata(ObjectMetadata, TabularSectionName);
		If TabularSectionDetails <> Undefined Then
			TabularSectionPresentation = TabularSectionDetails.Presentation();
		EndIf;
		
		CurrentTabularSectionChanged = False;
		
		For CurrCounterUUID = 1 To counterUniqueID[TabularSectionName] Do
			
			UUIDStringChanged = False;
			// If any changes are found, displaying the initial version (before the change) is required.
			// 
			InitialVersionFilled = False;
			
			// Searching each version for the current row (UniqueID = CurrCounterUUID) through all change 
			// history. If the row is deleted you can cancel the search, color-mark the "deleted" flag, and 
			// proceed to the next row.
			IndexByVersions = VersionNumberArray.Count();
			
			// ---------------------------------------------------------------------------------
			// Browsing the versions to make sure that changes are found ---
			
			RowModified = False;
			
			While IndexByVersions >= 1 Do
				CurrentTSVersionColumn = "Version" + Format(VersionNumberArray[IndexByVersions-1], "NG=0");
				CurrentVersionTS = CurrentTSVersions[CurrentTSVersionColumn];
				
				FoundRow = Undefined;
				If CurrentVersionTS.Columns.Find("Versioning_RowID") <> Undefined Then
					FoundRow = CurrentVersionTS.Find(CurrCounterUUID, "Versioning_RowID");
				EndIf;
				
				If FoundRow <> Undefined Then
					If (FoundRow.Versioning_Modification <> Undefined) Then
						If (TypeOf(FoundRow.Versioning_Modification) = Type("String")
							OR (TypeOf(FoundRow.Versioning_Modification) = Type("Boolean")
							      AND FoundRow.Versioning_Modification = True)) Then
							RowModified = True;
						EndIf;
					EndIf;
				EndIf;
				IndexByVersions = IndexByVersions - 1;
			EndDo;
			
			If Not RowModified Then
				Continue;
			EndIf;
			
			// ---------------------------------------------------------------------------------
			
			// Displaying the versions as a spreadsheet document.
			IndexByVersions = VersionNumberArray.Count();
			
			IntervalBetweenFillings = 0;
			
			// Repeating for each version. Searching each version for the changed row by its UniqueID.
			// 
			While IndexByVersions >= 1 Do
				IntervalBetweenFillings = IntervalBetweenFillings + 1;
				CurrentTSVersionColumn = "Version" + Format(VersionNumberArray[IndexByVersions-1]);
				// Tabular section of the current version (table of modified values).
				CurrentVersionTS = CurrentTSVersions[CurrentTSVersionColumn];
				FoundRow = CurrentVersionTS.Find(CurrCounterUUID, "Versioning_RowID");
				
				// Changed row found in a version (this change is possibly the latest).
				If FoundRow <> Undefined Then
					
					// This section displays common header for the tabular sections area.
					If Not TabularSectionAreaHeaderDisplayed Then
						TabularSectionAreaHeaderDisplayed = True;
						CommonTSSectionHeaderTemplate = CommonTemplate.GetArea("TabularSectionsHeader");
						ReportTS.Put(CommonTSSectionHeaderTemplate);
						ReportTS.StartRowGroup("TabularSectionsGroup");
						ReportTS.Put(EmptyRowTemplate);
					EndIf;
					
					// This section displays header for the current tabular section.
					If Not CurrentTabularSectionChanged Then
						CurrentTabularSectionChanged = True;
						CurrentTSHeaderTemplate = CommonTemplate.GetArea("TabularSectionHeader");
						CurrentTSHeaderTemplate.Parameters.TabularSectionDescription = TabularSectionPresentation;
						ReportTS.Put(CurrentTSHeaderTemplate);
						ReportTS.StartRowGroup("TabularSection"+TabularSectionName);
						ReportTS.Put(EmptyRowTemplate);
					EndIf;
					
					Modification = FoundRow.Versioning_Modification;
					
					If UUIDStringChanged = False Then
						UUIDStringChanged = True;
						
						TSRowHeaderTemplate = CommonTemplate.GetArea("TabularSectionRowHeader");
						TSRowHeaderTemplate.Parameters.TabularSectionRowNumber = CurrCounterUUID;
						ReportTS.Put(TSRowHeaderTemplate);
						ReportTS.StartRowGroup("LinesGroup"+TabularSectionName+CurrCounterUUID);
						
						OutputType = "";
						If Modification = "U" Then
							OutputType = "U"
						EndIf;
						FillArray = New Array;
						For Each Column In CurrentVersionTS.Columns Do
							If StrFind(Column.Name, InternalColumnPrefix) = 1 Then
								Continue;
							EndIf;
							AttributePresentation = Column.Name;
							If ValueIsFilled(Column.Title) Then
								AttributePresentation = Column.Title;
							Else
								If TabularSectionDetails <> Undefined Then
									AttributeDetails = ObjectsVersioning.TabularSectionAttributeMetadata(TabularSectionDetails, Column.Name);
									If AttributeDetails = Undefined AND Metadata.ChartsOfAccounts.Contains(ObjectMetadata) Then
										AttributeDetails = ObjectMetadata.ExtDimensionAccountingFlags.Find(Column.Name);
									EndIf;
									If AttributeDetails <> Undefined Then
										AttributePresentation = AttributeDetails.Presentation();
									EndIf;
								EndIf;
							EndIf;
							FillArray.Add(AttributePresentation);
						EndDo;
						
						EmptySector = GenerateEmptySector(CommonTemplate, CurrentVersionTS.Columns.Count()-2);
						EmptySectorToFill = GenerateEmptySector(CommonTemplate, CurrentVersionTS.Columns.Count()-2, OutputType);
						Section = GenerateTSRowSector(CommonTemplate, FillArray, OutputType);
						
						ReportTS.Join(EmptySector);
						ReportTS.Join(Section);
					EndIf;
					
					While IntervalBetweenFillings > 1 Do
						ReportTS.Join(EmptySectorToFill);
						IntervalBetweenFillings = IntervalBetweenFillings - 1;
					EndDo;
					
					IntervalBetweenFillings = 0;
					
					// Filling the next changed table row.
					FillArray = New ValueList;
					For Each Column In CurrentVersionTS.Columns Do
						If StrFind(Column.Name, InternalColumnPrefix) = 1 Then
							Continue;
						EndIf;
						
						Presentation = String(FoundRow[Column.Name]);
						FillArray.Add(FoundRow["Versioning_Changes"].Find(Column.Name) <> Undefined, Presentation);
					EndDo;
					
					If TypeOf(Modification) = Type("Boolean") Then
						OutputType = "";
					Else
						OutputType = Modification;
					EndIf;
					
					Section = GenerateTSRowSector(CommonTemplate, FillArray, OutputType);
					ReportTS.Join(Section);
				EndIf;
				IndexByVersions = IndexByVersions - 1;
			EndDo;
			
			If UUIDStringChanged Then
				ReportTS.EndRowGroup();
				ReportTS.Put(EmptyRowTemplate);
			EndIf;
			
		EndDo;
		
		If CurrentTabularSectionChanged Then
			ReportTS.EndRowGroup();
			ReportTS.Put(EmptyRowTemplate);
		EndIf;
		
	EndDo;
	
	If TabularSectionAreaHeaderDisplayed Then
		ReportTS.EndRowGroup();
		ReportTS.Put(EmptyRowTemplate);
	EndIf;
	
EndProcedure

Procedure OutputSpreadsheetDocumentsChanges(ReportTS, VersionNumberArray, SpreadsheetDocumentChangeTable, CommonTemplate)
	
	If SpreadsheetDocumentChangeTable.Count() = 0 Then
		Return;
	EndIf;
	
	TemplateHeaderSpreadsheetDocuments	= CommonTemplate.GetArea("SpreadsheetDocumentsHeader");
	ReportTS.Put(TemplateHeaderSpreadsheetDocuments);
	
	ReportTS.StartRowGroup("SpreadsheetDocumentsGroup");
	
	TemplateEmptyRow	 = CommonTemplate.GetArea("EmptyRow");
	ReportTS.Put(TemplateEmptyRow);
	
	TemplateRowSpreadsheetDocuments = CommonTemplate.GetArea("SpreadsheetDocumentHeader");
	
	TemplateCellNotChanged = CommonTemplate.GetArea("SpreadsheetDocumentsIdentical");
	TemplateCellChanged = CommonTemplate.GetArea("SpreadsheetDocumentsDifferent");
	TemplateCellAdded = CommonTemplate.GetArea("SpreadsheetDocumentsAdded");
	TemplateCellDeleted = CommonTemplate.GetArea("SpreadsheetDocumentsDeleted");
		
	For Each curRow In SpreadsheetDocumentChangeTable Do
		TemplateRowSpreadsheetDocuments.Parameters.SpreadsheetDocumentDescription = curRow.Presentation;
		ReportTS.Put(TemplateRowSpreadsheetDocuments);
		UBound = VersionNumberArray.UBound();
		For Index = 0 To UBound Do
			VersionNumberIndex = UBound-Index;
			VersionNumber = VersionNumberArray[VersionNumberIndex];
			ColumnName = "Version" + Format(VersionNumber, "NG=0");
			
			If curRow[ColumnName] = "AND" Then
				Area = ReportTS.Join(TemplateCellChanged);
				VersionNumber0 = Format(VersionNumber, "NG=0");
				VersionNumber1 = Format(VersionNumberArray[VersionNumberIndex-1], "NG=0");
				TextPattern = NStr("ru='сравнить версию №%1 с версией №%2'; en = 'compare version No.%1 with version No.%2'; pl = 'porównać nr%1 wersji z numerem%2 wersji';es_ES = 'comparar la versión №%1 con la versión №%2';es_CO = 'comparar la versión №%1 con la versión №%2';tr = '%1 sayılı sürümü %2 sayılı sürüm ile karşılaştır';it = 'confronta la versione №%1 con la versione №%2';de = 'um die Versionsnummer%1 mit der Versionsnummer%2 zu vergleichen'");
				Area.Text = StringFunctionsClientServer.SubstituteParametersToString(TextPattern, VersionNumber0, VersionNumber1);
				Area.Details = New Structure("Compare, Version0, Version1",
					curRow.Description, VersionNumberIndex, VersionNumberIndex-1);
				
			ElsIf curRow[ColumnName] = "U" Then
				Area = ReportTS.Join(TemplateCellDeleted);
				Area.Text = NStr("ru='Сохранение изменений табличного документа отключено'; en = 'Saving table document changes is disabled'; pl = 'Zapisywanie zmian w dokumencie tabelarycznego jest wyłączone';es_ES = 'Está desactivado guardar los cambio del documento de tabla';es_CO = 'Está desactivado guardar los cambio del documento de tabla';tr = 'Tablo belgesindeki değişiklikleri kaydetme devre dışı bırakıldı';it = 'La tabella di salvataggio modifiche documento è disabilitata';de = 'Das Speichern von Änderungen in einem Tabellendokument ist deaktiviert'");
				
			ElsIf curRow[ColumnName] = "A" Then
				Area = ReportTS.Join(TemplateCellAdded);
				Area.Text = NStr("ru='открыть'; en = 'open'; pl = 'otwórz';es_ES = 'abrir';es_CO = 'abrir';tr = 'açık';it = 'apri';de = 'öffnen'");
				Area.Details = New Structure("Open, Version", curRow.Description, VersionNumberIndex); 
				
			Else
				Area = ReportTS.Join(TemplateCellNotChanged);
				
			EndIf;
		EndDo;
		ReportTS.Put(TemplateEmptyRow);
	EndDo;
	
	ReportTS.EndRowGroup();
	ReportTS.Put(TemplateEmptyRow);
	
EndProcedure

Procedure OutputCompositionResultsInReportLayout(Parameters)
	AttributeChangeTable = Parameters.AttributeChangeTable;
	TabularSectionChangeTable = Parameters.TabularSectionChangeTable;
	SpreadsheetDocumentChangeTable = Parameters.SpreadsheetDocumentChangeTable;
	counterUniqueID = Parameters.counterUniqueID;
	VersionList = Parameters.VersionsList;
	ReportTS = Parameters.ReportTS;
	CommonTemplate = Parameters.CommonTemplate;
	ObjectRef = Parameters.ObjectRef;
	
	VersionNumberArray = VersionList.UnloadValues();
	
	ChangedAttributeCount = CalculateChangedAttributeCount(AttributeChangeTable, VersionNumberArray);
	VersionsCount = VersionNumberArray.Count();
	
	ReportTS.Clear();
	OutputHeader(ReportTS, VersionList, VersionsCount, CommonTemplate, ObjectRef);
	
	If ChangedAttributeCount = 0 Then
		AttributeHeaderArea = CommonTemplate.GetArea("AttributeHeader");
		ReportTS.Put(AttributeHeaderArea);
		ReportTS.StartRowGroup("AttributeGroup");
		AttributesUnchangedSection = CommonTemplate.GetArea("AttributesUnchanged");
		ReportTS.Put(AttributesUnchangedSection);
		ReportTS.EndRowGroup();
	Else
		OutputAttributeChanges(ReportTS, AttributeChangeTable, VersionNumberArray, CommonTemplate, ObjectRef);
	EndIf;
	
	OutputTabularSectionChanges(ReportTS, TabularSectionChangeTable, VersionNumberArray, counterUniqueID, CommonTemplate, ObjectRef);
	OutputSpreadsheetDocumentsChanges(ReportTS, VersionNumberArray, SpreadsheetDocumentChangeTable, CommonTemplate);

	ReportTS.TotalsBelow = False;
	ReportTS.ShowGrid = False;
	ReportTS.Protection = False;
	ReportTS.ReadOnly = True;
	
EndProcedure

Procedure OutputHeader(ReportTS, VersionList, VersionsCount, CommonTemplate, ObjectRef)
	
	SectionHeader = CommonTemplate.GetArea("Header");
	SectionHeader.Parameters.ReportDescription = NStr("ru = 'Отчет по изменениям версий объекта'; en = 'Object version change report'; pl = 'Sprawozdanie po przemianach wersji obiektu';es_ES = 'Informe de cambios de la versión del objeto';es_CO = 'Informe de cambios de la versión del objeto';tr = 'Nesne sürüm değişikliği raporu';it = 'Report modifiche di versioni degli oggetti';de = 'Objektversionsänderungsbericht'");
	SectionHeader.Parameters.ObjectDescription = String(ObjectRef);
	
	ReportTS.Put(SectionHeader);
	
	EmptyCell = CommonTemplate.GetArea("EmptyCell");
	VersionArea = CommonTemplate.GetArea("VersionTitle");
	ReportTS.Join(EmptyCell);
	ReportTS.Join(VersionArea);
	VersionArea = CommonTemplate.GetArea("VersionPresentation");
	
	VersionComments = New Structure;
	HasComments = False;
	
	IndexByVersions = VersionsCount;
	While IndexByVersions > 0 Do
		
		VersionInfo = GetVersionDetails(ObjectRef, VersionList[IndexByVersions-1]);
		VersionArea.Parameters.VersionPresentation = VersionInfo.Details;
		
		VersionComments.Insert("Comment" + IndexByVersions, VersionInfo.Comment);
		If Not IsBlankString(VersionInfo.Comment) Then
			HasComments = True;
		EndIf;
		
		ReportTS.Join(VersionArea);
		ReportTS.Area("C" + Format(IndexByVersions + 2, "NG=0")).ColumnWidth = 50;
		IndexByVersions = IndexByVersions - 1;
		
	EndDo;
	
	If HasComments Then
		
		AreaComment = CommonTemplate.GetArea("TitleComment");
		ReportTS.Put(EmptyCell);
		ReportTS.Join(AreaComment);
		AreaComment = CommonTemplate.GetArea("Comment");
		
		IndexByVersions = VersionsCount;
		While IndexByVersions > 0 Do
			
			AreaComment.Parameters.Comment = VersionComments["Comment" + IndexByVersions];
			ReportTS.Join(AreaComment);
			IndexByVersions = IndexByVersions - 1;
			
		EndDo;
		
	EndIf;
	
	EmptyRowArea = CommonTemplate.GetArea("EmptyRow");
	ReportTS.Put(EmptyRowArea);
	
EndProcedure

Function CalculateChanges(VersionNumber, VersionParsingResult_0, VersionParsingResult_1, ObjectRef)
	
	// Parsing the previous version.
	Attributes_0      = VersionParsingResult_0.Attributes;
	TabularSections_0 = VersionParsingResult_0.TabularSections;
	
	// Parsing the latest version.
	VersionParsingResult_1 = ObjectsVersioning.ParseVersion(ObjectRef, VersionNumber);
	AddRowNumbersToTabularSections(VersionParsingResult_1.TabularSections);
	
	Attributes_1      = VersionParsingResult_1.Attributes;
	TabularSections_1 = VersionParsingResult_1.TabularSections;
	
	///////////////////////////////////////////////////////////////////////////////
	//           Generating the list of changed tablular sections           //
	///////////////////////////////////////////////////////////////////////////////
	TabularSectionList_0	= CreateComparisonChart();
	For Each Item In TabularSections_0 Do
		NewRow = TabularSectionList_0.Add();
		NewRow.Set(0, TrimAll(Item.Key));
	EndDo;
	
	TabularSectionList_1	= CreateComparisonChart();
	For Each Item In TabularSections_1 Do
		NewRow = TabularSectionList_1.Add();
		NewRow.Set(0, TrimAll(Item.Key));
	EndDo;
	
	// Metadata structure is possibly changed: attributes were added or deleted.
	TSToAddList = SubtractTable(TabularSectionList_1, TabularSectionList_0);
	DeletedTSList  = SubtractTable(TabularSectionList_0, TabularSectionList_1);
	
	// List of unchanged attributes that will be used to search for matches/differences.
	RemainingTSList = SubtractTable(TabularSectionList_1, TSToAddList);
	
	// List of attributes that were changed.
	ChangedTSList = FindChangedTabularSections(RemainingTSList,
	                                                       TabularSections_0,
	                                                       TabularSections_1);
	
	///////////////////////////////////////////////////////////////////////////////
	//           Generating a list of modified attributes                 //
	///////////////////////////////////////////////////////////////////////////////
	AttributeList0 = CreateComparisonChart();
	For Each Attribute In VersionParsingResult_0.Attributes Do
		NewRow = AttributeList0.Add();		
		NewRow.Set(0, TrimAll(String(Attribute.AttributeDescription)));
	EndDo;
	
	AttributeList1 = CreateComparisonChart();
	For Each Attribute In VersionParsingResult_1.Attributes Do
		NewRow = AttributeList1.Add();
		NewRow.Set(0, TrimAll(String(Attribute.AttributeDescription)));
	EndDo;
	
	// Metadata structure is possibly changed: attributes were added or deleted.
	AddedAttributeList = SubtractTable(AttributeList1, AttributeList0);
	DeletedAttributeList  = SubtractTable(AttributeList0, AttributeList1);
	
	// List of unchanged attributes that will be used to search for matches/differences.
	RemainingAttributeList = SubtractTable(AttributeList1, AddedAttributeList);
	
	// List of attributes that were changed.
	ChangedAttributeList = CreateComparisonChart();
	
	ChangesInAttributes = New Map;
	ChangesInAttributes.Insert("village", AddedAttributeList);
	ChangesInAttributes.Insert("u", DeletedAttributeList);
	ChangesInAttributes.Insert("and", ChangedAttributeList);
	
	For Each ValueTableRow In RemainingAttributeList Do
		
		Attribute = ValueTableRow.Value;
		Value_0 = Attributes_0.Find(Attribute, "AttributeDescription").AttributeValue;
		Value_1 = Attributes_1.Find(Attribute, "AttributeDescription").AttributeValue;
		
		If TypeOf(Value_0) <> Type("ValueStorage")
			AND TypeOf(Value_1) <> Type("ValueStorage") Then
			If Value_0 <> Value_1 Then
				NewRow = ChangedAttributeList.Add();
				NewRow.Set(0, Attribute);
			EndIf;
		EndIf;
		
	EndDo;
	
	ChangesInTables = CalculateChangesInTabularSections(
	                              ChangedTSList,
	                              TabularSections_0,
	                              TabularSections_1);
	
	///////////////////////////////////////////////////////////////////////////////
	//                      Generating a list of SpreadsheetDocuments                 //
	///////////////////////////////////////////////////////////////////////////////
	
	SpreadsheetDocuments0 = VersionParsingResult_0.SpreadsheetDocuments;
	SpreadsheetDocuments1 = VersionParsingResult_1.SpreadsheetDocuments;
	
	SpreadsheetDocumentsList0 = CreateComparisonChart();
	SpreadsheetDocumentsList0.Columns.Add("Presentation");
	If SpreadsheetDocuments0 <> Undefined Then
		For Each StructureItem In SpreadsheetDocuments0 Do
			NewRow = SpreadsheetDocumentsList0.Add();
			NewRow.Value = StructureItem.Key;
			NewRow.Presentation = StructureItem.Value.Description;
		EndDo;
	EndIf;
	
	SpreadsheetDocumentsList1 = CreateComparisonChart();
	SpreadsheetDocumentsList1.Columns.Add("Presentation");
	If SpreadsheetDocuments1 <> Undefined Then
		For Each StructureItem In SpreadsheetDocuments1 Do
			NewRow = SpreadsheetDocumentsList1.Add();
			NewRow.Value = StructureItem.Key;
			NewRow.Presentation = StructureItem.Value.Description;
		EndDo;
	EndIf;
	
	AddedSpreadsheetDocumentsList	= SubtractTable(SpreadsheetDocumentsList1, SpreadsheetDocumentsList0);
	DeletedSpreadsheetDocumentsList		= SubtractTable(SpreadsheetDocumentsList0, SpreadsheetDocumentsList1);
	RemainingSpreadsheetDocumentsList		= SubtractTable(SpreadsheetDocumentsList1, 
													AddedSpreadsheetDocumentsList);
	
	ModifiedSpreadsheetDocumentsList	= CreateComparisonChart();
	ModifiedSpreadsheetDocumentsList.Columns.Add("Presentation");
	
	ChangesInSpreadsheetDocuments = New Map;
	ChangesInSpreadsheetDocuments.Insert("village", AddedSpreadsheetDocumentsList);
	ChangesInSpreadsheetDocuments.Insert("u", DeletedSpreadsheetDocumentsList);
	ChangesInSpreadsheetDocuments.Insert("and", ModifiedSpreadsheetDocumentsList);
	
	For Each ValueTableRow In RemainingSpreadsheetDocumentsList Do
		
		SpreadsheetDocumentName = ValueTableRow.Value;
		
		XMLSprDoc = ObjectsVersioning.SerializeObject(
			New ValueStorage(SpreadsheetDocuments0[SpreadsheetDocumentName].Data));
		CheckSum0 = ObjectsVersioning.Checksum(XMLSprDoc);
		
		XMLSprDoc = ObjectsVersioning.SerializeObject(
			New ValueStorage(SpreadsheetDocuments1[SpreadsheetDocumentName].Data));
		CheckSum1 = ObjectsVersioning.Checksum(XMLSprDoc);
		
		If CheckSum0 <> CheckSum1 Then
			FillPropertyValues(ModifiedSpreadsheetDocumentsList.Add(), ValueTableRow);
		EndIf;
		
	EndDo;
	
	TabularSectionModifications = New Structure;
	TabularSectionModifications.Insert("village", TSToAddList);
	TabularSectionModifications.Insert("u", DeletedTSList);
	TabularSectionModifications.Insert("and", ChangesInTables);
	
	ChangesComposition = New Map;
	ChangesComposition.Insert("Attributes",      ChangesInAttributes);
	ChangesComposition.Insert("TabularSections", TabularSectionModifications);
	ChangesComposition.Insert("SpreadsheetDocuments", ChangesInSpreadsheetDocuments);
	
	Return ChangesComposition;
	
EndFunction

Procedure PrepareAttributeChangeTableColumns(ValueTable,
                                                      VersionNumberArray)
	
	ValueTable = New ValueTable;
	
	ValueTable.Columns.Add("Description");
	ValueTable.Columns.Add("Versioning_Modification");
	ValueTable.Columns.Add("Versioning_ValueType"); // Expected value type.
	
	For Index = 1 To VersionNumberArray.Count() Do
		ValueTable.Columns.Add("Version" + Format(VersionNumberArray[Index-1], "NG=0"));
	EndDo;
	
EndProcedure

Function CalculateChangesInTabularSections(ChangedTSList, TabularSections_0, TabularSections_1)
	
	For Each TabularSection In TabularSections_0 Do
		If TabularSections_1[TabularSection.Key] = Undefined Then
			TabularSections_1.Insert(TabularSection.Key, New ValueTable);
			DeletedTabularSection = ChangedTSList.Add();
			DeletedTabularSection.Value = TabularSection.Key;
		EndIf;
	EndDo;
	
	For Each TabularSection In TabularSections_1 Do
		If TabularSections_0[TabularSection.Key] = Undefined Then
			TabularSections_0.Insert(TabularSection.Key, New ValueTable);
			AddedTabularSection = ChangedTSList.Add();
			AddedTabularSection.Value = TabularSection.Key;
		EndIf;
	EndDo;
	
	ChangesInTables = New Map;
	
	// Repeating for each tabular section.
	For Index = 1 To ChangedTSList.Count() Do
		
		ChangesInTables.Insert(ChangedTSList[Index-1].Value, New Map);
		
		TableToAnalyze = ChangedTSList[Index-1].Value;
		TS0 = TabularSections_0[TableToAnalyze];
		TS1 = TabularSections_1[TableToAnalyze];
		
		ChangedRowsTable = New ValueTable;
		ChangedRowsTable.Columns.Add("IndexInTS0");
		ChangedRowsTable.Columns.Add("IndexInTS1");
		ChangedRowsTable.Columns.Add("Differences");
		
		TS0RowsAndTS1RowsMap = MapTableRows(TS0, TS1);
		TS1RowsAndTS0RowsMap = New Map;
		ColumnsToCheck = FindCommonColumns(TS0, TS1);
		For Each Map In TS0RowsAndTS1RowsMap Do
			TableRow0 = Map.Key;
			TableRow1 = Map.Value;
			DifferencesBetweenRows = DifferencesBetweenRows(TableRow0, TableRow1, ColumnsToCheck);
			If DifferencesBetweenRows.Count() > 0 Then
				NewRow = ChangedRowsTable.Add();
				NewRow["IndexInTS0"] = RowIndex(TableRow0) + 1;
				NewRow["IndexInTS1"] = RowIndex(TableRow1) + 1;
				NewRow["Differences"] = DifferencesBetweenRows;
			EndIf;
			TS1RowsAndTS0RowsMap.Insert(TableRow1, TableRow0);
		EndDo;
		
		AddedRowTable = New ValueTable;
		AddedRowTable.Columns.Add("IndexInTS1");
		
		For Each TableRow In TS1 Do
			If TS1RowsAndTS0RowsMap[TableRow] = Undefined Then
				NewRow = AddedRowTable.Add();
				NewRow.IndexInTS1 = TS1.IndexOf(TableRow) + 1;
			EndIf;
		EndDo;
		
		DeletedRowTable = New ValueTable;
		DeletedRowTable.Columns.Add("IndexInTS0");
		
		For Each TableRow In TS0 Do
			If TS0RowsAndTS1RowsMap[TableRow] = Undefined Then
				NewRow = DeletedRowTable.Add();
				NewRow.IndexInTS0 = TS0.IndexOf(TableRow) + 1;
			EndIf;
		EndDo;
		
		ChangesInTables[ChangedTSList[Index-1].Value].Insert("A", AddedRowTable);
		ChangesInTables[ChangedTSList[Index-1].Value].Insert("U", DeletedRowTable);
		ChangesInTables[ChangedTSList[Index-1].Value].Insert("AND", ChangedRowsTable);
		
	EndDo;
	
	Return ChangesInTables;
	
EndFunction

Function FindChangedTabularSections(RemainingTSList,
                                        TabularSections_0,
                                        TabularSections_1)
	
	ChangedTSList = CreateComparisonChart();
	
	// Searching for tabular sections with changed rows.
	For Each Item In RemainingTSList Do
		
		TS_0 = TabularSections_0[Item.Value];
		TS_1 = TabularSections_1[Item.Value];
		
		If TS_0.Count() = TS_1.Count() Then
			
			DifferenceFound = False;
			
			// Making sure the column structure remains the same.
			If TabularSectionsEqual (TS_0.Columns, TS_1.Columns) Then
				
				// Searching for differing items - rows.
				For Index = 0 To TS_0.Count() - 1 Do
					Row_0 = TS_0[Index];
					Row_1 = TS_1[Index];
					
					If NOT TSRowsEqual(Row_0, Row_1, TS_0.Columns) Then
						DifferenceFound = True;
						Break;
					EndIf
				EndDo;
				
			Else
				DifferenceFound = True;
			EndIf;
			
			If DifferenceFound Then
				NewRow = ChangedTSList.Add();
				NewRow.Set(0, Item.Value);
			EndIf;
			
		Else
			NewRow = ChangedTSList.Add();
			NewRow.Set(0, Item.Value);
		EndIf;
			
	EndDo;
	
	Return ChangedTSList;
	
EndFunction

Function CountInitialAttributeAndTabularSectionValues(AttributesTable, TableTS, VersionsCount, VersionNumberArray, ObjectRef)
	
	JuniorObjectVersion = VersionNumberArray[0];
	
	// Parsing the first version.
	ObjectVersion  = ObjectsVersioning.ParseVersion(ObjectRef, JuniorObjectVersion);
	AddRowNumbersToTabularSections(ObjectVersion.TabularSections);
	
	Attributes      = ObjectVersion.Attributes;
	TabularSections = ObjectVersion.TabularSections;
	
	Column = "Version" + Format(VersionNumberArray[0], "NG=0");
	
	For Each ValueTableRow In Attributes Do
		
		NewRow = AttributesTable.Add();
		NewRow[Column] = New Structure("ChangeType, Value", "AND", ValueTableRow);
		NewRow.Description = ValueTableRow.AttributeDescription;
		NewRow.Versioning_Modification = False;
		NewRow.Versioning_ValueType = ValueTableRow.AttributeType;
		
	EndDo;
	
	For Each TSItem In TabularSections Do
		
		TableTS.Insert(TSItem.Key, New Map);
		PrepareChangeTableColumnsForMapping(TableTS[TSItem.Key], VersionNumberArray);
		TableTS[TSItem.Key]["Version" + Format(JuniorObjectVersion, "NG=0")] = TSItem.Value.Copy();
		
		CurrentVT = TableTS[TSItem.Key]["Version" + Format(JuniorObjectVersion, "NG=0")];
		
		CurrentVT.Columns.Add("Versioning_RowID");
		CurrentVT.Columns.Add("Versioning_Modification");
		CurrentVT.Columns.Add("Versioning_Changes", New TypeDescription("Array"));
		
		For Index = 1 To CurrentVT.Count() Do
			CurrentVT[Index-1].Versioning_RowID = Index;
			CurrentVT[Index-1].Versioning_Modification = False;
		EndDo;
	
	EndDo;
	
	Return ObjectVersion;
	
EndFunction

Procedure PrepareChangeTableColumnsForMapping(Map, VersionNumberArray)
	
	Count = VersionNumberArray.Count();
	
	For Index = 1 To Count Do
		Map.Insert("Version" + Format(VersionNumberArray[Index-1], "NG=0"), New ValueTable);
	EndDo;
	
EndProcedure

Function TabularSectionsEqual(FirstTableColumns, SecondTableColumns)
	If FirstTableColumns.Count() <> SecondTableColumns.Count() Then
		Return False;
	EndIf;
	
	For Each Column In FirstTableColumns Do
		Found = SecondTableColumns.Find(Column.Name);
		If Found = Undefined Or Column.ValueType <> Found.ValueType Then
			Return False;
		EndIf;
	EndDo;
	
	Return True;
EndFunction

Function TSRowsEqual(TSRow1, TSRow2, Columns)
	
	For Each Column In Columns Do
		ColumnName = Column.Name;
		If TSRow2.Owner().Columns.Find(ColumnName) = Undefined Then
			Continue;
		EndIf;
		ValueFromTS1 = TSRow1[ColumnName];
		ValueFromTS2 = TSRow2[ColumnName];
		If ValueFromTS1 <> ValueFromTS2 Then
			Return False;
		EndIf;
	EndDo;
	
	Return True;
	
EndFunction

Function GetVersionDetails(ObjectRef, VersionNumber)
	
	VersionInfo = ObjectsVersioning.ObjectVersionInfo(ObjectRef, VersionNumber.Value);
	
	Details = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = '№ %1 / (%2) / %3'; en = 'No. %1 / (%2) / %3'; pl = '№ %1 / (%2) / %3';es_ES = '№ %1 / (%2) / %3';es_CO = '№ %1 / (%2) / %3';tr = '№ %1 / (%2) / %3';it = 'No. %1 / (%2) / %3';de = '№ %1 / (%2) / %3'"), VersionNumber.Presentation, 
		String(VersionInfo.VersionDate), TrimAll(String(VersionInfo.VersionAuthor)));
		
	VersionInfo.Insert("Details", Details);
	
	Return VersionInfo;
	
EndFunction

Function CalculateChangedAttributeCount(AttributeChangeTable, VersionNumberArray)
	
	Result = 0;
	
	For Each VTItem In AttributeChangeTable Do
		If VTItem.Versioning_Modification <> Undefined AND VTItem.Versioning_Modification = True Then
			Result = Result + 1;
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

Function IncreaseCounter(counterUniqueID, TableName);
	
	counterUniqueID[TableName] = counterUniqueID[TableName] + 1;
	
	Return counterUniqueID[TableName];
	
EndFunction

Function GetUUID(TSChangeTable, VersionColumnName)
	
	MapUUID = New Map;
	
	For Each ItemMap In TSChangeTable Do
		MapUUID[ItemMap.Key] = Number(ItemMap.Value[VersionColumnName].Count());
	EndDo;
	
	Return MapUUID;
	
EndFunction

Procedure FillAttributeChangingCharacteristic(SingleAttributeChangeTable, 
                                                    ChangeFlag,
                                                    AttributeChangeTable,
                                                    CurrentVersionColumnName,
                                                    ObjectVersion)
	
	For Each Item In SingleAttributeChangeTable Do
		Description = Item.Value;
		AttributeChange = AttributeChangeTable.Find (Description, "Description");
		
		If AttributeChange = Undefined Then
			AttributeChange = AttributeChangeTable.Add();
			AttributeChange.Description = Description;
		EndIf;
		
		ChangeParameters = New Structure;
		ChangeParameters.Insert("ChangeType", ChangeFlag);
		
		If ChangeFlag = "u" Then
			ChangeParameters.Insert("Value", "deleted");
		Else
			ChangeParameters.Insert("Value", ObjectVersion.Attributes.Find(Description, "AttributeDescription"));
		EndIf;
		
		AttributeChange[CurrentVersionColumnName] = ChangeParameters;
		AttributeChange.Versioning_Modification = True;
	EndDo;
	
EndProcedure


Function GenerateTSRowSector(CommonTemplate, Val FillingValues, Val OutputType = "")
	
	SpreadsheetDocument = New SpreadsheetDocument;
	
	If      OutputType = ""  Then
		Template = CommonTemplate.GetArea("InitialAttributeValue");
	ElsIf OutputType = "AND" Then
		Template = CommonTemplate.GetArea("ModifiedAttributeValue");
	ElsIf OutputType = "A" Then
		Template = CommonTemplate.GetArea("AddedAttribute");
	ElsIf OutputType = "U" Then
		Template = CommonTemplate.GetArea("DeletedAttribute");
	EndIf;
	
	TemplateNoChanges = CommonTemplate.GetArea("InitialAttributeValue");
	TemplateHasChange = CommonTemplate.GetArea("ModifiedAttributeValue");
	
	HasDetails = TypeOf(FillingValues) = Type("ValueList");
	For Each Item In FillingValues Do
		Value = Item;
		If HasDetails AND OutputType = "AND" Then
			Value = Item.Presentation;
			HasChange = Item.Value;
			Template = ?(HasChange, TemplateHasChange, TemplateNoChanges);
		EndIf;
		Template.Parameters.AttributeValue = Value;
		SpreadsheetDocument.Put(Template);
	EndDo;
	
	Return SpreadsheetDocument;
	
EndFunction

Function GenerateEmptySector(CommonTemplate, Val StringsCount, Val OutputType = "")
	
	FillingValue = New Array;
	
	For Index = 1 To StringsCount Do
		FillingValue.Add(" ");
	EndDo;
	
	Return GenerateTSRowSector(CommonTemplate, FillingValue, OutputType);
	
EndFunction

Function SubtractTable(Val MainTable,
                       Val DeductedTable,
                       Val MainTableComparisonColumn = "",
                       Val SubtractTableComparisonColumn = "")
	
	If Not ValueIsFilled(MainTableComparisonColumn) Then
		MainTableComparisonColumn = "Value";
	EndIf;
	
	If Not ValueIsFilled(SubtractTableComparisonColumn) Then
		SubtractTableComparisonColumn = "Value";
	EndIf;
	
	ResultTable = New ValueTable;
	ResultTable = MainTable.Copy();
	
	For Each Item In DeductedTable Do
		Value = Item[MainTableComparisonColumn];
		FoundRow = ResultTable.Find(Value, MainTableComparisonColumn);
		If FoundRow <> Undefined Then
			ResultTable.Delete(FoundRow);
		EndIf;
	EndDo;
	
	Return ResultTable;
	
EndFunction

Function CreateComparisonChart(InitializationTable = Undefined,
                                ComparisonColumnName = "Value")
	
	Table = New ValueTable;
	Table.Columns.Add(ComparisonColumnName);
	
	If InitializationTable <> Undefined Then
		
		For Each Item In InitializationTable Do
			NewRow = Table.Add();
			NewRow.Set(0, Item[ComparisonColumnName]);
		EndDo;
		
	EndIf;
	
	Return Table;

EndFunction

Function RowIndex(TableRow)
	Return TableRow.Owner().IndexOf(TableRow);
EndFunction

Procedure AddRowNumbersToTabularSections(TabularSections)
	
	For Each Map In TabularSections Do
		Table = Map.Value;
		If Table.Columns.Find("LineNumber") <> Undefined Then
			Continue;
		EndIf;
		Table.Columns.Insert(0, "LineNumber",,NStr("ru = '№ строки'; en = 'Row #'; pl = 'Wiersz #';es_ES = 'línea #';es_CO = 'línea #';tr = 'hat #';it = 'Riga';de = 'Zeile Nr'"));
		For RowNumber = 1 To Table.Count() Do
			Table[RowNumber-1].LineNumber = RowNumber;
		EndDo;
	EndDo;
	
EndProcedure

Function FindSimilarTableRows(Table1, Val Table2, Val RequiredDifferenceCount = 0, Val MaxDifferences = Undefined, Table1RowsAndTable2RowsMap = Undefined)
	
	Ignore = "Skip_";
	
	Table2 = Table2.Copy();
	If Table2.Columns.Find(Ignore) = Undefined Then
		Table2.Columns.Add(Ignore, New TypeDescription("Boolean"));
		Table2.Indexes.Add(Ignore);
	EndIf;
	
	If Table1RowsAndTable2RowsMap = Undefined Then
		Table1RowsAndTable2RowsMap = New Map;
	EndIf;
	
	If MaxDifferences = Undefined Then
		MaxDifferences = MaxTableRowDifferenceCount(Table1, Table2);
	EndIf;
	
	// Comparing each row with each other row.
	For Each TableRow1 In Table1 Do
		For Each TableRow2 In Table2.FindRows(New Structure(Ignore, False)) Do
			// Count differences ignoring internal column.
			DifferenceCount = DifferenceCountInTableRows(TableRow1, TableRow2) - 1;
			
			// Analyzing the result of rows comparison.
			If DifferenceCount = RequiredDifferenceCount Then
				Table1RowsAndTable2RowsMap.Insert(TableRow1.LineNumber, TableRow2.LineNumber);
				TableRow2[Ignore] = True;
				Break;
			EndIf;
		EndDo;
	EndDo;
	
	If Table1RowsAndTable2RowsMap.Count() < Table1.Count() AND Table2.FindRows(New Structure(Ignore, False)).Count() > 0 Then
		If RequiredDifferenceCount < MaxDifferences Then
			FindSimilarTableRows(Table1, Table2, RequiredDifferenceCount + 1, MaxDifferences, Table1RowsAndTable2RowsMap);
		EndIf;
	EndIf;
	
	Return Table1RowsAndTable2RowsMap;
	
EndFunction

Function MapTableRows(Table1, Table2)
	MapRowNumbers = FindSimilarTableRows(Table1, Table2);
	Result = New Map;
	For Each Item In MapRowNumbers Do
		Result.Insert(Table1[Item.Key - 1], Table2[Item.Value - 1]);
	EndDo;
	Return Result;
EndFunction

Function MaxTableRowDifferenceCount(Table1, Table2)
	
	TableColumnNameArray1 = GetColumnNames(Table1);
	TableColumnNameArray2 = GetColumnNames(Table2);
	BothTablesColumnNameArray = MergeSets(TableColumnNameArray1, TableColumnNameArray2);
	TotalColumns = BothTablesColumnNameArray.Count();
	
	Return ?(TotalColumns = 0, 0, TotalColumns - 1);

EndFunction

Function MergeSets(Set1, Set2)
	
	Result = New Array;
	
	For Each Item In Set1 Do
		Index = Result.Find(Item);
		If Index = Undefined Then
			Result.Add(Item);
		EndIf;
	EndDo;
	
	For Each Item In Set2 Do
		Index = Result.Find(Item);
		If Index = Undefined Then
			Result.Add(Item);
		EndIf;
	EndDo;	
	
	Return Result;
	
EndFunction

Function GetColumnNames(Table)
	
	Result = New Array;
	
	For Each Column In Table.Columns Do
		Result.Add(Column.Name);
	EndDo;
	
	Return Result;
	
EndFunction

Function DifferenceCountInTableRows(TableRow1, TableRow2)
	
	Result = 0;
	
	Table1 = TableRow1.Owner();
	Table2 = TableRow2.Owner();
	
	CommonColumns = FindCommonColumns(Table1, Table2);
	OtherColumns = FindNonmatchingColumns(Table1, Table2);
	
	// Counting each non-common column as one case of difference.
	Result = Result + OtherColumns.Count();
	
	// Counting differences by non-matching values.
	For Each ColumnName In CommonColumns Do
		If TableRow1[ColumnName] <> TableRow2[ColumnName] Then
			Result = Result + 1;
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

Function FindCommonColumns(Table1, Table2)
	NameArray1 = GetColumnNames(Table1);
	NameArray2 = GetColumnNames(Table2);
	Return SetIntersection(NameArray1, NameArray2);
EndFunction

Function FindNonmatchingColumns(Table1, Table2)
	NameArray1 = GetColumnNames(Table1);
	NameArray2 = GetColumnNames(Table2);
	Return SetDifference(NameArray1, NameArray2, True);
EndFunction

Function SetDifference(Set1, Val Set2, SymmetricDifference = False)
	
	Result = New Array;
	Set2 = CopyArray(Set2);
	
	For Each Item In Set1 Do
		Index = Set2.Find(Item);
		If Index = Undefined Then
			Result.Add(Item);
		Else
			Set2.Delete(Index);
		EndIf;
	EndDo;
	
	If SymmetricDifference Then
		For Each Item In Set2 Do
			Result.Add(Item);
		EndDo;
	EndIf;
	
	Return Result;
EndFunction

Function SetIntersection(Set1, Set2)
	
	Result = New Array;
	
	For Each Item In Set1 Do
		Index = Set2.Find(Item);
		If Index <> Undefined Then
			Result.Add(Item);
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

Function CopyArray(Array)
	
	Result = New Array;
	
	For Each Item In Array Do
		Result.Add(Item);
	EndDo;
	
	Return Result;
	
EndFunction

Function DifferencesBetweenRows(String1, String2, ColumnsToCheck)
	Result = New Array;
	For Each Column In ColumnsToCheck Do
		If TypeOf(String1[Column]) = Type("ValueStorage") Then
			Continue; // Attributes with the ValueStorage type are not compared.
		EndIf;
		If String1[Column] <> String2[Column] Then
			Result.Add(Column);
		EndIf;
	EndDo;
	Return Result;
EndFunction

#EndRegion

#EndIf