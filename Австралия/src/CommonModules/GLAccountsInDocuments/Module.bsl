
#Region Public

Function FillGLAccountsInArray(DocObject, StructureArray, GetGLAccounts) Export
	
	For Each Item In StructureArray Do
		
		If DocObject.Property(Item.TabName) Then 
			
			GLAccounts = Undefined;
			
			If GetGLAccounts And Item.Property("ProductGLAccounts") And Not Item.Property("StructuralUnitInTabularSection") Then
				ProductsArray = GetProductsArray(DocObject[Item.TabName], Item.ProductName);
				Item.Insert("Products", ProductsArray);
				GLAccounts = GetProductListGLAccounts(Item);
			EndIf;
			
			For Each Row In DocObject[Item.TabName] Do
				
				FillPropertyValues(Item, Row);
				FillGLAccountsInStructure(Item, GLAccounts, GetGLAccounts);
				FillPropertyValues(Row, Item);
				
			EndDo;
		
		Else
			
			If GetGLAccounts And Item.Property("ProductGLAccounts") Then
				GLAccounts = GetProductListGLAccounts(Item);
			EndIf;
		
			FillGLAccountsInStructure(Item, GLAccounts, GetGLAccounts);
			FillPropertyValues(DocObject, Item);
			
		EndIf;
		
	EndDo;
	
EndFunction

Procedure FillGLAccountsInDocument(Document, Val FillingData = Undefined) Export
	
	If Not GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		Return;
	EndIf;
	
	If Common.IsReference(TypeOf(Document)) Then
		DocumentObject = Document.GetObject();
	Else
		DocumentObject = Document;
	EndIf;
		
	ObjectMetadata = DocumentObject.Metadata();
	If Common.IsReference(TypeOf(FillingData)) Then
		
		FillingMetadata = FillingData.Metadata();
		
	ElsIf TypeOf(FillingData) = Type("Structure") Then
		
		For Each Item In FillingData Do
			If TypeOf(Item.Value) = Type("Array") Then
				Array = Item.Value;
				If Array.Count() > 0
					And	Common.IsReference(TypeOf(Array[0])) Then
					FillingData = Array;
					FillingMetadata = FillingData[0].Metadata();
				EndIf;
			ElsIf Item.Key = "Basis"
				And Common.IsReference(TypeOf(Item.Value)) Then
				FillingData = Item.Value;
				FillingMetadata = Item.Value.Metadata();
			EndIf;
		EndDo;
		
	EndIf;
	
	ObjectParameters = GetObjectParametersByMetadata(DocumentObject, ObjectMetadata);
	
	StructureData = IncomeAndExpenseItemsInDocuments.GetCounterpartyStructureData(ObjectParameters, "Header", DocumentObject);
	CompleteCounterpartyStructureData(StructureData, ObjectParameters, "Header");
	
	StructureData.Insert("FillingMetadata",		FillingMetadata);
	StructureData.Insert("ObjectMetadata",		ObjectMetadata);
	
	FillGLAccountsInHeader(DocumentObject, StructureData, FillingData);
	
	TabularSectionsMetadata = ObjectMetadata.TabularSections;
	For Each TabSectionMetadata In TabularSectionsMetadata Do
		FillGLAccountsInTabSection(DocumentObject, TabSectionMetadata.Name, StructureData, FillingData);
	EndDo;
	
EndProcedure

Procedure CompleteObjectParameters(Val FormObject, ObjectParameters) Export

	If FormObject.Property("GLAccount") Then
		ObjectParameters.Insert("GLAccount", FormObject.GLAccount);
	EndIf;
	
	If FormObject.Property("Correspondence") Then
		ObjectParameters.Insert("Correspondence", FormObject.Correspondence);
	EndIf;
	
	If FormObject.Property("AccountsReceivableGLAccount") Then
		ObjectParameters.Insert("AccountsReceivableGLAccount", FormObject.AccountsReceivableGLAccount);
	EndIf;
	
	If FormObject.Property("AdvancesReceivedGLAccount") Then
		ObjectParameters.Insert("AdvancesReceivedGLAccount", FormObject.AdvancesReceivedGLAccount);
	EndIf;
	
	If FormObject.Property("AccountsPayableGLAccount") Then
		ObjectParameters.Insert("AccountsPayableGLAccount", FormObject.AccountsPayableGLAccount);
	EndIf;
	
	If FormObject.Property("AdvancesPaidGLAccount") Then
		ObjectParameters.Insert("AdvancesPaidGLAccount", FormObject.AdvancesPaidGLAccount);
	EndIf;
	
	If FormObject.Property("ConsumptionGLAccount") Then
		ObjectParameters.Insert("ConsumptionGLAccount", FormObject.ConsumptionGLAccount);
	EndIf;
	
	If FormObject.Property("ThirdPartyPayerGLAccount") Then
		ObjectParameters.Insert("ThirdPartyPayerGLAccount", FormObject.ThirdPartyPayerGLAccount);
	EndIf;
	
	If FormObject.Property("InventoryGLAccount") Then
		ObjectParameters.Insert("InventoryGLAccount", FormObject.InventoryGLAccount);
	EndIf;
	
	If FormObject.Property("VATInputGLAccount") Then
		ObjectParameters.Insert("VATInputGLAccount", FormObject.VATInputGLAccount);
	EndIf;
	
EndProcedure

Function GetGLAccountsForFilling(StructureData) Export
	
	DocumentName = StructureData.ObjectParameters.DocumentName;
	GLAccountsForFilling = Documents[DocumentName].GetGLAccountsStructure(StructureData);
	
	If StructureData.Property("CounterpartyGLAccounts") Then 
		FillCounterpartyGLAccountsDescription(StructureData, GLAccountsForFilling);
	ElsIf StructureData.Property("ProductGLAccounts") Then 
		FillProductGLAccountsDescription(StructureData, GLAccountsForFilling);
	EndIf;
	
	Return GLAccountsForFilling;
	
EndFunction

Function GetGLAccountsForFillingByParameters(Parameters) Export

	DocObject = Parameters.DocObject;
	TabName = Parameters.TabName;
	SelectedValue = Parameters.SelectedValue;
	
	If DocObject.Property(TabName) Then
		RowData = DocObject[TabName].FindByID(SelectedValue);
	Else
		RowData = SelectedValue;
	EndIf;
	
	ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(DocObject);
	CompleteObjectParameters(DocObject, ObjectParameters);
	
	If Parameters.Property("CounterpartyGLAccounts") Then
		
		StructureData = IncomeAndExpenseItemsInDocuments.GetCounterpartyStructureData(ObjectParameters, TabName, RowData);
		CompleteCounterpartyStructureData(StructureData, ObjectParameters, TabName, RowData);
		
		GLAccountsForFilling = GetGLAccountsForFilling(StructureData);
		GLAccountsForFilling.Insert("TableName",	TabName);
		
	ElsIf Parameters.Property("ProductGLAccounts") Then 
		
		StructureData = IncomeAndExpenseItemsInDocuments.GetStructureData(ObjectParameters, TabName, RowData);
		CompleteStructureData(StructureData, ObjectParameters, TabName, RowData);
		
		GLAccountsForFilling = GetGLAccountsForFilling(StructureData);
		GLAccountsForFilling.Insert("TableName",	TabName);
		GLAccountsForFilling.Insert("Products",		RowData[Parameters.AttributeName]);
		
		SetRestrictInventoryGLAccount(StructureData, GLAccountsForFilling);
		
	EndIf;
		
	Return GLAccountsForFilling; 
	
EndFunction

Function GetHigherGroupList(CatalogItem) Export

	Result = New Array;
	
	If Not ValueIsFilled(CatalogItem) Then
		Return Result;
	EndIf;
	
	CatalogMetadata = CatalogItem.Metadata();
	If Not CatalogMetadata.Hierarchical Then
		Return Result;
	EndIf;
	
	CatalogName = CatalogMetadata.Name;
	Query = GetHigherItemGroupListQuery(CatalogName);
	
	CurrentItem = CatalogItem;
	
	While ValueIsFilled(CurrentItem) Do
		
		RefArray = New Array;
		RefArray.Add(CurrentItem);
		Query.SetParameter("RefArray", RefArray);
		Selection = Query.Execute().Select();
		
		If Selection.Next() Then
			
			For Index = 1 To 5 Do
				
				Parent = Selection["Parent" + Index];
				
				If Parent = CurrentItem Then
					MessageCyclicLinkInObject(CatalogMetadata, CatalogItem);
					CurrentItem = Undefined;
					Break;
				EndIf;
				
				CurrentItem = Parent;
				If ValueIsFilled(CurrentItem) Then
					Result.Add(CurrentItem);
				Else
					Break;
				EndIf;
			EndDo;
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

Function GetObjectParametersByMetadata(DocumentObject, ObjectMetadata) Export

	ObjectParameters = New Structure;
	ObjectParameters.Insert("DocumentName", ObjectMetadata.Name);
	
	If ObjectMetadata.Attributes.Find("Company") <> Undefined Then
		ObjectParameters.Insert("Company", DocumentObject.Company);
	EndIf;
	
	If ObjectMetadata.Attributes.Find("Counterparty") <> Undefined Then
		ObjectParameters.Insert("Counterparty", DocumentObject.Counterparty);
	EndIf;
	
	If ObjectMetadata.Attributes.Find("Contract") <> Undefined Then
		ObjectParameters.Insert("Contract", DocumentObject.Contract);
	EndIf;
	
	If ObjectMetadata.Attributes.Find("VATTaxation") <> Undefined Then
		ObjectParameters.Insert("VATTaxation", DocumentObject.VATTaxation);
	EndIf;	
	
	If ObjectMetadata.Attributes.Find("StructuralUnit") <> Undefined Then
		ObjectParameters.Insert("StructuralUnit", DocumentObject.StructuralUnit);
	ElsIf ObjectMetadata.Attributes.Find("StructuralUnitReserve") <> Undefined Then
		ObjectParameters.Insert("StructuralUnit", DocumentObject.StructuralUnitReserve);
	EndIf;
	
	If ObjectMetadata.Attributes.Find("StructuralUnitPayee") <> Undefined Then
		ObjectParameters.Insert("StructuralUnitPayee", DocumentObject.StructuralUnitPayee);
	EndIf;
	
	If ObjectMetadata.Attributes.Find("BasisDocument") <> Undefined Then
		ObjectParameters.Insert("BasisDocument", DocumentObject.BasisDocument);
	EndIf;
	
	If ObjectMetadata.Attributes.Find("GLAccount") <> Undefined Then
		ObjectParameters.Insert("GLAccount", DocumentObject.GLAccount);
	EndIf;
	
	If ObjectMetadata.Attributes.Find("AccountsReceivableGLAccount") <> Undefined Then
		ObjectParameters.Insert("AccountsReceivableGLAccount", DocumentObject.AccountsReceivableGLAccount);
	EndIf;
	
	If ObjectMetadata.Attributes.Find("AdvancesReceivedGLAccount") <> Undefined Then
		ObjectParameters.Insert("AdvancesReceivedGLAccount", DocumentObject.AdvancesReceivedGLAccount);
	EndIf;
	
	If ObjectMetadata.Attributes.Find("AccountsPayableGLAccount") <> Undefined Then
		ObjectParameters.Insert("AccountsPayableGLAccount", DocumentObject.AccountsPayableGLAccount);
	EndIf;
	
	If ObjectMetadata.Attributes.Find("AdvancesPaidGLAccount") <> Undefined Then
		ObjectParameters.Insert("AdvancesPaidGLAccount", DocumentObject.AdvancesPaidGLAccount);
	EndIf;
	
	If ObjectMetadata.Attributes.Find("ConsumptionGLAccount") <> Undefined Then
		ObjectParameters.Insert("ConsumptionGLAccount", DocumentObject.ConsumptionGLAccount);
	EndIf;
	
	If ObjectMetadata.Attributes.Find("InventoryGLAccount") <> Undefined Then
		ObjectParameters.Insert("InventoryGLAccount", DocumentObject.InventoryGLAccount);
	EndIf;
	
	If ObjectMetadata.Attributes.Find("ThirdPartyPayerGLAccount") <> Undefined Then
		ObjectParameters.Insert("ThirdPartyPayerGLAccount", DocumentObject.ThirdPartyPayerGLAccount);
	EndIf;
	
	If ObjectMetadata.Attributes.Find("Products") <> Undefined Then
		ObjectParameters.Insert("Products", DocumentObject.Products);
	EndIf;
	
	If ObjectMetadata.Attributes.Find("OperationKind") <> Undefined Then
		
		ObjectParameters.Insert("OperationKind", DocumentObject.OperationKind);
		
		If ObjectParameters.Property("DocumentName") Then
			
			AddObjectParametersAdvanceInvoicing(ObjectParameters);
			
		EndIf;
		
	EndIf;
	
	If ObjectMetadata.Attributes.Find("OperationType") <> Undefined Then
		ObjectParameters.Insert("OperationType", DocumentObject.OperationType);
	EndIf;
	
	If ObjectMetadata.Attributes.Find("AdvanceInvoicing") <> Undefined Then
		ObjectParameters.Insert("AdvanceInvoicing", DocumentObject.AdvanceInvoicing);
	EndIf;
	
	If ObjectMetadata.Attributes.Find("VATIsDue") <> Undefined Then
		ObjectParameters.Insert("VATIsDue", DocumentObject.VATIsDue);
	EndIf;
	
	If ObjectMetadata.Attributes.Find("VATInputGLAccount") <> Undefined Then
		ObjectParameters.Insert("VATInputGLAccount", DocumentObject.VATInputGLAccount);
	EndIf;
	
	If ObjectMetadata.Attributes.Find("ThirdPartyPayment") <> Undefined Then
		ObjectParameters.Insert("ThirdPartyPayment", DocumentObject.ThirdPartyPayment);
	EndIf;
	
	Return ObjectParameters;
	
