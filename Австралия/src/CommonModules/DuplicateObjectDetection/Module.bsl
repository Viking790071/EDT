#Region Public

// Searches for duplicates for the specified value.
//
// Parameters:
//     SearchArea - String - a data table name (full metadata name) of the search area.
//                              For example "Catalog.Products". The search can be performed in 
//                              catalogs, charts of characteristic types, calculation types, and charts of accounts.
//
//     SampleObject - Arbitrary - an object with data of the item for which duplicates are searched.
//
//     AdditionalParameters - Arbitrary - a parameter to be passed to manager event handlers.
//
// Returns:
//     ValueTable - contains rows with description of duplicates.
// 
Function FindItemDuplicates(Val SearchArea, Val SampleObject, Val AdditionalParameters) Export
	
	DuplicatesSearchParameters = New Structure;
	DuplicatesSearchParameters.Insert("PrefilterComposer");
	DuplicatesSearchParameters.Insert("DuplicatesSearchArea", SearchArea);
	DuplicatesSearchParameters.Insert("TakeAppliedRulesIntoAccount", True);
	
	// From parameters
	DuplicatesSearchParameters.Insert("SearchRules", New ValueTable);
	DuplicatesSearchParameters.SearchRules.Columns.Add("Attribute", New TypeDescription("String"));
	DuplicatesSearchParameters.SearchRules.Columns.Add("Rule",  New TypeDescription("String"));
	
	// See DataProcessor.SearchAndDeletionOfDuplicates 
	DuplicatesSearchParameters.PrefilterComposer = New DataCompositionSettingsComposer;
	MetaArea = Metadata.FindByFullName(SearchArea);
	AvailableFilterAttributes = AvailableFilterMetaAttributesNames(MetaArea.StandardAttributes);
	AvailableFilterAttributes = ?(IsBlankString(AvailableFilterAttributes), ",", AvailableFilterAttributes)
		+ AvailableFilterMetaAttributesNames(MetaArea.Attributes);
	
	CompositionSchema = New DataCompositionSchema;
	DataSource = CompositionSchema.DataSources.Add();
	DataSource.DataSourceType = "Local";
	
	DataSet = CompositionSchema.DataSets.Add(Type("DataCompositionSchemaDataSetQuery"));
	DataSet.Query = "SELECT " + Mid(AvailableFilterAttributes, 2) + " FROM " + SearchArea;
	DataSet.AutoFillAvailableFields = True;
	
	DuplicatesSearchParameters.PrefilterComposer.Initialize( New DataCompositionAvailableSettingsSource(CompositionSchema) );
	
	// Applied script call
	SearchProcessing = DataProcessors.DuplicateObjectDetection.Create();
	
	UseAppliedRules = SearchProcessing.HasSearchForDuplicatesAreaAppliedRules(SearchArea);
	If UseAppliedRules Then
		AppliedParameters = New Structure;
		AppliedParameters.Insert("SearchRules",        DuplicatesSearchParameters.SearchRules);
		AppliedParameters.Insert("FilterComposer",    DuplicatesSearchParameters.PrefilterComposer);
		AppliedParameters.Insert("CompareRestrictions", New Array);
		AppliedParameters.Insert("ItemCountToCompare", 1500);
		
		SearchAreaManager = SearchProcessing.SearchForDuplicatesAreaManager(SearchArea);
		SearchAreaManager.DuplicatesSearchParameters(AppliedParameters, AdditionalParameters);
		
		DuplicatesSearchParameters.Insert("AdditionalParameters", AdditionalParameters);
	EndIf;
	
	DuplicatesGroups = SearchProcessing.DuplicatesGroups(DuplicatesSearchParameters, SampleObject);
	Result = DuplicatesGroups.DuplicatesTable;
	
	// Only one group, returning required items.
	For Each Row In Result.FindRows(New Structure("Parent", Undefined)) Do
		Result.Delete(Row);
	EndDo;
	BlankRef = SearchAreaManager.EmptyRef();
	For Each Row In Result.FindRows(New Structure("Ref", BlankRef)) Do
		Result.Delete(Row);
	EndDo;
	
	Return Result; 
EndFunction

#EndRegion

#Region Internal

Function CheckCanReplaceItemsString(ReplacementPairs, ReplacementParameters) Export
	
	Result = "";
	Errors = CheckCanReplaceItems(ReplacementPairs, ReplacementParameters);
	For Each KeyValue In Errors Do
		Result = Result + Chars.LF + KeyValue.Value;
	EndDo;
	Return TrimAll(Result);
	
EndFunction

