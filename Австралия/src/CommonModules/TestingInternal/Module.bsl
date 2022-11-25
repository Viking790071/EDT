
#Region Public

// The method puts data into temporary tables for the specified registers and the specified month
// A temporary table ReferenceMetadataObjectName is created  
// where MetadataObjectName is the name of the register. 
// Example: ReferenceAccountsPayable.
// Parameters:
//		ControlRegisters - Array - List of registers for which data is saved.
//		QueryParameters - Structure - qv QueryParameters()
//		RecordersArray - Array - List of documents for which movements are saved.
//		ReferenceData - ValueTable - Reference data to be compared.
// Return value:
//	TempTablesManager - Contains temporary tables with samples for the specified registers.
Function SaveReferenceData(ControlRegisters, QueryParameters = Undefined, RecordersArray = Undefined, ReferenceData = Undefined) Export
	
	QueryText = "";
	SaveReferenceData = True;
	TempTables = New TempTablesManager;
	
	DataQuery = New Query(QueryText);

	For each ControlRegister In ControlRegisters Do

		ReferenceTable = Undefined;
		If ReferenceData <> Undefined And ReferenceData[ControlRegister] <> Undefined Then
			RegisterNameComponents = StrSplit(ControlRegister, ".");
			RegisterName = ?(RegisterNameComponents.Count() > 1, RegisterNameComponents[1], RegisterNameComponents[0]);

			ReferenceTable = GetFromTempStorage(ReferenceData[ControlRegister]);
			DataQuery.SetParameter("ExternalTable" + RegisterName, ReferenceTable);
		EndIf;

		QueryText = QueryText + GenerateQuery(ControlRegister, SaveReferenceData, QueryParameters.RecordersFilter, ReferenceTable);
	EndDo;

	DataQuery.Text = QueryText;
	DataQuery.TempTablesManager = TempTables;
	DataQuery.SetParameter("RecordersArray", QueryParameters.RecordersArray);
	DataQuery.SetParameter("BeginOfPeriod", QueryParameters.BeginOfPeriod);
	DataQuery.SetParameter("EndOfPeriod", QueryParameters.EndOfPeriod);
	
	WriteLogEvent(NStr("en = 'Testing. Saving reference data started'; ru = 'Тестирование. Начато сохранение справочных данных';pl = 'Test. Rozpoczęto zapisywanie powiązanych danych';es_ES = 'Pruebas. Se ha empezado a lanzar los datos de referencia';es_CO = 'Pruebas. Se ha empezado a lanzar los datos de referencia';tr = 'Test. Referans verilerinin kaydedilmesi başladı';it = 'Test. Salvataggio dati di riferimento iniziato';de = 'Test. Referenzdaten werden gespeichert'"));
	DataQuery.ExecuteBatch();
	WriteLogEvent(NStr("en = 'Testing. Finished saving reference data'; ru = 'Тестирование. Сохранение справочных данных выполнено';pl = 'Test. Zakończono zapisywanie powiązanych danych';es_ES = 'Pruebas. Terminado de guardar los datos de referencia';es_CO = 'Pruebas. Terminado de guardar los datos de referencia';tr = 'Test. Referans verilerinin kaydedilmesi sona erdi';it = 'Test. Salvataggio dati di riferimento terminato';de = 'Test. Speichern von Referenzdaten abgeschlossen'"));
	
	Return TempTables;
	
EndFunction

