
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not Parameters.Property("SchemaURL", SchemaURL) OR Not IsTempStorageURL(SchemaURL) Then
		Cancel = True;
		Return;
	EndIf;
	
	CurrentFilters = Undefined;
	Parameters.Property("Filters", CurrentFilters);
	
	If Not TypeOf(CurrentFilters) = Type("FixedArray") Then
		Filters = New FixedArray(New Array);
	Else
		Filters = CurrentFilters;
	EndIf; 
	
	SettingsSource = New DataCompositionAvailableSettingsSource(SchemaURL);
	Composer.Initialize(SettingsSource);

	DataCompositionSchema = GetFromTempStorage(SchemaURL);
	Composer.LoadSettings(DataCompositionSchema.DefaultSettings);
	SettingsAddress = PutToTempStorage(DataCompositionSchema.DefaultSettings, UUID);
	
	Items.Field.ChoiceList.Clear();
	
	For Each FilterItem In Composer.Settings.Filter.Items Do
		
		If Not TypeOf(FilterItem) = Type("DataCompositionFilterItem") 
			OR Not TypeOf(FilterItem.LeftValue) = Type("DataCompositionField") Then
				Continue;
		EndIf;
		
		If Not IsBlankString(FilterItem.Presentation) Then
			Presentation = FilterItem.Presentation;
		Else
			AvailableField	= Composer.Settings.FilterAvailableFields.FindField(FilterItem.LeftValue);
			Presentation	= AvailableField.Title;
		EndIf; 
		
		Items.Field.ChoiceList.Add(String(FilterItem.LeftValue), Presentation);
		
	EndDo; 
	
	Items.Field.ChoiceList.Add("...", NStr("en = 'Other fields'; ru = 'Прочие поля';pl = 'Inne pola';es_ES = 'Otros campos';es_CO = 'Otros campos';tr = 'Diğer alanlar';it = 'Altri campi';de = 'Andere Felder'"),, PictureLib.Select);
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If SelectedValue = Undefined Then
		Return;
	EndIf;
	
	AvailableField = Composer.Settings.FilterAvailableFields.FindField(New DataCompositionField(SelectedValue));
	Items.Field.ChoiceList.Insert(Items.Field.ChoiceList.Count() - 1, SelectedValue, AvailableField.Title); 
	
	Field = SelectedValue;
	FieldOnChange(Items.Field);
	
EndProcedure

#EndRegion 

#Region FormsItemEventHandlers

&AtClient
Procedure FieldChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	If SelectedValue = "..." Then
		
		StandardProcessing = False;
		
		OpeningStructure = New Structure;
		OpeningStructure.Insert("Mode", "FilterFields");
		OpeningStructure.Insert("SchemaURL", SchemaURL);
		OpeningStructure.Insert("SettingsAddress", SettingsAddress);
		
		OpenForm("CommonForm.FieldListForm", OpeningStructure, ThisForm);
		
	EndIf; 
	
EndProcedure

&AtClient
Procedure FieldOnChange(Item)
	
	FieldWhenChangingServer();
	
EndProcedure

