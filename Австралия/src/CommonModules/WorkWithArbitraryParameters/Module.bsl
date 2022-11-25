
#Region Public

Function InitParametersTable() Export

	TableAvailableParameters = New ValueTable;
	TableAvailableParameters.Columns.Add("Field");
	TableAvailableParameters.Columns.Add("ValueType");
	TableAvailableParameters.Columns.Add("Synonym");
	TableAvailableParameters.Columns.Add("ListSynonym");
	TableAvailableParameters.Columns.Add("Category");
	TableAvailableParameters.Columns.Add("DrCr");
	TableAvailableParameters.Columns.Add("CategorySynonym");
	TableAvailableParameters.Columns.Add("RestrictedByType", New TypeDescription("Boolean")); 
	
	Return TableAvailableParameters;
	
EndFunction 

Function InitNestedAttributesTable() Export

	TableAvailableParameters = New ValueTable;
	TableAvailableParameters.Columns.Add("ParentField");
	TableAvailableParameters.Columns.Add("Field");
	TableAvailableParameters.Columns.Add("ValueType");
	TableAvailableParameters.Columns.Add("Synonym");
	TableAvailableParameters.Columns.Add("ListSynonym");
	TableAvailableParameters.Columns.Add("Category");
	TableAvailableParameters.Columns.Add("DrCr");
	TableAvailableParameters.Columns.Add("ParentDrCr");
	TableAvailableParameters.Columns.Add("RestrictedByType", New TypeDescription("Boolean")); 
	
	Return TableAvailableParameters;
	
EndFunction 

Function GetAvailablePeriodsList(DataSource, DocumentType) Export
	
	DataTypeRestriction = New TypeDescription("Date", , , New DateQualifiers(DateFractions.DateTime));
	
	ParametersTable = InitParametersTable();
	
	SupplementParametersTableWithDataSourceAttributes(
		ParametersTable, 
		DataSource, 
		DocumentType, 
		DataTypeRestriction);
	SupplementParametersTableWithDocumentsAttributes(
		ParametersTable, 
		DocumentType, 
		DataTypeRestriction);

	AvailablePeriodsList = New ValueList;
	
	For Each ParameterRow In ParametersTable Do
		
		AvailablePeriodsList.Add(ParameterRow.Field, ParameterRow.Synonym);
		
	EndDo;

	Return AvailablePeriodsList;
	
EndFunction 

Function GetAvailableAttributesByType(DataSource, DocumentType, DataTypeRestrictionString, TypeRestrictionIsNumeric = False) Export
	
	DataTypeRestriction = New TypeDescription(DataTypeRestrictionString);
	
	ParametersTable = InitParametersTable();
	
	SupplementParametersTableWithDataSourceAttributes(
		ParametersTable, 
		DataSource, 
		DocumentType, 
		DataTypeRestriction, 
		TypeRestrictionIsNumeric);
	SupplementParametersTableWithDocumentsAttributes(
		ParametersTable,
		DocumentType,
		DataTypeRestriction,
		TypeRestrictionIsNumeric);

	ListAvailable = New ValueList;
	
	For Each ParameterRow In ParametersTable Do
		
		ListAvailable.Add(ParameterRow.Field, ParameterRow.Synonym);
		
	EndDo;

	Return ListAvailable;
	
EndFunction 

Procedure GetAvailableCatalogsTable(TableCatalogs) Export
		
	For Each Catalog In Metadata.Catalogs Do
		
		If CheckObsolete(Catalog.Name, Catalog.Synonym) Then
			Continue;
		EndIf;
		
		ObjectPresentation = TrimAll(Catalog.ObjectPresentation);
		
		Synonym = ?(ValueIsFilled(ObjectPresentation), ObjectPresentation, Catalog.Synonym);
		
		NewParameter = TableCatalogs.Add();
		NewParameter.Field				= Catalog.Name;
		NewParameter.Synonym			= Synonym;
		NewParameter.ValueType			= New TypeDescription(StrTemplate("CatalogRef.%1", Catalog.Name));
		NewParameter.Category			= "AvailableCatalogTypes";
		NewParameter.CategorySynonym	= NStr("en = 'Available catalogs'; ru = 'Доступные справочники';pl = 'Dostępne katalogi';es_ES = 'Catálogos disponibles';es_CO = 'Catálogos disponibles';tr = 'Mevcut kataloglar';it = 'Cataloghi disponibili';de = 'Verfügbare Kataloge'"); 
		NewParameter.ListSynonym		= Synonym;
		
	EndDo;
	
EndProcedure

Procedure GetAvailableEnumsTable(TableCatalogs) Export
		
	For Each Enum In Metadata.Enums Do
		
		If CheckObsolete(Enum.Name, Enum.Synonym) Then
			Continue;
		EndIf;
		
		Synonym = Enum.Synonym;
		
		NewParameter = TableCatalogs.Add();
		NewParameter.Field				= Enum.Name;
		NewParameter.Synonym			= Synonym;
		NewParameter.ValueType			= New TypeDescription(StrTemplate("EnumRef.%1", Enum.Name));
		NewParameter.Category			= "AvailableEnumTypes";
		NewParameter.CategorySynonym	= NStr("en = 'Available enumerations'; ru = 'Доступные перечисления';pl = 'Dostępne wyliczenia';es_ES = 'Enumeraciones disponibles';es_CO = 'Enumeraciones disponibles';tr = 'Mevcut numaralandırmalar';it = 'Numerazioni disponibili';de = 'Verfügbare Aufzählungen'"); 
		NewParameter.ListSynonym		= Synonym;
		
	EndDo;
	
EndProcedure

Procedure GetAvailableDataSourcesTable(TableDataSources, DocumentType) Export
	
	If Not ValueIsFilled(DocumentType) Then
		Return;
	EndIf;
	
	MetadataObject = Common.MetadataObjectByID(DocumentType);
	
	// Accumulation registers
	For Each Register In MetadataObject.RegisterRecords Do
		
		If Common.IsAccumulationRegister(Register) Then
			
			NewDataSource = TableDataSources.Add();
			NewDataSource.Field 	= StrTemplate("%1.%2", "AccumulationRegisters", Register.Name);
			NewDataSource.Synonym 	= StrTemplate("%1: %2", NStr("en = 'Accumulation register'; ru = 'Регистр накопления';pl = 'Rejestr akumulacji';es_ES = 'Registro de acumulación';es_CO = 'Registro de acumulación';tr = 'Birikim kaydı';it = 'Registro di accumulo';de = 'Akkumulationsregister'"), Register.Synonym);
			NewDataSource.ValueType = Undefined;
			NewDataSource.Category  = "AccumulationRegisters";
			NewDataSource.CategorySynonym = NStr("en = 'Accumulation registers'; ru = 'Регистры накопления';pl = 'Rejestry akumulacji';es_ES = 'Registros de acumulación';es_CO = 'Registros de acumulación';tr = 'Birikim kayıtları';it = 'Registri di accumulo';de = 'Akkumulationsregister'");		
			NewDataSource.ListSynonym	  = Register.Synonym;
			
		EndIf;
		
	EndDo;

	// Tabular sections
	For Each TabSection In MetadataObject.TabularSections Do
		
		NewDataSource = TableDataSources.Add();
		NewDataSource.Field 	= StrTemplate("%1.%2" , "TabularSections" , TabSection.Name);
		NewDataSource.Synonym 	= StrTemplate("%1: %2", NStr("en = 'Tabular section'; ru = 'Табличная часть';pl = 'Sekcja tabelaryczna';es_ES = 'Parte de tabla';es_CO = 'Parte de tabla';tr = 'Tablo bölümü';it = 'Sezione tabellare';de = 'Tabellenabschnitt'"), TabSection.Synonym);
		NewDataSource.ValueType = Undefined;
		NewDataSource.Category  = "TabularSections";
		NewDataSource.CategorySynonym = StrTemplate(NStr("en = '%1 tables'; ru = 'Таблицы %1';pl = '%1 tabel';es_ES = '%1 tablas';es_CO = '%1 tablas';tr = '%1 tablo';it = '%1 tabelle';de = '%1 Tabellen'"), DocumentType.Synonym);
		NewDataSource.ListSynonym	  = TabSection.Synonym;
		
	EndDo;
	
	ModuleManager = Common.ObjectManagerByFullName(DocumentType.FullName);
	Try
		EntryTypesArray = ModuleManager.EntryTypes();
	Except
		EntryTypesArray = New Array;
	EndTry;
	
	FieldID			= "AccountingEntriesData";
	FieldSynonym	= NStr("en = 'Accounting entries data'; ru = 'Данные бухгалтерских проводок';pl = 'Dane wpisów księgowych';es_ES = 'Datos de entradas contables';es_CO = 'Datos de entradas contables';tr = 'Muhasebe girişleri verisi';it = 'Dati voci di contabilità';de = 'Daten von Buchungen'");
	
	For Each EntryType In EntryTypesArray Do
		
		EntryTypeName = Common.EnumValueName(EntryType);
		EntryTypeSynonym = String(EntryType);
		
		NewDataSource = TableDataSources.Add();
		NewDataSource.Field				= StrTemplate("%1.%2"	, FieldID		, EntryTypeName);
		NewDataSource.Synonym			= StrTemplate("%1: %2"	, FieldSynonym	, EntryTypeSynonym);
		NewDataSource.ValueType			= Undefined;
		NewDataSource.Category			= FieldID;
		NewDataSource.CategorySynonym	= FieldSynonym;
		NewDataSource.ListSynonym		= EntryTypeSynonym;
		
	EndDo;
	
EndProcedure

Procedure GetAvailableAccountsList(AccountsTable, Parameters) Export
	
	ChartOfAccounts = Parameters.ChartOfAccounts;
	
	If Not ValueIsFilled(ChartOfAccounts) Then
		Return;
	EndIf;
	
	ChartOfAccountsEnum = Common.ObjectAttributeValue(ChartOfAccounts, "ChartOfAccounts");
	
	If Not ValueIsFilled(ChartOfAccountsEnum) Then
		Return;
	EndIf;
	
	Company = Parameters.Company;
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	DefaultGLAccounts.Ref AS Ref,
	|	&CategoryName AS Category,
	|	&CategorySynonym AS CategorySynonym,
	|	DefaultGLAccounts.Presentation AS Presentation
	|FROM
	|	Catalog.DefaultGLAccounts AS DefaultGLAccounts
	|WHERE
	|	&FilterDefaultGLAccounts
	|
	|UNION ALL
	|
	|SELECT
	|	ChartOfAccountsTable.Ref,
	|	&ChartOfAccountsName,
	|	&ChartOfAccountsSynonym,
	|	&ChartOfAccountsPresentation
	|FROM
	|	&ChartOfAccountsTable AS ChartOfAccountsTable
	|WHERE
	|	&CompanyFilter
	|	AND &ChartOfAccountsFilter
	|	AND &PeriodFilter";
	
	MasterChartOfAccount = AccountingApprovalServer.GetMasterByChartOfAccounts(ChartOfAccounts);
	
	ChartOfAccountsName = AccountingApprovalServer.GetChartOfAccountsName(ChartOfAccountsEnum);
	
	If MasterChartOfAccount And ValueIsFilled(Company) Then
		
		Query.Text = StrReplace(Query.Text, "&ChartOfAccountsTable", StrTemplate("ChartOfAccounts.%1.Companies", ChartOfAccountsName));
		Query.Text = StrReplace(Query.Text, "&ChartOfAccountsPresentation", "ChartOfAccountsTable.Ref.Presentation");
		Query.Text = StrReplace(Query.Text, "&CompanyFilter", "ChartOfAccountsTable.Company = &Company");
		
		Query.SetParameter("Company", Company);
	Else
		
		Query.Text = StrReplace(Query.Text, "&ChartOfAccountsTable", StrTemplate("ChartOfAccounts.%1", ChartOfAccountsName));
		Query.Text = StrReplace(Query.Text, "&ChartOfAccountsPresentation", "ChartOfAccountsTable.Presentation");
		Query.Text = StrReplace(Query.Text, "&CompanyFilter", "True"); 
		
	EndIf;
	
	If MasterChartOfAccount And Parameters.Property("UsePeriodFilter") And Parameters.UsePeriodFilter Then
		
		Query.Text = StrReplace(Query.Text, "&PeriodFilter",  
			"(ChartOfAccountsTable.StartDate = DATETIME(1, 1, 1)
			|				AND &EndOfPeriod = DATETIME(1, 1, 1)
			|				AND ChartOfAccountsTable.EndDate = DATETIME(1, 1, 1)
			|			OR ChartOfAccountsTable.StartDate = DATETIME(1, 1, 1)
			|				AND &EndOfPeriod <> DATETIME(1, 1, 1)
			|				AND ChartOfAccountsTable.EndDate = DATETIME(1, 1, 1)
			|			OR ChartOfAccountsTable.StartDate = DATETIME(1, 1, 1)
			|				AND &EndOfPeriod <> DATETIME(1, 1, 1)
			|				AND ChartOfAccountsTable.EndDate <> DATETIME(1, 1, 1)
			|				AND ChartOfAccountsTable.EndDate >= &EndOfPeriod
			|			OR ChartOfAccountsTable.StartDate <> DATETIME(1, 1, 1)
			|				AND ChartOfAccountsTable.StartDate <= &BeginOfPeriod
			|				AND &EndOfPeriod = DATETIME(1, 1, 1)
			|				AND ChartOfAccountsTable.EndDate = DATETIME(1, 1, 1)
			|			OR ChartOfAccountsTable.StartDate <> DATETIME(1, 1, 1)
			|				AND ChartOfAccountsTable.StartDate <= &BeginOfPeriod
			|				AND &EndOfPeriod <> DATETIME(1, 1, 1)
			|				AND ChartOfAccountsTable.EndDate = DATETIME(1, 1, 1)
			|			OR ChartOfAccountsTable.StartDate <> DATETIME(1, 1, 1)
			|				AND ChartOfAccountsTable.StartDate <= &BeginOfPeriod
			|				AND &EndOfPeriod <> DATETIME(1, 1, 1)
			|				AND ChartOfAccountsTable.EndDate <> DATETIME(1, 1, 1)
			|				AND ChartOfAccountsTable.EndDate >= &EndOfPeriod)");
		
		BeginOfPeriod 	= Parameters.BeginOfPeriod;
		EndOfPeriod 	= Parameters.EndOfPeriod;
		
		Query.SetParameter("BeginOfPeriod"	, BeginOfPeriod);
		Query.SetParameter("EndOfPeriod"	, EndOfPeriod);
		
	Else
		
		Query.Text = StrReplace(Query.Text, "&PeriodFilter", "True");
	
	EndIf;
	
	If MasterChartOfAccount Then
		Query.Text = StrReplace(Query.Text,
			"&ChartOfAccountsFilter",
			?(ValueIsFilled(Company), 
				"ChartOfAccountsTable.Ref.ChartOfAccounts = &ChartOfAccounts",
				"ChartOfAccountsTable.ChartOfAccounts = &ChartOfAccounts"));
	Else
		Query.Text = StrReplace(Query.Text, "&ChartOfAccountsFilter", "TRUE");
	EndIf;
	
	Query.Text = StrReplace(Query.Text, "&FilterDefaultGLAccounts", "FALSE");
	
	Query.SetParameter("ChartOfAccounts"		, ChartOfAccounts);
	Query.SetParameter("ChartOfAccountsName"	, ChartOfAccountsName);
	Query.SetParameter("ChartOfAccountsSynonym"	, String(ChartOfAccountsEnum));
	Query.SetParameter("CategoryName"			, "DefaultGLAccounts");
	Query.SetParameter("CategorySynonym"		, NStr("en = 'Default GL Accounts'; ru = 'Счета учета по умолчанию';pl = 'Domyślne konta księgowe';es_ES = 'Cuentas del libro mayor por defecto';es_CO = 'Cuentas del libro mayor por defecto';tr = 'Varsayılan muhasebe hesapları';it = 'Conti mastro predefiniti';de = 'Standard-Hauptbuch-Konten'"));
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		
		NewAccRow = AccountsTable.Add();
		NewAccRow.Field		= SelectionDetailRecords.Ref;
		NewAccRow.Synonym	= SelectionDetailRecords.Presentation;
		NewAccRow.ValueType	= Undefined;
		NewAccRow.Category	= SelectionDetailRecords.Category;
		NewAccRow.CategorySynonym = SelectionDetailRecords.CategorySynonym;
		NewAccRow.ListSynonym	  = SelectionDetailRecords.Presentation;
		
	EndDo;
	
EndProcedure 

Procedure GetDimensionsListByAccount(TableAttributes, TableNestedAttributes, Parameters) Export
	
	Account = Parameters.Account;
	
	If Not ValueIsFilled(Account) Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	MasterChartOfAccountsAnalyticalDimensions.AnalyticalDimension AS AnalyticalDimension,
	|	MasterChartOfAccountsAnalyticalDimensions.AnalyticalDimension.ValueType AS ValueType,
	|	PRESENTATION(MasterChartOfAccountsAnalyticalDimensions.AnalyticalDimension) AS Presentation,
	|	MasterChartOfAccountsAnalyticalDimensions.LineNumber AS LineNumber
	|FROM
	|	ChartOfAccounts.MasterChartOfAccounts.AnalyticalDimensions AS MasterChartOfAccountsAnalyticalDimensions
	|WHERE
	|	MasterChartOfAccountsAnalyticalDimensions.Ref = &Account";
	
	Query.SetParameter("Account", Account);
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		
		NewParameter = TableAttributes.Add();
		
		NewParameter.Field		 = StrTemplate("ExtDimension%1", Format(SelectionDetailRecords.LineNumber, "NDS=; NGS=; NG=")) ;
		NewParameter.Synonym	 = SelectionDetailRecords.Presentation;
		NewParameter.ValueType	 = SelectionDetailRecords.ValueType;
		NewParameter.ListSynonym = SelectionDetailRecords.Presentation;
		
		SupplementNestedAttributes(SelectionDetailRecords.ValueType, TableNestedAttributes, NewParameter.Field, NewParameter.Synonym, NewParameter.Category);
		
	EndDo;
		
EndProcedure 

Procedure GetDimensionsList(TableAttributes, TableNestedAttributes, Parameters) Export
	
	DimensionsArray = Parameters.DimensionsArray;
	AdditionalArray = Parameters.AdditionalArray;
	
	If DimensionsArray.Count() = 0 And AdditionalArray.Count() = 0 Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	ManagerialAnalyticalDimensionTypes.Ref AS AnalyticalDimension,
	|	ManagerialAnalyticalDimensionTypes.ValueType AS ValueType,
	|	ManagerialAnalyticalDimensionTypes.Presentation AS Presentation,
	|	ManagerialAnalyticalDimensionTypes.Code AS Code
	|FROM
	|	ChartOfCharacteristicTypes.ManagerialAnalyticalDimensionTypes AS ManagerialAnalyticalDimensionTypes
	|WHERE
	|	ManagerialAnalyticalDimensionTypes.Ref IN(&DimensionsArray)";
	
	Query.SetParameter("DimensionsArray", DimensionsArray);
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		
		NewParameter = TableAttributes.Add();
		
		NewParameter.Field			= StrTemplate("%1", Format(SelectionDetailRecords.Code, "NDS=; NGS=; NG="));
		NewParameter.Synonym		= SelectionDetailRecords.Presentation;
		NewParameter.ValueType		= SelectionDetailRecords.ValueType;
		NewParameter.ListSynonym	= SelectionDetailRecords.Presentation;
		
		SupplementNestedAttributes(
			NewParameter.ValueType,
			TableNestedAttributes,
			NewParameter.Field,
			NewParameter.Synonym,
			NewParameter.Category);
		
	EndDo;
	
	For Each Item In AdditionalArray Do
		
		NewParameter = TableAttributes.Add();
		
		NewParameter.Field			= StrTemplate("%1", Format(Item.Name, "NDS=; NGS=; NG="));
		NewParameter.Synonym		= Item.Presentation;
		NewParameter.ValueType		= Item.Type;
		NewParameter.ListSynonym	= Item.Presentation;
		
		SupplementNestedAttributes(
			NewParameter.ValueType,
			TableNestedAttributes,
			NewParameter.Field,
			NewParameter.Synonym,
			NewParameter.Category);
		
	EndDo;
	
EndProcedure 

Procedure SupplementParametersTableWithDocumentsAttributes(TableAvailableParameters, TableNestedAttributes, DocumentType, TypeRestriction = Undefined, TypeRestrictionIsNumeric = False, ExcludedFields = Undefined) Export

	If Not ValueIsFilled(DocumentType) Then
		Return;
	EndIf;
	
	DocMetadata = Common.MetadataObjectByID(DocumentType);
	
	If ExcludedFields = Undefined Then
		ExcludedFields = New Array;
	EndIf;
	
	For Each DocAttribute In DocMetadata.Attributes Do
		
		If CheckObsolete(DocAttribute.Name, DocAttribute.Synonym) 
			Or ExcludedFields.Find(Upper(DocAttribute.Name)) <> Undefined Then
			Continue;
		EndIf;
		
		DocAttributeSynonym = ?(ValueIsFilled(DocAttribute.Synonym), DocAttribute.Synonym, DocAttribute.Name);
		
		NewParameter = TableAvailableParameters.Add();
		NewParameter.Field		= StrTemplate("Document.%1.%2", DocMetadata.Name, DocAttribute.Name);
		NewParameter.Synonym	= StrTemplate("%1 - %2", DocMetadata.Synonym, DocAttributeSynonym);
		NewParameter.ValueType	= DocAttribute.Type;
		NewParameter.Category	= DocMetadata.Name;
		NewParameter.CategorySynonym  = StrTemplate("%1", DocMetadata.Synonym);
		NewParameter.ListSynonym	  = DocAttributeSynonym;
		NewParameter.RestrictedByType = CheckTypeRestriction(TypeRestriction, TypeRestrictionIsNumeric, DocAttribute.Type);
		
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("TypeRestriction"			, TypeRestriction);
		AdditionalParameters.Insert("TypeRestrictionIsNumeric"	, TypeRestrictionIsNumeric);
		AdditionalParameters.Insert("ExcludedFields"			, ExcludedFields);
		
		SupplementNestedAttributes(
			DocAttribute.Type,
			TableNestedAttributes,
			NewParameter.Field,
			NewParameter.Synonym,
			NewParameter.Category,
			AdditionalParameters);
		
	EndDo;
	
	For Each DocAttribute In DocMetadata.StandardAttributes Do
		
		If CheckObsolete(DocAttribute.Name, DocAttribute.Synonym) 
			Or ExcludedFields.Find(Upper(DocAttribute.Name)) <> Undefined Then
			Continue;
		EndIf;
		
		DocAttributeSynonym = ?(ValueIsFilled(DocAttribute.Synonym), DocAttribute.Synonym, DocAttribute.Name);
		DocAttributeSynonym = ?(DocAttributeSynonym = DriveServer.GetAttributeVariant("Ref"),
			NStr("en = 'Document reference'; ru = 'Ссылка на документ';pl = 'Dokument referencyjny';es_ES = 'Referencia al documento';es_CO = 'Referencia al documento';tr = 'Belge bağlantısı';it = 'Riferimento al documento';de = 'Referenz zum Dokument'"),
			DocAttributeSynonym);
		
		NewParameter = TableAvailableParameters.Add();
		NewParameter.Field				= StrTemplate("Document.%1.%2"  , DocMetadata.Name   , DocAttribute.Name);
		NewParameter.Synonym			= StrTemplate("%1 - %2", DocMetadata.Synonym, DocAttributeSynonym);
		NewParameter.ValueType			= DocAttribute.Type;
		NewParameter.Category			= DocMetadata.Name;
		NewParameter.CategorySynonym	= DocMetadata.Synonym;
		NewParameter.ListSynonym		= DocAttributeSynonym;
		NewParameter.RestrictedByType	= CheckTypeRestriction(TypeRestriction, TypeRestrictionIsNumeric, DocAttribute.Type);
		
	EndDo;
	
EndProcedure

