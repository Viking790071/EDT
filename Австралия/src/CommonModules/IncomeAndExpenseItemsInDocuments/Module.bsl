
#Region Public

Function GetObjectParameters(Val FormObject, StructuralUnitName = "StructuralUnit", VATTaxationName = "VATTaxation") Export

	ObjectParameters = New Structure;
	
	If FormObject.Property("Ref") Then
		ObjectParameters.Insert("Ref", FormObject.Ref);
		ObjectParameters.Insert("DocumentName", FormObject.Ref.Metadata().Name);
	EndIf;
	
	If FormObject.Property("Company") Then
		ObjectParameters.Insert("Company", FormObject.Company);
	EndIf;
	
	If FormObject.Property("Counterparty") Then
		ObjectParameters.Insert("Counterparty", FormObject.Counterparty);
	EndIf;
	
	If FormObject.Property("CounterpartySource") Then
		ObjectParameters.Insert("CounterpartySource", FormObject.CounterpartySource);
	EndIf;
	
	If FormObject.Property("Contract") Then
		ObjectParameters.Insert("Contract", FormObject.Contract);
	EndIf;
	
	If FormObject.Property("Date") Then
		ObjectParameters.Insert("Date", FormObject.Date);
	EndIf;
	
	If FormObject.Property("Products") Then
		ObjectParameters.Insert("Products", FormObject.Products);
	EndIf;
	
	If FormObject.Property(StructuralUnitName) Then
		ObjectParameters.Insert("StructuralUnit", FormObject[StructuralUnitName]);
		ObjectParameters.Insert("StructuralUnitType", Common.ObjectAttributeValue(FormObject[StructuralUnitName], "StructuralUnitType"));
	EndIf;

	If FormObject.Property("StructuralUnitPayee") Then
		ObjectParameters.Insert("StructuralUnitPayee", FormObject.StructuralUnitPayee);
		ObjectParameters.Insert("StructuralUnitPayeeType", Common.ObjectAttributeValue(FormObject.StructuralUnitPayee, "StructuralUnitType"));
	EndIf;
	
	If FormObject.Property("OperationKind") Then
		
		ObjectParameters.Insert("OperationKind", FormObject.OperationKind);
		
		If ObjectParameters.Property("DocumentName") Then
			AddObjectParametersAdvanceInvoicing(ObjectParameters);
		EndIf;
		
	EndIf;
	
	If FormObject.Property("OperationType") Then
		ObjectParameters.Insert("OperationType", FormObject.OperationType);
	EndIf;
	
	If FormObject.Property("AdvanceInvoicing") Then
		ObjectParameters.Insert("AdvanceInvoicing", FormObject.AdvanceInvoicing);
	EndIf;
	
	If FormObject.Property("VATIsDue") Then
		ObjectParameters.Insert("VATIsDue", FormObject.VATIsDue);
	EndIf;
	
	If FormObject.Property(VATTaxationName) Then
		ObjectParameters.Insert("VATTaxation", FormObject[VATTaxationName]);
	EndIf;
	
	If FormObject.Property("ThirdPartyPayment") Then
		ObjectParameters.Insert("ThirdPartyPayment", FormObject.ThirdPartyPayment);
	EndIf;
	
	If FormObject.Property("BasisDocument") Then
		ObjectParameters.Insert("BasisDocument", FormObject.BasisDocument);
	EndIf;
	
	If FormObject.Property("SalesOrder") Then
		ObjectParameters.Insert("SalesOrder", FormObject.SalesOrder);
	EndIf;
	
	If FormObject.Property("RegisterExpense") Then
		ObjectParameters.Insert("RegisterExpense", FormObject.RegisterExpense);
	EndIf;
	
	If FormObject.Property("RegisterIncome") Then
		ObjectParameters.Insert("RegisterIncome", FormObject.RegisterIncome);
	EndIf;
	
	Return ObjectParameters;
	
EndFunction

Procedure FillProductIncomeAndExpenseItems(StructureData, Items = Undefined) Export

	If Not StructureData.Property("ObjectParameters")
		And StructureData.Property("Object") Then
		
		StructureData.Insert("ObjectParameters", GetObjectParameters(StructureData.Object));
	EndIf;
	
	DocumentName = StructureData.ObjectParameters.DocumentName;
	
	If Metadata.Documents.Find(DocumentName) <> Undefined Then
		
		If Items = Undefined Or Items.Get(StructureData.Products) = Undefined
			Or StructureData.Property("StructuralUnitInTabularSection")
				And StructureData.StructuralUnitInTabularSection Then
			Items = GetProductListIncomeAndExpenseItems(StructureData);
		EndIf;
		
		ItemsForFilling = Documents[DocumentName].GetIncomeAndExpenseItemsStructure(StructureData);
		
		FillPropertyValues(ItemsForFilling, Items[StructureData.Products]);
		FillPropertyValues(StructureData, ItemsForFilling);
		
		FillIncomeAndExpenseItemsDescription(StructureData);
		
	EndIf;
	
EndProcedure