Function CheckCanReplaceItems(ReplacementPairs, ReplacementParameters) Export
	
	If ReplacementPairs.Count() = 0 Then
		Return New Map;
	EndIf;
	
	For Each Item In ReplacementPairs Do
		FirstItem = Item.Key;
		Break;
	EndDo;
	
	ModuleManager = Common.ObjectManagerByRef(FirstItem);
	
	ObjectsList = New Map;
	DuplicateObjectsDetectionOverridable.OnDefineObjectsWithSearchForDuplicates(ObjectsList);
	ObjectInfo = ObjectsList[FirstItem.Metadata().FullName()];
	
	If ObjectInfo <> Undefined AND (ObjectInfo = "" Or StrFind(ObjectInfo, "CanReplaceItems") > 0) Then
		Return ModuleManager.CanReplaceItems(ReplacementPairs, ReplacementParameters);
	EndIf;
	
	Return New Map;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See ReportsOptionsOverridable.CustomizeReportOptions. 
Procedure OnSetUpReportsOptions(Settings) Export
	ModuleReportsOptions = Common.CommonModule("ReportsOptions");
	ModuleReportsOptions.CustomizeReportInManagerModule(Settings, Metadata.Reports.SearchForReferences);
EndProcedure

#EndRegion

#Region Private

// See DataProcessor.SearchAndDeletionOfDuplicates 
Function AvailableFilterMetaAttributesNames(Val MetaCollection)
	Result = "";
	StoreType = Type("ValueStorage");
	
	For Each MetaAttribute In MetaCollection Do
		IsStorage = MetaAttribute.Type.ContainsType(StoreType);
		If Not IsStorage Then
			Result = Result + "," + MetaAttribute.Name;
		EndIf
	EndDo;
	
	Return Result;
EndFunction

Procedure DefineUsageInstances(Val RefSet, Val ResultAddress) Export
	
	SearchTable = Common.UsageInstances(RefSet);
	
	Filter = New Structure("AuxiliaryData", False);
	ActualRows = SearchTable.FindRows(Filter);
	
	Result = SearchTable.Copy(ActualRows, "Ref");
	Result.Columns.Add("Occurrences", New TypeDescription("Number"));
	Result.FillValues(1, "Occurrences");
	
	Result.Indexes.Add("Ref");
	
	Result.GroupBy("Ref", "Occurrences");
	For Each Ref In RefSet Do
		If Result.Find(Ref, "Ref") = Undefined Then
			Result.Add().Ref = Ref;
		EndIf;
	EndDo;
	
	PutToTempStorage(Result, ResultAddress);
EndProcedure

// Replaces references in all data.
//
// Parameters:
//
//     ReplacementParameters - Structure - with properties ReplacementPairs and Parameters that 
//                                   correspond to Common.ReplaceReferences parameters with the same names.
//     ResultAddress - String - address of a temporary storage where the result of replacement is saved - ValueTable:
//       * Reference - AnyRef - a reference that was replaced.
//       * ErrorObject - Arbitrary - object - error cause.
//       * ErrorObjectPresentation - String - string representation of an error object.
//       * ErrorType - String - error type marker. Possible options:
//                              "LockError" - some objects were locked during reference processing
//                              "DataChanged" - data was changed by another user during processing
//                              "WritingError" - cannot write the object.
//                              "UnknownData" - data not planned for analysis was found during 
//                                                    processing. The replacement is not completed
//                              "CannotReplace" - the CanReplaceItems method returned a failure.
//       * ErrorText - String - detailed error description.
//
Procedure ReplaceReferences(ReplacementParameters, Val ResultAddress) Export
	
	Result = Common.ReplaceReferences(ReplacementParameters.ReplacementPairs, ReplacementParameters.Parameters);
	PutToTempStorage(Result, ResultAddress);
	
EndProcedure

