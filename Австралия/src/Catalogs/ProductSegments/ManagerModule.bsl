#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

// Function generates the structure of available rules table
// Returns:
//  ValueTable - Columns:
//  	1. Name - is a rule identifier,
//		2. DynamicRuleKey	- additional identifier for rights generated automatically (for example, Additional attributes),
//		3 IsFolder	- shows that this rule is not used in the settings,
//		4. Presentation	- user presentation	of a rule,
//		5. MultipleUse	- shows that several values can be specified,
//		6. AvailableComparisonTypes	- values list of the DataLayoutComparisonType type - comparison kinds used for rule,
//		7. ComparisonType	- default comparison kind,
//		8. ValueProperties	- properties of form field item (table columns) connected to specified comparison values.
Function RulesDescription() Export
	
	Rules = New ValueTree;
	Rules.Columns.Add("Name",						New TypeDescription("String", New StringQualifiers(50)));
	Rules.Columns.Add("DynamicRuleKey",				New TypeDescription(
		"ChartOfCharacteristicTypesRef.AdditionalAttributesAndInfo,CatalogRef.ProductsCharacteristics"));
	Rules.Columns.Add("Presentation",				New TypeDescription("String", New StringQualifiers(100)));
	Rules.Columns.Add("IsFolder",					New TypeDescription("Boolean"));
	Rules.Columns.Add("MultipleUse",				New TypeDescription("Boolean"));
	Rules.Columns.Add("AvailableComparisonTypes",	New TypeDescription("ValueList"));
	Rules.Columns.Add("ComparisonType",				New TypeDescription("DataCompositionComparisonType"));
	Rules.Columns.Add("ValueProperties",			New TypeDescription("Structure"));
	
	Return Rules;
	
EndFunction

// Function - Receive available rules of the ilter
// Returns:
//  ValueTable - For the description of the table fields, see a comment to the RulesDescription() function
Function GetAvailableFilterRules() Export
	
	Rules = RulesDescription();
	
	TypeDescriptionStructure = New Structure;	
	TypeDescriptionStructure.Insert("TypeDescriptionRow", New TypeDescription("String",,,, New StringQualifiers(100)));
	TypeDescriptionStructure.Insert("CurrencyTypeDescription", New TypeDescription("Number",,,New NumberQualifiers(15,2)));
	TypeDescriptionStructure.Insert("TypeDescriptionBoolean", New TypeDescription("Boolean"));
	TypeDescriptionStructure.Insert("TypeDescriptionStandardDate", New TypeDescription("StandardBeginningDate"));
	TypeDescriptionStructure.Insert("TypeDescriptionStandardPeriod", New TypeDescription("StandardPeriod"));
	
	ProductPropertiesGroup = Rules.Rows.Add();
	ProductPropertiesGroup.Name = "ProductAttributes";
	ProductPropertiesGroup.Presentation = NStr("en = 'Products'; ru = 'Номенклатура';pl = 'Produkty';es_ES = 'Productos';es_CO = 'Productos';tr = 'Ürünler';it = 'Articoli';de = 'Produkte'");
	ProductPropertiesGroup.IsFolder = True;
	AddProductAttributes(ProductPropertiesGroup, TypeDescriptionStructure);
	AddAdditionalAttributes(ProductPropertiesGroup, TypeDescriptionStructure);
	
	GroupVariants = Rules.Rows.Add();
	GroupVariants.Name = "ProductsVariants";
	GroupVariants.Presentation = NStr("en = 'Variants'; ru = 'Варианты';pl = 'Warianty';es_ES = 'Variantes';es_CO = 'Variantes';tr = 'Varyantlar';it = 'Varianti';de = 'Varianten'");
	GroupVariants.IsFolder = True;
	AddProductsVariants(GroupVariants, TypeDescriptionStructure);
	
	GroupSalesProducts = Rules.Rows.Add();
	GroupSalesProducts.Name = "SalesProducts";
	GroupSalesProducts.Presentation = NStr("en = 'Sales'; ru = 'Реализация';pl = 'Sprzedaż';es_ES = 'Ventas';es_CO = 'Ventas';tr = 'Satış';it = 'Vendite';de = 'Verkauf'");
	GroupSalesProducts.IsFolder = True;
	AddSalesProducts(GroupSalesProducts, TypeDescriptionStructure);
	
	Return Rules;
	
EndFunction

// Function returns the segment content
//
// Parameters:
//	Segment - CatalogRef.Segment - segment for which it is required to receive the content
//
// Returns:
// ValueTable - table of products included in segment.
Function GetSegmentContent(Segment) Export
	
	Query = GenerateQueryOnRules(Segment);
	Return Query.Execute().Unload();
	
EndFunction

