
#Region Interface

Procedure FillDocument(DocumentObject, Val FillingData, Val FillingStrategy = Undefined, ExcludingProperties = "") Export
	
	If SkipFilling(FillingData) Then
		FillPropertyValues(DocumentObject, FillingData);
		Return;
	EndIf;
	
	CallHandlerBeforeFilling(FillingStrategy, DocumentObject, FillingData);
	IncomeAndExpenseItemsInDocuments.FillIncomeAndExpenseItemsInDocument(DocumentObject, FillingData);
	GLAccountsInDocuments.FillGLAccountsInDocument(DocumentObject, FillingData);
	
	ConvertFillingDataRefTypeToStructure(FillingData, DocumentObject);
	ConvertValuesFillingDataArrayTypeToRef(FillingData);
	SupplementRegistrationPeriod(FillingData, DocumentObject);
	SupplementValuesFromSettings(FillingData, DocumentObject);
	RenameEventFields(FillingData);
	SupplementCatalogPredefinedItems(FillingData, DocumentObject);
	RenameFields(FillingData, DocumentObject);
	
	FillingData.Insert("Author", Users.CurrentUser());
	
	DeleteUnfilledExcludingProperties(FillingData, ExcludingProperties);
	FillPropertyValues(DocumentObject, FillingData,, ExcludingProperties);
	
	FillTabularSections(DocumentObject, FillingData);
	
EndProcedure

Procedure DeleteUnfilledExcludingProperties(FillingData, ExcludingProperties)
	
	If ExcludingProperties = "" Then
		Return;
	EndIf;
	
	StructureExcludingProperties = DriveClientServer.StringToStructure(ExcludingProperties, ",");
	
	For Each PropertyName In StructureExcludingProperties Do
		If Not FillingData.Property(PropertyName.Key) Then
			StructureExcludingProperties.Delete(PropertyName.Key);
		EndIf;
	EndDo;
	
	ExcludingProperties = DriveClientServer.StructureToString(StructureExcludingProperties, ",");
	
EndProcedure

Procedure SupplementCurrencies(ValuesFromSettings, DocumentObject) Export
	
	CurrencyByDefault = DriveReUse.GetFunctionalCurrency();
	
	For Each AttributeName In AttributeNames(CurrencyByDefault, DocumentObject) Do
		
		If ValuesFromSettings.Property(AttributeName) Then
			Continue;
		EndIf;
		
		If ValueIsFilled(DocumentObject[AttributeName]) Then
			Continue;
		EndIf;
		
		ValuesFromSettings.Insert(AttributeName, CurrencyByDefault);
		
	EndDo;
	
EndProcedure

Procedure RenameFields(FillingData, DocumentObject) Export
	
	RenamedFields = CommonClientServer.CopyStructure(FillingData);
	
	DeleteUnfilledValues(RenamedFields);
	
	RenameFieldsCompany(RenamedFields, DocumentObject);
	RenameFieldsCounterparty(RenamedFields, DocumentObject);
	RenameFieldsCounterpartyVATTaxation(RenamedFields, DocumentObject);
	RenameFieldsContract(RenamedFields, DocumentObject);
	CheckCurrency(FillingData, RenamedFields);
	RenameFieldsDiscountCard(RenamedFields);
	RenameFieldsStructuralUnit(RenamedFields, DocumentObject);
	RenameFieldsPriceKind(RenamedFields);
	
	If FillingData.Property("Company") Then
		Company = FillingData.Company;
	ElsIf CommonClientServer.HasAttributeOrObjectProperty(DocumentObject, "Company") Then
		Company = DocumentObject.Company;
	Else
		Company = Catalogs.Companies.EmptyRef();
	EndIf;
	
	RenameFieldsCurrency(RenamedFields, Company);
	
	CommonClientServer.SupplementMap(FillingData, RenamedFields, True);
	
EndProcedure

Procedure CheckCurrency(FillingData, RenamedFields)
	
	If Not RenamedFields.Property("DocumentCurrency") Then
		Return;
	EndIf;
	
	If FillingData.Property("DocumentCurrency")
		AND FillingData.DocumentCurrency = RenamedFields.DocumentCurrency Then
		Return;
	EndIf;
	
	FillingData.Delete("DocumentCurrency");
	
	If FillingData.Property("BankAccount") Then
		FillingData.Delete("BankAccount");
	EndIf;
	
	If RenamedFields.Property("BankAccount") Then
		RenamedFields.Delete("BankAccount");
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Function SkipFilling(FillingData)
	
	If TypeOf(FillingData) <> Type("Structure") Then
		Return False;
	EndIf;
	
	If Not FillingData.Property("SkipFilling") Then
		Return False;
	EndIf;
	
	If TypeOf(FillingData.SkipFilling) = Type("Boolean") Then
		Return FillingData.SkipFilling;
	EndIf;
	
	Return False;
	
EndFunction

