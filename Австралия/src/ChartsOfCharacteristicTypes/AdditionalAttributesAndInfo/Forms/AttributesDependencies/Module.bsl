#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	SetConditionalAppearance();
	
	PropertyToConfigure = Parameters.PropertyToConfigure;
	
	ObjectProperties = Common.ObjectAttributesValues(Parameters.AdditionalAttribute, "Title");
	
	Title = NStr("ru = '%1 дополнительного реквизита ""%2""'; en = '%1 of the ""%2"" additional attribute'; pl = '%1 atrybutu dodatkowego ""%2""';es_ES = '%1 del requisito adicional ""%2""';es_CO = '%1 del requisito adicional ""%2""';tr = '%1ek alanın ""%2""';it = '%1 dell''attributo aggiuntivo ""%2""';de = '%1 zusätzliche Attribute ""%2""'");
	If PropertyToConfigure = "Available" Then
		PropertyPresentation = NStr("ru = 'Доступность'; en = 'Availability'; pl = 'Dostępność';es_ES = 'Disponibilidad';es_CO = 'Disponibilidad';tr = 'Erişilebilirlik';it = 'Disponibilità';de = 'Verfügbarkeit'");
	ElsIf PropertyToConfigure = "RequiredToFill" Then
		PropertyPresentation = NStr("ru = 'Обязательность заполнения'; en = 'Required filling'; pl = 'Wymagane wypełnienie';es_ES = 'Necesidad de rellenado';es_CO = 'Necesidad de rellenado';tr = 'Gerekli doldurma';it = 'Compilazione richiesta';de = 'Erforderliches Ausfüllen'");
	Else
		PropertyPresentation = NStr("ru = 'Видимость'; en = 'Visibility'; pl = 'Widoczność';es_ES = 'Visibilidad';es_CO = 'Visibilidad';tr = 'Görünürlük';it = 'Visibilità';de = 'Sichtbarkeit'");
	EndIf;
	Title = StrReplace(Title, "%1", PropertyPresentation);
	Title = StrReplace(Title, "%2", ObjectProperties.Title);
	
	If Not ValueIsFilled(ObjectProperties.Title)  Then
		Title = StrReplace(Title, """", "");
	EndIf;
	
	PropertySet = Parameters.Set;
	While ValueIsFilled(PropertySet.Parent) Do
		PropertySet = PropertySet.Parent;
	EndDo;
	
	AdditionalAttributesSet = PropertySet.AdditionalAttributes;
	
	PredefinedDataName = PropertySet.PredefinedDataName;
	ReplacedCharacterPosition = StrFind(PredefinedDataName, "_");
	FullMetadataObjectName = Left(PredefinedDataName, ReplacedCharacterPosition - 1)
		                       + "."
		                       + Mid(PredefinedDataName, ReplacedCharacterPosition + 1);
	
	ObjectAttributes = ListOfAttributesForSelection(FullMetadataObjectName, AdditionalAttributesSet);
	
	FIlterRow = Undefined;
	AdditionalAttributesDependencies = Parameters.AttributesDependencies;
	For Each TabularSectionRow In AdditionalAttributesDependencies Do
		If TabularSectionRow.DependentProperty = PropertyToConfigure Then
			AttributeWithMultipleValue = (TabularSectionRow.Condition = "Accus list")
				Or (TabularSectionRow.Condition = "Not in list");
			
			If AttributeWithMultipleValue Then
				FilterParameters = New Structure;
				FilterParameters.Insert("Attribute", TabularSectionRow.Attribute);
				FilterParameters.Insert("Condition",  TabularSectionRow.Condition);
				
				SearchResult = AttributesDependencies.FindRows(FilterParameters);
				If SearchResult.Count() = 0 Then
					FIlterRow = AttributesDependencies.Add();
					FillPropertyValues(FIlterRow, TabularSectionRow,, "Value");
					
					Values = New ValueList;
					Values.Add(TabularSectionRow.Value);
					FIlterRow.Value = Values;
				Else
					FIlterRow = SearchResult[0];
					FIlterRow.Value.Add(TabularSectionRow.Value);
				EndIf;
			Else
				FIlterRow = AttributesDependencies.Add();
				FillPropertyValues(FIlterRow, TabularSectionRow);
			EndIf;
			
			AttributeDetails = ObjectAttributes.Find(FIlterRow.Attribute, "Attribute");
			If AttributeDetails = Undefined Then
				Continue; // Object attribute is not found.
			EndIf;
			FIlterRow.ChoiceMode   = AttributeDetails.ChoiceMode;
			FIlterRow.Presentation = AttributeDetails.Presentation;
			FIlterRow.ValueType   = AttributeDetails.ValueType;
			If AttributeWithMultipleValue Then
				FIlterRow.Value.ValueType = AttributeDetails.ValueType;
			EndIf;
		EndIf;
	EndDo;
	
	If CommonClientServer.IsMobileClient() Then
		
		CommandBarLocation = FormCommandBarLabelLocation.Auto;
		CommonClientServer.SetFormItemProperty(Items, "FormCancelCommand", "Visible", False);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region EventHandlersFormTables

&AtClient
Procedure AttributesDependenciesAttributeSelectionStart(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
	OpenAttributeSelectionForm();
EndProcedure

&AtClient
Procedure AttributesDependenciesBeforeChangeStart(Item, Cancel)
	AttributesDependenciesSetTypeRestrictionForValue();
EndProcedure

&AtClient
Procedure AttributesDependenciesComparisonKindOnChange(Item)
	AttributesDependenciesSetTypeRestrictionForValue();
	
	FormTable = Items.AttributesDependencies;
	CurrentRow = AttributesDependencies.FindByID(FormTable.CurrentRow);
	CurrentRow.Value = Undefined;
	
	If FormTable.CurrentData.Condition = "Accus list"
		Or FormTable.CurrentData.Condition = "Not in list" Then
		CurrentRow.Value = New ValueList;
		CurrentRow.Value.ValueType = FormTable.CurrentData.ValueType;
	Else
		CurrentRow.Value = Undefined;
	EndIf;
EndProcedure

&AtClient
Procedure AttributesDependenciesBeforeAdd(Item, Cancel, Clone, Parent, IsFolder, Parameter)
	If Not AddRow Then
		Cancel = True;
	Else
		OpenAttributeSelectionForm();
		AddRow = False;
	EndIf;
EndProcedure

&AtClient
Procedure OpenAttributeSelectionForm()
	FormParameters = New Structure;
	FormParameters.Insert("ObjectAttributes", ObjectAttributesInStorage);
	OpenForm("ChartOfCharacteristicTypes.AdditionalAttributesAndInfo.Form.SelectAttribute", FormParameters);
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure AddCondition(Command)
	AddRow = True;
	Items.AttributesDependencies.AddRow();
EndProcedure

&AtClient
Procedure OkCommand(Command)
	Result = New Structure;
	Result.Insert(PropertyToConfigure, SelectionSettingsInValueStorage());
	Notify("Properties_AttributeDependencySet", Result);
	Close();
EndProcedure

&AtClient
Procedure CancelCommand(Command)
	Close();
EndProcedure

#EndRegion

#Region Private

&AtServer
Function SelectionSettingsInValueStorage()
	
	If AttributesDependencies.Count() = 0 Then
		Return Undefined;
	EndIf;
	
	DependenciesTable = FormAttributeToValue("AttributesDependencies");
	TableCopy = DependenciesTable.Copy();
	TableCopy.Columns.Delete("Presentation");
	TableCopy.Columns.Delete("ValueType");
	
	FilterParameter = New Structure;
	FilterParameter.Insert("Condition", "Accus list"); // ID.
	ConvertDependenciesInList(TableCopy, FilterParameter);
	FilterParameter.Condition = "Not in list"; // ID.
	ConvertDependenciesInList(TableCopy, FilterParameter);
	
	Return New ValueStorage(TableCopy);
	
EndFunction

&AtServer
Procedure ConvertDependenciesInList(Table, Filter)
	FoundRows = Table.FindRows(Filter);
	For Each Row In FoundRows Do
		For Each Item In Row.Value Do
			NewRow = Table.Add();
			FillPropertyValues(NewRow, Row);
			NewRow.Value = Item.Value;
		EndDo;
		Table.Delete(Row);
	EndDo;
EndProcedure

&AtServer
Function ListOfAttributesForSelection(FullMetadataObjectName, AdditionalAttributesSet)
	
	ObjectAttributes = New ValueTable;
	ObjectAttributes.Columns.Add("Attribute");
	ObjectAttributes.Columns.Add("Presentation", New TypeDescription("String"));
	ObjectAttributes.Columns.Add("ValueType", New TypeDescription);
	ObjectAttributes.Columns.Add("PictureNumber", New TypeDescription("Number"));
	ObjectAttributes.Columns.Add("ChoiceMode", New TypeDescription("FoldersAndItemsUse"));
	
	MetadataObject = Metadata.FindByFullName(FullMetadataObjectName);
	
	For Each AdditionalAttribute In AdditionalAttributesSet Do
		ObjectProperties = Common.ObjectAttributesValues(AdditionalAttribute.Property, "Description, ValueType");
		AttributeString = ObjectAttributes.Add();
		AttributeString.Attribute = AdditionalAttribute.Property;
		AttributeString.Presentation = ObjectProperties.Description;
		AttributeString.PictureNumber  = 2;
		AttributeString.ValueType = ObjectProperties.ValueType;
	EndDo;
	
	For Each Attribute In MetadataObject.StandardAttributes Do
		AddAttributeToTable(ObjectAttributes, Attribute, True);
	EndDo;
	
	For Each Attribute In MetadataObject.Attributes Do
		AddAttributeToTable(ObjectAttributes, Attribute, False);
	EndDo;
	
	ObjectAttributes.Sort("Presentation Asc");
	
	ObjectAttributesInStorage = PutToTempStorage(ObjectAttributes, UUID);
	
	Return ObjectAttributes;
	
EndFunction

&AtServer
Procedure AddAttributeToTable(ObjectAttributes, Attribute, Standard)
	AttributeString = ObjectAttributes.Add();
	AttributeString.Attribute = Attribute.Name;
	AttributeString.Presentation = Attribute.Presentation();
	AttributeString.PictureNumber  = 1;
	AttributeString.ValueType = Attribute.Type;
	If Standard Then
		AttributeString.ChoiceMode = ?(Attribute.Name = "Parent", FoldersAndItemsUse.Folders, Undefined);
	Else
		AttributeString.ChoiceMode = Attribute.ChoiceFoldersAndItems;
	EndIf;
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	If EventName = "Properties_ObjectAttributeSelection" Then
		CurrentRow = AttributesDependencies.FindByID(Items.AttributesDependencies.CurrentRow);
		FillPropertyValues(CurrentRow, Parameter);
		AttributesDependenciesSetTypeRestrictionForValue();
		CurrentRow.DependentProperty = PropertyToConfigure;
		CurrentRow.Condition   = "Equal";
		CurrentRow.Value = CurrentRow.ValueType.AdjustValue(Undefined);
	EndIf;
EndProcedure

&AtClient
Procedure AttributesDependenciesSetTypeRestrictionForValue()
	
	FormTable = Items.AttributesDependencies;
	InputField    = Items.AttributesDependenciesRightValue;
	
	ChoiceParametersArray = New Array;
	If TypeOf(FormTable.CurrentData.Attribute) <> Type("String") Then
		ChoiceParametersArray.Add(New ChoiceParameter("Filter.Owner", FormTable.CurrentData.Attribute));
	EndIf;
	
	ChoiceMode = FormTable.CurrentData.ChoiceMode;
	If ChoiceMode = FoldersAndItemsUse.Folders Then
		InputField.ChoiceFoldersAndItems = FoldersAndItems.Folders;
	ElsIf ChoiceMode = FoldersAndItemsUse.Items Then
		InputField.ChoiceFoldersAndItems = FoldersAndItems.Items;
	ElsIf ChoiceMode = FoldersAndItemsUse.FoldersAndItems Then
		InputField.ChoiceFoldersAndItems = FoldersAndItems.FoldersAndItems;
	EndIf;
	
	InputField.ChoiceParameters = New FixedArray(ChoiceParametersArray);
	If FormTable.CurrentData.Condition = "Accus list"
		Or FormTable.CurrentData.Condition = "Not in list" Then
		InputField.TypeRestriction = New TypeDescription("ValueList");
	Else
		InputField.TypeRestriction = FormTable.CurrentData.ValueType;
	EndIf;
	
EndProcedure

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
	
	AvailabilityItem = ConditionalAppearanceItem.Appearance.Items.Find("Enabled");
	AvailabilityItem.Value = False;
	AvailabilityItem.Use = True;
	
	ComparisonValues = New ValueList;
	ComparisonValues.Add("Filled");
	ComparisonValues.Add("Not filled"); // an exception, it is ID.
	
	DataFilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue  = New DataCompositionField("AttributesDependencies.Condition");
	DataFilterItem.ComparisonType   = DataCompositionComparisonType.InList;
	DataFilterItem.RightValue = ComparisonValues;
	DataFilterItem.Use  = True;
	
	FieldAppearanceItem = ConditionalAppearanceItem.Fields.Items.Add();
	FieldAppearanceItem.Field = New DataCompositionField("AttributesDependenciesRightValue");
	FieldAppearanceItem.Use = True;
	
EndProcedure

#EndRegion
