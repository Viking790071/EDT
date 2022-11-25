#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	SetDataAppearance();
	
	If Parameters.ImportType = "TabularSection" AND ValueIsFilled(Parameters.FullTabularSectionName) Then 
		ConflictsList = New Array;
		
		ObjectArray = StringFunctionsClientServer.SplitStringIntoWordArray(Parameters.FullTabularSectionName);
		If ObjectArray[0] = "Document" Then
			ObjectManager = Documents[ObjectArray[1]];
		ElsIf ObjectArray[0] = "Catalog" Then
			ObjectManager = Catalogs[ObjectArray[1]];
		Else
			Cancel = True;
			Return;
		EndIf;
		
		ObjectManager.FillInConflictList(Parameters.FullTabularSectionName, ConflictsList, Parameters.Name, Parameters.ValuesOfColumnsToImport, Parameters.AdditionalParameters);
		
		Items.ConflictResolutionOption.Visible = False;
		Items.TitleDecoration.Title = StringFunctionsClientServer.SubstituteParametersToString(Items.TitleDecoration.Title, Parameters.Name);
		Items.TitleDecoration.Visible = True;
		Items.ImportFromFileDecoration.Visible = False;
		Items.CatalogItems.CommandBar.ChildItems.CatalogItemsNewItem.Visible = False;
		For each Column In Parameters.ValuesOfColumnsToImport Do 
			MappingColumns.Add(Column.Key);
		EndDo;
		Items.TitleRefSearchDecoration.Visible = False;
		
	ElsIf Parameters.ImportType = "PastingFromClipboard" Then
		Items.DataFromFileGroup.Visible = False;
		Items.TitleDecoration.Visible = False;
		Items.ImportFromFileDecoration.Visible = False;
		Items.TitleRefSearchDecoration.Visible = True;
		ConflictsList = Parameters.ConflictsList.UnloadValues();
		MappingColumns = Parameters.MappingColumns;
	Else
		ConflictsList = Parameters.ConflictsList.UnloadValues();
		MappingColumns = Parameters.MappingColumns;
		Items.TitleDecoration.Visible = False;
		Items.ImportFromFileDecoration.Visible = True;
		Items.TitleRefSearchDecoration.Visible = False;
	EndIf;
	Index = 0;
	
	If ConflictsList.Count() = 0 Then
		Cancel = True;
		Return;
	EndIf;
	
	TemporarySpecification = FormAttributeToValue("CatalogItems");
	TemporarySpecification.Columns.Clear();
	AttributesArray = New Array;

	FirstItem = ConflictsList.Get(0);
	MetadataObject = FirstItem.Metadata();
	
	For each Attribute In FirstItem.Metadata().Attributes Do
		If Attribute.Type.Types().Find(Type("ValueStorage")) = Undefined Then
			TemporarySpecification.Columns.Add(Attribute.Name, Attribute.Type, Attribute.Presentation());
			AttributesArray.Add(New FormAttribute(Attribute.Name, Attribute.Type, "CatalogItems", Attribute.Presentation()));
		EndIf;
	EndDo;
	
	For each Attribute In MetadataObject.StandardAttributes Do
		TemporarySpecification.Columns.Add(Attribute.Name, Attribute.Type, Attribute.Presentation());
		AttributesArray.Add(New FormAttribute(Attribute.Name, Attribute.Type, "CatalogItems", Attribute.Presentation()));
	EndDo;
	
	For each Item In Parameters.TableRow Do
		AttributesArray.Add(New FormAttribute("IND_" + Item[Index], New TypeDescription("String"),, Item[1]));
	EndDo;
	
	ChangeAttributes(AttributesArray);
	
	Items.CatalogItems.Height = ConflictsList.Count() + 3;
	
	For each Item In ConflictsList Do
		Row = SelectionOptions.GetItems().Add();
		Row.Presentation = String(Item);
		Row.Ref = Item.Ref;
		MetadataObject = Item.Metadata();
		
		For each Attribute In MetadataObject.StandardAttributes Do
			If Attribute.Name = "Code" OR Attribute.Name = "Description" Then
				Substring = Row.GetItems().Add();
				Substring.Presentation = Attribute.Presentation() + ":";
				Substring.Value = Item[Attribute.Name];
				Substring.Ref = Item.Ref;
			EndIf;
		EndDo;
		
		For each Attribute In MetadataObject.Attributes Do
			Substring = Row.GetItems().Add();
			Substring.Presentation = Attribute.Presentation() + ":";
			Substring.Value = Item[Attribute.Name];
			Substring.Ref = Item.Ref;
		EndDo;
	
	EndDo;
	
	For each Item In ConflictsList Do
		Row = CatalogItems.Add();
		Row.Presentation = String(Item);
		For Each Column In TemporarySpecification.Columns Do
			Types = New Array;
			Types.Add(TypeOf(Row[Column.Name]));
			TypeDetails = New TypeDescription(Types);
			Row[Column.Name] = TypeDetails.AdjustValue(Item[Column.Name]);
		EndDo;
	EndDo;
	
	For Each Column In TemporarySpecification.Columns Do
		NewItem = Items.Add(Column.Name, Type("FormField"), Items.CatalogItems);
		NewItem.Type = FormFieldType.InputField;
		NewItem.DataPath = "CatalogItems." + Column.Name;
		NewItem.Title = Column.Title;
	EndDo;
	
	If Parameters.ImportType = "PastingFromClipboard" Then
		Separator = "";
		RowWithValues = "";
		For each Item In Parameters.TableRow Do
			RowWithValues = RowWithValues + Separator + Item[2];
			Separator = ", ";
		EndDo;
		If StrLen(RowWithValues) > 70 Then
			RowWithValues = Left(RowWithValues, 70) + "...";
		EndIf;
		Items.TitleRefSearchDecoration.Title = StringFunctionsClientServer.SubstituteParametersToString(Items.TitleRefSearchDecoration.Title,
				RowWithValues);
	Else
		ConvertedItemsCount = 0;
		For each Item In Parameters.TableRow Do
			
			If Parameters.TableRow.Count() > 3 Then 
				If MappingColumns.FindByValue(Item[Index]) = Undefined Then
					ItemsGroup = Items.OtherDataFromFile;
					ConvertedItemsCount = ConvertedItemsCount + 1;
				Else
					ItemsGroup = Items.BasicDataFromFile;
				EndIf;
			Else
				ItemsGroup = Items.BasicDataFromFile;
			EndIf;
			
			NewItem2 = Items.Add(Item[Index] + "_val", Type("FormField"), ItemsGroup);
			NewItem2.DataPath = "IND_"+Item[Index];
			NewItem2.Title = Item[1];
			NewItem2.Type = FormFieldType.InputField;
			NewItem2.ReadOnly = True;
			ThisObject["IND_" + Item[Index]] = Item[2];
		EndDo;
	EndIf;
	
	Items.OtherDataFromFile.Title = Items.OtherDataFromFile.Title + " (" +String(ConvertedItemsCount) + ")";
	ThisObject.Height = Parameters.TableRow.Count() + ConflictsList.Count() + 7;

EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Select(Command)
	Close(Items.SelectionOptions.CurrentData.Ref);
EndProcedure

&AtClient
Procedure NewItem(Command)
	Close(Undefined);
EndProcedure

#EndRegion

#Region CatalogItemsTableItemsEventHandlers

&AtClient
Procedure CatalogItemsSelection(Item, RowSelected, Field, StandardProcessing)
	Close(Items.CatalogItems.CurrentData.Ref);
EndProcedure

&AtClient
Procedure ConflictResolvingOptionsOnChange(Item)
	Items.CatalogItems.ReadOnly = Not ConflictResolutionOption;
EndProcedure

&AtClient
Procedure SelectionOptionsSelection(Item, RowSelected, Field, StandardProcessing)
	If ValueIsFilled(Item.CurrentData.Ref) AND Field.Name="SelectionOptionsValue" Then
		StandardProcessing = False;
		ShowValue(, Item.CurrentData.Ref);
	ElsIf ValueIsFilled(Item.CurrentData.Ref) AND Field.Name="OptionsPresentation" Then
		StandardProcessing = False;
		Close(Items.SelectionOptions.CurrentData.Ref);
	EndIf;
EndProcedure

#EndRegion

#Region UtilityFunctions

&AtServer
Procedure SetDataAppearance()
	
	ConditionalAppearance.Items.Clear();
	ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
	
	AppearanceField = ConditionalAppearanceItem.Fields.Items.Add();
	AppearanceField.Field = New DataCompositionField("SelectionOptionsValue");
	AppearanceField.Use = True;
	
	FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterItem.LeftValue = New DataCompositionField("SelectionOptions.Value"); 
	FilterItem.ComparisonType = DataCompositionComparisonType.NotFilled; 
	FilterItem.Use = True;
	ConditionalAppearanceItem.Appearance.SetParameterValue("Visible", False);
	
EndProcedure

#EndRegion
