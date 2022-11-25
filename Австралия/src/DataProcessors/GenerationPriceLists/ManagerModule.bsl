#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Procedure GeneratePriceList(ParametersStructure, BackgroundJobStorageAddress = "") Export
	
	Var PriceList, PriceListSettings;
	
	If NOT ParametersStructure.Property("PriceList", PriceList) Then
		
		Return;
		
	EndIf;
	
	SpreadsheetDocument = New SpreadsheetDocument;
	
	ReadPriceListSettings(PriceList, PriceListSettings);
	BuildPriceList(PriceListSettings, SpreadsheetDocument);
	
	ExecutionResult = New Structure;
	ExecutionResult.Insert("SpreadsheetDocument",	SpreadsheetDocument);
	ExecutionResult.Insert("PictureSizeByte",	PriceListSettings.PictureSizeByte);
	
	PutToTempStorage(ExecutionResult, BackgroundJobStorageAddress);
	
EndProcedure

Function GetPriceListProducts(PriceList) Export
	
	PriceListSettings = Undefined;
	ReadPriceListSettings(PriceList, PriceListSettings);
	
	HierarchyTree = Undefined;
	
	If PriceListSettings.ContentHierarchy = Enums.PriceListsHierarchy.ProductsHierarchy Then
		
		GetItemsAndProductsHierarchy(PriceListSettings, HierarchyTree);
		
	ElsIf PriceListSettings.ContentHierarchy = Enums.PriceListsHierarchy.PricesGroupsHierarchy Then
		
		GetItemsAndPriceGroupHierarchy(PriceListSettings, HierarchyTree);
		
	ElsIf PriceListSettings.ContentHierarchy = Enums.PriceListsHierarchy.ProductsCategoriesHierarchy Then
		
		GetItemsAndProductsCategoriesHierarchy(PriceListSettings, HierarchyTree);
		
	EndIf;
	
	If TypeOf(HierarchyTree) = Type("ValueTree") Then
		Return GetArrayByHierarchyTree(HierarchyTree.Rows);
	Else
		Return New Array();
	EndIf;
	
EndFunction

#EndRegion

#Region Private

#Region FormationTD

Function ProductsAttributeNamePresentation(PriceListSettings)
	
	AttributeName = "Description";
	
	ProductsPresentation = PriceListSettings.ProductsPresentation;
	
	RowPresentation = ProductsPresentation.Find("DescriptionFull", "ProductsAttribute");
	If RowPresentation.Use Then
		
		Return RowPresentation["ProductsAttribute"];
		
	EndIf;
	
	RowPresentation = ProductsPresentation.Find("Comment", "ProductsAttribute");
	If RowPresentation.Use Then
		
		Return RowPresentation["ProductsAttribute"];
		
	EndIf;
	
	Return AttributeName;
	
EndFunction

Function ProductsAttributeNameCode(PriceListSettings)
	
	ProductsPresentation = PriceListSettings.ProductsPresentation;
	
	RowPresentationSKU = ProductsPresentation.Find("SKU", "ProductsAttribute");
	RowPresentationCode = ProductsPresentation.Find("Code", "ProductsAttribute");
	
	Return ?(RowPresentationSKU.Use, RowPresentationSKU["ProductsAttribute"], RowPresentationCode["ProductsAttribute"]);
	
EndFunction

Function FillPriceDetails(PriceListSettings, PriceType, Products, MeasurementUnit, Price, Characteristic = Undefined)
	
	StructureDetails = New Structure;
	StructureDetails.Insert("PriceType",	PriceType);
	StructureDetails.Insert("Products",		Products);
	
	If PriceListSettings.UseCharacteristics Then
		
		StructureDetails.Insert("Characteristic", Characteristic);
		
	EndIf;
	
	StructureDetails.Insert("MeasurementUnit",		MeasurementUnit);
	StructureDetails.Insert("Price",				Price);
	StructureDetails.Insert("UseCharacteristics",	PriceListSettings.UseCharacteristics);
	
	Return StructureDetails;
	
EndFunction

Procedure PutGroupInSpreadsheetDocumentList(RowsCollection, PriceListSettings, SpreadsheetDocument)
	
	AreaGroup				= PriceListSettings.AreaGroup;
	AreaRow					= PriceListSettings.AreaRow;
	DisplayPictures			= PriceListSettings.DisplayPictures;
	FreeBalance				= PriceListSettings.FreeBalance;
	BalancesPresentation	= PriceListSettings.BalancesPresentation;
	
	ParametersValues = New Structure;
	
	For Each Row In RowsCollection Do
		
		If Row.IsFolder = Undefined Then
			
			PutGroupToDocument = True;
			GroupPresentation = Row.GroupPresentationInHierarchy;
			
			ProcessFeaturesOfPutGroupInSpreadsheetDocument(Row, GroupPresentation, PriceListSettings.ContentHierarchy, PutGroupToDocument);
			
			GroupingOpen = False;
			If PutGroupToDocument Then
				
				ParametersValues.Insert("GroupPresentation", GroupPresentation);
				AreaGroup.Parameters.Fill(ParametersValues);
				SpreadsheetDocument.Put(AreaGroup);
				
				SpreadsheetDocument.StartRowGroup();
				GroupingOpen = True;
				
			EndIf;
			
			PutGroupInSpreadsheetDocumentList(Row.Rows, PriceListSettings, SpreadsheetDocument);
			
			If GroupingOpen Then
				
				SpreadsheetDocument.EndRowGroup();
				
			EndIf;
			
			Continue;
			
		EndIf;
		
		AreaRow.Parameters.Fill(Row);
		
		// Picture
		If DisplayPictures Then
			
			If ValueIsFilled(Row.Picture) Then
				
				PriceListSettings.PictureSizeByte = PriceListSettings.PictureSizeByte + Number(Row.Picture.Size);
				
				PictureData = AttachedFiles.GetBinaryFileData(Row.Picture);
				If ValueIsFilled(PictureData) Then
					
					AreaRow.Area("Picture").Picture = New Picture(PictureData);
					
				EndIf;
				
			Else
				
				AreaRow.Area("Picture").Picture = Undefined;
				
			EndIf;
			
			AreaRow.Parameters.Picture = ""; // What would the text not peeking under the picture...
			
		EndIf;
		
		// Balances Presentation
		If PriceListSettings.FreeBalance Then
			
			If PriceListSettings.BalancesPresentation = 2 Then
				
				If Row.PricingBalanceMin = 0
					OR Row.PricingBalanceMax = 0
					OR Row.PricingBalanceMin >= Row.PricingBalanceMax Then
					
					AreaRow.Parameters.FreeBalance = NStr("en = 'Not specified'; ru = 'Не указан';pl = 'Nie określono';es_ES = 'No especificado';es_CO = 'No especificado';tr = 'Belirtilmemiş';it = 'Non specificato';de = 'Keine Angabe'");
					
				ElsIf Row.FreeBalance <= Row.PricingBalanceMin Then
					
					AreaRow.Parameters.FreeBalance = PriceListSettings.TextPresentationBalancesFew;
					
				ElsIf Row.FreeBalance >= Row.PricingBalanceMax Then
					
					AreaRow.Parameters.FreeBalance = PriceListSettings.TextPresentationBalancesLot;
					
				Else
					
					AreaRow.Parameters.FreeBalance = PriceListSettings.TextPresentationBalancesEnough;
					
				EndIf;
				
			Else
				
				AreaRow.Parameters.FreeBalance = Format(Row.FreeBalance, "ND=15; NFD=1");
				
			EndIf;
			
		EndIf;
		
		// Details
		ParametersValues.Clear(); 
		
		CharacteristicRef = ?(PriceListSettings.UseCharacteristics, Row.Characteristic, Undefined);
		
		If PriceListSettings.UseCharacteristics Then
			
			CharacteristicDetails = New Structure("Products, Characteristic, ThisIsCharacteristic",
				Row.ProductsRef,
				CharacteristicRef,
				True);
			
			ParametersValues.Insert("CharacteristicDetails", CharacteristicDetails);
			
		EndIf;
		
		For Each RowPriceTypes In PriceListSettings.PriceTypesTable Do
			
			RowKey = "DetailsStructure" + RowPriceTypes.LineNumber;
			
			DetailsStructure = FillPriceDetails(PriceListSettings,
				RowPriceTypes.PriceType,
				Row.ProductsRef,
				Row["MeasurementUnitPrice_" + RowPriceTypes.LineNumber],
				Row["Price_" + RowPriceTypes.LineNumber],
				CharacteristicRef);
			
			ParametersValues.Insert(RowKey, DetailsStructure);
			
		EndDo;
		
		AreaRow.Parameters.Fill(ParametersValues);
		CellsArea = SpreadsheetDocument.Put(AreaRow);
		
	EndDo;
	