Procedure SupplementParametersTableWithDocumentsAdditionalAttributes(TableAvailableParameters, DocumentType, TypeRestriction = Undefined, TypeRestrictionIsNumeric = False) Export

	If Not ValueIsFilled(DocumentType) Then
		Return;
	EndIf;
	
	DocMetadata = Common.MetadataObjectByID(DocumentType);
	
	PredefinedName = StrTemplate("Document_%1", DocMetadata.Name);
	PredefinedNamesArray = Metadata.Catalogs.AdditionalAttributesAndInfoSets.GetPredefinedNames();
	
	If PredefinedNamesArray.Find(PredefinedName) <> Undefined Then
	
		Query = New Query;
		Query.Text = 
		"SELECT
		|	AdditionalAttributesAndInfoSetsAdditionalAttributes.Property AS Property,
		|	AdditionalAttributesAndInfo.ValueType AS ValueType,
		|	AdditionalAttributesAndInfo.Name AS Name
		|FROM
		|	Catalog.AdditionalAttributesAndInfoSets.AdditionalAttributes AS AdditionalAttributesAndInfoSetsAdditionalAttributes
		|		LEFT JOIN ChartOfCharacteristicTypes.AdditionalAttributesAndInfo AS AdditionalAttributesAndInfo
		|		ON AdditionalAttributesAndInfoSetsAdditionalAttributes.Property = AdditionalAttributesAndInfo.Ref
		|WHERE
		|	AdditionalAttributesAndInfoSetsAdditionalAttributes.Ref = &Ref";
		
		Query.SetParameter("Ref", Catalogs.AdditionalAttributesAndInfoSets[PredefinedName]);
		
		QueryResult = Query.Execute();
		
		SelectionDetailRecords = QueryResult.Select();
		
		While SelectionDetailRecords.Next() Do
		
			NewParameter = TableAvailableParameters.Add();
			NewParameter.Field				= StrTemplate("Document.%1.%2.%3" , DocMetadata.Name, "AdditionalAttribute" , SelectionDetailRecords.Name);
			NewParameter.Synonym			= StrTemplate("%1 - %2"  , NStr("en = 'Additional attribute'; ru = 'Дополнительный реквизит';pl = 'Dodatkowy atrybut';es_ES = '(Atributo adicional)';es_CO = '(Atributo adicional)';tr = 'Ek öznitelik';it = 'Attributo aggiuntivo';de = 'Zusätzliches Attribut'"), SelectionDetailRecords.Property);
			NewParameter.ValueType			= SelectionDetailRecords.ValueType;
			NewParameter.Category			= DocMetadata.Name;
			NewParameter.CategorySynonym	= DocMetadata.Synonym;
			NewParameter.ListSynonym		= SelectionDetailRecords.Property;
			NewParameter.RestrictedByType	= CheckTypeRestriction(TypeRestriction, TypeRestrictionIsNumeric, SelectionDetailRecords.ValueType);
			
		EndDo;
	EndIf;
	
EndProcedure

Procedure SupplementParametersTableWithConstants(TableAvailableParameters, TableNestedAttributes) Export

	For Each Constant In Metadata.Constants Do
		
		If CheckObsolete(Constant.Name, Constant.Synonym) Then
			Continue;
		EndIf;
		
		NewParameter = TableAvailableParameters.Add();
		NewParameter.Field		= StrTemplate("%1.%2"  , "Constant" , Constant.Name);
		NewParameter.Synonym 	= StrTemplate("%1 - %2", NStr("en = 'Settings'; ru = 'Настройки';pl = 'Ustawienia';es_ES = 'Configuraciones';es_CO = 'Configuraciones';tr = 'Ayarlar';it = 'Impostazioni';de = 'Einstellungen'") , Constant.Synonym);
		NewParameter.ValueType	= Constant.Type;
		NewParameter.Category	= "Constants";
		NewParameter.CategorySynonym = NStr("en = 'Settings'; ru = 'Настройки';pl = 'Ustawienia';es_ES = 'Configuraciones';es_CO = 'Configuraciones';tr = 'Ayarlar';it = 'Impostazioni';de = 'Einstellungen'");
		NewParameter.ListSynonym	 = Constant.Synonym;
		
		SupplementNestedAttributes(
			Constant.Type,
			TableNestedAttributes,
			NewParameter.Field,
			NewParameter.Synonym,
			NewParameter.Category);

	EndDo;
	
EndProcedure

Procedure SupplementParametersTableWithAP(TableAvailableParameters, TableNestedAttributes) Export
	
	For Each APField In Metadata.InformationRegisters.AccountingPolicy.Resources Do
		
		If CheckObsolete(APField.Name, APField.Synonym) Then
			Continue;
		EndIf;

		NewParameter = TableAvailableParameters.Add();
		NewParameter.Field		= StrTemplate("%1.%2"  , "AccountingPolicy" , APField.Name);
		NewParameter.Synonym 	= StrTemplate("%1 - %2", NStr("en = 'Accounting policy settings'; ru = 'Настройки учетной политики';pl = 'Ustawienia polityki rachunkowości';es_ES = 'Ajustes de la política de contabilidad';es_CO = 'Ajustes de la política de contabilidad';tr = 'Muhasebe politikası ayarları';it = 'Impostazioni politica contabile';de = 'Einstellungen von Bilanzierungsrichtlinien'"), APField.Synonym);
		NewParameter.ValueType	= APField.Type;
		NewParameter.Category	= "AccountingPolicy";
		NewParameter.CategorySynonym = NStr("en = 'Accounting policy settings'; ru = 'Настройки учетной политики';pl = 'Ustawienia polityki rachunkowości';es_ES = 'Ajustes de la política de contabilidad';es_CO = 'Ajustes de la política de contabilidad';tr = 'Muhasebe politikası ayarları';it = 'Impostazioni politica contabile';de = 'Einstellungen von Bilanzierungsrichtlinien'"); 
		NewParameter.ListSynonym	 = APField.Synonym;
		
		SupplementNestedAttributes(
			APField.Type,
			TableNestedAttributes,
			NewParameter.Field,
			NewParameter.Synonym,
			NewParameter.Category);
		
	EndDo;
	
EndProcedure

Procedure SupplementParametersTableWithDataSourceAttributes(TableAvailableParameters, TableNestedAttributes, DataSource, DocumentType, TypeRestriction = Undefined, TypeRestrictionIsNumeric = False, ExcludedFields = Undefined) Export
	
	If Not ValueIsFilled(DataSource) Then
		Return;
	EndIf;
	
	DataSourceArray = StrSplit(DataSource, ".");
	
	If DataSourceArray.Count() <> 2 Then
		Return;
	EndIf;
	
	If ExcludedFields = Undefined Then
		ExcludedFields = New Array;
	EndIf;
	
	If DataSourceArray[0] = "TabularSections" Then
		
		If Not ValueIsFilled(DocumentType) Then
			Return;
		EndIf;
		
		DocMetadata = Common.MetadataObjectByID(DocumentType);
		
		CurMetadata = DocMetadata.TabularSections[DataSourceArray[1]];
		
		For Each Field In CurMetadata.Attributes Do
			
			If CheckObsolete(Field.Name, Field.Synonym) 
				Or ExcludedFields.Find(Upper(Field.Name)) <> Undefined Then
				Continue;
			EndIf;
			
			FieldSynonym = ?(ValueIsFilled(Field.Synonym), Field.Synonym, Field.Name);
			
			NewParameter = TableAvailableParameters.Add();
			NewParameter.Field		= StrTemplate("TabularSection.%1.%2"  , CurMetadata.Name   , Field.Name);
			NewParameter.Synonym	= StrTemplate("%1 - %2", CurMetadata.Synonym, FieldSynonym);
			NewParameter.ValueType	= Field.Type;
			NewParameter.Category	= DataSource;
			NewParameter.CategorySynonym = NStr("en = 'Data source'; ru = 'Источник данных';pl = 'Źródło danych';es_ES = 'Fuente de datos';es_CO = 'Fuente de datos';tr = 'Veri kaynağı';it = 'Fonte dati';de = 'Datenquelle'"); 
			NewParameter.ListSynonym	 = FieldSynonym;
			NewParameter.RestrictedByType = CheckTypeRestriction(TypeRestriction, TypeRestrictionIsNumeric, Field.Type);
			
			AdditionalParameters = New Structure;
			AdditionalParameters.Insert("TypeRestriction"			, TypeRestriction);
			AdditionalParameters.Insert("TypeRestrictionIsNumeric"	, TypeRestrictionIsNumeric);
			AdditionalParameters.Insert("ExcludedFields"			, ExcludedFields);
			AdditionalParameters.Insert("DocumentType"				, DocumentType);
			AdditionalParameters.Insert("FieldName"					, Field.Name);
			
			SupplementNestedAttributes(
				Field.Type,
				TableNestedAttributes,
				NewParameter.Field,
				NewParameter.Synonym,
				NewParameter.Category,
				AdditionalParameters);

		EndDo;
		
	ElsIf DataSourceArray[0] = "AccountingEntriesData" Then
		
		If Not ValueIsFilled(DocumentType) Then
			Return;
		EndIf;
		
		ModuleManager = Common.ObjectManagerByFullName(DocumentType.FullName);
		CurMetadata = ModuleManager.AccountingFields()[DataSourceArray[1]];
		
		If CurMetadata.Property("MainDetails") Then
			
			For Each Field In CurMetadata.MainDetails Do
				
				If ExcludedFields.Find(Upper(Field.Key)) <> Undefined Then
					Continue;
				EndIf;
				
				FieldType = GetTypeOfRegisterField(Field.Key);
				
				NewParameter = TableAvailableParameters.Add();
				NewParameter.Field				= StrTemplate("Register.%1.%2"	, "AccountingEntriesData"		, Field.Key);
				NewParameter.Synonym			= StrTemplate("%1 - %2"	, NStr("en = 'Accounting entries data'; ru = 'Данные бухгалтерских проводок';pl = 'Dane wpisów księgowych';es_ES = 'Datos de entradas contables';es_CO = 'Datos de entradas contables';tr = 'Muhasebe girişleri verisi';it = 'Dati voci di contabilità';de = 'Daten von Buchungen'"), Field.Value);
				NewParameter.ValueType			= FieldType;
				NewParameter.Category			= DataSource;
				NewParameter.CategorySynonym	= NStr("en = 'Data source'; ru = 'Источник данных';pl = 'Źródło danych';es_ES = 'Fuente de datos';es_CO = 'Fuente de datos';tr = 'Veri kaynağı';it = 'Fonte dati';de = 'Datenquelle'"); 
				NewParameter.ListSynonym		= Field.Value;
				NewParameter.RestrictedByType	= CheckTypeRestriction(TypeRestriction, TypeRestrictionIsNumeric, FieldType);
				
				AdditionalParameters = New Structure;
				AdditionalParameters.Insert("TypeRestriction"			, TypeRestriction);
				AdditionalParameters.Insert("TypeRestrictionIsNumeric"	, TypeRestrictionIsNumeric);
				AdditionalParameters.Insert("ExcludedFields"			, ExcludedFields);
				AdditionalParameters.Insert("DocumentType"				, DocumentType);
				AdditionalParameters.Insert("FieldName"					, Field.Key);
				
				SupplementNestedAttributes(
					FieldType,
					TableNestedAttributes,
					NewParameter.Field,
					NewParameter.Synonym,
					NewParameter.Category,
					AdditionalParameters);
				
			EndDo;
			
		EndIf;
		
		For Each Field In CurMetadata.AdditionalDetails Do
			
			If ExcludedFields.Find(Upper(Field.Key)) <> Undefined Then
				Continue;
			EndIf;
			
			FieldType = GetTypeOfRegisterField(Field.Key);
			
			NewParameter = TableAvailableParameters.Add();
			NewParameter.Field 		= StrTemplate("Register.%1.%2"  , "AccountingEntriesData", Field.Key);
			NewParameter.Synonym 	= StrTemplate("%1 - %2", NStr("en = 'Accounting entries data'; ru = 'Данные бухгалтерских проводок';pl = 'Dane wpisów księgowych';es_ES = 'Datos de entradas contables';es_CO = 'Datos de entradas contables';tr = 'Muhasebe girişleri verisi';it = 'Dati voci di contabilità';de = 'Daten von Buchungen'"), Field.Value);
			NewParameter.ValueType 	= FieldType;
			NewParameter.Category   = DataSource;
			NewParameter.CategorySynonym = NStr("en = 'Data source'; ru = 'Источник данных';pl = 'Źródło danych';es_ES = 'Fuente de datos';es_CO = 'Fuente de datos';tr = 'Veri kaynağı';it = 'Fonte dati';de = 'Datenquelle'"); 
			NewParameter.ListSynonym 	 = Field.Value;
			NewParameter.RestrictedByType = CheckTypeRestriction(TypeRestriction, TypeRestrictionIsNumeric, FieldType);
			
			AdditionalParameters = New Structure;
			AdditionalParameters.Insert("TypeRestriction"			, TypeRestriction);
			AdditionalParameters.Insert("TypeRestrictionIsNumeric"	, TypeRestrictionIsNumeric);
			AdditionalParameters.Insert("ExcludedFields"			, ExcludedFields);
			AdditionalParameters.Insert("DocumentType"				, DocumentType);
			AdditionalParameters.Insert("FieldName"					, Field.Key);
			
			SupplementNestedAttributes(
				FieldType,
				TableNestedAttributes,
				NewParameter.Field,
				NewParameter.Synonym,
				NewParameter.Category,
				AdditionalParameters);

		EndDo;
		
		For Each Field In CurMetadata.DebitDetails Do
			
			If ExcludedFields.Find(Upper(Field.Key)) <> Undefined Then
				Continue;
			EndIf;
			
			FieldType	= GetTypeOfRegisterField(Field.Key);
			Synonym		= StrTemplate("Debit %1", Field.Value);
			
			NewParameter = TableAvailableParameters.Add();
			NewParameter.Field 		= StrTemplate("Register.%1.%2"  , "AccountingEntriesData", Field.Key);
			NewParameter.Synonym 	= StrTemplate("%1 - %2", NStr("en = 'Accounting entries data'; ru = 'Данные бухгалтерских проводок';pl = 'Dane wpisów księgowych';es_ES = 'Datos de entradas contables';es_CO = 'Datos de entradas contables';tr = 'Muhasebe girişleri verisi';it = 'Dati voci di contabilità';de = 'Daten von Buchungen'"), Synonym);
			NewParameter.DrCr		= Enums.DebitCredit.Dr;
			NewParameter.ValueType 	= FieldType;
			NewParameter.Category   = DataSource;
			NewParameter.CategorySynonym = NStr("en = 'Data source'; ru = 'Источник данных';pl = 'Źródło danych';es_ES = 'Fuente de datos';es_CO = 'Fuente de datos';tr = 'Veri kaynağı';it = 'Fonte dati';de = 'Datenquelle'"); 
			NewParameter.ListSynonym	 = Synonym;
			NewParameter.RestrictedByType = CheckTypeRestriction(TypeRestriction, TypeRestrictionIsNumeric, FieldType);
			
			AdditionalParameters = New Structure;
			AdditionalParameters.Insert("TypeRestriction"			, TypeRestriction);
			AdditionalParameters.Insert("TypeRestrictionIsNumeric"	, TypeRestrictionIsNumeric);
			AdditionalParameters.Insert("ExcludedFields"			, ExcludedFields);
			AdditionalParameters.Insert("DocumentType"				, DocumentType);
			AdditionalParameters.Insert("FieldName"					, Field.Key);
			AdditionalParameters.Insert("DrCr"						, NewParameter.DrCr);
			
			SupplementNestedAttributes(FieldType,
				TableNestedAttributes,
				NewParameter.Field,
				NewParameter.Synonym,
				NewParameter.Category,
				AdditionalParameters);

		EndDo;
		
		For Each Field In CurMetadata.CreditDetails Do
			
			If ExcludedFields.Find(Upper(Field.Key)) <> Undefined Then
				Continue;
			EndIf;
			
			FieldType	= GetTypeOfRegisterField(Field.Key);
			Synonym		= StrTemplate("Credit %1", Field.Value);

			NewParameter = TableAvailableParameters.Add();
			NewParameter.Field		= StrTemplate("Register.%1.%2"  , "AccountingEntriesData", Field.Key);
			NewParameter.Synonym	= StrTemplate("%1 - %2", NStr("en = 'Accounting entries data'; ru = 'Данные бухгалтерских проводок';pl = 'Dane wpisów księgowych';es_ES = 'Datos de entradas contables';es_CO = 'Datos de entradas contables';tr = 'Muhasebe girişleri verisi';it = 'Dati voci di contabilità';de = 'Daten von Buchungen'"), Synonym);
			NewParameter.DrCr		= Enums.DebitCredit.Cr;
			NewParameter.ValueType	= FieldType;
			NewParameter.Category	= DataSource;
			NewParameter.CategorySynonym = NStr("en = 'Data source'; ru = 'Источник данных';pl = 'Źródło danych';es_ES = 'Fuente de datos';es_CO = 'Fuente de datos';tr = 'Veri kaynağı';it = 'Fonte dati';de = 'Datenquelle'"); 
			NewParameter.ListSynonym 	 = Synonym;
			NewParameter.RestrictedByType = CheckTypeRestriction(TypeRestriction, TypeRestrictionIsNumeric, FieldType);
			
			AdditionalParameters = New Structure;
			AdditionalParameters.Insert("TypeRestriction"			, TypeRestriction);
			AdditionalParameters.Insert("TypeRestrictionIsNumeric"	, TypeRestrictionIsNumeric);
			AdditionalParameters.Insert("ExcludedFields"			, ExcludedFields);
			AdditionalParameters.Insert("DocumentType"				, DocumentType);
			AdditionalParameters.Insert("FieldName"					, Field.Key);
			AdditionalParameters.Insert("DrCr"						, NewParameter.DrCr);
			
			SupplementNestedAttributes(FieldType,
				TableNestedAttributes,
				NewParameter.Field,
				NewParameter.Synonym,
				NewParameter.Category,
				AdditionalParameters);

		EndDo;
		
		For Each Field In CurMetadata.Amounts Do
			
			If ExcludedFields.Find(Upper(Field.Key)) <> Undefined Then
				Continue;
			EndIf;
			
			FieldType = GetTypeOfRegisterField(Field.Key);
			
			NewParameter = TableAvailableParameters.Add();
			NewParameter.Field 		= StrTemplate("Register.%1.%2"  , "AccountingEntriesData", Field.Key);
			NewParameter.Synonym 	= StrTemplate("%1 - %2", NStr("en = 'Accounting entries data'; ru = 'Данные бухгалтерских проводок';pl = 'Dane wpisów księgowych';es_ES = 'Datos de entradas contables';es_CO = 'Datos de entradas contables';tr = 'Muhasebe girişleri verisi';it = 'Dati voci di contabilità';de = 'Daten von Buchungen'"), Field.Value);
			NewParameter.ValueType 	= FieldType;
			NewParameter.Category   = DataSource;
			NewParameter.CategorySynonym = NStr("en = 'Data source'; ru = 'Источник данных';pl = 'Źródło danych';es_ES = 'Fuente de datos';es_CO = 'Fuente de datos';tr = 'Veri kaynağı';it = 'Fonte dati';de = 'Datenquelle'"); 
			NewParameter.ListSynonym 	 = Field.Value;
			NewParameter.RestrictedByType = CheckTypeRestriction(TypeRestriction, TypeRestrictionIsNumeric, FieldType);
			
			AdditionalParameters = New Structure;
			AdditionalParameters.Insert("TypeRestriction"			, TypeRestriction);
			AdditionalParameters.Insert("TypeRestrictionIsNumeric"	, TypeRestrictionIsNumeric);
			AdditionalParameters.Insert("ExcludedFields"			, ExcludedFields);
			AdditionalParameters.Insert("DocumentType"				, DocumentType);
			AdditionalParameters.Insert("FieldName"					, Field.Key);
			
			SupplementNestedAttributes(
				FieldType,
				TableNestedAttributes,
				NewParameter.Field,
				NewParameter.Synonym,
				NewParameter.Category,
				AdditionalParameters);

		EndDo;
		
	Else
		
		CurMetadata = Metadata[DataSourceArray[0]][DataSourceArray[1]];
		CurMetadataCollection = CurMetadata.Dimensions;
		
		For Each Field In CurMetadata.Dimensions Do
			
			If CheckObsolete(Field.Name, Field.Synonym) Or ExcludedFields.Find(Upper(Field.Name)) <> Undefined Then
				Continue;
			EndIf;
			
			NewParameter = TableAvailableParameters.Add();
			NewParameter.Field		= StrTemplate("Register.%1.%2", CurMetadata.Name, Field.Name);
			NewParameter.Synonym	= StrTemplate("%1 - %2", CurMetadata.Synonym, Field.Synonym);
			NewParameter.ValueType	= Field.Type;
			NewParameter.Category	= DataSource;
			NewParameter.CategorySynonym = NStr("en = 'Data source'; ru = 'Источник данных';pl = 'Źródło danych';es_ES = 'Fuente de datos';es_CO = 'Fuente de datos';tr = 'Veri kaynağı';it = 'Fonte dati';de = 'Datenquelle'"); 
			NewParameter.ListSynonym	 = Field.Synonym;
			NewParameter.RestrictedByType = CheckTypeRestriction(TypeRestriction, TypeRestrictionIsNumeric, Field.Type);
			
			AdditionalParameters = New Structure;
			AdditionalParameters.Insert("TypeRestriction"			, TypeRestriction);
			AdditionalParameters.Insert("TypeRestrictionIsNumeric"	, TypeRestrictionIsNumeric);
			AdditionalParameters.Insert("ExcludedFields"			, ExcludedFields);
			AdditionalParameters.Insert("DocumentType"				, DocumentType);
			AdditionalParameters.Insert("FieldName"					, Field.Name);
			
			SupplementNestedAttributes(
				Field.Type,
				TableNestedAttributes,
				NewParameter.Field,
				NewParameter.Synonym,
				NewParameter.Category,
				AdditionalParameters);

		EndDo;
		
		For Each Field In CurMetadata.Resources Do
			
			If CheckObsolete(Field.Name, Field.Synonym) 
				Or ExcludedFields.Find(Upper(Field.Name)) <> Undefined Then
				Continue;
			EndIf;
			
			NewParameter = TableAvailableParameters.Add();
			NewParameter.Field		= StrTemplate("Register.%1.%2", CurMetadata.Name, Field.Name);
			NewParameter.Synonym	= StrTemplate("%1 - %2", CurMetadata.Synonym, Field.Synonym);
			NewParameter.ValueType	= Field.Type;
			NewParameter.Category	= DataSource;
			NewParameter.CategorySynonym = NStr("en = 'Data source'; ru = 'Источник данных';pl = 'Źródło danych';es_ES = 'Fuente de datos';es_CO = 'Fuente de datos';tr = 'Veri kaynağı';it = 'Fonte dati';de = 'Datenquelle'"); 
			NewParameter.ListSynonym	 = Field.Synonym;
			NewParameter.RestrictedByType = CheckTypeRestriction(TypeRestriction, TypeRestrictionIsNumeric, Field.Type);
			
			AdditionalParameters = New Structure;
			AdditionalParameters.Insert("TypeRestriction"			, TypeRestriction);
			AdditionalParameters.Insert("TypeRestrictionIsNumeric"	, TypeRestrictionIsNumeric);
			AdditionalParameters.Insert("ExcludedFields"			, ExcludedFields);
			AdditionalParameters.Insert("DocumentType"				, DocumentType);
			AdditionalParameters.Insert("FieldName"					, Field.Name);
			
			SupplementNestedAttributes(
				Field.Type,
				TableNestedAttributes,
				NewParameter.Field,
				NewParameter.Synonym,
				NewParameter.Category,
				AdditionalParameters);
			
		EndDo;
		
		For Each Field In CurMetadata.Attributes Do
			
			If CheckObsolete(Field.Name, Field.Synonym) 
				Or ExcludedFields.Find(Upper(Field.Name)) <> Undefined Then
				Continue;
			EndIf;
			
			NewParameter = TableAvailableParameters.Add();
			NewParameter.Field		= StrTemplate("Register.%1.%2", CurMetadata.Name, Field.Name);
			NewParameter.Synonym	= StrTemplate("%1 - %2", CurMetadata.Synonym, Field.Synonym);
			NewParameter.ValueType	= Field.Type;
			NewParameter.Category	= DataSource;
			NewParameter.CategorySynonym = NStr("en = 'Data source'; ru = 'Источник данных';pl = 'Źródło danych';es_ES = 'Fuente de datos';es_CO = 'Fuente de datos';tr = 'Veri kaynağı';it = 'Fonte dati';de = 'Datenquelle'");
			NewParameter.ListSynonym	 = Field.Synonym;
			NewParameter.RestrictedByType = CheckTypeRestriction(TypeRestriction, TypeRestrictionIsNumeric, Field.Type);
			
			AdditionalParameters = New Structure;
			AdditionalParameters.Insert("TypeRestriction"			, TypeRestriction);
			AdditionalParameters.Insert("TypeRestrictionIsNumeric"	, TypeRestrictionIsNumeric);
			AdditionalParameters.Insert("ExcludedFields"			, ExcludedFields);
			AdditionalParameters.Insert("DocumentType"				, DocumentType);
			AdditionalParameters.Insert("FieldName"					, Field.Name);
			
			SupplementNestedAttributes(
				Field.Type,
				TableNestedAttributes,
				NewParameter.Field,
				NewParameter.Synonym,
				NewParameter.Category,
				AdditionalParameters);
			
			EndDo;
			
		For Each Field In CurMetadata.StandardAttributes Do
			
			If (Not ValueIsFilled(Field.Synonym) And Field.Name <> "RecordType")
				Or ExcludedFields.Find(Upper(Field.Name)) <> Undefined Then
				Continue;
			EndIf;
			
			NewParameter = TableAvailableParameters.Add();
			NewParameter.Field		= StrTemplate("Register.%1.%2", CurMetadata.Name, Field.Name);
			NewParameter.Synonym	= StrTemplate("%1 - %2", CurMetadata.Synonym, ?(Field.Name <> "RecordType", Field.Synonym, NStr("en = 'Record type'; ru = 'Тип записи';pl = 'Rodzaj wpisu';es_ES = 'Tipo de registro';es_CO = 'Tipo de registro';tr = 'Kayıt türü';it = 'Tipo di registrazione';de = 'Satztyp'")));
			NewParameter.ValueType	= ?(Field.Name <> "RecordType", Field.Type, New TypeDescription("EnumRef.AccumulationRecordType"));
			NewParameter.Category	= DataSource;
			NewParameter.CategorySynonym = NStr("en = 'Data source'; ru = 'Источник данных';pl = 'Źródło danych';es_ES = 'Fuente de datos';es_CO = 'Fuente de datos';tr = 'Veri kaynağı';it = 'Fonte dati';de = 'Datenquelle'"); 
			NewParameter.ListSynonym	 = ?(Field.Name <> "RecordType", Field.Synonym, NStr("en = 'Record type'; ru = 'Тип записи';pl = 'Rodzaj wpisu';es_ES = 'Tipo de registro';es_CO = 'Tipo de registro';tr = 'Kayıt türü';it = 'Tipo di registrazione';de = 'Satztyp'"));
			NewParameter.RestrictedByType = CheckTypeRestriction(TypeRestriction, TypeRestrictionIsNumeric, Field.Type);
			
			AdditionalParameters = New Structure;
			AdditionalParameters.Insert("TypeRestriction"			, TypeRestriction);
			AdditionalParameters.Insert("TypeRestrictionIsNumeric"	, TypeRestrictionIsNumeric);
			AdditionalParameters.Insert("ExcludedFields"			, ExcludedFields);
			AdditionalParameters.Insert("DocumentType"				, DocumentType);
			AdditionalParameters.Insert("FieldName"					, Field.Name);
			
			SupplementNestedAttributes(
				Field.Type,
				TableNestedAttributes,
				NewParameter.Field,
				NewParameter.Synonym,
				NewParameter.Category,
				AdditionalParameters);
			
		EndDo;
		
	EndIf;
	