// The method compares data from temporary tables with data from control registers,
// returns the fields by which the data diverges with detail to the initial and final data.
//
// Parameters:
// 	TempTables		 		- TempTablesManager	- Contains reference data.
//	ControlRegisters	 	- Array				- List of registers for which data is compared.
//  QueryParameters 	 	- Structure 		- qv QueryParameters()
//  RecordersArray		 	- Array				- List of documents for which movements are saved.
//  ReferenceData 		 	- ValueTable		- Reference data to be compared.
//  AdditionalParameters	- Structure			- qv AdditionalParametersForShapingCompareQuery().
// 
// Return value:
//  Structure - Contains tables with discrepancies in control registers.
//
Function CompareToReferenceData(TempTables, ControlRegisters, QueryParameters = Undefined, RecordersArray = Undefined, ReferenceData = Undefined, AdditionalParameters = Undefined) Export

	SaveReferenceData = False;
	
	DataQuery = New Query;
	DataQuery.TempTablesManager = TempTables;
	DataQuery.SetParameter("RecordersArray", QueryParameters.RecordersArray);
	DataQuery.SetParameter("BeginOfPeriod", QueryParameters.BeginOfPeriod);
	DataQuery.SetParameter("EndOfPeriod", QueryParameters.EndOfPeriod);
	
	Divergence = New Map;
	DivergenceCount = 0;
	
	WriteLogEvent(NStr("en = 'Testing. Started comparison with reference data'; ru = 'Тестирование. Начато сравнение со справочными данными';pl = 'Test. Rozpoczęto porównanie z powiązanymi danymi';es_ES = 'Pruebas. Lanzamiento de la comparación con los datos de referencia';es_CO = 'Pruebas. Lanzamiento de la comparación con los datos de referencia';tr = 'Test. Referans verileriyle karşılaştırma başladı';it = 'Test. Avvio confronto con dati di riferimento';de = 'Test. Vergleich mit Referenzdaten läuft'"));
	
	For each ControlRegister In ControlRegisters Do
		
		WriteLogEvent(NStr("en = 'Exported'; ru = 'Выгружено';pl = 'Wyeksportowano';es_ES = 'Descargar';es_CO = 'Descargar';tr = 'Dışa aktarıldı';it = 'Esportato';de = 'Exportiert'") + " " + ControlRegister);
		
		AdditionalParametersByRegister = AdditionalParametersForShapingCompareQuery();
		If AdditionalParameters <> Undefined Then
			AdditionalParametersByRegister = AdditionalParameters[StrReplace(ControlRegister,".","_")];
		EndIf;
		If QueryParameters.Property("ExcludedFields") Then
			For each ExcludedField In QueryParameters.ExcludedFields Do
				AdditionalParametersByRegister.ExcludedFields.Insert(ExcludedField.Key);
			EndDo;
		EndIf;
		If QueryParameters.Property("Tolerance") Then
			AdditionalParametersByRegister.Tolerance = QueryParameters.Tolerance;
		EndIf;
		If QueryParameters.Property("DetermineGeneralDivergence") Then
			AdditionalParametersByRegister.DetermineGeneralDivergence = QueryParameters.DetermineGeneralDivergence;
		EndIf;

		ReferenceTable = Undefined;
		If ReferenceData <> Undefined And ReferenceData[ControlRegister] <> Undefined Then
			RegisterNameComponents = StrSplit(ControlRegister, ".");
			RegisterName = ?(RegisterNameComponents.Count() > 1, RegisterNameComponents[1], RegisterNameComponents[0]);
			ReferenceTable = GetFromTempStorage(ReferenceData[ControlRegister]);
		EndIf;
		
		DataQuery.Text = GenerateQuery(ControlRegister, SaveReferenceData, QueryParameters.RecordersFilter, ReferenceTable, AdditionalParametersByRegister);
		Result = DataQuery.ExecuteBatch();
		
		Position = 2;
		Boundary = Result.Count();
		While Position < Boundary Do
			If Not Result[Position].IsEmpty() Then
				
				Table = Result[Position].Unload();
				PivotTable = Table.Copy(, "TestRecordType");
				PivotTable.Columns.Add("LineCounter");
				PivotTable.FillValues(1, "LineCounter");
				PivotTable.GroupBy("TestRecordType", "LineCounter");
				
				BeforeCalculation = 0;
				AfterCalculation = 0;
				For each String In PivotTable Do
					If String.TestRecordType = "RecordsBeforeCalculation" Then
						BeforeCalculation = String.LineCounter;
					ElsIf String.TestRecordType = "RecordsAfterCalculation" Then
						AfterCalculation = String.LineCounter;
					EndIf;
				EndDo;
				DivergenceCount = DivergenceCount + Max(BeforeCalculation, AfterCalculation);
				RegisterName = Table[0].FullRegisterName;

				If AdditionalParametersByRegister.DetermineGeneralDivergence Then
					RegisterStructure = New Structure("Table, Count", Table, Max(BeforeCalculation, AfterCalculation));
					Table.Indexes.Add("Recorder");
					RegisterStructure.Insert("Documents", Result[3].Unload().UnloadColumn("Recorder"));
				Else
					Records = Common.ValueToXMLString(Table);
					RegisterStructure = New Structure("Records, Count", Records, Max(BeforeCalculation, AfterCalculation));
					Table.Clear();
				EndIf;
				
				Divergence.Insert(RegisterName, RegisterStructure);
				
			EndIf;
			Position = Position + 3;
		EndDo;
	EndDo;
	
	WriteLogEvent(NStr("en = 'Testing. Finished comparison with reference data'; ru = 'Тестирование. Сравнение со справочными данными выполнено';pl = 'Test. Zakończono porównanie z powiązanymi danymi';es_ES = 'Pruebas. Comparación final con los datos de referencia';es_CO = 'Pruebas. Comparación final con los datos de referencia';tr = 'Test. Referans verileriyle karşılaştırma sona erdi';it = 'Test. Fine confronto con dati di riferimento';de = 'Test. Vergleich mit Referenzdaten abgeschlossen'"));
	
	Divergence.Insert("DivergenceCount", DivergenceCount);
	
	Return Divergence;
	
EndFunction