EndProcedure

Procedure PutGroupInSpreadsheetDocumentTwoColumns(RowsCollection, PriceListSettings, SpreadsheetDocument)
	
	ProductsAttributeNameCode			= ProductsAttributeNameCode(PriceListSettings);
	ProductsAttributeNamePresentation	= ProductsAttributeNamePresentation(PriceListSettings);
	
	AreaGroup		= PriceListSettings.AreaGroup;
	AreaRow			= PriceListSettings.AreaRow;
	DisplayPictures	= PriceListSettings.DisplayPictures;
	
	ParametersValues = New Structure;
	
	ParametersValues.Clear();
	
	FirstColumn = True;
	
	For Each Row In RowsCollection Do
		
		If Row.IsFolder = Undefined Then
			
			If ParametersValues.Count() > 0 Then
				
				AreaRow.Parameters.Fill(ParametersValues);
				SpreadsheetDocument.Put(AreaRow);
				ParametersValues.Clear();
				
			EndIf;
			
			PutGroupToDocument = True;
			GroupPresentation = Row.GroupPresentationInHierarchy;
			
			ProcessFeaturesOfPutGroupInSpreadsheetDocument(Row, GroupPresentation, PriceListSettings.ContentHierarchy, PutGroupToDocument);
			
			GruppingOpen = False;
			If PutGroupToDocument Then
				
				ParametersValues.Insert("GroupPresentation", GroupPresentation);
				AreaGroup.Parameters.Fill(ParametersValues);
				SpreadsheetDocument.Put(AreaGroup);
				
				SpreadsheetDocument.StartRowGroup();
				GruppingOpen = True;
				ParametersValues.Clear();
				
			EndIf;
			
			PutGroupInSpreadsheetDocumentTwoColumns(Row.Rows, PriceListSettings, SpreadsheetDocument);
			
			If GruppingOpen Then
				
				SpreadsheetDocument.EndRowGroup();
				
			EndIf;
			
			Continue;
			
		EndIf;
		
		If FirstColumn Then
			
			ParametersValues.Insert("ProductsRef",			Row.ProductsRef);
			ParametersValues.Insert("CodeSKU",				Row[ProductsAttributeNameCode]);
			ParametersValues.Insert("ProductsPresentation",	Row[ProductsAttributeNamePresentation]);
			ParametersValues.Insert("MeasurementUnit",		Row.MeasurementUnitPrice_1);
			ParametersValues.Insert("Price",				Row.Price_1);
			
			DetailsStructure = FillPriceDetails(PriceListSettings,
				PriceListSettings.PriceTypesTable[0].PriceType,
				Row.ProductsRef,
				Row.MeasurementUnitPrice_1,
				Row.Price_1);
			
			ParametersValues.Insert("DetailsStructure",			DetailsStructure);
			ParametersValues.Insert("ProductsRef1",				Undefined);
			ParametersValues.Insert("CodeSKU1",					Undefined);
			ParametersValues.Insert("ProductsPresentation1",	Undefined);
			ParametersValues.Insert("MeasurementUnit1",			Undefined);
			ParametersValues.Insert("Price1",					Undefined);
			ParametersValues.Insert("DetailsStructure1",		Undefined);
			
		Else
			
			ParametersValues.ProductsRef1			= Row.ProductsRef;
			ParametersValues.CodeSKU1				= Row[ProductsAttributeNameCode];
			ParametersValues.ProductsPresentation1	= Row[ProductsAttributeNamePresentation];
			ParametersValues.MeasurementUnit1		= Row.MeasurementUnitPrice_1;
			ParametersValues.Price1					= Row.Price_1;
			
			DetailsStructure = FillPriceDetails(PriceListSettings,
				PriceListSettings.PriceTypesTable[0].PriceType,
				Row.ProductsRef,
				Row.MeasurementUnitPrice_1,
				Row.Price_1);
			
			ParametersValues.Insert("DetailsStructure1", DetailsStructure);
			
			AreaRow.Parameters.Fill(ParametersValues);
			SpreadsheetDocument.Put(AreaRow);
			ParametersValues.Clear();
			
		EndIf;
		
		FirstColumn = NOT FirstColumn;
		
	EndDo;
	
	If ParametersValues.Count() > 0 Then
		
		AreaRow.Parameters.Fill(ParametersValues);
		SpreadsheetDocument.Put(AreaRow);
		ParametersValues.Clear();
		
	EndIf;
	
EndProcedure

Procedure PutGroupInSpreadsheetDocumentTiles(RowsCollection, PriceListSettings, SpreadsheetDocument)
	
	ProductsAttributeNameCode			= ProductsAttributeNameCode(PriceListSettings);
	ProductsAttributeNamePresentation	= ProductsAttributeNamePresentation(PriceListSettings);
	
	AreaGroup				= PriceListSettings.AreaGroup;
	AreaSlideDetails		= PriceListSettings.AreaSlideDetails;
	AreaVerticalIndent		= PriceListSettings.AreaVerticalIndent;
	AreaHorizontalIndent	= PriceListSettings.AreaHorizontalIndent;
	DisplayPictures			= PriceListSettings.DisplayPictures;
	ColumnsCount			= PriceListSettings.ColumnsCount;
	
	WithCharacteristic = ?(PriceListSettings.UseCharacteristics, "WithCharacteristic", "");
	
	AreaVerticalIndent.Area("R2").RowHeight = PriceListSettings.PictureHeight;
	
	ParametersValues = New Structure;
	
	ParametersValues.Clear();
	
	Column = 0;
	
	For Each Row In RowsCollection Do
		
		If Row.IsFolder = Undefined Then
			
			PutGroupToDocument = True;
			GroupPresentation = Row.GroupPresentationInHierarchy;
			
			ProcessFeaturesOfPutGroupInSpreadsheetDocument(Row, GroupPresentation, PriceListSettings.ContentHierarchy, PutGroupToDocument);
			
			GroupingOpen = False;
			If PutGroupToDocument Then
				
				ParametersValues.Insert("GroupPresentation", GroupPresentation);
				AreaGroup.Parameters.Fill(ParametersValues);
				SpreadsheetDocument.Put(AreaGroup);
				
				SpreadsheetDocument.StartRowGroup();
				GroupingOpen = True;
				
			EndIf;
			
			PutGroupInSpreadsheetDocumentTiles(Row.Rows, PriceListSettings, SpreadsheetDocument);
			
			If GroupingOpen Then
				
				SpreadsheetDocument.EndRowGroup();
				
			EndIf;
			
			Continue;
			
		EndIf;
		
		Column = Column + 1;
		
		ParametersValues.Clear();
		ParametersValues.Insert("ProductsRef",			Row.ProductsRef);
		ParametersValues.Insert("CodeSKU",				Row[ProductsAttributeNameCode]);
		ParametersValues.Insert("ProductsPresentation",	Row[ProductsAttributeNamePresentation]);
		
		If NOT IsBlankString(WithCharacteristic) Then
			
			ParametersValues.Insert("CharacteristicPresentation", Row.CharacteristicPresentation);
			
		EndIf;
		
		MeasurementUnitPrice = "";
		If ValueIsFilled(Row.Price_1) Then
			
			MeasurementUnitPrice = String(Row.Price_1)
				+ " "
				+ String(PriceListSettings.Currency)
				+ "\"
				+ String(Row.MeasurementUnitPrice_1);
			
		EndIf;
		
		ParametersValues.Insert("MeasurementUnitPrice", MeasurementUnitPrice);
		
		AreaSlideDetails.Parameters.Fill(ParametersValues);
		
		If Column = 1 Then
			
			SpreadsheetDocument.Put(AreaVerticalIndent);
			
			// Picture
			If ValueIsFilled(Row.Picture) Then
				
				PictureData = AttachedFiles.GetBinaryFileData(Row.Picture);
				If ValueIsFilled(PictureData) Then
					
					AreaSlideDetails.Area("Picture" + WithCharacteristic).Picture = New Picture(PictureData);
					
				EndIf;
				
			Else
				
				AreaSlideDetails.Area("Picture" + WithCharacteristic).Picture = PictureLib.PlannedIdea;
				
			EndIf;
			
			AreaCellaWithPicture = SpreadsheetDocument.Join(AreaSlideDetails);
			AreaCellaWithPicture.ColumnWidth = PriceListSettings.PictureWidth;
			
		Else
			
			// Picture
			If ValueIsFilled(Row.Picture) Then
				
				PictureData = AttachedFiles.GetBinaryFileData(Row.Picture);
				If ValueIsFilled(PictureData) Then
					
					AreaSlideDetails.Area("Picture" + WithCharacteristic).Picture = New Picture(PictureData);
					
				EndIf;
				
			Else
				
				AreaSlideDetails.Area("Picture" + WithCharacteristic).Picture = PictureLib.PlannedIdea;
				
			EndIf;
			
			SpreadsheetDocument.Join(AreaVerticalIndent);
			AreaCellaWithPicture = SpreadsheetDocument.Join(AreaSlideDetails);
			AreaCellaWithPicture.ColumnWidth = PriceListSettings.PictureWidth;
			
			If Column = ColumnsCount Then
				
				Column = 0;
				SpreadsheetDocument.Put(AreaHorizontalIndent);
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure AddAreaLines(SelectionArea, LineCell)
	
	SelectionArea.TopBorder		= LineCell;
	SelectionArea.LeftBorder	= LineCell;
	SelectionArea.RightBorder	= LineCell;
	SelectionArea.BottomBorder	= LineCell;
	