EndProcedure

Function FindRowsNumeric(TableForSearch, InitStructure, FullStructure, SearchType) Export
	
	If SearchType.ContainsType(Type("Number")) Then
		
		FoundCommonRows = TableForSearch.FindRows(InitStructure); 
		FoundRows = New Array;
		For Each FoundCommonRow In FoundCommonRows Do
			
			FoundCommonRowValueType = FoundCommonRow.ValueType;
			If FoundCommonRowValueType.ContainsType(Type("Number"))
				And FoundCommonRowValueType.NumberQualifiers.FractionDigits = SearchType.NumberQualifiers.FractionDigits Then
				FoundRows.Add(FoundCommonRow);
			EndIf;
			
		EndDo;
		
	Else
		
		FoundRows = TableForSearch.FindRows(FullStructure); 
		
	EndIf;
	
	Return FoundRows;
	
EndFunction

Function FillDefaultParametersInTable(DataSource, DocumentType, Table, OnlyOne = False) Export
	
	AttributesTable 		= InitParametersTable();
	NestedAttributesTable 	= InitNestedAttributesTable();
	
	Messages			= New Array;
	SeveralVariantsText	= NStr("en = 'Cannot fill ""%1"". There are several attributes of this type. Fill ""%1"" manually.'; ru = 'Не удалось заполнить ""%1"". В базе есть несколько реквизитов этого типа. Заполните ""%1"" вручную.';pl = 'Nie można wypełnić ""%1"". Istnieje kilka atrybutów tego typu. Wypełnij ""%1"" ręcznie.';es_ES = 'No se puede rellenar ""%1"". Hay varios atributos de este tipo. Rellene ""%1"" manualmente.';es_CO = 'No se puede rellenar ""%1"". Hay varios atributos de este tipo. Rellene ""%1"" manualmente.';tr = '""%1"" doldurulamıyor. Bu türde birden çok öznitelik var. ""%1"" alanını manuel olarak doldurun.';it = 'Impossibile compilare ""%1"". Vi sono diversi attributi di questo tipo. Compilare ""%1"" manualmente.';de = 'Fehler beim Auffüllen von ""%1"". Es gibt mehrere Attribute dieses Typs. Füllen Sie ""%1"" manuell auf.'");
	NoVariantsText		= NStr("en = 'Cannot fill ""%1"". No fields of this data type are found. Fill ""%1"" manually.'; ru = 'Не удалось заполнить ""%1"". Поля этого типа данных не найдены. Заполните ""%1"" вручную.';pl = 'Nie można wypełnić ""%1"". Nie znaleziono pól tego typu danych. Wypełnij ""%1"" ręcznie.';es_ES = 'No se puede rellenar ""%1"". No se han encontrado campos de este tipo de datos. Rellene ""%1"" manualmente.';es_CO = 'No se puede rellenar ""%1"". No se han encontrado campos de este tipo de datos. Rellene ""%1"" manualmente.';tr = '""%1"" doldurulamıyor. Bu veri türünde hiç alan bulunamadı. ""%1"" alanını manuel doldurun.';it = 'Impossibile compilare ""%1"". Non sono stati trovati campi di questo tipo di dati. Compilare ""%1"" manualmente.';de = 'Fehler beim Auffüllen von ""%1"". Keine Felder dieses Datentyps sind gefunden. Füllen Sie ""%1"" manuell aus.'");
	
	SupplementParametersTableWithDataSourceAttributes(
		AttributesTable,
		NestedAttributesTable,
		DataSource,
		DocumentType);
	SupplementParametersTableWithDocumentsAttributes(
		AttributesTable,
		NestedAttributesTable,
		DocumentType);
		
	DocCategoryName = Common.ObjectAttributeValue(DocumentType, "Name");
	
	SpecialCheck = False;
	If TypeOf(Table) = Type("Array") Then
		SpecialCheck = Table.Count() > 0 And Table[0].Owner().Columns.Find("CheckType") <> Undefined;
	EndIf;
	
	For Each Row In Table Do
		
		If SpecialCheck
			And Row.CheckType = "Synonym" Then
			
			InitStructure = New Structure("Category, ListSynonym", DataSource, Row.Synonym);
			FullStructure = New Structure("ValueType, Category, ListSynonym", Row.TypeDescription, DataSource, Row.Synonym);
			FoundRows = FindRowsNumeric(AttributesTable, InitStructure, FullStructure, Row.TypeDescription);
			
		ElsIf SpecialCheck
			And Row.CheckType = "DebitCredit" Then
			
			InitStructure = New Structure("Category, DrCr", DataSource, Row.DrCr);
			FullStructure = New Structure("ValueType, Category, DrCr", Row.TypeDescription, DataSource, Row.DrCr);
			FoundRows = FindRowsNumeric(AttributesTable, InitStructure, FullStructure, Row.TypeDescription);
			
		EndIf;
		
		If Not SpecialCheck
			Or Row.CheckType = "Standart"
			Or FoundRows.Count() = 0 Then
			
			InitStructure = New Structure("Category", DataSource);
			FullStructure = New Structure("ValueType, Category", Row.TypeDescription, DataSource);
			FoundRows = FindRowsNumeric(AttributesTable, InitStructure, FullStructure, Row.TypeDescription);
			
		EndIf;
		
		If FoundRows.Count() = 0 Then
			InitStructure = New Structure("Category", DataSource);
			FullStructure = New Structure("ValueType, Category", Row.TypeDescription, DataSource);
			FoundRows = FindRowsNumeric(NestedAttributesTable, InitStructure, FullStructure, Row.TypeDescription);
		EndIf;
		
		If FoundRows.Count() = 0 Then
			InitStructure = New Structure("Category", DocCategoryName);
			FullStructure = New Structure("ValueType, Category", Row.TypeDescription, DocCategoryName);
			FoundRows = FindRowsNumeric(AttributesTable, InitStructure, FullStructure, Row.TypeDescription);
		EndIf;
		
		If FoundRows.Count() = 0 Then
			InitStructure = New Structure("Category", DocCategoryName);
			FullStructure = New Structure("ValueType, Category", Row.TypeDescription, DocCategoryName);
			FoundRows = FindRowsNumeric(NestedAttributesTable, InitStructure, FullStructure, Row.TypeDescription);
		EndIf;
		
		If OnlyOne And FoundRows.Count() > 1 Then
			
			Message = New Structure;
			Message.Insert("Text"	, StrTemplate(SeveralVariantsText, Row.Synonym));
			Message.Insert("Row"	, Row.Row);
			Message.Insert("Field"	, Row.Field);
			
			Messages.Add(Message);
			
			Row.Value 		 = Undefined;
			Row.ValueSynonym = Undefined;
			
		ElsIf FoundRows.Count() > 0 Then
			
			Row.Value 		 = FoundRows[0].Field;
			Row.ValueSynonym = FoundRows[0].Synonym;
			Row.DrCr		 = FoundRows[0].DrCr;
			
		ElsIf OnlyOne Then
			
			Message = New Structure;
			Message.Insert("Text"	, StrTemplate(NoVariantsText, Row.Synonym));
			Message.Insert("Row"	, Row.Row);
			Message.Insert("Field"	, Row.Field);
			
			Messages.Add(Message);
			
			Row.Value 		 = Undefined;
			Row.ValueSynonym = Undefined;
			
		EndIf;
		
	EndDo;
	
	Return Messages;
	
EndFunction

Procedure DeleteAllRowsByConnectionKey(Table, ConnectionKey, KeyAttributeName) Export
	
	Filter = New Structure(KeyAttributeName, ConnectionKey);
	
	FilteredRows = Table.FindRows(Filter);
	
	For Each TableRow In FilteredRows Do
		Table.Delete(TableRow);
	EndDo;

EndProcedure

Procedure DeleteAllRowsByMetadataName(Table, MetadataName) Export
		
	Filter = New Structure("MetadataName", MetadataName);
	
	FilteredRows = Table.FindRows(Filter);	
	
	For Each TableRow In FilteredRows Do		
		Table.Delete(TableRow);		
	EndDo;

EndProcedure

Function FillFromEntriesTemplates(TemplateAttributes, TemplateParameters, OnlyParameters) Export
	
	EntriesTemplatesTable = GetEntriesTemplates(TemplateAttributes, TemplateParameters);

	Return GetDataFromEntriesTemplates(EntriesTemplatesTable.UnloadColumn("EntriesTemplate"), OnlyParameters);
	
EndFunction 

Function FillFromSelectedEntriesTemplates(AddressInStorrage, OnlyParameters) Export
	
	Result = New Structure;
	
	RefsArray = GetFromTempStorage(AddressInStorrage);

	Result = GetDataFromEntriesTemplates(RefsArray, OnlyParameters);
	
	Return Result;

EndFunction 

Function GetEntriesTemplates(TemplateAttributes, TemplateParameters) Export

	Query = New Query;
	
	Query.Text =
	"SELECT
	|	AccountingEntriesTemplates.Ref AS EntriesTemplate,
	|	AccountingEntriesTemplates.Code AS Code,
	|	AccountingEntriesTemplates.Description AS Description,
	|	AccountingEntriesTemplates.StartDate AS StartDate,
	|	AccountingEntriesTemplates.EndDate AS EndDate,
	|	AccountingEntriesTemplates.Company AS Company,
	|	AccountingEntriesTemplates.TypeOfAccounting AS TypeOfAccounting,
	|	AccountingEntriesTemplates.ChartOfAccounts AS ChartOfAccounts,
	|	AccountingEntriesTemplates.DocumentType AS DocumentType,
	|	AccountingEntriesTemplates.Status AS Status,
	|	AccountingEntriesTemplates.Category AS Category
	|FROM
	|	Catalog.AccountingEntriesTemplates AS AccountingEntriesTemplates
	|WHERE
	|	AccountingEntriesTemplates.StartDate <= &StartDate
	|	AND (AccountingEntriesTemplates.EndDate >= &EndDate
	|			OR AccountingEntriesTemplates.EndDate = DATETIME(1, 1, 1))
	|	AND (AccountingEntriesTemplates.Company = &Company
	|			OR AccountingEntriesTemplates.Company = VALUE(Catalog.Companies.EmptyRef))
	|	AND AccountingEntriesTemplates.TypeOfAccounting = &TypeOfAccounting
	|	AND AccountingEntriesTemplates.ChartOfAccounts = &ChartOfAccounts
	|	AND AccountingEntriesTemplates.DocumentType = &DocumentType
	|	AND NOT AccountingEntriesTemplates.DeletionMark
	|	AND AccountingEntriesTemplates.Status = &Status
	|
	|ORDER BY
	|	AccountingEntriesTemplates.Ref";
	
	Query.SetParameter("StartDate"			, TemplateAttributes.StartDate);
	Query.SetParameter("EndDate"			, TemplateAttributes.EndDate);
	Query.SetParameter("ChartOfAccounts"	, TemplateAttributes.ChartOfAccounts);
	Query.SetParameter("Company"			, TemplateAttributes.Company);
	Query.SetParameter("DocumentType"		, TemplateAttributes.DocumentType);
	Query.SetParameter("TypeOfAccounting"	, TemplateAttributes.TypeOfAccounting);
	Query.SetParameter("Status"				, Enums.AccountingEntriesTemplatesStatuses.Active);

	QueryResult = Query.Execute();
	VTResult = QueryResult.Unload();
	
	If TemplateParameters.Count() > 0 Then
		UnsuitedTemplates = New Array;
		For Each Template In VTResult Do
			
			If Not CheckParametersInTemplate(Template.EntriesTemplate, TemplateParameters) Then
				UnsuitedTemplates.Add(Template);
			EndIf;
			
		EndDo;
		
		For Each Row In UnsuitedTemplates Do
			VTResult.Delete(Row);
		EndDo;
	EndIf;
	
	Return VTResult;
	
EndFunction 

Function GetTemplatesDates(TemplatesTable, Company, Val StartDate, Val EndDate) Export
	
	TemplatesRows			= TemplatesTable.FindRows(New Structure("Company", Company));
	TempStartDate			= StartDate;
	TempEndDate				= EndDate;
	TempTemplateStartDate	= Undefined;
	TempTemplateEndDate		= Undefined;
	EndDateMustBeEmpty		= False;
	
	For Each Template In TemplatesRows Do
		
		If Template.StartDate < TempStartDate Then
			
			TempStartDate			= Template.StartDate;
			TempTemplateStartDate	= Template.Ref;
			
		EndIf;
		
		If Not ValueIsFilled(Template.EndDate) Then
			
			EndDateMustBeEmpty	= True;
			TempTemplateEndDate	= Template.Ref;
			
		ElsIf Not EndDateMustBeEmpty
			And ValueIsFilled(TempEndDate)
			And Template.EndDate > TempEndDate Then
			
			TempEndDate			= Template.EndDate;
			TempTemplateEndDate	= Template.Ref;
			
		EndIf;
		
	EndDo;
	
	Result = New Structure;
	Result.Insert("TempStartDate"			, TempStartDate);
	Result.Insert("TempEndDate"				, TempEndDate);
	Result.Insert("TempTemplateStartDate"	, TempTemplateStartDate);
	Result.Insert("TempTemplateEndDate"		, TempTemplateEndDate);
	Result.Insert("EndDateMustBeEmpty"		, EndDateMustBeEmpty);
	
	Return Result;
	
EndFunction

Function GetValuesArray(ParametersValues, ConnectionKey, MetadataName = Undefined) Export

	ResultArray = New Array;
	
	Filter = New Structure("ConnectionKey", ConnectionKey);
	If MetadataName <> Undefined Then
		Filter.Insert("MetadataName", MetadataName);
	EndIf;
	
	ValuesRows = ParametersValues.FindRows(Filter);
	
	For Each Row In ValuesRows Do
		ResultArray.Add(Row.Value);
	EndDo;
	
	Return ResultArray;
	
EndFunction 

Function GetEntriesTemplatesWithAccount(Account) Export
	
	Query = New Query;
	Query.Text = 
	"SELECT DISTINCT
	|	AccountingEntriesTemplatesEntries.Ref AS Ref,
	|	AccountingEntriesTemplates.Company AS Company,
	|	AccountingEntriesTemplates.StartDate AS StartDate,
	|	AccountingEntriesTemplates.EndDate AS EndDate
	|FROM
	|	Catalog.AccountingEntriesTemplates.Entries AS AccountingEntriesTemplatesEntries
	|		INNER JOIN Catalog.AccountingEntriesTemplates AS AccountingEntriesTemplates
	|		ON AccountingEntriesTemplatesEntries.Ref = AccountingEntriesTemplates.Ref
	|WHERE
	|	AccountingEntriesTemplatesEntries.Account = &Account
	|	AND AccountingEntriesTemplates.Status = VALUE(Enum.AccountingEntriesTemplatesStatuses.Active)
	|
	|UNION ALL
	|
	|SELECT
	|	AccountingEntriesTemplatesEntriesSimple.Ref,
	|	AccountingEntriesTemplates.Company,
	|	AccountingEntriesTemplates.StartDate,
	|	AccountingEntriesTemplates.EndDate
	|FROM
	|	Catalog.AccountingEntriesTemplates.EntriesSimple AS AccountingEntriesTemplatesEntriesSimple
	|		INNER JOIN Catalog.AccountingEntriesTemplates AS AccountingEntriesTemplates
	|		ON AccountingEntriesTemplatesEntriesSimple.Ref = AccountingEntriesTemplates.Ref
	|WHERE
	|	(AccountingEntriesTemplatesEntriesSimple.AccountCr = &Account
	|			OR AccountingEntriesTemplatesEntriesSimple.AccountDr = &Account)
	|	AND AccountingEntriesTemplates.Status = VALUE(Enum.AccountingEntriesTemplatesStatuses.Active)";
	
	Query.SetParameter("Account", Account);
	
	QueryResult = Query.Execute();
	
	Return QueryResult.Unload();
	
EndFunction

Function CheckExistRegisterEntries(Val AccountsArray) Export
	
	SetPrivilegedMode(True);
	
	If TypeOf(AccountsArray) <> Type("Array") Then
		
		TempValue		= AccountsArray;
		AccountsArray	= New Array;
		AccountsArray.Add(TempValue);
		
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	CompoundWithExtDimensions.Account AS Account
	|FROM
	|	AccountingRegister.AccountingJournalEntriesCompound.RecordsWithExtDimensions(, , Account IN (&AccountsArray), , ) AS CompoundWithExtDimensions
	|WHERE
	|	CompoundWithExtDimensions.Active
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	SimpleWithExtDimensions.AccountDr
	|FROM
	|	AccountingRegister.AccountingJournalEntriesSimple.RecordsWithExtDimensions(, , AccountDr IN (&AccountsArray), , ) AS SimpleWithExtDimensions
	|WHERE
	|	SimpleWithExtDimensions.Active
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	SimpleWithExtDimensions.AccountCr
	|FROM
	|	AccountingRegister.AccountingJournalEntriesSimple.RecordsWithExtDimensions(, , AccountCr IN (&AccountsArray), , ) AS SimpleWithExtDimensions
	|WHERE
	|	SimpleWithExtDimensions.Active";
	
	Query.SetParameter("AccountsArray", AccountsArray);
	
	QueryResult = Query.Execute();
	
	Return Not QueryResult.IsEmpty();
	
EndFunction

Function CheckExistRegisterEntriesWithQuantityFlag(Val AccountsArray) Export
	
	SetPrivilegedMode(True);
	
	If TypeOf(AccountsArray) <> Type("Array") Then
		
		TempValue		 = AccountsArray;
		AccountsArray	 = New Array;
		AccountsArray.Add(TempValue);
		
	EndIf;
	
	Query = New Query;
	Query.Text = 
	"SELECT TOP 1
	|	AccountingJournalEntriesCompound.Account AS Account,
	|	AccountingJournalEntriesCompound.Recorder AS Recorder,
	|	AccountingJournalEntriesCompound.Quantity AS Quantity
	|FROM
	|	AccountingRegister.AccountingJournalEntriesCompound AS AccountingJournalEntriesCompound
	|WHERE
	|	AccountingJournalEntriesCompound.Account IN(&AccountsArray)
	|	AND AccountingJournalEntriesCompound.Quantity > 0";
	
	Query.SetParameter("AccountsArray", AccountsArray);
	
	QueryResult = Query.Execute();
	
	SetPrivilegedMode(False);
	
	Return Not QueryResult.IsEmpty();
	
EndFunction

Function CheckExistTemplates(Val AccountsArray) Export
	
	SetPrivilegedMode(True);
	
	If TypeOf(AccountsArray) <> Type("Array") Then
		
		TempValue		 = AccountsArray;
		AccountsArray	 = New Array;
		AccountsArray.Add(TempValue);
		
	EndIf;
	
	Query = New Query;
	
	Query.Text =
	"SELECT TOP 1
	|	AccountingEntriesTemplatesEntries.Ref AS Ref
	|FROM
	|	Catalog.AccountingEntriesTemplates.Entries AS AccountingEntriesTemplatesEntries
	|		INNER JOIN Catalog.AccountingEntriesTemplates AS AccountingEntriesTemplates
	|		ON AccountingEntriesTemplatesEntries.Ref = AccountingEntriesTemplates.Ref
	|WHERE
	|	AccountingEntriesTemplatesEntries.Account IN(&ChartOfAccounts)
	|	AND AccountingEntriesTemplates.Status = VALUE(Enum.AccountingEntriesTemplatesStatuses.Active)
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	AccountingEntriesTemplatesEntriesSimple.Ref
	|FROM
	|	Catalog.AccountingEntriesTemplates.EntriesSimple AS AccountingEntriesTemplatesEntriesSimple
	|		INNER JOIN Catalog.AccountingEntriesTemplates AS AccountingEntriesTemplates
	|		ON AccountingEntriesTemplatesEntriesSimple.Ref = AccountingEntriesTemplates.Ref
	|WHERE
	|	(AccountingEntriesTemplatesEntriesSimple.AccountDr IN (&ChartOfAccounts)
	|			OR AccountingEntriesTemplatesEntriesSimple.AccountCr IN (&ChartOfAccounts))
	|	AND AccountingEntriesTemplates.Status = VALUE(Enum.AccountingEntriesTemplatesStatuses.Active)
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	AccountingTransactionsTemplatesEntries.Ref
	|FROM
	|	Catalog.AccountingTransactionsTemplates.Entries AS AccountingTransactionsTemplatesEntries
	|		INNER JOIN Catalog.AccountingTransactionsTemplates AS AccountingTransactionsTemplates
	|		ON AccountingTransactionsTemplatesEntries.Ref = AccountingTransactionsTemplates.Ref
	|WHERE
	|	AccountingTransactionsTemplatesEntries.Account IN(&ChartOfAccounts)
	|	AND AccountingTransactionsTemplates.Status = VALUE(Enum.AccountingEntriesTemplatesStatuses.Active)
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	AccountingTransactionsTemplatesEntriesSimple.Ref
	|FROM
	|	Catalog.AccountingTransactionsTemplates.EntriesSimple AS AccountingTransactionsTemplatesEntriesSimple
	|		INNER JOIN Catalog.AccountingTransactionsTemplates AS AccountingTransactionsTemplates
	|		ON AccountingTransactionsTemplatesEntriesSimple.Ref = AccountingTransactionsTemplates.Ref
	|WHERE
	|	(AccountingTransactionsTemplatesEntriesSimple.AccountDr IN (&ChartOfAccounts)
	|			OR AccountingTransactionsTemplatesEntriesSimple.AccountCr IN (&ChartOfAccounts))
	|	AND AccountingTransactionsTemplates.Status = VALUE(Enum.AccountingEntriesTemplatesStatuses.Active)";
	
	Query.SetParameter("ChartOfAccounts"	, AccountsArray);
	Query.SetParameter("Status"				, Enums.AccountingEntriesTemplatesStatuses.Active);

	QueryResult = Query.Execute();
	
	SetPrivilegedMode(False);
	
	Return Not QueryResult.IsEmpty();
	
