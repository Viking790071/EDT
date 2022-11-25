#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	GenerateDescription(Cancel);
	
	If AdditionalProperties.Property("UpdateDeletionMark") Then
		UpdateDeletionMark();
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

Procedure GenerateDescription(Cancel)
	
	DescriptionArray = New Array;
	
	If ValueIsFilled(Project) Then
		DescriptionArray.Add(String(Project));
	EndIf;
	
	// begin Drive.FullVersion
	If ValueIsFilled(ProductionOrder) Then
		
		OrderData = Common.ObjectAttributesValues(ProductionOrder, "Number, Date");
		
		If GetFunctionalOption("UseCustomizableNumbering") Then
			NumberPresentation = TrimAll(OrderData.Number);
		Else
			NumberPresentation = ObjectPrefixationClientServer.GetNumberForPrinting(OrderData.Number, True, True);
		EndIf;
		
		DocumentMetadata = ProductionOrder.Metadata();
		MetadataPresentation = DocumentMetadata.ExtendedObjectPresentation;
		If IsBlankString(MetadataPresentation) Then
			MetadataPresentation = DocumentMetadata.ObjectPresentation;
		EndIf;
		If IsBlankString(MetadataPresentation) Then
			MetadataPresentation = DocumentMetadata.Presentation();
		EndIf;
		
		ProductionOrderPresentation = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '%1 %2 dated %3 %4'; ru = '%1 %2 от %3 %4';pl = '%1 %2 z dn. %3 %4';es_ES = '%1 %2 fechado %3 %4';es_CO = '%1 %2 fechado %3 %4';tr = '%1 %2 tarihli %3 %4';it = '%1 %2 con data %3 %4';de = '%1 %2 datiert %3 %4'"),
			MetadataPresentation,
			NumberPresentation,
			Format(OrderData.Date, "DLF=D"),
			"");
		
		DescriptionArray.Add(ProductionOrderPresentation);
		
	EndIf;
	// end Drive.FullVersion
	
	If ValueIsFilled(Products) Then
		DescriptionArray.Add(String(Products));
	EndIf;
	
	If DescriptionArray.Count() = 0 Then
		
		ErrorMessage = NStr("en = 'Cannot save Cost object. At least one of the fields Project, Production order or Product should be filled in.'; ru = 'Невозможно сохранить объект затрат. Необходимо заполнить хотя бы одно из полей ""Проект"", ""Заказ на производство"" или ""Номенклатура"".';pl = 'Nie można uzapisać Obiektu kosztów. Należy wypełnić co najmniej jedno z pól Projekt, Zlecenie produkcyjne lub Produkt.';es_ES = 'No puede guardar el Objeto de coste. Debe rellenarse al menos uno de los campos Proyecto, Orden de producción o Producto.';es_CO = 'No puede guardar el Objeto de coste. Debe rellenarse al menos uno de los campos Proyecto, Orden de producción o Producto.';tr = 'Maliyet nesnesi kaydedilemiyor. Proje, Üretim emri ve Ürün alanlarından en az biri doldurulmalı.';it = 'Impossibile salvare Costo oggetto. Almeno uno dei campi Progetto, Ordine di produzione o Articolo devono essere compilati.';de = 'Kostenträger kann nicht gespeichert werden. Zumindest ein der Felder ""Projekt"", ""Produktionsbestellung"" oder ""Produkt"" soll ausgefüllt sein.'");
		
		CommonClientServer.MessageToUser(ErrorMessage, , , , Cancel);
		
		Return;
		
	EndIf;
	
	If ValueIsFilled(Characteristic) Then
		DescriptionArray.Add(String(Characteristic));
	EndIf;
	
	Description = StringFunctionsClientServer.StringFromSubstringArray(DescriptionArray, "; ");
	
EndProcedure

Procedure UpdateDeletionMark()
	
	Query = New Query;
	
	Query.SetParameter("Project", Project);
	Query.SetParameter("ProductionOrder", ProductionOrder);
	Query.SetParameter("Products", Products);
	Query.SetParameter("Characteristic", Characteristic);
	
	Query.Text =
	"SELECT
	|	Projects.DeletionMark AS DeletionMark
	|INTO TT_DeletionMarks
	|FROM
	|	Catalog.Projects AS Projects
	|WHERE
	|	Projects.Ref = &Project
	|
	|UNION ALL
	|
	|SELECT
	|	Products.DeletionMark
	|FROM
	|	Catalog.Products AS Products
	|WHERE
	|	Products.Ref = &Products
	|
	|UNION ALL
	|
	|SELECT
	|	ProductsCharacteristics.DeletionMark
	|FROM
	|	Catalog.ProductsCharacteristics AS ProductsCharacteristics
	|WHERE
	|	ProductsCharacteristics.Ref = &Characteristic
	// begin Drive.FullVersion
	|
	|UNION ALL
	|
	|SELECT
	|	ProductionOrder.DeletionMark
	|FROM
	|	Document.ProductionOrder AS ProductionOrder
	|WHERE
	|	ProductionOrder.Ref = &ProductionOrder
	// end Drive.FullVersion
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MAX(TT_DeletionMarks.DeletionMark) AS DeletionMark
	|FROM
	|	TT_DeletionMarks AS TT_DeletionMarks";
	
	Sel = Query.Execute().Select();
	
	If Sel.Next() Then
		DeletionMark = Sel.DeletionMark;
	EndIf;
	
EndProcedure

#EndRegion

#EndIf