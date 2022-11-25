#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Private

//  Returns a user report in the spreadsheet document format.
//  The result is based on InfobaseNode and AdditionalRegistration attribute values.
//
//  Parameters:
//       FullMetadataName - String - restriction.
//       кPesentation       - String - a result parameter.
//       SimplifiedMode     - Boolean - template selection.
//
//  Returns:
//      SpreadsheetDocument - report.
//
Function GenerateUserSpreadsheetDocument(FullMetadataName = "", Presentation = "", SimplifiedMode = False) Export
	SetPrivilegedMode(True);
	
	CompositionData = InitializeComposer();
	
	If IsBlankString(FullMetadataName) Then
		DetailsData = New DataCompositionDetailsData;
		OptionName = "UserData"; 
	Else
		DetailsData = Undefined;
		OptionName = "DetailsByObjectKind"; 
	EndIf;
	
	// Saving filter settings
	FiltersSettings = CompositionData.SettingsComposer.GetSettings();
	
	// Applying the selected option
	CompositionData.SettingsComposer.LoadSettings(
		CompositionData.CompositionSchema.SettingVariants[OptionName].Settings);
	
	// Restoring filter settings
	AddDataCompositionFilterValues(CompositionData.SettingsComposer.Settings.Filter.Items, 
		FiltersSettings.Filter.Items);
	
	Parameters = CompositionData.CompositionSchema.Parameters;
	Parameters.Find("CreationDate").Value = CurrentSessionDate();
	Parameters.Find("SimplifiedMode").Value  = SimplifiedMode;
	
	Parameters.Find("CommonSynchronizationParameterText").Value = DataExchangeServer.DataSynchronizationRuleDetails(InfobaseNode);
	Parameters.Find("AdditionalParameterText").Value     = AdditionalParameterText();
	
	If Not IsBlankString(FullMetadataName) Then
		Parameters.Find("ListPresentation").Value = Presentation;
		
		FilterItems = CompositionData.SettingsComposer.Settings.Filter.Items;
		
		Item = FilterItems.Add(Type("DataCompositionFilterItem"));
		Item.LeftValue  = New DataCompositionField("FullMetadataName");
		Item.Presentation  = Presentation;
		Item.ComparisonType   = DataCompositionComparisonType.Equal;
		Item.RightValue = FullMetadataName;
		Item.Use  = True;
	EndIf;
	
	ComposerSettings = CompositionData.SettingsComposer.GetSettings();
	If SimplifiedMode Then
		// Disabling some fields
		HiddenFields = New Structure("CountByGeneralRules, RegistrationAdditionally, CommonCount, NoExport, CanExportObject");
		For Each Group In ComposerSettings.Structure Do
			HideSelectionFields(Group.Selection.Items, HiddenFields)
		EndDo;
		// Modifying footer section.
		GroupsCount = ComposerSettings.Structure.Count();
		If GroupsCount > 0 Then
			ComposerSettings.Structure[GroupsCount - 1].Name = "EmptyFooter";
		EndIf;
	EndIf;

	TemplateComposer = New DataCompositionTemplateComposer;
	Template = TemplateComposer.Execute(CompositionData.CompositionSchema, ComposerSettings, DetailsData, , Type("DataCompositionTemplateGenerator"));
	ExternalDataSets = New Structure("MetadataTableNodeComposition", CompositionData.MetadataTableNodeComposition);
	
	Toller = New DataCompositionProcessor;
	Toller.Initialize(Template, ExternalDataSets, DetailsData, True);
	
	Output = New DataCompositionResultSpreadsheetDocumentOutputProcessor;
	Output.SetDocument(New SpreadsheetDocument);
	
	Return New Structure("SpreadsheetDocument, Details, CompositionSchema",
		Output.Output(Toller), DetailsData, CompositionData.CompositionSchema);
EndFunction

//  Returns a two-level tree where the first level contains metadata types and the second level contains metadata objects.
//  The result is based on InfobaseNode and AdditionalRegistration attribute values.
//
//  Parameters:
//      MetadataNameList - Array - an array of full metadata names for restricting a query.
//                                      This parameter can contain a collection of objects that have the FullMetadataName field.
//  Returns:
//      ValuesTree - a two-level tree where the first level contains metadata types and the second level contains metadata objects.
//
Function GenerateValueTree(MetadataNameList = Undefined) Export
	SetPrivilegedMode(True);
	
	CompositionData = InitializeComposer(MetadataNameList);
	
	TemplateComposer = New DataCompositionTemplateComposer;
	Template = TemplateComposer.Execute(CompositionData.CompositionSchema, CompositionData.SettingsComposer.GetSettings(), , , 
		Type("DataCompositionValueCollectionTemplateGenerator"));
	ExternalDataSets = New Structure("MetadataTableNodeComposition", CompositionData.MetadataTableNodeComposition);
	
	Toller = New DataCompositionProcessor;
	Toller.Initialize(Template, ExternalDataSets, , True);
	
	Output = New DataCompositionResultValueCollectionOutputProcessor;
	Output.SetObject(New ValueTree);
	ResultTree = Output.Output(Toller);
	
	Return ResultTree;
EndFunction

//  Initializes the data processor.
//
//  Parameters:
//      Souce - String, UUID - an address in a temporary storage where the source object is placed or data.
//
//  Returns:
//      DataProcessorObject - InteractiveExportModification.
//
Function InitializeThisObject(Val Source = "") Export
	
	If TypeOf(Source)=Type("String") Then
		If IsBlankString(Source) Then
			Return ThisObject;
		EndIf;
		Source = GetFromTempStorage(Source);
	EndIf;
		
	FillPropertyValues(ThisObject, Source, , "AllDocumentsFilterComposer, AdditionalRegistration, AdditionalNodeScenarioRegistration");
	
	DataExchangeServer.FillValueTable(AdditionalRegistration, Source.AdditionalRegistration);
	DataExchangeServer.FillValueTable(AdditionalNodeScenarioRegistration, Source.AdditionalNodeScenarioRegistration);
	
	// Reinitializing composer.
	If IsBlankString(Source.AllDocumentsComposerAddress) Then
		Data = CommonFilterSettingsComposer();
	Else
		Data = GetFromTempStorage(Source.AllDocumentsComposerAddress);
	EndIf;
		
	AllDocumentsFilterComposer = New DataCompositionSettingsComposer;
	AllDocumentsFilterComposer.Initialize(
		New DataCompositionAvailableSettingsSource(Data.CompositionSchema));
	AllDocumentsFilterComposer.LoadSettings(Data.Settings);
	
	If IsBlankString(Source.AllDocumentsComposerAddress) Then
		AllDocumentsComposerAddress = PutToTempStorage(Data, Source.FromStorageAddress);
	Else 
		AllDocumentsComposerAddress = Source.AllDocumentsComposerAddress;
	EndIf;
		
	Return ThisObject;