Function GetStructureData(ObjectParameters, TabName = "Inventory", RowData = Undefined, ProductName = "Products") Export
	
	Var ObjectMetadata;
	
	EmptyItem = Catalogs.IncomeAndExpenseItems.EmptyRef();
	EmptyItems = GetEmptyStructure();
	CheckBoxes = GetCheckBoxStructure();
	
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
		StructureData = New Structure("Products");
		StructureData.Insert("ProductsTypeInventory", True);
		StructureData.Insert("IncomeAndExpenseItems");
		StructureData.Insert("IncomeAndExpenseItemsFilled");
		
		If AttributesMetadata.Find("AdvanceInvoicing") <> Undefined Then
			StructureData.Insert("AdvanceInvoicing", False);
		EndIf;
		
		If AttributesMetadata.Find("Shipped") <> Undefined Then
			StructureData.Insert("Shipped", False);
		EndIf;
		
		If AttributesMetadata.Find("Batch") <> Undefined Then
			StructureData.Insert("Batch", Catalogs.ProductsBatches.EmptyRef());
		EndIf;
		
		If AttributesMetadata.Find("Ownership") <> Undefined Then
			StructureData.Insert("Ownership", Catalogs.InventoryOwnership.EmptyRef());
		EndIf;
		
		If AttributesMetadata.Find("StructuralUnit") <> Undefined Then
			StructureData.Insert("StructuralUnit", Catalogs.BusinessUnits.EmptyRef());
			StructureData.Insert("StructuralUnitInTabularSection", True);
		EndIf;
		
		If AttributesMetadata.Find("GoodsIssue") <> Undefined Then
			StructureData.Insert("GoodsIssue", Documents.GoodsIssue.EmptyRef());
		EndIf;
		
		If AttributesMetadata.Find("GoodsReceipt") <> Undefined Then
			StructureData.Insert("GoodsReceipt", Documents.GoodsReceipt.EmptyRef());
		EndIf;
		
		If AttributesMetadata.Find("ReceiptDocument") <> Undefined Then
			StructureData.Insert("AdvanceInvoicing", False);
		EndIf;
		
		If AttributesMetadata.Find("SalesInvoice") <> Undefined Then
			StructureData.Insert("SalesInvoice", Documents.SalesInvoice.EmptyRef());
		EndIf;
		
		If AttributesMetadata.Find("SupplierInvoice") <> Undefined Then
			StructureData.Insert("SupplierInvoice", Documents.SupplierInvoice.EmptyRef());
		EndIf;
		
		If AttributesMetadata.Find("EarningAndDeductionType") <> Undefined Then
			StructureData.Insert("EarningAndDeductionType", Catalogs.EarningAndDeductionTypes.EmptyRef());
		EndIf;
		
		If AttributesMetadata.Find("ExistsEPD") <> Undefined Then
			StructureData.Insert("ExistsEPD", False);
		EndIf;
		
		For Each Item In EmptyItems Do
			If AttributesMetadata.Find(Item.Key) <> Undefined Then
				StructureData.Insert(Item.Key, EmptyItem);
			EndIf;
		EndDo;
		
		For Each Item In CheckBoxes Do
			If AttributesMetadata.Find(Item.Key) <> Undefined Then
				StructureData.Insert(Item.Key, EmptyItem);
			EndIf;
		EndDo;
		
	ElsIf TabName = "Header"  Then
		
		StructureData = New Structure;
		AttributesMetadata = ObjectMetadata.Attributes;

		For Each Item In EmptyItems Do
			If AttributesMetadata.Find(Item.Key) <> Undefined Then
				StructureData.Insert(Item.Key, EmptyItem);
			EndIf;
		EndDo;
		
		For Each Item In CheckBoxes Do
			If AttributesMetadata.Find(Item.Key) <> Undefined Then
				StructureData.Insert(Item.Key, EmptyItem);
			EndIf;
		EndDo;
		
	Else
		
		StructureData = New Structure;
		If ObjectParameters.Property(ProductName) Then
			StructureData.Insert("Products", ObjectParameters[ProductName]);
		EndIf;
		
	EndIf;
	
	StructureData.Insert("ObjectParameters", ObjectParameters);
	StructureData.Insert("TabName", TabName);
	StructureData.Insert("ProductName", ProductName);
	
	If RowData <> Undefined Then 
		FillPropertyValues(StructureData, RowData);
		
		If RowData.Property(ProductName) Then
			ProductsType = Common.ObjectAttributeValue(RowData[ProductName], "ProductsType");
			StructureData.Insert("ProductsTypeInventory", ProductsType = Enums.ProductsTypes.InventoryItem);
		EndIf;
		
		If TabSectionMetadata <> Undefined And AttributesMetadata.Find("ReceiptDocument") <> Undefined Then
			StructureData.Insert("AdvanceInvoicing", DriveServerCall.AdvanceInvoicing(RowData.ReceiptDocument));
		EndIf;
	EndIf;
	
	Return StructureData;

EndFunction

