#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

// Defines the object manager to call applied rules.
//
// Parameters:
//   DataSearchAreaName - String - area name (full metadata name).
//
// Returns:
//   CatalogsManager, ChartsOfCharacteristicTypesManager,
//   ChartsOfAccountsManager, ChartsOfCalculationTypesManager - Object manager.
//
Function SearchForDuplicatesAreaManager(Val DataSearchAreaName) Export
	Meta = Metadata.FindByFullName(DataSearchAreaName);
	
	If Metadata.Catalogs.Contains(Meta) Then
		Return Catalogs[Meta.Name];
		
	ElsIf Metadata.ChartsOfCharacteristicTypes.Contains(Meta) Then
		Return ChartsOfCharacteristicTypes[Meta.Name];
		
	ElsIf Metadata.ChartsOfAccounts.Contains(Meta) Then
		Return ChartsOfAccounts[Meta.Name];
		
	ElsIf Metadata.ChartsOfCalculationTypes.Contains(Meta) Then
		Return ChartsOfCalculationTypes[Meta.Name];
		
	EndIf;
	
	Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Неизвестный тип объекта метаданных ""%1""'; en = 'Unknown metadata object type: ""%1""'; pl = 'Nieznany typ obiektu metadanych %1';es_ES = 'Tipo del objeto de metadatos desconocido ""%1""';es_CO = 'Tipo del objeto de metadatos desconocido ""%1""';tr = 'Bilinmeyen meta veri nesne türü ""%1""';it = 'Tipo di oggetto metadati sconosciuto: ""%1""';de = 'Unbekannter Metadaten-Objekttyp ""%1""'"), DataSearchAreaName);
EndFunction