// The method generates the query text for all fields for the specified metadata object.
//
// Parameters:
//  MetadataPath			- String	 - The path to the object which data is saved.
//  	Example "AccumulationRegister.AccountsPayable".
//  SaveToTempTable	 		- Boolean	 - Query result will be saved to a temporary table like
//  	"ReferenceMetadataObjectName"
//  RecordersFilter			- Boolean	 - An optional parameter, if set to true, in the query will be a condition on the data selection,
//  	where the recorder is in the recorders array. There will be no selection by period
//	ReferenceTable			- ValueTable - Reference data to be compared.
//  AdditionalParameters	- Structure - qv AdditionalParametersForShapingCompareQuery().
// 
// Return value:
//  String - Query text.
//
Function GenerateQuery(MetadataPath, SaveToTempTable = False, RecordersFilter = False, ReferenceTable = Undefined, AdditionalParameters = Undefined) Export

	ReadingFromReferenceData = ReferenceTable <> Undefined;
	If AdditionalParameters = Undefined Then
		AdditionalParameters = AdditionalParametersForShapingCompareQuery();
	EndIf;
	If RegistersWithServiceRecorder().Find(MetadataPath) <> Undefined Then
		AdditionalParameters.ExcludedFields.Insert("Recorder");
	Else
		
		MetaRegister = Metadata.FindByFullName(MetadataPath);
		
		If Metadata.InformationRegisters.Contains(MetaRegister)
		 And MetaRegister.WriteMode = Metadata.ObjectProperties.RegisterWriteMode.Independent Then
			AdditionalParameters.SubordinateToRecorder = False;
			AdditionalParameters.DetermineGeneralDivergence = False;
		EndIf;
		
	EndIf;
	ExcludedFields = ExclusionList(AdditionalParameters.ExcludedFields);
	FieldsKeysWhichNeedDeploy = AdditionalParameters.FieldsKeysWhichNeedDeploy;
	
	MetadataCollection = Metadata.FindByFullName(MetadataPath);
	RegisterName = MetadataCollection.Name;
	IsAccountingRegister = Common.IsAccountingRegister(MetadataCollection);
	QueryMetadataPath = MetadataPath + ?(IsAccountingRegister, ".RecordsWithExtDimensions", "");
	
	FieldRefinement = DefaultQueryFieldsNames();
	If IsAccountingRegister Then
		FieldRefinement.Insert("ExpressionBefore", "ISNULL(");
		FieldRefinement.Insert("ExpressionAfter", ", Undefined)");
		FieldRefinement.Insert("Alias");
	EndIf;
	
	FieldStructure = CollectionFieldsStructure(MetadataCollection, AdditionalParameters);

	If ReadingFromReferenceData Then

		// Removing missing dimensions and attributes from comparison
		For each FieldCollection In FieldStructure Do
			Count = FieldCollection.Value.Count() - 1;
			While Count >= 0 Do

				FieldName = FieldCollection.Value[Count];
				If ReferenceTable.Columns.Find(FieldName) = Undefined Then
					FieldCollection.Value.Delete(Count);
				EndIf;
				Count = Count - 1;

			EndDo;
		EndDo;

	EndIf;
	
	If AdditionalParameters.GroupByDimensions Then
		GroupingArray = FieldStructure.Dimensions;
	Else
		GroupingArray = New Array;
		CommonClientServer.SupplementArray(GroupingArray, FieldStructure.Dimensions, True);
		CommonClientServer.SupplementArray(GroupingArray, FieldStructure.Resources, True);
		CommonClientServer.SupplementArray(GroupingArray, FieldStructure.Attributes, True);
	EndIf;
	
	GroupingArrayAfter = CommonClientServer.CopyRecursive(GroupingArray);
	
	DeployFieldsKeys(GroupingArray, FieldsKeysWhichNeedDeploy, ExcludedFields);
	
	DeployFieldsKeys(GroupingArrayAfter, FieldsKeysWhichNeedDeploy, ExcludedFields, True);
	
	If SaveToTempTable Then
		
		If ReadingFromReferenceData Then
			
			QueryTextTemplate = "
			|SELECT
			|	&TextDimensionsAttributes,
			|	&TextAmount,
			|	TRUE
			|INTO ReferenceMetadataObjectName
			|FROM
			|	&ExternalTableMetadataObjectName AS TT
			|WHERE
			|	&TextSelectionConditions
			|;
			|///////////////////////////////////
			|";
			
		Else 
		
			QueryTextTemplate = "
			|SELECT
			|	&TextDimensionsAttributes,
			|	&TextAmount,
			|	TRUE
			|INTO ReferenceMetadataObjectName
			|FROM
			|	MetadataObject AS TT
			|WHERE
			|	&TextSelectionConditions
			|;
			|///////////////////////////////////
			|";
			
		EndIf;
		
		TextDimensionsAttributes = AddFieldsInQuery(GroupingArray, FieldRefinement);
		
		FullQueryText = StrReplace(QueryTextTemplate, "&TextDimensionsAttributes,", TextDimensionsAttributes + ",");
		
		If FieldStructure.NumberFields.Count() > 0 Then
			FieldRefinement.ExpressionAfter = StrReplace(FieldRefinement.ExpressionAfter, "Undefined", "0");
			TextAmount = AddFieldsInQuery(FieldStructure.NumberFields, FieldRefinement) + ",";
		Else
			TextAmount = "";
		EndIf;
		FullQueryText = StrReplace(FullQueryText, "&TextAmount,", TextAmount);
		
		If IsPeriodInCollection(MetadataCollection) And Not RecordersFilter Then
			FullQueryText = StrReplace(FullQueryText, "&TextSelectionConditions", "TT.Period BETWEEN &BeginOfPeriod And &EndOfPeriod");
		ElsIf RecordersFilter Then
			FullQueryText = StrReplace(FullQueryText, "&TextSelectionConditions", "TT.Recorder In (&RecordersArray)");
		Else
			FullQueryText = StrReplace(FullQueryText, "&TextSelectionConditions", "TRUE");
		EndIf;
		
		FullQueryText = StrReplace(FullQueryText, "MetadataObjectName", RegisterName);
		FullQueryText = StrReplace(FullQueryText, "MetadataObject", QueryMetadataPath);
	Else
		QueryTextTemplate = "
		|SELECT DISTINCT
		|	&TextDimensionsAttributes,
		|	&TextDivergenceAmount,
		|	TT.CommonField
		|	, SUM(TT.CheckValue)
		|INTO DivergenceFieldsMetadataObjectName
		|FROM
		|	(SELECT
		|		&TextDimensionsAttributesBefore,
		|		&TextAmountsBefore,
		|		Undefined AS CommonField,
		|		1 AS CheckValue
		|	FROM
		|		ReferenceMetadataObjectName AS TT
		|	WHERE
		|		&TextSelectionConditionsBefore And
		|		TRUE
		|	
		|	UNION ALL
		|
		|	SELECT
		|		&TextDimensionsAttributesAfter,
		|		&TextAmountsAfter,
		|		Undefined AS CommonField,
		|		- 1 AS CheckValue
		|	FROM
		|		MetadataObject AS TT
		|	WHERE
		|		&TextSelectionConditionsAfter And
		|		TRUE
		|	) AS TT
		|GROUP BY
		|	&TextGroupIndex, 
		|	TT.CommonField
		|HAVING 
		|	&TextControlField And
		|	FALSE
		|	And &TextNumberOfRecordsCondition
		|;
		|/////////////////////////////////////////
		|SELECT
		|	""RecordsBeforeCalculation"" AS TestRecordType,
		|	&TextDimensionsAttributes,
		|	&TextDivergenceAmountBefore,
		|	""MetadataObjectFullName"" AS FullRegisterName,
		|	""MetadataObjectName"" AS RegisterName
		|INTO DetailRecordsMetadataObjectName
		|FROM
		|	DivergenceFieldsMetadataObjectName AS TT
		|
		|WHERE &TextInternalConnectionToReference
		|
		|UNION ALL
		|
		|SELECT
		|	""RecordsAfterCalculation""   AS TestRecordType,
		|	&TextDimensionsAttributesAfter,
		|	&TextDivergenceAmountAfter,
		|	""MetadataObjectFullName"" AS FullRegisterName,
		|	""MetadataObjectName"" AS RegisterName
		|FROM DivergenceFieldsMetadataObjectName AS TT
		|
		|WHERE &TextInternalConnectionToResult
		|;
		|/////////////////////////////////////////
		|SELECT
		|	TT.TestRecordType,
		|	&TextDimensionsAttributesFinal,
		|	&TextSumOfAmounts,
		|	TT.FullRegisterName,
		|	TT.RegisterName
		|FROM DetailRecordsMetadataObjectName AS TT
		|GROUP BY
		|	TT.TestRecordType,
		|	&TextGroupIndex,
		|	TT.FullRegisterName,
		|	TT.RegisterName
		|;
		|/////////////////////////////////////////
		|";
		
		TextDimensionsAttributes = AddFieldsInQuery(GroupingArray);
		FullQueryText = StrReplace(QueryTextTemplate, "&TextDimensionsAttributes,", TextDimensionsAttributes + ",");
		
		If AdditionalParameters.DetermineGeneralDivergence And ExcludedFields.Property("Recorder") Then
			TextDimensionsAttributesFinal = StrReplace(TextDimensionsAttributes, "AS DocumentRecorder", "AS Recorder");
		Else
			TextDimensionsAttributesFinal = TextDimensionsAttributes;
		EndIf;
		FullQueryText = StrReplace(FullQueryText, "&TextDimensionsAttributesFinal,", TextDimensionsAttributesFinal + ",");
		
		If Not AdditionalParameters.GroupByDimensions Then
			FullQueryText = StrReplace(FullQueryText, "And &TextNumberOfRecordsCondition", "Or SUM(TT.CheckValue) <> 0");
		Else
			FullQueryText = StrReplace(FullQueryText, "And &TextNumberOfRecordsCondition", "");
		EndIf;
		
		TextDimensionsAttributesBefore = TextDimensionsAttributes;
		ReplaceFields(TextDimensionsAttributesBefore, AdditionalParameters.FieldReplacementsBefore);
		FullQueryText = StrReplace(FullQueryText, "&TextDimensionsAttributesBefore,", TextDimensionsAttributesBefore + ",");
		
		TextDimensionsAttributesAfter = AddFieldsInQuery(GroupingArrayAfter, FieldRefinement);
		ReplaceFields(TextDimensionsAttributesAfter, AdditionalParameters.FieldReplacementsAfter);
		FullQueryText = StrReplace(FullQueryText, "&TextDimensionsAttributesAfter,", TextDimensionsAttributesAfter + ",");
		
		If FieldStructure.NumberFields.Count() > 0 Then
			FieldsNames = DefaultQueryFieldsNames();
			FieldsNames.ExpressionBefore = "ISNULL(";
			FieldsNames.ExpressionAfter = ", 0)";
			FieldsNames.Insert("Alias");
			TextAmountsBefore = AddFieldsInQuery(FieldStructure.NumberFields, FieldsNames) + ",";
			ReplaceFields(TextAmountsBefore, AdditionalParameters.FieldReplacementsBefore);
			
			FieldsNames.ExpressionBefore = "-"+FieldsNames.ExpressionBefore;
			TextAmountsAfter = AddFieldsInQuery(FieldStructure.NumberFields, FieldsNames) + ",";
			ReplaceFields(TextAmountsAfter, AdditionalParameters.FieldReplacementsAfter);
			
			FieldsNames = DefaultQueryFieldsNames();
			FieldsNames.FieldName = "Table";
			TextDivergenceAmountBefore = AddFieldsInQuery(FieldStructure.NumberFields, FieldsNames) + ",";
			ReplaceFields(TextDivergenceAmountBefore, AdditionalParameters.FieldReplacementsBefore, "Table");
			TextDivergenceAmountAfter = AddFieldsInQuery(FieldStructure.NumberFields, FieldsNames) + ",";
			ReplaceFields(TextDivergenceAmountAfter, AdditionalParameters.FieldReplacementsAfter, "Table");
			
			FieldsNames = DefaultQueryFieldsNames();
			FieldsNames.ExpressionBefore = "SUM(";
			FieldsNames.ExpressionAfter = ")";
			TextSumOfAmounts = AddFieldsInQuery(FieldStructure.NumberFields, FieldsNames) + ",";
		Else
			TextAmountsBefore = "";
			TextAmountsAfter = "";
			TextDivergenceAmountBefore = "";
			TextDivergenceAmountAfter = "";
			TextSumOfAmounts = "";
		EndIf;
		FullQueryText = StrReplace(FullQueryText, "&TextAmountsBefore,", TextAmountsBefore);
		FullQueryText = StrReplace(FullQueryText, "&TextAmountsAfter,", TextAmountsAfter);
		FullQueryText = StrReplace(FullQueryText, "&TextDivergenceAmountBefore,", TextDivergenceAmountBefore);
		FullQueryText = StrReplace(FullQueryText, "&TextDivergenceAmountAfter,", TextDivergenceAmountAfter);
		FullQueryText = StrReplace(FullQueryText, "&TextSumOfAmounts,", TextSumOfAmounts);
		If AdditionalParameters.DetermineGeneralDivergence Then
			FullQueryText = StrReplace(FullQueryText, "&TextDivergenceAmount,", TextSumOfAmounts);
		Else
			FullQueryText = StrReplace(FullQueryText, "&TextDivergenceAmount,", "");
		EndIf;
		
		TextSelectionConditionsBefore = "";
		If ValueIsFilled(AdditionalParameters.SelectionConditionsBefore) Then
			TextSelectionConditionsBefore = AdditionalParameters.SelectionConditionsBefore + " " + "And";
		EndIf;
		FullQueryText = StrReplace(FullQueryText, "&TextSelectionConditionsBefore And", TextSelectionConditionsBefore);
		If RecordersFilter Then
			TextSelectionConditionsAfter = "TT.Recorder In (&RecordersArray) And";
		ElsIf IsPeriodInCollection(MetadataCollection) Then
			TextSelectionConditionsAfter = "TT.Period BETWEEN &BeginOfPeriod And &EndOfPeriod And";
		Else
			TextSelectionConditionsAfter = "TRUE And"
		EndIf;

		If ValueIsFilled(AdditionalParameters.SelectionConditionsAfter) Then
			TextSelectionConditionsAfter = TextSelectionConditionsAfter + "
				|(" + AdditionalParameters.SelectionConditionsAfter + ") " + "And";
		EndIf;
		FullQueryText = StrReplace(FullQueryText, "&TextSelectionConditionsAfter And", TextSelectionConditionsAfter);
		
		FieldsNames = DefaultQueryFieldsNames();
		FieldsNames.ExpressionBefore = "SUM(";
		FieldsNames.ExpressionAfter = ") <> 0 ";
		FieldsNames.ExpressionJoin = "Or ";
		
		FieldsNames = DefaultQueryFieldsNames();
		FieldsNames.ExpressionBefore = "SUM(";
		FieldsNames.ExpressionJoin = "Or"+ " ";
		FieldsNames.ExpressionAfter = ") > &Tolerance" + " ";
		TextControlField1 = AddFieldsInQuery(FieldStructure.NumberFields, FieldsNames);
		FieldsNames.ExpressionAfter = ") < -&Tolerance" + " ";
		TextControlField2 = AddFieldsInQuery(FieldStructure.NumberFields, FieldsNames);
		TextControlField = StrReplace(
			TextControlField1 + " Or " + TextControlField2,
			"&Tolerance",
			AdditionalParameters.Tolerance);
		
		If ValueIsFilled(TextControlField1) Then
			FullQueryText = StrReplace(FullQueryText, "&TextControlField And", TextControlField + " " + "Or");
		Else
			FullQueryText = StrReplace(FullQueryText, "&TextControlField And", "");
		EndIf;
		
		FieldsNames = DefaultQueryFieldsNames();
		FieldsNames.ExpressionBefore = "";
		FieldsNames.ExpressionAfter = " ";
		TextGroupIndex = AddFieldsInQuery(GroupingArray, FieldsNames);
		FullQueryText = StrReplace(FullQueryText, "&TextGroupIndex,", TextGroupIndex + ",");
		
		InternalConnectionToReference = InnerJoinText(GroupingArray, "ReferenceMetadataObjectName");
		FullQueryText = StrReplace(FullQueryText, "WHERE &TextInternalConnectionToReference", InternalConnectionToReference);
		
		If AdditionalParameters.DetermineGeneralDivergence Then
			DivergenceTemplate = " + SUM(CASE WHEN TT.%1 > 0 THEN TT.%1 ELSE -TT.%1 END)";
			TextAmountOfDiscrepancies = "0";
			For each Field In FieldStructure.NumberFields Do
				TextAmountOfDiscrepancies = TextAmountOfDiscrepancies
					+ StringFunctionsClientServer.SubstituteParametersToString(
						DivergenceTemplate,
						Field);
			EndDo;
			
			DivergenceQuery = "
			|SELECT TOP 5
			|	TT.Recorder AS Recorder,
			|	&TextAmountOfDiscrepancies AS AmountOfDiscrepancies,
			|	""MetadataObjectName"" AS RegisterName
			|FROM DivergenceFieldsMetadataObjectName AS TT
			|GROUP BY
			|	TT.Recorder
			|ORDER BY
			|	AmountOfDiscrepancies DESC
			|;
			|/////////////////////////////////////////
			|";
			If ExcludedFields.Property("Recorder") Then
				DivergenceQuery = StrReplace(DivergenceQuery, "TT.Recorder", "TT.DocumentRecorder");
			EndIf;
			DivergenceQuery = StrReplace(DivergenceQuery, "&TextAmountOfDiscrepancies", TextAmountOfDiscrepancies);
			FullQueryText = FullQueryText + DivergenceQuery;
		EndIf;
		
		If FieldsKeysWhichNeedDeploy.Count() > 0 Then
			InternalConnectionToResult = InnerJoinText(GroupingArrayAfter, "MetadataObject", FieldRefinement);
			For each Field In FieldsKeysWhichNeedDeploy Do
				InternalConnectionToResult = StrReplace(InternalConnectionToResult, "TT." + Field + ".", "TT." + Field);
			EndDo;
		Else
			InternalConnectionToResult = InnerJoinText(GroupingArray, "MetadataObject", FieldRefinement);
		EndIf;
		FullQueryText = StrReplace(FullQueryText, "WHERE &TextInternalConnectionToResult", InternalConnectionToResult);
		
		FullQueryText = StrReplace(FullQueryText, "MetadataObjectFullName", MetadataPath);
		FullQueryText = StrReplace(FullQueryText, "MetadataObjectName", RegisterName);
		FullQueryText = StrReplace(FullQueryText, "MetadataObject", QueryMetadataPath);
	EndIf;
	
	Return FullQueryText;
	
