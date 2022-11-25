#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	CompositionSettings = Undefined;
	
	If IsTempStorageURL(Parameters.CompositionSettingsAddress) Then
		CompositionSettings = GetFromTempStorage(Parameters.CompositionSettingsAddress);
	EndIf;
	
	If Parameters.Property("IntegrationComponent") Then
		IntegrationComponent = Parameters.IntegrationComponent;
	EndIf;
	
	InitializeComposerServer(CompositionSettings);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure FinishEditing(Command)
	Close(GetCompositionSettingsServer());
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure InitializeComposerServer(CompositionSettings)
	
	DataProcessorStorage = Common.ObjectAttributeValue(IntegrationComponent, "DataProcessorStorage");
	DataProcessor = Catalogs.IntegrationComponents.GetDataProcessor(DataProcessorStorage);
		
	ExportDataSchema = DataProcessor.GetTemplate("ExportProductsSchema");
	
	AddPredefinedFields(ExportDataSchema);
	DeleteOutdatedFilterFields(ExportDataSchema);
	SetValueTypeOfReferenceFields(ExportDataSchema);
	
	SchemaAddress = PutToTempStorage(ExportDataSchema, UUID);
	DataCompositionSettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(SchemaAddress)); 
	
	If CompositionSettings = Undefined Then
		DataCompositionSettingsComposer.LoadSettings(ExportDataSchema.DefaultSettings);
	Else
		DataCompositionSettingsComposer.LoadSettings(CompositionSettings);
		DataCompositionSettingsComposer.Refresh(DataCompositionSettingsRefreshMethod.CheckAvailability);
	EndIf;
		
EndProcedure

&AtServer
Procedure DeleteOutdatedFilterFields(ExportDataSchema)
	
	DeletedFields = New Array;
	
	RemoveFilterFieldsFromScheme(ExportDataSchema.DefaultSettings.Filter.Items, DeletedFields);
	
EndProcedure

&AtServer
Procedure RemoveFilterFieldsFromScheme(SelectionItems, DeletedFields)
	
	If DeletedFields.Count() = 0 Then
		Return;
	EndIf;
	
	Count = 0;
	While Count < SelectionItems.Count() Do
		
		FilterField = SelectionItems[Count];
		FieldName = String(FilterField.LeftValue);
		
		If Not DeletedFields.Find(FieldName) = Undefined Then
			SelectionItems.Delete(FilterField);
		Else
			Count = Count + 1;
		EndIf;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure AddPredefinedFields(ExportDataSchema)
	
	FilterFields = New Map;
	
	ExchangeWithWebsite.AddFilterFieldsToSchema(FilterFields, ExportDataSchema);
	
EndProcedure

&AtServer
Procedure SetValueTypeOfReferenceFields(ExportDataSchema)
	
	ValueTypeProducts = New TypeDescription("CatalogRef.Products");
	ValueTypePriceType = New TypeDescription("CatalogRef.PriceTypes");
	ValueTypeProductsCategory = New TypeDescription("CatalogRef.ProductsCategories");
	ValueTypeProductsProperty = New TypeDescription("ChartOfCharacteristicTypesRef.AdditionalAttributesAndInfo");		
	ExportSchemeFields = ExportDataSchema.DataSets.DataSet1.Fields;
	
	FieldProducts = ExportSchemeFields.Find("Products");
	If FieldProducts <> Undefined Then
		FieldProducts.ValueType = ValueTypeProducts;
	EndIf;
	
	FieldProductsCategory = ExportSchemeFields.Find("ProductsCategory");
	If FieldProductsCategory <> Undefined Then
		FieldProductsCategory.ValueType = ValueTypeProductsCategory;
	EndIf;
	
	FieldPriceType = ExportSchemeFields.Find("PriceType");
	If FieldPriceType <> Undefined Then
		FieldPriceType.ValueType = ValueTypePriceType;
	EndIf;
	
	FieldProductsProperty = ExportSchemeFields.Find("ProductsProperty");
	If FieldProductsProperty <> Undefined Then
		FieldProductsProperty.ValueType = ValueTypeProductsProperty;
	EndIf;
	
	ExportSchemeFilterItems = ExportDataSchema.DefaultSettings.Filter.Items;
	
	For Each FilterItem In ExportSchemeFilterItems Do
		
		If Lower(FilterItem.LeftValue) = Lower("Products") Then
			FilterItem.RightValue = Catalogs.Products.EmptyRef();
		ElsIf Lower(FilterItem.LeftValue) = Lower("PriceType") Then
			FilterItem.RightValue = Catalogs.PriceTypes.EmptyRef();
		ElsIf Lower(FilterItem.LeftValue) = Lower("ProductsCategory") Then
			FilterItem.RightValue = Catalogs.ProductsCategories.EmptyRef();
		ElsIf Lower(FilterItem.LeftValue) = Lower("ProductsProperty") Then
			FilterItem.RightValue = ChartsOfCharacteristicTypes.AdditionalAttributesAndInfo.EmptyRef();
		ElsIf Lower(FilterItem.LeftValue) = Lower("Balance") Then
			FilterItem.RightValue = 0;
		EndIf;
		
	EndDo;
	
EndProcedure

&AtServer
Function GetCompositionSettingsServer()
	
	Return DataCompositionSettingsComposer.GetSettings();
	
EndFunction

&AtServer
Function GetDefaultSettingsServer()
	
	DataProcessorStorage = Common.ObjectAttributeValue(IntegrationComponent, "DataProcessorStorage");
	DataProcessor = Catalogs.IntegrationComponents.GetDataProcessor(DataProcessorStorage);
	
	ExportDataSchema = DataProcessor.GetTemplate("ExportProductsSchema");
	Return ExportDataSchema.DefaultSettings;
	
EndFunction

&AtClient
Procedure DefaultSettings(Command)
	Close(GetDefaultSettingsServer());
EndProcedure

#EndRegion