#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

// Function generates the structure of
// the Return value available rules table:
//  ValueTable - Columns:
//  	1. Name							- is a
//  	rule identifier, 2. DynamicRuleKey		- additional identifier for rights generated automatically (for example, Additional attributes,
//  	contact information kinds), 3 IsFolder					- shows that this rule is not used
//  	in the settings, 4. Presentation				- user presentation
//  	of a rule, 5. MultipleUse	- shows that several values
//  	can be specified, 6. AvailableComparisonTypes		- values list of the DataLayoutComparisonType type - comparison kinds used
//  	for rule, 7. ComparisonType					- default comparison
//  	kind, 8. ValueProperties				- properties of form field item (table columns) connected to specified comparison values.
Function RulesDescription() Export
	
	Rules = New ValueTree;
	Rules.Columns.Add("Name",						New TypeDescription("String", New StringQualifiers(50)));
	Rules.Columns.Add("DynamicRuleKey",				New TypeDescription("ChartOfCharacteristicTypesRef.AdditionalAttributesAndInfo,CatalogRef.ContactInformationKinds"));
	Rules.Columns.Add("Presentation",				New TypeDescription("String", New StringQualifiers(100)));
	Rules.Columns.Add("IsFolder",					New TypeDescription("Boolean"));
	Rules.Columns.Add("MultipleUse",				New TypeDescription("Boolean"));
	Rules.Columns.Add("AvailableComparisonTypes",	New TypeDescription("ValueList"));
	Rules.Columns.Add("ComparisonType",				New TypeDescription("DataCompositionComparisonType"));
	Rules.Columns.Add("ValueProperties",			New TypeDescription("Structure"));
	
	Return Rules;
	
EndFunction