EndFunction

Function CheckExistTemplatesWithCurrencyFlag(Val AccountsArray) Export
	
	SetPrivilegedMode(True);
	
	If TypeOf(AccountsArray) <> Type("Array") Then
		
		TempValue		 = AccountsArray;
		AccountsArray	 = New Array;
		AccountsArray.Add(TempValue);
		
	EndIf;
	
	Query = New Query;
	
	Query.Text =
	"SELECT TOP 1
	|	AccountingEntriesTemplatesEntries.Ref AS Ref
	|FROM
	|	Catalog.AccountingEntriesTemplates.Entries AS AccountingEntriesTemplatesEntries
	|		INNER JOIN Catalog.AccountingEntriesTemplates AS AccountingEntriesTemplates
	|		ON AccountingEntriesTemplatesEntries.Ref = AccountingEntriesTemplates.Ref
	|WHERE
	|	AccountingEntriesTemplatesEntries.Account IN(&ChartOfAccounts)
	|	AND AccountingEntriesTemplatesEntries.Currency <> VALUE(Catalog.Currencies.EmptyRef)
	|	AND AccountingEntriesTemplates.Status = VALUE(Enum.AccountingEntriesTemplatesStatuses.Active)
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	AccountingEntriesTemplatesEntriesSimple.Ref
	|FROM
	|	Catalog.AccountingEntriesTemplates.EntriesSimple AS AccountingEntriesTemplatesEntriesSimple
	|		INNER JOIN Catalog.AccountingEntriesTemplates AS AccountingEntriesTemplates
	|		ON AccountingEntriesTemplatesEntriesSimple.Ref = AccountingEntriesTemplates.Ref
	|WHERE
	|	(AccountingEntriesTemplatesEntriesSimple.AccountDr IN(&ChartOfAccounts)
	|			OR AccountingEntriesTemplatesEntriesSimple.AccountCr IN(&ChartOfAccounts))
	|	AND (AccountingEntriesTemplatesEntriesSimple.CurrencyDr <> VALUE(Catalog.Currencies.EmptyRef)
	|			OR AccountingEntriesTemplatesEntriesSimple.CurrencyCr <> VALUE(Catalog.Currencies.EmptyRef))
	|	AND AccountingEntriesTemplates.Status = VALUE(Enum.AccountingEntriesTemplatesStatuses.Active)
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	AccountingTransactionsTemplatesEntries.Ref
	|FROM
	|	Catalog.AccountingTransactionsTemplates.Entries AS AccountingTransactionsTemplatesEntries
	|		INNER JOIN Catalog.AccountingTransactionsTemplates AS AccountingTransactionsTemplates
	|		ON AccountingTransactionsTemplatesEntries.Ref = AccountingTransactionsTemplates.Ref
	|WHERE
	|	AccountingTransactionsTemplatesEntries.Account IN(&ChartOfAccounts)
	|	AND AccountingTransactionsTemplatesEntries.Currency <> VALUE(Catalog.Currencies.EmptyRef)
	|	AND AccountingTransactionsTemplates.Status = VALUE(Enum.AccountingEntriesTemplatesStatuses.Active)
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	AccountingTransactionsTemplatesEntriesSimple.Ref
	|FROM
	|	Catalog.AccountingTransactionsTemplates.EntriesSimple AS AccountingTransactionsTemplatesEntriesSimple
	|		INNER JOIN Catalog.AccountingTransactionsTemplates AS AccountingTransactionsTemplates
	|		ON AccountingTransactionsTemplatesEntriesSimple.Ref = AccountingTransactionsTemplates.Ref
	|WHERE
	|	(AccountingTransactionsTemplatesEntriesSimple.AccountDr IN(&ChartOfAccounts)
	|			OR AccountingTransactionsTemplatesEntriesSimple.AccountCr IN(&ChartOfAccounts))
	|	AND (AccountingTransactionsTemplatesEntriesSimple.CurrencyDr <> VALUE(Catalog.Currencies.EmptyRef)
	|			OR AccountingTransactionsTemplatesEntriesSimple.CurrencyCr <> VALUE(Catalog.Currencies.EmptyRef))
	|	AND AccountingTransactionsTemplates.Status = VALUE(Enum.AccountingEntriesTemplatesStatuses.Active)";
	
	Query.SetParameter("ChartOfAccounts"	, AccountsArray);
	Query.SetParameter("Status"				, Enums.AccountingEntriesTemplatesStatuses.Active);

	QueryResult = Query.Execute();
	
	SetPrivilegedMode(False);
	
	Return Not QueryResult.IsEmpty();
	
EndFunction

Procedure CheckExistTemplatesWithCompany(ParametersStructure, Cancel) Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	AccountingEntriesTemplatesEntries.Ref AS Ref,
	|	AccountingEntriesTemplates.StartDate AS StartDate,
	|	AccountingEntriesTemplates.EndDate AS EndDate,
	|	AccountingEntriesTemplates.Code AS Code,
	|	AccountingEntriesTemplates.Description AS Description
	|FROM
	|	Catalog.AccountingEntriesTemplates.Entries AS AccountingEntriesTemplatesEntries
	|		INNER JOIN Catalog.AccountingEntriesTemplates AS AccountingEntriesTemplates
	|		ON AccountingEntriesTemplatesEntries.Ref = AccountingEntriesTemplates.Ref
	|WHERE
	|	AccountingEntriesTemplatesEntries.Account = &ChartOfAccounts
	|	AND AccountingEntriesTemplates.Status = VALUE(Enum.AccountingEntriesTemplatesStatuses.Active)
	|	AND AccountingEntriesTemplates.Company = &Company
	|	AND NOT(AccountingEntriesTemplates.StartDate BETWEEN &StartDate AND &EndDate
	|				OR AccountingEntriesTemplates.EndDate BETWEEN &StartDate AND &EndDate)
	|
	|UNION ALL
	|
	|SELECT
	|	AccountingEntriesTemplatesEntriesSimple.Ref,
	|	AccountingEntriesTemplates.StartDate,
	|	AccountingEntriesTemplates.EndDate,
	|	AccountingEntriesTemplates.Code,
	|	AccountingEntriesTemplates.Description
	|FROM
	|	Catalog.AccountingEntriesTemplates.EntriesSimple AS AccountingEntriesTemplatesEntriesSimple
	|		INNER JOIN Catalog.AccountingEntriesTemplates AS AccountingEntriesTemplates
	|		ON AccountingEntriesTemplatesEntriesSimple.Ref = AccountingEntriesTemplates.Ref
	|WHERE
	|	(AccountingEntriesTemplatesEntriesSimple.AccountDr = &ChartOfAccounts
	|			OR AccountingEntriesTemplatesEntriesSimple.AccountCr IN (&ChartOfAccounts))
	|	AND AccountingEntriesTemplates.Status = VALUE(Enum.AccountingEntriesTemplatesStatuses.Active)
	|	AND AccountingEntriesTemplates.Company = &Company
	|	AND NOT(AccountingEntriesTemplates.StartDate BETWEEN &StartDate AND &EndDate
	|				OR AccountingEntriesTemplates.EndDate BETWEEN &StartDate AND &EndDate)";
	
	Query.SetParameter("ChartOfAccounts"	, ParametersStructure.ChartOfAccounts);
	Query.SetParameter("StartDate"			, ParametersStructure.StartDate);
	Query.SetParameter("EndDate"			, ?(ParametersStructure.EndDate = Date(1,1,1), Date(3999,12,31), ParametersStructure.EndDate));

	If ParametersStructure.Property("Company") Then
		MessageBoxText = NStr("en = 'Cannot save the changes. Account ""%1, %2"" is applied to accounting entries templates. The account validity period for %3 must fall within the validity period of an accounting entries template.'; ru = 'Не удалось сохранить изменения. Счет ""%1, %2"" уже применяется в шаблонах бухгалтерских проводок. Срок действия счета для %3 должен находиться в пределах срока действия шаблона бухгалтерских проводок.';pl = 'Nie można zapisać zmian. Konto ""%1, %2"" jest zastosowane do szablonów wpisów księgowych. Okres ważności konta dla %3musi wchodzić do okresu ważności szablonu wpisów księgowych.';es_ES = 'No se pueden guardar los cambios. La cuenta ""%1, %2"" se aplica a las plantillas de entradas contables. El periodo de validez de la cuenta para %3 debe estar dentro del periodo de validez de una plantilla de entradas contables.';es_CO = 'No se pueden guardar los cambios. La cuenta ""%1, %2"" se aplica a las plantillas de entradas contables. El periodo de validez de la cuenta para %3 debe estar dentro del periodo de validez de una plantilla de entradas contables.';tr = 'Değişiklikler kaydedilemiyor. ""%1, %2"" hesabı, muhasebe girişi şablonlarına uygulanıyor. %3 için hesap geçerlilik dönemi, bir muhasebe girişi şablonunun geçerlilik dönemi içinde olmalıdır.';it = 'Impossibile salvare le modifiche. Il conto ""%1,%2"" è applicato ai modelli di voci di contabilità. Il periodo di validità del conto per %3deve essere incluso nel periodo di validità di un modello di voci di contabilità.';de = 'Fehler beim Speichern von Änderungen. Das Konto ""%1, %2"" ist für Buchungsvorlagen verwendet. Die Kontogültigkeitsdauer für %3 muss innerhalb der Gültigkeitsdauer der Buchungsvorlage liegen.'");
		Query.SetParameter("Company", ParametersStructure.Company);
		FieldName = StrTemplate("Object.Companies[%1].Company", ParametersStructure.Index);
	Else
		MessageBoxText = NStr("en = 'Cannot save the changes. Account ""%1, %2"" is applied to accounting entries templates. The account validity period must fall within this period.'; ru = 'Не удалось сохранить изменения. Счет ""%1, %2"" уже применяется в шаблонах бухгалтерских проводок. Срок действия счета должен находиться в пределах этого срока.';pl = 'Nie można zapisać zmian. Konto ""%1, %2"" jest stosowane do szablonów wpisów księgowych. Okres ważności musi wchodzić do tego okresu.';es_ES = 'No se pueden guardar los cambios. La cuenta ""%1,%2"" se aplica a las plantillas de entradas contables. El periodo de validez de la cuenta debe estar dentro de este periodo.';es_CO = 'No se pueden guardar los cambios. La cuenta ""%1,%2"" se aplica a las plantillas de entradas contables. El periodo de validez de la cuenta debe estar dentro de este periodo.';tr = 'Değişiklikler kaydedilemiyor. ""%1, %2"" hesabı, muhasebe girişi şablonlarına uygulanıyor. Hesabın geçerlilik dönemi bu dönem içinde olmalıdır.';it = 'Impossibile salvare le modifiche. Il conto ""%1,%2"" è applicato ai modelli di voci di contabilità. Il periodo di validità del conto deve essere incluso in questo periodo.';de = 'Fehler beim Speichern von Änderungen. Das Konto ""%1, %2"" ist für Buchungsvorlagen verwendet. Die Kontogültigkeitsdauer für  muss innerhalb diesem Zeitraum liegen.'");
		Query.Text = StrReplace(Query.Text, "AccountingEntriesTemplates.Company = &Company", "AccountingEntriesTemplates.Company = VALUE(Catalog.Companies.EmptyRef)");
		FieldName = "Object.StartDate";
	EndIf;
	
	ChartOfAccountsAttributes = Common.ObjectAttributesValues(ParametersStructure.ChartOfAccounts, "Code, Description");
	
	MessageBoxText = StringFunctionsClientServer.SubstituteParametersToString(
		MessageBoxText,
		ChartOfAccountsAttributes.Code,
		ChartOfAccountsAttributes.Description,
		?(ParametersStructure.Property("Company"), ParametersStructure.Company, Undefined));
	
	QueryResult = Query.Execute();
	If Not QueryResult.IsEmpty() Then
	
		MessageText = NStr("en = 'Accounting entries templates and their validity periods:'; ru = 'Шаблоны бухгалтерских проводок и сроки их действия:';pl = 'Szablony wpisów księgowych i ich okresy ważności:';es_ES = 'Plantillas de entradas contables y sus periodos de validez:';es_CO = 'Plantillas de entradas contables y sus periodos de validez:';tr = 'Muhasebe girişi şablonları ve geçerlilik dönemleri:';it = 'Modelli di voci di contabilità e il loro periodo di validità:';de = 'Buchungsvorlagen und deren Gültigkeitsdauer::'");
		CommonClientServer.MessageToUser(MessageText);
		
		Selection = QueryResult.Select();
		
		While Selection.Next() Do
			
			MessageText = NStr("en = '#%1, %2 is active from %3 to %4'; ru = '№%1, %2 активен с %3 по %4';pl = 'nr%1, %2 jest aktywny od %3 do %4';es_ES = '#%1,%2 está activo desde %3 hasta %4 ';es_CO = '#%1,%2 está activo desde %3 hasta %4 ';tr = '#%1, %2 öğesi %3 ile %4 arasında aktif';it = '#%1, %2 è attivo da %3 a  %4';de = '#%1, %2 ist vom %3 bis %4 aktiv'");
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				MessageText,
				Selection.Code,
				Selection.Description,
				Format(Selection.StartDate, "DLF=D; DE=-"),
				Format(Selection.EndDate, "DLF=D; DE=-"),
				?(ParametersStructure.Property("Company"), ParametersStructure.Company, Undefined));
				
			CommonClientServer.MessageToUser(MessageText, Selection.Ref, , , Cancel);
			
		EndDo;
		
		Raise MessageBoxText;
		
	EndIf;
	
EndProcedure

Procedure CheckExistDefaultAccountsWithCompany(ParametersStructure, Cancel) Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	DefaultAccounts.Ref AS Ref,
	|	DefaultAccounts.StartDate AS StartDate,
	|	DefaultAccounts.EndDate AS EndDate,
	|	DefaultAccountsAccounts.Account AS Account,
	|	DefaultAccounts.Code AS Code
	|FROM
	|	Catalog.DefaultAccounts.Accounts AS DefaultAccountsAccounts
	|		INNER JOIN Catalog.DefaultAccounts AS DefaultAccounts
	|		ON DefaultAccountsAccounts.Ref = DefaultAccounts.Ref
	|WHERE
	|	VALUETYPE(DefaultAccounts.Accounts.Account) = TYPE(ChartOfAccounts.MasterChartOfAccounts)
	|	AND DefaultAccounts.Accounts.Account = &ChartOfAccounts
	|	AND NOT(DefaultAccounts.StartDate BETWEEN &StartDate AND &EndDate
	|				OR DefaultAccounts.EndDate BETWEEN &StartDate AND &EndDate)";
	
	Query.SetParameter("ChartOfAccounts"	, ParametersStructure.ChartOfAccounts);
	Query.SetParameter("Status"				, Enums.AccountingEntriesTemplatesStatuses.Active);
	Query.SetParameter("StartDate"			, ParametersStructure.StartDate);
	Query.SetParameter("EndDate"			, ParametersStructure.EndDate);
	
	MessageBoxText = NStr("en = 'Cannot save the changes. Account ""%1, %2"" is included in the settings of default accounts. The account validity period must fall within the validity period of a default account.'; ru = 'Не удалось сохранить изменения. Счет ""%1, %2"" включен в настройки счетов по умолчанию. Срок действия счета должен находиться в пределах срока действия счета по умолчанию.';pl = 'Nie można zapisać zmian. Konto ""%1, %2"" jest włączony w ustawieniach domyślnych kont. Okres ważności muszą wchodzić do okresu ważności domyślnego konta.';es_ES = 'No se pueden guardar los cambios. La cuenta ""%1,%2 "" está incluida en las configuraciones de las cuentas por defecto. El periodo de validez de la cuenta debe estar dentro del periodo de validez de una cuenta por defecto.';es_CO = 'No se pueden guardar los cambios. La cuenta ""%1,%2 "" está incluida en las configuraciones de las cuentas por defecto. El periodo de validez de la cuenta debe estar dentro del periodo de validez de una cuenta por defecto.';tr = 'Değişiklikler kaydedilemiyor. ""%1, %2"" hesabı varsayılan hesapların ayarlarına dahil. Hesabın geçerlilik dönemi bir varsayılan hesabın geçerlilik dönemi içinde olmalıdır.';it = 'Impossibile salvare le modifiche. Il conto ""%1,%2"" è incluso nelle impostazioni dei conti predefiniti. Il periodo di validità del conto deve essere incluso nel periodo di validità di un conto predefinito.';de = 'Fehler beim Speichern von Änderungen. Konto ""%1, %2"" ist in die Einstellungen von Standardkonten eingeschlossen. Die Kontogültigkeitsdauer muss binnen der Gültigkeitsdauer eines Standardkontos liegen.'");
	
	ChartOfAccountsAttributes = Common.ObjectAttributesValues(ParametersStructure.ChartOfAccounts, "Code, Description");
	
	MessageBoxText = StringFunctionsClientServer.SubstituteParametersToString(
		MessageBoxText,
		ChartOfAccountsAttributes.Code,
		ChartOfAccountsAttributes.Description);
	
	QueryResult = Query.Execute();
	If Not QueryResult.IsEmpty() Then
	
		MessageText = NStr("en = 'Default accounts and their validity periods:'; ru = 'Счета по умолчанию и сроки их действия:';pl = 'Domyślne konta i ich okresy ważności:';es_ES = 'Cuentas por defecto y sus periodos de validez:';es_CO = 'Cuentas por defecto y sus periodos de validez:';tr = 'Varsayılan hesaplar ve geçerlilik dönemleri:';it = 'Conti predefiniti e i loro periodi di validità:';de = 'Standardkonten und deren Gültigkeitsdauer:'");
		CommonClientServer.MessageToUser(MessageText);
		
		Selection = QueryResult.Select();
		
		While Selection.Next() Do
			
			MessageText = NStr("en = '#%1 is active from %2 to %3'; ru = '№%1 активен с %2 по %3';pl = 'nr%1 jest aktywny od %2 do %3';es_ES = '#%1 está activo desde %2 hasta %3 ';es_CO = '#%1 está activo desde %2 hasta %3 ';tr = '#%1, %2 ile %3 arasında aktif';it = '#%1 iè attivo da %2 a %3';de = 'Nr.%1 ist vom %2 bi %3 aktiv'");
			
			MessageText = StrTemplate(
				MessageText,
				Selection.Code,
				Format(Selection.StartDate, "DLF=D; DE=-"),
				Format(Selection.EndDate, "DLF=D; DE=-"));
				
			CommonClientServer.MessageToUser(MessageText, , , , Cancel);
			
		EndDo;
		
		Raise MessageBoxText;
		
	EndIf;
		
EndProcedure

Function GetExistTemplatesWithCompany(Val AccountsArray, Company) Export
	
	SetPrivilegedMode(True);
	
	If TypeOf(AccountsArray) <> Type("Array") Then
		
		TempValue		 = AccountsArray;
		AccountsArray	 = New Array;
		AccountsArray.Add(TempValue);
		
	EndIf;
	
	CompaniesArray = New Array;
	CompaniesArray.Add(Catalogs.Companies.EmptyRef());
	If ValueIsFilled(Company) Then 
		CompaniesArray.Add(Company);
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	AccountingEntriesTemplatesEntries.Ref AS Ref
	|FROM
	|	Catalog.AccountingEntriesTemplates.Entries AS AccountingEntriesTemplatesEntries
	|		INNER JOIN Catalog.AccountingEntriesTemplates AS AccountingEntriesTemplates
	|		ON AccountingEntriesTemplatesEntries.Ref = AccountingEntriesTemplates.Ref
	|WHERE
	|	AccountingEntriesTemplatesEntries.Account IN(&ChartOfAccounts)
	|	AND AccountingEntriesTemplates.Status = VALUE(Enum.AccountingEntriesTemplatesStatuses.Active)
	|	AND AccountingEntriesTemplates.Company IN(&CompaniesArray)
	|
	|UNION ALL
	|
	|SELECT
	|	AccountingEntriesTemplatesEntriesSimple.Ref
	|FROM
	|	Catalog.AccountingEntriesTemplates.EntriesSimple AS AccountingEntriesTemplatesEntriesSimple
	|		INNER JOIN Catalog.AccountingEntriesTemplates AS AccountingEntriesTemplates
	|		ON AccountingEntriesTemplatesEntriesSimple.Ref = AccountingEntriesTemplates.Ref
	|WHERE
	|	(AccountingEntriesTemplatesEntriesSimple.AccountDr IN (&ChartOfAccounts)
	|			OR AccountingEntriesTemplatesEntriesSimple.AccountCr IN (&ChartOfAccounts))
	|	AND AccountingEntriesTemplates.Status = VALUE(Enum.AccountingEntriesTemplatesStatuses.Active)
	|	AND AccountingEntriesTemplates.Company IN(&CompaniesArray)
	|
	|UNION ALL
	|
	|SELECT
	|	AccountingTransactionsTemplatesEntries.Ref
	|FROM
	|	Catalog.AccountingTransactionsTemplates.Entries AS AccountingTransactionsTemplatesEntries
	|		INNER JOIN Catalog.AccountingTransactionsTemplates AS AccountingTransactionsTemplates
	|		ON AccountingTransactionsTemplatesEntries.Ref = AccountingTransactionsTemplates.Ref
	|WHERE
	|	AccountingTransactionsTemplatesEntries.Account IN(&ChartOfAccounts)
	|	AND AccountingTransactionsTemplates.Status = VALUE(Enum.AccountingEntriesTemplatesStatuses.Active)
	|	AND AccountingTransactionsTemplates.Company IN(&CompaniesArray)
	|
	|UNION ALL
	|
	|SELECT
	|	AccountingTransactionsTemplatesEntriesSimple.Ref
	|FROM
	|	Catalog.AccountingTransactionsTemplates.EntriesSimple AS AccountingTransactionsTemplatesEntriesSimple
	|		INNER JOIN Catalog.AccountingTransactionsTemplates AS AccountingTransactionsTemplates
	|		ON AccountingTransactionsTemplatesEntriesSimple.Ref = AccountingTransactionsTemplates.Ref
	|WHERE
	|	(AccountingTransactionsTemplatesEntriesSimple.AccountDr IN (&ChartOfAccounts)
	|			OR AccountingTransactionsTemplatesEntriesSimple.AccountCr IN (&ChartOfAccounts))
	|	AND AccountingTransactionsTemplates.Status = VALUE(Enum.AccountingEntriesTemplatesStatuses.Active)
	|	AND AccountingTransactionsTemplates.Company IN(&CompaniesArray)
	|
	|UNION ALL
	|
	|SELECT
	|	DefaultAccounts.Ref
	|FROM
	|	Catalog.DefaultAccounts.Accounts AS DefaultAccountsAccounts
	|		INNER JOIN Catalog.DefaultAccounts AS DefaultAccounts
	|		ON DefaultAccountsAccounts.Ref = DefaultAccounts.Ref
	|WHERE
	|	VALUETYPE(DefaultAccounts.Accounts.Account) = TYPE(ChartOfAccounts.MasterChartOfAccounts)
	|	AND DefaultAccounts.Accounts.Account IN(&ChartOfAccounts)
	|	AND DefaultAccounts.Company IN(&CompaniesArray)";
	
	Query.SetParameter("ChartOfAccounts"	, AccountsArray);
	Query.SetParameter("Status"				, Enums.AccountingEntriesTemplatesStatuses.Active);
	Query.SetParameter("CompaniesArray"		, CompaniesArray);

	QueryResult = Query.Execute();
	
	SetPrivilegedMode(False);
	
	Return QueryResult;
	