EndFunction

// Function-wizard of the parameter structure to form a comparison query
// 
// Return value:
// 	Structure - Description:
// * DetermineGeneralDivergence - Boolean -
// * VerifyChecksum - Boolean -
// * Tolerance - String -
// * SelectionConditionsAfter - String -
// * SelectionConditionsBefore - String -
// * FieldsKeysWhichNeedDeploy - Array -
// * GroupByDimensions - Boolean -
// * FieldReplacementsAfter - Structure -
// * FieldReplacementsBefore - Structure -
// * ExcludedFields - Structure -
//
Function AdditionalParametersForShapingCompareQuery() Export
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ExcludedFields", New Structure);
	AdditionalParameters.Insert("FieldReplacementsBefore", New Structure);
	AdditionalParameters.Insert("FieldReplacementsAfter", New Structure);
	AdditionalParameters.Insert("GroupByDimensions", False);
	AdditionalParameters.Insert("FieldsKeysWhichNeedDeploy", New Array);
	AdditionalParameters.Insert("SelectionConditionsBefore", "");
	AdditionalParameters.Insert("SelectionConditionsAfter", "");
	AdditionalParameters.Insert("Tolerance", "0.02");
	AdditionalParameters.Insert("VerifyChecksum", True);
	AdditionalParameters.Insert("DetermineGeneralDivergence", False);
	AdditionalParameters.Insert("SubordinateToRecorder", True);
	
	Return AdditionalParameters;
	
