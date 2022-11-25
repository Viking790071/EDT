
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	FillParameters(Parameters.FillingValues);
	DefaultIncomeAndExpenseItems = GetDefaultIncomeAndExpenseItems();
	FormManagment();
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	If Modified
		And Not UserWasQuestioned
		And NeedToFillEmptyIncomeAndExpenseItems() Then
		
		Text = NStr("en = 'You have not specified some of the inventory and expense items.
			|They will be automatically filled in with the default inventory and expense items.'; 
			|ru = 'Вы не указали некоторые статьи запасов и расходов.
			|Они будут автоматически заполнены статьями запасов и расходов по умолчанию.';
			|pl = 'Nie określono niektórych z pozycji zapasów i rozchodów.
			|Zostaną one automatycznie wypełnione domyślnymi pozycjami zapasów i rozchodów.';
			|es_ES = 'No se han especificado algunos de los artículos de inventario y gastos.
			|Se rellenarán automáticamente con los artículos de inventario y gastos por defecto.';
			|es_CO = 'No se han especificado algunos de los artículos de inventario y gastos.
			|Se rellenarán automáticamente con los artículos de inventario y gastos por defecto.';
			|tr = 'Stok ve gider kalemlerinden bazılarını belirtmediniz.
			|Bunlar varsayılan stok ve gider kalemleriyle otomatik olarak doldurulacak.';
			|it = 'Non sono state specificate alcune scorte e voci di uscita.
			|Saranno compilate automaticamente con le scorte e voci di uscita predefinite.';
			|de = 'Sie haben einige der Positionen von Bestand und Kosten nicht angegeben.
			|Sie werden automatisch mit den Standardpositionen von Bestand und Kosten ausgefüllt.'");
		Notification = New NotifyDescription("FillCheckEnd", ThisObject, WriteParameters);
		ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
		
		Cancel = True;
		UserWasQuestioned = False;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ProductCategoryOnChange(Item)
	ProductCategoryOnChangeAtServer();
EndProcedure

&AtClient
Procedure ProductOnChange(Item)
	ProductOnChangeAtServer();
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure FillParameters(FillingValues)
	
	For Each Parameter In FillingValues Do
		
		If TypeOf(Parameter.Value) <> Type("ValueList") Then
			Continue;
		EndIf;
		
		Array = Parameter.Value[0].Value;
		
		For Each Item In Array Do
			If ValueIsFilled(Item) Then
				Record[Parameter.Key] = Item;
				Break;
			EndIf;
		EndDo;
	EndDo;
	
EndProcedure

&AtServer
Procedure FormManagment()

	ProductType = Common.ObjectAttributeValue(Record.Product, "ProductsType");
	IsEmptyProductType = Not ValueIsFilled(ProductType);
	
	IsInventoryItem = (ProductType = Enums.ProductsTypes.InventoryItem)
		Or IsEmptyProductType;
	
	Items.StructuralUnit.Visible = IsInventoryItem;
	Items.SalesReturnItem.Visible = IsInventoryItem;
	Items.PurchaseReturnItem.Visible = IsInventoryItem;
	
	Items.COGSItem.Title = ?(IsInventoryItem,
		NStr("en = 'COGS item'; ru = 'Статья себестоимости продаж';pl = 'Pozycja KWS';es_ES = 'Artículo de precio de coste';es_CO = 'Artículo de precio de coste';tr = 'SMM kalemi';it = 'Voce di costo del venduto';de = 'Position von Wareneinsatz'"),
		NStr("en = 'Cost of sales item'; ru = 'Статья себестоимости продаж';pl = 'Pozycja kosztu własnego sprzedaży';es_ES = 'Artículo del coste de las ventas';es_CO = 'Artículo del coste de las ventas';tr = 'Satış maliyeti kalemi';it = 'Costo dell''elemento di vendita';de = 'Position von Umsatzkosten'"));
	
	ChoiceParameterLinks = New Array;
	If Not Record.ProductCategory.IsEmpty() Then
		ChoiceParameterLinks.Add(New ChoiceParameterLink("Filter.ProductsCategory", "Record.ProductCategory"));
	EndIf;
	
	Items.Product.ChoiceParameterLinks = New FixedArray(ChoiceParameterLinks);
	
EndProcedure

&AtServer
Procedure ProductCategoryOnChangeAtServer()
	
	CurrentProductCategory = Common.ObjectAttributeValue(Record.Product, "ProductsCategory");
	
	If Record.ProductCategory <> CurrentProductCategory Then
		Record.Product = Catalogs.Products.EmptyRef();
		ProductOnChangeAtServer();
	EndIf;
	
EndProcedure

&AtServer
Procedure ProductOnChangeAtServer()
	
	FormManagment();
	
EndProcedure

&AtClient
Procedure FillCheckEnd(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult = DialogReturnCode.Yes Then
		FillEmptyIncomeAndExpenses();
	EndIf;
	
	UserWasQuestioned = True;
	Write();
	
EndProcedure

&AtClient
Procedure FillEmptyIncomeAndExpenses()
	
	For Each InventoryAndExpensesItem In ProductTypeDefaultIncomeAndExpenseItems Do
		
		If Not ValueIsFilled(Record[InventoryAndExpensesItem.Key]) Then
			Record[InventoryAndExpensesItem.Key] = ProductTypeDefaultIncomeAndExpenseItems[InventoryAndExpensesItem.Key];
		EndIf;
		
	EndDo;
	
EndProcedure

&AtServerNoContext
Function GetDefaultIncomeAndExpenseItems()

	EmptyProduct = Catalogs.Products.EmptyRef();
	StructureData = New Structure("ObjectParameters, Products, WithoutCheckBoxes", New Structure, EmptyProduct, True);
	IncomeAndExpenseItemsMap = IncomeAndExpenseItemsInDocuments.GetProductListIncomeAndExpenseItems(StructureData);
	DefaultIncomeAndExpenseItems = IncomeAndExpenseItemsMap[EmptyProduct];
	
	Return DefaultIncomeAndExpenseItems;

EndFunction

&AtClient
Function NeedToFillEmptyIncomeAndExpenseItems()

	ProductTypeDefaultIncomeAndExpenseItems = GetProductTypeDefaultIncomeAndExpenseItems();
	
	For Each IncomeAndExpenseItem In ProductTypeDefaultIncomeAndExpenseItems Do
		
		If Not ValueIsFilled(Record[IncomeAndExpenseItem.Key])
			And ValueIsFilled(IncomeAndExpenseItem.Value) Then
			Return True;
			Break;
		EndIf;
			
	EndDo;
	
	Return False;

EndFunction

&AtClient
Function GetProductTypeDefaultIncomeAndExpenseItems()
	
	If Not IsInventoryItem Then
		ProductTypeIncomeAndExpenseItems = New Structure("ExpenseItem, RevenueItem, COGSItem");
		FillPropertyValues(ProductTypeIncomeAndExpenseItems, DefaultIncomeAndExpenseItems);
	Else
		ProductTypeIncomeAndExpenseItems = DefaultIncomeAndExpenseItems;
	EndIf;
	
	Return ProductTypeIncomeAndExpenseItems;
	
EndFunction

#EndRegion