EndFunction

Function CheckExistRegisterEntriesWithExtDimensions(Val AccountsArray) Export
	
	SetPrivilegedMode(True);
	
	If TypeOf(AccountsArray) <> Type("Array") Then
		
		TempValue		= AccountsArray;
		AccountsArray	= New Array;
		AccountsArray.Add(TempValue);
		
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	CompoundWithExtDimensions.Account AS Account,
	|	CompoundWithExtDimensions.ExtDimension1 AS ExtDimension1
	|FROM
	|	AccountingRegister.AccountingJournalEntriesCompound.RecordsWithExtDimensions(, , Account IN (&AccountsArray), , ) AS CompoundWithExtDimensions
	|WHERE
	|	CompoundWithExtDimensions.ExtDimension1.Ref IS NOT NULL 
	|	AND CompoundWithExtDimensions.Active
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	SimpleWithExtDimensions.AccountDr,
	|	SimpleWithExtDimensions.ExtDimensionDr1
	|FROM
	|	AccountingRegister.AccountingJournalEntriesSimple.RecordsWithExtDimensions(, , AccountDr IN (&AccountsArray), , ) AS SimpleWithExtDimensions
	|WHERE
	|	SimpleWithExtDimensions.ExtDimensionDr1.Ref IS NOT NULL 
	|	AND SimpleWithExtDimensions.Active
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	SimpleWithExtDimensions.AccountCr,
	|	SimpleWithExtDimensions.ExtDimensionCr1
	|FROM
	|	AccountingRegister.AccountingJournalEntriesSimple.RecordsWithExtDimensions(, , AccountCr IN (&AccountsArray), , ) AS SimpleWithExtDimensions
	|WHERE
	|	SimpleWithExtDimensions.ExtDimensionDr1.Ref IS NOT NULL 
	|	AND SimpleWithExtDimensions.Active";
	
	Query.SetParameter("AccountsArray", AccountsArray);
	
	QueryResult = Query.Execute();
	
	Return Not QueryResult.IsEmpty();
	
EndFunction

Function CheckExistAccountingEntriesTemplates(Val AccountsArray) Export
	
	SetPrivilegedMode(True);
	
	If TypeOf(AccountsArray) <> Type("Array") Then
		
		TempValue		= AccountsArray;
		AccountsArray	= New Array;
		AccountsArray.Add(TempValue);
		
	EndIf;
	
	Query = New Query;
	Query.Text = 
	"SELECT TOP 1
	|	CatalogAccountingEntriesTemplates.Ref AS Ref
	|FROM
	|	Catalog.AccountingEntriesTemplates AS CatalogAccountingEntriesTemplates
	|		LEFT JOIN Catalog.AccountingEntriesTemplates.Entries AS AccountingEntriesTemplatesEntries
	|		ON (AccountingEntriesTemplatesEntries.Ref = CatalogAccountingEntriesTemplates.Ref)
	|		LEFT JOIN Catalog.AccountingEntriesTemplates.EntriesSimple AS AccountingEntriesTemplatesEntriesSimple
	|		ON CatalogAccountingEntriesTemplates.Ref = AccountingEntriesTemplatesEntriesSimple.Ref
	|WHERE
	|	(AccountingEntriesTemplatesEntries.Account IN (&AccountsArray)
	|			OR AccountingEntriesTemplatesEntriesSimple.AccountDr IN (&AccountsArray)
	|			OR AccountingEntriesTemplatesEntriesSimple.AccountCr IN (&AccountsArray))";
	
	Query.SetParameter("AccountsArray", AccountsArray);
	
	QueryResult = Query.Execute();
	
	SetPrivilegedMode(False);
	
	Return Not QueryResult.IsEmpty();
	
EndFunction

#Region Metadata

Procedure GetRecordersListByCoA(TableAvailableParameters, Val ChartRef = Undefined) Export
	
	If ValueIsFilled(ChartRef) Then
		ChartOfAccountsData	= Common.ObjectAttributesValues(ChartRef, "ChartOfAccounts, TypeOfEntries");
		
		ChartOfAccountsName = AccountingApprovalServer.GetChartOfAccountsName(ChartOfAccountsData.ChartOfAccounts);
	
		If ValueIsFilled(ChartOfAccountsName) Then
			EmptyRefValue	= ChartsOfAccounts[ChartOfAccountsName].EmptyRef();
			ChartOfAccountsMetadata = Metadata.ChartsOfAccounts[ChartOfAccountsName];
		Else
			EmptyRefValue	= ChartsOfAccounts.MasterChartOfAccounts.EmptyRef();
			ChartOfAccountsMetadata = Metadata.ChartsOfAccounts.MasterChartOfAccounts;
		EndIf;
		
	Else
		ChartRef			= Undefined;
		EmptyRefValue		= ChartsOfAccounts.MasterChartOfAccounts.EmptyRef();
		ChartOfAccountsMetadata = Metadata.ChartsOfAccounts.MasterChartOfAccounts;
	EndIf;
	
	For Each AcccountingRegister In Metadata.AccountingRegisters Do
		
		If ChartRef <> Undefined 
			And AcccountingRegister.ChartOfAccounts <> ChartOfAccountsMetadata Then
			Continue;
		EndIf;
		
		If ChartRef = Undefined And AcccountingRegister = Metadata.AccountingRegisters.AccountingJournalEntriesCompound Then
			
			ChartOfAccountsData = New Structure("TypeOfEntries", Enums.ChartsOfAccountsTypesOfEntries.Compound);
			
		ElsIf ChartRef = Undefined Then
			
			ChartOfAccountsData = New Structure("TypeOfEntries", Enums.ChartsOfAccountsTypesOfEntries.Simple);
			
		EndIf;
		
		Module = Common.ObjectManagerByRef(EmptyRefValue);
		Try
			RegisterName = Module.AccountingRegisterName(ChartOfAccountsData.TypeOfEntries);
		Except
			RegisterName = "";
		EndTry;
		
		If AcccountingRegister.Name <> RegisterName Then
			Continue;
		EndIf;
		
		RegSet = AccountingRegisters[AcccountingRegister.Name].CreateRecordSet();
		
		For Each Recorder In RegSet.Filter.Recorder.ValueType.Types() Do
			
			RecorderMetadataID = Common.MetadataObjectID(Metadata.FindByType(Recorder));
			
			If RecorderMetadataID.EmptyRefValue = Documents.AccountingTransaction.EmptyRef() Then
				Continue;
			EndIf;
			
			Presentation = Common.ObjectAttributeValue(RecorderMetadataID, "Synonym");
			
			NewParameter = TableAvailableParameters.Add();
			NewParameter.Field			= RecorderMetadataID;
			NewParameter.Synonym		= Presentation;
			NewParameter.ListSynonym	= Presentation;
			
		EndDo;
		 
	EndDo;
	
EndProcedure

Procedure GetRecordersList(TableAvailableParameters) Export
	
	For Each AcccountingRegister In Metadata.AccountingRegisters Do
		
		If AcccountingRegister <> Metadata.AccountingRegisters.AccountingJournalEntriesCompound
			And AcccountingRegister <> Metadata.AccountingRegisters.AccountingJournalEntriesSimple Then
			Continue;
		EndIf;
		
		RegSet = AccountingRegisters[AcccountingRegister.Name].CreateRecordSet();
		
		For Each Recorder In RegSet.Filter.Recorder.ValueType.Types() Do
			
			RecorderMetadataID = Common.MetadataObjectID(Metadata.FindByType(Recorder));
			
			If RecorderMetadataID.EmptyRefValue = Documents.AccountingTransaction.EmptyRef() Then
				Continue;
			EndIf;
			
			FoundRows = TableAvailableParameters.FindRows(New Structure("Field", RecorderMetadataID));
			
			If FoundRows.Count() = 0 Then
				
				Presentation = Common.ObjectAttributeValue(RecorderMetadataID, "Synonym");
				
				NewParameter = TableAvailableParameters.Add();
				NewParameter.Field			= RecorderMetadataID;
				NewParameter.Synonym		= Presentation;
				NewParameter.ListSynonym	= Presentation;
				
			EndIf;
			
		EndDo;
		 
	EndDo;
	
EndProcedure

Procedure GetAllDocumentsTable(TableAvailableParameters) Export

	For Each SystemDocument In Metadata.Documents Do
				
		SystemDocumentMetadataID = Common.MetadataObjectID(SystemDocument);
		
		If SystemDocumentMetadataID.EmptyRefValue = Documents.AccountingTransaction.EmptyRef() Then
			Continue;
		EndIf;
		
		Presentation = Common.ObjectAttributeValue(SystemDocumentMetadataID, "Synonym");
		
		NewParameter = TableAvailableParameters.Add();
		NewParameter.Field 		 = SystemDocumentMetadataID;
		NewParameter.Synonym 	 = Presentation;
		NewParameter.ListSynonym = Presentation;	
		NewParameter.Category	 = "AvailableDocTypes";
		NewParameter.CategorySynonym = NStr("en = 'Available documents'; ru = 'Доступные документы';pl = 'Dostępne dokumenty';es_ES = 'Documentos disponibles';es_CO = 'Documentos disponibles';tr = 'Mevcut belgeler';it = 'Documenti disponibili';de = 'Verfügbare Dokumente'"); 
		 
	EndDo;
	
EndProcedure

#EndRegion

#Region FormManagement

Procedure FillFormTableRowSynonym(SynonymTS, CurrentRow, DataFieldName, FieldName) Export
	
	Filter = New Structure("MetadataName, ConnectionKey", DataFieldName, CurrentRow.ConnectionKey);
	
	FilteredRows = SynonymTS.FindRows(Filter);
	
	If FilteredRows.Count() > 0 Then
		CurrentRow[FieldName] = FilteredRows[0].Synonym;
	EndIf;
	
EndProcedure

Procedure GetTableValueStorageAttributes(FormTable, DBObjectTable) Export
		
	For Each Row In FormTable Do				
		GetTableRowDynamicAttributes(Row, DBObjectTable[Row.LineNumber - 1]);		
	EndDo;

EndProcedure

Procedure GetTableValueStorageAttributesByMap(FormTable, DBObjectTable, Map) Export
		
	For Each Row In FormTable Do
		GetTableRowDynamicAttributesByMap(Row, DBObjectTable[Row.LineNumber - 1], Map);
	EndDo;
	
EndProcedure

Procedure SetTableValueStorageAttributes(FormTable, DBObjectTable) Export
	
	For Each DBRow In DBObjectTable Do		
		SetTableRowDynamicAttributes(FormTable[DBRow.LineNumber - 1], DBRow); 		
	EndDo; 	

EndProcedure

Procedure SetTableValueStorageAttributesByMap(FormTable, DBObjectTable, Map) Export
	
	For Each DBRow In DBObjectTable Do
		SetTableRowDynamicAttributesByMap(FormTable[DBRow.LineNumber - 1], DBRow, Map);
	EndDo;
	
EndProcedure

Function ValueArrayPresentation(Value) Export

	Presentation = "";
	IsValueList = (TypeOf(Value) = Type("ValueList"));
	IsArray		= (TypeOf(Value) = Type("Array"));
	
	If IsValueList Or IsArray Then 
		
		FirstElem = True;
		
		For Each Element In Value Do
			
			If IsValueList And  Not Element.Check Then
				Continue;
			EndIf;
			
			If FirstElem Then
				PresentTemplate = "%1";
				FirstElem = False;
			Else
				PresentTemplate = "; %1";				
			EndIf;
			
			Presentation = Presentation + StrTemplate(PresentTemplate, ?(IsValueList, Element.Value, Element));
			
		EndDo;
	Else
		Presentation = String(Value);
	EndIf;

	Return Presentation;
	
EndFunction

Procedure FillFormFieldSynonym(Form, SynonymTS, ConnectionKey, DataFieldName, FieldName) Export
	
	Filter = New Structure("MetadataName, ConnectionKey", DataFieldName, ConnectionKey);
	
	FilteredRows = SynonymTS.FindRows(Filter);	
	
	If FilteredRows.Count() > 0 Then
		Form[FieldName] = FilteredRows[0].Synonym;
	EndIf;
	
EndProcedure

Procedure DeleteRowsByConnectionKey(TabularSection, FieldName, ConnectionKey) Export
	
	Filter = New Structure("MetadataName, ConnectionKey", FieldName, ConnectionKey);
	
	FilteredRows = TabularSection.FindRows(Filter);
	
	For Each TableRow In FilteredRows Do
		TabularSection.Delete(TableRow);
	EndDo;
	
EndProcedure

Procedure UpdateObjectSynonymsTS(CurrentObject, FieldName, ConnectionKey, Synonym, DrCr = Undefined) Export

	SynonymTS = CurrentObject.ElementsSynonyms;
	
	Filter = New Structure("MetadataName, ConnectionKey", FieldName, ConnectionKey);
	
	FilteredRows 	= SynonymTS.FindRows(Filter);	
	RowsCount		= FilteredRows.Count();
	
	If RowsCount = 0 Then
		
		NewSynonymRow = SynonymTS.Add();
		
		FillPropertyValues(NewSynonymRow, Filter);
		NewSynonymRow.Synonym	 = Synonym;
		NewSynonymRow.DrCr		 = DrCr;
		
	ElsIf RowsCount = 1 Then
		
		SynonymRow = FilteredRows[0];
		
		FillPropertyValues(SynonymRow, Filter);
		SynonymRow.Synonym	= Synonym;
		SynonymRow.DrCr		= DrCr;
		
	Else
		
		While RowsCount > 1 Do
			SynonymTS.Delete(FilteredRows[RowsCount - 1]);
			RowsCount = RowsCount - 1;
		EndDo;
		
		SynonymRow = FilteredRows[0];
		
		FillPropertyValues(SynonymRow, Filter);
		SynonymRow.Synonym	= Synonym;
		SynonymRow.DrCr		= DrCr;
	
	EndIf;
	
EndProcedure

Function SetComplexTypeOfEntries(ChartOfAccounts, EntriesCount) Export
	
	If ValueIsFilled(ChartOfAccounts) Then
		CurrentTypeOfEntries = Common.ObjectAttributeValue(ChartOfAccounts, "TypeOfEntries");
		
		If CurrentTypeOfEntries = Enums.ChartsOfAccountsTypesOfEntries.Compound Then
			IsComplexTypeOfEntries = True;
		Else
			IsComplexTypeOfEntries = False;
		EndIf;
		
	Else
		
		IsComplexTypeOfEntries = EntriesCount > 0;
		
	EndIf;
	
	Return IsComplexTypeOfEntries;
	
EndFunction

#EndRegion

#EndRegion

#Region Private

Function CheckTypeRestriction(TypeRestriction, TypeRestrictionIsNumeric, FieldType)

	If TypeRestrictionIsNumeric Then
		
		Return FieldType.Types()[0] <> Type("Number");
			
	ElsIf TypeRestriction = Undefined Then
		
		Return False;
			
	Else
		
		TypesInTypeRestriction = True;
		For Each Item In FieldType.Types() Do
			
			If TypeRestriction.ContainsType(Item) Then
				
				TypesInTypeRestriction = False;
				Break;
				
			EndIf;
			
		EndDo;
		
		Return TypesInTypeRestriction;
		
	EndIf;

EndFunction

Function CheckObsolete(MetadataName, MetadataSynonym = "")
	
	Obsolete = False;
	
	Obsolete = Obsolete Or StrFind(Upper(MetadataName)		, "OBSOLETE") <> 0;
	Obsolete = Obsolete Or StrFind(Upper(MetadataSynonym)	, NStr("en = '(NOT USED)'; ru = '(НЕ ИСПОЛЬЗУЕТСЯ)';pl = '(NIEUŻYWANE)';es_ES = '(NO SE USA)';es_CO = '(NO SE USA)';tr = '(KULLANILMAZ)';it = '(NON UTILIZZATO)';de = '(NICHT VERWENDET)'")) <> 0;
	
	Return Obsolete;

EndFunction 

Procedure SupplementNestedAttributes(MetadataType, TableNestedAttributes, Parent, ParentSynonym, Category, AdditionalParameters = Undefined)
	
	Var TypeRestriction, TypeRestrictionIsNumeric, ExcludedFields, DocumentType, FieldName, DrCr;
	
	If AdditionalParameters <> Undefined Then
		
		If AdditionalParameters.Property("TypeRestriction") Then
			TypeRestriction = AdditionalParameters.TypeRestriction;
		Else
			TypeRestriction = Undefined;
		EndIf;
		
		If AdditionalParameters.Property("TypeRestrictionIsNumeric") Then
			TypeRestrictionIsNumeric = AdditionalParameters.TypeRestrictionIsNumeric;
		Else
			TypeRestrictionIsNumeric = False;
		EndIf;
		
		If AdditionalParameters.Property("ExcludedFields") Then
			ExcludedFields = AdditionalParameters.ExcludedFields;
		Else
			ExcludedFields = Undefined;
		EndIf;
		
		If AdditionalParameters.Property("DocumentType") Then
			DocumentType = AdditionalParameters.DocumentType;
		Else
			DocumentType = Undefined;
		EndIf;
		
		If AdditionalParameters.Property("FieldName") Then
			FieldName = AdditionalParameters.FieldName;
		Else
			FieldName = "";
		EndIf;
		
		If AdditionalParameters.Property("DrCr") Then
			DrCr = AdditionalParameters.DrCr;
		Else
			DrCr = Undefined;
		EndIf;
		
	Else
		
		TypeRestriction			 = Undefined;
		TypeRestrictionIsNumeric = False;
		ExcludedFields			 = Undefined;
		DocumentType			 = Undefined;
		FieldName				 = "";
		DrCr					 = Undefined;
		
	EndIf;
	
	MetadataTypes = MetadataType.Types();
	
	For Each CurrentType In MetadataTypes Do
		
		If ValueIsFilled(FieldName) And FieldName = "Recorder" And DocumentType <> Undefined Then
			
			If CurrentType <> TypeOf(DocumentType.EmptyRefValue) Then
				Continue;
			EndIf;
			
		EndIf;
		
		TypesArray = New Array;
		
		TypesArray.Add(CurrentType);
		
		CurrentTypeDescription = New TypeDescription(
			TypesArray,
			,
			,
			MetadataType.NumberQualifiers,
			MetadataType.StringQualifiers,
			MetadataType.DateQualifiers,
			MetadataType.BinaryDataQualifiers);
		
		EmptyRef = CurrentTypeDescription.AdjustValue("");
		
		If Not Common.RefTypeValue(EmptyRef) Then
			Continue;
		EndIf;
		
		RefMetadata = EmptyRef.Metadata();
		
		If Common.IsEnum(RefMetadata) Then
			Continue;
		EndIf;
		
		If ExcludedFields = Undefined Then
			ExcludedFields = New Array;
		EndIf;
		
		SearchStructure = New Structure("ParentField, ParentDrCr, Category", Parent, DrCr, Category);
		
		FoundRows = TableNestedAttributes.FindRows(SearchStructure);
		
		If FoundRows.Count() > 0 Then
			Continue;	
		EndIf;
		
		For Each NestedAttribute In RefMetadata.Attributes Do
			
			If CheckObsolete(NestedAttribute.Name, NestedAttribute.Synonym) 
				Or Not ValueIsFilled(NestedAttribute.Synonym)
				Or ExcludedFields.Find(Upper(NestedAttribute.Name)) <> Undefined Then
				Continue;
			EndIf;
			
			NewRow = TableNestedAttributes.Add();
			FillNewNestedParameterRow(NewRow, NestedAttribute, Parent, ParentSynonym, Category, DrCr);
			NewRow.RestrictedByType = CheckTypeRestriction(TypeRestriction, TypeRestrictionIsNumeric, NestedAttribute.Type);
			
		EndDo;
		
		For Each NestedAttribute In RefMetadata.StandardAttributes Do
			
			If CheckObsolete(NestedAttribute.Name, NestedAttribute.Synonym) 
				Or Not ValueIsFilled(NestedAttribute.Synonym)
				Or Upper(NestedAttribute.Name) = Upper(DriveServer.GetAttributeVariant("Ref"))
				Or ExcludedFields.Find(Upper(NestedAttribute.Name)) <> Undefined Then
				Continue;
			EndIf;
			
			NewRow = TableNestedAttributes.Add();
			FillNewNestedParameterRow(NewRow, NestedAttribute, Parent, ParentSynonym, Category, DrCr);
			NewRow.RestrictedByType = CheckTypeRestriction(TypeRestriction, TypeRestrictionIsNumeric, NestedAttribute.Type);
			
		EndDo;
		
	EndDo;
	
EndProcedure

Procedure FillNewNestedParameterRow(NewRow, Attribute, Parent, ParentSynonym, Category, DrCr = Undefined)

	NewRow.Field 		= StrTemplate("%1.%2"  , Parent, Attribute.Name);
	NewRow.Synonym 		= StrTemplate("%1 - %2", ParentSynonym, Attribute.Synonym);
	NewRow.ParentField	= Parent;
	NewRow.ValueType	= Attribute.Type;
	NewRow.ListSynonym	= Attribute.Synonym;
	NewRow.Category		= Category;
	NewRow.DrCr			= DrCr;
	NewRow.ParentDrCr	= DrCr;

EndProcedure

Procedure GetTableRowDynamicAttributes(FormTableRow, DBObjectTableRow)

	FormTableRow.ConditionPresentation = DBObjectTableRow.Condition.Get();
	FormTableRow.ValueType 			   = DBObjectTableRow.SavedValueType.Get();
		
EndProcedure

Procedure GetTableRowDynamicAttributesByMap(FormTableRow, DBObjectTableRow, Map)
	
	For Each Row In Map Do
		FormTableRow[Row.Value] = DBObjectTableRow[Row.Key].Get();
	EndDo;
	
EndProcedure

Procedure SetTableRowDynamicAttributes(FormTableRow, DBObjectTableRow)

	DBObjectTableRow.Condition 		= New ValueStorage(FormTableRow.ConditionPresentation);	
	DBObjectTableRow.SavedValueType = New ValueStorage(FormTableRow.ValueType);		
		
EndProcedure

Procedure SetTableRowDynamicAttributesByMap(FormTableRow, DBObjectTableRow, Map)
	
	For Each Row In Map Do
		DBObjectTableRow[Row.Key] = New ValueStorage(FormTableRow[Row.Value]);
	EndDo;
	
EndProcedure

#Region Filling

Function GetDataFromEntriesTemplates(RefsArray, OnlyParameters = False)
	
	Result = New Structure;
	
	Query = New Query;
	
	Query.Text = GetFillingDataQueryText(OnlyParameters);
	
	If OnlyParameters Then
		
		Query.SetParameter("RefsArray", RefsArray);
		
	Else
		
		RefsTable = New ValueTable;
		RefsTable.Columns.Add("Ref"		, New TypeDescription("CatalogRef.AccountingEntriesTemplates"));
		RefsTable.Columns.Add("RefOrder", New TypeDescription("Number"));
		
		Count = 0;
		For Each Item In RefsArray Do
			
			NewRow			 = RefsTable.Add();
			NewRow.Ref		 = Item;
			NewRow.RefOrder	 = Count;
			
			Count = Count + 1;
			
		EndDo;
		
		Query.SetParameter("RefsTable", RefsTable);
		
	EndIf;
	
	QueryResult = Query.ExecuteBatch();
	
	AccountingEntriesTemplatesRefs = New ValueTable;
	AccountingEntriesTemplatesRefs.Columns.Add("Ref");
	AccountingEntriesTemplatesRefs.Columns.Add("MetaData");
	AccountingEntriesTemplatesRefs.Columns.Add("ConnectionKey");
	AccountingEntriesTemplatesRefs.Columns.Add("NewConnectionKey");
	
	TmpIndex = ?(OnlyParameters, 1, 0);
	ParametersTable 		= GetResultParameters(AccountingEntriesTemplatesRefs, QueryResult[2 - TmpIndex].Select());
	ParametersValuesTable 	= GetResultParametersValues(AccountingEntriesTemplatesRefs, QueryResult[3 - TmpIndex].Select());
	
	If OnlyParameters Then
		GroupParametersByFieldAndValues(ParametersTable, ParametersValuesTable);
	EndIf;
	
	Result.Insert("Parameters"		, ParametersTable);
	Result.Insert("ParametersValues", ParametersValuesTable);
	
	
	If Not OnlyParameters Then
		
		Result.Insert("Entries"			, GetResultEntries(AccountingEntriesTemplatesRefs, QueryResult[5].Select()));
		Result.Insert("EntriesSimple"	, GetResultEntriesSimple(AccountingEntriesTemplatesRefs, QueryResult[7].Select()));
		Result.Insert("ElementsSynonyms", GetResultElementsSynonyms(AccountingEntriesTemplatesRefs, QueryResult[10].Select()));
		
		If Result.Entries.Count() <> 0 Then
			Result.Insert("EntriesFilters", GetResultEntriesFilters(AccountingEntriesTemplatesRefs, QueryResult[9].Select(), "Entries"));
		ElsIf Result.EntriesSimple.Count() <> 0 Then
			Result.Insert("EntriesFilters", GetResultEntriesFilters(AccountingEntriesTemplatesRefs, QueryResult[9].Select(), "EntriesSimple"));
		Else
			Result.Insert("EntriesFilters", New ValueTable);
		EndIf;
		
		Result.Insert("ParametersValuesEntries"	, GetResultParametersValuesEntries(AccountingEntriesTemplatesRefs, QueryResult[11].Select()));
		
		Result.Insert("EntriesDefaultAccounts"	, GetResultEntriesDefaultAccounts(AccountingEntriesTemplatesRefs, QueryResult[12].Select()));
	EndIf;
	
	Return Result;