EndFunction

Function GetDefaultIncomeAndExpenseType(TypeOfAccount) Export
	
	If TypeOfAccount = Enums.GLAccountsTypes.CostOfSales Then
		Return Catalogs.IncomeAndExpenseTypes.CostOfSales;
	ElsIf TypeOfAccount = Enums.GLAccountsTypes.Expenses Then
		Return Catalogs.IncomeAndExpenseTypes.AdministrativeExpenses;
	ElsIf TypeOfAccount = Enums.GLAccountsTypes.IndirectExpenses Then
		Return Catalogs.IncomeAndExpenseTypes.ManufacturingOverheads;
	ElsIf TypeOfAccount = Enums.GLAccountsTypes.OtherExpenses Then
		Return Catalogs.IncomeAndExpenseTypes.OtherExpenses;
	ElsIf TypeOfAccount = Enums.GLAccountsTypes.OtherIncome Then
		Return Catalogs.IncomeAndExpenseTypes.OtherIncome;
	ElsIf TypeOfAccount = Enums.GLAccountsTypes.Revenue Then
		Return Catalogs.IncomeAndExpenseTypes.Revenue;
	Else
		Return Catalogs.IncomeAndExpenseTypes.EmptyRef();
	EndIf;
	
EndFunction

#Region ProductGLAccounts

Procedure FillProductGLAccounts(StructureData, GLAccounts = Undefined) Export
	
	If Not StructureData.Property("ObjectParameters") Then
		
		If StructureData.Property("Object") Then
			
			ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(StructureData.Object);
			CompleteObjectParameters(StructureData.Object, ObjectParameters);
			
			StructureData.Insert("ObjectParameters", ObjectParameters);
			
		Else
			Return;
		EndIf;
		
	EndIf;
	
	DocumentName = StructureData.ObjectParameters.DocumentName;
	
	If Metadata.Documents.Find(DocumentName) <> Undefined Then
		
		If GLAccounts = Undefined Or GLAccounts.Get(StructureData.Products) = Undefined
			Or StructureData.Property("StructuralUnitInTabularSection")
				And StructureData.StructuralUnitInTabularSection Then
			GLAccounts = GetProductListGLAccounts(StructureData);
		EndIf;
		
		GLAccountsForFilling = Documents[DocumentName].GetGLAccountsStructure(StructureData);
		
		FillPropertyValues(GLAccountsForFilling, GLAccounts[StructureData.Products]);
		FillProductGLAccountsDescription(StructureData, GLAccountsForFilling);
		
		CheckItemRegistration(StructureData);
		
	EndIf;
	
EndProcedure

Procedure FillProductGLAccountsDescription(StructureData, GLAccountsForFilling = Undefined) Export

	If Not ValueIsFilled(StructureData.Products)
		And StructureData.Property("GLAccounts") Then
		StructureData.GLAccounts = GLAccountsInDocumentsClientServer.GetEmptyGLAccountPresentation();
		Return;	
	EndIf;
	
	If GLAccountsForFilling = Undefined Then
		DocumentName = StructureData.ObjectParameters.DocumentName;
		GLAccountsForFilling = Documents[DocumentName].GetGLAccountsStructure(StructureData);
	EndIf;
	
	GLAccountsDescription = GLAccountsInDocumentsServerCall.GetGLAccountsDescription(GLAccountsForFilling);
	FillPropertyValues(StructureData, GLAccountsDescription);
	
EndProcedure

Procedure CompleteStructureData(StructureData, ObjectParameters, TabName = "Inventory", RowData = Undefined, ProductName = "Products") Export
	
	EmptyGLAccount = ChartsOfAccounts.PrimaryChartOfAccounts.EmptyRef();
	EmptyGLAccounts = GetProductGLAccountEmptyStructure();
	
	If Metadata.Documents.Find(ObjectParameters.DocumentName) <> Undefined Then
		ObjectMetadata = Metadata.Documents[ObjectParameters.DocumentName];
	ElsIf Metadata.Catalogs.Find(ObjectParameters.DocumentName) <> Undefined Then
		ObjectMetadata = Metadata.Catalogs[ObjectParameters.DocumentName];
	EndIf;
		
	If ObjectMetadata = Undefined Then
		TabSectionMetadata = Undefined;
	Else
		TabSectionMetadata = ObjectMetadata.TabularSections.Find(TabName);
	EndIf;
	
	If TabSectionMetadata <> Undefined Then 
		
		AttributesMetadata = TabSectionMetadata.Attributes;
		StructureData.Insert("GLAccounts");
		StructureData.Insert("GLAccountsFilled");
		StructureData.Insert("IncomeAndExpenseItems");
		StructureData.Insert("IncomeAndExpenseItemsFilled");
		
		For Each GLAccount In EmptyGLAccounts Do
			If AttributesMetadata.Find(GLAccount.Key) <> Undefined Then
				StructureData.Insert(GLAccount.Key, EmptyGLAccount);
			EndIf;
		EndDo;
		
	Else
		StructureData.Insert("GLAccounts", "");
	EndIf;
	
	StructureData.Insert("ProductGLAccounts", True);
	
	If RowData <> Undefined Then 
		FillPropertyValues(StructureData, RowData);
		ProductsType = Common.ObjectAttributeValue(RowData[ProductName], "ProductsType");
		StructureData.Insert("ProductsTypeInventory", ProductsType = Enums.ProductsTypes.InventoryItem);
		
		If TabSectionMetadata <> Undefined And AttributesMetadata.Find("ReceiptDocument") <> Undefined Then
			StructureData.Insert("AdvanceInvoicing", DriveServerCall.AdvanceInvoicing(RowData.ReceiptDocument));
		EndIf;
	EndIf;

EndProcedure