EndFunction

//  Saves this object data in the temporary storage.
//
//  Parameters:
//      StorageAddress - String, UUID - a storage form ID or an address.
//
//  Returns:
//      String - an addess of saved.
//
Function SaveThisObject(Val StorageAddress) Export
	Data = New Structure;
	For Each Meta In Metadata().Attributes Do
		Name = Meta.Name;
		Data.Insert(Name, ThisObject[Name]);
	EndDo;
	
	ComposerData = CommonFilterSettingsComposer();
	Data.Insert("AllDocumentsComposerAddress", PutToTempStorage(ComposerData, StorageAddress));
	
	Return PutToTempStorage(Data, StorageAddress);
EndFunction

//  Returns composer data for common filters of the InfobaseNode node.
//  The result is based on InfobaseNode and AdditionalRegistration attribute values.
//
//  Parameters:
//      SchemaSavingAddress - String, UUID - a temporary storage address for saving the composition 
//                             schema.
//
// Returns:
//      Structure - fields:
//          * Settings       - DataCompositionSettings - composer settings.
//          * CompositionSchema - DataCompositionSchema     - a composition schema.
//
Function CommonFilterSettingsComposer(SchemaSavingAddress = Undefined) Export
	
	SavedOption = ExportOption;
	ExportOption = 1;
	AddressToSave = ?(SchemaSavingAddress = Undefined, New UUID, SchemaSavingAddress);
	Data = InitializeComposer(Undefined, True, AddressToSave);
	ExportOption = SavedOption;
	
	Result = New Structure;
	Result.Insert("Settings",  Data.SettingsComposer.Settings);
	Result.Insert("CompositionSchema", Data.CompositionSchema);
	
	Return Result;
EndFunction

//  Returns a filter composer for a single metadata type of the node specified in the InfobaseNode attribute.
//
//  Parameters:
//      FullMetadataName  - String - a table name for filling composer settings. Perhaps there will 
//                                      be IDs for all documents or all catalogs.
//                                      or reference to the group.
//      Presentation        - String - object presentation in the filter.
//      Filter - DataCompositionFilter - a composition filter for filling.
//      SchemaSavingAddress - String, UUID - a temporary storage address for saving the composition 
//                             schema.
//
// Returns:
//      DataCompositionSettingsComposer - an initialized composer.
//
Function SettingsComposerByTableName(FullMetadataName, Presentation = Undefined, Filter = Undefined, SchemaSavingAddress = Undefined) Export
	
	CompositionSchema = New DataCompositionSchema;
	
	Source = CompositionSchema.DataSources.Add();
	Source.Name = "Source";
	Source.DataSourceType = "local";
	
	TablesToAdd = EnlargedMetadataGroupComposition(FullMetadataName);
	
	For Each TableName In TablesToAdd Do
		AddSetToCompositionSchema(CompositionSchema, TableName, Presentation);
	EndDo;
	
	Composer = New DataCompositionSettingsComposer;
	Composer.Initialize(New DataCompositionAvailableSettingsSource(
		PutToTempStorage(CompositionSchema, SchemaSavingAddress)));
	
	If Filter <> Undefined Then
		AddDataCompositionFilterValues(Composer.Settings.Filter.Items, Filter.Items);
		Composer.Refresh(DataCompositionSettingsRefreshMethod.CheckAvailability);
	EndIf;
	
	Return Composer;
EndFunction

// Returns:
//     String - a prefix o receive fom names of the curent objcts.
//
Function BaseNameForForm() Export
	Return Metadata().FullName() + "."
EndFunction

// Returns:
//     String - a title to generate presentation by all documents.
//
Function AllDocumentsFilterGroupTitle() Export
	Return NStr("ru='Все документы'; en = 'All documents'; pl = 'Wszystkie dokumenty';es_ES = 'Todos documentos';es_CO = 'Todos documentos';tr = 'Tüm belgeler';it = 'Tutti i documenti';de = 'Alle Dokumente'");
EndFunction

// Returns:
//     String - a title for presentation generation by all catalogs.
//
Function AllCatalogsFilterGroupTitle() Export
	Return NStr("ru='Все справочники'; en = 'All catalogs'; pl = 'Wszystkie katalogi';es_ES = 'Todos catálogos';es_CO = 'Todos catálogos';tr = 'Tüm kataloglar';it = 'Tutti le anagrafiche';de = 'Alle Kataloge'");
EndFunction

//  Returns period and filter details as string.
//
//  Parameters:
//      Period - StandardPeriod - period for filter details.
//      Filter - DataCompositionFilter - a data composition filter for details.
//      EmptyFilterDetails - String - the function returns this value if an empty filter is passed.
// Returns:
//     String - presentation of period and filter.
//
Function FilterPresentation(Period, Filter, Val EmptyFilterDetails = Undefined) Export
	Return DataExchangeServer.ExportAdditionFilterPresentation(Period, Filter, EmptyFilterDetails);
EndFunction

//  Returns details of the detailed filter by the AdditionalRegistration attribute.
//
//  Parameters:
//      EmptyFilterDetails - String - the function returns this value if an empty filter is passed.
// Returns:
//     String - detailed filter presentation by the AdditionalRegistration attribute.
//
Function DetailedFilterPresentation(Val EmptyFilterDetails=Undefined)
	Return DataExchangeServer.DetailedExportAdditionPresentation(AdditionalRegistration, EmptyFilterDetails);
EndFunction

// The "All documents" metadata object internal group ID.
// Returns:
//     String - the "All documents" metadata object internal group ID.
//
Function AllDocumentsID() Export
	// The ID must not be identical to the full metadata name.
	Return DataExchangeServer.ExportAdditionAllDocumentsID();
EndFunction

// Returns:
//     String - the "All catalogs" metadata object internal group ID.
//
Function AllCatalogsID() Export
	// The ID must not be identical to the full metadata name.
	Return DataExchangeServer.ExportAdditionAllCatalogsID();
EndFunction