EndFunction 

Function GetFillingDataQueryText(OnlyParameters)

	QueryText = "";
	
	If OnlyParameters Then
		QueryText = 
		"SELECT
		|	AccountingEntriesTemplatesParameters.ParameterName AS ParameterName,
		|	AccountingEntriesTemplatesParameters.ParameterSynonym AS ParameterSynonym,
		|	AccountingEntriesTemplatesParameters.Condition AS Condition,
		|	AccountingEntriesTemplatesParameters.ValuePresentation AS ValuePresentation,
		|	AccountingEntriesTemplatesParameters.ValuesConnectionKey AS ValuesConnectionKey,
		|	AccountingEntriesTemplatesParameters.SavedValueType AS SavedValueType,
		|	AccountingEntriesTemplatesParameters.MultipleValuesMode AS MultipleValuesMode,
		|	AccountingEntriesTemplatesParameters.Ref AS Ref,
		|	AccountingEntriesTemplatesParameters.LineNumber AS LineNumber
		|INTO TT_Parameters
		|FROM
		|	Catalog.AccountingEntriesTemplates.Parameters AS AccountingEntriesTemplatesParameters
		|WHERE
		|	AccountingEntriesTemplatesParameters.Ref IN(&RefsArray)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	TT_Parameters.ParameterName AS ParameterName,
		|	TT_Parameters.ParameterSynonym AS ParameterSynonym,
		|	TT_Parameters.Condition AS Condition,
		|	TT_Parameters.ValuePresentation AS ValuePresentation,
		|	TT_Parameters.ValuesConnectionKey AS ValuesConnectionKey,
		|	TT_Parameters.SavedValueType AS SavedValueType,
		|	TT_Parameters.MultipleValuesMode AS MultipleValuesMode,
		|	TT_Parameters.Ref AS Ref
		|FROM
		|	TT_Parameters AS TT_Parameters
		|
		|ORDER BY
		|	TT_Parameters.Ref,
		|	TT_Parameters.LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	AccountingEntriesTemplatesParametersValues.ConnectionKey AS ConnectionKey,
		|	AccountingEntriesTemplatesParametersValues.MetadataName AS MetadataName,
		|	AccountingEntriesTemplatesParametersValues.Value AS Value,
		|	AccountingEntriesTemplatesParametersValues.Ref AS Ref
		|FROM
		|	Catalog.AccountingEntriesTemplates.ParametersValues AS AccountingEntriesTemplatesParametersValues
		|WHERE
		|	AccountingEntriesTemplatesParametersValues.MetadataName = ""Parameters""
		|	AND (AccountingEntriesTemplatesParametersValues.Ref, AccountingEntriesTemplatesParametersValues.ConnectionKey) IN
		|			(SELECT
		|				TT_Parameters.Ref AS Ref,
		|				TT_Parameters.ValuesConnectionKey AS ValuesConnectionKey
		|			FROM
		|				TT_Parameters AS TT_Parameters)";
	Else
		QueryText = 
		"SELECT
		|	RefsTable.Ref AS Ref,
		|	RefsTable.RefOrder AS RefOrder
		|INTO TT_Refs
		|FROM
		|	&RefsTable AS RefsTable
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	AccountingEntriesTemplatesParameters.ParameterName AS ParameterName,
		|	AccountingEntriesTemplatesParameters.ParameterSynonym AS ParameterSynonym,
		|	AccountingEntriesTemplatesParameters.Condition AS Condition,
		|	AccountingEntriesTemplatesParameters.ValuePresentation AS ValuePresentation,
		|	AccountingEntriesTemplatesParameters.ValuesConnectionKey AS ValuesConnectionKey,
		|	AccountingEntriesTemplatesParameters.SavedValueType AS SavedValueType,
		|	AccountingEntriesTemplatesParameters.MultipleValuesMode AS MultipleValuesMode,
		|	AccountingEntriesTemplatesParameters.Ref AS Ref,
		|	AccountingEntriesTemplatesParameters.LineNumber AS LineNumber
		|INTO TT_Parameters
		|FROM
		|	Catalog.AccountingEntriesTemplates.Parameters AS AccountingEntriesTemplatesParameters
		|WHERE
		|	AccountingEntriesTemplatesParameters.Ref IN
		|			(SELECT
		|				TT_Refs.Ref AS Ref
		|			FROM
		|				TT_Refs AS TT_Refs)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	TT_Parameters.ParameterName AS ParameterName,
		|	TT_Parameters.ParameterSynonym AS ParameterSynonym,
		|	TT_Parameters.Condition AS Condition,
		|	TT_Parameters.ValuePresentation AS ValuePresentation,
		|	TT_Parameters.ValuesConnectionKey AS ValuesConnectionKey,
		|	TT_Parameters.SavedValueType AS SavedValueType,
		|	TT_Parameters.MultipleValuesMode AS MultipleValuesMode,
		|	TT_Parameters.Ref AS Ref
		|FROM
		|	TT_Parameters AS TT_Parameters
		|
		|ORDER BY
		|	TT_Parameters.Ref,
		|	TT_Parameters.LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	AccountingEntriesTemplatesParametersValues.ConnectionKey AS ConnectionKey,
		|	AccountingEntriesTemplatesParametersValues.MetadataName AS MetadataName,
		|	AccountingEntriesTemplatesParametersValues.Value AS Value,
		|	AccountingEntriesTemplatesParametersValues.Ref AS Ref
		|FROM
		|	Catalog.AccountingEntriesTemplates.ParametersValues AS AccountingEntriesTemplatesParametersValues
		|WHERE
		|	AccountingEntriesTemplatesParametersValues.MetadataName = ""Parameters""
		|	AND (AccountingEntriesTemplatesParametersValues.Ref, AccountingEntriesTemplatesParametersValues.ConnectionKey) IN
		|			(SELECT
		|				TT_Parameters.Ref AS Ref,
		|				TT_Parameters.ValuesConnectionKey AS ValuesConnectionKey
		|			FROM
		|				TT_Parameters AS TT_Parameters)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	AccountingEntriesTemplatesEntries.Ref AS Ref,
		|	AccountingEntriesTemplatesEntries.EntryNumber AS EntryNumber,
		|	AccountingEntriesTemplatesEntries.EntryLineNumber AS EntryLineNumber,
		|	AccountingEntriesTemplatesEntries.DataSource AS DataSource,
		|	AccountingEntriesTemplatesEntries.Mode AS Mode,
		|	AccountingEntriesTemplatesEntries.DrCr AS DrCr,
		|	AccountingEntriesTemplatesEntries.Account AS Account,
		|	AccountingEntriesTemplatesEntries.Period AS Period,
		|	AccountingEntriesTemplatesEntries.PeriodAggregateFunction AS PeriodAggregateFunction,
		|	AccountingEntriesTemplatesEntries.AnalyticalDimensionsSet AS AnalyticalDimensionsSet,
		|	AccountingEntriesTemplatesEntries.AnalyticalDimensions1 AS AnalyticalDimensions1,
		|	AccountingEntriesTemplatesEntries.AnalyticalDimensions2 AS AnalyticalDimensions2,
		|	AccountingEntriesTemplatesEntries.AnalyticalDimensions3 AS AnalyticalDimensions3,
		|	AccountingEntriesTemplatesEntries.Currency AS Currency,
		|	AccountingEntriesTemplatesEntries.Quantity AS Quantity,
		|	AccountingEntriesTemplatesEntries.Amount AS Amount,
		|	AccountingEntriesTemplatesEntries.AmountCur AS AmountCur,
		|	AccountingEntriesTemplatesEntries.Content AS Content,
		|	AccountingEntriesTemplatesEntries.ConnectionKey AS ConnectionKey,
		|	AccountingEntriesTemplatesEntries.FilterPresentation AS FilterPresentation,
		|	AccountingEntriesTemplatesEntries.AnalyticalDimensions4 AS AnalyticalDimensions4,
		|	AccountingEntriesTemplatesEntries.AnalyticalDimensionsType1 AS AnalyticalDimensionsType1,
		|	AccountingEntriesTemplatesEntries.AnalyticalDimensionsType2 AS AnalyticalDimensionsType2,
		|	AccountingEntriesTemplatesEntries.AnalyticalDimensionsType3 AS AnalyticalDimensionsType3,
		|	AccountingEntriesTemplatesEntries.AnalyticalDimensionsType4 AS AnalyticalDimensionsType4,
		|	AccountingEntriesTemplatesEntries.DefaultAccountType AS DefaultAccountType,
		|	AccountingEntriesTemplatesEntries.AccountReferenceName AS AccountReferenceName
		|INTO TT_Entries
		|FROM
		|	Catalog.AccountingEntriesTemplates.Entries AS AccountingEntriesTemplatesEntries
		|WHERE
		|	AccountingEntriesTemplatesEntries.Ref IN
		|			(SELECT
		|				TT_Refs.Ref AS Ref
		|			FROM
		|				TT_Refs AS TT_Refs)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	TT_Entries.Ref AS Ref,
		|	TT_Entries.EntryNumber AS EntryNumber,
		|	TT_Entries.EntryLineNumber AS EntryLineNumber,
		|	TT_Entries.DataSource AS DataSource,
		|	TT_Entries.Mode AS Mode,
		|	TT_Entries.DrCr AS DrCr,
		|	TT_Entries.Account AS Account,
		|	TT_Entries.Period AS Period,
		|	TT_Entries.PeriodAggregateFunction AS PeriodAggregateFunction,
		|	TT_Entries.AnalyticalDimensionsSet AS AnalyticalDimensionsSet,
		|	TT_Entries.AnalyticalDimensions1 AS AnalyticalDimensions1,
		|	TT_Entries.AnalyticalDimensions2 AS AnalyticalDimensions2,
		|	TT_Entries.AnalyticalDimensions3 AS AnalyticalDimensions3,
		|	TT_Entries.Currency AS Currency,
		|	TT_Entries.Quantity AS Quantity,
		|	TT_Entries.Amount AS Amount,
		|	TT_Entries.AmountCur AS AmountCur,
		|	TT_Entries.Content AS Content,
		|	TT_Entries.ConnectionKey AS ConnectionKey,
		|	TT_Entries.FilterPresentation AS FilterPresentation,
		|	TT_Entries.AnalyticalDimensions4 AS AnalyticalDimensions4,
		|	TT_Entries.AnalyticalDimensionsType1 AS AnalyticalDimensionsType1,
		|	TT_Entries.AnalyticalDimensionsType2 AS AnalyticalDimensionsType2,
		|	TT_Entries.AnalyticalDimensionsType3 AS AnalyticalDimensionsType3,
		|	TT_Entries.AnalyticalDimensionsType4 AS AnalyticalDimensionsType4,
		|	TT_Entries.DefaultAccountType AS DefaultAccountType,
		|	TT_Entries.AccountReferenceName AS AccountReferenceName
		|FROM
		|	TT_Entries AS TT_Entries
		|		INNER JOIN TT_Refs AS TT_Refs
		|		ON TT_Entries.Ref = TT_Refs.Ref
		|
		|ORDER BY
		|	TT_Refs.RefOrder,
		|	EntryNumber,
		|	EntryLineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	AccountingEntriesTemplatesEntriesSimple.Ref AS Ref,
		|	AccountingEntriesTemplatesEntriesSimple.LineNumber AS EntryNumber,
		|	AccountingEntriesTemplatesEntriesSimple.Mode AS Mode,
		|	AccountingEntriesTemplatesEntriesSimple.DataSource AS DataSource,
		|	AccountingEntriesTemplatesEntriesSimple.Period AS Period,
		|	AccountingEntriesTemplatesEntriesSimple.PeriodAggregateFunction AS PeriodAggregateFunction,
		|	AccountingEntriesTemplatesEntriesSimple.Content AS Content,
		|	AccountingEntriesTemplatesEntriesSimple.Amount AS Amount,
		|	AccountingEntriesTemplatesEntriesSimple.AccountCr AS AccountCr,
		|	AccountingEntriesTemplatesEntriesSimple.AccountDr AS AccountDr,
		|	AccountingEntriesTemplatesEntriesSimple.AmountCurDr AS AmountCurDr,
		|	AccountingEntriesTemplatesEntriesSimple.AmountCurCr AS AmountCurCr,
		|	AccountingEntriesTemplatesEntriesSimple.AnalyticalDimensionsCr1 AS AnalyticalDimensionsCr1,
		|	AccountingEntriesTemplatesEntriesSimple.AnalyticalDimensionsCr2 AS AnalyticalDimensionsCr2,
		|	AccountingEntriesTemplatesEntriesSimple.AnalyticalDimensionsCr3 AS AnalyticalDimensionsCr3,
		|	AccountingEntriesTemplatesEntriesSimple.AnalyticalDimensionsDr1 AS AnalyticalDimensionsDr1,
		|	AccountingEntriesTemplatesEntriesSimple.AnalyticalDimensionsDr2 AS AnalyticalDimensionsDr2,
		|	AccountingEntriesTemplatesEntriesSimple.AnalyticalDimensionsDr3 AS AnalyticalDimensionsDr3,
		|	AccountingEntriesTemplatesEntriesSimple.CurrencyCr AS CurrencyCr,
		|	AccountingEntriesTemplatesEntriesSimple.CurrencyDr AS CurrencyDr,
		|	AccountingEntriesTemplatesEntriesSimple.AnalyticalDimensionsSetCr AS AnalyticalDimensionsSetCr,
		|	AccountingEntriesTemplatesEntriesSimple.AnalyticalDimensionsSetDr AS AnalyticalDimensionsSetDr,
		|	AccountingEntriesTemplatesEntriesSimple.FilterPresentation AS FilterPresentation,
		|	AccountingEntriesTemplatesEntriesSimple.QuantityCr AS QuantityCr,
		|	AccountingEntriesTemplatesEntriesSimple.QuantityDr AS QuantityDr,
		|	AccountingEntriesTemplatesEntriesSimple.ConnectionKey AS ConnectionKey,
		|	AccountingEntriesTemplatesEntriesSimple.AnalyticalDimensionsTypeCr1 AS AnalyticalDimensionsTypeCr1,
		|	AccountingEntriesTemplatesEntriesSimple.AnalyticalDimensionsTypeCr2 AS AnalyticalDimensionsTypeCr2,
		|	AccountingEntriesTemplatesEntriesSimple.AnalyticalDimensionsTypeCr3 AS AnalyticalDimensionsTypeCr3,
		|	AccountingEntriesTemplatesEntriesSimple.AnalyticalDimensionsTypeDr1 AS AnalyticalDimensionsTypeDr1,
		|	AccountingEntriesTemplatesEntriesSimple.AnalyticalDimensionsTypeDr2 AS AnalyticalDimensionsTypeDr2,
		|	AccountingEntriesTemplatesEntriesSimple.AnalyticalDimensionsTypeDr3 AS AnalyticalDimensionsTypeDr3,
		|	AccountingEntriesTemplatesEntriesSimple.AnalyticalDimensionsCr4 AS AnalyticalDimensionsCr4,
		|	AccountingEntriesTemplatesEntriesSimple.AnalyticalDimensionsDr4 AS AnalyticalDimensionsDr4,
		|	AccountingEntriesTemplatesEntriesSimple.AnalyticalDimensionsTypeDr4 AS AnalyticalDimensionsTypeDr4,
		|	AccountingEntriesTemplatesEntriesSimple.AnalyticalDimensionsTypeCr4 AS AnalyticalDimensionsTypeCr4,
		|	AccountingEntriesTemplatesEntriesSimple.DefaultAccountTypeCr AS DefaultAccountTypeCr,
		|	AccountingEntriesTemplatesEntriesSimple.AccountReferenceNameCr AS AccountReferenceNameCr,
		|	AccountingEntriesTemplatesEntriesSimple.DefaultAccountTypeDr AS DefaultAccountTypeDr,
		|	AccountingEntriesTemplatesEntriesSimple.AccountReferenceNameDr AS AccountReferenceNameDr
		|INTO TT_EntriesSimple
		|FROM
		|	Catalog.AccountingEntriesTemplates.EntriesSimple AS AccountingEntriesTemplatesEntriesSimple
		|WHERE
		|	AccountingEntriesTemplatesEntriesSimple.Ref IN
		|			(SELECT
		|				TT_Refs.Ref AS Ref
		|			FROM
		|				TT_Refs AS TT_Refs)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	TT_EntriesSimple.Ref AS Ref,
		|	TT_EntriesSimple.EntryNumber AS EntryLineNumber,
		|	TT_EntriesSimple.Mode AS Mode,
		|	TT_EntriesSimple.DataSource AS DataSource,
		|	TT_EntriesSimple.Period AS Period,
		|	TT_EntriesSimple.PeriodAggregateFunction AS PeriodAggregateFunction,
		|	TT_EntriesSimple.Content AS Content,
		|	TT_EntriesSimple.Amount AS Amount,
		|	TT_EntriesSimple.AccountCr AS AccountCr,
		|	TT_EntriesSimple.AccountDr AS AccountDr,
		|	TT_EntriesSimple.AmountCurDr AS AmountCurDr,
		|	TT_EntriesSimple.AmountCurCr AS AmountCurCr,
		|	TT_EntriesSimple.AnalyticalDimensionsCr1 AS AnalyticalDimensionsCr1,
		|	TT_EntriesSimple.AnalyticalDimensionsCr2 AS AnalyticalDimensionsCr2,
		|	TT_EntriesSimple.AnalyticalDimensionsCr3 AS AnalyticalDimensionsCr3,
		|	TT_EntriesSimple.AnalyticalDimensionsDr1 AS AnalyticalDimensionsDr1,
		|	TT_EntriesSimple.AnalyticalDimensionsDr2 AS AnalyticalDimensionsDr2,
		|	TT_EntriesSimple.AnalyticalDimensionsDr3 AS AnalyticalDimensionsDr3,
		|	TT_EntriesSimple.CurrencyCr AS CurrencyCr,
		|	TT_EntriesSimple.CurrencyDr AS CurrencyDr,
		|	TT_EntriesSimple.AnalyticalDimensionsSetCr AS AnalyticalDimensionsSetCr,
		|	TT_EntriesSimple.AnalyticalDimensionsSetDr AS AnalyticalDimensionsSetDr,
		|	TT_EntriesSimple.FilterPresentation AS FilterPresentation,
		|	TT_EntriesSimple.QuantityCr AS QuantityCr,
		|	TT_EntriesSimple.QuantityDr AS QuantityDr,
		|	TT_EntriesSimple.ConnectionKey AS ConnectionKey,
		|	TT_EntriesSimple.AnalyticalDimensionsTypeCr1 AS AnalyticalDimensionsTypeCr1,
		|	TT_EntriesSimple.AnalyticalDimensionsTypeCr2 AS AnalyticalDimensionsTypeCr2,
		|	TT_EntriesSimple.AnalyticalDimensionsTypeCr3 AS AnalyticalDimensionsTypeCr3,
		|	TT_EntriesSimple.AnalyticalDimensionsTypeDr1 AS AnalyticalDimensionsTypeDr1,
		|	TT_EntriesSimple.AnalyticalDimensionsTypeDr2 AS AnalyticalDimensionsTypeDr2,
		|	TT_EntriesSimple.AnalyticalDimensionsTypeDr3 AS AnalyticalDimensionsTypeDr3,
		|	TT_EntriesSimple.AnalyticalDimensionsCr4 AS AnalyticalDimensionsCr4,
		|	TT_EntriesSimple.AnalyticalDimensionsDr4 AS AnalyticalDimensionsDr4,
		|	TT_EntriesSimple.AnalyticalDimensionsTypeDr4 AS AnalyticalDimensionsTypeDr4,
		|	TT_EntriesSimple.AnalyticalDimensionsTypeCr4 AS AnalyticalDimensionsTypeCr4,
		|	TT_EntriesSimple.DefaultAccountTypeCr AS DefaultAccountTypeCr,
		|	TT_EntriesSimple.AccountReferenceNameCr AS AccountReferenceNameCr,
		|	TT_EntriesSimple.DefaultAccountTypeDr AS DefaultAccountTypeDr,
		|	TT_EntriesSimple.AccountReferenceNameDr AS AccountReferenceNameDr
		|FROM
		|	TT_EntriesSimple AS TT_EntriesSimple
		|		INNER JOIN TT_Refs AS TT_Refs
		|		ON TT_EntriesSimple.Ref = TT_Refs.Ref
		|
		|ORDER BY
		|	TT_Refs.RefOrder,
		|	EntryLineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	TT_Entries.Ref AS Ref,
		|	TT_Entries.ConnectionKey AS ConnectionKey
		|INTO TT_EntriesUnion
		|FROM
		|	TT_Entries AS TT_Entries
		|
		|UNION ALL
		|
		|SELECT
		|	TT_EntriesSimple.Ref,
		|	TT_EntriesSimple.ConnectionKey
		|FROM
		|	TT_EntriesSimple AS TT_EntriesSimple
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	AccountingEntriesTemplatesEntriesFilters.Ref AS Ref,
		|	AccountingEntriesTemplatesEntriesFilters.ParameterName AS ParameterName,
		|	AccountingEntriesTemplatesEntriesFilters.ParameterSynonym AS ParameterSynonym,
		|	AccountingEntriesTemplatesEntriesFilters.Condition AS Condition,
		|	AccountingEntriesTemplatesEntriesFilters.ValuePresentation AS ValuePresentation,
		|	AccountingEntriesTemplatesEntriesFilters.EntryConnectionKey AS EntryConnectionKey,
		|	AccountingEntriesTemplatesEntriesFilters.ValuesConnectionKey AS ValuesConnectionKey,
		|	AccountingEntriesTemplatesEntriesFilters.SavedValueType AS SavedValueType,
		|	AccountingEntriesTemplatesEntriesFilters.MultipleValuesMode AS MultipleValuesMode
		|FROM
		|	Catalog.AccountingEntriesTemplates.EntriesFilters AS AccountingEntriesTemplatesEntriesFilters
		|WHERE
		|	(AccountingEntriesTemplatesEntriesFilters.Ref, AccountingEntriesTemplatesEntriesFilters.EntryConnectionKey) IN
		|			(SELECT
		|				TT_EntriesUnion.Ref AS Ref,
		|				TT_EntriesUnion.ConnectionKey AS ConnectionKey
		|			FROM
		|				TT_EntriesUnion AS TT_EntriesUnion)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	AccountingEntriesTemplatesElementsSynonyms.Ref AS Ref,
		|	AccountingEntriesTemplatesElementsSynonyms.MetadataName AS MetadataName,
		|	AccountingEntriesTemplatesElementsSynonyms.ConnectionKey AS ConnectionKey,
		|	AccountingEntriesTemplatesElementsSynonyms.Synonym AS Synonym
		|FROM
		|	Catalog.AccountingEntriesTemplates.ElementsSynonyms AS AccountingEntriesTemplatesElementsSynonyms
		|WHERE
		|	(AccountingEntriesTemplatesElementsSynonyms.Ref, AccountingEntriesTemplatesElementsSynonyms.ConnectionKey) IN
		|			(SELECT
		|				TT_EntriesUnion.Ref AS Ref,
		|				TT_EntriesUnion.ConnectionKey AS ConnectionKey
		|			FROM
		|				TT_EntriesUnion AS TT_EntriesUnion)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	AccountingEntriesTemplatesParametersValues.Ref AS Ref,
		|	AccountingEntriesTemplatesParametersValues.ConnectionKey AS ConnectionKey,
		|	AccountingEntriesTemplatesParametersValues.MetadataName AS MetadataName,
		|	AccountingEntriesTemplatesParametersValues.Value AS Value
		|FROM
		|	Catalog.AccountingEntriesTemplates.ParametersValues AS AccountingEntriesTemplatesParametersValues
		|WHERE
		|	AccountingEntriesTemplatesParametersValues.Ref IN
		|			(SELECT
		|				TT_EntriesUnion.Ref AS Ref
		|			FROM
		|				TT_EntriesUnion AS TT_EntriesUnion)
		|	AND AccountingEntriesTemplatesParametersValues.MetadataName = ""EntriesFilters""
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	AccountingEntriesTemplatesEntriesDefaultAccounts.Ref AS Ref,
		|	AccountingEntriesTemplatesEntriesDefaultAccounts.EntryConnectionKey AS EntryConnectionKey,
		|	AccountingEntriesTemplatesEntriesDefaultAccounts.DrCr AS DrCr,
		|	AccountingEntriesTemplatesEntriesDefaultAccounts.EntryOrder AS EntryOrder,
		|	AccountingEntriesTemplatesEntriesDefaultAccounts.FilterName AS FilterName,
		|	AccountingEntriesTemplatesEntriesDefaultAccounts.FilterSynonym AS FilterSynonym,
		|	AccountingEntriesTemplatesEntriesDefaultAccounts.Value AS Value,
		|	AccountingEntriesTemplatesEntriesDefaultAccounts.ValueSynonym AS ValueSynonym,
		|	AccountingEntriesTemplatesEntriesDefaultAccounts.SavedValueType AS SavedValueType
		|FROM
		|	Catalog.AccountingEntriesTemplates.EntriesDefaultAccounts AS AccountingEntriesTemplatesEntriesDefaultAccounts
		|WHERE
		|	(AccountingEntriesTemplatesEntriesDefaultAccounts.Ref, AccountingEntriesTemplatesEntriesDefaultAccounts.EntryConnectionKey) IN
		|			(SELECT
		|				TT_EntriesUnion.Ref AS Ref,
		|				TT_EntriesUnion.ConnectionKey AS ConnectionKey
		|			FROM
		|				TT_EntriesUnion AS TT_EntriesUnion)";
		
	EndIf;
	
	Return QueryText;

