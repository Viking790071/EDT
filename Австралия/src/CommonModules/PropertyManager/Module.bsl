#Region Public

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for standard processing of additional attributes.

// Creates main form attributes and fields necessary for work.
// Fills additional attributes if used.
// Is called from the OnCreateAtServer handler of the object form with properties.
// 
// Parameters:
//  Form - ClientApplicationForm - in which additional attributes will be displayed.
//
//  AdditionalParameters - Undefined - all additional parameters have default values.
//                               Earlier the attribute was called Object and had the meaning as the 
//                               structure property of the same name specified below.
//                          - Structure - with optional properties:
//
//    * Object - FormDataStructure - by object type if the property is not specified or Undefined, 
//               take object from the Object form attribute.
//
//    * ItemNameForPlacement - String - a group name of the form, in which properties will be placed.
//
//    * ArbitraryObject - Boolean - if True, then the additional attribute details table is created 
//            in the form, the Object parameter is ignored, and additional attributes are not created and not filled in.
//
//            It is useful upon sequential use of one form for viewing or editing additional 
//            attributes of different objects (including objects of different types).
//
//            After executing OnCreateAtServer, call FillAdditionalAttributesInForm() to add and 
//            fill additional attributes.
//            To save changes, call TransferValuesFromFormAttributesToObject(), and to update 
//            attributes, call UpdateAdditionalAttributeItems().
//
//    * CommandBarItemName - String - a group name of the form to which the button will be added.
//            EditContentOfAdditionalAttributes. If the item name is not specified, the standard 
//            group "Form.CommandBar" is used.
//
//    * HideDeleted - Boolean - enable/disable the hide deleted mode.
//            If the parameter is not specified, but the object parameter is specified and the Link 
//            property is not filled in, then the initial value is set to True, otherwise, False.
//            When calling the BeforeWriteAtServer procedure in the hide deleted mode, deleted 
//            values are cleared (not transferred back to object), and the HideDeleted mode is set to False.
//
Procedure OnCreateAtServer(Form, AdditionalParameters = Undefined) Export
	
	If Not PropertiesUsed(Form, AdditionalParameters) Then
		Return;
	EndIf;
	
	Context = New Structure;
	Context.Insert("Object",                     Undefined);
	Context.Insert("ItemForPlacementName",   "");
	Context.Insert("DeferredInitialization",    False);
	Context.Insert("ArbitraryObject",         False);
	Context.Insert("CommandBarItemName", "");
	Context.Insert("HideDeleted",            Undefined);
	
	If TypeOf(AdditionalParameters) = Type("Structure") Then
		FillPropertyValues(Context, AdditionalParameters);
	EndIf;
	
	If Context.ArbitraryObject Then
		CreateAdditionalAttributesDetails = True;
	Else
		If Context.Object = Undefined Then
			ObjectDetails = Form.Object;
		Else
			ObjectDetails = Context.Object;
		EndIf;
		CreateAdditionalAttributesDetails = UseAddlAttributes(ObjectDetails.Ref);
		If Not ValueIsFilled(ObjectDetails.Ref) AND Context.HideDeleted = Undefined Then
			Context.HideDeleted = True;
		EndIf;
	EndIf;
	
	NewMainFormObjects(Form, Context, CreateAdditionalAttributesDetails);
	
	If Context.DeferredInitialization Then
		
		If NOT Form.Properties_UseProperties
			OR NOT Form.Properties_UseAddlAttributes Then
			Return;
		EndIf;
		
		AssignmentKey = Undefined;
		ObjectPropertySets = PropertyManagerInternal.GetObjectPropertySets(
			ObjectDetails, AssignmentKey);
		
		PropertyManagerInternal.FillSetsWithAdditionalAttributes(
			ObjectPropertySets,
			Form.Properties_ObjectAdditionalAttributeSets);
		
		InfoNotFound = PropertyManagerInternal.AdditionalAttributesAndInfoNotFound(
			Form.Properties_ObjectAdditionalAttributeSets, False, True);
		
		If Form.PropertiesParameters.Property("EmptyDecorationAdded") Then
			For Each DecorationName In Form.PropertiesParameters.DecorationCollections Do
				Form.Items[DecorationName].Visible = Not InfoNotFound;
			EndDo;
		EndIf;
		
		UpdateFormAssignmentKey(Form, AssignmentKey);
	EndIf;
	
	If Not Context.ArbitraryObject
		AND Not Context.DeferredInitialization Then
		FillAdditionalAttributesInForm(Form, ObjectDetails, , Context.HideDeleted);
	EndIf;
	
EndProcedure

// Fills in an object from attributes created in the form.
// Is called from the BeforeWriteAtServer handler of the object form with properties.
//
// Parameters:
//  Form - ClientApplicationForm - already set in the OnCreateAtServer procedure.
//  CurrentObject - Object - <MetadataObjectKind>Object.<MetadataObjectName>.
//
Procedure OnReadAtServer(Form, CurrentObject) Export
	
	Structure = New Structure("Properties_UseProperties");
	FillPropertyValues(Structure, Form);
	
	If TypeOf(Structure.Properties_UseProperties) = Type("Boolean")
		AND Structure.Properties_UseProperties Then
		
		If Form.PropertiesParameters.Property("DeferredInitializationExecuted")
			AND Not Form.PropertiesParameters.DeferredInitializationExecuted Then
			Return;
		EndIf;
		
		FillAdditionalAttributesInForm(Form, CurrentObject);
	EndIf;
	
EndProcedure

// Fills in an object from attributes created in the form.
// Is called from the BeforeWriteAtServer handler of the object form with properties.
//
// Parameters:
//  Form - ClientApplicationForm - already set in the OnCreateAtServer procedure.
//  CurrentObject - Object - <MetadataObjectKind>Object.<MetadataObjectName>.
//
Procedure BeforeWriteAtServer(Form, CurrentObject) Export
	
	PropertyManagerInternal.TransferValuesFromFormAttributesToObject(Form, CurrentObject, True);
	
EndProcedure

// Checks if required attributes are filled in.
// 
// Parameters:
//  Form - ClientApplicationForm - already set in the OnCreateAtServer procedure.
//  Cancel - Boolean - a parameter of the FillCheckProcessingAtServer handler.
//  CheckedAttributes - Array - a parameter of the FillCheckProcessingAtServer handler.
//  Object - Object - by object type, if the property is not specified or Undefined, the object is 
//           taken from the Object form attribute.
//
Procedure FillCheckProcessing(Form, Cancel, AttributesToCheck, Object = Undefined) Export
	
	If NOT Form.Properties_UseProperties
	 OR NOT Form.Properties_UseAddlAttributes Then
		
		Return;
	EndIf;
	
	Destination = New Structure;
	Destination.Insert("PropertiesParameters", Undefined);
	FillPropertyValues(Destination, Form);
	
	If TypeOf(Destination.PropertiesParameters) = Type("Structure")
		AND Destination.PropertiesParameters.Property("DeferredInitializationExecuted")
		AND Not Destination.PropertiesParameters.DeferredInitializationExecuted Then
		FillAdditionalAttributesInForm(Form, Object);
	EndIf;
	
	Errors = Undefined;
	
	For each Row In Form.Properties_AdditionalAttributeDetails Do
		If Row.RequiredToFill AND NOT Row.Deleted Then
			Result = True;
			If Object = Undefined Then
				ObjectDetails = Form.Object;
			Else
				ObjectDetails = Object;
			EndIf;
			
			For Each DependentAttribute In Form.Properties_DependentAdditionalAttributesDescription Do
				If DependentAttribute.ValueAttributeName = Row.ValueAttributeName
					AND DependentAttribute.FillingRequiredCondition <> Undefined Then
					
					Parameters = New Structure;
					Parameters.Insert("ParameterValues", DependentAttribute.FillingRequiredCondition.ParameterValues);
					Parameters.Insert("Form", Form);
					Parameters.Insert("ObjectDetails", ObjectDetails);
					Result = Common.CalculateInSafeMode(DependentAttribute.FillingRequiredCondition.ConditionCode, Parameters);
					
					Break;
				EndIf;
			EndDo;
			If Not Result Then
				Continue;
			EndIf;
			
			If NOT ValueIsFilled(Form[Row.ValueAttributeName]) Then
				CommonClientServer.MessageToUser(
					StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Поле ""%1"" не заполнено.'; en = 'The ""%1"" field is required.'; pl = 'Pole ""%1"" nie jest wypełnione.';es_ES = 'El ""%1"" campo no está rellenado.';es_CO = 'El ""%1"" campo no está rellenado.';tr = '""%1"" alanı doldurulmadı.';it = 'Il campo ""%1"" è richiesto.';de = 'Das ""%1"" Feld ist nicht ausgefüllt.'"), Row.Description),
					,
					Row.ValueAttributeName,
					,
					Cancel);
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

