
#Region Public

// Conditional appearance

Function CreateFilterItemGroup(ItemCollection, GroupType) Export
	
	FilterItemsGroup = ItemCollection.Items.Add(Type("DataCompositionFilterItemGroup"));
	
	If TypeOf(GroupType) = Type("String") Then
		FilterItemsGroup.GroupType = DataCompositionFilterItemsGroupType[GroupType];
	Else
		FilterItemsGroup.GroupType = GroupType;
	EndIf;
	
	Return FilterItemsGroup;
	
EndFunction

Procedure AddFilterItem(FilterItemsGroup, DataPath, Value, ComparisonType = Undefined) Export
	
	If ComparisonType = Undefined Then
		ComparisonType = DataCompositionComparisonType.Equal;
	ElsIf TypeOf(ComparisonType) = Type("String") Then
		ComparisonType = DataCompositionComparisonType[ComparisonType];
	EndIf;
	
	Filter = FilterItemsGroup.Items.Add(Type("DataCompositionFilterItem"));
	Filter.ComparisonType	= ComparisonType;
	Filter.Use				= True;
	Filter.LeftValue		= New DataCompositionField(DataPath);
	Filter.RightValue		= Value;
	
EndProcedure

Procedure AddDataCompositionAppearanceField(ConditionalAppearance, DataPath) Export
	
	ConditionalAppearanceFieldItem			= ConditionalAppearance.Fields.Items.Add();
	ConditionalAppearanceFieldItem.Field	= New DataCompositionField(DataPath);
	ConditionalAppearanceFieldItem.Use		= True;
	
EndProcedure

Procedure AddAppearanceField(ConditionalAppearance, DataCompositionAppearanceFields) Export
	
	If TypeOf(DataCompositionAppearanceFields) = Type("Array") Then
		FieldsArray = DataCompositionAppearanceFields;
	ElsIf TypeOf(DataCompositionAppearanceFields) = Type("String") Then
		FieldsArray = StringFunctionsClientServer.SplitStringIntoSubstringsArray(StrReplace(DataCompositionAppearanceFields, Chars.LF, ""),,, True);
	Else
		Return;
	EndIf;
	
	For Each FieldName In FieldsArray Do
		AddDataCompositionAppearanceField(ConditionalAppearance, FieldName)
	EndDo;
	
EndProcedure

Procedure AddConditionalAppearanceItem(ConditionalAppearanceItem, ID, Value) Export
	
	Appearance			= ConditionalAppearanceItem.Appearance.Items.Find(ID);
	Appearance.Value	= Value;
	Appearance.Use		= True;
	
EndProcedure

Procedure SetChoiceParametersByCompany(Company, Form, FieldName) Export

	CompanysArray = New Array;
	CompanysArray.Add(Catalogs.Companies.EmptyRef());
	CompanysArray.Add(Company);
	
	FixedCompanysArray = New FixedArray(CompanysArray);
	
	Parameter = New ChoiceParameter("Filter.Company", FixedCompanysArray);
	
	ParamArr = New Array;
	ParamArr.Add(Parameter);
	
	FixedParamArr = New FixedArray(ParamArr);
	
	Form.Items[FieldName].ChoiceParameters = FixedParamArr;

EndProcedure

// Sets ReadOnly for item, but opening button stays enabled
Procedure SetReadOnlyForTableColumn(Item, ReadOnly = True) Export
	
	Item.SetAction("StartChoice", "Attachable_ReadOnlyFieldStartChoice");
	
	If ReadOnly Then
		
		Item.OpenButton = True;
		Item.ChoiceButton = False;
		Item.DropListButton = False;
		Item.CreateButton = False;
		Item.TextEdit = False;
		Item.QuickChoice = False;
		Item.ChoiceHistoryOnInput = ChoiceHistoryOnInput.DontUse;
		
	Else
		
		Item.OpenButton = Undefined;
		Item.ChoiceButton = Undefined;
		Item.DropListButton = Undefined;
		Item.CreateButton = Undefined;
		Item.TextEdit = True;
		Item.QuickChoice = Undefined;
		Item.ChoiceHistoryOnInput = ChoiceHistoryOnInput.Auto;
		
	EndIf;
	
EndProcedure

#EndRegion