EndFunction 

Function GetTableStructure(TabularSectionName, AdditionalColumns)
	
	Result = New ValueTable;
	
	ColumnsArray = StrSplit(AdditionalColumns, ",", False);
	For Each Column In ColumnsArray Do
		Result.Columns.Add(TrimAll(Column));
	EndDo;
	
	For Each Attribute In Metadata.Catalogs.AccountingEntriesTemplates.TabularSections[TabularSectionName].Attributes Do
		Result.Columns.Add(TrimAll(Attribute.Name));
	EndDo;	
	
	Return Result;
	
EndFunction

Function GetResultParameters(Refs, SelectionDetailRecords)

	LastConnectionKey = 1;
	
	ResultParameters = GetTableStructure("Parameters", "Ref");
	
	While SelectionDetailRecords.Next() Do
					
		NewRow = ResultParameters.Add();
		
		FillPropertyValues(NewRow, SelectionDetailRecords, , "Condition, SavedValueType");
		
		NewRow.Condition		 = New ValueStorage(SelectionDetailRecords.Condition.Get());
		NewRow.SavedValueType	 = New ValueStorage(SelectionDetailRecords.SavedValueType.Get());
		
		If NewRow.ValuesConnectionKey <> 0 Then
			
			Filter = New Structure;
			Filter.Insert("Ref"				, SelectionDetailRecords.Ref);
			Filter.Insert("MetaData"		, "Parameters");
			Filter.Insert("ConnectionKey"	, SelectionDetailRecords.ValuesConnectionKey);
			
			Rows = Refs.FindRows(Filter);
			
			If Rows.Count() = 0 Then
				
				NewRefs					 = Refs.Add();
				NewRefs.Ref				 = SelectionDetailRecords.Ref;
				NewRefs.MetaData		 = "Parameters";
				NewRefs.ConnectionKey	 = SelectionDetailRecords.ValuesConnectionKey;
				NewRefs.NewConnectionKey = LastConnectionKey;
				
				ConnectionKey		 = LastConnectionKey;
				LastConnectionKey	 = LastConnectionKey + 1;
				
			Else				
				ConnectionKey = Rows[0].NewConnectionKey;
			EndIf;
			
			NewRow.ValuesConnectionKey = ConnectionKey;
			
		EndIf;
		
	EndDo;

	Return ResultParameters;
	
EndFunction 

Function GetResultParametersValues(Refs, SelectionDetailRecords)

	ResultParametersValues = GetTableStructure("ParametersValues", "Ref");
	
	While SelectionDetailRecords.Next() Do
		
		Filter = New Structure;
		Filter.Insert("Ref"				, SelectionDetailRecords.Ref);
		Filter.Insert("MetaData"		, "Parameters");
		Filter.Insert("ConnectionKey"	, SelectionDetailRecords.ConnectionKey);
		Rows = Refs.FindRows(Filter);
		
		If Rows.Count() > 0 Then
			NewRow = ResultParametersValues.Add();
			
			FillPropertyValues(NewRow,SelectionDetailRecords);
			
			ConnectionKey = Rows[0].NewConnectionKey;
			
			NewRow.ConnectionKey = ConnectionKey;
		EndIf;
		
	EndDo;
	
	Return ResultParametersValues;

EndFunction 

Function GetResultEntries(Refs, SelectionDetailRecords)

	LastConnectionKey = 1;
	
	ResultEntries = GetTableStructure("Entries", "Ref, EntriesTemplate");
	
	While SelectionDetailRecords.Next() Do
			
		NewRow = ResultEntries.Add();
		
		FillPropertyValues(NewRow, SelectionDetailRecords);
		NewRow.EntriesTemplate = NewRow.Ref;
		
		Filter = New Structure;
		Filter.Insert("Ref"				, SelectionDetailRecords.Ref);
		Filter.Insert("MetaData"		, "Entries");
		Filter.Insert("ConnectionKey"	, SelectionDetailRecords.ConnectionKey);
		Rows = Refs.FindRows(Filter);
		
		If Rows.Count() = 0 Then
			
			 NewRefs					 = Refs.Add();
			 NewRefs.Ref				 = SelectionDetailRecords.Ref;
			 NewRefs.MetaData			 = "Entries";
			 NewRefs.ConnectionKey		 = SelectionDetailRecords.ConnectionKey;
			 NewRefs.NewConnectionKey	 = LastConnectionKey;
			 
			 ConnectionKey		 = LastConnectionKey;
			 LastConnectionKey	 = LastConnectionKey + 1;
			 
		 Else
			 
			 ConnectionKey = Rows[0].NewConnectionKey;
			 
		EndIf;
		
		NewRow.ConnectionKey = ConnectionKey;
		
	EndDo;

	Return ResultEntries;
	
EndFunction 

Function GetResultEntriesSimple(Refs, SelectionDetailRecords)

	LastConnectionKey = 1;
	
	ResultEntries = GetTableStructure("EntriesSimple", "Ref,EntriesTemplate");
	ResultEntries.Columns.Add("EntryLineNumber");
	
	While SelectionDetailRecords.Next() Do
			
		NewRow = ResultEntries.Add();
		
		FillPropertyValues(NewRow, SelectionDetailRecords);
		NewRow.EntriesTemplate = NewRow.Ref;
		
		Filter = New Structure;
		Filter.Insert("Ref"				, SelectionDetailRecords.Ref);
		Filter.Insert("MetaData"		, "EntriesSimple");
		Filter.Insert("ConnectionKey"	, SelectionDetailRecords.ConnectionKey);
		Rows = Refs.FindRows(Filter);
		
		If Rows.Count() = 0 Then
			
			 NewRefs					 = Refs.Add();
			 NewRefs.Ref				 = SelectionDetailRecords.Ref;
			 NewRefs.MetaData			 = "EntriesSimple";
			 NewRefs.ConnectionKey		 = SelectionDetailRecords.ConnectionKey;
			 NewRefs.NewConnectionKey	 = LastConnectionKey;
			 
			 ConnectionKey		 = LastConnectionKey;
			 LastConnectionKey	 = LastConnectionKey + 1;
			 
		 Else
			 
			 ConnectionKey		 = Rows[0].NewConnectionKey;
			 
		EndIf;
		
		NewRow.ConnectionKey			 = ConnectionKey;
		
	EndDo;

	Return ResultEntries;
	
EndFunction

Function GetResultEntriesFilters(Refs, SelectionDetailRecords, MetaDataName)

	LastConnectionKey = 1;
	
	ResultParametersValues = GetTableStructure("EntriesFilters", "Ref");
	
	While SelectionDetailRecords.Next() Do
		
		NewRow = ResultParametersValues.Add();
		
		FillPropertyValues(NewRow, SelectionDetailRecords);
		
		Filter = New Structure;
		Filter.Insert("Ref"				, SelectionDetailRecords.Ref);
		Filter.Insert("MetaData"		, MetaDataName);
		Filter.Insert("ConnectionKey"	, SelectionDetailRecords.EntryConnectionKey);
		Rows = Refs.FindRows(Filter);
		
		ConnectionKey = Rows[0].NewConnectionKey;
		
		NewRow.EntryConnectionKey = ConnectionKey;
		
		If NewRow.ValuesConnectionKey <> 0 Then
			
			Filter = New Structure;
			Filter.Insert("Ref"				, SelectionDetailRecords.Ref);
			Filter.Insert("MetaData"		, "EntriesFilters");
			Filter.Insert("ConnectionKey"	, SelectionDetailRecords.ValuesConnectionKey);
			Rows = Refs.FindRows(Filter);
			
			If Rows.Count() = 0 Then
				
				NewRefs					 = Refs.Add();
				NewRefs.Ref				 = SelectionDetailRecords.Ref;
				NewRefs.MetaData		 = "EntriesFilters";
				NewRefs.ConnectionKey	 = SelectionDetailRecords.ValuesConnectionKey;
				NewRefs.NewConnectionKey = LastConnectionKey;
				
				ConnectionKey		 = LastConnectionKey;
				LastConnectionKey	 = LastConnectionKey + 1;
				
			Else
				ConnectionKey = Rows[0].NewConnectionKey;
			EndIf;
			
			NewRow.ValuesConnectionKey	 = ConnectionKey;
		EndIf;
		
		NewRow.Condition		 = New ValueStorage(SelectionDetailRecords.Condition.Get());
		NewRow.SavedValueType	 = New ValueStorage(SelectionDetailRecords.SavedValueType.Get());
		
	EndDo;
	
	Return ResultParametersValues;

EndFunction 

Function GetResultElementsSynonyms(Refs, SelectionDetailRecords)

	ResultParametersValues = GetTableStructure("ElementsSynonyms", "Ref");
	
	While SelectionDetailRecords.Next() Do
		
		NewRow = ResultParametersValues.Add();
		
		FillPropertyValues(NewRow,SelectionDetailRecords);
		
		Filter = New Structure;
		Filter.Insert("Ref"				, SelectionDetailRecords.Ref);
		Filter.Insert("MetaData"		, "Entries");
		Filter.Insert("ConnectionKey"	, SelectionDetailRecords.ConnectionKey);
		Rows = Refs.FindRows(Filter);
		
		If Rows.Count() = 0 Then
			Filter.MetaData = "EntriesSimple";
			Rows = Refs.FindRows(Filter);
		EndIf;
		
		ConnectionKey = Rows[0].NewConnectionKey;
		
		NewRow.ConnectionKey = ConnectionKey;
		
	EndDo;
	
	Return ResultParametersValues;

EndFunction 

Function GetResultParametersValuesEntries(Refs, SelectionDetailRecords)

	ResultParametersValues = GetTableStructure("ParametersValues", "Ref");
	
	While SelectionDetailRecords.Next() Do
		
		If SelectionDetailRecords.ConnectionKey = 0 Then
			Continue;
		EndIf;
				
		
		Filter = New Structure;
		Filter.Insert("Ref"				, SelectionDetailRecords.Ref);
		Filter.Insert("MetaData"		, "EntriesFilters");
		Filter.Insert("ConnectionKey"	, SelectionDetailRecords.ConnectionKey);
		
		Rows = Refs.FindRows(Filter);
		
		If Rows.Count() = 0 Then
			Continue;
		EndIf;
		
		NewRow = ResultParametersValues.Add();
		
		FillPropertyValues(NewRow, SelectionDetailRecords);
		
		NewRow.ConnectionKey = Rows[0].NewConnectionKey;
		
	EndDo;
	
	Return ResultParametersValues;

EndFunction 

Function GetResultEntriesDefaultAccounts(Refs, SelectionDetailRecords)

	ResultParametersValues = GetTableStructure("EntriesDefaultAccounts", "Ref");
	
	While SelectionDetailRecords.Next() Do
		
		NewRow = ResultParametersValues.Add();
		
		FillPropertyValues(NewRow, SelectionDetailRecords);
		
		Filter = New Structure;
		Filter.Insert("Ref"				, SelectionDetailRecords.Ref);
		Filter.Insert("MetaData"		, "Entries");
		Filter.Insert("ConnectionKey"	, SelectionDetailRecords.EntryConnectionKey);
		Rows = Refs.FindRows(Filter);
		
		If Rows.Count() = 0 Then
			Filter.MetaData = "EntriesSimple";
			Rows = Refs.FindRows(Filter);
		EndIf;
		
		NewRow.EntryConnectionKey	= Rows[0].NewConnectionKey;
		NewRow.SavedValueType		= New ValueStorage(SelectionDetailRecords.SavedValueType.Get());
		
	EndDo;
	
	Return ResultParametersValues;

EndFunction 

Procedure GroupParametersByFieldAndValues(Parameters, ParametersValues)

	ParamsToDelete = New Array;
	ParamsChecked  = New Array;
	
	For Each ParamRow In Parameters Do
		
		If ParameterIsDuplicate(ParamRow, ParamsChecked, ParametersValues) Then
			ParamsToDelete.Add(ParamRow);
		Else
			ParamsChecked.Add(ParamRow);
		EndIf;   		
		
	EndDo;
	
	For Each RowToDel In ParamsToDelete Do
		
		DeleteAllRowsByConnectionKey(ParametersValues, RowToDel.ValuesConnectionKey, "ConnectionKey");
		
		Parameters.Delete(RowToDel);
		
	EndDo;
	
EndProcedure

Function ParameterIsDuplicate(ParameterToCheck, ParametersChecked, ParametersValues)

	For Each Parameter In ParametersChecked Do
		
		If ParameterToCheck.ParameterName <> Parameter.ParameterName 
			Or ParameterToCheck.ValuePresentation <> Parameter.ValuePresentation 
			Or ParameterToCheck.Condition.Get() <> Parameter.Condition.Get() Then
			
			Continue;
		EndIf;
		
		ParameterToCheckValues 	= GetValuesArray(ParametersValues, ParameterToCheck.ValuesConnectionKey, "Parameters");
		ParameterValues 		= GetValuesArray(ParametersValues, Parameter.ValuesConnectionKey, "Parameters");
		
		If Not Common.IdenticalCollections(ParameterToCheckValues, ParameterValues) Then
			Continue;
		EndIf;
		
		Return True;
	EndDo;

	Return False;
	
EndFunction 

#EndRegion

Function CheckParametersInTemplate(EntriesTemplate, TemplateParameters)

	For Each Parameter In EntriesTemplate.Parameters Do
		
		Filter = New Structure;
		Filter.Insert("ParameterName", Parameter.ParameterName);
		
		FindRows = TemplateParameters.FindRows(Filter);
		
		If FindRows.Count() > 0 Then
			
			EntriesParameterValues = GetValuesArray(
				EntriesTemplate.ParametersValues,
				Parameter.ValuesConnectionKey,
				"Parameters");
			
			For Each Row In FindRows Do
				
				If Row.ValuePresentation = Parameter.ValuePresentation 
					And Row.ConditionPresentation = Parameter.Condition.Get() Then
					
					If Not Common.IdenticalCollections(Row.ParameterValues, EntriesParameterValues) Then
						Return False;
					EndIf;
					
				Else
					Return False;
				EndIf;
			
			EndDo;
			
		EndIf;
		
	EndDo;
	
	Return True;

EndFunction

Function GetTypeOfRegisterField(FieldName)
	
	If FieldName = "Period" Or FieldName = "Recorder" Then
		Item = Metadata.InformationRegisters.AccountingEntriesData.StandardAttributes[FieldName];
		Return Item.Type;
	EndIf;
	
	Item = Metadata.InformationRegisters.AccountingEntriesData.Attributes.Find(FieldName);
	If Item <> Undefined Then
		Return Item.Type;
	EndIf;
	
	Item = Metadata.InformationRegisters.AccountingEntriesData.Dimensions.Find(FieldName);
	If Item <> Undefined Then
		Return Item.Type;
	EndIf;
	
	Item = Metadata.InformationRegisters.AccountingEntriesData.Resources.Find(FieldName);
	If Item <> Undefined Then
		Return Item.Type;
	EndIf;
	
EndFunction

Procedure CheckDefaultAccountValidation(CheckingObject, ErrorFields = Undefined) Export
	
	AccountSynonymTemplate = NStr("en = '%1 - %2'; ru = '%1 - %2';pl = '%1 - %2';es_ES = '%1 - %2';es_CO = '%1 - %2';tr = '%1 - %2';it = '%1 - %2';de = '%1 - %2'");
	ErrorTextTemplate = NStr("en = 'Line %1 contains account ""%2"". This account is not valid for the selected company, types of accounts, or chart of accounts. Select another default account.'; ru = 'Строка %1 содержит счет ""%2"". Этот счет недействителен для указанной организации, типов счетов или плана счетов. Выберите другой счет.';pl = 'Wiersz %1 zawiera konto ""%2"". To konto nie jest ważne dla wybranej firmy, rodzajów kont. Wybierz inne domyślne konto.';es_ES = 'La línea %1 contiene la cuenta ""%2"". Esta cuenta no es válida para la empresa, los tipos de cuentas o el diagrama de cuentas seleccionados. Seleccione otra cuenta por defecto.';es_CO = 'La línea %1 contiene la cuenta ""%2"". Esta cuenta no es válida para la empresa, los tipos de cuentas o el diagrama de cuentas seleccionados. Seleccione otra cuenta por defecto.';tr = '%1 satırı ""%2"" hesabını içeriyor. Bu hesap seçilen iş yeri, hesap türü veya hesap planı için geçerli değil. Başka bir varsayılan hesap seçin.';it = 'La riga %1 contiene un conto ""%2"". Questo conto non è valido per l''azienda selezionata, i tipi di conti o il piano dei conti. Selezionare un altro conto predefinito.';de = 'Die Zeile %1 enthält Konto ""%2"". Dieses Konto ist für die ausgewählte Firma, Typen von Konten oder das Kontenplan dieser Vorlage nicht gültig. Wählen Sie ein anderes Standardkonto aus.'");
	
	For Each Row In CheckingObject.Entries Do
		
		If ValueIsFilled(Row.DefaultAccountType) 
			And Not CheckDefaultAccountAttributes(CheckingObject, Row.DefaultAccountType) Then
			
			AccountSynonym = StrTemplate(AccountSynonymTemplate, Row.DefaultAccountType, Row.AccountReferenceName);
			
			FieldStructure = New Structure;
			FieldStructure.Insert("Name"		,	"AccountSynonym");
			FieldStructure.Insert("Synonym"		,	AccountSynonym);
			FieldStructure.Insert("ObjectName"	,	"Object.Entries");
			FieldStructure.Insert("RowCount"	,	Row.LineNumber - 1);
			FieldStructure.Insert("Text"		,	StrTemplate(ErrorTextTemplate, Row.LineNumber, AccountSynonym));
			FieldStructure.Insert("DefaultAccount",	True);
			ErrorFields.Add(FieldStructure);
			
		EndIf;
		
	EndDo;
	
	For Each Row In CheckingObject.EntriesSimple Do
		
		If ValueIsFilled(Row.DefaultAccountTypeDr)
			And Not CheckDefaultAccountAttributes(CheckingObject, Row.DefaultAccountTypeDr) Then
			
			AccountSynonym = StrTemplate(AccountSynonymTemplate, Row.DefaultAccountTypeDr, Row.AccountReferenceNameDr);
			
			FieldStructure = New Structure;
			FieldStructure.Insert("Name"		,	"AccountDrSynonym");
			FieldStructure.Insert("Synonym"		,	AccountSynonym);
			FieldStructure.Insert("ObjectName"	,	"Object.EntriesSimple");
			FieldStructure.Insert("RowCount"	,	Row.LineNumber - 1);
			FieldStructure.Insert("Text"		,	StrTemplate(ErrorTextTemplate, Row.LineNumber, AccountSynonym));
			FieldStructure.Insert("DefaultAccount", True);
			ErrorFields.Add(FieldStructure);
				
		EndIf;
		
		If ValueIsFilled(Row.DefaultAccountTypeCr)
			And Not CheckDefaultAccountAttributes(CheckingObject, Row.DefaultAccountTypeCr) Then
				
			AccountSynonym = StrTemplate(AccountSynonymTemplate, Row.DefaultAccountTypeCr, Row.AccountReferenceNameCr);
			
			FieldStructure = New Structure;
			FieldStructure.Insert("Name"		,	"AccountCrSynonym");
			FieldStructure.Insert("Synonym"		,	Row.DefaultAccountTypeCr);
			FieldStructure.Insert("ObjectName"	,	"Object.EntriesSimple");
			FieldStructure.Insert("RowCount"	,	Row.LineNumber - 1);
			FieldStructure.Insert("Text"		,	StrTemplate(ErrorTextTemplate, Row.LineNumber, AccountSynonym));
			FieldStructure.Insert("DefaultAccount",	True);
			ErrorFields.Add(FieldStructure);
			
		EndIf;
		
	EndDo;
	
EndProcedure

Function CheckDefaultAccountAttributes(CheckingObject, DefaultAccount)
	
	Return DefaultAccount.TypeOfAccounting = CheckingObject.TypeOfAccounting
		And DefaultAccount.ChartOfAccounts = CheckingObject.ChartOfAccounts
		And (Not ValueIsFilled(DefaultAccount.Company)
		Or DefaultAccount.Company = CheckingObject.Company);
	
EndFunction