//  Adds a filter to the filter end with possible fields adjustment.
//
//  Parameters:
//      DestinationItems - DataCompositionFilterItemsCollection - a destination.
//      SourceItems - DataCompositionFilterItemsCollection - source.
//      FieldMap - Map - determines the composition of the filter fields to be replaced.
//                          * Key - an initial path to the field data.
//                          * Value - a path for the result.
//                          For example, to replace type fields.
//                          "Ref.Description" -> "RegistrationObject.Description".
//                          pass New Structure("Ref", "RegistrationObject").
//
Procedure AddDataCompositionFilterValues(DestinationItems, SourceItems, FieldsMap = Undefined) Export
	
	For Each Item In SourceItems Do
		
		Type=TypeOf(Item);
		FilterItem = DestinationItems.Add(Type);
		FillPropertyValues(FilterItem, Item);
		If Type=Type("DataCompositionFilterItemGroup") Then
			AddDataCompositionFilterValues(FilterItem.Items, Item.Items, FieldsMap);
			
		ElsIf FieldsMap<>Undefined Then
			SourceFieldAsString = Item.LeftValue;
			For Each KeyValue In FieldsMap Do
				ControlNew     = Lower(KeyValue.Key);
				ControlLength     = 1 + StrLen(ControlNew);
				SourceControl = Lower(Left(SourceFieldAsString, ControlLength));
				If SourceControl=ControlNew Then
					FilterItem.LeftValue = New DataCompositionField(KeyValue.Value);
					Break;
				ElsIf SourceControl=ControlNew + "." Then
					FilterItem.LeftValue = New DataCompositionField(KeyValue.Value + Mid(SourceFieldAsString, ControlLength));
					Break;
				EndIf;
			EndDo;
			
		EndIf;
		
	EndDo;
	
EndProcedure

//  Returns a value list item by presentation.
//
//  Parameters:
//      ValueList - ValueList - a search list.
//      Presentation  - String         - search parameter.
//
// Returns:
//      ListItem - a found item.
//      Undefined - if an item is not found.
//
Function FindByPresentationListItem(ValueList, Presentation)
	For Each ListItem In ValueList Do
		If ListItem.Presentation=Presentation Then
			Return ListItem;
		EndIf;
	EndDo;
	Return Undefined;
EndFunction

//  Carries out additional registration by current object data.
//
Procedure RecordAdditionalChanges() Export
	
	If ExportOption <= 0 Then
		// no change
		Return;
	EndIf;
	
	ChangesTree = GenerateValueTree();
	
	SetPrivilegedMode(True);
	For Each GroupString In ChangesTree.Rows Do
		For Each Row In GroupString.Rows Do
			If Row.ToExportCount > 0 Then
				DataExchangeEvents.RecordDataChanges(InfobaseNode, Row.RegistrationObject, False);
			EndIf;
		EndDo;
	EndDo;
	
EndProcedure

//  Returns a value list that contains all available settings presentations.
//
//  Parameters:
//      ExchangeNode - ExchangePlanRef - an exchange node for getting settings. If it is not 
//                                      specified, the current InfobaseNode attribute value is used.
//      Options - Array             - if specified, the settings are filtered as follows:
//                                      0 - without filter, 1 - all document filter, 2 - detailed, 3 - node scenario.
//
//  Returns:
//      ValueList - possible settings.
//
Function ReadSettingsListPresentations(ExchangeNode = Undefined, Options = Undefined) Export
	
	SettingsParameters = SettingsParameterStructure(ExchangeNode);
	
	SetPrivilegedMode(True);    
	VariantList = CommonSettingsStorage.Load(
	SettingsParameters.ObjectKey, SettingsParameters.SettingsKey,
	SettingsParameters, SettingsParameters.User);
	
	PresentationsList = New ValueList;
	If VariantList<>Undefined Then
		For Each Item In VariantList Do
			If Options=Undefined Or Options.Find(Item.Value.ExportOption)<>Undefined Then
				PresentationsList.Add(Item.Presentation, Item.Presentation);
			EndIf;
		EndDo;
	EndIf;
	
	Return PresentationsList;
EndFunction

//  Restores attribute values of the current object from the specified list item.
//
//  Parameters:
//      Presentation       - String - presentation of settings to be restored.
//      Options            - Array - if specified, the settings are filtered as follows:
//                                     0 - without filter, 1 - all document filter, 2 - detailed, 3 - node scenario.
//      FromStorageAddress - String, UUID - an optional address for saving.
//
// Returns:
//      Boolean - True - restored, False - the setting is not found.
//
Function RestoreCurrentAttributesFromSettings(Presentation, Options = Undefined, FromStorageAddress = Undefined) Export
	
	VariantList = ReadSettingsList(Options);
	ListItem = FindByPresentationListItem(VariantList, Presentation);
	
	Result = ListItem<>Undefined;
	If Result Then
		ConstantData = New Structure("InfobaseNode");
		FillPropertyValues(ConstantData, ThisObject);
		FillPropertyValues(ThisObject, ListItem.Value);
		FillPropertyValues(ThisObject, ConstantData);
		
		// Specifying composer options.
		Data = CommonFilterSettingsComposer();
		AllDocumentsFilterComposer = New DataCompositionSettingsComposer;
		AllDocumentsFilterComposer.Initialize(New DataCompositionAvailableSettingsSource(Data.CompositionSchema));
		AllDocumentsFilterComposer.LoadSettings(ListItem.Value._AllDocumentsFilterComposerSettings);
		
		// Initializing additional composer.
		If FromStorageAddress<>Undefined Then
			AllDocumentsComposerAddress = PutToTempStorage(Data, FromStorageAddress);
		EndIf;
	EndIf;
	
	Return Result;
EndFunction

//  Saves the values of the current object attributes to settings in the specified presentation.
//
//  Parameters:
//      Presentation         - String - settings presentation.
//
Procedure SaveCurrentValuesInSettings(Presentation) Export
	VariantList = ReadSettingsList();
	
	ListItem = FindByPresentationListItem(VariantList, Presentation);
	If ListItem=Undefined Then
		ListItem = VariantList.Add(, Presentation);
		VariantList.SortByPresentation();
	EndIf;
	
	AttributesToSave = "InfobaseNode, ExportOption, AllDocumentsFilterPeriod, AdditionalRegistration,
		|NodeScenarioFilterPeriod, AdditionalNodeScenarioRegistration, NodeScenarioFilterPresentation";
	
	ListItem.Value = New Structure(AttributesToSave);
	FillPropertyValues(ListItem.Value, ThisObject);
	
	ListItem.Value.Insert("_AllDocumentsFilterComposerSettings", AllDocumentsFilterComposer.Settings);
	
	SettingsParameters = SettingsParameterStructure();
	
	SetPrivilegedMode(True);
	CommonSettingsStorage.Save(
		SettingsParameters.ObjectKey, SettingsParameters.SettingsKey, 
		VariantList, 
		SettingsParameters, SettingsParameters.User);
