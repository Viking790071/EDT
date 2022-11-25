#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	PriceList.ProductsPresentation.Load(Parameters.ProductsPresentation.Unload());
	PriceList.BalancesPresentation = Parameters.BalancesPresentation;
	PriceList.PriceListPrintingVariant = Parameters.PriceListPrintingVariant;
	
	PriceList.ColumnsCount = Parameters.ColumnsCount;
	PriceList.PictureWidth = Parameters.PictureWidth;
	PriceList.PictureHeight = Parameters.PictureHeight;
	PriceList.ResizeProportionally = Parameters.ResizeProportionally;
	
	CommonClientServer.SetFormItemProperty(Items, "PictureHeight", "Enabled", NOT PriceList.ResizeProportionally);
	
	ThisIsTiles = (PriceList.PriceListPrintingVariant = Enums.PriceListPrintingVariants.Tiles);
	
	For Each Row In PriceList.ProductsPresentation Do
		
		If Row.ProductsAttribute = "SKU" Then 
			
			CodeArticle = ?(Row.Use, "SKU", "Code");
			
		EndIf;
		
		If Row.Use Then
			
			If Row.ProductsAttribute = "Description"
				OR Row.ProductsAttribute = "DescriptionFull" Then
				
				Presentation = Row.ProductsAttribute;
				
			ElsIf Row.ProductsAttribute = "Comment" Then
				
				Presentation = "Comment";
				
			EndIf;
			
		EndIf;
		
		If Row.ProductsAttribute = "Characteristic" AND ThisIsTiles Then
			
			DisplayCharacteristics = Row.Use;
			
		EndIf;
		
	EndDo;
	
	If NOT ThisIsTiles Then
		
		CommonClientServer.SetFormItemProperty(Items, "PagePicture", "Visible", False);
		CommonClientServer.SetFormItemProperty(Items, "GroupColumnsSettings", "Visible", False);
		CommonClientServer.SetFormItemProperty(Items, "Pages", "PagesRepresentation", FormPagesRepresentation.None);
		
	EndIf;
	
	GroupCharacteristicsVisible = (GetFunctionalOption("UseCharacteristics") AND ThisIsTiles);
	
	CommonClientServer.SetFormItemProperty(Items, "GroupCharacteristics", "Visible", GroupCharacteristicsVisible);
	
	EditingAvailable = AccessRight("Edit", Metadata.Catalogs.PriceLists);
	CommonClientServer.SetFormItemProperty(Items, "Pages", "ReadOnly", NOT EditingAvailable);
	
	If CommonClientServer.IsMobileClient() Then
		
		FormItemCommandBarLabelLocation = FormItemCommandBarLabelLocation.Auto;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure CodeArticleOnChange(Item)
	
	RowSet = PriceList.ProductsPresentation.FindRows(New Structure("ProductsAttribute", "Code"));
	RowSet[0].Use = (CodeArticle = "Code");
	
	RowSet = PriceList.ProductsPresentation.FindRows(New Structure("ProductsAttribute", "SKU"));
	RowSet[0].Use = (CodeArticle = "SKU");
	
EndProcedure

&AtClient
Procedure PresentationOnChange(Item)
	
	RowSet = PriceList.ProductsPresentation.FindRows(New Structure("ProductsAttribute", "Description"));
	RowSet[0].Use = (Presentation = "Description");
	
	RowSet = PriceList.ProductsPresentation.FindRows(New Structure("ProductsAttribute", "DescriptionFull"));
	RowSet[0].Use = (Presentation = "DescriptionFull");
	
	RowSet = PriceList.ProductsPresentation.FindRows(New Structure("ProductsAttribute", "Comment"));
	RowSet[0].Use = (Presentation = "Comment");
	
EndProcedure

&AtClient
Procedure PictureWidthOnChange(Item)
	
	If PriceList.ResizeProportionally Then
		
		PriceList.PictureHeight = PriceList.PictureWidth * 5;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ResizeProportionallyOnChange(Item)
	
	CommonClientServer.SetFormItemProperty(Items, "PictureHeight", "Enabled", NOT PriceList.ResizeProportionally);
	
	If PriceList.ResizeProportionally Then
		
		PriceList.PictureHeight = PriceList.PictureWidth * 5;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure DisplayCharacteristicsOnChange(Item)
	
	RowSet = PriceList.ProductsPresentation.FindRows(New Structure("ProductsAttribute", "Characteristic"));
	RowSet[0].Use = DisplayCharacteristics;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure OK(Command)
	
	RowArray = PriceList.ProductsPresentation.FindRows(New Structure("Use", True));
	
	If RowArray.Count() = 0 Then
		
		CommonClientServer.MessageToUser(NStr("en='You must select at least one field.'; ru = 'Выберите, как минимум, одно поле.';pl = 'Musisz wybrać co najmniej jedno pole.';es_ES = 'Debe seleccionar por lo menos un campo.';es_CO = 'Debe seleccionar por lo menos un campo.';tr = 'En az bir alan seçmelisiniz.';it = 'Dovete selezionare almeno un campo.';de = 'Sie müssen mindestens ein Feld auswählen.'"));
		
	Else
		
		CloseParameter = New Structure;
		CloseParameter.Insert("CloseResult",			DialogReturnCode.OK);
		CloseParameter.Insert("ProductsPresentation",	PriceList.ProductsPresentation);
		CloseParameter.Insert("BalancesPresentation",	PriceList.BalancesPresentation);
		CloseParameter.Insert("ColumnsCount",			PriceList.ColumnsCount);
		CloseParameter.Insert("PictureWidth",			PriceList.PictureWidth);
		CloseParameter.Insert("PictureHeight",			PriceList.PictureHeight);
		CloseParameter.Insert("ResizeProportionally",	PriceList.ResizeProportionally);
		
		Close(CloseParameter);
		
	EndIf;
	
EndProcedure

#EndRegion