// Generates a table of managed metadata objects and their general settings.
//
// Returns:
//   ValueTable - a list to be filled. Contains:
//       * FullName - String - a full name of table object metadata.
//       * ItemPresentation - String - item presentation for a user.
//       * ListPresentation - String - list presentation for a user.
//       * Deleted - Boolean - shows that a metadata object has the "Delete" prefix.
//       * EventDuplicatesSearchParameters - Boolean - shows whether there is a subscription to the corresponding event.
//       * EventOnDuplicatesSearch - Boolean - shows whether there is a subscription to the corresponding event.
//       * EventCanReplaceItems - Boolean - shows whether there is a subscription to the corresponding event.
//
Function MetadataObjectsSettings() Export
	Settings = New ValueTable;
	Settings.Columns.Add("Kind",                   New TypeDescription("String"));
	Settings.Columns.Add("FullName",             New TypeDescription("String"));
	Settings.Columns.Add("ItemPresentation", New TypeDescription("String"));
	Settings.Columns.Add("ListPresentation",   New TypeDescription("String"));
	Settings.Columns.Add("Removed",                New TypeDescription("Boolean"));
	Settings.Columns.Add("EventDuplicateSearchParameters",      New TypeDescription("Boolean"));
	Settings.Columns.Add("EventOnDuplicatesSearch",            New TypeDescription("Boolean"));
	Settings.Columns.Add("EventCanReplaceItems", New TypeDescription("Boolean"));
	
	AllConnectedEvents = New Map;
	DuplicateObjectsDetectionOverridable.OnDefineObjectsWithSearchForDuplicates(AllConnectedEvents);
	
	RegisterMetadataCollection(Settings, AllConnectedEvents, Metadata.Catalogs, "Catalog");
	RegisterMetadataCollection(Settings, AllConnectedEvents, Metadata.Documents, "Document");
	RegisterMetadataCollection(Settings, AllConnectedEvents, Metadata.ChartsOfAccounts, "ChartOfAccounts");
	RegisterMetadataCollection(Settings, AllConnectedEvents, Metadata.ChartsOfCalculationTypes, "ChartOfCalculationTypes");
	
	Result = Settings.Copy(New Structure("Removed", False));
	Result.Sort("ListPresentation");
	
	Return Result;
EndFunction

Procedure RegisterMetadataCollection(Settings, AllAttachedEvents, MetadataCollection, Kind)
	StandardProperties = New Structure("ObjectPresentation, ExtendedObjectPresentation, ListPresentation, ExtendedListPresentation");
	
	For Each MetadataObject In MetadataCollection Do
		If Not AccessRight("View", MetadataObject)
			Or Not Common.MetadataObjectAvailableByFunctionalOptions(MetadataObject) Then
			Continue; // Access denied. Do not display in the list.
		EndIf;
		
		TableRow = Settings.Add();
		TableRow.Kind = Kind;
		TableRow.FullName = MetadataObject.FullName();
		TableRow.Removed = StrStartsWith(MetadataObject.Name, "Delete");
		
		FillPropertyValues(StandardProperties, MetadataObject);
		If ValueIsFilled(StandardProperties.ObjectPresentation) Then
			TableRow.ItemPresentation = StandardProperties.ObjectPresentation;
		ElsIf ValueIsFilled(StandardProperties.ExtendedObjectPresentation) Then
			TableRow.ItemPresentation = StandardProperties.ExtendedObjectPresentation;
		Else
			TableRow.ItemPresentation = MetadataObject.Presentation();
		EndIf;
		If ValueIsFilled(StandardProperties.ListPresentation) Then
			TableRow.ListPresentation = StandardProperties.ListPresentation;
		ElsIf ValueIsFilled(StandardProperties.ExtendedListPresentation) Then
			TableRow.ListPresentation = StandardProperties.ExtendedListPresentation;
		Else
			TableRow.ListPresentation = MetadataObject.Presentation();
		EndIf;
		
		Events = AllAttachedEvents[TableRow.FullName];
		If TypeOf(Events) = Type("String") Then
			If IsBlankString(Events) Then
				TableRow.EventDuplicateSearchParameters      = True;
				TableRow.EventOnDuplicatesSearch            = True;
				TableRow.EventCanReplaceItems = True;
			Else
				TableRow.EventDuplicateSearchParameters      = StrFind(Events, "DuplicatesSearchParameters") > 0;
				TableRow.EventOnDuplicatesSearch            = StrFind(Events, "OnSearchForDuplicates") > 0;
				TableRow.EventCanReplaceItems = StrFind(Events, "CanReplaceItems") > 0;
			EndIf;
		EndIf;
	EndDo;
EndProcedure

// Subsystem presentation. It is used for writing to the event log and in other places.
Function SubsystemDescription(ForUser) Export
	LanguageCode = ?(ForUser, CommonClientServer.DefaultLanguageCode(), "");
	Return NStr("ru = 'Поиск и удаление дублей'; en = 'Duplicate object detection'; pl = 'Wyszukiwanie i usuwanie duplikatów';es_ES = 'Buscar y eliminar los duplicados';es_CO = 'Buscar y eliminar los duplicados';tr = 'Kopyaları arama ve silme';it = 'Rilevamento oggetto duplicato';de = 'Duplikate suchen und entfernen'", LanguageCode);
EndFunction

#EndRegion