// Updates sets of additional attributes and info for an object kind with properties.
//  Used upon writing catalog items that are object kinds with properties.
//  For example, if there is the Products catalog, to which the Properties subsystem is applied and
// the ProductKinds catalog is created for it, you need to call this procedure when writing the ProductKind item.
//
// Parameters:
//  ObjectKind - Object - for example, product kind before writing.
//  ObjectWithPropertiesName - String - for example, Product.
//  PropertySetAttributeName - String - used when there are several property sets or name of the 
//                              default set attribute that differs from PropertySet is used.
//
Procedure BeforeWriteObjectKind(ObjectKind,
                                  ObjectWithPropertiesName,
                                  PropertySetAttributeName = "PropertySet") Export
	
	SetPrivilegedMode(True);
	
	PropertySet   = ObjectKind[PropertySetAttributeName];
	SetParent = Catalogs.AdditionalAttributesAndInfoSets[ObjectWithPropertiesName];
	
	If ValueIsFilled(PropertySet) Then
		
		OldSetProperties = Common.ObjectAttributesValues(
			PropertySet, "Description, Parent, DeletionMark");
		
		If OldSetProperties.Description    = ObjectKind.Description
		   AND OldSetProperties.DeletionMark = ObjectKind.DeletionMark
		   AND OldSetProperties.Parent        = SetParent Then
			
			Return;
		EndIf;
		
		If OldSetProperties.Parent = SetParent Then
			LockDataForEdit(PropertySet);
			PropertySetObject = PropertySet.GetObject();
		Else
			PropertySetObject = PropertySet.Copy();
		EndIf;
	Else
		PropertySetObject = Catalogs.AdditionalAttributesAndInfoSets.CreateItem();
		PropertySetObject.Used = True;
	EndIf;
	
	PropertySetObject.Description    = ObjectKind.Description;
	PropertySetObject.DeletionMark = ObjectKind.DeletionMark;
	PropertySetObject.Parent        = SetParent;
	PropertySetObject.Write();
	
	ObjectKind[PropertySetAttributeName] = PropertySetObject.Ref;
	
	// Updating descriptions of uncommon additional attributes and info.
	If Not ValueIsFilled(PropertySet) Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.SetParameter("PropertySet", PropertySet);
	Query.Text =
	"SELECT
	|	Properties.Ref AS Ref,
	|	Properties.PropertySet.Description AS SetDescription,
	|	Properties.PropertySet.DeletionMark AS SetDeletionMark
	|FROM
	|	ChartOfCharacteristicTypes.AdditionalAttributesAndInfo AS Properties
	|WHERE
	|	Properties.PropertySet = &PropertySet
	|	AND CASE
	|			WHEN Properties.Description <> Properties.Title + "" ("" + Properties.PropertySet.Description + "")""
	|				THEN TRUE
	|			WHEN Properties.DeletionMark <> Properties.PropertySet.DeletionMark
	|				THEN TRUE
	|			ELSE FALSE
	|		END";
	Selection = Query.Execute().Select();
	
	PropertiesSelection = Query.Execute().Select();
	While PropertiesSelection.Next() Do
		LockDataForEdit(PropertiesSelection.Ref);
		Object = PropertiesSelection.Ref.GetObject();
		Object.Description = Object.Title + " (" + String(PropertiesSelection.SetDescription) + ")";
		Object.DeletionMark = PropertiesSelection.SetDeletionMark;
		Object.Write();
	EndDo;
	
EndProcedure

// Updates displayed data on the object form with properties.
// 
// Parameters:
//  Form - ClientApplicationForm - already set in the OnCreateAtServer procedure.
//
//  Object - Undefined - take the object from the Object form attribute.
//                  - Object - CatalogObject, DocumentObject, ..., FormDataStructure (by object type).
//
//  HideDeleted - Undefined - do not change the current hide deleted mode set earlier.
//                  - Boolean - enable/disable the hide deleted mode.
//                    When calling the BeforeWriteAtServer procedure in the hide deleted mode, 
//                    deleted values are cleared (not transferred back to object), and the HideDeleted mode is set to False.
//
Procedure UpdateAdditionalAttributesItems(Form, Object = Undefined, HideDeleted = Undefined) Export
	
	PropertyManagerInternal.TransferValuesFromFormAttributesToObject(Form, Object);
	
	FillAdditionalAttributesInForm(Form, Object, , HideDeleted);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for non-standard processing of additional properties.