EndProcedure

Function CreateAreaHeader(PriceListSettings, SpreadsheetDocument, TemplateList)
	
	// Start. Without this rudiment, the width of columns in a tabular document stops working.
	SelectionArea = SpreadsheetDocument.Area(1, 1, 1, 1);
	SelectionArea.Merge();
	// The finish. Without this rudiment, the width of columns in a tabular document stops working.
	
	AreaHeader		= TemplateList.GetArea("Header");
	PriceTypesTable	= PriceListSettings.PriceTypesTable;
	LineCell		= New Line(SpreadsheetDocumentCellLineType.Solid, 1);
	
	ColumnNumber = 1;
	For Each Row In PriceListSettings.ProductsPresentation Do
		
		If Row.Use Then
			
			ColumnNumber = ColumnNumber + 1;
			SelectionArea = AreaHeader.Area(1, ColumnNumber, 1, ColumnNumber);
			
			SelectionArea.Text			= Row.AttributePresentation;
			SelectionArea.TextPlacement	= SpreadsheetDocumentTextPlacementType.Wrap;
			SelectionArea.BackColor		= StyleColors.BorderColor;
			
			AddAreaLines(SelectionArea, LineCell);
			
			SpreadsheetDocument.Area(1, ColumnNumber, 1, ColumnNumber).ColumnWidth = Row.Width;
			
		EndIf;
		
	EndDo;
	
	For PriceIndex = 1 To PriceTypesTable.Count() Do
		
		SpreadsheetDocument.Area(1, ColumnNumber+1, 1, ColumnNumber+1).ColumnWidth = 3; // MeasurementUnit
		SpreadsheetDocument.Area(1, ColumnNumber+2, 1, ColumnNumber+2).ColumnWidth = 7; // Price
		
		SelectionArea = AreaHeader.Area(1, ColumnNumber+1, 1, ColumnNumber+2);
		
		SelectionArea.Merge();
		
		SelectionArea.Text = ?(PriceListSettings.PricePresentation,
			String(PriceTypesTable[PriceIndex - 1].PriceType),
			NStr("en ='Price'; ru = 'Цена';pl = 'Cena';es_ES = 'Precio';es_CO = 'Precio';tr = 'Fiyat';it = 'Prezzo';de = 'Preis'") + " " + PriceIndex);
		
		SelectionArea.TextPlacement		= SpreadsheetDocumentTextPlacementType.Wrap;
		SelectionArea.HorizontalAlign	= HorizontalAlign.Center;
		SelectionArea.BackColor			= StyleColors.BorderColor;
		
		AddAreaLines(SelectionArea, LineCell);
		
		ColumnNumber = ColumnNumber + 2;
		
	EndDo;
	
	Return AreaHeader;
	
EndFunction

Function CreateAreaRow(PriceListSettings, TemplateList)
	
	AreaRow			= TemplateList.GetArea("Row");
	PriceTypesTable	= PriceListSettings.PriceTypesTable;
	LineCell		= New Line(SpreadsheetDocumentCellLineType.Dotted, 1);
	
	ColumnNumber = 1;
	For Each Row In PriceListSettings.ProductsPresentation Do
		
		If Row.Use Then
			
			ColumnNumber = ColumnNumber + 1;
			SelectionArea = AreaRow.Area(1, ColumnNumber, 1, ColumnNumber);
			
			SelectionArea.FillType			= SpreadsheetDocumentAreaFillType.Parameter;
			SelectionArea.Parameter			= Row.ProductsAttribute;
			SelectionArea.DetailsParameter	= Row.DetailsParameter;
			SelectionArea.TextPlacement		= SpreadsheetDocumentTextPlacementType.Wrap;
			
			AddAreaLines(SelectionArea, LineCell);
			
			If Row.ProductsAttribute = "Picture" Then
				
				SelectionArea.Name = "Picture";
				SelectionArea.RowHeight = PriceListSettings.PictureHeight;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	For PriceIndex = 1 To PriceTypesTable.Count() Do
		
		ColumnNumber = ColumnNumber + 1;
		SelectionArea = AreaRow.Area(1, ColumnNumber, 1, ColumnNumber);
		
		SelectionArea.FillType			= SpreadsheetDocumentAreaFillType.Parameter;
		SelectionArea.Parameter			= "MeasurementUnitPrice_" + String(PriceIndex);
		SelectionArea.DetailsParameter	= "DetailsStructure" + String(PriceIndex);
		
		AddAreaLines(SelectionArea, LineCell);
		
		ColumnNumber = ColumnNumber + 1;
		SelectionArea = AreaRow.Area(1, ColumnNumber, 1, ColumnNumber);
		
		SelectionArea.FillType			= SpreadsheetDocumentAreaFillType.Parameter;
		SelectionArea.Parameter			= "Price_" + String(PriceIndex);
		SelectionArea.DetailsParameter	= "DetailsStructure" + String(PriceIndex);
		SelectionArea.Format			= "ND=15; NFD=2";
		
		AddAreaLines(SelectionArea, LineCell);
		
	EndDo;
	
	Return AreaRow;
	
EndFunction