EndProcedure

//  Removes a settings option from the list.
//
//  Parameters:
//      Presentation          - String - settings presentation.
//
Procedure DeleteSettingsOption(Presentation) Export
	VariantList = ReadSettingsList();
	ListItem = FindByPresentationListItem(VariantList, Presentation);
	
	If ListItem<>Undefined Then
		VariantList.Delete(ListItem);
		VariantList.SortByPresentation();
		SaveSettingsList(VariantList);
	EndIf;
	
EndProcedure

// Returns a name array of metadata tables according to the FullMetadataName composite parameter type.
// The result is based on the current InfobaseNode attribute value.
//
// Parameters:
//      String, ValueTree - metadata object name (for example Catalog.Currencies), or predefined 
//                            group name (for example AllDocuments), or value tree that describes a 
//                            group
//
// Returns:
//      Array - metadata names.
//
Function EnlargedMetadataGroupComposition(FullMetadataName) Export
	
	If TypeOf(FullMetadataName) <> Type("String") Then
		// Value tree with filter a group. Root - description, in rows - metadata names.
		CompositionTable = New Array;
		For Each GroupString In FullMetadataName.Rows Do
			For Each GroupCompositionRow In GroupString.Rows Do
				CompositionTable.Add(GroupCompositionRow.FullMetadataName);
			EndDo;
		EndDo;
		
	ElsIf FullMetadataName = AllDocumentsID() Then
		// Getting names of all node documents
		AllData = DataExchangeCached.ExchangePlanContent(InfobaseNode.Metadata().Name, True, False);
		CompositionTable = AllData.UnloadColumn("FullMetadataName");
		
	ElsIf FullMetadataName = AllCatalogsID() Then
		// Getting names of all node catalogs
		AllData = DataExchangeCached.ExchangePlanContent(InfobaseNode.Metadata().Name, False, True);
		CompositionTable = AllData.UnloadColumn("FullMetadataName");
		
	Else
		// Single metadata table.
		CompositionTable = New Array;
		CompositionTable.Add(FullMetadataName);
		
	EndIf;
	
	// Hiding items with NotExport set.
	NotExportMode = Enums.ExchangeObjectExportModes.DoNotExport;
	ExportModes   = DataExchangeCached.UserExchangePlanComposition(InfobaseNode);
	
	Position = CompositionTable.UBound();
	While Position >= 0 Do
		If ExportModes[CompositionTable[Position]] = NotExportMode Then
			CompositionTable.Delete(Position);
		EndIf;
		Position = Position - 1;
	EndDo;
	
	Return CompositionTable;
EndFunction

//  Value table constructor. Generates a table with custom type columns.
//
//  Parameters:
//      ColumnList  - String - a list of table columns separated by commas.
//      IndexList - String - a list of table indexes separated by commas.
//
// Returns:
//      ValueTable - a generated table.
//
Function ValueTable(ColumnsList, IndexList = "")
	ResultTable = New ValueTable;
	
	For Each KeyValue In (New Structure(ColumnsList)) Do
		ResultTable.Columns.Add(KeyValue.Key);
	EndDo;
	For Each KeyValue In (New Structure(IndexList)) Do
		ResultTable.Indexes.Add(KeyValue.Key);
	EndDo;
	
	Return ResultTable;
EndFunction

//  Adds a single filter item to the list
//
//  Parameters:
//      FilterItems - DataCompositionFilterItem - a reference to the object to check.
//      DataPathField - String - data path of the filter item.
//      ComparisonType - DataCompositionComparisonType - a type of comparison for item to be added.
//      Values - Arbitrary - a comparison value for item to be added.
//      Presentation    -String - optional field presentation.
//      
Procedure AddFilterItem(FilterItems, DataPathField, ComparisonType, Value, Presentation = Undefined)
	
	Item = FilterItems.Add(Type("DataCompositionFilterItem"));
	Item.Use  = True;
	Item.LeftValue  = New DataCompositionField(DataPathField);
	Item.ComparisonType   = ComparisonType;
	Item.RightValue = Value;
	
	If Presentation<>Undefined Then
		Item.Presentation = Presentation;
	EndIf;
EndProcedure

//  Adds a data set with one Reference field by the table name in the composition schema.
//
//  Parameters:
//      DataCompositionSchema - DataCompositionSchema - a schema being modified.
//      TableName:           - String - a data table name.
//      Presentation:        - String - the Reference field presentation.
//
Procedure AddSetToCompositionSchema(DataCompositionSchema, TableName, Presentation = Undefined)
	
	Set = DataCompositionSchema.DataSets.Add(Type("DataCompositionSchemaDataSetQuery"));
	Set.Query = "
		|SELECT 
		|   Ref
		|FROM 
		|   " + TableName + "
		|";
	Set.AutoFillAvailableFields = True;
	Set.DataSource = DataCompositionSchema.DataSources[0].Name;
	Set.Name = "Set" + Format(DataCompositionSchema.DataSets.Count()-1, "NZ=; NG=");
	
	Field = Set.Fields.Add(Type("DataCompositionSchemaDataSetField"));
	Field.Field = "Ref";
	Field.Title = ?(Presentation=Undefined, DataExchangeServer.ObjectPresentation(TableName), Presentation);
	
EndProcedure

//  Adds a structure from the collection to the composition structure.
//
//  Parameters:
//      DestinationItems - DataCompositionSettingsStructureItemsCollection -a destination.
//      SourceItems - DataCompositionSettingsStructureItemsCollection - source.
//
Procedure AddCompositionStructureValues(DestinationItems, SourceItems)
	For Each Item In SourceItems Do
		Type=TypeOf(Item);
		FilterItem = DestinationItems.Add(Type);
		FillPropertyValues(FilterItem, Item);
		If Type=Type("DataCompositionGroup") Then
			AddCompositionStructureValues(FilterItem.Items, Item.Items);
		EndIf;
	EndDo
EndProcedure