Function GetProductListIncomeAndExpenseItems(StructureData) Export
	
	ObjectParameters = StructureData.ObjectParameters;
	Products = StructureData.Products;
	
	EmptyBusinessUnit = Catalogs.BusinessUnits.EmptyRef();
	
	If StructureData.Property("StructuralUnit") Then
		StructuralUnit = StructureData.StructuralUnit;
	Else
		StructuralUnit = EmptyBusinessUnit;
	EndIf;
	
	If Not ValueIsFilled(StructuralUnit)
		And ObjectParameters.Property("StructuralUnit") Then 
		StructuralUnit = ObjectParameters.StructuralUnit;
	EndIf;
	
	If ObjectParameters.Property("StructuralUnitPayee") Then
		StructuralUnitPayee = ObjectParameters.StructuralUnitPayee;
	Else
		StructuralUnitPayee = EmptyBusinessUnit;
	EndIf;
	
	Result = New Map;
	
	If Common.RefTypeValue(Products) Then
		ProductList = New Array;
		ProductList.Add(Products);
	Else
		If Products.Count() = 0 Then
			Return Result;
		EndIf;
		
		ProductList = Products;
	EndIf;
	
	If Not AccessRight("Read", Metadata.InformationRegisters.ProductIncomeAndExpenseItems) Then
		Return Result;
	EndIf;
	
	WithCheckBoxes = Not StructureData.Property("WithoutCheckBoxes");
	
	EmptyProduct = Catalogs.Products.EmptyRef();
	
	For Each Products In ProductList Do
		
		If Products = Undefined Then
			Continue;
		EndIf;
		
		ReturnStructure = GetProductIncomeAndExpensesEmptyStructure();
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
	|	ProductIncomeAndExpenseItems.Product AS Product
	|FROM
	|	InformationRegister.ProductIncomeAndExpenseItems AS ProductIncomeAndExpenseItems
	|WHERE
	|	ProductIncomeAndExpenseItems.Product.IsFolder";
	
	ThereIsProduct = Not Query.Execute().IsEmpty();
	
	HierarchyTable = New ValueTable;
	HierarchyTable.Columns.Add("Item", New TypeDescription("CatalogRef.Products"));
	HierarchyTable.Columns.Add("Parent", New TypeDescription("CatalogRef.Products"));
	HierarchyTable.Columns.Add("Level", Common.TypeDescriptionNumber(10, 0));
	
	If ThereIsProduct Then
		
		ItemAndGroupMap = GetHigherItemGroupList(ProductList);
		
		For Each Products In ProductList Do
			
			NewRow = HierarchyTable.Add();
			NewRow.Item = Products;
			
			NewRow = HierarchyTable.Add();
			NewRow.Item = Products;
			NewRow.Parent = Products;
			
			GroupList = ItemAndGroupMap.Get(Products);
			If GroupList = Undefined Then
				NewRow.Level = 1;
				Continue;
			EndIf;
			
			HigherGroupCount = GroupList.Count();
			
			NewRow.Level = HigherGroupCount + 1;
			
			For Index = 1 To HigherGroupCount Do
				NewRow = HierarchyTable.Add();
				NewRow.Item = Products;
				NewRow.Parent = GroupList[Index - 1];
				NewRow.Level = HigherGroupCount - Index + 1;
			EndDo;
		EndDo;
		
	Else
		
		For Each Products In ProductList Do
			
			ProductsCategory = Common.ObjectAttributesValues(Products, "ProductsCategory");
			
			NewRow = HierarchyTable.Add();
			NewRow.Item = Products;
			
			NewRow = HierarchyTable.Add();
			NewRow.Item = Products;
			NewRow.Parent = Products;
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
	|WHERE
	|	HierarchyTable.Parent IN(&ProductArray)
	|
	|INDEX BY
	|	Item
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
	|	Parent,
	|	ProductsCategory
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	HierarchyTable.Item AS Products,
	|	HierarchyTable.Parent AS Parent,
	|	HierarchyTable.Level AS Level,
	|	ProductIncomeAndExpenseItems.ProductCategory AS ProductsCategory,
	|	ProductIncomeAndExpenseItems.Company AS Company,
	|	ProductIncomeAndExpenseItems.StructuralUnit AS StructuralUnit,
	|	ProductIncomeAndExpenseItems.ExpenseItem AS ExpenseItem,
	|	ProductIncomeAndExpenseItems.RevenueItem AS RevenueItem,
	|	ProductIncomeAndExpenseItems.COGSItem AS COGSItem,
	|	ProductIncomeAndExpenseItems.SalesReturnItem AS SalesReturnItem,
	|	ProductIncomeAndExpenseItems.PurchaseReturnItem AS PurchaseReturnItem,
	|	ProductIncomeAndExpenseItems.CostOfSalesItem AS CostOfSalesItem
	|FROM
	|	HierarchyTableWithCategories AS HierarchyTable
	|		INNER JOIN InformationRegister.ProductIncomeAndExpenseItems AS ProductIncomeAndExpenseItems
	|		ON (ProductIncomeAndExpenseItems.Company IN (&CompanyArray))
	|			AND HierarchyTable.Parent = ProductIncomeAndExpenseItems.Product
	|			AND HierarchyTable.ProductsCategory = ProductIncomeAndExpenseItems.ProductCategory
	|			AND (ProductIncomeAndExpenseItems.StructuralUnit IN (&WarehouseArray))
	|
	|UNION ALL
	|
	|SELECT
	|	HierarchyTable.Item,
	|	HierarchyTable.Parent,
	|	HierarchyTable.Level,
	|	ProductIncomeAndExpenseItems.ProductCategory,
	|	ProductIncomeAndExpenseItems.Company,
	|	ProductIncomeAndExpenseItems.StructuralUnit,
	|	ProductIncomeAndExpenseItems.ExpenseItem,
	|	ProductIncomeAndExpenseItems.RevenueItem,
	|	ProductIncomeAndExpenseItems.COGSItem,
	|	ProductIncomeAndExpenseItems.SalesReturnItem,
	|	ProductIncomeAndExpenseItems.PurchaseReturnItem,
	|	ProductIncomeAndExpenseItems.CostOfSalesItem
	|FROM
	|	HierarchyTableWithCategories AS HierarchyTable
	|		INNER JOIN InformationRegister.ProductIncomeAndExpenseItems AS ProductIncomeAndExpenseItems
	|		ON (ProductIncomeAndExpenseItems.Company IN (&CompanyArray))
	|			AND HierarchyTable.Parent = ProductIncomeAndExpenseItems.Product
	|			AND (ProductIncomeAndExpenseItems.ProductCategory = VALUE(Catalog.ProductsCategories.EmptyRef))
	|			AND (ProductIncomeAndExpenseItems.StructuralUnit IN (&WarehouseArray))
	|
	|ORDER BY
	|	Level DESC,
	|	ProductsCategory DESC,
	|	StructuralUnit DESC,
	|	Company DESC";
	
	Query.SetParameter("CompanyArray", CompanyArray);
	Query.SetParameter("ProductArray", ProductArray);
	Query.SetParameter("HierarchyTable", HierarchyTable);
	Query.SetParameter("WarehouseArray", WarehouseArray);
	
	TableIncomeAndExpenses = Query.Execute().Unload();
	TableIncomeAndExpenses.Indexes.Add("Products");
	
	For Each Products In ProductList Do
		
		ReturnStructure = Result.Get(Products);
		
		FilterIncomeAndExpenses = New Structure("Products");
		FilterIncomeAndExpenses.Products = Products;
		
		FoundStrings = TableIncomeAndExpenses.FindRows(FilterIncomeAndExpenses);
		
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
			
			FilterIncomeAndExpenses.Products = EmptyProduct;
			
			FoundStrings = TableIncomeAndExpenses.FindRows(FilterIncomeAndExpenses);
			If FoundStrings.Count() > 0 Then
				FillPropertyValues(ReturnStructure, FoundStrings[0]);
			EndIf;
			
		EndIf;
		
		If ValueIsFilled(StructuralUnitPayee) Then
			
			FilterIncomeAndExpenses.Insert("StructuralUnit", StructuralUnitPayee);
			FoundStrings = TableIncomeAndExpenses.FindRows(FilterIncomeAndExpenses);
			
			If FoundStrings.Count() > 0 Then
				
				ReturnStructure.Insert("ExpenseItem", FoundStrings[0].ExpenseItem);
				ReturnStructure.Insert("RevenueItem", FoundStrings[0].RevenueItem);
				ReturnStructure.Insert("COGSItem", FoundStrings[0].COGSItem);
				ReturnStructure.Insert("SalesReturnItem", FoundStrings[0].SalesReturnItem);
				ReturnStructure.Insert("PurchaseReturnItem", FoundStrings[0].PurchaseReturnItem);
				ReturnStructure.Insert("CostOfSalesItem", FoundStrings[0].CostOfSalesItem);
				
			Else
				
				FilterIncomeAndExpenses.StructuralUnit = EmptyBusinessUnit;
				FoundStrings = TableIncomeAndExpenses.FindRows(FilterIncomeAndExpenses);
				
				If FoundStrings.Count() > 0 Then
					
					ReturnStructure.Insert("ExpenseItem", FoundStrings[0].ExpenseItem);
					ReturnStructure.Insert("RevenueItem", FoundStrings[0].RevenueItem);
					ReturnStructure.Insert("COGSItem", FoundStrings[0].COGSItem);
					ReturnStructure.Insert("SalesReturnItem", FoundStrings[0].SalesReturnItem);
					ReturnStructure.Insert("PurchaseReturnItem", FoundStrings[0].PurchaseReturnItem);
					ReturnStructure.Insert("CostOfSalesItem", FoundStrings[0].CostOfSalesItem);
					
				Else
					
					FilterIncomeAndExpenses.Products = EmptyProduct;
					
					FoundStrings = TableIncomeAndExpenses.FindRows(FilterIncomeAndExpenses);
					If FoundStrings.Count() > 0 Then
						FillPropertyValues(ReturnStructure, FoundStrings[0]);
					EndIf;
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
		If WithCheckBoxes Then
			For Each Elem In ReturnStructure Do
				ItemName = Left(Elem.Key, StrLen(Elem.Key)-4);
				ReturnStructure.Insert("Register" + ItemName, ValueIsFilled(Elem.Value));
			EndDo;
		EndIf;
		
	EndDo;
	
	Return Result;
	
EndFunction