&AtServer
Procedure FieldWhenChangingServer()
	
	Items.ComparisonType.ChoiceList.Clear();
	If IsBlankString(Field) Then
		Return;
	EndIf;
	
	AvailableField = Composer.Settings.FilterAvailableFields.FindField(New DataCompositionField(Field));
	TypeDescription = AvailableField.ValueType;
	UnavailableComparisonKinds = DetermineUnavailableComparisonKinds(Field, TypeDescription);
	
	For Each Type In TypeDescription.Types() Do
		
		If Type = Type("Number") Then
			
			// Numbers
			AddComparisonKind("Greater", NStr("en = 'Greater'; ru = 'Больше';pl = 'Większy';es_ES = 'Mayor';es_CO = 'Mayor';tr = 'Daha fazla';it = 'Maggiore';de = 'Größer'"), UnavailableComparisonKinds);
			AddComparisonKind("GreaterOrEqual", NStr("en = 'Greater or equal'; ru = 'Больше или равно';pl = 'Większy lub równy';es_ES = 'Mayor o igual';es_CO = 'Mayor o igual';tr = 'Fazla veya eşit';it = 'Maggiore o uguale';de = 'Größer oder gleich'"), UnavailableComparisonKinds);
			AddComparisonKind("Less", NStr("en = 'Less'; ru = 'Меньше';pl = 'Mniejszy';es_ES = 'Menor';es_CO = 'Menor';tr = 'Daha az';it = 'Meno';de = 'Weniger'"), UnavailableComparisonKinds);
			AddComparisonKind("LessOrEqual", NStr("en = 'Less or equal'; ru = 'Меньше или равно';pl = 'Mniejszy lub równy';es_ES = 'Menor o igual';es_CO = 'Menor o igual';tr = 'Daha az veya eşit';it = 'Meno o uguale';de = 'Weniger oder gleich'"), UnavailableComparisonKinds);
			
		ElsIf Type = Type("Date") Then
			
			// Dates
			AddComparisonKind("Greater", NStr("en = 'Greater'; ru = 'Больше';pl = 'Większy';es_ES = 'Mayor';es_CO = 'Mayor';tr = 'Daha fazla';it = 'Maggiore';de = 'Größer'"), UnavailableComparisonKinds);
			AddComparisonKind("GreaterOrEqual", NStr("en = 'Greater or equal'; ru = 'Больше или равно';pl = 'Większy lub równy';es_ES = 'Mayor o igual';es_CO = 'Mayor o igual';tr = 'Fazla veya eşit';it = 'Maggiore o uguale';de = 'Größer oder gleich'"), UnavailableComparisonKinds);
			AddComparisonKind("Less", NStr("en = 'Less'; ru = 'Меньше';pl = 'Mniejszy';es_ES = 'Menor';es_CO = 'Menor';tr = 'Daha az';it = 'Meno';de = 'Weniger'"), UnavailableComparisonKinds);
			AddComparisonKind("LessOrEqual", NStr("en = 'Less or equal'; ru = 'Меньше или равно';pl = 'Mniejszy lub równy';es_ES = 'Menor o igual';es_CO = 'Menor o igual';tr = 'Daha az veya eşit';it = 'Meno o uguale';de = 'Weniger oder gleich'"), UnavailableComparisonKinds);
			
		ElsIf Type = Type("String") Then
			
			// Rows
			AddComparisonKind("Contains", NStr("en = 'Contains'; ru = 'Содержит';pl = 'Zawiera';es_ES = 'Contiene';es_CO = 'Contiene';tr = 'İçerir';it = 'Contiene';de = 'Enthält'"), UnavailableComparisonKinds);
			AddComparisonKind("NotContains", NStr("en = 'Does not contain'; ru = 'Не содержит';pl = 'Nie zawiera';es_ES = 'No contiene';es_CO = 'No contiene';tr = 'İçermez';it = 'Non contiene';de = 'Enthält nicht'"), UnavailableComparisonKinds);
			AddComparisonKind("BeginsWith", NStr("en = 'Starts with'; ru = 'Начинается с';pl = 'Zaczyna się od';es_ES = 'Empieza con';es_CO = 'Empieza con';tr = 'İle başlar';it = 'Comincia con';de = 'Beginnt mit'"), UnavailableComparisonKinds);
			AddComparisonKind("NotBeginsWith", NStr("en = 'Does not start with'; ru = 'Не начинается с';pl = 'Nie zaczyna się od';es_ES = 'No empieza con';es_CO = 'No empieza con';tr = 'İle başlamaz';it = 'Non comincia con';de = 'Beginnt nicht mit'"), UnavailableComparisonKinds);
			AddComparisonKind("Like", NStr("en = 'Like'; ru = 'Подобно';pl = 'Podobne';es_ES = 'Me gusta';es_CO = 'Me gusta';tr = 'Gibi';it = 'Come';de = 'Wie'"), UnavailableComparisonKinds);
			AddComparisonKind("NotLike", NStr("en = 'Not the same'; ru = 'Не подобно';pl = 'Nie ten sam';es_ES = 'No el mismo';es_CO = 'No el mismo';tr = 'Eşit değil';it = 'Non similare';de = 'Nicht das gleiche'"), UnavailableComparisonKinds);
			
		ElsIf Type = Type("Boolean") Then
			
			AddComparisonKind("Equal", NStr("en = 'Equal'; ru = 'Равно';pl = 'Równy';es_ES = 'Igual';es_CO = 'Igual';tr = 'Eşit';it = 'uguale';de = 'Gleich'"), UnavailableComparisonKinds);
			AddComparisonKind("NotEqual",NStr("en = 'Not equal'; ru = 'Не равно';pl = 'Nie równy';es_ES = 'Desigual';es_CO = 'Desigual';tr = 'Eşit değil';it = 'Non uguale';de = 'Nicht gleich'"), UnavailableComparisonKinds);
			
		ElsIf Common.IsReference(Type) Then
			
			EmptyRef		= New(Type);
			ValuesCount		= DriveReports.DetermineItemQuantity(Type);
			ObjectMetadata	= EmptyRef.Metadata();
			
			If (Common.IsCatalog(ObjectMetadata) 
					OR Common.IsChartOfCharacteristicTypes(ObjectMetadata)) 
				AND ObjectMetadata.Hierarchical Then
					AddComparisonKind("InListByHierarchy", NStr("en = 'In groups'; ru = 'В группах';pl = 'W grupach';es_ES = 'En grupos';es_CO = 'En grupos';tr = 'Gruplarda';it = 'Nei gruppi';de = 'In Gruppen'"), UnavailableComparisonKinds);
					AddComparisonKind("NotInListByHierarchy", NStr("en = 'Not in groups'; ru = 'Не в группах';pl = 'Nie w grupach';es_ES = 'No en grupos';es_CO = 'No en grupos';tr = 'Gruplarda değil';it = 'Non nei gruppi';de = 'Nicht in Gruppen'"), UnavailableComparisonKinds);
			EndIf;
			
			If ValuesCount > 2 Then
				AddComparisonKind("InList", NStr("en = 'In the list'; ru = 'В списке';pl = 'Na liście';es_ES = 'En la lista';es_CO = 'En la lista';tr = 'Listede';it = 'Nell''elenco';de = 'In der Liste'"), UnavailableComparisonKinds);
				AddComparisonKind("NotInList", NStr("en = 'Not in the list'; ru = 'Не в списке';pl = 'Nie na liście';es_ES = 'No en la lista';es_CO = 'No en la lista';tr = 'Listede değil';it = 'Non in elenco';de = 'Nicht in der Liste'"), UnavailableComparisonKinds);
			EndIf; 
			
			AddComparisonKind("Equal", NStr("en = 'Equal'; ru = 'Равно';pl = 'Równy';es_ES = 'Igual';es_CO = 'Igual';tr = 'Eşit';it = 'uguale';de = 'Gleich'"), UnavailableComparisonKinds);
			AddComparisonKind("NotEqual",NStr("en = 'Not equal'; ru = 'Не равно';pl = 'Nie równy';es_ES = 'Desigual';es_CO = 'Desigual';tr = 'Eşit değil';it = 'Non uguale';de = 'Nicht gleich'"), UnavailableComparisonKinds);
		EndIf;	
	EndDo;
	
	If Common.TypeDetailsContainsType(TypeDescription, Type("Number")) Then
		Items.Value.AutoMarkIncomplete = False;
	Else
		Items.Value.AutoMarkIncomplete = True;
	EndIf; 
	
	ComparisonType = "";
	
	For Each FilterDescription In Filters Do
		
		If Not FilterDescription.Field = Field Then
			Continue;
		EndIf;
		
		ComparisonKindName = GetPredefinedValueFullName(FilterDescription.ComparisonType);
		ComparisonKindName = Mid(ComparisonKindName, Find(ComparisonKindName, ".") + 1);
		
		If Not Items.ComparisonType.ChoiceList.FindByValue(ComparisonKindName) = Undefined Then
			ComparisonType = ComparisonKindName;
			Break;
		EndIf; 	
	EndDo; 
	
	If IsBlankString(ComparisonType) AND Items.ComparisonType.ChoiceList.Count() > 0 Then
		ComparisonType = Items.ComparisonType.ChoiceList[0].Value;
	EndIf;
	
	ComparisonKindWhenChangingServer();
	
