
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not ValueIsFilled(Object.Ref) Then
		
		Object.Currency = DriveReUse.GetFunctionalCurrency();
		
		NewRow			 = Object.PriceTypes.Add();
		NewRow.PriceType = Catalogs.PriceTypes.Wholesale;
		
	EndIf;
	
	If Object.ProductsPresentation.FindRows(New Structure("Use", True)).Count() = 0 Then
		
		TableViews = Catalogs.PriceLists.AvailableProductsFields();
		Object.ProductsPresentation.Load(TableViews);
		
	EndIf;
	
	If IsBlankString(Object.Description) Then
		
		Object.Description = NStr("en ='Price list'; ru = 'Прайс-лист';pl = 'Cennik';es_ES = 'Lista de precios';es_CO = 'Lista de precios';tr = 'Fiyat listesi';it = 'Listino prezzi';de = 'Preisliste'");
		
	EndIf;
	
	PricePresentation = Number(Object.PricePresentation);
	
	CacheValues = New Structure;
	CacheValues.Insert("ProductsHierarchy",				Enums.PriceListsHierarchy.ProductsHierarchy);
	CacheValues.Insert("PricesGroupsHierarchy",			Enums.PriceListsHierarchy.PricesGroupsHierarchy);
	CacheValues.Insert("ProductsCategoriesHierarchy",	Enums.PriceListsHierarchy.ProductsCategoriesHierarchy);
	CacheValues.Insert("List",							Enums.PriceListPrintingVariants.List);
	CacheValues.Insert("TwoColumns",					Enums.PriceListPrintingVariants.TwoColumns);
	CacheValues.Insert("Tiles",							Enums.PriceListPrintingVariants.Tiles);
	CacheValues.Insert("WholesalePrice",				Catalogs.PriceTypes.Wholesale);
	CacheValues.Insert("WholesalePriceCurrency",		Catalogs.PriceTypes.Wholesale.PriceCurrency);
	
	CommonClientServer.SetFormItemProperty(Items, "FormationDate", "Enabled", Object.DisplayFormationDate);
	
	SetPriceTypesChoiceList();
	
	// StandardSubsystems.ObjectVersioning
	ObjectsVersioning.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.ObjectVersioning
	
	// StandardSubsystems.ObjectAttributesLock
	ObjectAttributesLock.LockAttributes(ThisObject);
	// End StandardSubsystems.ObjectAttributesLock
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject, Object);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	ChangePriceListPrintingVariant();
	ChangeVariantProductsFilter();
	FormItemsPropertiesManagement();
	FillProductsPresentation();
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	If Object.PriceListPrintingVariant = CacheValues.TwoColumns Then
		
		DeleteOverweightRows(Cancel);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)

	NativeLanguagesSupportServer.BeforeWriteAtServer(CurrentObject);
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	// StandardSubsystems.ObjectAttributesLock
	ObjectAttributesLock.LockAttributes(ThisObject);
	// End StandardSubsystems.ObjectAttributesLock

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, MessageText, StandardProcessing)
	
	FilesOperationsClient.ShowConfirmationForClosingFormWithFiles(ThisObject, Cancel, Exit, Object.Ref);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ContentHierarchyOnChange(Item)
	
	ChangeVariantProductsFilter();
	
EndProcedure

&AtClient
Procedure PriceListPrintingVariantOnChange(Item)
	
	ChangePriceListPrintingVariant();
	
EndProcedure