Procedure CallHandlerBeforeFilling(FillingStrategy, DocumentObject, FillingData)
	
	If Not ValueIsFilled(FillingStrategy) Then
		Return;
	EndIf;
	
	If TypeOf(FillingStrategy) = Type("String") Then
		Common.ExecuteObjectMethod(
		DocumentObject,
		FillingStrategy,
		CommonClientServer.ValueInArray(FillingData));
		Return;
	EndIf;
	
	If TypeOf(FillingStrategy) <> Type("Map") Then
		Raise NStr("en = 'Invalid parameter type ""FillingHandler"": expected String or Map.'; ru = 'Некорректный тип параметра ""FillingHandler"": ожидается String или Map.';pl = 'Nieprawidłowy typ parametru ""FillingHandler"": oczekiwany Wiersz lub Mapa.';es_ES = 'Tipo del parámetro inválido ""FillingHandler"": esperado Línea o Mapa.';es_CO = 'Tipo del parámetro inválido ""FillingHandler"": esperado Línea o Mapa.';tr = 'Geçersiz parametre türü ""FillingHandler"": beklenen Dize veya Harita.';it = 'Tipo di parametro ""FillingHandler"" non valido: la stringa o la corrispondenza prevista.';de = 'Ungültiger Parametertyp ""FüllenderHandler"": erwartet Zeichenfolge oder Datenfeld.'");
	EndIf;
	
	NameHandlerBeforeFilling = FillingStrategy[TypeOf(FillingData)];
	
	If Not ValueIsFilled(NameHandlerBeforeFilling) Then
		Return;
	EndIf;
	
	Common.ExecuteObjectMethod(
	DocumentObject,
	NameHandlerBeforeFilling,
	CommonClientServer.ValueInArray(FillingData));
	
EndProcedure

Procedure ConvertFillingDataRefTypeToStructure(FillingData, DocumentObject)
	
	If Not ValueIsFilled(FillingData) Then
		FillingData = New Structure;
		Return;
	EndIf;
	
	If Not Common.RefTypeValue(FillingData) Then
		Return;
	EndIf;
	
	ParameterBasis	= FillingData;
	FillingData		= New Structure;
	
	For Each AttributeName In AttributeNames(ParameterBasis, DocumentObject) Do
		
		If ValueIsFilled(DocumentObject[AttributeName]) Then
			Continue;
		EndIf;
		
		FillingData.Insert(AttributeName, ParameterBasis);
		
	EndDo;
	
	SupplementFromBasisAmountIncludesVAT(FillingData, ParameterBasis);
	
EndProcedure

Procedure SupplementFromBasisAmountIncludesVAT(FillingData, ParameterBasis)
	
	If FillingData.Property("AmountIncludesVAT") Then
		Return;
	EndIf;
	
	MetadataObject = ParameterBasis.Metadata();
	
	If Not Common.IsDocument(MetadataObject) Then
		Return;
	EndIf;
	
	If Not Common.HasObjectAttribute("AmountIncludesVAT", MetadataObject) Then
		Return;
	EndIf;
	
	FillingData.Insert(
	"AmountIncludesVAT",
	Common.ObjectAttributeValue(
	ParameterBasis,
	"AmountIncludesVAT"));
	
EndProcedure

Procedure ConvertValuesFillingDataArrayTypeToRef(FillingData)
	
	For Each KeyAndValue In FillingData Do
		
		If TypeOf(KeyAndValue.Value) <> Type("Array") Then
			Continue;
		EndIf;
		
		If Not ValueIsFilled(KeyAndValue.Value) Then
			Continue;
		EndIf;
		
		LastArrayItem = KeyAndValue.Value[KeyAndValue.Value.UBound()];
		
		If TypeOf(LastArrayItem) = Type("Structure") Then
			Continue;
		EndIf;
		
		FillingData.Insert(KeyAndValue.Key, LastArrayItem);
		
	EndDo;
	
EndProcedure

Procedure SupplementRegistrationPeriod(FillingData, DocumentObject)
	
	If FillingData.Property("RegistrationPeriod") Then
		Return;
	EndIf;
	
	If NoUnfilledAttribute("RegistrationPeriod", DocumentObject) Then
		Return;
	EndIf;
	
	FillingData.Insert("RegistrationPeriod", BegOfMonth(CurrentSessionDate()));
	
EndProcedure

Procedure SupplementValuesFromSettings(FillingData, DocumentObject)
	
	ValuesFromSettings = New Structure;
	
	SupplementCurrencies(ValuesFromSettings, DocumentObject);
	SupplementCompany(ValuesFromSettings, DocumentObject);
	SupplementDepartment(ValuesFromSettings, DocumentObject);
	SupplementStructuralUnit(ValuesFromSettings, DocumentObject, "MainDepartment");
	SupplementStructuralUnit(ValuesFromSettings, DocumentObject, "MainWarehouse");
	SupplementMainResponsible(ValuesFromSettings, DocumentObject);
	SupplementPriceKind(ValuesFromSettings, DocumentObject);
	SupplementPositionResponsible(ValuesFromSettings, DocumentObject);
	SupplementReceiptDatePositionInPurchaseOrder(ValuesFromSettings, DocumentObject);
	SupplementWorkOrderSettings(ValuesFromSettings, DocumentObject, FillingData);
	SupplementShipmentDatePositionInSalesOrder(ValuesFromSettings, DocumentObject);
	SupplementSalesOrderPositionInShipmentDocuments(ValuesFromSettings, DocumentObject);
	SupplementPurchaseOrderPositionInReceiptDocuments(ValuesFromSettings, DocumentObject);
	SupplementSalesOrderPositionInInventoryTransfer(ValuesFromSettings, DocumentObject);
	SupplementCounterpartyAndContractInActualSalesVolume(ValuesFromSettings, DocumentObject);
	
	// begin Drive.FullVersion
	SupplementWorkKindPositionInEmployeeTask(ValuesFromSettings, DocumentObject);
	SupplementInventoryStructuralUnitPositionInWIP(ValuesFromSettings, DocumentObject);
	// end Drive.FullVersion
	
	CommonClientServer.SupplementStructure(FillingData, ValuesFromSettings, False);
	
