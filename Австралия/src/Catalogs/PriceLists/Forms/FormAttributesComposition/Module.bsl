#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	PriceList.ProductsPresentation.Load(Parameters.ProductsPresentation.Unload());
	PriceList.BalancesPresentation = Parameters.BalancesPresentation;
	
	PriceList.ColumnsCount = Parameters.ColumnsCount;
	PriceList.PictureWidth = Parameters.PictureWidth;
	PriceList.PictureHeight = Parameters.PictureHeight;
	PriceList.ResizeProportionally = Parameters.ResizeProportionally;
	
	ArrayColumns = PriceList.ProductsPresentation.FindRows(New Structure("ProductsAttribute", "FreeBalance"));
	CommonClientServer.SetFormItemProperty(Items, "PriceListBalancesPresentation", "Enabled", ArrayColumns[0].Use);
	
	ArrayColumns = PriceList.ProductsPresentation.FindRows(New Structure("ProductsAttribute", "Picture"));
	UsePictures = ArrayColumns[0].Use;
	
	If UsePictures Then
		
		CommonClientServer.SetFormItemProperty(Items, "PriceListPictureHeight", "Enabled", NOT PriceList.ResizeProportionally);
		
	Else
		
		CommonClientServer.SetFormItemProperty(Items, "PriceListPictureWidth", "Enabled", False);
		CommonClientServer.SetFormItemProperty(Items, "PriceListPictureHeight", "Enabled", False);
		CommonClientServer.SetFormItemProperty(Items, "PriceListResizeProportionally", "Enabled", False);
		
	EndIf;
	
	UseCharacteristics = GetFunctionalOption("UseCharacteristics");
	ArrayRows = PriceList.ProductsPresentation.FindRows(New Structure("ProductsAttribute", "Characteristic"));
	ArrayRows[0].ServiceVisibilityManagement = UseCharacteristics;
	
	Items.PriceListProductsPresentation.RowFilter = New FixedStructure("ServiceVisibilityManagement", True);
	
	If CommonClientServer.IsMobileClient() Then
		
		FormItemCommandBarLabelLocation = FormItemCommandBarLabelLocation.Auto;
		CommonClientServer.SetFormItemProperty(Items, "Decoration2", "Visible", False);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure PriceListResizeProportionallyOnChange(Item)
	
	CommonClientServer.SetFormItemProperty(Items, "PriceListPictureHeight", "Enabled", NOT PriceList.ResizeProportionally);
	
	If PriceList.ResizeProportionally Then
		
		PriceList.PictureHeight = PriceList.PictureWidth * 5;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure PriceListPictureWidthOnChange(Item)
	
	If PriceList.ResizeProportionally Then
		
		PriceList.PictureHeight = PriceList.PictureWidth * 5;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersPriceListProductsPresentation

&AtClient
Procedure PriceListProductsPresentationOnChange(Item)
	
	CurrentRowData = Items.PriceListProductsPresentation.CurrentData;
	
	If CurrentRowData <> Undefined Then
		
		If CurrentRowData.ProductsAttribute = "FreeBalance" Then
			
			CommonClientServer.SetFormItemProperty(Items, "PriceListBalancesPresentation", "Enabled", CurrentRowData.Use);
			
		ElsIf CurrentRowData.ProductsAttribute = "Picture" Then
			
			PriceListPictureHeightEnabled = (CurrentRowData.Use AND NOT PriceList.ResizeProportionally);
			
			CommonClientServer.SetFormItemProperty(Items, "PriceListPictureWidth", "Enabled", CurrentRowData.Use);
			CommonClientServer.SetFormItemProperty(Items, "PriceListPictureHeight", "Enabled", PriceListPictureHeightEnabled);
			CommonClientServer.SetFormItemProperty(Items, "PriceListResizeProportionally", "Enabled", CurrentRowData.Use);
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure OK(Command)
	
	ArrayRows = PriceList.ProductsPresentation.FindRows(New Structure("Use", True));
	
	If ArrayRows.Count() = 0 Then
		
		CommonClientServer.MessageToUser(NStr("en = 'You must select at least one field.'; ru = 'Выберите, как минимум, одно поле.';pl = 'Musisz wybrać co najmniej jedno pole.';es_ES = 'Debe seleccionar por lo menos un campo.';es_CO = 'Debe seleccionar por lo menos un campo.';tr = 'En az bir alan seçmelisiniz.';it = 'Dovete selezionare almeno un campo.';de = 'Sie müssen mindestens ein Feld auswählen.'"));
		
	Else
		
		CloseParameter = New Structure;
		CloseParameter.Insert("CloseResult", DialogReturnCode.OK);
		CloseParameter.Insert("ProductsPresentation", PriceList.ProductsPresentation);
		CloseParameter.Insert("BalancesPresentation", PriceList.BalancesPresentation);
		CloseParameter.Insert("ColumnsCount", PriceList.ColumnsCount);
		CloseParameter.Insert("PictureWidth", PriceList.PictureWidth);
		CloseParameter.Insert("PictureHeight", PriceList.PictureHeight);
		CloseParameter.Insert("ResizeProportionally", PriceList.ResizeProportionally);
		
		Close(CloseParameter);
		
	EndIf;
	
EndProcedure

#EndRegion