Procedure FillTemplateAreaTitle(PriceListSettings, SpreadsheetDocument, Template)
	
	AreaTitleBase	= Template.GetArea("Title|Base");
	
	If PriceListSettings.PriceListPrintingVariant = Enums.PriceListPrintingVariants.List Then
		AreaTitleIndent = Template.GetArea("Title|Indent");
	EndIf;
	
	AreaTitleCompany = Template.GetArea("Title|Company");
	AreaTitleSimple = Template.GetArea("TitleSimple");
	
	ParametersValues = New Structure;
	ParametersValues.Insert("Title", PriceListSettings.Description);
	
	IsDisplayContactInformation = (PriceListSettings.DisplayContactInformation AND ValueIsFilled(PriceListSettings.Company));
	
	If IsDisplayContactInformation
		AND ValueIsFilled(PriceListSettings.Logo) Then
		
		PictureData = AttachedFiles.GetBinaryFileData(PriceListSettings.Logo);
		If ValueIsFilled(PictureData) Then
			
			AreaTitleBase.Area("Logo").Picture = New Picture(PictureData);
			
		EndIf;
		
	EndIf;
	
	ParametersValues.Insert("FormationDate", "");
	If PriceListSettings.DisplayFormationDate Then
		FormationDate = NStr("en = 'Formed'; ru = 'Сформировано';pl = 'Utworzony';es_ES = 'Formado';es_CO = 'Formado';tr = 'Oluşturulan';it = 'Creato';de = 'Gebildet'") + " " + Format(PriceListSettings.FormationDate, "DLF=DD");
		ParametersValues.Insert("FormationDate", FormationDate);
	EndIf;
	
	ParametersValues.Insert("CurrencyDescription", NStr("en = 'Currency:'; ru = 'Валюта:';pl = 'Waluta:';es_ES = 'Moneda:';es_CO = 'Moneda:';tr = 'Para birimi:';it = 'Valuta:';de = 'Währung:'") + " " + PriceListSettings.Currency);
	If ValueIsFilled(PriceListSettings.Currency) 
		AND PriceListSettings.Currency <> DriveReUse.GetFunctionalCurrency() Then
		
		CurrencyRateCalculationDate = ?(ValueIsFilled(PriceListSettings.CurrencyRateCalculationDate),
			PriceListSettings.CurrencyRateCalculationDate,
			CurrentSessionDate());
		
		CurrencyRate = CurrencyRateOperations.GetCurrencyRate(CurrencyRateCalculationDate, PriceListSettings.Currency, PriceListSettings.Company);
		
		ParametersValues.CurrencyDescription = ParametersValues.CurrencyDescription
			+ ", "
			+ NStr("en = 'rate'; ru = 'ставка';pl = 'stawka';es_ES = 'tasa';es_CO = 'tasa de liquidaciones';tr = 'oran';it = 'tasso';de = 'bewerten'")
			+ " "
			+ CurrencyRate.Rate;
		
		If CurrencyRate.Repetition <> 1 Then
			
			ParametersValues.CurrencyDescription = ParametersValues.CurrencyDescription
				+ ", " 
				+ NStr("en = 'multiplicity'; ru = 'кратность';pl = 'mnożnik';es_ES = 'multiplicador';es_CO = 'multiplicador';tr = 'çokluk';it = 'multiplicità';de = 'Multiplikator'")
				+ " "
				+ CurrencyRate.Repetition;
			
		EndIf;
		
	EndIf;
	
	If IsDisplayContactInformation Then
		
		AreaTitleBase.Parameters.Fill(ParametersValues);
		SpreadsheetDocument.Put(AreaTitleBase);
		
		If PriceListSettings.PriceListPrintingVariant = Enums.PriceListPrintingVariants.List Then
			SpreadsheetDocument.Join(AreaTitleIndent);
		EndIf;
		
		ParametersValues.Clear();
		
		DataCompany = DriveServer.InfoAboutLegalEntityIndividual(PriceListSettings.Company, CurrentSessionDate());
		
		ParametersValues.Insert("CompanyName",		NStr("en = 'Company:'; ru = 'Организация:';pl = 'Firma:';es_ES = 'Empresa:';es_CO = 'Empresa:';tr = 'İş yeri:';it = 'Azienda:';de = 'Firma:'") + " " + DataCompany.FullDescr);
		ParametersValues.Insert("CompanyAddress",	NStr("en = 'Address:'; ru = 'Адрес:';pl = 'Adres:';es_ES = 'Dirección:';es_CO = 'Dirección:';tr = 'Adres:';it = 'Indirizzo:';de = 'Adresse:'") + " " + DataCompany.LegalAddress);
		ParametersValues.Insert("CompanyPhone",		NStr("en = 'Phone:'; ru = 'Телефон:';pl = 'Telefon:';es_ES = 'Teléfono:';es_CO = 'Teléfono:';tr = 'Telefon:';it = 'Telefono:';de = 'Telefon:'") + " " + DataCompany.PhoneNumbers);
		ParametersValues.Insert("CompanyEmail",		NStr("en = 'E-mail:'; ru = 'E-mail:';pl = 'E-mail:';es_ES = 'Correo electrónico:';es_CO = 'Correo electrónico:';tr = 'E-posta:';it = 'E-mail:';de = 'E-Mail:'") + " " + DataCompany.Email);
		ParametersValues.Insert("CompanyVATNumber", NStr("en = 'VAT:'; ru = 'НДС:';pl = 'VAT:';es_ES = 'IVA:';es_CO = 'IVA:';tr = 'KDV:';it = 'P.IVA:';de = 'USt.:'") + " " + DataCompany.VATNumber);
		
		AreaTitleCompany.Parameters.Fill(ParametersValues);
		SpreadsheetDocument.Join(AreaTitleCompany);
		
	Else
		
		ParametersValues.Insert("FormationDate", "");
		If PriceListSettings.DisplayFormationDate Then
			ParametersValues.FormationDate = ", " + ParametersValues.FormationDate;
		EndIf;
		
		AreaTitleSimple.Parameters.Fill(ParametersValues);
		SpreadsheetDocument.Put(AreaTitleSimple);
		
	EndIf;
	
EndProcedure

Procedure FillTemplateListProductsHierarchy(PriceListSettings, SpreadsheetDocument, HierarchyTree)
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.Area(1, 1, 1, 1).ColumnWidth = 2;
	
	TemplateList = PrintManagement.PrintFormTemplate("DataProcessor.GenerationPriceLists.PF_MXL_List");
	
	AreaHeader			= CreateAreaHeader(PriceListSettings, SpreadsheetDocument, TemplateList);
	AreaGroup			= TemplateList.GetArea("Group");
	AreaRow				= CreateAreaRow(PriceListSettings, TemplateList);
	AreaFormationDate	= TemplateList.GetArea("FormationDate");
	AreaComment			= TemplateList.GetArea("Comment");
	
	FillTemplateAreaTitle(PriceListSettings, SpreadsheetDocument, TemplateList);
	
	ParametersValues= New Structure;
	
	AreaHeader.Parameters.Fill(ParametersValues);
	SpreadsheetDocument.Put(AreaHeader);
	SpreadsheetDocument.RepeatOnRowPrint = SpreadsheetDocument.Area("Header");
	
	PriceListSettings.Insert("AreaGroup", AreaGroup);
	PriceListSettings.Insert("AreaRow", AreaRow);
	
	PutGroupInSpreadsheetDocumentList(HierarchyTree.Rows, PriceListSettings, SpreadsheetDocument);
	
	If PriceListSettings.DisplayPictures Then
		
		SpreadsheetDocument.Area("C2").ColumnWidth = PriceListSettings.PictureWidth;
		
	EndIf;
	
	If NOT IsBlankString(PriceListSettings.Comment) Then
		
		ParametersValues.Clear();
		ParametersValues.Insert("Comment", PriceListSettings.Comment);
		AreaComment.Parameters.Fill(ParametersValues);
		SpreadsheetDocument.Put(AreaComment);
		
	EndIf;
	
EndProcedure

Procedure FillTemplateTwoColumnsProductsHierarchy(PriceListSettings, SpreadsheetDocument, HierarchyTree)
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.Area(1, 1, 1, 1).ColumnWidth = 2;
	
	TemplateTwoColumns = PrintManagement.PrintFormTemplate("DataProcessor.GenerationPriceLists.PF_MXL_TwoColumns");
	
	EmptySection = TemplateTwoColumns.GetArea("EmptySection");
	SpreadsheetDocument.Put(EmptySection);
	
	FillTemplateAreaTitle(PriceListSettings, SpreadsheetDocument, TemplateTwoColumns);
	
	AreaHeader	= TemplateTwoColumns.GetArea("Header");
	AreaGroup	= TemplateTwoColumns.GetArea("Group");
	AreaRow		= TemplateTwoColumns.GetArea("Row");
	AreaComment	= TemplateTwoColumns.GetArea("Comment");
	
	ParametersValues = New Structure;
	
	PriceTitle = NStr("en = 'Price'; ru = 'Цена';pl = 'Cena';es_ES = 'Precio';es_CO = 'Precio';tr = 'Fiyat';it = 'Prezzo';de = 'Preis'");
	
	If PriceListSettings.PricePresentation 
		AND PriceListSettings.PriceTypesTable.Count() > 0 Then
		
		PriceTitle = String(PriceListSettings.PriceTypesTable[0].PriceType);
		
	EndIf;
	
	ParametersValues.Insert("PriceTitle", PriceTitle);
	AreaHeader.Parameters.Fill(ParametersValues);
	SpreadsheetDocument.Put(AreaHeader);
	SpreadsheetDocument.RepeatOnRowPrint = SpreadsheetDocument.Area("Header");
	
	PriceListSettings.Insert("AreaGroup", AreaGroup);
	PriceListSettings.Insert("AreaRow", AreaRow);
	PutGroupInSpreadsheetDocumentTwoColumns(HierarchyTree.Rows, PriceListSettings, SpreadsheetDocument);
	
	If NOT IsBlankString(PriceListSettings.Comment) Then
		
		ParametersValues.Clear();
		ParametersValues.Insert("Comment", PriceListSettings.Comment);
		AreaComment.Parameters.Fill(ParametersValues);
		SpreadsheetDocument.Put(AreaComment);
		
	EndIf;
	
EndProcedure

Procedure FillTemplateTilesProductsHierarchy(PriceListSettings, SpreadsheetDocument, HierarchyTree)
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.Area(1, 1, 1, 1).ColumnWidth = 2;
	
	TemplateTiles = PrintManagement.PrintFormTemplate("DataProcessor.GenerationPriceLists.PF_MXL_Tiles");
	
	AreaGroup				= TemplateTiles.GetArea("Group");
	WithCharacteristic		= ?(PriceListSettings.UseCharacteristics, "WithCharacteristic", "");
	AreaSlideDetails		= TemplateTiles.GetArea("Slide|Details" + WithCharacteristic);
	AreaVerticalIndent		= TemplateTiles.GetArea("VerticalIndent|Details" + WithCharacteristic);
	AreaHorizontalIndent	= TemplateTiles.GetArea("Slide|HorizontalIndent");
	AreaComment				= TemplateTiles.GetArea("Comment");
	
	FillTemplateAreaTitle(PriceListSettings, SpreadsheetDocument, TemplateTiles);
	
	ParametersValues = New Structure;
	PriceListSettings.Insert("AreaGroup", AreaGroup);
	PriceListSettings.Insert("AreaSlideDetails", AreaSlideDetails);
	PriceListSettings.Insert("AreaVerticalIndent", AreaVerticalIndent);
	PriceListSettings.Insert("AreaHorizontalIndent", AreaHorizontalIndent);
	
	PutGroupInSpreadsheetDocumentTiles(HierarchyTree.Rows, PriceListSettings, SpreadsheetDocument);
	
	If NOT IsBlankString(PriceListSettings.Comment) Then
		
		ParametersValues.Clear();
		ParametersValues.Insert("Comment", PriceListSettings.Comment);
		AreaComment.Parameters.Fill(ParametersValues);
		SpreadsheetDocument.Put(AreaComment);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region DataSelection