// Function - Receive available
// rules of the Return value filter:
//  ValueTable - For the description of the table fields, see a comment to the RulesDescription() function
Function GetAvailableFilterRules() Export
	
	Rules = RulesDescription();
	
	TypeDescriptionRow				= New TypeDescription("String",,,,New StringQualifiers(100));
	CurrencyTypeDescription			= New TypeDescription("Number",,,New NumberQualifiers(15,2));
	TypeDescriptionStandardDate		= New TypeDescription("StandardBeginningDate");
	TypeDescriptionStandardPeriod	= New TypeDescription("StandardPeriod");
	
	#Region CounterpartyAttributes
	
	CounterpartyPropertiesGroup = Rules.Rows.Add();
	CounterpartyPropertiesGroup.Name = "CounterpartyAttributes";
	CounterpartyPropertiesGroup.Presentation = NStr("en = 'Counterparty'; ru = 'Контрагент';pl = 'Kontrahent';es_ES = 'Contraparte';es_CO = 'Contraparte';tr = 'Cari hesap';it = 'Controparte';de = 'Geschäftspartner'");
	CounterpartyPropertiesGroup.IsFolder = True;
	
	NewRule = CounterpartyPropertiesGroup.Rows.Add();
	NewRule.Name = "Tag";
	NewRule.Presentation = NStr("en = 'Tag'; ru = 'Тег';pl = 'Etykieta';es_ES = 'Etiqueta';es_CO = 'Etiqueta';tr = 'Etiket';it = 'Etichetta';de = 'Tag'");
	NewRule.IsFolder = False;
	NewRule.MultipleUse = False;
	NewRule.ValueProperties.Insert("TypeRestriction", New TypeDescription("CatalogRef.Tags"));
	NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
	SegmentsServer.AddComparisonTypes(NewRule, "Equal,NotEqual,InList,NotInList");
	
	NewRule = CounterpartyPropertiesGroup.Rows.Add();
	NewRule.Name = "CounterpartyType";
	NewRule.Presentation = Metadata.Catalogs.Counterparties.Attributes.LegalEntityIndividual.Synonym;
	NewRule.IsFolder = False;
	NewRule.MultipleUse = False;
	NewRule.ValueProperties.Insert("TypeRestriction", New TypeDescription("EnumRef.CounterpartyType"));
	NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
	SegmentsServer.AddComparisonTypes(NewRule, "Equal");
	
	NewRule = CounterpartyPropertiesGroup.Rows.Add();
	NewRule.Name = "Group";
	NewRule.Presentation = Metadata.Catalogs.Counterparties.StandardAttributes.Parent.Synonym;
	NewRule.IsFolder = False;
	NewRule.MultipleUse = False;
	NewRule.ValueProperties.Insert("TypeRestriction", New TypeDescription("CatalogRef.Counterparties"));
	NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Folders);
	SegmentsServer.AddComparisonTypes(NewRule, "Equal,NotEqual,InHierarchy,NotInHierarchy,InList,NotInList", 3);
	
	NewRule = CounterpartyPropertiesGroup.Rows.Add();
	NewRule.Name = "CreationDate";
	NewRule.Presentation = Metadata.Catalogs.Counterparties.Attributes.CreationDate;
	NewRule.IsFolder = False;
	NewRule.MultipleUse = True;
	NewRule.ValueProperties.Insert("TypeRestriction", TypeDescriptionStandardDate);
	NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
	SegmentsServer.AddComparisonTypes(NewRule, "Equal,NotEqual,Greater,GreaterOrEqual,Less,LessOrEqual", 4);
	
	NewRule = CounterpartyPropertiesGroup.Rows.Add();
	NewRule.Name = "Comment";
	NewRule.Presentation = Metadata.Catalogs.Counterparties.Attributes.Comment;
	NewRule.IsFolder = False;
	NewRule.MultipleUse = False;
	NewRule.ValueProperties.Insert("TypeRestriction", TypeDescriptionRow);
	NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
	SegmentsServer.AddComparisonTypes(NewRule, "BeginsWith,NotBeginsWith,Contains,NotContains", 3);
	
	NewRule = CounterpartyPropertiesGroup.Rows.Add();
	NewRule.Name = "Responsible";
	NewRule.Presentation = Metadata.Catalogs.Counterparties.Attributes.Responsible.Synonym;
	NewRule.IsFolder = False;
	NewRule.MultipleUse = False;
	NewRule.ValueProperties.Insert("TypeRestriction", New TypeDescription("CatalogRef.Employees"));
	NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
	SegmentsServer.AddComparisonTypes(NewRule, "Equal,NotEqual,InList,NotInList,InGroup,NotInGroup,Filled,NotFilled");
	
	NewRule = CounterpartyPropertiesGroup.Rows.Add();
	NewRule.Name = "SalesRep";
	NewRule.Presentation = Metadata.Catalogs.Counterparties.Attributes.SalesRep.Synonym;
	NewRule.IsFolder = False;
	NewRule.MultipleUse = False;
	NewRule.ValueProperties.Insert("TypeRestriction", New TypeDescription("CatalogRef.Employees"));
	NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
	SegmentsServer.AddComparisonTypes(NewRule, "Equal,NotEqual,InList,NotInList,InGroup,NotInGroup,Filled,NotFilled");
	
	NewRule = CounterpartyPropertiesGroup.Rows.Add();
	NewRule.Name = "CashAssetType";
	NewRule.Presentation = Metadata.Catalogs.Counterparties.Attributes.CashAssetType.Synonym;
	NewRule.IsFolder = False;
	NewRule.MultipleUse = False;
	NewRule.ValueProperties.Insert("TypeRestriction", New TypeDescription("EnumRef.CashAssetTypes"));
	NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
	SegmentsServer.AddComparisonTypes(NewRule, "Equal,NotEqual,InList,NotInList,InGroup,NotInGroup,Filled,NotFilled");
	
	NewRule = CounterpartyPropertiesGroup.Rows.Add();
	NewRule.Name = "PriceKind";
	NewRule.Presentation = Metadata.Catalogs.Counterparties.Attributes.PriceKind.Synonym;
	NewRule.IsFolder = False;
	NewRule.MultipleUse = False;
	NewRule.ValueProperties.Insert("TypeRestriction", New TypeDescription("CatalogRef.PriceTypes"));
	NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
	SegmentsServer.AddComparisonTypes(NewRule, "Equal,NotEqual,InList,NotInList,InGroup,NotInGroup,Filled,NotFilled");
	
	NewRule = CounterpartyPropertiesGroup.Rows.Add();
	NewRule.Name = "CounterpartyKind";
	NewRule.Presentation = NStr("en = 'Counterparty kind'; ru = 'Вид контрагента';pl = 'Rodzaj kontrahenta';es_ES = 'Clase de contraparte';es_CO = 'Clase de contraparte';tr = 'Cari hesap türü';it = 'Tipologia di controparte';de = 'Art des Geschäftspartners'");
	NewRule.IsFolder = False;
	NewRule.MultipleUse = False;
	NewRule.ValueProperties.Insert("TypeRestriction", New TypeDescription("String"));
	NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
	SegmentsServer.AddComparisonTypes(NewRule, "Equal,NotEqual,InList,NotInList");
	
	#EndRegion
	
	#Region AdditionalAttributes
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	AdditionalAttributesAndInformation.Ref AS Ref,
	|	AdditionalAttributesAndInformation.Title AS Title,
	|	AdditionalAttributesAndInformation.ValueType AS ValueType,
	|	AdditionalAttributesAndInformation.FormatProperties AS FormatProperties
	|FROM
	|	ChartOfCharacteristicTypes.AdditionalAttributesAndInfo AS AdditionalAttributesAndInformation
	|WHERE
	|	AdditionalAttributesAndInformation.DeletionMark = FALSE
	|	AND NOT AdditionalAttributesAndInformation.IsAdditionalInfo
	|	AND AdditionalAttributesAndInformation.PropertySet = VALUE(Catalog.AdditionalAttributesAndInfoSets.Catalog_Counterparties)
	|
	|ORDER BY
	|	AdditionalAttributesAndInformation.Title";
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		NewRule = CounterpartyPropertiesGroup.Rows.Add();
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
			SegmentsServer.AddComparisonTypes(NewRule, "Greater,GreaterOrEqual,Less,LessOrEqual");
			NewRule.MultipleUse = True;
		EndIf;
		
		If Selection.ValueType.ContainsType(Type("String")) Then
			SegmentsServer.AddComparisonTypes(NewRule, "BeginsWith,NotBeginsWith,Contains,NotContains");
		EndIf;
		
		For Each ValueType In Selection.ValueType.Types() Do
			If Common.IsReference(ValueType) Then
				SegmentsServer.AddComparisonTypes(NewRule, "InList,NotInList,Filled,NotFilled");
				Break;
			EndIf;
		EndDo;
		
	EndDo;

	#EndRegion
	
	#Region ContactInformation
	
	GroupContactInformation = Rules.Rows.Add();
	GroupContactInformation.Name = "CounterpartyContactInformation";
	GroupContactInformation.Presentation = NStr("en = 'Contact information'; ru = 'Контактная информация';pl = 'Informacje kontaktowe';es_ES = 'Información de contacto';es_CO = 'Información de contacto';tr = 'İletişim bilgileri';it = 'Informazioni di contatto';de = 'Kontakt Informationen'");
	GroupContactInformation.IsFolder = True;
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	ContactInformationTypes.Type,
	|	ContactInformationTypes.Ref,
	|	ContactInformationTypes.Description
	|FROM
	|	Catalog.ContactInformationKinds AS ContactInformationTypes
	|WHERE
	|	ContactInformationTypes.DeletionMark = FALSE
	|	AND ContactInformationTypes.Parent = VALUE(Catalog.ContactInformationKinds.CatalogCounterparties)
	|
	|ORDER BY
	|	ContactInformationTypes.AdditionalOrderingAttribute";
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		If Selection.Type = Enums.ContactInformationTypes.Address Then
			
			RuleAddress = GroupContactInformation.Rows.Add();
			RuleAddress.Name = "ContactInformationKindPresentation";
			RuleAddress.DynamicRuleKey = Selection.Ref;
			RuleAddress.IsFolder = False;
			RuleAddress.MultipleUse = False;
			RuleAddress.Presentation = Selection.Description;
			RuleAddress.ValueProperties.Insert("TypeRestriction", TypeDescriptionRow);
			RuleAddress.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
			SegmentsServer.AddComparisonTypes(RuleAddress, "BeginsWith,NotBeginsWith,Contains,NotContains", 3);
			
			NewRule = RuleAddress.Rows.Add();
			NewRule.Name = "ContactInformationKindCountry";
			NewRule.DynamicRuleKey = Selection.Ref;
			NewRule.IsFolder = False;
			NewRule.MultipleUse = False;
			NewRule.Presentation = NStr("en = 'Country'; ru = 'Страна';pl = 'Kraj';es_ES = 'País';es_CO = 'País';tr = 'Ülke';it = 'Paese';de = 'Land'") + " (" + Lower(RuleAddress.Presentation) + ")";
			NewRule.ValueProperties.Insert("TypeRestriction", TypeDescriptionRow);
			NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
			SegmentsServer.AddComparisonTypes(NewRule, "BeginsWith,NotBeginsWith,Contains,NotContains", 3);
			
			NewRule = RuleAddress.Rows.Add();
			NewRule.Name = "ContactInformationKindState";
			NewRule.DynamicRuleKey = Selection.Ref;
			NewRule.IsFolder = False;
			NewRule.MultipleUse = False;
			NewRule.Presentation = NStr("en = 'Region'; ru = 'Область';pl = 'Region';es_ES = 'Región';es_CO = 'Región';tr = 'Bölge';it = 'Regione';de = 'Region'") + " (" + Lower(RuleAddress.Presentation) + ")";
			NewRule.ValueProperties.Insert("TypeRestriction", TypeDescriptionRow);
			NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
			SegmentsServer.AddComparisonTypes(NewRule, "BeginsWith,NotBeginsWith,Contains,NotContains", 3);
			
			NewRule = RuleAddress.Rows.Add();
			NewRule.Name = "ContactInformationKindCity";
			NewRule.DynamicRuleKey = Selection.Ref;
			NewRule.IsFolder = False;
			NewRule.MultipleUse = False;
			NewRule.Presentation = NStr("en = 'City'; ru = 'Город';pl = 'Miasto';es_ES = 'Ciudad';es_CO = 'Ciudad';tr = 'Şehir';it = 'Città';de = 'Stadt'") + " (" + Lower(RuleAddress.Presentation) + ")";
			NewRule.ValueProperties.Insert("TypeRestriction", TypeDescriptionRow);
			NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
			SegmentsServer.AddComparisonTypes(NewRule, "BeginsWith,NotBeginsWith,Contains,NotContains", 3);
			
		EndIf;
		
	EndDo;
	
	#EndRegion
	
	#Region Events
	
	EventGroup = Rules.Rows.Add();
	EventGroup.Name = "Events";
	EventGroup.Presentation = NStr("en = 'Events'; ru = 'События';pl = 'Wydarzenia';es_ES = 'Eventos';es_CO = 'Eventos';tr = 'Etkinlikler';it = 'Eventi';de = 'Ereignisse'");
	EventGroup.IsFolder = True;
	
	NewRule = EventGroup.Rows.Add();
	NewRule.Name = "EventsDateLast";
	NewRule.Presentation = NStr("en = 'Last event date'; ru = 'Дата последнего события';pl = 'Data ostatniego wydarzenia';es_ES = 'Fecha del último evento';es_CO = 'Fecha del último evento';tr = 'Son etkinlik tarihi';it = 'Data ultimo evento';de = 'Letztes Ereignisdatum'");
	NewRule.IsFolder = False;
	NewRule.MultipleUse = True;
	NewRule.ValueProperties.Insert("TypeRestriction", TypeDescriptionStandardDate);
	NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
	SegmentsServer.AddComparisonTypes(NewRule, "Equal,NotEqual,Greater,GreaterOrEqual,Less,LessOrEqual", 5);
	
	RuleEventsQuantity = EventGroup.Rows.Add();
	RuleEventsQuantity.Name = "EventsQuantity";
	RuleEventsQuantity.Presentation = NStr("en = 'Number of events'; ru = 'Количество событий';pl = 'Ilość wydarzeń';es_ES = 'Número de eventos';es_CO = 'Número de eventos';tr = 'Etkinlik sayısı';it = 'Numero di eventi';de = 'Anzahl der Ereignisse'");
	RuleEventsQuantity.IsFolder = False;
	RuleEventsQuantity.MultipleUse = True;
	RuleEventsQuantity.ValueProperties.Insert("TypeRestriction", New TypeDescription("Number"));
	RuleEventsQuantity.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
	SegmentsServer.AddComparisonTypes(RuleEventsQuantity, "Equal,NotEqual,Greater,GreaterOrEqual,Less,LessOrEqual", 3);
	
	NewRule = RuleEventsQuantity.Rows.Add();
	NewRule.Name = "EventsQuantityPeriod";
	NewRule.Presentation = NStr("en = 'For the period'; ru = 'За период';pl = 'Na okres';es_ES = 'Por el período';es_CO = 'Por el período';tr = 'Dönem için';it = 'Per il periodo';de = 'Für den Zeitraum'") + " (" + Lower(RuleEventsQuantity.Presentation) + ")";
	NewRule.IsFolder = False;
	NewRule.MultipleUse = False;
	NewRule.ValueProperties.Insert("TypeRestriction", TypeDescriptionStandardPeriod);
	NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
	SegmentsServer.AddComparisonTypes(NewRule, "Equal");
	
	#EndRegion
	
	#Region SalesOrders
	
	GroupOrders = Rules.Rows.Add();
	GroupOrders.Name = "SalesOrders";
	GroupOrders.Presentation = NStr("en = 'Sales orders'; ru = 'Заказы покупателей';pl = 'Zamówienia sprzedaży';es_ES = 'Pedidos de cliente';es_CO = 'Órdenes de ventas';tr = 'Satış siparişleri';it = 'Ordini Cliente';de = 'Kundenaufträge'");
	GroupOrders.IsFolder = True;
	
	NewRule = GroupOrders.Rows.Add();
	NewRule.Name = "SalesOrdersDateLast";
	NewRule.Presentation = NStr("en = 'Last order date'; ru = 'Дата последнего заказа';pl = 'Data ostatniego zlecenia';es_ES = 'Fecha del último pedido';es_CO = 'Fecha del último pedido';tr = 'Son sipariş tarihi';it = 'Data ultimo ordine';de = 'Datum der letzten Bestellung'");
	NewRule.IsFolder = False;
	NewRule.MultipleUse = True;
	NewRule.ValueProperties.Insert("TypeRestriction", TypeDescriptionStandardDate);
	NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
	SegmentsServer.AddComparisonTypes(NewRule, "Equal,NotEqual,Greater,GreaterOrEqual,Less,LessOrEqual", 5);
	
	RuleOrdersQuantity = GroupOrders.Rows.Add();
	RuleOrdersQuantity.Name = "SalesOrdersQuantity";
	RuleOrdersQuantity.Presentation = NStr("en = 'Number of orders'; ru = 'Количество заказов';pl = 'Ilość zamówień';es_ES = 'Número de órdenes';es_CO = 'Número de órdenes';tr = 'Sipariş sayısı';it = 'Numero degli ordini';de = 'Anzahl der Bestellungen'");
	RuleOrdersQuantity.IsFolder = False;
	RuleOrdersQuantity.MultipleUse = True;
	RuleOrdersQuantity.ValueProperties.Insert("TypeRestriction", New TypeDescription("Number"));
	RuleOrdersQuantity.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
	SegmentsServer.AddComparisonTypes(RuleOrdersQuantity, "Equal,NotEqual,Greater,GreaterOrEqual,Less,LessOrEqual", 3);
	
	NewRule = RuleOrdersQuantity.Rows.Add();
	NewRule.Name = "SalesOrdersQuantityPeriod";
	NewRule.Presentation = NStr("en = 'For the period'; ru = 'За период';pl = 'Na okres';es_ES = 'Por el período';es_CO = 'Por el período';tr = 'Dönem için';it = 'Per il periodo';de = 'Für den Zeitraum'") + " (" + Lower(RuleOrdersQuantity.Presentation) + ")";
	NewRule.IsFolder = False;
	NewRule.MultipleUse = False;
	NewRule.ValueProperties.Insert("TypeRestriction", TypeDescriptionStandardPeriod);
	NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
	SegmentsServer.AddComparisonTypes(NewRule, "Equal");
	
	#EndRegion
	
	#Region InvoicesForPayment
	
	Account_sGroup = Rules.Rows.Add();
	Account_sGroup.Name = "InvoicesForPayment";
	Account_sGroup.Presentation = NStr("en = 'Quotation'; ru = 'Коммерческие предложения';pl = 'Oferta cenowa';es_ES = 'Presupuesto';es_CO = 'Presupuesto';tr = 'Teklif';it = 'Preventivo';de = 'Angebot'");
	Account_sGroup.IsFolder = True;
	
	NewRule = Account_sGroup.Rows.Add();
	NewRule.Name = "InvoicesForPaymentLastDate";
	NewRule.Presentation = NStr("en = 'Last quotation date'; ru = 'Дата последнего коммерческого предложения';pl = 'Data ostatniej oferty cenowej';es_ES = 'Fecha del último presupuesto';es_CO = 'Fecha del último presupuesto';tr = 'Son teklif tarihi';it = 'Data dell''ultimo preventivo';de = 'Letztes Angebotsdatum'");
	NewRule.IsFolder = False;
	NewRule.MultipleUse = True;
	NewRule.ValueProperties.Insert("TypeRestriction", TypeDescriptionStandardDate);
	NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
	SegmentsServer.AddComparisonTypes(NewRule, "Equal,NotEqual,Greater,GreaterOrEqual,Less,LessOrEqual", 5);
	
	RuleAccountsQuantity = Account_sGroup.Rows.Add();
	RuleAccountsQuantity.Name = "InvoicesForPaymentQuantity";
	RuleAccountsQuantity.Presentation = NStr("en = 'Number of quotations'; ru = 'Количество коммерческих предложений';pl = 'Ilość ofert cenowych';es_ES = 'Número de presupuestos';es_CO = 'Número de presupuestos';tr = 'Teklif sayısı';it = 'Numero di preventivi';de = 'Anzahl der Angebote'");
	RuleAccountsQuantity.IsFolder = False;
	RuleAccountsQuantity.MultipleUse = True;
	RuleAccountsQuantity.ValueProperties.Insert("TypeRestriction", New TypeDescription("Number"));
	RuleAccountsQuantity.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
	SegmentsServer.AddComparisonTypes(RuleAccountsQuantity, "Equal,NotEqual,Greater,GreaterOrEqual,Less,LessOrEqual", 3);
	
	NewRule = RuleAccountsQuantity.Rows.Add();
	NewRule.Name = "InvoicesForPaymentQuantityPeriod";
	NewRule.Presentation = NStr("en = 'For the period'; ru = 'За период';pl = 'Na okres';es_ES = 'Por el período';es_CO = 'Por el período';tr = 'Dönem için';it = 'Per il periodo';de = 'Für den Zeitraum'") + " (" + Lower(RuleAccountsQuantity.Presentation) + ")";
	NewRule.IsFolder = False;
	NewRule.MultipleUse = False;
	NewRule.ValueProperties.Insert("TypeRestriction", TypeDescriptionStandardPeriod);
	NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
	SegmentsServer.AddComparisonTypes(NewRule, "Equal");
	
	#EndRegion
	
	#Region SalesProducts
	
	GroupSalesProducts = Rules.Rows.Add();
	GroupSalesProducts.Name = "SalesProducts";
	GroupSalesProducts.Presentation = NStr("en = 'Products sold'; ru = 'Проданная номенклатура';pl = 'Produktów sprzedano';es_ES = 'Productos vendidos';es_CO = 'Productos vendidos';tr = 'Satılan ürünler';it = 'Articoli venduti';de = 'Verkaufte Produkte'");
	GroupSalesProducts.IsFolder = True;
	
	NewRule = GroupSalesProducts.Rows.Add();
	NewRule.Name = "SalesProductsProducts";
	NewRule.Presentation = NStr("en = 'Product'; ru = 'Номенклатура';pl = 'Produkt';es_ES = 'Producto';es_CO = 'Producto';tr = 'Ürün';it = 'Articolo';de = 'Produkt'");
	NewRule.IsFolder = False;
	NewRule.MultipleUse = False;
	NewRule.ValueProperties.Insert("TypeRestriction", New TypeDescription("CatalogRef.Products"));
	NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Items);
	SegmentsServer.AddComparisonTypes(NewRule, "Equal,NotEqual,InList,NotInList");
	
	NewRule = GroupSalesProducts.Rows.Add();
	NewRule.Name = "SalesProductsProductsGroup";
	NewRule.Presentation = NStr("en = 'Product group'; ru = 'Группа номенклатуры';pl = 'Grupa produktów';es_ES = 'Grupo de producto';es_CO = 'Grupo de producto';tr = 'Ürün grubu';it = 'Gruppo articolo';de = 'Produktgruppe'");
	NewRule.IsFolder = False;
	NewRule.MultipleUse = False;
	NewRule.ValueProperties.Insert("TypeRestriction", New TypeDescription("CatalogRef.Products"));
	NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Folders);
	SegmentsServer.AddComparisonTypes(NewRule, "Equal,NotEqual,InHierarchy,NotInHierarchy,InList,NotInList");
	
	NewRule = GroupSalesProducts.Rows.Add();
	NewRule.Name = "SalesProductsProductsCategory";
	NewRule.Presentation = NStr("en = 'Product category'; ru = 'Категория номенклатуры';pl = 'Kategoria produktu';es_ES = 'Categoría de producto';es_CO = 'Categoría de producto';tr = 'Ürün kategorisi';it = 'Categoria articolo';de = 'Produktkategorie'");
	NewRule.IsFolder = False;
	NewRule.MultipleUse = False;
	NewRule.ValueProperties.Insert("TypeRestriction", New TypeDescription("CatalogRef.ProductsCategories"));
	NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Items);
	SegmentsServer.AddComparisonTypes(NewRule, "Equal,NotEqual,InHierarchy,NotInHierarchy,InList,NotInList");
	
	NewRule = GroupSalesProducts.Rows.Add();
	NewRule.Name = "SalesProductsPeriod";
	NewRule.Presentation = NStr("en = 'Product sales period'; ru = 'Период продаж номенклатуры';pl = 'Okres sprzedaży produktu';es_ES = 'Período de venta del producto';es_CO = 'Período de venta del producto';tr = 'Ürün satış dönemi';it = 'Periodo di vendita articolo';de = 'Produktverkaufszeitraum'");
	NewRule.IsFolder = False;
	NewRule.MultipleUse = False;
	NewRule.ValueProperties.Insert("TypeRestriction", TypeDescriptionStandardPeriod);
	NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
	SegmentsServer.AddComparisonTypes(NewRule, "Equal");
	
	#EndRegion
	
	#Region SalesIncome
	
	GroupSalesIncome = Rules.Rows.Add();
	GroupSalesIncome.Name = "SalesIncome";
	GroupSalesIncome.Presentation = NStr("en = 'Sales'; ru = 'Продажи';pl = 'Sprzedaż';es_ES = 'Ventas';es_CO = 'Ventas';tr = 'Satışlar';it = 'Vendite';de = 'Verkäufe'");
	GroupSalesIncome.IsFolder = True;
	
	NewRule = GroupSalesIncome.Rows.Add();
	NewRule.Name = "SalesIncomeIncome";
	NewRule.Presentation = NStr("en = 'Revenue'; ru = 'Выручка';pl = 'Przychód';es_ES = 'Ingreso';es_CO = 'Ingreso';tr = 'Gelir';it = 'Ricavo';de = 'Erlös'");
	NewRule.IsFolder = False;
	NewRule.MultipleUse = True;
	NewRule.ValueProperties.Insert("TypeRestriction", CurrencyTypeDescription);
	NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
	SegmentsServer.AddComparisonTypes(NewRule, "Equal,NotEqual,Greater,GreaterOrEqual,Less,LessOrEqual", 4);
	
	NewRule = GroupSalesIncome.Rows.Add();
	NewRule.Name = "SalesIncomeGrossProfit";
	NewRule.Presentation = NStr("en = 'Gross profit'; ru = 'Валовая прибыль';pl = 'Zysk brutto';es_ES = 'Ganancia bruta';es_CO = 'Ganancia bruta';tr = 'Brüt kâr';it = 'Profitto lordo';de = 'Bruttoertrag'");
	NewRule.IsFolder = False;
	NewRule.MultipleUse = True;
	NewRule.ValueProperties.Insert("TypeRestriction", CurrencyTypeDescription);
	NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
	SegmentsServer.AddComparisonTypes(NewRule, "Equal,NotEqual,Greater,GreaterOrEqual,Less,LessOrEqual", 4);
	
	NewRule = GroupSalesIncome.Rows.Add();
	NewRule.Name = "SalesIncomePeriod";
	NewRule.Presentation = NStr("en = 'Sales period'; ru = 'Период продаж';pl = 'Okres sprzedaży';es_ES = 'Período de ventas';es_CO = 'Período de ventas';tr = 'Satış dönemi';it = 'Periodo di vendita';de = 'Verkaufszeitraum'");
	NewRule.IsFolder = False;
	NewRule.MultipleUse = False;
	NewRule.ValueProperties.Insert("TypeRestriction", TypeDescriptionStandardPeriod);
	NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
	SegmentsServer.AddComparisonTypes(NewRule, "Equal");
	
	#EndRegion
	
	#Region Debt
	
	GroupDebt = Rules.Rows.Add();
	GroupDebt.Name = "Debt";
	GroupDebt.Presentation = NStr("en = 'Customer/supplier  balance'; ru = 'Баланс покупателя/поставщика';pl = 'Saldo nabywcy/dostawcy';es_ES = 'Saldo del cliente/proveedor';es_CO = 'Saldo del cliente/proveedor';tr = 'Müşteri/tedarikçi bakiyesi';it = 'Saldo Cliente/Fornitore';de = 'Kunden- und Lieferantensaldo'");
	GroupDebt.IsFolder = True;
	
	NewRule = GroupDebt.Rows.Add();
	NewRule.Name = "CustomerDebtAmount";
	NewRule.Presentation = NStr("en = 'AR balance'; ru = 'Остаток дебиторской задолженности';pl = 'Stan należności';es_ES = 'Saldo de cuentas por cobrar';es_CO = 'Saldo de cuentas por cobrar';tr = 'Alacak hesabı bakiyesi';it = 'Saldo Cred.';de = 'Offene Posten Debitoren-Bilanz'");
	NewRule.IsFolder = False;
	NewRule.MultipleUse = True;
	NewRule.ValueProperties.Insert("TypeRestriction", CurrencyTypeDescription);
	NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
	SegmentsServer.AddComparisonTypes(NewRule, "Equal,NotEqual,Greater,GreaterOrEqual,Less,LessOrEqual", 4);
	
	NewRule = GroupDebt.Rows.Add();
	NewRule.Name = "CustomerDebtTerm";
	NewRule.Presentation = NStr("en = 'AR days past due'; ru = 'Просрочка дебиторской задолженности (дней)';pl = 'Wn przekroczono dni';es_ES = 'Índice de días de rotación de cartera';es_CO = 'Índice de días de rotación de cartera';tr = 'Alacak hesabı gecikme günü';it = 'Fatture attive scadute';de = 'Offene Posten Debitoren nach Fälligkeitstermin'");
	NewRule.IsFolder = False;
	NewRule.MultipleUse = True;
	NewRule.ValueProperties.Insert("TypeRestriction", New TypeDescription("Number"));
	NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
	SegmentsServer.AddComparisonTypes(NewRule, "Equal,NotEqual,Greater,GreaterOrEqual,Less,LessOrEqual");
	
	NewRule = GroupDebt.Rows.Add();
	NewRule.Name = "VendorDebtAmount";
	NewRule.Presentation = NStr("en = 'AP balance'; ru = 'Остаток кредиторской задолженности';pl = 'Stan zobowiązań';es_ES = 'Saldo de cuentas por pagar';es_CO = 'Saldo de cuentas por pagar';tr = 'Borç hesabı bakiyesi';it = 'Saldo Deb.';de = 'Offene Posten Kreditoren - Bilanz'");
	NewRule.IsFolder = False;
	NewRule.MultipleUse = True;
	NewRule.ValueProperties.Insert("TypeRestriction", CurrencyTypeDescription);
	NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
	SegmentsServer.AddComparisonTypes(NewRule, "Equal,NotEqual,Greater,GreaterOrEqual,Less,LessOrEqual", 4);
	
	NewRule = GroupDebt.Rows.Add();
	NewRule.Name = "VendorDebtTerm";
	NewRule.Presentation = NStr("en = 'AP days past due'; ru = 'Просрочка кредиторской задолженности (дней)';pl = 'Ma przekroczono dni';es_ES = 'Índice de días de rotación de cartera';es_CO = 'Índice de días de rotación de cartera';tr = 'Borç hesabı gecikme günü';it = 'Fatture passive scadute';de = 'Offene Posten Kreditoren nach Fälligkeitstermin'");
	NewRule.IsFolder = False;
	NewRule.MultipleUse = True;
	NewRule.ValueProperties.Insert("TypeRestriction", New TypeDescription("Number"));
	NewRule.ValueProperties.Insert("ChoiceFoldersAndItems", FoldersAndItems.Auto);
	SegmentsServer.AddComparisonTypes(NewRule, "Equal,NotEqual,Greater,GreaterOrEqual,Less,LessOrEqual");
	
	#EndRegion
	
	Return Rules;
	