Function GetProductListGLAccounts(StructureData) Export
	
	ObjectParameters = StructureData.ObjectParameters;	
	Products		= StructureData.Products;
	
	EmptyWarehouse = Catalogs.BusinessUnits.EmptyRef();
	
	If StructureData.Property("StructuralUnit") Then
		StructuralUnit = StructureData.StructuralUnit;
	Else
		StructuralUnit = EmptyWarehouse;
	EndIf;
	
	If Not ValueIsFilled(StructuralUnit)
		And ObjectParameters.Property("StructuralUnit") Then 
		StructuralUnit = ObjectParameters.StructuralUnit;
	EndIf;
	
	If ObjectParameters.Property("StructuralUnitPayee") Then
		StructuralUnitPayee = ObjectParameters.StructuralUnitPayee;
	Else
		StructuralUnitPayee = EmptyWarehouse;
	EndIf;
	
	Result	= New Map;
	
	If Common.RefTypeValue(Products) Then
		ProductList = New Array;
		ProductList.Add(Products);
	Else
		If Products.Count() = 0 Then
			Return Result;
		EndIf;
		
		ProductList = Products;
	EndIf;
	
	If Not AccessRight("Read", Metadata.InformationRegisters.ProductGLAccounts) Then
		Return Result;
	EndIf;
	
	EmptyProduct = Catalogs.Products.EmptyRef();
	EmptyGLAccount = ChartsOfAccounts.PrimaryChartOfAccounts.EmptyRef();
	
	For Each Products In ProductList Do
		If Products = Undefined Then
			Continue;
		EndIf;
		ReturnStructure = GetProductGLAccountEmptyStructure();
		
		Result.Insert(Products, ReturnStructure);
	EndDo;

	CompanyArray = New Array();
	CompanyArray.Add(Catalogs.Companies.EmptyRef());
	
	If ObjectParameters.Property("Company") Then
		CompanyArray.Add(ObjectParameters.Company);
	EndIf;
	
	WarehouseArray = New Array();
	WarehouseArray.Add(Catalogs.BusinessUnits.EmptyRef());
	
	If ValueIsFilled(StructuralUnit) Then
		WarehouseArray.Add(StructuralUnit);
	EndIf;
	
	If ValueIsFilled(StructuralUnitPayee) Then
		WarehouseArray.Add(StructuralUnitPayee);
	EndIf;
	
	Query = New Query();
	Query.Text = 
	"SELECT ALLOWED TOP 1
	|	ProductGLAccounts.Product AS Product
	|FROM
	|	InformationRegister.ProductGLAccounts AS ProductGLAccounts
	|WHERE
	|	ProductGLAccounts.Product.IsFolder";
	
	ThereIsProduct = NOT Query.Execute().IsEmpty();
	
	HierarchyTable = New ValueTable;
	HierarchyTable.Columns.Add("Item",		New TypeDescription("CatalogRef.Products"));
	HierarchyTable.Columns.Add("Parent",	New TypeDescription("CatalogRef.Products"));
	HierarchyTable.Columns.Add("Level",		Common.TypeDescriptionNumber(10, 0));
	
	If ThereIsProduct Then
				
		ItemAndGroupMap = GetHigherItemGroupList(ProductList);
		
		For Each Products In ProductList Do
			
			NewRow = HierarchyTable.Add();
			NewRow.Item		= Products;
			
			NewRow = HierarchyTable.Add();
			NewRow.Item		= Products;
			NewRow.Parent	= Products;
			
			GroupList = ItemAndGroupMap.Get(Products);
			If GroupList = Undefined Then
				NewRow.Level = 1;
				Continue;
			EndIf;
			
			HigherGroupCount = GroupList.Count();
			
			NewRow.Level = HigherGroupCount + 1;
			
			For Index = 1 To HigherGroupCount Do
				NewRow = HierarchyTable.Add();
				NewRow.Item	= Products;
				NewRow.Parent= GroupList[Index - 1];
				NewRow.Level	= HigherGroupCount - Index + 1;
			EndDo;						
		EndDo;
	Else
		
		For Each Products In ProductList Do
			ProductsCategory = Common.ObjectAttributesValues(Products, "ProductsCategory");
			
			NewRow = HierarchyTable.Add();
			NewRow.Item		= Products;
			
			NewRow = HierarchyTable.Add();
			NewRow.Item		= Products;
			NewRow.Parent	= Products;
			NewRow.Level = 1;
			
		EndDo;
		
	EndIf;
	
	NewRow = HierarchyTable.Add();
	
	ProductArray = Common.UnloadColumn(HierarchyTable, "Parent", True);
	
	Query = New Query();
	Query.Text =
	"SELECT
	|	HierarchyTable.Item AS Item,
	|	HierarchyTable.Parent AS Parent,
	|	HierarchyTable.Level AS Level
	|INTO HierarchyTable
	|FROM
	|	&HierarchyTable AS HierarchyTable
	|
	|INDEX BY
	|	Parent
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	HierarchyTable.Item AS Item,
	|	HierarchyTable.Parent AS Parent,
	|	HierarchyTable.Level AS Level,
	|	Products.ProductsCategory AS ProductsCategory
	|INTO HierarchyTableWithCategories
	|FROM
	|	HierarchyTable AS HierarchyTable
	|		LEFT JOIN Catalog.Products AS Products
	|		ON HierarchyTable.Item = Products.Ref
	|
	|INDEX BY
	|	Parent
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	HierarchyTable.Item AS Products,
	|	HierarchyTable.Parent AS Parent,
	|	HierarchyTable.Level AS Level,
	|	ProductGLAccounts.ProductCategory AS ProductsCategory,
	|	ProductGLAccounts.Company AS Company,
	|	ProductGLAccounts.StructuralUnit AS StructuralUnit,
	|	ProductGLAccounts.Inventory AS InventoryGLAccount,
	|	ProductGLAccounts.InventoryTransferred AS InventoryTransferredGLAccount,
	|	ProductGLAccounts.InventoryReceived AS InventoryReceivedGLAccount,
	|	ProductGLAccounts.GoodsShippedNotInvoiced AS GoodsShippedNotInvoicedGLAccount,
	|	ProductGLAccounts.GoodsReceivedNotInvoiced AS GoodsReceivedNotInvoicedGLAccount,
	|	ProductGLAccounts.GoodsInvoicedNotDelivered AS GoodsInvoicedNotDeliveredGLAccount,
	|	&GoodsInTransit AS GoodsInTransitGLAccount,
	|	ProductGLAccounts.SignedOutEquipment AS SignedOutEquipmentGLAccount,
	|	ProductGLAccounts.UnearnedRevenue AS UnearnedRevenueGLAccount,
	|	ProductGLAccounts.VATInput AS VATInputGLAccount,
	|	ProductGLAccounts.VATOutput AS VATOutputGLAccount,
	|	ProductGLAccounts.Revenue AS RevenueGLAccount,
	|	ProductGLAccounts.COGS AS COGSGLAccount,
	|	ProductGLAccounts.Consumption AS ConsumptionGLAccount,
	|	ProductGLAccounts.SalesReturn AS SalesReturnGLAccount,
	|	ProductGLAccounts.PurchaseReturn AS PurchaseReturnGLAccount,
	|	ProductGLAccounts.AbnormalScrap AS AbnormalScrapGLAccount,
	|	ProductGLAccounts.CostOfSales AS CostOfSalesGLAccount
	|FROM
	|	HierarchyTableWithCategories AS HierarchyTable
	|		LEFT JOIN InformationRegister.ProductGLAccounts AS ProductGLAccounts
	|		ON HierarchyTable.Parent = ProductGLAccounts.Product
	|			AND HierarchyTable.ProductsCategory = ProductGLAccounts.ProductCategory
	|WHERE
	|	ProductGLAccounts.Company IN(&CompanyArray)
	|	AND ProductGLAccounts.Product IN(&ProductArray)
	|	AND ProductGLAccounts.StructuralUnit IN(&WarehouseArray)
	|
	|UNION ALL
	|
	|SELECT
	|	HierarchyTable.Item,
	|	HierarchyTable.Parent,
	|	HierarchyTable.Level,
	|	ProductGLAccounts.ProductCategory,
	|	ProductGLAccounts.Company,
	|	ProductGLAccounts.StructuralUnit,
	|	ProductGLAccounts.Inventory,
	|	ProductGLAccounts.InventoryTransferred,
	|	ProductGLAccounts.InventoryReceived,
	|	ProductGLAccounts.GoodsShippedNotInvoiced,
	|	ProductGLAccounts.GoodsReceivedNotInvoiced,
	|	ProductGLAccounts.GoodsInvoicedNotDelivered,
	|	&GoodsInTransit,
	|	ProductGLAccounts.SignedOutEquipment,
	|	ProductGLAccounts.UnearnedRevenue,
	|	ProductGLAccounts.VATInput,
	|	ProductGLAccounts.VATOutput,
	|	ProductGLAccounts.Revenue,
	|	ProductGLAccounts.COGS,
	|	ProductGLAccounts.Consumption,
	|	ProductGLAccounts.SalesReturn,
	|	ProductGLAccounts.PurchaseReturn,
	|	ProductGLAccounts.AbnormalScrap,
	|	ProductGLAccounts.CostOfSales
	|FROM
	|	HierarchyTableWithCategories AS HierarchyTable
	|		LEFT JOIN InformationRegister.ProductGLAccounts AS ProductGLAccounts
	|		ON HierarchyTable.Parent = ProductGLAccounts.Product
	|WHERE
	|	ProductGLAccounts.Company IN(&CompanyArray)
	|	AND ProductGLAccounts.Product IN(&ProductArray)
	|	AND ProductGLAccounts.StructuralUnit IN(&WarehouseArray)
	|	AND ProductGLAccounts.ProductCategory = VALUE(Catalog.ProductsCategories.EmptyRef)
	|
	|ORDER BY
	|	Level DESC,
	|	ProductsCategory DESC,
	|	StructuralUnit DESC,
	|	Company DESC";
	
	Query.SetParameter("CompanyArray",		CompanyArray);
	Query.SetParameter("ProductList",		ProductList);
	Query.SetParameter("ProductArray",		ProductArray);
	Query.SetParameter("HierarchyTable",	HierarchyTable);
	Query.SetParameter("WarehouseArray",	WarehouseArray);
	Query.SetParameter("EmptyGLAccount",	ChartsOfAccounts.PrimaryChartOfAccounts.EmptyRef());
	Query.SetParameter("GoodsInTransit",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("GoodsInTransit"));
	
	GLAccountsTable = Query.Execute().Unload();
	GLAccountsTable.Indexes.Add("Products");
	
	GLAccountFilter = New Structure("Products");
	
	For Each Products In ProductList Do
		
		ReturnStructure = Result.Get(Products);
		
		GLAccountFilter = New Structure("Products");
		GLAccountFilter.Products = Products;
		
		FoundStrings = GLAccountsTable.FindRows(GLAccountFilter);
		
		If FoundStrings.Count() > 0 Then
			If ValueIsFilled(StructuralUnitPayee) Then
				
				For Each Item In FoundStrings Do
					If Item.StructuralUnit = StructuralUnit
						Or Not ValueIsFilled(Item.StructuralUnit) Then
						FillPropertyValues(ReturnStructure, Item);
						Break;
					EndIf;
				EndDo;
				
			Else
				FillPropertyValues(ReturnStructure, FoundStrings[0]);
			EndIf;
			
		Else
			GLAccountFilter.Products = EmptyProduct;
			
			FoundStrings = GLAccountsTable.FindRows(GLAccountFilter);
			If FoundStrings.Count() > 0 Then
				FillPropertyValues(ReturnStructure, FoundStrings[0]);
			EndIf;
			
		EndIf;
		
		If ValueIsFilled(StructuralUnitPayee) Then
			GLAccountFilter.Insert("StructuralUnit", StructuralUnitPayee);
			FoundStrings = GLAccountsTable.FindRows(GLAccountFilter);
			
			ReceiptFromAThirdParty = Enums.OperationTypesGoodsReceipt.ReceiptFromAThirdParty;
			If TypeOf(ObjectParameters.BasisDocument) = Type("DocumentRef.GoodsReceipt")
				And Common.ObjectAttributeValue(ObjectParameters.BasisDocument, "OperationType") = ReceiptFromAThirdParty Then
				InventoryGLAccountName = "InventoryReceivedGLAccount";
			Else
				InventoryGLAccountName = "InventoryGLAccount";
			EndIf;
			
			
			If FoundStrings.Count() > 0 Then
				ReturnStructure.Insert("InventoryToGLAccount", FoundStrings[0][InventoryGLAccountName]);
				ReturnStructure.Insert("ConsumptionGLAccount", FoundStrings[0].ConsumptionGLAccount);
				ReturnStructure.Insert("SignedOutEquipmentGLAccount", FoundStrings[0].SignedOutEquipmentGLAccount);
			Else
				GLAccountFilter.StructuralUnit = EmptyWarehouse;
				
				FoundStrings = GLAccountsTable.FindRows(GLAccountFilter);
				If FoundStrings.Count() > 0 Then
					ReturnStructure.Insert("InventoryToGLAccount", FoundStrings[0][InventoryGLAccountName]);
					ReturnStructure.Insert("ConsumptionGLAccount", FoundStrings[0].ConsumptionGLAccount);
					ReturnStructure.Insert("SignedOutEquipmentGLAccount", FoundStrings[0].SignedOutEquipmentGLAccount);
				Else
					
					GLAccountFilter.Products = EmptyProduct;
					
					FoundStrings = GLAccountsTable.FindRows(GLAccountFilter);
					If FoundStrings.Count() > 0 Then
						FillPropertyValues(ReturnStructure, FoundStrings[0]);
					EndIf;
				EndIf;
			EndIf;
		EndIf;
		
	EndDo;
	
	Return Result;

EndFunction

Function GetProductsArray(TabSection, ProductName = "Products") Export
	
	TableProducts = TabSection.Unload(, ProductName);
	ProductsArray = TableProducts.UnloadColumn(ProductName);
	
	Return ProductsArray;
	
EndFunction

Function FillGLAccountsInBarcodeData(StructureData, DocumentObject, DocumentName, TabName = "Inventory", ProductName = "Products") Export
	
	EmptyGLAccount = ChartsOfAccounts.PrimaryChartOfAccounts.EmptyRef();
	EmptyGLAccounts = GetProductGLAccountEmptyStructure();
	
	DocumentMetadata = Metadata.Documents[DocumentName];
	TabSectionMetadata = DocumentMetadata.TabularSections.Find(TabName);
	
	If TabSectionMetadata <> Undefined Then 
		
		AttributesMetadata = TabSectionMetadata.Attributes;
		StructureData.Insert("GLAccounts", "");
		StructureData.Insert("GLAccountsFilled", False);
		
		For Each GLAccount In EmptyGLAccounts Do
			If AttributesMetadata.Find(GLAccount.Key) <> Undefined Then
				StructureData.Insert(GLAccount.Key, EmptyGLAccount);
			EndIf;
		EndDo;
		
	EndIf;
	
	StructureData.Insert("ProductGLAccounts", True);
	
	Return StructureData;

EndFunction

Procedure FillGLAccountsInRow(ObjectParameters, RowData, TabName = "Inventory") Export
	
	StructureData = IncomeAndExpenseItemsInDocuments.GetStructureData(ObjectParameters, TabName, RowData);
	CompleteStructureData(StructureData, ObjectParameters, TabName, RowData);
	
	FillProductGLAccounts(StructureData);
	FillPropertyValues(RowData, StructureData);
	
EndProcedure

#EndRegion

#Region CounterpartyGLAccounts

Procedure FillCounterpartyGLAccounts(StructureData, GLAccounts = Undefined, FillingData = Undefined) Export

	If Not StructureData.Property("ObjectParameters")
		And StructureData.Property("Object") Then
		
		ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(StructureData.Object);
		CompleteObjectParameters(StructureData.Object, ObjectParameters);
		
		StructureData.Insert("ObjectParameters", ObjectParameters);
		
	EndIf;
	
	If GLAccounts = Undefined Then
		GLAccounts = GetCounterpartyGLAccounts(StructureData);
	EndIf;
	
	DocumentName = StructureData.ObjectParameters.DocumentName;
	GLAccountsForFilling = Documents[DocumentName].GetGLAccountsStructure(StructureData);
	
	FillOtherGLAccounts(StructureData, GLAccountsForFilling);
	
	FillPropertyValues(GLAccountsForFilling, GLAccounts);
	
	If ValueIsFilled(FillingData) Then
		FillPropertyValues(GLAccountsForFilling, FillingData);
	EndIf;
	
	FillCounterpartyGLAccountsDescription(StructureData, GLAccountsForFilling);
	IncomeAndExpenseItemsInDocuments.FillIncomeAndExpenseItemsDescription(StructureData);
	
EndProcedure

Procedure FillCounterpartyGLAccountsDescription(StructureData, GLAccountsForFilling = Undefined) Export

	If GLAccountsForFilling = Undefined Then
		DocumentName = StructureData.ObjectParameters.DocumentName;
		GLAccountsForFilling = Documents[DocumentName].GetGLAccountsStructure(StructureData);
	EndIf;
	
	GLAccountsDescription = GLAccountsInDocumentsServerCall.GetGLAccountsDescription(GLAccountsForFilling);
	FillPropertyValues(StructureData, GLAccountsDescription);
	