EndFunction

// Function-wizard of the parameter structure to form a query.
//
// Return value:
//	Structure - parameter structure
// * BeginOfPeriod - Date -
// * EndOfPeriod - Date - 
// * RecordersArray - Array - 
// * RecordersFilter - Boolean - 
//
Function QueryParameters(Month, RecordersArray = Undefined) Export
	
	QueryParameters = New Structure("BeginOfPeriod, EndOfPeriod, RecordersArray, RecordersFilter");
	
	If Not ValueIsFilled(RecordersArray) Then
		QueryParameters.RecordersArray = New Array;
		QueryParameters.RecordersFilter = False;
	Else
		QueryParameters.RecordersFilter = True;
		QueryParameters.RecordersArray = RecordersArray;
	EndIf;
	
	If ValueIsFilled(Month) Then
		QueryParameters.BeginOfPeriod = BegOfMonth(Month);
		QueryParameters.EndOfPeriod = EndOfMonth(Month);
	Else
		QueryParameters.BeginOfPeriod = Date("00010101000000");
		QueryParameters.EndOfPeriod = Date("39991212235959");
	EndIf;
	
	Return QueryParameters;
	
EndFunction

Function RegistersWithServiceRecorder() Export
	
	ReturnArray = New Array;
	
	// method will expand
	
	Return ReturnArray;
	