// Creates/recreates additional attributes and items in the property owner form.
//
// Parameters:
//  Form - ClientApplicationForm - already set in the OnCreateAtServer procedure.
//
//  Object - Undefined - take the object from the Object form attribute.
//                  - Object - CatalogObject, DocumentObject, ..., FormDataStructure (by object type).
//
//  LabelsFields - Boolean - if True is specified, then instead of input fields, the label fields are created on the form.
//
//  HideDeleted - Undefined - do not change the current hide deleted mode set earlier.
//                  - Boolean - enable/disable the hide deleted mode.
//                    When calling the BeforeWriteAtServer procedure in the hide deleted mode, 
//                    deleted values are cleared (not transferred back to object), and the HideDeleted mode is set to False.
//
Procedure FillAdditionalAttributesInForm(Form, Object = Undefined, LabelsFields = False, HideDeleted = Undefined) Export
	
	If NOT Form.Properties_UseProperties
	 OR NOT Form.Properties_UseAddlAttributes Then
		Return;
	EndIf;
	
	If TypeOf(HideDeleted) = Type("Boolean") Then
		Form.Properties_HideDeleted = HideDeleted;
	EndIf;
	
	If Object = Undefined Then
		ObjectDetails = Form.Object;
	Else
		ObjectDetails = Object;
	EndIf;
	
	Form.Properties_ObjectAdditionalAttributeSets = New ValueList;
	
	AssignmentKey = Undefined;
	ObjectPropertySets = PropertyManagerInternal.GetObjectPropertySets(
		ObjectDetails, AssignmentKey);
	
	PropertyManagerInternal.FillSetsWithAdditionalAttributes(
		ObjectPropertySets,
		Form.Properties_ObjectAdditionalAttributeSets);
	
	UpdateFormAssignmentKey(Form, AssignmentKey);
	
	PropertiesDetails = PropertyManagerInternal.PropertiesValues(
		ObjectDetails.AdditionalAttributes.Unload(),
		Form.Properties_ObjectAdditionalAttributeSets,
		False);
	
	PropertiesDetails.Columns.Add("ValueAttributeName");
	PropertiesDetails.Columns.Add("RefTypeString");
	PropertiesDetails.Columns.Add("LinkAttributeNameValue");
	PropertiesDetails.Columns.Add("NameUniquePart");
	PropertiesDetails.Columns.Add("AdditionalValue");
	PropertiesDetails.Columns.Add("Boolean");
	
	DeleteOldAttributesAndItems(Form);
	
	// Creating attributes.
	AttributesToAdd = New Array();
	
	For each PropertyDetails In PropertiesDetails Do
		
		PropertyValueType = PropertyDetails.ValueType;
		TypesList = PropertyValueType.Types();
		StringAttribute = (TypesList.Count() = 1) AND (TypesList[0] = Type("String"));
		
		// Support of strings with unlimited length.
		UseUnlimitedString = PropertyManagerInternal.UseUnlimitedString(
			PropertyValueType, PropertyDetails.MultilineInputField);
		
		If UseUnlimitedString Then
			PropertyValueType = New TypeDescription("String");
		ElsIf PropertyValueType.ContainsType(Type("String"))
			AND PropertyValueType.StringQualifiers.Length = 0 Then
			// If unlimited string cannot be used, but it is unlimited in attribute properties, set the limit of 
			// 1024 characters.
			PropertyValueType = New TypeDescription(PropertyDetails.ValueType,
				,,, New StringQualifiers(1024));
		EndIf;
		
		PropertyDetails.NameUniquePart = 
			StrReplace(Upper(String(PropertyDetails.Set.UUID())), "-", "x")
			+ "_"
			+ StrReplace(Upper(String(PropertyDetails.Property.UUID())), "-", "x");
		
		PropertyDetails.ValueAttributeName =
			"AdditionalRequisiteValue_" + PropertyDetails.NameUniquePart;
		
		PropertyDetails.RefTypeString = False;
		If StringAttribute
			AND Not UseUnlimitedString
			AND PropertyDetails.OutputAsHyperlink Then
			FormattedString                           = New TypeDescription("FormattedString");
			PropertyDetails.RefTypeString           = True;
			PropertyDetails.LinkAttributeNameValue = "ReferenceAdditionalAttributeValue_" + PropertyDetails.NameUniquePart;
			
			Attribute = New FormAttribute(PropertyDetails.LinkAttributeNameValue, FormattedString, , PropertyDetails.Description, True);
			AttributesToAdd.Add(Attribute);
		EndIf;
		
		If PropertyDetails.Deleted Then
			PropertyValueType = New TypeDescription("String");
		EndIf;
		
		Attribute = New FormAttribute(PropertyDetails.ValueAttributeName, PropertyValueType, , PropertyDetails.Description, True);
		AttributesToAdd.Add(Attribute);
		
		PropertyDetails.AdditionalValue =
			PropertyManagerInternal.ValueTypeContainsPropertyValues(PropertyValueType);
		
		PropertyDetails.Boolean = Common.TypeDetailsContainsType(PropertyValueType, Type("Boolean"));
	EndDo;
	Form.ChangeAttributes(AttributesToAdd);
	
	// Creating form items.
	For Each PropertyDetails In PropertiesDetails Do
		
		ItemForPlacementName = Form.Properties_ItemNameForPlacement;
		If TypeOf(ItemForPlacementName) <> Type("ValueList") Then
			If ItemForPlacementName = Undefined Then
				ItemForPlacementName = "";
			EndIf;
			
			PlacementItem = ?(ItemForPlacementName = "", Undefined, Form.Items[ItemForPlacementName]);
		Else
			SectionsForPlacement = Form.Properties_ItemNameForPlacement;
			SetPlacement = SectionsForPlacement.FindByValue(PropertyDetails.Set);
			If SetPlacement = Undefined Then
				SetPlacement = SectionsForPlacement.FindByValue("AllOther");
			EndIf;
			PlacementItem = Form.Items[SetPlacement.Presentation];
		EndIf;
		
		FormPropertyDetails = Form.Properties_AdditionalAttributeDetails.Add();
		FillPropertyValues(FormPropertyDetails, PropertyDetails);
		
		// Filling in the table of dependent additional attributes.
		If PropertyDetails.AdditionalAttributesDependencies.Count() > 0
			AND Not PropertyDetails.Deleted Then
			DependentAttributeDetails = Form.Properties_DependentAdditionalAttributesDescription.Add();
			FillPropertyValues(DependentAttributeDetails, PropertyDetails);
		EndIf;
		
		For Each TableRow In PropertyDetails.AdditionalAttributesDependencies Do
			If TableRow.DependentProperty = "RequiredToFill"
				AND PropertyDetails.ValueType = New TypeDescription("Boolean") Then
				Continue;
			EndIf;
			If PropertyDetails.Deleted Then
				Continue;
			EndIf;
			
			If TypeOf(TableRow.Attribute) = Type("String") Then
				AttributePath = "Parameters.ObjectDetails." + TableRow.Attribute;
			Else
				AdditionalAttributeDetails = PropertiesDetails.Find(TableRow.Attribute, "Property");
				If AdditionalAttributeDetails = Undefined Then
					Continue; // Additional attribute does not exist, the condition is ignored.
				EndIf;
				AttributePath = "Parameters.Form." + AdditionalAttributeDetails.ValueAttributeName;
			EndIf;
			
			ConditionTemplate = "";
			If TableRow.Condition = "Equal" Then
				ConditionTemplate = "%1 = %2";
			ElsIf TableRow.Condition = "Not equal" Then // not an error, an ID.
				ConditionTemplate = "%1 <> %2";
			EndIf;
			
			If TableRow.Condition = "Accus list" Then // not an error, an ID.
				ConditionTemplate = "%2.FindByValue(%1) <> Undefined"
			ElsIf TableRow.Condition = "Not in list" Then // not an error, an ID.
				ConditionTemplate = "%2.FindByValue(%1) = Undefined"
			EndIf;
			
			RightValue = "";
			If ValueIsFilled(ConditionTemplate) Then
				RightValue = "Parameters.ParameterValues[""" + AttributePath + """]";
			EndIf;
			
			If TableRow.Condition = "Filled" Then
				ConditionTemplate = "ValueIsFilled(%1)";
			ElsIf TableRow.Condition = "Not filled" Then // not an error, an ID.
				ConditionTemplate = "Not ValueIsFilled(%1)";
			EndIf;
			
			If ValueIsFilled(RightValue) Then
				ConditionCode = StringFunctionsClientServer.SubstituteParametersToString(ConditionTemplate, AttributePath, RightValue);
			Else
				ConditionCode = StringFunctionsClientServer.SubstituteParametersToString(ConditionTemplate, AttributePath);
			EndIf;
			
			If TableRow.DependentProperty = "Available" Then
				SetDependenceCondition(DependentAttributeDetails.AvailabilityCondition, AttributePath, TableRow, ConditionCode, TableRow.Condition);
			ElsIf TableRow.DependentProperty = "Visible" Then
				SetDependenceCondition(DependentAttributeDetails.VisibilityCondition, AttributePath, TableRow, ConditionCode, TableRow.Condition);
			Else
				SetDependenceCondition(DependentAttributeDetails.FillingRequiredCondition, AttributePath, TableRow, ConditionCode, TableRow.Condition);
			EndIf;
		EndDo;
		
		If PropertyDetails.RefTypeString Then
			If ValueIsFilled(PropertyDetails.Value) Then
				Value = PropertyDetails.ValueType.AdjustValue(PropertyDetails.Value);
				StringValue = StringFunctionsClientServer.FormattedString(Value);
			Else
				Value = NStr("ru = 'не задано'; en = 'not set'; pl = 'nie określono';es_ES = 'no definido';es_CO = 'no definido';tr = 'Belirlenmedi';it = 'non impostato';de = 'nicht gesetzt'");
				EditLink = "NotDefined";
				StringValue = New FormattedString(Value,, StyleColors.EmptyHyperlinkColor,, EditLink);
			EndIf;
			Form[PropertyDetails.LinkAttributeNameValue] = StringValue;
		EndIf;
		Form[PropertyDetails.ValueAttributeName] = PropertyDetails.Value;
		
		If PropertyDetails.Deleted AND Form.Properties_HideDeleted Then
			Continue;
		EndIf;
		
		If ObjectPropertySets.Count() > 1 Then
			
			ListItem = Form.Properties_AdditionalAttributeGroupItems.FindByValue(
				PropertyDetails.Set);
			
			If ListItem <> Undefined Then
				Parent = Form.Items[ListItem.Presentation];
			Else
				SetDetails = ObjectPropertySets.Find(PropertyDetails.Set, "Set");
				
				If SetDetails = Undefined Then
					SetDetails = ObjectPropertySets.Add();
					SetDetails.Set     = PropertyDetails.Set;
					SetDetails.Title = NStr("ru = 'Удаленные реквизиты'; en = 'Deleted attributes'; pl = 'Usunięte atrybuty';es_ES = 'Atributos eliminados';es_CO = 'Atributos eliminados';tr = 'Silinen özellikler';it = 'Attributi eliminati';de = 'Gelöschte Attribute'")
				EndIf;
				
				If NOT ValueIsFilled(SetDetails.Title) Then
					SetDetails.Title = String(PropertyDetails.Set);
				EndIf;
				
				SetItemName = "AdditionalAttributesSet" + PropertyDetails.NameUniquePart;
				
				Parent = Form.Items.Add(SetItemName, Type("FormGroup"), PlacementItem);
				
				Form.Properties_AdditionalAttributeGroupItems.Add(
					PropertyDetails.Set, Parent.Name);
				
				If TypeOf(PlacementItem) = Type("FormGroup")
				   AND PlacementItem.Type = FormGroupType.Pages Then
					
					Parent.Type = FormGroupType.Page;
				Else
					Parent.Type = FormGroupType.UsualGroup;
					Parent.Representation = UsualGroupRepresentation.None;
				EndIf;
				Parent.ShowTitle = False;
				Parent.Group = ChildFormItemsGroup.Vertical;
				
				FilledGroupProperties = New Structure;
				For each Column In ObjectPropertySets.Columns Do
					If SetDetails[Column.Name] <> Undefined Then
						FilledGroupProperties.Insert(Column.Name, SetDetails[Column.Name]);
					EndIf;
				EndDo;
				FillPropertyValues(Parent, FilledGroupProperties);
			EndIf;
		Else
			Parent = PlacementItem;
		EndIf;
		
		If PropertyDetails.OutputAsHyperlink Then
			HyperlinkGroupName = "Group_" + PropertyDetails.NameUniquePart;
			HyperlinkGroup = Form.Items.Add(HyperlinkGroupName, Type("FormGroup"), Parent);
			HyperlinkGroup.Type = FormGroupType.UsualGroup;
			HyperlinkGroup.Representation = UsualGroupRepresentation.None;
			HyperlinkGroup.ShowTitle = False;
			HyperlinkGroup.Group = ChildFormItemsGroup.AlwaysHorizontal;
			HyperlinkGroup.Title = PropertyDetails.Description;
			
			Item = Form.Items.Add(PropertyDetails.ValueAttributeName, Type("FormField"), HyperlinkGroup);
			
			If Not LabelsFields Then
				ButtonName = "Button_" + PropertyDetails.NameUniquePart;
				Button = Form.Items.Add(
					ButtonName,
					Type("FormButton"),
					HyperlinkGroup);
					
				Button.OnlyInAllActions = True;
				Button.CommandName = "EditAttributeHyperlink";
				Button.ShapeRepresentation = ButtonShapeRepresentation.WhenActive;
			EndIf;
			
			If Not PropertyDetails.RefTypeString AND ValueIsFilled(PropertyDetails.Value) Then
				Item.Hyperlink = True;
			EndIf;
		Else
			Item = Form.Items.Add(PropertyDetails.ValueAttributeName, Type("FormField"), Parent);
		EndIf;
		
		FormPropertyDetails.FormItemAdded = True;
		
		If PropertyDetails.Boolean AND IsBlankString(PropertyDetails.FormatProperties) Then
			Item.Type = FormFieldType.CheckBoxField;
			Item.TitleLocation = FormItemTitleLocation.Right;
		Else
			If LabelsFields Then
				Item.Type = FormFieldType.InputField;
			ElsIf PropertyDetails.OutputAsHyperlink
				AND (PropertyDetails.RefTypeString
					Or ValueIsFilled(PropertyDetails.Value))Then
				Item.Type = FormFieldType.LabelField;
			Else
				Item.Type = FormFieldType.InputField;
				Item.AutoMarkIncomplete = PropertyDetails.RequiredToFill AND NOT PropertyDetails.Deleted;
			EndIf;
			
			Item.VerticalStretch = False;
			Item.TitleLocation     = FormItemTitleLocation.Left;
		EndIf;
		
		If PropertyDetails.RefTypeString Then
			Item.DataPath = PropertyDetails.LinkAttributeNameValue;
			Item.SetAction("URLProcessing", "Attachable_PropertiesExecuteCommand");
		Else
			Item.DataPath = PropertyDetails.ValueAttributeName;
		EndIf;
		Item.ToolTip   = PropertyDetails.ToolTip;
		Item.SetAction("OnChange", "Attachable_OnChangeAdditionalAttribute");
		
		If Item.Type = FormFieldType.InputField
		   AND Not UseUnlimitedString
		   AND PropertyDetails.ValueType.Types().Find(Type("String")) <> Undefined Then
			
			Item.TypeLink = New TypeLink("Properties_AdditionalAttributeDetails.Property",
				PropertiesDetails.IndexOf(PropertyDetails));
		EndIf;
		
		If PropertyDetails.MultilineInputField > 0 Then
			If NOT LabelsFields Then
				Item.MultiLine = True;
			EndIf;
			Item.Height = PropertyDetails.MultilineInputField;
		EndIf;
		
		If NOT IsBlankString(PropertyDetails.FormatProperties)
			AND Not PropertyDetails.OutputAsHyperlink Then
			If LabelsFields Then
				Item.Format = PropertyDetails.FormatProperties;
			Else
				FormatString = "";
				Array = StrSplit(PropertyDetails.FormatProperties, ";", False);
				
				For each Substring In Array Do
					If StrFind(Substring, "DE=") > 0 OR StrFind(Substring, "DE=") > 0 Then
						Continue;
					EndIf;
					If StrFind(Substring, "NZ=") > 0 OR StrFind(Substring, "NZ=") > 0 Then
						Continue;
					EndIf;
					If StrFind(Substring, "DF=") > 0 OR StrFind(Substring, "DF=") > 0 Then
						If StrFind(Substring, "ddd") > 0 OR StrFind(Substring, "ddd") > 0 Then
							Substring = StrReplace(Substring, "ddd", "dd");
							Substring = StrReplace(Substring, "ddd", "dd");
						EndIf;
						If StrFind(Substring, "dddd") > 0 OR StrFind(Substring, "dddd") > 0 Then
							Substring = StrReplace(Substring, "dddd", "dd");
							Substring = StrReplace(Substring, "dddd", "dd");
						EndIf;
						If StrFind(Substring, "MMM") > 0 OR StrFind(Substring, "MMM") > 0 Then
							Substring = StrReplace(Substring, "MMM", "MM");
							Substring = StrReplace(Substring, "MMM", "MM");
						EndIf;
						If StrFind(Substring, "MMMM") > 0 OR StrFind(Substring, "MMMM") > 0 Then
							Substring = StrReplace(Substring, "MMMM", "MM");
							Substring = StrReplace(Substring, "MMMM", "MM");
						EndIf;
					EndIf;
					If StrFind(Substring, "DLF=") > 0 OR StrFind(Substring, "DLF=") > 0 Then
						If StrFind(Substring, "DD") > 0 OR StrFind(Substring, "DD") > 0 Then
							Substring = StrReplace(Substring, "DD", "A");
							Substring = StrReplace(Substring, "DD", "D");
						EndIf;
					EndIf;
					FormatString = FormatString + ?(FormatString = "", "", ";") + Substring;
				EndDo;
				
				Item.Format = FormatString;
				Item.EditFormat = FormatString;
			EndIf;
		EndIf;
		
		If PropertyDetails.Deleted Then
			Item.TitleTextColor = StyleColors.InaccessibleCellTextColor;
			Item.TitleFont = StyleFonts.DeletedAdditionalAttributeFont;
			If Item.Type = FormFieldType.InputField Then
				Item.ClearButton = True;
				Item.ChoiceButton = False;
				Item.OpenButton = False;
				Item.DropListButton = False;
				Item.TextEdit = False;
			EndIf;
			
		ElsIf NOT LabelsFields Then
			
			AdditionalValuesTypes = New Map;
			AdditionalValuesTypes.Insert(Type("CatalogRef.ObjectsPropertiesValues"), True);
			AdditionalValuesTypes.Insert(Type("CatalogRef.ObjectPropertyValueHierarchy"), True);
			
			UsedAdditionalValuesType = True;
			For each Type In PropertyDetails.ValueType.Types() Do
				If AdditionalValuesTypes.Get(Type) = Undefined Then
					UsedAdditionalValuesType = False;
					Break;
				EndIf;
			EndDo;
		EndIf;
		
		If NOT LabelsFields AND PropertyDetails.AdditionalValue AND Item.Type = FormFieldType.InputField Then
			ChoiceParameters = New Array;
			ChoiceParameters.Add(New ChoiceParameter("Filter.Owner",
				?(ValueIsFilled(PropertyDetails.AdditionalValuesOwner),
					PropertyDetails.AdditionalValuesOwner, PropertyDetails.Property)));
			Item.ChoiceParameters = New FixedArray(ChoiceParameters);
		EndIf;
		
	EndDo;
	
	// Setting visibility, availability and required filling of additional attributes.
	For Each DependentAttributeDetails In Form.Properties_DependentAdditionalAttributesDescription Do
		If DependentAttributeDetails.OutputAsHyperlink Then
			ProcessedItem = StrReplace(DependentAttributeDetails.ValueAttributeName, "AdditionalRequisiteValue_", "Group_");
		Else
			ProcessedItem = DependentAttributeDetails.ValueAttributeName;
		EndIf;
		
		If DependentAttributeDetails.AvailabilityCondition <> Undefined Then
			Result = ConditionCalculationResult(Form, ObjectDetails, DependentAttributeDetails.AvailabilityCondition);
			Item = Form.Items[ProcessedItem];
			If Item.Enabled <> Result Then
				Item.Enabled = Result;
			EndIf;
		EndIf;
		If DependentAttributeDetails.VisibilityCondition <> Undefined Then
			Result = ConditionCalculationResult(Form, ObjectDetails, DependentAttributeDetails.VisibilityCondition);
			Item = Form.Items[ProcessedItem];
			If Item.Visible <> Result Then
				Item.Visible = Result;
			EndIf;
		EndIf;
		If DependentAttributeDetails.FillingRequiredCondition <> Undefined Then
			If Not DependentAttributeDetails.RequiredToFill
				Or Form.Items[DependentAttributeDetails.ValueAttributeName].Type = FormFieldType.InputField Then
				Continue;
			EndIf;
			
			Result = ConditionCalculationResult(Form, ObjectDetails, DependentAttributeDetails.FillingRequiredCondition);
			Item = Form.Items[ProcessedItem];
			If Not DependentAttributeDetails.OutputAsHyperlink
				AND Item.AutoMarkIncomplete <> Result Then
				Item.AutoMarkIncomplete = Result;
			EndIf;
		EndIf;
	EndDo;
	
	Structure = New Structure("PropertiesParameters");
	FillPropertyValues(Structure, Form);
	If TypeOf(Structure.PropertiesParameters) = Type("Structure")
		AND Structure.PropertiesParameters.Property("DeferredInitializationExecuted") Then
		Form.PropertiesParameters.DeferredInitializationExecuted = True;
		// Deleting temporary decoration if it was added.
		If Form.PropertiesParameters.Property("EmptyDecorationAdded") Then
			For Each DecorationName In Form.PropertiesParameters.DecorationCollections Do
				Form.Items.Delete(Form.Items[DecorationName]);
			EndDo;
			Form.PropertiesParameters.Delete("EmptyDecorationAdded");
		EndIf;
	EndIf;
	
EndProcedure

// Transfers property values from form attributes to the tabular section of the object.
// 
// Parameters:
//  Form - ClientApplicationForm - already set in the OnCreateAtServer procedure.
//  Object - Undefined - take the object from the Object form attribute.
//               - Object - CatalogObject, DocumentObject, ..., FormDataStructure (by object type).
//
Procedure TransferValuesFromFormAttributesToObject(Form, Object = Undefined) Export
	
	PropertyManagerInternal.TransferValuesFromFormAttributesToObject(Form, Object);
	
EndProcedure

// Removes old attributes and form items.
// 
// Parameters:
//  Form - ClientApplicationForm - already set in the OnCreateAtServer procedure.
//  
Procedure DeleteOldAttributesAndItems(Form) Export
	
	AttributesToDelete = New Array;
	For each PropertyDetails In Form.Properties_AdditionalAttributeDetails Do
		UniquePart = StrReplace(PropertyDetails.ValueAttributeName, "AdditionalRequisiteValue_", "");
		
		AttributesToDelete.Add(PropertyDetails.ValueAttributeName);
		If PropertyDetails.RefTypeString Then
			AttributesToDelete.Add("ReferenceAdditionalAttributeValue_" + UniquePart);
		EndIf;
		If PropertyDetails.FormItemAdded Then
			If PropertyDetails.OutputAsHyperlink Then
				Form.Items.Delete(Form.Items["Group_" + UniquePart]);
			Else
				Form.Items.Delete(Form.Items[PropertyDetails.ValueAttributeName]);
			EndIf;
		EndIf;
	EndDo;
	
	If AttributesToDelete.Count() > 0 Then
		Form.ChangeAttributes(, AttributesToDelete);
	EndIf;
	
	For each ListItem In Form.Properties_AdditionalAttributeGroupItems Do
		Form.Items.Delete(Form.Items[ListItem.Presentation]);
	EndDo;
	
	Form.Properties_AdditionalAttributeDetails.Clear();
	Form.Properties_AdditionalAttributeGroupItems.Clear();
	Form.Properties_DependentAdditionalAttributesDescription.Clear();
	
EndProcedure

// Returns additional attributes and info for the specified object.
//
// Parameters:
//  PropertiesOwner - Reference - for example, CatalogRef.Product, DocumentRef.SalesOrder, ...
//                       - Object - for example, CatalogObject.Product, DocumentObject.SalesOrder, ...
//                       - FormDataStructure - a collection by property owner object type.
//  GetAdditionalAttributes - Boolean - include additional attributes to the result.
//  GetAdditionalInfo - Boolean - include additional info to the result.
//
// Returns:
//  Array - values
//    * ChartOfCharacteristicTypesRef.AdditionalAttributesAndInfo - if available.
//
Function ObjectProperties(PropertiesOwner, GetAdditionalAttributes = True, GetAdditionalInfo = True) Export
	
	If NOT (GetAdditionalAttributes OR GetAdditionalInfo) Then
		Return New Array;
	EndIf;
	
	GetAdditionalInfo = GetAdditionalInfo AND AccessRight("Read", Metadata.InformationRegisters.AdditionalInfo);
	
	SetPrivilegedMode(True);
	ObjectPropertySets = PropertyManagerInternal.GetObjectPropertySets(
		PropertiesOwner);
	SetPrivilegedMode(False);
	
	ObjectPropertySetsArray = ObjectPropertySets.UnloadColumn("Set");
	
	QueryTextAdditionalAttributes = 
		"SELECT
		|	PropertiesTable.Property AS Property
		|FROM
		|	Catalog.AdditionalAttributesAndInfoSets.AdditionalAttributes AS PropertiesTable
		|WHERE
		|	PropertiesTable.Ref IN (&ObjectPropertySetsArray)";
	
	QueryTextAdditionalInfo = 
		"SELECT ALLOWED
		|	PropertiesTable.Property AS Property
		|FROM
		|	Catalog.AdditionalAttributesAndInfoSets.AdditionalInfo AS PropertiesTable
		|WHERE
		|	PropertiesTable.Ref IN (&ObjectPropertySetsArray)";
	
	Query = New Query;
	
	If GetAdditionalAttributes AND GetAdditionalInfo Then
		
		Query.Text = QueryTextAdditionalInfo + "
		|
		| UNION ALL
		|" + QueryTextAdditionalAttributes;
		
	ElsIf GetAdditionalAttributes Then
		Query.Text = QueryTextAdditionalAttributes;
		
	ElsIf GetAdditionalInfo Then
		Query.Text = QueryTextAdditionalInfo;
	EndIf;
	
	Query.Parameters.Insert("ObjectPropertySetsArray", ObjectPropertySetsArray);
	
	Result = Query.Execute().Unload().UnloadColumn("Property");
	
	Return Result;
	
EndFunction

// Returns values of additional object properties.
//
// Parameters:
//  ObjectsWithProperties - Array - objects for which additional property values are to be received.
//                       - AnyRef - a reference to an object, for example, CatalogRef.Product,
//                                       DocumentRef.SalesOrder, ...
//  GetAdditionalAttributes - Boolean - include additional attributes to the result. Default value is True.
//  GetAdditionalInfo - Boolean - include additional info to the result. Default value is True.
//  Properties - Array - properties:
//                          * ChartOfCharacteristicTypesRef.AdditionalAttributesAndInfo - values to 
//                            be received.
//                          * String - a unique name of an additional property.
//                       - Undefined - receive values of all owner properties by default.
//
// Returns:
//  ValueTable - columns:
//    * Property - ChartOfCharacteristicTypesRef.AdditionalAttributesAndInfo - an owner property.
//    * Value - Arbitrary - values of any type from metadata object property type details:
//                  "Metadata.ChartOfCharacteristicTypes.AdditionalAttributesAndInfo.Type".
//    * PropertiesOwner - AnyRef - a reference to an object.
//
Function PropertiesValues(ObjectsWithProperties,
                        GetAdditionalAttributes = True,
                        GetAdditionalInfo = True,
                        Properties = Undefined) Export
	
	GetAdditionalInfo = GetAdditionalInfo AND AccessRight("Read", Metadata.InformationRegisters.AdditionalInfo);
	
	If TypeOf(ObjectsWithProperties) = Type("Array") Then
		PropertiesOwner = ObjectsWithProperties[0];
	Else
		PropertiesOwner = ObjectsWithProperties;
	EndIf;
	
	If Properties = Undefined Then
		Properties = ObjectProperties(PropertiesOwner, GetAdditionalAttributes, GetAdditionalInfo);
	EndIf;
	
	ObjectWithPropertiesName = Common.TableNameByRef(PropertiesOwner);
	
	QueryTextAdditionalAttributes =
		"SELECT [ALLOWED]
		|	PropertiesTable.Property AS Property,
		|	PropertiesTable.Value AS Value,
		|	PropertiesTable.TextString,
		|	PropertiesTable.Ref AS PropertiesOwner
		|FROM
		|	[ObjectWithPropertiesName].AdditionalAttributes AS PropertiesTable
		|		LEFT JOIN ChartOfCharacteristicTypes.AdditionalAttributesAndInfo AS AdditionalAttributesAndInfo
		|		ON AdditionalAttributesAndInfo.Ref = PropertiesTable.Property
		|WHERE
		|	PropertiesTable.Ref IN (&ObjectsWithProperties)
		|	AND (AdditionalAttributesAndInfo.Ref IN (&Properties)
		|		OR AdditionalAttributesAndInfo.Name IN (&Properties))";
	
	QueryTextAdditionalInfo =
		"SELECT [ALLOWED]
		|	PropertiesTable.Property AS Property,
		|	PropertiesTable.Value AS Value,
		|	"""" AS TextString,
		|	PropertiesTable.Object AS PropertiesOwner
		|FROM
		|	InformationRegister.AdditionalInfo AS PropertiesTable
		|		LEFT JOIN ChartOfCharacteristicTypes.AdditionalAttributesAndInfo AS AdditionalAttributesAndInfo
		|		ON AdditionalAttributesAndInfo.Ref = PropertiesTable.Property
		|WHERE
		|	PropertiesTable.Object IN (&ObjectsWithProperties)
		|	AND (AdditionalAttributesAndInfo.Ref IN (&Properties)
		|		OR AdditionalAttributesAndInfo.Name IN (&Properties))";
	
	Query = New Query;
	
	If GetAdditionalAttributes AND GetAdditionalInfo Then
		QueryText = StrReplace(QueryTextAdditionalAttributes, "[ALLOWED]", "ALLOWED") + "
			|
			| UNION ALL
			|" + StrReplace(QueryTextAdditionalInfo, "[ALLOWED]", "");
		
	ElsIf GetAdditionalAttributes Then
		QueryText = StrReplace(QueryTextAdditionalAttributes, "[ALLOWED]", "ALLOWED");
		
	ElsIf GetAdditionalInfo Then
		QueryText = StrReplace(QueryTextAdditionalInfo, "[ALLOWED]", "ALLOWED");
	EndIf;
	
	QueryText = StrReplace(QueryText, "[ObjectWithPropertiesName]", ObjectWithPropertiesName);
	
	Query.Parameters.Insert("ObjectsWithProperties", ObjectsWithProperties);
	Query.Parameters.Insert("Properties", Properties);
	Query.Text = QueryText;
	
	Result = Query.Execute().Unload();
	ResultWithTextStrings = Undefined;
	RowIndex = 0;
	For each PropertyValue In Result Do
		TextString = PropertyValue.TextString;
		If Not IsBlankString(TextString) Then
			If ResultWithTextStrings = Undefined Then
				ResultWithTextStrings = Result.Copy(,"Property, PropertiesOwner");
				ResultWithTextStrings.Columns.Add("Value");
				ResultWithTextStrings.LoadColumn(Result.UnloadColumn("Value"), "Value");
			EndIf;
			ResultWithTextStrings[RowIndex].Value = TextString;
		EndIf;
		RowIndex = RowIndex + 1;
	EndDo;
	
	Return ?(ResultWithTextStrings <> Undefined, ResultWithTextStrings, Result);