//  Sets the data sets to the schema and initializes the composer.
//  Is based on attribute values:
//    "InfobaseNode", "AdditionalRegistration",
//    "ExportVariant", "AllDocumentsFilterPeriod", "AllDocumentsFilterComposer".
//
//  Parameters:
//      MetadataNameList - Array - metadata names (trees of restriction group values, internal IDs
//                                      
//                                      of "All documents" or "All regulatory data") that serve as a basis for the composition schema.
//                                      If it is Undefined, all metadata types from node content are used.
//
//      LimitUsingWithFilter - Boolean - a flag showing whether composition schema is initialized 
//                                                  only for export item filter.
//
//      SchemaSavingAddress - String, UUID - a temporary storage address for saving the composition 
//                             schema.
//
//  Returns:
//      Structure - the following fields:
//         * NodeContentMetadataTable - ValueTable - node content description.
//         * CompositionSchema - CompositionDataSchema - an initialized value.
//         * SettingsComposer - DataCompositionSettingsComposer - an initialized value.
//
Function InitializeComposer(MetadataNameList = Undefined, LimitUsageWithFilter = False, SchemaSavingAddress = Undefined)
	
	NodeCompositionMetadataTable = DataExchangeCached.ExchangePlanContent(InfobaseNode.Metadata().Name);
	CompositionSchema = GetTemplate("DataCompositionSchema");
	
	// Sets for total count.
	ItemsSetsCounts = CompositionSchema.DataSets.TotalItemsCount.Items;
	
	// Sets for each metadata type included in the exchange.
	SetItemsChanges = CompositionSchema.DataSets.ChangeRegistration.Items;
	While SetItemsChanges.Count() > 1 Do
		// [0] - Field details
		SetItemsChanges.Delete(SetItemsChanges[1]);
	EndDo;
	DataSource = CompositionSchema.DataSources[0].Name;
	
	// Filling the MetadataNameFilter.
	MetadataNameFilter = New Map;
	If MetadataNameList <> Undefined Then
		If TypeOf(MetadataNameList) = Type("Array") Then
			For Each MetaName In MetadataNameList Do
				MetadataNameFilter.Insert(MetaName, True);
			EndDo;
		Else
			For Each Item In MetadataNameList Do
				MetadataNameFilter.Insert(Item.FullMetadataName, True);
			EndDo;
		EndIf;
	EndIf;
	
	// Automatic changes and counts are always used in filter settings.
	For Each Row In NodeCompositionMetadataTable Do
		FullMetadataName = Row.FullMetadataName;
		If MetadataNameList <> Undefined AND MetadataNameFilter[FullMetadataName] <> True Then
			Continue;
		EndIf;
		
		MetadataSetName = StrReplace(FullMetadataName, ".", "_");
		SetName = "Auto_" + MetadataSetName;
		If SetItemsChanges.Find(SetName) = Undefined Then
			Set = SetItemsChanges.Add(Type("DataCompositionSchemaDataSetQuery"));
			Set.AutoFillAvailableFields = Not LimitUsageWithFilter;
			Set.DataSource = DataSource;
			Set.Name = SetName;
			Set.Query = "
				|SELECT DISTINCT ALLOWED
				|	" + SetName + "_Changes.Ref         AS RegistrationObject,
				|	TYPE(" + FullMetadataName + ") AS RegistrationObjectType,
				|	&RegistrationReasonAutomatically AS RegistrationReason
				|FROM
				|	" + FullMetadataName + ".Changes AS " + SetName + "_Changes
				|WHERE " + SetName + "_Changes.Node = &InfobaseNode
				|";
		EndIf;
		
		SetName = "Count_" + MetadataSetName;
		If ItemsSetsCounts.Find(SetName) = Undefined Then
			Set = ItemsSetsCounts.Add(Type("DataCompositionSchemaDataSetQuery"));
			Set.AutoFillAvailableFields = True;
			Set.DataSource = DataSource;
			Set.Name = SetName;
			Set.Query = "
				|SELECT ALLOWED
				|	TYPE(" + FullMetadataName + ")     AS Type,
				|	COUNT(" + SetName + ".Ref) AS CommonCount
				|FROM
				|	" + FullMetadataName + " AS " + SetName + "
				|";
		EndIf;
		
	EndDo;
	
	// Additional modification options.
	If ExportOption = 1 Then
		// General filter by header attributes
		AdditionalChangeTable = ValueTable("FullMetadataName, Filter, Period, SelectPeriod");
		Row = AdditionalChangeTable.Add();
		Row.FullMetadataName = AllDocumentsID();
		Row.SelectPeriod        = True;
		Row.Period              = AllDocumentsFilterPeriod;
		Row.Filter               = AllDocumentsFilterComposer.Settings.Filter;
		
	ElsIf ExportOption = 2 Then
		// Detailed filter
		AdditionalChangeTable = AdditionalRegistration;
		
	Else
		// Additional filter options are not being used.
		AdditionalChangeTable = New ValueTable;
		
	EndIf;
	
	// Additional changes
	For Each Row In AdditionalChangeTable Do
		FullMetadataName = Row.FullMetadataName;
		If MetadataNameList <> Undefined AND MetadataNameFilter[FullMetadataName] <> True Then
			Continue;
		EndIf;
		
		TablesToAdd = EnlargedMetadataGroupComposition(FullMetadataName);
		For Each NameOfTableToAdd In TablesToAdd Do
			If MetadataNameList <> Undefined AND MetadataNameFilter[NameOfTableToAdd] <> True Then
				Continue;
			EndIf;
			
			SetName = "Additionally_" + StrReplace(NameOfTableToAdd, ".", "_");
			If SetItemsChanges.Find(SetName) = Undefined Then 
				Set = SetItemsChanges.Add(Type("DataCompositionSchemaDataSetQuery"));
				Set.DataSource = DataSource;
				Set.AutoFillAvailableFields = True;
				Set.Name = SetName;
				
				Set.Query = "
					|SELECT ALLOWED
					|	" + SetName + ".Ref           AS RegistrationObject,
					|	TYPE(" + NameOfTableToAdd + ") AS RegistrationObjectType,
					|	&RegistrationReasonAdvanced   AS RegistrationReason
					|FROM
					|	" + NameOfTableToAdd + " AS " + SetName + "
					|";
					
				// Adding additional sets to receive data of their filter tabular sections.
				AddingOptions = New Structure;
				AddingOptions.Insert("NameOfTableToAdd", NameOfTableToAdd);
				AddingOptions.Insert("CompositionSchema",       CompositionSchema);
				AddTabularSectionCompositionAdditionalSets(Row.Filter.Items, AddingOptions)
			EndIf;
			
		EndDo;
	EndDo;
	
	// Common parameters
	Parameters = CompositionSchema.Parameters;
	Parameters.Find("InfobaseNode").Value = InfobaseNode;
	
	AutomaticallyParameter = Parameters.Find("RegistrationReasonAutomatically");
	AutomaticallyParameter.Value = NStr("ru = 'По общим правилам'; en = 'By common rules'; pl = 'Według wspólnych zasad';es_ES = 'Por reglas comunes';es_CO = 'Por reglas comunes';tr = 'Genel kurallara göre';it = 'Con regole comuni';de = 'Nach allgemeinen Regeln'");
	
	AdditionallyParameter = Parameters.Find("RegistrationReasonAdvanced");
	AdditionallyParameter.Value = NStr("ru = 'Дополнительно'; en = 'More'; pl = 'Więcej';es_ES = 'Más';es_CO = 'Más';tr = 'Daha fazla';it = 'Di Più';de = 'Mehr'");
	
	ParameterByRef = Parameters.Find("RegistrationReasonByRef");
	ParameterByRef.Value = NStr("ru = 'По ссылке'; en = 'By reference'; pl = 'Przez odniesienie\link';es_ES = 'Por referencia';es_CO = 'Por referencia';tr = 'Referans olarak';it = 'Per riferimento';de = 'Mit Bezugnahme'");
	
	If LimitUsageWithFilter Then
		Fields = CompositionSchema.DataSets.ChangeRegistration.Fields;
		Restriction = Fields.Find("RegistrationObjectType").UseRestriction;
		Restriction.Condition = True;
		Restriction = Fields.Find("RegistrationReason").UseRestriction;
		Restriction.Condition = True;
		
		Fields = CompositionSchema.DataSets.MetadataTableNodeComposition.Fields;
		Restriction = Fields.Find("ListPresentation").UseRestriction;
		Restriction.Condition = True;
		Restriction = Fields.Find("Presentation").UseRestriction;
		Restriction.Condition = True;
		Restriction = Fields.Find("FullMetadataName").UseRestriction;
		Restriction.Condition = True;
		Restriction = Fields.Find("Periodic").UseRestriction;
		Restriction.Condition = True;
	EndIf;
	
	SettingsComposer = New DataCompositionSettingsComposer;
	
	SettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(
		PutToTempStorage(CompositionSchema, SchemaSavingAddress)));
	SettingsComposer.LoadSettings(CompositionSchema.DefaultSettings);
	
	If AdditionalChangeTable.Count() > 0 Then 
		
		If LimitUsageWithFilter Then
			SettingsRoot = SettingsComposer.FixedSettings;
		Else
			SettingsRoot = SettingsComposer.Settings;
		EndIf;
		
		// Adding additional data filter settings.
		FilterGroup = SettingsRoot.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
		FilterGroup.Use = True;
		FilterGroup.GroupType = DataCompositionFilterItemsGroupType.OrGroup;
		
		FilterItems = FilterGroup.Items;
		
		// Adding autoregistration filter options.
		AddFilterItem(FilterGroup.Items, "RegistrationReason", DataCompositionComparisonType.Equal, AutomaticallyParameter.Value);
		AddFilterItem(FilterGroup.Items, "RegistrationReason", DataCompositionComparisonType.Equal, ParameterByRef.Value);
		
		For Each Row In AdditionalChangeTable Do
			FullMetadataName = Row.FullMetadataName;
			If MetadataNameList <> Undefined AND MetadataNameFilter[FullMetadataName] <> True Then
				Continue;
			EndIf;
			
			TablesToAdd = EnlargedMetadataGroupComposition(FullMetadataName);
			For Each NameOfTableToAdd In TablesToAdd Do
				If MetadataNameList <> Undefined AND MetadataNameFilter[NameOfTableToAdd] <> True Then
					Continue;
				EndIf;
				
				FilterGroup = FilterItems.Add(Type("DataCompositionFilterItemGroup"));
				FilterGroup.Use = True;
				
				AddFilterItem(FilterGroup.Items, "FullMetadataName", DataCompositionComparisonType.Equal, NameOfTableToAdd);
				AddFilterItem(FilterGroup.Items, "RegistrationReason",  DataCompositionComparisonType.Equal, AdditionallyParameter.Value);
				
				If Row.SelectPeriod Then
					StartDate    = Row.Period.StartDate;
					EndDate = Row.Period.EndDate;
					If StartDate <> '00010101' Then
						AddFilterItem(FilterGroup.Items, "RegistrationObject.Date", DataCompositionComparisonType.GreaterOrEqual, StartDate);
					EndIf;
					If EndDate <> '00010101' Then
						AddFilterItem(FilterGroup.Items, "RegistrationObject.Date", DataCompositionComparisonType.LessOrEqual, EndDate);
					EndIf;
				EndIf;
				
				// Adding filter items with field replacement: "Ref" -> "RegistrationObject.
				AddingOptions = New Structure;
				AddingOptions.Insert("NameOfTableToAdd", NameOfTableToAdd);
				AddTabularSectionCompositionAdditionalFilters(
					FilterGroup.Items, Row.Filter.Items, SetItemsChanges, 
					AddingOptions);
			EndDo;
		EndDo;
		
	EndIf;
	
	Return New Structure("MetadataTableNodeComposition,CompositionSchema,SettingsComposer", 
		NodeCompositionMetadataTable, CompositionSchema, SettingsComposer);
