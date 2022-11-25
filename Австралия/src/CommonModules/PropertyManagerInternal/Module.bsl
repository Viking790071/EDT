#Region Internal

// Returns the list of all metadata object properties.
//
// Parameters:
//  ObjectKind - String - a metadata object full name.
//  PropertyKind - String - AdditionalAttributes or AdditionalInfo.
//
// Returns:
//  ValueTable - Property, Description, and ValueType.
//  Undefined - there is no property set for the specified object kind.
//
Function PropertiesListForObjectsKind(ObjectsKind, Val PropertyKind) Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	PropertySets.Ref AS Ref,
	|	PropertySets.PredefinedDataName AS PredefinedDataName
	|FROM
	|	Catalog.AdditionalAttributesAndInfoSets AS PropertySets
	|WHERE
	|	PropertySets.Predefined";
	Selection = Query.Execute().Select();
	
	PredefinedDataName = StrReplace(ObjectsKind, ".", "_");
	SetRef = Undefined;
	
	While Selection.Next() Do
		If Selection.PredefinedDataName = PredefinedDataName Then
			SetRef = Selection.Ref;
			Break;
		EndIf;
	EndDo;
	
	If SetRef = Undefined Then
		Return Undefined;
	EndIf;
	
	QueryText = 
	"SELECT
	|	PropertiesTable.Property AS Property,
	|	PropertiesTable.Property.Description AS Description,
	|	PropertiesTable.Property.ValueType AS ValueType
	|FROM
	|	&PropertiesTable AS PropertiesTable
	|WHERE
	|	PropertiesTable.Ref IN HIERARCHY(&Ref)";
	
	FullTableName = "Catalog.AdditionalAttributesAndInfoSets." + PropertyKind;
	QueryText = StrReplace(QueryText, "&PropertiesTable", FullTableName);
	
	Query = New Query(QueryText);
	Query.SetParameter("Ref", SetRef);
	
	Result = Query.Execute().Unload();
	Result.GroupBy("Property,Description,ValueType");
	Result.Sort("Description Asc");
	
	Return Result;
	
EndFunction