Function FillIncomeAndExpenseItemsInBarcodeData(StructureData, DocumentObject, DocumentName, TabName = "Inventory", ProductName = "Products") Export
	
	EmptyItem = Catalogs.IncomeAndExpenseItems.EmptyRef();
	EmptyItems = GetProductIncomeAndExpenseItemsEmptyStructure();
	
	DocumentMetadata = Metadata.Documents[DocumentName];
	TabSectionMetadata = DocumentMetadata.TabularSections.Find(TabName);
	
	If TabSectionMetadata <> Undefined Then 
		
		AttributesMetadata = TabSectionMetadata.Attributes;
		
		If AttributesMetadata.Find("Batch") <> Undefined Then
			StructureData.Insert("Batch", Catalogs.ProductsBatches.EmptyRef());
		EndIf;
		
		If AttributesMetadata.Find("StructuralUnit") <> Undefined Then
			StructureData.Insert("StructuralUnit", Catalogs.BusinessUnits.EmptyRef());
		EndIf;
		
		If AttributesMetadata.Find("GoodsIssue") <> Undefined Then
			StructureData.Insert("GoodsIssue", Documents.GoodsIssue.EmptyRef());
		EndIf;
		
		If AttributesMetadata.Find("GoodsReceipt") <> Undefined Then
			StructureData.Insert("GoodsReceipt", Documents.GoodsReceipt.EmptyRef());
		EndIf;
		
		If AttributesMetadata.Find("SalesInvoice") <> Undefined Then
			StructureData.Insert("SalesInvoice", Documents.SalesInvoice.EmptyRef());
		EndIf;
		
		If AttributesMetadata.Find("SupplierInvoice") <> Undefined Then
			StructureData.Insert("SupplierInvoice", Documents.SupplierInvoice.EmptyRef());
		EndIf;
		
		For Each Item In EmptyItems Do
			If AttributesMetadata.Find(Item.Key) <> Undefined Then
				StructureData.Insert(Item.Key, EmptyItem);
			EndIf;
		EndDo;
		
	EndIf;
	
	StructureData.Insert("Object", DocumentObject);
	StructureData.Insert("TabName", TabName);
	StructureData.Insert("ProductName", ProductName);
	
	Return StructureData;

EndFunction

Procedure FillIncomeAndExpenseItemsInRow(ObjectParameters, TS_Row, TabName = "Inventory") Export
	
	StructureData = GetStructureData(ObjectParameters, TabName, TS_Row);
	FillProductIncomeAndExpenseItems(StructureData);
	FillPropertyValues(TS_Row, StructureData);
	
EndProcedure

Function GetCounterpartyIncomeAndExpenseItems(StructureData) Export

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
	
	Result = New Structure("DiscountAllowedItem, DiscountReceivedItem");

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
		Result.Insert("DiscountAllowedItem", Selection.DiscountAllowedItem);
		Result.Insert("DiscountReceivedItem", Selection.DiscountReceivedItem);
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
	
	Result = New Structure("DiscountAllowedItem, DiscountReceivedItem");
	
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
		Result.Insert("DiscountAllowedItem",Selection.DiscountAllowedItem);
		Result.Insert("DiscountReceivedItem",	Selection.DiscountReceivedItem);
	EndIf;
	
	Return Result;

EndFunction

Function GetCounterpartyStructureData(ObjectParameters, TabName = "PaymentDetails", RowData = Undefined) Export
	
	EmptyItem = Catalogs.IncomeAndExpenseItems.EmptyRef();
	EmptyItems = GetEmptyStructure();
	CheckBoxes = GetCheckBoxStructure();
	
	DocumentMetadata = Metadata.Documents[ObjectParameters.DocumentName];
	TabSectionMetadata = DocumentMetadata.TabularSections.Find(TabName);
	
	If TabSectionMetadata <> Undefined Then 
		
		AttributesMetadata = TabSectionMetadata.Attributes;
		Attributes = "LineNumber, Counterparty, Contract, Document, VATRate, ExistsEPD, EPDAmount";
		StructureData = New Structure(Attributes);
		
		For Each Item In EmptyItems Do
			If AttributesMetadata.Find(Item.Key) <> Undefined Then
				StructureData.Insert(Item.Key, EmptyItem);
			EndIf;
		EndDo;
		
		For Each Item In CheckBoxes Do
			If AttributesMetadata.Find(Item.Key) <> Undefined Then
				StructureData.Insert(Item.Key, EmptyItem);
			EndIf;
		EndDo;
		
	ElsIf TabName = "Header"  Then
		
		StructureData = New Structure;
		AttributesMetadata = DocumentMetadata.Attributes;

		For Each Item In EmptyItems Do
			If AttributesMetadata.Find(Item.Key) <> Undefined Then
				StructureData.Insert(Item.Key, EmptyItem);
			EndIf;
		EndDo;
		
		For Each Item In CheckBoxes Do
			If AttributesMetadata.Find(Item.Key) <> Undefined Then
				StructureData.Insert(Item.Key, EmptyItem);
			EndIf;
		EndDo;
		
	Else
		AttributesMetadata = DocumentMetadata.Attributes;
		
		StructureData = New Structure;
		If AttributesMetadata.Find("Counterparty") <> Undefined Then
			StructureData.Insert("Counterparty", ObjectParameters.Counterparty);
		EndIf;
		
		If AttributesMetadata.Find("Contract") <> Undefined Then
			StructureData.Insert("Contract", ObjectParameters.Contract);
		EndIf;
		
	EndIf;
	
	StructureData.Insert("ObjectParameters", ObjectParameters);
	StructureData.Insert("TabName", TabName);
	StructureData.Insert("CounterpartyIncomeAndExpenseItems", True);
	
	If RowData <> Undefined Then 
		FillPropertyValues(StructureData, RowData);
	EndIf;
	
	Return StructureData;

EndFunction

Procedure FillIncomeAndExpenseItemsInDocument(Document, Val FillingData = Undefined) Export
	
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
					And Common.IsReference(TypeOf(Array[0])) Then
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
	
	StructureData = GetCounterpartyStructureData(ObjectParameters, "Header", DocumentObject);
	
	StructureData.Insert("FillingMetadata",		FillingMetadata);
	StructureData.Insert("ObjectMetadata",		ObjectMetadata);
	
	TabularSectionsMetadata = ObjectMetadata.TabularSections;
	For Each TabSectionMetadata In TabularSectionsMetadata Do
		FillIncomeAndExpenseItemsInTabSection(DocumentObject, TabSectionMetadata.Name, StructureData, FillingData);
	EndDo;
	
EndProcedure