// Function - Generate query by rules
//
// Parameters:
//  Segment	 - CatalogRef.Segment	 - segment for which it
// is required to receive the Return value query:
//  Query - query with a set text and parameters
Function GenerateQueryOnRules(Segment) Export
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	SegmentsUsedRules.Name,
		|	SegmentsUsedRules.Settings,
		|	SegmentsUsedRules.DynamicRuleKey
		|FROM
		|	Catalog.ProductSegments.UsedRules AS SegmentsUsedRules
		|WHERE
		|	SegmentsUsedRules.Ref = &Ref
		|
		|ORDER BY
		|	SegmentsUsedRules.LineNumber";
	
	Query.SetParameter("Ref", Segment);
	RulesTable = Query.Execute().Unload();
	
	Query = New Query;
	
	QuerySchema = New QuerySchema;
	QuerySchema.SetQueryText("
		|SELECT ALLOWED DISTINCT
		|	Products.Ref AS Product
		|FROM
		|	Catalog.Products AS Products
		|WHERE
		|	Products.IsFolder = FALSE
		|	AND Products.DeletionMark = FALSE
		|
		|ORDER BY
		|	Products.Description");
	
	AddVariantsBatch(QuerySchema);
	
	FilterQuery = QuerySchema.QueryBatch[0].Operators[0].Filter;
	QueryAverageVolume = Undefined;
	QuerySales = Undefined;
	QueryVariants = Undefined;
	QueryVariantAttribute = Undefined;
	
	RuleNumber = 0;
	
	For Each RuleRow In RulesTable Do
		
		RuleNumber = RuleNumber + 1;
		RuleSettings = RuleRow.Settings.Get();
		
		If RuleRow.Name = "Product" Then
			
			FilterQuery.Add(SegmentsServer.ComparisonCondition("Products.Ref", RuleSettings.ComparisonType, RuleRow.Name));
			Query.SetParameter(RuleRow.Name, RuleSettings.Value);
			
		ElsIf RuleRow.Name = "ChangeDate" Then
			
			FilterQuery.Add(
				SegmentsServer.ComparisonCondition(
					"Products.ChangeDate", RuleSettings.ComparisonType, RuleRow.Name + "_" + RuleNumber));
			Query.SetParameter(RuleRow.Name + "_" + RuleNumber, RuleSettings.Value.Date);
			
		ElsIf RuleRow.Name = "DescriptionFull" Then
			
			FilterQuery.Add(
				SegmentsServer.ComparisonCondition(
					"Products.DescriptionFull", RuleSettings.ComparisonType, RuleRow.Name));
			Query.SetParameter(
				RuleRow.Name, SegmentsServer.OperatorTemplateDetails(RuleSettings.ComparisonType, RuleSettings.Value));
			
		ElsIf RuleRow.Name = "Description" Then
			
			FilterQuery.Add(
				SegmentsServer.ComparisonCondition("Products.Description", RuleSettings.ComparisonType, RuleRow.Name));
			Query.SetParameter(
				RuleRow.Name, SegmentsServer.OperatorTemplateDetails(RuleSettings.ComparisonType, RuleSettings.Value));
			
		ElsIf RuleRow.Name = "AdditionalAttribute" AND ValueIsFilled(RuleRow.DynamicRuleKey) Then
			
			QueryText = 
			"SELECT ALLOWED
			|	ProductsAdditionalAttributes.Ref AS Ref
			|FROM
			|	Catalog.Products.AdditionalAttributes AS ProductsAdditionalAttributes";
			
			QuerySchema.QueryBatch[0].PlacementTable = "ProductsTable";
			QueryAttribute = QuerySchema.QueryBatch.Add(Type("QuerySchemaSelectQuery"));
			QueryAttribute.SetQueryText(QueryText);
			
			LastTableName = GetLastTableName(QuerySchema);
			LastAvailableTable = JoinLastTable(
				QueryAttribute, LastTableName, ".Product = ProductsAdditionalAttributes.Ref", QuerySchemaJoinType.Inner); 
			QueryAttribute.Operators[0].SelectedFields.Add(LastAvailableTable.Fields.Find("Product"));
			QueryAttribute.Operators[0].SelectedFields.Add(LastAvailableTable.Fields.Find("Variant"));
			InsertedQueryFilter = QueryAttribute.Operators[0].Filter;
			
			InsertedQueryFilter.Add("ProductsAdditionalAttributes.Property = &Property" + RuleNumber);
			Query.SetParameter("Property" + RuleNumber, RuleRow.DynamicRuleKey);
			InsertedQueryFilter.Add(
				SegmentsServer.ComparisonCondition(
					"ProductsAdditionalAttributes.Value", RuleSettings.ComparisonType, "ValueAdditionalAttribute" + RuleNumber));
			If IsStringValue(RuleSettings) Then
				Query.SetParameter(
					"ValueAdditionalAttribute" + RuleNumber,
					SegmentsServer.OperatorTemplateDetails(RuleSettings.ComparisonType, RuleSettings.Value));
			Else
				Query.SetParameter("ValueAdditionalAttribute" + RuleNumber, RuleSettings.Value);
			EndIf;
			
		ElsIf Left(RuleRow.Name, 7) = "Variant" Then
			
			QueryText = 
			"SELECT ALLOWED
			|	ProductsCharacteristics.Owner AS Product,
			|	ProductsCharacteristics.Ref AS Variant,
			|	ProductsCharacteristics.Description AS VariantDescription
			|FROM
			|	Catalog.ProductsCharacteristics AS ProductsCharacteristics";
			
			QuerySchema.QueryBatch[0].PlacementTable = "ProductsTable";
			QueryVariants = QuerySchema.QueryBatch.Add(Type("QuerySchemaSelectQuery"));
			QueryVariants.SetQueryText(QueryText);
			
			LastTableName = GetLastTableName(QuerySchema);
			LastAvailableTable = JoinLastTable(
				QueryVariants,
				LastTableName,
				"&LastTableName.Product = ProductsCharacteristics.Owner AND &LastTableName.Variant = ProductsCharacteristics.Ref",
				QuerySchemaJoinType.Inner,
				True);
			InsertedQueryFilter = QueryVariants.Operators[0].Filter;

			If RuleRow.Name = "VariantOwner" Then
				InsertedQueryFilter.Add(
					SegmentsServer.ComparisonCondition("ProductsCharacteristics.Owner", RuleSettings.ComparisonType, RuleRow.Name));
				Query.SetParameter(RuleRow.Name, RuleSettings.Value);
			ElsIf RuleRow.Name = "VariantDescription" Then
				InsertedQueryFilter.Add(
					SegmentsServer.ComparisonCondition(
						"ProductsCharacteristics.Description", RuleSettings.ComparisonType, RuleRow.Name));
				Query.SetParameter(
					RuleRow.Name, SegmentsServer.OperatorTemplateDetails(RuleSettings.ComparisonType, RuleSettings.Value));
			ElsIf RuleRow.Name = "VariantAdditionalAttribute" AND ValueIsFilled(RuleRow.DynamicRuleKey) Then
				
				QueryText = 
				"SELECT ALLOWED
				|	ProductsCharacteristicsAdditionalAttributes.Ref AS Variant,
				|	ProductsCharacteristicsAdditionalAttributes.Property AS Property,
				|	ProductsCharacteristicsAdditionalAttributes.Value AS Value
				|FROM
				|	Catalog.ProductsCharacteristics.AdditionalAttributes AS ProductsCharacteristicsAdditionalAttributes";
				
				QueryVariantAttribute = QuerySchema.QueryBatch.Add(Type("QuerySchemaSelectQuery"));
				QueryVariantAttribute.SetQueryText(QueryText);
				
				LastTableName = GetLastTableName(QuerySchema);
				LastAvailableTable = JoinLastTable(
					QueryVariantAttribute,
					LastTableName,
					"&LastTableName.Variant = ProductsCharacteristicsAdditionalAttributes.Ref",
					QuerySchemaJoinType.Inner); 
				QueryVariantAttribute.Operators[0].SelectedFields.Add(LastAvailableTable.Fields.Find("Product"));  
				
				InsertedQueryFilter = QueryVariantAttribute.Operators[0].Filter;
				PropertyCondition = "ProductsCharacteristicsAdditionalAttributes.Property = &Property" + RuleNumber;
				ValueCondition = SegmentsServer.ComparisonCondition(
					"ProductsCharacteristicsAdditionalAttributes.Value",
					RuleSettings.ComparisonType,
					"ValueAdditionalAttribute" + RuleNumber);
				InsertedQueryFilter.Add(PropertyCondition + " AND " + ValueCondition);
				
				Query.SetParameter("Property" + RuleNumber, RuleRow.DynamicRuleKey);
				If IsStringValue(RuleSettings) Then
					Query.SetParameter(
						"ValueAdditionalAttribute" + RuleNumber,
						SegmentsServer.OperatorTemplateDetails(RuleSettings.ComparisonType, RuleSettings.Value));
				Else
					Query.SetParameter("ValueAdditionalAttribute" + RuleNumber, RuleSettings.Value);
				EndIf;
				
			EndIf;
			
		ElsIf Left(RuleRow.Name, 12) = "StockBalance" Then
			
			Continue;
			
		ElsIf Left(RuleRow.Name, 13) = "SalesProducts" Then
			
			QueryText = 
			"SELECT ALLOWED DISTINCT
			|	SalesTurnovers.Products AS Product,
			|	SalesTurnovers.Characteristic AS Variant,
			|	SalesTurnovers.QuantityTurnover AS QuantityTurnover,
			|	SalesTurnovers.AmountTurnover AS AmountTurnover,
			|	CASE
			|		WHEN SalesTurnovers.AmountTurnover <> 0
			|			THEN (SalesTurnovers.AmountTurnover - SalesTurnovers.CostTurnover) * 100 / SalesTurnovers.AmountTurnover
			|		ELSE 0
			|	END AS Margin
			|FROM
			|	AccumulationRegister.Sales.Turnovers(
			|			,
			|			,
			|			,
			|			Products IN
			|				(SELECT
			|					ProductsTable.Product AS Ref
			|				FROM
			|					ProductsTable AS ProductsTable)) AS SalesTurnovers";
			
			QuerySchema.QueryBatch[0].PlacementTable = "ProductsTable";
			NewQueryBatch = GetNewQueryBatch(
				QuerySchema,
				QueryText,
				"&LastTableName.Product = SalesTurnovers.Products AND (&LastTableName.Variant = SalesTurnovers.Characteristic
					|OR SalesTurnovers.Characteristic = VALUE(Catalog.ProductsCharacteristics.EmptyRef))",
				QuerySchemaJoinType.Inner,
				True);
			InsertedQueryFilter = NewQueryBatch.Operators[0].Filter;

			If RuleRow.Name = "SalesProductsQuantity" Then
				InsertedQueryFilter.Add(
					SegmentsServer.ComparisonCondition(
						"SalesTurnovers.QuantityTurnover", RuleSettings.ComparisonType, RuleRow.Name + "_" + RuleNumber));
				Query.SetParameter(RuleRow.Name + "_" + RuleNumber, RuleSettings.Value);
			ElsIf RuleRow.Name = "SalesProductsAmount" Then
				InsertedQueryFilter.Add(
					SegmentsServer.ComparisonCondition(
						"SalesTurnovers.AmountTurnover", RuleSettings.ComparisonType, RuleRow.Name + "_" + RuleNumber));
				Query.SetParameter(RuleRow.Name + "_" + RuleNumber, RuleSettings.Value);
			ElsIf RuleRow.Name = "SalesProductsMargin" Then
				Margin = "CASE WHEN SalesTurnovers.AmountTurnover <> 0 THEN
					|(SalesTurnovers.AmountTurnover - SalesTurnovers.CostTurnover) * 100 / SalesTurnovers.AmountTurnover 
					|ELSE 0 END"; 
				InsertedQueryFilter.Add(
					SegmentsServer.ComparisonCondition(
						Margin, RuleSettings.ComparisonType, RuleRow.Name + "_" + RuleNumber));
				Query.SetParameter(RuleRow.Name + "_" + RuleNumber, RuleSettings.Value);
			ElsIf RuleRow.Name = "SalesProductsPeriod" Then
				Source = NewQueryBatch.Operators[0].Sources[0].Source;				
				If ValueIsFilled(RuleSettings.Value.StartDate) Then
					Source.Parameters[0].Expression = New QuerySchemaExpression("&" + RuleRow.Name + "Begin");
					Query.SetParameter(RuleRow.Name + "Begin", RuleSettings.Value.StartDate);
				EndIf;
				If ValueIsFilled(RuleSettings.Value.EndDate) Then
					Source.Parameters[1].Expression = New QuerySchemaExpression("&" + RuleRow.Name + "End");
					Query.SetParameter(RuleRow.Name + "End",  RuleSettings.Value.EndDate);
				EndIf;
			EndIf;
			
		Else
			FilterQuery.Add(
				SegmentsServer.ComparisonCondition("Products." + RuleRow.Name, RuleSettings.ComparisonType, RuleRow.Name));
			Query.SetParameter(RuleRow.Name, RuleSettings.Value);
		EndIf;
		
	EndDo;
	
	Query.Text = QuerySchema.GetQueryText();
	
	Return Query;
	