EndFunction

Procedure AddTabularSectionCompositionAdditionalSets(SourceItems, AddingOptions)
	
	NameOfTableToAdd = AddingOptions.NameOfTableToAdd;
	CompositionSchema       = AddingOptions.CompositionSchema;
	
	CommonSet = CompositionSchema.DataSets.ChangeRegistration;
	DataSource = CompositionSchema.DataSources[0].Name; 
	
	ObjectMetadata = Metadata.FindByFullName(NameOfTableToAdd);
	If ObjectMetadata = Undefined Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("ru='Некорректное имя метаданных ""%1"" для регистрации на узле ""%2""'; en = 'Incorrect metadata name ""%1"" for registration at node ""%2""'; pl = 'Nieprawidłowa nazwa metadanych ""%1"" do rejestracji w węźle ""%2""';es_ES = 'Nombre incorrecto de metadatos ""%1"" para registrar en el nodo ""%2""';es_CO = 'Nombre incorrecto de metadatos ""%1"" para registrar en el nodo ""%2""';tr = '%1 ünitesinde kayıt için meta verilerin %2 yanlış adı';it = 'Nome metadati non corretto ""%1"" per registrazione nel nodo ""%2""';de = 'Falscher Metadatenname ""%1"" für die Registrierung auf dem Knoten ""%2""'"),
				NameOfTableToAdd, InfobaseNode);
	EndIf;
		
	For Each Item In SourceItems Do
		
		If TypeOf(Item) = Type("DataCompositionFilterItemGroup") Then 
			AddTabularSectionCompositionAdditionalSets(Item.Items, AddingOptions);
			Continue;
		EndIf;
		
		// It is an item, analyzing passed data kind.
		FieldName = Item.LeftValue;
		If StrStartsWith(FieldName, "Ref.") Then
			FieldName = Mid(FieldName, 8);
		ElsIf StrStartsWith(FieldName, "RegistrationObject.") Then
			FieldName = Mid(FieldName, 19);
		Else
			Continue;
		EndIf;
			
		Position = StrFind(FieldName, "."); 
		TableName   = Left(FieldName, Position - 1);
		TabularSectionMetadata = ObjectMetadata.TabularSections.Find(TableName);
			
		If Position = 0 Then
			// Filter of header attributes can be retrieved by reference.
			Continue;
		ElsIf TabularSectionMetadata = Undefined Then
			// The tabular section does not match the conditions.
			Continue;
		EndIf;
		
		// The tabular section that matches the conditions
		DataPath = Mid(FieldName, Position + 1);
		If StrStartsWith(DataPath + ".", "Ref.") Then
			// Redirecting to the parent table.
			Continue;
		EndIf;
		
		Alias = StrReplace(NameOfTableToAdd, ".", "") + TableName;
		SetName = "Additionally_" + Alias;
		Set = CommonSet.Items.Find(SetName);
		If Set <> Undefined Then
			Continue;
		EndIf;
		
		Set = CommonSet.Items.Add(Type("DataCompositionSchemaDataSetQuery"));
		Set.AutoFillAvailableFields = True;
		Set.DataSource = DataSource;
		Set.Name = SetName;
		
		AllTabularSectionFields = TabularSectionAttributesForQuery(TabularSectionMetadata, Alias);
		Set.Query = "
			|SELECT ALLOWED
			|	Ref                             AS RegistrationObject,
			|	TYPE(" + NameOfTableToAdd + ") AS RegistrationObjectType,
			|	&RegistrationReasonAdvanced   AS RegistrationReason
			|	" + AllTabularSectionFields.QueryFields +  "
			|FROM
			|	" + NameOfTableToAdd + "." + TableName + "
			|";
			
		For Each FieldName In AllTabularSectionFields.FieldsNames Do
			Field = Set.Fields.Find(FieldName);
			If Field = Undefined Then
				Field = Set.Fields.Add(Type("DataCompositionSchemaDataSetField"));
				Field.DataPath = FieldName;
				Field.Field        = FieldName;
			EndIf;
			Field.AttributeUseRestriction.Condition = True;
			Field.AttributeUseRestriction.Field    = True;
			Field.UseRestriction.Condition = True;
			Field.UseRestriction.Field    = True;
		EndDo;
		
	EndDo;
		