EndFunction

// Returns a value of an additional object property.
//
// Parameters:
//  Object - AnyRef - a reference to an object, for example, CatalogRef.Product,
//                           DocumentRef.SalesOrder, ...
//  Property - ChartOfCharacteristicTypesRef.AdditionalAttributesAndInfo - a reference to the 
//                           additional attribute whose value is to be received.
//           - String - an additional property name.
//
// Returns:
//  Arbitrary - any value allowed for the property.
//
Function PropertyValue(Object, Property) Export
	GetAttributes = PropertyManagerInternal.IsMetadataObjectWithAdditionalAttributes(Object.Metadata());
	
	Result = PropertiesValues(Object, GetAttributes, True, Property);
	If Result.Count() = 1 Then
		Return Result[0].Value;
	EndIf;
EndFunction

// Checks whether the object has a property.
//
// Parameters:
//  PropertiesOwner - Reference - for example, CatalogRef.Product, DocumentRef.SalesOrder, ...
//  Property - ChartOfCharacteristicTypesRef.AdditionalAttributesAndInfo - a property being checked.
//
// Returns:
//  Boolean - if True, the owner has a property.
//
Function CheckObjectProperty(PropertiesOwner, Property) Export
	
	PropertiesArray = ObjectProperties(PropertiesOwner);
	
	If PropertiesArray.Find(Property) = Undefined Then
		Return False;
	Else
		Return True;
	EndIf;
	