EndProcedure

#Region SupplementValuesFromSettings

Procedure SupplementCompany(ValuesFromSettings, DocumentObject)
	
	If NoUnfilledAttribute("Company", DocumentObject) Then
		Return;
	EndIf;
	
	CompanyByDefault = DriveReUse.GetValueByDefaultUser(
	Users.CurrentUser(),
	"MainCompany");
	
	If ValueIsFilled(CompanyByDefault) Then
		ValuesFromSettings.Insert("Company", CompanyByDefault);
	EndIf;
	
EndProcedure

Procedure SupplementDepartment(ValuesFromSettings, DocumentObject)
	
	If NoUnfilledAttribute("Department", DocumentObject) Then
		Return;
	EndIf;
	
	DepartmentByDefault = DriveReUse.GetValueByDefaultUser(
	Users.CurrentUser(),
	"MainDepartment");
	
	If ValueIsFilled(DepartmentByDefault) Then
		ValuesFromSettings.Insert("Department", DepartmentByDefault);
	EndIf;
	
EndProcedure

Procedure SupplementStructuralUnit(ValuesFromSettings, DocumentObject, SettingsName)
	
	If TypeOf(DocumentObject) = Type("DocumentObject.ShiftClosure") Then
		Return;
	EndIf;
	
	StructuralUnit = DriveReUse.GetValueByDefaultUser(
	Users.CurrentUser(),
	SettingsName);
	
	If Not ValueIsFilled(StructuralUnit) Then
		Return;
	EndIf;
	
	StructuralUnitType = Common.ObjectAttributeValue(StructuralUnit, "StructuralUnitType");
	
	For Each Attribute In DocumentObject.Ref.Metadata().Attributes Do
		
		If ValuesFromSettings.Property(Attribute.Name) Then
			Continue;
		EndIf;
		
		If Not Attribute.Type.ContainsType(TypeOf(StructuralUnit)) Then
			Continue;
		EndIf;
		
		If Not StructuralUnitTypeToChoiceParameters(StructuralUnitType, Attribute.ChoiceParameters) Then
			Continue;
		EndIf;
		
		If ValueIsFilled(DocumentObject[Attribute.Name]) Then
			Continue;
		EndIf;
		
		ValuesFromSettings.Insert(Attribute.Name, StructuralUnit);
		
	EndDo;
	
EndProcedure

Procedure SupplementMainResponsible(ValuesFromSettings, DocumentObject)
	
	If NoUnfilledAttribute("Responsible", DocumentObject) Then
		Return;
	EndIf;
	
	MainResponsible = DriveReUse.GetValueByDefaultUser(
	Users.CurrentUser(),
	"MainResponsible");
	
	If ValueIsFilled(MainResponsible) Then
		ValuesFromSettings.Insert("Responsible", MainResponsible);
	EndIf;
	
EndProcedure

Procedure SupplementPriceKind(ValuesFromSettings, DocumentObject)
	
	If ValuesFromSettings.Property("PriceKind")
		AND ValueIsFilled(ValuesFromSettings.PriceKind) Then
		Return;
	EndIf;
	
	If TypeOf(DocumentObject.Ref) = Type("DocumentRef.ShiftClosure") Then
		Return;
	EndIf;
	
	If TypeOf(DocumentObject.Ref) = Type("DocumentRef.SalesSlip") Then
		Return;
	EndIf;
	
	If TypeOf(DocumentObject.Ref) = Type("DocumentRef.ProductReturn") Then
		Return;
	EndIf;
	
	If NoUnfilledAttribute("PriceKind", DocumentObject) Then
		Return;
	EndIf;
	
	PriceKindByDefault = DriveReUse.GetValueByDefaultUser(
	Users.CurrentUser(),
	"MainPriceTypesales");
	
	If ValueIsFilled(PriceKindByDefault) Then
		ValuesFromSettings.Insert("PriceKind", PriceKindByDefault);
	EndIf;
	
EndProcedure

Procedure SupplementPositionResponsible(ValuesFromSettings, DocumentObject)
	
	If TypeOf(DocumentObject.Ref) <> Type("DocumentObject.ShiftClosure") Then
		Return;
	EndIf;
	
	If NoUnfilledAttribute("PositionResponsible", DocumentObject) Then
		Return;
	EndIf;
	
	PositionResponsible = DriveReUse.GetValueByDefaultUser(
	Users.CurrentUser(),
	"PositionResponsible");
	
	If ValueIsFilled(PositionResponsible) Then
		ValuesFromSettings.Insert("PositionResponsible", PositionResponsible);
	EndIf;
	
EndProcedure

Procedure SupplementReceiptDatePositionInPurchaseOrder(ValuesFromSettings, DocumentObject)
	
	If TypeOf(DocumentObject.Ref) <> Type("DocumentRef.PurchaseOrder") Then
		Return;
	EndIf;
	
	ReceiptDatePositionByDefault = DriveReUse.GetValueByDefaultUser(
	Users.CurrentUser(),
	"ReceiptDatePositionInPurchaseOrder");
	
	If ValueIsFilled(ReceiptDatePositionByDefault) Then
		ValuesFromSettings.Insert("ReceiptDatePosition", ReceiptDatePositionByDefault);
	EndIf;
	
EndProcedure