Procedure CheckAccountsValueValidation(CheckingObject, ErrorFields = Undefined, Cancel = False) Export
	
	If Not ValueIsFilled(CheckingObject.ChartOfAccounts) 
		Or (CheckingObject.Entries.Count() = 0 And CheckingObject.EntriesSimple.Count() = 0) Then
		Return;
	EndIf;
	
	MasterRecordSet = AccountingApprovalServer.GetMasterByChartOfAccounts(CheckingObject.ChartOfAccounts);
	
	If MasterRecordSet Then
		
		Query = New Query;

		Query.SetParameter("EntriesSimple"	, CheckingObject.EntriesSimple.Unload(,"LineNumber, AccountCr, AccountDr"));
		Query.SetParameter("Entries"		, CheckingObject.Entries.Unload(,"LineNumber, Account"));
		
		If CheckingObject.Status = Enums.AccountingEntriesTemplatesStatuses.Active Then
			Query.SetParameter("StartDate"	, CheckingObject.StartDate);
			Query.SetParameter("EndDate"	, CheckingObject.EndDate);
			CheckingObjectStartDate	 = CheckingObject.StartDate;
			CheckingObjectEndDate	 = CheckingObject.EndDate;
		Else
			Query.SetParameter("StartDate"	, CheckingObject.PlanStartDate);
			Query.SetParameter("EndDate"	, CheckingObject.PlanEndDate);
			CheckingObjectStartDate	 = CheckingObject.PlanStartDate;
			CheckingObjectEndDate	 = CheckingObject.PlanEndDate;
		EndIf;
		
		Query.SetParameter("Company", CheckingObject.Company);

		Query.Text = 
		"SELECT
		|	""EntriesSimple"" AS TabularSectionName,
		|	EntriesSimple.LineNumber,
		|	""AccountCrSynonym"" AS FieldNameCr,
		|	""AccountDrSynonym"" AS FieldNameDr,
		|	EntriesSimple.AccountCr,
		|	EntriesSimple.AccountDr
		|INTO EntriesSimple
		|FROM
		|	&EntriesSimple AS EntriesSimple
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	""Entries"" AS TabularSectionName,
		|	Entries.LineNumber,
		|	""AccountSynonym"" AS FieldName,
		|	Entries.Account
		|INTO Entries
		|FROM
		|	&Entries AS Entries";
		
		Query.Text = Query.Text + DriveClientServer.GetQueryDelimeter();
		
		If ValueIsFilled(CheckingObject.Company) Then
			
			Query.Text = Query.Text +
			"SELECT
			|	Entries.Account AS Account,
			|	MasterChartOfAccountsCompanies.Company AS Company
			|INTO AccountWithCompany
			|FROM
			|	Entries AS Entries
			|		INNER JOIN ChartOfAccounts.MasterChartOfAccounts.Companies AS MasterChartOfAccountsCompanies
			|		ON Entries.Account = MasterChartOfAccountsCompanies.Ref
			|
			|UNION ALL
			|
			|SELECT
			|	EntriesSimple.AccountDr,
			|	MasterChartOfAccountsCompanies.Company
			|FROM
			|	EntriesSimple AS EntriesSimple
			|		INNER JOIN ChartOfAccounts.MasterChartOfAccounts.Companies AS MasterChartOfAccountsCompanies
			|		ON EntriesSimple.AccountDr = MasterChartOfAccountsCompanies.Ref
			|
			|UNION ALL
			|
			|SELECT
			|	EntriesSimple.AccountCr,
			|	MasterChartOfAccountsCompanies.Company
			|FROM
			|	EntriesSimple AS EntriesSimple
			|		INNER JOIN ChartOfAccounts.MasterChartOfAccounts.Companies AS MasterChartOfAccountsCompanies
			|		ON EntriesSimple.AccountCr = MasterChartOfAccountsCompanies.Ref
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT
			|	AccountWithCompany.Account AS Account
			|INTO AccountWithCurrentCompany
			|FROM
			|	AccountWithCompany AS AccountWithCompany
			|WHERE
			|	AccountWithCompany.Company = &Company
			|
			|GROUP BY
			|	AccountWithCompany.Account
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT
			|	Entries.TabularSectionName AS TabularSectionName,
			|	Entries.LineNumber AS LineNumber,
			|	Entries.Account AS Account,
			|	Entries.FieldName AS FieldName,
			|	"""" AS NameAdding
			|FROM
			|	Entries AS Entries
			|		LEFT JOIN AccountWithCurrentCompany AS AccountWithCurrentCompany
			|		ON Entries.Account = AccountWithCurrentCompany.Account
			|WHERE
			|	Entries.Account IN
			|			(SELECT
			|				AccountWithCompany.Account AS Account
			|			FROM
			|				AccountWithCompany AS AccountWithCompany)
			|	AND AccountWithCurrentCompany.Account IS NULL
			|
			|UNION ALL
			|
			|SELECT
			|	EntriesSimple.TabularSectionName,
			|	EntriesSimple.LineNumber,
			|	EntriesSimple.AccountDr,
			|	EntriesSimple.FieldNameDr,
			|	""Dr""
			|FROM
			|	EntriesSimple AS EntriesSimple
			|		LEFT JOIN AccountWithCurrentCompany AS AccountWithCurrentCompany
			|		ON EntriesSimple.AccountDr = AccountWithCurrentCompany.Account
			|WHERE
			|	EntriesSimple.AccountDr IN
			|			(SELECT
			|				AccountWithCompany.Account AS Account
			|			FROM
			|				AccountWithCompany AS AccountWithCompany)
			|	AND AccountWithCurrentCompany.Account IS NULL
			|
			|UNION ALL
			|
			|SELECT
			|	EntriesSimple.TabularSectionName,
			|	EntriesSimple.LineNumber,
			|	EntriesSimple.AccountCr,
			|	EntriesSimple.FieldNameCr,
			|	""Cr""
			|FROM
			|	EntriesSimple AS EntriesSimple
			|		LEFT JOIN AccountWithCurrentCompany AS AccountWithCurrentCompany
			|		ON EntriesSimple.AccountCr = AccountWithCurrentCompany.Account
			|WHERE
			|	EntriesSimple.AccountCr IN
			|			(SELECT
			|				AccountWithCompany.Account AS Account
			|			FROM
			|				AccountWithCompany AS AccountWithCompany)
			|	AND AccountWithCurrentCompany.Account IS NULL
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT
			|	EntriesSimple.TabularSectionName AS TabularSectionName,
			|	EntriesSimple.LineNumber AS LineNumber,
			|	EntriesSimple.AccountCr AS Account,
			|	EntriesSimple.FieldNameCr AS FieldName,
			|	ChartOfAccountsTable.StartDate AS StartDate,
			|	ChartOfAccountsTable.EndDate AS EndDate,
			|	""Cr"" AS NameAdding
			|FROM
			|	EntriesSimple AS EntriesSimple
			|		INNER JOIN ChartOfAccounts.MasterChartOfAccounts.Companies AS ChartOfAccountsTable
			|		ON EntriesSimple.AccountCr = ChartOfAccountsTable.Ref
			|			AND (ChartOfAccountsTable.Company = &Company)
			|			AND (ChartOfAccountsTable.StartDate > &StartDate
			|				OR &EndDate > ChartOfAccountsTable.EndDate
			|					AND ChartOfAccountsTable.EndDate <> DATETIME(1, 1, 1)
			|				OR &EndDate = DATETIME(1, 1, 1)
			|					AND ChartOfAccountsTable.EndDate <> DATETIME(1, 1, 1))
			|
			|UNION ALL
			|
			|SELECT
			|	EntriesSimple.TabularSectionName,
			|	EntriesSimple.LineNumber,
			|	EntriesSimple.AccountDr,
			|	EntriesSimple.FieldNameDr,
			|	ChartOfAccountsTable.StartDate,
			|	ChartOfAccountsTable.EndDate,
			|	""Dr""
			|FROM
			|	EntriesSimple AS EntriesSimple
			|		INNER JOIN ChartOfAccounts.MasterChartOfAccounts.Companies AS ChartOfAccountsTable
			|		ON EntriesSimple.AccountDr = ChartOfAccountsTable.Ref
			|			AND (ChartOfAccountsTable.Company = &Company)
			|			AND (ChartOfAccountsTable.StartDate > &StartDate
			|				OR &EndDate > ChartOfAccountsTable.EndDate
			|					AND ChartOfAccountsTable.EndDate <> DATETIME(1, 1, 1)
			|				OR &EndDate = DATETIME(1, 1, 1)
			|					AND ChartOfAccountsTable.EndDate <> DATETIME(1, 1, 1))
			|
			|UNION ALL
			|
			|SELECT
			|	Entries.TabularSectionName,
			|	Entries.LineNumber,
			|	Entries.Account,
			|	Entries.FieldName,
			|	ChartOfAccountsTable.StartDate,
			|	ChartOfAccountsTable.EndDate,
			|	""""
			|FROM
			|	Entries AS Entries
			|		INNER JOIN ChartOfAccounts.MasterChartOfAccounts.Companies AS ChartOfAccountsTable
			|		ON Entries.Account = ChartOfAccountsTable.Ref
			|			AND (ChartOfAccountsTable.Company = &Company)
			|			AND (ChartOfAccountsTable.StartDate > &StartDate
			|				OR &EndDate > ChartOfAccountsTable.EndDate
			|					AND ChartOfAccountsTable.EndDate <> DATETIME(1, 1, 1)
			|				OR &EndDate = DATETIME(1, 1, 1)
			|					AND ChartOfAccountsTable.EndDate <> DATETIME(1, 1, 1))
			|
			|ORDER BY
			|	LineNumber";
			
		Else
			
			Query.Text = Query.Text + 
			"SELECT
			|	EntriesSimple.TabularSectionName AS TabularSectionName,
			|	EntriesSimple.LineNumber AS LineNumber,
			|	EntriesSimple.AccountCr AS Account,
			|	EntriesSimple.FieldNameCr AS FieldName,
			|	ChartOfAccountsTable.StartDate AS StartDate,
			|	ChartOfAccountsTable.EndDate AS EndDate,
			|	""Cr"" AS NameAdding
			|FROM
			|	EntriesSimple AS EntriesSimple
			|		INNER JOIN ChartOfAccounts.MasterChartOfAccounts AS ChartOfAccountsTable
			|		ON EntriesSimple.AccountCr = ChartOfAccountsTable.Ref
			|			AND (ChartOfAccountsTable.StartDate > &StartDate
			|				OR &EndDate > ChartOfAccountsTable.EndDate
			|					AND ChartOfAccountsTable.EndDate <> DATETIME(1, 1, 1)
			|				OR &EndDate = DATETIME(1, 1, 1)
			|					AND ChartOfAccountsTable.EndDate <> DATETIME(1, 1, 1))
			|
			|UNION ALL
			|
			|SELECT
			|	EntriesSimple.TabularSectionName,
			|	EntriesSimple.LineNumber,
			|	EntriesSimple.AccountDr,
			|	EntriesSimple.FieldNameDr,
			|	ChartOfAccountsTable.StartDate,
			|	ChartOfAccountsTable.EndDate,
			|	""Dr""
			|FROM
			|	EntriesSimple AS EntriesSimple
			|		INNER JOIN ChartOfAccounts.MasterChartOfAccounts AS ChartOfAccountsTable
			|		ON EntriesSimple.AccountDr = ChartOfAccountsTable.Ref
			|			AND (ChartOfAccountsTable.StartDate > &StartDate
			|				OR &EndDate > ChartOfAccountsTable.EndDate
			|					AND ChartOfAccountsTable.EndDate <> DATETIME(1, 1, 1)
			|				OR &EndDate = DATETIME(1, 1, 1)
			|					AND ChartOfAccountsTable.EndDate <> DATETIME(1, 1, 1))
			|
			|UNION ALL
			|
			|SELECT
			|	Entries.TabularSectionName,
			|	Entries.LineNumber,
			|	Entries.Account,
			|	Entries.FieldName,
			|	ChartOfAccountsTable.StartDate,
			|	ChartOfAccountsTable.EndDate,
			|	""""
			|FROM
			|	Entries AS Entries
			|		INNER JOIN ChartOfAccounts.MasterChartOfAccounts AS ChartOfAccountsTable
			|		ON Entries.Account = ChartOfAccountsTable.Ref
			|			AND (ChartOfAccountsTable.StartDate > &StartDate
			|				OR &EndDate > ChartOfAccountsTable.EndDate
			|					AND ChartOfAccountsTable.EndDate <> DATETIME(1, 1, 1)
			|				OR &EndDate = DATETIME(1, 1, 1)
			|					AND ChartOfAccountsTable.EndDate <> DATETIME(1, 1, 1))
			|
			|ORDER BY
			|	LineNumber";
			
		EndIf;
		
		QueryResult = Query.ExecuteBatch();
		
		If ValueIsFilled(CheckingObject.Company) And Not QueryResult[QueryResult.Count() - 2].IsEmpty() Then
			
			SelectionDetailRecords = QueryResult[QueryResult.Count() - 2].Select();
		
			While SelectionDetailRecords.Next() Do
				
				ErrorTextTemplate = NStr("en = 'Line %1 contains account """"%2"""". The account companies does not match the company of this template. Select another account or template company.'; ru = 'Строка %1 содержит счет """"%2"""". Организация счета не соответствует организации этого шаблона. Выберите другой счет или измените организацию в шаблоне.';pl = 'Wiersz %1 zawiera konto """"%2"""". Firmy konta nie są zgodne z firmą tego szablonu. Wybierz inne konto lub firmę szablonu.';es_ES = 'La línea %1 contiene la cuenta """"%2"""". La cuenta de las empresas no coincide con la empresa de esta plantilla. Seleccione otra cuenta o empresa de la plantilla.';es_CO = 'La línea %1 contiene la cuenta """"%2"""". La cuenta de las empresas no coincide con la empresa de esta plantilla. Seleccione otra cuenta o empresa de la plantilla.';tr = '%1 satırı ""%2"" hesabını içeriyor. Hesabın iş yerleri bu şablonun iş yeri ile eşleşmiyor. Başka bir hesap veya şablon iş yeri seçin.';it = 'La riga %1 contiene il conto """"%2"""". Le aziende del conto non corrispondono all''azienda di questo modello. Selezionare un altro conto o azienda modello.';de = 'Die Zeile %1 enthält Konto ""%2"". Dieses Konto Firmen stimmt mit der Firma dieser Vorlage nicht überein. Wählen Sie ein anderes Konto oder Vorlage Firma aus.'");
				
				FieldStructure = New Structure;
				FieldStructure.Insert("Name"		, SelectionDetailRecords.FieldName);
				FieldStructure.Insert("Synonym"		, SelectionDetailRecords.Account);
				FieldStructure.Insert("ObjectName"	, StrTemplate("Object.%1", SelectionDetailRecords.TabularSectionName));
				FieldStructure.Insert("RowCount"	, SelectionDetailRecords.LineNumber - 1);
				FieldStructure.Insert("Text"		, StrTemplate(
					ErrorTextTemplate,
					SelectionDetailRecords.LineNumber,
					SelectionDetailRecords.Account));
				
				ErrorFields.Add(FieldStructure);
				
			EndDo;
		EndIf;
		
		SelectionDetailRecords = QueryResult[QueryResult.Count() - 1].Select();
		
		While SelectionDetailRecords.Next() Do
			
			ErrorTextTemplate = NStr("en = 'Line %1 contains account ""%2"". The account validity period (from %3 to %4) does not match the validity period of this template. Select another account or adjust the template validity period.'; ru = 'Строка %1 содержит счет ""%2"". Срок действия счета (с %3 по %4) не соответствует сроку действия этого шаблона. Выберите другой счет или измените срок действия шаблона.';pl = 'Wiersz %1 zawiera konto ""%2"". Okres ważności konta (od %3 do %4) nie jest zgodny z okresem tego szablonu. Wybierz inne konto lub dostosuj okres ważności szablonu.';es_ES = 'La línea %1 contiene la cuenta ""%2"". El periodo de validez de la cuenta (desde %3 hasta %4) no coincide con el periodo de validez de esta plantilla. Seleccione otra cuenta o ajuste el periodo de validez de la plantilla.';es_CO = 'La línea %1 contiene la cuenta ""%2"". El periodo de validez de la cuenta (desde %3 hasta %4) no coincide con el periodo de validez de esta plantilla. Seleccione otra cuenta o ajuste el periodo de validez de la plantilla.';tr = '%1 satırı ""%2"" hesabını içeriyor. Hesabın geçerlilik dönemi (%3 - %4) bu şablonun geçerlilik dönemiyle eşleşmiyor. Başka bir hesap seçin veya şablonun geçerlilik dönemini değiştirin.';it = 'La riga %1 contiene il conto ""%2"". Il periodo di validità del conto (da %3 a %4) non corrisponde al periodo di validità di questo modello. Selezionare un altro conto o correggere il periodo di validità del modello.';de = 'Die Zeile %1 enthält Konto ""%2"". Das Kontogültigkeitsdauer (vom %3 bis %4) stimmt mit der Gültigkeitsdauer dieser Vorlage nicht überein. Wählen Sie ein anderes Konto aus oder bearbeiten die Vorlagengültigkeitsdauer.'");
			
			FieldStructure = New Structure;
			FieldStructure.Insert("Name"		, SelectionDetailRecords.FieldName);
			FieldStructure.Insert("Synonym"		, SelectionDetailRecords.Account);
			FieldStructure.Insert("ObjectName"	, StrTemplate("Object.%1", SelectionDetailRecords.TabularSectionName));
			FieldStructure.Insert("RowCount"	, SelectionDetailRecords.LineNumber - 1);
			FieldStructure.Insert("Text"		, StrTemplate(
				ErrorTextTemplate,
				SelectionDetailRecords.LineNumber,
				SelectionDetailRecords.Account,
				Format(CheckingObjectStartDate, "DLF=D; DE=..."),
				Format(CheckingObjectEndDate, "DLF=D; DE=...")));
			
			ErrorFields.Add(FieldStructure);
			
		EndDo;
		
	EndIf;
	
EndProcedure

Procedure CheckAccountsValueChartOfAccountsValidation(CheckingObject, ErrorFields = Undefined) Export
	
	If Not ValueIsFilled(CheckingObject.ChartOfAccounts) 
		Or (CheckingObject.Entries.Count() = 0 And CheckingObject.EntriesSimple.Count() = 0)  Then
		Return;
	EndIf;
	
	MasterRecordSet = AccountingApprovalServer.GetMasterByChartOfAccounts(CheckingObject.ChartOfAccounts);
	
	If MasterRecordSet Then
		
		Query = New Query;

		Query.SetParameter("EntriesSimple", CheckingObject.EntriesSimple.Unload(,"LineNumber, AccountCr, AccountDr"));
		Query.SetParameter("Entries", 		CheckingObject.Entries.Unload(,"LineNumber, Account"));
		Query.Text = 
		"SELECT
		|	""EntriesSimple"" AS TabularSectionName,
		|	EntriesSimple.LineNumber,
		|	""AccountCrSynonym"" AS FieldNameCr,
		|	""AccountDrSynonym"" AS FieldNameDr,
		|	EntriesSimple.AccountCr,
		|	EntriesSimple.AccountDr
		|INTO EntriesSimple
		|FROM
		|	&EntriesSimple AS EntriesSimple
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	""Entries"" AS TabularSectionName,
		|	Entries.LineNumber,
		|	""AccountSynonym"" AS FieldName,
		|	Entries.Account
		|INTO Entries
		|FROM
		|	&Entries AS Entries";
		
		Query.Text = Query.Text + DriveClientServer.GetQueryDelimeter();
		
		Query.Text = Query.Text + 
		"SELECT
		|	EntriesSimple.TabularSectionName AS TabularSectionName,
		|	EntriesSimple.LineNumber AS LineNumber,
		|	EntriesSimple.AccountCr AS Account,
		|	EntriesSimple.FieldNameCr AS FieldName,
		|	ChartOfAccountsTable.StartDate AS StartDate,
		|	ChartOfAccountsTable.EndDate AS EndDate,
		|	""Cr"" AS NameAdding
		|FROM
		|	EntriesSimple AS EntriesSimple
		|		INNER JOIN ChartOfAccounts.MasterChartOfAccounts AS ChartOfAccountsTable
		|		ON EntriesSimple.AccountCr = ChartOfAccountsTable.Ref
		|			AND (&ChartOfAccounts <> ChartOfAccountsTable.ChartOfAccounts)
		|
		|UNION ALL
		|
		|SELECT
		|	EntriesSimple.TabularSectionName,
		|	EntriesSimple.LineNumber,
		|	EntriesSimple.AccountDr,
		|	EntriesSimple.FieldNameDr,
		|	ChartOfAccountsTable.StartDate,
		|	ChartOfAccountsTable.EndDate,
		|	""Dr""
		|FROM
		|	EntriesSimple AS EntriesSimple
		|		INNER JOIN ChartOfAccounts.MasterChartOfAccounts AS ChartOfAccountsTable
		|		ON EntriesSimple.AccountDr = ChartOfAccountsTable.Ref
		|			AND (&ChartOfAccounts <> ChartOfAccountsTable.ChartOfAccounts)
		|
		|UNION ALL
		|
		|SELECT
		|	Entries.TabularSectionName,
		|	Entries.LineNumber,
		|	Entries.Account,
		|	Entries.FieldName,
		|	ChartOfAccountsTable.StartDate,
		|	ChartOfAccountsTable.EndDate,
		|	""""
		|FROM
		|	Entries AS Entries
		|		INNER JOIN ChartOfAccounts.MasterChartOfAccounts AS ChartOfAccountsTable
		|		ON Entries.Account = ChartOfAccountsTable.Ref
		|			AND (&ChartOfAccounts <> ChartOfAccountsTable.ChartOfAccounts)
		|
		|ORDER BY
		|	LineNumber";
		
		Query.SetParameter("ChartOfAccounts", CheckingObject.ChartOfAccounts);
			
		QueryResult = Query.Execute();
		
		SelectionDetailRecords = QueryResult.Select();
		
		While SelectionDetailRecords.Next() Do
			
			If ErrorFields = Undefined Then
						
				ErrorMessage = StrTemplate(
					NStr("en = 'Line %1 contains account ""%2"". This account is not valid for the selected chart of accounts. Select another account.'; ru = 'Строка %1 содержит счет ""%2"". Этот счет недействителен для указанного плана счетов. Выберите другой счет.';pl = 'Wiersz %1 zawiera konto ""%2"". To konto nie jest ważne dla wybranego planu kont. Wybierz inne konto.';es_ES = 'La línea %1 contiene la cuenta ""%2"". Esta cuenta no es válida para el diagrama de cuentas seleccionado. Seleccione otra cuenta.';es_CO = 'La línea %1 contiene la cuenta ""%2"". Esta cuenta no es válida para el diagrama de cuentas seleccionado. Seleccione otra cuenta.';tr = '%1 satırı ""%2"" hesabını içeriyor. Bu hesap seçilen hesap planı için geçerli değil. Başka bir hesap seçin.';it = 'La riga %1 contiene il conto ""%2"". Questo conto non è valido per il piano dei conti selezionato. Selezionare un altro conto.';de = 'Die Zeile %1 enthält Konto ""%2"". Dieses Konto ist für den ausgewählten Kontenplan nicht gültig. Wählen Sie ein anderes Standardkonto aus.'"),
					SelectionDetailRecords.Account,
					SelectionDetailRecords.LineNumber);
				
				DriveServer.ShowMessageAboutError(CheckingObject, 
					ErrorMessage, 
					SelectionDetailRecords.TabularSectionName, 
					SelectionDetailRecords.LineNumber, 
					SelectionDetailRecords.FieldName, 
					False);
				
			Else
				
				ErrorField = New Structure;
				ErrorField.Insert("Name"		, SelectionDetailRecords.FieldName);
				ErrorField.Insert("Synonym"		, SelectionDetailRecords.Account);
				ErrorField.Insert("ObjectName"	, StringFunctionsClientServer.SubstituteParametersToString("Object.", SelectionDetailRecords.TabularSectionName));
				ErrorField.Insert("RowCount"	, SelectionDetailRecords.LineNumber - 1);
				ErrorField.Insert("Text"		, StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Line %1 contains account ""%2"". This account is not valid for the selected chart of accounts. Select another account.'; ru = 'Строка %1 содержит счет ""%2"". Этот счет недействителен для указанного плана счетов. Выберите другой счет.';pl = 'Wiersz %1 zawiera konto ""%2"". To konto nie jest ważne dla wybranego planu kont. Wybierz inne konto.';es_ES = 'La línea %1 contiene la cuenta ""%2"". Esta cuenta no es válida para el diagrama de cuentas seleccionado. Seleccione otra cuenta.';es_CO = 'La línea %1 contiene la cuenta ""%2"". Esta cuenta no es válida para el diagrama de cuentas seleccionado. Seleccione otra cuenta.';tr = '%1 satırı ""%2"" hesabını içeriyor. Bu hesap seçilen hesap planı için geçerli değil. Başka bir hesap seçin.';it = 'La riga %1 contiene il conto ""%2"". Questo conto non è valido per il piano dei conti selezionato. Selezionare un altro conto.';de = 'Die Zeile %1 enthält Konto ""%2"". Dieses Konto ist für den ausgewählten Kontenplan nicht gültig. Wählen Sie ein anderes Standardkonto aus.'"),
					SelectionDetailRecords.LineNumber,
					SelectionDetailRecords.Account));
				
				ErrorFields.Add(ErrorField);
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure

#EndRegion