EndFunction

#EndRegion // Public

#Region Private

Function CollectionFieldsStructure(Collection, AdditionalParameters) Export
	
	NumericFieldsArray = New Array;
	ExclusionList = ExclusionList(AdditionalParameters.ExcludedFields);
	IsAccountingRegister = Common.IsAccountingRegister(Collection);
	
	#Region Resources
	
	ResourcesArray = New Array;
	
	For each Field In Collection.Resources Do
		If Not ExclusionList.Property(Field.Name) Then
			NumericTypeField = String(Field.Type) = String(New TypeDescription("Number",,,Field.Type.NumberQualifiers));
			ArrayToAdd = ?(NumericTypeField, NumericFieldsArray, ResourcesArray);
			If Field.Type <> New TypeDescription("String") Then
				If IsAccountingRegister And Not Field.Balance And Collection.Correspondence Then
					ArrayToAdd.Add(Field.Name+"Dr");
					ArrayToAdd.Add(Field.Name+"Cr");
				Else
					ArrayToAdd.Add(Field.Name);
				EndIf;
			EndIf;
		EndIf;
	EndDo;
	
	#EndRegion
	
	#Region Dimensions
	
	DimensionArray = New Array;
	
	For each Field In Collection.Dimensions Do
		If Not ExclusionList.Property(Field.Name) Then
			NumericTypeField = String(Field.Type) = String(New TypeDescription("Number",,,Field.Type.NumberQualifiers));
			ArrayToAdd = ?(Not AdditionalParameters.GroupByDimensions And NumericTypeField, NumericFieldsArray, DimensionArray);
			If Field.Type <> New TypeDescription("String") Then
				If IsAccountingRegister And Not Field.Balance And Collection.Correspondence Then
					ArrayToAdd.Add(Field.Name+"Dr");
					ArrayToAdd.Add(Field.Name+"Cr");
				ElsIf Find(Collection.Name, "AccountingJournalEntries") 
					And Field.Name = "Status" Then
					
					// skip this dimension
				Else
					ArrayToAdd.Add(Field.Name);
				EndIf;
			EndIf;
		EndIf;
	EndDo;
	
	#EndRegion
	
	#Region StandardAttributes
	
	RequiredStandardAttributes = StrSplit("Period,Recorder,RecordType,Active", ",");
	
	For each CurAttribute In Collection.StandardAttributes Do
		
		Attribute = CurAttribute; 
		If Not ExclusionList.Property(Attribute.Name) And RequiredStandardAttributes.Find(Attribute.Name) <> Undefined Then
			
			DimensionArray.Add(Attribute.Name);
				
		EndIf;
		
	EndDo;
	
	If IsAccountingRegister Then
		If Collection.Correspondence Then
			DimensionArray.Add("AccountDr");
			DimensionArray.Add("AccountCr");
			DimensionArray.Add("ExtDimensionDr1");
			DimensionArray.Add("ExtDimensionCr1");
			DimensionArray.Add("ExtDimensionDr2");
			DimensionArray.Add("ExtDimensionCr2");
			DimensionArray.Add("ExtDimensionDr3");
			DimensionArray.Add("ExtDimensionCr3");
		Else
			DimensionArray.Add("Account");
			DimensionArray.Add("ExtDimension1");
			DimensionArray.Add("ExtDimension2");
			DimensionArray.Add("ExtDimension3");
		EndIf;
	EndIf;
	
	#EndRegion
	
	#Region Attributes
	
	AttributesArray = New Array;
	
	For each Field In Collection.Attributes Do
		If Not ExclusionList.Property(Field.Name) Then
			NumericTypeField = String(Field.Type) = String(New TypeDescription("Number",,,Field.Type.NumberQualifiers));
			ArrayToAdd = ?(Not AdditionalParameters.GroupByDimensions And NumericTypeField, NumericFieldsArray, AttributesArray);
			If Field.Type <> New TypeDescription("String") Then
				ArrayToAdd.Add(Field.Name);
			EndIf;
		EndIf;
	EndDo;
	
	#EndRegion
	
	#Region ReturnStructure
	
	FieldStructure = New Structure;
	FieldStructure.Insert("Dimensions", DimensionArray);
	FieldStructure.Insert("Attributes", AttributesArray);
	FieldStructure.Insert("Resources", ResourcesArray);
	FieldStructure.Insert("NumberFields", NumericFieldsArray);
	
	#EndRegion
	
	Return FieldStructure;
	