EndProcedure

Procedure AddTabularSectionCompositionAdditionalFilters(DestinationItems, SourceItems, SetItems, AddingOptions)
	
	NameOfTableToAdd = AddingOptions.NameOfTableToAdd;
	MetaObject = Metadata.FindByFullName(NameOfTableToAdd);
	
	For Each Item In SourceItems Do
		// The analysis script fragment is similar to the script fragment in the AddTabularSectionCompositionAdditionalSets procedure.
		
		Type = TypeOf(Item);
		If Type = Type("DataCompositionFilterItemGroup") Then
			// Copying filter item
			FilterItem = DestinationItems.Add(Type);
			FillPropertyValues(FilterItem, Item);
			
			AddTabularSectionCompositionAdditionalFilters(
				FilterItem.Items, Item.Items, SetItems, 
				AddingOptions);
			Continue;
		EndIf;
		
		// It is an item, analyzing passed data kind.
		FieldName = String(Item.LeftValue);
		If FieldName = "Ref" Then
			FilterItem = DestinationItems.Add(Type);
			FillPropertyValues(FilterItem, Item);
			FilterItem.LeftValue = New DataCompositionField("RegistrationObject");
			Continue;
			
		ElsIf StrStartsWith(FieldName, "Ref.") Then
			FieldName = Mid(FieldName, 8);
			
		ElsIf StrStartsWith(FieldName, "RegistrationObject.") Then
			FieldName = Mid(FieldName, 19);
			
		Else
			FilterItem = DestinationItems.Add(Type);
			FillPropertyValues(FilterItem, Item);
			Continue;
			
		EndIf;
			
		Position    = StrFind(FieldName, "."); 
		TableName = Left(FieldName, Position - 1);
		
		MetaTabularSection = MetaObject.TabularSections.Find(TableName);
		MetaAttributes      = MetaObject.Attributes.Find(TableName);
			
		If Position = 0
			Or MetaAttributes <> Undefined
			Or Common.IsStandardAttribute(MetaObject.StandardAttributes, TableName) Then
			// Header attribute filter is retrieved by reference.
			FilterItem = DestinationItems.Add(Type);
			FillPropertyValues(FilterItem, Item);
			FilterItem.LeftValue = New DataCompositionField("RegistrationObject." + FieldName);
			Continue;
			
		ElsIf MetaTabularSection = Undefined Then
			// Specified tabular section does not match conditions. Adjusting the filter settings.
			FilterItem = DestinationItems.Add(Type);
			FillPropertyValues(FilterItem, Item);
			FilterItem.LeftValue  = New DataCompositionField("FullMetadataName");
			FilterItem.ComparisonType   = DataCompositionComparisonType.Equal;
			FilterItem.Use  = True;
			FilterItem.RightValue = "";
			
			Continue;
		EndIf;
		
		// Setting up filter for a tabular section
		DataPath = Mid(FieldName, Position + 1);
		If StrStartsWith(DataPath + ".", "Ref.") Then
			// Redirecting to the parent table.
			FilterItem = DestinationItems.Add(Type);
			FillPropertyValues(FilterItem, Item);
			FilterItem.LeftValue = New DataCompositionField("RegistrationObject." + Mid(DataPath, 8));
			
		ElsIf DataPath <> "LineNumber" AND DataPath <> "Ref"
			AND MetaTabularSection.Attributes.Find(DataPath) = Undefined Then
			// Tabular section is correct but an attribute does not match conditions Adjusting the filter settings.
			FilterItem = DestinationItems.Add(Type);
			FillPropertyValues(FilterItem, Item);
			FilterItem.LeftValue  = New DataCompositionField("FullMetadataName");
			FilterItem.ComparisonType   = DataCompositionComparisonType.Equal;
			FilterItem.Use  = True;
			FilterItem.RightValue = "";
			
		Else
			// Modifying filter item name
			FilterItem = DestinationItems.Add(Type);
			FillPropertyValues(FilterItem, Item);
			DataPath = StrReplace(NameOfTableToAdd + TableName, ".", "") + DataPath;
			FilterItem.LeftValue = New DataCompositionField(DataPath);
		EndIf;
		
	EndDo;
	