EndProcedure

Procedure CompleteCounterpartyStructureData(StructureData, ObjectParameters, TabName = "PaymentDetails", RowData = Undefined) Export
	
	EmptyGLAccount = ChartsOfAccounts.PrimaryChartOfAccounts.EmptyRef();
	EmptyGLAccounts = GetCounterpartyGLAccountEmptyStructure();
	
	AddOthersEmptyGLAccounts(EmptyGLAccounts);
	
	DocumentMetadata = Metadata.Documents[ObjectParameters.DocumentName];
	TabSectionMetadata = DocumentMetadata.TabularSections.Find(TabName);
	
	If TabSectionMetadata <> Undefined Then 
		
		AttributesMetadata = TabSectionMetadata.Attributes;
		
		StructureData.Insert("GLAccounts");
		StructureData.Insert("GLAccountsFilled");
		StructureData.Insert("IncomeAndExpenseItems");
		StructureData.Insert("IncomeAndExpenseItemsFilled");
		
	Else
		
		AttributesMetadata = DocumentMetadata.Attributes;
		
		StructureData.Insert("GLAccounts", "");
		StructureData.Insert("IncomeAndExpenseItems", "");
		
	EndIf;
	
	For Each GLAccount In EmptyGLAccounts Do
		If AttributesMetadata.Find(GLAccount.Key) <> Undefined Then
			StructureData.Insert(GLAccount.Key, EmptyGLAccount);
		EndIf;
	EndDo;
	
	StructureData.Insert("CounterpartyGLAccounts", True);
	
	If RowData <> Undefined Then 
		FillPropertyValues(StructureData, RowData);
	EndIf;
	
EndProcedure

Procedure FillCounterpartyGLAccountsInRow(ObjectParameters, TS_Row, TabName = "PaymentDetails", FillingData = Undefined) Export
	
	StructureData = IncomeAndExpenseItemsInDocuments.GetCounterpartyStructureData(ObjectParameters, TabName, TS_Row);
	CompleteCounterpartyStructureData(StructureData, ObjectParameters, TabName);
	
	FillCounterpartyGLAccounts(StructureData, , FillingData);
	FillPropertyValues(TS_Row, StructureData);
	
EndProcedure