//  Adds columns of additional attributes and properties to the column list for loading data.
//
// Parameters:
//  CatalogMetadata	 - MetadataObject - a catalog metadata.
//  ColumnsInformation	 - ValueTable - template columns.
//
Procedure ColumnsForDataImport(CatalogMetadata, ColumnsInformation) Export
	
	If CatalogMetadata.TabularSections.Find("AdditionalAttributes") <> Undefined Then
		
		Position = ColumnsInformation.Count() + 1;
		Properties = PropertyManager.ObjectProperties(Catalogs[CatalogMetadata.Name].EmptyRef());
		
		AdditionalInfo = New Array;
		For each Property In Properties Do
			If NOT Property.IsAdditionalInfo Then
				ColumnsInfoRow = ColumnsInformation.Add();
				ColumnName = StandardSubsystemsServer.TransformStringToValidColumnDescription(Property.Description);
				ColumnsInfoRow.ColumnName = "AdditionalAttribute_" + ColumnName;
				ColumnsInfoRow.ColumnPresentation = Property.Description;
				ColumnsInfoRow.ColumnType = Property.ValueType;
				ColumnsInfoRow.Required = Property.RequiredToFill;
				ColumnsInfoRow.Position = Position;
				ColumnsInfoRow.Group = NStr("ru = 'Доп. реквизиты'; en = 'Additional attributes'; pl = 'Dodatkowe atrybuty';es_ES = 'Atributos adicionales';es_CO = 'Atributos adicionales';tr = 'Ek öznitelikler';it = 'Attributi aggiuntivi';de = 'Zusätzliche Attribute'");
				ColumnsInfoRow.Visible = True;
				ColumnsInfoRow.Comment = Property.Description;
				ColumnsInfoRow.Width = 30;
				Position = Position + 1;
				
				Values = AdditionalPropertyValues(Property);
				If Values.Count() > 0 Then
					ColumnsInfoRow.Comment = ColumnsInfoRow.Comment  + Chars.LF + NStr("ru = 'Варианты значений:'; en = 'Value options:'; pl = 'Opcje wartości:';es_ES = 'Variantes de valores:';es_CO = 'Variantes de valores:';tr = 'Değer seçenekleri:';it = 'Opzioni valore:';de = 'Wertvarianten:'") + Chars.LF;
					For each Value In Values Do
						Code = ?(ValueIsFilled(Value.Code), " (" + Value.Code + ")", "");
						ColumnsInfoRow.Comment = ColumnsInfoRow.Comment + Value.Description + Code +Chars.LF;
					EndDo;
				EndIf;
			Else
				AdditionalInfo.Add(Property);
			EndIf;
		EndDo;
		
		For each Property In AdditionalInfo Do
			ColumnsInfoRow = ColumnsInformation.Add();
			ColumnName =  StandardSubsystemsServer.TransformStringToValidColumnDescription(Property.Description);
			ColumnsInfoRow.ColumnName = "Property_" + ColumnName;
			ColumnsInfoRow.ColumnPresentation = Property.Description;
			ColumnsInfoRow.ColumnType = Property.ValueType;
			ColumnsInfoRow.Required = Property.RequiredToFill;
			ColumnsInfoRow.Position = Position;
			ColumnsInfoRow.Group = NStr("ru = 'Доп. свойства'; en = 'Additional properties'; pl = 'Dodatkowe właściwości';es_ES = 'Propiedades adicionales';es_CO = 'Propiedades adicionales';tr = 'Ek özellikler';it = 'Ulteriori oggetti';de = 'Zusatzeigenschaften'");
			ColumnsInfoRow.Visible = True;
			ColumnsInfoRow.Comment = Property.Description;
			ColumnsInfoRow.Width = 30;
			Position = Position + 1;
			
			Values = AdditionalPropertyValues(Property);
			If Values.Count() > 0 Then
				ColumnsInfoRow.Comment = ColumnsInfoRow.Comment  + Chars.LF + NStr("ru = 'Варианты значений:'; en = 'Value options:'; pl = 'Opcje wartości:';es_ES = 'Variantes de valores:';es_CO = 'Variantes de valores:';tr = 'Değer seçenekleri:';it = 'Opzioni valore:';de = 'Wertvarianten:'") + Chars.LF;
				For each Value In Values Do
					Code = ?(ValueIsFilled(Value.Code), " (" + Value.Code + ")", "");
					ColumnsInfoRow.Comment = ColumnsInfoRow.Comment + Value.Description + Code +Chars.LF;
				EndDo;
			EndIf;
			
		EndDo;

	EndIf;

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See InfobaseUpdateSSL.OnAddUpdateHandlers. 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.SharedData = True;
	Handler.HandlerManagement = True;
	Handler.Version = "*";
	Handler.ExecutionMode = "Seamless";
	Handler.Procedure = "PropertyManagerInternal.FillSeparatedDataHandlers";
	
	Handler = Handlers.Add();
	Handler.Version = "*";
	Handler.ExecutionMode = "Seamless";
	Handler.Procedure = "PropertyManager.UpdatePropertyAndSetDescriptions";
	
	Handler = Handlers.Add();
	Handler.Version = "1.0.6.7";
	Handler.Procedure = "PropertyManagerInternal.UpdateAdditionalPropertyList_1_0_6";
	
	Handler = Handlers.Add();
	Handler.ExecuteInMandatoryGroup = True;
	Handler.Version = "2.1.5.3";
	Handler.Priority = 1;
	Handler.Procedure = "PropertyManagerInternal.FillNewData_2_1_5";
	
	Handler = Handlers.Add();
	Handler.Version = "2.1.5.18";
	Handler.ExecutionMode = "Deferred";
	Handler.ID = New UUID("b3885620-c224-49f1-bda0-4510c7c18584");
	Handler.Comment = NStr("ru = 'Реструктуризация дополнительных реквизитов и сведений.
		|Возможна некорректная работа отборов по дополнительным реквизитам и сведениям в списках.'; 
		|en = 'Restructuring additional attributes and information.
		|Filters by additional attributes and information in lists might work incorrectly.'; 
		|pl = 'Restrukturyzacja dodatkowych rekwizytów i informacji.
		|Może nie działać prawidłowo selekcja dodatkowych rekwizytów i informacji w listach.';
		|es_ES = 'La reestructuración de los requisitos adicionales y la información.
		|Es posible el funcionamiento incorrecto de las selecciones por requisitos adicionales y la información en las listas.';
		|es_CO = 'La reestructuración de los requisitos adicionales y la información.
		|Es posible el funcionamiento incorrecto de las selecciones por requisitos adicionales y la información en las listas.';
		|tr = 'Ek özellikleri ve bilgilerin yeniden yapılandırılması. 
		|İsteğe bağlı özellikler ve listelerdeki bilgiler için filtreler yanlış çalışıyor olabilir.';
		|it = 'Ristrutturazione di requisiti e informazioni aggiuntivi.
		|I filtri per requisiti e informazioni aggiuntivi negli elenchi potrebbero funzionare in modo errato.';
		|de = 'Neustrukturierung von zusätzlichen Attributen und Informationen.
		|Eine Fehlbedienung von Selektionen aufgrund von zusätzlichen Attributen und Informationen in den Listen ist möglich.'");
	Handler.Procedure = "PropertyManagerInternal.RefreshPropertiesCompositionOfAllSetsGroups";
	
	Handler = Handlers.Add();
	Handler.Version = "2.3.1.14";
	Handler.Procedure = "PropertyManagerInternal.FillNewAdditionalAttributesAndInfoProperties";
	Handler.ExecutionMode = "Exclusive";
	
	Handler = Handlers.Add();
	Handler.Version = "2.3.1.21";
	Handler.Procedure = "PropertyManagerInternal.SetUsageFlagValue";
	Handler.ExecutionMode = "Seamless";
	Handler.InitialFilling = True;
	
	Handler = Handlers.Add();
	Handler.Version = "3.0.1.101";
	Handler.ID = New UUID("ecd6aad4-4b04-43be-82bc-cd4f563beb0b");
	Handler.Procedure = "ChartsOfCharacteristicTypes.AdditionalAttributesAndInfo.ProcessDataForMigrationToNewVersion";
	Handler.Comment = NStr("ru = 'Заполняет уникальное имя дополнительных реквизитов и сведений.
		|Редактирование дополнительных реквизитов и сведений будет недоступно до завершения обновления.'; 
		|en = 'Fills in a unique name of additional attributes and information.
		|Editing of additional attributes and information will not be available until the update is complete.'; 
		|pl = 'Wypełnia unikalną nazwę dodatkowych rekwizytów i informacji. 
		|Edycja dodatkowych danych i informacji będzie niedostępna aż do zakończenia procesu aktualizacji.';
		|es_ES = 'Rellena el nombre único de los requisitos adicionales y la información.
		|La edición de los requisitos adicionales y la información no estará disponible hasta terminar la actualización.';
		|es_CO = 'Rellena el nombre único de los requisitos adicionales y la información.
		|La edición de los requisitos adicionales y la información no estará disponible hasta terminar la actualización.';
		|tr = 'Ek özelliklerin ve bilgilerin benzersiz adını doldurur. 
		|Ek özelliklerin ve bilgilerin düzenlenmesi güncelleme bitmeden yapılamaz.';
		|it = 'Inserisci un nome univoco dei requisiti e informazioni aggiuntivi.
		|Non sarà possibile modificare i requisiti e le informazioni aggiuntivi fino al completamento dell''aggiornamento.';
		|de = 'Neustrukturierung von zusätzlichen Attributen und Informationen.
		|Die Bearbeitung zusätzlicher Attribute und Informationen ist erst nach Abschluss des Updates möglich.'");
	Handler.ExecutionMode = "Deferred";
	Handler.DeferredProcessingQueue = 1;
	Handler.UpdateDataFillingProcedure = "ChartsOfCharacteristicTypes.AdditionalAttributesAndInfo.RegisterDataToProcessForMigrationToNewVersion";
	Handler.ObjectsToRead    = "ChartOfCharacteristicTypes.AdditionalAttributesAndInfo";
	Handler.ObjectsToChange  = "ChartOfCharacteristicTypes.AdditionalAttributesAndInfo";
	Handler.CheckProcedure  = "InfobaseUpdate.DataUpdatedForNewApplicationVersion";
	Handler.ObjectsToLock = "ChartOfCharacteristicTypes.AdditionalAttributesAndInfo";
	
EndProcedure

// See ObjectsAttributesEditBlockedOverridable.OnDefineObjectsWithLockedAttributes. 
Procedure OnDefineObjectsWithLockedAttributes(Objects) Export
	Objects.Insert(Metadata.ChartsOfCharacteristicTypes.AdditionalAttributesAndInfo.FullName(), "");
EndProcedure

// See BatchObjectModificationOverridable.OnDetermineObjectsWithEditableAttributes. 
Procedure OnDefineObjectsWithEditableAttributes(Objects) Export
	Objects.Insert(Metadata.ChartsOfCharacteristicTypes.AdditionalAttributesAndInfo.FullName(), "AttributesToEditInBatchProcessing");
	Objects.Insert(Metadata.Catalogs.ObjectsPropertiesValues.FullName(), "AttributesToEditInBatchProcessing");
	Objects.Insert(Metadata.Catalogs.ObjectPropertyValueHierarchy.FullName(), "AttributesToEditInBatchProcessing");
	Objects.Insert(Metadata.Catalogs.AdditionalAttributesAndInfoSets.FullName(), "AttributesToEditInBatchProcessing");
EndProcedure

// See ObjectVersioningOverridable.OnPrepareObjectData. 
Procedure OnPrepareObjectData(Object, AdditionalAttributes) Export 
	
	If PropertyManager.UseAddlAttributes(Object.Ref) Then
		For Each PropertyValue In PropertyManager.PropertiesValues(Object.Ref) Do
			Attribute = AdditionalAttributes.Add();
			Attribute.Description = PropertyValue.Property;
			Attribute.Value = PropertyValue.Value;
		EndDo;
	EndIf;
	
EndProcedure

// Restores object attributes values stored separately from the object.
Procedure OnRestoreObjectVersion(Object, AdditionalAttributes) Export
	
	For Each Attribute In AdditionalAttributes Do
		If TypeOf(Attribute.Description) = Type("ChartOfCharacteristicTypesRef.AdditionalAttributesAndInfo") Then
			IsAdditionalInfo = Common.ObjectAttributeValue(Attribute.Description, "IsAdditionalInfo");
			If IsAdditionalInfo Then
				RecordSet = InformationRegisters.AdditionalInfo.CreateRecordSet();
				RecordSet.Filter.Object.Set(Object.Ref);
				RecordSet.Filter.Property.Set(Attribute.Description);
				
				Record = RecordSet.Add();
				Record.Property = Attribute.Description;
				Record.Value = Attribute.Value;
				Record.Object = Object.Ref;
				RecordSet.Write();
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

// See CommonOverridable.OnAddRefsSearchExceptions. 
Procedure OnAddReferenceSearchExceptions(Array) Export
	
	Array.Add(Metadata.InformationRegisters.AdditionalInfo.FullName());
	Array.Add(Metadata.Catalogs.AdditionalAttributesAndInfoSets.FullName());
	
EndProcedure

// See AccessManagementOverridable.OnFillAccessKinds. 
Procedure OnFillAccessKinds(AccessKinds) Export
	
	AccessKind = AccessKinds.Add();
	AccessKind.Name = "AdditionalInfo";
	AccessKind.Presentation = NStr("ru = 'Дополнительные сведения'; en = 'Additional information'; pl = 'Informacje dodatkowe';es_ES = 'Información adicional';es_CO = 'Información adicional';tr = 'Ek bilgi';it = 'Informazioni aggiuntive';de = 'Weitere informationen'");
	AccessKind.ValuesType   = Type("ChartOfCharacteristicTypesRef.AdditionalAttributesAndInfo");
	
EndProcedure

// See AccessManagementOverridable.OnFillListsWithAccessRestriction. 
Procedure OnFillListsWithAccessRestriction(Lists) Export
	
	Lists.Insert(Metadata.Catalogs.ObjectsPropertiesValues, True);
	Lists.Insert(Metadata.Catalogs.ObjectPropertyValueHierarchy, True);
	Lists.Insert(Metadata.ChartsOfCharacteristicTypes.AdditionalAttributesAndInfo, True);
	Lists.Insert(Metadata.InformationRegisters.AdditionalInfo, True);
	
EndProcedure

// See AccessManagementOverridable.OnFillAccessKindUsage. 
Procedure OnFillAccessKindUsage(AccessKind, Usage) Export
	
	SetPrivilegedMode(True);
	
	If AccessKind = "AdditionalInfo" Then
		Usage = Constants.UseAdditionalAttributesAndInfo.Get();
	EndIf;
	
EndProcedure

// See AccessManagementOverridable.OnFillMetadataObjectsAccessRestrictionsKinds. 
Procedure OnFillMetadataObjectsAccessRestrictionKinds(Details) Export
	
	If NOT Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		Return;
	EndIf;
	
	ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
	
	If ModuleAccessManagementInternal.AccessKindExists("AdditionalInfo") Then
		
		Details = Details + "
		|
		|Catalog.ObjectsPropertiesValues.Read.AdditionalInfo
		|Catalog.ObjectPropertyValueHierarchy.Read.AdditionalInfo
		|ChartOfCharacteristicTypes.AdditionalAttributesAndInfo.Read.AdditionalInfo
		|InformationRegister.AdditionalInfo.Read.AdditionalInfo
		|InformationRegister.AdditionalInfo.Update.AdditionalInfo
		|";
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

// See PropertyManagement.TransferValuesFromFormAttributesToObject. 
Procedure TransferValuesFromFormAttributesToObject(Form, Object = Undefined, BeforeWrite = False) Export
	
	Destination = New Structure;
	Destination.Insert("PropertiesParameters", Undefined);
	FillPropertyValues(Destination, Form);
	
	If NOT Form.Properties_UseProperties
		OR NOT Form.Properties_UseAddlAttributes
		OR (TypeOf(Destination.PropertiesParameters) = Type("Structure")
			AND Destination.PropertiesParameters.Property("DeferredInitializationExecuted")
			AND Not Destination.PropertiesParameters.DeferredInitializationExecuted) Then
		
		Return;
	EndIf;
	
	If Object = Undefined Then
		ObjectDetails = Form.Object;
	Else
		ObjectDetails = Object;
	EndIf;
	
	PreviousValues = ObjectDetails.AdditionalAttributes.Unload();
	ObjectDetails.AdditionalAttributes.Clear();
	
	For each Row In Form.Properties_AdditionalAttributeDetails Do
		
		Value = Form[Row.ValueAttributeName];
		
		If Value = Undefined Then
			Continue;
		EndIf;
		
		If Row.ValueType.Types().Count() = 1
		   AND (NOT ValueIsFilled(Value) Or Value = False) Then
			
			Continue;
		EndIf;
		
		If Row.Deleted Then
			If ValueIsFilled(Value) AND Not (BeforeWrite AND Form.Properties_HideDeleted) Then
				FoundRow = PreviousValues.Find(Row.Property, "Property");
				If FoundRow <> Undefined Then
					FillPropertyValues(ObjectDetails.AdditionalAttributes.Add(), FoundRow);
				EndIf;
			EndIf;
			Continue;
		EndIf;
		
		// Support of hyperlink strings.
		UseStringAsLink = UseStringAsLink(
			Row.ValueType, Row.OutputAsHyperlink, Row.MultilineInputField);
		
		NewRow = ObjectDetails.AdditionalAttributes.Add();
		NewRow.Property = Row.Property;
		If UseStringAsLink Then
			AddressAndPresentation = AddressAndPresentation(Value);
			NewRow.Value = AddressAndPresentation.Presentation;
		Else
			NewRow.Value = Value;
		EndIf;
		
		// Support of strings with unlimited length.
		UseUnlimitedString = UseUnlimitedString(
			Row.ValueType, Row.MultilineInputField);
		
		If UseUnlimitedString Or UseStringAsLink Then
			NewRow.TextString = Value;
		EndIf;
	EndDo;
	
	If BeforeWrite Then
		Form.Properties_HideDeleted = False;
	EndIf;
	
EndProcedure

// Returns a table of available owner property sets.
//
// Parameters:
//  PropertiesOwner - a reference to a property owner.
//                    Property owner object.
//                    FormStructureData (by type of property owner object).
//
Function GetObjectPropertySets(Val PropertiesOwner, AssignmentKey = Undefined) Export
	
	If TypeOf(PropertiesOwner) = Type("FormDataStructure") Then
		RefType = TypeOf(PropertiesOwner.Ref)
		
	ElsIf Common.IsReference(TypeOf(PropertiesOwner)) Then
		RefType = TypeOf(PropertiesOwner);
	Else
		RefType = TypeOf(PropertiesOwner.Ref)
	EndIf;
	
	GetDefaultSet = True;
	
	PropertySets = New ValueTable;
	PropertySets.Columns.Add("Set");
	PropertySets.Columns.Add("Height");
	PropertySets.Columns.Add("Title");
	PropertySets.Columns.Add("ToolTip");
	PropertySets.Columns.Add("VerticalStretch");
	PropertySets.Columns.Add("HorizontalStretch");
	PropertySets.Columns.Add("ReadOnly");
	PropertySets.Columns.Add("TitleTextColor");
	PropertySets.Columns.Add("Width");
	PropertySets.Columns.Add("TitleFont");
	PropertySets.Columns.Add("Group");
	PropertySets.Columns.Add("Representation");
	PropertySets.Columns.Add("Picture");
	PropertySets.Columns.Add("ShowTitle");
	PropertySets.Columns.Add("CommonSet", New TypeDescription("Boolean"));
	// Obsolete:
	PropertySets.Columns.Add("ChildItemsWidth");
	
	PropertyManagerOverridable.FillObjectPropertySets(
		PropertiesOwner, RefType, PropertySets, GetDefaultSet, AssignmentKey);
	
	If PropertySets.Count() = 0
	   AND GetDefaultSet = True Then
		
		MainSet = GetDefaultObjectPropertySet(PropertiesOwner);
		
		If ValueIsFilled(MainSet) Then
			PropertySets.Add().Set = MainSet;
		EndIf;
	EndIf;
	
	Return PropertySets;
	
EndFunction

// Returns a filled table of object property values.
Function PropertiesValues(AdditionalObjectProperties, Sets, IsAdditionalInfo) Export
	
	If AdditionalObjectProperties.Count() = 0 Then
		// Preliminary quick check of additional properties usage.
		PropertiesNotFound = AdditionalAttributesAndInfoNotFound(Sets, IsAdditionalInfo);
		
		If PropertiesNotFound Then
			PropertiesDetails = New ValueTable;
			PropertiesDetails.Columns.Add("Set");
			PropertiesDetails.Columns.Add("Property");
			PropertiesDetails.Columns.Add("AdditionalValuesOwner");
			PropertiesDetails.Columns.Add("RequiredToFill");
			PropertiesDetails.Columns.Add("Description");
			PropertiesDetails.Columns.Add("ValueType");
			PropertiesDetails.Columns.Add("FormatProperties");
			PropertiesDetails.Columns.Add("MultilineInputField");
			PropertiesDetails.Columns.Add("Deleted");
			PropertiesDetails.Columns.Add("Value");
			Return PropertiesDetails;
		EndIf;
	EndIf;
	
	Properties = AdditionalObjectProperties.UnloadColumn("Property");
	
	PropertySets = New ValueTable;
	
	PropertySets.Columns.Add(
		"Set", New TypeDescription("CatalogRef.AdditionalAttributesAndInfoSets"));
	
	PropertySets.Columns.Add(
		"SetOrder", New TypeDescription("Number"));
	
	For each ListItem In Sets Do
		NewRow = PropertySets.Add();
		NewRow.Set         = ListItem.Value;
		NewRow.SetOrder = Sets.IndexOf(ListItem);
	EndDo;
	
	Query = New Query;
	Query.SetParameter("Properties",      Properties);
	Query.SetParameter("PropertySets", PropertySets);
	Query.Text =
	"SELECT
	|	PropertySets.Set,
	|	PropertySets.SetOrder
	|INTO PropertySets
	|FROM
	|	&PropertySets AS PropertySets
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	PropertySets.Set,
	|	PropertySets.SetOrder,
	|	SetsProperties.Property,
	|	SetsProperties.DeletionMark,
	|	SetsProperties.LineNumber AS PropertyOrder
	|INTO SetsProperties
	|FROM
	|	PropertySets AS PropertySets
	|		INNER JOIN Catalog.AdditionalAttributesAndInfoSets.AdditionalAttributes AS SetsProperties
	|		ON (SetsProperties.Ref = PropertySets.Set)
	|		INNER JOIN ChartOfCharacteristicTypes.AdditionalAttributesAndInfo AS Properties
	|		ON (SetsProperties.Property = Properties.Ref)
	|WHERE
	|	NOT SetsProperties.DeletionMark
	|	AND NOT Properties.DeletionMark
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	Properties.Ref AS Property
	|INTO CompletedProperties
	|FROM
	|	ChartOfCharacteristicTypes.AdditionalAttributesAndInfo AS Properties
	|WHERE
	|	Properties.Ref IN(&Properties)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SetsProperties.Set,
	|	SetsProperties.SetOrder,
	|	SetsProperties.Property,
	|	SetsProperties.PropertyOrder,
	|	SetsProperties.DeletionMark AS Deleted
	|INTO AllProperties
	|FROM
	|	SetsProperties AS SetsProperties
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(Catalog.AdditionalAttributesAndInfoSets.EmptyRef),
	|	0,
	|	CompletedProperties.Property,
	|	0,
	|	TRUE
	|FROM
	|	CompletedProperties AS CompletedProperties
	|		LEFT JOIN SetsProperties AS SetsProperties
	|		ON CompletedProperties.Property = SetsProperties.Property
	|WHERE
	|	SetsProperties.Property IS NULL 
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	AllProperties.Set,
	|	AllProperties.Property,
	|	AdditionalAttributesAndInfo.AdditionalValuesOwner,
	|	AdditionalAttributesAndInfo.RequiredToFill,
	|	AdditionalAttributesAndInfo.Title AS Description,
	|	AdditionalAttributesAndInfo.ValueType,
	|	AdditionalAttributesAndInfo.FormatProperties,
	|	AdditionalAttributesAndInfo.MultilineInputField,
	|	AllProperties.Deleted AS Deleted,
	|	AdditionalAttributesAndInfo.Available,
	|	AdditionalAttributesAndInfo.Visible,
	|	AdditionalAttributesAndInfo.ToolTip,
	|	AdditionalAttributesAndInfo.OutputAsHyperlink,
	|	AdditionalAttributesAndInfo.AdditionalAttributesDependencies.(
	|		DependentProperty,
	|		Attribute,
	|		Condition,
	|		Value
	|	)
	|FROM
	|	AllProperties AS AllProperties
	|		INNER JOIN ChartOfCharacteristicTypes.AdditionalAttributesAndInfo AS AdditionalAttributesAndInfo
	|		ON AllProperties.Property = AdditionalAttributesAndInfo.Ref
	|
	|ORDER BY
	|	Deleted,
	|	AllProperties.SetOrder,
	|	AllProperties.PropertyOrder";
	
	If IsAdditionalInfo Then
		Query.Text = StrReplace(
			Query.Text,
			"Catalog.AdditionalAttributesAndInfoSets.AdditionalAttributes",
			"Catalog.AdditionalAttributesAndInfoSets.AdditionalInfo");
	EndIf;
	
	PropertiesDetails = Query.Execute().Unload();
	PropertiesDetails.Indexes.Add("Property");
	PropertiesDetails.Columns.Add("Value");
	
	// Deleting property duplicates in subordinate property sets.
	If Sets.Count() > 1 Then
		Index = PropertiesDetails.Count()-1;
		
		While Index >= 0 Do
			Row = PropertiesDetails[Index];
			FoundRow = PropertiesDetails.Find(Row.Property, "Property");
			
			If FoundRow <> Undefined
			   AND FoundRow <> Row Then
				
				PropertiesDetails.Delete(Index);
			EndIf;
			
			Index = Index-1;
		EndDo;
	EndIf;
	
	// Filling property values.
	For Each Row In AdditionalObjectProperties Do
		PropertyDetails = PropertiesDetails.Find(Row.Property, "Property");
		If PropertyDetails <> Undefined Then
			// Support of strings with unlimited length.
			If NOT IsAdditionalInfo Then
				UseStringAsLink = UseStringAsLink(
					PropertyDetails.ValueType,
					PropertyDetails.OutputAsHyperlink,
					PropertyDetails.MultilineInputField);
				UseUnlimitedString = UseUnlimitedString(
					PropertyDetails.ValueType,
					PropertyDetails.MultilineInputField);
				NeedToTransferValueFromRef = NeedToTransferValueFromRef(
						Row.TextString,
						Row.Value);
				If (UseUnlimitedString
						Or UseStringAsLink
						Or NeedToTransferValueFromRef)
					AND NOT IsBlankString(Row.TextString) Then
					If Not UseStringAsLink AND NeedToTransferValueFromRef Then
						ValueWithoutRef = ValueWithoutRef(Row.TextString, Row.Value);
						PropertyDetails.Value = ValueWithoutRef;
					Else
						PropertyDetails.Value = Row.TextString;
					EndIf;
				Else
					PropertyDetails.Value = Row.Value;
				EndIf;
			Else
				PropertyDetails.Value = Row.Value;
			EndIf;
		EndIf;
	EndDo;
	
	Return PropertiesDetails;
	
EndFunction

// For internal use only.
//
Function AdditionalAttributesAndInfoNotFound(Sets, IsAdditionalInfo, DeferredInitialization = False) Export
	
	Query = New Query;
	Query.SetParameter("PropertySets", Sets.UnloadValues());
	Query.Text =
	"SELECT TOP 1
	|	SetsProperties.Property AS Property
	|FROM
	|	Catalog.AdditionalAttributesAndInfoSets.AdditionalAttributes AS SetsProperties
	|WHERE
	|	SetsProperties.Ref IN(&PropertySets)
	|	AND NOT SetsProperties.DeletionMark";
	
	If IsAdditionalInfo Then
		Query.Text = StrReplace(
			Query.Text,
			"Catalog.AdditionalAttributesAndInfoSets.AdditionalAttributes",
			"Catalog.AdditionalAttributesAndInfoSets.AdditionalInfo");
	EndIf;
	
	SetPrivilegedMode(True);
	PropertiesNotFound = Query.Execute().IsEmpty();
	SetPrivilegedMode(False);
	
	Return PropertiesNotFound;
EndFunction

// Returns the metadata object that is the owner of property values of additional attribute and info 
// set.
//
Function SetPropertiesValuesOwnerMetadata(Ref, ConsiderDeletionMark = True, RefType = Undefined) Export
	
	If NOT ValueIsFilled(Ref) Then
		Return Undefined;
	EndIf;
	
	If TypeOf(Ref) = Type("Structure") Then
		ReferenceProperties = Ref;
	Else
		ReferenceProperties = Common.ObjectAttributesValues(
			Ref, "DeletionMark, IsFolder, Predefined, Parent, PredefinedDataName");
	EndIf;
	
	If ConsiderDeletionMark AND ReferenceProperties.DeletionMark Then
		Return Undefined;
	EndIf;
	
	If ReferenceProperties.IsFolder Then
		PredefinedRef = Ref;
		
	ElsIf ReferenceProperties.Predefined
	        AND ReferenceProperties.Parent = Catalogs.AdditionalAttributesAndInfoSets.EmptyRef() Then
		
		PredefinedRef = Ref;
	Else
		PredefinedRef = ReferenceProperties.Parent;
	EndIf;
	
	If Ref <> PredefinedRef Then
		PredefinedItemName = Common.ObjectAttributeValue(PredefinedRef, "PredefinedDataName");
	Else
		PredefinedItemName = ReferenceProperties.PredefinedDataName;
	EndIf;
	
	Position = StrFind(PredefinedItemName, "_");
	
	FirstNamePart =  Left(PredefinedItemName, Position - 1);
	SecondNamePart = Right(PredefinedItemName, StrLen(PredefinedItemName) - Position);
	
	OwnerMetadata = Metadata.FindByFullName(FirstNamePart + "." + SecondNamePart);
	
	If OwnerMetadata <> Undefined Then
		RefType = Type(FirstNamePart + "Ref." + SecondNamePart);
	EndIf;
	
	Return OwnerMetadata;
	
EndFunction

// Returns the usage of additional attributes and info by the set.
Function SetPropertiesTypes(Ref, ConsiderDeletionMark = True) Export
	
	SetPropertiesTypes = New Structure;
	SetPropertiesTypes.Insert("AdditionalAttributes", False);
	SetPropertiesTypes.Insert("AdditionalInfo",  False);
	
	RefType = Undefined;
	OwnerMetadata = SetPropertiesValuesOwnerMetadata(Ref, ConsiderDeletionMark, RefType);
	
	If OwnerMetadata = Undefined Then
		Return SetPropertiesTypes;
	EndIf;
	
	// Checking additional attributes usage.
	SetPropertiesTypes.Insert(
		"AdditionalAttributes",
		OwnerMetadata <> Undefined
		AND OwnerMetadata.TabularSections.Find("AdditionalAttributes") <> Undefined );
	
	// Checking additional info usage.
	SetPropertiesTypes.Insert(
		"AdditionalInfo",
		      Metadata.CommonCommands.Find("AdditionalInfoCommandBar") <> Undefined
		    AND Metadata.CommonCommands.AdditionalInfoCommandBar.CommandParameterType.ContainsType(RefType));
	
	Return SetPropertiesTypes;
	
EndFunction

Procedure FillSetsWithAdditionalAttributes(AllSets, SetsWithAttributes) Export
	
	References = AllSets.UnloadColumn("Set");
	
	ReferencesProperties = Common.ObjectsAttributesValues(
		References, "DeletionMark, IsFolder, Predefined, Parent, PredefinedDataName");
	
	For Each ReferenceProperties In ReferencesProperties Do
		RefType = Undefined;
		OwnerMetadata = SetPropertiesValuesOwnerMetadata(ReferenceProperties.Value, True, RefType);
		
		If OwnerMetadata = Undefined Then
			Return;
		EndIf;
		
		// Checking additional attributes usage.
		If OwnerMetadata.TabularSections.Find("AdditionalAttributes") <> Undefined Then
			Row = AllSets.Find(ReferenceProperties.Key, "Set");
			SetsWithAttributes.Add(Row.Set, Row.Title);
		EndIf;
		
	EndDo;
	
EndProcedure

// Defines that a value type contains a type of additional property values.
Function ValueTypeContainsPropertyValues(ValueType) Export
	
	Return ValueType.ContainsType(Type("CatalogRef.ObjectsPropertiesValues"))
	    OR ValueType.ContainsType(Type("CatalogRef.ObjectPropertyValueHierarchy"));
	
EndFunction

// Checks if it is possible to use string of unlimited length for the property.
Function UseUnlimitedString(PropertyValueType, MultilineInputField) Export
	
	If PropertyValueType.ContainsType(Type("String"))
	   AND PropertyValueType.Types().Count() = 1
	   AND (PropertyValueType.StringQualifiers.Length = 0
		   Or MultilineInputField > 1) Then
		Return True;
	Else
		Return False;
	EndIf;
	
EndFunction

Function UseStringAsLink(PropertyValueType, OutputAsHyperlink, MultilineInputField)
	TypesList = PropertyValueType.Types();
	
	If Not UseUnlimitedString(PropertyValueType, MultilineInputField)
		AND TypesList.Count() = 1
		AND TypesList[0] = Type("String")
		AND OutputAsHyperlink Then
		Return True;
	Else
		Return False;
	EndIf;
	
EndFunction

Function AddressAndPresentation(Row) Export
	
	Result = New Structure;
	BoldBeginning = StrFind(Row, "<a href = ");
	
	StringAfterOpeningTag = Mid(Row, BoldBeginning + 9);
	EndTag = StrFind(StringAfterOpeningTag, ">");
	
	Ref = TrimAll(Left(StringAfterOpeningTag, EndTag - 2));
	If StrStartsWith(Ref, """") Then
		Ref = Mid(Ref, 2, StrLen(Ref) - 1);
	EndIf;
	If StrEndsWith(Ref, """") Then
		Ref = Mid(Ref, 1, StrLen(Ref) - 1);
	EndIf;
	
	StringAfterLink = Mid(StringAfterOpeningTag, EndTag + 1);
	BoldEnd = StrFind(StringAfterLink, "</a>");
	HyperlinkAnchorText = Left(StringAfterLink, BoldEnd - 1);
	Result.Insert("Presentation", HyperlinkAnchorText);
	Result.Insert("Ref", Ref);
	
	Return Result;
	
EndFunction

// PropertiesBeforeRemoveReferenceObject event handler.
// Searches for references to deleted objects in the additional attribute dependence table.
//
Procedure BeforeRemoveReferenceObject(Object, Cancel) Export
	If Object.DataExchange.Load = True
		Or Cancel Then
		Return;
	EndIf;
	
	If Not Common.SeparatedDataUsageAvailable() Then
		// Do not check in shared mode.
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text =
		"SELECT DISTINCT
		|	Dependencies.Ref AS Ref
		|FROM
		|	ChartOfCharacteristicTypes.AdditionalAttributesAndInfo.AdditionalAttributesDependencies AS Dependencies
		|WHERE
		|	Dependencies.Value = &Value
		|
		|ORDER BY
		|	Ref";
	Query.SetParameter("Value", Object.Ref);
	Result = Query.Execute().Unload();
	
	For Each Row In Result Do
		AttributeObject = Row.Ref.GetObject();
		FilterParameters = New Structure("Value", Object.Ref);
		FoundRows = AttributeObject.AdditionalAttributesDependencies.FindRows(FilterParameters);
		For Each Dependence In FoundRows Do
			AttributeObject.AdditionalAttributesDependencies.Delete(Dependence);
		EndDo;
		AttributeObject.Write();
	EndDo;
EndProcedure

// Checks for objects using the property.
//
// Parameters:
//  Property - ChartOfCharacteristicTypesRef.AdditionalAttributesAndInfo.
// 
// Returns:
//  Boolean. True if at least one object is found.
//
Function AdditionalPropertyUsed(Property) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.SetParameter("Property", Property);
	Query.Text =
	"SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	InformationRegister.AdditionalInfo AS AdditionalInfo
	|WHERE
	|	AdditionalInfo.Property = &Property";
	
	If NOT Query.Execute().IsEmpty() Then
		Return True;
	EndIf;
	
	MetadataObjectKinds = New Array;
	MetadataObjectKinds.Add("ExchangePlans");
	MetadataObjectKinds.Add("Catalogs");
	MetadataObjectKinds.Add("Documents");
	MetadataObjectKinds.Add("ChartsOfCharacteristicTypes");
	MetadataObjectKinds.Add("ChartsOfAccounts");
	MetadataObjectKinds.Add("ChartsOfCalculationTypes");
	MetadataObjectKinds.Add("BusinessProcesses");
	MetadataObjectKinds.Add("Tasks");
	
	ObjectTables = New Array;
	For each MetadataObjectsKind In MetadataObjectKinds Do
		For each MetadataObject In Metadata[MetadataObjectsKind] Do
			
			If IsMetadataObjectWithAdditionalAttributes(MetadataObject) Then
				ObjectTables.Add(MetadataObject.FullName());
			EndIf;
			
		EndDo;
	EndDo;
	
	QueryText =
	"SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	TableName AS CurrentTable
	|WHERE
	|	CurrentTable.Property = &Property";
	
	For each Table In ObjectTables Do
		Query.Text = StrReplace(QueryText, "TableName", Table + ".AdditionalAttributes");
		If NOT Query.Execute().IsEmpty() Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

// Checks if the metadata object uses additional attributes.
// The check is intended to control reference integrity, that is why the embedding check is skipped.
// 
//
Function IsMetadataObjectWithAdditionalAttributes(MetadataObject) Export
	
	If MetadataObject = Metadata.Catalogs.AdditionalAttributesAndInfoSets Then
		Return False;
	EndIf;
	
	TabularSection = MetadataObject.TabularSections.Find("AdditionalAttributes");
	If TabularSection = Undefined Then
		Return False;
	EndIf;
	
	Attribute = TabularSection.Attributes.Find("Property");
	If Attribute = Undefined Then
		Return False;
	EndIf;
	
	If NOT Attribute.Type.ContainsType(Type("ChartOfCharacteristicTypesRef.AdditionalAttributesAndInfo")) Then
		Return False;
	EndIf;
	
	Attribute = TabularSection.Attributes.Find("Value");
	If Attribute = Undefined Then
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

// Returns description of the predefined set that is received from the metadata object found by the 
// predefined set description.
// 
// Parameters:
//  Set - CatalogRef.AdditionalAttributesAndInfoSets,
//        - String - a full name of the predefined item.
//
Function PredefinedSetDescription(Set) Export
	
	If TypeOf(Set) = Type("String") Then
		PredefinedItemName = Set;
	Else
		PredefinedItemName = Common.ObjectAttributeValue(Set, "PredefinedDataName");
	EndIf;
	
	Position = StrFind(PredefinedItemName, "_");
	FirstNamePart =  Left(PredefinedItemName, Position - 1);
	SecondNamePart = Right(PredefinedItemName, StrLen(PredefinedItemName) - Position);
	
	FullName = FirstNamePart + "." + SecondNamePart;
	
	MetadataObject = Metadata.FindByFullName(FullName);
	If MetadataObject = Undefined Then
		If TypeOf(Set) = Type("String") Then
			Return "";
		Else
			Return Common.ObjectAttributeValue(Set, "Description");
		EndIf;
	EndIf;
	
	If ValueIsFilled(MetadataObject.ListPresentation) Then
		Description = MetadataObject.ListPresentation;
		
	ElsIf ValueIsFilled(MetadataObject.Synonym) Then
		Description = MetadataObject.Synonym;
	Else
		If TypeOf(Set) = Type("String") Then
			Description = "";
		Else
			Description = Common.ObjectAttributeValue(Set, "Description");
		EndIf;
	EndIf;
	
	Return Description;
	
EndFunction

// Updates content of the top group to use fields of the dynamic list and its settings (filters, ...
// ) upon customization.
//
// Parameters:
//  Group - CatalogRef.AdditionalAttributesAndInfoSets with the flag IsFolder = True.
//                  
//
Procedure CheckRefreshGroupPropertiesContent(Folder) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.SetParameter("Group", Folder);
	Query.Text =
	"SELECT DISTINCT
	|	AdditionalAttributes.Property AS Property
	|FROM
	|	Catalog.AdditionalAttributesAndInfoSets.AdditionalAttributes AS AdditionalAttributes
	|WHERE
	|	AdditionalAttributes.Ref.Parent = &Group
	|
	|ORDER BY
	|	Property
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	AdditionalInfo.Property AS Property
	|FROM
	|	Catalog.AdditionalAttributesAndInfoSets.AdditionalInfo AS AdditionalInfo
	|WHERE
	|	AdditionalInfo.Ref.Parent = &Group
	|
	|ORDER BY
	|	Property";
	
	QueryResult = Query.ExecuteBatch();
	AdditionalGroupAttributes = QueryResult[0].Unload();
	AdditionalGroupInfo  = QueryResult[1].Unload();
	
	GroupObject = Folder.GetObject();
	
	Update = False;
	
	If GroupObject.AdditionalAttributes.Count() <> AdditionalGroupAttributes.Count() Then
		Update = True;
	EndIf;
	
	If GroupObject.AdditionalInfo.Count() <> AdditionalGroupInfo.Count() Then
		Update = True;
	EndIf;
	
	If Not Update Then
		Index = 0;
		For each Row In GroupObject.AdditionalAttributes Do
			If Row.Property <> AdditionalGroupAttributes[Index].Property Then
				Update = True;
			EndIf;
			Index = Index + 1;
		EndDo;
	EndIf;
	
	If Not Update Then
		Index = 0;
		For each Row In GroupObject.AdditionalInfo Do
			If Row.Property <> AdditionalGroupInfo[Index].Property Then
				Update = True;
			EndIf;
			Index = Index + 1;
		EndDo;
	EndIf;
	
	If Not Update Then
		Return;
	EndIf;
	
	GroupObject.AdditionalAttributes.Load(AdditionalGroupAttributes);
	GroupObject.AdditionalInfo.Load(AdditionalGroupInfo);
	GroupObject.Write();
	
EndProcedure

// Returns enum values of the specified property.
//
// Parameters:
//  Property - ChartOfCharacteristicTypesRef.AdditionalAttributesAndInfo - a property for which 
//             listed values are to be received.
// 
// Returns:
//  Array - values:
//    * CatalogRef.ObjectPropertyValues, CatalogRef.ObjectPropertyValuesHierarchy - property values 
//      if any.
//
Function AdditionalPropertyValues(Property) Export
	
	ValueType = Common.ObjectAttributeValue(Property, "ValueType");
	
	If ValueType.ContainsType(Type("CatalogRef.ObjectPropertyValueHierarchy")) Then
		QueryText =
		"SELECT
		|	Ref AS Ref
		|FROM
		|	Catalog.ObjectPropertyValueHierarchy AS ObjectsPropertiesValues
		|WHERE
		|	ObjectsPropertiesValues.Owner = &Property";
	Else
		QueryText =
		"SELECT
		|	Ref AS Ref
		|FROM
		|	Catalog.ObjectsPropertiesValues AS ObjectsPropertiesValues
		|WHERE
		|	ObjectsPropertiesValues.Owner = &Property";
	EndIf;
	
	Query = New Query;
	Query.Text = QueryText;
	Query.Parameters.Insert("Property", Property);
	Result = Query.Execute().Unload().UnloadColumn("Ref");
	
	Return Result;
	
EndFunction

Procedure DeleteDisallowedCharacters(Row) Export
	DisallowedCharacters = """'`/\[]{}:;|=?*<>,.()+#№@!%^&~";
	Row = StrConcat(StrSplit(Row, DisallowedCharacters, True));
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures and functions.

// Returns the default owner property set.
//
// Parameters:
//  PropertiesOwner - a reference or property owner object.
//
// Returns:
//  CatalogRef.AdditionalAttributesAndInfoSets - when an object kind attribute name is not specified 
//   for a property owner type in the procedure.
//         PropertyManagementOverridable.GetObjectKindAttributeName(),
//   then the predefined item returns with name in format full metadata object name, where the "." 
//         character is replaced by the "_" character,
//   otherwise, the PropertySet attribute value returns, it belongs to the kind that is included in 
//         property owner attribute with the name specified in overridable procedure.
//         
//
//  Undefined - when property owner is a catalog item group or chart of characteristic types item 
//                 group.
//  
Function GetDefaultObjectPropertySet(PropertiesOwner)
	
	ObjectTransferred = False;
	If Common.RefTypeValue(PropertiesOwner) Then
		Ref = PropertiesOwner;
	Else
		ObjectTransferred = True;
		Ref = PropertiesOwner.Ref;
	EndIf;
	
	ObjectMetadata = Ref.Metadata();
	MetadataObjectName = ObjectMetadata.Name;
	
	MetadataObjectKind = Common.ObjectKindByRef(Ref);
	
	If MetadataObjectKind = "Catalog" Or MetadataObjectKind = "ChartOfCharacteristicTypes" Then
		If Common.ObjectIsFolder(PropertiesOwner) Then
			Return Undefined;
		EndIf;
	EndIf;
	ItemName = MetadataObjectKind + "_" + MetadataObjectName;
	Return Catalogs.AdditionalAttributesAndInfoSets[ItemName];
	
EndFunction

// The procedure is used upon updating the infobase.
Function HasMetadataObjectWithPropertiesPresentationChanges()
	
	SetPrivilegedMode(True);
	
	Catalogs.AdditionalAttributesAndInfoSets.RefreshPredefinedSetsDescriptionsContent();
	
	LastChanges = StandardSubsystemsServer.ApplicationParameterChanges(
		"StandardSubsystems.Properties.AdditionalDataAndAttributePredefinedSets");
	
	If LastChanges = Undefined
	 Or LastChanges.Count() > 0 Then
		
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

Function NeedToTransferValueFromRef(Value, Presentation)
	
	If ValueIsFilled(Presentation) AND Left(Value, 7) = "<a href" Then
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

Function ValueWithoutRef(Value, Presentation)
	
	If Not ValueIsFilled(Presentation) Or Left(Value, 7) <> "<a href" Then
		Return Value;
	EndIf;
	
	RefStart = "<a href = """;
	RefFinish = StringFunctionsClientServer.SubstituteParametersToString(""">%1</a>", Presentation);
	
	Result = StrReplace(Value, RefStart, "");
	Result = StrReplace(Result, RefFinish, "");
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Updating an infobase.

// Fills in separated data handler that depends on shared data change.
//
// Parameters:
//   Handlers - ValueTable, Undefined - see details of the NewUpdateHandlerTable function of the 
//    common module.
//    InfobaseUpdate.
//    Undefined is passed upon direct call (without using the infobase version update functionality).
//    
// 
Procedure FillSeparatedDataHandlers(Parameters = Undefined) Export
	
	If Parameters <> Undefined AND HasMetadataObjectWithPropertiesPresentationChanges() Then
		Handlers = Parameters.SeparatedHandlers;
		Handler = Handlers.Add();
		Handler.Version = "*";
		Handler.ExecutionMode = "Seamless";
		Handler.Procedure = "PropertyManager.UpdatePropertyAndSetDescriptions";
	EndIf;
	
EndProcedure

// Updates additional attribute and info sets in the infobase.
// Used to switch to a new storage format.
//
Procedure UpdateAdditionalPropertyList_1_0_6() Export
	
	AdditionalAttributesAndInfoSets = Catalogs.AdditionalAttributesAndInfoSets.Select();
	
	While AdditionalAttributesAndInfoSets.Next() Do
		
		AdditionalInfo = New Array;
		
		PropertySetObject = AdditionalAttributesAndInfoSets.Ref.GetObject();
		
		For Each Record In PropertySetObject.AdditionalAttributes Do
			If Record.Property.IsAdditionalInfo Then
				AdditionalInfo.Add(Record);
			EndIf;
		EndDo;
		
		If AdditionalInfo.Count() > 0 Then
			
			For Each AdditionalInfoItem In AdditionalInfo Do
				NewRow = PropertySetObject.AdditionalInfo.Add();
				NewRow.Property = AdditionalInfoItem.Property;
				PropertySetObject.AdditionalAttributes.Delete(
					PropertySetObject.AdditionalAttributes.IndexOf(AdditionalInfoItem));
				
			EndDo;
			InfobaseUpdate.WriteData(PropertySetObject);
		EndIf;
		
	EndDo;
	
EndProcedure

// 1. Fills in new data:
// Catalog.AdditionalAttributesAndInfoSets
// - AttributesNumber
// - InfoCount
// ChartOfCharacteristicTypes.AdditionalAttributesAndInfo.
// - Header
// - PropertySet
// - AdditionalValuesUsed
// - AdditionalValuesWithWeight
// - ValueFormTitle
// - ValueSelectionFormTitle
// Constant.UseAdditionalCommonAttributesAndInfo
// Constant.UseCommonAdditionalValues.
//
// 2. Updates existing data:
// Catalog.AdditionalAttributesAndInfoSets
// - Description
// - AdditionalAttributes (clears if embedding is changed).
// - AdditionalInfo (clears if embedding is changed).
// ChartOfCharacteristicTypes.AdditionalAttributesAndInfo.
// - Description.
// 
Procedure FillNewData_2_1_5() Export
	
	PropertiesQuery = New Query;
	PropertiesQuery.Text =
	"SELECT
	|	Properties.Ref AS Ref
	|FROM
	|	ChartOfCharacteristicTypes.AdditionalAttributesAndInfo AS Properties
	|WHERE
	|	Properties.Description <> """"
	|	AND Properties.Title = """"";
	
	PropertiesSelection = PropertiesQuery.Execute().Select();
	
	If PropertiesSelection.Count() = 0 Then
		Return;
	EndIf;
	
	SetsQuery = New Query;
	SetsQuery.Text =
	"SELECT
	|	Sets.Ref AS Ref,
	|	Sets.IsFolder AS IsFolder,
	|	Sets.Description AS Description,
	|	Sets.AttributesNumber,
	|	Sets.InfoCount,
	|	Sets.AdditionalAttributes.(
	|		DeletionMark
	|	),
	|	Sets.AdditionalInfo.(
	|		DeletionMark
	|	)
	|FROM
	|	Catalog.AdditionalAttributesAndInfoSets AS Sets";
	
	SetsSelection = SetsQuery.Execute().Select();
	While SetsSelection.Next() Do
		
		Description = PredefinedSetDescription(SetsSelection.Ref);
		
		// Calculating the number of properties not marked for deletion.
		SetPropertiesTypes = SetPropertiesTypes(SetsSelection.Ref);
		
		AdditionalAttributes = SetsSelection.AdditionalAttributes.Unload();
		If SetPropertiesTypes.AdditionalAttributes Then
			AttributesNumber = AdditionalAttributes.Count();
			AttributesNumberAsString = Format(AdditionalAttributes.FindRows(
				New Structure("DeletionMark", False)).Count(), "NG=");
		Else
			AttributesNumber = 0;
			AttributesNumberAsString = "";
		EndIf;
		
		AdditionalInfo = SetsSelection.AdditionalInfo.Unload();
		If SetPropertiesTypes.AdditionalInfo Then
			InfoCount = AdditionalInfo.Count();
			InfoCountAsString   = Format(AdditionalInfo.FindRows(
				New Structure("DeletionMark", False)).Count(), "NG=");
		Else
			InfoCount = 0;
			InfoCountAsString = "";
		EndIf;
		
		If SetsSelection.Description <> Description
		 OR NOT SetsSelection.IsFolder
		   AND (    AdditionalAttributes.Count() <> AttributesNumber
		      OR AdditionalInfo.Count()  <> InfoCount
		      OR SetsSelection.AttributesNumber <> AttributesNumberAsString
		      OR SetsSelection.InfoCount   <> InfoCountAsString ) Then
			
			Object = SetsSelection.Ref.GetObject();
			Object.Description = Description;
			If NOT SetsSelection.IsFolder Then
				Object.AttributesNumber = AttributesNumberAsString;
				Object.InfoCount   = InfoCountAsString;
				If NOT SetPropertiesTypes.AdditionalAttributes Then
					Object.AdditionalAttributes.Clear();
				EndIf;
				If NOT SetPropertiesTypes.AdditionalInfo Then
					Object.AdditionalInfo.Clear();
				EndIf;
			EndIf;
			InfobaseUpdate.WriteData(Object);
		EndIf;
	EndDo;
	
	UniquenessCheckQuery = New Query;
	UniquenessCheckQuery.Text =
	"SELECT TOP 2
	|	Sets.Ref AS Ref,
	|	FALSE AS IsAdditionalInfo
	|FROM
	|	Catalog.AdditionalAttributesAndInfoSets.AdditionalAttributes AS Sets
	|WHERE
	|	Sets.Property = &Property
	|	AND Sets.Ref.IsFolder = FALSE
	|
	|UNION ALL
	|
	|SELECT TOP 2
	|	Sets.Ref,
	|	TRUE
	|FROM
	|	Catalog.AdditionalAttributesAndInfoSets.AdditionalInfo AS Sets
	|WHERE
	|	Sets.Property = &Property
	|	AND Sets.Ref.IsFolder = FALSE";
	
	WeightCheckQuery = New Query;
	WeightCheckQuery.Text =
	"SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	Catalog.ObjectsPropertiesValues AS Values
	|WHERE
	|	Values.Owner = &Property
	|	AND NOT Values.IsFolder
	|	AND Values.Weight <> 0
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	TRUE
	|FROM
	|	Catalog.ObjectPropertyValueHierarchy AS Values
	|WHERE
	|	Values.Owner = &Property
	|	AND Values.Weight <> 0";
	
	While PropertiesSelection.Next() Do
		
		Object = PropertiesSelection.Ref.GetObject();
		UniquenessCheckQuery.SetParameter("Property", PropertiesSelection.Ref);
		DataExported = UniquenessCheckQuery.Execute().Unload();
		
		If DataExported.Count() = 1
		   AND DataExported[0].IsAdditionalInfo = Object.IsAdditionalInfo Then
			
			Object.PropertySet =  DataExported[0].Ref;
		EndIf;
		
		Object.Title = Object.Description;
		If ValueIsFilled(Object.PropertySet) Then
			Object.Description = Object.Title + " (" + String(Object.PropertySet) + ")";
		EndIf;
		
		If ValueTypeContainsPropertyValues(Object.ValueType) Then
			Object.AdditionalValuesUsed = True;
		EndIf;
		
		WeightCheckQuery.SetParameter("Property", PropertiesSelection.Ref);
		If NOT WeightCheckQuery.Execute().IsEmpty() Then
			Object.AdditionalValuesWithWeight = True;
		EndIf;
		
		Object.ValueFormTitle       = StrGetLine(Object.DeleteSubjectDeclensions, 1);
		Object.ValueSelectionFormTitle = StrGetLine(Object.DeleteSubjectDeclensions, 2);
		Object.DeleteSubjectDeclensions = "";
		
		InfobaseUpdate.WriteData(Object);
	EndDo;
	
	// Filling constants.
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	ChartOfCharacteristicTypes.AdditionalAttributesAndInfo AS AdditionalAttributesAndInfo
	|WHERE
	|	AdditionalAttributesAndInfo.PropertySet = VALUE(Catalog.AdditionalAttributesAndInfoSets.EmptyRef)
	|	AND AdditionalAttributesAndInfo.DeletionMark = FALSE";
	
	If NOT Query.Execute().IsEmpty() Then
		If Constants.UseAdditionalCommonAttributesAndInfo.Get() Then
			Constants.UseAdditionalCommonAttributesAndInfo.Set(True);
		EndIf;
		If Constants.UseCommonAdditionalValues.Get() Then
			Constants.UseCommonAdditionalValues.Set(True);
		EndIf;
	EndIf;
	
EndProcedure

// Updates properties for all set groups upon migrating to the new subsystem version.
Procedure RefreshPropertiesCompositionOfAllSetsGroups(Parameters = Undefined) Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	PropertySets.Ref
	|FROM
	|	Catalog.AdditionalAttributesAndInfoSets AS PropertySets
	|WHERE
	|	PropertySets.IsFolder = TRUE";
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		CheckRefreshGroupPropertiesContent(Selection.Ref);
	EndDo;
	
EndProcedure

// Sets the Visible and Available property values to True.
//
Procedure FillNewAdditionalAttributesAndInfoProperties() Export
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	AdditionalAttributesAndInfo.Ref
	|FROM
	|	ChartOfCharacteristicTypes.AdditionalAttributesAndInfo AS AdditionalAttributesAndInfo";
	Result = Query.Execute().Unload();
	
	For Each ResultString In Result Do
		RefAttributeInfo = ResultString.Ref;
		Object = RefAttributeInfo.GetObject();
		
		Object.Visible    = True;
		Object.Available = True;
		
		InfobaseUpdate.WriteData(Object);
	EndDo;
	
EndProcedure

// Sets the Used property value to True.
//
Procedure SetUsageFlagValue() Export
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	AdditionalAttributesAndInfoSets.Ref
	|FROM
	|	Catalog.AdditionalAttributesAndInfoSets AS AdditionalAttributesAndInfoSets
	|WHERE
	|	NOT AdditionalAttributesAndInfoSets.Used";
	
	Result = Query.Execute();
	Selection = Result.Select();
	
	While Selection.Next() Do
		
		SetObject = Selection.Ref.GetObject();
		SetObject.Used = True;
		InfobaseUpdate.WriteData(SetObject);
		
	EndDo;
	
EndProcedure

#EndRegion