Procedure FillIncomeAndExpenseItemsInTabSection(DocumentObject, TabSectionName, StructureData, FillingData = Undefined) Export
	
	ObjectMetadata = DocumentObject.Metadata();
	
	If StructureData = Undefined Then
		StructureData = New Structure;
	EndIf;
	
	If StructureData.Property("ObjectParameters") Then
		ObjectParameters = StructureData.ObjectParameters;
	Else
		ObjectParameters = GetObjectParametersByMetadata(DocumentObject, ObjectMetadata, TabSectionName);
		StructureData.Insert("ObjectParameters", ObjectParameters);
	EndIf;
	
	TabSection = DocumentObject[TabSectionName];
	TabSectionMetadata = ObjectMetadata.TabularSections[TabSectionName];
	
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
		
		If ObjectMetadata.Attributes.Find("InventoryWarehouse") <> Undefined Then
			If TabSectionName = "Materials" Then
				ObjectParameters.Insert("StructuralUnit", DocumentObject.InventoryWarehouse);
			ElsIf ObjectMetadata.Attributes.Find("StructuralUnitReserve") <> Undefined Then
				ObjectParameters.Insert("StructuralUnit", DocumentObject.StructuralUnitReserve);
			EndIf;
		EndIf;
		
		ProductIncomeAndExpenseItems = GetProductListIncomeAndExpenseItems(StructureData);
		
		For Each Row In TabSection Do
			
			Items = ProductIncomeAndExpenseItems[Row.Products];
			For Each Item In Items Do
				ItemKey = Item.Key;
				
				IncomeAndExpenseItemInRow = TabSectionMetadata.Attributes.Find(ItemKey);
				If IncomeAndExpenseItemInRow <> Undefined Then
					
					If FillingMetadata <> Undefined
						And FillingMetadataTabSections.Find(TabSectionName) <> Undefined
						And FillingMetadataTabSections[TabSectionName].Attributes.Find(ItemKey) <> Undefined Then
						
						For Each Basis In FillingDataArray Do
							
							FilterStructure = New Structure(ProductName, Row[ProductName]);
							FoundRow = Basis[TabSectionName].FindRows(FilterStructure);
							
							If FoundRow.Count() > 0 Then
								Row[ItemKey] = FoundRow[0][ItemKey];
							EndIf;
							
						EndDo;
					EndIf;
					
					If Not ValueIsFilled(Row[ItemKey]) Then
						Row[ItemKey] = Item.Value;
						
						ItemName = Left(ItemKey, StrLen(ItemKey)-4);
						
						StructureData = New Structure("Register" + ItemName, True);
						FillPropertyValues(Row, StructureData);
					EndIf;
					
				EndIf;
			EndDo;
			
		EndDo;
		
	EndIf;
	
EndProcedure

Function GetIncomeAndExpenseItemsForFilling(StructureData) Export
	
	DocumentName = StructureData.ObjectParameters.DocumentName;
	
	GLAccountsForFilling = Documents[DocumentName].GetIncomeAndExpenseItemsStructure(StructureData);
	
	FillIncomeAndExpenseItemsDescription(StructureData, GLAccountsForFilling);
	
	Return GLAccountsForFilling;
	
EndFunction

Function GetIncomeAndExpenseItemsForFillingByParameters(Parameters) Export

	DocObject = Parameters.DocObject;
	TabName = Parameters.TabName;
	SelectedValue = Parameters.SelectedValue;
	
	If DocObject.Property(TabName) Then
		RowData = DocObject[TabName].FindByID(SelectedValue);
	Else
		RowData = SelectedValue;
	EndIf;
	
	ObjectParameters = GetObjectParameters(DocObject);
	StructureData = GetStructureData(ObjectParameters, TabName, RowData);
	
	GLAccountsForFilling = GetIncomeAndExpenseItemsForFilling(StructureData);
	GLAccountsForFilling.Insert("TabName",	TabName);
	GLAccountsForFilling.Insert("ObjectParameters", ObjectParameters);
	
	Return GLAccountsForFilling; 
	
EndFunction

Procedure FillIncomeAndExpenseItemsDescription(StructureData, IncomeAndExpenseItemsForFilling = Undefined) Export

	If IncomeAndExpenseItemsForFilling = Undefined Then
		DocumentName = StructureData.ObjectParameters.DocumentName;
		IncomeAndExpenseItemsForFilling = Documents[DocumentName].GetIncomeAndExpenseItemsStructure(StructureData);
	EndIf;
	
	IncomeAndExpenseItemsDescription = IncomeAndExpenseItemsInDocumentsServerCall.GetIncomeAndExpenseItemsDescription(IncomeAndExpenseItemsForFilling);
	FillPropertyValues(StructureData, IncomeAndExpenseItemsDescription);
	
EndProcedure

Procedure SetRegistrationAttributesVisibility(Form, AttributeNames, IsVisible = Undefined) Export
	
	AttributeNameArray = StringFunctionsClientServer.SplitStringIntoSubstringsArray(AttributeNames, ",", True, True);
	
	If IsVisible = Undefined Then
		IsVisible = RegistrationIsOptional(Form.Parameters.Key);
	EndIf;
	
	For Each AttributeName In AttributeNameArray Do
		Form.Items[AttributeName].Visible = IsVisible;
	EndDo;
	
EndProcedure

Function RegistrationIsOptional(Ref) Export
	
	TypeOfRef = TypeOf(Ref);
	
	If TypeOfRef = Type("DocumentRef.ExpenseReport")
		Or TypeOfRef = Type("DocumentRef.FixedAssetRecognition")
		Or TypeOfRef = Type("DocumentRef.OpeningBalanceEntry")
		Or TypeOfRef = Type("DocumentRef.OtherExpenses")
		Or TypeOfRef = Type("DocumentRef.Payroll")
		Or TypeOfRef = Type("DocumentRef.RetailRevaluation")
		Or TypeOfRef = Type("DocumentRef.SupplierInvoice")
		Or TypeOfRef = Type("DocumentRef.TaxAccrual")
		Or TypeOfRef = Type("DocumentRef.WorkOrder") Then
		
		Return Not GetFunctionalOption("UseDefaultTypeOfAccounting");
	EndIf;
	
	Return False;
	
EndFunction

Procedure FillCounterpartyIncomeAndExpenseItemsInRow(ObjectParameters, TS_Row, TabName = "PaymentDetails", FillingData = Undefined) Export
	
	StructureData = GetCounterpartyStructureData(ObjectParameters, TabName, TS_Row);
	
	FillCounterpartyIncomeAndExpenseItems(StructureData, , FillingData);
	FillPropertyValues(TS_Row, StructureData);
	
EndProcedure

Procedure FillCounterpartyIncomeAndExpenseItems(StructureData, IncomeAndExpenseItems = Undefined, FillingData = Undefined) Export

	If Not StructureData.Property("ObjectParameters")
		And StructureData.Property("Object") Then
		
		ObjectParameters = GetObjectParameters(StructureData.Object);
		StructureData.Insert("ObjectParameters", ObjectParameters);
		
	EndIf;
	
	If IncomeAndExpenseItems = Undefined Then
		IncomeAndExpenseItems = GetCounterpartyIncomeAndExpenseItems(StructureData);
	EndIf;
	
	DocumentName = StructureData.ObjectParameters.DocumentName;
	IncomeAndExpenseItemsForFilling = Documents[DocumentName].GetIncomeAndExpenseItemsStructure(StructureData);
	
	FillPropertyValues(IncomeAndExpenseItemsForFilling, IncomeAndExpenseItems);
	
	If ValueIsFilled(FillingData) Then
		FillPropertyValues(IncomeAndExpenseItemsForFilling, FillingData);
	EndIf;
	
	FillCounterpartyIncomeAndExpenseItemsDescription(StructureData, IncomeAndExpenseItemsForFilling);
	