Procedure GetItemsAndProductsHierarchy(PriceListSettings, HierarchyTree)
	
	HierarchyTree = New ValueTree;
	
	// 1. Get SKD
	SchemaDCName = ?(PriceListSettings.UseCharacteristics, "ProductsAndCharacteristicsHierarchy", "ProductsHierarchy");
	DataCompositionSchema = GetTemplate(SchemaDCName);
	
	// 2. Create settings for the scheme 
	DataCompositionSettings = DataCompositionSchema.DefaultSettings;
	
	// 2.1 set the parameter values
	ParameterDC = DataCompositionSchema.Parameters.Find("ArrayPriceTypes");
	ParameterDC.Value = PriceListSettings.PriceTypesTable.UnloadColumn("PriceType");
	
	ParameterDC = DataCompositionSchema.Parameters.Find("PriceList");
	ParameterDC.Value = PriceListSettings.PriceList;
	
	If ValueIsFilled(PriceListSettings.PricePeriod) Then
		
		ParameterDC = DataCompositionSchema.Parameters.Find("PricePeriod");
		ParameterDC.Value = PriceListSettings.PricePeriod;
		
	EndIf;
	
	If PriceListSettings.Products.Count() > 0 Then
		
		ParameterDC = DataCompositionSchema.Parameters.Find("ArrayFolders");
		ParameterDC.Value = PriceListSettings.Products;
		
	Else
		
		QueryText = DataCompositionSchema.DataSets.DataSet1.Query;
		QueryText = StrReplace(QueryText, "AND CatalogProducts.Ref IN HIERARCHY(&ArrayFolders)", "");
		DataCompositionSchema.DataSets.DataSet1.Query = QueryText;
		
	EndIf;
	
	If PriceListSettings.DisplayProductsWithoutPrice Then
		
		QueryText = DataCompositionSchema.DataSets.DataSet1.Query;
		QueryText = StrReplace(QueryText, "IsRecordWithPrices.HasRecords", "TRUE");
		DataCompositionSchema.DataSets.DataSet1.Query = QueryText;
		
	EndIf;
	
	// 2.2 set the values of the filters
	If PriceListSettings.FormationByAvailability Then
		
		DataCompositionSettings.Filter.Items.Get(0).Use = True;
		
	EndIf;
	
	// 2.3 set the values of the orders
	If PriceListSettings.Sorting = 1 Then
		
		DataCompositionSettings.Structure[0].Order.Items[0].OrderType = DataCompositionSortDirection.Desc;
		DataCompositionSettings.Structure[0].Order.Items[1].OrderType = DataCompositionSortDirection.Desc;
		
		DataCompositionSettings.Structure[0].Structure[0].Order.Items[0].OrderType = DataCompositionSortDirection.Desc;
		
		If PriceListSettings.UseCharacteristics Then
			
			DataCompositionSettings.Structure[0].Structure[0].Order.Items[1].OrderType = DataCompositionSortDirection.Desc;
			
		EndIf;
		
	EndIf;
	
	// 3. preparing template 
	TemplateComposer = New DataCompositionTemplateComposer;
	Template = TemplateComposer.Execute(DataCompositionSchema, DataCompositionSettings, , , Type("DataCompositionValueCollectionTemplateGenerator"));
	
	// 4. execute template 
	CompositionProcessor = New DataCompositionProcessor;
	CompositionProcessor.Initialize(Template);
	CompositionProcessor.Reset();
	
	// 5. display the result 
	OutputProcessor = New DataCompositionResultValueCollectionOutputProcessor;
	OutputProcessor.SetObject(HierarchyTree);
	OutputProcessor.Output(CompositionProcessor);
	
EndProcedure

Procedure GetItemsAndPriceGroupHierarchy(PriceListSettings, HierarchyTree)
	
	HierarchyTree = New ValueTree;
	
	// 1. Get SKD
	SchemaDCName = ?(PriceListSettings.UseCharacteristics, "PriceGroupHierarchyProductsAndCharacteristics", "PriceGroupHierarchy");
	DataCompositionSchema = GetTemplate(SchemaDCName);
	
	// 2. Create settings for the scheme 
	DataCompositionSettings = DataCompositionSchema.DefaultSettings;
	
	// 2.1 set the parameter values
	ParameterDC = DataCompositionSchema.Parameters.Find("ArrayPriceTypes");
	ParameterDC.Value = PriceListSettings.PriceTypesTable.UnloadColumn("PriceType");
	
	ParameterDC = DataCompositionSchema.Parameters.Find("PriceList");
	ParameterDC.Value = PriceListSettings.PriceList;
	
	If ValueIsFilled(PriceListSettings.PricePeriod) Then
		
		ParameterDC = DataCompositionSchema.Parameters.Find("PricePeriod");
		ParameterDC.Value = PriceListSettings.PricePeriod;
		
	EndIf;
	
	If PriceListSettings.PriceGroups.Count() > 0 Then
		
		ParameterDC = DataCompositionSchema.Parameters.Find("ArrayPriceGroups");
		ParameterDC.Value = PriceListSettings.PriceGroups;
		
	Else
		
		QueryText = DataCompositionSchema.DataSets.DataSet1.Query;
		QueryText = StrReplace(QueryText, "AND CatalogProducts.PriceGroup IN HIERARCHY(&ArrayPriceGroups)", "");
		DataCompositionSchema.DataSets.DataSet1.Query = QueryText;
		
	EndIf;
	
	If PriceListSettings.DisplayProductsWithoutPrice Then
		
		QueryText = DataCompositionSchema.DataSets.DataSet1.Query;
		QueryText = StrReplace(QueryText, "IsRecordWithPrices.HasRecords", "TRUE");
		DataCompositionSchema.DataSets.DataSet1.Query = QueryText;
		
	EndIf;
	
	// 2.2 set the values of the filters
	If PriceListSettings.FormationByAvailability Then
		
		DataCompositionSettings.Filter.Items.Get(0).Use = True;
		
	EndIf;
	
	// 2.3 set the values of the orders
	If PriceListSettings.Sorting = 1 Then
		
		DataCompositionSettings.Structure[0].Order.Items[0].OrderType = DataCompositionSortDirection.Desc;
		DataCompositionSettings.Structure[0].Order.Items[1].OrderType = DataCompositionSortDirection.Desc;
		DataCompositionSettings.Structure[0].Order.Items[2].OrderType = DataCompositionSortDirection.Desc;
		DataCompositionSettings.Structure[0].Order.Items[3].OrderType = DataCompositionSortDirection.Desc;
		
		DataCompositionSettings.Structure[0].Structure[0].Order.Items[0].OrderType = DataCompositionSortDirection.Desc;
		
		If PriceListSettings.UseCharacteristics Then
			
			DataCompositionSettings.Structure[0].Structure[0].Order.Items[1].OrderType = DataCompositionSortDirection.Desc;
			
		EndIf;
		
	EndIf;
	
	// 3. preparing template 
	TemplateComposer = New DataCompositionTemplateComposer;
	Template = TemplateComposer.Execute(DataCompositionSchema, DataCompositionSettings, , , Type("DataCompositionValueCollectionTemplateGenerator"));
	
	// 4. execute template 
	CompositionProcessor = New DataCompositionProcessor;
	CompositionProcessor.Initialize(Template);
	CompositionProcessor.Reset();
	
	// 5. display the result 
	OutputProcessor = New DataCompositionResultValueCollectionOutputProcessor;
	OutputProcessor.SetObject(HierarchyTree);
	OutputProcessor.Output(CompositionProcessor);
	
EndProcedure