Function GetCounterpartyGLAccounts(StructureData) Export

	If StructureData.Property("ObjectParameters") Then
		ObjectParameters = StructureData.ObjectParameters;
	Else
		ObjectParameters = New Structure;
	EndIf;
	
	Counterparty = Undefined;
	
	If StructureData.Property("Company") Then
		Company = StructureData.Company;
	ElsIf ObjectParameters.Property("Company") Then 
		Company = ObjectParameters.Company;
	EndIf;
	
	If StructureData.Property("Contract")
		And ValueIsFilled(StructureData.Contract) Then
		Contract = StructureData.Contract;
		Counterparty = Contract.Owner;
	ElsIf ObjectParameters.Property("Contract") 
		And ValueIsFilled(ObjectParameters.Contract) Then
		Contract = ObjectParameters.Contract;
		Counterparty = Contract.Owner;
	Else
		Contract = Catalogs.CounterpartyContracts.EmptyRef();
	EndIf;
	
	If Not ValueIsFilled(Counterparty) Then
		If StructureData.Property("Counterparty") Then
			Counterparty = StructureData.Counterparty;
		ElsIf ObjectParameters.Property("Counterparty") Then
			Counterparty = ObjectParameters.Counterparty;
		EndIf;
	EndIf;
	
	If StructureData.Property("VATTaxation") Then
		TaxCategory = StructureData.VATTaxation;
	ElsIf ObjectParameters.Property("VATTaxation") Then 
		TaxCategory = ObjectParameters.VATTaxation;
	EndIf;
	
	Result = New Structure("AccountsReceivableGLAccount, 
	                            |AdvancesReceivedGLAccount, 
	                            |AccountsPayableGLAccount, 
	                            |AdvancesPaidGLAccount,
	                            |DiscountAllowedGLAccount,
	                            |DiscountReceivedGLAccount,
								|ThirdPartyPayerGLAccount");

	CounterpartyGroupList = GetHigherGroupList(Counterparty);
	
	ContractArray = New Array;
	ContractArray.Add(Contract);
	ContractGroupList = GetHigherItemGroupList(ContractArray)[Contract];
	
	Query = New Query();
	Query.SetParameter("Company",			Company);
	Query.SetParameter("Counterparty",		Counterparty);
	Query.SetParameter("Contract",			Contract);
	Query.SetParameter("TaxCategory",		TaxCategory);
	Query.SetParameter("EmptyCompany",		Catalogs.Companies.EmptyRef());
	Query.SetParameter("EmptyCounterparty",	Catalogs.Counterparties.EmptyRef());
	Query.SetParameter("EmptyContract",		Catalogs.CounterpartyContracts.EmptyRef());
	Query.SetParameter("EmptyTaxCategory",	Enums.VATTaxationTypes.EmptyRef());
	
	FillParameters(Query, "Counterparty", CounterpartyGroupList);
	FillParameters(Query, "Contract", ContractGroupList);
	
	QueryText = "";
	
	Priority = 1;
	Fields = FieldsWithDefaultValues();
	Fields.Company.Condition = "Selected";
	Fields.TaxCategory.Condition = "Selected";
	Fields.Counterparty.Condition = "Selected";
	Fields.Contract.Condition = "Selected";
	AddQueryText(QueryText, Priority, Fields);
	
	Priority = 2;
	Fields = FieldsWithDefaultValues();
	Fields.Company.Condition = "Selected";
	Fields.TaxCategory.Condition = "Selected";
	Fields.Counterparty.Condition = "Selected";
	Fields.Contract.Condition = "InGroup";
	Fields.Contract.MaxCount = ContractGroupList.Count();
	AddQueryText(QueryText, Priority, Fields);
	
	Priority = 3;
	Fields = FieldsWithDefaultValues();
	Fields.Company.Condition = "Selected";
	Fields.TaxCategory.Condition = "Empty";
	Fields.Counterparty.Condition = "Selected";
	Fields.Contract.Condition = "Selected";
	AddQueryText(QueryText, Priority, Fields);
	
	Priority = 4;
	Fields = FieldsWithDefaultValues();
	Fields.Company.Condition = "Selected";
	Fields.TaxCategory.Condition = "Empty";
	Fields.Counterparty.Condition = "Selected";
	Fields.Contract.Condition = "InGroup";
	Fields.Contract.MaxCount = ContractGroupList.Count();
	AddQueryText(QueryText, Priority, Fields);
	
	Priority = 5;
	Fields = FieldsWithDefaultValues();
	Fields.Company.Condition = "Selected";
	Fields.TaxCategory.Condition = "Selected";
	Fields.Counterparty.Condition = "Selected";
	Fields.Contract.Condition = "Empty";
	AddQueryText(QueryText, Priority, Fields);
	
	Priority = 6;
	Fields = FieldsWithDefaultValues();
	Fields.Company.Condition = "Selected";
	Fields.TaxCategory.Condition = "Selected";
	Fields.Counterparty.Condition = "InGroup";
	Fields.Counterparty.MaxCount = CounterpartyGroupList.Count();
	Fields.Contract.Condition = "Empty";
	AddQueryText(QueryText, Priority, Fields);
	
	Priority = 7;
	Fields = FieldsWithDefaultValues();
	Fields.Company.Condition = "Empty";
	Fields.TaxCategory.Condition = "Selected";
	Fields.Counterparty.Condition = "Selected";
	Fields.Contract.Condition = "Empty";
	AddQueryText(QueryText, Priority, Fields);
	
	Priority = 8;
	Fields = FieldsWithDefaultValues();
	Fields.Company.Condition = "Empty";
	Fields.TaxCategory.Condition = "Selected";
	Fields.Counterparty.Condition = "InGroup";
	Fields.Counterparty.MaxCount = CounterpartyGroupList.Count();
	Fields.Contract.Condition = "Empty";
	AddQueryText(QueryText, Priority, Fields);
	
	Priority = 9;
	Fields = FieldsWithDefaultValues();
	Fields.Company.Condition = "Selected";
	Fields.TaxCategory.Condition = "Empty";
	Fields.Counterparty.Condition = "Selected";
	Fields.Contract.Condition = "Empty";
	AddQueryText(QueryText, Priority, Fields);
	
	Priority = 10;
	Fields = FieldsWithDefaultValues();
	Fields.Company.Condition = "Selected";
	Fields.TaxCategory.Condition = "Empty";
	Fields.Counterparty.Condition = "InGroup";
	Fields.Counterparty.MaxCount = CounterpartyGroupList.Count();
	Fields.Contract.Condition = "Empty";
	AddQueryText(QueryText, Priority, Fields);
	
	Priority = 11;
	Fields = FieldsWithDefaultValues();
	Fields.Company.Condition = "Empty";
	Fields.TaxCategory.Condition = "Empty";
	Fields.Counterparty.Condition = "Selected";
	Fields.Contract.Condition = "Empty";
	AddQueryText(QueryText, Priority, Fields);
	
	Priority = 12;
	Fields = FieldsWithDefaultValues();
	Fields.Company.Condition = "Empty";
	Fields.TaxCategory.Condition = "Empty";
	Fields.Counterparty.Condition = "InGroup";
	Fields.Counterparty.MaxCount = CounterpartyGroupList.Count();
	Fields.Contract.Condition = "Empty";
	AddQueryText(QueryText, Priority, Fields);
	
	Priority = 13;
	Fields = FieldsWithDefaultValues();
	Fields.Company.Condition = "Selected";
	Fields.TaxCategory.Condition = "Selected";
	Fields.Counterparty.Condition = "Empty";
	Fields.Contract.Condition = "Empty";
	AddQueryText(QueryText, Priority, Fields);
	
	Priority = 14;
	Fields = FieldsWithDefaultValues();
	Fields.Company.Condition = "Empty";
	Fields.TaxCategory.Condition = "Selected";
	Fields.Counterparty.Condition = "Empty";
	Fields.Contract.Condition = "Empty";
	AddQueryText(QueryText, Priority, Fields);
	
	Priority = 15;
	Fields = FieldsWithDefaultValues();
	Fields.Company.Condition = "Selected";
	Fields.TaxCategory.Condition = "Empty";
	Fields.Counterparty.Condition = "Empty";
	Fields.Contract.Condition = "Empty";
	AddQueryText(QueryText, Priority, Fields);
	
	Priority = 16;
	Fields = FieldsWithDefaultValues();
	Fields.Company.Condition = "Empty";
	Fields.TaxCategory.Condition = "Empty";
	Fields.Counterparty.Condition = "Empty";
	Fields.Contract.Condition = "Empty";
	AddQueryText(QueryText, Priority, Fields);
	
	Query.Text = QueryText + "
	|ORDER BY
	|	Priority
	|";
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Result.Insert("AccountsReceivableGLAccount",Selection.AccountsReceivable);
		Result.Insert("AdvancesReceivedGLAccount",	Selection.AdvancesReceived);
		Result.Insert("AccountsPayableGLAccount",	Selection.AccountsPayable);
		Result.Insert("AdvancesPaidGLAccount",		Selection.AdvancesPaid);
		Result.Insert("DiscountAllowedGLAccount",	Selection.DiscountAllowed);
		Result.Insert("DiscountReceivedGLAccount",	Selection.DiscountReceived);
		Result.Insert("ThirdPartyPayerGLAccount",	Selection.ThirdPartyPayer);
	EndIf;
	
	If Not ValueIsFilled(Counterparty) Then
		If StructureData.Property("Counterparty") Then
			Counterparty = StructureData.Counterparty;
		ElsIf ObjectParameters.Property("Counterparty") Then
			Counterparty = ObjectParameters.Counterparty;
		EndIf;
	EndIf;
	
	If StructureData.Property("VATTaxation") Then
		TaxCategory = StructureData.VATTaxation;
	ElsIf ObjectParameters.Property("VATTaxation") Then 
		TaxCategory = ObjectParameters.VATTaxation;
	EndIf;
	
	Result = New Structure("AccountsReceivableGLAccount, 
		|AdvancesReceivedGLAccount, 
		|AccountsPayableGLAccount, 
		|AdvancesPaidGLAccount,
		|DiscountAllowedGLAccount,
		|DiscountReceivedGLAccount,
		|ThirdPartyPayerGLAccount");
	
	CounterpartyGroupList = GetHigherGroupList(Counterparty);
	
	ContractArray = New Array;
	ContractArray.Add(Contract);
	ContractGroupList = GetHigherItemGroupList(ContractArray)[Contract];
	
	Query = New Query();
	Query.SetParameter("Company",			Company);
	Query.SetParameter("Counterparty",		Counterparty);
	Query.SetParameter("Contract",			Contract);
	Query.SetParameter("TaxCategory",		TaxCategory);
	Query.SetParameter("EmptyCompany",		Catalogs.Companies.EmptyRef());
	Query.SetParameter("EmptyCounterparty",	Catalogs.Counterparties.EmptyRef());
	Query.SetParameter("EmptyContract",		Catalogs.CounterpartyContracts.EmptyRef());
	Query.SetParameter("EmptyTaxCategory",	Enums.VATTaxationTypes.EmptyRef());
	
	FillParameters(Query, "Counterparty", CounterpartyGroupList);
	FillParameters(Query, "Contract", ContractGroupList);
	
	QueryText = "";
	
	Priority = 1;
	Fields = FieldsWithDefaultValues();
	Fields.Company.Condition = "Selected";
	Fields.TaxCategory.Condition = "Selected";
	Fields.Counterparty.Condition = "Selected";
	Fields.Contract.Condition = "Selected";
	AddQueryText(QueryText, Priority, Fields);
	
	Priority = 2;
	Fields = FieldsWithDefaultValues();
	Fields.Company.Condition = "Selected";
	Fields.TaxCategory.Condition = "Selected";
	Fields.Counterparty.Condition = "Selected";
	Fields.Contract.Condition = "InGroup";
	Fields.Contract.MaxCount = ContractGroupList.Count();
	AddQueryText(QueryText, Priority, Fields);
	
	Priority = 3;
	Fields = FieldsWithDefaultValues();
	Fields.Company.Condition = "Selected";
	Fields.TaxCategory.Condition = "Empty";
	Fields.Counterparty.Condition = "Selected";
	Fields.Contract.Condition = "Selected";
	AddQueryText(QueryText, Priority, Fields);
	
	Priority = 4;
	Fields = FieldsWithDefaultValues();
	Fields.Company.Condition = "Selected";
	Fields.TaxCategory.Condition = "Empty";
	Fields.Counterparty.Condition = "Selected";
	Fields.Contract.Condition = "InGroup";
	Fields.Contract.MaxCount = ContractGroupList.Count();
	AddQueryText(QueryText, Priority, Fields);
	
	Priority = 5;
	Fields = FieldsWithDefaultValues();
	Fields.Company.Condition = "Selected";
	Fields.TaxCategory.Condition = "Selected";
	Fields.Counterparty.Condition = "Selected";
	Fields.Contract.Condition = "Empty";
	AddQueryText(QueryText, Priority, Fields);
	
	Priority = 6;
	Fields = FieldsWithDefaultValues();
	Fields.Company.Condition = "Selected";
	Fields.TaxCategory.Condition = "Selected";
	Fields.Counterparty.Condition = "InGroup";
	Fields.Counterparty.MaxCount = CounterpartyGroupList.Count();
	Fields.Contract.Condition = "Empty";
	AddQueryText(QueryText, Priority, Fields);
	
	Priority = 7;
	Fields = FieldsWithDefaultValues();
	Fields.Company.Condition = "Empty";
	Fields.TaxCategory.Condition = "Selected";
	Fields.Counterparty.Condition = "Selected";
	Fields.Contract.Condition = "Empty";
	AddQueryText(QueryText, Priority, Fields);
	
	Priority = 8;
	Fields = FieldsWithDefaultValues();
	Fields.Company.Condition = "Empty";
	Fields.TaxCategory.Condition = "Selected";
	Fields.Counterparty.Condition = "InGroup";
	Fields.Counterparty.MaxCount = CounterpartyGroupList.Count();
	Fields.Contract.Condition = "Empty";
	AddQueryText(QueryText, Priority, Fields);
	
	Priority = 9;
	Fields = FieldsWithDefaultValues();
	Fields.Company.Condition = "Selected";
	Fields.TaxCategory.Condition = "Empty";
	Fields.Counterparty.Condition = "Selected";
	Fields.Contract.Condition = "Empty";
	AddQueryText(QueryText, Priority, Fields);
	
	Priority = 10;
	Fields = FieldsWithDefaultValues();
	Fields.Company.Condition = "Selected";
	Fields.TaxCategory.Condition = "Empty";
	Fields.Counterparty.Condition = "InGroup";
	Fields.Counterparty.MaxCount = CounterpartyGroupList.Count();
	Fields.Contract.Condition = "Empty";
	AddQueryText(QueryText, Priority, Fields);
	
	Priority = 11;
	Fields = FieldsWithDefaultValues();
	Fields.Company.Condition = "Empty";
	Fields.TaxCategory.Condition = "Empty";
	Fields.Counterparty.Condition = "Selected";
	Fields.Contract.Condition = "Empty";
	AddQueryText(QueryText, Priority, Fields);
	
	Priority = 12;
	Fields = FieldsWithDefaultValues();
	Fields.Company.Condition = "Empty";
	Fields.TaxCategory.Condition = "Empty";
	Fields.Counterparty.Condition = "InGroup";
	Fields.Counterparty.MaxCount = CounterpartyGroupList.Count();
	Fields.Contract.Condition = "Empty";
	AddQueryText(QueryText, Priority, Fields);
	
	Priority = 13;
	Fields = FieldsWithDefaultValues();
	Fields.Company.Condition = "Selected";
	Fields.TaxCategory.Condition = "Selected";
	Fields.Counterparty.Condition = "Empty";
	Fields.Contract.Condition = "Empty";
	AddQueryText(QueryText, Priority, Fields);
	
	Priority = 14;
	Fields = FieldsWithDefaultValues();
	Fields.Company.Condition = "Empty";
	Fields.TaxCategory.Condition = "Selected";
	Fields.Counterparty.Condition = "Empty";
	Fields.Contract.Condition = "Empty";
	AddQueryText(QueryText, Priority, Fields);
	
	Priority = 15;
	Fields = FieldsWithDefaultValues();
	Fields.Company.Condition = "Selected";
	Fields.TaxCategory.Condition = "Empty";
	Fields.Counterparty.Condition = "Empty";
	Fields.Contract.Condition = "Empty";
	AddQueryText(QueryText, Priority, Fields);
	
	Priority = 16;
	Fields = FieldsWithDefaultValues();
	Fields.Company.Condition = "Empty";
	Fields.TaxCategory.Condition = "Empty";
	Fields.Counterparty.Condition = "Empty";
	Fields.Contract.Condition = "Empty";
	AddQueryText(QueryText, Priority, Fields);
	
	Query.Text = QueryText + "
	|ORDER BY
	|	Priority
	|";
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Result.Insert("AccountsReceivableGLAccount",Selection.AccountsReceivable);
		Result.Insert("AdvancesReceivedGLAccount",	Selection.AdvancesReceived);
		Result.Insert("AccountsPayableGLAccount",	Selection.AccountsPayable);
		Result.Insert("AdvancesPaidGLAccount",		Selection.AdvancesPaid);
		Result.Insert("DiscountAllowedGLAccount",	Selection.DiscountAllowed);
		Result.Insert("DiscountReceivedGLAccount",	Selection.DiscountReceived);
		Result.Insert("ThirdPartyPayerGLAccount",	Selection.ThirdPartyPayer);
	EndIf;
	
	Return Result;

EndFunction

#EndRegion

#Region OtherGLAccounts

Procedure FillOtherGLAccounts(StructureData, GLAccountsForFilling) Export

	DocumentName = StructureData.ObjectParameters.DocumentName;
	
	If GLAccountsForFilling.Property("VATInputGLAccount")
		And (Documents[DocumentName] = Documents.PaymentExpense 
		Or Documents[DocumentName] = Documents.CashVoucher
		Or Documents[DocumentName] = Documents.DebitNote) Then
		
		FillVATInputGLAccount(StructureData, GLAccountsForFilling);
		
	EndIf;
	
	If GLAccountsForFilling.Property("VATOutputGLAccount")
		And (Documents[DocumentName] = Documents.PaymentReceipt
		Or Documents[DocumentName] = Documents.CashReceipt
		Or Documents[DocumentName] = Documents.CreditNote) Then
		
		FillVATOutputGLAccount(StructureData, GLAccountsForFilling);
		
	EndIf;

EndProcedure

#EndRegion

#Region IncomeAndExpenseRegistration

Procedure CheckItemRegistration(StructureData, TabName = "Header") Export
	
	If (StructureData.Property("UseDefaultTypeOfAccounting") And Not StructureData.UseDefaultTypeOfAccounting)
		Or Not GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		Return;
	EndIf;
	
	If Not StructureData.Property("ObjectParameters")
		And StructureData.Property("Object") Then
		
		StructureData.Insert("ObjectParameters", IncomeAndExpenseItemsInDocuments.GetObjectParameters(StructureData.Object));
	EndIf;
	
	DocumentName = StructureData.ObjectParameters.DocumentName;
	If Metadata.Documents.Find(DocumentName) <> Undefined Then
		
		If Not StructureData.Property("TabName") Then
			StructureData.Insert("TabName", TabName);
		EndIf;
		
		ItemsGLAMap = Documents[DocumentName].GetIncomeAndExpenseItemsGLAMap(StructureData);
		For Each Elem In ItemsGLAMap Do
			If StructureData.Property(Elem.Key) Then
				
				IsIncomeAndExpenseGLA = IsIncomeAndExpenseGLA(StructureData[Elem.Key]);
				
				If TypeOf(Elem.Value) = Type("Array") Then
					
					For Each Value In Elem.Value Do
						CheckItemRegistrationSetValues(StructureData, IsIncomeAndExpenseGLA, Value);
					EndDo;
					
				Else
					
					CheckItemRegistrationSetValues(StructureData, IsIncomeAndExpenseGLA, Elem.Value);
					
				EndIf;
				
			ElsIf Elem.Key = "Clear" Then
				
				If TypeOf(Elem.Value) = Type("Array") Then
					For Each Value In Elem.Value Do
						StructureData.Insert(Value, Undefined);
					EndDo;
				Else
					StructureData.Insert(Elem.Value, Undefined);
				EndIf;
				
			EndIf;
		EndDo;
		
		IncomeAndExpenseItemsInDocuments.FillIncomeAndExpenseItemsDescription(StructureData);
		
	EndIf;
	
EndProcedure

Procedure CheckItemRegistrationInRow(StructureData, TabRow, TabName = "Header") Export
	
	If (StructureData.Property("UseDefaultTypeOfAccounting") And Not StructureData.UseDefaultTypeOfAccounting)
		Or Not GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		Return;
	EndIf;
	
	If StructureData.Property("DocumentName") Then
		DocumentName = StructureData.DocumentName;
	ElsIf StructureData.Property("ObjectParameters")
			And StructureData.ObjectParameters.Property("DocumentName") Then
		DocumentName = StructureData.ObjectParameters.DocumentName;
	Else
		DocumentName = "";
	EndIf;
	
	If StructureData.Property("Account") Then
		Account = StructureData.Account;
		AccountInRow = False;
	Else
		AccountInRow = True;
	EndIf;
	
	StructureData.Insert("TabName", TabName);
	
	If Metadata.Documents.Find(DocumentName) <> Undefined Then
		
		AttributesStructure = New Structure;
		
		ItemsGLAMap = Documents[DocumentName].GetIncomeAndExpenseItemsGLAMap(StructureData);
		For Each Elem In ItemsGLAMap Do
			
			If Elem.Key = "Clear" Then
				If TypeOf(Elem.Value) = Type("Array") Then
					For Each Value In Elem.Value Do
						TabRow[Value] = Undefined;
					EndDo;
				Else
					TabRow[Elem.Value] = Undefined;
				EndIf;
				
				Continue;
			EndIf;
			
			If AccountInRow Then
				Account = TabRow[Elem.Key];
			EndIf;
			IsIncomeAndExpenseGLA = IsIncomeAndExpenseGLA(Account);
			
			If TypeOf(Elem.Value) = Type("Array") Then
				
				For Each Value In Elem.Value Do
					CheckItemRegistrationSetValues(AttributesStructure, IsIncomeAndExpenseGLA, Value);
				EndDo;
				
			Else
				
				CheckItemRegistrationSetValues(AttributesStructure, IsIncomeAndExpenseGLA, Elem.Value);
				
			EndIf;
			
		EndDo;
		
		FillPropertyValues(TabRow, AttributesStructure);
		
	EndIf;
	
EndProcedure

Function IsIncomeAndExpenseGLA(GLAccount) Export
	
	TypeOfAccount = Common.ObjectAttributeValue(GLAccount, "TypeOfAccount");
	Return IsIncomeAndExpenseTypeOfAccount(TypeOfAccount);
	
EndFunction

Function IsIncomeGLA(GLAccount) Export
	
	TypeOfAccount = Common.ObjectAttributeValue(GLAccount, "TypeOfAccount");
	Return IsIncomeTypeOfAccount(TypeOfAccount);
	
EndFunction

Function IsExpenseGLA(GLAccount) Export
	
	TypeOfAccount = Common.ObjectAttributeValue(GLAccount, "TypeOfAccount");
	Return IsExpenseTypeOfAccount(TypeOfAccount);
	
EndFunction

#EndRegion

#EndRegion

#Region Private

Procedure FillGLAccountsInStructure(StructureForFilling, GLAccounts, GetGLAccounts)
	
	If StructureForFilling.Property("ProductGLAccounts") Then
		
		If GetGLAccounts Then
			FillProductGLAccounts(StructureForFilling, GLAccounts);
		Else
			FillProductGLAccountsDescription(StructureForFilling);
		EndIf;
		
	ElsIf StructureForFilling.Property("CounterpartyGLAccounts") Then
		
		If GetGLAccounts Then
			FillCounterpartyGLAccounts(StructureForFilling, GLAccounts);
		Else
			FillCounterpartyGLAccountsDescription(StructureForFilling);
		EndIf;
		
	EndIf;
	
	IncomeAndExpenseItemsInDocuments.FillIncomeAndExpenseItemsDescription(StructureForFilling);
	
EndProcedure

Procedure FillGLAccountsInHeader(DocumentObject, StructureData, FillingData = Undefined)
	
	ObjectMetadata = StructureData.ObjectMetadata;
	CounterpartyGLAccountStructure = GetCounterpartyGLAccountEmptyStructure();
	
	If FillingData <> Undefined Then
		FillingDataArray = GetFillingDataArray(FillingData);
		FillingMetadata = StructureData.FillingMetadata;
	EndIf;
	
	For Each Item In CounterpartyGLAccountStructure Do
		
		If ObjectMetadata.Attributes.Find(Item.Key) <> Undefined Then
			If FillingMetadata <> Undefined
				And FillingMetadata.Attributes.Find(Item.Key) <> Undefined Then
				DocumentObject[Item.Key] = FillingDataArray[0][Item.Key];
			Else
				FillCounterpartyGLAccounts(StructureData);
				DocumentObject[Item.Key] = StructureData[Item.Key];
			EndIf;
			
			CheckItemRegistrationInRow(StructureData, DocumentObject);
		EndIf;
	EndDo;

EndProcedure

Procedure FillGLAccountsInTabSection(DocumentObject, TabSectionName, StructureData, FillingData = Undefined)
	
	ObjectParameters = StructureData.ObjectParameters;
	TabSection = DocumentObject[TabSectionName];
	TabSectionMetadata = DocumentObject.Metadata().TabularSections[TabSectionName];
	
	If FillingData <> Undefined Then
		
		FillingDataArray = GetFillingDataArray(FillingData);
		FillingMetadata = GetFillingMetadata(StructureData, FillingDataArray, FillingData);
		
		If FillingMetadata <> Undefined Then
			FillingMetadataTabSections = FillingMetadata.TabularSections;
		EndIf;
	EndIf;
	
	If StructureData.Property("ProductName") Then
		ProductName = StructureData.ProductName;
	Else
		ProductName = "Products";
	EndIf;
	
	If TabSectionMetadata.Attributes.Find(ProductName) <> Undefined Then
				
		StructureData.Insert("Products", GetProductsArray(TabSection, ProductName));
		
		If StructureData.Property("ObjectMetadata")
			And StructureData.ObjectMetadata.Attributes.Find("InventoryWarehouse") <> Undefined Then
			If TabSectionName = "Materials"  Then
				ObjectParameters.Insert("StructuralUnit", DocumentObject.InventoryWarehouse);
			ElsIf StructureData.ObjectMetadata.Attributes.Find("StructuralUnitReserve") <> Undefined Then
				ObjectParameters.Insert("StructuralUnit", DocumentObject.StructuralUnitReserve);
			EndIf;
		EndIf;
		
		ProductGLAccounts = GetProductListGLAccounts(StructureData);
		
		For Each Row In TabSection Do
			
			NeedCheckItem = False;
			
			GLAccounts = ProductGLAccounts[Row.Products];
			For Each GLAccount In GLAccounts Do
				GLAccountInRow = TabSectionMetadata.Attributes.Find(GLAccount.Key);
				If GLAccountInRow <> Undefined Then
					
					If FillingMetadata <> Undefined
						And FillingMetadataTabSections.Find(TabSectionName) <> Undefined
						And FillingMetadataTabSections[TabSectionName].Attributes.Find(GLAccount.Key) <> Undefined Then
						
						For Each Basis In FillingDataArray Do
							
							FilterStructure = New Structure(ProductName, Row[ProductName]);
							FoundRow = Basis[TabSectionName].FindRows(FilterStructure);
							
							If FoundRow.Count() > 0 Then
								Row[GLAccount.Key] = FoundRow[0][GLAccount.Key];
								NeedCheckItem = True;
							EndIf;
							
						EndDo;
					EndIf;
					
					If Not ValueIsFilled(Row[GLAccount.Key]) Then
						Row[GLAccount.Key] = GLAccount.Value;
						NeedCheckItem = True;
					EndIf;
				EndIf;
			EndDo;
			
			If NeedCheckItem Then
				CheckItemRegistrationInRow(StructureData, Row, TabSectionName);
			EndIf;
			
		EndDo;
		
	Else
		
		CounterpartyGLAccountStructure = GetCounterpartyGLAccountEmptyStructure();
		For Each Item In CounterpartyGLAccountStructure Do
			
			If TabSectionMetadata.Attributes.Find(Item.Key) <> Undefined Then
				
				For Each Row In TabSection Do
					
					TableData = IncomeAndExpenseItemsInDocuments.GetCounterpartyStructureData(ObjectParameters, TabSectionName, Row);
					CompleteCounterpartyStructureData(TableData, ObjectParameters, TabSectionName);
					
					FillCounterpartyGLAccounts(TableData);
					Row[Item.Key] = TableData[Item.Key];
					
					CheckItemRegistrationInRow(StructureData, Row, TabSectionName);
					
				EndDo;
				
			EndIf;
		EndDo;
		
	EndIf;
	
EndProcedure

Procedure AddQueryText(QueryText, Priority, Fields)
	
	FullCondition = "";
	FieldKey = "";	
	PostProcessing = New Array();
	
	For Each Field In Fields Do
		
		If Field.Value.Condition = "Empty" Then // [AND] Contract = &EmptyContract
			
			Condition = StringFunctionsClientServer.SubstituteParametersToString(
				"%1 %2 = &Empty%2",
				?(FullCondition <> "", " AND", ""),
				Field.Key);
			
		ElsIf Field.Value.Condition = "Selected" Then // [AND] Contract = &Contract AND NOT &Contract = &EmptyContract
				
			Condition = StringFunctionsClientServer.SubstituteParametersToString(
				"%1 %2 = &%2 AND NOT &%2 = &Empty%2",
				?(FullCondition <> "", " AND", ""),
				Field.Key);
			
		ElsIf Field.Value.Condition = "InGroup" Then // Contract = &ContractGroup" + Index + " ...
			
			If Field.Value.MaxCount = 0 Then
				Return;
			EndIf;
			
			Condition = "";
			PostProcessing.Add(Field.Value);
			FieldKey = Field.Key;			
		Else
			Raise NStr("en = 'This is incorrect type of condition'; ru = 'Неправильный тип условия.';pl = 'To nieprawidłowy typ warunku';es_ES = 'Es el tipo incorrecto de la condición';es_CO = 'Es el tipo incorrecto de la condición';tr = 'Bu yanlış bir koşul türüdür';it = 'Questa è un tipo incorretto di condizione';de = 'Dies ist eine falsche Art von Bedingung'");
		EndIf;
		
		FullCondition = FullCondition + Condition;
		
	EndDo;
	
	If PostProcessing.Count() = 0 Then
		
		NewQueryText = QueryTemplate();
		NewQueryText = StrReplace(NewQueryText, "&Priority", Priority);
		NewQueryText = StrReplace(NewQueryText, "&Condition", FullCondition);
		
	ElsIf PostProcessing.Count() = 1 Then
		
		Field = PostProcessing[0];
		
		NewQueryText = "";
		QueryTemplate = QueryTemplate();
		QueryTemplate = StrReplace(QueryTemplate, "&Priority", Priority);
		
		Count = 0;
		
		While Count < Field.MaxCount Do
			
			TextHierarchy = QueryTemplate;
			
			HierarchyCondition = StringFunctionsClientServer.SubstituteParametersToString(
				"%1 %2 = &%2Group%3",
				?(FullCondition <> "", " AND", ""),
				FieldKey,
				Count + 1);
			
			TextHierarchy = StrReplace(TextHierarchy, "&Condition", FullCondition + HierarchyCondition);
			
			If NewQueryText <> "" Then
				
				NewQueryText = NewQueryText + DriveClientServer.GetQueryUnion();
				
			EndIf;
			
			NewQueryText = NewQueryText + TextHierarchy;
			
			Count = Count + 1;
		EndDo;
		
	Else
		Raise NStr("en = 'Conditions with hierarchy can not be more than one'; ru = 'Может быть только одно условие с иерархией';pl = 'Warunki z hierarchią nie mogą być większe, niż jeden';es_ES = 'No puede haber más que una condición con jerarquía';es_CO = 'No puede haber más que una condición con jerarquía';tr = 'Hiyerarşili koşullar birden fazla olamaz';it = 'Le condizioni con gerarchia non possono essere più di una';de = 'Bedingungen mit Hierarchie dürfen nicht mehr als eine sein'");
	EndIf;
	
	If QueryText <> "" Then
		QueryText = QueryText + DriveClientServer.GetQueryUnion();
		NewQueryText = StrReplace(NewQueryText, " ALLOWED", "");
	EndIf;
	
	QueryText = QueryText + NewQueryText;
	
EndProcedure

Function DeleteDuplicateArrayItems(ProcessedArray, DoNotUseUndefined = False, AnalyzeRefsAsIDs = False)

	If TypeOf(ProcessedArray) <> Type("Array") Then
		Return ProcessedArray;
	EndIf;
	
	AlreadyInArray = New Map;
	If AnalyzeRefsAsIDs Then 
		
		ReferenceTypeDescription = Common.AllRefsTypeDetails();
		
	 	ThereWasUndefined = False;
		ItemCountInArray  = ProcessedArray.Count();

		For ReverseIndex = 1 To ItemCountInArray Do
			
			ArrayItem = ProcessedArray[ItemCountInArray - ReverseIndex];
			ItemType = TypeOf(ArrayItem);
			If ArrayItem = Undefined Then
				If ThereWasUndefined Or DoNotUseUndefined Then
					ProcessedArray.Delete(ItemCountInArray - ReverseIndex);
				Else
					ThereWasUndefined = True;
				EndIf;
				Continue;
			ElsIf ReferenceTypeDescription.ContainsType(ItemType) Then

				ItemID = String(ArrayItem.UUID());

			Else

				ItemID = ArrayItem;

			EndIf;

			If AlreadyInArray[ItemID] = True Then
				ProcessedArray.Delete(ItemCountInArray - ReverseIndex);
			Else
				AlreadyInArray[ItemID] = True;
			EndIf;
			
		EndDo;

	Else
		
		ItemIndex = 0;
		ItemCount = ProcessedArray.Count();
		While ItemIndex < ItemCount Do
			
			ArrayItem = ProcessedArray[ItemIndex];
			If DoNotUseUndefined AND ArrayItem = Undefined
			 Or AlreadyInArray[ArrayItem] = True Then
			 
			 	ProcessedArray.Delete(ItemIndex);
				ItemCount = ItemCount - 1;
				
			Else
				
				AlreadyInArray.Insert(ArrayItem, True);
				ItemIndex = ItemIndex + 1;
				
			EndIf;
		EndDo;
	EndIf;

	Return ProcessedArray;

EndFunction

Function FieldsWithDefaultValues()
	
	Properties = ("Condition, MaxCount");
	
	Fields = New Structure();
	
	Fields.Insert("Company", New Structure(Properties));
	Fields.Insert("TaxCategory", New Structure(Properties));
	Fields.Insert("Counterparty", New Structure(Properties));
	Fields.Insert("Contract", New Structure(Properties));
	
	Return Fields;
	
EndFunction

Procedure FillParameters(Query, FieldName, Array)
	
	Count = 1;
	For Each Item In Array Do
		Query.SetParameter(FieldName + "Group" + Count, Item);
		Count = Count + 1;
	EndDo;
	
EndProcedure

Function GetCounterpartyGLAccountEmptyStructure()
	
	EmptyGLAccount = ChartsOfAccounts.PrimaryChartOfAccounts.EmptyRef();
	
	ReturnStructure = New Structure();
	ReturnStructure.Insert("AccountsReceivableGLAccount",	EmptyGLAccount);
	ReturnStructure.Insert("AdvancesReceivedGLAccount",		EmptyGLAccount);
	ReturnStructure.Insert("AccountsPayableGLAccount",		EmptyGLAccount);
	ReturnStructure.Insert("AdvancesPaidGLAccount",			EmptyGLAccount);
	ReturnStructure.Insert("DiscountAllowedGLAccount",		EmptyGLAccount);
	ReturnStructure.Insert("DiscountReceivedGLAccount",		EmptyGLAccount);
	ReturnStructure.Insert("ThirdPartyPayerGLAccount",		EmptyGLAccount);
	
	Return ReturnStructure; 
	
EndFunction

Function GetFillingDataArray(FillingData)
	
	If TypeOf(FillingData) = Type("Array") Then
		FillingDataArray = FillingData;
	Else	
		FillingDataArray = New Array;
		FillingDataArray.Add(FillingData);
	EndIf;
	
	Return FillingDataArray; 
	
EndFunction

Function GetFillingMetadata(StructureData, FillingDataArray, FillingData)
	
	If StructureData.Property("FillingMetadata") Then
		FillingMetadata = StructureData.FillingMetadata;
	ElsIf Common.IsReference(TypeOf(FillingData)) Then
		FillingMetadata = FillingDataArray[0].Metadata();
	EndIf;
	
	Return FillingMetadata; 
	
EndFunction

Function GetProductGLAccountEmptyStructure()
	
	EmptyGLAccount = ChartsOfAccounts.PrimaryChartOfAccounts.EmptyRef();
	
	ReturnStructure = New Structure();
	ReturnStructure.Insert("InventoryGLAccount",					EmptyGLAccount);
	ReturnStructure.Insert("InventoryTransferredGLAccount",			EmptyGLAccount);
	ReturnStructure.Insert("UnearnedRevenueGLAccount",				EmptyGLAccount);
	ReturnStructure.Insert("VATInputGLAccount",						EmptyGLAccount);
	ReturnStructure.Insert("VATOutputGLAccount",					EmptyGLAccount);
	ReturnStructure.Insert("RevenueGLAccount",						EmptyGLAccount);
	ReturnStructure.Insert("COGSGLAccount",							EmptyGLAccount);
	ReturnStructure.Insert("ConsumptionGLAccount",					EmptyGLAccount);
	ReturnStructure.Insert("SalesReturnGLAccount",					EmptyGLAccount);
	ReturnStructure.Insert("PurchaseReturnGLAccount",				EmptyGLAccount);
	ReturnStructure.Insert("InventoryReceivedGLAccount",			EmptyGLAccount);
	ReturnStructure.Insert("GoodsShippedNotInvoicedGLAccount",		EmptyGLAccount);
	ReturnStructure.Insert("GoodsReceivedNotInvoicedGLAccount",		EmptyGLAccount);
	ReturnStructure.Insert("GoodsInvoicedNotDeliveredGLAccount",	EmptyGLAccount);
	ReturnStructure.Insert("GoodsInTransitGLAccount",				EmptyGLAccount);
	ReturnStructure.Insert("SignedOutEquipmentGLAccount",			EmptyGLAccount);
	ReturnStructure.Insert("InventoryToGLAccount",					EmptyGLAccount);
	ReturnStructure.Insert("AbnormalScrapGLAccount",				EmptyGLAccount);
	ReturnStructure.Insert("CostOfSalesGLAccount",					EmptyGLAccount);
	
	Return ReturnStructure; 
	
EndFunction

Function GetHigherItemGroupListQuery(CatalogName)

	Query = New Query;
	QueryText =
	"SELECT
	|	Catalog.Ref AS Item,
	|	Catalog.Parent AS Parent1,
	|	Catalog2.Parent AS Parent2,
	|	Catalog3.Parent AS Parent3,
	|	Catalog4.Parent AS Parent4,
	|	Catalog5.Parent AS Parent5
	|FROM
	|	Catalog.Product AS Catalog
	|		LEFT JOIN Catalog.Product AS Catalog2
	|		ON (Catalog2.Ref = Catalog.Parent)
	|		LEFT JOIN Catalog.Product AS Catalog3
	|		ON (Catalog3.Ref = Catalog2.Parent)
	|		LEFT JOIN Catalog.Product AS Catalog4
	|		ON (Catalog4.Ref = Catalog3.Parent)
	|		LEFT JOIN Catalog.Product AS Catalog5
	|		ON (Catalog5.Ref = Catalog4.Parent)
	|WHERE
	|	Catalog.Ref IN(&RefArray)";
	
	Query.Text = StrReplace(QueryText, "Product", CatalogName);
	
	Return Query;

EndFunction

Function GetHigherItemGroupList(CatalogItemArray)

	Result = New Map;
	
	If CatalogItemArray.Count() = 0 Then
		Return Result;
	EndIf;
	
	For Each CatalogItem In CatalogItemArray Do
		Result.Insert(CatalogItem, New Array);
	EndDo;
	
	CatalogMetadata = CatalogItemArray[0].Metadata();
	If Not CatalogMetadata.Hierarchical Then
		Return Result;
	EndIf;
	
	CatalogName = CatalogMetadata.Name;
	Query = GetHigherItemGroupListQuery(CatalogName);
	
	GroupsAndItemsMap = New ValueTable;
	GroupsAndItemsMap.Columns.Add("Parent",	New TypeDescription("CatalogRef." + CatalogName));
	GroupsAndItemsMap.Columns.Add("Item",	New TypeDescription("CatalogRef." + CatalogName));
	GroupsAndItemsMap.Indexes.Add("Parent");
	For Each CatalogItem In CatalogItemArray Do
		NewMap = GroupsAndItemsMap.Add();
		NewMap.Parent	= CatalogItem;
		NewMap.Item	= CatalogItem;
	EndDo;
	
	Filter	= New Structure("Parent");
	
	RefCurrentArray = CatalogItemArray;
	
	While RefCurrentArray.Count() > 0 Do
		
		Query.SetParameter("RefArray", DeleteDuplicateArrayItems(RefCurrentArray));
		Selection = Query.Execute().Select();
		
		RefCurrentArray	= New Array;
		
		While Selection.Next() Do
			
			Filter.Parent = Selection.Item;
			
			FoundRows = GroupsAndItemsMap.FindRows(Filter);
			For Each GroupAndItemMap In FoundRows Do
				
				CatalogItem	= GroupAndItemMap.Item;
				
				HigherGroupArray = Result.Get(CatalogItem);
				
				For Index = 1 To 5 Do
					
					Parent = Selection["Parent" + Index];

					If Parent = CatalogItem Then
						MessageCyclicLinkInObject(CatalogMetadata, CatalogItem);
						Break;
					EndIf;
					
					If ValueIsFilled(Parent) Then
						
						HigherGroupArray.Add(Parent);
						If Index = 5 Then
							RefCurrentArray.Add(Parent);
							NewMap = GroupsAndItemsMap.Add();
							NewMap.Parent	= Parent;
							NewMap.Item		= CatalogItem;
						EndIf;
						
					Else
						Break;
					EndIf;
				EndDo;
			EndDo;
		EndDo;
	EndDo;
	
	Return Result;

EndFunction

Procedure MessageCyclicLinkInObject(ObjectMetadata, DataItem)

	ObjectType = "";
	If Common.IsCatalog(ObjectMetadata) Then
		ObjectType = NStr("en = 'In the catalog'; ru = 'В справочнике';pl = 'W katalogu';es_ES = 'En el catálogo';es_CO = 'En el catálogo';tr = 'Katalogda';it = 'Nel catalogo';de = 'Im Katalog'");
	ElsIf Common.IsChartOfCharacteristicTypes(ObjectMetadata) Then
		ObjectType = NStr("en = 'In the chart of characteristic types'; ru = 'В плане видов характеристик';pl = 'Na wykresie typów charakterystycznych';es_ES = 'En el diagrama de tipos de requisitos';es_CO = 'En el diagrama de tipos de requisitos';tr = 'Özellik türü listesinde';it = 'Nel grafico dei tipi caratteristica';de = 'Im Diagramm der Merkmalsarten'");
	EndIf;
	
	MessageText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = '%1 %2 the %3 element in the %4 field contains a cyclical reference to itself. You should specify the correct group.'; ru = '%1 %2 Элемент %3 в поле %4 содержит циклическую ссылку на самого себя. Необходимо указать правильную группу.';pl = '%1 %2 ten %3 element w %4 polu zawiera cykliczne odniesienie do samego siebie. Należy określić poprawną grupę.';es_ES = '%1 %2 el %3 elemento en el %4 campo contiene la referencia cíclica por sí mismo. Hay que especificar un grupo correcto.';es_CO = '%1 %2 el %3 elemento en el %4 campo contiene la referencia cíclica por sí mismo. Hay que especificar un grupo correcto.';tr = '%1 %2, %4 alanındaki %3 elemanı kendisine çevrimsel bir referans içerir. Doğru grubu belirtmelisiniz.';it = '%1 %2 l''elemento%3 nel campo %4 contiene un riferimento ciclico a se stesso. Dovete specificare il gruppo corretto.';de = '%1 %2 das %3 Element im %4 Feld enthält eine zyklische Referenz zu sich selbst. Sie sollten die korrekte Gruppe festlegen.'"),
		ObjectType,
		ObjectMetadata.Synonym,
		DataItem,
		ObjectMetadata.StandardAttributes.Parent.Synonym);
	WriteLogEvent(
		NStr("en = 'Cyclic link'; ru = 'Циклическая ссылка';pl = 'Odnośnik cykliczny';es_ES = 'Enlace cíclico';es_CO = 'Enlace cíclico';tr = 'Döngüsel bağlantı';it = 'Collegamento ciclico';de = 'Zyklischer Link'", CommonClientServer.DefaultLanguageCode()),
		EventLogLevel.Warning,
		ObjectMetadata,
		DataItem,
		MessageText);
	CommonClientServer.MessageToUser(MessageText, DataItem, "Parent", "Object");

EndProcedure

Function QueryTemplate()
	
	Return "SELECT ALLOWED
	       |	&Priority AS Priority,
	       |	Table.AccountsReceivable AS AccountsReceivable,
	       |	Table.AdvancesReceived AS AdvancesReceived,
	       |	Table.AccountsPayable AS AccountsPayable,
	       |	Table.AdvancesPaid AS AdvancesPaid,
	       |	Table.DiscountAllowed AS DiscountAllowed,
	       |	Table.DiscountReceived AS DiscountReceived,
	       |	Table.ThirdPartyPayer AS ThirdPartyPayer
	       |FROM
	       |	InformationRegister.CounterpartiesGLAccounts AS Table
	       |WHERE
	       |	&Condition";
	
EndFunction

Procedure AddObjectParametersAdvanceInvoicing(ObjectParameters)
	
	Result = False;
	
	If ObjectParameters.DocumentName = "SalesInvoice" 
		And ObjectParameters.OperationKind = Enums.OperationTypesSalesInvoice.AdvanceInvoice Then
			
		Result = True;
				
	ElsIf ObjectParameters.DocumentName = "SupplierInvoice" 
		And ObjectParameters.OperationKind = Enums.OperationTypesSupplierInvoice.AdvanceInvoice Then 
		
		Result = True;
		
	EndIf;
	
	ObjectParameters.Insert("AdvanceInvoicing", Result);
	
EndProcedure

Procedure FillVATInputGLAccount(StructureData, GLAccountsForFilling)

	If Not StructureData.Property("Document")
		Or Not StructureData.Property("VATRate") Then
		Return;
	EndIf;
	
	If ValueIsFilled(StructureData.Document) Then
		
		Query = New Query;
		Query.Text = 
		"SELECT
		|	SupplierInvoice.Ref AS Ref
		|INTO SupplierInvoice
		|FROM
		|	Document.SupplierInvoice AS SupplierInvoice
		|WHERE
		|	SupplierInvoice.Ref = &Document
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT TOP 1
		|	SupplierInvoiceInventory.VATInputGLAccount AS VATInputGLAccount
		|FROM
		|	SupplierInvoice AS SupplierInvoice
		|		INNER JOIN Document.SupplierInvoice.Inventory AS SupplierInvoiceInventory
		|		ON SupplierInvoice.Ref = SupplierInvoiceInventory.Ref
		|WHERE
		|	SupplierInvoiceInventory.VATRate = &VATRate
		|
		|UNION ALL
		|
		|SELECT TOP 1
		|	SupplierInvoiceExpenses.VATInputGLAccount
		|FROM
		|	SupplierInvoice AS SupplierInvoice
		|		INNER JOIN Document.SupplierInvoice.Expenses AS SupplierInvoiceExpenses
		|		ON SupplierInvoice.Ref = SupplierInvoiceExpenses.Ref
		|WHERE
		|	SupplierInvoiceExpenses.VATRate = &VATRate";
		
		Query.SetParameter("Document",	StructureData.Document);
		Query.SetParameter("VATRate",	StructureData.VATRate);
		
		QueryResult = Query.Execute();
		
		Selection = QueryResult.Select();
		
		If Selection.Next() Then
			StructureData.Insert("VATInputGLAccount",			Selection.VATInputGLAccount);
			GLAccountsForFilling.Insert("VATInputGLAccount",	Selection.VATInputGLAccount);
		EndIf;
		
	EndIf;
	
	If Not ValueIsFilled(GLAccountsForFilling.VATInputGLAccount) Then
		
		VATInputGLAccount = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATInput");
		StructureData.Insert("VATInputGLAccount",			VATInputGLAccount);
		GLAccountsForFilling.Insert("VATInputGLAccount",	VATInputGLAccount);
		
		If ValueIsFilled(StructureData.Document) Then
			MessageText = Nstr("en = 'The VAT rate from line #%1 does not match VAT rates from %2. The VAT input GL account is set to the default VAT input GL account from the Default GL accounts catalog.'; ru = 'Ставка НДС из строки %1 не соответствует ставкам НДС из %2. Счет учета входящего НДС устанавливается как счет учета входящего НДС по умолчанию в справочнике Счета учета по умолчанию.';pl = 'Stawka VAT z wiersza nr %1 nie odpowiada stawkom VAT z %2. Konto księgowe należnego VAT jest ustawione na domyślne konto księgowe należnego VAT z katalogu domyślnych kont księgowych.';es_ES = 'El tipo de IVA en la línea #%1 no coincide con los tipos de IVA de %2. La cuenta del libro mayor del IVA soportado se establece en la cuenta de libro mayor del IVA soportado por defecto del catálogo de cuentas del libro mayor por defecto.';es_CO = 'El tipo de IVA en la línea #%1 no coincide con los tipos de IVA de %2. La cuenta del libro mayor del IVA soportado se establece en la cuenta de libro mayor del IVA soportado por defecto del catálogo de cuentas del libro mayor por defecto.';tr = '%1 satırındaki KDV oranı %2 KDV oranıyla eşleşmiyor. KDV girişi muhasebe hesabı, Varsayılan muhasebe hesapları kataloğundan Varsayılan KDV girişi muhasebe hesabı olarak ayarlı.';it = 'L''aliquota IVA dalla riga #%1 non corrisponde alle aliquote IVA da %2. L''inserimento dell''IVA nel conto mastro è impostato all''inserimento predefinito del''IVA nel conto mastro dal catalogo predefinito del conto mastro.';de = 'Der USt.-Satz von Zeile #%1 stimmt nicht mit den USt.-Sätzen von %2überein. Das Hauptbuch-Konto von USt.-EIngabe ist auf den Standard-Hauptbuch-Konto von USt.-EIngabe aus dem Standard-Hauptbuch-Kontenkatalog gesetzt.'");
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				MessageText,
				StructureData.LineNumber,
				StructureData.Document);
			CommonClientServer.MessageToUser(MessageText);
		EndIf;
		
	EndIf;
		