EndFunction

// Writes additional attributes and info to the property owner.
// Changes occur in a transaction.
// 
// Parameters:
//  PropertiesOwner - Reference - for example, CatalogRef.Product, DocumentRef.SalesOrder, ...
//  PropertyAndValueTable - ValueTable - with columns:
//    * Property - ChartOfCharacteristicTypesRef.AdditionalAttributesAndInfo - an owner property.
//    * Value - Arbitrary - any value allowed for the property (specified in the property item).
//
Procedure WriteObjectProperties(PropertiesOwner, PropertyAndValueTable) Export
	
	AdditionalAttributeTable = New ValueTable;
	AdditionalAttributeTable.Columns.Add("Property", New TypeDescription("ChartOfCharacteristicTypesRef.AdditionalAttributesAndInfo"));
	AdditionalAttributeTable.Columns.Add("Value");
	
	AdditionalInfoTable = AdditionalAttributeTable.CopyColumns();
	
	For Each PropertyTableRow In PropertyAndValueTable Do
		If PropertyTableRow.Property.IsAdditionalInfo Then
			NewRow = AdditionalInfoTable.Add();
		Else
			NewRow = AdditionalAttributeTable.Add();
		EndIf;
		FillPropertyValues(NewRow, PropertyTableRow, "Property,Value");
	EndDo;
	
	HasAdditionalAttributes = AdditionalAttributeTable.Count() > 0;
	HasAdditionalInfo  = AdditionalInfoTable.Count() > 0;
	
	PropertiesArray = ObjectProperties(PropertiesOwner);
	
	AdditionalAttributesArray = New Array;
	AdditionalInfoArray = New Array;
	
	For Each AdditionalProperty In PropertiesArray Do
		If AdditionalProperty.IsAdditionalInfo Then
			AdditionalInfoArray.Add(AdditionalProperty);
		Else
			AdditionalAttributesArray.Add(AdditionalProperty);
		EndIf;
	EndDo;
	
	BeginTransaction();
	Try
		If HasAdditionalAttributes Then
			PropertiesOwnerObject = PropertiesOwner.GetObject();
			LockDataForEdit(PropertiesOwnerObject.Ref);
			For Each AdditionalAttribute In AdditionalAttributeTable Do
				If AdditionalAttributesArray.Find(AdditionalAttribute.Property) = Undefined Then
					Continue;
				EndIf;
				RowsArray = PropertiesOwnerObject.AdditionalAttributes.FindRows(New Structure("Property", AdditionalAttribute.Property));
				If RowsArray.Count() Then
					PropertyRow = RowsArray[0];
				Else
					PropertyRow = PropertiesOwnerObject.AdditionalAttributes.Add();
				EndIf;
				FillPropertyValues(PropertyRow, AdditionalAttribute, "Property,Value");
			EndDo;
			PropertiesOwnerObject.Write();
		EndIf;
		
		If HasAdditionalInfo Then
			For Each AdditionalInfoItem In AdditionalInfoTable Do
				If AdditionalInfoArray.Find(AdditionalInfoItem.Property) = Undefined Then
					Continue;
				EndIf;
				
				RecordManager = InformationRegisters.AdditionalInfo.CreateRecordManager();
				
				RecordManager.Object = PropertiesOwner;
				RecordManager.Property = AdditionalInfoItem.Property;
				RecordManager.Value = AdditionalInfoItem.Value;
				
				RecordManager.Write(True);
			EndDo;
			
		EndIf;
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Checks if additional attributes are used with the object.
//
// Parameters:
//  PropertiesOwner - Reference - for example, CatalogRef.Product, DocumentRef.SalesOrder, ...
//
// Returns:
//  Boolean - if True, additional attributes are used.
//
Function UseAddlAttributes(PropertiesOwner) Export
	
	OwnerMetadata = PropertiesOwner.Metadata();
	Return OwnerMetadata.TabularSections.Find("AdditionalAttributes") <> Undefined
	      AND OwnerMetadata <> Metadata.Catalogs.AdditionalAttributesAndInfoSets;
	