&AtClient
Procedure AttributesCompositionClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	FormOpenParameters = New Structure;
	FormOpenParameters.Insert("ProductsPresentation", Object.ProductsPresentation);
	FormOpenParameters.Insert("BalancesPresentation", Object.BalancesPresentation);
	FormOpenParameters.Insert("PriceListPrintingVariant", Object.PriceListPrintingVariant);
	FormOpenParameters.Insert("ColumnsCount", Object.ColumnsCount);
	FormOpenParameters.Insert("PictureWidth", Object.PictureWidth);
	FormOpenParameters.Insert("PictureHeight", Object.PictureHeight);
	FormOpenParameters.Insert("ResizeProportionally", Object.ResizeProportionally);
	
	NotifyDescription = New NotifyDescription("AttributesCompositionAfterEdit", ThisObject);
	
	If Object.PriceListPrintingVariant = CacheValues.List Then
		
		OpenForm("Catalog.PriceLists.Form.FormAttributesComposition",
			FormOpenParameters,
			ThisObject, , , ,
			NotifyDescription);
		
	ElsIf Object.PriceListPrintingVariant = CacheValues.TwoColumns
		OR Object.PriceListPrintingVariant = CacheValues.Tiles Then
		
		OpenForm("Catalog.PriceLists.Form.FormAttributesCompositionTwoColumns",
			FormOpenParameters,
			ThisObject, , , ,
			NotifyDescription);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AttributesCompositionAfterEdit(CloseResult, AdditionalParameters) Export
	
	If TypeOf(CloseResult) = Type("Structure") Then
		
		If CloseResult.CloseResult = DialogReturnCode.OK Then
			
			Object.ProductsPresentation.Clear();
			
			For Each Row In CloseResult.ProductsPresentation Do
				
				FillPropertyValues(Object.ProductsPresentation.Add(), Row);
				
			EndDo;
			
			Object.ColumnsCount = CloseResult.ColumnsCount;
			Object.PictureWidth = CloseResult.PictureWidth;
			Object.PictureHeight = CloseResult.PictureHeight;
			Object.ResizeProportionally = CloseResult.ResizeProportionally;
			
			FillProductsPresentation();
			
			Object.BalancesPresentation = CloseResult.BalancesPresentation;
			
			Modified = True;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure DisplayFormationDateOnChange(Item)
	
	CommonClientServer.SetFormItemProperty(Items, "FormationDate", "Enabled", Object.DisplayFormationDate);
	
EndProcedure

&AtClient
Procedure PricePresentation1OnChange(Item)
	
	Object.PricePresentation = Boolean(PricePresentation);
	
EndProcedure

&AtClient
Procedure CompanyOnChange(Item)
	
	SetPriceTypesChoiceList();
	
EndProcedure

&AtClient
Procedure Attachable_Open(Item, StandardProcessing)
	NativeLanguagesSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Generate(Command)
	
	If NOT ValueIsFilled(Object.Ref) Or Modified Then
		Write();
	EndIf;
	If NOT ValueIsFilled(Object.Company) Then
		Return;
	EndIf;
	
	OpenForm("DataProcessor.GenerationPriceLists.Form", New Structure("PriceList", Object.Ref), ThisObject);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetPriceTypesChoiceList()

	WorkWithForm.SetChoiceParametersByCompany(Object.Company, ThisForm, "PriceTypesPriceType");
	
EndProcedure