EndProcedure

&AtServer
Function DetermineUnavailableComparisonKinds(Field, Type)
	
	Result = New Array;
	
	For Each FilterDescription In Filters Do
		
		If Not FilterDescription.Field=  Field Then
			Continue;
		EndIf;
		
		If FilterDescription.ComparisonType = DataCompositionComparisonType.Equal Then			
			
			Result.Add("NotEqual");
			Result.Add("NotInList");
			Result.Add("InListByHierarchy");
			Result.Add("NotInListByHierarchy");
			Result.Add("Greater");
			Result.Add("GreaterOrEqual");
			Result.Add("Less");
			Result.Add("LessOrEqual");
			Result.Add("Contains");
			Result.Add("NotContains");
			Result.Add("BeginsWith");
			Result.Add("NotBeginsWith");
			Result.Add("Like");
			Result.Add("NotLike");	
			
		ElsIf FilterDescription.ComparisonType = DataCompositionComparisonType.NotEqual Then
			Result.Add("Equal");
		ElsIf FilterDescription.ComparisonType = DataCompositionComparisonType.InList Then

		ElsIf FilterDescription.ComparisonType = DataCompositionComparisonType.NotInList Then
			Result.Add("Equal");
		ElsIf FilterDescription.ComparisonType = DataCompositionComparisonType.InListByHierarchy Then
			Result.Add("Equal");
		ElsIf FilterDescription.ComparisonType = DataCompositionComparisonType.NotInListByHierarchy Then
			Result.Add("Equal");
		ElsIf FilterDescription.ComparisonType = DataCompositionComparisonType.Greater 
			OR FilterDescription.ComparisonType = DataCompositionComparisonType.GreaterOrEqual Then
				Result.Add("Greater");
				Result.Add("GreaterOrEqual");
		ElsIf FilterDescription.ComparisonType = DataCompositionComparisonType.Less 
			OR FilterDescription.ComparisonType = DataCompositionComparisonType.LessOrEqual Then
				Result.Add("Less");
				Result.Add("LessOrEqual");
		ElsIf FilterDescription.ComparisonType = DataCompositionComparisonType.Contains
			OR FilterDescription.ComparisonType = DataCompositionComparisonType.NotContains
			OR FilterDescription.ComparisonType = DataCompositionComparisonType.BeginsWith
			OR FilterDescription.ComparisonType = DataCompositionComparisonType.NotBeginsWith
			OR FilterDescription.ComparisonType = DataCompositionComparisonType.Like
			OR FilterDescription.ComparisonType = DataCompositionComparisonType.NotLike Then
				Result.Add("Equal");
		EndIf; 
	EndDo;
	
	Return Result;
	