EndFunction

#EndRegion

#Region EventHandlers

Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	NativeLanguagesSupportServer.ChoiceDataGetProcessing(
		ChoiceData,
		Parameters,
		StandardProcessing,
		Metadata.Catalogs.ProductSegments);
	
EndProcedure

Procedure PresentationGetProcessing(Data, Presentation, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationGetProcessing(Data, Presentation, StandardProcessing);
	
EndProcedure

Procedure PresentationFieldsGetProcessing(Fields, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationFieldsGetProcessing(Fields, StandardProcessing);
	
EndProcedure

#EndRegion

#Region Private

Procedure AddProductAttributes(ProductPropertiesGroup, TypeDescriptionStructure)
	
	NewRule = ProductPropertiesGroup.Rows.Add();
	NewRule.Name = "Product";
	NewRule.Presentation = Metadata.Catalogs.Products.ObjectPresentation;
	NewRule.IsFolder = False;
	NewRule.MultipleUse = False;
	NewRule.ValueProperties.Insert("TypeRestriction", New TypeDescription("CatalogRef.Products"));
	NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
	SegmentsServer.AddComparisonTypes(NewRule, "Equal, NotEqual, InHierarchy, NotInHierarchy, InList, NotInList", 5);
	
	NewRule = ProductPropertiesGroup.Rows.Add();
	NewRule.Name = "BusinessLine";
	NewRule.Presentation = Metadata.Catalogs.Products.Attributes.BusinessLine.Synonym;
	NewRule.IsFolder = False;
	NewRule.MultipleUse = False;
	NewRule.ValueProperties.Insert("TypeRestriction", New TypeDescription("CatalogRef.LinesOfBusiness"));
	NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
	SegmentsServer.AddComparisonTypes(NewRule, "Equal, NotEqual, InList, NotInList");
		
	NewRule = ProductPropertiesGroup.Rows.Add();
	NewRule.Name = "ChangeDate";
	NewRule.Presentation = Metadata.Catalogs.Products.Attributes.ChangeDate;
	NewRule.IsFolder = False;
	NewRule.MultipleUse = True;
	NewRule.ValueProperties.Insert("TypeRestriction", TypeDescriptionStructure.TypeDescriptionStandardDate);
	NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
	SegmentsServer.AddComparisonTypes(NewRule, "Equal, NotEqual, Greater, GreaterOrEqual, Less, LessOrEqual", 4);
	
	NewRule = ProductPropertiesGroup.Rows.Add();
	NewRule.Name = "CountryOfOrigin";
	NewRule.Presentation = Metadata.Catalogs.Products.Attributes.CountryOfOrigin.Synonym;
	NewRule.IsFolder = False;
	NewRule.MultipleUse = False;
	NewRule.ValueProperties.Insert("TypeRestriction", New TypeDescription("CatalogRef.WorldCountries"));
	NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
	SegmentsServer.AddComparisonTypes(NewRule, "Equal, NotEqual, InList, NotInList, Filled, NotFilled");
	
	NewRule = ProductPropertiesGroup.Rows.Add();
	NewRule.Name = "DescriptionFull";
	NewRule.Presentation = Metadata.Catalogs.Products.Attributes.DescriptionFull;
	NewRule.IsFolder = False;
	NewRule.MultipleUse = False;
	NewRule.ValueProperties.Insert("TypeRestriction", TypeDescriptionStructure.TypeDescriptionRow);
	NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
	SegmentsServer.AddComparisonTypes(NewRule, "BeginsWith, NotBeginsWith, Contains, NotContains", 3);
	
	NewRule = ProductPropertiesGroup.Rows.Add();
	NewRule.Name = "Description";
	NewRule.Presentation = Metadata.Catalogs.Products.StandardAttributes.Description.Synonym;
	NewRule.IsFolder = False;
	NewRule.MultipleUse = False;
	NewRule.ValueProperties.Insert("TypeRestriction", TypeDescriptionStructure.TypeDescriptionRow);
	NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
	SegmentsServer.AddComparisonTypes(NewRule, "BeginsWith, NotBeginsWith, Contains, NotContains", 3);
	
	NewRule = ProductPropertiesGroup.Rows.Add();
	NewRule.Name = "HSCode";
	NewRule.Presentation = Metadata.Catalogs.Products.Attributes.HSCode.Synonym;
	NewRule.IsFolder = False;
	NewRule.MultipleUse = False;
	NewRule.ValueProperties.Insert("TypeRestriction", New TypeDescription("CatalogRef.HSCodes"));
	NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
	SegmentsServer.AddComparisonTypes(NewRule, "Equal, NotEqual, InList, NotInList, Filled, NotFilled");
	
	NewRule = ProductPropertiesGroup.Rows.Add();
	NewRule.Name = "PriceGroup";
	NewRule.Presentation = Metadata.Catalogs.Products.Attributes.PriceGroup.Synonym;
	NewRule.IsFolder = False;
	NewRule.MultipleUse = False;
	NewRule.ValueProperties.Insert("TypeRestriction", New TypeDescription("CatalogRef.PriceGroups"));
	NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
	SegmentsServer.AddComparisonTypes(NewRule, "Equal, NotEqual, InList, NotInList, Filled, NotFilled");
	
	NewRule = ProductPropertiesGroup.Rows.Add();
	NewRule.Name = "ProductsCategory";
	NewRule.Presentation = Metadata.Catalogs.Products.Attributes.ProductsCategory.Synonym;
	NewRule.IsFolder = False;
	NewRule.MultipleUse = False;
	NewRule.ValueProperties.Insert("TypeRestriction", New TypeDescription("CatalogRef.ProductsCategories"));
	NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
	SegmentsServer.AddComparisonTypes(NewRule, "Equal, NotEqual, InList, NotInList, Filled, NotFilled");
	
	NewRule = ProductPropertiesGroup.Rows.Add();
	NewRule.Name = "ProductsType";
	NewRule.Presentation = Metadata.Catalogs.Products.Attributes.ProductsType.Synonym;
	NewRule.IsFolder = False;
	NewRule.MultipleUse = False;
	NewRule.ValueProperties.Insert("TypeRestriction", New TypeDescription("EnumRef.ProductsTypes"));
	NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
	SegmentsServer.AddComparisonTypes(NewRule, "Equal, NotEqual, InList, NotInList");
	
	NewRule = ProductPropertiesGroup.Rows.Add();
	NewRule.Name = "ReplenishmentMethod";
	NewRule.Presentation = Metadata.Catalogs.Products.Attributes.ReplenishmentMethod.Synonym;
	NewRule.IsFolder = False;
	NewRule.MultipleUse = False;
	NewRule.ValueProperties.Insert("TypeRestriction", New TypeDescription("EnumRef.InventoryReplenishmentMethods"));
	NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
	SegmentsServer.AddComparisonTypes(NewRule, "Equal, NotEqual, InList, NotInList");
	
	NewRule = ProductPropertiesGroup.Rows.Add();
	NewRule.Name = "UseBatches";
	NewRule.Presentation = Metadata.Catalogs.Products.Attributes.UseBatches.Synonym;
	NewRule.IsFolder = False;
	NewRule.MultipleUse = False;
	NewRule.ValueProperties.Insert("TypeRestriction", TypeDescriptionStructure.TypeDescriptionBoolean);
	NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
	SegmentsServer.AddComparisonTypes(NewRule, "Equal, NotEqual");
	
	NewRule = ProductPropertiesGroup.Rows.Add();
	NewRule.Name = "UseCharacteristics";
	NewRule.Presentation = Metadata.Catalogs.Products.Attributes.UseCharacteristics.Synonym;
	NewRule.IsFolder = False;
	NewRule.MultipleUse = False;
	NewRule.ValueProperties.Insert("TypeRestriction", TypeDescriptionStructure.TypeDescriptionBoolean);
	NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
	SegmentsServer.AddComparisonTypes(NewRule, "Equal, NotEqual");
	
	NewRule = ProductPropertiesGroup.Rows.Add();
	NewRule.Name = "Vendor";
	NewRule.Presentation = Metadata.Catalogs.Products.Attributes.Vendor.Synonym;
	NewRule.IsFolder = False;
	NewRule.MultipleUse = False;
	NewRule.ValueProperties.Insert("TypeRestriction", New TypeDescription("CatalogRef.Counterparties"));
	NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
	SegmentsServer.AddComparisonTypes(NewRule, "Equal, NotEqual, InHierarchy, NotInHierarchy, InList, NotInList");
	
	NewRule = ProductPropertiesGroup.Rows.Add();
	NewRule.Name = "IsBundle";
	NewRule.Presentation = Metadata.Catalogs.Products.Attributes.IsBundle.Synonym;
	NewRule.IsFolder = False;
	NewRule.MultipleUse = False;
	NewRule.ValueProperties.Insert("TypeRestriction", TypeDescriptionStructure.TypeDescriptionBoolean);
	NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
	SegmentsServer.AddComparisonTypes(NewRule, "Equal, NotEqual");
	
EndProcedure

Procedure AddAdditionalAttributes(ProductPropertiesGroup, TypeDescriptionStructure)
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	AdditionalAttributesAndInfoSets.Ref AS Ref
	|INTO PropertySets
	|FROM
	|	Catalog.AdditionalAttributesAndInfoSets AS AdditionalAttributesAndInfoSets
	|WHERE
	|	AdditionalAttributesAndInfoSets.Parent = VALUE(Catalog.AdditionalAttributesAndInfoSets.Catalog_Products)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AdditionalAttributesAndInformation.Ref AS Ref,
	|	AdditionalAttributesAndInformation.Title AS Title,
	|	AdditionalAttributesAndInformation.ValueType AS ValueType,
	|	AdditionalAttributesAndInformation.FormatProperties AS FormatProperties
	|FROM
	|	ChartOfCharacteristicTypes.AdditionalAttributesAndInfo AS AdditionalAttributesAndInformation
	|		INNER JOIN PropertySets AS PropertySets
	|		ON AdditionalAttributesAndInformation.PropertySet = PropertySets.Ref
	|
	|ORDER BY
	|	AdditionalAttributesAndInformation.Title";
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		NewRule = ProductPropertiesGroup.Rows.Add();
		NewRule.Name			= "AdditionalAttribute";
		NewRule.DynamicRuleKey	= Selection.Ref;
		NewRule.IsFolder		= False;
		NewRule.MultipleUse		= False;
		NewRule.Presentation	= Selection.Title;
		
		NewRule.ValueProperties.Insert("TypeRestriction",		Selection.ValueType);
		NewRule.ValueProperties.Insert("ChoiceFoldersAndItems",	FoldersAndItems.Items);
		NewRule.ValueProperties.Insert("Format",				Selection.FormatProperties);
		
		SegmentsServer.AddComparisonTypes(NewRule, "Equal,NotEqual");
		If Selection.ValueType.ContainsType(Type("Number"))
			OR Selection.ValueType.ContainsType(Type("Date")) Then
			SegmentsServer.AddComparisonTypes(NewRule, "Greater, GreaterOrEqual, Less, LessOrEqual");
			NewRule.MultipleUse = True;
		EndIf;
		
		If Selection.ValueType.ContainsType(Type("String")) Then
			SegmentsServer.AddComparisonTypes(NewRule, "BeginsWith, NotBeginsWith, Contains, NotContains");
		EndIf;
		
		For Each ValueType In Selection.ValueType.Types() Do
			If Common.IsReference(ValueType) Then
				SegmentsServer.AddComparisonTypes(NewRule, "InList, NotInList, Filled, NotFilled");
				Break;
			EndIf;
		EndDo;
		
	EndDo;

EndProcedure

Procedure AddProductsVariants(GroupVariants, TypeDescriptionStructure)
	
	NewRule = GroupVariants.Rows.Add();
	NewRule.Name = "VariantOwner";
	NewRule.Presentation = NStr("en = 'Owner'; ru = 'Владелец';pl = 'Właściciel';es_ES = 'Propietario';es_CO = 'Propietario';tr = 'Sahibi';it = 'Proprietario';de = 'Eigentümer'");
	NewRule.IsFolder = False;
	NewRule.MultipleUse = False;
	NewRule.ValueProperties.Insert("TypeRestriction", New TypeDescription("CatalogRef.Products"));
	NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
	SegmentsServer.AddComparisonTypes(NewRule, "Equal, NotEqual, InHierarchy, NotInHierarchy, InList, NotInList");
	
	NewRule = GroupVariants.Rows.Add();
	NewRule.Name = "VariantDescription";
	NewRule.Presentation = Metadata.Catalogs.ProductsCharacteristics.StandardAttributes.Description.Synonym;
	NewRule.IsFolder = False;
	NewRule.MultipleUse = False;
	NewRule.ValueProperties.Insert("TypeRestriction", TypeDescriptionStructure.TypeDescriptionRow);
	NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
	SegmentsServer.AddComparisonTypes(NewRule, "BeginsWith, NotBeginsWith, Contains, NotContains", 3);
	
	#Region AdditionalAttributes
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	AdditionalAttributesAndInfoSets.Ref AS Ref
	|INTO PropertySets
	|FROM
	|	Catalog.AdditionalAttributesAndInfoSets AS AdditionalAttributesAndInfoSets
	|WHERE
	|	AdditionalAttributesAndInfoSets.Parent = VALUE(Catalog.AdditionalAttributesAndInfoSets.Catalog_ProductsCharacteristics)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AdditionalAttributesAndInformation.Ref AS Ref,
	|	AdditionalAttributesAndInformation.Title AS Title,
	|	AdditionalAttributesAndInformation.ValueType AS ValueType,
	|	AdditionalAttributesAndInformation.FormatProperties AS FormatProperties
	|FROM
	|	ChartOfCharacteristicTypes.AdditionalAttributesAndInfo AS AdditionalAttributesAndInformation
	|		INNER JOIN PropertySets AS PropertySets
	|		ON AdditionalAttributesAndInformation.PropertySet = PropertySets.Ref
	|
	|ORDER BY
	|	AdditionalAttributesAndInformation.Title";
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		NewRule = GroupVariants.Rows.Add();
		NewRule.Name			= "VariantAdditionalAttribute";
		NewRule.DynamicRuleKey	= Selection.Ref;
		NewRule.IsFolder		= False;
		NewRule.MultipleUse		= False;
		NewRule.Presentation	= Selection.Title;
		
		NewRule.ValueProperties.Insert("TypeRestriction",		Selection.ValueType);
		NewRule.ValueProperties.Insert("ChoiceFoldersAndItems",	FoldersAndItems.Items);
		NewRule.ValueProperties.Insert("Format",				Selection.FormatProperties);
		
		SegmentsServer.AddComparisonTypes(NewRule, "Equal,NotEqual");
		If Selection.ValueType.ContainsType(Type("Number"))
			OR Selection.ValueType.ContainsType(Type("Date")) Then
			SegmentsServer.AddComparisonTypes(NewRule, "Greater, GreaterOrEqual, Less, LessOrEqual");
			NewRule.MultipleUse = True;
		EndIf;
		
		If Selection.ValueType.ContainsType(Type("String")) Then
			SegmentsServer.AddComparisonTypes(NewRule, "BeginsWith, NotBeginsWith, Contains, NotContains");
		EndIf;
		
		For Each ValueType In Selection.ValueType.Types() Do
			If Common.IsReference(ValueType) Then
				SegmentsServer.AddComparisonTypes(NewRule, "InList, NotInList, Filled, NotFilled");
				Break;
			EndIf;
		EndDo;
		
	EndDo;

	#EndRegion

EndProcedure

Procedure AddSalesProducts(GroupSalesProducts, TypeDescriptionStructure)
	
	NewRule = GroupSalesProducts.Rows.Add();
	NewRule.Name = "SalesProductsQuantity";
	NewRule.Presentation = NStr("en = 'Quantity'; ru = 'Количество';pl = 'Ilość';es_ES = 'Cantidad';es_CO = 'Cantidad';tr = 'Miktar';it = 'Quantità';de = 'Menge'");
	NewRule.IsFolder = False;
	NewRule.MultipleUse = False;
	NewRule.ValueProperties.Insert("TypeRestriction", TypeDescriptionStructure.CurrencyTypeDescription);
	NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
	SegmentsServer.AddComparisonTypes(NewRule, "Equal, NotEqual, Greater, GreaterOrEqual, Less, LessOrEqual", 4);
	
	NewRule = GroupSalesProducts.Rows.Add();
	NewRule.Name = "SalesProductsAmount";
	NewRule.Presentation = NStr("en = 'Amount'; ru = 'Сумма';pl = 'Wartość';es_ES = 'Importe';es_CO = 'Importe';tr = 'Tutar';it = 'Importo';de = 'Betrag'");
	NewRule.IsFolder = False;
	NewRule.MultipleUse = False;
	NewRule.ValueProperties.Insert("TypeRestriction", TypeDescriptionStructure.CurrencyTypeDescription);
	NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
	SegmentsServer.AddComparisonTypes(NewRule, "Equal, NotEqual, Greater, GreaterOrEqual, Less, LessOrEqual", 4);
	
	NewRule = GroupSalesProducts.Rows.Add();
	NewRule.Name = "SalesProductsMargin";
	NewRule.Presentation = NStr("en = 'Margin'; ru = 'Прибыль/выручка';pl = 'Marża';es_ES = 'Margen';es_CO = 'Margen';tr = 'Kar Marjı (%)';it = 'Utile / Fatturato';de = 'Marge'");
	NewRule.IsFolder = False;
	NewRule.MultipleUse = False;
	NewRule.ValueProperties.Insert("TypeRestriction", TypeDescriptionStructure.CurrencyTypeDescription);
	NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
	SegmentsServer.AddComparisonTypes(NewRule, "Equal, NotEqual, Greater, GreaterOrEqual, Less, LessOrEqual", 4);
	
	NewRule = GroupSalesProducts.Rows.Add();
	NewRule.Name = "SalesProductsPeriod";
	NewRule.Presentation = NStr("en = 'Product sales period'; ru = 'Период продаж номенклатуры';pl = 'Okres sprzedaży produktu';es_ES = 'Período de venta del producto';es_CO = 'Período de venta del producto';tr = 'Ürün satış dönemi';it = 'Periodo di vendita articolo';de = 'Produktverkaufszeitraum'");
	NewRule.IsFolder = False;
	NewRule.MultipleUse = False;
	NewRule.ValueProperties.Insert("TypeRestriction", TypeDescriptionStructure.TypeDescriptionStandardPeriod);
	NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
	SegmentsServer.AddComparisonTypes(NewRule, "Equal");

EndProcedure

Function GetLastTableName(QuerySchema)
	
	PreviousBatchIndex = QuerySchema.QueryBatch.Count()-2;
	LastTableName = ?(PreviousBatchIndex = 0, "ProductsTable", "QueryBatch" + PreviousBatchIndex);
	QuerySchema.QueryBatch[PreviousBatchIndex].PlacementTable = LastTableName;
	Return LastTableName;
	
EndFunction

Function JoinLastTable(NewQueryBatch, LastTableName, JoinCondition, JoinType, ClearJoins = False)
	
	TemporaryTables = NewQueryBatch.AvailableTables.Get(NewQueryBatch.AvailableTables.Count()-1);
	LastAvailableTable = TemporaryTables.Content.Find(LastTableName);					
	NewQueryBatch.Operators[0].Sources.Add(LastAvailableTable, LastTableName);
	
	If ClearJoins Then
		NewQueryBatch.Operators[0].Sources[1].Joins.Clear();
	EndIf;
	Source = NewQueryBatch.Operators[0].Sources[0];
	Source.Joins.Add(LastTableName, StrReplace(JoinCondition, "&LastTableName", LastTableName));  
	Source.Joins[0].JoinType = JoinType;
	Return LastAvailableTable; 
	
EndFunction

Function GetNewQueryBatch(QuerySchema, QueryText, JoinCondition, JoinType, ClearJoins = False)
	
	NewQueryBatch = QuerySchema.QueryBatch.Add(Type("QuerySchemaSelectQuery"));
	NewQueryBatch.SetQueryText(QueryText);
	
	LastTableName = GetLastTableName(QuerySchema);
	JoinLastTable(NewQueryBatch, LastTableName, JoinCondition, JoinType, ClearJoins);	
	Return NewQueryBatch;
	
EndFunction

Function IsStringValue(RuleSettings)
	
	Return TypeOf(RuleSettings.Value) = Type("String")
		AND (RuleSettings.ComparisonType = DataCompositionComparisonType.BeginsWith
		Or RuleSettings.ComparisonType = DataCompositionComparisonType.NotBeginsWith
		Or RuleSettings.ComparisonType = DataCompositionComparisonType.Contains
		Or RuleSettings.ComparisonType = DataCompositionComparisonType.NotContains);	
	
EndFunction

Procedure AddVariantsBatch(QuerySchema)
	
	QueryText = 
	"SELECT
	|	ISNULL(ProductsCharacteristics.Ref, VALUE(Catalog.ProductsCharacteristics.EmptyRef)) AS Variant
	|FROM
	|	Catalog.ProductsCharacteristics AS ProductsCharacteristics";
	
	QuerySchema.QueryBatch[0].PlacementTable = "ProductsTable";
	NewQueryBatch = QuerySchema.QueryBatch.Add(Type("QuerySchemaSelectQuery"));
	NewQueryBatch.SetQueryText(QueryText);
	
	LastTableName = GetLastTableName(QuerySchema);
	LastAvailableTable = JoinLastTable(NewQueryBatch, LastTableName, ".Product = ProductsCharacteristics.Owner", QuerySchemaJoinType.RightOuter); 
	NewQueryBatch.Operators[0].SelectedFields.Add(LastAvailableTable.Fields.Find("Product"));
	
EndProcedure

#EndRegion

#EndIf