// Direct search for duplicates.
//
// Parameters:
//     SearchParameters - Structure - describes search parameters.
//     SampleObject - Arbitrary - an object to compare when searching similar items.
//
// Returns:
//   Structure - Duplicates search results.
//       * DuplicateTable - ValueTable - found duplicates (displayed in the interface in 2 levels: Parents and Items).
//           ** Reference - Arbitrary - an item reference.
//           ** Code - Arbitrary - an item code.
//           ** Description - Arbitrary - item description.
//           ** Parent - Arbitrary - a parent of the duplicates group. If the Parent is empty, the 
//                                            item is parent for the duplicates group.
//           ** <Other fields> - Arbitrary - the value of the corresponding filter fields and criteria for comparing duplicates.
//       * ErrorDescription - Undefined - no errors occurred.
//                        - Row - Details of error occurred during the search for duplicates.
//       * UsageInstances - Undefined, ValueTable - filled in if
//           SearchParameters.CalculateUsageInstances = True.
//           For the table column details, see Common.UsageInstances().
//
Function DuplicatesGroups(Val SearchParameters, Val SampleObject = Undefined) Export
	FullMetadataObjectName = SearchParameters.DuplicatesSearchArea;
	MetadataObject = Metadata.FindByFullName(FullMetadataObjectName);
	ReadTable1FromDBMS = (SampleObject = Undefined);
	
	// 1. Determining parameters according to the applied script.
	ReturnedPortionSize = CommonClientServer.StructureProperty(SearchParameters, "MaxDuplicates");
	If Not ValueIsFilled(ReturnedPortionSize) Then
		ReturnedPortionSize = 0; // Without restriction.
	EndIf;
	
	CalculateUsageInstances = CommonClientServer.StructureProperty(SearchParameters, "CalculateUsageInstances");
	If TypeOf(CalculateUsageInstances) <> Type("Boolean") Then
		CalculateUsageInstances = False;
	EndIf;
	
	// For passing to the applied script.
	AdditionalParameters = CommonClientServer.StructureProperty(SearchParameters, "AdditionalParameters");
	
	// Calling applied script
	UseAppliedRules = SearchParameters.TakeAppliedRulesIntoAccount
		AND HasSearchForDuplicatesAreaAppliedRules(FullMetadataObjectName);
	
	EqualityCompareFields = ""; // Names of the attributes to be used for comparison by equality.
	LikeCompareFields   = ""; // Names of the attributes that are used for fuzzy comparison.
	AdditionalDataFields = ""; // Names of the addition attributes defined with the applied rules.
	AppliedPortionSize   = 0;  // Size of the data portion to be passed to the applied rules for calculating.
	
	If UseAppliedRules Then
		AppliedParameters = New Structure;
		AppliedParameters.Insert("SearchRules",        SearchParameters.SearchRules);
		AppliedParameters.Insert("CompareRestrictions", New Array);
		AppliedParameters.Insert("FilterComposer",    SearchParameters.PrefilterComposer);
		AppliedParameters.Insert("ItemCountToCompare", 1000);
		
		SearchAreaManager = Common.ObjectManagerByFullName(FullMetadataObjectName);
		SearchAreaManager.DuplicatesSearchParameters(AppliedParameters, AdditionalParameters);
		
		AllAdditionalFields = New Map;
		For Each Restriction In AppliedParameters.CompareRestrictions Do
			For Each KeyValue In New Structure(Restriction.AdditionalFields) Do
				FieldName = KeyValue.Key;
				If AllAdditionalFields[FieldName] = Undefined Then
					AdditionalDataFields = AdditionalDataFields + ", " + FieldName;
					AllAdditionalFields[FieldName] = True;
				EndIf;
			EndDo;
		EndDo;
		AdditionalDataFields = Mid(AdditionalDataFields, 2);
		
		// Size of the data portion to be passed to the applied rules for calculating.
		AppliedPortionSize = AppliedParameters.ItemCountToCompare;
	EndIf;
	
	// List of fields perhaps modified by the applied script.
	For Each Row In SearchParameters.SearchRules Do
		If Row.Rule = "Equal" Then
			EqualityCompareFields = EqualityCompareFields + ", " + Row.Attribute;
		ElsIf Row.Rule = "Like" Then
			LikeCompareFields = LikeCompareFields + ", " + Row.Attribute;
		EndIf
	EndDo;
	EqualityCompareFields = Mid(EqualityCompareFields, 2);
	LikeCompareFields   = Mid(LikeCompareFields, 2);
	
	IdentityFieldStructure   = New Structure(EqualityCompareFields);
	SimilarityFieldStructure        = New Structure(LikeCompareFields);
	AdditionalFieldsStructure = New Structure(AdditionalDataFields);
	
	// 2. Constructing by perhaps modified filter settings composer.
	Characteristics = New Structure;
	Characteristics.Insert("CodeLength", 0);
	Characteristics.Insert("NumberLength", 0);
	Characteristics.Insert("DescriptionLength", 0);
	Characteristics.Insert("Hierarchical", False);
	Characteristics.Insert("HierarchyType", Undefined);
	
	FillPropertyValues(Characteristics, MetadataObject);
	
	HasDescription = Characteristics.DescriptionLength > 0;
	HasCode          = Characteristics.CodeLength > 0;
	HasNumber        = Characteristics.NumberLength > 0;
	
	// Additional fields can intersect other ones, they must get aliases
	ApplicantsTable = New ValueTable;
	CandidateColumns = ApplicantsTable.Columns;
	CandidateColumns.Add("Ref1");
	CandidateColumns.Add("Fields1");
	CandidateColumns.Add("Ref2");
	CandidateColumns.Add("Fields2");
	CandidateColumns.Add("IsDuplicates", New TypeDescription("Boolean"));
	ApplicantsTable.Indexes.Add("IsDuplicates");
	
	FieldNamesInQuery = AvailableFilterAttributes(MetadataObject);
	If Not HasCode Then
		If HasNumber Then 
			FieldNamesInQuery = FieldNamesInQuery + ", Number AS Code";
		Else
			FieldNamesInQuery = FieldNamesInQuery + ", UNDEFINED AS Code";
		EndIf;
	EndIf;
	If Not HasDescription Then
		FieldNamesInQuery = FieldNamesInQuery + ", Ref AS Description";
	EndIf;
	FieldNamesInSelection  = StrSplit(EqualityCompareFields + "," + LikeCompareFields, ",", False);
	
	AdditionalFieldDetails = New Map;
	SequenceNumber = 0;
	For Each KeyValue In AdditionalFieldsStructure Do
		FieldName   = KeyValue.Key;
		Alias = "Addl" + Format(SequenceNumber, "NZ=; NG=") + "_" + FieldName;
		AdditionalFieldDetails.Insert(Alias, FieldName);
		
		FieldNamesInQuery = FieldNamesInQuery + "," + FieldName + " AS " + Alias;
		FieldNamesInSelection.Add(Alias);
		SequenceNumber = SequenceNumber + 1;
	EndDo;
	
	// Filling of the schema.
	DCSchema = New DataCompositionSchema;
	
	DCSchemaDataSource = DCSchema.DataSources.Add();
	DCSchemaDataSource.Name = "DataSource1";
	DCSchemaDataSource.DataSourceType = "Local";
	
	DataSet = DCSchema.DataSets.Add(Type("DataCompositionSchemaDataSetQuery"));
	DataSet.Name = "DataSet1";
	DataSet.DataSource = "DataSource1";
	DataSet.Query = "SELECT ALLOWED " + FieldNamesInQuery + " FROM " + FullMetadataObjectName;
	DataSet.AutoFillAvailableFields = True;
	
	// Composer initialization.
	DCSettingsComposer = New DataCompositionSettingsComposer;
	DCSettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(DCSchema));
	DCSettingsComposer.LoadSettings(SearchParameters.PrefilterComposer.Settings);
	DCSettings = DCSettingsComposer.Settings;
	
	// Fields.
	DCSettings.Selection.Items.Clear();
	For Each FieldName In FieldNamesInSelection Do
		DCField = New DataCompositionField(TrimAll(FieldName));
		AvailableDCField = DCSettings.SelectionAvailableFields.FindField(DCField);
		If AvailableDCField = Undefined Then
			WriteLogEvent(
				DuplicateObjectDetection.SubsystemDescription(False),
				EventLogLevel.Warning,
				MetadataObject,
				SampleObject,
				StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Поле ""%1"" не найдено.'; en = 'Field ""%1"" not found.'; pl = 'Pole ""%1"" nie znaleziono.';es_ES = 'Campo ""%1"" no encontrado.';es_CO = 'Campo ""%1"" no encontrado.';tr = '""%1"" alanı bulunamadı.';it = 'Campo ""%1"" non trovato.';de = 'Das Feld ""%1"" wurde nicht gefunden.'"), String(DCField)));
			Continue;
		EndIf;
		SelectedDCField = DCSettings.Selection.Items.Add(Type("DataCompositionSelectedField"));
		SelectedDCField.Field = DCField;
	EndDo;
	SelectedDCField = DCSettings.Selection.Items.Add(Type("DataCompositionSelectedField"));
	SelectedDCField.Field = New DataCompositionField("Ref");
	SelectedDCField = DCSettings.Selection.Items.Add(Type("DataCompositionSelectedField"));
	SelectedDCField.Field = New DataCompositionField("Code");
	SelectedDCField = DCSettings.Selection.Items.Add(Type("DataCompositionSelectedField"));
	SelectedDCField.Field = New DataCompositionField("Description");
	
	// Sorting.
	DCSettings.Order.Items.Clear();
	DCOrderingItem = DCSettings.Order.Items.Add(Type("DataCompositionOrderItem"));
	DCOrderingItem.Field = New DataCompositionField("Ref");
	
	// Filters.
	If Characteristics.Hierarchical
		AND Characteristics.HierarchyType = Metadata.ObjectProperties.HierarchyType.HierarchyFoldersAndItems Then
		DCFilterItem = DCSettings.Filter.Items.Add(Type("DataCompositionFilterItem"));
		DCFilterItem.LeftValue = New DataCompositionField("IsFolder");
		DCFilterItem.ComparisonType = DataCompositionComparisonType.Equal;
		DCFilterItem.RightValue = False;
	EndIf;
	
	If MetadataObject = Metadata.Catalogs.Users Then
		DCFilterItem = DCSettings.Filter.Items.Add(Type("DataCompositionFilterItem"));
		DCFilterItem.LeftValue  = New DataCompositionField("Internal");
		DCFilterItem.ComparisonType   = DataCompositionComparisonType.Equal;
		DCFilterItem.RightValue = False;
	EndIf;
	
	// Structure.
	DCSettings.Structure.Clear();
	DCGroup = DCSettings.Structure.Add(Type("DataCompositionGroup"));
	DCGroup.Selection.Items.Add(Type("DataCompositionAutoSelectedField"));
	DCGroup.Order.Items.Add(Type("DataCompositionAutoOrderItem"));
	
	// Reading original data.
	If ReadTable1FromDBMS Then
		Selection1 = InitializeDCSelection(DCSchema, DCSettingsComposer.GetSettings());
	Else
		ValueTable = ObjectIntoValueTable(SampleObject, AdditionalFieldDetails);
		If Not HasCode AND Not HasNumber Then
			ValueTable.Columns.Add("Code", New TypeDescription("Undefined"));
		EndIf;
		Selection1 = InitializeVTSelection(ValueTable);
	EndIf;
	
	// Preparing DCS to read the duplicate data.
	CandidatesFilter = New Map;
	FieldsNames = StrSplit(EqualityCompareFields, ",", False);
	For Each FieldName In FieldsNames Do
		FieldName = TrimAll(FieldName);
		DCFilterItem = DCSettings.Filter.Items.Add(Type("DataCompositionFilterItem"));
		DCFilterItem.LeftValue = New DataCompositionField(FieldName);
		DCFilterItem.ComparisonType = DataCompositionComparisonType.Equal;
		CandidatesFilter.Insert(FieldName, DCFilterItem);
	EndDo;
	DCFilterItem = DCSettings.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DCFilterItem.LeftValue = New DataCompositionField("Ref");
	If ReadTable1FromDBMS Then
		DCFilterItem.ComparisonType = DataCompositionComparisonType.Greater;
	Else
		DCFilterItem.ComparisonType = DataCompositionComparisonType.NotEqual;
	EndIf;
	CandidatesFilter.Insert("Ref", DCFilterItem);
	
	// Result and search loop
	DuplicatesTable = New ValueTable;
	ResultColumns = DuplicatesTable.Columns;
	ResultColumns.Add("Ref");
	For Each KeyValue In IdentityFieldStructure Do
		If ResultColumns.Find(KeyValue.Key) = Undefined Then
			ResultColumns.Add(KeyValue.Key);
		EndIf;
	EndDo;
	For Each KeyValue In SimilarityFieldStructure Do
		If ResultColumns.Find(KeyValue.Key) = Undefined Then
			ResultColumns.Add(KeyValue.Key);
		EndIf;
	EndDo;
	If ResultColumns.Find("Code") = Undefined Then
		ResultColumns.Add("Code");
	EndIf;
	If ResultColumns.Find("Description") = Undefined Then
		ResultColumns.Add("Description");
	EndIf;
	If ResultColumns.Find("Parent") = Undefined Then
		ResultColumns.Add("Parent");
	EndIf;
	
	DuplicatesTable.Indexes.Add("Ref");
	DuplicatesTable.Indexes.Add("Parent");
	DuplicatesTable.Indexes.Add("Ref, Parent");
	
	Result = New Structure("DuplicatesTable, ErrorDescription, UsageInstances", DuplicatesTable);
	
	FieldStructure = New Structure;
	FieldStructure.Insert("AdditionalFieldDetails", AdditionalFieldDetails);
	FieldStructure.Insert("IdentityFieldStructure",     IdentityFieldStructure);
	FieldStructure.Insert("SimilarityFieldStructure",          SimilarityFieldStructure);
	FieldStructure.Insert("IdentityFieldList",        EqualityCompareFields);
	FieldStructure.Insert("SimilarityFieldList",             LikeCompareFields);
	
	While NextSelectionItem(Selection1) Do
		TableRow1 = Selection1.CurrentItem;
		
		// Setting filter for candidates selection.
		For Each KeyAndValue In CandidatesFilter Do
			DCFilterItem = KeyAndValue.Value;
			DCFilterItem.RightValue = TableRow1[KeyAndValue.Key];
		EndDo;
		
		// Selection of data candidates from DBMS.
		Selection2 = InitializeDCSelection(DCSchema, DCSettings);
		Table2 = Selection2.DCOutputProcessor.Output(Selection2.DCProcessor);
		
		If SimilarityFieldStructure.Count() > 0 Then
			
			FuzzySearch = Common.AttachAddInFromTemplate("FuzzyStringMatchExtension", "CommonTemplate.StringSearchAddIn");
			If FuzzySearch = Undefined Then
				Result.ErrorDescription = 
					NStr("ru = 'Не удалось подключить внешнюю компоненту FuzzyStringMatchExtension
					           |из макета ""CommonTemplate.StringSearchAddIn""
					           |Подробнее см. в журнале регистрации.'; 
					           |en = 'Cannot attach the FuzzyStringMatchExtension add-in
					           |from CommonTemplate.StringSearchAddIn template.
					           |For more information, see the event log.'; 
					           |pl = 'Nie udało się podłączyć FuzzyStringMatchExtension add-in
					           |z CommonTemplate.StringSearchAddIn template.
					           |Więcej informacji można znaleźć w dzienniku wydarzenia.';
					           |es_ES = 'No se ha podido conectar el componente externo FuzzyStringMatchExtension
					           |de la plantilla CommonTemplate.StringSearchAddIn template
					           |Véase en el registro de eventos.';
					           |es_CO = 'No se ha podido conectar el componente externo FuzzyStringMatchExtension
					           |de la plantilla CommonTemplate.StringSearchAddIn template
					           |Véase en el registro de eventos.';
					           |tr = 'Harici bileşen FuzzyStringMatchExtension
					           | ""CommonTemplate.StringSearchAddIn"" maketinde bağlanamadı.
					           |Kayıt defterinde daha detaylı bkz.';
					           |it = 'Impossibile collegare il componente aggiuntivo FuzzyStringMatchExtension
					           |dal modello CommonTemplate.StringSearchAddIn.
					           |Per ulteriori informazioni consultare registro eventi.';
					           |de = 'Fehler beim Verbinden der externen Komponente FuzzyStringMatchExtension
					           |des Layouts ""AllgemeinesLayout.ZeichenkettenKomponenteSuchen""
					           |Weitere Informationen finden Sie im Ereignisprotokoll.'");
				Return Result;
			EndIf;
			For Each KeyValue In SimilarityFieldStructure Do
				FieldName = KeyValue.Key;
				RowsArray = Table2.UnloadColumn(FieldName);
				RowByArray = StrConcat(RowsArray,"~");
				SearchRow = TableRow1[FieldName];
				IndexArrayByString = FuzzySearch.StringSearch(Lower(SearchRow), Lower(RowByArray), "~", 10, 80, 90);
				If IsBlankString(IndexArrayByString) Then
					Continue;
				EndIf;
				IndexArray = StrSplit(IndexArrayByString, ",");
				If IndexArray.Count() > 0 Then
					For Each RowIndex In IndexArray Do
						If IsBlankString(RowIndex) Then
							Continue;
						EndIf;
						TableRow2 = Table2.Get(RowIndex);
						If UseAppliedRules Then
							// Filling the table for the applied rules, calling them if necessary.
							AddCandidateRow(ApplicantsTable, TableRow1, TableRow2, FieldStructure);
							If ApplicantsTable.Count() = AppliedPortionSize Then
								AddDuplicatesByAppliedRules(DuplicatesTable, SearchAreaManager, TableRow1, ApplicantsTable, FieldStructure, AdditionalParameters);
								ApplicantsTable.Clear();
							EndIf;
						Else
							// These are duplicates.
							AddDuplicateToResult(DuplicatesTable, TableRow1, TableRow2, FieldStructure);
						EndIf;
					EndDo;
				EndIf;
			EndDo;
		Else
			For Each TableRow2 In Table2 Do
				If UseAppliedRules Then
					// Filling the table for the applied rules, calling them if necessary.
					AddCandidateRow(ApplicantsTable, TableRow1, TableRow2, FieldStructure);
					If ApplicantsTable.Count() = AppliedPortionSize Then
						AddDuplicatesByAppliedRules(DuplicatesTable, SearchAreaManager, TableRow1, ApplicantsTable, FieldStructure, AdditionalParameters);
						ApplicantsTable.Clear();
					EndIf;
				Else
					// These are duplicates.
					AddDuplicateToResult(DuplicatesTable, TableRow1, TableRow2, FieldStructure);
				EndIf;
			EndDo;
		EndIf;
		
		// Processing the rest of the applied rule table.
		If UseAppliedRules Then
			AddDuplicatesByAppliedRules(DuplicatesTable, SearchAreaManager, TableRow1, ApplicantsTable, FieldStructure, AdditionalParameters);
			ApplicantsTable.Clear();
		EndIf;
		
		// Group analysis is completed, analyzing the result volume. Do not passing large volume of data to the client.
		If ReturnedPortionSize > 0 AND (DuplicatesTable.Count() > ReturnedPortionSize) Then
			// Rolling back the last group.
			For Each Row In DuplicatesTable.FindRows( New Structure("Parent ", TableRow1.Ref) ) Do
				DuplicatesTable.Delete(Row);
			EndDo;
			For Each Row In DuplicatesTable.FindRows( New Structure("Ref", TableRow1.Ref) ) Do
				DuplicatesTable.Delete(Row);
			EndDo;
			// In case of the last group, reporting error.
			If DuplicatesTable.Count() = 0 Then
				Result.ErrorDescription = NStr("ru = 'Найдено слишком много элементов, определены не все группы дублей.'; en = 'Too many items found. Not all groups of duplicates are determined.'; pl = 'Znaleziono zbyt wiele elementów, nie wszystkie zduplikowane grupy są zdefiniowane.';es_ES = 'Demasiados artículos se han encontrado, no todos los grupos de duplicados se han determinado.';es_CO = 'Demasiados artículos se han encontrado, no todos los grupos de duplicados se han determinado.';tr = 'Çok sayıda öğe bulundu, tüm yinelenen gruplar tanımlanmaz.';it = 'Troppi elementi trovati. Non tutti i gruppi di duplicati sono stati determinati.';de = 'Zu viele Elemente werden gefunden, Nicht alle doppelten Gruppen sind definiert.'");
			Else
				Result.ErrorDescription = NStr("ru = 'Найдено слишком много элементов. Уточните критерии поиска дублей.'; en = 'Too many items found. Refine the duplicate search criteria.'; pl = 'Znaleziono zbyt wiele elementów. Określ kryteriów wyszukiwania duplikatów.';es_ES = 'Demasiados artículos se han encontrado. Especificar los criterios de búsqueda de duplicados.';es_CO = 'Demasiados artículos se han encontrado. Especificar los criterios de búsqueda de duplicados.';tr = 'Çok fazla öğe bulundu. Yinelenen arama kriterlerini belirtin.';it = 'Trovati troppi elementi. Raffinare i criteri di ricerca duplicati.';de = 'Zu viele Elemente wurden gefunden. Geben Sie die doppelten Suchkriterien an.'");
			EndIf;
			Break;
		EndIf;
	EndDo;
	
	If Result.ErrorDescription <> Undefined Then
		Return Result;
	EndIf;
	
	// Calculating places of use
	If CalculateUsageInstances Then
		RefSet = New Array;
		For Each DuplicateRow In DuplicatesTable Do
			If ValueIsFilled(DuplicateRow.Ref) Then
				RefSet.Add(DuplicateRow.Ref);
			EndIf;
		EndDo;
		
		UsageInstances = SearchForReferences(RefSet);
		UsageInstances = UsageInstances.Copy(
			UsageInstances.FindRows(New Structure("AuxiliaryData", False)));
		UsageInstances.Indexes.Add("Ref");
		
		Result.Insert("UsageInstances", UsageInstances);
	EndIf;
	
	Return Result;
EndFunction

// Determining whether the object has applied rules.
//
// Parameters:
//     AreaManager - CatalogManager - manager of the object to be checked.
//
// Returns:
//     Boolean - True if applied rules are defined.
//
Function HasSearchForDuplicatesAreaAppliedRules(Val ObjectName) Export
	
	ObjectsList = New Map;
	DuplicateObjectsDetectionOverridable.OnDefineObjectsWithSearchForDuplicates(ObjectsList);
	
	ObjectInfo = ObjectsList[ObjectName];
	Return ObjectInfo <> Undefined AND (ObjectInfo = "" Or StrFind(ObjectInfo, "DuplicatesSearchParameters") > 0);
	
EndFunction

// Handler of background search for duplicates.
//
// Parameters:
//     Parameters - Structure - data to be analyzed.
//     ResultAddress - String - a temporary storage address to save result.
//
Procedure BackgroundSearchForDuplicates(Val Parameters, Val ResultAddress) Export
	
	// Rebuilding the composer through the schema and the settings.
	PrefilterComposer = New DataCompositionSettingsComposer;
	
	PrefilterComposer.Initialize( New DataCompositionAvailableSettingsSource(Parameters.CompositionSchema) );
	PrefilterComposer.LoadSettings(Parameters.PrefilterComposerSettings);
	
	Parameters.Insert("PrefilterComposer", PrefilterComposer);
	
	// Transforming the search rules into an indexed value table.
	SearchRules = New ValueTable;
	SearchRules.Columns.Add("Attribute", New TypeDescription("String") );
	SearchRules.Columns.Add("Rule",  New TypeDescription("String") );
	SearchRules.Indexes.Add("Attribute");
	
	For Each Rule In Parameters.SearchRules Do
		FillPropertyValues(SearchRules.Add(), Rule);
	EndDo;
	Parameters.Insert("SearchRules", SearchRules);
	
	Parameters.Insert("CalculateUsageInstances", True);
	
	// Starting the search
	PutToTempStorage(DuplicatesGroups(Parameters), ResultAddress);
EndProcedure

#EndRegion

#Region Private

// Deletes duplicates in background
//
// Parameters:
//     Parameters - Structure - data to be analyzed.
//     ResultAddress - String - a temporary storage address to save result.
//
Procedure BackgroundDuplicateDeletion(Val Parameters, Val ResultAddress) Export
	
	ReplacementParameters = New Structure;
	ReplacementParameters.Insert("DeletionMethod",       Parameters.DeletionMethod);
	ReplacementParameters.Insert("IncludeBusinessLogic", True);
	ReplacementParameters.Insert("TakeAppliedRulesIntoAccount", Parameters.TakeAppliedRulesIntoAccount);
	
	ReplaceReferences(Parameters.ReplacementPairs, ReplacementParameters, ResultAddress);
	
EndProcedure

// Converts an object to a table for adding to a query.
Function ObjectIntoValueTable(Val DataObject, Val AdditionalFieldDetails)
	Result = New ValueTable;
	DataString = Result.Add();
	
	MetaObject = DataObject.Metadata();
	
	For Each MetaAttribute In MetaObject.StandardAttributes  Do
		Name = MetaAttribute.Name;
		Result.Columns.Add(Name, MetaAttribute.Type);
		DataString[Name] = DataObject[Name];
	EndDo;
	
	For Each MetaAttribute In MetaObject.Attributes Do
		Name = MetaAttribute.Name;
		Result.Columns.Add(Name, MetaAttribute.Type);
		DataString[Name] = DataObject[Name];
	EndDo;
	
	For Each KeyAndValue In AdditionalFieldDetails Do
		Name1 = KeyAndValue.Key;
		Name2 = KeyAndValue.Value;
		Result.Columns.Add(Name1, Result.Columns[Name2].ValueType);
		DataString[Name1] = DataString[Name2];
	EndDo;
	
	Return Result;
EndFunction

// Additional analysis of candidates for duplicates by the applied method.
//
Procedure AddDuplicatesByAppliedRules(ResultTreeRows, Val SearchAreaManager, Val BasicData, Val ApplicantsTable, Val FieldStructure, Val AdditionalParameters)
	If ApplicantsTable.Count() = 0 Then
		Return;
	EndIf;
	
	SearchAreaManager.OnSearchForDuplicates(ApplicantsTable, AdditionalParameters);
	
	Data1 = New Structure;
	Data2 = New Structure;
	
	FoundItems = ApplicantsTable.FindRows(New Structure("IsDuplicates", True));
	For Each CandidateCouple In FoundItems Do
		Data1.Insert("Ref",       CandidateCouple.Ref1);
		Data1.Insert("Code",          CandidateCouple.Fields1.Code);
		Data1.Insert("Description", CandidateCouple.Fields1.Description);
		
		Data2.Insert("Ref",       CandidateCouple.Ref2);
		Data2.Insert("Code",          CandidateCouple.Fields2.Code);
		Data2.Insert("Description", CandidateCouple.Fields2.Description);
		
		For Each KeyValue In FieldStructure.IdentityFieldStructure Do
			FieldName = KeyValue.Key;
			Data1.Insert(FieldName, CandidateCouple.Fields1[FieldName]);
			Data2.Insert(FieldName, CandidateCouple.Fields2[FieldName]);
		EndDo;
		For Each KeyValue In FieldStructure.SimilarityFieldStructure Do
			FieldName = KeyValue.Key;
			Data1.Insert(FieldName, CandidateCouple.Fields1[FieldName]);
			Data2.Insert(FieldName, CandidateCouple.Fields2[FieldName]);
		EndDo;
		
		AddDuplicateToResult(ResultTreeRows, Data1, Data2, FieldStructure);
	EndDo;
EndProcedure

// Adding a row to the candidate table for the applied method.
//
Function AddCandidateRow(ApplicantsTable, Val MainItemData, Val CandidateData, Val FieldStructure)
	
	Row = ApplicantsTable.Add();
	Row.IsDuplicates = False;
	Row.Ref1  = MainItemData.Ref;
	Row.Ref2  = CandidateData.Ref;
	
	Row.Fields1 = New Structure("Code, Description", MainItemData.Code, MainItemData.Description);
	Row.Fields2 = New Structure("Code, Description", CandidateData.Code, CandidateData.Description);
	
	For Each KeyValue In FieldStructure.IdentityFieldStructure Do
		FieldName = KeyValue.Key;
		Row.Fields1.Insert(FieldName, MainItemData[FieldName]);
		Row.Fields2.Insert(FieldName, CandidateData[FieldName]);
	EndDo;
	
	For Each KeyValue In FieldStructure.SimilarityFieldStructure Do
		FieldName = KeyValue.Key;
		Row.Fields1.Insert(FieldName, MainItemData[FieldName]);
		Row.Fields2.Insert(FieldName, CandidateData[FieldName]);
	EndDo;
	
	For Each KeyValue In FieldStructure.AdditionalFieldDetails Do
		ColumnName = KeyValue.Value;
		FieldName    = KeyValue.Key;
		
		Row.Fields1.Insert(ColumnName, MainItemData[FieldName]);
		Row.Fields2.Insert(ColumnName, CandidateData[FieldName]);
	EndDo;
	
	Return Row;
EndFunction

// Adding the found option to the result tree.
//
Procedure AddDuplicateToResult(DuplicatesTable, Val TableRow1, Val TableRow2, Val FieldStructure)
	// Defining which item is already added to duplicates.
	DuplicateRow1 = DuplicatesTable.Find(TableRow1.Ref, "Ref");
	DuplicateRow2 = DuplicatesTable.Find(TableRow2.Ref, "Ref");
	Duplicate1Registered = (DuplicateRow1 <> Undefined);
	Duplicate2Registered = (DuplicateRow2 <> Undefined);
	
	// If both items are added to duplicates, do nothing.
	If Duplicate1Registered AND Duplicate2Registered Then
		Return;
	EndIf;
	
	// Before registering a duplicate, determine a reference to the group of duplicates.
	If Duplicate1Registered Then
		DuplicateGroupsReference = ?(ValueIsFilled(DuplicateRow1.Parent), DuplicateRow1.Parent, DuplicateRow1.Ref);
	ElsIf Duplicate2Registered Then
		DuplicateGroupsReference = ?(ValueIsFilled(DuplicateRow2.Parent), DuplicateRow2.Parent, DuplicateRow2.Ref);
	Else // Register group of duplicates.
		DuplicateGroup = DuplicatesTable.Add();
		DuplicateGroup.Ref = TableRow1.Ref;
		DuplicateGroupsReference = DuplicateGroup.Ref;
	EndIf;
	
	PropertiesList = "Ref, Code, Description," + FieldStructure.IdentityFieldList + "," + FieldStructure.SimilarityFieldList;
	
	If Not Duplicate1Registered Then
		DuplicateRow1 = DuplicatesTable.Add();
		FillPropertyValues(DuplicateRow1, TableRow1, PropertiesList);
		DuplicateRow1.Parent = DuplicateGroupsReference;
	EndIf;
	
	If Not Duplicate2Registered Then
		DuplicateRow2 = DuplicatesTable.Add();
		FillPropertyValues(DuplicateRow2, TableRow2, PropertiesList);
		DuplicateRow2.Parent = DuplicateGroupsReference;
	EndIf;
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// For offline work.

// [Common.UsageInstances]
Function SearchForReferences(Val RefSet, Val ResultAddress = "")
	
	Return Common.UsageInstances(RefSet, ResultAddress);
	
EndFunction

// [Common.ReplaceReferences]
Procedure ReplaceReferences(Val ReplacementPairs, Val Parameters = Undefined, Val ResultAddress = "")
	
	Result = Common.ReplaceReferences(ReplacementPairs, Parameters);
	If ResultAddress <> "" Then
		PutToTempStorage(Result, ResultAddress);
	EndIf;
		
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Other.

Function AvailableFilterAttributes(MetadataObject)
	AttributesArray = New Array;
	For Each AttributeMetadata In MetadataObject.StandardAttributes Do
		If AttributeMetadata.Type.ContainsType(Type("ValueStorage")) Then
			Continue;
		EndIf;
		AttributesArray.Add(AttributeMetadata.Name);
	EndDo;
	For Each AttributeMetadata In MetadataObject.Attributes Do
		If AttributeMetadata.Type.ContainsType(Type("ValueStorage")) Then
			Continue;
		EndIf;
		AttributesArray.Add(AttributeMetadata.Name);
	EndDo;
	Return StrConcat(AttributesArray, ",");
EndFunction

Function InitializeDCSelection(DCSchema, DCSettings)
	Selection = New Structure("Table, CurrentItem, IndexOf, UBound, DCProcessor, DCOutputProcessor");
	DCTemplateComposer = New DataCompositionTemplateComposer;
	DCTemplate = DCTemplateComposer.Execute(DCSchema, DCSettings, , , Type("DataCompositionValueCollectionTemplateGenerator"));
	
	Selection.DCProcessor = New DataCompositionProcessor;
	Selection.DCProcessor.Initialize(DCTemplate);
	
	Selection.Table = New ValueTable;
	Selection.IndexOf = -1;
	Selection.UBound = -100;
	
	Selection.DCOutputProcessor = New DataCompositionResultValueCollectionOutputProcessor;
	Selection.DCOutputProcessor.SetObject(Selection.Table);
	
	Return Selection;
EndFunction

Function InitializeVTSelection(ValueTable)
	Selection = New Structure("Table, CurrentItem, IndexOf, UBound, DCProcessor, DCOutputProcessor");
	Selection.Table = ValueTable;
	Selection.IndexOf = -1;
	Selection.UBound = ValueTable.Count() - 1;
	Return Selection;
EndFunction

Function NextSelectionItem(Selection)
	If Selection.IndexOf >= Selection.UBound Then
		If Selection.DCProcessor = Undefined Then
			Return False;
		EndIf;
		If Selection.UBound = -100 Then
			Selection.DCOutputProcessor.BeginOutput();
		EndIf;
		Selection.Table.Clear();
		Selection.IndexOf = -1;
		Selection.UBound = -1;
		While Selection.UBound = -1 Do
			DCResultItem = Selection.DCProcessor.Next();
			If DCResultItem = Undefined Then
				Selection.DCOutputProcessor.EndOutput();
				Return False;
			EndIf;
			Selection.DCOutputProcessor.OutputItem(DCResultItem);
			Selection.UBound = Selection.Table.Count() - 1;
		EndDo;
	EndIf;
	Selection.IndexOf = Selection.IndexOf + 1;
	Selection.CurrentItem = Selection.Table[Selection.IndexOf];
	Return True;
EndFunction

#EndRegion

#EndIf