EndFunction

&AtServer
Procedure AddComparisonKind(ComparisonType, Presentation, UnavailableComparisonKinds)
	
	If Not UnavailableComparisonKinds.Find(ComparisonType) = Undefined Then
		Return;
	EndIf;
	
	If Not Items.ComparisonType.ChoiceList.FindByValue(ComparisonType) = Undefined Then
		Return;
	EndIf; 
	
	Items.ComparisonType.ChoiceList.Add(ComparisonType, Presentation);
	
EndProcedure

&AtClient
Procedure ComparisonKindWhenChanging(Item)
	
	ComparisonKindWhenChangingServer();
	
EndProcedure

&AtServer
Procedure ComparisonKindWhenChangingServer()
	
	If Not ValueIsFilled(ComparisonType) Then
		Value = Undefined;
		Return;
	EndIf;
	
	NewComparisonKind = DataCompositionComparisonType[ComparisonType];
	UpdateValueType();
	
EndProcedure

#EndRegion 

#Region FormCommandHandlers

&AtClient
Procedure AddFilter(Command)
	
	If IsBlankString(Field) OR IsBlankString(ComparisonType) OR (Not ValueIsFilled(Value) AND Items.Value.AutoMarkIncomplete=True) Then
		Return;
	EndIf; 
	
	ReturnStructure = New Structure;
	ReturnStructure.Insert("Event", "AddFilter");
	ReturnStructure.Insert("Field", Field);
	ReturnStructure.Insert("ComparisonType", DataCompositionComparisonType[ComparisonType]);
	ReturnStructure.Insert("Value", Value);
	NotifyChoice(ReturnStructure);
	
EndProcedure

#EndRegion 

#Region InternalProceduresAndFunctions