Procedure SupplementWorkOrderSettings(ValuesFromSettings, DocumentObject, FillingData)
	
	If TypeOf(DocumentObject.Ref) <> Type("DocumentRef.SalesOrder") Then
		Return;
	EndIf;
	
	OperationKind = DocumentObject.OperationKind;
	
	If Not ValueIsFilled(OperationKind) Then
		FillingData.Property("OperationKind", OperationKind);
	EndIf;
	
EndProcedure

// begin Drive.FullVersion
Procedure SupplementWorkKindPositionInEmployeeTask(ValuesFromSettings, DocumentObject)
	
	If TypeOf(DocumentObject.Ref) <> Type("DocumentRef.EmployeeTask") Then
		Return;
	EndIf;
	
	If NoUnfilledAttribute("WorkKindPosition", DocumentObject) Then
		Return;
	EndIf;
	
	WorkKindPositionByDefault = DriveReUse.GetValueByDefaultUser(
	Users.CurrentUser(),
	"WorkKindPositionInWorkTask");
	
	If ValueIsFilled(WorkKindPositionByDefault) Then
		ValuesFromSettings.Insert("WorkKindPosition", WorkKindPositionByDefault);
	Else
		ValuesFromSettings.Insert("WorkKindPosition", Enums.AttributeStationing.InHeader);
	EndIf;
	
EndProcedure

Procedure SupplementInventoryStructuralUnitPositionInWIP(ValuesFromSettings, DocumentObject)
	
	If TypeOf(DocumentObject.Ref) <> Type("DocumentRef.ManufacturingOperation")
			Or NoUnfilledAttribute("InventoryStructuralUnitPosition", DocumentObject) Then
		Return;
	EndIf;
	
	InventoryStructuralUnitPositionByDefault = DriveReUse.GetValueByDefaultUser(
		Users.CurrentUser(),
		"InventoryStructuralUnitPositionInWIP");
	
	If ValueIsFilled(InventoryStructuralUnitPositionByDefault) Then
		ValuesFromSettings.Insert("InventoryStructuralUnitPosition", InventoryStructuralUnitPositionByDefault);
	Else
		ValuesFromSettings.Insert("InventoryStructuralUnitPosition", Enums.AttributeStationing.InHeader);
	EndIf;
	
EndProcedure
// end Drive.FullVersion

Procedure SupplementShipmentDatePositionInSalesOrder(ValuesFromSettings, DocumentObject)
	
	If TypeOf(DocumentObject.Ref) <> Type("DocumentRef.SalesOrder") Then
		Return;
	EndIf;
	
	If NoUnfilledAttribute("ShipmentDatePosition", DocumentObject) Then
		Return;
	EndIf;
	
	ShipmentDatePositionByDefault = DriveReUse.GetValueByDefaultUser(
	Users.CurrentUser(),
	"ShipmentDatePositionInSalesOrder");
	
	If ValueIsFilled(ShipmentDatePositionByDefault) Then
		ValuesFromSettings.Insert("ShipmentDatePosition", ShipmentDatePositionByDefault);
	Else
		ValuesFromSettings.Insert("ShipmentDatePosition", Enums.AttributeStationing.InHeader);
	EndIf;
	
EndProcedure

Procedure SupplementCounterpartyAndContractInActualSalesVolume(ValuesFromSettings, DocumentObject)
	
	If TypeOf(DocumentObject.Ref) <> Type("DocumentRef.ActualSalesVolume") Then
		Return;
	EndIf;
	
	If NoUnfilledAttribute(
		"CounterpartyAndContractPosition",
		DocumentObject) Then
		Return;
	EndIf;
	
	CounterpartyAndContractPositionInActualSalesVolume = DriveReUse.GetValueByDefaultUser(
		Users.CurrentUser(),
		"CounterpartyAndContractPositionInActualSalesVolume");
	
	If ValueIsFilled(CounterpartyAndContractPositionInActualSalesVolume) Then
		ValuesFromSettings.Insert("CounterpartyAndContractPosition", CounterpartyAndContractPositionInActualSalesVolume);
	Else
		ValuesFromSettings.Insert("CounterpartyAndContractPosition", Enums.AttributeStationing.InHeader);
	EndIf;
	
EndProcedure

Procedure SupplementSalesOrderPositionInShipmentDocuments(ValuesFromSettings, DocumentObject)
	
	If TypeOf(DocumentObject.Ref) <> Type("DocumentRef.SalesInvoice") Then
		Return;
	EndIf;
	
	If NoUnfilledAttribute(
		"SalesOrderPosition",
		DocumentObject) Then
		Return;
	EndIf;
	
	SalesOrderPositionInShipmentDocuments = DriveReUse.GetValueByDefaultUser(
	Users.CurrentUser(),
	"SalesOrderPositionInShipmentDocuments");
	
	If ValueIsFilled(SalesOrderPositionInShipmentDocuments) Then
		ValuesFromSettings.Insert("SalesOrderPosition", SalesOrderPositionInShipmentDocuments);
	Else
		ValuesFromSettings.Insert("SalesOrderPosition", Enums.AttributeStationing.InHeader);
	EndIf;
	
EndProcedure

Procedure SupplementPurchaseOrderPositionInReceiptDocuments(ValuesFromSettings, DocumentObject)
	
	If TypeOf(DocumentObject.Ref) <> Type("DocumentRef.SupplierInvoice") Then
		Return;
	EndIf;
	
	If NoUnfilledAttribute(
		"PurchaseOrderPosition",
		DocumentObject) Then
		Return;
	EndIf;
	
	PurchaseOrderPositionInReceiptDocuments = DriveReUse.GetValueByDefaultUser(
	Users.CurrentUser(),
	"PurchaseOrderPositionInReceiptDocuments");
	
	If ValueIsFilled(PurchaseOrderPositionInReceiptDocuments) Then
		ValuesFromSettings.Insert("PurchaseOrderPosition", PurchaseOrderPositionInReceiptDocuments);
	Else
		ValuesFromSettings.Insert("PurchaseOrderPosition", Enums.AttributeStationing.InHeader);
	EndIf;
	