&AtClient
Procedure ChangeVariantProductsFilter()
	
	If Object.ContentHierarchy = CacheValues.ProductsHierarchy Then
		
		Items.PagesComposition.CurrentPage = Items.PageFilterProductGroups;
		
		Object.PriceGroups.Clear();
		Object.ProductsCategories.Clear();
		
	ElsIf Object.ContentHierarchy = CacheValues.PricesGroupsHierarchy Then
		
		Items.PagesComposition.CurrentPage = Items.PageFilterPriceGroups;
		
		Object.Inventory.Clear();
		Object.ProductsCategories.Clear();
		
	ElsIf Object.ContentHierarchy = CacheValues.ProductsCategoriesHierarchy Then
		
		Items.PagesComposition.CurrentPage = Items.PageFilterProductCategories;
		
		Object.Inventory.Clear();
		Object.PriceGroups.Clear();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure FormItemsPropertiesManagement()
	
	If Object.PriceListPrintingVariant = CacheValues.List Then
		
		Items.PagesPriceTypes.CurrentPage = Items.PagePriceTypeList;
		Items.DecorationPriceListSample.Picture = PictureLib.PriceListVariantList;
		CommonClientServer.SetFormItemProperty(Items, "Currency", "Enabled", True);
		
	ElsIf Object.PriceListPrintingVariant = CacheValues.TwoColumns Then
		
		Items.PagesPriceTypes.CurrentPage = Items.PagePriceTypeRecord;
		Items.DecorationPriceListSample.Picture = PictureLib.PriceListVariantColumn;
		
	ElsIf Object.PriceListPrintingVariant = CacheValues.Tiles Then
		
		Items.PagesPriceTypes.CurrentPage = Items.PagePriceTypeRecord;
		Items.DecorationPriceListSample.Picture = PictureLib.PriceListVariantTiles;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ChangePriceListPrintingVariant()
	
	If Object.PriceListPrintingVariant = CacheValues.TwoColumns Then
		
		For Each Row In Object.ProductsPresentation Do
			
			Row.Use = (Row.ProductsAttribute = "SKU" Or Row.ProductsAttribute = "Description");
			
		EndDo;
		
		FillProductsPresentation();
		
		If Object.PriceTypes.Count() = 0 Then
			
			NewRow			 = Object.PriceTypes.Add();
			NewRow.PriceType = CacheValues.WholesalePrice;
			
		EndIf;
		
		Object.BalancesPresentation = 1;
		Object.FormationByAvailability = False;
		
	ElsIf Object.PriceListPrintingVariant = CacheValues.Tiles Then
		
		For Each Row In Object.ProductsPresentation Do
			
			Row.Use = (Row.ProductsAttribute = "SKU" Or Row.ProductsAttribute = "DescriptionFull");
			
		EndDo;
		
		FillProductsPresentation();
		
		If Object.PriceTypes.Count() = 0 Then
			
			NewRow			 = Object.PriceTypes.Add();
			NewRow.PriceType = CacheValues.WholesalePrice;
			Object.Currency	 = CacheValues.WholesalePriceCurrency;
			
		Else
			
			Object.Currency  = GetPriceCurrency(Object.PriceTypes[0].PriceType);
			
		EndIf;
		
	EndIf;
	
	FormItemsPropertiesManagement();
	
EndProcedure

&AtClient
Procedure FillProductsPresentation()
	
	AttributesComposition = "";
	
	For Each Row In Object.ProductsPresentation Do
		
		If Row.Use Then
			
			AttributesComposition = AttributesComposition
				+ ?(IsBlankString(AttributesComposition), "", ", ")
				+ Row.AttributePresentation;
			
		EndIf;
		
	EndDo;
	
	If Object.PriceListPrintingVariant = CacheValues.Tiles Then
		
		ColumnsTitle	= NStr("en = 'Columns'; ru = 'Колонки';pl = 'Kolumny';es_ES = 'Columnas';es_CO = 'Columnas';tr = 'Sütunlar';it = 'Colonne';de = 'Spalten'");
		SizeTitle		= NStr("en = 'Size'; ru = 'Размер';pl = 'Rozmiar';es_ES = 'Tamaño';es_CO = 'Tamaño';tr = 'Boyut';it = 'Dimensione';de = 'Größe'");
		
		AttributesComposition = StringFunctionsClientServer.SubstituteParametersToString("%1, %2: %3, %4: %5 x %6",
			AttributesComposition,
			ColumnsTitle,
			Object.ColumnsCount,
			SizeTitle,
			Object.PictureWidth,
			Object.PictureHeight);
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function GetPriceCurrency(PriceType)
	
	Return PriceType.PriceCurrency;
	
EndFunction

&AtClient
Procedure DeleteOverweightRows(Cancel)
	
	PriceTypesCount = Object.PriceTypes.Count();
	
	If PriceTypesCount > 1 Then
		
		While PriceTypesCount > 1 Do
			
			Object.PriceTypes.Delete(PriceTypesCount - 1);
			
			PriceTypesCount = PriceTypesCount - 1;
			
		EndDo;
		
	EndIf;
	
EndProcedure

#Region LibrariesHandlers

// StandardSubsystems.ObjectAttributesLock
&AtClient
Procedure Attachable_AllowObjectAttributesEditing(Command)
	
	AfterProcessingHandler = New NotifyDescription("Attachable_AfterAllowObjectAttributesEditingProcessing", ThisObject);
	ObjectAttributesLockClient.AllowObjectAttributeEdit(ThisObject, AfterProcessingHandler);
	
EndProcedure

// End StandardSubsystems.ObjectAttributesLock

#EndRegion

#EndRegion