EndProcedure

Procedure FillVATOutputGLAccount(StructureData, GLAccountsForFilling)
	
	If Not StructureData.Property("Document") Or Not StructureData.Property("VATRate") Then
		Return;
	EndIf;
	
	If ValueIsFilled(StructureData.Document) Then
		
		Query = New Query;
		Query.Text = 
		"SELECT
		|	SalesInvoice.Ref AS Ref
		|INTO SalesInvoice
		|FROM
		|	Document.SalesInvoice AS SalesInvoice
		|WHERE
		|	SalesInvoice.Ref = &Document
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT TOP 1
		|	SalesInvoiceInventory.VATOutputGLAccount AS VATOutputGLAccount
		|FROM
		|	SalesInvoice AS SalesInvoice
		|		INNER JOIN Document.SalesInvoice.Inventory AS SalesInvoiceInventory
		|		ON SalesInvoice.Ref = SalesInvoiceInventory.Ref
		|WHERE
		|	SalesInvoiceInventory.VATRate = &VATRate";
		
		Query.SetParameter("Document", StructureData.Document);
		Query.SetParameter("VATRate", StructureData.VATRate);
		
		QueryResult = Query.Execute();
		
		Selection = QueryResult.Select();
		
		If Selection.Next() Then
			StructureData.Insert("VATOutputGLAccount", Selection.VATOutputGLAccount);
			GLAccountsForFilling.Insert("VATOutputGLAccount", Selection.VATOutputGLAccount);
		EndIf;
		
	EndIf;
	
	If Not ValueIsFilled(GLAccountsForFilling.VATOutputGLAccount) Then
		
		VATOutputGLAccount = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATOutput");
		StructureData.Insert("VATOutputGLAccount", VATOutputGLAccount);
		GLAccountsForFilling.Insert("VATOutputGLAccount", VATOutputGLAccount);
		
		If ValueIsFilled(StructureData.Document) Then
			MessageText = Nstr("en = 'The VAT rate from line #%1 does not match VAT rates from %2. The VAT output GL account is set to the default VAT output GL account from the Default GL accounts catalog.'; ru = 'Ставка НДС из строки %1 не соответствует ставкам НДС из %2. Счет учета исходящего НДС устанавливается как счет учета исходящего НДС по умолчанию в справочнике Счета учета по умолчанию.';pl = 'Stawka VAT z wiersza nr %1 nie odpowiada stawkom VAT z %2. Konto księgowe należnego VAT jest ustawione na domyślne konto księgowe należnego VAT z katalogu domyślnych kont księgowych.';es_ES = 'La tasa del IVA en la línea #%1 no coincide con las tasas del IVA de %2. La cuenta del libro mayor de la salida de IVA se establece en la cuenta de libro mayor de la salida de IVA por defecto del catálogo de cuentas del libro mayor por defecto.';es_CO = 'La tasa de IVA en la línea #%1 no coincide con las tasas de IVA de %2. La cuenta del libro mayor de la salida del IVA se establece en la cuenta de libro mayor de la salida del IVA por defecto del catálogo de cuentas del libro mayor por defecto.';tr = '%1 satırındaki KDV oranı %2 KDV oranıyla eşleşmiyor. KDV çıkışı muhasebe hesabı, Varsayılan muhasebe hesapları kataloğundan Varsayılan KDV çıkışı muhasebe hesabı olarak ayarlı.';it = 'L''aliquota IVA dalla riga #%1 non corrisponde alle aliquote IVA da %2. L''IVA a valle nel conto mastro è impostata all''IVA a valle predefinita nel conto mastro dal catalogo predefinito del conto mastro.';de = 'Der USt.-Satz von Zeile #%1 stimmt nicht mit den USt.-Sätzen von %2überein. Das Hauptbuch-Konto von USt.-Ergebnis ist auf den Standard-Hauptbuch-Konto von USt.-Ergebnis aus dem Standard-Hauptbuch-Kontenkatalog gesetzt.'");
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageText,
				StructureData.LineNumber,
				StructureData.Document);
			CommonClientServer.MessageToUser(MessageText);
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure AddOthersEmptyGLAccounts(EmptyGLAccounts)

	EmptyGLAccount = ChartsOfAccounts.PrimaryChartOfAccounts.EmptyRef();
	EmptyGLAccounts.Insert("VATInputGLAccount", EmptyGLAccount);
	EmptyGLAccounts.Insert("VATOutputGLAccount", EmptyGLAccount);

EndProcedure

Procedure SetRestrictInventoryGLAccount(StructureData, GLAccountsForFilling)
	
	If StructureData.ObjectParameters.Property("DocumentName")
		And StructureData.ObjectParameters.DocumentName = "SupplierInvoice" 
		And StructureData.Property("ProductsTypeInventory")
		And StructureData.ProductsTypeInventory Then
		
		RestrictTypeOfAccount = New Structure;
		RestrictTypeOfAccount.Insert("ExcludeTypeOfAccount", Enums.GLAccountsTypes.IndirectExpenses);
		
		GLAccountsForFilling.Insert("RestrictInventoryGLAccount", RestrictTypeOfAccount);
		
	ElsIf StructureData.ObjectParameters.Property("DocumentName")
		And StructureData.ObjectParameters.DocumentName = "ExpenseReport" Then
		
		RestrictTypeOfAccount = New Structure;
		RestrictTypeOfAccount.Insert("ExcludeTypeOfAccount", Enums.GLAccountsTypes.IndirectExpenses);
		
		GLAccountsForFilling.Insert("RestrictInventoryGLAccount", RestrictTypeOfAccount);
		
	EndIf;
	
EndProcedure

Procedure CheckItemRegistrationSetValues(StructureData, IsIncomeAndExpenseGLA, Value)
	
	ItemName = Left(Value, StrLen(Value)-4);
	
	StructureData.Insert("Register" + ItemName, IsIncomeAndExpenseGLA);
	
	If StructureData.Property("Manual") And Not IsIncomeAndExpenseGLA Then
		StructureData.Insert(Value, Catalogs.IncomeAndExpenseItems.EmptyRef());
	EndIf;
	
EndProcedure

Function IsIncomeAndExpenseTypeOfAccount(TypeOfAccount)
	
	Return TypeOfAccount = Enums.GLAccountsTypes.CostOfSales
		Or TypeOfAccount = Enums.GLAccountsTypes.Expenses
		Or TypeOfAccount = Enums.GLAccountsTypes.IndirectExpenses
		Or TypeOfAccount = Enums.GLAccountsTypes.OtherExpenses
		Or TypeOfAccount = Enums.GLAccountsTypes.OtherIncome
		Or TypeOfAccount = Enums.GLAccountsTypes.Revenue;
	
EndFunction

Function IsIncomeTypeOfAccount(TypeOfAccount)
	
	Return (TypeOfAccount = Enums.GLAccountsTypes.OtherIncome
		Or TypeOfAccount = Enums.GLAccountsTypes.Revenue);
	
EndFunction

Function IsExpenseTypeOfAccount(TypeOfAccount)
	
	Return TypeOfAccount = Enums.GLAccountsTypes.CostOfSales
		Or TypeOfAccount = Enums.GLAccountsTypes.Expenses
		Or TypeOfAccount = Enums.GLAccountsTypes.IndirectExpenses
		Or TypeOfAccount = Enums.GLAccountsTypes.OtherExpenses;
	
EndFunction

#EndRegion