EndProcedure

Procedure FillCounterpartyIncomeAndExpenseItemsDescription(StructureData, IncomeAndExpenseItemsForFilling = Undefined) Export

	If IncomeAndExpenseItemsForFilling = Undefined Then
		DocumentName = StructureData.ObjectParameters.DocumentName;
		IncomeAndExpenseItemsForFilling = Documents[DocumentName].GetIncomeAndExpenseItemsStructure(StructureData);
	EndIf;
	
	IncomeAndExpenseItemsDescription = IncomeAndExpenseItemsInDocumentsServerCall.GetIncomeAndExpenseItemsDescription(IncomeAndExpenseItemsForFilling);
	FillPropertyValues(StructureData, IncomeAndExpenseItemsDescription);
	
EndProcedure

Procedure SetConditionalAppearance(Form, TabName) Export
	
	If GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		DisabledAccountPresentation = GLAccountsInDocumentsClientServer.GetDisabledGLAccountPresentation();
		SetItemConditionalAppearance(Form, TabName, DisabledAccountPresentation, "GLAccounts");
	EndIf;
	
	DisabledAccountPresentation = IncomeAndExpenseItemsInDocumentsServerCall.GetDisabledIncomeAndExpenseItemsPresentation();
	SetItemConditionalAppearance(Form, TabName, DisabledAccountPresentation, "IncomeAndExpenseItems");
	
EndProcedure

#EndRegion

#Region Private

Function GetEmptyStructure()
	
	EmptyIncomeAndExpenseItem = Catalogs.IncomeAndExpenseItems.EmptyRef();
	
	ReturnStructure = New Structure();
	ReturnStructure.Insert("COGSItem",						EmptyIncomeAndExpenseItem);
	ReturnStructure.Insert("ExpenseItem",					EmptyIncomeAndExpenseItem);
	ReturnStructure.Insert("PurchaseReturnItem",			EmptyIncomeAndExpenseItem);
	ReturnStructure.Insert("RevenueItem",					EmptyIncomeAndExpenseItem);
	ReturnStructure.Insert("SalesReturnItem",				EmptyIncomeAndExpenseItem);
	ReturnStructure.Insert("BankFeeExpenseItem",			EmptyIncomeAndExpenseItem);
	ReturnStructure.Insert("CommissionExpenseItem",			EmptyIncomeAndExpenseItem);
	ReturnStructure.Insert("CommissionIncomeItem",			EmptyIncomeAndExpenseItem);
	ReturnStructure.Insert("DepreciationChargeItem",		EmptyIncomeAndExpenseItem);
	ReturnStructure.Insert("DiscountAllowedExpenseItem",	EmptyIncomeAndExpenseItem);
	ReturnStructure.Insert("DiscountReceivedIncomeItem",	EmptyIncomeAndExpenseItem);
	ReturnStructure.Insert("IncomeItem",					EmptyIncomeAndExpenseItem);
	ReturnStructure.Insert("InterestAccruedIncomeItem",		EmptyIncomeAndExpenseItem);
	ReturnStructure.Insert("InterestExpenseItem",			EmptyIncomeAndExpenseItem);
	ReturnStructure.Insert("PurchaseReturnItem",			EmptyIncomeAndExpenseItem);
	ReturnStructure.Insert("RevaluationItem",				EmptyIncomeAndExpenseItem);
	ReturnStructure.Insert("CostOfSalesItem",				EmptyIncomeAndExpenseItem);
	
	Return ReturnStructure;

EndFunction

Function GetProductIncomeAndExpensesEmptyStructure()
	
	EmptyIncomeAndExpenseItem = Catalogs.IncomeAndExpenseItems.EmptyRef();
	
	ReturnStructure = New Structure();
	ReturnStructure.Insert("COGSItem",						EmptyIncomeAndExpenseItem);
	ReturnStructure.Insert("ExpenseItem",					EmptyIncomeAndExpenseItem);
	ReturnStructure.Insert("PurchaseReturnItem",			EmptyIncomeAndExpenseItem);
	ReturnStructure.Insert("RevenueItem",					EmptyIncomeAndExpenseItem);
	ReturnStructure.Insert("SalesReturnItem",				EmptyIncomeAndExpenseItem);
	ReturnStructure.Insert("CostOfSalesItem",				EmptyIncomeAndExpenseItem);
	
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
	GroupsAndItemsMap.Columns.Add("Parent", New TypeDescription("CatalogRef." + CatalogName));
	GroupsAndItemsMap.Columns.Add("Item", New TypeDescription("CatalogRef." + CatalogName));
	GroupsAndItemsMap.Indexes.Add("Parent");
	
	For Each CatalogItem In CatalogItemArray Do
		NewMap = GroupsAndItemsMap.Add();
		NewMap.Parent = CatalogItem;
		NewMap.Item = CatalogItem;
	EndDo;
	
	Filter	= New Structure("Parent");
	
	RefCurrentArray = CatalogItemArray;
	
	While RefCurrentArray.Count() > 0 Do
		
		Query.SetParameter("RefArray", DeleteDuplicateArrayItems(RefCurrentArray));
		Selection = Query.Execute().Select();
		
		RefCurrentArray = New Array;
		
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