Procedure GetItemsAndProductsCategoriesHierarchy(PriceListSettings, HierarchyTree)
	
	HierarchyTree = New ValueTree;
	
	// 1. Get SKD
	SchemaDCName = ?(PriceListSettings.UseCharacteristics, "ProductsCategoriesHierarchyAndCharacteristics", "ProductsCategoriesHierarchy");
	DataCompositionSchema = GetTemplate(SchemaDCName);
	
	// 2. Create settings for the scheme 
	DataCompositionSettings = DataCompositionSchema.DefaultSettings;
	
	// 2.1 set the parameter values
	ParameterDC = DataCompositionSchema.Parameters.Find("ArrayPriceTypes");
	ParameterDC.Value = PriceListSettings.PriceTypesTable.UnloadColumn("PriceType");
	
	ParameterDC = DataCompositionSchema.Parameters.Find("PriceList");
	ParameterDC.Value = PriceListSettings.PriceList;
	
	If ValueIsFilled(PriceListSettings.PricePeriod) Then
		
		ParameterDC = DataCompositionSchema.Parameters.Find("PricePeriod");
		ParameterDC.Value = PriceListSettings.PricePeriod;
		
	EndIf;
	
	If PriceListSettings.ProductsCategories.Count() > 0 Then
		
		ParameterDC = DataCompositionSchema.Parameters.Find("ArrayProductsCategories");
		ParameterDC.Value = PriceListSettings.ProductsCategories;
		
	Else
		
		QueryText = DataCompositionSchema.DataSets.DataSet1.Query;
		QueryText = StrReplace(QueryText, "AND CatalogProducts.ProductsCategory IN HIERARCHY(&ArrayProductsCategories)", "");
		DataCompositionSchema.DataSets.DataSet1.Query = QueryText;
		
	EndIf;
	
	If PriceListSettings.DisplayProductsWithoutPrice Then
		
		QueryText = DataCompositionSchema.DataSets.DataSet1.Query;
		QueryText = StrReplace(QueryText, "IsRecordWithPrices.HasRecords", "TRUE");
		DataCompositionSchema.DataSets.DataSet1.Query = QueryText;
		
	EndIf;
	
	// 2.2 set the values of the filters
	If PriceListSettings.FormationByAvailability Then
		
		DataCompositionSettings.Filter.Items.Get(0).Use = True;
		
	EndIf;
	
	// 2.3 set the values of the orders
	If PriceListSettings.Sorting = 1 Then
		
		DataCompositionSettings.Structure[0].Order.Items[0].OrderType = DataCompositionSortDirection.Desc;
		
		DataCompositionSettings.Structure[0].Structure[0].Order.Items[0].OrderType = DataCompositionSortDirection.Desc;
		
		DataCompositionSettings.Structure[0].Structure[0].Structure[0].Order.Items[0].OrderType = DataCompositionSortDirection.Desc;
		
		If PriceListSettings.UseCharacteristics Then
			
			DataCompositionSettings.Structure[0].Structure[0].Structure[0].Order.Items[1].OrderType = DataCompositionSortDirection.Desc;
			
		EndIf;
		
	EndIf;
	
	// 3. preparing template 
	TemplateComposer = New DataCompositionTemplateComposer;
	Template = TemplateComposer.Execute(DataCompositionSchema, DataCompositionSettings, , , Type("DataCompositionValueCollectionTemplateGenerator"));
	
	// 4. execute template 
	CompositionProcessor = New DataCompositionProcessor;
	CompositionProcessor.Initialize(Template);
	CompositionProcessor.Reset();
	
	// 5. display the result 
	OutputProcessor = New DataCompositionResultValueCollectionOutputProcessor;
	OutputProcessor.SetObject(HierarchyTree);
	OutputProcessor.Output(CompositionProcessor);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions


Procedure ProcessFeaturesOfPutGroupInSpreadsheetDocument(Row, GroupPresentation, ContentHierarchy, PutGroupToDocument)
	
	If ContentHierarchy = Enums.PriceListsHierarchy.ProductsCategoriesHierarchy Then
		
		If ValueIsFilled(Row.ProductsCategory) Then
			
			GroupPresentation = Row.ProductsCategory;
			
		EndIf;
		
		If ValueIsFilled(Row.Parent)
			AND Row.GroupPresentationInHierarchy = Row.Parent.GroupPresentationInHierarchy
			AND Row.ProductsCategory = Row.Parent.ProductsCategory Then
			
			PutGroupToDocument = False;
			
		EndIf;
		
	ElsIf ContentHierarchy = Enums.PriceListsHierarchy.PricesGroupsHierarchy Then
		
		If ValueIsFilled(Row.Parent)
			AND Row.GroupPresentationInHierarchy = Row.Parent.GroupPresentationInHierarchy Then
			
			PutGroupToDocument = False;
			
		EndIf;
		
	ElsIf ContentHierarchy = Enums.PriceListsHierarchy.ProductsHierarchy Then
		
		If ValueIsFilled(Row.Parent)
			AND Row.GroupPresentationInHierarchy = Row.Parent.GroupPresentationInHierarchy Then
			
			PutGroupToDocument = False;
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure GetPriceTable(PriceListSettings, PriceTable)
	
	Currency = PriceListSettings.Currency;
	
	If NOT ValueIsFilled(Currency) Then
		
		Currency = DriveReUse.GetFunctionalCurrency();
		
	EndIf;
	
	CurrencyRateCalculationDate = PriceListSettings.CurrencyRateCalculationDate;
	
	If NOT ValueIsFilled(CurrencyRateCalculationDate) Then
		
		CurrencyRateCalculationDate = CurrentSessionDate();
		
	EndIf;
	
	CurrencyRate = CurrencyRateOperations.GetCurrencyRate(CurrencyRateCalculationDate, Currency, PriceListSettings.Company);
	
	ArrayPriceTypesManual = New Array;
	ArrayPriceTypesPercent = New Array;
	
	For Each Row In PriceListSettings.PriceTypesTable Do
		
		If Row.PriceType.PriceCalculationMethod = Enums.PriceCalculationMethods.Manual Then
			ArrayPriceTypesManual.Add(Row.PriceType);
		ElsIf Row.PriceType.PriceCalculationMethod = Enums.PriceCalculationMethods.CalculatedDynamic Then
			ArrayPriceTypesPercent.Add(Row.PriceType);
		EndIf;
		
	EndDo;
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	PriceTypes.Ref AS Ref,
	|	PriceTypes.PricesBaseKind AS PricesBaseKind,
	|	PriceTypes.Percent AS Percent,
	|	CatalogPricesBaseKind.PriceCurrency AS PriceCurrency
	|INTO DynamicPriceTypes
	|FROM
	|	Catalog.PriceTypes AS PriceTypes
	|		INNER JOIN Catalog.PriceTypes AS CatalogPricesBaseKind
	|		ON PriceTypes.PricesBaseKind = CatalogPricesBaseKind.Ref
	|WHERE
	|	PriceTypes.Ref IN(&ArrayPriceTypesPercent)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	PricesSliceLast.PriceKind AS PriceKind,
	|	PricesSliceLast.Products AS Products,
	|	PricesSliceLast.Characteristic AS Characteristic,
	|	PricesSliceLast.MeasurementUnit AS MeasurementUnit,
	|	PricesSliceLast.Price AS Price
	|INTO PricesForDynamic
	|FROM
	|	InformationRegister.Prices.SliceLast(
	|			&PricePeriod,
	|			PriceKind IN
	|					(SELECT
	|						DynamicPriceTypes.PricesBaseKind
	|					FROM
	|						DynamicPriceTypes)
	|				AND (&UseCharacteristics
	|					OR Characteristic = VALUE(Catalog.ProductsCharacteristics.EmptyRef))) AS PricesSliceLast
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	Prices.PriceKind AS PriceKind,
	|	Prices.Products AS ProductsRef,
	|	Prices.Characteristic AS Characteristic,
	|	CASE
	|		WHEN Prices.PriceKind.PriceCurrency = &Currency
	|			THEN Prices.Price
	|		ELSE ISNULL(Prices.Price * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN &PriceListExchangeRate * ExchangeRatesPriceKind.Repetition / (ExchangeRatesPriceKind.Rate * &PriceListMultiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN ExchangeRatesPriceKind.Rate * &PriceListMultiplicity / (&PriceListExchangeRate * ExchangeRatesPriceKind.Repetition)
	|			END, 0)
	|	END AS Price,
	|	Prices.MeasurementUnit AS MeasurementUnit
	|FROM
	|	InformationRegister.Prices.SliceLast(
	|			&PricePeriod,
	|			PriceKind IN (&ArrayPriceTypesManual)
	|				AND (&UseCharacteristics
	|					OR Characteristic = VALUE(Catalog.ProductsCharacteristics.EmptyRef))) AS Prices
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&CurrencyRateCalculationDate, Company = &Company) AS ExchangeRatesPriceKind
	|		ON Prices.PriceKind.PriceCurrency = ExchangeRatesPriceKind.Currency
	|
	|UNION ALL
	|
	|SELECT
	|	DynamicPriceTypes.Ref,
	|	PricesForDynamic.Products,
	|	PricesForDynamic.Characteristic,
	|	CASE
	|		WHEN DynamicPriceTypes.PriceCurrency = &Currency
	|			THEN PricesForDynamic.Price
	|		ELSE ISNULL(PricesForDynamic.Price * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN ExchangeRatesPriceKind.Rate * &PriceListMultiplicity / (&PriceListExchangeRate * ExchangeRatesPriceKind.Repetition)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (ExchangeRatesPriceKind.Rate * &PriceListMultiplicity / (&PriceListExchangeRate * ExchangeRatesPriceKind.Repetition))
	|			END, 0)
	|	END * (1 + DynamicPriceTypes.Percent / 100),
	|	PricesForDynamic.MeasurementUnit
	|FROM
	|	DynamicPriceTypes AS DynamicPriceTypes
	|		INNER JOIN PricesForDynamic AS PricesForDynamic
	|		ON DynamicPriceTypes.PricesBaseKind = PricesForDynamic.PriceKind
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&CurrencyRateCalculationDate, Company = &Company) AS ExchangeRatesPriceKind
	|		ON DynamicPriceTypes.PriceCurrency = ExchangeRatesPriceKind.Currency";
	
	Query.SetParameter("UseCharacteristics",			PriceListSettings.UseCharacteristics);
	Query.SetParameter("PricePeriod",					PriceListSettings.PricePeriod);
	Query.SetParameter("Company",						PriceListSettings.Company);
	Query.SetParameter("ArrayPriceTypesManual",			ArrayPriceTypesManual);
	Query.SetParameter("ArrayPriceTypesPercent",		ArrayPriceTypesPercent);
	Query.SetParameter("CurrencyRateCalculationDate",	CurrencyRateCalculationDate);
	Query.SetParameter("Currency",						Currency);
	Query.SetParameter("PriceListExchangeRate",			CurrencyRate.Rate);
	Query.SetParameter("PriceListMultiplicity",			CurrencyRate.Repetition);
	Query.SetParameter("ExchangeRateMethod",			DriveServer.GetExchangeMethod(PriceListSettings.Company));
	
	PriceTable = Query.Execute().Unload();
	