EndFunction

// Checks if the object uses additional info.
//
// Parameters:
//  PropertiesOwner - Reference - for example, CatalogRef.Product, DocumentRef.SalesOrder, ...
//
// Returns:
//  Boolean - if True, additional info is used.
//
Function UseAddlInfo(PropertiesOwner) Export
	
	Return Metadata.FindByFullName("CommonCommand.AdditionalInfoCommandBar") <> Undefined
		AND Metadata.CommonCommands.AdditionalInfoCommandBar.CommandParameterType.Types().Find(TypeOf(PropertiesOwner)) <> Undefined;
	
EndFunction

// Checks subsystem availability for the current user.
//
// Returns:
//  Boolean - True if subsystem is available.
//
Function PropertiesAvailable() Export
	Return AccessRight("Read", Metadata.Catalogs.AdditionalAttributesAndInfoSets);
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Updating an infobase.

// 1. Updates descriptions of predefined property sets if they differ from current presentations of 
// matching metadata objects with properties.
// 
// 2. Updates descriptions of not common properties if their adjustment is different from their set 
// description.
// 3. Sets deletion mark for not common properties if deletion mark is set for their sets.
// 
//
Procedure UpdatePropertyAndSetDescriptions() Export
	
	SetsQuery = New Query;
	SetsQuery.Text =
	"SELECT
	|	Sets.Ref AS Ref,
	|	Sets.Description AS Description
	|FROM
	|	Catalog.AdditionalAttributesAndInfoSets AS Sets
	|WHERE
	|	Sets.Predefined
	|	AND Sets.Parent = VALUE(Catalog.AdditionalAttributesAndInfoSets.EmptyRef)";
	
	SetsSelection = SetsQuery.Execute().Select();
	While SetsSelection.Next() Do
		
		Description = PropertyManagerInternal.PredefinedSetDescription(
			SetsSelection.Ref);
		
		If SetsSelection.Description <> Description Then
			Object = SetsSelection.Ref.GetObject();
			Object.Description = Description;
			InfobaseUpdate.WriteData(Object);
		EndIf;
	EndDo;
	
	PropertiesQuery = New Query;
	PropertiesQuery.Text =
	"SELECT
	|	Properties.Ref AS Ref,
	|	Properties.PropertySet.Description AS SetDescription,
	|	Properties.PropertySet.DeletionMark AS SetDeletionMark
	|FROM
	|	ChartOfCharacteristicTypes.AdditionalAttributesAndInfo AS Properties
	|WHERE
	|	CASE
	|			WHEN Properties.PropertySet = VALUE(Catalog.AdditionalAttributesAndInfoSets.EmptyRef)
	|				THEN FALSE
	|			ELSE CASE
	|					WHEN Properties.Description <> Properties.Title + "" ("" + Properties.PropertySet.Description + "")""
	|						THEN TRUE
	|					WHEN Properties.DeletionMark <> Properties.PropertySet.DeletionMark
	|						THEN TRUE
	|					ELSE FALSE
	|				END
	|		END";
	
	PropertiesSelection = PropertiesQuery.Execute().Select();
	While PropertiesSelection.Next() Do
		
		Object = PropertiesSelection.Ref.GetObject();
		Object.Description = Object.Title + " (" + String(PropertiesSelection.SetDescription) + ")";
		Object.DeletionMark = PropertiesSelection.SetDeletionMark;
		InfobaseUpdate.WriteData(Object);
	EndDo;
	
EndProcedure

// Sets property set parameters.
//
// Parameters:
//  PropertySetName - String - a name of predefined property set.
//  Parameters - Structure - see details of the PropertySetParametersStructure function.
//
Procedure SetPropertySetParameters(PropertySetName, Parameters = Undefined) Export
	
	If Parameters = Undefined Then
		Parameters = PropertySetParametersStructure();
	EndIf;
	
	WriteObject = False;
	PropertySet = Catalogs.AdditionalAttributesAndInfoSets[PropertySetName];
	PropertySetObject = PropertySet.GetObject();
	For Each Parameter In Parameters Do
		If PropertySetObject[Parameter.Key] = Parameter.Value Then
			Continue;
		EndIf;
		WriteObject = True;
	EndDo;
	
	If WriteObject Then
		FillPropertyValues(PropertySetObject, Parameters);
		InfobaseUpdate.WriteData(PropertySetObject);
	EndIf;
	
EndProcedure

// Gets parameter structure for a property set.
//
// Returns:
//  Structure - with the following properties:
//     * Used - Boolean - shows if the property set is used.
//                               It is set to False, for example, if the object is disabled by the 
//                               functional option.
//
Function PropertySetParametersStructure() Export
	
	Parameters = New Structure;
	Parameters.Insert("Used", True);
	Return Parameters;
	
EndFunction

#Region ObsoleteProceduresAndFunctions

// Obsolete. Use PropertiesValues or PropertyValues.
// Returns values of additional object properties.
//
// Parameters:
//  PropertiesOwner - Reference - for example, CatalogRef.Product, DocumentRef.SalesOrder, ...
//  GetAdditionalAttributes - Boolean - include additional attributes to the result.
//  GetAdditionalInfo - Boolean - include additional info to the result.
//  PropertyArray - Array - properties:
//                          * ChartOfCharacteristicTypesRef.AdditionalAttributesAndInfo - values to 
//                            be received.
//                       - Undefined - get values of all owner properties.
// Returns:
//  ValueTable - columns:
//    * Property - ChartOfCharacteristicTypesRef.AdditionalAttributesAndInfo - an owner property.
//    * Value - Arbitrary - values of any type from metadata object property type details:
//                  "Metadata.ChartOfCharacteristicTypes.AdditionalAttributesAndInfo.Type".
//
Function GetValuesProperties(PropertiesOwner,
                                GetAdditionalAttributes = True,
                                GetAdditionalInfo = True,
                                PropertiesArray = Undefined) Export
	
	Return PropertiesValues(PropertiesOwner, GetAdditionalAttributes, GetAdditionalInfo, PropertiesArray);
	
EndFunction

// Obsolete. Use ObjectProperties.
// Returns owner properties.
//
// Parameters:
//  PropertiesOwner - Reference - for example, CatalogRef.Product, DocumentRef.SalesOrder, ...
//  GetAdditionalAttributes - Boolean - include additional attributes to the result.
//  GetAdditionalInfo - Boolean - include additional info to the result.
//
// Returns:
//  Array - values
//    * ChartOfCharacteristicTypesRef.AdditionalAttributesAndInfo - if available.
//
Function GetPropertyList(PropertiesOwner, GetAdditionalAttributes = True, GetAdditionalInfo = True) Export
	Return ObjectProperties(PropertiesOwner, GetAdditionalAttributes, GetAdditionalInfo);
EndFunction

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
Function GetPropertiesValuesList(Property) Export
	
	Return PropertyManagerInternal.AdditionalPropertyValues(Property);
	
EndFunction

#EndRegion

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures and functions.