EndProcedure

Procedure SupplementSalesOrderPositionInInventoryTransfer(ValuesFromSettings, DocumentObject)
	
	If TypeOf(DocumentObject.Ref) <> Type("DocumentRef.InventoryTransfer") Then
		Return;
	EndIf;
	
	If NoUnfilledAttribute(
		"SalesOrderPosition",
		DocumentObject) Then
		Return;
	EndIf;
	
	SalesOrderPositionInInventoryTransfer = DriveReUse.GetValueByDefaultUser(
	Users.CurrentUser(),
	"SalesOrderPositionInInventoryTransfer");
	
	If ValueIsFilled(SalesOrderPositionInInventoryTransfer) Then
		ValuesFromSettings.Insert("SalesOrderPosition", SalesOrderPositionInInventoryTransfer);
	Else
		ValuesFromSettings.Insert("SalesOrderPosition", Enums.AttributeStationing.InHeader);
	EndIf;
	
EndProcedure

#EndRegion

Procedure SupplementCatalogPredefinedItems(FillingData, DocumentObject)
	
	CatalogPredefinedItems = New Structure;
	
	SupplementPredefinedCompany(CatalogPredefinedItems, DocumentObject);
	SupplementPredefinedDepartment(CatalogPredefinedItems, DocumentObject);
	SupplementPredefinedBusinessUnits(CatalogPredefinedItems, DocumentObject);
	SupplementPredefinedPriceKind(CatalogPredefinedItems, DocumentObject);
	
	CommonClientServer.SupplementStructure(FillingData, CatalogPredefinedItems, False);
	
EndProcedure

#Region SupplementCatalogPredefinedItems

Procedure SupplementPredefinedCompany(CatalogPredefinedItems, DocumentObject)
	
	If NoUnfilledAttribute("Company", DocumentObject) Then
		Return;
	EndIf;
	
	CatalogPredefinedItems.Insert("Company", DriveServer.GetPredefinedCompany());
	
EndProcedure

Procedure SupplementPredefinedDepartment(CatalogPredefinedItems, DocumentObject)
	
	If TypeOf(DocumentObject) = Type("DocumentObject.ShiftClosure") Then
		Return;
	EndIf;
	
	If NoUnfilledAttribute("Department", DocumentObject) Then
		Return;
	EndIf;
	
	CatalogPredefinedItems.Insert(
	"Department",
	CommonClientServer.PredefinedItem(
	"Catalog.BusinessUnits.MainDepartment"));

EndProcedure

Procedure SupplementPredefinedBusinessUnits(CatalogPredefinedItems, DocumentObject)
	
	If TypeOf(DocumentObject) = Type("DocumentObject.ShiftClosure") Then
		Return;
	EndIf;
	
	If Not NoUnfilledAttribute("StructuralUnit", DocumentObject) Then
		FillingRulesForStructuralUnit = New Map;
		ObjectFillingDriveOverridable.OnDefiningRulesBusinessUnitsSettings(
		FillingRulesForStructuralUnit);
		
		PredefinedStructuralUnit = FillingRulesForStructuralUnit[TypeOf(DocumentObject)];
		
		If ValueIsFilled(PredefinedStructuralUnit) Then
			CatalogPredefinedItems.Insert(
			"StructuralUnit",
			PredefinedStructuralUnit);
		EndIf;
	EndIf;
	
	If Not NoUnfilledAttribute("BusinessUnitsales", DocumentObject) Then
		CatalogPredefinedItems.Insert(
		"BusinessUnitsales",
		CommonClientServer.PredefinedItem(
		"Catalog.BusinessUnits.MainDepartment"));
	EndIf;
	
	If Not NoUnfilledAttribute("StructuralUnitReserve", DocumentObject) Then
		CatalogPredefinedItems.Insert(
		"StructuralUnitReserve",
		CommonClientServer.PredefinedItem(
		"Catalog.BusinessUnits.MainWarehouse"));
	EndIf;

EndProcedure

Procedure SupplementPredefinedPriceKind(CatalogPredefinedItems, DocumentObject)
	
	If TypeOf(DocumentObject) = Type("DocumentObject.ShiftClosure") Then
		Return;
	EndIf;
	
	If TypeOf(DocumentObject) = Type("DocumentObject.SalesSlip") Then
		Return;
	EndIf;
	
	If TypeOf(DocumentObject) = Type("DocumentObject.ProductReturn") Then
		Return;
	EndIf;
	
	If NoUnfilledAttribute("PriceKind", DocumentObject) Then
		Return;
	EndIf;
	
	CatalogPredefinedItems.Insert(
	"PriceKind",
	CommonClientServer.PredefinedItem(
	"Catalog.PriceTypes.Wholesale"));
	
EndProcedure

#EndRegion

Procedure DeleteUnfilledValues(RenamedFields)
	
	For Each KeyAndValue In RenamedFields Do
		If ValueIsFilled(KeyAndValue.Value) Then
			Continue;
		EndIf;
		RenamedFields.Delete(KeyAndValue.Key);
	EndDo;