EndProcedure

Procedure FillSpreadsheetDocument(PriceListSettings, SpreadsheetDocument, HierarchyTree)
	
	If PriceListSettings.PriceListPrintingVariant = Enums.PriceListPrintingVariants.List Then
		
		FillTemplateListProductsHierarchy(PriceListSettings, SpreadsheetDocument, HierarchyTree);
		
	ElsIf PriceListSettings.PriceListPrintingVariant = Enums.PriceListPrintingVariants.TwoColumns Then
		
		FillTemplateTwoColumnsProductsHierarchy(PriceListSettings, SpreadsheetDocument, HierarchyTree);
		
	ElsIf PriceListSettings.PriceListPrintingVariant = Enums.PriceListPrintingVariants.Tiles Then
		
		FillTemplateTilesProductsHierarchy(PriceListSettings, SpreadsheetDocument, HierarchyTree);
		
	EndIf;
	
EndProcedure

Procedure ReadPriceListSettings(PriceList, PriceListSettings)
	
	PriceListSettings = New Structure;
	PriceListSettings.Insert("PriceList",					PriceList.Ref);
	PriceListSettings.Insert("Description",					PriceList.Description);
	PriceListSettings.Insert("ContentHierarchy",			PriceList.ContentHierarchy);
	PriceListSettings.Insert("Sorting",						PriceList.Sorting);
	PriceListSettings.Insert("PriceListPrintingVariant",	PriceList.PriceListPrintingVariant);
	PriceListSettings.Insert("Currency",					PriceList.Currency);
	PriceListSettings.Insert("CurrencyRateCalculationDate",	PriceList.CurrencyRateCalculationDate);
	PriceListSettings.Insert("Company",						PriceList.Company);
	PriceListSettings.Insert("Logo",						PriceList.Company.LogoFile);
	PriceListSettings.Insert("PricePeriod",					PriceList.PricePeriod);
	PriceListSettings.Insert("Products",					PriceList.Inventory.UnloadColumn("Products"));
	PriceListSettings.Insert("PriceGroups",					PriceList.PriceGroups.UnloadColumn("PriceGroup"));
	PriceListSettings.Insert("ProductsCategories",			PriceList.ProductsCategories.UnloadColumn("ProductsCategory"));
	PriceListSettings.Insert("ProductsPresentation",		PriceList.ProductsPresentation);
	PriceListSettings.Insert("DisplayContactInformation",	PriceList.DisplayContactInformation);
	PriceListSettings.Insert("PricePresentation",			PriceList.PricePresentation);
	
	If PriceList.PriceTypes.Count() = 0 Then
		
		Query = New Query;
		Query.Text =
		"SELECT ALLOWED
		|	0 AS LineNumber,
		|	PriceTypes.Ref AS PriceType
		|FROM
		|	Catalog.PriceTypes AS PriceTypes";
		
		PriceListSettings.Insert("PriceTypesTable", Query.Execute().Unload());
		
		For Counter = 1 To PriceListSettings.PriceTypesTable.Count() Do
			
			PriceListSettings.PriceTypesTable[Counter - 1].LineNumber = Counter;
			
		EndDo;
		
	Else
		
		PriceListSettings.Insert("PriceTypesTable", PriceList.PriceTypes.Unload());
		
	EndIf;
	
	PriceListSettings.Insert("FormationByAvailability", PriceList.FormationByAvailability);
	PriceListSettings.Insert("DisplayProductsWithoutPrice", PriceList.DisplayProductsWithoutPrice);
	
	DisplayPictures = (PriceList.ProductsPresentation.FindRows(New Structure("Use, ProductsAttribute", True, "Picture")).Count() > 0);
	
	PriceListSettings.Insert("DisplayPictures",		DisplayPictures);
	PriceListSettings.Insert("PictureSizeByte",		0);
	PriceListSettings.Insert("PictureWidth",		PriceList.PictureWidth);
	PriceListSettings.Insert("PictureHeight",		PriceList.PictureHeight);
	
	If GetFunctionalOption("UseCharacteristics") Then
		
		FilterParameters = New Structure("Use, ProductsAttribute", True, "Characteristic");
		CharacteristicRows = PriceList.ProductsPresentation.FindRows(FilterParameters);
		PriceListSettings.Insert("UseCharacteristics", CharacteristicRows.Count() > 0);
		
	Else
		
		PriceListSettings.Insert("UseCharacteristics", False);
		
	EndIf;
	
	FilterParameters = New Structure("Use, ProductsAttribute", True, "FreeBalance");
	FreeBalanceRows = PriceList.ProductsPresentation.FindRows(FilterParameters);
	PriceListSettings.Insert("FreeBalance", FreeBalanceRows.Count() > 0);
	
	FormationDate = ?(ValueIsFilled(PriceList.FormationDate), PriceList.FormationDate, CurrentSessionDate());
	PriceListSettings.Insert("FormationDate", FormationDate);
	
	PriceListSettings.Insert("BalancesPresentation",					PriceList.BalancesPresentation);
	PriceListSettings.Insert("TextPresentationBalancesFew",				PriceList.TextPresentationBalancesFew);
	PriceListSettings.Insert("TextPresentationBalancesEnough",			PriceList.TextPresentationBalancesEnough);
	PriceListSettings.Insert("TextPresentationBalancesLot",				PriceList.TextPresentationBalancesLot);
	PriceListSettings.Insert("DisplayFormationDate",					PriceList.DisplayFormationDate);
	PriceListSettings.Insert("Comment",									PriceList.Comment);
	PriceListSettings.Insert("ColumnsCount",							PriceList.ColumnsCount);
	
EndProcedure

Procedure BuildPriceList(PriceListSettings, SpreadsheetDocument)
	
	If PriceListSettings.ContentHierarchy = Enums.PriceListsHierarchy.ProductsHierarchy Then
		
		BuildPriceListByProductsHierarchy(PriceListSettings, SpreadsheetDocument);
		
	ElsIf PriceListSettings.ContentHierarchy = Enums.PriceListsHierarchy.PricesGroupsHierarchy Then
		
		BuildPriceListByPricesGroupsHierarchy(PriceListSettings, SpreadsheetDocument);
		
	ElsIf PriceListSettings.ContentHierarchy = Enums.PriceListsHierarchy.ProductsCategoriesHierarchy Then
		
		BuildPriceListByProductsCategoriesHierarchy(PriceListSettings, SpreadsheetDocument);
		
	EndIf;
	
EndProcedure