// Creates main attributes, commands, and items in the property owner form.
Procedure NewMainFormObjects(Form, Context, CreateAdditionalAttributesDetails)
	
	ItemForPlacementName   = Context.ItemForPlacementName;
	CommandBarItemName = Context.CommandBarItemName;
	DeferredInitialization    = Context.DeferredInitialization;
	
	Attributes = New Array;
	
	// Checking a value of the Property usage functional option.
	OptionUseProperties = Form.GetFormFunctionalOption("UseAdditionalAttributesAndInfo");
	AttributeUseProperties = New FormAttribute("Properties_UseProperties", New TypeDescription("Boolean"));
	Attributes.Add(AttributeUseProperties);
	AttributeHideDeleted = New FormAttribute("Properties_HideDeleted", New TypeDescription("Boolean"));
	Attributes.Add(AttributeHideDeleted);
	// Additional parameters of the property subsystem.
	AttributePropertiesParameters = New FormAttribute("PropertiesParameters", New TypeDescription());
	Attributes.Add(AttributePropertiesParameters);
	
	If OptionUseProperties Then
		
		AttributeUseAdditionalAttributes = New FormAttribute("Properties_UseAddlAttributes", New TypeDescription("Boolean"));
		Attributes.Add(AttributeUseAdditionalAttributes);
		
		If CreateAdditionalAttributesDetails Then
			
			// Adding an attribute containing used sets of additional attributes.
			Attributes.Add(New FormAttribute(
				"Properties_ObjectAdditionalAttributeSets", New TypeDescription("ValueList")));
			
			// Adding a details attribute for created attributes and form items.
			DetailsName = "Properties_AdditionalAttributeDetails";
			
			Attributes.Add(New FormAttribute(
				DetailsName, New TypeDescription("ValueTable")));
			
			Attributes.Add(New FormAttribute(
				"ValueAttributeName", New TypeDescription("String"), DetailsName));
			
			Attributes.Add(New FormAttribute(
				"Property", New TypeDescription("ChartOfCharacteristicTypesRef.AdditionalAttributesAndInfo"),
					DetailsName));
			
			Attributes.Add(New FormAttribute(
				"AdditionalValuesOwner", New TypeDescription("ChartOfCharacteristicTypesRef.AdditionalAttributesAndInfo"),
					DetailsName));
			
			Attributes.Add(New FormAttribute(
				"ValueType", New TypeDescription("TypeDescription"), DetailsName));
			
			Attributes.Add(New FormAttribute(
				"MultilineInputField", New TypeDescription("Number"), DetailsName));
			
			Attributes.Add(New FormAttribute(
				"Deleted", New TypeDescription("Boolean"), DetailsName));
			
			Attributes.Add(New FormAttribute(
				"RequiredToFill", New TypeDescription("Boolean"), DetailsName));
			
			Attributes.Add(New FormAttribute(
				"Available", New TypeDescription("Boolean"), DetailsName));
			
			Attributes.Add(New FormAttribute(
				"Visible", New TypeDescription("Boolean"), DetailsName));
			
			Attributes.Add(New FormAttribute(
				"Description", New TypeDescription("String"), DetailsName));
			
			Attributes.Add(New FormAttribute(
				"FormItemAdded", New TypeDescription("Boolean"), DetailsName));
			
			Attributes.Add(New FormAttribute(
				"OutputAsHyperlink", New TypeDescription("Boolean"), DetailsName));
			
			Attributes.Add(New FormAttribute(
				"RefTypeString", New TypeDescription("Boolean"), DetailsName));
			
			// Adding a details attribute for dependent attributes.
			DependentAttributesTable = "Properties_DependentAdditionalAttributesDescription";
			
			Attributes.Add(New FormAttribute(
				DependentAttributesTable, New TypeDescription("ValueTable")));
			
			Attributes.Add(New FormAttribute(
				"ValueAttributeName", New TypeDescription("String"), DependentAttributesTable));
			
			Attributes.Add(New FormAttribute(
				"Available", New TypeDescription("Boolean"), DependentAttributesTable));
			
			Attributes.Add(New FormAttribute(
				"AvailabilityCondition", New TypeDescription(), DependentAttributesTable));
			
			Attributes.Add(New FormAttribute(
				"Visible", New TypeDescription("Boolean"), DependentAttributesTable));
				
			Attributes.Add(New FormAttribute(
				"VisibilityCondition", New TypeDescription(), DependentAttributesTable));
			
			Attributes.Add(New FormAttribute(
				"RequiredToFill", New TypeDescription("Boolean"), DependentAttributesTable));
			
			Attributes.Add(New FormAttribute(
				"FillingRequiredCondition", New TypeDescription(), DependentAttributesTable));
			
			Attributes.Add(New FormAttribute(
				"OutputAsHyperlink", New TypeDescription("Boolean"), DependentAttributesTable));
			
			// Adding an attribute that contains items of created additional attribute groups.
			Attributes.Add(New FormAttribute(
				"Properties_AdditionalAttributeGroupItems", New TypeDescription("ValueList")));
			
			// Adding an attribute with name of the item in which input fields will be placed.
			Attributes.Add(New FormAttribute(
				"Properties_ItemNameForPlacement", New TypeDescription()));
			
			// Adding a form command if the AddEditAdditionalAttributesAndInfo role is set or if the user has 
			// full rights.
			If AccessRight("Update", Metadata.Catalogs.AdditionalAttributesAndInfoSets) Then
				// Adding a command.
				Command = Form.Commands.Add("EditAdditionalAttributesComposition");
				Command.Title = NStr("ru = 'Изменить состав дополнительных реквизитов'; en = 'Change set of additional attributes'; pl = 'Zmień zestaw atrybutów dodatkowych';es_ES = 'Cambiar el conjunto de atributos adicionales';es_CO = 'Cambiar el conjunto de atributos adicionales';tr = 'Ek öznitelik setini değiştir';it = 'Cambiare set di attributi aggiuntivi';de = 'Satz zusätzlicher Attribute ändern'");
				Command.Action = "Attachable_PropertiesExecuteCommand";
				Command.ToolTip = NStr("ru = 'Изменить состав дополнительных реквизитов'; en = 'Change set of additional attributes'; pl = 'Zmień zestaw atrybutów dodatkowych';es_ES = 'Cambiar el conjunto de atributos adicionales';es_CO = 'Cambiar el conjunto de atributos adicionales';tr = 'Ek öznitelik setini değiştir';it = 'Cambiare set di attributi aggiuntivi';de = 'Satz zusätzlicher Attribute ändern'");
				Command.Picture = PictureLib.ListSettings;
				
				Button = Form.Items.Add(
					"EditAdditionalAttributesComposition",
					Type("FormButton"),
					?(CommandBarItemName = "",
						Form.CommandBar,
						Form.Items[CommandBarItemName]));
				
				Button.OnlyInAllActions = True;
				Button.CommandName = "EditAdditionalAttributesComposition";
			EndIf;
			
			Command = Form.Commands.Add("EditAttributeHyperlink");
			Command.Title   = NStr("ru = 'Начать/закончить редактирование'; en = 'Start/end editing'; pl = 'Rozpocząć/zakończyć edycję';es_ES = 'Empezar/ terminar la edición';es_CO = 'Empezar/ terminar la edición';tr = 'Düzenlemeyi başla/bitir';it = 'Avvio/fine modifica';de = 'Bearbeitung starten/beenden'");
			Command.Action    = "Attachable_PropertiesExecuteCommand";
			Command.ToolTip   = NStr("ru = 'Начать/закончить редактирование'; en = 'Start/end editing'; pl = 'Rozpocząć/zakończyć edycję';es_ES = 'Empezar/ terminar la edición';es_CO = 'Empezar/ terminar la edición';tr = 'Düzenlemeyi başla/bitir';it = 'Avvio/fine modifica';de = 'Bearbeitung starten/beenden'");
			Command.Picture    = PictureLib.Change;
			Command.Representation = ButtonRepresentation.Picture;
		EndIf;
	EndIf;
	
	Form.ChangeAttributes(Attributes);
	
	Form.Properties_UseProperties = OptionUseProperties;
	
	Form.PropertiesParameters = New Structure;
	If DeferredInitialization Then
		// If properties are not used, the execution flag of deferred initialization is set to True.
		// 
		Value = ?(OptionUseProperties, False, True);
		Form.PropertiesParameters.Insert("DeferredInitializationExecuted", Value);
	EndIf;
	
	If OptionUseProperties Then
		Form.Properties_UseAddlAttributes = CreateAdditionalAttributesDetails;
	EndIf;
	
	If OptionUseProperties AND CreateAdditionalAttributesDetails Then
		Form.Properties_ItemNameForPlacement = ItemForPlacementName;
	EndIf;
	
	// If additional attributes are located on a separate page, deferred initialization and properties 
	// are enabled, an empty decoration is placed on the page.
	// Decoration is deleted automatically upon switching to a bookmark.
	// The capability of transferring additional attributes from the group is also blocked.
	If OptionUseProperties
		AND DeferredInitialization
		AND ItemForPlacementName <> "" Then
		Form.PropertiesParameters.Insert("DecorationCollections");
		Form.PropertiesParameters.DecorationCollections = New Array;
		
		Form.PropertiesParameters.Insert("EmptyDecorationAdded", True);
		If TypeOf(ItemForPlacementName ) = Type("ValueList") Then
			Index = 0;
			For Each PlacementGroup In ItemForPlacementName Do
				PrepareFormForDeferredInitialization(Form, Context, PlacementGroup.Presentation, Index);
				Index = Index + 1;
			EndDo;
		Else
			PrepareFormForDeferredInitialization(Form, Context, ItemForPlacementName, "");
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure PrepareFormForDeferredInitialization(Form, Context, ItemForPlacementName, Index)
	
	FormGroup = Form.Items[ItemForPlacementName];
	If FormGroup.Type <> FormGroupType.Page Then
		Parent = ParentPage(FormGroup);
	Else
		Parent = FormGroup;
	EndIf;
	
	If Parent <> Undefined
		AND Not Form.PropertiesParameters.Property(Parent.Name) Then
		DecorationName = "Properties_EmptyDecoration" + Index;
		Form.PropertiesParameters.DecorationCollections.Add(DecorationName);
		Decoration = Form.Items.Add(DecorationName, Type("FormDecoration"), FormGroup);
		
		PageGroup = Parent.Parent;
		PageHeader = ?(ValueIsFilled(Parent.Title), Parent.Title, Parent.Name);
		PageGroupHeader = ?(ValueIsFilled(PageGroup.Title), PageGroup.Title, PageGroup.Name);
		
		PlacementWarning = NStr("ru = 'Для отображения дополнительных реквизитов необходимо разместить группу ""%1"" не первым элементом (после любой другой группы) в группе ""%2"" (меню Еще - Изменить форму).'; en = 'To show additional attributes, place the ""%1"" group not as the first item (after any other group) in the ""%2"" group (menu More actions - Change form).'; pl = 'Aby wyświetlić więcej danych należy umieścić grupę ""%1"" nie pierwszym elementem (po każdej innej grupie) w grupie ""%2"" (Menu Więcej - Zmień formularz).';es_ES = 'Para visualizar los requisitos adicionales es necesario colocar en el grupo ""%1"" no como el primer elemento (después del cualquier otro grupo) en el grupo ""%2"" (menú Más - Cambiar el formulario).';es_CO = 'Para visualizar los requisitos adicionales es necesario colocar en el grupo ""%1"" no como el primer elemento (después del cualquier otro grupo) en el grupo ""%2"" (menú Más - Cambiar el formulario).';tr = 'Ek özellikleri görüntülemek için, ""%1""grubu ""%2"" grubunda (başka bir gruptan sonra) ilk öğe şeklinde yerleştirmemeniz gerekir (menü Daha fazla-Formu değiştirin).';it = 'Per mostrare i requisiti aggiuntivi, è necessario collocare il gruppo ""%1"" non come primo elemento (dopo qualsiasi altro gruppo) nel gruppo ""%2"" (menu Altro - Cambia modulo).';de = 'Um zusätzliche Atrtibute anzuzeigen, ist es notwendig, die Gruppe ""%1"" nicht das erste Element (nach einer anderen Gruppe) in der Gruppe ""%2"" (Menü Mehr - Formular ändern) zu platzieren.'");
		PlacementWarning = StringFunctionsClientServer.SubstituteParametersToString(PlacementWarning,
			PageHeader, PageGroupHeader);
		TooltipText = NStr("ru = 'Также можно установить стандартные настройки формы:
			|   • в меню Еще выбрать пункт Изменить форму...;
			|   • в открывшейся форме ""Настройка формы"" в меню Еще выбрать пункт ""Установить стандартные настройки"".'; 
			|en = 'You can also set default form settings:
			| • In the ""More actions"" menu, click ""Change form"".
			| • In the opened ""Customize form"" window, in the ""More actions"" menu, click ""Use standard settings"".'; 
			|pl = 'Można również ustawić domyślne ustawienia formularzu:
			| • w menu Więcej wybrać punkt Zmienić formularz...;
			| • w otwartym formularzu ""Ustawienia formularza"" w menu Więcej wybrać opcję ""Ustaw domyślne ustawienia"".';
			|es_ES = 'Además se puede instalar los ajustes estándares del formulario:
			|   • en el menú Más hay que seleccionar el punto Cambiar el formulario...;
			|   • en el formulario que se abrirá ""Ajustes del formulario"" en el menú Más hay que seleccionar el punto ""Establecer los ajustes estándares"".';
			|es_CO = 'Además se puede instalar los ajustes estándares del formulario:
			|   • en el menú Más hay que seleccionar el punto Cambiar el formulario...;
			|   • en el formulario que se abrirá ""Ajustes del formulario"" en el menú Más hay que seleccionar el punto ""Establecer los ajustes estándares"".';
			|tr = 'Ayrıca standart biçim ayarları belirlenebilir:
			|   • Daha fazla menüsünde Biçim değiştir alt menüyü seçin...;
			|   • açılan formda ""Biçim ayarları"" ""Daha fazla menüsünde ""Standart ayarları belirle"" alt menüyü seçin.';
			|it = 'Potete anche impostare impostazioni modulo predefinite:
			| • Nel menu ""Più azioni"", premi ""Modifica modulo"".
			| • nella finestra aperta ""Personalizza modulo"", nel menu ""Più azioni"", premi ""Utilizza impostazioni standard"".';
			|de = 'Sie können auch die Standardeinstellungen für das Formular festlegen:
			|  - im Menü Mehr, den Punkt ""Formular ändern"" wählen;
			|  - im geöffneten Formular ""Formulareinstellung"" im Menü Mehr, den Punkt ""Standardeinstellungen einstellen"" wählen.'");
			
		Decoration.ToolTipRepresentation = ToolTipRepresentation.Button;
		Decoration.Title  = PlacementWarning;
		Decoration.ToolTip  = TooltipText;
		Decoration.TextColor = StyleColors.ErrorNoteText;
		
		// Page containing additional attributes.
		Form.PropertiesParameters.Insert(Parent.Name);
	EndIf;
	
	FormGroup.EnableContentChange = False;
	
EndProcedure

Function ParentPage(FormGroup)
	
	Parent = FormGroup.Parent;
	If TypeOf(Parent) = Type("FormGroup") Then
		Parent.EnableContentChange = False;
		If Parent.Type = FormGroupType.Page Then
			Return Parent;
		Else
			ParentPage(Parent);
		EndIf;
	Else
		Return Undefined;
	EndIf;
	
EndFunction

Procedure SetDependenceCondition(DependenciesStructure, AttributePath, TableRow, ConditionCode, Condition)
	If DependenciesStructure = Undefined Then
		ParameterValues = New Map;
		If Condition = "Accus list"
			Or Condition = "Not in list" Then
			Value = New ValueList;
			Value.Add(TableRow.Value);
		Else
			Value = TableRow.Value;
		EndIf;
		ParameterValues.Insert(AttributePath, Value);
		DependenciesStructure = New Structure;
		DependenciesStructure.Insert("ConditionCode", ConditionCode);
		DependenciesStructure.Insert("ParameterValues", ParameterValues);
	ElsIf (Condition = "Accus list" Or Condition = "Not in list")
		AND TypeOf(DependenciesStructure.ParameterValues[AttributePath]) = Type("ValueList") Then
		DependenciesStructure.ParameterValues[AttributePath].Add(TableRow.Value);
	Else
		DependenciesStructure.ConditionCode = DependenciesStructure.ConditionCode + " AND " + ConditionCode;
		If Condition = "Accus list" Or Condition = "Not in list" Then
			Value = New ValueList;
			Value.Add(TableRow.Value);
		Else
			Value = TableRow.Value;
		EndIf;
		DependenciesStructure.ParameterValues.Insert(AttributePath, Value);
	EndIf;
EndProcedure

Procedure UpdateFormAssignmentKey(Form, AssignmentKey)
	
	If AssignmentKey = Undefined Then
		AssignmentKey = PropertySetsKey(Form.Properties_ObjectAdditionalAttributeSets);
	EndIf;
	
	If IsBlankString(AssignmentKey) Then
		Return;
	EndIf;
	
	KeyBeginning = "PropertySetsKey";
	PropertySetsKey = KeyBeginning + Left(AssignmentKey + "00000000000000000000000000000000", 32);
	
	NewKey = NewAssignmentKey(Form.PurposeUseKey, KeyBeginning, PropertySetsKey);
	If NewKey = Undefined Then
		// Key is already supplemented.
		NewKey = Form.PurposeUseKey;
	EndIf;
	
	NewLocationKey = NewAssignmentKey(Form.WindowOptionsKey, KeyBeginning, PropertySetsKey);
	If NewLocationKey = Undefined Then
		// Key is already supplemented.
		NewLocationKey = Form.WindowOptionsKey;
	EndIf;
	
	StandardSubsystemsServer.SetFormAssignmentKey(Form, NewKey, NewLocationKey);
	
EndProcedure

Function ConditionCalculationResult(Form, ObjectDetails, Parameters)
	ConditionParameters = New Structure;
	ConditionParameters.Insert("ParameterValues", Parameters.ParameterValues);
	ConditionParameters.Insert("Form", Form);
	ConditionParameters.Insert("ObjectDetails", ObjectDetails);
	
	Return Common.CalculateInSafeMode(Parameters.ConditionCode, ConditionParameters);
EndFunction

Function NewAssignmentKey(CurrentKey, KeyBeginning, PropertySetsKey)
	
	Position = StrFind(CurrentKey, KeyBeginning);
	
	NewAssignmentKey = Undefined;
	
	If Position = 0 Then
		NewAssignmentKey = CurrentKey + PropertySetsKey;
	
	ElsIf StrFind(CurrentKey, PropertySetsKey) = 0 Then
		NewAssignmentKey = Left(CurrentKey, Position - 1) + PropertySetsKey
			+ Mid(CurrentKey, Position + StrLen(KeyBeginning) + 32);
	EndIf;
	
	Return NewAssignmentKey;
	
EndFunction

Function PropertySetsKey(Sets)
	
	SetIDs = New ValueList;
	
	For each ListItem In Sets Do
		SetIDs.Add(String(ListItem.Value.UUID()));
	EndDo;
	
	SetIDs.SortByValue();
	IDString = "";
	
	For each ListItem In SetIDs Do
		IDString = IDString + StrReplace(ListItem.Value, "-", "");
	EndDo;
	
	Return Common.CheckSumString(IDString);
	
EndFunction



Function PropertiesUsed(Form, AdditionalParameters)
	
	If Not AccessRight("Read", Metadata.Catalogs.AdditionalAttributesAndInfoSets) Then
		DisableAdditionalAttributesOnForm(Form, AdditionalParameters);
		Return False;
	EndIf;
	
	If AdditionalParameters <> Undefined
		AND AdditionalParameters.Property("ArbitraryObject")
		AND AdditionalParameters.ArbitraryObject Then
		Return True;
	EndIf;
	
	If AdditionalParameters <> Undefined
		AND AdditionalParameters.Property("Object") Then
		ObjectDetails = AdditionalParameters.Object;
	Else
		ObjectDetails = Form.Object;
	EndIf;
	ObjectType = TypeOf(ObjectDetails.Ref);
	FullName = Metadata.FindByType(ObjectType).FullName();
	
	FormNameArray = StrSplit(FullName, ".");
	
	ItemName = FormNameArray[0] + "_" + FormNameArray[1];
	PropertySet = Catalogs.AdditionalAttributesAndInfoSets[ItemName];
	
	PropertiesUsed = Common.ObjectAttributeValue(PropertySet, "Used");
	
	If Not PropertiesUsed Then
		DisableAdditionalAttributesOnForm(Form, AdditionalParameters);
	EndIf;
	
	Return PropertiesUsed;
	
EndFunction

Procedure DisableAdditionalAttributesOnForm(Form, AdditionalParameters)
	
	AttributesArray = CommonClientServer.ValueInArray(
		New FormAttribute("Properties_UseProperties", New TypeDescription("Boolean")));
	PropertiesParametersAdded = False;
	
	If TypeOf(AdditionalParameters) = Type("Structure") Then
		If AdditionalParameters.Property("ItemForPlacementName") Then
			If TypeOf(AdditionalParameters.ItemForPlacementName) = Type("ValueList") Then
				For Each ListItem In AdditionalParameters.ItemForPlacementName Do
					Form.Items[ListItem.Presentation].Visible = False;
				EndDo;
			Else
				Form.Items[AdditionalParameters.ItemForPlacementName].Visible = False;
			EndIf;
		EndIf;
		
		If AdditionalParameters.Property("DeferredInitialization") Then
			AttributePropertiesParameters = New FormAttribute("PropertiesParameters", New TypeDescription());
			AttributesArray.Add(AttributePropertiesParameters);
			PropertiesParametersAdded = True;
		EndIf;
	EndIf;
	
	Form.ChangeAttributes(AttributesArray);
	Form.Properties_UseProperties = False;
	If PropertiesParametersAdded Then
		Form.PropertiesParameters = New Structure;
		Form.PropertiesParameters.Insert("DeferredInitializationExecuted", True);
	EndIf;
	
EndProcedure

#EndRegion
