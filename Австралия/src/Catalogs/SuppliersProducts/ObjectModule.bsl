#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED TOP 1
	|	SuppliersProducts.Ref
	|FROM
	|	Catalog.SuppliersProducts AS SuppliersProducts
	|WHERE
	|	SuppliersProducts.Owner = &Owner
	|	AND SuppliersProducts.SKU = &SKU
	|	AND SuppliersProducts.Products = &Products
	|	AND SuppliersProducts.Characteristic = &Characteristic
	|	AND SuppliersProducts.Ref <> &CurrentRef";
	
	Query.SetParameter("Owner", Owner);
	Query.SetParameter("SKU", SKU);
	Query.SetParameter("Products", Products);
	Query.SetParameter("Characteristic", Characteristic);
	Query.SetParameter("CurrentRef", Ref);
	
	Result = Query.Execute();
	If Not Result.IsEmpty() Then
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Product cross-reference ""%1,%2 - %3,%4"" already exists.'; ru = 'Номенклатура поставщиков ""%1,%2 - %3,%4"" уже существует.';pl = 'Powiązane informacje o produkcie ""%1,%2 - %3,%4"" już istnieją.';es_ES = 'El Producto con referencias cruzadas %1,%2 - %3,%4 ya existe.';es_CO = 'El Producto con referencias cruzadas %1,%2 - %3,%4 ya existe.';tr = '""%1,%2 - %3,%4"" ürün çapraz referansı zaten mevcut.';it = 'Il riferimento incrociato dell''articolo ""%1,%2 - %3, %4"" esiste già.';de = 'Die Produktherstellartikelnummer ""%1,%2 - %3,%4"" ist bereits vorhanden.'"),
			Owner, SKU, Products, Characteristic);
			
		CommonClientServer.MessageToUser(MessageText,,,,Cancel);
		
	EndIf;
	
	EnumProductsType = Common.ObjectAttributeValue(Products, "ProductsType");
	
	If Not ValueIsFilled(ThisObject.ProductsType)
		Or ThisObject.ProductsType <> EnumProductsType Then
		
		ThisObject.ProductsType = EnumProductsType;
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf