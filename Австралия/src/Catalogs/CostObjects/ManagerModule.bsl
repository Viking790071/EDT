#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Function GetCostObject(Project, ProductionOrder, Products, Characteristic) Export
	
	If Not ValueIsFilled(Project)
		And Not ValueIsFilled(ProductionOrder)
		And Not ValueIsFilled(Products) Then
		
		ErrorMessage = NStr("en = 'Cannot create Cost object. At least one of the fields Project, Production order or Product should be filled in.'; ru = 'Невозможно создать объект затрат. Необходимо заполнить хотя бы одно из полей ""Проект"", ""Заказ на производство"" или ""Номенклатура"".';pl = 'Nie można utworzyć Obiektu kosztów. Należy wypełnić co najmniej jedno z pól Projekt, Zlecenie produkcyjne lub Produkt.';es_ES = 'No puede crear el Objeto de coste. Debe rellenarse al menos uno de los campos Proyecto, Orden de producción o Producto.';es_CO = 'No puede crear el Objeto de coste. Debe rellenarse al menos uno de los campos Proyecto, Orden de producción o Producto.';tr = 'Maliyet nesnesi oluşturulamıyor. Proje, Üretim emri ve Ürün alanlarından en az biri doldurulmalı.';it = 'Impossibile creare Costo oggetto. Almeno uno dei campi Progetto, Ordine di produzione o Articolo devono essere compilati.';de = 'Kostenträger kann nicht erstellt werden. Zumindest ein der Felder ""Produkt"", ""Produktionsauftrag"" oder ""Produkt"" soll ausgefüllt sein.'");
		CommonClientServer.MessageToUser(ErrorMessage);
		
		Return Undefined;
		
	EndIf;
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	CostObjects.Ref AS Ref
	|FROM
	|	Catalog.CostObjects AS CostObjects
	|WHERE
	|	CostObjects.Project = &Project
	|	AND CostObjects.ProductionOrder = &ProductionOrder
	|	AND CostObjects.Products = &Products
	|	AND CostObjects.Characteristic = &Characteristic";
	
	Query.SetParameter("Project", Project);
	Query.SetParameter("ProductionOrder", ProductionOrder);
	Query.SetParameter("Products", Products);
	Query.SetParameter("Characteristic", Characteristic);
	
	Sel = Query.Execute().Select();
	
	If Sel.Next() Then
		
		Return Sel.Ref;
		
	Else
		
		Object = CreateItem();
		Object.Project = Project;
		Object.ProductionOrder = ProductionOrder;
		Object.Products = Products;
		Object.Characteristic = Characteristic;
		Try
			
			Object.Write();
			Return Object.Ref;
			
		Except
			
			ErrorMessage = NStr("en = 'Cannot create Cost object: %1'; ru = 'Невозможно создать Объект затрат: %1';pl = 'Nie można utworzyć Obiektu kosztów: %1';es_ES = 'No puede crear el Objeto de coste: %1';es_CO = 'No puede crear el Objeto de coste: %1';tr = 'Maliyet hedefi oluşturulamıyor: %1';it = 'Impossibile creare Costo oggetto: %1';de = 'Kostenträger kann nicht erstellt werden: %1'");
			ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(
				ErrorMessage,
				ErrorDescription());
			
			CommonClientServer.MessageToUser(ErrorMessage);
			
			Return Undefined;
			
		EndTry;
		
	EndIf;
	
EndFunction

Procedure UpdateLinkedCostObjectsData(Ref) Export
	
	If TypeOf(Ref) = Type("CatalogRef.Projects") Then
		SelectUpdateDescription("Project", Ref);
	// begin Drive.FullVersion
	ElsIf TypeOf(Ref) = Type("DocumentRef.ProductionOrder") Then
		SelectUpdateDescription("ProductionOrder", Ref);
	// end Drive.FullVersion
	ElsIf TypeOf(Ref) = Type("CatalogRef.Products") Then
		SelectUpdateDescription("Products", Ref);
	ElsIf TypeOf(Ref) = Type("CatalogRef.ProductsCharacteristics") Then
		SelectUpdateDescription("Characteristic", Ref);
	EndIf;
	
EndProcedure

#Region LibrariesHandlers

#Region ObjectAttributesLock

// StandardSubsystems.ObjectAttributesLock

// See ObjectsAttributesEditBlockedOverridable.OnDefineObjectsWithLockedAttributes. 
Function GetObjectAttributesToLock() Export
	
	AttributesToLock = New Array;
	AttributesToLock.Add("Project");
	AttributesToLock.Add("ProductionOrder");
	AttributesToLock.Add("Products");
	AttributesToLock.Add("Characteristic");
	Return AttributesToLock;
	
EndFunction

// End StandardSubsystems.ObjectAttributesLock

#EndRegion

#EndRegion

#EndRegion

#Region Private

Procedure SelectUpdateDescription(AttributeName, AttributeValue)
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	CostObjects.Ref AS Ref
	|FROM
	|	Catalog.CostObjects AS CostObjects
	|WHERE
	|	&Filter";
	
	Query.SetParameter(AttributeName, AttributeValue);
	
	Filter = StringFunctionsClientServer.SubstituteParametersToString("CostObjects.%1 = &%1", AttributeName);
	Query.Text = StrReplace(Query.Text, "&Filter", Filter);
	
	Sel = Query.Execute().Select();
	While Sel.Next() Do
		
		Try
			Object = Sel.Ref.GetObject();
			Object.AdditionalProperties.Insert("UpdateDeletionMark", True);
			Object.Write();
		Except
		EndTry;
		
	EndDo;
	
EndProcedure

#EndRegion

#EndIf