Procedure MessageCyclicLinkInObject(ObjectMetadata, DataItem)

	ObjectType = "";
	If Common.IsCatalog(ObjectMetadata) Then
		ObjectType = NStr("en = 'In the catalog'; ru = 'В справочнике';pl = 'W katalogu';es_ES = 'En el catálogo';es_CO = 'En el catálogo';tr = 'Katalogda';it = 'Nel catalogo';de = 'Im Katalog'");
	ElsIf Common.IsChartOfCharacteristicTypes(ObjectMetadata) Then
		ObjectType = NStr("en = 'In the chart of characteristic types'; ru = 'В плане видов характеристик';pl = 'Na wykresie typów charakterystycznych';es_ES = 'En el diagrama de tipos de requisitos';es_CO = 'En el diagrama de tipos de requisitos';tr = 'Özellik türü listesinde';it = 'Nel piano dei tipi di caratteristiche';de = 'Im Diagramm der Merkmalstypen'");
	EndIf;
	
	MessageText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = '%1 ""%2"", field ""%4"" contains an item ""%3"" with an incorrect parent item (such as group or parent group).
			|Specify another parent item so that the item is not parent to itself. Then try again.'; 
			|ru = '%1 ""%2"", поле ""%4"" содержит элемент ""%3"" с некорректным родительским элементом (например, группа или родительская группа).
			|Укажите другой родительский элемент, чтобы элемент не был родительским для самого себя и попробуйте снова.';
			|pl = '%1 ""%2"", pole ""%4"" zawiera pozycję ""%3"" z nieprawidłową pozycją nadrzędną (taką jak grupa lub grupa nadrzędna).
			|Określ inną pozycję nadrzędną tak, aby pozycja nie była nadrzędną sama do siebie. Następnie spróbuj ponownie.';
			|es_ES = '%1 ""%2"", campo ""%4"" contiene un artículo ""%3"" con un artículo principal incorrecto (como grupo o grupo padre).
			|Especifique otro artículo principal para que el artículo no sea padre de sí mismo. A continuación, inténtelo de nuevo.';
			|es_CO = '%1 ""%2"", campo ""%4"" contiene un artículo ""%3"" con un artículo principal incorrecto (como grupo o grupo padre).
			|Especifique otro artículo principal para que el artículo no sea padre de sí mismo. A continuación, inténtelo de nuevo.';
			|tr = '%1 ""%2"", ""%4"" alanı yanlı üst öğeli (grup veya üst grup gibi) ""%3"" öğesini içeriyor.
			|Öğenin kendi kendinin üst öğesi olmaması için başka bir üst öğe belirtip tekrar deneyin.';
			|it = '%1 ""%2"", il campo ""%4"" contiene un elemento ""%3"" con un elemento padre errato (come gruppo o gruppo padre).
			|Indicare un altro elemento padre, così che l''elemento non sia padre di se stesso. Poi riprovare.';
			|de = '%1 ""%2"", Feld ""%4"" enthält eine Position ""%3"" mit einer inkorrekten übergeordneten Position (wie eine Gruppe oder übergeordnete Gruppe).
			|Geben Sie eine andere übergeordnete Position an, damit die Position keine übergeordnete Position zu sich selbst ist. Dann versuchen Sie erneut.'"),
		ObjectType,
		ObjectMetadata.Synonym,
		DataItem,
		ObjectMetadata.StandardAttributes.Parent.Synonym);
	WriteLogEvent(
		NStr("en = 'CyclicLink'; ru = 'ЦиклическаяСсылка';pl = 'CyclicLink';es_ES = 'EnlaceCíclico';es_CO = 'EnlaceCíclico';tr = 'CyclicLink';it = 'CyclicLink';de = 'CyclicLink'", CommonClientServer.DefaultLanguageCode()),
		EventLogLevel.Warning,
		ObjectMetadata,
		DataItem,
		MessageText);
	CommonClientServer.MessageToUser(MessageText, DataItem, "Parent", "Object");

EndProcedure

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

Function GetProductIncomeAndExpenseItemsEmptyStructure()
	
	EmptyItem = Catalogs.IncomeAndExpenseItems.EmptyRef();
	
	ReturnStructure = New Structure();
	ReturnStructure.Insert("ExpenseItem", EmptyItem);
	ReturnStructure.Insert("RevenueItem", EmptyItem);
	ReturnStructure.Insert("COGSItem", EmptyItem);
	ReturnStructure.Insert("SalesReturnItem", EmptyItem);
	ReturnStructure.Insert("PurchaseReturnItem", EmptyItem);
	ReturnStructure.Insert("CostOfSalesItem", EmptyItem);
	
	Return ReturnStructure; 
	
EndFunction

Procedure FillParameters(Query, FieldName, Array)
	
	Count = 1;
	For Each Item In Array Do
		Query.SetParameter(FieldName + "Group" + Count, Item);
		Count = Count + 1;
	EndDo;
	
EndProcedure

Function FieldsWithDefaultValues()
	
	Properties = ("Condition, MaxCount");
	
	Fields = New Structure();
	
	Fields.Insert("Company", New Structure(Properties));
	Fields.Insert("TaxCategory", New Structure(Properties));
	Fields.Insert("Counterparty", New Structure(Properties));
	Fields.Insert("Contract", New Structure(Properties));
	
	Return Fields;
	