EndProcedure

#Region RenameEventFields
	
Procedure RenameEventFields(RenamedFields)
	
	If Not RenamedFields.Property("Event") Or Not GetFunctionalOption("UseDocumentEvent") Then
		Return;
	EndIf;
	
	RenameEventFieldsCounterparty(RenamedFields);
	RenameEventFieldsProject(RenamedFields);
	
EndProcedure

Procedure RenameEventFieldsCounterparty(RenamedFields)
	
	If RenamedFields.Property("Counterparty") Then
		Return;
	EndIf;
	
	Query = New Query(
	"SELECT ALLOWED TOP 1
	|	EventParticipants.Contact AS Counterparty
	|FROM
	|	Document.Event.Participants AS EventParticipants
	|WHERE
	|	EventParticipants.Contact REFS Catalog.Counterparties
	|	AND EventParticipants.Ref = &Ref");
	Query.SetParameter("Ref", RenamedFields.Event);
	
	QueryResult = Query.Execute();
	If Not QueryResult.IsEmpty() Then
		Selection = QueryResult.Select();
		Selection.Next();
		RenamedFields.Insert("Counterparty", Selection.Counterparty);
	EndIf;
	
EndProcedure

Procedure RenameEventFieldsProject(RenamedFields)
	
	If Not GetFunctionalOption("UseProjects") Then
		Return;
	EndIf;
	
	If RenamedFields.Property("Project") Then
		Return;
	EndIf;
	
	Project = Common.ObjectAttributeValue(RenamedFields.Event, "Project");
	If ValueIsFilled(Project) Then
		RenamedFields.Insert("Project", Project);
	EndIf;
	
EndProcedure

Procedure RenameFieldsCompany(RenamedFields, DocumentObject)
	
	If Not Common.HasObjectAttribute(
		"Company",
		DocumentObject.Metadata()) Then
		Return;
	EndIf;
	
	Company = DocumentObject.Company;
	
	If Not ValueIsFilled(Company) Then
		RenamedFields.Property("Company", Company);
	EndIf;
	
	If Not ValueIsFilled(Company) Then
		Return;
	EndIf;
	
	RenameFieldsCompanyBankAccount(RenamedFields, DocumentObject, Company);
	RenameFieldsCompanyPettyCash(RenamedFields, DocumentObject, Company);
	RenameFieldsCompanyResponsiblePersons(RenamedFields, DocumentObject, Company);
	RenameFieldsCompanyVATTaxation(RenamedFields, DocumentObject, Company);
	RenameFieldsCompanyAutomaticVATCalculation(RenamedFields, DocumentObject, Company);
	
EndProcedure

Procedure RenameFieldsCompanyBankAccount(RenamedFields, DocumentObject, Company)
	
	If NoUnfilledAttribute("BankAccount", DocumentObject) Then
		Return;
	EndIf;
	
	If Common.HasObjectAttribute("DocumentCurrency", DocumentObject.Metadata())
		AND ValueIsFilled(DocumentObject.DocumentCurrency) Then
		CashCurrency = DocumentObject.DocumentCurrency;
	ElsIf Common.HasObjectAttribute("CashCurrency", DocumentObject.Metadata())
		AND ValueIsFilled(DocumentObject.CashCurrency) Then
		CashCurrency = DocumentObject.CashCurrency;
	EndIf;
	
	If Not ValueIsFilled(CashCurrency) Then
		RenamedFields.Property("DocumentCurrency", CashCurrency);
	EndIf;
	
	If Not ValueIsFilled(CashCurrency) Then
		RenamedFields.Property("CashCurrency", CashCurrency);
	EndIf;
	
	If Not ValueIsFilled(CashCurrency) Then
		Return;
	EndIf;
	
	Query = New Query(
	"SELECT ALLOWED
	|	CASE
	|		WHEN Companies.BankAccountByDefault.CashCurrency = &CashCurrency
	|			THEN Companies.BankAccountByDefault
	|		ELSE UNDEFINED
	|	END AS BankAccount
	|FROM
	|	Catalog.Companies AS Companies
	|WHERE
	|	Companies.Ref = &Company");
	Query.SetParameter("Company", Company);
	Query.SetParameter("CashCurrency", CashCurrency);
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	Selection = QueryResult.Select();
	Selection.Next();
	
	If Not ValueIsFilled(Selection.BankAccount) Then
		Return;
	EndIf;
	
	RenamedFields.Insert("BankAccount", Selection.BankAccount);
	
	If NoUnfilledAttribute("BankAccountPayee", DocumentObject) Then
		Return;
	EndIf;
	
	RenamedFields.Insert("BankAccountPayee", Selection.BankAccount);
	
EndProcedure

Procedure RenameFieldsCompanyPettyCash(RenamedFields, DocumentObject, Company)
	
	If NoUnfilledAttribute("PettyCash", DocumentObject) Then
		Return;
	EndIf;
	
	PettyCashByDefault = Catalogs.CashAccounts.GetPettyCashByDefault(Company);
	
	If Not ValueIsFilled(PettyCashByDefault) Then
		Return;
	EndIf;
	
	RenamedFields.Insert("PettyCash", PettyCashByDefault);
	
	If NoUnfilledAttribute("PettyCashPayee", DocumentObject) Then
		Return;
	EndIf;
	
	RenamedFields.Insert("PettyCashPayee", PettyCashByDefault);
	
EndProcedure

Procedure RenameFieldsCompanyResponsiblePersons(RenamedFields, DocumentObject, Company)
	
	If StrFind(DocumentObject.Metadata().FullName(), "Catalog") > 0 Then
		ResponsiblePersons = DriveServer.OrganizationalUnitsResponsiblePersons(
								Company,
								CurrentSessionDate());
	Else
		ResponsiblePersons = DriveServer.OrganizationalUnitsResponsiblePersons(
								Company,
								DocumentObject.Date);
	EndIf;
	
	FieldsMap = New Map;
	FieldsMap["Head"]				= "Head";
	FieldsMap["HeadPosition"]		= "HeadPositionRefs";
	FieldsMap["ChiefAccountant"]	= "ChiefAccountant";
	FieldsMap["LetOut"]				= "WarehouseSupervisor";
	FieldsMap["LetOutPosition"]		= "WarehouseSupervisorPositionRef";
	
	For Each KeyAndValue In FieldsMap Do
		
		If NoUnfilledAttribute(KeyAndValue.Key, DocumentObject) Then
			Continue;
		EndIf;
		
		If Not ValueIsFilled(ResponsiblePersons[KeyAndValue.Value]) Then
			Continue;
		EndIf;
		
		RenamedFields.Insert(KeyAndValue.Key, ResponsiblePersons[KeyAndValue.Value]);
		
	EndDo;

EndProcedure

Procedure RenameFieldsCompanyVATTaxation(RenamedFields, DocumentObject, Company)
	
	If NoUnfilledAttribute("VATTaxation", DocumentObject) Then
		Return;
	EndIf;
	
	RenamedFields.Insert("VATTaxation", DriveServer.VATTaxation(Company, CurrentSessionDate()));
	
EndProcedure

Procedure RenameFieldsCompanyAutomaticVATCalculation(RenamedFields, DocumentObject, Company)
	
	If Not Common.HasObjectAttribute("AutomaticVATCalculation", DocumentObject.Metadata()) Then
		Return;
	EndIf;
	
	RenamedFields.Insert("AutomaticVATCalculation", DriveServer.AutomaticVATCalculation(Company, CurrentSessionDate()));
	
EndProcedure

Procedure RenameFieldsCounterparty(RenamedFields, DocumentObject)
	
	If NOT RenamedFields.Property("Counterparty") OR NOT RenamedFields.Property("Company") Then
		Return;
	EndIf;
	
	IsFolder = Common.ObjectAttributeValue(RenamedFields.Counterparty, "IsFolder");
	
	If IsFolder Then
		Raise NStr("en = 'You cannot select a counterparty group.'; ru = 'Нельзя выбирать группу контрагентов.';pl = 'Wybór grupy kontrahentów nie jest możliwy.';es_ES = 'Usted no puede seleccionar un grupo de contrapartes.';es_CO = 'Usted no puede seleccionar un grupo de contrapartes.';tr = 'Cari hesap grubu seçilemez.';it = 'Non è possibile selezionare una gruppo controparte.';de = 'Sie können keine Geschäftspartnergruppe auswählen.'");
	EndIf;
	
	If RenamedFields.Property("Contract") AND ValueIsFilled(RenamedFields.Contract) Then
		
		ContractDetails = Common.ObjectAttributesValues(RenamedFields.Contract, "Owner, Company");
		
		If RenamedFields.Counterparty = ContractDetails.Owner
			AND RenamedFields.Company = ContractDetails.Company Then
			Return;
		EndIf;
		
	EndIf;
	
	ContractByDefault = DriveServer.GetContractByDefault(DocumentObject.Ref,
		RenamedFields.Counterparty,
		RenamedFields.Company);
	
	RenamedFields.Insert("Contract", ContractByDefault);
	
EndProcedure

Procedure RenameFieldsCounterpartyVATTaxation(RenamedFields, DocumentObject)
	
	If Not RenamedFields.Property("Counterparty") Or Not ValueIsFilled(RenamedFields.Counterparty) Then
		Return;
	EndIf;
	
	If NoUnfilledAttribute("VATTaxation", DocumentObject) Then
		Return;
	EndIf;
	
	If Not RenamedFields.Property("VATTaxation") Then
		RenamedFields.Insert("VATTaxation", Enums.VATTaxationTypes.EmptyRef());
	EndIf;
	
	RenamedFields.VATTaxation = DriveServer.CounterpartyVATTaxation(RenamedFields.Counterparty, RenamedFields.VATTaxation);
	
EndProcedure

Procedure RenameFieldsContract(RenamedFields, DocumentObject)
	
	If Not RenamedFields.Property("Contract") Then
		Return;
	EndIf;
	
	ContractDetails = Common.ObjectAttributesValues(
	RenamedFields.Contract,
	"SettlementsCurrency, PriceKind, SupplierPriceTypes, DiscountMarkupKind");
	
	For Each KeyAndValue In ContractDetails Do
		
		If Not ValueIsFilled(KeyAndValue.Value) Then
			Continue;
		EndIf;
		
		For Each AttributeName In AttributeNames(KeyAndValue.Value, DocumentObject) Do
			RenamedFields.Insert(AttributeName, KeyAndValue.Value);
		EndDo;
		
	EndDo;
	
EndProcedure

Procedure RenameFieldsDiscountCard(RenamedFields)
	
	If Not RenamedFields.Property("DiscountCard") Then
		Return;
	EndIf;
	
	RenamedFields.Insert(
	"DiscountPercentByDiscountCard",
	DriveServer.CalculateDiscountPercentByDiscountCard(
	CurrentSessionDate(),
	RenamedFields.DiscountCard));
	
EndProcedure

Procedure RenameFieldsStructuralUnit(RenamedFields, DocumentObject)
	
	If Not Common.HasObjectAttribute("StructuralUnit", DocumentObject.Metadata()) Then
		Return;
	EndIf;
	
	StructuralUnit = DocumentObject.StructuralUnit;
	
	If Not ValueIsFilled(StructuralUnit) Then
		RenamedFields.Property("StructuralUnit", StructuralUnit);
	EndIf;
	
	If Not ValueIsFilled(StructuralUnit) Then
		Return;
	EndIf;
	
	StructuralUnitFieldsDescription = New Structure;
	StructuralUnitFieldsDescription.Insert("ProductsStructuralUnit", "TransferRecipient");
	StructuralUnitFieldsDescription.Insert("ProductsCell", "TransferRecipientCell");
	StructuralUnitFieldsDescription.Insert("InventoryStructuralUnit", "TransferSource");
	StructuralUnitFieldsDescription.Insert("CellInventory", "TransferSourceCell");
	StructuralUnitFieldsDescription.Insert("DisposalsStructuralUnit", "RecipientOfWastes");
	StructuralUnitFieldsDescription.Insert("DisposalsCell", "DisposalsRecipientCell");
	StructuralUnitFieldsDescription.Insert("StructuralUnitPayee", "TransferRecipient");
	StructuralUnitFieldsDescription.Insert("StructuralUnitReserve", "TransferSource");
	
	StructuralUnitData = Common.ObjectAttributesValues(
	StructuralUnit,
	StructuralUnitFieldsDescription, True);
	
	For Each KeyAndValue In StructuralUnitData Do
		
		If NoUnfilledAttribute(KeyAndValue.Key, DocumentObject) Then
			Continue;
		EndIf;
		
		If ValueIsFilled(KeyAndValue.Value) Then
			RenamedFields.Insert(KeyAndValue.Key, KeyAndValue.Value);
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure RenameFieldsPriceKind(RenamedFields)
	
	If Not RenamedFields.Property("PriceKind") Then
		Return;
	EndIf;
	
	RenamedFields.Insert(
	"AmountIncludesVAT",
	Common.ObjectAttributeValue(
	RenamedFields.PriceKind,
	"PriceIncludesVAT"));
	
EndProcedure

Procedure RenameFieldsCurrency(RenamedFields, Company)
	
	For Each KeyAndValue In RenamedFields Do
		
		If TypeOf(KeyAndValue.Value) <> Type("CatalogRef.Currencies") Then
			Continue;
		EndIf;
		
		ExchangeRates = CurrencyRateOperations.GetCurrencyRate(, KeyAndValue.Value, Company);
		ExchangeRates.Insert("ContractCurrencyExchangeRate", ExchangeRates.Rate);
		ExchangeRates.Insert("ContractCurrencyMultiplicity", ExchangeRates.Repetition);
		ExchangeRates.Insert("ExchangeRate", ExchangeRates.Rate);
		ExchangeRates.Insert("Multiplicity", ExchangeRates.Repetition);
		
		CommonClientServer.SupplementMap(RenamedFields, ExchangeRates, True);
		
		Break;
		
	EndDo;
	
EndProcedure

#EndRegion

Function StructuralUnitTypeToChoiceParameters(StructuralUnitType, ChoiceParameters)
	
	For Each ChoiceParameter In ChoiceParameters Do
		
		If ChoiceParameter.Name <> "Filter.StructuralUnitType" Then
			Continue;
		EndIf;
		
		If TypeOf(ChoiceParameter.Value) = Type("FixedArray") Then
			For Each ParameterValue In ChoiceParameter.Value Do
				If StructuralUnitType = ParameterValue Then
					Return True;
				EndIf; 
			EndDo;
		ElsIf TypeOf(ChoiceParameter.Value) = Type("EnumRef.BusinessUnitsTypes") 
			AND StructuralUnitType = ChoiceParameter.Value Then
			Return True;
		EndIf;
		
	EndDo;
	
	Return False;
	
EndFunction

Function NoUnfilledAttribute(AttributeName, DocumentObject)
	
	If Not Common.HasObjectAttribute(
		AttributeName,
		DocumentObject.Metadata()) Then
		Return True;
	EndIf;
	
	Return ValueIsFilled(DocumentObject[AttributeName]);
	
EndFunction

Function AttributeNames(Value, DocumentObject)
	
	Result = New Array;
	
	For Each Attribute In DocumentObject.Ref.Metadata().Attributes Do
		
		If Attribute.Type.ContainsType(TypeOf(Value)) Then
			Result.Add(Attribute.Name);
		EndIf;
		
	EndDo;
	
	Return Result;
	
EndFunction

Procedure FillTabularSections(DocumentObject, FillingData)
	
	For Each TabularSection In DocumentObject.Metadata().TabularSections Do
		
		If Not FillingData.Property(TabularSection.Name) Then
			Continue;
		EndIf;

		If DocumentObject[TabularSection.Name].Count()>0 Then
			Continue;
		EndIf;
		
		For Each FillingRow In FillingData[TabularSection.Name] Do
			NewTabularSectionRow = DocumentObject[TabularSection.Name].Add();
			FillPropertyValues(NewTabularSectionRow, FillingRow);
			WorkWithProductsServer.FillDataInTabularSectionRow(DocumentObject, TabularSection.Name, NewTabularSectionRow);
		EndDo;
				
	EndDo;

EndProcedure

#EndRegion