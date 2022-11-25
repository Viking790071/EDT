
Function MaximumOfUsefulColumnsTableDocument() Export
	
	// Most attributes contains catalog Counterparties (30 useful) + 10 CI + Additional attributes.
	// The remaining cells are checked in DataImportFromExternalSources.OptimizeSpreadsheetDocument();
	
	Return 30 + 10 + MaximumOfAdditionalAttributesTableDocument();
	
EndFunction

Function MaximumOfAdditionalAttributesTableDocument() Export
	
	Return 10;
	
EndFunction

Procedure AddConditionalMatchTablesDesign(ThisObject, AttributePath, DataLoadSettings) Export
	
	FieldNames = New Array;
	AdditionalConditions = New Map;
	
	TextNewItem	= NStr("en = '<New item will be created>'; ru = '<Будет создан новый элемент>';pl = '<Zostanie utworzony nowy element>';es_ES = '<Nuevo artículo se creará>';es_CO = '<Nuevo artículo se creará>';tr = '<Yeni öğe oluşturulacak>';it = '<Verrà creato un nuovo elemento>';de = '<Neuer Artikel wird erstellt>'");
	TextSkipped	= NStr("en = '<Data will be skipped>'; ru = '<Данные будут пропущены>';pl = '<Dane zostaną pominięte>';es_ES = '<Datos se saltarán>';es_CO = '<Datos se saltarán>';tr = '<Veri atlanacak>';it = '<Verranno saltati dati>';de = '<Daten werden übersprungen>'");
	
	FillingObjectFullName = DataLoadSettings.FillingObjectFullName;
	
	If DataLoadSettings.IsTabularSectionImport Then
		
		ConditionalAppearanceText = TextNewItem;
		
		If FillingObjectFullName = "Document.OpeningBalanceEntry.TabularSection.CashAssets" Then
			
			If DataLoadSettings.AccountType = "BankAccount" Then
				FieldNames.Add("Bank");
			EndIf;
			
			FieldNames.Add("Currency");
			FieldNames.Add("Account");
			
		ElsIf FillingObjectFullName = "Document.OpeningBalanceEntry.TabularSection.AccountsReceivable" 
			Or FillingObjectFullName = "Document.OpeningBalanceEntry.TabularSection.AccountsPayable" Then 
			
			FieldNames.Add("Counterparty");
			
			FieldNames.Add("Contract");
			Conditions = New Array;
			Conditions.Add("ContractDescription");
			AdditionalConditions.Insert("Contract", Conditions);
			
			FieldNames.Add("Currency");
			FieldNames.Add("Document");
			
		ElsIf FillingObjectFullName = "Document.SalesTarget.TabularSection.Inventory" Then
			
		ElsIf FillingObjectFullName = "Document.RequestForQuotation.TabularSection.Suppliers" Then
			
		Else
			// Inventory
			FilledObject = Metadata.FindByFullName(FillingObjectFullName);
			
			UseSeveralWarehouses = GetFunctionalOption("UseSeveralWarehouses")
				And Common.HasObjectAttribute("StructuralUnit", FilledObject);
			
			If UseSeveralWarehouses Then
				FieldNames.Add("StructuralUnit");
				Conditions = New Array;
				Conditions.Add("StructuralUnitDescription");
				AdditionalConditions.Insert("StructuralUnit", Conditions);
			EndIf;
			
			If GetFunctionalOption("UseStorageBins")
				And Common.HasObjectAttribute("Cell", FilledObject) Then
				FieldNames.Add("Cell");
				Conditions = New Array;
				Conditions.Add("CellDescription");
				If UseSeveralWarehouses Then
					Conditions.Add("StructuralUnitDescription");
				EndIf;
				AdditionalConditions.Insert("Cell", Conditions);
			EndIf;
			
			If Common.HasObjectAttribute("Products", FilledObject) Then
				FieldNames.Add("Products");
			EndIf;
			
			If Common.HasObjectAttribute("Document", FilledObject) Then
				FieldNames.Add("Document");
			EndIf;
			
			If GetFunctionalOption("UseCharacteristics")
				And Common.HasObjectAttribute("Characteristic", FilledObject) Then
				FieldNames.Add("Characteristic");
				Conditions = New Array;
				Conditions.Add("CharacteristicDescription");
				AdditionalConditions.Insert("Characteristic", Conditions);
			EndIf;
			
			If GetFunctionalOption("UseBatches")
				And Common.HasObjectAttribute("Batch", FilledObject) Then
				FieldNames.Add("Batch");
				Conditions = New Array;
				Conditions.Add("BatchDescription");
				AdditionalConditions.Insert("Batch", Conditions);
			EndIf;
			
			If Common.HasObjectAttribute("MeasurementUnit", FilledObject) Then
				FieldNames.Add("MeasurementUnit");
			EndIf;
			
		EndIf;
		
	ElsIf DataLoadSettings.IsCatalogImport Then
		
		If FillingObjectFullName = "Catalog.Products" Then
			
			FieldNames.Add("Products");
			
		ElsIf FillingObjectFullName = "Catalog.Counterparties" Then
			
			FieldNames.Add("Counterparty");
			
		ElsIf FillingObjectFullName = "Catalog.Leads" Then
			
			FieldNames.Add("Lead");
			
		ElsIf FillingObjectFullName = "Catalog.ProductsBatches" Then
			
			FieldNames.Add("Batch");	
			
		EndIf;
		
		ConditionalAppearanceText = ?(DataLoadSettings.CreateIfNotMatched, TextNewItem, TextSkipped);
		
	ElsIf DataLoadSettings.IsInformationRegisterImport Then
		
		If FillingObjectFullName = "InformationRegister.Prices" Then
			
			FieldNames.Add("Products");
			
		EndIf;
		
		ConditionalAppearanceText = NStr("en = '<Row will be skipped...>'; ru = '<Строка будет пропущена...>';pl = '<Wiersz zostanie pominięty...>';es_ES = '<Fila se saltará...>';es_CO = '<Fila se saltará...>';tr = '<Satır atlanacak...>';it = '<La riga verrà ignorata ...>';de = '<Zeile wird übersprungen...>'");
		
	ElsIf DataLoadSettings.IsChartOfAccountsImport Then
		
		FieldNames.Add("Account");
		
		ConditionalAppearanceText = ?(DataLoadSettings.CreateIfNotMatched, TextNewItem, TextSkipped);
		
	EndIf;
	
	For Each FieldName In FieldNames Do
		
		DCConditionalAppearanceItem = ThisObject.ConditionalAppearance.Items.Add();
		DCConditionalAppearanceItem.Use = True;
		
		DCFilterItem = DCConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
		DCFilterItem.LeftValue = New DataCompositionField(AttributePath + "." + FieldName);
		DCFilterItem.ComparisonType = DataCompositionComparisonType.NotFilled;
		
		DCFilterItem = DCConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
		ServiceFieldName = DataImportFromExternalSources.ServiceFieldNameImportToApplicationPossible();
		DCFilterItem.LeftValue = New DataCompositionField(AttributePath + "." + ServiceFieldName);
		DCFilterItem.ComparisonType = DataCompositionComparisonType.Equal;
		DCFilterItem.RightValue = True;
		
		Conditions = AdditionalConditions[FieldName];
		If Conditions <> Undefined Then
			For Each AdditionalField In Conditions Do
				DCFilterItem = DCConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
				DCFilterItem.LeftValue = New DataCompositionField(AttributePath + "." + AdditionalField);
				DCFilterItem.ComparisonType = DataCompositionComparisonType.Filled;
			EndDo;
		EndIf;
		
		DCConditionalAppearanceItem.Appearance.SetParameterValue(New DataCompositionParameter("Text"), ConditionalAppearanceText);
		DCConditionalAppearanceItem.Appearance.SetParameterValue(New DataCompositionParameter("TextColor"), WebColors.DarkGray);
		DCConditionalAppearanceItem.Appearance.SetParameterValue(New DataCompositionParameter("MarkIncomplete"), False);
		
		FormedFieldKD = DCConditionalAppearanceItem.Fields.Items.Add();
		FormedFieldKD.Field = New DataCompositionField(FieldName);
		
	EndDo;
	
	If DataLoadSettings.IsAccountingEntriesImport Then
		AccountingEntriesSettings = DataLoadSettings.AccountingEntriesSettings;
		MaxAnalyticalDimensionsNumber = AccountingEntriesSettings.MaxAnalyticalDimensionsNumber;
		IsCompound = (AccountingEntriesSettings.TypeOfEntries = Enums.ChartsOfAccountsTypesOfEntries.Compound);
		For Index = 1 To MaxAnalyticalDimensionsNumber Do
			If IsCompound Then
				SetupExtDimensionsConditionalAppearance(ThisObject.ConditionalAppearance, AttributePath, Index);
			Else
				SetupExtDimensionsConditionalAppearance(ThisObject.ConditionalAppearance, AttributePath, Index, "Dr");
				SetupExtDimensionsConditionalAppearance(ThisObject.ConditionalAppearance, AttributePath, Index, "Cr");
			EndIf;
		EndDo;
	EndIf;
	
EndProcedure

Procedure SetupExtDimensionsConditionalAppearance(ConditionalAppearance, AttributePath, Index, Suffix = "")
	
	ExtField = MasterAccountingClientServer.GetExtDimensionFieldName(Index, Suffix);
	ErrorField = MasterAccountingClientServer.GetExtDimensionFieldName(Index, Suffix, "Error");
	
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	
	FilterAndGroup = WorkWithForm.CreateFilterItemGroup(NewConditionalAppearance.Filter,
		DataCompositionFilterItemsGroupType.AndGroup);
	
	WorkWithForm.AddFilterItem(FilterAndGroup,
		AttributePath + "." + ExtField,
		Undefined,
		DataCompositionComparisonType.NotFilled);
		
	WorkWithForm.AddFilterItem(FilterAndGroup,
		AttributePath + "." + ErrorField,
		Undefined,
		DataCompositionComparisonType.Filled);
		
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, ExtField);
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "MarkIncomplete", True);
	
EndProcedure

Procedure ChangeConditionalDesignText(ConditionalAppearance, DataLoadSettings) Export
	
	If DataLoadSettings.IsTabularSectionImport Then
		
		Return;
		
	ElsIf DataLoadSettings.IsAccountingEntriesImport Then
		
		Return;
		
	ElsIf DataLoadSettings.IsInformationRegisterImport Then
		
		Return;
		
	ElsIf DataLoadSettings.IsCatalogImport Then
		
		If DataLoadSettings.FillingObjectFullName = "Catalog.Products" Then
			
			FieldName = "Products";
			
		ElsIf DataLoadSettings.FillingObjectFullName = "Catalog.Counterparties" Then
			
			FieldName = "Counterparty";
			
		EndIf;
		
		TextNewItem	= NStr("en = '<New item will be created>'; ru = '<Будет создан новый элемент>';pl = '<Zostanie utworzony nowy element>';es_ES = '<Nuevo artículo se creará>';es_CO = '<Nuevo artículo se creará>';tr = '<Yeni öğe oluşturulacak>';it = '<Verrà creato un nuovo elemento>';de = '<Neuer Artikel wird erstellt>'");
		TextSkipped	= NStr("en = '<Data will be skipped>'; ru = '<Данные будут пропущены>';pl = '<Dane zostaną pominięte>';es_ES = '<Datos se saltarán>';es_CO = '<Datos se saltarán>';tr = '<Veri atlanacak>';it = '<Verranno saltati dati>';de = '<Daten werden übersprungen>'");
		ConditionalAppearanceText = ?(DataLoadSettings.CreateIfNotMatched, TextNewItem, TextSkipped);
		
	ElsIf DataLoadSettings.IsChartOfAccountsImport Then
		
		FieldName = "Account";
		
		TextNewItem	= NStr("en = '<New item will be created>'; ru = '<Будет создан новый элемент>';pl = '<Zostanie utworzony nowy element>';es_ES = '<Nuevo artículo se creará>';es_CO = '<Nuevo artículo se creará>';tr = '<Yeni öğe oluşturulacak>';it = '<Verrà creato un nuovo elemento>';de = '<Neuer Artikel wird erstellt>'");
		TextSkipped	= NStr("en = '<Data will be skipped>'; ru = '<Данные будут пропущены>';pl = '<Dane zostaną pominięte>';es_ES = '<Datos se saltarán>';es_CO = '<Datos se saltarán>';tr = '<Veri atlanacak>';it = '<Verranno saltati dati>';de = '<Daten werden übersprungen>'");
		ConditionalAppearanceText = ?(DataLoadSettings.CreateIfNotMatched, TextNewItem, TextSkipped);
		
	EndIf;
	
	SearchItem = New DataCompositionField(FieldName);
	For Each ConditionalAppearanceItem In ConditionalAppearance.Items Do
		
		ThisIsTargetFormat = False;
		For Each MadeOutField In ConditionalAppearanceItem.Fields.Items Do
			
			If MadeOutField.Field = SearchItem Then
				
				ThisIsTargetFormat = True;
				Break;
				
			EndIf;
			
		EndDo;
		
		If ThisIsTargetFormat Then
			
			ConditionalAppearanceItem.Appearance.SetParameterValue(New DataCompositionParameter("Text"), ConditionalAppearanceText);
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure WhenDeterminingDataImportForm(DataImportFormNameFromExternalSources, FillingObjectFullName, FilledObject) Export
	
	
	
EndProcedure

Procedure OverrideDataImportFieldsFilling(ImportFieldsTable, DataLoadSettings) Export
	
	
	
EndProcedure

Procedure WhenAddingServiceFields(ServiceFieldsGroup, FillingObjectFullName) Export
	
	
	
EndProcedure

Procedure AfterAddingItemsToMatchesTables(ThisObject, DataLoadSettings) Export
	
	If DataLoadSettings.FillingObjectFullName = "Catalog.Products" Then
		
		ThisObject.Items["Parent"].ChoiceForm = "Catalog.Products.Form.GroupChoiceForm";
		
	ElsIf DataLoadSettings.FillingObjectFullName = "Catalog.Counterparties"  Then
		
		ThisObject.Items["Parent"].ChoiceForm = "Catalog.Counterparties.Form.GroupChoiceForm.";
		
	ElsIf DataLoadSettings.FillingObjectFullName = "Catalog.Cells"  Then
		
		ThisObject.Items["Parent"].ChoiceForm = "Catalog.Cells.Form.ChoiceForm.";
		
	ElsIf DataLoadSettings.FillingObjectFullName = "Document.SupplierInvoice.TabularSection.Inventory" Then
		
		ArrayProductsTypes = New Array;
		ArrayProductsTypes.Add(Enums.ProductsTypes.InventoryItem);
		
		NewParameter = New ChoiceParameter("Filter.ProductsType", ArrayProductsTypes);
		
		ParameterArray = New Array;
		ParameterArray.Add(NewParameter);
		
		ThisObject.Items["Products"].ChoiceParameters = New FixedArray(ParameterArray);
		
	ElsIf DataLoadSettings.FillingObjectFullName = "Document.SupplierInvoice.TabularSection.Expenses" Then
		
		ArrayProductsTypes = New Array;
		ArrayProductsTypes.Add(Enums.ProductsTypes.Service);
		
		NewParameter = New ChoiceParameter("Filter.ProductsType", ArrayProductsTypes);
		
		ParameterArray = New Array;
		ParameterArray.Add(NewParameter);
		
		ThisObject.Items["Products"].ChoiceParameters = New FixedArray(ParameterArray);
		
	EndIf;
	
	ChoiceParameterLinksFilterArray = New Array;
	ChoiceParameterLinksFilterArray.Add("Filter.Owner");
	
	Parameters = New Structure;
	Parameters.Insert("Object", ThisObject);
	Parameters.Insert("MetadataObject", Metadata.FindByFullName(DataLoadSettings.FillingObjectFullName));
	Parameters.Insert("MetadataAttribute", "Characteristic");
	Parameters.Insert("FormAttribute", "Characteristic");
	Parameters.Insert("ChoiceParameterLinksFilterArray", ChoiceParameterLinksFilterArray);
	
	SetupAttributeChoiceParameterLinksByMetadata(Parameters);
	
EndProcedure

Procedure WhenDeterminingUsageMode(UseTogether) Export
	
	UseTogether = True;
	
EndProcedure

Procedure DataImportFieldsFromExternalSource(ImportFieldsTable, DataLoadSettings) Export
	
	FillingObjectFullName = DataLoadSettings.FillingObjectFullName;
	FilledObject = Metadata.FindByFullName(FillingObjectFullName);
	
	TypeDescriptionString8		= New TypeDescription("String", , , , New StringQualifiers(8));
	TypeDescriptionString9		= New TypeDescription("String", , , , New StringQualifiers(9));
	TypeDescriptionString10		= New TypeDescription("String", , , , New StringQualifiers(10));
	TypeDescriptionString11		= New TypeDescription("String", , , , New StringQualifiers(11));
	TypeDescriptionString13		= New TypeDescription("String", , , , New StringQualifiers(13));
	TypeDescriptionString17		= New TypeDescription("String", , , , New StringQualifiers(17));
	TypeDescriptionString20		= New TypeDescription("String", , , , New StringQualifiers(20));
	TypeDescriptionString25 	= New TypeDescription("String", , , , New StringQualifiers(25));
	TypeDescriptionString30 	= New TypeDescription("String", , , , New StringQualifiers(30));
	TypeDescriptionString50 	= New TypeDescription("String", , , , New StringQualifiers(50));
	TypeDescriptionString100	= New TypeDescription("String", , , , New StringQualifiers(100));
	TypeDescriptionString120	= New TypeDescription("String", , , , New StringQualifiers(120));
	TypeDescriptionString150 	= New TypeDescription("String", , , , New StringQualifiers(150));
	TypeDescriptionString200 	= New TypeDescription("String", , , , New StringQualifiers(200));
	TypeDescriptionString1000 	= New TypeDescription("String", , , , New StringQualifiers(100));
	TypeDescriptionNumber10_0	= New TypeDescription("Number", , , , New NumberQualifiers(10, 0));
	TypeDescriptionNumber10_3	= New TypeDescription("Number", , , , New NumberQualifiers(10, 3));
	TypeDescriptionNumber15_0	= New TypeDescription("Number", , , , New NumberQualifiers(15, 0, AllowedSign.Nonnegative));
	TypeDescriptionNumber15_2	= New TypeDescription("Number", , , , New NumberQualifiers(15, 2));
	TypeDescriptionNumber15_3 	= New TypeDescription("Number", , , , New NumberQualifiers(15, 3));
	TypeDescriptionNumber4_2	= New TypeDescription("Number", , , , New NumberQualifiers(4, 2));
	TypeDescriptionDate 		= New TypeDescription("Date", , , , New DateQualifiers(DateFractions.Date));
	TypeDescriptionDateTime		= New TypeDescription("Date", , , , New DateQualifiers(DateFractions.DateTime));
	TypeDescriptionBoolean 		= New TypeDescription("Boolean");
	
	If DataLoadSettings.FillingObjectFullName = "Document.SalesTarget.TabularSection.Inventory" Then
		
		SalesGoalSettingAttributes = DataLoadSettings.SalesGoalSettingAttributes;
		
		For Each Dimension In SalesGoalSettingAttributes.Dimensions Do
			
			TypeDescriptionColumn = SalesTargetingClientServer.DimensionTypeDescription(Dimension);
			
			If Dimension = "Products" Then
			
				DataImportFromExternalSources.AddImportDescriptionField(
					ImportFieldsTable, "Barcode", NStr("en = 'Barcode'; ru = 'Штрихкод';pl = 'Kod kreskowy';es_ES = 'Código de barras';es_CO = 'Código de barras';tr = 'Barkod';it = 'Codice a barre';de = 'Barcode'"),
					TypeDescriptionString200, TypeDescriptionColumn,
					"Products", NStr("en = 'Product'; ru = 'Номенклатура';pl = 'Produkt';es_ES = 'Producto';es_CO = 'Producto';tr = 'Ürün';it = 'Articolo';de = 'Produkt'"), 1, , True);
				
				DataImportFromExternalSources.AddImportDescriptionField(
					ImportFieldsTable, "SKU", NStr("en = 'ID (item #)'; ru = 'Идентификатор (артикул)';pl = 'ID (pozycja nr)';es_ES = 'Identificador (artículo №)';es_CO = 'Identificador (artículo №)';tr = 'Kimlik (ürün no)';it = 'ID (elemento #)';de = 'ID (Artikel Nr.)'"),
					TypeDescriptionString25, TypeDescriptionColumn,
					"Products", NStr("en = 'Product'; ru = 'Номенклатура';pl = 'Produkt';es_ES = 'Producto';es_CO = 'Producto';tr = 'Ürün';it = 'Articolo';de = 'Produkt'"), 2, , True);
				
				DataImportFromExternalSources.AddImportDescriptionField(
					ImportFieldsTable, "ProductsDescription", NStr("en = 'Description'; ru = 'Наименование';pl = 'Opis';es_ES = 'Descripción';es_CO = 'Descripción';tr = 'Tanım';it = 'Descrizione';de = 'Beschreibung'"),
					TypeDescriptionString100, TypeDescriptionColumn,
					"Products", NStr("en = 'Product'; ru = 'Номенклатура';pl = 'Produkt';es_ES = 'Producto';es_CO = 'Producto';tr = 'Ürün';it = 'Articolo';de = 'Produkt'"), 3, , True);
				
				DataImportFromExternalSources.AddImportDescriptionField(
					ImportFieldsTable, "ProductsDescriptionFull", NStr("en = 'Detailed description'; ru = 'Подробное описание';pl = 'Szczegółowy opis';es_ES = 'Descripción detallada';es_CO = 'Descripción detallada';tr = 'Ayrıntılı açıklama';it = 'Descrizione dettagliata';de = 'Detaillierte Beschreibung'"),
					TypeDescriptionString1000, TypeDescriptionColumn,
					"Products", NStr("en = 'Product'; ru = 'Номенклатура';pl = 'Produkt';es_ES = 'Producto';es_CO = 'Producto';tr = 'Ürün';it = 'Articolo';de = 'Produkt'"), 4, , True);
				
				If GetFunctionalOption("UseCharacteristics") Then
					TypeDescriptionColumn = New TypeDescription("CatalogRef.ProductsCharacteristics");
					DataImportFromExternalSources.AddImportDescriptionField(
						ImportFieldsTable, "Characteristic", NStr("en = 'Variant (name)'; ru = 'Вариант (наименование)';pl = 'Wariant (nazwa)';es_ES = 'Variante (nombre)';es_CO = 'Variante (nombre)';tr = 'Varyant (isim)';it = 'Variante (nome)';de = 'Variante (Name)'"),
						TypeDescriptionString150, TypeDescriptionColumn);
				EndIf;
			
			Else
				
				DataImportFromExternalSources.AddImportDescriptionField(
					ImportFieldsTable, Dimension, Enums.SalesGoalDimensions[Dimension],
					TypeDescriptionString150, TypeDescriptionColumn, , , , True);
				
			EndIf;
			
		EndDo;
		
		If SalesGoalSettingAttributes.SpecifyQuantity Then
			
			// Measurement unit
			TypeDescriptionColumn = New TypeDescription("CatalogRef.UOMClassifier"
										+ ?(GetFunctionalOption("UseSeveralUnitsForProduct"), ", CatalogRef.UOM", ""));
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, "MeasurementUnit", NStr("en = 'Unit of measure'; ru = 'Ед. изм.';pl = 'Jednostka miary';es_ES = 'Unidad de medida';es_CO = 'Unidad de medida';tr = 'Ölçü birimi';it = 'Unità di misura';de = 'Maßeinheit'"),
				TypeDescriptionString25, TypeDescriptionColumn, , , , True, ,
				GetFunctionalOption("UseSeveralUnitsForProduct"));
		
			//Price
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, "Price", NStr("en = 'Price'; ru = 'Цена';pl = 'Cena';es_ES = 'Precio';es_CO = 'Precio';tr = 'Fiyat';it = 'Prezzo';de = 'Preis'"),
				TypeDescriptionString25, TypeDescriptionNumber15_2, , , , True);
			
		EndIf;
		
		For Index = 0 To DataLoadSettings.Periods.Count() - 1 Do
			
			If SalesGoalSettingAttributes.SpecifyQuantity Then
				
				DataImportFromExternalSources.AddImportDescriptionField(
					ImportFieldsTable, "ColumnQuantity_" + Format(Index, "NZ=0; NG=0"),
					DataLoadSettings.Periods.Get(Index) + ": " + NStr("en = 'Quantity'; ru = 'Количество';pl = 'Ilość';es_ES = 'Cantidad';es_CO = 'Cantidad';tr = 'Miktar';it = 'Quantità';de = 'Menge'"),
					TypeDescriptionString25, TypeDescriptionNumber15_3);
				
			EndIf;
			
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, "ColumnAmount_" + Format(Index, "NZ=0; NG=0"),
				DataLoadSettings.Periods.Get(Index) + ": " + NStr("en = 'Amount'; ru = 'Сумма';pl = 'Kwota';es_ES = 'Importe';es_CO = 'Importe';tr = 'Tutar';it = 'Importo';de = 'Betrag'"),
				TypeDescriptionString25, TypeDescriptionNumber15_2);
			
		EndDo;
		
	ElsIf DataLoadSettings.FillingObjectFullName = "Catalog.Counterparties" Then 
		
		TypeDescriptionColumn = New TypeDescription("CatalogRef.Counterparties");
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "Parent", NStr("en = 'Group'; ru = 'Группа';pl = 'Grupa';es_ES = 'Grupo';es_CO = 'Grupo';tr = 'Grup';it = 'Gruppo';de = 'Gruppe'"),
			TypeDescriptionString100, TypeDescriptionColumn);
		
		TypeDescriptionColumn = New TypeDescription("Boolean");
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "ThisIsInd", NStr("en = 'Is this an individual?'; ru = 'Это физическое лицо?';pl = 'Czy to osoba fizyczna?';es_ES = '¿Es un particular?';es_CO = '¿Es un particular?';tr = 'Gerçek kişi mi?';it = 'Si tratta di una persona fisica?';de = 'Ist das eine Natürliche Person?'"),
			TypeDescriptionString10, TypeDescriptionColumn);
		
		TypeDescriptionColumn = New TypeDescription("CatalogRef.Counterparties");
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "TIN", NStr("en = 'TIN'; ru = 'ИНН';pl = 'NIP';es_ES = 'NIF';es_CO = 'NIF';tr = 'VKN';it = 'Cod.Fiscale';de = 'Steuernummer'"),
			TypeDescriptionString25, TypeDescriptionColumn,
			"Counterparty", NStr("en = 'Counterparty'; ru = 'Контрагент';pl = 'Kontrahent';es_ES = 'Contraparte';es_CO = 'Contraparte';tr = 'Cari hesap';it = 'Controparte';de = 'Geschäftspartner'"), 1, , True);
			
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "CounterpartyDescription", NStr("en = 'Description'; ru = 'Наименование';pl = 'Opis';es_ES = 'Descripción';es_CO = 'Descripción';tr = 'Tanım';it = 'Descrizione';de = 'Beschreibung'"),
			TypeDescriptionString100, TypeDescriptionColumn,
			"Counterparty", NStr("en = 'Counterparty'; ru = 'Контрагент';pl = 'Kontrahent';es_ES = 'Contraparte';es_CO = 'Contraparte';tr = 'Cari hesap';it = 'Controparte';de = 'Geschäftspartner'"), 3, True, True);
			
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "BankAccount", NStr("en = 'Bank account'; ru = 'Банковский счет';pl = 'Rachunek bankowy';es_ES = 'Cuenta bancaria';es_CO = 'Cuenta bancaria';tr = 'Banka hesabı';it = 'Conto corrente';de = 'Bankkonto'"),
			TypeDescriptionString50, TypeDescriptionColumn,
			"Counterparty", NStr("en = 'Counterparty'; ru = 'Контрагент';pl = 'Kontrahent';es_ES = 'Contraparte';es_CO = 'Contraparte';tr = 'Cari hesap';it = 'Controparte';de = 'Geschäftspartner'"), 4, , True);
		
		If GetFunctionalOption("UseCounterpartiesAccessGroups") Then
			
			TypeDescriptionColumn = New TypeDescription("CatalogRef.CounterpartiesAccessGroups");
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, "AccessGroup", NStr("en = 'Counterparty access group'; ru = 'Группа доступа контрагента';pl = 'Grupa dostępu kontrahenta';es_ES = 'Grupo de acceso de la contraparte';es_CO = 'Grupo de acceso de la contraparte';tr = 'Cari hesap erişim grubu';it = 'Gruppo di accesso delle controparti';de = 'Zugriffsgruppe Geschäftspartner'"),
				TypeDescriptionString200, TypeDescriptionColumn, , , , True);
		EndIf;
		
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "Comment", NStr("en = 'Comment'; ru = 'Комментарий';pl = 'Uwagi';es_ES = 'Comentario';es_CO = 'Comentario';tr = 'Yorum';it = 'Commento';de = 'Kommentar'"),
			TypeDescriptionString200, TypeDescriptionString200);
		
		TypeDescriptionColumn = New TypeDescription("Boolean");
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "DoOperationsByContracts", NStr("en = 'Accounting by contracts'; ru = 'Вести расчеты по договорам';pl = 'Rozliczenia według kontraktów';es_ES = 'Contabilidad por contratos';es_CO = 'Contabilidad por contratos';tr = 'Sözleşmelere göre muhasebe';it = 'Contabilità per contratti';de = 'Abrechnung nach Verträgen'"),
			TypeDescriptionString10, TypeDescriptionColumn);
		
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "DoOperationsByOrders", NStr("en = 'Accounting by orders'; ru = 'Вести расчеты по заказам';pl = 'Rozliczenia według zamówień';es_ES = 'Contabilidad por pedidos';es_CO = 'Contabilidad por pedidos';tr = 'Siparişlere göre muhasebe';it = 'Contabilità per ordini';de = 'Abrechnung nach Aufträgen'"),
			TypeDescriptionString10, TypeDescriptionColumn);

		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "Phone", NStr("en = 'Phone'; ru = 'Телефон';pl = 'Telefon';es_ES = 'Teléfono';es_CO = 'Teléfono';tr = 'Telefon';it = 'Telefono';de = 'Telefon'"),
			TypeDescriptionString100, TypeDescriptionString100);
			
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "EMail_Address", NStr("en = 'Email'; ru = 'Эл. почта';pl = 'E-mail';es_ES = 'Correo electrónico';es_CO = 'Correo electrónico';tr = 'E-posta';it = 'Email';de = 'E-Mail'"),
			TypeDescriptionString100, TypeDescriptionString100);
		
		TypeDescriptionColumn = New TypeDescription("Boolean");
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "Customer", NStr("en = 'Customer'; ru = 'Покупатель';pl = 'Nabywca';es_ES = 'Cliente';es_CO = 'Cliente';tr = 'Müşteri';it = 'Cliente';de = 'Kunde'"),
			TypeDescriptionString10, TypeDescriptionColumn);
			
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "Supplier", NStr("en = 'Supplier'; ru = 'Поставщик';pl = 'Dostawca';es_ES = 'Proveedor';es_CO = 'Proveedor';tr = 'Tedarikçi';it = 'Fornitore';de = 'Lieferant'"),
			TypeDescriptionString10, TypeDescriptionColumn);
			
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "OtherRelationship", NStr("en = 'Other relationship'; ru = 'Прочие отношения';pl = 'Inna relacja';es_ES = 'Otras relaciones';es_CO = 'Otras relaciones';tr = 'Diğer ilişkiler';it = 'Altre relazioni';de = 'Andere Beziehung'"),
			TypeDescriptionString10, TypeDescriptionColumn);
		
		TypeDescriptionColumn = New TypeDescription("EnumRef.BaselineDateForPayment");
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "BaselineDate", NStr("en = 'Baseline date'; ru = 'Базисная дата';pl = 'Data bazowa';es_ES = 'Fecha de referencia';es_CO = 'Fecha de referencia';tr = 'Başlangıç tarihi';it = 'Data di base';de = 'Basisdatum'"),
			TypeDescriptionString50, TypeDescriptionColumn);
			
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "DateOfBirth", NStr("en = 'Birth date'; ru = 'Дата рождения';pl = 'Data urodzenia';es_ES = 'Fecha de nacimiento';es_CO = 'Fecha de nacimiento';tr = 'Doğum tarihi';it = 'Data di nascita';de = 'Geburtsdatum'"),
			TypeDescriptionString25, TypeDescriptionDate);
			
		TypeDescriptionColumn = New TypeDescription("EnumRef.DeliveryOptions");
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "DefaultDeliveryOption", NStr("en = 'Delivery option'; ru = 'Способ доставки';pl = 'Opcja dostawy';es_ES = 'Opción de la entrega';es_CO = 'Opción de la entrega';tr = 'Teslimat seçeneği';it = 'Opzione di consegna';de = 'Liefermöglichkeit'"),
			TypeDescriptionString50, TypeDescriptionColumn);
			
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "DescriptionFull", NStr("en = 'Legal name'; ru = 'Юридическое наименование';pl = 'Nazwa prawna';es_ES = 'Nombre legal';es_CO = 'Nombre legal';tr = 'Yasal unvan';it = 'Nome legale';de = 'Offizieller Name'"),
			TypeDescriptionString200, TypeDescriptionString200);
			
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "EORI", NStr("en = 'EORI'; ru = 'EORI';pl = 'EORI';es_ES = 'EORI';es_CO = 'EORI';tr = 'EORI';it = 'EORI';de = 'EORI'"),
			TypeDescriptionString17, TypeDescriptionString17);
			
		TypeDescriptionColumn = New TypeDescription("EnumRef.Gender");
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "Gender", NStr("en = 'Gender'; ru = 'Род';pl = 'Płeć';es_ES = 'Género';es_CO = 'Género';tr = 'Cinsiyet';it = 'Genere';de = 'Geschlecht'"),
			TypeDescriptionString25, TypeDescriptionColumn);
			
		TypeDescriptionColumn = New TypeDescription("CatalogRef.LegalForms");
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "LegalForm", NStr("en = 'Legal form'; ru = 'Организационно-правовая форма';pl = 'Forma prawna';es_ES = 'Formulario legal';es_CO = 'Formulario legal';tr = 'Yasal form';it = 'Forma legale';de = 'Rechtsform'"),
			TypeDescriptionString100, TypeDescriptionColumn);
			
		TypeDescriptionColumn = New TypeDescription("CatalogRef.PaymentMethods");
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "PaymentMethod", NStr("en = 'Payment method'; ru = 'Способ оплаты';pl = 'Metoda płatności';es_ES = 'Método de pago';es_CO = 'Método de pago';tr = 'Ödeme yöntemi';it = 'Metodo di pagamento';de = 'Zahlungsmethode'"),
			TypeDescriptionString50, TypeDescriptionColumn);
			
		TypeDescriptionColumn = New TypeDescription("CatalogRef.PriceTypes");
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "PriceKind", NStr("en = 'Sale price type'; ru = 'Тип цен продажи';pl = 'Rodzaj ceny sprzedaży';es_ES = 'Tipo de precio de venta';es_CO = 'Tipo de precio de venta';tr = 'Satış fiyatı türü';it = 'Tipo di prezzo di vendita';de = 'Verkaufspreistyp'"),
			TypeDescriptionString100, TypeDescriptionColumn);
			
		TypeDescriptionColumn = New TypeDescription("CatalogRef.WorldCountries");
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "RegistrationCountry", NStr("en = 'Registration country'; ru = 'Страна регистрации';pl = 'Kraj rejestracji';es_ES = 'País de registro';es_CO = 'País de registro';tr = 'Kayıt ülkesi';it = 'Paese di registrazione';de = 'Anmeldeland'"),
			TypeDescriptionString100, TypeDescriptionColumn);
			
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "RegistrationNumber", NStr("en = 'Registration number'; ru = 'ОГРН';pl = 'Numer rejestracyjny';es_ES = 'Número de registro';es_CO = 'Número de registro';tr = 'Kayıt numarası';it = 'Numero di registrazione';de = 'Registriernummer'"),
			TypeDescriptionString13, TypeDescriptionString13);
			
		TypeDescriptionColumn = New TypeDescription("CatalogRef.SalesTerritories");
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "SalesTerritory", NStr("en = 'Sales territory'; ru = 'Территория продаж';pl = 'Terytorium sprzedaży';es_ES = 'Territorio de ventas';es_CO = 'Territorio de ventas';tr = 'Satış bölgesi';it = 'Territorio di vendita';de = 'Verkaufsgebiet'"),
			TypeDescriptionString100, TypeDescriptionColumn);
			
		TypeDescriptionColumn = New TypeDescription("CatalogRef.Employees");
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "Responsible", NStr("en = 'Person responsible'; ru = 'Ответственный';pl = 'Osoba odpowiedzialna';es_ES = 'Persona responsable';es_CO = 'Persona responsable';tr = 'Sorumlu kişi';it = 'Persona responsabile';de = 'Verantwortliche Person'"),
			TypeDescriptionString100, TypeDescriptionColumn);
			
		TypeDescriptionColumn = New TypeDescription("CatalogRef.Employees");
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "SalesRep", NStr("en = 'Sales rep'; ru = 'Торговый представитель';pl = 'Przedstawiciel handlowy';es_ES = 'Agente de ventas';es_CO = 'Agente de ventas';tr = 'Satış temsilcisi';it = 'Agente di vendita';de = 'Vertriebsmitarbeiter'"),
			TypeDescriptionString100, TypeDescriptionColumn);
			
		TypeDescriptionColumn = New TypeDescription("CatalogRef.Currencies");
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "SettlementsCurrency", NStr("en = 'Currency'; ru = 'Валюта';pl = 'Waluta';es_ES = 'Moneda';es_CO = 'Moneda';tr = 'Para birimi';it = 'Valuta';de = 'Währung'"),
			TypeDescriptionString100, TypeDescriptionColumn);
			
		TypeDescriptionColumn = New TypeDescription("CatalogRef.SupplierPriceTypes");
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "SupplierPriceTypes", NStr("en = 'Purchase price type'; ru = 'Тип цен закупки';pl = 'Typ ceny zakupu';es_ES = 'Tipo de precio de compra';es_CO = 'Tipo de precio de compra';tr = 'Satın alma fiyatı türü';it = 'Tipo di prezzo di acquisto';de = 'Einkaufspreistyp'"),
			TypeDescriptionString100, TypeDescriptionColumn);
			
		If GetFunctionalOption("UseVAT") Then
			
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, "VATNumber", NStr("en = 'VAT ID'; ru = 'Номер плательщика НДС';pl = 'Numer VAT';es_ES = 'Identificador del IVA';es_CO = 'Identificador de IVA';tr = 'KDV kodu';it = 'P.IVA';de = 'USt.- IdNr.'"),
				TypeDescriptionString25, TypeDescriptionString25);
			
			TypeDescriptionColumn = New TypeDescription("EnumRef.VATTaxationTypes");
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, "VATTaxation", NStr("en = 'Tax category'; ru = 'Налогообложение';pl = 'Rodzaj opodatkowania VAT';es_ES = 'Categoría de impuestos';es_CO = 'Categoría de impuestos';tr = 'Vergi kategorisi';it = 'Categoria di imposta';de = 'Steuerkategorie'"),
				TypeDescriptionString100, TypeDescriptionColumn);
				
		EndIf;
			
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "CreditLimit", NStr("en = 'Credit limit'; ru = 'Кредитный лимит';pl = 'Limit kredytowy';es_ES = 'Límite de crédito';es_CO = 'Límite de crédito';tr = 'Kredi limiti';it = 'Limite credito';de = 'Kreditlimit'"),
			TypeDescriptionNumber15_2, TypeDescriptionNumber15_2);
			
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "OverdueLimit", NStr("en = 'Overdue limit'; ru = 'Лимит просрочки';pl = 'Zaległy limit';es_ES = 'Límite de atraso';es_CO = 'Límite de atraso';tr = 'Vadesi geçmiş limiti';it = 'Limite scoperto';de = 'Überfälligkeitsgrenze'"),
			TypeDescriptionNumber15_2, TypeDescriptionNumber15_2);
			
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "TransactionLimit", NStr("en = 'Transaction limit'; ru = 'Лимит транзакции';pl = 'Limit transakcji';es_ES = 'Límite de transacción';es_CO = 'Límite de transacción';tr = 'İşlem limiti';it = 'Limite transazione';de = 'Transaktionslimit'"),
			TypeDescriptionNumber15_2, TypeDescriptionNumber15_2);
			
		If GetFunctionalOption("UseSalesTax") Then
			TypeDescriptionColumn = New TypeDescription("CatalogRef.SalesTaxRates");
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, "SalesTaxRate", NStr("en = 'Sales tax rate'; ru = 'Ставка налога с продаж';pl = 'Stawka podatku od sprzedaży';es_ES = 'Tasa de impuesto sobre ventas';es_CO = 'Tasa de impuesto sobre ventas';tr = 'Satış vergisi oranı';it = 'Aliquota imposta sulle vendite';de = 'Umsatzsteuersatz'"),
				TypeDescriptionString100, TypeDescriptionColumn);
		EndIf;
			
		// AdditionalAttributes
		DataImportFromExternalSources.PrepareMapForAdditionalAttributes(DataLoadSettings, Catalogs.AdditionalAttributesAndInfoSets.Catalog_Counterparties);
		If DataLoadSettings.AdditionalAttributeDescription.Count() > 0 Then
			
			FieldName = DataImportFromExternalSources.AdditionalAttributesForAddingFieldsName();
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, FieldName, NStr("en = 'Additional attributes'; ru = 'Доп. реквизиты';pl = 'Dodatkowe atrybuty';es_ES = 'Atributos adicionales';es_CO = 'Atributos adicionales';tr = 'Ek öznitelikler';it = 'Attributi aggiuntivi';de = 'Zusätzliche Attribute'"),
				TypeDescriptionString150, TypeDescriptionString11, , , , , , , True,
				Catalogs.AdditionalAttributesAndInfoSets.Catalog_Counterparties);
		EndIf;
		
	ElsIf FillingObjectFullName = "Catalog.Cells" Then
		
		TypeDescriptionColumn = New TypeDescription("CatalogRef.Cells");
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "Parent", NStr("en = 'Group'; ru = 'Группа';pl = 'Grupa';es_ES = 'Grupo';es_CO = 'Grupo';tr = 'Grup';it = 'Gruppo';de = 'Gruppe'"),
			TypeDescriptionString100, TypeDescriptionColumn);
			
		TypeDescriptionColumn = New TypeDescription("CatalogRef.Cells");
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "Code", NStr("en = 'Code'; ru = 'Код';pl = 'Kod';es_ES = 'Código';es_CO = 'Código';tr = 'Kod';it = 'Codice';de = 'Code'"),
			TypeDescriptionString9, TypeDescriptionColumn,
			"Cells", NStr("en = 'Storage bin'; ru = 'Складская ячейка';pl = 'Komórka magazynowa';es_ES = 'Área de almacenamiento';es_CO = 'Área de almacenamiento';tr = 'Depo';it = 'Contenitore di magazzino';de = 'Lagerplatz'"), 1, , True);
			
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "CellsDescription", NStr("en = 'Description'; ru = 'Наименование';pl = 'Opis';es_ES = 'Descripción';es_CO = 'Descripción';tr = 'Tanım';it = 'Descrizione';de = 'Beschreibung'"),
			TypeDescriptionString50, TypeDescriptionColumn,
			"Cells", NStr("en = 'Storage bin'; ru = 'Складская ячейка';pl = 'Komórka magazynowa';es_ES = 'Área de almacenamiento';es_CO = 'Área de almacenamiento';tr = 'Depo';it = 'Contenitore di magazzino';de = 'Lagerplatz'"), 2, , True);
			
		TypeDescriptionColumn = New TypeDescription("CatalogRef.BusinessUnits");
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "Owner", NStr("en = 'Business unit / warehouse'; ru = 'Структурная единица / склад';pl = 'Jednostka biznesowa / magazyn';es_ES = 'Unidad empresarial / almacén';es_CO = 'Unidad de negocio / almacén';tr = 'Departman / ambar';it = 'Business unit / magazzino';de = 'Abteilung / Lager'"),
			TypeDescriptionString50, TypeDescriptionColumn, , , , , True);
			
	ElsIf FillingObjectFullName = "Catalog.SalesTaxRates" Then
		
		TypeDescriptionColumn = New TypeDescription("CatalogRef.SalesTaxRates");
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "Description", NStr("en = 'Description'; ru = 'Наименование';pl = 'Opis';es_ES = 'Descripción';es_CO = 'Descripción';tr = 'Tanım';it = 'Descrizione';de = 'Beschreibung'"),
			TypeDescriptionString100, TypeDescriptionColumn,
			"SalesTaxRates", NStr("en = 'Sales tax rate'; ru = 'Ставка налога с продаж';pl = 'Stawka podatku od sprzedaży';es_ES = 'Tasa de impuesto sobre ventas';es_CO = 'Tasa de impuesto sobre ventas';tr = 'Satış vergisi oranı';it = 'Aliquota imposta sulle vendite';de = 'Umsatzsteuersatz'"), 1, , True);
			
		TypeDescriptionColumn = New TypeDescription("CatalogRef.TaxTypes");
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "Agency", NStr("en = 'Tax agency'; ru = 'Налоговый орган';pl = 'Rodzaj podatku';es_ES = 'Agencia tributaria';es_CO = 'Agencia tributaria';tr = 'Vergi idaresi';it = 'Agenzia fiscale';de = 'Steueramt'"), 
			TypeDescriptionString50, TypeDescriptionColumn);
			
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "Rate", NStr("en = 'Rate'; ru = 'Ставка';pl = 'Stawka';es_ES = 'Tasa';es_CO = 'Tasa';tr = 'Oran';it = 'Tasso di cambio';de = 'Größe'"),
			TypeDescriptionString10, TypeDescriptionNumber4_2);
			
		TypeDescriptionColumn = New TypeDescription("Boolean");
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "Combined", NStr("en = 'Combined'; ru = 'Вместе';pl = 'Razem';es_ES = 'Junto';es_CO = 'Junto';tr = 'Birlikte';it = 'Combinato';de = 'Zusammen'"),
			TypeDescriptionString10, TypeDescriptionColumn);
			
	// begin Drive.FullVersion
		
	ElsIf FillingObjectFullName = "Catalog.CompanyResourceTypes" Then
		
		TypeDescriptionColumn = New TypeDescription("CatalogRef.CompanyResourceTypes");
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "Description", NStr("en = 'Description'; ru = 'Наименование';pl = 'Opis';es_ES = 'Descripción';es_CO = 'Descripción';tr = 'Tanım';it = 'Descrizione';de = 'Beschreibung'"),
			TypeDescriptionString50, TypeDescriptionColumn,
			"CompanyResourceType", NStr("en = 'Work center type'; ru = 'Тип рабочего центра';pl = 'Typ gniazda produkcyjnego';es_ES = 'Tipo de centro de trabajo';es_CO = 'Tipo de centro de trabajo';tr = 'İş merkezi türü';it = 'Tipo di centro di lavoro';de = 'Arbeitsabschnittstyp'"), 1, , True);
			
		TypeDescriptionColumn = New TypeDescription("CatalogRef.BusinessUnits");
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "BusinessUnit", NStr("en = 'Department'; ru = 'Подразделение';pl = 'Dział';es_ES = 'Departamento';es_CO = 'Departamento';tr = 'Bölüm';it = 'Reparto';de = 'Abteilung'"), 
			TypeDescriptionString50, TypeDescriptionColumn, , , , True);
			
		TypeDescriptionColumn = New TypeDescription("Boolean");
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "PlanningOnWorkcentersLevel", NStr("en = 'Planning on work centers level'; ru = 'Планирование на уровне рабочих центров';pl = 'Planowanie na poziomie gniazd produkcyjnych';es_ES = 'Planificación a nivel de los centros de trabajo';es_CO = 'Planificación a nivel de los centros de trabajo';tr = 'İş merkezleri düzeyinde planlama';it = 'Pianificazione a livello di centro di costo';de = 'Planung auf der Arbeitsabschnittsebene'"),
			TypeDescriptionString10, TypeDescriptionColumn);
			
		TypeDescriptionColumn = New TypeDescription("CatalogRef.Calendars");
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "Schedule", NStr("en = 'Work schedule'; ru = 'График работы';pl = 'Harmonogram pracy';es_ES = 'Horario de trabajo';es_CO = 'Horario de trabajo';tr = 'Çalışma programı';it = 'Grafico di lavoro';de = 'Arbeitszeitplan'"), 
			TypeDescriptionString100, TypeDescriptionColumn);
			
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "Capacity", NStr("en = 'Capacity'; ru = 'Мощность';pl = 'Zdolność produkcyjna';es_ES = 'Capacidad';es_CO = 'Capacidad';tr = 'Kapasite';it = 'Capacità';de = 'Kapazität'"),
			TypeDescriptionString17, TypeDescriptionNumber15_2);
			
	ElsIf FillingObjectFullName = "Catalog.CompanyResources" Then
		
		TypeDescriptionColumn = New TypeDescription("CatalogRef.CompanyResources");
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "Description", NStr("en = 'Description'; ru = 'Наименование';pl = 'Opis';es_ES = 'Descripción';es_CO = 'Descripción';tr = 'Tanım';it = 'Descrizione';de = 'Beschreibung'"),
			TypeDescriptionString50, TypeDescriptionColumn,
			"CompanyResource", NStr("en = 'Work center'; ru = 'Рабочий центр';pl = 'Gniazdo produkcyjne';es_ES = 'Centro de trabajo';es_CO = 'Centro de trabajo';tr = 'İş merkezi';it = 'Centro di lavoro';de = 'Arbeitsabschnitt'"), 1, , True);
			
		TypeDescriptionColumn = New TypeDescription("CatalogRef.CompanyResourceTypes");
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "WorkcenterType", NStr("en = 'Work center type'; ru = 'Тип рабочего центра';pl = 'Typ gniazda produkcyjnego';es_ES = 'Tipo de centro de trabajo';es_CO = 'Tipo de centro de trabajo';tr = 'İş merkezi türü';it = 'Tipo di centro di lavoro';de = 'Arbeitsabschnittstyp'"), 
			TypeDescriptionString50, TypeDescriptionColumn, , , , True);
			
		TypeDescriptionColumn = New TypeDescription("CatalogRef.Calendars");
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "Schedule", NStr("en = 'Work schedule'; ru = 'График работы';pl = 'Harmonogram pracy';es_ES = 'Horario de trabajo';es_CO = 'Horario de trabajo';tr = 'Çalışma programı';it = 'Grafico di lavoro';de = 'Arbeitszeitplan'"), 
			TypeDescriptionString100, TypeDescriptionColumn);
			
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "Capacity", NStr("en = 'Capacity'; ru = 'Мощность';pl = 'Zdolność produkcyjna';es_ES = 'Capacidad';es_CO = 'Capacidad';tr = 'Kapasite';it = 'Capacità';de = 'Kapazität'"),
			TypeDescriptionString17, TypeDescriptionNumber15_2);
			
	ElsIf FillingObjectFullName = "Catalog.ManufacturingActivities" Then
		
		TypeDescriptionColumn = New TypeDescription("CatalogRef.ManufacturingActivities");
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "Description", NStr("en = 'Description'; ru = 'Наименование';pl = 'Opis';es_ES = 'Descripción';es_CO = 'Descripción';tr = 'Tanım';it = 'Descrizione';de = 'Beschreibung'"),
			TypeDescriptionString100, TypeDescriptionColumn,
			"Operation", NStr("en = 'Operation'; ru = 'Операция';pl = 'Operacja';es_ES = 'Operación';es_CO = 'Operación';tr = 'İşlem';it = 'Operazione';de = 'Operation'"), 1, , True);
			
		TypeDescriptionColumn = New TypeDescription("CatalogRef.CostPools");
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "CostPool", NStr("en = 'Cost pool'; ru = 'Группа затрат';pl = 'Pula kosztów';es_ES = 'Grupo de coste';es_CO = 'Grupo de coste';tr = 'Maliyet havuzu';it = 'Centro di Costo';de = 'Kostenpool'"), 
			TypeDescriptionString50, TypeDescriptionColumn, , , , True);
			
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "StandardWorkload", NStr("en = 'Standard workload'; ru = 'Нормативная трудоемкость';pl = 'Standardowe obciążenie pracą';es_ES = 'Carga de trabajo estándar';es_CO = 'Carga de trabajo estándar';tr = 'Standart iş yükü';it = 'Carico di lavoro standard';de = 'Standardarbeitsaufwand'"),
			TypeDescriptionString17, TypeDescriptionNumber15_2);
			
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "StandardTimeInUOM", NStr("en = 'Standard time'; ru = 'Нормы времени работ';pl = 'Norma czasowa';es_ES = 'Tiempo estándar';es_CO = 'Tiempo estándar';tr = 'Standart süre';it = 'Tempo standard';de = 'Standardzeit'"),
			TypeDescriptionString17, TypeDescriptionNumber15_2);
			
		TypeDescriptionColumn = New TypeDescription("CatalogRef.TimeUOM");
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "TimeUOM", NStr("en = 'Time unit'; ru = 'Ед. времени';pl = 'Jednostka czasu';es_ES = 'Unidad de tiempo';es_CO = 'Unidad de tiempo';tr = 'Zaman birimi';it = 'Unità di tempo';de = 'Zeiteinheit'"), 
			TypeDescriptionString25, TypeDescriptionColumn);
			
		TypeDescriptionColumn = New TypeDescription("CatalogRef.CompanyResourceTypes");
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "WorkcenterType", NStr("en = 'Work center type'; ru = 'Тип рабочего центра';pl = 'Typ gniazda produkcyjnego';es_ES = 'Tipo de centro de trabajo';es_CO = 'Tipo de centro de trabajo';tr = 'İş merkezi türü';it = 'Tipo di centro di lavoro';de = 'Arbeitsabschnittstyp'"), 
			TypeDescriptionString50, TypeDescriptionColumn);
			
	// end Drive.FullVersion
	
	ElsIf FillingObjectFullName = "Catalog.Products" Then
		
		TypeDescriptionColumn = New TypeDescription("CatalogRef.Products");
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "Parent", NStr("en = 'Group'; ru = 'Группа';pl = 'Grupa';es_ES = 'Grupo';es_CO = 'Grupo';tr = 'Grup';it = 'Gruppo';de = 'Gruppe'"),
			TypeDescriptionString100, TypeDescriptionColumn);
			
		TypeDescriptionColumn = New TypeDescription("CatalogRef.Products");
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "Code", NStr("en = 'Code'; ru = 'Код';pl = 'Kod';es_ES = 'Código';es_CO = 'Código';tr = 'Kod';it = 'Codice';de = 'Code'"),
			TypeDescriptionString11, TypeDescriptionColumn,
			"Products", NStr("en = 'Product'; ru = 'Номенклатура';pl = 'Produkt';es_ES = 'Producto';es_CO = 'Producto';tr = 'Ürün';it = 'Articolo';de = 'Produkt'"), 1, , True);
			
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "Barcode", 	NStr("en = 'Barcode'; ru = 'Штрихкод';pl = 'Kod kreskowy';es_ES = 'Código de barras';es_CO = 'Código de barras';tr = 'Barkod';it = 'Codice a barre';de = 'Barcode'"),
			TypeDescriptionString200, TypeDescriptionColumn,
			"Products", NStr("en = 'Product'; ru = 'Номенклатура';pl = 'Produkt';es_ES = 'Producto';es_CO = 'Producto';tr = 'Ürün';it = 'Articolo';de = 'Produkt'"), 2, , True);
			
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "SKU", 	NStr("en = 'ID (item #)'; ru = 'Идентификатор (артикул)';pl = 'ID (pozycja nr)';es_ES = 'Identificador (artículo №)';es_CO = 'Identificador (artículo №)';tr = 'Kimlik (ürün no)';it = 'ID (elemento #)';de = 'ID (Artikel Nr.)'"),
			TypeDescriptionString25, TypeDescriptionColumn,
			"Products", NStr("en = 'Product'; ru = 'Номенклатура';pl = 'Produkt';es_ES = 'Producto';es_CO = 'Producto';tr = 'Ürün';it = 'Articolo';de = 'Produkt'"), 3, , True);
			
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "ProductsDescription", NStr("en = 'Description'; ru = 'Наименование';pl = 'Opis';es_ES = 'Descripción';es_CO = 'Descripción';tr = 'Tanım';it = 'Descrizione';de = 'Beschreibung'"),
			TypeDescriptionString100, TypeDescriptionColumn,
			"Products", NStr("en = 'Product'; ru = 'Номенклатура';pl = 'Produkt';es_ES = 'Producto';es_CO = 'Producto';tr = 'Ürün';it = 'Articolo';de = 'Produkt'"), 4, , True);
			
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "ProductsDescriptionFull", NStr("en = 'Detailed description'; ru = 'Подробное описание';pl = 'Szczegółowy opis';es_ES = 'Descripción detallada';es_CO = 'Descripción detallada';tr = 'Ayrıntılı açıklama';it = 'Descrizione dettagliata';de = 'Detaillierte Beschreibung'"),
			TypeDescriptionString1000, TypeDescriptionColumn,
			"Products", NStr("en = 'Product'; ru = 'Номенклатура';pl = 'Produkt';es_ES = 'Producto';es_CO = 'Producto';tr = 'Ürün';it = 'Articolo';de = 'Produkt'"), 5, , True);
			
		TypeDescriptionColumn = New TypeDescription("EnumRef.ProductsTypes");
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "ProductsType", NStr("en = 'Product type'; ru = 'Тип номенклатуры';pl = 'Typ produktu';es_ES = 'Tipo de producto';es_CO = 'Tipo de producto';tr = 'Ürün türü';it = 'Tipo di articolo';de = 'Produktart'"),
			TypeDescriptionString11, TypeDescriptionColumn);
		
		TypeDescriptionColumn = New TypeDescription("CatalogRef.UOMClassifier");
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "MeasurementUnit", NStr("en = 'Unit of measure'; ru = 'Ед. изм.';pl = 'Jednostka miary';es_ES = 'Unidad de medida';es_CO = 'Unidad de medida';tr = 'Ölçü birimi';it = 'Unità di misura';de = 'Maßeinheit'"), 
			TypeDescriptionString25, TypeDescriptionColumn, , , , True);
			
		TypeDescriptionColumn = New TypeDescription("CatalogRef.UOMClassifier");
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "ReportUOM", NStr("en = 'Report unit'; ru = 'Единица измерения отчета';pl = 'Jednostka miary w raporcie';es_ES = 'Informe de unidad';es_CO = 'Informe de unidad';tr = 'Rapor birimi';it = 'Unità report';de = 'Bericht Maßeinheit'"), 
			TypeDescriptionString25, TypeDescriptionColumn);
			
		TypeDescriptionColumn = New TypeDescription("CatalogRef.LinesOfBusiness");
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "BusinessLine", NStr("en = 'Line of business'; ru = 'Направление деятельности';pl = 'Rodzaj działalności';es_ES = 'Dirección de negocio';es_CO = 'Dirección de negocio';tr = 'İş kolu';it = 'Linea di business';de = 'Geschäftsbereich'"), 
			TypeDescriptionString50, TypeDescriptionColumn, , , , , , 
			GetFunctionalOption("AccountingBySeveralLinesOfBusiness"));
			
		TypeDescriptionColumn = New TypeDescription("CatalogRef.ProductsCategories");
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "ProductsCategory", NStr("en = 'Product category'; ru = 'Категория номенклатуры';pl = 'Kategoria produktu';es_ES = 'Categoría de producto';es_CO = 'Categoría de producto';tr = 'Ürün kategorisi';it = 'Categoria articolo';de = 'Produktkategorie'"), 
			TypeDescriptionString100, TypeDescriptionColumn);
			
		TypeDescriptionColumn = New TypeDescription("CatalogRef.Counterparties");
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "Vendor", NStr("en = 'Supplier (TIN or name)'; ru = 'Поставщик (ИНН или наименование)';pl = 'Dostawca (NIP lub nazwa)';es_ES = 'Proveedor (NIF o el nombre)';es_CO = 'Proveedor (NIF o el nombre)';tr = 'Tedarikçi (VKN veya adı)';it = 'Fornitore (Cod.Fiscale o nome)';de = 'Lieferant (Steuernummer oder Name)'"), 
			TypeDescriptionString100, TypeDescriptionColumn);
			
		TypeDescriptionColumn = New TypeDescription("CatalogRef.Counterparties");
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "Manufacturer", NStr("en = 'Manufacturer (TIN or name)'; ru = 'Производитель (ИНН или наименование)';pl = 'Producent (NIP lub nazwa)';es_ES = 'Producción (NIF o nombre)';es_CO = 'Producción (NIF o nombre)';tr = 'Üretici (VKN veya adı)';it = 'Produttore (Cod.Fiscale o nome)';de = 'Hersteller (Steuernummer oder Name)'"), 
			TypeDescriptionString100, TypeDescriptionColumn);
			
		If GetFunctionalOption("UseSerialNumbers") Then
			
			TypeDescriptionColumn = New TypeDescription("Boolean");
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, "UseSerialNumbers", NStr("en = 'Use serial numbers'; ru = 'Использовать серийные номера';pl = 'Używać numerów seryjnych';es_ES = 'Utilizar los números de serie';es_CO = 'Utilizar los números de serie';tr = 'Seri numaraları kullan';it = 'Utilizzare numeri di serie';de = 'Seriennummern verwenden'"),
				TypeDescriptionString25, TypeDescriptionColumn);
				
			TypeDescriptionColumn = New TypeDescription("CatalogRef.SerialNumbers");
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, "SerialNumber", NStr("en = 'Serial number'; ru = 'Серийный номер';pl = 'Numer seryjny';es_ES = 'Número de serie';es_CO = 'Número de serie';tr = 'Seri numarası';it = 'Numero di serie';de = 'Seriennummer'"),
				TypeDescriptionString150, TypeDescriptionColumn);
				
		EndIf;
		
		TypeDescriptionColumn = New TypeDescription("CatalogRef.BusinessUnits");
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "Warehouse", NStr("en = 'Warehouse (name)'; ru = 'Склад (наименование)';pl = 'Magazyn (nazwa)';es_ES = 'Almacén (nombre)';es_CO = 'Almacén (nombre)';tr = 'Ambar (isim)';it = 'Magazzino (denominazione)';de = 'Lager (Name)'"), 
			TypeDescriptionString50, TypeDescriptionColumn);
			
		TypeDescriptionColumn = New TypeDescription("EnumRef.InventoryReplenishmentMethods");
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "ReplenishmentMethod", NStr("en = 'Replenishment method'; ru = 'Способ пополнения';pl = 'Sposób uzupełniania';es_ES = 'Método de reposición';es_CO = 'Método de reposición';tr = 'Stok yenileme yöntemi';it = 'Metodo di rifornimento';de = 'Auffüllungsmethode'"), 
			TypeDescriptionString50, TypeDescriptionColumn);
			
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "ReplenishmentDeadline", NStr("en = 'Replenishment deadline'; ru = 'Срок пополнения';pl = 'Ostateczny termin uzupełniania';es_ES = 'Fecha límite de reposición';es_CO = 'Fecha límite de reposición';tr = 'Yeniden doldurmanın son tarihi';it = 'Data prevista per il rifornimento';de = 'Auffüllungsfrist'"), 
			TypeDescriptionString25, TypeDescriptionNumber10_0);
			
		TypeDescriptionColumn = New TypeDescription("CatalogRef.VATRates");
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "VATRate", NStr("en = 'VAT rate'; ru = 'Ставка НДС';pl = 'Stawka VAT';es_ES = 'Tasa del IVA';es_CO = 'Tasa del IVA';tr = 'KDV oranı';it = 'Aliquota IVA';de = 'USt.-Satz'"), 
			TypeDescriptionString11, TypeDescriptionColumn);
			
		If GetFunctionalOption("UseStorageBins") Then
			TypeDescriptionColumn = New TypeDescription("CatalogRef.Cells");
			DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "Cell", NStr("en = 'Bin (name)'; ru = 'Ячейка (наименование)';pl = 'Komórka (nazwa)';es_ES = 'Contenedor (nombre)';es_CO = 'Contenedor (nombre)';tr = 'Hücre (ad)';it = 'Contenitore (nome)';de = 'Lagerplatz (Name)'"),
			TypeDescriptionString50, TypeDescriptionColumn);
		EndIf;
		
		TypeDescriptionColumn = New TypeDescription("CatalogRef.PriceGroups");
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "PriceGroup", NStr("en = 'Price group (name)'; ru = 'Ценовая группа (наименование)';pl = 'Grupa cen (nazwa)';es_ES = 'Grupo de precios (nombre)';es_CO = 'Grupo de precios (nombre)';tr = 'Fiyat grubu (ad)';it = 'Gruppo prezzo (nome)';de = 'Preisgruppe (Beschreibung)'"),
			TypeDescriptionString50, TypeDescriptionColumn);
			
		TypeDescriptionColumn = New TypeDescription("Boolean");
		If GetFunctionalOption("UseCharacteristics") Then
			DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "UseCharacteristics", NStr("en = 'Use variants'; ru = 'Использовать варианты';pl = 'Używaj wariantów';es_ES = 'Utilizar variantes';es_CO = 'Utilizar variantes';tr = 'Varyantları kullan';it = 'Utilizzare varianti';de = 'Varianten benutzen'"), 
			TypeDescriptionString25, TypeDescriptionColumn);
		EndIf;
		
		If GetFunctionalOption("UseBatches") Then
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, "UseBatches", NStr("en = 'Use batches'; ru = 'Использовать партии';pl = 'Użyć partii';es_ES = 'Utilizar lotes';es_CO = 'Utilizar lotes';tr = 'Partileri kullan';it = 'Utilizzare i lotti';de = 'Chargen verwenden'"), 
				TypeDescriptionString25, TypeDescriptionColumn);
		EndIf;
		
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "Comment", NStr("en = 'Comment'; ru = 'Комментарий';pl = 'Uwagi';es_ES = 'Comentario';es_CO = 'Comentario';tr = 'Yorum';it = 'Commento';de = 'Kommentar'"), 
			TypeDescriptionString200, TypeDescriptionString200);
			
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "OrderCompletionDeadline", NStr("en = 'Order fulfillment deadline'; ru = 'Срок исполнения заказа';pl = 'Termin realizacji zamówienia';es_ES = 'Fecha límite de cumplimiento del orden';es_CO = 'Fecha límite de cumplimiento del orden';tr = 'Sipariş tamamlama son tarihi';it = 'Data prevista di completamento dell''ordine';de = 'Frist für die Auftragserfüllung'"), 
			TypeDescriptionString11, TypeDescriptionNumber10_0);
			
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "TimeNorm", NStr("en = 'Standard hours'; ru = 'Норма времени';pl = 'Norma czasowa';es_ES = 'Horas estándar';es_CO = 'Horas estándar';tr = 'Standart süre';it = 'Ore standard';de = 'Richtwertsätze'"),
			TypeDescriptionString25, TypeDescriptionNumber10_3);
			
		TypeDescriptionColumn = New TypeDescription("Boolean");
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "FixedCost", NStr("en = 'Fixed cost (for works)'; ru = 'Фикс. стоимость (для работ)';pl = 'Stały koszt (dla prac)';es_ES = 'Coste fijo (para trabajos)';es_CO = 'Coste fijo (para trabajos)';tr = 'Sabit tutar (işler için)';it = 'Costo fisso (per lavori)';de = 'Feste Kosten (für Arbeiten)'"),
			TypeDescriptionString25, TypeDescriptionColumn);
			
		TypeDescriptionColumn = New TypeDescription("CatalogRef.WorldCountries");
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "CountryOfOrigin", NStr("en = 'Country of origin (code or name)'; ru = 'Страна происхождения (код или наименование)';pl = 'Kraj pochodzenia (kod lub nazwa)';es_ES = 'País de origen (código o nombre)';es_CO = 'País de origen (código o nombre)';tr = 'Menşei ülke (kod veya ad)';it = 'Paese d''origine (codice o nome)';de = 'Herkunftsland (Code oder Name)'"),
			TypeDescriptionString25, TypeDescriptionColumn);
			
		// AdditionalAttributes
		DataImportFromExternalSources.PrepareMapForAdditionalAttributes(DataLoadSettings, Catalogs.AdditionalAttributesAndInfoSets.Catalog_Products);
		If DataLoadSettings.AdditionalAttributeDescription.Count() > 0 Then
			
			FieldName = DataImportFromExternalSources.AdditionalAttributesForAddingFieldsName();
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, FieldName, NStr("en = 'Additional attributes'; ru = 'Доп. реквизиты';pl = 'Dodatkowe atrybuty';es_ES = 'Atributos adicionales';es_CO = 'Atributos adicionales';tr = 'Ek öznitelikler';it = 'Attributi aggiuntivi';de = 'Zusätzliche Attribute'"),
				TypeDescriptionString150, TypeDescriptionString11, , , , , , , True,
				Catalogs.AdditionalAttributesAndInfoSets.Catalog_Products);
			
		EndIf;
		
	ElsIf FillingObjectFullName = "Catalog.BillsOfMaterials.TabularSection.Content" Then
		
		TypeDescriptionColumn = New TypeDescription("EnumRef.BOMLineType");
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "ContentRowType", NStr("en = 'Row type'; ru = 'Тип строки';pl = 'Rodzaj wiersza';es_ES = 'Tipo de fila';es_CO = 'Tipo de fila';tr = 'Satır türü';it = 'Tipo di riga';de = 'Zeilentyp'"),
			TypeDescriptionString25, TypeDescriptionColumn, , , , True);
		
		TypeDescriptionColumn = New TypeDescription("CatalogRef.Products");
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "Barcode", NStr("en = 'Barcode'; ru = 'Штрихкод';pl = 'Kod kreskowy';es_ES = 'Código de barras';es_CO = 'Código de barras';tr = 'Barkod';it = 'Codice a barre';de = 'Barcode'"),
			TypeDescriptionString200, TypeDescriptionColumn,
			"Products", NStr("en = 'Product'; ru = 'Номенклатура';pl = 'Produkt';es_ES = 'Producto';es_CO = 'Producto';tr = 'Ürün';it = 'Articolo';de = 'Produkt'"), 1, , True);
			
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "SKU", NStr("en = 'ID (item #)'; ru = 'Идентификатор (артикул)';pl = 'ID (pozycja nr)';es_ES = 'Identificador (artículo №)';es_CO = 'Identificador (artículo №)';tr = 'Kimlik (ürün no)';it = 'ID (elemento #)';de = 'ID (Artikel Nr.)'"),
			TypeDescriptionString25, TypeDescriptionColumn,
			"Products", NStr("en = 'Product'; ru = 'Номенклатура';pl = 'Produkt';es_ES = 'Producto';es_CO = 'Producto';tr = 'Ürün';it = 'Articolo';de = 'Produkt'"), 2, , True);
			
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "ProductsDescription", NStr("en = 'Description'; ru = 'Наименование';pl = 'Opis';es_ES = 'Descripción';es_CO = 'Descripción';tr = 'Tanım';it = 'Descrizione';de = 'Beschreibung'"),
			TypeDescriptionString100, TypeDescriptionColumn,
			"Products", NStr("en = 'Product'; ru = 'Номенклатура';pl = 'Produkt';es_ES = 'Producto';es_CO = 'Producto';tr = 'Ürün';it = 'Articolo';de = 'Produkt'"), 3, , True);
			
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "ProductsDescriptionFull", NStr("en = 'Detailed description'; ru = 'Подробное описание';pl = 'Szczegółowy opis';es_ES = 'Descripción detallada';es_CO = 'Descripción detallada';tr = 'Ayrıntılı açıklama';it = 'Descrizione dettagliata';de = 'Detaillierte Beschreibung'"),
			TypeDescriptionString1000, TypeDescriptionColumn,
			"Products", NStr("en = 'Product'; ru = 'Номенклатура';pl = 'Produkt';es_ES = 'Producto';es_CO = 'Producto';tr = 'Ürün';it = 'Articolo';de = 'Produkt'"), 4, , True);
		
		If GetFunctionalOption("UseCharacteristics") Then
			TypeDescriptionColumn = New TypeDescription("CatalogRef.ProductsCharacteristics");
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, "Characteristic", NStr("en = 'Variant (name)'; ru = 'Вариант (наименование)';pl = 'Wariant (nazwa)';es_ES = 'Variante (nombre)';es_CO = 'Variante (nombre)';tr = 'Varyant (isim)';it = 'Variante (nome)';de = 'Variante (Name)'"),
				TypeDescriptionString150, TypeDescriptionColumn);
		EndIf;
		
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "Quantity", NStr("en = 'Quantity'; ru = 'Количество';pl = 'Ilość';es_ES = 'Cantidad';es_CO = 'Cantidad';tr = 'Miktar';it = 'Quantità';de = 'Menge'"),
			TypeDescriptionString25, TypeDescriptionNumber15_3, , , , True);
		
		TypeDescriptionColumn = New TypeDescription("CatalogRef.UOMClassifier"
			+ ?(GetFunctionalOption("UseSeveralUnitsForProduct"), ", CatalogRef.UOM", ""));
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "MeasurementUnit", NStr("en = 'Unit of measure'; ru = 'Ед. изм.';pl = 'Jednostka miary';es_ES = 'Unidad de medida';es_CO = 'Unidad de medida';tr = 'Ölçü birimi';it = 'Unità di misura';de = 'Maßeinheit'"),
			TypeDescriptionString25, TypeDescriptionColumn);
		
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "CostPercentage", NStr("en = 'Cost share'; ru = 'Доля себестоимости';pl = 'Podział kosztów';es_ES = 'Repartición de costes';es_CO = 'Repartición de costes';tr = 'Maliyet payı';it = 'Condivisione dei costi';de = 'Kostenanteil'"),
			TypeDescriptionString25, TypeDescriptionNumber15_2);
		
		TypeDescriptionColumn = New TypeDescription("CatalogRef.BillsOfMaterials");
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "Specification", NStr("en = 'Bill of materials (name)'; ru = 'Спецификация (наименование)';pl = 'Specyfikacja materiałowa (nazwa)';es_ES = 'Lista de materiales (nombre)';es_CO = 'Lista de materiales (nombre)';tr = 'Ürün reçetesi (ad)';it = 'Distinta Base (nome)';de = 'Stückliste (Name)'"),
			TypeDescriptionString100, TypeDescriptionColumn);
			
	// begin Drive.FullVersion
	ElsIf FillingObjectFullName = "Catalog.RoutingTemplates.TabularSection.Operations" Then
																	
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, 
			"ActivityNumber",
			NStr("en = 'Operation number'; ru = 'Номер операции';pl = 'Numer operacji';es_ES = 'Número de operación';es_CO = 'Número de operación';tr = 'İşlem numarası';it = 'Numero operazione';de = 'Operationsnummer'"),
			TypeDescriptionString17, 
			TypeDescriptionNumber15_0,
			, ,
			True);
			
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, 
			"NextActivityNumber",
			NStr("en = 'Next operation'; ru = 'Следующая операция';pl = 'Następna operacja';es_ES = 'Próxima operación';es_CO = 'Próxima operación';tr = 'Sonraki işlem';it = 'Prossima operazione';de = 'Nächste Operation'"),
			TypeDescriptionString17, 
			TypeDescriptionNumber15_0,
			, ,
			True);
			
		TypeDescriptionColumn = New TypeDescription("CatalogRef.ManufacturingActivities");
		DataImportFromExternalSources.AddImportDescriptionField(ImportFieldsTable, 
			"Activity",
			NStr("en = 'Operation'; ru = 'Операция';pl = 'Operacja';es_ES = 'Operación';es_CO = 'Operación';tr = 'İşlem';it = 'Operazione';de = 'Operation'"),
			TypeDescriptionString100, 
			TypeDescriptionColumn,
			, ,
			True);
			
	// end Drive.FullVersion
	
	ElsIf FillingObjectFullName = "InformationRegister.Prices" Then
		
		TypeDescriptionColumn = New TypeDescription("CatalogRef.Products");
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "Barcode", NStr("en = 'Barcode'; ru = 'Штрихкод';pl = 'Kod kreskowy';es_ES = 'Código de barras';es_CO = 'Código de barras';tr = 'Barkod';it = 'Codice a barre';de = 'Barcode'"),
			TypeDescriptionString200, TypeDescriptionColumn,
			"Products", NStr("en = 'Product'; ru = 'Номенклатура';pl = 'Produkt';es_ES = 'Producto';es_CO = 'Producto';tr = 'Ürün';it = 'Articolo';de = 'Produkt'"), 1, , True);
			
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "SKU", NStr("en = 'ID (item #)'; ru = 'Идентификатор (артикул)';pl = 'ID (pozycja nr)';es_ES = 'Identificador (artículo №)';es_CO = 'Identificador (artículo №)';tr = 'Kimlik (ürün no)';it = 'ID (elemento #)';de = 'ID (Artikel Nr.)'"),
			TypeDescriptionString25, TypeDescriptionColumn,
			"Products", NStr("en = 'Product'; ru = 'Номенклатура';pl = 'Produkt';es_ES = 'Producto';es_CO = 'Producto';tr = 'Ürün';it = 'Articolo';de = 'Produkt'"), 2, , True);
			
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "ProductsDescription", NStr("en = 'Description'; ru = 'Наименование';pl = 'Opis';es_ES = 'Descripción';es_CO = 'Descripción';tr = 'Tanım';it = 'Descrizione';de = 'Beschreibung'"),
			TypeDescriptionString100, TypeDescriptionColumn,
			"Products", NStr("en = 'Product'; ru = 'Номенклатура';pl = 'Produkt';es_ES = 'Producto';es_CO = 'Producto';tr = 'Ürün';it = 'Articolo';de = 'Produkt'"), 3, , True);
			
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "ProductsDescriptionFull", NStr("en = 'Detailed description'; ru = 'Подробное описание';pl = 'Szczegółowy opis';es_ES = 'Descripción detallada';es_CO = 'Descripción detallada';tr = 'Ayrıntılı açıklama';it = 'Descrizione dettagliata';de = 'Detaillierte Beschreibung'"),
			TypeDescriptionString1000, TypeDescriptionColumn,
			"Products", NStr("en = 'Product'; ru = 'Номенклатура';pl = 'Produkt';es_ES = 'Producto';es_CO = 'Producto';tr = 'Ürün';it = 'Articolo';de = 'Produkt'"), 4, , True);
			
		If GetFunctionalOption("UseCharacteristics") Then
			TypeDescriptionColumn = New TypeDescription("CatalogRef.ProductsCharacteristics");
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, "Characteristic", NStr("en = 'Variant (name)'; ru = 'Вариант (наименование)';pl = 'Wariant (nazwa)';es_ES = 'Variante (nombre)';es_CO = 'Variante (nombre)';tr = 'Varyant (isim)';it = 'Variante (nome)';de = 'Variante (Name)'"),
				TypeDescriptionString25, TypeDescriptionColumn);
		EndIf;
		
		TypeDescriptionColumn = New TypeDescription("CatalogRef.UOMClassifier"
			+ ?(GetFunctionalOption("UseSeveralUnitsForProduct"), ", CatalogRef.UOM", ""));
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "MeasurementUnit", NStr("en = 'Unit of measure'; ru = 'Ед. изм.';pl = 'Jednostka miary';es_ES = 'Unidad de medida';es_CO = 'Unidad de medida';tr = 'Ölçü birimi';it = 'Unità di misura';de = 'Maßeinheit'"),
			TypeDescriptionString25, TypeDescriptionColumn, , , , True);
		
		TypeDescriptionColumn = New TypeDescription("CatalogRef.PriceTypes");
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "PriceKind", NStr("en = 'Price type (name)'; ru = 'Тип цен (наименование)';pl = 'Rodzaj ceny (nazwa)';es_ES = 'Tipo de precios (nombre)';es_CO = 'Tipo de precios (nombre)';tr = 'Fiyat türü (ad)';it = 'Tipo prezzo (nome)';de = 'Preistyp (Name)'"),
			TypeDescriptionString100, TypeDescriptionColumn);
		
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "Price", NStr("en = 'Price'; ru = 'Цена';pl = 'Cena';es_ES = 'Precio';es_CO = 'Precio';tr = 'Fiyat';it = 'Prezzo';de = 'Preis'"),
			TypeDescriptionString25, TypeDescriptionNumber15_2, , , , True);
		
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "Date", NStr("en = 'Date (start of use)'; ru = 'Дата (начало использования)';pl = 'Data (początek użytkowania)';es_ES = 'Fecha (inicio del uso)';es_CO = 'Fecha (inicio del uso)';tr = 'Tarih (kullanım başlangıcı)';it = 'Data (inizio dell''utilizzo)';de = 'Datum (Beginn der Nutzung)'"),
			TypeDescriptionString25, TypeDescriptionDate);
		
	ElsIf FillingObjectFullName = "Document.OpeningBalanceEntry.TabularSection.AccountsReceivable"
		Or FillingObjectFullName = "Document.OpeningBalanceEntry.TabularSection.AccountsPayable" Then
		
		IsAR = (FillingObjectFullName = "Document.OpeningBalanceEntry.TabularSection.AccountsReceivable");
		
		ForeignExchangeAccounting = GetFunctionalOption("ForeignExchangeAccounting");
		UseContractsWithCounterparties = Constants.UseContractsWithCounterparties.Get();
		
		TypeDescriptionColumn = New TypeDescription("CatalogRef.Counterparties");
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "CounterpartyDescription", NStr("en = 'Counterparty name'; ru = 'Наименование контрагента';pl = 'Nazwa kontrahenta';es_ES = 'Nombre de la contraparte';es_CO = 'Nombre de la contraparte';tr = 'Cari hesap ismi';it = 'Nome controparte';de = 'Name des Geschäftspartners'"),
			TypeDescriptionString100, TypeDescriptionColumn,
			"Counterparty", NStr("en = 'Counterparty'; ru = 'Контрагент';pl = 'Kontrahent';es_ES = 'Contraparte';es_CO = 'Contraparte';tr = 'Cari hesap';it = 'Controparte';de = 'Geschäftspartner'"), 1, True, True);
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "CounterpartyTIN", NStr("en = 'Counterparty TIN'; ru = 'ИНН контрагента';pl = 'NIP kontrahenta';es_ES = 'El número de identificación del contribuyente de la contraparte';es_CO = 'El número de identificación del contribuyente de la contraparte';tr = 'Cari hesap VKN';it = 'Cod.Fiscale della controparte';de = 'Geschäftspartnersteuernummer'"),
			TypeDescriptionString100, TypeDescriptionColumn,
			"Counterparty", NStr("en = 'Counterparty'; ru = 'Контрагент';pl = 'Kontrahent';es_ES = 'Contraparte';es_CO = 'Contraparte';tr = 'Cari hesap';it = 'Controparte';de = 'Geschäftspartner'"), 2, , True);
			
		If UseContractsWithCounterparties Then
			TypeDescriptionColumn = New TypeDescription("CatalogRef.CounterpartyContracts");
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, "ContractDescription", NStr("en = 'Contract name'; ru = 'Наименование договора';pl = 'Nazwa kontraktu';es_ES = 'Nombre del contrato';es_CO = 'Nombre del contrato';tr = 'Sözleşme ismi';it = 'Nome contratto';de = 'Vertragsname'"),
				TypeDescriptionString100, TypeDescriptionColumn,
				"Contract", NStr("en = 'Contract'; ru = 'Договор';pl = 'Kontrakt';es_ES = 'Contrato';es_CO = 'Contrato';tr = 'Sözleşme';it = 'Contratto';de = 'Vertrag'"));
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, "ContractNo", NStr("en = 'Contract number'; ru = 'Номер договора';pl = 'Numer umowy';es_ES = 'Número del contrato';es_CO = 'Número del contrato';tr = 'Sözleşme numarası';it = 'Numero di contratto';de = 'Vertragsnummer'"),
				TypeDescriptionString50, TypeDescriptionColumn,
				"Contract", NStr("en = 'Contract'; ru = 'Договор';pl = 'Kontrakt';es_ES = 'Contrato';es_CO = 'Contrato';tr = 'Sözleşme';it = 'Contratto';de = 'Vertrag'"));
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, "ContractDate", NStr("en = 'Contract date'; ru = 'Дата договора';pl = 'Data podpisania umowy';es_ES = 'Fecha de contrato';es_CO = 'Fecha de contrato';tr = 'Sözleşme tarihi';it = 'Data del contratto';de = 'Vertragsdatum'"),
				TypeDescriptionString50, TypeDescriptionColumn,
				"Contract", NStr("en = 'Contract'; ru = 'Договор';pl = 'Kontrakt';es_ES = 'Contrato';es_CO = 'Contrato';tr = 'Sözleşme';it = 'Contratto';de = 'Vertrag'"));
		EndIf;
		
		If ForeignExchangeAccounting Then
			TypeDescriptionColumn = New TypeDescription("CatalogRef.Currencies");
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, "CurrencyName", NStr("en = 'Currency name (ISO code)'; ru = 'Валюта (код ISO)';pl = 'Nazwa waluty (kod ISO)';es_ES = 'Nombre de moneda (código ISO)';es_CO = 'Nombre de moneda (código ISO)';tr = 'Para birimi ismi (ISO kodu)';it = 'Nome valuta (Codice ISO)';de = 'Währungsname (ISO-Kode)'"),
				TypeDescriptionString10, TypeDescriptionColumn,
				"Currency", NStr("en = 'Currency'; ru = 'Валюта';pl = 'Waluta';es_ES = 'Moneda';es_CO = 'Moneda';tr = 'Para birimi';it = 'Valuta';de = 'Währung'"), 1, , True);
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, "CurrencyCode", NStr("en = 'Currency code (numeric)'; ru = 'Код валюты (числовой)';pl = 'Kod waluty (numeryczny)';es_ES = 'Código de moneda (numérico)';es_CO = 'Código de moneda (numérico)';tr = 'Para birimi kodu (rakamlarla)';it = 'Codice valuta (numerico)';de = 'Währungsschlüssel (numerisch)'"),
				TypeDescriptionString10, TypeDescriptionColumn,
				"Currency", NStr("en = 'Currency'; ru = 'Валюта';pl = 'Waluta';es_ES = 'Moneda';es_CO = 'Moneda';tr = 'Para birimi';it = 'Valuta';de = 'Währung'"), 2, , True);
		EndIf;
		
		TypeArray = ARAPDocumentTypes(IsAR);
		TypeDescriptionColumn = New TypeDescription(TypeArray);
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "DocumentType", NStr("en = 'Document type'; ru = 'Тип документа';pl = 'Typ dokumentu';es_ES = 'Tipo de documento';es_CO = 'Tipo de documento';tr = 'Belge türü';it = 'Tipo di documento';de = 'Dokumententyp'"),
			TypeDescriptionString50, TypeDescriptionColumn,
			"Document", NStr("en = 'Billing document'; ru = 'Документ расчета';pl = 'Dokument rozliczeniowy';es_ES = 'Documento de presupuesto';es_CO = 'Documento de presupuesto';tr = 'Fatura belgesi';it = 'Documento di fatturazione';de = 'Abrechnungsbeleg'"), , , True);
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "DocumentNumber", NStr("en = 'Document number'; ru = 'Номер документа';pl = 'Numer dokumentu';es_ES = 'Número del documento';es_CO = 'Número del documento';tr = 'Belge numarası';it = 'Numero del documento';de = 'Dokumentnummer'"),
			TypeDescriptionString25, TypeDescriptionColumn,
			"Document", NStr("en = 'Billing document'; ru = 'Документ расчета';pl = 'Dokument rozliczeniowy';es_ES = 'Documento de presupuesto';es_CO = 'Documento de presupuesto';tr = 'Fatura belgesi';it = 'Documento di fatturazione';de = 'Abrechnungsbeleg'"), , True, True);
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "DocumentDate", NStr("en = 'Document date'; ru = 'Дата документа';pl = 'Data dokumentu';es_ES = 'Fecha del documento';es_CO = 'Fecha del documento';tr = 'Belge tarihi';it = 'Data del documento';de = 'Dokumentdatum'"),
			TypeDescriptionString25, TypeDescriptionColumn,
			"Document", NStr("en = 'Billing document'; ru = 'Документ расчета';pl = 'Dokument rozliczeniowy';es_ES = 'Documento de presupuesto';es_CO = 'Documento de presupuesto';tr = 'Fatura belgesi';it = 'Documento di fatturazione';de = 'Abrechnungsbeleg'"), , , True);
			
		If IsAR Then
			TypeDescriptionColumn = New TypeDescription("DocumentRef.SalesOrder");
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, "OrderNumber", NStr("en = 'Sales order number'; ru = 'Номер заказа покупателя';pl = 'Numer zamówienia sprzedaży';es_ES = 'Número de orden de ventas';es_CO = 'Número de orden de ventas';tr = 'Satış siparişi numarası';it = 'Numero ordine cliente';de = 'Kundenauftragsnummer'"),
				TypeDescriptionString25, TypeDescriptionColumn,
				"Order", NStr("en = 'Sales order'; ru = 'Заказ покупателя';pl = 'Zamówienie sprzedaży';es_ES = 'Orden de ventas';es_CO = 'Orden de ventas';tr = 'Satış siparişi';it = 'Ordine cliente';de = 'Kundenauftrag'"));
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, "OrderDate", NStr("en = 'Sales order date'; ru = 'Дата заказа покупателя';pl = 'Data zamówienia sprzedaży';es_ES = 'Fecha de orden de ventas';es_CO = 'Fecha de orden de ventas';tr = 'Satış siparişi tarihi';it = 'Data ordine cliente';de = 'Kundenauftragsdatum'"),
				TypeDescriptionString25, TypeDescriptionColumn,
				"Order", NStr("en = 'Sales order'; ru = 'Заказ покупателя';pl = 'Zamówienie sprzedaży';es_ES = 'Orden de ventas';es_CO = 'Orden de ventas';tr = 'Satış siparişi';it = 'Ordine cliente';de = 'Kundenauftrag'"));
		Else
			TypeDescriptionColumn = New TypeDescription("DocumentRef.PurchaseOrder");
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, "OrderNumber", NStr("en = 'Purchase order number'; ru = 'Номер заказа поставщику';pl = 'Numer zamówienia zakupu';es_ES = 'Número del pedido';es_CO = 'Número del pedido';tr = 'Satın alma siparişi numarası';it = 'Numero ordine di acquisto';de = 'Nummer der Bestellung an Lieferanten'"),
				TypeDescriptionString25, TypeDescriptionColumn,
				"Order", NStr("en = 'Purchase order'; ru = 'Заказ поставщику';pl = 'Zamówienie zakupu';es_ES = 'Orden de compra';es_CO = 'Orden de compra';tr = 'Satın alma siparişi';it = 'Ordine di acquisto';de = 'Bestellung an Lieferanten'"));
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, "OrderDate", NStr("en = 'Purchase order date'; ru = 'Дата заказа поставщику';pl = 'Data zamówienia zakupu';es_ES = 'Fecha del pedido';es_CO = 'Fecha del pedido';tr = 'Satın alma siparişi tarihi';it = 'Data ordine di acquisto';de = 'Datum der Bestellung an Lieferanten'"),
				TypeDescriptionString25, TypeDescriptionColumn,
				"Order", NStr("en = 'Purchase order'; ru = 'Заказ поставщику';pl = 'Zamówienie zakupu';es_ES = 'Orden de compra';es_CO = 'Orden de compra';tr = 'Satın alma siparişi';it = 'Ordine di acquisto';de = 'Bestellung an Lieferanten'"));
		EndIf;
			
		TypeDescriptionColumn = New TypeDescription("Boolean");
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "AdvanceFlag", NStr("en = 'Is advance?'; ru = 'Это аванс?';pl = 'Czy to zaliczka?';es_ES = '¿Es un anticipo?';es_CO = '¿Es un anticipo?';tr = 'Avans mı?';it = 'E'' un anticipo?';de = 'Ist dies eine Vorauszahlung?'"),
			TypeDescriptionString25, TypeDescriptionColumn);
			
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "AmountCur", NStr("en = 'Amount'; ru = 'Сумма';pl = 'Kwota';es_ES = 'Importe';es_CO = 'Importe';tr = 'Tutar';it = 'Importo';de = 'Betrag'"),
			TypeDescriptionString25, TypeDescriptionNumber15_2, , , , True);
		If ForeignExchangeAccounting Then
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, "Amount", NStr("en = 'Amount in presentation currency'; ru = 'Cумма в валюте представления отчетности';pl = 'Kwota w walucie prezentacji';es_ES = 'Importe en la moneda de presentación';es_CO = 'Importe en la moneda de presentación';tr = 'Finansal tablo para biriminde tutar';it = 'Importo nella valuta contabile';de = 'Betrag in der Währung für die Berichtserstattung'"),
				TypeDescriptionString25, TypeDescriptionNumber15_2);
		EndIf;
		
	ElsIf FillingObjectFullName = "Document.OpeningBalanceEntry.TabularSection.CashAssets" Then
		
		ForeignExchangeAccounting = GetFunctionalOption("ForeignExchangeAccounting");
		
		If DataLoadSettings.AccountType = "BankAccount" Then
			
			TypeDescriptionColumn = New TypeDescription("CatalogRef.Banks");
			
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, "BankCode", NStr("en = 'SWIFT'; ru = 'SWIFT, корр. счет банка';pl = 'SWIFT';es_ES = 'SWIFT';es_CO = 'SWIFT';tr = 'SWIFT';it = 'SWIFT';de = 'SWIFT'"),
				TypeDescriptionString11, TypeDescriptionColumn,
				"Bank", NStr("en = 'Bank'; ru = 'Банк';pl = 'Bank';es_ES = 'Banco';es_CO = 'Banco';tr = 'Banka';it = 'Banca';de = 'Bank'"), 1, , True);
			
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, "BankDescription", NStr("en = 'Bank name'; ru = 'Наименование банка';pl = 'Nazwa banku';es_ES = 'Nombre del Banco';es_CO = 'Nombre del Banco';tr = 'Banka adı';it = 'Nome della banca';de = 'Name der Bank'"),
				TypeDescriptionString100, TypeDescriptionColumn,
				"Bank", NStr("en = 'Bank'; ru = 'Банк';pl = 'Bank';es_ES = 'Banco';es_CO = 'Banco';tr = 'Banka';it = 'Banca';de = 'Bank'"), 2, , True);
			
			If ForeignExchangeAccounting Then
				
				TypeDescriptionColumn = New TypeDescription("CatalogRef.Currencies");
				
				DataImportFromExternalSources.AddImportDescriptionField(
					ImportFieldsTable, "CurrencyName", NStr("en = 'Currency name (ISO code)'; ru = 'Валюта (код ISO)';pl = 'Nazwa waluty (kod ISO)';es_ES = 'Nombre de moneda (código ISO)';es_CO = 'Nombre de moneda (código ISO)';tr = 'Para birimi ismi (ISO kodu)';it = 'Nome valuta (Codice ISO)';de = 'Währungsname (ISO-Kode)'"),
					TypeDescriptionString10, TypeDescriptionColumn,
					"Currency", NStr("en = 'Currency'; ru = 'Валюта';pl = 'Waluta';es_ES = 'Moneda';es_CO = 'Moneda';tr = 'Para birimi';it = 'Valuta';de = 'Währung'"), 1, , True);
				
				DataImportFromExternalSources.AddImportDescriptionField(
					ImportFieldsTable, "CurrencyCode", NStr("en = 'Currency code (numeric)'; ru = 'Код валюты (числовой)';pl = 'Kod waluty (numeryczny)';es_ES = 'Código de moneda (numérico)';es_CO = 'Código de moneda (numérico)';tr = 'Para birimi kodu (rakamlarla)';it = 'Codice valuta (numerico)';de = 'Währungsschlüssel (numerisch)'"),
					TypeDescriptionString10, TypeDescriptionColumn,
					"Currency", NStr("en = 'Currency'; ru = 'Валюта';pl = 'Waluta';es_ES = 'Moneda';es_CO = 'Moneda';tr = 'Para birimi';it = 'Valuta';de = 'Währung'"), 2, , True);
					
			EndIf;
			
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, "IBAN", NStr("en = 'IBAN'; ru = 'IBAN';pl = 'IBAN';es_ES = 'IBAN';es_CO = 'IBAN';tr = 'IBAN';it = 'IBAN';de = 'IBAN'"),
				TypeDescriptionString50, TypeDescriptionString50,
				"IBAN_AccountNo", NStr("en = 'IBAN, Account number'; ru = 'IBAN, номер счета';pl = 'IBAN, Numer rachunku';es_ES = 'IBAN, Número de cuenta';es_CO = 'IBAN, Número de cuenta';tr = 'IBAN, Hesap numarası';it = 'IBAN, Numero di conto';de = 'IBAN, Konto-Nr.'"), 1, , True);
			
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, "AccountNo", NStr("en = 'Account number'; ru = 'Номер счета';pl = 'Numer rachunku';es_ES = 'Número de cuenta';es_CO = 'Número de cuenta';tr = 'Hesap numarası';it = 'Numero di conto';de = 'Kontonummer'"),
				TypeDescriptionString50, TypeDescriptionString50,
				"IBAN_AccountNo", NStr("en = 'IBAN, Account number'; ru = 'IBAN, номер счета';pl = 'IBAN, Numer rachunku';es_ES = 'IBAN, Número de cuenta';es_CO = 'IBAN, Número de cuenta';tr = 'IBAN, Hesap numarası';it = 'IBAN, Numero di conto';de = 'IBAN, Konto-Nr.'"), 2, , True);
			
			TypeDescriptionColumn = New TypeDescription("CatalogRef.BankAccounts");
			
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, "BankRef", NStr("en = 'Bank'; ru = 'Банк';pl = 'Bank';es_ES = 'Banco';es_CO = 'Banco';tr = 'Banka';it = 'Banca';de = 'Bank'"),
				New TypeDescription("CatalogRef.Banks"), TypeDescriptionColumn,
				"Account", NStr("en = 'Bank account'; ru = 'Банковский счет';pl = 'Rachunek bankowy';es_ES = 'Cuenta bancaria';es_CO = 'Cuenta bancaria';tr = 'Banka hesabı';it = 'Conto corrente';de = 'Bankkonto'"), , , True, False);
			
			If ForeignExchangeAccounting Then
				DataImportFromExternalSources.AddImportDescriptionField(
					ImportFieldsTable, "CashCurrency", NStr("en = 'Currency'; ru = 'Валюта';pl = 'Waluta';es_ES = 'Moneda';es_CO = 'Moneda';tr = 'Para birimi';it = 'Valuta';de = 'Währung'"),
					New TypeDescription("CatalogRef.Currencies"), TypeDescriptionColumn,
					"Account", NStr("en = 'Bank account'; ru = 'Банковский счет';pl = 'Rachunek bankowy';es_ES = 'Cuenta bancaria';es_CO = 'Cuenta bancaria';tr = 'Banka hesabı';it = 'Conto corrente';de = 'Bankkonto'"), , , True, False);
			EndIf;
			
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, "AmountCur", NStr("en = 'Amount'; ru = 'Сумма';pl = 'Kwota';es_ES = 'Importe';es_CO = 'Importe';tr = 'Tutar';it = 'Importo';de = 'Betrag'"),
				TypeDescriptionString10, TypeDescriptionNumber15_2, , , , True);
			If ForeignExchangeAccounting Then
				DataImportFromExternalSources.AddImportDescriptionField(
					ImportFieldsTable, "Amount", NStr("en = 'Amount in presentation currency'; ru = 'Cумма в валюте представления отчетности';pl = 'Kwota w walucie prezentacji';es_ES = 'Importe en la moneda de presentación';es_CO = 'Importe en la moneda de presentación';tr = 'Finansal tablo para biriminde tutar';it = 'Importo nella valuta contabile';de = 'Betrag in der Währung für die Berichtserstattung'"),
					TypeDescriptionString10, TypeDescriptionNumber15_2);
			EndIf;
			
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, "Description", NStr("en = 'Description'; ru = 'Наименование';pl = 'Opis';es_ES = 'Descripción';es_CO = 'Descripción';tr = 'Tanım';it = 'Descrizione';de = 'Beschreibung'"),
				TypeDescriptionString100, TypeDescriptionString100);
				
		ElsIf DataLoadSettings.AccountType = "CashAccount" Then
			
			TypeDescriptionColumn = New TypeDescription("CatalogRef.CashAccounts");
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, "Description", NStr("en = 'Description'; ru = 'Наименование';pl = 'Opis';es_ES = 'Descripción';es_CO = 'Descripción';tr = 'Tanım';it = 'Descrizione';de = 'Beschreibung'"),
				TypeDescriptionString100, TypeDescriptionColumn,
				"Account" , NStr("en = 'Cash account'; ru = 'Кассовый счет';pl = 'Kasa';es_ES = 'Cuenta de efectivo';es_CO = 'Cuenta de efectivo';tr = 'Kasa hesabı';it = 'Cassa';de = 'Liquiditätskonto'"), , , True);
			
			If ForeignExchangeAccounting Then
				
				TypeDescriptionColumn = New TypeDescription("CatalogRef.Currencies");
				
				DataImportFromExternalSources.AddImportDescriptionField(
					ImportFieldsTable, "CurrencyName", NStr("en = 'Currency name (ISO code)'; ru = 'Валюта (код ISO)';pl = 'Nazwa waluty (kod ISO)';es_ES = 'Nombre de moneda (código ISO)';es_CO = 'Nombre de moneda (código ISO)';tr = 'Para birimi ismi (ISO kodu)';it = 'Nome valuta (Codice ISO)';de = 'Währungsname (ISO-Kode)'"),
					TypeDescriptionString10, TypeDescriptionColumn,
					"Currency", NStr("en = 'Currency'; ru = 'Валюта';pl = 'Waluta';es_ES = 'Moneda';es_CO = 'Moneda';tr = 'Para birimi';it = 'Valuta';de = 'Währung'"), 1, , True);
				
				DataImportFromExternalSources.AddImportDescriptionField(
					ImportFieldsTable, "CurrencyCode", NStr("en = 'Currency code (numeric)'; ru = 'Код валюты (числовой)';pl = 'Kod waluty (numeryczny)';es_ES = 'Código de moneda (numérico)';es_CO = 'Código de moneda (numérico)';tr = 'Para birimi kodu (rakamlarla)';it = 'Codice valuta (numerico)';de = 'Währungsschlüssel (numerisch)'"),
					TypeDescriptionString10, TypeDescriptionColumn,
					"Currency", NStr("en = 'Currency'; ru = 'Валюта';pl = 'Waluta';es_ES = 'Moneda';es_CO = 'Moneda';tr = 'Para birimi';it = 'Valuta';de = 'Währung'"), 2, , True);
			EndIf;
			
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, "AmountCur", NStr("en = 'Amount'; ru = 'Сумма';pl = 'Kwota';es_ES = 'Importe';es_CO = 'Importe';tr = 'Tutar';it = 'Importo';de = 'Betrag'"),
				TypeDescriptionString10, TypeDescriptionNumber15_2, , , , True);
			If ForeignExchangeAccounting Then
				DataImportFromExternalSources.AddImportDescriptionField(
					ImportFieldsTable, "Amount", NStr("en = 'Amount in presentation currency'; ru = 'Cумма в валюте представления отчетности';pl = 'Kwota w walucie prezentacji';es_ES = 'Importe en la moneda de presentación';es_CO = 'Importe en la moneda de presentación';tr = 'Finansal tablo para biriminde tutar';it = 'Importo nella valuta contabile';de = 'Betrag in der Währung für die Berichtserstattung'"),
					TypeDescriptionString10, TypeDescriptionNumber15_2);
			EndIf;
			
		EndIf;
		
	ElsIf DataLoadSettings.FillingObjectFullName = "Catalog.Leads" Then
		
		TypeDescriptionString0000 = New TypeDescription("String", , , , New StringQualifiers(0));
		TypeDescriptionColumn = New TypeDescription("CatalogRef.Leads");
		
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "Description", NStr("en = 'Description'; ru = 'Наименование';pl = 'Opis';es_ES = 'Descripción';es_CO = 'Descripción';tr = 'Tanım';it = 'Descrizione';de = 'Beschreibung'"),
			TypeDescriptionString100, TypeDescriptionColumn,
			"Lead", NStr("en = 'Lead'; ru = 'Лид';pl = 'Lead';es_ES = 'Lead';es_CO = 'Lead';tr = 'Müşteri adayı';it = 'Potenziale Cliente';de = 'Lead'"), 1, True, True);
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "Code", NStr("en = 'Code'; ru = 'Код';pl = 'Kod';es_ES = 'Código';es_CO = 'Código';tr = 'Kod';it = 'Codice';de = 'Code'"),
			TypeDescriptionString10, TypeDescriptionColumn,
			"Lead", NStr("en = 'Lead'; ru = 'Лид';pl = 'Lead';es_ES = 'Lead';es_CO = 'Lead';tr = 'Müşteri adayı';it = 'Potenziale Cliente';de = 'Lead'"), 2, , True);
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "Contact1", NStr("en = '(1) Contact (name)'; ru = '(1) Контакт (имя)';pl = '(1) Kontakt (imię)';es_ES = '(1) Contacto (nombre)';es_CO = '(1) Contacto (nombre)';tr = '(1) Kişi (adı)';it = '(1) Contatto (nome)';de = '(1) Kontakt (Name)'"),
			TypeDescriptionString0000, TypeDescriptionString0000,
			"Contact_1", NStr("en = 'Contract 1'; ru = 'Договор 1';pl = 'Kontrakt 1';es_ES = 'Contrato 1';es_CO = 'Contrato 1';tr = 'Sözleşme 1';it = 'Contratto 1';de = 'Vertrag 1'"), 1);
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "Phone1", NStr("en = '(1) Phone'; ru = '(1) Телефон';pl = '(1) Telefon';es_ES = '(1) Teléfono';es_CO = '(1) Teléfono';tr = '(1) Telefon';it = '(1) Telefono';de = '(1) Telefon'"),
			TypeDescriptionString100, TypeDescriptionString100,
			"Contact_1", NStr("en = 'Contract 1'; ru = 'Договор 1';pl = 'Kontrakt 1';es_ES = 'Contrato 1';es_CO = 'Contrato 1';tr = 'Sözleşme 1';it = 'Contratto 1';de = 'Vertrag 1'"), 2);
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "Email1", NStr("en = '(1) Email'; ru = '(1) Электронная почта';pl = '(1) E-mail';es_ES = '(1) Email';es_CO = '(1) Email';tr = '(1) E-posta';it = '(1) Email';de = '(1) E-Mail'"),
			TypeDescriptionString100, TypeDescriptionString100,
			"Contact_1", NStr("en = 'Contract 1'; ru = 'Договор 1';pl = 'Kontrakt 1';es_ES = 'Contrato 1';es_CO = 'Contrato 1';tr = 'Sözleşme 1';it = 'Contratto 1';de = 'Vertrag 1'"), 3);
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "Contact2", NStr("en = '(2) Contact (name)'; ru = '(2) Контакт (имя)';pl = '(2) Kontakt (imię)';es_ES = '(2) Contacto (nombre)';es_CO = '(2) Contacto (nombre)';tr = '(2) Kişi adı';it = '(2) Contatto (nome)';de = '(2) Kontakt (Name)'"),
			TypeDescriptionString0000, TypeDescriptionString0000,
			"Contact_2", NStr("en = 'Contract 2'; ru = 'Договор 2';pl = 'Kontrakt 2';es_ES = 'Contrato 2';es_CO = 'Contrato 2';tr = 'Sözleşme 2';it = 'Contratto 2';de = 'Vertrag 2'"), 1);
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "Phone2", NStr("en = '(2) Phone'; ru = '(2) Телефон';pl = '(2) Telefon';es_ES = '(2) Teléfono';es_CO = '(2) Teléfono';tr = '(2) Telefon';it = '(2) Telefono';de = '(2) Telefon'"),
			TypeDescriptionString100, TypeDescriptionString100,
			"Contact_2", NStr("en = 'Contract 2'; ru = 'Договор 2';pl = 'Kontrakt 2';es_ES = 'Contrato 2';es_CO = 'Contrato 2';tr = 'Sözleşme 2';it = 'Contratto 2';de = 'Vertrag 2'"), 2);
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "Email2", NStr("en = '(2) Email'; ru = '(2) Электронная почта';pl = '(2) E-mail';es_ES = '(2) Email';es_CO = '(2) Email';tr = '(2) E-posta';it = '(2) Email';de = '(2) E-Mail'"),
			TypeDescriptionString100, TypeDescriptionString100,
			"Contact_2", NStr("en = 'Contract 2'; ru = 'Договор 2';pl = 'Kontrakt 2';es_ES = 'Contrato 2';es_CO = 'Contrato 2';tr = 'Sözleşme 2';it = 'Contratto 2';de = 'Vertrag 2'"), 3);
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "Contact3", NStr("en = '(3) Contact (name)'; ru = '(3) Контакт (имя)';pl = '(3) Kontakt (imię)';es_ES = '(3) Contacto (nombre)';es_CO = '(3) Contacto (nombre)';tr = '(3) Kişi (adı)';it = '(3) Contatto (nome)';de = '(3) Kontakt (Name)'"),
			TypeDescriptionString0000, TypeDescriptionString0000,
			"Contact_3", NStr("en = 'Contract 3'; ru = 'Договор 3';pl = 'Kontrakt 3';es_ES = 'Contrato 3';es_CO = 'Contrato 3';tr = 'Sözleşme 3';it = 'Contratto 3';de = 'Vertrag 3'"), 1);
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "Phone3", NStr("en = '(3) Phone'; ru = '(3) Телефон';pl = '(3) Telefon';es_ES = '(3) Teléfono';es_CO = '(3) Teléfono';tr = '(3) Telefon';it = '(3) Telefono';de = '(3) Telefon'"),
			TypeDescriptionString100, TypeDescriptionString100,
			"Contact_3", NStr("en = 'Contract 3'; ru = 'Договор 3';pl = 'Kontrakt 3';es_ES = 'Contrato 3';es_CO = 'Contrato 3';tr = 'Sözleşme 3';it = 'Contratto 3';de = 'Vertrag 3'"), 2);
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "Email3", NStr("en = '(3) Email'; ru = '(3) Электронная почта';pl = '(3) E-mail';es_ES = '(3) Email';es_CO = '(3) Email';tr = '(3) E-posta';it = '(3) Email';de = '(3) E-Mail'"),
			TypeDescriptionString100, TypeDescriptionString100,
			"Contact_3", NStr("en = 'Contract 3'; ru = 'Договор 3';pl = 'Kontrakt 3';es_ES = 'Contrato 3';es_CO = 'Contrato 3';tr = 'Sözleşme 3';it = 'Contratto 3';de = 'Vertrag 3'"), 3);
		TypeDescriptionNumber15_0 = New TypeDescription("Number", , , , New NumberQualifiers(15, 0, AllowedSign.Nonnegative));
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "Potential", NStr("en = 'Potential'; ru = 'Потенциал';pl = 'Potencjał';es_ES = 'Potencial';es_CO = 'Potencial';tr = 'Potansiyel';it = 'Potenziale';de = 'Potential'"),
			TypeDescriptionString10, TypeDescriptionNumber15_0);
		TypeDescriptionColumn = New TypeDescription("CatalogRef.CustomerAcquisitionChannels");
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "AcquisitionChannel", NStr("en = 'Acquisition channel'; ru = 'Источник';pl = 'Kanał pozyskiwania';es_ES = 'Canal de adquisición';es_CO = 'Canal de adquisición';tr = 'Müşteri edinme kanalı';it = 'Canale di acquisizione';de = 'Kanal'"),
			TypeDescriptionString100, TypeDescriptionColumn);
		TypeDescriptionColumn = New TypeDescription("String");
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "Note", NStr("en = 'Note'; ru = 'Примечание';pl = 'Uwagi';es_ES = 'Nota';es_CO = 'Nota';tr = 'Not';it = 'Nota';de = 'Hinweis'"),
			TypeDescriptionString0000, TypeDescriptionColumn);
		// AdditionalAttributes
		DataImportFromExternalSources.PrepareMapForAdditionalAttributes(DataLoadSettings, Catalogs.AdditionalAttributesAndInfoSets.Catalog_Leads);
		If DataLoadSettings.AdditionalAttributeDescription.Count() > 0 Then
			
			FieldName = DataImportFromExternalSources.AdditionalAttributesForAddingFieldsName();
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, FieldName, NStr("en = 'Additional attributes'; ru = 'Доп. реквизиты';pl = 'Dodatkowe atrybuty';es_ES = 'Atributos adicionales';es_CO = 'Atributos adicionales';tr = 'Ek öznitelikler';it = 'Attributi aggiuntivi';de = 'Zusätzliche Attribute'"),
				TypeDescriptionString150, TypeDescriptionString11, , , , , , , True,
				Catalogs.AdditionalAttributesAndInfoSets.Catalog_Leads);
		EndIf;
		
	ElsIf DataLoadSettings.FillingObjectFullName = "Document.RequestForQuotation.TabularSection.Suppliers" Then
		
		TypeDescriptionColumn		= New TypeDescription("CatalogRef.Counterparties");
		TypeDescriptionString0000	= New TypeDescription("String", , , , New StringQualifiers(0));
		
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "Counterparty", NStr("en = 'Counterparty (TIN or name)'; ru = 'Контрагент (ИНН или наименование)';pl = 'Kontrahent (NIP lub nazwa)';es_ES = 'Contraparte (NIF o nombre)';es_CO = 'Contraparte (NIF o nombre)';tr = 'Cari hesap (VKN veya adı)';it = 'Controparte (Cod.Fiscale o nome)';de = 'Geschäftspartner (Steuernummer oder Name)'"), 
			TypeDescriptionString100, TypeDescriptionColumn);
		
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "ContactPerson", NStr("en = 'Contact (name)'; ru = 'Контакт (имя)';pl = 'Kontakt (imię)';es_ES = 'Contacto (nombre)';es_CO = 'Contacto (nombre)';tr = 'İletişim bilgisi (isim)';it = 'Contatto (nome)';de = 'Kontakt (Name)'"),
			TypeDescriptionString0000, TypeDescriptionString0000);
		
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "Email", NStr("en = 'Email'; ru = 'Эл. почта';pl = 'E-mail';es_ES = 'Correo electrónico';es_CO = 'Correo electrónico';tr = 'E-posta';it = 'Email';de = 'E-Mail'"),
			TypeDescriptionString100, TypeDescriptionString100);
		
	ElsIf FillingObjectFullName = "ChartOfAccounts.PrimaryChartOfAccounts" Then
		
		TypeDescriptionColumn = New TypeDescription("ChartOfAccountsRef.PrimaryChartOfAccounts");
		
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "Code", NStr("en = 'Code'; ru = 'Код';pl = 'Kod';es_ES = 'Código';es_CO = 'Código';tr = 'Kod';it = 'Codice';de = 'Code'"),
			TypeDescriptionString20, TypeDescriptionColumn,
			"Account", NStr("en = 'Account'; ru = 'Учетная запись';pl = 'Konto';es_ES = 'Cuenta';es_CO = 'Cuenta';tr = 'Hesap';it = 'Conto';de = 'Konto'"), 1, True, True);
		
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "Description", NStr("en = 'Description'; ru = 'Наименование';pl = 'Opis';es_ES = 'Descripción';es_CO = 'Descripción';tr = 'Tanım';it = 'Descrizione';de = 'Beschreibung'"),
			TypeDescriptionString120, TypeDescriptionColumn,
			"Account", NStr("en = 'Account'; ru = 'Учетная запись';pl = 'Konto';es_ES = 'Cuenta';es_CO = 'Cuenta';tr = 'Hesap';it = 'Conto';de = 'Konto'"), 2, , True);
		
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "Order", NStr("en = 'Sort order'; ru = 'Порядок сортировки';pl = 'Kolejność sortowania';es_ES = 'Clasificar el orden';es_CO = 'Clasificar el orden';tr = 'Sıralama';it = 'Ordinamento';de = 'Sortierreihenfolge'"),
			TypeDescriptionString20, TypeDescriptionString20);
		
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "Parent", NStr("en = 'Subordinate to'; ru = 'Подчинен счету';pl = 'Podporządkowany';es_ES = 'Subordinar a';es_CO = 'Subordinar a';tr = 'Üst hesap';it = 'Subordinato a';de = 'Untergeordnet zu'"),
			TypeDescriptionString20, TypeDescriptionColumn);
		
		TypeDescriptionColumn = New TypeDescription("AccountType");
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "Type", NStr("en = 'Normal balance'; ru = 'Обычный остаток';pl = 'Normalne saldo';es_ES = 'Tipo';es_CO = 'Tipo';tr = 'Hesap türü';it = 'Bilancio normale';de = 'Normaler Saldo'"),
			TypeDescriptionString25, TypeDescriptionColumn);
		
		TypeDescriptionColumn = New TypeDescription("EnumRef.GLAccountsTypes");
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "TypeOfAccount", NStr("en = 'Account type'; ru = 'Тип счета';pl = 'Rodzaj konta';es_ES = 'Tipo de cuenta';es_CO = 'Tipo de cuenta';tr = 'Hesap türü';it = 'Tipologia di conto';de = 'Kontotyp'"),
			TypeDescriptionString50, TypeDescriptionColumn);
		
		TypeDescriptionColumn = New TypeDescription("EnumRef.CostAllocationMethod");
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "MethodOfDistribution", NStr("en = 'Allocation method'; ru = 'Способ распределения';pl = 'Metoda alokacji';es_ES = 'Método de asignación';es_CO = 'Método de asignación';tr = 'Tahsis yöntemi';it = 'Metodo di allocazione';de = 'Zuordnungsmethode'"),
			TypeDescriptionString50, TypeDescriptionColumn);
		
		TypeDescriptionColumn = New TypeDescription("EnumRef.FinancialStatement");
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "FinancialStatement", NStr("en = 'Financial statement'; ru = 'Форма отчетности';pl = 'Sprawozdanie finansowe';es_ES = 'Declaración financiera';es_CO = 'Declaración financiera';tr = 'Mali tablo';it = 'Rendiconto finanziario';de = 'Finanzbericht'"),
			TypeDescriptionString50, TypeDescriptionColumn);
		
		TypeDescriptionColumn = New TypeDescription("Boolean");
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "Currency", NStr("en = 'Currency (yes/no)'; ru = 'Валюта (да/нет)';pl = 'Waluta (tak/nie)';es_ES = 'Moneda (sí/no)';es_CO = 'Moneda (sí/no)';tr = 'Para birimi (evet/hayır)';it = 'Valuta (si/no)';de = 'Währung (Ja/Nein)'"),
			TypeDescriptionString10, TypeDescriptionColumn);
		
		TypeDescriptionColumn = New TypeDescription("Boolean");
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "OffBalance", NStr("en = 'Off-balance (yes/no)'; ru = 'Забалансовый (да/нет)';pl = 'Pozabilansowy (tak/nie)';es_ES = 'Fuera de balance (sí/no)';es_CO = 'Fuera de balance (sí/no)';tr = 'Bilanço dışı (evet/hayır)';it = 'Fuori bilancio (si/no)';de = 'Außerbilanz (Ja/Nein)'"),
			TypeDescriptionString10, TypeDescriptionColumn);
			
	ElsIf FillingObjectFullName = "ChartOfAccounts.FinancialChartOfAccounts" Then
		
		TypeDescriptionColumn = New TypeDescription("ChartOfAccountsRef.FinancialChartOfAccounts");
		
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "Code", NStr("en = 'Code'; ru = 'Код';pl = 'Kod';es_ES = 'Código';es_CO = 'Código';tr = 'Kod';it = 'Codice';de = 'Code'"),
			TypeDescriptionString9, TypeDescriptionColumn,
			"Account", NStr("en = 'Account'; ru = 'Учетная запись';pl = 'Konto';es_ES = 'Cuenta';es_CO = 'Cuenta';tr = 'Hesap';it = 'Conto';de = 'Konto'"), 1, True, True);
		
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "Description", NStr("en = 'Description'; ru = 'Наименование';pl = 'Opis';es_ES = 'Descripción';es_CO = 'Descripción';tr = 'Tanım';it = 'Descrizione';de = 'Beschreibung'"),
			TypeDescriptionString120, TypeDescriptionColumn,
			"Account", NStr("en = 'Account'; ru = 'Учетная запись';pl = 'Konto';es_ES = 'Cuenta';es_CO = 'Cuenta';tr = 'Hesap';it = 'Conto';de = 'Konto'"), 2, , True);
		
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "Order", NStr("en = 'Sort order'; ru = 'Порядок сортировки';pl = 'Kolejność sortowania';es_ES = 'Clasificar el orden';es_CO = 'Clasificar el orden';tr = 'Sıralama';it = 'Ordinamento';de = 'Sortierreihenfolge'"),
			TypeDescriptionString9, TypeDescriptionString9);
		
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "Parent", NStr("en = 'Subordinate to'; ru = 'Подчинен счету';pl = 'Podporządkowany';es_ES = 'Subordinar a';es_CO = 'Subordinar a';tr = 'Üst hesap';it = 'Subordinato a';de = 'Untergeordnet zu'"),
			TypeDescriptionString9, TypeDescriptionColumn);
		
		TypeDescriptionColumn = New TypeDescription("AccountType");
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "Type", NStr("en = 'Normal balance'; ru = 'Обычный остаток';pl = 'Normalne saldo';es_ES = 'Tipo';es_CO = 'Tipo';tr = 'Hesap türü';it = 'Bilancio normale';de = 'Normaler Saldo'"),
			TypeDescriptionString25, TypeDescriptionColumn);
		
		TypeDescriptionColumn = New TypeDescription("Boolean");
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "Currency", NStr("en = 'Currency (yes/no)'; ru = 'Валюта (да/нет)';pl = 'Waluta (tak/nie)';es_ES = 'Moneda (sí/no)';es_CO = 'Moneda (sí/no)';tr = 'Para birimi (evet/hayır)';it = 'Valuta (si/no)';de = 'Währung (Ja/Nein)'"),
			TypeDescriptionString10, TypeDescriptionColumn);
		
		TypeDescriptionColumn = New TypeDescription("Boolean");
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "OffBalance", NStr("en = 'Off-balance (yes/no)'; ru = 'Забалансовый (да/нет)';pl = 'Pozabilansowy (tak/nie)';es_ES = 'Fuera de balance (sí/no)';es_CO = 'Fuera de balance (sí/no)';tr = 'Bilanço dışı (evet/hayır)';it = 'Fuori bilancio (si/no)';de = 'Außerbilanz (Ja/Nein)'"),
			TypeDescriptionString10, TypeDescriptionColumn);
			
	ElsIf FillingObjectFullName = "ChartOfAccounts.MasterChartOfAccounts" Then
		
		TypeDescriptionColumn = New TypeDescription("ChartOfAccountsRef.MasterChartOfAccounts");
		
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "Code", NStr("en = 'Code'; ru = 'Код';pl = 'Kod';es_ES = 'Código';es_CO = 'Código';tr = 'Kod';it = 'Codice';de = 'Code'"),
			TypeDescriptionString20, TypeDescriptionColumn,
			"Account", NStr("en = 'Account'; ru = 'Учетная запись';pl = 'Konto';es_ES = 'Cuenta';es_CO = 'Cuenta';tr = 'Hesap';it = 'Conto';de = 'Konto'"), 1, True, True);
		
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "Description", NStr("en = 'Description'; ru = 'Наименование';pl = 'Opis';es_ES = 'Descripción';es_CO = 'Descripción';tr = 'Tanım';it = 'Descrizione';de = 'Beschreibung'"),
			TypeDescriptionString120, TypeDescriptionColumn,
			"Account", NStr("en = 'Account'; ru = 'Учетная запись';pl = 'Konto';es_ES = 'Cuenta';es_CO = 'Cuenta';tr = 'Hesap';it = 'Conto';de = 'Konto'"), 2, , True);
		
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "Order", NStr("en = 'Sort order'; ru = 'Порядок сортировки';pl = 'Kolejność sortowania';es_ES = 'Clasificar el orden';es_CO = 'Clasificar el orden';tr = 'Sıralama';it = 'Ordinamento';de = 'Sortierreihenfolge'"),
			TypeDescriptionString20, TypeDescriptionString20);
		
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "Parent", NStr("en = 'Subordinate to'; ru = 'Подчинен счету';pl = 'Podporządkowany';es_ES = 'Subordinar a';es_CO = 'Subordinar a';tr = 'Üst hesap';it = 'Subordinato a';de = 'Untergeordnet zu'"),
			TypeDescriptionString20, TypeDescriptionColumn);
		
		TypeDescriptionColumn = New TypeDescription("AccountType");
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "Type", NStr("en = 'Normal balance'; ru = 'Обычный остаток';pl = 'Normalne saldo';es_ES = 'Tipo';es_CO = 'Tipo';tr = 'Hesap türü';it = 'Bilancio normale';de = 'Normaler Saldo'"),
			TypeDescriptionString25, TypeDescriptionColumn);
		
		TypeDescriptionColumn = New TypeDescription("CatalogRef.ChartsOfAccounts");
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "ChartOfAccounts", NStr("en = 'Chart of accounts'; ru = 'План счетов';pl = 'Plan kont';es_ES = 'Diagrama primario de las cuentas';es_CO = 'Diagrama primario de las cuentas';tr = 'Hesap planı';it = 'Piano dei conti';de = 'Kontenplan'"),
			TypeDescriptionString50, TypeDescriptionColumn, , , , True, True);
		
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "StartDate", NStr("en = 'Active from'; ru = 'Активен с';pl = 'Aktywny od';es_ES = 'Activo desde';es_CO = 'Activo desde';tr = 'Aktivasyon başlangıcı';it = 'Attivo da';de = 'Aktiv vom'"),
			TypeDescriptionString25, TypeDescriptionDate);
			
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "EndDate", NStr("en = 'Active to'; ru = 'Активен до';pl = 'Aktywny do';es_ES = 'Activo hasta';es_CO = 'Activo hasta';tr = 'Aktivasyon bitişi';it = 'Attivo fino a';de = 'Aktiv bis'"),
			TypeDescriptionString25, TypeDescriptionDate);
		
		TypeDescriptionColumn = New TypeDescription("Boolean");
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "Currency", NStr("en = 'Currency (yes/no)'; ru = 'Валюта (да/нет)';pl = 'Waluta (tak/nie)';es_ES = 'Moneda (sí/no)';es_CO = 'Moneda (sí/no)';tr = 'Para birimi (evet/hayır)';it = 'Valuta (si/no)';de = 'Währung (Ja/Nein)'"),
			TypeDescriptionString10, TypeDescriptionColumn);
			
		TypeDescriptionColumn = New TypeDescription("Boolean");
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "UseQuantity", NStr("en = 'Quantity (yes/no)'; ru = 'Количество (да/нет)';pl = 'Ilość (tak/nie)';es_ES = 'Cantidad (sí/no)';es_CO = 'Cantidad (sí/no)';tr = 'Miktar (evet/hayır)';it = 'Quantità (si/no)';de = 'Menge (Ja/Nein)'"),
			TypeDescriptionString10, TypeDescriptionColumn);
		
		TypeDescriptionColumn = New TypeDescription("Boolean");
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "UseAnalyticalDimensions", NStr("en = 'Analytical dimensions (yes/no)'; ru = 'Аналитические измерения (да/нет)';pl = 'Wymiary analityczne (tak/nie)';es_ES = 'Dimensiones analíticas (sí/no)';es_CO = 'Dimensiones analíticas (sí/no)';tr = 'Analitik boyutlar (evet/hayır)';it = 'Dimensioni analitiche (si/no)';de = 'Analytische Messungen (Ja/Nein)'"),
			TypeDescriptionString10, TypeDescriptionColumn);
		
		TypeDescriptionColumn = New TypeDescription("CatalogRef.AnalyticalDimensionsSets");
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "AnalyticalDimensionsSet", NStr("en = 'Analytical dimension set'; ru = 'Набор аналитических измерений';pl = 'Zestaw wymiarów analitycznych';es_ES = 'Conjunto de dimensión analítica';es_CO = 'Conjunto de dimensión analítica';tr = 'Analitik boyut kümesi';it = 'Set dimensione analitica';de = 'Satz von analytischen Messungen'"),
			TypeDescriptionString50, TypeDescriptionColumn);
			
	ElsIf FillingObjectFullName = "Catalog.ProductsBatches" Then
			
		TypeDescriptionColumn = New TypeDescription("CatalogRef.Products");
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "Barcode", NStr("en = 'Barcode'; ru = 'Штрихкод';pl = 'Kod kreskowy';es_ES = 'Código de barras';es_CO = 'Código de barras';tr = 'Barkod';it = 'Codice a barre';de = 'Barcode'"),
			TypeDescriptionString200, TypeDescriptionColumn,
			"Owner", NStr("en = 'Product'; ru = 'Номенклатура';pl = 'Produkt';es_ES = 'Producto';es_CO = 'Producto';tr = 'Ürün';it = 'Articolo';de = 'Produkt'"), 1, , True);
			
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "SKU", NStr("en = 'ID (item #)'; ru = 'Идентификатор (артикул)';pl = 'ID (pozycja nr)';es_ES = 'Identificador (artículo №)';es_CO = 'Identificador (artículo №)';tr = 'Kimlik (ürün no)';it = 'ID (elemento #)';de = 'ID (Artikel Nr.)'"),
			TypeDescriptionString25, TypeDescriptionColumn,
			"Owner", NStr("en = 'Product'; ru = 'Номенклатура';pl = 'Produkt';es_ES = 'Producto';es_CO = 'Producto';tr = 'Ürün';it = 'Articolo';de = 'Produkt'"), 2, , True);
			
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "ProductsDescription", NStr("en = 'Product description'; ru = 'Наименование номенклатуры';pl = 'Opis produktu';es_ES = 'Descripción del producto';es_CO = 'Descripción del producto';tr = 'Ürün açıklaması';it = 'Descrizione articolo';de = 'Beschreibung des Produkts'"),
			TypeDescriptionString100, TypeDescriptionColumn,
			"Owner", NStr("en = 'Product'; ru = 'Номенклатура';pl = 'Produkt';es_ES = 'Producto';es_CO = 'Producto';tr = 'Ürün';it = 'Articolo';de = 'Produkt'"), 3, , True);
			
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "ProductsDescriptionFull", NStr("en = 'Product detailed description'; ru = 'Полное наименование номенклатуры';pl = 'Szczegółowy opis produktu';es_ES = 'Descripción detallada del producto';es_CO = 'Descripción detallada del producto';tr = 'Ürünlerin ayrıntılı açıklaması';it = 'Descrizione completa dell''articolo';de = 'Produktdetailbeschreibung'"),
			TypeDescriptionString1000, TypeDescriptionColumn,
			"Owner", NStr("en = 'Product'; ru = 'Номенклатура';pl = 'Produkt';es_ES = 'Producto';es_CO = 'Producto';tr = 'Ürün';it = 'Articolo';de = 'Produkt'"), 4, , True);
		
		TypeDescriptionColumn = New TypeDescription("CatalogRef.ProductsBatches");
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "Description", NStr("en = 'Description'; ru = 'Наименование';pl = 'Opis';es_ES = 'Descripción';es_CO = 'Descripción';tr = 'Tanım';it = 'Descrizione';de = 'Beschreibung'"),
			TypeDescriptionString100, TypeDescriptionColumn,
			"Batch", NStr("en = 'Batch'; ru = 'Партия';pl = 'Partia';es_ES = 'Lote';es_CO = 'Lote';tr = 'Parti';it = 'Lotto';de = 'Charge'"), 1);
			
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "BatchNumber", NStr("en = 'Batch number'; ru = 'Номер партии';pl = 'Numer partii';es_ES = 'Número del lote';es_CO = 'Número del lote';tr = 'Parti numarası';it = 'Numero di lotto';de = 'Chargennummer'"), 
			TypeDescriptionString30, TypeDescriptionString30);
		
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "ExpirationDate", NStr("en = 'Expiration date'; ru = 'Срок действия';pl = 'Data zakończenia';es_ES = 'Fecha de expiración';es_CO = 'Fecha de expiración';tr = 'Sona erme tarihi';it = 'Data di scadenza';de = 'Ablaufdatum'"), 
			TypeDescriptionString25, TypeDescriptionDate);
		
		DataImportFromExternalSources.AddImportDescriptionField(
			ImportFieldsTable, "ProductionDate", NStr("en = 'Manufacturing date'; ru = 'Дата производства';pl = 'Data produkcji';es_ES = 'Fecha de fabricación';es_CO = 'Fecha de fabricación';tr = 'Üretim tarihi';it = 'Data di produzione';de = 'Produktionsdatum'"), 
			TypeDescriptionString25, TypeDescriptionDate);
					
		// AdditionalAttributes
		DataImportFromExternalSources.PrepareMapForAdditionalAttributes(DataLoadSettings, Catalogs.AdditionalAttributesAndInfoSets.Catalog_ProductsBatches);
		If DataLoadSettings.AdditionalAttributeDescription.Count() > 0 Then
			
			FieldName = DataImportFromExternalSources.AdditionalAttributesForAddingFieldsName();
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, FieldName, NStr("en = 'Additional attributes'; ru = 'Доп. реквизиты';pl = 'Dodatkowe atrybuty';es_ES = 'Atributos adicionales';es_CO = 'Atributos adicionales';tr = 'Ek öznitelikler';it = 'Attributi aggiuntivi';de = 'Zusätzliche Attribute'"),
				TypeDescriptionString150, TypeDescriptionString11, , , , , , , True,
				Catalogs.AdditionalAttributesAndInfoSets.Catalog_ProductsBatches);
			
		EndIf;
		
	ElsIf DataLoadSettings.FillingObjectFullName = "AccountingRegister.AccountingJournalEntriesCompound" Then
		
		AccountingEntriesSettings = DataLoadSettings.AccountingEntriesSettings;
		IsCompound = (AccountingEntriesSettings.TypeOfEntries = Enums.ChartsOfAccountsTypesOfEntries.Compound);
		MaxAnalyticalDimensionsNumber = AccountingEntriesSettings.MaxAnalyticalDimensionsNumber;
		TypeCurrency = New TypeDescription("CatalogRef.Currencies");
		TypeMasterChartOfAccount = New TypeDescription("ChartOfAccountsRef.MasterChartOfAccounts");
		
		If IsCompound Then
			
			TypeAccountingRecord = New TypeDescription("EnumRef.AccountingRecordType");
			
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, "Period", NStr("en = 'Period'; ru = 'Период';pl = 'Okres';es_ES = 'Período';es_CO = 'Período';tr = 'Dönem';it = 'Periodo';de = 'Zeitraum'"), 
				TypeDescriptionString25, TypeDescriptionDateTime);
				
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, "RecordType", NStr("en = 'Debit/Credit'; ru = 'Дебет/Кредит';pl = 'Zobowiązania / Należności';es_ES = 'Débito/Crédito';es_CO = 'Débito/Crédito';tr = 'Borç/Alacak';it = 'Debito credito';de = 'Soll / Haben'"), 
				TypeDescriptionString25, TypeAccountingRecord, , , , True);
				
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, 
				"AccountDescription", NStr("en = 'Description'; ru = 'Наименование';pl = 'Opis';es_ES = 'Descripción';es_CO = 'Descripción';tr = 'Tanım';it = 'Descrizione';de = 'Beschreibung'"), 
				TypeDescriptionString200, TypeMasterChartOfAccount, 
				"Account", NStr("en = 'Account'; ru = 'Учетная запись';pl = 'Konto';es_ES = 'Cuenta';es_CO = 'Cuenta';tr = 'Hesap';it = 'Conto';de = 'Konto'"), , , True);
				
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, 
				"AccountCode", NStr("en = 'Code'; ru = 'Код';pl = 'Kod';es_ES = 'Código';es_CO = 'Código';tr = 'Kod';it = 'Codice';de = 'Code'"), 
				TypeDescriptionString200, TypeMasterChartOfAccount, 
				"Account", NStr("en = 'Account'; ru = 'Учетная запись';pl = 'Konto';es_ES = 'Cuenta';es_CO = 'Cuenta';tr = 'Hesap';it = 'Conto';de = 'Konto'"), , , True);
				
			If AccountingEntriesSettings.UseAnalyticalDimensions Then
				
				For Index = 1 To MaxAnalyticalDimensionsNumber Do
					
					DataImportFromExternalSources.AddImportDescriptionField(
						ImportFieldsTable, 
						MasterAccountingClientServer.GetExtDimensionFieldName(Index, , "Type"), 
						NStr("en = 'Type'; ru = 'Тип';pl = 'Typ';es_ES = 'Tipo';es_CO = 'Tipo';tr = 'Tür';it = 'Tipo';de = 'Typ'"), 
						TypeDescriptionString100, New TypeDescription(),
						MasterAccountingClientServer.GetExtDimensionFieldName(Index), 
						MasterAccountingClientServer.GetExtDimensionFieldPresentation(Index), 
						Index);
						
					DataImportFromExternalSources.AddImportDescriptionField(
						ImportFieldsTable, 
						MasterAccountingClientServer.GetExtDimensionFieldName(Index, "Number"), 
						NStr("en = 'Number (for documents)'; ru = 'Номер (для документов)';pl = 'Numer (dla dokumentów)';es_ES = 'Número (para documentos)';es_CO = 'Número (para documentos)';tr = 'Sayı (belgeler için)';it = 'Numero (per i documenti)';de = 'Nummer (für Dokumente)'"), 
						TypeDescriptionString20, New TypeDescription(),
						MasterAccountingClientServer.GetExtDimensionFieldName(Index), 
						MasterAccountingClientServer.GetExtDimensionFieldPresentation(Index));
						
					DataImportFromExternalSources.AddImportDescriptionField(
						ImportFieldsTable, 
						MasterAccountingClientServer.GetExtDimensionFieldName(Index, "Date"), 
						NStr("en = 'Date (for documents)'; ru = 'Дата (для документов)';pl = 'Data (dla dokumentów)';es_ES = 'Fecha (para documentos)';es_CO = 'Fecha (para documentos)';tr = 'Tarih (belgeler için)';it = 'Data (per i documenti)';de = 'Datum (für Dokumente)'"), 
						TypeDescriptionString20, New TypeDescription(),
						MasterAccountingClientServer.GetExtDimensionFieldName(Index), 
						MasterAccountingClientServer.GetExtDimensionFieldPresentation(Index));
						
					DataImportFromExternalSources.AddImportDescriptionField(
						ImportFieldsTable, 
						MasterAccountingClientServer.GetExtDimensionFieldName(Index, "Code"), 
						NStr("en = 'Code (for catalogs)'; ru = 'Код (для справочников)';pl = 'Kod (dla katalogów)';es_ES = 'Código (para catálogos)';es_CO = 'Código (para catálogos)';tr = 'Kod (kataloglar için)';it = 'Codice (per i cataloghi)';de = 'Code (für Kataloge)'"), 
						TypeDescriptionString20, New TypeDescription(),
						MasterAccountingClientServer.GetExtDimensionFieldName(Index), 
						MasterAccountingClientServer.GetExtDimensionFieldPresentation(Index));
						
					DataImportFromExternalSources.AddImportDescriptionField(
						ImportFieldsTable, 
						MasterAccountingClientServer.GetExtDimensionFieldName(Index, "Description"), 
						NStr("en = 'Description (for catalogs)'; ru = 'Наименование (для справочников)';pl = 'Opis (dla katalogów)';es_ES = 'Descripción (para catálogos)';es_CO = 'Descripción (para catálogos)';tr = 'Tanım (kataloglar için)';it = 'Descrizione (per i cataloghi)';de = 'Beschreibung (für Kataloge)'"), 
						TypeDescriptionString200, New TypeDescription(),
						MasterAccountingClientServer.GetExtDimensionFieldName(Index), 
						MasterAccountingClientServer.GetExtDimensionFieldPresentation(Index));
						
					DataImportFromExternalSources.AddImportDescriptionField(
						ImportFieldsTable, 
						MasterAccountingClientServer.GetExtDimensionFieldName(Index, "Error"), 
						NStr("en = 'Error'; ru = 'Ошибка';pl = 'Błąd';es_ES = 'Error';es_CO = 'Error';tr = 'Hata';it = 'Errore';de = 'Fehler'"), 
						TypeDescriptionString200, New TypeDescription(),
						MasterAccountingClientServer.GetExtDimensionFieldName(Index), 
						MasterAccountingClientServer.GetExtDimensionFieldPresentation(Index), , , , False);
					
				EndDo;
				
			EndIf;
			
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, 
				"CurrencyCode", NStr("en = 'Transaction currency name (numeric)'; ru = 'Валюта операции (числовой код)';pl = 'Nazwa waluty transakcji (numeryczna)';es_ES = 'Nombre de la moneda de transacción (numérico)';es_CO = 'Nombre de la moneda de transacción (numérico)';tr = 'İşlem para birimi adı (sayısal)';it = 'Nome valuta di transazione (numerico)';de = 'Name der Transaktionswährung (numerisch)'"), 
				TypeDescriptionString25, TypeCurrency, 
				"Currency", NStr("en = 'Transaction currency'; ru = 'Валюта операции';pl = 'Waluta transakcji';es_ES = 'Moneda de transacción';es_CO = 'Moneda de transacción';tr = 'İşlem para birimi';it = 'Valuta della transazione';de = 'Transaktionswährung'"));
				
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, 
				"CurrencyName", NStr("en = 'Transaction currency name (ISO code)'; ru = 'Валюта операции (код ISO)';pl = 'Nazwa waluty transakcji (kod ISO)';es_ES = 'Nombre de la moneda de transacción (código ISO)';es_CO = 'Nombre de la moneda de transacción (código ISO)';tr = 'İşlem para birimi adı (ISO kodu)';it = 'Nome valuta della transazione (Codice ISO)';de = 'Name Transaktionswährung (ISO-Code)'"), 
				TypeDescriptionString25, TypeCurrency, 
				"Currency", NStr("en = 'Transaction currency'; ru = 'Валюта операции';pl = 'Waluta transakcji';es_ES = 'Moneda de transacción';es_CO = 'Moneda de transacción';tr = 'İşlem para birimi';it = 'Valuta della transazione';de = 'Transaktionswährung'"));
				
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, 
				"AmountCur", NStr("en = 'Amount (Transaction currency)'; ru = 'Сумма (Валюта операции)';pl = 'Wartość (Waluta transakcji)';es_ES = 'Importe (Moneda de transacción)';es_CO = 'Importe (Moneda de transacción)';tr = 'Tutar (İşlem para birimi)';it = 'Importo (valuta transazione)';de = 'Betrag (Transaktionswährung)'"), 
				TypeDescriptionString20, TypeDescriptionNumber15_2);
				
			If AccountingEntriesSettings.UseQuantity Then
				
				DataImportFromExternalSources.AddImportDescriptionField(
					ImportFieldsTable, 
					"Quantity", NStr("en = 'Quantity'; ru = 'Количество';pl = 'Ilość';es_ES = 'Cantidad';es_CO = 'Cantidad';tr = 'Miktar';it = 'Quantità';de = 'Menge'"), 
					TypeDescriptionString20, TypeDescriptionNumber15_3);
					
			EndIf;
			
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, 
				"Amount", NStr("en = 'Amount (Presentation currency)'; ru = 'Сумма (Валюта представления отчетности)';pl = 'Wartość (Waluta prezentacji)';es_ES = 'Importe (Moneda de presentación)';es_CO = 'Importe (Moneda de presentación)';tr = 'Tutar (Finansal tablo para birimi)';it = 'Importo (Valuta di presentazione)';de = 'Betrag (Währung für die Berichtserstattung)'"), 
				TypeDescriptionString20, TypeDescriptionNumber15_2, , , , True);
				
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, 
				"Content", NStr("en = 'Entry description'; ru = 'Содержание проводки';pl = 'Opis wpisu';es_ES = 'Descripción de la entrada de diario';es_CO = 'Descripción de la entrada de diario';tr = 'Giriş açıklaması';it = 'Descrizione voce';de = 'Buchungsbeschreibung'"), 
				TypeDescriptionString100, TypeDescriptionString100, , , , True);
			
		Else
			
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, "Period", NStr("en = 'Period'; ru = 'Период';pl = 'Okres';es_ES = 'Período';es_CO = 'Período';tr = 'Dönem';it = 'Periodo';de = 'Zeitraum'"), 
				TypeDescriptionString25, TypeDescriptionDateTime);
				
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, 
				"DebitDescription", NStr("en = 'Description'; ru = 'Наименование';pl = 'Opis';es_ES = 'Descripción';es_CO = 'Descripción';tr = 'Tanım';it = 'Descrizione';de = 'Beschreibung'"), 
				TypeDescriptionString200, TypeMasterChartOfAccount, 
				"AccountDr", NStr("en = 'Account Dr'; ru = 'Счет Дт';pl = 'Konto Wn';es_ES = 'Cuenta Dr';es_CO = 'Cuenta Dr';tr = 'Alacak hesabı';it = 'Conto deb';de = 'Konto Soll'"), , , True);
				
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, 
				"DebitCode", NStr("en = 'Code'; ru = 'Код';pl = 'Kod';es_ES = 'Código';es_CO = 'Código';tr = 'Kod';it = 'Codice';de = 'Code'"), 
				TypeDescriptionString200, TypeMasterChartOfAccount, 
				"AccountDr", NStr("en = 'Account Dr'; ru = 'Счет Дт';pl = 'Konto Wn';es_ES = 'Cuenta Dr';es_CO = 'Cuenta Dr';tr = 'Alacak hesabı';it = 'Conto deb';de = 'Konto Soll'"), , , True);
				
			If AccountingEntriesSettings.UseAnalyticalDimensions Then
				
				For Index = 1 To MaxAnalyticalDimensionsNumber Do
					
					DataImportFromExternalSources.AddImportDescriptionField(
						ImportFieldsTable, 
						MasterAccountingClientServer.GetExtDimensionFieldName(Index, "Dr", "Type"), 
						NStr("en = 'Type'; ru = 'Тип';pl = 'Typ';es_ES = 'Tipo';es_CO = 'Tipo';tr = 'Tür';it = 'Tipo';de = 'Typ'"), 
						TypeDescriptionString100, New TypeDescription(),
						MasterAccountingClientServer.GetExtDimensionFieldName(Index, "Dr"), 
						MasterAccountingClientServer.GetExtDimensionFieldPresentation(Index, "Dr"));
						
					DataImportFromExternalSources.AddImportDescriptionField(
						ImportFieldsTable, 
						MasterAccountingClientServer.GetExtDimensionFieldName(Index, "Dr", "Number"), 
						NStr("en = 'Number (for documents)'; ru = 'Номер (для документов)';pl = 'Numer (dla dokumentów)';es_ES = 'Número (para documentos)';es_CO = 'Número (para documentos)';tr = 'Sayı (belgeler için)';it = 'Numero (per i documenti)';de = 'Nummer (für Dokumente)'"), 
						TypeDescriptionString20, New TypeDescription(),
						MasterAccountingClientServer.GetExtDimensionFieldName(Index, "Dr"), 
						MasterAccountingClientServer.GetExtDimensionFieldPresentation(Index, "Dr"));
						
					DataImportFromExternalSources.AddImportDescriptionField(
						ImportFieldsTable, 
						MasterAccountingClientServer.GetExtDimensionFieldName(Index, "Dr", "Date"), 
						NStr("en = 'Date (for documents)'; ru = 'Дата (для документов)';pl = 'Data (dla dokumentów)';es_ES = 'Fecha (para documentos)';es_CO = 'Fecha (para documentos)';tr = 'Tarih (belgeler için)';it = 'Data (per i documenti)';de = 'Datum (für Dokumente)'"), 
						TypeDescriptionString20, New TypeDescription(),
						MasterAccountingClientServer.GetExtDimensionFieldName(Index, "Dr"), 
						MasterAccountingClientServer.GetExtDimensionFieldPresentation(Index, "Dr"));
						
					DataImportFromExternalSources.AddImportDescriptionField(
						ImportFieldsTable, 
						MasterAccountingClientServer.GetExtDimensionFieldName(Index, "Dr", "Code"), 
						NStr("en = 'Code (for catalogs)'; ru = 'Код (для справочников)';pl = 'Kod (dla katalogów)';es_ES = 'Código (para catálogos)';es_CO = 'Código (para catálogos)';tr = 'Kod (kataloglar için)';it = 'Codice (per i cataloghi)';de = 'Code (für Kataloge)'"), 
						TypeDescriptionString20, New TypeDescription(),
						MasterAccountingClientServer.GetExtDimensionFieldName(Index, "Dr"), 
						MasterAccountingClientServer.GetExtDimensionFieldPresentation(Index, "Dr"));
						
					DataImportFromExternalSources.AddImportDescriptionField(
						ImportFieldsTable, 
						MasterAccountingClientServer.GetExtDimensionFieldName(Index, "Dr", "Description"), 
						NStr("en = 'Description (for catalogs)'; ru = 'Наименование (для справочников)';pl = 'Opis (dla katalogów)';es_ES = 'Descripción (para catálogos)';es_CO = 'Descripción (para catálogos)';tr = 'Tanım (kataloglar için)';it = 'Descrizione (per i cataloghi)';de = 'Beschreibung (für Kataloge)'"), 
						TypeDescriptionString200, New TypeDescription(),
						MasterAccountingClientServer.GetExtDimensionFieldName(Index, "Dr"), 
						MasterAccountingClientServer.GetExtDimensionFieldPresentation(Index, "Dr"));
						
					DataImportFromExternalSources.AddImportDescriptionField(
						ImportFieldsTable, 
						MasterAccountingClientServer.GetExtDimensionFieldName(Index, "Dr", "Error"), 
						NStr("en = 'Error'; ru = 'Ошибка';pl = 'Błąd';es_ES = 'Error';es_CO = 'Error';tr = 'Hata';it = 'Errore';de = 'Fehler'"), 
						TypeDescriptionString200, New TypeDescription(),
						MasterAccountingClientServer.GetExtDimensionFieldName(Index, "Dr"), 
						MasterAccountingClientServer.GetExtDimensionFieldPresentation(Index, "Dr"), , , , False);
					
				EndDo;
				
			EndIf;
			
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, 
				"CurrencyCodeDr", NStr("en = 'Transaction currency Dr name (numeric)'; ru = 'Валюта операции Дт (числовой код)';pl = 'Nazwa waluty transakcji Wn (numeryczna)';es_ES = 'Nombre de la moneda de transacción Débito (numérico)';es_CO = 'Nombre de la moneda de transacción Débito (numérico)';tr = 'İşlem para birimi Borç adı (sayısal)';it = 'Valuta della transazione nome deb (numerico)';de = 'Name der Transaktionswährung Soll (numerisch)'"), 
				TypeDescriptionString25, TypeCurrency, 
				"CurrencyDr", NStr("en = 'Transaction currency Dr'; ru = 'Валюта операции Дт';pl = 'Waluta transakcji Wn';es_ES = 'Moneda de transacción Débito';es_CO = 'Moneda de transacción Débito';tr = 'İşlem para birimi Borç';it = 'Valuta della transazione deb';de = 'Transaktionswährung Soll'"));
				
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, 
				"CurrencyNameDr", NStr("en = 'Transaction currency Dr name (ISO code)'; ru = 'Валюта операции Дт (код ISO)';pl = 'Nazwa waluty transakcji Wn (kod ISO)';es_ES = 'Nombre de la moneda de transacción Débito (código ISO)';es_CO = 'Nombre de la moneda de transacción Débito (código ISO)';tr = 'İşlem para birimi Borç adı (ISO kodu)';it = 'Valuta della transazione nome deb (Codice ISO)';de = 'Name Transaktionswährung Soll (ISO-Code)'"), 
				TypeDescriptionString25, TypeCurrency, 
				"CurrencyDr", NStr("en = 'Transaction currency Dr'; ru = 'Валюта операции Дт';pl = 'Waluta transakcji Wn';es_ES = 'Moneda de transacción Débito';es_CO = 'Moneda de transacción Débito';tr = 'İşlem para birimi Borç';it = 'Valuta della transazione deb';de = 'Transaktionswährung Soll'"));
				
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, 
				"AmountCurDr", NStr("en = 'Amount Dr (Transaction currency)'; ru = 'Сумма Дт (Валюта операции)';pl = 'Wartość Wn (waluta transakcji)';es_ES = 'Importe Débito (moneda de transacción)';es_CO = 'Importe Débito (moneda de transacción)';tr = 'Tutar Borç (İşlem para birimi)';it = 'Importo Deb (Valuta transazione)';de = 'Betrag Soll (Transaktionswährung)'"), 
				TypeDescriptionString20, TypeDescriptionNumber15_2);
				
			If AccountingEntriesSettings.UseQuantity Then
				
				DataImportFromExternalSources.AddImportDescriptionField(
					ImportFieldsTable, 
					"QuantityDr", NStr("en = 'Quantity Dr'; ru = 'Количество Дт';pl = 'Ilość Wn';es_ES = 'Cantidad Dr';es_CO = 'Cantidad Dr';tr = 'Miktar Borç';it = 'Quantità Deb';de = 'Menge Soll'"), 
					TypeDescriptionString20, TypeDescriptionNumber15_3);
					
			EndIf;
				
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, 
				"CreditDescription", NStr("en = 'Description'; ru = 'Наименование';pl = 'Opis';es_ES = 'Descripción';es_CO = 'Descripción';tr = 'Tanım';it = 'Descrizione';de = 'Beschreibung'"), 
				TypeDescriptionString200, TypeMasterChartOfAccount, 
				"AccountCr", NStr("en = 'Account Cr'; ru = 'Счет Кт';pl = 'Konto Ma';es_ES = 'Cuenta Cr';es_CO = 'Cuenta Cr';tr = 'Borç hesabı';it = 'Conto Cred';de = 'Konto Haben'"), , , True);
				
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, 
				"CreditCode", NStr("en = 'Code'; ru = 'Код';pl = 'Kod';es_ES = 'Código';es_CO = 'Código';tr = 'Kod';it = 'Codice';de = 'Code'"), 
				TypeDescriptionString200, TypeMasterChartOfAccount, 
				"AccountCr", NStr("en = 'Account Cr'; ru = 'Счет Кт';pl = 'Konto Ma';es_ES = 'Cuenta Cr';es_CO = 'Cuenta Cr';tr = 'Borç hesabı';it = 'Conto Cred';de = 'Konto Haben'"), , , True);
				
			If AccountingEntriesSettings.UseAnalyticalDimensions Then
			
				For Index = 1 To MaxAnalyticalDimensionsNumber Do
					
					DataImportFromExternalSources.AddImportDescriptionField(
						ImportFieldsTable, 
						MasterAccountingClientServer.GetExtDimensionFieldName(Index, "Cr", "Type"), 
						NStr("en = 'Type'; ru = 'Тип';pl = 'Typ';es_ES = 'Tipo';es_CO = 'Tipo';tr = 'Tür';it = 'Tipo';de = 'Typ'"), 
						TypeDescriptionString100, New TypeDescription(),
						MasterAccountingClientServer.GetExtDimensionFieldName(Index, "Cr"), 
						MasterAccountingClientServer.GetExtDimensionFieldPresentation(Index, "Cr"));
						
					DataImportFromExternalSources.AddImportDescriptionField(
						ImportFieldsTable, 
						MasterAccountingClientServer.GetExtDimensionFieldName(Index, "Cr", "Number"), 
						NStr("en = 'Number (for documents)'; ru = 'Номер (для документов)';pl = 'Numer (dla dokumentów)';es_ES = 'Número (para documentos)';es_CO = 'Número (para documentos)';tr = 'Sayı (belgeler için)';it = 'Numero (per i documenti)';de = 'Nummer (für Dokumente)'"), 
						TypeDescriptionString20, New TypeDescription(),
						MasterAccountingClientServer.GetExtDimensionFieldName(Index, "Cr"), 
						MasterAccountingClientServer.GetExtDimensionFieldPresentation(Index, "Cr"));
						
					DataImportFromExternalSources.AddImportDescriptionField(
						ImportFieldsTable, 
						MasterAccountingClientServer.GetExtDimensionFieldName(Index, "Cr", "Date"), 
						NStr("en = 'Date (for documents)'; ru = 'Дата (для документов)';pl = 'Data (dla dokumentów)';es_ES = 'Fecha (para documentos)';es_CO = 'Fecha (para documentos)';tr = 'Tarih (belgeler için)';it = 'Data (per i documenti)';de = 'Datum (für Dokumente)'"), 
						TypeDescriptionString20, New TypeDescription(),
						MasterAccountingClientServer.GetExtDimensionFieldName(Index, "Cr"), 
						MasterAccountingClientServer.GetExtDimensionFieldPresentation(Index, "Cr"));
						
					DataImportFromExternalSources.AddImportDescriptionField(
						ImportFieldsTable, 
						MasterAccountingClientServer.GetExtDimensionFieldName(Index, "Cr", "Code"), 
						NStr("en = 'Code (for catalogs)'; ru = 'Код (для справочников)';pl = 'Kod (dla katalogów)';es_ES = 'Código (para catálogos)';es_CO = 'Código (para catálogos)';tr = 'Kod (kataloglar için)';it = 'Codice (per i cataloghi)';de = 'Code (für Kataloge)'"), 
						TypeDescriptionString20, New TypeDescription(),
						MasterAccountingClientServer.GetExtDimensionFieldName(Index, "Cr"), 
						MasterAccountingClientServer.GetExtDimensionFieldPresentation(Index, "Cr"));
						
					DataImportFromExternalSources.AddImportDescriptionField(
						ImportFieldsTable, 
						MasterAccountingClientServer.GetExtDimensionFieldName(Index, "Cr", "Description"), 
						NStr("en = 'Description (for catalogs)'; ru = 'Наименование (для справочников)';pl = 'Opis (dla katalogów)';es_ES = 'Descripción (para catálogos)';es_CO = 'Descripción (para catálogos)';tr = 'Tanım (kataloglar için)';it = 'Descrizione (per i cataloghi)';de = 'Beschreibung (für Kataloge)'"), 
						TypeDescriptionString200, New TypeDescription(),
						MasterAccountingClientServer.GetExtDimensionFieldName(Index, "Cr"), 
						MasterAccountingClientServer.GetExtDimensionFieldPresentation(Index, "Cr"));
						
					DataImportFromExternalSources.AddImportDescriptionField(
						ImportFieldsTable, 
						MasterAccountingClientServer.GetExtDimensionFieldName(Index, "Cr", "Error"), 
						NStr("en = 'Error'; ru = 'Ошибка';pl = 'Błąd';es_ES = 'Error';es_CO = 'Error';tr = 'Hata';it = 'Errore';de = 'Fehler'"), 
						TypeDescriptionString200, New TypeDescription(),
						MasterAccountingClientServer.GetExtDimensionFieldName(Index, "Cr"), 
						MasterAccountingClientServer.GetExtDimensionFieldPresentation(Index, "Cr"), , , , False);
					
				EndDo;
				
			EndIf;
			
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, 
				"CurrencyCodeCr", NStr("en = 'Transaction currency Cr name (numeric)'; ru = 'Валюта операции Кт (числовой код)';pl = 'Nazwa waluty transakcji Ma (numeryczna)';es_ES = 'Nombre de la moneda de transacción Crédito (numérico)';es_CO = 'Nombre de la moneda de transacción Crédito (numérico)';tr = 'İşlem para birimi Alacak adı (sayısal)';it = 'Valuta della transazione cred nome (numerico)';de = 'Name der Transaktionswährung Haben (numerisch)'"), 
				TypeDescriptionString25, TypeCurrency, 
				"CurrencyCr", NStr("en = 'Transaction currency Cr'; ru = 'Валюта операции Кт';pl = 'Transaction currency Ma';es_ES = 'Moneda de transacción Crédito';es_CO = 'Moneda de transacción Crédito';tr = 'İşlem para birimi Alacak';it = 'Valuta della transazione cred';de = 'Transaktionswährung Haben'"));
				
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, 
				"CurrencyNameCr", NStr("en = 'Transaction currency Cr name (ISO code)'; ru = 'Валюта операции Кт (код ISO)';pl = 'Nazwa waluty transakcji Ma (kod ISO)';es_ES = 'Nombre de la moneda de transacción Crédito (código ISO)';es_CO = 'Nombre de la moneda de transacción Crédito (código ISO)';tr = 'İşlem para birimi Alacak adı (ISO kodu)';it = 'Valuta della transazione nome cred (Codice ISO)';de = 'Name Transaktionswährung Haben (ISO-Code)'"), 
				TypeDescriptionString25, TypeCurrency, 
				"CurrencyCr", NStr("en = 'Transaction currency Cr'; ru = 'Валюта операции Кт';pl = 'Transaction currency Ma';es_ES = 'Moneda de transacción Crédito';es_CO = 'Moneda de transacción Crédito';tr = 'İşlem para birimi Alacak';it = 'Valuta della transazione cred';de = 'Transaktionswährung Haben'"));
				
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, 
				"AmountCurCr", NStr("en = 'Amount Cr (Transaction currency)'; ru = 'Сумма Кт (Валюта операции)';pl = 'Wartość Ma (waluta transakcji)';es_ES = 'Importe Crédito (moneda de transacción)';es_CO = 'Importe Crédito (moneda de transacción)';tr = 'Tutar Alacak (İşlem para birimi)';it = 'Importo cred (Valuta transazione )';de = 'Betrag Haben (Transaktionswährung)'"), 
				TypeDescriptionString20, TypeDescriptionNumber15_2);
				
			If AccountingEntriesSettings.UseQuantity Then
				
				DataImportFromExternalSources.AddImportDescriptionField(
					ImportFieldsTable, 
					"QuantityCr", NStr("en = 'Quantity Cr'; ru = 'Количество Кт';pl = 'Ilość Ma';es_ES = 'Cantidad crédito';es_CO = 'Cantidad crédito';tr = 'Miktar Alacak';it = 'Quantità Cred';de = 'Menge Haben'"), 
					TypeDescriptionString20, TypeDescriptionNumber15_3);
					
			EndIf;
				
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, 
				"Amount", NStr("en = 'Amount (Presentation currency)'; ru = 'Сумма (Валюта представления отчетности)';pl = 'Wartość (Waluta prezentacji)';es_ES = 'Importe (Moneda de presentación)';es_CO = 'Importe (Moneda de presentación)';tr = 'Tutar (Finansal tablo para birimi)';it = 'Importo (Valuta di presentazione)';de = 'Betrag (Währung für die Berichtserstattung)'"), 
				TypeDescriptionString20, TypeDescriptionNumber15_2, , , , True);
				
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, 
				"Content", NStr("en = 'Entry description'; ru = 'Содержание проводки';pl = 'Opis wpisu';es_ES = 'Descripción de la entrada de diario';es_CO = 'Descripción de la entrada de diario';tr = 'Giriş açıklaması';it = 'Descrizione voce';de = 'Buchungsbeschreibung'"), 
				TypeDescriptionString100, TypeDescriptionString100, , , , True);
		
		EndIf;
			
	Else // Inventory
		
		If FillingObjectFullName = "Document.ActualSalesVolume.TabularSection.Inventory"
			And DataLoadSettings.CounterpartyAndContractPositionInTabularSection Then
			
			TypeDescriptionColumn = New TypeDescription("CatalogRef.Counterparties");
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, "CounterpartyDescription", NStr("en = 'Counterparty name'; ru = 'Наименование контрагента';pl = 'Nazwa kontrahenta';es_ES = 'Nombre de la contraparte';es_CO = 'Nombre de la contraparte';tr = 'Cari hesap ismi';it = 'Nome controparte';de = 'Name des Geschäftspartners'"),
				TypeDescriptionString100, TypeDescriptionColumn,
				"Counterparty", NStr("en = 'Counterparty'; ru = 'Контрагент';pl = 'Kontrahent';es_ES = 'Contraparte';es_CO = 'Contraparte';tr = 'Cari hesap';it = 'Controparte';de = 'Geschäftspartner'"), 1, , True);
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, "CounterpartyTIN", NStr("en = 'Counterparty TIN'; ru = 'ИНН контрагента';pl = 'NIP kontrahenta';es_ES = 'El número de identificación del contribuyente de la contraparte';es_CO = 'El número de identificación del contribuyente de la contraparte';tr = 'Cari hesap VKN';it = 'Cod.Fiscale della controparte';de = 'Geschäftspartnersteuernummer'"),
				TypeDescriptionString100, TypeDescriptionColumn,
				"Counterparty", NStr("en = 'Counterparty'; ru = 'Контрагент';pl = 'Kontrahent';es_ES = 'Contraparte';es_CO = 'Contraparte';tr = 'Cari hesap';it = 'Controparte';de = 'Geschäftspartner'"), 2, , True);
				
			TypeDescriptionColumn = New TypeDescription("CatalogRef.CounterpartyContracts");
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, "ContractDescription", NStr("en = 'Contract name'; ru = 'Наименование договора';pl = 'Nazwa kontraktu';es_ES = 'Nombre del contrato';es_CO = 'Nombre del contrato';tr = 'Sözleşme ismi';it = 'Nome contratto';de = 'Vertragsname'"),
				TypeDescriptionString100, TypeDescriptionColumn,
				"Contract", NStr("en = 'Contract'; ru = 'Договор';pl = 'Kontrakt';es_ES = 'Contrato';es_CO = 'Contrato';tr = 'Sözleşme';it = 'Contratto';de = 'Vertrag'"), 1, , True);
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, "ContractNo", NStr("en = 'Contract number'; ru = 'Номер договора';pl = 'Numer umowy';es_ES = 'Número del contrato';es_CO = 'Número del contrato';tr = 'Sözleşme numarası';it = 'Numero di contratto';de = 'Vertragsnummer'"),
				TypeDescriptionString50, TypeDescriptionColumn,
				"Contract", NStr("en = 'Contract'; ru = 'Договор';pl = 'Kontrakt';es_ES = 'Contrato';es_CO = 'Contrato';tr = 'Sözleşme';it = 'Contratto';de = 'Vertrag'"), 2, , True);
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, "ContractDate", NStr("en = 'Contract date'; ru = 'Дата договора';pl = 'Data podpisania umowy';es_ES = 'Fecha de contrato';es_CO = 'Fecha de contrato';tr = 'Sözleşme tarihi';it = 'Data del contratto';de = 'Vertragsdatum'"),
				TypeDescriptionString50, TypeDescriptionColumn,
				"Contract", NStr("en = 'Contract'; ru = 'Договор';pl = 'Kontrakt';es_ES = 'Contrato';es_CO = 'Contrato';tr = 'Sözleşme';it = 'Contratto';de = 'Vertrag'"), 3, , True);
		
		ElsIf FillingObjectFullName = "Document.OpeningBalanceEntry.TabularSection.Inventory" Then
			
			If DataLoadSettings.DocumentAttributes.InventoryValuationMethod = Enums.InventoryValuationMethods.FIFO Then

				TypeArray = Metadata.Documents.OpeningBalanceEntry.TabularSections.Inventory.Attributes.Document.Type.Types();
				TypeDescriptionColumn = New TypeDescription(TypeArray);
				DataImportFromExternalSources.AddImportDescriptionField(
					ImportFieldsTable, "DocumentType", NStr("en = 'Document type'; ru = 'Тип документа';pl = 'Typ dokumentu';es_ES = 'Tipo de documento';es_CO = 'Tipo de documento';tr = 'Belge türü';it = 'Tipo di documento';de = 'Dokumententyp'"),
					TypeDescriptionString50, TypeDescriptionColumn,
					"Document", NStr("en = 'Acquisition  document'; ru = 'Документ приобретения';pl = 'Dokument zakupu';es_ES = 'Documento de adquisición';es_CO = 'Documento de adquisición';tr = 'Alım belgesi';it = 'Documento di acquisizione';de = 'Einkaufsdokument'"), , , True);
				DataImportFromExternalSources.AddImportDescriptionField(
					ImportFieldsTable, "DocumentNumber", NStr("en = 'Document number'; ru = 'Номер документа';pl = 'Numer dokumentu';es_ES = 'Número del documento';es_CO = 'Número del documento';tr = 'Belge numarası';it = 'Numero del documento';de = 'Dokumentnummer'"),
					TypeDescriptionString25, TypeDescriptionColumn,
					"Document", NStr("en = 'Acquisition  document'; ru = 'Документ приобретения';pl = 'Dokument zakupu';es_ES = 'Documento de adquisición';es_CO = 'Documento de adquisición';tr = 'Alım belgesi';it = 'Documento di acquisizione';de = 'Einkaufsdokument'"), , True, True);
				DataImportFromExternalSources.AddImportDescriptionField(
					ImportFieldsTable, "DocumentDate", NStr("en = 'Document date'; ru = 'Дата документа';pl = 'Data dokumentu';es_ES = 'Fecha del documento';es_CO = 'Fecha del documento';tr = 'Belge tarihi';it = 'Data del documento';de = 'Dokumentdatum'"),
					TypeDescriptionString25, TypeDescriptionColumn,
					"Document", NStr("en = 'Acquisition  document'; ru = 'Документ приобретения';pl = 'Dokument zakupu';es_ES = 'Documento de adquisición';es_CO = 'Documento de adquisición';tr = 'Alım belgesi';it = 'Documento di acquisizione';de = 'Einkaufsdokument'"), , , True);
					
			EndIf;
		EndIf;
		
		If GetFunctionalOption("UseSeveralWarehouses")
			And Common.HasObjectAttribute("StructuralUnit", FilledObject) Then
			TypeDescriptionColumn = New TypeDescription("CatalogRef.BusinessUnits");
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, "StructuralUnitDescription", NStr("en = 'Warehouse description'; ru = 'Наименование склада';pl = 'Opis magazynu';es_ES = 'Descripción del almacén';es_CO = 'Descripción del almacén';tr = 'Ambar tanımı';it = 'Descrizione magazzino';de = 'Lagerbeschreibung'"),
				TypeDescriptionString100, TypeDescriptionColumn,
				"StructuralUnit", NStr("en = 'Warehouse'; ru = 'Склад';pl = 'Magazyn';es_ES = 'Almacén';es_CO = 'Almacén';tr = 'Ambar';it = 'Magazzino';de = 'Lager'"), 1, , True);
		
		EndIf;
		
		If GetFunctionalOption("UseStorageBins")
			And Common.HasObjectAttribute("Cell", FilledObject) Then
			TypeDescriptionColumn = New TypeDescription("CatalogRef.Cells");
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, "CellDescription", NStr("en = 'Storage bin description'; ru = 'Наименование складской ячейки';pl = 'Opis komórki magazynowej';es_ES = 'Descripción del área de almacenamiento';es_CO = 'Descripción del área de almacenamiento';tr = 'Depo tanımı';it = 'Descrizione contenitori di magazzino';de = 'Lagerplatzbeschreibung'"),
				TypeDescriptionString50, TypeDescriptionColumn,
				"Cell", NStr("en = 'Storage bin'; ru = 'Складская ячейка';pl = 'Komórka magazynowa';es_ES = 'Área de almacenamiento';es_CO = 'Área de almacenamiento';tr = 'Depo';it = 'Contenitore di magazzino';de = 'Lagerplatz'"), 1);
		EndIf;
		
		If Common.HasObjectAttribute("Products", FilledObject) Then
			TypeDescriptionColumn = New TypeDescription("CatalogRef.Products");
			
			TypeDescriptionColumn = New TypeDescription("CatalogRef.Products");
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, "Code", NStr("en = 'Code'; ru = 'Код';pl = 'Kod';es_ES = 'Código';es_CO = 'Código';tr = 'Kod';it = 'Codice';de = 'Code'"),
				TypeDescriptionString11, TypeDescriptionColumn,
				"Products", NStr("en = 'Product'; ru = 'Номенклатура';pl = 'Produkt';es_ES = 'Producto';es_CO = 'Producto';tr = 'Ürün';it = 'Articolo';de = 'Produkt'"), 1, , True);
			
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, "Barcode", NStr("en = 'Barcode'; ru = 'Штрихкод';pl = 'Kod kreskowy';es_ES = 'Código de barras';es_CO = 'Código de barras';tr = 'Barkod';it = 'Codice a barre';de = 'Barcode'"),
				TypeDescriptionString200, TypeDescriptionColumn,
				"Products", NStr("en = 'Product'; ru = 'Номенклатура';pl = 'Produkt';es_ES = 'Producto';es_CO = 'Producto';tr = 'Ürün';it = 'Articolo';de = 'Produkt'"), 2, , True);
			
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, "SKU", NStr("en = 'ID (item #)'; ru = 'Идентификатор (артикул)';pl = 'ID (pozycja nr)';es_ES = 'Identificador (artículo №)';es_CO = 'Identificador (artículo №)';tr = 'Kimlik (ürün no)';it = 'ID (elemento #)';de = 'ID (Artikel Nr.)'"),
				TypeDescriptionString25, TypeDescriptionColumn,
				"Products", NStr("en = 'Product'; ru = 'Номенклатура';pl = 'Produkt';es_ES = 'Producto';es_CO = 'Producto';tr = 'Ürün';it = 'Articolo';de = 'Produkt'"), 3, , True);
			
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, "ProductsDescription", NStr("en = 'Description'; ru = 'Наименование';pl = 'Opis';es_ES = 'Descripción';es_CO = 'Descripción';tr = 'Tanım';it = 'Descrizione';de = 'Beschreibung'"),
				TypeDescriptionString100, TypeDescriptionColumn,
				"Products", NStr("en = 'Product'; ru = 'Номенклатура';pl = 'Produkt';es_ES = 'Producto';es_CO = 'Producto';tr = 'Ürün';it = 'Articolo';de = 'Produkt'"), 4, , True);
			
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, "ProductsDescriptionFull", NStr("en = 'Detailed description'; ru = 'Подробное описание';pl = 'Szczegółowy opis';es_ES = 'Descripción detallada';es_CO = 'Descripción detallada';tr = 'Ayrıntılı açıklama';it = 'Descrizione dettagliata';de = 'Detaillierte Beschreibung'"),
				TypeDescriptionString1000, TypeDescriptionColumn,
				"Products", NStr("en = 'Product'; ru = 'Номенклатура';pl = 'Produkt';es_ES = 'Producto';es_CO = 'Producto';tr = 'Ürün';it = 'Articolo';de = 'Produkt'"), 5, , True);
		EndIf;
		
		If GetFunctionalOption("UseCharacteristics")
			And Common.HasObjectAttribute("Characteristic", FilledObject) Then
			TypeDescriptionColumn = New TypeDescription("CatalogRef.ProductsCharacteristics");
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, "CharacteristicDescription", NStr("en = 'Variant description'; ru = 'Наименование варианта';pl = 'Opis wariantu';es_ES = 'Descripción de la variante';es_CO = 'Descripción de la variante';tr = 'Varyant tanımı';it = 'Descrizione variante';de = 'Variantenbeschreibung'"),
				TypeDescriptionString150, TypeDescriptionColumn,
				"Characteristic", NStr("en = 'Variant'; ru = 'Вариант';pl = 'Wariant';es_ES = 'Variante';es_CO = 'Variante';tr = 'Varyant';it = 'Variante';de = 'Variante'"), 1);
		EndIf;
		
		If GetFunctionalOption("UseBatches")
			And Common.HasObjectAttribute("Batch", FilledObject) Then
			TypeDescriptionColumn = New TypeDescription("CatalogRef.ProductsBatches");
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, "BatchDescription", NStr("en = 'Batch description'; ru = 'Наименование партии';pl = 'Opis partii';es_ES = 'Descripción del lote';es_CO = 'Descripción del lote';tr = 'Parti tanımı';it = 'Descrizione lotto';de = 'Chargen-Beschreibung'"),
				TypeDescriptionString100, TypeDescriptionColumn,
				"Batch", NStr("en = 'Batch'; ru = 'Партия';pl = 'Partia';es_ES = 'Lote';es_CO = 'Lote';tr = 'Parti';it = 'Lotto';de = 'Charge'"), 1);
		EndIf;
		
		If GetFunctionalOption("UseSerialNumbers")
			And Common.HasObjectAttribute("SerialNumbers", FilledObject)
			And Not FillingObjectFullName = "Document.SalesOrder.TabularSection.Inventory" Then
			
			TypeDescriptionColumn = New TypeDescription("CatalogRef.SerialNumbers");
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, "SerialNumber", NStr("en = 'Serial number'; ru = 'Серийный номер';pl = 'Numer seryjny';es_ES = 'Número de serie';es_CO = 'Número de serie';tr = 'Seri numarası';it = 'Numero di serie';de = 'Seriennummer'"),
				TypeDescriptionString150, TypeDescriptionColumn);
			
		EndIf;
		
		If Common.HasObjectAttribute("MeasurementUnit", FilledObject) Then
			TypeDescriptionColumn = New TypeDescription("CatalogRef.UOMClassifier"
				+ ?(GetFunctionalOption("UseSeveralUnitsForProduct"), ", CatalogRef.UOM", ""));
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, "MeasurementUnitDescription", NStr("en = 'Unit description'; ru = 'Наименование единицы измерения';pl = 'Opis jednostki';es_ES = 'Descripción de la unidad';es_CO = 'Descripción de la unidad';tr = 'Birim tanımı';it = 'Descrizione unità';de = 'Beschreibung der Einheit'"),
				TypeDescriptionString25, TypeDescriptionColumn,
				"MeasurementUnit", NStr("en = 'Unit of measurement'; ru = 'Единица измерения';pl = 'Jednostka miary';es_ES = 'Unidad de medida';es_CO = 'Unidad de medida';tr = 'Ölçü birimi';it = 'Unità di misura';de = 'Maßeinheit'"), 1, , True);
		EndIf;
		
		If Common.HasObjectAttribute("Quantity", FilledObject) Then
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, "Quantity", NStr("en = 'Quantity'; ru = 'Количество';pl = 'Ilość';es_ES = 'Cantidad';es_CO = 'Cantidad';tr = 'Miktar';it = 'Quantità';de = 'Menge'"),
				TypeDescriptionString25, TypeDescriptionNumber15_3, , , , True);
		EndIf;
		
		If Common.HasObjectAttribute("Reserve", FilledObject)
			And GetFunctionalOption("UseInventoryReservation")
			And Not FillingObjectFullName = "Document.OpeningBalanceEntry.TabularSection.Inventory" Then
				DataImportFromExternalSources.AddImportDescriptionField(
					ImportFieldsTable, "Reserve", NStr("en = 'Reserve'; ru = 'Резерв';pl = 'Rezerwa';es_ES = 'Reserva';es_CO = 'Reserva';tr = 'Rezerve';it = 'Riserva';de = 'Reserve'"),
					TypeDescriptionString25, TypeDescriptionNumber15_3);
		EndIf;
		
		If Common.HasObjectAttribute("Price", FilledObject) Then
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, "Price", NStr("en = 'Price'; ru = 'Цена';pl = 'Cena';es_ES = 'Precio';es_CO = 'Precio';tr = 'Fiyat';it = 'Prezzo';de = 'Preis'"),
				TypeDescriptionString25, TypeDescriptionNumber15_2, , , , True);
		EndIf;
		
		If Common.HasObjectAttribute("Amount", FilledObject) Then
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, "Amount", NStr("en = 'Amount'; ru = 'Сумма';pl = 'Kwota';es_ES = 'Importe';es_CO = 'Importe';tr = 'Tutar';it = 'Importo';de = 'Betrag'"),
				TypeDescriptionString25, TypeDescriptionNumber15_2);
		EndIf;
		
		If Common.HasObjectAttribute("VATRate", FilledObject) Then
			TypeDescriptionColumn = New TypeDescription("CatalogRef.VATRates");
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, "VATRate", NStr("en = 'VAT rate'; ru = 'Ставка НДС';pl = 'Stawka VAT';es_ES = 'Tasa del IVA';es_CO = 'Tasa del IVA';tr = 'KDV oranı';it = 'Aliquota IVA';de = 'USt.-Satz'"),
				TypeDescriptionString50, TypeDescriptionColumn);
		EndIf;
		
		If Common.HasObjectAttribute("VATAmount", FilledObject) Then
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, "VATAmount", NStr("en = 'VAT amount'; ru = 'Сумма НДС';pl = 'Kwota podatku VAT';es_ES = 'Importe del IVA';es_CO = 'Importe del IVA';tr = 'KDV tutarı';it = 'Importo IVA';de = 'USt.-Betrag'"),
				TypeDescriptionString25, TypeDescriptionNumber15_2);
		EndIf;
		
		If Common.HasObjectAttribute("ReceiptDate", FilledObject) Then
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, "ReceiptDate", NStr("en = 'Receipt date'; ru = 'Дата поступления';pl = 'Data przyjęcia';es_ES = 'Fecha de entrega';es_CO = 'Fecha de entrega';tr = 'Teslim alma tarihi';it = 'Data di ricevimento';de = 'Eingangsdatum'"),
				TypeDescriptionString25, TypeDescriptionDate);
		EndIf;
		
		If Common.HasObjectAttribute("ShipmentDate", FilledObject) Then
			FieldVisible = (DataLoadSettings.DatePositionInOrder = Enums.AttributeStationing.InTabularSection);
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, "ShipmentDate", NStr("en = 'Shipment date'; ru = 'Дата отгрузки';pl = 'Data wysyłki';es_ES = 'Fecha de envío';es_CO = 'Fecha de envío';tr = 'Sevkiyat tarihi';it = 'Data di spedizione';de = 'Versanddatum'"),
				TypeDescriptionString25, TypeDescriptionDate, , , , , , FieldVisible);
		EndIf;
		
		If Common.HasObjectAttribute("Order", FilledObject) Then
			
			TypeArray = New Array;
			TypeArray.Add(Type("DocumentRef.SalesOrder"));
			TypeArray.Add(Type("DocumentRef.PurchaseOrder"));
			
			If DataLoadSettings.Property("OrderPositionInDocument") Then
				VisibilityOfSalesOrder = (DataLoadSettings.OrderPositionInDocument = Enums.AttributeStationing.InTabularSection);
			Else
				VisibilityOfSalesOrder = False;
			EndIf;
			
			TypeDescriptionColumn = New TypeDescription(TypeArray);
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, "Order", NStr("en = 'Order (customer/supplier)'; ru = 'Заказ (покупатель/поставщик)';pl = 'Zamówienie (klient / dostawca)';es_ES = 'Pedido (cliente/proveedor)';es_CO = 'Pedido (cliente/proveedor)';tr = 'Sipariş (müşteri/tedarikçi)';it = 'Ordine (cliente/fornitore)';de = 'Bestellung (Kunde / Lieferant)'"),
				TypeDescriptionString50, TypeDescriptionColumn, , , , , , VisibilityOfSalesOrder);
			
		EndIf;
		
		If Common.HasObjectAttribute("Specification", FilledObject) Then
			If GetFunctionalOption("UseWorkOrders") 
				// begin Drive.FullVersion
				Or GetFunctionalOption("UseProductionSubsystem")
				// end Drive.FullVersion
				Then
			TypeDescriptionColumn = New TypeDescription("CatalogRef.BillsOfMaterials");
			DataImportFromExternalSources.AddImportDescriptionField(
				ImportFieldsTable, "Specification", NStr("en = 'Bill of materials (name)'; ru = 'Спецификация (наименование)';pl = 'Specyfikacja materiałowa (nazwa)';es_ES = 'Lista de materiales (nombre)';es_CO = 'Lista de materiales (nombre)';tr = 'Ürün reçetesi (ad)';it = 'Distinta Base (nome)';de = 'Stückliste (Name)'"),
				TypeDescriptionString150, TypeDescriptionColumn);
			EndIf;
		EndIf;
		
	EndIf;

EndProcedure

Procedure MatchImportedDataFromExternalSource(DataMatchingTable, DataLoadSettings) Export
	Var Manager;
	
	FillingObjectFullName 	= DataLoadSettings.FillingObjectFullName;
	FilledObject 			= Metadata.FindByFullName(FillingObjectFullName);
	UpdateData 				= DataLoadSettings.UpdateExisting;
	
	// DataMatchingTable - Type FormDataCollection
	For Each FormTableRow In DataMatchingTable Do
		
		If FillingObjectFullName = "Catalog.Counterparties" Then
			
			// Counterparty by TIN, Name, Current account
			MapCounterparty(FormTableRow.Counterparty,
				FormTableRow.TIN,
				FormTableRow.CounterpartyDescription,
				FormTableRow.BankAccount,
				FormTableRow.EMail_Address_IncomingData,
				FormTableRow.Phone_IncomingData);
			ThisStringIsMapped = ValueIsFilled(FormTableRow.Counterparty);
			
			// Parent by name
			DefaultValue = Catalogs.Counterparties.EmptyRef();
			WhenDefiningDefaultValue(FormTableRow.Counterparty, "Parent", FormTableRow.Parent_IncomingData, ThisStringIsMapped, DefaultValue);
			MapParent("Counterparties", FormTableRow.Parent, FormTableRow.Parent_IncomingData, DefaultValue);
			
			ConvertStringToBoolean(FormTableRow.ThisIsInd, FormTableRow.ThisIsInd_IncomingData);
			
			If GetFunctionalOption("UseCounterpartiesAccessGroups") Then
				MapAccessGroup(FormTableRow.AccessGroup, FormTableRow.AccessGroup_IncomingData);
			EndIf;
			
			// Comment
			CopyRowToStringTypeValue(FormTableRow.Comment, FormTableRow.Comment_IncomingData);
			
			// DoOperationsByContracts
			StringForMatch = ?(IsBlankString(FormTableRow.DoOperationsByContracts_IncomingData), "TRUE", FormTableRow.DoOperationsByContracts_IncomingData);
			ConvertStringToBoolean(FormTableRow.DoOperationsByContracts, StringForMatch);
			
			// DoOperationsByOrders
			StringForMatch = ?(IsBlankString(FormTableRow.DoOperationsByOrders_IncomingData), "TRUE", FormTableRow.DoOperationsByOrders_IncomingData);
			ConvertStringToBoolean(FormTableRow.DoOperationsByOrders, StringForMatch);
			
			// Phone
			CopyRowToStringTypeValue(FormTableRow.Phone, FormTableRow.Phone_IncomingData);
			
			// EMail_Address
			CopyRowToStringTypeValue(FormTableRow.EMail_Address, FormTableRow.EMail_Address_IncomingData);
			
			// Customer, Supplier, OtherRelationship
			ConvertStringToBoolean(FormTableRow.Customer,			FormTableRow.Customer_IncomingData);
			ConvertStringToBoolean(FormTableRow.Supplier,			FormTableRow.Supplier_IncomingData);
			ConvertStringToBoolean(FormTableRow.OtherRelationship,	FormTableRow.OtherRelationship_IncomingData);
			
			If Not FormTableRow.Customer
				AND Not FormTableRow.Supplier
				AND Not FormTableRow.OtherRelationship Then
				
				FormTableRow.Customer			= True;
				FormTableRow.Supplier			= True;
				FormTableRow.OtherRelationship	= True;
				
			EndIf;
			
			DefaultValue = Enums.BaselineDateForPayment.DocumentDate;
			WhenDefiningDefaultValue(
				FormTableRow.Counterparty,
				"BaselineDate",
				FormTableRow.BaselineDate_IncomingData,
				ThisStringIsMapped,
				DefaultValue);
			MapEnumeration(
				"BaselineDateForPayment",
				FormTableRow.BaselineDate,
				FormTableRow.BaselineDate_IncomingData,
				DefaultValue);
			
			ConvertStringToDate(FormTableRow.DateOfBirth, FormTableRow.DateOfBirth_IncomingData);
			
			If Not IsBlankString(FormTableRow.DescriptionFull_IncomingData) Then
				CopyRowToStringTypeValue(FormTableRow.DescriptionFull, FormTableRow.DescriptionFull_IncomingData);
			Else
				CopyRowToStringTypeValue(FormTableRow.DescriptionFull, FormTableRow.CounterpartyDescription);
			EndIf;
			
			CopyRowToStringTypeValue(FormTableRow.EORI, FormTableRow.EORI_IncomingData);
			
			DefaultValue = Enums.DeliveryOptions.Delivery;
			WhenDefiningDefaultValue(
				FormTableRow.Counterparty,
				"DefaultDeliveryOption",
				FormTableRow.DefaultDeliveryOption_IncomingData,
				ThisStringIsMapped,
				DefaultValue);
			MapEnumeration(
				"DeliveryOptions",
				FormTableRow.DefaultDeliveryOption,
				FormTableRow.DefaultDeliveryOption_IncomingData,
				DefaultValue);
				
			DefaultValue = Undefined;
			WhenDefiningDefaultValue(
				FormTableRow.Counterparty,
				"Gender",
				FormTableRow.Gender_IncomingData,
				ThisStringIsMapped,
				DefaultValue);
			MapEnumeration(
				"Gender",
				FormTableRow.Gender,
				FormTableRow.Gender_IncomingData,
				DefaultValue);
				
			DefaultValue = Undefined;
			WhenDefiningDefaultValue(
				FormTableRow.Counterparty,
				"LegalForm",
				FormTableRow.LegalForm_IncomingData,
				ThisStringIsMapped,
				DefaultValue);
			CatalogByName(
				"LegalForms",
				FormTableRow.LegalForm,
				FormTableRow.LegalForm_IncomingData,
				DefaultValue);
				
			DefaultValue = Catalogs.PaymentMethods.Undefined;
			WhenDefiningDefaultValue(
				FormTableRow.Counterparty,
				"PaymentMethod",
				FormTableRow.PaymentMethod_IncomingData,
				ThisStringIsMapped,
				DefaultValue);
			CatalogByName(
				"PaymentMethods",
				FormTableRow.PaymentMethod,
				FormTableRow.PaymentMethod_IncomingData,
				DefaultValue);
				
			DefaultValue = Catalogs.PriceTypes.Wholesale;
			WhenDefiningDefaultValue(
				FormTableRow.Counterparty,
				"PriceKind",
				FormTableRow.PriceKind_IncomingData,
				ThisStringIsMapped,
				DefaultValue);
			CatalogByName(
				"PriceTypes",
				FormTableRow.PriceKind,
				FormTableRow.PriceKind_IncomingData,
				DefaultValue);
			
			DefaultValue = Undefined;
			WhenDefiningDefaultValue(
				FormTableRow.Counterparty,
				"RegistrationCountry",
				FormTableRow.RegistrationCountry_IncomingData,
				ThisStringIsMapped,
				DefaultValue);
			CatalogByName(
				"WorldCountries",
				FormTableRow.RegistrationCountry,
				FormTableRow.RegistrationCountry_IncomingData,
				DefaultValue);
				
			CopyRowToStringTypeValue(FormTableRow.RegistrationNumber, FormTableRow.RegistrationNumber_IncomingData);
			
			DefaultValue = Undefined;
			WhenDefiningDefaultValue(
				FormTableRow.Counterparty,
				"SalesTerritory",
				FormTableRow.SalesTerritory_IncomingData,
				ThisStringIsMapped,
				DefaultValue);
			CatalogByName(
				"SalesTerritories",
				FormTableRow.SalesTerritory,
				FormTableRow.SalesTerritory_IncomingData,
				DefaultValue);
				
			DefaultValue = Undefined;
			WhenDefiningDefaultValue(
				FormTableRow.Counterparty,
				"Responsible",
				FormTableRow.Responsible_IncomingData,
				ThisStringIsMapped,
				DefaultValue);
			CatalogByName(
				"Employees",
				FormTableRow.Responsible,
				FormTableRow.Responsible_IncomingData,
				DefaultValue);
				
			DefaultValue = Undefined;
			WhenDefiningDefaultValue(
				FormTableRow.Counterparty,
				"SalesRep",
				FormTableRow.SalesRep_IncomingData,
				ThisStringIsMapped,
				DefaultValue);
			CatalogByName(
				"Employees",
				FormTableRow.SalesRep,
				FormTableRow.SalesRep_IncomingData,
				DefaultValue);
				
			DefaultValue = Undefined;
			WhenDefiningDefaultValue(
				FormTableRow.Counterparty,
				"SettlementsCurrency",
				FormTableRow.SettlementsCurrency_IncomingData,
				ThisStringIsMapped,
				DefaultValue);
			CatalogByName(
				"Currencies",
				FormTableRow.SettlementsCurrency,
				FormTableRow.SettlementsCurrency_IncomingData,
				DefaultValue);
				
			DefaultValue = Undefined;
			WhenDefiningDefaultValue(
				FormTableRow.Counterparty,
				"SupplierPriceTypes",
				FormTableRow.SupplierPriceTypes_IncomingData,
				ThisStringIsMapped,
				DefaultValue);
			CatalogByName(
				"SupplierPriceTypes",
				FormTableRow.SupplierPriceTypes,
				FormTableRow.SupplierPriceTypes_IncomingData,
				DefaultValue);
			
			If GetFunctionalOption("UseVAT") Then
				
				CopyRowToStringTypeValue(FormTableRow.VATNumber, FormTableRow.VATNumber_IncomingData);
				
				DefaultValue = Enums.VATTaxationTypes.SubjectToVAT;
				WhenDefiningDefaultValue(
					FormTableRow.Counterparty,
					"VATTaxation",
					FormTableRow.VATTaxation_IncomingData,
					ThisStringIsMapped,
					DefaultValue);
				MapEnumeration(
					"VATTaxationTypes",
					FormTableRow.VATTaxation,
					FormTableRow.VATTaxation_IncomingData,
					DefaultValue);
				
			EndIf;
			
			ConvertRowToNumber(FormTableRow.CreditLimit, FormTableRow.CreditLimit_IncomingData);
			ConvertRowToNumber(FormTableRow.OverdueLimit, FormTableRow.OverdueLimit_IncomingData);
			ConvertRowToNumber(FormTableRow.TransactionLimit, FormTableRow.TransactionLimit_IncomingData);
			
			If GetFunctionalOption("UseSalesTax") Then
				DefaultValue = Undefined;
				WhenDefiningDefaultValue(
					FormTableRow.Counterparty,
					"SalesTaxRate",
					FormTableRow.SalesTaxRate_IncomingData,
					ThisStringIsMapped,
					DefaultValue);
				CatalogByName(
					"SalesTaxRates",
					FormTableRow.SalesTaxRate,
					FormTableRow.SalesTaxRate_IncomingData,
					DefaultValue);
			EndIf;
			
		ElsIf FillingObjectFullName = "Catalog.Cells" Then
			
			// Owner/warehouse by description
			DefaultValue = Catalogs.BusinessUnits.MainWarehouse;
			MapStructuralUnit(FormTableRow.Owner, FormTableRow.Owner_IncomingData, DefaultValue);
			
			// Parent by name
			DefaultValue = Catalogs.Cells.EmptyRef();
			MapItemParentWithOwner("Cells", FormTableRow.Parent, FormTableRow.Parent_IncomingData, DefaultValue, FormTableRow.Owner);
			
			If ValueIsFilled(FormTableRow.Owner) Then
				MapCell(FormTableRow.Cells, FormTableRow.CellsDescription, FormTableRow.Code, FormTableRow.Owner, , FormTableRow.Parent);
			EndIf;
			ThisStringIsMapped = ValueIsFilled(FormTableRow.Cells);
			
		ElsIf FillingObjectFullName = "Catalog.SalesTaxRates" Then
			
			// Agency
			MapTaxTypes(FormTableRow.Agency, FormTableRow.Agency_IncomingData, Catalogs.TaxTypes.EmptyRef());
			
		// begin Drive.FullVersion
		
		ElsIf FillingObjectFullName = "Catalog.CompanyResourceTypes" Then
			
			CatalogByName("CompanyResourceTypes", FormTableRow.CompanyResourceType, FormTableRow.Description);
			
			CatalogByName("BusinessUnits", FormTableRow.BusinessUnit, FormTableRow.BusinessUnit_IncomingData);
			
			ConvertStringToBoolean(FormTableRow.PlanningOnWorkcentersLevel, FormTableRow.PlanningOnWorkcentersLevel_IncomingData);
			
			CatalogByName("Calendars", FormTableRow.Schedule, FormTableRow.Schedule_IncomingData);
			
			ConvertRowToNumber(FormTableRow.Capacity, FormTableRow.Capacity_IncomingData, 1);
			
		ElsIf FillingObjectFullName = "Catalog.CompanyResources" Then
			
			CatalogByName("CompanyResources", FormTableRow.CompanyResource, FormTableRow.Description);
			
			CatalogByName("CompanyResourceTypes", FormTableRow.WorkcenterType, FormTableRow.WorkcenterType_IncomingData);
			
			CatalogByName("Calendars", FormTableRow.Schedule, FormTableRow.Schedule_IncomingData);
			
			ConvertRowToNumber(FormTableRow.Capacity, FormTableRow.Capacity_IncomingData, 1);
			
		ElsIf FillingObjectFullName = "Catalog.ManufacturingActivities" Then
			
			CatalogByName("ManufacturingActivities", FormTableRow.Operation, FormTableRow.Description);
			
			CatalogByName("CostPools", FormTableRow.CostPool, FormTableRow.CostPool_IncomingData);
			
			ConvertRowToNumber(FormTableRow.StandardWorkload, FormTableRow.StandardWorkload_IncomingData, 0);
			
			ConvertRowToNumber(FormTableRow.StandardTimeInUOM, FormTableRow.StandardTimeInUOM_IncomingData, 0);
			
			CatalogByName("TimeUOM", FormTableRow.TimeUOM, FormTableRow.TimeUOM_IncomingData);
			
			CatalogByName("CompanyResourceTypes", FormTableRow.WorkcenterType, FormTableRow.WorkcenterType_IncomingData);
			
		// end Drive.FullVersion
		
		ElsIf FillingObjectFullName = "Catalog.Products" Then
			
			// Product by Barcode, SKU, Description
			CompareProducts(FormTableRow.Products, FormTableRow.Barcode, FormTableRow.SKU, FormTableRow.ProductsDescription, FormTableRow.ProductsDescriptionFull, FormTableRow.Code);
			ThisStringIsMapped = ValueIsFilled(FormTableRow.Products);
			
			// Parent by name
			DefaultValue = Catalogs.Products.EmptyRef();
			WhenDefiningDefaultValue(FormTableRow.Products, "Parent", FormTableRow.Parent_IncomingData, ThisStringIsMapped, DefaultValue);
			MapParent("Products", FormTableRow.Parent, FormTableRow.Parent_IncomingData, DefaultValue);
			
			// Product type (we can not correct attributes closed for editing)
			If ThisStringIsMapped Then
				FormTableRow.ProductsType = FormTableRow.Products.ProductsType;
			Else
				MapProductsType(FormTableRow.ProductsType, FormTableRow.ProductsType_IncomingData, Enums.ProductsTypes.InventoryItem);
			EndIf;
			
			// MeasurementUnits by Description (also consider the option to bind user MU)
			DefaultValue = Undefined;
			WhenDefiningDefaultValue(FormTableRow.Products, "MeasurementUnit", FormTableRow.MeasurementUnit_IncomingData, ThisStringIsMapped, DefaultValue);
			MapUOM(FormTableRow.Products, FormTableRow.MeasurementUnit, FormTableRow.MeasurementUnit_IncomingData, DefaultValue);
			
			// ReportUOM by Description
			DefaultValue = Undefined;
			WhenDefiningDefaultValue(FormTableRow.Products, "ReportUOM", FormTableRow.ReportUOM_IncomingData, ThisStringIsMapped, DefaultValue);
			MapReportUOM(FormTableRow.ReportUOM, FormTableRow.ReportUOM_IncomingData, DefaultValue);
			
			// BusinessLine by name
			DefaultValue = Catalogs.LinesOfBusiness.MainLine;
			WhenDefiningDefaultValue(FormTableRow.Products, "BusinessLine", FormTableRow.BusinessLine_IncomingData, ThisStringIsMapped, DefaultValue);
			MapBusinessLine(FormTableRow.BusinessLine, FormTableRow.BusinessLine_IncomingData, DefaultValue);
			
			// ProductsCategory by description
			DefaultValue = Catalogs.ProductsCategories.MainGroup;
			WhenDefiningDefaultValue(FormTableRow.Products, "ProductsCategory", FormTableRow.ProductsCategory_IncomingData, ThisStringIsMapped, DefaultValue);
			MapProductsCategory(FormTableRow.ProductsCategory, FormTableRow.ProductsCategory_IncomingData, DefaultValue);
			
			// Supplier by TIN, Description
			MapSupplier(FormTableRow.Vendor, FormTableRow.Vendor_IncomingData, FormTableRow.Vendor_IncomingData);
			
			// Manufacturer by TIN, Description
			MapSupplier(FormTableRow.Manufacturer, FormTableRow.Manufacturer_IncomingData, FormTableRow.Manufacturer_IncomingData);
			
			// Serial numbers
			If GetFunctionalOption("UseSerialNumbers") Then
				
				ConvertStringToBoolean(FormTableRow.UseSerialNumbers, FormTableRow.UseSerialNumbers_IncomingData);
				FormTableRow.UseSerialNumbers = Not IsBlankString(FormTableRow.SerialNumber_IncomingData);
				
				If ThisStringIsMapped
					AND FormTableRow.UseSerialNumbers Then
					
					MapSerialNumber(FormTableRow.Products, FormTableRow.SerialNumber, FormTableRow.SerialNumber_IncomingData);
					
				EndIf;
				
			EndIf;
			
			// Warehouse by description
			DefaultValue = Catalogs.BusinessUnits.MainWarehouse;
			WhenDefiningDefaultValue(FormTableRow.Products, "Warehouse", FormTableRow.Warehouse_IncomingData, ThisStringIsMapped, DefaultValue);
			MapStructuralUnit(FormTableRow.Warehouse, FormTableRow.Warehouse_IncomingData, DefaultValue);
			
			// ReplenishmentMethod by description
			DefaultValue = Enums.InventoryReplenishmentMethods.Purchase;
			WhenDefiningDefaultValue(FormTableRow.Products, "ReplenishmentMethod", FormTableRow.ReplenishmentMethod_IncomingData, ThisStringIsMapped, DefaultValue);
			MapReplenishmentMethod(FormTableRow.ReplenishmentMethod, FormTableRow.ReplenishmentMethod_IncomingData, DefaultValue);
			
			// ReplenishmentDeadline
			DefaultValue = 1;
			WhenDefiningDefaultValue(FormTableRow.Products, "ReplenishmentDeadline", FormTableRow.ReplenishmentDeadline_IncomingData, ThisStringIsMapped, DefaultValue);
			ConvertRowToNumber(FormTableRow.ReplenishmentDeadline, FormTableRow.ReplenishmentDeadline_IncomingData, DefaultValue);
			
			// VATRate by description
			DefaultValue = InformationRegisters.AccountingPolicy.GetDefaultVATRate(, Catalogs.Companies.MainCompany);
			WhenDefiningDefaultValue(FormTableRow.Products, "VATRate", FormTableRow.VATRate_IncomingData, ThisStringIsMapped, DefaultValue);
			MapVATRate(FormTableRow.VATRate, FormTableRow.VATRate_IncomingData, DefaultValue);
			
			If GetFunctionalOption("UseStorageBins") Then
				
				// Cell by description
				DefaultValue = Catalogs.Cells.EmptyRef();
				WhenDefiningDefaultValue(FormTableRow.Products, "Cell", FormTableRow.Cell_IncomingData, ThisStringIsMapped, DefaultValue);
				MapCell(FormTableRow.Cell, FormTableRow.Cell_IncomingData, , FormTableRow.Warehouse, DefaultValue);
				
			EndIf;
			
			// PriceGroup by description
			DefaultValue = Catalogs.PriceGroups.EmptyRef();
			WhenDefiningDefaultValue(FormTableRow.Products, "PriceGroup", FormTableRow.PriceGroup_IncomingData, ThisStringIsMapped, DefaultValue);
			MapPriceGroup(FormTableRow.PriceGroup, FormTableRow.PriceGroup_IncomingData, DefaultValue);
			
			// UseCharacteristics
			If GetFunctionalOption("UseCharacteristics") Then
				 ConvertStringToBoolean(FormTableRow.UseCharacteristics, FormTableRow.UseCharacteristics_IncomingData);
			EndIf;
			
			// UseBatches
			If GetFunctionalOption("UseBatches") Then
				ConvertStringToBoolean(FormTableRow.UseBatches, FormTableRow.UseBatches_IncomingData);
			EndIf;
			
			// Comment as string
			CopyRowToStringTypeValue(FormTableRow.Comment, FormTableRow.Comment_IncomingData);
			
			// OrderCompletionDeadline
			DefaultValue = 1;
			WhenDefiningDefaultValue(FormTableRow.Products, "OrderCompletionDeadline", FormTableRow.OrderCompletionDeadline_IncomingData, ThisStringIsMapped, DefaultValue);
			ConvertRowToNumber(FormTableRow.OrderCompletionDeadline, FormTableRow.OrderCompletionDeadline_IncomingData, DefaultValue);
			
			// TimeNorm
			DefaultValue = 0;
			WhenDefiningDefaultValue(FormTableRow.Products, "TimeNorm", FormTableRow.TimeNorm_IncomingData, ThisStringIsMapped, DefaultValue);
			ConvertRowToNumber(FormTableRow.TimeNorm, FormTableRow.TimeNorm_IncomingData, DefaultValue);
			
			// OriginCountry by the code
			DefaultValue = Catalogs.WorldCountries.EmptyRef();
			WhenDefiningDefaultValue(FormTableRow.Products, "CountryOfOrigin", FormTableRow.CountryOfOrigin_IncomingData, ThisStringIsMapped, DefaultValue);
			MapOriginCountry(FormTableRow.CountryOfOrigin, FormTableRow.CountryOfOrigin_IncomingData, DefaultValue);
			
		ElsIf FillingObjectFullName = "Catalog.BillsOfMaterials.TabularSection.Content" Then
			
			// Product by Barcode, SKU, Description
			CompareProducts(FormTableRow.Products, FormTableRow.Barcode, FormTableRow.SKU, FormTableRow.ProductsDescription, FormTableRow.ProductsDescriptionFull);
			ThisStringIsMapped = ValueIsFilled(FormTableRow.Products);
			
			// StringType by StringType.Description
			MapRowType(FormTableRow.ContentRowType, FormTableRow.ContentRowType_IncomingData, Enums.BOMLineType.Material);
			
			If GetFunctionalOption("UseCharacteristics") Then
				If ValueIsFilled(FormTableRow.Products) Then
					// Variant by Owner and Name
					MapCharacteristic(FormTableRow.Characteristic, FormTableRow.Products, FormTableRow.Barcode, FormTableRow.Characteristic_IncomingData);
				EndIf;
			EndIf;
			
			// Quantity
			ConvertRowToNumber(FormTableRow.Quantity, FormTableRow.Quantity_IncomingData);
			
			// UOM by Description 
			DefaultValue = Undefined;
			WhenDefiningDefaultValue(FormTableRow.Products, "MeasurementUnit", FormTableRow.MeasurementUnit_IncomingData, ThisStringIsMapped, DefaultValue);
			MapUOM(FormTableRow.Products, FormTableRow.MeasurementUnit, FormTableRow.MeasurementUnit_IncomingData, DefaultValue);
			
			// Cost share
			ConvertRowToNumber(FormTableRow.CostPercentage, FormTableRow.CostPercentage_IncomingData);
			
			// BillsOfMaterials by owner, description
			MapSpecification(FormTableRow.Specification, FormTableRow.Specification_IncomingData, FormTableRow.Products);
			
		// begin Drive.FullVersion
		
		ElsIf FillingObjectFullName = "Catalog.RoutingTemplates.TabularSection.Operations" Then
			
			MapActivity(FormTableRow.Activity, FormTableRow.Activity_IncomingData);
			
			// Activity number
			ConvertRowToNumber(FormTableRow.ActivityNumber, FormTableRow.ActivityNumber_IncomingData);
			
			// Next activity number
			ConvertRowToNumber(FormTableRow.NextActivityNumber, FormTableRow.NextActivityNumber_IncomingData);
			
		// end Drive.FullVersion
		
		ElsIf FillingObjectFullName = "InformationRegister.Prices" Then
			
			// Product by Barcode, SKU, Description
			CompareProducts(FormTableRow.Products, FormTableRow.Barcode, FormTableRow.SKU, FormTableRow.ProductsDescription, FormTableRow.ProductsDescriptionFull);
			ThisStringIsMapped = ValueIsFilled(FormTableRow.Products);
			
			If GetFunctionalOption("UseCharacteristics") Then
				If ThisStringIsMapped Then
					// Variant by Owner and Name
					MapCharacteristic(FormTableRow.Characteristic, FormTableRow.Products, FormTableRow.Barcode, FormTableRow.Characteristic_IncomingData);
				EndIf;
			EndIf;
			
			// MeasurementUnits by Description (also consider the option to bind user MU)
			DefaultValue = Undefined;
			WhenDefiningDefaultValue(FormTableRow.Products, "MeasurementUnit", FormTableRow.MeasurementUnit_IncomingData, ThisStringIsMapped, DefaultValue);
			MapUOM(FormTableRow.Products, FormTableRow.MeasurementUnit, FormTableRow.MeasurementUnit_IncomingData, DefaultValue);
			
			// PriceTypes by description
			DefaultValue = Catalogs.Counterparties.GetMainKindOfSalePrices();
			MapPriceKind(FormTableRow.PriceKind, FormTableRow.PriceKind_IncomingData, DefaultValue);
			
			// Price
			ConvertRowToNumber(FormTableRow.Price, FormTableRow.Price_IncomingData);
			
			// Date
			ConvertStringToDate(FormTableRow.Date, FormTableRow.Date_IncomingData);
			If Not ValueIsFilled(FormTableRow.Date) Then
				FormTableRow.Date = BegOfDay(CurrentSessionDate());
			EndIf;
			
		ElsIf FillingObjectFullName = "Document.OpeningBalanceEntry.TabularSection.AccountsReceivable"
			Or  FillingObjectFullName = "Document.OpeningBalanceEntry.TabularSection.AccountsPayable" Then
			
			IsAR = (FillingObjectFullName = "Document.OpeningBalanceEntry.TabularSection.AccountsReceivable");
			
			ForeignExchangeAccounting = GetFunctionalOption("ForeignExchangeAccounting");
			UseContractsWithCounterparties = Constants.UseContractsWithCounterparties.Get();
			
			MapSupplier(FormTableRow.Counterparty, FormTableRow.CounterpartyTIN, FormTableRow.CounterpartyDescription);
			ThisStringIsMapped = ValueIsFilled(FormTableRow.Counterparty);
			
			ConvertStringToBoolean(FormTableRow.AdvanceFlag, FormTableRow.AdvanceFlag_IncomingData);
			
			If IsBlankString(FormTableRow.DocumentType) Then
				FormTableRow.DocumentType = DefaultBillingDocumentType(IsAR, FormTableRow.AdvanceFlag);
			EndIf;
			
			If IsBlankString(FormTableRow.DocumentDate) Then
				FormTableRow.DocumentDate = Format(DataLoadSettings.DocumentAttributes.Date, "DLF=D");
			EndIf;
			
			If ThisStringIsMapped Then
				If UseContractsWithCounterparties Then
					MapContract(FormTableRow.Counterparty, FormTableRow.Contract, FormTableRow.ContractDescription,
						FormTableRow.ContractNo, DataLoadSettings.DocumentAttributes.Company);
				EndIf;
			EndIf;
			
			OrderType = ?(IsAR, "SalesOrder", "PurchaseOrder");
			MapOrderByNumberDate(FormTableRow.Order, OrderType, FormTableRow.Counterparty,
				FormTableRow.OrderNumber, FormTableRow.OrderDate);
				
			MapBillingDocumentByNumberDate(FormTableRow.Document, FormTableRow.DocumentType, IsAR,
				FormTableRow.Counterparty, FormTableRow.DocumentNumber, FormTableRow.DocumentDate);
			
			ConvertRowToNumber(FormTableRow.AmountCur, FormTableRow.AmountCur_IncomingData);
			
			If ForeignExchangeAccounting Then
				
				If IsBlankString(FormTableRow.CurrencyName)
					And IsBlankString(FormTableRow.CurrencyCode) Then
					FormTableRow.Currency = DriveServer.GetPresentationCurrency(DataLoadSettings.DocumentAttributes.Company);
				Else
					MapCurrency(FormTableRow.Currency, FormTableRow.CurrencyName, FormTableRow.CurrencyCode);
					
					If Not ValueIsFilled(FormTableRow.Currency) Then
						SupplimentCurrencyDataFromClassifier(FormTableRow.CurrencyCode, FormTableRow.CurrencyName);
					EndIf;
				EndIf;
				
				If ValueIsFilled(FormTableRow.Amount_IncomingData) Then
					ConvertRowToNumber(FormTableRow.Amount, FormTableRow.Amount_IncomingData);
				ElsIf ValueIsFilled(FormTableRow.Currency) Then
					FormTableRow.Amount = DriveServer.RecalculateFromCurrencyToAccountingCurrency(
						DataLoadSettings.DocumentAttributes.Company,
						FormTableRow.AmountCur,
						FormTableRow.Currency,
						DataLoadSettings.DocumentAttributes.Date);
				Else
					FormTableRow.Amount = FormTableRow.AmountCur;
				EndIf;
				
			EndIf;
			
			If UseContractsWithCounterparties And Not ValueIsFilled(FormTableRow.Contract) Then
				If IsBlankString(FormTableRow.ContractDescription) And Not IsBlankString(FormTableRow.ContractNo) Then
					If Not IsBlankString(FormTableRow.ContractDate) Then
						If ForeignExchangeAccounting Then
							ContractDescription = NStr("en = '#%1 dated %2 (%3)'; ru = '№%1 от %2 (%3)';pl = 'nr %1 z dn. %2 (%3)';es_ES = '#%1 fechado %2 (%3)';es_CO = '#%1 fechado %2 (%3)';tr = '#%1 tarih %2 (%3)';it = '#%1, con data %2 (%3)';de = 'Nr.%1 vom %2 (%3)'");
						Else
							ContractDescription = NStr("en = '#%1 dated %2'; ru = '№ %1 от %2';pl = '#%1 z dn. %2';es_ES = '#%1 fechado %2';es_CO = '#%1 fechado %2';tr = 'no %1 tarih %2';it = '#%1 con data %2';de = 'Nr. %1 vom %2'");
						EndIf;
					Else
						If ForeignExchangeAccounting Then
							ContractDescription = NStr("en = '#%1 (%3)'; ru = '#%1 (%3)';pl = '#%1 (%3)';es_ES = '#%1 (%3)';es_CO = '#%1 (%3)';tr = '#%1 (%3)';it = '#%1 (%3)';de = '#%1 (%3)'");
						Else
							ContractDescription = NStr("en = '#%1'; ru = '#%1';pl = '#%1';es_ES = '#%1';es_CO = '#%1';tr = '#%1';it = '#%1';de = '#%1'");
						EndIf;
					EndIf;
					If ForeignExchangeAccounting Then
						If ValueIsFilled(FormTableRow.Currency) Then
							Currency = FormTableRow.Currency;
						Else
							Currency = FormTableRow.CurrencyName;
						EndIf;
					Else
						Currency = "";
					EndIf;
					FormTableRow.ContractDescription = StringFunctionsClientServer.SubstituteParametersToString(
						ContractDescription,
						FormTableRow.ContractNo,
						Format(FormTableRow.ContractDate, "DLF=D"),
						Currency); 
				EndIf;
			EndIf;
			
		ElsIf FillingObjectFullName = "Document.OpeningBalanceEntry.TabularSection.CashAssets" Then
			
			If DataLoadSettings.AccountType = "BankAccount" Then
				
				MapBank(FormTableRow.Bank, FormTableRow.BankCode, FormTableRow.BankDescription);
				FormTableRow.BankRef = FormTableRow.Bank;
				
				ConvertRowToNumber(FormTableRow.AmountCur, FormTableRow.AmountCur_IncomingData);
				
				If GetFunctionalOption("ForeignExchangeAccounting") Then
					
					MapCurrency(FormTableRow.Currency, FormTableRow.CurrencyName, FormTableRow.CurrencyCode);
					FormTableRow.CashCurrency = FormTableRow.Currency;
					
					If Not ValueIsFilled(FormTableRow.CashCurrency) Then
						SupplimentCurrencyDataFromClassifier(FormTableRow.CurrencyCode, FormTableRow.CurrencyName);
					EndIf;
					
					If ValueIsFilled(FormTableRow.Amount_IncomingData) Then
						ConvertRowToNumber(FormTableRow.Amount, FormTableRow.Amount_IncomingData);
					ElsIf ValueIsFilled(FormTableRow.CashCurrency) Then
						FormTableRow.Amount = DriveServer.RecalculateFromCurrencyToAccountingCurrency(
							DataLoadSettings.DocumentAttributes.Company,
							FormTableRow.AmountCur,
							FormTableRow.CashCurrency,
							DataLoadSettings.DocumentAttributes.Date);
					Else
						FormTableRow.Amount = FormTableRow.AmountCur;
					EndIf;
					
					Currency = FormTableRow.Currency;
					
				Else
					
					Currency = Undefined;
					
				EndIf;
				
				IBAN_AccountNoArray = New Array;
				IBAN_AccountNoArray.Add(FormTableRow.IBAN);
				IBAN_AccountNoArray.Add(FormTableRow.AccountNo);
				FormTableRow.IBAN_AccountNo = StringFunctionsClientServer.StringFromSubstringArray(IBAN_AccountNoArray, ", ");
				
				CopyRowToStringTypeValue(FormTableRow.Description, FormTableRow.Description_IncomingData);
				
				MapBankAccount(FormTableRow, DataLoadSettings.DocumentAttributes.Company, Currency);
				
			ElsIf DataLoadSettings.AccountType = "CashAccount" Then
				
				ConvertRowToNumber(FormTableRow.AmountCur, FormTableRow.AmountCur_IncomingData);
				
				If GetFunctionalOption("ForeignExchangeAccounting") Then
					
					MapCurrency(FormTableRow.Currency, FormTableRow.CurrencyName, FormTableRow.CurrencyCode);
					
					If Not ValueIsFilled(FormTableRow.Currency) Then
						SupplimentCurrencyDataFromClassifier(FormTableRow.CurrencyCode, FormTableRow.CurrencyName);
					EndIf;
					
					If ValueIsFilled(FormTableRow.Amount_IncomingData) Then
						ConvertRowToNumber(FormTableRow.Amount, FormTableRow.Amount_IncomingData);
					ElsIf ValueIsFilled(FormTableRow.Currency) Then
						FormTableRow.Amount = DriveServer.RecalculateFromCurrencyToAccountingCurrency(
							DataLoadSettings.DocumentAttributes.Company,
							FormTableRow.AmountCur,
							FormTableRow.Currency,
							DataLoadSettings.DocumentAttributes.Date);
					Else
						FormTableRow.Amount = FormTableRow.AmountCur;
					EndIf;
					
					Currency = FormTableRow.Currency;
					
				Else
					
					Currency = Undefined;
					
				EndIf;
				
				MapCashAccount(FormTableRow, Currency);
				
			EndIf;
			
		ElsIf FillingObjectFullName = "Catalog.Leads" Then
			
			// Lead by Name, CI
			CIArray = New Array;
			CIArray.Add(FormTableRow.Phone1);
			CIArray.Add(FormTableRow.Email1);
			CIArray.Add(FormTableRow.Phone2);
			CIArray.Add(FormTableRow.Email2);
			CIArray.Add(FormTableRow.Phone3);
			CIArray.Add(FormTableRow.Email3);
			
			MapLead(FormTableRow.Lead, FormTableRow.Description, CIArray);
			
			ThisStringIsMapped = ValueIsFilled(FormTableRow.Lead);
			
			CopyRowToStringTypeValue(FormTableRow.Contact1, FormTableRow.Contact1);
			CopyRowToStringTypeValue(FormTableRow.Phone1, FormTableRow.Phone1);
			CopyRowToStringTypeValue(FormTableRow.Email1, FormTableRow.Email1);
			
			CopyRowToStringTypeValue(FormTableRow.Contact2, FormTableRow.Contact2);
			CopyRowToStringTypeValue(FormTableRow.Phone2, FormTableRow.Phone2);
			CopyRowToStringTypeValue(FormTableRow.Email2, FormTableRow.Email2);
			
			CopyRowToStringTypeValue(FormTableRow.Contact3, FormTableRow.Contact3);
			CopyRowToStringTypeValue(FormTableRow.Phone3, FormTableRow.Phone3);
			CopyRowToStringTypeValue(FormTableRow.Email3, FormTableRow.Email3);
			
			MapAcquisitionChannel(FormTableRow.AcquisitionChannel, FormTableRow.AcquisitionChannel_IncomingData);
			ConvertRowToNumber(FormTableRow.Potential, FormTableRow.Potential_IncomingData);
			
			CopyRowToStringTypeValue(FormTableRow.Note, FormTableRow.Note);
			
		ElsIf FillingObjectFullName = "Document.RequestForQuotation.TabularSection.Suppliers" Then
			
			 // Counterparty by TIN, Name
			MapSupplier(FormTableRow.Counterparty, FormTableRow.Counterparty_IncomingData, FormTableRow.Counterparty_IncomingData);
			ThisStringIsMapped = ValueIsFilled(FormTableRow.Counterparty);
			
			If ThisStringIsMapped Then
				
				// Contact by Name
				MapContactPerson(FormTableRow.Counterparty, FormTableRow.ContactPerson, FormTableRow.ContactPerson_IncomingData);
				// Email
				CopyRowToStringTypeValue(FormTableRow.Email, FormTableRow.Email_IncomingData);
				
			EndIf;
			
		ElsIf FillingObjectFullName = "ChartOfAccounts.PrimaryChartOfAccounts" Then
			
			ChartsOfAccountsManager = ChartsOfAccounts.PrimaryChartOfAccounts;
			
			// Account by Code, Description
			CompareAccount(FormTableRow.Account, FormTableRow.Code, FormTableRow.Description, ChartsOfAccountsManager);
			ThisStringIsMapped = ValueIsFilled(FormTableRow.Account);
			
			// Parent by code
			DefaultValue = ChartsOfAccountsManager.EmptyRef();
			MapGLAccount(FormTableRow.Parent, FormTableRow.Parent_IncomingData, DefaultValue, ChartsOfAccountsManager);
			
			// AccountType by description
			DefaultValue = Undefined;
			MapAccountType(FormTableRow.Type, FormTableRow.Type_IncomingData, DefaultValue);
			
			// TypeOfAccount by description
			DefaultValue = Enums.GLAccountsTypes.EmptyRef();
			MapTypeOfGLAccount(FormTableRow.TypeOfAccount, FormTableRow.TypeOfAccount_IncomingData, DefaultValue);
			
			// MethodOfDistribution by description
			DefaultValue = Enums.CostAllocationMethod.EmptyRef();
			MapMethodOfDistribution(FormTableRow.MethodOfDistribution, FormTableRow.MethodOfDistribution_IncomingData, DefaultValue);
			
			// FinancialStatement by description
			DefaultValue = Enums.FinancialStatement.EmptyRef();
			MapFinancialStatement(FormTableRow.FinancialStatement, FormTableRow.FinancialStatement_IncomingData, DefaultValue);
			
			// Currency
			StringForMatch = ?(IsBlankString(FormTableRow.Currency_IncomingData), "FALSE", FormTableRow.Currency_IncomingData);
			ConvertStringToBoolean(FormTableRow.Currency, StringForMatch);
			
			// OffBalance
			StringForMatch = ?(IsBlankString(FormTableRow.OffBalance_IncomingData), "FALSE", FormTableRow.OffBalance_IncomingData);
			ConvertStringToBoolean(FormTableRow.OffBalance, StringForMatch);
			
			// Order
			StringForMatch = ?(IsBlankString(FormTableRow.Order_IncomingData), FormTableRow.Code, FormTableRow.Order_IncomingData);
			CopyRowToStringTypeValue(FormTableRow.Order, StringForMatch);
			
		ElsIf FillingObjectFullName = "ChartOfAccounts.MasterChartOfAccounts" Then
			
			ChartsOfAccountsManager = ChartsOfAccounts.MasterChartOfAccounts;
			
			// ChartOfAccounts by description
			DefaultValue = Catalogs.ChartsOfAccounts.EmptyRef();
			MapChartOfAccounts(FormTableRow.ChartOfAccounts, FormTableRow.ChartOfAccounts_IncomingData, DefaultValue);
			
			// Account by Code, Description
			CompareMasterAccount(FormTableRow.Account,
				FormTableRow.Code,
				FormTableRow.Description,
				FormTableRow.ChartOfAccounts,
				ChartsOfAccountsManager);
			ThisStringIsMapped = ValueIsFilled(FormTableRow.Account);
			
			// Parent by code
			DefaultValue = ChartsOfAccountsManager.EmptyRef();
			MapGLAccount(FormTableRow.Parent, FormTableRow.Parent_IncomingData, DefaultValue, ChartsOfAccountsManager);
			
			// AccountType by description
			DefaultValue = Undefined;
			MapAccountType(FormTableRow.Type, FormTableRow.Type_IncomingData, DefaultValue);
			
			
			// StartDate by description
			ConvertStringToDate(FormTableRow.StartDate, FormTableRow.StartDate_IncomingData);
			
			// EndDate by description
			ConvertStringToDate(FormTableRow.EndDate, FormTableRow.EndDate_IncomingData);
			
			// Currency
			StringForMatch = ?(IsBlankString(FormTableRow.Currency_IncomingData), "FALSE", FormTableRow.Currency_IncomingData);
			ConvertStringToBoolean(FormTableRow.Currency, StringForMatch);
			
			// UseQuantity
			StringForMatch = ?(IsBlankString(FormTableRow.UseQuantity_IncomingData), "FALSE", FormTableRow.UseQuantity_IncomingData);
			ConvertStringToBoolean(FormTableRow.UseQuantity, StringForMatch);
			
			// UseAnalyticalDimensions
			StringForMatch = ?(IsBlankString(FormTableRow.UseAnalyticalDimensions_IncomingData), "FALSE", FormTableRow.UseAnalyticalDimensions_IncomingData);
			ConvertStringToBoolean(FormTableRow.UseAnalyticalDimensions, StringForMatch);
			
			// Order
			StringForMatch = ?(IsBlankString(FormTableRow.Order_IncomingData), FormTableRow.Code, FormTableRow.Order_IncomingData);
			CopyRowToStringTypeValue(FormTableRow.Order, StringForMatch);
			
			// AnalyticalDimensionsSet by description
			DefaultValue = Catalogs.AnalyticalDimensionsSets.EmptyRef();
			MapAnalyticalDimensionsSets(FormTableRow.AnalyticalDimensionsSet, FormTableRow.AnalyticalDimensionsSet_IncomingData, DefaultValue);
			
		ElsIf FillingObjectFullName = "AccountingRegister.AccountingJournalEntriesCompound" Then
			
			AccountingEntriesSettings = DataLoadSettings.AccountingEntriesSettings;
			IsCompound = (AccountingEntriesSettings.TypeOfEntries = Enums.ChartsOfAccountsTypesOfEntries.Compound);
			MaxAnalyticalDimensionsNumber = AccountingEntriesSettings.MaxAnalyticalDimensionsNumber;
			ChartOfAccounts = AccountingEntriesSettings.ChartOfAccounts;
			ChartsOfAccountsManager = ChartsOfAccounts.MasterChartOfAccounts;
			
			// Period
			ConvertStringToDate(FormTableRow.Period, FormTableRow.Period_IncomingData);
			
			// Amount
			ConvertRowToNumber(FormTableRow.Amount, FormTableRow.Amount_IncomingData);
			
			// Entry description
			CopyRowToStringTypeValue(FormTableRow.Content, FormTableRow.Content_IncomingData);
			
			If IsCompound Then
				
				// Record type
				MapAccountingRecordType(FormTableRow.RecordType, FormTableRow.RecordType_IncomingData);
				
				// Account by Code, Description
				CompareMasterAccount(FormTableRow.Account,
					FormTableRow.AccountCode,
					FormTableRow.AccountDescription,
					ChartOfAccounts,
					ChartsOfAccountsManager);
					
				// Ext dimensions
				If AccountingEntriesSettings.UseAnalyticalDimensions Then
					
					For Index = 1 To MaxAnalyticalDimensionsNumber Do
						
						ExtField = MasterAccountingClientServer.GetExtDimensionFieldName(Index);
						TypeField = MasterAccountingClientServer.GetExtDimensionFieldName(Index, "Type");
						NumberField = MasterAccountingClientServer.GetExtDimensionFieldName(Index, "Number");
						DateField = MasterAccountingClientServer.GetExtDimensionFieldName(Index, "Date");
						CodeField = MasterAccountingClientServer.GetExtDimensionFieldName(Index, "Code");
						DescriptionField = MasterAccountingClientServer.GetExtDimensionFieldName(Index, "Description");
						ErrorField = MasterAccountingClientServer.GetExtDimensionFieldName(Index, "Error");
						
						ExtDimensionAttributes = New Structure;
						ExtDimensionAttributes.Insert("Account", FormTableRow.Account);
						ExtDimensionAttributes.Insert("LineNumber", Index);
						ExtDimensionAttributes.Insert("TypeString", FormTableRow[TypeField]);
						ExtDimensionAttributes.Insert("Number", FormTableRow[NumberField]);
						ExtDimensionAttributes.Insert("DateString", FormTableRow[DateField]);
						ExtDimensionAttributes.Insert("Code", FormTableRow[CodeField]);
						ExtDimensionAttributes.Insert("Description", FormTableRow[DescriptionField]);
						
						MapExtDimension(FormTableRow[ExtField], ExtDimensionAttributes, FormTableRow[ErrorField]);
						
					EndDo;
					
				EndIf;
				
				// Currency
				MapCurrency(FormTableRow.Currency, FormTableRow.CurrencyName, FormTableRow.CurrencyCode);
				
				// Quantity
				If AccountingEntriesSettings.UseQuantity Then
					ConvertRowToNumber(FormTableRow.Quantity, FormTableRow.Quantity_IncomingData);
				EndIf;
				
				// Amount in transaction currency
				ConvertRowToNumber(FormTableRow.AmountCur, FormTableRow.AmountCur_IncomingData);
				
				ThisStringIsMapped = ValueIsFilled(FormTableRow.Account) And ValueIsFilled(FormTableRow.RecordType);
				
			Else
				
				// Account by Code, Description
				CompareMasterAccount(FormTableRow.AccountDr,
					FormTableRow.DebitCode,
					FormTableRow.DebitDescription,
					ChartOfAccounts,
					ChartsOfAccountsManager);
					
				CompareMasterAccount(FormTableRow.AccountCr,
					FormTableRow.CreditCode,
					FormTableRow.CreditDescription,
					ChartOfAccounts,
					ChartsOfAccountsManager);
					
				// Ext dimensions
				If AccountingEntriesSettings.UseAnalyticalDimensions Then
					
					For Index = 1 To MaxAnalyticalDimensionsNumber Do
						
						ExtField = MasterAccountingClientServer.GetExtDimensionFieldName(Index, "Dr");
						TypeField = MasterAccountingClientServer.GetExtDimensionFieldName(Index, "Dr", "Type");
						NumberField = MasterAccountingClientServer.GetExtDimensionFieldName(Index, "Dr", "Number");
						DateField = MasterAccountingClientServer.GetExtDimensionFieldName(Index, "Dr", "Date");
						CodeField = MasterAccountingClientServer.GetExtDimensionFieldName(Index, "Dr", "Code");
						DescriptionField = MasterAccountingClientServer.GetExtDimensionFieldName(Index, "Dr", "Description");
						ErrorField = MasterAccountingClientServer.GetExtDimensionFieldName(Index, "Dr", "Error");
						
						ExtDimensionAttributes = New Structure;
						ExtDimensionAttributes.Insert("Account", FormTableRow.AccountDr);
						ExtDimensionAttributes.Insert("LineNumber", Index);
						ExtDimensionAttributes.Insert("TypeString", FormTableRow[TypeField]);
						ExtDimensionAttributes.Insert("Number", FormTableRow[NumberField]);
						ExtDimensionAttributes.Insert("DateString", FormTableRow[DateField]);
						ExtDimensionAttributes.Insert("Code", FormTableRow[CodeField]);
						ExtDimensionAttributes.Insert("Description", FormTableRow[DescriptionField]);
						
						MapExtDimension(FormTableRow[ExtField], ExtDimensionAttributes, FormTableRow[ErrorField]);
						
						ExtField = MasterAccountingClientServer.GetExtDimensionFieldName(Index, "Cr");
						TypeField = MasterAccountingClientServer.GetExtDimensionFieldName(Index, "Cr", "Type");
						NumberField = MasterAccountingClientServer.GetExtDimensionFieldName(Index, "Cr", "Number");
						DateField = MasterAccountingClientServer.GetExtDimensionFieldName(Index, "Cr", "Date");
						CodeField = MasterAccountingClientServer.GetExtDimensionFieldName(Index, "Cr", "Code");
						DescriptionField = MasterAccountingClientServer.GetExtDimensionFieldName(Index, "Cr", "Description");
						ErrorField = MasterAccountingClientServer.GetExtDimensionFieldName(Index, "Cr", "Error");
						
						ExtDimensionAttributes = New Structure;
						ExtDimensionAttributes.Insert("Account", FormTableRow.AccountCr);
						ExtDimensionAttributes.Insert("LineNumber", Index);
						ExtDimensionAttributes.Insert("TypeString", FormTableRow[TypeField]);
						ExtDimensionAttributes.Insert("Number", FormTableRow[NumberField]);
						ExtDimensionAttributes.Insert("DateString", FormTableRow[DateField]);
						ExtDimensionAttributes.Insert("Code", FormTableRow[CodeField]);
						ExtDimensionAttributes.Insert("Description", FormTableRow[DescriptionField]);
						
						MapExtDimension(FormTableRow[ExtField], ExtDimensionAttributes, FormTableRow[ErrorField]);
						
					EndDo;
					
				EndIf;
				
				// Currency
				MapCurrency(FormTableRow.CurrencyDr, FormTableRow.CurrencyNameDr, FormTableRow.CurrencyCodeDr);
				MapCurrency(FormTableRow.CurrencyCr, FormTableRow.CurrencyNameCr, FormTableRow.CurrencyCodeCr);
				
				// Quantity
				If AccountingEntriesSettings.UseQuantity Then
					ConvertRowToNumber(FormTableRow.QuantityDr, FormTableRow.QuantityDr_IncomingData);
					ConvertRowToNumber(FormTableRow.QuantityCr, FormTableRow.QuantityCr_IncomingData);
				EndIf;
				
				// Amount in transaction currency
				ConvertRowToNumber(FormTableRow.AmountCurDr, FormTableRow.AmountCurDr_IncomingData);
				ConvertRowToNumber(FormTableRow.AmountCurCr, FormTableRow.AmountCurCr_IncomingData);
				
				ThisStringIsMapped = ValueIsFilled(FormTableRow.AccountDr) And ValueIsFilled(FormTableRow.AccountCr);
				
			EndIf;
			
		ElsIf FillingObjectFullName = "Document.SalesTarget.TabularSection.Inventory" Then
			
			SalesGoalSettingAttributes = DataLoadSettings.SalesGoalSettingAttributes;
			
			For Each Dimension In SalesGoalSettingAttributes.Dimensions Do
				
				If Dimension = "SalesRep" Then
					
					MapSalesRep(FormTableRow.SalesRep, FormTableRow.SalesRep_IncomingData, Undefined);
					
				ElsIf Dimension = "SalesTerritory" Then
					
					MapSalesTerritory(FormTableRow.SalesTerritory, FormTableRow.SalesTerritory_IncomingData, Undefined);
					
				ElsIf Dimension = "Project" Then
					
					MapProject(FormTableRow.Project, FormTableRow.Project_IncomingData, Undefined);
					
				ElsIf Dimension = "ProductCategory" Then
					
					MapProductsCategory(FormTableRow.ProductCategory, FormTableRow.ProductCategory_IncomingData, Undefined);
				
				ElsIf Dimension = "ProductGroup" Then
					
					MapProductGroup(FormTableRow.ProductGroup, FormTableRow.ProductGroup_IncomingData, Undefined);
					
				ElsIf Dimension = "Products" Then
					
					CompareProducts(FormTableRow.Products,
									FormTableRow.Barcode,
									FormTableRow.SKU,
									FormTableRow.ProductsDescription,
									FormTableRow.ProductsDescriptionFull);
									
					If GetFunctionalOption("UseCharacteristics") Then
						If ValueIsFilled(FormTableRow.Products) Then
							MapCharacteristic(FormTableRow.Characteristic, FormTableRow.Products, "", FormTableRow.Characteristic_IncomingData);
						EndIf;
					EndIf;
					
				EndIf;
				
			EndDo;
			
			If SalesGoalSettingAttributes.SpecifyQuantity Then
				
				DefaultValue = Undefined;
				WhenDefiningDefaultValue(FormTableRow.Products,
					"MeasurementUnit",
					FormTableRow.MeasurementUnit_IncomingData,
					ValueIsFilled(FormTableRow.Products),
					DefaultValue);
				MapUOM(FormTableRow.Products, FormTableRow.MeasurementUnit, FormTableRow.MeasurementUnit_IncomingData, DefaultValue);
				
				ConvertRowToNumber(FormTableRow.Price, FormTableRow.Price_IncomingData);
				
			EndIf;
			
			For Index = 0 To DataLoadSettings.Periods.Count() - 1 Do
				
				If SalesGoalSettingAttributes.SpecifyQuantity Then
					
					ConvertRowToNumber(FormTableRow["ColumnQuantity_" + Format(Index, "NZ=0; NG=0")],
						FormTableRow["ColumnQuantity_" + Format(Index, "NZ=0; NG=0") + "_IncomingData"]);
					
				EndIf;
				
				ConvertRowToNumber(FormTableRow["ColumnAmount_" + Format(Index, "NZ=0; NG=0")],
					FormTableRow["ColumnAmount_" + Format(Index, "NZ=0; NG=0") + "_IncomingData"]);
				
			EndDo;
		
		ElsIf FillingObjectFullName = "ChartOfAccounts.FinancialChartOfAccounts" Then
			
			ChartsOfAccountsManager = ChartsOfAccounts.FinancialChartOfAccounts;
			
			// Account by Code, Description
			CompareAccount(FormTableRow.Account, FormTableRow.Code, FormTableRow.Description, ChartsOfAccountsManager);
			ThisStringIsMapped = ValueIsFilled(FormTableRow.Account);
			
			// Parent by code
			DefaultValue = ChartsOfAccountsManager.EmptyRef();
			MapGLAccount(FormTableRow.Parent, FormTableRow.Parent_IncomingData, DefaultValue, ChartsOfAccountsManager);
			
			// AccountType by description
			DefaultValue = Undefined;
			MapAccountType(FormTableRow.Type, FormTableRow.Type_IncomingData, DefaultValue);
			
			// Currency
			StringForMatch = ?(IsBlankString(FormTableRow.Currency_IncomingData), "FALSE", FormTableRow.Currency_IncomingData);
			ConvertStringToBoolean(FormTableRow.Currency, StringForMatch);
			
			// OffBalance
			StringForMatch = ?(IsBlankString(FormTableRow.OffBalance_IncomingData), "FALSE", FormTableRow.OffBalance_IncomingData);
			ConvertStringToBoolean(FormTableRow.OffBalance, StringForMatch);
			
			// Order
			StringForMatch = ?(IsBlankString(FormTableRow.Order_IncomingData), FormTableRow.Code, FormTableRow.Order_IncomingData);
			CopyRowToStringTypeValue(FormTableRow.Order, StringForMatch);
			
		ElsIf FillingObjectFullName = "Catalog.ProductsBatches" Then	
			
			// Owner by Barcode, SKU, Description
			CompareProducts(FormTableRow.Owner, FormTableRow.Barcode, FormTableRow.SKU, FormTableRow.ProductsDescription, FormTableRow.ProductsDescriptionFull);
			
			If ValueIsFilled(FormTableRow.Owner) Then
				
				BatchSettings = Catalogs.BatchSettings.ProductBatchSettings(FormTableRow.Owner);
				
				// BatchNumber
				If BatchSettings.UseBatchNumber Then
					CopyRowToStringTypeValue(FormTableRow.BatchNumber, FormTableRow.BatchNumber_IncomingData);
				EndIf;	
				
				// ExpirationDate
				If BatchSettings.UseExpirationDate Then
					ConvertStringToDate(FormTableRow.ExpirationDate, FormTableRow.ExpirationDate_IncomingData);
				EndIf;
				
				// ProductionDate
				If BatchSettings.UseProductionDate Then
					ConvertStringToDate(FormTableRow.ProductionDate, FormTableRow.ProductionDate_IncomingData);
				EndIf;
				
				// Description 
				If Not ValueIsFilled(FormTableRow.Description) 					
					And Not IsBlankString(BatchSettings.DescriptionTemplate) Then
					
					FormatString = DriveClientServer.DatePrecisionFormatString(BatchSettings.ExpirationDatePrecision); 							
					If IsBlankString(FormatString) Then 								
						ExpirationDate = String(FormTableRow.ExpirationDate);								
					Else								
						ExpirationDate = Format(FormTableRow.ExpirationDate, FormatString);								
					EndIf;
					
					FormatString = DriveClientServer.DatePrecisionFormatString(BatchSettings.ProductionDatePrecision); 							
					If IsBlankString(FormatString) Then 								
						ProductionDate = String(FormTableRow.ProductionDate);								
					Else								
						ProductionDate = Format(FormTableRow.ProductionDate, FormatString);								
					EndIf;
					
					FormTableRow.Description = StringFunctionsClientServer.SubstituteParametersToString(BatchSettings.DescriptionTemplate,
							FormTableRow.BatchNumber, ExpirationDate, ProductionDate); 						
				EndIf;
				
			EndIf;
			
			// Batch
			MapBatch(FormTableRow.Batch, FormTableRow.Owner, FormTableRow.Barcode, FormTableRow.Description);
						
			ThisStringIsMapped = ValueIsFilled(FormTableRow.Batch);
		
		// Inventory
		Else
			
			If FillingObjectFullName = "Document.ActualSalesVolume.TabularSection.Inventory"
				And DataLoadSettings.CounterpartyAndContractPositionInTabularSection Then
				
				MapSupplier(FormTableRow.Counterparty, FormTableRow.CounterpartyTIN, FormTableRow.CounterpartyDescription);
				ThisStringIsMapped = ValueIsFilled(FormTableRow.Counterparty);
				
				If ThisStringIsMapped Then
					MapContract(FormTableRow.Counterparty, FormTableRow.Contract, FormTableRow.ContractDescription,
						FormTableRow.ContractNo, DataLoadSettings.DocumentAttributes.Company);
				EndIf;
				
				If Not ValueIsFilled(FormTableRow.Contract) Then
					If IsBlankString(FormTableRow.ContractDescription) And Not IsBlankString(FormTableRow.ContractNo) Then
						If Not IsBlankString(FormTableRow.ContractDate) Then
							ContractDescription = NStr("en = '#%1 dated %2'; ru = '№ %1 от %2';pl = '#%1 z dn. %2';es_ES = '#%1 fechado %2';es_CO = '#%1 fechado %2';tr = 'no %1 tarih %2';it = '#%1 con data %2';de = 'Nr. %1 vom %2'");
						Else
							ContractDescription = NStr("en = '#%1'; ru = '#%1';pl = '#%1';es_ES = '#%1';es_CO = '#%1';tr = '#%1';it = '#%1';de = '#%1'");
						EndIf;
						FormTableRow.ContractDescription = StringFunctionsClientServer.SubstituteParametersToString(
							ContractDescription,
							FormTableRow.ContractNo,
							Format(FormTableRow.ContractDate, "DLF=D")); 
					EndIf;
				EndIf;
				
			ElsIf FillingObjectFullName = "Document.OpeningBalanceEntry.TabularSection.Inventory" Then
				
				If DataLoadSettings.DocumentAttributes.InventoryValuationMethod = Enums.InventoryValuationMethods.FIFO Then
				
					If IsBlankString(FormTableRow.DocumentType) Then
						FormTableRow.DocumentType = Metadata.Documents.SupplierInvoice.Name;
					Else
						TypeArray = Metadata.Documents.OpeningBalanceEntry.TabularSections.Inventory.Attributes.Document.Type.Types();	
						MapDocumentNames = GetDocumentTypesMap(TypeArray);	
						FormTableRow.DocumentType = MapDocumentNames.Get(UpperNoBlanks(FormTableRow.DocumentType));
					EndIf;
					
					MapInventoryAcquisitionDocumentByNumberDate(FormTableRow.Document, FormTableRow.DocumentType,
						FormTableRow.DocumentNumber, FormTableRow.DocumentDate);
						
				EndIf;
				
			EndIf;
			
			UseSeveralWarehouses = GetFunctionalOption("UseSeveralWarehouses")
				And Common.HasObjectAttribute("StructuralUnit", FilledObject);
			
			If UseSeveralWarehouses Then
				MapStructuralUnit(FormTableRow.StructuralUnit, FormTableRow.StructuralUnitDescription, Undefined);
			EndIf;
			
			If GetFunctionalOption("UseStorageBins") And Common.HasObjectAttribute("Cell", FilledObject) Then
				If UseSeveralWarehouses Then
					If ValueIsFilled(FormTableRow.StructuralUnit) Then
						MapCell(FormTableRow.Cell, FormTableRow.CellDescription, , FormTableRow.StructuralUnit);
					EndIf;
				Else
					MapCell(FormTableRow.Cell, FormTableRow.CellDescription, , Catalogs.BusinessUnits.MainWarehouse);
				EndIf;
			EndIf;
			
			// Product by Barcode, SKU, Description
			If Common.HasObjectAttribute("Products", FilledObject) Then
				If DataLoadSettings.Property("Supplier") Then
					CompareProducts(FormTableRow.Products,
									FormTableRow.Barcode,
									FormTableRow.SKU,
									FormTableRow.ProductsDescription,
									FormTableRow.ProductsDescriptionFull,
									FormTableRow.Code,
									DataLoadSettings.Supplier)
				Else
					CompareProducts(FormTableRow.Products,
									FormTableRow.Barcode,
									FormTableRow.SKU,
									FormTableRow.ProductsDescription,
									FormTableRow.ProductsDescriptionFull,
									FormTableRow.Code)
				EndIf;
			EndIf;
			
			// Variant by Owner and Name
			If GetFunctionalOption("UseCharacteristics")
				And Common.HasObjectAttribute("Characteristic", FilledObject)
				And ValueIsFilled(FormTableRow.Products) Then
				MapCharacteristic(FormTableRow.Characteristic, FormTableRow.Products, FormTableRow.Barcode, FormTableRow.CharacteristicDescription);
			EndIf;
			
			// Batch by Owner and Name
			If GetFunctionalOption("UseBatches")
				And Common.HasObjectAttribute("Batch", FilledObject)
				And ValueIsFilled(FormTableRow.Products) Then
				MapBatch(FormTableRow.Batch, FormTableRow.Products, FormTableRow.Barcode, FormTableRow.BatchDescription);
			EndIf;
			
			// Quantity
			If Common.HasObjectAttribute("Quantity", FilledObject) Then
				ConvertRowToNumber(FormTableRow.Quantity, FormTableRow.Quantity_IncomingData);
			EndIf;
			
			// Reserve
			If GetFunctionalOption("UseInventoryReservation")
				And Common.HasObjectAttribute("Reserve", FilledObject)
				And Not FillingObjectFullName = "Document.OpeningBalanceEntry.TabularSection.Inventory" Then
				ConvertRowToNumber(FormTableRow.Reserve, FormTableRow.Reserve_IncomingData, 0);
			EndIf;
			
			// MeasurementUnits by Description (also consider the option to bind user MU)
			If Common.HasObjectAttribute("MeasurementUnit", FilledObject) Then
				DefaultValue = Undefined;
				WhenDefiningDefaultValue(FormTableRow.Products,
					"MeasurementUnit",
					FormTableRow.MeasurementUnitDescription,
					ValueIsFilled(FormTableRow.Products),
					DefaultValue);
				MapUOM(FormTableRow.Products, FormTableRow.MeasurementUnit, FormTableRow.MeasurementUnitDescription, DefaultValue);
			EndIf;
			
			// Price
			If Common.HasObjectAttribute("Price", FilledObject) Then
				ConvertRowToNumber(FormTableRow.Price, FormTableRow.Price_IncomingData);
			EndIf;
			
			// Amount
			If Common.HasObjectAttribute("Amount", FilledObject) Then
				ConvertRowToNumber(FormTableRow.Amount, FormTableRow.Amount_IncomingData);
			EndIf;
			
			// VATRate
			If Common.HasObjectAttribute("VATRate", FilledObject) Then
				MapVATRate(FormTableRow.VATRate, FormTableRow.VATRate_IncomingData, Undefined);
			EndIf;
			
			// VATAmount
			If Common.HasObjectAttribute("VATAmount", FilledObject) Then
				ConvertRowToNumber(FormTableRow.VATAmount, FormTableRow.VATAmount_IncomingData, 0);
			EndIf;
			
			// ReceiptDate
			If Common.HasObjectAttribute("ReceiptDate", FilledObject) Then
				ConvertStringToDate(FormTableRow.ReceiptDate, FormTableRow.ReceiptDate_IncomingData);
			EndIf;
			
			// Order
			If Common.HasObjectAttribute("Order", FilledObject) Then
				MatchOrder(FormTableRow.Order, FormTableRow.Order_IncomingData);
			EndIf;
			
			If GetFunctionalOption("UseSerialNumbers") Then
				If FormTableRow.Property("SerialNumber_IncomingData")
					And ValueIsFilled(FormTableRow.SerialNumber_IncomingData) Then
					MapSerialNumber(FormTableRow.Products, FormTableRow.SerialNumber, FormTableRow.SerialNumber_IncomingData);
				EndIf;
			EndIf;
			
			// Specification
			If Common.HasObjectAttribute("Specification", FilledObject) Then
				If GetFunctionalOption("UseWorkOrders")
					// begin Drive.FullVersion
					Or GetFunctionalOption("UseProductionSubsystem")
					// end Drive.FullVersion
					Then
					
					If ValueIsFilled(FormTableRow.Products) Then
						MapSpecification(FormTableRow.Specification, FormTableRow.Specification_IncomingData, FormTableRow.Products);
					EndIf;
					
				EndIf;
			EndIf;
		EndIf;
		
		// Additional attributes		
		If DataLoadSettings.Property("SelectedAdditionalAttributes") AND DataLoadSettings.SelectedAdditionalAttributes.Count() > 0 Then
			MapAdditionalAttributes(FormTableRow, DataLoadSettings.SelectedAdditionalAttributes);
		EndIf;
		
		CheckDataCorrectnessInTableRow(FormTableRow, FillingObjectFullName, DataLoadSettings);
		
	EndDo;
	
EndProcedure

Procedure WhenDefiningDefaultValue(CatalogRef, AttributeName, IncomingData, RowMatched, DefaultValue)
	
	If RowMatched 
		AND Not ValueIsFilled(IncomingData) Then
		
		DefaultValue = Common.ObjectAttributeValue(CatalogRef, AttributeName);
		
	EndIf;
	
EndProcedure

Procedure CheckDataCorrectnessInTableRow(FormTableRow, FillingObjectFullName = "", DataLoadSettings = Undefined) Export
	
	FilledObject 		= Metadata.FindByFullName(FillingObjectFullName);
	ServiceFieldName	= DataImportFromExternalSources.ServiceFieldNameImportToApplicationPossible();
	
	If FillingObjectFullName = "Catalog.Counterparties" Then 
		
		FormTableRow._RowMatched = ValueIsFilled(FormTableRow.Counterparty);
		FormTableRow[ServiceFieldName] = FormTableRow._RowMatched
		OR (NOT FormTableRow._RowMatched AND Not IsBlankString(FormTableRow.CounterpartyDescription));
		
	ElsIf FillingObjectFullName = "Catalog.Cells" Then
		
		FormTableRow._RowMatched = ValueIsFilled(FormTableRow.Cells);
		FormTableRow[ServiceFieldName] = FormTableRow._RowMatched
		OR (NOT FormTableRow._RowMatched AND Not IsBlankString(FormTableRow.CellsDescription) 
		AND ValueIsFilled(FormTableRow.Owner));
		
	ElsIf FillingObjectFullName = "Catalog.Products" Then
		
		FormTableRow._RowMatched = ValueIsFilled(FormTableRow.Products);
		FormTableRow[ServiceFieldName] = FormTableRow._RowMatched
		OR (NOT FormTableRow._RowMatched AND Not IsBlankString(FormTableRow.ProductsDescription));
		
	ElsIf  FillingObjectFullName = "Catalog.SalesTaxRates" Then
		
		FormTableRow._RowMatched = ValueIsFilled(FormTableRow.SalesTaxRates);
		FormTableRow[ServiceFieldName] = FormTableRow._RowMatched
		OR (NOT FormTableRow._RowMatched AND Not IsBlankString(FormTableRow.Description));
		
	// begin Drive.FullVersion
	
	ElsIf FillingObjectFullName = "Catalog.CompanyResourceTypes" Then
		
		FormTableRow._RowMatched = ValueIsFilled(FormTableRow.CompanyResourceType);
		FormTableRow[ServiceFieldName] = FormTableRow._RowMatched
			Or Not IsBlankString(FormTableRow.Description)
				And ValueIsFilled(FormTableRow.BusinessUnit)
				And (FormTableRow.PlanningOnWorkcentersLevel
					Or ValueIsFilled(FormTableRow.Schedule));
		
	ElsIf FillingObjectFullName = "Catalog.CompanyResources" Then
		
		FormTableRow._RowMatched = ValueIsFilled(FormTableRow.CompanyResource);
		FormTableRow[ServiceFieldName] = FormTableRow._RowMatched
			Or Not IsBlankString(FormTableRow.Description)
				And ValueIsFilled(FormTableRow.WorkcenterType)
				And (ValueIsFilled(FormTableRow.Schedule)
					Or Not Common.ObjectAttributeValue(FormTableRow.WorkcenterType, "PlanningOnWorkcentersLevel"));
		
	ElsIf FillingObjectFullName = "Catalog.ManufacturingActivities" Then
		
		FormTableRow._RowMatched = ValueIsFilled(FormTableRow.Operation);
		FormTableRow[ServiceFieldName] = FormTableRow._RowMatched
			Or Not IsBlankString(FormTableRow.Description)
				And ValueIsFilled(FormTableRow.CostPool);
				
	// end Drive.FullVersion
	
	ElsIf FillingObjectFullName = "Catalog.BillsOfMaterials.TabularSection.Content" Then
		
		FormTableRow[ServiceFieldName] = ValueIsFilled(FormTableRow.Products) 
		AND  ValueIsFilled(FormTableRow.ContentRowType) 
		AND FormTableRow.Quantity <> 0;
		
	ElsIf FillingObjectFullName = "InformationRegister.Prices" Then
		
		FormTableRow[ServiceFieldName] = ValueIsFilled(FormTableRow.PriceKind)
		AND Not FormTableRow.PriceKind.CalculatesDynamically
		AND ValueIsFilled(FormTableRow.Products)
		AND FormTableRow.Price > 0
		AND ValueIsFilled(FormTableRow.MeasurementUnit)
		AND ValueIsFilled(FormTableRow.Date);
		
		If FormTableRow[ServiceFieldName] Then
			
			RecordSet = InformationRegisters.Prices.CreateRecordSet();
			RecordSet.Filter.Period.Set(BegOfDay(FormTableRow.Date));
			RecordSet.Filter.PriceKind.Set(FormTableRow.PriceKind);
			RecordSet.Filter.Products.Set(FormTableRow.Products);
			
			If GetFunctionalOption("UseCharacteristics") Then
				
				RecordSet.Filter.Characteristic.Set(FormTableRow.Characteristic);
				
			EndIf;
			
			RecordSet.Read();
			
			FormTableRow._RowMatched = (RecordSet.Count() > 0);
			
		EndIf;
		
	ElsIf FillingObjectFullName = "Document.OpeningBalanceEntry.TabularSection.AccountsReceivable" 
		OR FillingObjectFullName = "Document.OpeningBalanceEntry.TabularSection.AccountsPayable" Then
		
		FormTableRow._RowMatched = ValueIsFilled(FormTableRow.Counterparty);
		
		ForeignExchangeAccounting = GetFunctionalOption("ForeignExchangeAccounting");
		
		FormTableRow[ServiceFieldName] = (FormTableRow._RowMatched
				Or DataLoadSettings.CreateIfNotMatched
					And Not IsBlankString(FormTableRow.CounterpartyDescription))
			And (Not ForeignExchangeAccounting
				Or ValueIsFilled(FormTableRow.Currency)
				Or DataLoadSettings.CreateIfNotMatched
					And Not IsBlankString(FormTableRow.CurrencyCode)
					And Not IsBlankString(FormTableRow.CurrencyName))
			And (ValueIsFilled(FormTableRow.Document)
				Or Not IsBlankString(FormTableRow.DocumentNumber)
					And Not IsBlankString(FormTableRow.DocumentDate)
					And Not IsBlankString(FormTableRow.DocumentType)
					And Not FormTableRow.DocumentType = InvalidDocumentType())
			And FormTableRow.AmountCur <> 0;
		
	ElsIf FillingObjectFullName = "Document.OpeningBalanceEntry.TabularSection.CashAssets" Then
		
		FormTableRow._RowMatched = ValueIsFilled(FormTableRow.Account);
		
		ForeignExchangeAccounting = GetFunctionalOption("ForeignExchangeAccounting");
		
		If DataLoadSettings.AccountType = "BankAccount" Then
			
			FormTableRow[ServiceFieldName] = FormTableRow._RowMatched
				Or (ValueIsFilled(FormTableRow.Bank)
						Or DataLoadSettings.CreateIfNotMatched
							And Not IsBlankString(FormTableRow.BankCode)
							And Not IsBlankString(FormTableRow.BankDescription))
					And (Not ForeignExchangeAccounting
						Or ValueIsFilled(FormTableRow.Currency)
						Or DataLoadSettings.CreateIfNotMatched
							And Not IsBlankString(FormTableRow.CurrencyCode)
							And Not IsBlankString(FormTableRow.CurrencyName))
					And Not IsBlankString(FormTableRow.IBAN)
						Or Not IsBlankString(FormTableRow.AccountNo);
			
		ElsIf DataLoadSettings.AccountType = "CashAccount" Then
			
			FormTableRow[ServiceFieldName] = (FormTableRow._RowMatched
					Or DataLoadSettings.CreateIfNotMatched
						And Not IsBlankString(FormTableRow.Description))
				And (Not ForeignExchangeAccounting
						Or ValueIsFilled(FormTableRow.Currency)
						Or DataLoadSettings.CreateIfNotMatched
							And Not IsBlankString(FormTableRow.CurrencyCode)
							And Not IsBlankString(FormTableRow.CurrencyName));
			
		EndIf;
		
	ElsIf FillingObjectFullName = "Document.SupplierInvoice.TabularSection.Expenses" Then
		FormTableRow[ServiceFieldName] = ValueIsFilled(FormTableRow.Products)
			AND FormTableRow.Products.ProductsType = Enums.ProductsTypes.Service
			AND FormTableRow.Quantity <> 0
			AND FormTableRow.Price <> 0;
		
	ElsIf FillingObjectFullName = "Catalog.Leads" Then 
		
		FormTableRow._RowMatched = ValueIsFilled(FormTableRow.Lead);
		FormTableRow[ServiceFieldName] = FormTableRow._RowMatched
			OR (NOT FormTableRow._RowMatched AND Not IsBlankString(FormTableRow.Description));
		
	ElsIf FillingObjectFullName = "Document.RequestForQuotation.TabularSection.Suppliers" Then
		
		FormTableRow[ServiceFieldName] = ValueIsFilled(FormTableRow.Counterparty)
		
	ElsIf FillingObjectFullName = "ChartOfAccounts.PrimaryChartOfAccounts" Then 
		
		FormTableRow._RowMatched = ValueIsFilled(FormTableRow.Account);
		FormTableRow[ServiceFieldName] = (FormTableRow._RowMatched Or Not IsBlankString(FormTableRow.Description));
		
	ElsIf FillingObjectFullName = "ChartOfAccounts.MasterChartOfAccounts" Then 
		
		FormTableRow._RowMatched = ValueIsFilled(FormTableRow.Account)
			And ValueIsFilled(FormTableRow.ChartOfAccounts)
			And Not IsBlankString(FormTableRow.Description);
		FormTableRow[ServiceFieldName] = FormTableRow._RowMatched Or Not IsBlankString(FormTableRow.Description);
		
	ElsIf FillingObjectFullName = "AccountingRegister.AccountingJournalEntriesCompound" Then
		
		AccountingEntriesSettings = DataLoadSettings.AccountingEntriesSettings;
		IsCompound = (AccountingEntriesSettings.TypeOfEntries = Enums.ChartsOfAccountsTypesOfEntries.Compound);
		MaxAnalyticalDimensionsNumber = AccountingEntriesSettings.MaxAnalyticalDimensionsNumber;
		
		If IsCompound Then
			
			FormTableRow._RowMatched = ValueIsFilled(FormTableRow.Account);
			
			If AccountingEntriesSettings.UseAnalyticalDimensions Then
				
				For Index = 1 To MaxAnalyticalDimensionsNumber Do
				
					ExtDimensionField = MasterAccountingClientServer.GetExtDimensionFieldName(Index);
					ErrorField = MasterAccountingClientServer.GetExtDimensionFieldName(Index, "Error");
					FormTableRow._RowMatched = FormTableRow._RowMatched
						And (Not ValueIsFilled(FormTableRow[ErrorField]) Or ValueIsFilled(FormTableRow[ExtDimensionField]));
					
				EndDo;
				
			EndIf;
			
			FormTableRow[ServiceFieldName] = FormTableRow._RowMatched;
			
		Else
			
			FormTableRow._RowMatched = ValueIsFilled(FormTableRow.AccountDr) And ValueIsFilled(FormTableRow.AccountCr);
			
			If AccountingEntriesSettings.UseAnalyticalDimensions Then
				
				For Index = 1 To MaxAnalyticalDimensionsNumber Do
					
					ExtDimensionField = MasterAccountingClientServer.GetExtDimensionFieldName(Index, "Dr");
					ErrorField = MasterAccountingClientServer.GetExtDimensionFieldName(Index, "Dr", "Error");
					FormTableRow._RowMatched = FormTableRow._RowMatched
						And (Not ValueIsFilled(FormTableRow[ErrorField]) Or ValueIsFilled(FormTableRow[ExtDimensionField]));
					ExtDimensionField = MasterAccountingClientServer.GetExtDimensionFieldName(Index, "Cr");
					ErrorField = MasterAccountingClientServer.GetExtDimensionFieldName(Index, "Cr", "Error");
					FormTableRow._RowMatched = FormTableRow._RowMatched
						And (Not ValueIsFilled(FormTableRow[ErrorField]) Or ValueIsFilled(FormTableRow[ExtDimensionField]));
					
				EndDo;
				
			EndIf;
			
			FormTableRow[ServiceFieldName] = FormTableRow._RowMatched;
			
		EndIf;
		
	ElsIf FillingObjectFullName = "Document.SalesTarget.TabularSection.Inventory" Then 
		
		FormTableRow[ServiceFieldName] = True;
		
		If DataLoadSettings <> Undefined Then
			
			AllColumnsAreEmpty = True;
			
			For Each Dimension In DataLoadSettings.SalesGoalSettingAttributes.Dimensions Do
				
				If ValueIsFilled(FormTableRow[Dimension]) Then
					AllColumnsAreEmpty = False;
					Break;
				EndIf;
				
			EndDo;
			
			FormTableRow[ServiceFieldName] = Not AllColumnsAreEmpty;
			
		EndIf;
	
	ElsIf FillingObjectFullName = "ChartOfAccounts.FinancialChartOfAccounts" Then 
		
		FormTableRow._RowMatched = ValueIsFilled(FormTableRow.Account);
		FormTableRow[ServiceFieldName] = (FormTableRow._RowMatched OR NOT IsBlankString(FormTableRow.Description));
		
		
	// begin Drive.FullVersion
	
	ElsIf FillingObjectFullName = "Catalog.RoutingTemplates.TabularSection.Operations" Then
		
		FormTableRow[ServiceFieldName] = ValueIsFilled(FormTableRow.Activity);
		
	// end Drive.FullVersion
	
	ElsIf FillingObjectFullName = "Catalog.ProductsBatches" Then 
		
		FormTableRow._RowMatched = ValueIsFilled(FormTableRow.Batch);
		FormTableRow[ServiceFieldName] = FormTableRow._RowMatched
			Or (Not FormTableRow._RowMatched And ValueIsFilled(FormTableRow.Owner) And Not IsBlankString(FormTableRow.Description));
			
		If FormTableRow[ServiceFieldName] Then
			
			BatchSettings = Catalogs.BatchSettings.ProductBatchSettings(FormTableRow.Owner);
			If (BatchSettings.UseBatchNumber And IsBlankString(FormTableRow.BatchNumber))
				Or (BatchSettings.UseExpirationDate And FormTableRow.ExpirationDate = Date(1,1,1))
				Or (BatchSettings.UseProductionDate And FormTableRow.ProductionDate = Date(1,1,1)) Then
				
				FormTableRow[ServiceFieldName] = False;
				
			EndIf;
			
		EndIf;
		
	// Inventory
	Else 
		
		If FillingObjectFullName = "Document.Pricing.TabularSection.Inventory" Then
			
			FormTableRow[ServiceFieldName] = ValueIsFilled(FormTableRow.Products)
				AND ?(FormTableRow.Property("Price"), FormTableRow.Price <> 0, True);
			
		Else
			
			FormTableRow._RowMatched = True;
			CanBeCreated = True;
			
			If FillingObjectFullName = "Document.ActualSalesVolume.TabularSection.Inventory"
				And DataLoadSettings.CounterpartyAndContractPositionInTabularSection Then
				
				FormTableRow._RowMatched = FormTableRow._RowMatched
					And ValueIsFilled(FormTableRow.Counterparty)
					And ValueIsFilled(FormTableRow.Contract);
				
				CanBeCreated = CanBeCreated
					And Not IsBlankString(FormTableRow.CounterpartyDescription)
					And Not IsBlankString(FormTableRow.ContractDescription);
					
			ElsIf FillingObjectFullName = "Document.OpeningBalanceEntry.TabularSection.Inventory" Then
				
				If DataLoadSettings.DocumentAttributes.InventoryValuationMethod = Enums.InventoryValuationMethods.FIFO Then
				
					FormTableRow._RowMatched = FormTableRow._RowMatched
						And ValueIsFilled(FormTableRow.Document)
						Or (Not IsBlankString(FormTableRow.DocumentNumber)
							And Not FormTableRow.DocumentType = InvalidDocumentType());
							
				EndIf;
				
			EndIf;
			
			If GetFunctionalOption("UseSeveralWarehouses")
				And Common.HasObjectAttribute("StructuralUnit", FilledObject) Then
				
				FormTableRow._RowMatched = FormTableRow._RowMatched
					And ValueIsFilled(FormTableRow.StructuralUnit);
					
				If Not ValueIsFilled(FormTableRow.StructuralUnit) Then
					CanBeCreated = CanBeCreated And Not IsBlankString(FormTableRow.StructuralUnitDescription);
				EndIf;
					
			EndIf;
			
			If GetFunctionalOption("UseStorageBins")
				And Common.HasObjectAttribute("Cell", FilledObject)
				And Not IsBlankString(FormTableRow.CellDescription) Then
				FormTableRow._RowMatched = FormTableRow._RowMatched
					And ValueIsFilled(FormTableRow.Cell);
			
			EndIf;
			
			If Common.HasObjectAttribute("Products", FilledObject) Then
				
				ThisIsExpenses		= (FillingObjectFullName = "Document.SupplierInvoice.TabularSection.Expenses");
				ServicesAvailable	= (FillingObjectFullName = "Document.SalesOrder.TabularSection.Inventory") 
					Or (FillingObjectFullName = "Document.SalesInvoice.TabularSection.Inventory")
					Or (FillingObjectFullName = "Document.PurchaseOrder.TabularSection.Inventory")
					Or (FillingObjectFullName = "Document.ActualSalesVolume.TabularSection.Inventory");
					
				ProductsType = Common.ObjectAttributeValue(FormTableRow.Products, "ProductsType");
				ProductsTypeIsService = (ProductsType = Enums.ProductsTypes.Service);
				
				FormTableRow._RowMatched = FormTableRow._RowMatched
					And ValueIsFilled(FormTableRow.Products)
					And (Not ProductsTypeIsService
							Or ThisIsExpenses
							Or ServicesAvailable);
				
				If Not ValueIsFilled(FormTableRow.Products) Then
					CanBeCreated = CanBeCreated
						And Not IsBlankString(FormTableRow.ProductsDescription);
				EndIf;
					
			EndIf;
			
			If GetFunctionalOption("UseCharacteristics")
				And Common.HasObjectAttribute("Characteristic", FilledObject)
				And Not IsBlankString(FormTableRow.CharacteristicDescription) Then
				FormTableRow._RowMatched = FormTableRow._RowMatched
					And ValueIsFilled(FormTableRow.Characteristic);
			EndIf;
			
			If GetFunctionalOption("UseBatches")
				And Common.HasObjectAttribute("Batch", FilledObject)
				And Not IsBlankString(FormTableRow.BatchDescription) Then
				FormTableRow._RowMatched = FormTableRow._RowMatched
					And ValueIsFilled(FormTableRow.Batch);
			EndIf;
			
			If Common.HasObjectAttribute("MeasurementUnit", FilledObject) Then
				FormTableRow._RowMatched = FormTableRow._RowMatched
					And ValueIsFilled(FormTableRow.MeasurementUnit);
				If Not ValueIsFilled(FormTableRow.MeasurementUnit) Then
					CanBeCreated = CanBeCreated
						And Not IsBlankString(FormTableRow.MeasurementUnitDescription)
						// only UOMClassifier for new products items can be created
						And Not ValueIsFilled(FormTableRow.Products);
				EndIf;
			EndIf;
				
			FormTableRow[ServiceFieldName] = FormTableRow._RowMatched
				Or DataLoadSettings.CreateIfNotMatched
					And CanBeCreated;
				
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure ImportDataFromExternalSourceResultDataProcessor(ImportResult, Object = Undefined, CurrentForm = Undefined) Export
	
	Try
		
		BeginTransaction();
		
		DataMatchingTable 		= ImportResult.DataMatchingTable;
		DataLoadSettings 		= ImportResult.DataLoadSettings;
		UpdateExisting 			= DataLoadSettings.UpdateExisting;
		CreateIfNotMatched 		= DataLoadSettings.CreateIfNotMatched;
		FillingObjectFullName	= DataLoadSettings.FillingObjectFullName;
		IsTabularSectionImport	= DataLoadSettings.IsTabularSectionImport;
		UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
		
		If Type(Object) = Type("FormDataStructure") And Object.Property("Company") Then
			DefaultVATRate = InformationRegisters.AccountingPolicy.GetDefaultVATRate(, Object.Company);
		Else	
			DefaultVATRate = Catalogs.VATRates.Exempt; 
		EndIf;
		
		If IsTabularSectionImport Then
			ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(Object);
			GLAccountsInDocuments.CompleteObjectParameters(Object, ObjectParameters);
		EndIf;
		
		For Each TableRow In DataMatchingTable Do
			
			ImportToApplicationIsPossible = TableRow[DataImportFromExternalSources.ServiceFieldNameImportToApplicationPossible()];
			
			If FillingObjectFullName = "Catalog.Counterparties" Then 
				
				CoordinatedStringStatus = (TableRow._RowMatched AND UpdateExisting) 
				OR (NOT TableRow._RowMatched AND CreateIfNotMatched);
				
				If ImportToApplicationIsPossible AND CoordinatedStringStatus Then
					
					If TableRow._RowMatched Then
						CatalogItem					= TableRow.Counterparty.GetObject();
					Else
						CatalogItem					= Catalogs.Counterparties.CreateItem();
						CatalogItem.Parent			= TableRow.Parent;
						CatalogItem.CreationDate	= CurrentSessionDate();
					EndIf;
					
					CatalogItem.Description 	= TableRow.CounterpartyDescription;
					
					FillPropertyValues(CatalogItem, TableRow, , "Parent");
					
					CatalogItem.LegalEntityIndividual = ?(TableRow.ThisIsInd, Enums.CounterpartyType.Individual, Enums.CounterpartyType.LegalEntity);
					
					If Not IsBlankString(TableRow.TIN) Then
						
						Separators = New Array;
						Separators.Add("/");
						Separators.Add("\");
						Separators.Add("|");
						
						TIN = "";
						
						For Each SeparatorValue In Separators Do
							
							SeparatorPosition = Find(TableRow.TIN, SeparatorValue);
							If SeparatorPosition = 0 Then 
								Continue;
							EndIf;
							
							TIN = Left(TableRow.TIN, SeparatorPosition - 1);
							
						EndDo;
						
						If IsBlankString(TIN) Then
							TIN = TableRow.TIN;
						EndIf;
						
						CatalogItem.TIN = TIN;
						
					EndIf;
					
					If Not IsBlankString(TableRow.Phone) Then
						AddContacts(CatalogItem, TableRow.Phone, Catalogs.ContactInformationKinds.CounterpartyPhone);  
					EndIf;
					
					If Not IsBlankString(TableRow.EMail_Address) Then
						AddContacts(CatalogItem, TableRow.EMail_Address, Catalogs.ContactInformationKinds.CounterpartyEmail);  
					EndIf;
					
					If DataLoadSettings.SelectedAdditionalAttributes.Count() > 0 Then
						DataImportFromExternalSources.ProcessSelectedAdditionalAttributes(CatalogItem, TableRow._RowMatched, TableRow, DataLoadSettings.SelectedAdditionalAttributes);
					EndIf;
					
					CatalogItem.DataExchange.Load = True;
					CatalogItem.Write();
				EndIf;
				
			ElsIf FillingObjectFullName = "Catalog.Cells" Then
				
				CoordinatedStringStatus = (TableRow._RowMatched AND UpdateExisting) 
				OR (NOT TableRow._RowMatched AND CreateIfNotMatched);
				
				If ImportToApplicationIsPossible AND CoordinatedStringStatus Then
					
					If TableRow._RowMatched Then
						CatalogItem 			= TableRow.Cells.GetObject();
					Else
						
						CatalogItem 			= Catalogs.Cells.CreateItem();
						CatalogItem.Parent 		= TableRow.Parent;
						
						If Not TrimAll(TableRow.Code) = "" Then
							CatalogItem.Code = TrimAll(TableRow.Code);
						Else 
							CatalogItem.SetNewCode();
						EndIf;
						
					EndIf;
					
					CatalogItem.Description 	= TableRow.CellsDescription;
					CatalogItem.Owner			= TableRow.Owner;
					
					CatalogItem.DataExchange.Load = True;
					CatalogItem.Write();
					
				EndIf;
				
			ElsIf FillingObjectFullName = "Catalog.SalesTaxRates" Then
				
				CoordinatedStringStatus = (TableRow._RowMatched AND UpdateExisting) 
				OR (NOT TableRow._RowMatched AND CreateIfNotMatched);
				
				If ImportToApplicationIsPossible AND CoordinatedStringStatus Then
					
					If TableRow._RowMatched Then
						CatalogItem 			= TableRow.SalesTaxRates.GetObject();
					Else
						CatalogItem 			= Catalogs.SalesTaxRates.CreateItem();
					EndIf;
					
					FillPropertyValues(CatalogItem, TableRow);
					
					CatalogItem.Write();
					
				EndIf;
				
			// begin Drive.FullVersion
			
			ElsIf FillingObjectFullName = "Catalog.CompanyResourceTypes" Then
				
				CoordinatedStringStatus = TableRow._RowMatched And UpdateExisting 
					Or Not TableRow._RowMatched And CreateIfNotMatched;
				
				If ImportToApplicationIsPossible And CoordinatedStringStatus Then
					
					If TableRow._RowMatched Then
						CatalogItem = TableRow.CompanyResourceType.GetObject();
					Else
						CatalogItem = Catalogs.CompanyResourceTypes.CreateItem();
					EndIf;
					
					FillPropertyValues(CatalogItem, TableRow);
					
					CatalogItem.Write();
					
				EndIf;
				
			ElsIf FillingObjectFullName = "Catalog.CompanyResources" Then
				
				CoordinatedStringStatus = TableRow._RowMatched And UpdateExisting 
					Or Not TableRow._RowMatched And CreateIfNotMatched;
				
				If ImportToApplicationIsPossible And CoordinatedStringStatus Then
					
					If TableRow._RowMatched Then
						CatalogItem = TableRow.CompanyResource.GetObject();
					Else
						CatalogItem = Catalogs.CompanyResources.CreateItem();
					EndIf;
					
					FillPropertyValues(CatalogItem, TableRow);
					
					CatalogItem.Write();
					
				EndIf;
				
			ElsIf FillingObjectFullName = "Catalog.ManufacturingActivities" Then
				
				CoordinatedStringStatus = TableRow._RowMatched And UpdateExisting 
					Or Not TableRow._RowMatched And CreateIfNotMatched;
				
				If ImportToApplicationIsPossible And CoordinatedStringStatus Then
					
					If TableRow._RowMatched Then
						CatalogItem = TableRow.Operation.GetObject();
					Else
						CatalogItem = Catalogs.ManufacturingActivities.CreateItem();
					EndIf;
					
					FillPropertyValues(CatalogItem, TableRow);
					
					If ValueIsFilled(TableRow.TimeUOM) Then
						UOMFactor = Common.ObjectAttributeValue(TableRow.TimeUOM, "Factor");
						CatalogItem.StandardTime = CatalogItem.StandardTimeInUOM * UOMFactor;
					EndIf;
					
					If ValueIsFilled(TableRow.WorkcenterType) Then
						CatalogItem.WorkCenterTypes.Clear();
						NewLine = CatalogItem.WorkCenterTypes.Add();
						NewLine.WorkcenterType = TableRow.WorkcenterType;
					EndIf;
					
					CatalogItem.Write();
					
				EndIf;
				
			ElsIf FillingObjectFullName = "Catalog.RoutingTemplates.TabularSection.Operations" Then
				
				If ImportToApplicationIsPossible Then
					
					TabularSectionName = "Operations";
					NewRow = Object[TabularSectionName].Add();
					FillPropertyValues(NewRow, TableRow, "Activity, ActivityNumber, NextActivityNumber", );
					
				EndIf;
				
			// end Drive.FullVersion
			
			ElsIf FillingObjectFullName = "Catalog.Products" Then
				
				CoordinatedStringStatus = (TableRow._RowMatched AND UpdateExisting) 
				OR (NOT TableRow._RowMatched AND CreateIfNotMatched);
				
				If ImportToApplicationIsPossible AND CoordinatedStringStatus Then
					
					If TableRow._RowMatched Then
						CatalogItem 			= TableRow.Products.GetObject();
					Else
						CatalogItem 			= Catalogs.Products.CreateItem();
						CatalogItem.Parent 		= TableRow.Parent;
					EndIf;
					
					CatalogItem.Description 	= TableRow.ProductsDescription;
					CatalogItem.DescriptionFull = ?(ValueIsFilled(TableRow.ProductsDescriptionFull),
					TableRow.ProductsDescriptionFull,
					TableRow.ProductsDescription);
					FillPropertyValues(CatalogItem, TableRow);
					
					If Not ValueIsFilled(CatalogItem.ReportUOM) Then
						CatalogItem.ReportUOM = CatalogItem.MeasurementUnit;
					EndIf;
					
					If DataLoadSettings.SelectedAdditionalAttributes.Count() > 0 Then
						DataImportFromExternalSources.ProcessSelectedAdditionalAttributes(CatalogItem, TableRow._RowMatched, TableRow, DataLoadSettings.SelectedAdditionalAttributes);
					EndIf;
					
					CatalogItem.Write(); 
					
					If TableRow.Property("SerialNumber")
						And ValueIsFilled(TableRow.SerialNumber_IncomingData) Then
						If ValueIsFilled(TableRow.SerialNumber) Then
							SerialNumbers 			= TableRow.SerialNumber.GetObject();
						Else
							SerialNumbers 			= Catalogs.SerialNumbers.CreateItem();
						EndIf;
						SerialNumbers.Owner  = CatalogItem.Ref;
						SerialNumbers.Description = TableRow.SerialNumber_IncomingData; 
						SerialNumbers.Write();
					EndIf;
				EndIf;
				
			ElsIf FillingObjectFullName = "InformationRegister.Prices" Then
				
				CoordinatedStringStatus = (TableRow._RowMatched AND UpdateExisting) 
				OR (NOT TableRow._RowMatched AND CreateIfNotMatched);
				
				If ImportToApplicationIsPossible AND CoordinatedStringStatus Then
					
					RecordManager 					= InformationRegisters.Prices.CreateRecordManager();
					RecordManager.PriceKind			= TableRow.PriceKind;
					RecordManager.MeasurementUnit	= TableRow.MeasurementUnit;
					RecordManager.Products			= TableRow.Products;
					RecordManager.Period			= TableRow.Date;
					RecordManager.Price				= TableRow.Price;
					RecordManager.Author			= Users.AuthorizedUser();
					
					If GetFunctionalOption("UseCharacteristics") Then
						RecordManager.Characteristic	= TableRow.Characteristic;
					EndIf;
					
					RecordManager.Write(True);
					
				EndIf;
				
			ElsIf FillingObjectFullName = "Document.OpeningBalanceEntry.TabularSection.AccountsReceivable" 
				OR FillingObjectFullName = "Document.OpeningBalanceEntry.TabularSection.AccountsPayable" Then
				
				If ImportToApplicationIsPossible Then
					
					If FillingObjectFullName = "Document.OpeningBalanceEntry.TabularSection.AccountsReceivable" Then
						TabularSectionName = "AccountsReceivable";
					Else 
						TabularSectionName = "AccountsPayable";
					EndIf;
					
					ForeignExchangeAccounting = GetFunctionalOption("ForeignExchangeAccounting");
					If Not ForeignExchangeAccounting Then
						PresentationCurrency = DriveServer.GetPresentationCurrency(DataLoadSettings.DocumentAttributes.Company);
					EndIf;
					UseContractsWithCounterparties = Constants.UseContractsWithCounterparties.Get();
					
					NewRow = Object[TabularSectionName].Add();
					
					If ForeignExchangeAccounting Then
						If Not ValueIsFilled(TableRow.Currency) Then
							CreateCurrency(TableRow, DataMatchingTable);
						EndIf;
					EndIf;
					
					CounterpartyIsNew = False;
					If Not ValueIsFilled(TableRow.Counterparty) Then
						
						Filter = New Structure;
						Filter.Insert("CounterpartyDescription", TableRow.CounterpartyDescription);
						TableRowsToBeUpdated = DataMatchingTable.FindRows(Filter);
						
						NewCounterparty = Catalogs.Counterparties.CreateItem();
						NewCounterparty.Description = TableRow.CounterpartyDescription;
						NewCounterparty.DescriptionFull = NewCounterparty.Description;
						NewCounterparty.TIN = TableRow.CounterpartyTIN;
						If UseContractsWithCounterparties Then
							If Not IsBlankString(TableRow.ContractDescription) Then
								NewCounterparty.DoOperationsByContracts = True;
							Else
								For Each TableRowToBeUpdated In TableRowsToBeUpdated Do
									If Not IsBlankString(TableRowToBeUpdated.ContractDescription) Then
										NewCounterparty.DoOperationsByContracts = True;
										Break;
									EndIf;
								EndDo;
							EndIf;
						EndIf;
						If Not IsBlankString(TableRow.OrderNumber) Then
							NewCounterparty.DoOperationsByOrders = True;
						Else
							For Each TableRowToBeUpdated In TableRowsToBeUpdated Do
								If Not IsBlankString(TableRowToBeUpdated.OrderNumber) Then
									NewCounterparty.DoOperationsByOrders = True;
									Break;
								EndIf;
							EndDo;
						EndIf;
						
						NewCounterparty.CreationDate = CurrentSessionDate();
						NewCounterparty.DefaultDeliveryOption = Enums.DeliveryOptions.Delivery;
						NewCounterparty.LegalEntityIndividual = Enums.CounterpartyType.LegalEntity;
						If TabularSectionName = "AccountsReceivable" Then
							NewCounterparty.Customer = True;
						Else
							NewCounterparty.Supplier = True;
						EndIf;
						NewCounterparty.PaymentMethod = Catalogs.PaymentMethods.Electronic;
						If UseContractsWithCounterparties Then
							If ForeignExchangeAccounting Then
								NewCounterparty.SettlementsCurrency = TableRow.Currency;
							Else
								NewCounterparty.SettlementsCurrency = PresentationCurrency;
							EndIf;
						EndIf;
						NewCounterparty.Write();
						CounterpartyIsNew = True;
						
						For Each TableRowToBeUpdated In TableRowsToBeUpdated Do
							TableRowToBeUpdated.Counterparty = NewCounterparty.Ref;
						EndDo;
						
					EndIf;
					
					If UseContractsWithCounterparties
						And ValueIsFilled(TableRow.Counterparty)
						And Not ValueIsFilled(TableRow.Contract)
						And Not IsBlankString(TableRow.ContractDescription) Then
						
						If Not CounterpartyIsNew
							And Not Common.ObjectAttributeValue(TableRow.Counterparty, "DoOperationsByContracts") Then
							CounterpartyObject = TableRow.Counterparty.GetObject();
							CounterpartyObject.DoOperationsByContracts = True;
							CounterpartyObject.Write();
						EndIf;
						
						NewContract = Catalogs.CounterpartyContracts.CreateItem();
						NewContract.Owner = TableRow.Counterparty;
						NewContract.Description = TableRow.ContractDescription;
						NewContract.ContractNo = TableRow.ContractNo;
						ConvertStringToDate(NewContract.ContractDate, TableRow.ContractDate);
						If ForeignExchangeAccounting Then
							NewContract.SettlementsCurrency = TableRow.Currency;
						Else
							NewContract.SettlementsCurrency = PresentationCurrency;
						EndIf;
						
						NewContract.Company = Object.Company;
						If TabularSectionName = "AccountsReceivable" Then
							NewContract.ContractKind = Enums.ContractType.WithCustomer;
						Else
							NewContract.ContractKind = Enums.ContractType.WithVendor;
						EndIf;
						NewContract.PaymentMethod = Catalogs.PaymentMethods.Electronic;
						NewContract.Status = Enums.CounterpartyContractStatuses.Active;
						NewContract.Write();
						
						Filter = New Structure;
						Filter.Insert("Counterparty", TableRow.Counterparty);
						Filter.Insert("ContractDescription", TableRow.ContractDescription);
						TableRowsToBeUpdated = DataMatchingTable.FindRows(Filter);
						For Each TableRowToBeUpdated In TableRowsToBeUpdated Do
							TableRowToBeUpdated.Contract = NewContract.Ref;
						EndDo;
						
					EndIf;
					
					FieldsToBeFilled = "Counterparty, AdvanceFlag, AmountCur, Document, DocumentNumber";
					If UseContractsWithCounterparties Then
						FieldsToBeFilled = FieldsToBeFilled + ", Contract";
					EndIf;
					FillPropertyValues(NewRow, TableRow, FieldsToBeFilled);
					
					StructureData = GetDataCounterparty(Object, NewRow.Counterparty, TabularSectionName, CurrentForm);
					If UseContractsWithCounterparties And Not ValueIsFilled(NewRow.Contract) Then
						NewRow.Contract = StructureData.Contract;
					EndIf;
					NewRow.DoOperationsByContracts = StructureData.DoOperationsByContracts;
					NewRow.DoOperationsByOrders = StructureData.DoOperationsByOrders;
					
					If ForeignExchangeAccounting Then
						NewRow.Amount = TableRow.Amount;
					Else
						NewRow.Amount = NewRow.AmountCur;
					EndIf;
					
					If Not NewRow.Document = Undefined Then
						NewRow.DocumentType = Metadata.FindByType(TypeOf(NewRow.Document)).Name;
					EndIf;
					ConvertStringToDate(NewRow.DocumentDate, TableRow.DocumentDate);
					
					If NewRow.DoOperationsByOrders Then
						If TabularSectionName = "AccountsReceivable" Then
							NewRow.SalesOrder = TableRow.Order;
						Else
							NewRow.PurchaseOrder = TableRow.Order;
						EndIf;
					EndIf;
					
				EndIf;
				
			ElsIf FillingObjectFullName = "Document.OpeningBalanceEntry.TabularSection.CashAssets" Then
				
				If ImportToApplicationIsPossible Then
					
					TabularSectionName = Metadata.FindByFullName(FillingObjectFullName).Name;
					NewRow = Object[TabularSectionName].Add();
					
					ForeignExchangeAccounting = GetFunctionalOption("ForeignExchangeAccounting");
					If Not ForeignExchangeAccounting Then
						PresentationCurrency = DriveServer.GetPresentationCurrency(DataLoadSettings.DocumentAttributes.Company);
					EndIf;
					
					If DataLoadSettings.AccountType = "BankAccount" Then
						
						If Not TableRow._RowMatched Then
							
							If Not ValueIsFilled(TableRow.Bank) Then
								
								NewBank = Catalogs.Banks.CreateItem();
								NewBank.Description = TableRow.BankDescription;
								NewBank.Code = TableRow.BankCode;
								NewBank.Write();
								
								Filter = New Structure;
								Filter.Insert("BankCode", TableRow.BankCode);
								Filter.Insert("BankDescription", TableRow.BankDescription);
								TableRowsToBeUpdated = DataMatchingTable.FindRows(Filter);
								For Each TableRowToBeUpdated In TableRowsToBeUpdated Do
									TableRowToBeUpdated.Bank = NewBank.Ref;
								EndDo;
								
							EndIf;
							
							If ForeignExchangeAccounting Then
								If Not ValueIsFilled(TableRow.Currency) Then
									CreateCurrency(TableRow, DataMatchingTable);
								EndIf;
							EndIf;
							
							NewAccount = Catalogs.BankAccounts.CreateItem();
							NewAccount.Owner = DataLoadSettings.DocumentAttributes.Company;
							NewAccount.AccountType = "Transactional";
							NewAccount.GLAccount = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("BankAccount");
							NewAccount.AccountNo = TableRow.AccountNo;
							NewAccount.IBAN = TableRow.IBAN;
							If ForeignExchangeAccounting Then
								NewAccount.CashCurrency = TableRow.Currency;
							Else
								NewAccount.CashCurrency = PresentationCurrency;
							EndIf;
							NewAccount.Bank = TableRow.Bank;
							If IsBlankString(TableRow.Description) Then
								NewAccount.Description = StringFunctionsClientServer.SubstituteParametersToString(
									"%1 (%2)",
									NewAccount.Bank,
									NewAccount.CashCurrency);
							Else
								NewAccount.Description = TableRow.Description;
							EndIf;
							NewAccount.Write();
							
							Filter = New Structure;
							Filter.Insert("Bank", TableRow.Bank);
							If ForeignExchangeAccounting Then
								Filter.Insert("Currency", TableRow.Currency);
							EndIf;
							If Not IsBlankString(TableRow.IBAN) Then
								Filter.Insert("IBAN", TableRow.IBAN);
							Else
								Filter.Insert("AccountNo", TableRow.AccountNo);
							EndIf;
							TableRowsToBeUpdated = DataMatchingTable.FindRows(Filter);
							For Each TableRowToBeUpdated In TableRowsToBeUpdated Do
								TableRowToBeUpdated.Account = NewAccount.Ref;
								TableRowToBeUpdated._RowMatched = True;
							EndDo;
							
						EndIf;
						
					ElsIf DataLoadSettings.AccountType = "CashAccount" Then
						
						If Not TableRow._RowMatched Then
							
							If ForeignExchangeAccounting Then
								If Not ValueIsFilled(TableRow.Currency) Then
									CreateCurrency(TableRow, DataMatchingTable);
								EndIf;
							EndIf;
							
							NewAccount = Catalogs.CashAccounts.CreateItem();
							NewAccount.Description = TableRow.Description;
							NewAccount.GLAccount = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("PettyCashAccount");
							If ForeignExchangeAccounting Then
								NewAccount.CurrencyByDefault = TableRow.Currency;
							Else
								NewAccount.CurrencyByDefault = PresentationCurrency;
							EndIf;
							NewAccount.Write();
							
							Filter = New Structure;
							Filter.Insert("Description", TableRow.Description);
							Filter.Insert("Currency", TableRow.Currency);
							TableRowsToBeUpdated = DataMatchingTable.FindRows(Filter);
							For Each TableRowToBeUpdated In TableRowsToBeUpdated Do
								TableRowToBeUpdated.Account = NewAccount.Ref;
								TableRowToBeUpdated._RowMatched = True;
							EndDo;
							
						EndIf;
						
					EndIf;
					
					NewRow.BankAccountPettyCash = TableRow.Account;
					NewRow.AmountCur = TableRow.AmountCur;
					If ForeignExchangeAccounting Then
						NewRow.CashCurrency = TableRow.Currency;
						NewRow.Amount = TableRow.Amount;
					Else
						NewRow.CashCurrency = PresentationCurrency;
						NewRow.Amount = TableRow.AmountCur;
					EndIf;
					
				EndIf;
				
			ElsIf FillingObjectFullName = "Document.RequestForQuotation.TabularSection.Suppliers" Then
				
				If ImportToApplicationIsPossible Then
					
					TabularSectionName = Metadata.FindByFullName(FillingObjectFullName).Name;
					NewRow = Object[TabularSectionName].Add();
					
					FillPropertyValues(NewRow, TableRow, "Counterparty, ContactPerson, Email");
					
					If NOT ValueIsFilled(NewRow.ContactPerson) Then
						NewRow.ContactPerson = Catalogs.ContactPersons.GetDefaultContactPerson(NewRow.Counterparty);
					EndIf;
					
					If NOT ValueIsFilled(NewRow.Email) Then
						
						If ValueIsFilled(NewRow.ContactPerson) Then
							NewRow.Email = DriveServer.GetContactInformation(NewRow.ContactPerson, Catalogs.ContactInformationKinds.ContactPersonEmail);
						Else
							NewRow.Email = DriveServer.GetContactInformation(NewRow.Counterparty, Catalogs.ContactInformationKinds.CounterpartyEmail);
						EndIf;
						
					EndIf;
					
				EndIf;
				
			ElsIf FillingObjectFullName = "ChartOfAccounts.PrimaryChartOfAccounts" Then 
				
				CoordinatedRowStatus = (TableRow._RowMatched AND UpdateExisting)
					OR (NOT TableRow._RowMatched AND CreateIfNotMatched);
				
				If ImportToApplicationIsPossible AND CoordinatedRowStatus Then
					
					If TableRow._RowMatched Then
						ChartOfAccountsItem = TableRow.Account.GetObject();
					Else
						ChartOfAccountsItem = ChartsOfAccounts.PrimaryChartOfAccounts.CreateAccount();
						
						If Not ValueIsFilled(TableRow.Parent) Then
							
							If Not IsBlankString(TableRow.Parent_IncomingData) Then
								
								FoundParent = ChartsOfAccounts.PrimaryChartOfAccounts.FindByCode(TableRow.Parent_IncomingData);
								If Not ValueIsFilled(FoundParent) Then
									FoundParent = ChartsOfAccounts.PrimaryChartOfAccounts.FindByDescription(TableRow.Parent_IncomingData, True);
								EndIf;
								
								If ValueIsFilled(FoundParent) Then
									TableRow.Parent = FoundParent
								EndIf;
								
							EndIf;
							
						EndIf;
						
						ChartOfAccountsItem.Parent = TableRow.Parent;
						
					EndIf;
					
					ChartOfAccountsItem.Description = TableRow.Description;
					FillPropertyValues(ChartOfAccountsItem, TableRow, , "Parent");
					
					ChartOfAccountsItem.DataExchange.Load = True;
					ChartOfAccountsItem.Write();
					
				EndIf;
				
			ElsIf FillingObjectFullName = "ChartOfAccounts.FinancialChartOfAccounts" Then 
				
				CoordinatedRowStatus = (TableRow._RowMatched AND UpdateExisting)
					OR (NOT TableRow._RowMatched AND CreateIfNotMatched);
				
				If ImportToApplicationIsPossible AND CoordinatedRowStatus Then
					
					If TableRow._RowMatched Then
						ChartOfAccountsItem = TableRow.Account.GetObject();
					Else
						ChartOfAccountsItem = ChartsOfAccounts.FinancialChartOfAccounts.CreateAccount();
						ChartOfAccountsItem.Parent = TableRow.Parent;
					EndIf;
					
					ChartOfAccountsItem.Description = TableRow.Description;
					FillPropertyValues(ChartOfAccountsItem, TableRow, , "Parent");
					
					ChartOfAccountsItem.DataExchange.Load = True;
					ChartOfAccountsItem.Write();
					
				EndIf;
				
			ElsIf FillingObjectFullName = "ChartOfAccounts.MasterChartOfAccounts" Then 
				
				CoordinatedRowStatus = (TableRow._RowMatched And UpdateExisting)
					Or (Not TableRow._RowMatched And CreateIfNotMatched);
				
				If ImportToApplicationIsPossible And CoordinatedRowStatus Then
					
					If TableRow._RowMatched Then
						ChartOfAccountsItem = TableRow.Account.GetObject();
					Else
						ChartOfAccountsItem = ChartsOfAccounts.MasterChartOfAccounts.CreateAccount();
						
						If Not ValueIsFilled(TableRow.Parent) Then
							
							If Not IsBlankString(TableRow.Parent_IncomingData) Then
								
								FoundParent = ChartsOfAccounts.MasterChartOfAccounts.FindByCode(TableRow.Parent_IncomingData);
								If Not ValueIsFilled(FoundParent) Then
									FoundParent = ChartsOfAccounts.MasterChartOfAccounts.FindByDescription(TableRow.Parent_IncomingData, True);
								EndIf;
								
								If ValueIsFilled(FoundParent) Then
									TableRow.Parent = FoundParent;
								EndIf;
								
							EndIf;
							
						EndIf;
						
						ChartOfAccountsItem.Parent = TableRow.Parent;
						
					EndIf;
					
					ChartOfAccountsItem.Description = TableRow.Description;
					FillPropertyValues(ChartOfAccountsItem, TableRow, , "Parent");
					
					ChartOfAccountsItem.AnalyticalDimensions.Clear();
					
					If ValueIsFilled(ChartOfAccountsItem.AnalyticalDimensionsSet) Then
						
						AnalyticalDimensionsSet = ChartOfAccountsItem.AnalyticalDimensionsSet;
						ChartOfAccountsItem.AnalyticalDimensions.Load(AnalyticalDimensionsSet.AnalyticalDimensions.Unload());
						
					EndIf;
					
					ChartOfAccountsItem.Quantity = ChartOfAccountsItem.UseQuantity;
					
					ChartsOfAccounts.MasterChartOfAccounts.FillExtDimensionTypesByAnalyticalDimensions(
						ChartOfAccountsItem.AnalyticalDimensions,
						ChartOfAccountsItem.ExtDimensionTypes,
						ChartOfAccountsItem.UseQuantity,
						ChartOfAccountsItem.Currency);
					
					ChartOfAccountsItem.DataExchange.Load = True;
					ChartOfAccountsItem.Write();
					
				EndIf;
				
			ElsIf FillingObjectFullName = "AccountingRegister.AccountingJournalEntriesCompound" Then
				
				AccountingEntriesSettings = DataLoadSettings.AccountingEntriesSettings;
				IsCompound = (AccountingEntriesSettings.TypeOfEntries = Enums.ChartsOfAccountsTypesOfEntries.Compound);
				RecordSet = Object;
				
				If ImportToApplicationIsPossible Then
					
					NewRow = RecordSet.Add();
					FillPropertyValues(NewRow, TableRow);
					NewRow.Active = True;
					NewRow.PlanningPeriod = Catalogs.PlanningPeriods.Actual;
					NewRow.Company = AccountingEntriesSettings.Company;
					NewRow.Status = Enums.AccountingEntriesStatus.NotApproved;
					NewRow.TypeOfAccounting = AccountingEntriesSettings.TypeOfAccounting;
					
					If Not ValueIsFilled(NewRow.Period) Then
						NewRow.Period = AccountingEntriesSettings.Date;
					EndIf;
					
					If IsCompound Then
						
						NewRow.EntryNumber = AccountingEntriesSettings.MaxEntryNumber;
						
						NewRow.RecordType = ?(TableRow.RecordType = Enums.AccountingRecordType.Debit, 
							AccountingRecordType.Debit, AccountingRecordType.Credit);
						
					EndIf;
					
					MasterAccounting.FillMiscFields(CommonClientServer.ValueInArray(NewRow));
					
				EndIf;
				
			ElsIf FillingObjectFullName = "Catalog.ProductsBatches" Then
				
				CoordinatedStringStatus = TableRow._RowMatched And UpdateExisting 
					Or Not TableRow._RowMatched And CreateIfNotMatched;
				
				If ImportToApplicationIsPossible And CoordinatedStringStatus Then
					
					If TableRow._RowMatched Then
						CatalogItem = TableRow.Batch.GetObject();
					Else
						CatalogItem = Catalogs.ProductsBatches.CreateItem();
					EndIf;
					
					FillPropertyValues(CatalogItem, TableRow);
					
					If DataLoadSettings.SelectedAdditionalAttributes.Count() > 0 Then
						DataImportFromExternalSources.ProcessSelectedAdditionalAttributes(CatalogItem, TableRow._RowMatched, TableRow, DataLoadSettings.SelectedAdditionalAttributes);
					EndIf;
				
					CatalogItem.Write();
					
				EndIf;	
				
			Else 
				
				If ImportToApplicationIsPossible Then
					
					TabularSectionName = Metadata.FindByFullName(FillingObjectFullName).Name;
					NewRow = Object[TabularSectionName].Add();
					
					PropertyNames = New Array;
					
					If FillingObjectFullName = "Document.ActualSalesVolume.TabularSection.Inventory"
						And DataLoadSettings.CounterpartyAndContractPositionInTabularSection Then
						
						PresentationCurrency = DriveServer.GetPresentationCurrency(Object.Company);
						
						CounterpartyIsNew = False;
						If Not ValueIsFilled(TableRow.Counterparty) Then
							
							NewCounterparty = Catalogs.Counterparties.CreateItem();
							NewCounterparty.Description = TableRow.CounterpartyDescription;
							NewCounterparty.DescriptionFull = NewCounterparty.Description;
							NewCounterparty.TIN = TableRow.CounterpartyTIN;
							
							NewCounterparty.DoOperationsByContracts = True;
							
							NewCounterparty.CreationDate = CurrentSessionDate();
							NewCounterparty.DefaultDeliveryOption = Enums.DeliveryOptions.Delivery;
							NewCounterparty.LegalEntityIndividual = Enums.CounterpartyType.LegalEntity;
							NewCounterparty.Customer = True;
							NewCounterparty.PaymentMethod = Catalogs.PaymentMethods.Electronic;
							
							NewCounterparty.SettlementsCurrency = PresentationCurrency;
							
							NewCounterparty.Write();
							CounterpartyIsNew = True;
							
							Filter = New Structure;
							Filter.Insert("CounterpartyDescription", TableRow.CounterpartyDescription);
							TableRowsToBeUpdated = DataMatchingTable.FindRows(Filter);
							For Each TableRowToBeUpdated In TableRowsToBeUpdated Do
								TableRowToBeUpdated.Counterparty = NewCounterparty.Ref;
							EndDo;
							
						EndIf;
						
						If ValueIsFilled(TableRow.Counterparty)
							And Not ValueIsFilled(TableRow.Contract)
							And Not IsBlankString(TableRow.ContractDescription) Then
							
							NewContract = Catalogs.CounterpartyContracts.CreateItem();
							NewContract.Owner = TableRow.Counterparty;
							NewContract.Description = TableRow.ContractDescription;
							NewContract.ContractNo = TableRow.ContractNo;
							ConvertStringToDate(NewContract.ContractDate, TableRow.ContractDate);
							NewContract.SettlementsCurrency = PresentationCurrency;
							NewContract.Company = Object.Company;
							NewContract.ContractKind = Enums.ContractType.WithCustomer;
							NewContract.PaymentMethod = Catalogs.PaymentMethods.Electronic;
							NewContract.Status = Enums.CounterpartyContractStatuses.Active;
							NewContract.Write();
							
							Filter = New Structure;
							Filter.Insert("Counterparty", TableRow.Counterparty);
							Filter.Insert("ContractDescription", TableRow.ContractDescription);
							TableRowsToBeUpdated = DataMatchingTable.FindRows(Filter);
							For Each TableRowToBeUpdated In TableRowsToBeUpdated Do
								TableRowToBeUpdated.Contract = NewContract.Ref;
							EndDo;
							
						EndIf;
						
						PropertyNames.Add("Counterparty");
						PropertyNames.Add("Contract");
						
					EndIf;
					
					If NewRow.Property("StructuralUnit") And TableRow.Property("StructuralUnit") Then
						If GetFunctionalOption("UseSeveralWarehouses") Then
							If Not ValueIsFilled(TableRow.StructuralUnit)
								And DataLoadSettings.CreateIfNotMatched
								And Not IsBlankString(TableRow.StructuralUnitDescription) Then
								NewObject = Catalogs.BusinessUnits.CreateItem();
								NewObject.Description = TableRow.StructuralUnitDescription;
								NewObject.StructuralUnitType = Enums.BusinessUnitsTypes.Warehouse;
								NewObject.Company = Catalogs.Companies.MainCompany;
								NewObject.Write();
								Filter = New Structure;
								Filter.Insert("StructuralUnitDescription", TableRow.StructuralUnitDescription);
								TableRowsToBeUpdated = DataMatchingTable.FindRows(Filter);
								For Each TableRowToBeUpdated In TableRowsToBeUpdated Do
									If Not ValueIsFilled(TableRowToBeUpdated.StructuralUnit) Then
										TableRowToBeUpdated.StructuralUnit = NewObject.Ref;
									EndIf;
								EndDo;
							EndIf;
							PropertyNames.Add("StructuralUnit");
						Else
							NewRow.StructuralUnit = Catalogs.BusinessUnits.MainWarehouse;
						EndIf;
					EndIf;
					
					If NewRow.Property("Document")
						And TableRow.Property("Document") Then
						
						PropertyNames.Add("Document");
					EndIf;
					
					If NewRow.Property("DocumentNumber")
						And TableRow.Property("DocumentNumber") Then
						
						PropertyNames.Add("DocumentNumber");
					EndIf;
					
					If NewRow.Property("DocumentDate")
						And TableRow.Property("DocumentDate") Then
						
						ConvertStringToDate(NewRow.DocumentDate, TableRow.DocumentDate);
						
						If Not ValueIsFilled(NewRow.DocumentDate) Then
							NewRow.DocumentDate = Common.CurrentUserDate();
						EndIf;
						
					EndIf;
					
					If NewRow.Property("DocumentType")
						And TableRow.Property("DocumentType") Then
						
						PropertyNames.Add("DocumentType");
					EndIf;
					
					If NewRow.Property("Cell")
						And TableRow.Property("Cell")
						And GetFunctionalOption("UseStorageBins") Then
						If Not ValueIsFilled(TableRow.Cell)
							And DataLoadSettings.CreateIfNotMatched
							And Not IsBlankString(TableRow.CellDescription) Then
							NewObject = Catalogs.Cells.CreateItem();
							NewObject.Description = TableRow.CellDescription;
							If TableRow.Property("StructuralUnit") Then
								NewObject.Owner = TableRow.StructuralUnit;
							Else
								NewObject.Owner = Catalogs.BusinessUnits.MainWarehouse;
							EndIf;
							NewObject.Write();
							Filter = New Structure;
							Filter.Insert("CellDescription", TableRow.CellDescription);
							If NewRow.Property("StructuralUnit")
								And GetFunctionalOption("UseSeveralWarehouses") Then
								Filter.Insert("StructuralUnit", TableRow.StructuralUnit);
							EndIf;
							TableRowsToBeUpdated = DataMatchingTable.FindRows(Filter);
							For Each TableRowToBeUpdated In TableRowsToBeUpdated Do
								If Not ValueIsFilled(TableRowToBeUpdated.Cell) Then
									TableRowToBeUpdated.Cell = NewObject.Ref;
								EndIf;
							EndDo;
						EndIf;
						PropertyNames.Add("Cell");
					EndIf;
					
					If NewRow.Property("MeasurementUnit") And TableRow.Property("MeasurementUnit") Then
						If Not ValueIsFilled(TableRow.MeasurementUnit)
							And DataLoadSettings.CreateIfNotMatched
							And Not IsBlankString(TableRow.MeasurementUnitDescription) Then
							NewObject = Catalogs.UOMClassifier.CreateItem();
							NewObject.Description = TableRow.MeasurementUnitDescription;
							NewObject.Write();
							Filter = New Structure;
							Filter.Insert("MeasurementUnitDescription", TableRow.MeasurementUnitDescription);
							TableRowsToBeUpdated = DataMatchingTable.FindRows(Filter);
							For Each TableRowToBeUpdated In TableRowsToBeUpdated Do
								If Not ValueIsFilled(TableRowToBeUpdated.MeasurementUnit) Then
									TableRowToBeUpdated.MeasurementUnit = NewObject.Ref;
								EndIf;
							EndDo;
						EndIf;
						PropertyNames.Add("MeasurementUnit");
					EndIf;
					
					UseCharacteristics = NewRow.Property("Characteristic") And GetFunctionalOption("UseCharacteristics");
					UseBatches = NewRow.Property("Batch") And GetFunctionalOption("UseBatches");
					
					ProductIsNew = False;
					If NewRow.Property("Products") And TableRow.Property("Products") Then
						If Not ValueIsFilled(TableRow.Products)
							And DataLoadSettings.CreateIfNotMatched
							And Not IsBlankString(TableRow.ProductsDescription)
							And ValueIsFilled(TableRow.MeasurementUnit) Then
							NewObject = Catalogs.Products.CreateItem();
							NewObject.Description = TableRow.ProductsDescription;
							NewObject.DescriptionFull = ?(ValueIsFilled(TableRow.ProductsDescriptionFull),
								TableRow.ProductsDescriptionFull,
								TableRow.ProductsDescription);
							NewObject.AccountingMethod = Enums.InventoryValuationMethods.WeightedAverage;
							NewObject.BusinessLine = Catalogs.LinesOfBusiness.MainLine;
							NewObject.MeasurementUnit = TableRow.MeasurementUnit;
							NewObject.ProductsCategory = Catalogs.ProductsCategories.MainGroup;
							If FillingObjectFullName = "Document.SupplierInvoice.TabularSection.Expenses" Then
								NewObject.ProductsType = Enums.ProductsTypes.Service;
							Else
								NewObject.ProductsType = Enums.ProductsTypes.InventoryItem;
							EndIf;
							NewObject.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Purchase;
							NewObject.ReportUOM = NewObject.MeasurementUnit;
							NewObject.SKU = TableRow.SKU;
							Filter = New Structure("ProductsDescription, ProductsDescriptionFull, SKU");
							FillPropertyValues(Filter, TableRow);
							CurrentProductRows = DataMatchingTable.FindRows(Filter);
							If UseCharacteristics Or UseBatches Then
								For Each CurrentProductRow In CurrentProductRows Do
									If UseCharacteristics And Not IsBlankString(CurrentProductRow.CharacteristicDescription) Then
										NewObject.UseCharacteristics = True;
									EndIf;
									If UseBatches And Not IsBlankString(CurrentProductRow.BatchDescription) Then
										NewObject.UseBatches = True;
									EndIf;
								EndDo;
							EndIf;
							NewObject.VATRate = DefaultVATRate;
							NewObject.Write();
							For Each CurrentProductRow In CurrentProductRows Do
								If Not ValueIsFilled(CurrentProductRow.Products) Then
									CurrentProductRow.Products = NewObject.Ref;
								EndIf;
							EndDo;
							ProductIsNew = True;
						EndIf;
						PropertyNames.Add("Products");
					EndIf;
					
					CharacteristicIsNew = False;
					If UseCharacteristics And TableRow.Property("Characteristic") Then
						If Not ValueIsFilled(TableRow.Characteristic)
							And DataLoadSettings.CreateIfNotMatched
							And Not IsBlankString(TableRow.CharacteristicDescription)
							And ValueIsFilled(TableRow.Products) Then
							NewObject = Catalogs.ProductsCharacteristics.CreateItem();
							NewObject.Owner = TableRow.Products;
							NewObject.Description = TableRow.CharacteristicDescription;
							NewObject.Write();
							Filter = New Structure;
							Filter.Insert("CharacteristicDescription", TableRow.CharacteristicDescription);
							Filter.Insert("Products", TableRow.Products);
							TableRowsToBeUpdated = DataMatchingTable.FindRows(Filter);
							For Each TableRowToBeUpdated In TableRowsToBeUpdated Do
								If Not ValueIsFilled(TableRowToBeUpdated.Characteristic) Then
									TableRowToBeUpdated.Characteristic = NewObject.Ref;
								EndIf;
							EndDo;
							CharacteristicIsNew = True;
							If Not ProductIsNew
								And Not Common.ObjectAttributeValue(TableRow.Products, "UseCharacteristics") Then
								ProductObject = TableRow.Products.GetObject();
								ProductObject.UseCharacteristics = True;
								ProductObject.Write();
							EndIf;
						EndIf;
						PropertyNames.Add("Characteristic");
					EndIf;
					
					BatchIsNew = False;
					If UseBatches And TableRow.Property("Batch") Then
						If Not ValueIsFilled(TableRow.Batch)
							And DataLoadSettings.CreateIfNotMatched
							And Not IsBlankString(TableRow.BatchDescription)
							And ValueIsFilled(TableRow.Products) Then
							NewObject = Catalogs.ProductsBatches.CreateItem();
							NewObject.Owner = TableRow.Products;
							NewObject.Description = TableRow.BatchDescription;
							NewObject.Write();
							Filter = New Structure;
							Filter.Insert("BatchDescription", TableRow.BatchDescription);
							Filter.Insert("Products", TableRow.Products);
							TableRowsToBeUpdated = DataMatchingTable.FindRows(Filter);
							For Each TableRowToBeUpdated In TableRowsToBeUpdated Do
								If Not ValueIsFilled(TableRowToBeUpdated.Batch) Then
									TableRowToBeUpdated.Batch = NewObject.Ref;
								EndIf;
							EndDo;
							BatchIsNew = True;
							If Not ProductIsNew
								And Not Common.ObjectAttributeValue(TableRow.Products, "UseBatches") Then
								ProductObject = TableRow.Products.GetObject();
								ProductObject.UseBatches = True;
								ProductObject.Write();
							EndIf;
						EndIf;
						PropertyNames.Add("Batch");
					EndIf;
					
					If ProductIsNew Or CharacteristicIsNew Or BatchIsNew Then
						Barcodes = New Array;
						Filter = New Structure;
						Filter.Insert("Products", TableRow.Products);
						If UseCharacteristics Then
							Filter.Insert("Characteristic", TableRow.Characteristic);
						EndIf;
						If UseBatches Then
							Filter.Insert("Batch", TableRow.Batch);
						EndIf;
						TableRowsToBeUpdated = DataMatchingTable.FindRows(Filter);
						For Each TableRowToBeUpdated In TableRowsToBeUpdated Do
							If Not IsBlankString(TableRowToBeUpdated.Barcode)
								And Barcodes.Find(TableRowToBeUpdated.Barcode) = Undefined Then
								BarcodeRecordSet = InformationRegisters.Barcodes.CreateRecordSet();
								BarcodeRecordSet.Filter.Barcode.Set(TableRowToBeUpdated.Barcode);
								BarcodeEntry = BarcodeRecordSet.Add();
								FillPropertyValues(BarcodeEntry, TableRowToBeUpdated);
								BarcodeRecordSet.Write();
								Barcodes.Add(TableRowToBeUpdated.Barcode);
							EndIf;
						EndDo;
					EndIf;
					
					If NewRow.Property("Quantity") And TableRow.Property("Quantity") Then
						PropertyNames.Add("Quantity");
					EndIf;
					
					If NewRow.Property("Reserve")
						And TableRow.Property("Reserve")
						And GetFunctionalOption("UseInventoryReservation")
						And Not FillingObjectFullName = "Document.OpeningBalanceEntry.TabularSection.Inventory" Then
						
						PropertyNames.Add("Reserve");
					EndIf;
					
					If NewRow.Property("VATRate") And TableRow.Property("VATRate") Then
						PropertyNames.Add("VATRate");
					EndIf;
					
					If NewRow.Property("Order") And TableRow.Property("Order") Then
						PropertyNames.Add("Order");
					EndIf;
					
					If NewRow.Property("Specification") And TableRow.Property("Specification") Then
						If GetFunctionalOption("UseWorkOrders")
							// begin Drive.FullVersion
							Or GetFunctionalOption("UseProductionSubsystem")
							// end Drive.FullVersion
							Then
						
								PropertyNames.Add("Specification");

						EndIf;
					EndIf;
					
					If NewRow.Property("Order") And TableRow.Property("Order") Then
						PropertyNames.Add("Order");
					EndIf;
					
					If NewRow.Property("ReceiptDate") And TableRow.Property("ReceiptDate") Then
						PropertyNames.Add("ReceiptDate");
					EndIf;
					
					If NewRow.Property("ShipmentDate") And TableRow.Property("ShipmentDate") Then
						PropertyNames.Add("ShipmentDate");
					EndIf;
					
					If NewRow.Property("ContentRowType") And TableRow.Property("ContentRowType") Then
						PropertyNames.Add("ContentRowType");
					EndIf;
					
					If NewRow.Property("CostPercentage") And TableRow.Property("CostPercentage") Then
						PropertyNames.Add("CostPercentage");
					EndIf;
					
					FillPropertyValues(NewRow, TableRow, StringFunctionsClientServer.StringFromSubstringArray(PropertyNames));
					
					If NewRow.Property("ProductsTypeInventory") Then
						ProductsType = Common.ObjectAttributesValues(NewRow.Products, "ProductsType");
						NewRow.ProductsTypeInventory = (ProductsType = Enums.ProductsTypes.InventoryItem);
					EndIf;
					
					If NewRow.Property("Price") Then
						NewRow.Price = TableRow.Price;
					EndIf;
					
					ForceVATAmountCalculation = False;
					
					If NewRow.Property("Amount")
						And NewRow.Property("Price")
						And NewRow.Property("Quantity")
						And NewRow.Amount = 0 Then
						
						NewRow.Amount = TableRow.Price * TableRow.Quantity;
						ForceVATAmountCalculation = True;
						
					EndIf;
					
					If NewRow.Property("VATRate") And Not ValueIsFilled(NewRow.VATRate) Then
						
						If Object.Property("VATTaxation") And Object.VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then
							VATRate = Catalogs.VATRates.Exempt;
						ElsIf Object.Property("VATTaxation")
							And (Object.VATTaxation = Enums.VATTaxationTypes.ForExport
								Or Object.VATTaxation = Enums.VATTaxationTypes.ReverseChargeVAT) Then
							VATRate = Catalogs.VATRates.ZeroRate;
						Else
							VATRate = Common.ObjectAttributeValue(NewRow.Products, "VATRate");
						EndIf;
						
						If Not ValueIsFilled(VATRate) Then
							VATRate = DefaultVATRate;
						EndIf;
						
						NewRow.VATRate = VATRate;
						ForceVATAmountCalculation = True;
						
					EndIf;
					
					If Object.Property("AmountIncludesVAT") Then
						AmountIncludesVAT = Object.AmountIncludesVAT;
					Else
						AmountIncludesVAT = False;
					EndIf;
					
					If NewRow.Property("VATAmount")
						And NewRow.Property("VATRate")
						And NewRow.Property("Amount")
						And (NewRow.VATAmount = 0
								And ValueIsFilled(NewRow.VATRate)
								And NewRow.VATRate <> Catalogs.VATRates.Exempt
								And NewRow.VATRate <> Catalogs.VATRates.ZeroRate
							Or ForceVATAmountCalculation) Then
							
						VATRateValue = DriveReUse.GetVATRateValue(NewRow.VATRate);
						
						If AmountIncludesVAT Then
							NewRow.VATAmount = NewRow.Amount - (NewRow.Amount) / ((VATRateValue + 100) / 100);
						Else
							NewRow.VATAmount = NewRow.Amount * VATRateValue / 100;
						EndIf;
						
					EndIf;
					
					If NewRow.Property("Total")
						And NewRow.Property("Amount")
						And NewRow.Property("VATAmount") Then
						
						NewRow.Total = NewRow.Amount + ?(AmountIncludesVAT, 0, NewRow.VATAmount);
					EndIf;
					
					If NewRow.Property("SerialNumbers")
						And TableRow.Property("SerialNumber")
						And ValueIsFilled(TableRow.SerialNumber)
						And Object.Property("SerialNumbers")
						And NewRow.Property("ConnectionKey") Then
						
						WorkWithSerialNumbersClientServer.FillConnectionKey(Object[TabularSectionName], NewRow, "ConnectionKey");
						
						NewRow.SerialNumbers = TableRow.SerialNumber_IncomingData;
						
						SNNewRow = Object.SerialNumbers.Add();
						SNNewRow.ConnectionKey = NewRow.ConnectionKey;
						SNNewRow.SerialNumber = TableRow.SerialNumber;
						
					EndIf;
					
					If Not FillingObjectFullName = "Document.ActualSalesVolume.TabularSection.Inventory"
						And Not FillingObjectFullName = "Document.Pricing.TabularSection.Inventory"
						And Not FillingObjectFullName = "Document.Quote.TabularSection.Inventory"
						And Not FillingObjectFullName = "Document.Production.TabularSection.Products"
						And Not FillingObjectFullName = "Document.KitOrder.TabularSection.Products"
						And Not FillingObjectFullName = "Document.RequestForQuotation.TabularSection.Products"
						And Not FillingObjectFullName = "Document.Stocktaking.TabularSection.Inventory"
						And Not FillingObjectFullName = "Document.SupplierQuote.TabularSection.Inventory" Then
						
						IncomeAndExpenseItemsInDocuments.FillIncomeAndExpenseItemsInRow(ObjectParameters, NewRow, TabularSectionName);
						
						If UseDefaultTypeOfAccounting Then
							GLAccountsInDocuments.FillGLAccountsInRow(ObjectParameters, NewRow, TabularSectionName);
						EndIf;
					EndIf;
					
					If UseDefaultTypeOfAccounting 
						And IsTabularSectionImport 
						And (ObjectParameters.DocumentName = "Production"
							Or ObjectParameters.DocumentName = "Manufacturing") Then
						GLAccountsInDocuments.FillGLAccountsInRow(ObjectParameters, NewRow, TabularSectionName);
					EndIf;
					
				EndIf;
				
			EndIf;
		EndDo;
		
		CommitTransaction();
		
	Except
		
		WriteLogEvent(
			NStr("en = 'Data Import'; ru = 'Загрузка данных';pl = 'Import danych';es_ES = 'Importación de Datos';es_CO = 'Importación de Datos';tr = 'Veri içe aktarımı';it = 'Importazione dati';de = 'Datenimport'", CommonClientServer.DefaultLanguageCode()),
			EventLogLevel.Error,
			Metadata.Catalogs.Products,
			,
			ErrorDescription());
			
		RollbackTransaction();
	EndTry;
	
EndProcedure

// Procedure sets visible of calculation attributes depending on the parameters specified to the counterparty.
//
Procedure SetAccountsAttributesVisible(Object, CurrentForm = Undefined, Val DoOperationsByContracts = False, Val DoOperationsByOrders = False, TabularSectionName)
	
	If CurrentForm.FormName = "Document.OpeningBalanceEntry.Form.DocumentForm" Then
		ThisIsWizard = False;
	Else
		ThisIsWizard = True;
	EndIf;
	
	FillServiceAttributesByCounterpartyInCollection(Object[TabularSectionName]);
	
	For Each CurRow In Object[TabularSectionName] Do
		If CurRow.DoOperationsByContracts Then
			DoOperationsByContracts = True;
		EndIf;
		If CurRow.DoOperationsByOrders Then
			DoOperationsByOrders = True;
		EndIf;
	EndDo;
	
	If TabularSectionName = "AccountsPayable" Then
		CurrentForm.Items[?(ThisIsWizard, "OpeningBalanceEntryCounterpartiesSettlements", "")+ "AccountsPayableContract"].Visible = DoOperationsByContracts;
		CurrentForm.Items[?(ThisIsWizard, "OpeningBalanceEntryCounterpartiesSettlements", "")+ "AccountsPayablePurchaseOrder"].Visible = DoOperationsByOrders;
	ElsIf TabularSectionName = "AccountsReceivable" Then
		CurrentForm.Items[?(ThisIsWizard, "OpeningBalanceEntryCounterpartiesSettlementsAccountsReceivableContract", "AccountsReceivableAgreement")].Visible = DoOperationsByContracts;
		CurrentForm.Items[?(ThisIsWizard, "OpeningBalanceEntryCounterpartiesSettlements", "")+ "AccountsReceivableSalesOrder"].Visible = DoOperationsByOrders;
	ElsIf TabularSectionName = "StockTransferredToThirdParties" Then
		CurrentForm.Items.StockTransferredToThirdPartiesContract.Visible = DoOperationsByContracts;
	ElsIf TabularSectionName = "StockReceivedFromThirdParties" Then
		CurrentForm.Items.StockReceivedFromThirdPartiesContract.Visible = DoOperationsByContracts;
	EndIf;
	
EndProcedure

Procedure FillServiceAttributesByCounterpartyInCollection(DataCollection)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	CAST(Table.LineNumber AS NUMBER) AS LineNumber,
	|	Table.Counterparty AS Counterparty
	|INTO TableOfCounterparty
	|FROM
	|	&DataCollection AS Table
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableOfCounterparty.Counterparty.DoOperationsByContracts AS DoOperationsByContracts,
	|	TableOfCounterparty.Counterparty.DoOperationsByOrders AS DoOperationsByOrders
	|FROM
	|	TableOfCounterparty AS TableOfCounterparty";
	
	Query.SetParameter("DataCollection", DataCollection.Unload( ,"LineNumber, Counterparty"));
	
	Selection = Query.Execute().Select();
	For Ct = 0 To DataCollection.Count() - 1 Do
		Selection.Next(); // Number of rows in the query selection always equals to the number of rows in the collection
		FillPropertyValues(DataCollection[Ct], Selection, "DoOperationsByContracts, DoOperationsByOrders");
	EndDo;
	
EndProcedure

Function GetContractByDefault(Document, Counterparty, Company, TabularSectionName, OperationKind = Undefined)
	
	If (TabularSectionName = "StockTransferredToThirdParties"
		OR TabularSectionName = "StockReceivedFromThirdParties")
		AND Not ValueIsFilled(OperationKind) Then
		
		Return Catalogs.CounterpartyContracts.EmptyRef();
	EndIf;
	
	ManagerOfCatalog = Catalogs.CounterpartyContracts;
	
	ContractTypesList = ManagerOfCatalog.GetContractTypesListForDocument(Document, OperationKind, TabularSectionName);
	ContractByDefault = ManagerOfCatalog.GetDefaultContractByCompanyContractKind(Counterparty, Company, ContractTypesList);
	
	Return ContractByDefault;
	
EndFunction

// It receives data set from the server for the CounterpartyOnChange procedure.
//
Function GetDataCounterparty(Object, Counterparty, TabularSectionName, CurrentForm = Undefined, OperationKind = Undefined)
	
	ContractByDefault = GetContractByDefault(Object, Counterparty, Object.Company, TabularSectionName, OperationKind);
	
	StructureData = New Structure();
	
	StructureData.Insert(
		"Contract",
		ContractByDefault);
	
	StructureData.Insert(
		"SettlementsCurrency",
		ContractByDefault.SettlementsCurrency);
	
	StructureData.Insert("DoOperationsByContracts", Counterparty.DoOperationsByContracts);
	StructureData.Insert("DoOperationsByOrders", Counterparty.DoOperationsByOrders);
	
	SetAccountsAttributesVisible(
		Object,
		CurrentForm,
		Counterparty.DoOperationsByContracts,
		Counterparty.DoOperationsByOrders,
		TabularSectionName);
	
	Return StructureData;
	
EndFunction

Function DefaultPriceKind() Export
	
	Return Catalogs.Counterparties.GetMainKindOfSalePrices();
	
EndFunction

Function NotUpdatableStandardFieldNames() Export
	
	Return
	"TIN
	|CounterpartyDescription
	|ProductsDescription
	|ProductsFullDescription
	|BankAccount
	|Parent
	|PhoneNumber
	|SerialNumber
	|Barcode"
	
EndFunction

Procedure AddContacts(CatalogItem, CIPresentation, CIKind)
	
	CIValue = ContactsManager.ContactsByPresentation(CIPresentation, CIKind);
	ContactsManager.WriteContactInformation(CatalogItem, CIValue, CIKind, CIKind.Type);
	
EndProcedure

Procedure CreateCurrency(TableRow, DataMatchingTable, UpdateAllRows = True)
	
	Codes = New Array;
	Codes.Add(TableRow.CurrencyCode);
	AddedCurrencies = DataProcessors.ImportCurrenciesRates.AddCurrenciesByCode(Codes);
	If AddedCurrencies.Count() = 0 Then
		NewCurrency = Catalogs.Currencies.CreateItem();
		NewCurrency.Code = TableRow.CurrencyCode;
		NewCurrency.Description = TableRow.CurrencyName;
		NewCurrency.DescriptionFull = TableRow.CurrencyName;
		NewCurrency.Write();
		AddedCurrencies.Add(NewCurrency.Ref);
	EndIf;
	
	Filter = New Structure;
	Filter.Insert("CurrencyCode", TableRow.CurrencyCode);
	Filter.Insert("CurrencyName", TableRow.CurrencyName);
	TableRowsToBeUpdated = DataMatchingTable.FindRows(Filter);
	For Each TableRowToBeUpdated In TableRowsToBeUpdated Do
		TableRowToBeUpdated.Currency = AddedCurrencies[0];
	EndDo;
	
EndProcedure

#Region ComparisonMethods

// Common

Procedure CatalogByName(CatalogName, CatalogValue, CatalogDescription, DefaultValue = Undefined, Owner = Undefined)
	
	If Not IsBlankString(CatalogDescription) Then
		
		If ValueIsFilled(Owner) Then
			CatalogRef = Catalogs[CatalogName].FindByDescription(CatalogDescription, True, , Owner);
		Else
			CatalogRef = Catalogs[CatalogName].FindByDescription(CatalogDescription, True);
		EndIf;
		If ValueIsFilled(CatalogRef) Then
			
			CatalogValue = CatalogRef;
			
		EndIf;
		
	EndIf;
	
	If Not ValueIsFilled(CatalogValue) Then
		
		CatalogValue = DefaultValue;
		
	EndIf;
	
EndProcedure

Procedure MapEnumeration(EnumerationName, EnumValue, IncomingData, DefaultValue)
	
	If ValueIsFilled(IncomingData) Then
		
		For Each EnumerationItem In Metadata.Enums[EnumerationName].EnumValues Do
			
			Synonym = EnumerationItem.Synonym;
			If Find(Upper(Synonym), Upper(IncomingData)) > 0 Then
				
				EnumValue = Enums[EnumerationName][EnumerationItem.Name];
				Break;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	If Not ValueIsFilled(EnumValue) Then
		
		EnumValue = DefaultValue;
		
	EndIf;
	
EndProcedure

Procedure MapGLAccount(GLAccount, GLAccount_IncomingData, DefaultValue, ChartsOfAccountsManager = Undefined)
	
	If ChartsOfAccountsManager = Undefined Then
		ChartsOfAccountsManager = ChartsOfAccounts.PrimaryChartOfAccounts;
	EndIf;
	
	If Not IsBlankString(GLAccount_IncomingData) Then
		
		FoundGLAccount = ChartsOfAccountsManager.FindByCode(GLAccount_IncomingData);
		If FoundGLAccount = Undefined Then
			
			FoundGLAccount = ChartsOfAccountsManager.FindByDescription(GLAccount_IncomingData, True);
			
		EndIf;
		
		If ValueIsFilled(FoundGLAccount) Then
			
			GLAccount = FoundGLAccount
			
		EndIf;
		
	EndIf;
	
	If Not ValueIsFilled(GLAccount) Then
		
		GLAccount = DefaultValue;
		
	EndIf;
	
EndProcedure

Procedure ConvertStringToBoolean(ValueBoolean, IncomingData) Export
	
	IncomingData = UPPER(TrimAll(IncomingData));
	
	Array = New Array;
	Array.Add("+");
	Array.Add("1");
	Array.Add("TRUE");
	Array.Add("YES");
	
	ValueBoolean = (Array.Find(IncomingData) <> Undefined);
	
EndProcedure

Procedure ConvertRowToNumber(NumberResult, Val NumberByString, DefaultValue = 0)
	
	If IsBlankString(NumberByString) Then
		NumberResult = DefaultValue;
		Return;
	EndIf;
	
	TestNumberString = String(0.1);
	DecimalSeparator = Mid(TestNumberString, 2, 1);
	
	Digits = "0123456789";
	NonDigitalSymbols = New Array;
	
	NumberByString = TrimAll(NumberByString);
	
	SignMultiplier = 1;
	If Left(NumberByString, 1) = "-" Then
		SignMultiplier = -1;
		NumberByString = Mid(NumberByString, 2);
	EndIf;
	
	For Counter = 1 To StrLen(NumberByString) Do
		CurrentSymbol = Mid(NumberByString, Counter, 1);
		If StrFind(Digits, CurrentSymbol) = 0
			And NonDigitalSymbols.Find(CurrentSymbol) = Undefined Then
			NonDigitalSymbols.Add(CurrentSymbol);
		EndIf;
	EndDo;
	
	NumberByStringCopy = NumberByString;
	
	NonDigitalSymbolsCount = NonDigitalSymbols.Count();
	If NonDigitalSymbolsCount > 0 Then
		For Counter = 1 To NonDigitalSymbolsCount - 1 Do
			NumberByStringCopy = StrReplace(NumberByStringCopy, NonDigitalSymbols[Counter - 1], "");
		EndDo;
		NumberByStringCopy = StrReplace(
			NumberByStringCopy,
			NonDigitalSymbols[NonDigitalSymbolsCount - 1],
			DecimalSeparator);
	EndIf;
	
	Try
		NumberResult = Number(NumberByStringCopy) * SignMultiplier;
	Except
		NumberResult = DefaultValue;
	EndTry;
	
EndProcedure

Procedure ConvertStringToDate(DateResult, DateString) Export
	
	If IsBlankString(DateString) Then
		
		DateResult = Date(0001, 01, 01);
		Return;
		
	EndIf;
	
	Try
		DateResult = Date(TrimAll(DateString));
		Return;
	Except
		DateResult = Date(0001, 01, 01);
	EndTry;
	
	CopyDateString = DateString;
	
	DelimitersArray = New Array;
	DelimitersArray.Add(".");
	DelimitersArray.Add("/");
	DelimitersArray.Add("-");
	
	For Each Delimiter In DelimitersArray Do
		
		NumberByString = "";
		MonthString = "";
		YearString = "";
		
		SeparatorPosition = Find(CopyDateString, Delimiter);
		If SeparatorPosition > 0 Then
			
			NumberByString = Left(CopyDateString, SeparatorPosition - 1);
			CopyDateString = Mid(CopyDateString, SeparatorPosition + 1);
			
		EndIf;
		
		SeparatorPosition = Find(CopyDateString, Delimiter);
		If SeparatorPosition > 0 Then
			
			MonthString = Left(CopyDateString, SeparatorPosition - 1);
			CopyDateString = Mid(CopyDateString, SeparatorPosition + 1);
			
		EndIf;
		
		YearString = CopyDateString;
		
		If Not IsBlankString(NumberByString)
			And Not IsBlankString(MonthString)
			And Not IsBlankString(YearString) Then
			
			Try
				
				DateResult = Date(Number(YearString), Number(MonthString), Number(NumberByString));
				
			Except
				
				DateResult = Date(0001, 01, 01);
				
			EndTry;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure CopyRowToStringTypeValue(StringTypeValue, String) Export
	
	StringTypeValue = TrimAll(String);
	
EndProcedure

Procedure CompareProducts(Products, Barcode, SKU, ProductsDescription, ProductsDescriptionFull = Undefined, Code = Undefined, Supplier  = Undefined)
	
	ValueWasMapped = False;
	If ValueIsFilled(Code) Then
		
		CatalogRef = Catalogs.Products.FindByCode(Code, False);
		If Not CatalogRef.IsEmpty() Then
			
			ValueWasMapped = True;
			Products = CatalogRef;
			
		EndIf;
		
	EndIf;
	
	If Not ValueWasMapped 
		AND ValueIsFilled(Barcode) Then
		
		Query = New Query(
		"SELECT
		|	BC.Products AS Products
		|FROM
		|	InformationRegister.Barcodes AS BC
		|WHERE
		|	BC.Barcode = &Barcode");
		Query.SetParameter("Barcode", Barcode);
		Selection = Query.Execute().Select();
		If Selection.Next() Then
			
			ValueWasMapped = True;
			Products = Selection.Products;
			
		EndIf;
		
	EndIf;
	
	If Not ValueWasMapped
		AND ValueIsFilled(SKU) Then
		
		CatalogRef = DuplicatesBlocking.MapObject(
			Enums.DuplicateObjectsTypes.Products,
			Enums.DuplicateObjectsCriterias.SKU,
			SKU);
		
		If ValueIsFilled(CatalogRef) Then
			
			ValueWasMapped = True;
			Products = CatalogRef;
			
		EndIf;
		
	EndIf;
	
	If Not ValueWasMapped
		AND ValueIsFilled(ProductsDescription) Then
		
		If Not ValueIsFilled(Supplier) Then 
			
			CatalogRef = DuplicatesBlocking.MapObject(
				Enums.DuplicateObjectsTypes.Products,
				Enums.DuplicateObjectsCriterias.Description,
				ProductsDescription);
			
			If ValueIsFilled(CatalogRef)
				AND Not CatalogRef.IsFolder Then 
				
				ValueWasMapped = True;
				Products = CatalogRef;
			EndIf;
		Else
			Products = SearchProduct(ProductsDescription, True, Supplier)
		EndIf;
		
	EndIf;
	
	If Not ValueWasMapped
		AND ValueIsFilled(ProductsDescriptionFull) Then
		
		If Not ValueIsFilled(Supplier) Then 
			
			CatalogRef = DuplicatesBlocking.MapObject(
				Enums.DuplicateObjectsTypes.Products,
				Enums.DuplicateObjectsCriterias.DescriptionFull,
				ProductsDescriptionFull);
			
			If ValueIsFilled(CatalogRef)
				AND Not CatalogRef.IsFolder Then 
				
				ValueWasMapped = True;
				Products = CatalogRef;
			EndIf;
		Else
			Products = SearchProduct(ProductsDescriptionFull, True, Supplier)
		EndIf;
		
	EndIf;
	
	// Categories for catalog of products are not used at the moment.
	If ValueIsFilled(Products)
		AND Products.IsFolder Then
		
		Products = Catalogs.Products.EmptyRef(ProductsDescription, True);
		
	EndIf;
	
EndProcedure

Function SearchProduct(ProductsDescription, ExactMap, Supplier)
	
	CatalogRef = Catalogs.Products.FindByDescription(ProductsDescription, ExactMap);

	If Not ValueIsFilled(CatalogRef) Then
		SupplierProduct = Catalogs.SuppliersProducts.FindByDescription(ProductsDescription, True, , Supplier);
		CatalogRef = SupplierProduct.Products;
	EndIf;

	SupplierProduct = ValueIsFilled(SupplierProduct) AND SupplierProduct.DeletionMark;
	
	If ValueIsFilled(CatalogRef)
		AND Not CatalogRef.IsFolder
		AND Not CatalogRef.DeletionMark
		AND Not SupplierProduct Then

		Products = CatalogRef;
	Else
		
		If SupplierProduct Then
			CommonClientServer.MessageToUser(
				StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Object matching %1 has deletion mark'; ru = 'Объект, соответствующий %1, помечен на удаление.';pl = 'Dopasowanie obiektu %1 posiada oznaczenie usunięcia';es_ES = 'La correspondencia del objeto %1 tiene la marca de borrar';es_CO = 'La correspondencia del objeto %1 tiene la marca de borrar';tr = 'Nesne eşleme %1, silme işaretine sahip';it = 'La corrispondenza oggetto %1 presenta il contrassegno di eliminazione';de = 'Objektvergleich %1 hat Löschmarkierung'"),
					SupplierProduct));
		EndIf;
		
		If CatalogRef.DeletionMark Then
			CommonClientServer.MessageToUser(
				StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Object %1 has deletion mark'; ru = 'Объект %1 помечен на удаление.';pl = 'Obiekt %1 posiada oznaczenie usunięcia';es_ES = 'El objeto %1 tiene la marca de borrar';es_CO = 'El objeto %1 tiene la marca de borrar';tr = 'Nesne %1''in silme işareti var';it = 'L''oggetto %1 presenta il contrassegno di eliminazione';de = 'Objekt %1 hat Löschmarkierung'"),
					CatalogRef));
		EndIf;
		
	EndIf;
	
	Return Products;
	
EndFunction

Procedure CreateAdditionalProperty(AdditionalAttributeValue, Property, UseHierarchy, StringValue) Export
	
	If Not ValueIsFilled(AdditionalAttributeValue) Then
		
		CatalogName = ?(UseHierarchy, "ObjectPropertyValueHierarchy", "ObjectsPropertiesValues");
		
		CatalogObject = Catalogs[CatalogName].CreateItem();
		CatalogObject.Owner = Property;
		CatalogObject.Description = StringValue;
		
		InfobaseUpdate.WriteObject(CatalogObject, True, True);
		
		AdditionalAttributeValue = CatalogObject.Ref;
		
	EndIf;
	
EndProcedure

Procedure MapAdditionalAttribute(AdditionalAttributeValue, Property, UseHierarchy, StringValue) Export
	
	QueryText = 
	"SELECT
	|	ObjectsPropertiesValues.Ref AS PropertyValue
	|FROM
	|	Catalog.ObjectsPropertiesValues AS ObjectsPropertiesValues
	|WHERE
	|	ObjectsPropertiesValues.Description LIKE &Description
	|	AND ObjectsPropertiesValues.Ref IN(&ValueArray)";
	
	Query = New Query(QueryText);
	
	If UseHierarchy Then         
		
		Query.Text = StrReplace(Query.Text, "Catalog.ObjectsPropertiesValues", "Catalog.ObjectPropertyValueHierarchy");
		
	EndIf;	
	
	ValueArray = PropertyManager.GetPropertiesValuesList(Property);
	
	Query.SetParameter("Description", TrimAll(StringValue));
	Query.SetParameter("ValueArray", ValueArray);
	QueryResult = Query.Execute();
	
	If NOT QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		If Selection.Next() Then
			AdditionalAttributeValue = Selection.PropertyValue;
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure CreateFillTableOfPossibleValueTypesForAdditionalAttribute(Property, TypesTable) Export
	
	TypesTable = New ValueTable;
	TypesTable.Columns.Add("Type");
	TypesTable.Columns.Add("Priority");
	
	ValueTypeArray = Property.ValueType.Types();
	For Each ArrayItem In ValueTypeArray Do
		
		NewRow = TypesTable.Add();
		NewRow.Type = ArrayItem;
		If ArrayItem = Type("CatalogRef.ObjectsPropertiesValues")
			OR ArrayItem = Type("CatalogRef.ObjectPropertyValueHierarchy") Then
			
			NewRow.Priority = 1;
			
		ElsIf ArrayItem = Type("Boolean")
			OR ArrayItem = Type("Date")
			OR ArrayItem = Type("Number") Then
			
			NewRow.Priority = 3;
			
		ElsIf ArrayItem = Type("String") Then
			NewRow.Priority = 4;
		Else
			NewRow.Priority = 2;
		EndIf;
		
	EndDo;
	
	TypesTable.Sort("Priority");
	
EndProcedure

Procedure MapCharacteristic(Characteristic, Products, Barcode, Characteristic_IncomingData) Export
	
	If ValueIsFilled(Products) Then
		
		ValueWasMapped = False;
		If ValueIsFilled(Barcode) Then
			
			Query = New Query("SELECT BC.Characteristic FROM InformationRegister.Barcodes AS BC WHERE BC.Barcode = &Barcode AND BC.Products = &Products");
			Query.SetParameter("Barcode", Barcode);
			Query.SetParameter("Products", Products);
			
			Selection = Query.Execute().Select();
			If Selection.Next() Then
				
				ValueWasMapped = True;
				Characteristic = Selection.Characteristic;
				
			EndIf;
			
		EndIf;
		
		If Not ValueWasMapped
			AND ValueIsFilled(Characteristic_IncomingData) Then
			
			// Product or product category can be owners of a variant.
			//
			
			CatalogRef = Undefined;
			CatalogRef = Catalogs.ProductsCharacteristics.FindByDescription(Characteristic_IncomingData, True, , Products);
			If Not ValueIsFilled(CatalogRef)
				AND ValueIsFilled(Products.ProductsCategory) Then
				
				CatalogRef = Catalogs.ProductsCharacteristics.FindByDescription(Characteristic_IncomingData, True, , Products.ProductsCategory);
				
			EndIf;
			
			If ValueIsFilled(CatalogRef) Then
				
				Characteristic = CatalogRef;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure MapBatch(Batch, Products, Barcode, Batch_IncomingData) Export
	
	If ValueIsFilled(Products) Then
		
		ValueWasMapped = False;
		If ValueIsFilled(Barcode) Then
			
			Query = New Query("SELECT BC.Batch FROM InformationRegister.Barcodes AS BC WHERE BC.Barcode = &Barcode AND BC.Products = &Products");
			Query.SetParameter("Barcode", Barcode);
			Query.SetParameter("Products", Products);
			
			Selection = Query.Execute().Select();
			If Selection.Next() Then
				
				ValueWasMapped = True;
				Batch = Selection.Batch;
				
			EndIf;
			
		EndIf;
		
		If Not ValueWasMapped
			AND ValueIsFilled(Batch_IncomingData) Then
			
			CatalogRef = Catalogs.ProductsBatches.FindByDescription(Batch_IncomingData, True, , Products);
			If ValueIsFilled(CatalogRef) Then
				
				Batch = CatalogRef;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure MapUOM(Products, MeasurementUnit, MeasurementUnit_IncomingData, DefaultValue) Export
	
	If Not IsBlankString(MeasurementUnit_IncomingData) Then
		
		CatalogRef = Catalogs.UOMClassifier.FindByDescription(MeasurementUnit_IncomingData, True);
		ProductsIsFilled = ValueIsFilled(Products);
		
		If ValueIsFilled(CatalogRef) 
			AND ((ProductsIsFilled 
					AND Common.ObjectAttributeValue(Products, "MeasurementUnit") = CatalogRef)
				Or Not ProductsIsFilled) Then
			
			MeasurementUnit = CatalogRef;
			
		ElsIf ProductsIsFilled Then
			CatalogRef = Catalogs.UOM.FindByDescription(MeasurementUnit_IncomingData, True, , Products);
			If ValueIsFilled(CatalogRef) Then
				MeasurementUnit = CatalogRef;
			EndIf;
		EndIf;
		
	EndIf;
	
	If Not ValueIsFilled(MeasurementUnit) Then 
		
		MeasurementUnit = DefaultValue;
		
	EndIf;
	
EndProcedure

Procedure MapReportUOM(ReportUOM, ReportUOM_IncomingData, DefaultValue) Export
	
	CatalogByName("UOMClassifier", ReportUOM, ReportUOM_IncomingData, DefaultValue);
	
EndProcedure

Procedure MapParent(CatalogName, Parent, Parent_IncomingData, DefaultValue) Export
	
	If Not IsBlankString(Parent_IncomingData) Then
		
		Query = New Query("SELECT ALLOWED Catalog." + CatalogName + ".Ref WHERE Catalog." + CatalogName + ".IsFolder AND Catalog." + CatalogName + ".Description LIKE &Description");
		Query.SetParameter("Description", Parent_IncomingData + "%");
		Selection = Query.Execute().Select();
		
		If Selection.Next() Then
			
			Parent = Selection.Ref;
			
		EndIf;
		
	EndIf;
	
	If Not ValueIsFilled(Parent) Then
		
		Parent = DefaultValue;
		
	EndIf;
	
EndProcedure

Procedure MapItemParentWithOwner(CatalogName, Parent, Parent_IncomingData, DefaultValue, Owner) Export
	
	If Not ValueIsFilled(Owner) Then
		
		Parent = DefaultValue;
		Return;
		
	EndIf;
	
	If Not IsBlankString(Parent_IncomingData) Then
		
		Query = New Query("SELECT ALLOWED Catalog." + CatalogName + ".Ref WHERE Catalog." + CatalogName + ".Owner = &Owner AND Catalog." + CatalogName + ".Description LIKE &Description");
		Query.SetParameter("Description", Parent_IncomingData + "%");
		Query.SetParameter("Owner", Owner);
		Selection = Query.Execute().Select();
		
		If Selection.Next() Then
			
			Parent = Selection.Ref;
			
		EndIf;
		
	EndIf;
	
	If Not ValueIsFilled(Parent) Then
		
		Parent = DefaultValue;
		
	EndIf;
	
EndProcedure

Procedure MapAdditionalAttributes(FormTableRow, SelectedAdditionalAttributes) Export
	Var TypesTable;
	
	Postfix = "_IncomingData";
	For Each MapItem In SelectedAdditionalAttributes Do
		
		StringValue = FormTableRow[MapItem.Value + Postfix];
		If IsBlankString(StringValue) Then
			Continue;
		EndIf;
		
		Property = MapItem.Key;
		
		CreateFillTableOfPossibleValueTypesForAdditionalAttribute(Property, TypesTable);
		
		AdditionalAttributeValue = Undefined;
		For Each TableRow In TypesTable Do
			
			If TableRow.Type = Type("CatalogRef.ObjectsPropertiesValues") Then
				
				MapAdditionalAttribute(AdditionalAttributeValue, Property, False, StringValue);
				
			ElsIf TableRow.Type = Type("CatalogRef.ObjectPropertyValueHierarchy") Then
				
				MapAdditionalAttribute(AdditionalAttributeValue, Property, True, StringValue);
			
			ElsIf TableRow.Type = Type("CatalogRef.Counterparties") Then
				
				MapCounterparty(AdditionalAttributeValue, StringValue, StringValue, StringValue, StringValue, StringValue);
				
			ElsIf TableRow.Type = Type("CatalogRef.Individuals") Then
				
				MapIndividualPerson(AdditionalAttributeValue, StringValue);
				
			ElsIf TableRow.Type = Type("Boolean") Then
				
				ConvertStringToBoolean(AdditionalAttributeValue, StringValue);
				
			ElsIf TableRow.Type = Type("String") Then
				
				CopyRowToStringTypeValue(AdditionalAttributeValue, StringValue);
				
			ElsIf TableRow.Type = Type("Date") Then
				
				ConvertStringToDate(AdditionalAttributeValue, StringValue);
				
			ElsIf TableRow.Type = Type("Number") Then
				
				ConvertRowToNumber(AdditionalAttributeValue, StringValue);
				If AdditionalAttributeValue = 0 Then // 0 ignore
					AdditionalAttributeValue = Undefined;
				EndIf;
				
			EndIf;
			
			If AdditionalAttributeValue <> Undefined Then
				FormTableRow[MapItem.Value] = AdditionalAttributeValue;
				Break;
			EndIf;
		EndDo;
	EndDo;
	
EndProcedure

Procedure MapSystemEnumeration(SystemEnumeration, EnumValue, IncomingData, DefaultValue)
	
	If ValueIsFilled(IncomingData) Then
		
		For Each EnumerationItem In SystemEnumeration Do
			
			Synonym = String(EnumerationItem);
			If Find(Upper(Synonym), Upper(IncomingData)) > 0 Then
				
				EnumValue = EnumerationItem;
				Break;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	If Not ValueIsFilled(EnumValue) Then
		
		EnumValue = DefaultValue;
		
	EndIf;
	
EndProcedure

Function GetOwner(Value) Export
	
	Return Common.ObjectAttributeValue(Value, "Owner");
	
EndFunction

// Specification

Procedure MapRowType(RowType, RowType_IncomingData, DefaultValue) Export
	
	MapEnumeration("BOMLineType", RowType, RowType_IncomingData, DefaultValue);
	
EndProcedure

Procedure MapSpecification(Specification, Specification_IncomingData, Products) Export
	
	If ValueIsFilled(Products) 
		AND Not IsBlankString(Specification_IncomingData) Then
		
		CatalogRef = Catalogs.BillsOfMaterials.FindByDescription(Specification_IncomingData, True, , Products);
		If ValueIsFilled(CatalogRef) Then
			
			Specification = CatalogRef;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Products

Procedure MapProductsType(ProductsType, ProductsType_IncomingData, DefaultValue) Export
	
	MapEnumeration("ProductsTypes", ProductsType, ProductsType_IncomingData, DefaultValue);
	
EndProcedure

Procedure MapBusinessLine(BusinessLine, BusinessLine_IncomingData, DefaultValue) Export
	
	UseEnabled = GetFunctionalOption("AccountingBySeveralLinesOfBusiness");
	If Not UseEnabled Then
		
		// You can not fill in the default value as it can, for instance, come from custom settings.
		//
		BusinessLine = Catalogs.LinesOfBusiness.MainLine;
		
	Else
		
		CatalogByName("LinesOfBusiness", BusinessLine, BusinessLine_IncomingData, DefaultValue);
		
	EndIf;
	
EndProcedure

Procedure MapProductsCategory(ProductsCategory, ProductsCategory_IncomingData, DefaultValue) Export
	
	CatalogByName("ProductsCategories", ProductsCategory, ProductsCategory_IncomingData, DefaultValue)
	
EndProcedure

Procedure MapSalesRep(SalesRep, SalesRep_IncomingData, DefaultValue) Export
	
	CatalogByName("Employees", SalesRep, SalesRep_IncomingData, DefaultValue)
	
EndProcedure

Procedure MapSalesTerritory(SalesTerritory, SalesTerritory_IncomingData, DefaultValue) Export
	
	CatalogByName("SalesTerritories", SalesTerritory, SalesTerritory_IncomingData, DefaultValue)
	
EndProcedure

Procedure MapProject(Project, Project_IncomingData, DefaultValue) Export
	
	CatalogByName("Projects", Project, Project_IncomingData, DefaultValue)
	
EndProcedure

Procedure MapProductGroup(ProductGroup, ProductGroup_IncomingData, DefaultValue) Export
	
	If IsBlankString(ProductGroup_IncomingData) Then
		
		Return;
		
	EndIf;
	
	Query = New Query("SELECT
	|	Products.Ref AS Ref
	|FROM
	|	Catalog.Products AS Products
	|WHERE
	|	Products.IsFolder
	|	AND Products.Description = &Description");
	
	Query.SetParameter("Description", ProductGroup_IncomingData);
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		
		ProductGroup = Selection.Ref;
		
	EndIf;
	
EndProcedure

Procedure MapSupplier(Vendor, Vendor_TIN, Vendor_Name)
	
	If Not IsBlankString(Vendor_TIN) Then
		
		// TIN Search
		Separators = New Array;
		Separators.Add("/");
		Separators.Add("\");
		Separators.Add("-");
		Separators.Add("|");
		
		TIN = "";
		
		For Each SeparatorValue In Separators Do
			
			SeparatorPosition = Find(Vendor_TIN, SeparatorValue);
			If SeparatorPosition = 0 Then 
				
				Continue;
				
			EndIf;
			
			TIN = Left(Vendor_TIN, SeparatorPosition - 1);
			
			Query = New Query(
			"SELECT ALLOWED
			|	Counterparties.Ref AS Ref
			|FROM
			|	Catalog.Counterparties AS Counterparties
			|WHERE
			|	NOT Counterparties.IsFolder
			|	AND Counterparties.TIN = &TIN");
			Query.SetParameter("TIN", TIN);
			
			Selection = Query.Execute().Select();
			If Selection.Next() Then
				
				Vendor = Selection.Ref;
				Return;
				
			EndIf;
			
		EndDo;
		
		// Search TIN
		Query = New Query("SELECT ALLOWED Catalog.Counterparties.Ref WHERE NOT IsFolder AND TIN = &TIN");
		Query.SetParameter("TIN", Vendor_TIN);
		Selection = Query.Execute().Select();
		If Selection.Next() Then
			
			Vendor = Selection.Ref;
			Return;
			
		EndIf;
		
	EndIf;
	
	// Search Name
	If Not IsBlankString(Vendor_Name) Then
		CatalogRef = Catalogs.Counterparties.FindByDescription(Vendor_Name, True);
		If ValueIsFilled(CatalogRef) Then
			
			Vendor = CatalogRef;
			
		EndIf;
	EndIf;
	
EndProcedure

Procedure MapStructuralUnit(Warehouse, Warehouse_IncomingData, DefaultValue) Export
	
	CatalogByName("BusinessUnits", Warehouse, Warehouse_IncomingData, DefaultValue);
	
EndProcedure

Procedure MapReplenishmentMethod(ReplenishmentMethod, ReplenishmentMethod_IncomingData, DefaultValue) Export
	
	MapEnumeration("InventoryReplenishmentMethods", ReplenishmentMethod, ReplenishmentMethod_IncomingData, DefaultValue);
	
EndProcedure

Procedure MapVATRate(VATRate, VATRate_IncomingData, DefaultValue) Export
	
	CatalogByName("VATRates", VATRate, VATRate_IncomingData, DefaultValue);
	
EndProcedure

Procedure MapCell(Cell, Cell_IncomingData, CellCode = "", Owner, DefaultValue = Undefined, Parent = Undefined)
	
	CatalogByName("Cells", Cell, Cell_IncomingData, DefaultValue, Owner);
	
	If Cell = Catalogs.Cells.EmptyRef()
		And Not CellCode = "" 
		And ValueIsFilled(Parent) Then
		
		Cell = Catalogs.Cells.FindByCode(CellCode, , Parent, Owner);
		
	ElsIf Cell = Catalogs.Cells.EmptyRef()
		And Not CellCode = "" Then
		
		Cell = Catalogs.Cells.FindByCode(CellCode, , , Owner);
		
	EndIf;
	
EndProcedure

Procedure MapPriceGroup(PriceGroup, PriceGroup_IncomingData, DefaultValue) Export
	
	CatalogByName("PriceGroups", PriceGroup, PriceGroup_IncomingData, DefaultValue);
	
EndProcedure

Procedure MapOriginCountry(CountryOfOrigin, CountryOfOrigin_IncomingData, DefaultValue) Export
	
	If Not IsBlankString(CountryOfOrigin_IncomingData) Then
		
		CatalogRef = Catalogs.WorldCountries.FindByDescription(CountryOfOrigin_IncomingData, True);
		If Not ValueIsFilled(CatalogRef) Then
			
			CatalogRef = Catalogs.WorldCountries.FindByAttribute("CodeAlfa3", CountryOfOrigin_IncomingData);
			If Not ValueIsFilled(CatalogRef) Then
				
				CatalogRef = Catalogs.WorldCountries.FindByCode(CountryOfOrigin_IncomingData, True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	If ValueIsFilled(CatalogRef) Then
		
		CountryOfOrigin = CatalogRef;
		
	Else
		
		CountryOfOrigin = DefaultValue;
		
	EndIf;
	
EndProcedure

Procedure MapSerialNumber(ProductsRef, SerialNumber, SerialNumber_IncomingData) Export
	
	SerialNumber = Catalogs.SerialNumbers.FindByDescription(SerialNumber_IncomingData, True, , ProductsRef);
	
EndProcedure

Procedure SetupAttributeChoiceParameterLinksByMetadata(Parameters)
	
	MetadataObject = Parameters.MetadataObject;
	Object = Parameters.Object;
	MetadataAttribute = Parameters.MetadataAttribute;
	FormAttribute = Parameters.FormAttribute;
	
	If MetadataObject = Undefined 
		Or Not TypeOf(Object) = Type("ClientApplicationForm")
		Or Not CommonClientServer.HasAttributeOrObjectProperty(Object.Items, FormAttribute)
		Or Not CommonClientServer.HasAttributeOrObjectProperty(MetadataObject, "Attributes")
		Or Not CommonClientServer.HasAttributeOrObjectProperty(MetadataObject.Attributes, MetadataAttribute)Then
		
		Return;
	EndIf;
	
	Filter = Parameters.ChoiceParameterLinksFilterArray;
	EnableFilter = Filter.Count() > 0;
	NewChoiceParameterLinks = New Array;
	ChoiceParameterLinks = MetadataObject.Attributes[MetadataAttribute].ChoiceParameterLinks;
	
	For Each ChoiceParameterLink In ChoiceParameterLinks Do
		
		If EnableFilter And Filter.Find(ChoiceParameterLink.Name) = Undefined Then
			Continue;		
		EndIf;
		
		DataPath = ChoiceParameterLink.DataPath;
		PathParts = StrSplit(ChoiceParameterLink.DataPath, ".");
		
		If PathParts.Count() > 1 Then
			
			DataPath = StringFunctionsClientServer.SubstituteParametersToString(
				"Items.%1.CurrentData.%2", "DataMatchingTable", PathParts[1]);	
			
		EndIf;
		
		NewChoiceParameterLink = New ChoiceParameterLink(
			ChoiceParameterLink.Name, DataPath, ChoiceParameterLink.ValueChange);
		
		NewChoiceParameterLinks.Add(NewChoiceParameterLink);
		
	EndDo;
	
	If NewChoiceParameterLinks.Count() > 0 Then
		Try
			Object.Items[FormAttribute].ChoiceParameterLinks = New FixedArray(NewChoiceParameterLinks);
		Except
			
			WriteLogEvent(NStr("en = 'Data Import'; ru = 'Загрузка данных';pl = 'Import danych';es_ES = 'Importación de Datos';es_CO = 'Importación de Datos';tr = 'Veri içe aktarımı';it = 'Importazione dati';de = 'Datenimport'", CommonClientServer.DefaultLanguageCode()),
				EventLogLevel.Warning, , , ErrorDescription());
				
		EndTry;
	EndIf;
	
EndProcedure

// Purchase order
Procedure MatchOrder(Order, Order_IncomingData) Export
	
	If IsBlankString(Order_IncomingData) Then
		
		Return;
		
	EndIf;
	
	SuppliersTagsArray = New Array;
	SuppliersTagsArray.Add("Purchase order");
	SuppliersTagsArray.Add("PurchaseOrder");
	SuppliersTagsArray.Add("Vendor");
	SuppliersTagsArray.Add("Vendor");
	SuppliersTagsArray.Add("Post");
	
	NumberForSearch	= Order_IncomingData;
	DocumentKind	= "SalesOrder";
	For Each TagFromArray In SuppliersTagsArray Do
		
		If Find(Order_IncomingData, TagFromArray) > 0 Then
			
			DocumentKind = "PurchaseOrder";
			NumberForSearch = TrimAll(StrReplace(NumberForSearch, "", TagFromArray));
			
		EndIf;
		
	EndDo;
	
	Query = New Query("Select Document.SalesOrder.Ref Where Number LIKE &Number ORDER BY Date Desc");
	Query.SetParameter("Number", "%" + NumberForSearch + "%");
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		
		Order = Selection.Ref;
		
	EndIf;
	
EndProcedure

// Counterparty
Procedure MapCounterparty(Counterparty, TIN, CounterpartyDescription, BankAccount, Email, Phone) Export
	
	// TIN Search
	If Not IsBlankString(TIN) Then
		
		Query = New Query("SELECT ALLOWED Catalog.Counterparties.Ref WHERE NOT IsFolder AND TIN = &TIN");
		Query.SetParameter("TIN", TIN);
		Selection = Query.Execute().Select();
		If Selection.Next() Then
			
			Counterparty = Selection.Ref;
			Return;
			
		EndIf;
		
	EndIf;
	
	//Search Name
	If Not IsBlankString(CounterpartyDescription) Then
		
		CatalogRef = DuplicatesBlocking.MapObject(
			Enums.DuplicateObjectsTypes.Counterparties,
			Enums.DuplicateObjectsCriterias.Description,
			CounterpartyDescription);
		
		If ValueIsFilled(CatalogRef) Then
			
			Counterparty = CatalogRef;
			Return;
			
		EndIf;
		
	EndIf;
	
	// Current account number
	If Not IsBlankString(BankAccount) Then
		
		CatalogRef = Catalogs.BankAccounts.FindByAttribute("AccountNo", BankAccount);
		If ValueIsFilled(CatalogRef) Then
			Counterparty = CatalogRef.Owner;
		Else
			
			CatalogRef = Catalogs.BankAccounts.FindByAttribute("IBAN", BankAccount);
			If ValueIsFilled(CatalogRef) Then
				Counterparty = CatalogRef.Owner;
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// Email
	If Not IsBlankString(Email) Then
		
		CatalogRef = DuplicatesBlocking.MapObject(
			Enums.DuplicateObjectsTypes.Counterparties,
			Enums.DuplicateObjectsCriterias.ContactInformation,
			Email);
		
		If ValueIsFilled(CatalogRef) Then
			
			Counterparty = CatalogRef;
			Return;
			
		EndIf;
		
	EndIf;
	
	// Phone
	If Not IsBlankString(Phone) Then
		
		CatalogRef = DuplicatesBlocking.MapObject(
			Enums.DuplicateObjectsTypes.Counterparties,
			Enums.DuplicateObjectsCriterias.ContactInformation,
			Phone);
		
		If ValueIsFilled(CatalogRef) Then
			
			Counterparty = CatalogRef;
			Return;
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure MapIndividualPerson(Individual, Individual_IncomingData) Export
	
	CatalogByName("Individuals", Individual, Individual_IncomingData, Undefined);
	
EndProcedure

Procedure MapAccessGroup(AccessGroup, AccessGroup_IncomingData) Export
	
	CatalogByName("CounterpartiesAccessGroups", AccessGroup, AccessGroup_IncomingData);
	
EndProcedure

// Leads
Procedure MapLead(Lead, Description, CIArray)
	
	If Not IsBlankString(Description) Then
		
		CatalogRef = DuplicatesBlocking.MapObject(
			Enums.DuplicateObjectsTypes.Leads,
			Enums.DuplicateObjectsCriterias.Description,
			Description);
		
		If ValueIsFilled(CatalogRef) Then
			
			Lead = CatalogRef;
			Return;
			
		EndIf;
		
	EndIf;
	
	For Each CILine In CIArray Do
		
		If Not IsBlankString(CILine) Then
			
			CatalogRef = DuplicatesBlocking.MapObject(
				Enums.DuplicateObjectsTypes.Leads,
				Enums.DuplicateObjectsCriterias.ContactInformation,
				CILine);
			
			If ValueIsFilled(CatalogRef) Then
				
				Lead = CatalogRef;
				Return;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure MapAcquisitionChannel(AcquisitionChannel, AcquisitionChannel_IncomingData)
	
	CatalogByName("CustomerAcquisitionChannels", AcquisitionChannel, AcquisitionChannel_IncomingData, Undefined);
	
EndProcedure

// Prices

Procedure MapPriceKind(PriceKind, PriceKind_IncomingData, DefaultValue) Export
	
	CatalogByName("PriceTypes", PriceKind, PriceKind_IncomingData, DefaultValue);
	
EndProcedure

// Enter opening balance

Procedure MapContract(Counterparty, Contract, Contract_Description, Contract_Number, Company)
	
	If ValueIsFilled(Counterparty) Then
		
		Query = New Query;
		Query.Text =
		"SELECT
		|	CounterpartyContracts.Ref AS Ref
		|FROM
		|	Catalog.CounterpartyContracts AS CounterpartyContracts
		|WHERE
		|	CounterpartyContracts.Owner = &Owner
		|	AND CounterpartyContracts.Company = &Company
		|	AND CounterpartyContracts.Description = &Description
		|
		|UNION ALL
		|
		|SELECT
		|	CounterpartyContracts.Ref
		|FROM
		|	Catalog.CounterpartyContracts AS CounterpartyContracts
		|WHERE
		|	CounterpartyContracts.Owner = &Owner
		|	AND CounterpartyContracts.Company = &Company
		|	AND CounterpartyContracts.ContractNo = &ContractNo";
		
		Query.SetParameter("Owner", Counterparty);
		Query.SetParameter("Company", Company);
		If ValueIsFilled(Contract_Description) Then
			Query.SetParameter("Description", Contract_Description);
		Else
			Query.SetParameter("Description", Null);
		EndIf;
		If ValueIsFilled(Contract_Description) Then
			Query.SetParameter("ContractNo", Contract_Number);
		Else
			Query.SetParameter("ContractNo", Null);
		EndIf;
		
		Sel = Query.Execute().Select();
		If Sel.Next() Then
			Contract = Sel.Ref;
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure MapOrderByNumberDate(Order, DocumentTypeName, Counterparty, Number_IncomingData, Date_IncomingData) Export
	
	If Not ValueIsFilled(Counterparty)
		Or IsBlankString(Number_IncomingData) Then
		Return;
	EndIf;
	
	If DocumentTypeName <> "PurchaseOrder" Then
		DocumentTypeName = "SalesOrder"
	EndIf;
	
	TableName = "Document." + DocumentTypeName;
	
	Query = New Query(
		"SELECT
		|	Order.Ref AS Ref
		|FROM
		|	&TableName AS Order
		|WHERE
		|	Order.Counterparty = &Counterparty
		|	AND Order.Number LIKE &Number");
	Query.Text = StrReplace(Query.Text, "&TableName", TableName);
	Query.SetParameter("Counterparty", Counterparty);
	Query.SetParameter("Number", "%" + Number_IncomingData + "%");
	
	If Not IsBlankString(Date_IncomingData) Then
		
		DateFromString = Date('00010101');
		ConvertStringToDate(DateFromString, Date_IncomingData);
		
		If ValueIsFilled(DateFromString) Then
			
			Query.Text = Query.Text + "
			|	AND Order.Date Between &StartDate AND &EndDate";
			Query.SetParameter("StartDate", BegOfDay(DateFromString));
			Query.SetParameter("EndDate", EndOfDay(DateFromString));
			
		EndIf;
		
	EndIf;
	
	Query.Text = Query.Text + "
	|ORDER BY Order.Date DESC";
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		
		Order = Selection.Ref;
		
	EndIf;
	
EndProcedure

Procedure MapBillingDocumentByNumberDate(Document, DocumentTypeName, IsAR,
	Counterparty, Number_IncomingData, Date_IncomingData)
	
	TypeArray = ARAPDocumentTypes(IsAR);
	MapDocumentNames = GetDocumentTypesMap(TypeArray);
	DocumentType = MapDocumentNames.Get(UpperNoBlanks(DocumentTypeName));
	If DocumentType = Undefined Then
		
		DocumentTypeName = InvalidDocumentType();
		Return;
		
	EndIf;
	
	TableName = "Document." + DocumentType;
	
	If ValueIsFilled(Counterparty) Then
		Query = New Query(
			"SELECT
			|	AccountingDocument.Ref AS Ref
			|FROM
			|	&TableName AS AccountingDocument
			|WHERE
			|	&CounterpartyCondition
			|	AND AccountingDocument.Number LIKE &Number");
		Query.Text = StrReplace(Query.Text, "&TableName", TableName);
		If Common.HasObjectAttribute("Counterparty", Metadata.Documents[DocumentType]) Then
			Query.Text = StrReplace(Query.Text, "&CounterpartyCondition", "AccountingDocument.Counterparty = &Counterparty");
			Query.SetParameter("Counterparty", Counterparty);
		Else
			Query.Text = StrReplace(Query.Text, "&CounterpartyCondition", "TRUE");
		EndIf;
		Query.SetParameter("Number", "%" + Number_IncomingData + "%");
		
		If Not IsBlankString(Date_IncomingData) Then
			
			DateFromString = Date('00010101');
			ConvertStringToDate(DateFromString, Date_IncomingData);
			
			If ValueIsFilled(DateFromString) Then
				
				Query.Text = Query.Text + "
				|	AND AccountingDocument.Date Between &StartDate AND &EndDate";
				Query.SetParameter("StartDate", BegOfDay(DateFromString));
				Query.SetParameter("EndDate", EndOfDay(DateFromString));
				
			EndIf;
			
		EndIf;
		
		Query.Text = Query.Text + "
		|ORDER BY AccountingDocument.Date Desc";
		Selection = Query.Execute().Select();
		If Selection.Next() Then
			Document = Selection.Ref;
		Else
			Document = Documents[DocumentType].EmptyRef();
		EndIf;
	Else
		Document = Documents[DocumentType].EmptyRef();
	EndIf;
	
EndProcedure

Function UpperNoBlanks(StringData)
	
	Return Upper(StrReplace(StringData, " ", ""));
	
EndFunction

Function DefaultBillingDocumentType(IsAR, IsAdvance)
	
	If IsAR Then
		If IsAdvance Then
			MetaDoc = Metadata.Documents.PaymentReceipt;
		Else
			MetaDoc = Metadata.Documents.SalesInvoice;
		EndIf;
	Else
		If IsAdvance Then
			MetaDoc = Metadata.Documents.PaymentExpense;
		Else
			MetaDoc = Metadata.Documents.SupplierInvoice;
		EndIf;
	EndIf;
	
	Return MetaDoc.Presentation();
	
EndFunction

Function InvalidDocumentType()
	
	Return NStr("en = '<Invalid type>'; ru = '<Недопустимый тип>';pl = '<Niepoprawny typ>';es_ES = '<Tipo inválido>';es_CO = '<Tipo inválido>';tr = '<Geçersiz tür>';it = '<Tipo non valido>';de = '<Unzulässiger Typ>'");
	
EndFunction

Function ARAPDocumentTypes(IsAR)
	
	If IsAR Then
		TSName = "AccountsReceivable";
	Else
		TSName = "AccountsPayable";
	EndIf;
	
	DocMetadataTS = Metadata.Documents.OpeningBalanceEntry.TabularSections;
	TypeArray = DocMetadataTS[TSName].Attributes.Document.Type.Types();
	
	Return TypeArray;
	
EndFunction

Procedure MapContactPerson(Counterparty, ContactPerson, ContactPerson_IncomingData) Export
	
	If ValueIsFilled(Counterparty) AND ValueIsFilled(ContactPerson_IncomingData) Then
		
		CatalogRef = Catalogs.ContactPersons.FindByDescription(ContactPerson_IncomingData, True, , Counterparty);
		
		If ValueIsFilled(CatalogRef) Then
			
			ContactPerson = CatalogRef;
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure MapBank(Bank, Code, Description)
	
	If Not IsBlankString(Code) Then
		Bank = Catalogs.Banks.FindByCode(Code);
	EndIf;
	
	If Not ValueIsFilled(Bank) And Not IsBlankString(Description) Then
		Bank = Catalogs.Banks.FindByDescription(Description, True);
	EndIf;
	
EndProcedure

Procedure MapCurrency(Currency, Description, Code)
	
	If Not IsBlankString(Description) Then
		Currency = Catalogs.Currencies.FindByDescription(Description, True);
	EndIf;
	
	If Not ValueIsFilled(Currency) And Not IsBlankString(Code) Then
		Currency = Catalogs.Currencies.FindByCode(Code);
	EndIf;
	
EndProcedure

Procedure SupplimentCurrencyDataFromClassifier(Code, Description)
	
	XMLClassifier = DataProcessors.ImportCurrenciesRates.GetTemplate("NationalCurrencyClassifier").GetText();
	ClassifierTable = Common.ReadXMLToTable(XMLClassifier).Data;
	
	If IsBlankString(Code) And Not IsBlankString(Description) Then
		
		CCRecord = ClassifierTable.Find(Description, "CodeSymbol");
		If CCRecord <> Undefined Then
			Code = CCRecord.Code;
		EndIf;
		
	ElsIf IsBlankString(Description) And Not IsBlankString(Code) Then
		
		CCRecord = ClassifierTable.Find(Code, "Code");
		If CCRecord <> Undefined Then
			Description = CCRecord.CodeSymbol;
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure MapBankAccount(TableRow, Company, Currency)
	
	If ValueIsFilled(TableRow.Bank) Then
		
		Query = New Query;
		
		Query.Text =
		"SELECT TOP 1
		|	BankAccounts.Ref AS Ref
		|FROM
		|	Catalog.BankAccounts AS BankAccounts
		|WHERE
		|	BankAccounts.Owner = &Owner
		|	AND BankAccounts.Bank = &Bank
		|	AND NOT BankAccounts.DeletionMark
		|	AND (BankAccounts.CashCurrency = &CashCurrency
		|			OR &CashCurrency = UNDEFINED)
		|	AND (BankAccounts.IBAN = &IBAN
		|				AND &IBAN <> """"
		|			OR BankAccounts.AccountNo = &AccountNo
		|				AND &AccountNo <> """")";
		
		Query.SetParameter("Owner", Company);
		Query.SetParameter("Bank", TableRow.Bank);
		Query.SetParameter("CashCurrency", Currency);
		Query.SetParameter("IBAN", TableRow.IBAN);
		Query.SetParameter("AccountNo", TableRow.AccountNo);
		
		Sel = Query.Execute().Select();
		If Sel.Next() Then
			
			TableRow.Account = Sel.Ref;
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure MapCashAccount(TableRow, Currency)
	
	If IsBlankString(TableRow.Description)
		Or Currency = Catalogs.Currencies.EmptyRef() Then
		Return;
	EndIf;
	
	Query = New Query;
	
	Query.Text =
	"SELECT
	|	CashAccounts.Ref AS Ref
	|FROM
	|	Catalog.CashAccounts AS CashAccounts
	|WHERE
	|	CashAccounts.Description = &Description
	|	AND NOT CashAccounts.DeletionMark
	|	AND (CashAccounts.CurrencyByDefault = &Currency
	|			OR &Currency = UNDEFINED)";
	
	Query.SetParameter("Description", TableRow.Description);
	Query.SetParameter("Currency", Currency);
	
	Sel = Query.Execute().Select();
	
	If Sel.Next() Then
		TableRow.Account = Sel.Ref;
	EndIf;
	
EndProcedure

// Chart of accounts

Procedure CompareAccount(Account, Code, AccountDescription, ChartsOfAccountsManager)
	
	ValueWasMapped = False;
	
	If ValueIsFilled(Code) Then
		
		ChartsOfAccountsRef = ChartsOfAccountsManager.FindByCode(Code);
		If NOT ChartsOfAccountsRef.IsEmpty() Then
			
			ValueWasMapped = True;
			Account = ChartsOfAccountsRef;
			
		EndIf;
		
	EndIf;
	
	If NOT ValueWasMapped AND ValueIsFilled(AccountDescription) Then
		
		ChartsOfAccountsRef = ChartsOfAccountsManager.FindByDescription(AccountDescription, True);
		If NOT ChartsOfAccountsRef.IsEmpty() Then
			
			ValueWasMapped = True;
			Account = ChartsOfAccountsRef;
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure CompareMasterAccount(Account, Code, AccountDescription, ChartOfAccounts, ChartsOfAccountsManager)
	
	ValueWasMapped = False;
	
	If ValueIsFilled(Code) Then
		
		ChartsOfAccountsRef = ChartsOfAccountsManager.FindByCodeAndChartOfAccounts(Code, ChartOfAccounts);
		If Not ChartsOfAccountsRef.IsEmpty() Then
			
			ValueWasMapped = True;
			Account = ChartsOfAccountsRef;
			
		EndIf;
		
	EndIf;
	
	If Not ValueWasMapped And ValueIsFilled(AccountDescription) Then
		
		ChartsOfAccountsRef = ChartsOfAccountsManager.FindByDescriptionAndChartOfAccounts(AccountDescription, ChartOfAccounts);
		If Not ChartsOfAccountsRef.IsEmpty() Then
			
			ValueWasMapped = True;
			Account = ChartsOfAccountsRef;
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure MapTypeOfGLAccount(TypeOfAccount, TypeOfAccount_IncomingData, DefaultValue) Export
	
	MapEnumeration("GLAccountsTypes", TypeOfAccount, TypeOfAccount_IncomingData, DefaultValue);
	
EndProcedure

Procedure MapChartOfAccounts(ChartOfAccounts, ChartOfAccounts_IncomingData, DefaultValue)
	
	CatalogByName("ChartsOfAccounts", ChartOfAccounts, ChartOfAccounts_IncomingData, DefaultValue);

EndProcedure

Procedure MapMethodOfDistribution(MethodOfDistribution, MethodOfDistribution_IncomingData, DefaultValue) Export
	
	MapEnumeration("CostAllocationMethod", MethodOfDistribution, MethodOfDistribution_IncomingData, DefaultValue);
	
EndProcedure

Procedure MapFinancialStatement(FinancialStatement, FinancialStatement_IncomingData, DefaultValue) Export
	
	MapEnumeration("FinancialStatement", FinancialStatement, FinancialStatement_IncomingData, DefaultValue);
	
EndProcedure

Procedure MapAccountType(AcountTypeValue, AccountTypeValue_IncomingData, DefaultValue) Export
	
	If AccountTypeValue_IncomingData = NStr("en = 'Dr'; ru = 'Дт';pl = 'Wn';es_ES = 'Débito';es_CO = 'Débito';tr = 'Borç';it = 'Deb';de = 'Soll'") Then
		AcountTypeValue = AccountType.Active;
	ElsIf AccountTypeValue_IncomingData = NStr("en = '(Cr)'; ru = '(Кт)';pl = '(Ma)';es_ES = '(Crédito)';es_CO = '(Crédito)';tr = 'Alacak';it = '(Cred.)';de = '(Haben)'") Then
		AcountTypeValue = AccountType.Passive;
	Else
		MapSystemEnumeration(AccountType, AcountTypeValue, AccountTypeValue_IncomingData, DefaultValue)
	EndIf;
	
EndProcedure

Procedure MapAnalyticalDimensionsSets(AnalyticalDimensionsSet, AnalyticalDimensionsSet_IncomingData, DefaultValue)
	
	CatalogByName("AnalyticalDimensionsSets", AnalyticalDimensionsSet, AnalyticalDimensionsSet_IncomingData, DefaultValue)
	
EndProcedure

// Accounting entries
Procedure MapExtDimension(ExtDimension, AdditionalAttributes, Error)
	
	Account = AdditionalAttributes.Account;
	LineNumber = AdditionalAttributes.LineNumber;
	TypeString = AdditionalAttributes.TypeString;
	Number = AdditionalAttributes.Number;
	DateString = AdditionalAttributes.DateString;
	Code = AdditionalAttributes.Code;
	Description = AdditionalAttributes.Description;
	
	If Not ValueIsFilled(Account)
		Or Not (ValueIsFilled(TypeString)
		Or ValueIsFilled(Number)
		Or ValueIsFilled(DateString)
		Or ValueIsFilled(Code)
		Or ValueIsFilled(Description)) Then
		
		Return;
		
	EndIf;
	
	TypeString = TrimAll(TypeString);
	Number = TrimAll(Number);
	DateString = TrimAll(DateString);
	Code = TrimAll(Code);
	Description = TrimAll(Description);
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	MasterChartOfAccountsAnalyticalDimensions.AnalyticalDimension.ValueType AS ValueType
	|FROM
	|	ChartOfAccounts.MasterChartOfAccounts.AnalyticalDimensions AS MasterChartOfAccountsAnalyticalDimensions
	|WHERE
	|	MasterChartOfAccountsAnalyticalDimensions.Ref = &Account
	|	AND MasterChartOfAccountsAnalyticalDimensions.LineNumber = &LineNumber";
	
	Query.SetParameter("Account", Account);
	Query.SetParameter("LineNumber", LineNumber);
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		
		Error = ?(Not IsBlankString(TypeString) Or Not IsBlankString(Number)
			Or Not IsBlankString(DateString) Or Not IsBlankString(Code)
			Or Not IsBlankString(Description), "INVALID_INPUT", "");
		
		Return;
		
	EndIf;
	
	Selection = QueryResult.Select();
	Selection.Next();
	ValueType = Selection.ValueType;
	TypesMap = New Map;
	
	For Each Type In ValueType.Types() Do
		
		TypeMetadata = Metadata.FindByType(Type);
		TypesMap.Insert(Upper(TypeMetadata.Name), TypeMetadata.FullName());
		TypesMap.Insert(Upper(TypeMetadata.FullName()), TypeMetadata.FullName());
		TypesMap.Insert(Upper(TypeMetadata.Presentation()), TypeMetadata.FullName());
		TypesMap.Insert(Upper(TypeMetadata.ObjectPresentation), TypeMetadata.FullName());
		
	EndDo;
	
	MetadataFullName = TypesMap.Get(
		StrReplace(StrReplace(Upper(TypeString), " ", ""), Chars.NBSp, ""));
	
	If MetadataFullName = Undefined Then
		
		If ValueType.Types().Count() > 1 Then
			
			Error = "AMBIGUOUS_TYPE";
			Return;
			
		Else
			
			Type = ValueType.Types()[0];
			MetadataFullName =  Metadata.FindByType(Type).FullName();
			
		EndIf;
		
	EndIf;
	
	MetadataObject = Metadata.FindByFullName(MetadataFullName);
	If Not AccessRight("View", MetadataObject) Then
		Return;
	EndIf;
	
	ManagerModule = Common.ObjectManagerByFullName(MetadataFullName);
	Value = ManagerModule.EmptyRef();
	
	If Common.IsCatalog(MetadataObject) Then
		
		If IsBlankString(Code) And IsBlankString(Description) Then
			
			Error = "INVALID_INPUT";
			Return;
			
		EndIf;
		
		Query = New Query;
		Query.Text =
		"SELECT ALLOWED TOP 1
		|	Table.Ref AS Ref
		|FROM
		|	&MetadataTable AS Table
		|WHERE
		|	(Table.Code = &Code
		|				AND &FindByCode
		|			OR Table.Description = &Description
		|				AND &FindByDescription)";
		
		Query.SetParameter("Code", Code);
		Query.SetParameter("Description", Description);
		Query.SetParameter("FindByCode", Not IsBlankString(Code));
		Query.SetParameter("FindByDescription", Not IsBlankString(Description));
		
	ElsIf Common.IsDocument(MetadataObject) Then
		
		If IsBlankString(Number) Or IsBlankString(DateString) Then
			
			Error = "INVALID_INPUT";
			Return;
			
		EndIf;
		
		Date = Undefined;
		Try
			ConvertStringToDate(Date, DateString);
		Except
			Error = "NOT_MATCHED";
			Return;
		EndTry;
		
		Query = New Query;
		Query.Text =
		"SELECT ALLOWED TOP 1
		|	Table.Ref AS Ref
		|FROM
		|	&MetadataTable AS Table
		|WHERE
		|	Table.Date BETWEEN &StartDate AND &EndDate
		|	AND Table.Number = &Number";
		
		Query.SetParameter("Number", Number);
		Query.SetParameter("StartDate", BegOfDay(Date));
		Query.SetParameter("EndDate", EndOfDay(Date));
		
	EndIf;
	
	Query.Text = StrReplace(Query.Text, "&MetadataTable", MetadataFullName);
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		Value = Selection.Ref;
	Else
		Error = "NOT_MATCHED";
	EndIf;
	
	ExtDimension = Value;
	
EndProcedure

Procedure MapAccountingRecordType(RecordType, RecordType_IncomingData)
	
	RecordTypeString = TrimAll(Upper(RecordType_IncomingData));
	
	DebitValue = NStr("en = 'DR'; ru = 'ДТ';pl = 'WN';es_ES = 'DR';es_CO = 'DR';tr = 'Borç';it = 'Deb';de = 'Soll'");
	CreditValue = NStr("en = 'CR'; ru = 'КТ';pl = 'MA';es_ES = 'CR';es_CO = 'CR';tr = 'Alacak';it = 'Cred';de = 'Haben'");
	
	If RecordTypeString = Upper(Enums.AccountingRecordType.Debit) Or RecordTypeString = DebitValue Then
		RecordType = Enums.AccountingRecordType.Debit;
	ElsIf RecordTypeString = Upper(Enums.AccountingRecordType.Credit) Or RecordTypeString = CreditValue Then
		RecordType = Enums.AccountingRecordType.Credit;
	Else
		RecordType = Enums.AccountingRecordType.EmptyRef();
	EndIf;
	
EndProcedure

// SalesTaxRates

Procedure MapTaxTypes(TaxType, TaxType_IncomingData, DefaultValue) Export
	
	CatalogByName("TaxTypes", TaxType, TaxType_IncomingData, DefaultValue);
	
EndProcedure

// begin Drive.FullVersion

// RoutingTemplates

Procedure MapActivity(Activity, Activity_IncomingData)
	
	CatalogByName("ManufacturingActivities", Activity, Activity_IncomingData);
	
EndProcedure

// end Drive.FullVersion

Procedure MapInventoryAcquisitionDocumentByNumberDate(Document, DocumentTypeName, Number_IncomingData, Date_IncomingData)
	
	If IsBlankString(Number_IncomingData) Then
		Return;
	EndIf;
	
	MetadataOpeningBalanceEntry = Metadata.Documents.OpeningBalanceEntry;
	InventoryTabSection = MetadataOpeningBalanceEntry.TabularSections.Inventory;
	DocumentAttribute = InventoryTabSection.Attributes.Document;
	TypeArray = DocumentAttribute.Type.Types();
	MapDocumentNames = GetDocumentTypesMap(TypeArray);
	DocumentType = MapDocumentNames.Get(UpperNoBlanks(DocumentTypeName));
	If DocumentType = Undefined Then
		Return;
	EndIf;
	
	TableName = "Document." + DocumentType;
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED TOP 1
	|	AccountingDocument.Ref AS Ref
	|FROM
	|	&TableName AS AccountingDocument
	|WHERE
	|	AccountingDocument.Number LIKE &Number";
	
	Query.SetParameter("Number", "%" + Number_IncomingData + "%");
	
	Query.Text = StrReplace(Query.Text, "&TableName", TableName);
	
	If Not IsBlankString(Date_IncomingData) Then
		
		DateFromString = Date('00010101');
		ConvertStringToDate(DateFromString, Date_IncomingData);
		
		If ValueIsFilled(DateFromString) Then
			
			Query.Text = Query.Text + "
			|	AND AccountingDocument.Date Between &StartDate AND &EndDate";
			Query.SetParameter("StartDate", BegOfDay(DateFromString));
			Query.SetParameter("EndDate", EndOfDay(DateFromString));
			
		EndIf;
		
	EndIf;
	
	Query.Text = Query.Text + "
		|ORDER BY AccountingDocument.Date Desc";
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Document = Selection.Ref;
	Else
		Document = Documents[DocumentType].EmptyRef();
	EndIf;
	
EndProcedure

Function GetDocumentTypesMap(TypeArray)
	
	MapDocumentNames = New Map;
	
	For Each DocType In TypeArray Do
		
		MetaDoc = Metadata.FindByType(DocType);
		
		DocName = MetaDoc.Name;
		
		MapDocumentNames.Insert(UpperNoBlanks(DocName), DocName);
		
		If Not IsBlankString(MetaDoc.Synonym) Then
			MapDocumentNames.Insert(UpperNoBlanks(MetaDoc.Synonym), DocName);
		EndIf;
		
		If Not IsBlankString(MetaDoc.ObjectPresentation) Then
			MapDocumentNames.Insert(UpperNoBlanks(MetaDoc.ObjectPresentation), DocName);
		EndIf;
		
		If Not IsBlankString(MetaDoc.ExtendedObjectPresentation) Then
			MapDocumentNames.Insert(UpperNoBlanks(MetaDoc.ExtendedObjectPresentation), DocName);
		EndIf;
		
		If Not IsBlankString(MetaDoc.ListPresentation) Then
			MapDocumentNames.Insert(UpperNoBlanks(MetaDoc.ListPresentation), DocName);
		EndIf;
		
		If Not IsBlankString(MetaDoc.ExtendedListPresentation) Then
			MapDocumentNames.Insert(UpperNoBlanks(MetaDoc.ExtendedListPresentation), DocName);
		EndIf;
		
	EndDo;
	
	Return MapDocumentNames;
	
EndFunction

#EndRegion
 