EndFunction

// Returns an array of fields to be excluded when forming the request text.
Function ExclusionList(ExcludedFields)
	
	ExclusionList = New Structure;
	ExclusionList.Insert("LineID", True);
	ExclusionList.Insert("LineNumber", True);
	ExclusionList.Insert("Comment", True);
	
	CommonClientServer.SupplementStructure(ExclusionList, ExcludedFields);
	
	Return ExclusionList;
	
EndFunction

// Generates the inner join text for the specified fields and source.
Function InnerJoinText(FieldsArray, SourceName, SourceFieldAdditionalRefinement = Undefined)
	
	If SourceFieldAdditionalRefinement = Undefined Then
		SourceFieldAdditionalRefinement = DefaultQueryFieldsNames();
	EndIf;
	
	Template = "INNER JOIN DataSourceName AS Table
	|ON ";
	InnerJoinText = StrReplace(Template, "DataSourceName", SourceName);
	
	FirstWriter = True;
	For each Field In FieldsArray Do
		
		If (Field = "CurrencyDr" Or Field = "CurrencyCr")
			And ValueIsFilled(SourceFieldAdditionalRefinement.ExpressionAfter) Then
			
			ExpressionAfter = ", VALUE(Catalog.Currencies.EmptyRef))";
		Else
			ExpressionAfter = SourceFieldAdditionalRefinement.ExpressionAfter;
		EndIf;
		
		SourceTableField = SourceFieldAdditionalRefinement.ExpressionBefore + "Table.FieldName" + ExpressionAfter;
		Template = "TT.FieldName = " + SourceTableField;
		TextOn = StrReplace(Template, "FieldName", Field);
		If Not FirstWriter Then
			TextOn = " And " + TextOn;
		EndIf;
		
		InnerJoinText = InnerJoinText + "
		| " + TextOn;
		
		FirstWriter = False;
	EndDo;
	
	Return InnerJoinText;
	