Procedure TransposingTables(PriceListSettings, HierarchyTree, PriceTable) 
	
	ColumnsNames = New Map;
	PriceTypesTable = PriceListSettings.PriceTypesTable;
	
	TableSize = PriceTypesTable.Count();
	
	For IndexRow = 1 To TableSize Do
		
		Row = PriceTypesTable[IndexRow - 1];
		
		NewColumn = HierarchyTree.Columns.Add("Price_" + IndexRow);
		NewColumn.Title = Row.PriceType.Description;
		
		NewColumn = HierarchyTree.Columns.Add("MeasurementUnitPrice_" + IndexRow);
		
		ColumnsNames.Insert(Row.PriceType.Code, "Price_" + IndexRow);
		
	EndDo;
	
	FilterByTable = New Structure;
	
	For Each Row In PriceTable Do
		
		FilterByTable.Clear();
		FilterByTable.Insert("ProductsRef", Row.ProductsRef);
		
		If PriceListSettings.UseCharacteristics Then 
			
			FilterByTable.Insert("Characteristic", Row.Characteristic);
			
		EndIf;
		
		SearchResult = HierarchyTree.Rows.FindRows(FilterByTable, True);
		
		If SearchResult.Count() > 0 Then
			
			SearchResult[0][String(ColumnsNames[Row.PriceKind.Code])] = DriveClientServer.RoundPrice(Row.Price,
				Enums.RoundingMethods.Round0_01);
			
			SearchResult[0]["MeasurementUnit" + String(ColumnsNames[Row.PriceKind.Code])] = Row.MeasurementUnit;
			
		EndIf;
		
	EndDo;
	
	If PriceListSettings.UseCharacteristics Then
		
		CommonPriceTable = PriceTable.Copy(New Structure("Characteristic", Catalogs.ProductsCharacteristics.EmptyRef()));
		
		FilterStructure = New Structure;
		
		For Each Row In CommonPriceTable Do
			
			FilterStructure.Clear();
			FilterStructure.Insert("ProductsRef", Row.ProductsRef);
			FilterStructure.Insert(String(ColumnsNames[Row.PriceKind.Code]), Undefined);
			
			SearchResult = HierarchyTree.Rows.FindRows(FilterStructure, True);
			
			For Each HierarchyRow In SearchResult Do
				
				HierarchyRow[String(ColumnsNames[Row.PriceKind.Code])] = DriveClientServer.RoundPrice(Row.Price,
					Enums.RoundingMethods.Round0_01);
				
				HierarchyRow["MeasurementUnit" + String(ColumnsNames[Row.PriceKind.Code])] = Row.MeasurementUnit;
				
			EndDo;
			
		EndDo;
		
	EndIf;
	
	For IndexRow = 1 To TableSize Do
		
		Row = PriceTypesTable[IndexRow - 1];
		If Row.PriceType.PriceCalculationMethod = Enums.PriceCalculationMethods.Formula Then
			
			CalculateByFormula(PriceListSettings, HierarchyTree, Row.PriceType, "Price_" + IndexRow);
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure BuildPriceListByProductsHierarchy(PriceListSettings, SpreadsheetDocument)
	
	Var HierarchyTree, PriceTable;
	
	GetItemsAndProductsHierarchy(PriceListSettings, HierarchyTree);
	GetPriceTable(PriceListSettings, PriceTable);
	TransposingTables(PriceListSettings, HierarchyTree, PriceTable);
	
	FillSpreadsheetDocument(PriceListSettings, SpreadsheetDocument, HierarchyTree);
	
EndProcedure

Procedure BuildPriceListByPricesGroupsHierarchy(PriceListSettings, SpreadsheetDocument)
	
	Var HierarchyTree, PriceTable;
	
	GetItemsAndPriceGroupHierarchy(PriceListSettings, HierarchyTree);
	GetPriceTable(PriceListSettings, PriceTable);
	TransposingTables(PriceListSettings, HierarchyTree, PriceTable);
	
	FillSpreadsheetDocument(PriceListSettings, SpreadsheetDocument, HierarchyTree);
	
EndProcedure

Procedure BuildPriceListByProductsCategoriesHierarchy(PriceListSettings, SpreadsheetDocument)
	
	Var HierarchyTree, PriceTable;
	
	GetItemsAndProductsCategoriesHierarchy(PriceListSettings, HierarchyTree);
	GetPriceTable(PriceListSettings, PriceTable);
	TransposingTables(PriceListSettings, HierarchyTree, PriceTable);
	
	FillSpreadsheetDocument(PriceListSettings, SpreadsheetDocument, HierarchyTree);
	
EndProcedure

Function GetArrayByHierarchyTree(HierarchyTreeRows, ReturnableArray = Undefined)
	
	If ReturnableArray = Undefined Then
		ReturnableArray = New Array;
	EndIf;
	
	For Each Row In HierarchyTreeRows Do
		
		GetArrayByHierarchyTree(Row.Rows, ReturnableArray);
		
		If NOT ValueIsFilled(Row.ProductsRef) AND ValueIsFilled(Row.GroupPresentationInHierarchy) Then
			ReturnableArray.Add(Row.GroupPresentationInHierarchy);
		ElsIf ValueIsFilled(Row.ProductsRef) Then
			ReturnableArray.Add(Row.ReturnableArray);
		EndIf;
		
	EndDo;
	
	Return ReturnableArray;
	
EndFunction

Function GetTablesFromTreeForFormulaCalculated(Tree, Table, UseCharacteristics)
	
	For Each RowTree In Tree.Rows Do
		
		If RowTree.IsFolder <> Undefined Then
			
			If NOT RowTree.IsFolder Then
				
				NewRowTable = Table.Add();
				NewRowTable.Products = RowTree.ProductsRef;
				If UseCharacteristics Then
					NewRowTable.Characteristic = RowTree.Characteristic;
				EndIf;
				
			EndIf;
			
		EndIf;
		
		GetTablesFromTreeForFormulaCalculated(RowTree, Table, UseCharacteristics);
		
	EndDo;
	
	Return Table;
	
EndFunction

Procedure CalculateByFormula(PriceListSettings, Tree, PriceType, ColumnPriceName)
	
	TableProducts = New ValueTable;
	TableProducts.Columns.Add("Products", New TypeDescription("CatalogRef.Products"));
	TableProducts.Columns.Add("Characteristic", New TypeDescription("CatalogRef.ProductsCharacteristics"));
	TableProducts.Columns.Add("MeasurementUnit");
	
	TableProducts = GetTablesFromTreeForFormulaCalculated(Tree, TableProducts, PriceListSettings.UseCharacteristics);
	
	ExchangeRates = DriveServer.GetExchangeRate(PriceListSettings.Company, PriceType.PriceCurrency,
		PriceListSettings.Currency,
		PriceListSettings.FormationDate);
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("DocumentCurrency",					PriceListSettings.Currency);
	ParametersStructure.Insert("ExchangeRate",						ExchangeRates.Rate);
	ParametersStructure.Insert("Multiplicity",						ExchangeRates.Repetition);
	ParametersStructure.Insert("VATTaxation",						False);
	ParametersStructure.Insert("AmountIncludesVAT",					PriceType.PriceIncludesVAT);
	ParametersStructure.Insert("Company",							PriceListSettings.Company);
	ParametersStructure.Insert("DocumentDate",						PriceListSettings.FormationDate);
	ParametersStructure.Insert("RefillPrices",						True);
	ParametersStructure.Insert("RecalculatePrices",					True);
	ParametersStructure.Insert("WereMadeChanges",					False);
	ParametersStructure.Insert("PriceKind",							PriceType);
	ParametersStructure.Insert("SetCharacteristicsWithoutPrice",	True);
	
	TableResult = PriceGenerationFormulaServerCall.GetTabularSectionPricesByFormula(ParametersStructure, TableProducts);
	
	FilterByTable = New Structure;
	
	For Each Row In TableResult Do
		
		If Row.Price = 0 Then
			Continue;
		EndIf;
		
		FilterByTable.Clear();
		FilterByTable.Insert("ProductsRef", Row.Products);
		
		If PriceListSettings.UseCharacteristics Then 
			
			FilterByTable.Insert("Characteristic", Row.Characteristic);
			
		EndIf;
		
		SearchResult = Tree.Rows.FindRows(FilterByTable, True);
		
		If SearchResult.Count() > 0 Then
			
			SearchResult[0][ColumnPriceName] = DriveClientServer.RoundPrice(Row.Price, Enums.RoundingMethods.Round0_01);
			SearchResult[0]["MeasurementUnit" + ColumnPriceName] = Row.Products.MeasurementUnit;
			
		EndIf;
		
	EndDo;
	
EndProcedure

#EndRegion

#EndRegion

#EndIf