EndFunction

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
			Raise NStr("en = 'Cannot find and fill in income and expense items. The internal search includes incorrect types of conditions.
						|Contact the Administrator.'; 
						|ru = 'Не удалось найти и заполнить статьи доходов и расходов. Внутренний поиск включает некорректные типы условий.
						|Обратитесь к администратору.';
						|pl = 'Nie można znaleźć i wypełnić pozycji dochodów i rozchodów. Wewnętrzne wyszukiwanie zawiera nieprawidłowe typy warunków.
						|Skontaktuj się z Administratorem.';
						|es_ES = 'No se ha podido encontrar y rellenar los artículos de ingresos y gastos. La búsqueda interna incluye tipos de condiciones incorrectas.
						|Diríjase al administrador.';
						|es_CO = 'No se ha podido encontrar y rellenar los artículos de ingresos y gastos. La búsqueda interna incluye tipos de condiciones incorrectas.
						|Diríjase al administrador.';
						|tr = 'Gelir ve gider kalemleri bulunup doldurulamıyor. Dahili arama yanlış koşul türleri içeriyor.
						|Yöneticiye başvurun.';
						|it = 'Impossibile trovare e compilare le voci di entrata e uscita. La ricerca interna include tipi di condizione errati.
						|Contattare l''Amministratore.';
						|de = 'Fehler beim Finden und Ausfüllen in Positionen von Einnahme und Ausgaben. Die interne Suche enthält inkorrekte Typen von Bedingungen.
						|Kontaktieren Sie den Administrator.'");
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
		Raise NStr("en = 'Cannot find and fill in income and expense items. The internal search includes multiple hierarchical conditions.
					|Contact the Administrator.'; 
					|ru = 'Не удалось найти и заполнить статьи доходов и расходов. Внутренний поиск включает несколько иерархических условий.
					|Обратитесь к администратору.';
					|pl = 'Nie można znaleźć i wypełnić pozycji dochodów i rozchodów. Wewnętrzne wyszukiwanie zawiera wiele warunków hierarchicznych.
					|Skontaktuj się z Administratorem.';
					|es_ES = 'No se ha podido encontrar y rellenar los artículos de ingresos y gastos. La búsqueda interna incluye múltiples condiciones jerárquicas.
					|Diríjase al administrador.';
					|es_CO = 'No se ha podido encontrar y rellenar los artículos de ingresos y gastos. La búsqueda interna incluye múltiples condiciones jerárquicas.
					|Diríjase al administrador.';
					|tr = 'Gelir ve gider kalemleri bulunup doldurulamıyor. Dahili arama birden fazla hiyerarşik koşul içeriyor.
					|Yöneticiye başvurun.';
					|it = 'Impossibile trovare e compilare le voci di entrata e uscita. La ricerca interna include condizioni gerarchiche multiple.
					|Contattare l''Amministratore.';
					|de = 'Fehler beim Finden und Ausfüllen in Positionen von Einnahme und Ausgaben. Die interne Suche enthält mehrfache hierarchische Bedingungen.
					|Kontaktieren Sie den Administrator.'");
	EndIf;
	
	If QueryText <> "" Then
		QueryText = QueryText + DriveClientServer.GetQueryUnion();
		NewQueryText = StrReplace(NewQueryText, " ALLOWED", "");
	EndIf;
	
	QueryText = QueryText + NewQueryText;
	
EndProcedure

Function QueryTemplate()
	
	Return 
	"SELECT ALLOWED
	|	&Priority AS Priority,
	|	Table.DiscountAllowedItem AS DiscountAllowedItem,
	|	Table.DiscountReceivedItem AS DiscountReceivedItem
	|FROM
	|	InformationRegister.CounterpartyIncomeAndExpenseItems AS Table
	|WHERE
	|	&Condition";
	
EndFunction

Function GetProductsArray(TabSection, ProductName = "Products")
	
	TableProducts = TabSection.Unload(, ProductName);
	ProductsArray = TableProducts.UnloadColumn(ProductName);
	
	Return ProductsArray;
	
EndFunction

Function GetObjectParametersByMetadata(DocumentObject, ObjectMetadata, TabSectionName = "Header")

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
	
	If ObjectMetadata.Attributes.Find("StructuralUnitPayee") <> Undefined Then
		ObjectParameters.Insert("StructuralUnitPayee", DocumentObject.StructuralUnitPayee);
	EndIf;
	
	If TabSectionName <> "Header" Then
		
		If ObjectMetadata.TabularSections[TabSectionName].Attributes.Find("RevenueItem") <> Undefined Then
			ObjectParameters.Insert("RevenueItem");
		EndIf;
		
		If ObjectMetadata.TabularSections[TabSectionName].Attributes.Find("COGSItem") <> Undefined Then
			ObjectParameters.Insert("COGSItem");
		EndIf;
		
		If ObjectMetadata.TabularSections[TabSectionName].Attributes.Find("CostOfSalesItem") <> Undefined Then
			ObjectParameters.Insert("CostOfSalesItem");
		EndIf;
		
		If ObjectMetadata.TabularSections[TabSectionName].Attributes.Find("ExpenseItem") <> Undefined Then
			ObjectParameters.Insert("ExpenseItem");
		EndIf;
		
		If ObjectMetadata.TabularSections[TabSectionName].Attributes.Find("IncomeItem") <> Undefined Then
			ObjectParameters.Insert("IncomeItem");
		EndIf;
		
		If ObjectMetadata.TabularSections[TabSectionName].Attributes.Find("RevaluationItem") <> Undefined Then
			ObjectParameters.Insert("RevaluationItem");
		EndIf;
		
		If ObjectMetadata.TabularSections[TabSectionName].Attributes.Find("PurchaseReturnItem") <> Undefined Then
			ObjectParameters.Insert("PurchaseReturnItem");
		EndIf;
		
		If ObjectMetadata.TabularSections[TabSectionName].Attributes.Find("SalesReturnItem") <> Undefined Then
			ObjectParameters.Insert("SalesReturnItem");
		EndIf;
		
		If ObjectMetadata.TabularSections[TabSectionName].Attributes.Find("DepreciationChargeItem") <> Undefined Then
			ObjectParameters.Insert("DepreciationChargeItem");
		EndIf;
		
		If ObjectMetadata.TabularSections[TabSectionName].Attributes.Find("DiscountReceivedIncomeItem") <> Undefined Then
			ObjectParameters.Insert("DiscountReceivedIncomeItem");
		EndIf;
		
		If ObjectMetadata.TabularSections[TabSectionName].Attributes.Find("DiscountAllowedExpenseItem") <> Undefined Then
			ObjectParameters.Insert("DiscountAllowedExpenseItem");
		EndIf;
		
		If ObjectMetadata.TabularSections[TabSectionName].Attributes.Find("ThirdPartyPayment") <> Undefined Then
			ObjectParameters.Insert("ThirdPartyPayment");
		EndIf;
		
	EndIf;

	If ObjectMetadata.Attributes.Find("BankFeeExpenseItem") <> Undefined Then
		ObjectParameters.Insert("BankFeeExpenseItem", DocumentObject.BankFeeExpenseItem);
	EndIf;
	
	If ObjectMetadata.Attributes.Find("CommissionExpenseItem") <> Undefined Then
		ObjectParameters.Insert("CommissionExpenseItem", DocumentObject.CommissionExpenseItem);
	EndIf;
	
	If ObjectMetadata.Attributes.Find("InterestExpenseItem") <> Undefined Then
		ObjectParameters.Insert("InterestExpenseItem", DocumentObject.InterestExpenseItem);
	EndIf;
	
	If ObjectMetadata.Attributes.Find("CommissionIncomeItem") <> Undefined Then
		ObjectParameters.Insert("CommissionIncomeItem", DocumentObject.CommissionIncomeItem);
	EndIf;
	
	If ObjectMetadata.Attributes.Find("InterestIncomeItem") <> Undefined Then
		ObjectParameters.Insert("InterestIncomeItem", DocumentObject.InterestIncomeItem);
	EndIf;
	
	If ObjectMetadata.Attributes.Find("ExpenseItem") <> Undefined Then
		ObjectParameters.Insert("ExpenseItem", DocumentObject.ExpenseItem);
	EndIf;
	
	If ObjectMetadata.Attributes.Find("IncomeItem") <> Undefined Then
		ObjectParameters.Insert("IncomeItem", DocumentObject.IncomeItem);
	EndIf;
	
	Return ObjectParameters;
	
EndFunction

Function GetCheckBoxStructure()
	
	EmptyIncomeAndExpenseItem = Catalogs.IncomeAndExpenseItems.EmptyRef();
	
	ReturnStructure = New Structure();
	ReturnStructure.Insert("RegisterRevaluation",				False);
	ReturnStructure.Insert("RegisterIncome",					False);
	ReturnStructure.Insert("RegisterExpense",					False);
	ReturnStructure.Insert("RegisterDepreciationCharge",		False);
	ReturnStructure.Insert("RegisterBankFeeExpense",			False);
	
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

Procedure SetItemConditionalAppearance(Form, TabName, DisabledAccountPresentation, ItemName)
	
	NewConditionalAppearance = Form.ConditionalAppearance.Items.Add();
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"Object." + TabName + "." + ItemName,
		DisabledAccountPresentation,
		DataCompositionComparisonType.Equal);
	
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, TabName + ItemName);
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "ReadOnly", True);
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "TextColor", StyleColors.UnavailableTabularSectionTextColor);
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "Enabled", False);
	
EndProcedure

#EndRegion