EndFunction

// Function returns the segment content
//
// Parameters:
//  Segment	 - CatalogRef.Segment	 - segment for which it
// is required to receive the Return value content:
//  Array - array of counterparties included in segment
Function GetSegmentContent(Segment) Export
	
	Query = GenerateQueryOnRules(Segment);
	CounterpartiesArray = Query.Execute().Unload().UnloadColumn("Ref");
	
	Return CounterpartiesArray;
	
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
		|	Catalog.CounterpartySegments.UsedRules AS SegmentsUsedRules
		|WHERE
		|	SegmentsUsedRules.Ref = &Ref
		|
		|ORDER BY
		|	SegmentsUsedRules.LineNumber";
	
	Query.SetParameter("Ref", Segment);
	RulesSelection = Query.Execute().Select();
	
	Query = New Query;
	
	QuerySchema = New QuerySchema;
	QuerySchema.SetQueryText("
		|SELECT ALLOWED DISTINCT
		|	Counterparties.Ref
		|FROM
		|	Catalog.Counterparties AS Counterparties
		|WHERE
		|	Counterparties.IsFolder = FALSE
		|	AND Counterparties.DeletionMark = FALSE
		|
		|ORDER BY
		|	Counterparties.Description");
	
	AvailableTableCounterparties = QuerySchema.QueryBatch[0].AvailableTables.Find("Catalog.Counterparties");
	Operator = QuerySchema.QueryBatch[0].Operators[0];
	FilterQuery = Operator.Filter;
	
	RuleNumber = 0;
	
	While RulesSelection.Next() Do
		
		RuleNumber = RuleNumber + 1;
		RuleSettings = RulesSelection.Settings.Get();
		
		If RulesSelection.Name = "Tag" Then
			
			FilterQuery.Add(SegmentsServer.ComparisonCondition("Counterparties.Tags.Tag", RuleSettings.ComparisonType, RulesSelection.Name));
			Query.SetParameter(RulesSelection.Name, RuleSettings.Value);
			
		ElsIf RulesSelection.Name = "CounterpartyType" Then
			
			FilterQuery.Add(SegmentsServer.ComparisonCondition("Counterparties.LegalEntityIndividual", RuleSettings.ComparisonType, RulesSelection.Name));
			Query.SetParameter(RulesSelection.Name, RuleSettings.Value);
			
		ElsIf RulesSelection.Name = "Group" Then
			
			FilterQuery.Add(SegmentsServer.ComparisonCondition("Counterparties.Parent", RuleSettings.ComparisonType, RulesSelection.Name));
			Query.SetParameter(RulesSelection.Name, RuleSettings.Value);
			
		ElsIf RulesSelection.Name = "CreationDate" Then
			
			FilterQuery.Add(SegmentsServer.ComparisonCondition("Counterparties.CreationDate", RuleSettings.ComparisonType, RulesSelection.Name + "_" + RuleNumber));
			Query.SetParameter(RulesSelection.Name + "_" + RuleNumber, RuleSettings.Value.Date);
			
		ElsIf RulesSelection.Name = "Comment" Then
			
			FilterQuery.Add(SegmentsServer.ComparisonCondition("Counterparties.Comment", RuleSettings.ComparisonType, RulesSelection.Name));
			Query.SetParameter(RulesSelection.Name, SegmentsServer.OperatorTemplateDetails(RuleSettings.ComparisonType, RuleSettings.Value));
			
		ElsIf RulesSelection.Name = "Responsible" Then
			
			FilterQuery.Add(SegmentsServer.ComparisonCondition("Counterparties.Responsible", RuleSettings.ComparisonType, RulesSelection.Name));
			Query.SetParameter(RulesSelection.Name, RuleSettings.Value);
			
		ElsIf RulesSelection.Name = "SalesRep" Then
			
			FilterQuery.Add(SegmentsServer.ComparisonCondition("Counterparties.SalesRep", RuleSettings.ComparisonType, RulesSelection.Name));
			Query.SetParameter(RulesSelection.Name, RuleSettings.Value);
			
		ElsIf RulesSelection.Name = "CashAssetType" Then
			
			FilterQuery.Add(SegmentsServer.ComparisonCondition("Counterparties.CashAssetType", RuleSettings.ComparisonType, RulesSelection.Name));
			Query.SetParameter(RulesSelection.Name, RuleSettings.Value);
			
		ElsIf RulesSelection.Name = "PriceKind" Then
			
			FilterQuery.Add(SegmentsServer.ComparisonCondition("Counterparties.PriceKind", RuleSettings.ComparisonType, RulesSelection.Name));
			Query.SetParameter(RulesSelection.Name, RuleSettings.Value);
			
		ElsIf RulesSelection.Name = "CounterpartyKind" Then
			
			If TypeOf(RuleSettings.Value) = Type("ValueList") Then
				For Each Item In RuleSettings.Value Do
					Value = ?(RuleSettings.ComparisonType = DataCompositionComparisonType.InList, True, False);
					FilterQuery.Add(SegmentsServer.ComparisonCondition("Counterparties." + Item.Value, DataCompositionComparisonType.Equal, Item.Value));
					Query.SetParameter(Item.Value, Value);
				EndDo;
			Else
				FilterQuery.Add(SegmentsServer.ComparisonCondition("Counterparties." + RulesSelection.DynamicRuleKey, DataCompositionComparisonType.Equal, RulesSelection.DynamicRuleKey));
				Value = ?(RuleSettings.ComparisonType = DataCompositionComparisonType.Equal, True, False);
				Query.SetParameter(RulesSelection.DynamicRuleKey, Value);
			EndIf;
			
		ElsIf RulesSelection.Name = "AdditionalAttribute" AND ValueIsFilled(RulesSelection.DynamicRuleKey) Then
			
			If DriveServer.FindQuerySchemaSource(Operator.Sources, "CounterpartiesAdditionalAttributes") = Undefined Then
				AvailableAdditAttributesTable = DriveServer.FindAvailableTableQuerySchemaField(AvailableTableCounterparties, "AdditionalAttributes", Type("QuerySchemaAvailableNestedTable"));
				NewSource = Operator.Sources.Add(AvailableAdditAttributesTable, "CounterpartiesAdditionalAttributes");
				NewSource.Joins.Clear();
				Operator.Sources[0].Joins.Add("CounterpartiesAdditionalAttributes", "Counterparties.Ref = CounterpartiesAdditionalAttributes.Ref");
				Operator.Sources[0].Joins[0].JoinType = QuerySchemaJoinType.Inner;
			EndIf;
			
			FilterQuery.Add("CounterpartiesAdditionalAttributes.Property = &Property" + RuleNumber);
			Query.SetParameter("Property" + RuleNumber, RulesSelection.DynamicRuleKey);
			FilterQuery.Add(SegmentsServer.ComparisonCondition("CounterpartiesAdditionalAttributes.Value", RuleSettings.ComparisonType, "ValueAdditionalAttribute" + RuleNumber));
			If TypeOf(RuleSettings.Value) = Type("String") AND
				(RuleSettings.ComparisonType = DataCompositionComparisonType.BeginsWith Or RuleSettings.ComparisonType = DataCompositionComparisonType.NotBeginsWith
				Or RuleSettings.ComparisonType = DataCompositionComparisonType.Contains Or RuleSettings.ComparisonType = DataCompositionComparisonType.NotContains) Then
					Query.SetParameter("ValueAdditionalAttribute" + RuleNumber, SegmentsServer.OperatorTemplateDetails(RuleSettings.ComparisonType, RuleSettings.Value));
			Else
				Query.SetParameter("ValueAdditionalAttribute" + RuleNumber, RuleSettings.Value);
			EndIf;
			
		ElsIf Left(RulesSelection.Name, 22) = "ContactInformationKind" AND ValueIsFilled(RulesSelection.DynamicRuleKey) Then
			
			If DriveServer.FindQuerySchemaSource(Operator.Sources, "CounterpartiesContactInformation") = Undefined Then
				AvailableCITable = DriveServer.FindAvailableTableQuerySchemaField(AvailableTableCounterparties, "ContactInformation", Type("QuerySchemaAvailableNestedTable"));
				NewSource = Operator.Sources.Add(AvailableCITable, "CounterpartiesContactInformation");
				NewSource.Joins.Clear();
				Operator.Sources[0].Joins.Add("CounterpartiesContactInformation", "Counterparties.Ref = CounterpartiesContactInformation.Ref");
				Operator.Sources[0].Joins[0].JoinType = QuerySchemaJoinType.Inner;
			EndIf;
			
			FilterQuery.Add("CounterpartiesContactInformation.Kind = &CIKind" + RuleNumber);
			Query.SetParameter("CIKind" + RuleNumber, RulesSelection.DynamicRuleKey);
			FilterQuery.Add(SegmentsServer.ComparisonCondition("CounterpartiesContactInformation." + Mid(RulesSelection.Name, 23), RuleSettings.ComparisonType, "ValueCI" + RuleNumber));
			Query.SetParameter("ValueCI" + RuleNumber, SegmentsServer.OperatorTemplateDetails(RuleSettings.ComparisonType, RuleSettings.Value));
			
		ElsIf Left(RulesSelection.Name, 6) = "Events" Then
			
			NewSource = DriveServer.FindQuerySchemaSource(Operator.Sources, "EventsForPeriod");
			
			If NewSource = Undefined Then
				
				NewSource = Operator.Sources.Add(Type("QuerySchemaNestedQuery"), "EventsForPeriod");
				NewSource.Source.Query.SetQueryText("SELECT ALLOWED
				                                    |	EventParticipants.Contact AS Counterparty,
				                                    |	COUNT(DISTINCT EventParticipants.Ref) AS EventsQuantity,
				                                    |	MAX(EventParticipants.Ref.Date) AS LastEventDate
				                                    |FROM
				                                    |	Document.Event.Participants AS EventParticipants
				                                    |WHERE
				                                    |	EventParticipants.Ref.DeletionMark = FALSE
				                                    |	AND EventParticipants.Contact REFS Catalog.Counterparties
				                                    |	AND &UseDocumentEvent
				                                    |
				                                    |GROUP BY
				                                    |	EventParticipants.Contact");
				
				NewSource.Joins.Clear();
				Operator.Sources[0].Joins.Add("EventsForPeriod", "Counterparties.Ref = EventsForPeriod.Counterparty");
				Operator.Sources[0].Joins[0].JoinType = QuerySchemaJoinType.Inner;
				
			EndIf;
			
			InsertedQueryFilter = NewSource.Source.Query.Operators[0].Filter;
			
			If RulesSelection.Name = "EventsDateLast" Then
				FilterQuery.Add(SegmentsServer.ComparisonCondition("ISNULL(EventsForPeriod.LastEventDate, DATETIME(0001,01,01))", RuleSettings.ComparisonType, RulesSelection.Name + "_" + RuleNumber));
				Query.SetParameter(RulesSelection.Name + "_" + RuleNumber, RuleSettings.Value.Date);
			ElsIf RulesSelection.Name = "EventsQuantity" Then
				FilterQuery.Add(SegmentsServer.ComparisonCondition("ISNULL(EventsForPeriod.EventsQuantity, 0)", RuleSettings.ComparisonType, RulesSelection.Name + "_" + RuleNumber));
				Query.SetParameter(RulesSelection.Name + "_" + RuleNumber, RuleSettings.Value);
			ElsIf RulesSelection.Name = "EventsQuantityPeriod" Then
				If ValueIsFilled(RuleSettings.Value.StartDate) Then
					InsertedQueryFilter.Add(SegmentsServer.ComparisonCondition("EventParticipants.Ref.Date", DataCompositionComparisonType.GreaterOrEqual, RulesSelection.Name + "Begin"));
					Query.SetParameter(RulesSelection.Name + "Begin", RuleSettings.Value.StartDate);
				EndIf;
				If ValueIsFilled(RuleSettings.Value.EndDate) Then
					InsertedQueryFilter.Add(SegmentsServer.ComparisonCondition("EventParticipants.Ref.Date", DataCompositionComparisonType.LessOrEqual, RulesSelection.Name + "End"));
					Query.SetParameter(RulesSelection.Name + "End",  RuleSettings.Value.EndDate);
				EndIf;
			ElsIf RulesSelection.Name = "EventsState" Then
				InsertedQueryFilter.Add(SegmentsServer.ComparisonCondition("EventParticipants.Ref.Status", RuleSettings.ComparisonType, RulesSelection.Name));
				Query.SetParameter(RulesSelection.Name, RuleSettings.Value);
			ElsIf RulesSelection.Name = "EventsEventType" Then
				InsertedQueryFilter.Add(SegmentsServer.ComparisonCondition("EventParticipants.Ref.EventType", RuleSettings.ComparisonType, RulesSelection.Name));
				Query.SetParameter(RulesSelection.Name, RuleSettings.Value);
			EndIf;
			
			Query.SetParameter("UseDocumentEvent", GetFunctionalOption("UseDocumentEvent"));
			
		ElsIf Left(RulesSelection.Name, 11) = "SalesOrders" Then
			
			NewSource = DriveServer.FindQuerySchemaSource(Operator.Sources, "OrdersForPeriod");
			
			If NewSource = Undefined Then
				
				NewSource = Operator.Sources.Add(Type("QuerySchemaNestedQuery"), "OrdersForPeriod");
				NewSource.Source.Query.SetQueryText("
					|SELECT ALLOWED
					|	SalesOrder.Counterparty,
					|	COUNT(SalesOrder.Ref) AS OrdersQuantity,
					|	MAX(SalesOrder.Date) AS LastOrderDate
					|FROM
					|	Document.SalesOrder AS SalesOrder
					|WHERE
					|	SalesOrder.Posted = TRUE
					|
					|GROUP BY
					|	SalesOrder.Counterparty");
				
				NewSource.Joins.Clear();
				Operator.Sources[0].Joins.Add("OrdersForPeriod", "Counterparties.Ref = OrdersForPeriod.Counterparty");
				Operator.Sources[0].Joins[0].JoinType = QuerySchemaJoinType.Inner;
				
			EndIf;
			
			InsertedQueryFilter = NewSource.Source.Query.Operators[0].Filter;
			
			If RulesSelection.Name = "SalesOrdersDateLast" Then
				FilterQuery.Add(SegmentsServer.ComparisonCondition("ISNULL(OrdersForPeriod.LastOrderDate, DATETIME(0001,01,01))", RuleSettings.ComparisonType, RulesSelection.Name + "_" + RuleNumber));
				Query.SetParameter(RulesSelection.Name + "_" + RuleNumber, RuleSettings.Value.Date);
			ElsIf RulesSelection.Name = "SalesOrdersQuantity" Then
				FilterQuery.Add(SegmentsServer.ComparisonCondition("ISNULL(OrdersForPeriod.OrdersQuantity, 0)", RuleSettings.ComparisonType, RulesSelection.Name + "_" + RuleNumber));
				Query.SetParameter(RulesSelection.Name + "_" + RuleNumber, RuleSettings.Value);
			ElsIf RulesSelection.Name = "SalesOrdersQuantityPeriod" Then
				If ValueIsFilled(RuleSettings.Value.StartDate) Then
					InsertedQueryFilter.Add(SegmentsServer.ComparisonCondition("SalesOrder.Date", DataCompositionComparisonType.GreaterOrEqual, RulesSelection.Name + "Begin"));
					Query.SetParameter(RulesSelection.Name + "Begin", RuleSettings.Value.StartDate);
				EndIf;
				If ValueIsFilled(RuleSettings.Value.EndDate) Then
					InsertedQueryFilter.Add(SegmentsServer.ComparisonCondition("SalesOrder.Date", DataCompositionComparisonType.LessOrEqual, RulesSelection.Name + "End"));
					Query.SetParameter(RulesSelection.Name + "End",  RuleSettings.Value.EndDate);
				EndIf;
			ElsIf RulesSelection.Name = "SalesOrdersOrderState" Then
				InsertedQueryFilter.Add(SegmentsServer.ComparisonCondition("SalesOrder.OrderState", RuleSettings.ComparisonType, RulesSelection.Name));
				Query.SetParameter(RulesSelection.Name, RuleSettings.Value);
			EndIf;
			
		ElsIf Left(RulesSelection.Name, 18) = "InvoicesForPayment" Then
			
			NewSource = DriveServer.FindQuerySchemaSource(Operator.Sources, "AccountsForPeriod");
			
			If NewSource = Undefined Then
				
				NewSource = Operator.Sources.Add(Type("QuerySchemaNestedQuery"), "AccountsForPeriod");
				NewSource.Source.Query.SetQueryText("
					|SELECT ALLOWED
					|	Quote.Counterparty,
					|	COUNT(Quote.Ref) AS AccountsQuantity,
					|	MAX(Quote.Date) AS LastAccountDate
					|FROM
					|	Document.Quote AS Quote
					|WHERE
					|	Quote.Posted = TRUE
					|
					|GROUP BY
					|	Quote.Counterparty");
				
				NewSource.Joins.Clear();
				Operator.Sources[0].Joins.Add("AccountsForPeriod", "Counterparties.Ref = AccountsForPeriod.Counterparty");
				Operator.Sources[0].Joins[0].JoinType = QuerySchemaJoinType.Inner;
				
			EndIf;
			
			InsertedQueryFilter = NewSource.Source.Query.Operators[0].Filter;
			
			If RulesSelection.Name = "InvoicesForPaymentLastDate" Then
				FilterQuery.Add(SegmentsServer.ComparisonCondition("ISNULL(AccountsForPeriod.LastAccountDate, DATETIME(0001,01,01))", RuleSettings.ComparisonType, RulesSelection.Name + "_" + RuleNumber));
				Query.SetParameter(RulesSelection.Name + "_" + RuleNumber, RuleSettings.Value.Date);
			ElsIf RulesSelection.Name = "InvoicesForPaymentQuantity" Then
				FilterQuery.Add(SegmentsServer.ComparisonCondition("ISNULL(AccountsForPeriod.AccountsQuantity, 0)", RuleSettings.ComparisonType, RulesSelection.Name + "_" + RuleNumber));
				Query.SetParameter(RulesSelection.Name + "_" + RuleNumber, RuleSettings.Value);
			ElsIf RulesSelection.Name = "InvoicesForPaymentQuantityPeriod" Then
				If ValueIsFilled(RuleSettings.Value.StartDate) Then
					InsertedQueryFilter.Add(SegmentsServer.ComparisonCondition("Quote.Date", DataCompositionComparisonType.GreaterOrEqual, RulesSelection.Name + "Begin"));
					Query.SetParameter(RulesSelection.Name + "Begin", RuleSettings.Value.StartDate);
				EndIf;
				If ValueIsFilled(RuleSettings.Value.EndDate) Then
					InsertedQueryFilter.Add(SegmentsServer.ComparisonCondition("Quote.Date", DataCompositionComparisonType.LessOrEqual, RulesSelection.Name + "End"));
					Query.SetParameter(RulesSelection.Name + "End",  RuleSettings.Value.EndDate);
				EndIf;
			EndIf;
			
		ElsIf Left(RulesSelection.Name, 13) = "SalesProducts" Then
			
			NewSource = DriveServer.FindQuerySchemaSource(Operator.Sources, "SalesProducts");
			
			If NewSource = Undefined Then
				
				NewSource = Operator.Sources.Add(Type("QuerySchemaNestedQuery"), "SalesProducts");
				NewSource.Source.Query.SetQueryText(
				"SELECT ALLOWED
				|	CASE
				|		WHEN Sales.Document REFS Document.SalesOrder
				|			THEN CAST(Sales.Document AS Document.SalesOrder).Counterparty
				|		WHEN Sales.Document REFS Document.AccountSalesFromConsignee
				|			THEN CAST(Sales.Document AS Document.AccountSalesFromConsignee).Counterparty
				|		WHEN Sales.Document REFS Document.AccountSalesToConsignor
				|			THEN CAST(Sales.Document AS Document.AccountSalesToConsignor).Counterparty
				|		WHEN Sales.Document REFS Document.SupplierInvoice
				|			THEN CAST(Sales.Document AS Document.SupplierInvoice).Counterparty
				|		WHEN Sales.Document REFS Document.SalesInvoice
				|			THEN CAST(Sales.Document AS Document.SalesInvoice).Counterparty
				|		ELSE VALUE(Catalog.Counterparties.EmptyRef)
				|	END AS Counterparty,
				|	Sales.Products AS Products,
				|	Sales.Products.ProductsCategory AS ProductsCategory
				|FROM
				|	AccumulationRegister.Sales AS Sales");
					
				NewSource.Joins.Clear();
				Operator.Sources[0].Joins.Add("SalesProducts", "Counterparties.Ref = SalesProducts.Counterparty");
				Operator.Sources[0].Joins[0].JoinType = QuerySchemaJoinType.Inner;
				
			EndIf;
			
			FilterQuery.Add("NOT SalesProducts.Counterparty IS NULL");
			InsertedQueryFilter = NewSource.Source.Query.Operators[0].Filter;
			
			If RulesSelection.Name = "SalesProductsProducts" Then
				InsertedQueryFilter.Add(SegmentsServer.ComparisonCondition("Sales.Products", RuleSettings.ComparisonType, RulesSelection.Name));
				Query.SetParameter(RulesSelection.Name, RuleSettings.Value);
			ElsIf RulesSelection.Name = "SalesProductsProductsGroup" Then
				InsertedQueryFilter.Add(SegmentsServer.ComparisonCondition("Sales.Products.Parent", RuleSettings.ComparisonType, RulesSelection.Name));
				Query.SetParameter(RulesSelection.Name, RuleSettings.Value);
			ElsIf RulesSelection.Name = "SalesProductsProductsCategory" Then
				InsertedQueryFilter.Add(SegmentsServer.ComparisonCondition("Sales.Products.ProductsCategory", RuleSettings.ComparisonType, RulesSelection.Name));
				Query.SetParameter(RulesSelection.Name, RuleSettings.Value);
			ElsIf RulesSelection.Name = "SalesProductsPeriod" Then
				If ValueIsFilled(RuleSettings.Value.StartDate) Then
					InsertedQueryFilter.Add(SegmentsServer.ComparisonCondition("Sales.Period", DataCompositionComparisonType.GreaterOrEqual, RulesSelection.Name + "Begin"));
					Query.SetParameter(RulesSelection.Name + "Begin", RuleSettings.Value.StartDate);
				EndIf;
				If ValueIsFilled(RuleSettings.Value.EndDate) Then
					InsertedQueryFilter.Add(SegmentsServer.ComparisonCondition("Sales.Period", DataCompositionComparisonType.LessOrEqual, RulesSelection.Name + "End"));
					Query.SetParameter(RulesSelection.Name + "End",  RuleSettings.Value.EndDate);
				EndIf;
			EndIf;
			
		ElsIf Left(RulesSelection.Name, 11) = "SalesIncome" Then
			
			NewSource = DriveServer.FindQuerySchemaSource(Operator.Sources, "SalesIncome");
			
			If NewSource = Undefined Then
				
				NewSource = Operator.Sources.Add(Type("QuerySchemaNestedQuery"), "SalesIncome");
				NewSource.Source.Query.SetQueryText(
				"SELECT ALLOWED
				|	CASE
				|		WHEN SalesTurnovers.Document REFS Document.SalesOrder
				|			THEN CAST(SalesTurnovers.Document AS Document.SalesOrder).Counterparty
				|		WHEN SalesTurnovers.Document REFS Document.AccountSalesFromConsignee
				|			THEN CAST(SalesTurnovers.Document AS Document.AccountSalesFromConsignee).Counterparty
				|		WHEN SalesTurnovers.Document REFS Document.AccountSalesToConsignor
				|			THEN CAST(SalesTurnovers.Document AS Document.AccountSalesToConsignor).Counterparty
				|		WHEN SalesTurnovers.Document REFS Document.SupplierInvoice
				|			THEN CAST(SalesTurnovers.Document AS Document.SupplierInvoice).Counterparty
				|		WHEN SalesTurnovers.Document REFS Document.SalesInvoice
				|			THEN CAST(SalesTurnovers.Document AS Document.SalesInvoice).Counterparty
				|		ELSE VALUE(Catalog.Counterparties.EmptyRef)
				|	END AS Counterparty,
				|	SUM(SalesTurnovers.AmountTurnover) AS Income,
				|	SUM(SalesTurnovers.AmountTurnover - SalesTurnovers.CostTurnover) AS GrossProfit
				|FROM
				|	AccumulationRegister.Sales.Turnovers(, , , ) AS SalesTurnovers
				|
				|GROUP BY
				|	CASE
				|		WHEN SalesTurnovers.Document REFS Document.SalesOrder
				|			THEN CAST(SalesTurnovers.Document AS Document.SalesOrder).Counterparty
				|		WHEN SalesTurnovers.Document REFS Document.AccountSalesFromConsignee
				|			THEN CAST(SalesTurnovers.Document AS Document.AccountSalesFromConsignee).Counterparty
				|		WHEN SalesTurnovers.Document REFS Document.AccountSalesToConsignor
				|			THEN CAST(SalesTurnovers.Document AS Document.AccountSalesToConsignor).Counterparty
				|		WHEN SalesTurnovers.Document REFS Document.SupplierInvoice
				|			THEN CAST(SalesTurnovers.Document AS Document.SupplierInvoice).Counterparty
				|		WHEN SalesTurnovers.Document REFS Document.SalesInvoice
				|			THEN CAST(SalesTurnovers.Document AS Document.SalesInvoice).Counterparty
				|		ELSE VALUE(Catalog.Counterparties.EmptyRef)
				|	END");
				
				NewSource.Joins.Clear();
				Operator.Sources[0].Joins.Add("SalesIncome", "Counterparties.Ref = SalesIncome.Counterparty");
				Operator.Sources[0].Joins[0].JoinType = QuerySchemaJoinType.Inner;
				
			EndIf;
			
			SalesVirtualTableParameters = NewSource.Source.Query.Operators[0].Sources[0].Source.Parameters;
			
			If RulesSelection.Name = "SalesIncomeIncome" Then
				FilterQuery.Add(SegmentsServer.ComparisonCondition("ISNULL(SalesIncome.Income, 0)", RuleSettings.ComparisonType, RulesSelection.Name + "_" + RuleNumber));
				Query.SetParameter(RulesSelection.Name + "_" + RuleNumber, RuleSettings.Value);
			ElsIf RulesSelection.Name = "SalesIncomeGrossProfit" Then
				FilterQuery.Add(SegmentsServer.ComparisonCondition("ISNULL(SalesIncome.GrossProfit, 0)", RuleSettings.ComparisonType, RulesSelection.Name + "_" + RuleNumber));
				Query.SetParameter(RulesSelection.Name + "_" + RuleNumber, RuleSettings.Value);
			ElsIf RulesSelection.Name = "SalesIncomePeriod" Then
				If ValueIsFilled(RuleSettings.Value.StartDate) Then
					SalesVirtualTableParameters[0].Expression = New QuerySchemaExpression("&" + RulesSelection.Name + "Begin");
					Query.SetParameter(RulesSelection.Name + "Begin", RuleSettings.Value.StartDate);
				EndIf;
				If ValueIsFilled(RuleSettings.Value.EndDate) Then
					SalesVirtualTableParameters[1].Expression = New QuerySchemaExpression("&" + RulesSelection.Name + "End");
					Query.SetParameter(RulesSelection.Name + "End",  RuleSettings.Value.EndDate);
				EndIf;
			EndIf;
			
		ElsIf RulesSelection.Name = "CustomerDebtAmount" Then
			
			NewSource = DriveServer.FindQuerySchemaSource(Operator.Sources, "CustomerDebt");
			
			If NewSource = Undefined Then
				
				NewSource = Operator.Sources.Add(Type("QuerySchemaNestedQuery"), "CustomerDebtAmount");
				NewSource.Source.Query.SetQueryText("
					|SELECT ALLOWED
					|	AccountsReceivableBalances.Counterparty,
					|	AccountsReceivableBalances.AmountBalance AS DebtAmount
					|FROM
					|	AccumulationRegister.AccountsReceivable.Balance(, SettlementsType = VALUE(Enum.SettlementsTypes.Debt)) AS AccountsReceivableBalances
					|WHERE
					|	AccountsReceivableBalances.AmountBalance > 0");
				
				NewSource.Joins.Clear();
				Operator.Sources[0].Joins.Add("CustomerDebtAmount", "Counterparties.Ref = CustomerDebtAmount.Counterparty");
				Operator.Sources[0].Joins[0].JoinType = QuerySchemaJoinType.Inner;
				
			EndIf;
			
			FilterQuery.Add(SegmentsServer.ComparisonCondition("ISNULL(CustomerDebtAmount.DebtAmount, 0)", RuleSettings.ComparisonType, RulesSelection.Name + "_" + RuleNumber));
			Query.SetParameter(RulesSelection.Name + "_" + RuleNumber, RuleSettings.Value);
			
		ElsIf RulesSelection.Name = "CustomerDebtTerm" Then
			
			NewSource = DriveServer.FindQuerySchemaSource(Operator.Sources, "CustomerDebtTerm");
			
			If NewSource = Undefined Then
				
				NewSource = Operator.Sources.Add(Type("QuerySchemaNestedQuery"), "CustomerDebtTerm");
				NewSource.Source.Query.SetQueryText("
					|SELECT ALLOWED
					|	NestedSelect.Counterparty AS Counterparty,
					|	MAX(CASE
					|			WHEN NestedSelect.TermPaymentFromCustomer > 0
					|					AND DATEDIFF(NestedSelect.DateAccountingDocument, &CurrentDate, Day) > NestedSelect.TermPaymentFromCustomer
					|				THEN DATEDIFF(NestedSelect.DateAccountingDocument, &CurrentDate, Day) - NestedSelect.TermPaymentFromCustomer
					|			ELSE 0
					|		END) AS DelayTerm
					|FROM
					|	(SELECT
					|		AccountsReceivableBalances.Counterparty AS Counterparty,
					|		0 AS TermPaymentFromCustomer,
					|		AccountsReceivableBalances.Document.Date AS DateAccountingDocument
					|	FROM
					|		AccumulationRegister.AccountsReceivable.Balance AS AccountsReceivableBalances
					|	WHERE
					|		AccountsReceivableBalances.Document <> UNDEFINED
					|		AND AccountsReceivableBalances.AmountBalance > 0
					|		AND AccountsReceivableBalances.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
					|		AND DATEDIFF(AccountsReceivableBalances.Document.Date, &CurrentDate, Day) >= 0) AS NestedSelect
					|
					|GROUP BY
					|	NestedSelect.Counterparty");
					
				NewSource.Joins.Clear();
				Operator.Sources[0].Joins.Add("CustomerDebtTerm", "Counterparties.Ref = CustomerDebtTerm.Counterparty");
				Operator.Sources[0].Joins[0].JoinType = QuerySchemaJoinType.Inner;
				
			EndIf;
			
			FilterQuery.Add(SegmentsServer.ComparisonCondition("ISNULL(CustomerDebtTerm.DelayTerm, 0)", RuleSettings.ComparisonType, RulesSelection.Name + "_" + RuleNumber));
			Query.SetParameter(RulesSelection.Name + "_" + RuleNumber, RuleSettings.Value);
			Query.SetParameter("CurrentDate", CurrentSessionDate());
			
		ElsIf Left(RulesSelection.Name, 23) = "VendorDebtAmount" Then
			
			NewSource = DriveServer.FindQuerySchemaSource(Operator.Sources, "VendorDebtAmount");
			
			If NewSource = Undefined Then
				
				NewSource = Operator.Sources.Add(Type("QuerySchemaNestedQuery"), "VendorDebtAmount");
				NewSource.Source.Query.SetQueryText("
					|SELECT ALLOWED
					|	AccountsPayableBalances.Counterparty,
					|	AccountsPayableBalances.AmountBalance AS DebtAmount
					|FROM
					|	AccumulationRegister.AccountsPayable.Balance(, SettlementsType = VALUE(Enum.SettlementsTypes.Debt)) AS AccountsPayableBalances");
				
				NewSource.Joins.Clear();
				Operator.Sources[0].Joins.Add("VendorDebtAmount", "Counterparties.Ref = VendorDebtAmount.Counterparty");
				Operator.Sources[0].Joins[0].JoinType = QuerySchemaJoinType.Inner;
				
			EndIf;
			
			FilterQuery.Add(SegmentsServer.ComparisonCondition("ISNULL(VendorDebtAmount.DebtAmount, 0)", RuleSettings.ComparisonType, RulesSelection.Name + "_" + RuleNumber));
			Query.SetParameter(RulesSelection.Name + "_" + RuleNumber, RuleSettings.Value);
			
		ElsIf RulesSelection.Name = "VendorDebtTerm" Then
			
			NewSource = DriveServer.FindQuerySchemaSource(Operator.Sources, "VendorDebtTerm");
			
			If NewSource = Undefined Then
				
				NewSource = Operator.Sources.Add(Type("QuerySchemaNestedQuery"), "VendorDebtTerm");
				NewSource.Source.Query.SetQueryText("
					|SELECT ALLOWED
					|	NestedSelect.Counterparty AS Counterparty,
					|	0 AS DelayTerm
					|FROM
					|	(SELECT
					|		AccountsPayableBalances.Counterparty AS Counterparty,
					|		AccountsPayableBalances.Document.Date AS DateAccountingDocument
					|	FROM
					|		AccumulationRegister.AccountsPayable.Balance(, ) AS AccountsPayableBalances
					|	WHERE
					|		AccountsPayableBalances.Document <> UNDEFINED
					|		AND AccountsPayableBalances.AmountBalance > 0
					|		AND AccountsPayableBalances.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
					|		AND DATEDIFF(AccountsPayableBalances.Document.Date, &CurrentDate, Day) >= 0) AS NestedSelect
					|
					|GROUP BY
					|	NestedSelect.Counterparty");
				
				NewSource.Joins.Clear();
				Operator.Sources[0].Joins.Add("VendorDebtTerm", "Counterparties.Ref = VendorDebtTerm.Counterparty");
				Operator.Sources[0].Joins[0].JoinType = QuerySchemaJoinType.Inner;
				
			EndIf;
			
			FilterQuery.Add(SegmentsServer.ComparisonCondition("ISNULL(VendorDebtTerm.DelayTerm, 0)", RuleSettings.ComparisonType, RulesSelection.Name + "_" + RuleNumber));
			Query.SetParameter(RulesSelection.Name + "_" + RuleNumber, RuleSettings.Value);
			Query.SetParameter("CurrentDate", CurrentSessionDate());
			
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
		Metadata.Catalogs.CounterpartySegments);
	
EndProcedure

Procedure PresentationGetProcessing(Data, Presentation, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationGetProcessing(Data, Presentation, StandardProcessing);
	
EndProcedure

Procedure PresentationFieldsGetProcessing(Fields, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationFieldsGetProcessing(Fields, StandardProcessing);
	
EndProcedure

#EndRegion

#EndIf