EndProcedure

Function TabularSectionAttributesForQuery(Val MetaTabularSection, Val Prefix = "")
	
	QueryFields = ", LineNumber AS " + Prefix + "LineNumber
	              |, Ref      AS " + Prefix + "Ref
	              |";
	
	FieldsNames  = New Array;
	FieldsNames.Add(Prefix + "LineNumber");
	FieldsNames.Add(Prefix + "Ref");
	
	For Each MetaAttribute In MetaTabularSection.Attributes Do
		Name       = MetaAttribute.Name;
		Alias = Prefix + Name;
		QueryFields = QueryFields + ", " + Name + " AS " + Alias + Chars.LF;
		FieldsNames.Add(Alias);
	EndDo;
	
	Return New Structure("QueryFields, FieldsNames", QueryFields, FieldsNames);
EndFunction

//  Returns key parameters to save settings broken down by an exchange plan for all users.
//
//  Parameters:
//      ExchangeNode - ExchangePlanRef - a reference to an exchange node for getting settings. If it 
//                                      is not specified, the current InfobaseNode attribute value is used.
//
//  Returns:
//      SettingsDetails - settings description.
//
Function SettingsParameterStructure(ExchangeNode = Undefined)
	Node = ?(ExchangeNode=Undefined,  InfobaseNode, ExchangeNode);
	
	Meta = Node.Metadata();
	
	Presentation = Meta.ExtendedObjectPresentation;
	If IsBlankString(Presentation) Then
		Presentation = Meta.ObjectPresentation;
	EndIf;
	If IsBlankString(Presentation) Then
		Presentation = String(Meta);
	EndIf;
	
	SettingsParameters = New SettingsDescription();
	SettingsParameters.Presentation = Presentation;
	SettingsParameters.ObjectKey   = "InteractiveExportSettingsOptions";
	SettingsParameters.SettingsKey  = Meta.Name;
	SettingsParameters.User  = "*";
	
	Return SettingsParameters;
EndFunction

// Returns a settings list for the current InfobaseNode attribute value.
//
// Parameters:
//      Options - Array - if specified, the settings are filtered as follows:
//                          0 - without filter, 1 - all document filter, 2 - detailed, 3 - node scenario.
//
//  Returns:
//      ValueList - settings.
//
Function ReadSettingsList(Options = Undefined)
	SettingsParameters = SettingsParameterStructure();
	
	SetPrivilegedMode(True);
	VariantList = CommonSettingsStorage.Load(
		SettingsParameters.ObjectKey, SettingsParameters.SettingsKey, 
		SettingsParameters, SettingsParameters.User);
		
	If VariantList=Undefined Then
		Result = New ValueList;
	ElsIf Options=Undefined Then
		Result = VariantList;
	Else
		Result = VariantList;
		Position = Result.Count() - 1;
		While Position>=0 Do
			If Options.Find(Result[Position].Value.ExportOption)=Undefined Then
				Result.Delete(Position);
			EndIf;
			Position = Position - 1
		EndDo;
	EndIf;
		
	Return Result;
EndFunction

// Saves a settings list for the current InfobaseNode attribute value.
//
//  Parameters:
//      VariantList - ValueList - an option list to be saved.
//
Procedure SaveSettingsList(VariantList)
	SettingsParameters = SettingsParameterStructure();
	
	SetPrivilegedMode(True);
	If VariantList.Count()=0 Then
		CommonSettingsStorage.Delete(
			SettingsParameters.ObjectKey, SettingsParameters.SettingsKey, SettingsParameters.User);
	Else
		CommonSettingsStorage.Save(
			SettingsParameters.ObjectKey, SettingsParameters.SettingsKey, 
			VariantList, 
			SettingsParameters, SettingsParameters.User);
	EndIf;        
EndProcedure

// Returns a description for a selected export option.
//
Function AdditionalParameterText()
	
	If ExportOption = 0 Then
		// All automatic data
		Return NStr("ru='Без дополнительных данных.'; en = 'Export without additional data.'; pl = 'Bez dodatkowych danych.';es_ES = 'Sin datos adicionales.';es_CO = 'Sin datos adicionales.';tr = 'Ek veri yok.';it = 'Esportazione senza dati aggiuntivi.';de = 'Ohne zusätzliche Daten.'");
		
	ElsIf ExportOption = 1 Then
		AllDocumentsText = AllDocumentsFilterGroupTitle();
		Result = FilterPresentation(AllDocumentsFilterPeriod, AllDocumentsFilterComposer, AllDocumentsText);
		Return StrReplace(Result, "RegistrationObject.", AllDocumentsText + ".")
		
	ElsIf ExportOption = 2 Then
		Return DetailedFilterPresentation();
		
	EndIf;
	
	Return "";
EndFunction

// Returns a structure of object attributes.
//
Function ThisObjectInStructureForBackgroundJob() Export
	ResultStructure = New Structure();

	For Each Meta In Metadata().Attributes Do
		AttributeName = Meta.Name;
		If AttributeName = "AllDocumentsFilterComposer" Then
			Continue;
		EndIf;
		
		ResultStructure.Insert(AttributeName, ThisObject[AttributeName]);
	EndDo;
	// If an empty item is passed, it will be excluded from the data processor.
	ResultStructure.Insert("AllDocumentsFilterComposer");

	// Filling the structure with the AllDocumentsFilterComposer settings. Filter only.
	ResultStructure.Insert("AllDocumentsFilterComposerSettings", AllDocumentsFilterComposer.Settings);
	
	Return ResultStructure;
EndFunction

Procedure HideSelectionFields(GroupItems, Val HiddenFields)
	TypeGroup = Type("DataCompositionSelectedFieldGroup");
	For Each GroupingItem In GroupItems Do
		If TypeOf(GroupingItem)=TypeGroup Then
			HideSelectionFields(GroupingItem.Items, HiddenFields)
		Else
			FieldName = StrReplace(String(GroupingItem.Field), ".", "");
			If Not IsBlankString(FieldName) AND HiddenFields.Property(FieldName) Then
				GroupingItem.Use = False;
			EndIf;
		EndIf;
	EndDo;
EndProcedure

#EndRegion

#EndIf