&AtServer
Procedure UpdateValueType()
	
	AvailableField	= Composer.Settings.FilterAvailableFields.FindField(New DataCompositionField(Field));
	Type			= AvailableField.ValueType;
	IsReference		= False;
	
	For Each AvailableType In Type.Types() Do
		If Common.IsReference(AvailableType) Then
			IsReference = True;
			Break;
		EndIf; 
	EndDo; 
	
	If IsReference 
		AND (ComparisonType = "InHierarchy" 
			OR ComparisonType = "NotInHierarchy" 
			OR ComparisonType = "InListByHierarchy" 
			OR ComparisonType = "NotInListByHierarchy") Then
			
		Items.Value.ChoiceFoldersAndItems = FoldersAndItems.Folders;
		
	Else
		Items.Value.ChoiceFoldersAndItems = FoldersAndItems.Auto;
	EndIf; 
	
	OldValue = Value;
	If IsReference 
		AND Not ComparisonType = "Equal" 
		AND Not ComparisonType = "NotEqual" Then
		
		Items.Value.TypeRestriction = New TypeDescription("ValueList");
		Value						= New ValueList;
		Value.ValueType				= Type;
		
		If TypeOf(OldValue) = Type("ValueList") Then
			For Each OldItem In OldValue Do
				ElementValue = Type.AdjustValue(OldItem.Value);
				
				If ValueIsFilled(ElementValue) Then
					Value.Add(ElementValue);
				EndIf; 
			EndDo; 
		EndIf; 
		
		For Each AvailableType In Type.Types() Do
			If ValueIsFilled(OldValue) AND TypeOf(OldValue) = AvailableType Then
				Value.Add(OldValue);
			EndIf; 
		EndDo;
		
	Else
		Items.Value.TypeRestriction = Type;		
		Value = Type.AdjustValue(Value);
		
		If TypeOf(OldValue) = Type("ValueList") AND OldValue.Count() > 0 Then
			FirstItem = OldValue[0].Value;
			
			For Each AvailableType In Type.Types() Do
				If TypeOf(FirstItem) = AvailableType Then
					Value = FirstItem;
				EndIf; 
			EndDo; 
		EndIf; 
		
	EndIf;
	
	// Special cases
	
	If Field = "BankAccountPettyCash" Then
		
		// Bank accounts with filter by company
		Query = New Query;
		Query.Text =
		"SELECT ALLOWED
		|	Companies.Ref
		|FROM
		|	Catalog.Companies AS Companies";
		CompanyArray = Query.Execute().Unload().UnloadColumn("Ref");
		
		ChoiceParameter = New ChoiceParameter("Filter.Owner", New FixedArray(CompanyArray));
		
		ParameterArray = New Array;
		ParameterArray.Add(ChoiceParameter);
		Items.Value.ChoiceParameters = New FixedArray(ParameterArray);
		
	ElsIf Find(Field, "[") > 0 Then
		// This is an add. attribute
		Position	= Find(Field, "[");
		EndPosition	= Find(Field, "]");
		Description	= Mid(Field, Position + 1, EndPosition - Position - 1);
		
		Query = New Query;
		Query.SetParameter("Description", Description);
		Query.Text =
		"SELECT ALLOWED
		|	AdditionalAttributesAndInformation.Ref AS Ref
		|FROM
		|	ChartOfCharacteristicTypes.AdditionalAttributesAndInfo AS AdditionalAttributesAndInformation
		|WHERE
		|	AdditionalAttributesAndInformation.Description = &Description
		|	AND AdditionalAttributesAndInformation.AdditionalValuesOwner = VALUE(ChartOfCharacteristicTypes.AdditionalAttributesAndInfo.EmptyRef)
		|
		|UNION ALL
		|
		|SELECT
		|	AdditionalAttributesAndInformation.AdditionalValuesOwner
		|FROM
		|	ChartOfCharacteristicTypes.AdditionalAttributesAndInfo AS AdditionalAttributesAndInformation
		|WHERE
		|	AdditionalAttributesAndInformation.Description = &Description
		|	AND AdditionalAttributesAndInformation.AdditionalValuesOwner <> VALUE(ChartOfCharacteristicTypes.AdditionalAttributesAndInfo.EmptyRef)";
		PropertyArray = Query.Execute().Unload().UnloadColumn("Ref");
		
		If PropertyArray.Count() > 0 Then
			ChoiceParameter = New ChoiceParameter("Filter.Owner", PropertyArray[0]);
			
			ParameterArray = New Array;
			ParameterArray.Add(ChoiceParameter);
			
			Items.Value.ChoiceParameters = New FixedArray(ParameterArray);
		Else
			Items.Value.ChoiceParameters = New FixedArray(New Array);
		EndIf;
		
	Else
		Items.Value.ChoiceParameters = New FixedArray(New Array);
	EndIf;
	
EndProcedure

#EndRegion