EndFunction

Function DefaultQueryFieldsNames()
	
	DefaultFieldsNames = New Structure;
	DefaultFieldsNames.Insert("ExpressionBefore", "");
	DefaultFieldsNames.Insert("ExpressionAfter", "");
	DefaultFieldsNames.Insert("ExpressionJoin", ",");
	DefaultFieldsNames.Insert("FieldName", "TT");
	
	Return DefaultFieldsNames;
	
EndFunction

Function AddFieldsInQuery(FieldsArray, FieldsNames = Undefined)
	
	If FieldsNames = Undefined Then
		FieldsNames = DefaultQueryFieldsNames();
	EndIf;
	
	FieldsText = "";
	Count = 1;
	Boundary = FieldsArray.Count();
	For each Field In FieldsArray Do
		
		If (Field = "CurrencyDr" Or Field = "CurrencyCr") And ValueIsFilled(FieldsNames.ExpressionAfter) Then
			ExpressionAfter = ", VALUE(Catalog.Currencies.EmptyRef))";
		Else
			ExpressionAfter = FieldsNames.ExpressionAfter;
		EndIf;
		
		FieldsText = FieldsText  + "
		|" + FieldsNames.ExpressionBefore + FieldsNames.FieldName + "." + Field + ExpressionAfter;
		
		If FieldsNames.ExpressionAfter = "" Or FieldsNames.ExpressionAfter = ")" Or FieldsNames.Property("Alias") Then
			FieldsText = FieldsText + " AS "+ StrReplace(Field,".","");
		EndIf;
		
		If Count < Boundary Then
			FieldsText = FieldsText + FieldsNames.ExpressionJoin;
		EndIf;
		
		Count = Count + 1;
		
	EndDo;
	
	Return FieldsText;
	
EndFunction

// check the collection for the field "Period"
Function IsPeriodInCollection(Collection)
	
	HasPeriod = False;
	For each CurItem In Collection.StandardAttributes Do
		Item = CurItem; 
		If Item.Name = "Period" Then
			HasPeriod = True;
		EndIf;
	EndDo;
	
	Return HasPeriod;
	
EndFunction

Procedure DeployFieldsKeys(DimensionArray, FieldsKeysWhichNeedDeploy, ExcludedFields, GetFieldsThroughPoint = False)
	
	For each Field In FieldsKeysWhichNeedDeploy Do
		
		ItemIndex = DimensionArray.Find(Field);
		If ItemIndex <> Undefined Then
			DimensionArray.Delete(ItemIndex);
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure ReplaceFields(OriginalText, FieldReplacements, TableAlias = "TT")
	
	For each KeyAndValue In FieldReplacements Do
		OriginalText = StrReplace(OriginalText, TableAlias + "." + KeyAndValue.Key + " " + "AS", StrReplace(KeyAndValue.Value,"T.",TableAlias + ".") + " " + "AS");
	EndDo;
	
EndProcedure

#EndRegion
