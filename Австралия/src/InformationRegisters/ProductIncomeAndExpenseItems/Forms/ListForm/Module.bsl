
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	IsFilterSet = False;
	
	If Parameters.Property("Filter") And Parameters.Filter.Count() Then
		
		IsFilterSet = True;
		
		Parameters.Filter.Property("Product", Product);
		Parameters.Filter.Property("ProductCategory", ProductCategory);
		
	EndIf;
	
	Items.ShowRelevantSettings.Visible = IsFilterSet;
	
	FormManagement();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ShowRelevantSettingsOnChange(Item)
	FormManagement();
EndProcedure

#EndRegion 

#Region Private

&AtServer
Procedure FormManagement()
	
	FilterItems = List.Filter.Items;
	FilterItems.Clear();
	
	If ShowRelevantSettings Then
		
		If ValueIsFilled(Product) Then
			
			ProductArray = New Array();
			ProductArray.Add(Catalogs.Products.EmptyRef());
			ProductArray.Add(Product);
			
			GroupList = GLAccountsInDocuments.GetHigherGroupList(Product);
			For Each Item In GroupList Do
				ProductArray.Add(Item);
			EndDo;
			
			FilterItem = FilterItems.Add(Type("DataCompositionFilterItem"));
			FilterItem.LeftValue = New DataCompositionField("Product");
			FilterItem.ComparisonType = DataCompositionComparisonType.InList;
			FilterItem.RightValue = ProductArray;
			
		EndIf;
		
		If ValueIsFilled(ProductCategory) Then
			
			ProductCategoryArray = New Array();
			ProductCategoryArray.Add(Catalogs.ProductsCategories.EmptyRef());
			ProductCategoryArray.Add(Common.ObjectAttributeValue(Product, "ProductsCategory"));
			ProductCategoryArray.Add(ProductCategory);
			
			FilterItem = FilterItems.Add(Type("DataCompositionFilterItem"));
			FilterItem.LeftValue = New DataCompositionField("ProductCategory");
			FilterItem.ComparisonType = DataCompositionComparisonType.InList;
			FilterItem.RightValue = ProductCategoryArray;
			
		EndIf;
		
	Else
		
		If ValueIsFilled(Product) Then
			
			FilterItem = FilterItems.Add(Type("DataCompositionFilterItem"));
			FilterItem.LeftValue = New DataCompositionField("Product");
			FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
			FilterItem.RightValue = Product;
			
		EndIf;
		
		If ValueIsFilled(ProductCategory) Then 
			
			FilterItem = FilterItems.Add(Type("DataCompositionFilterItem"));
			FilterItem.LeftValue = New DataCompositionField("ProductCategory");
			FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
			FilterItem.RightValue = ProductCategory;
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion 