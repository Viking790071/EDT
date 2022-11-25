#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region Print

Function PrintForm(ObjectsArray, PrintObjects, TemplateName, PrintParams=Undefined) Export
	
	If TemplateName = "SimplifiedTaxInvoice" Then
		
		Return PrintSimplifiedTaxInvoice(ObjectsArray, PrintObjects, TemplateName, PrintParams);
		
	EndIf;
	
EndFunction

#EndRegion

#EndRegion

#Region Private

#Region Print

Function PrintSimplifiedTaxInvoice(ObjectsArray, PrintObjects, TemplateName, PrintParams)
    
    DisplayPrintOption = (PrintParams <> Undefined);
    
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_SimplifiedTaxInvoice";
	
	Query = New Query();
	
	StandartMode = True;
	
	If ObjectsArray.Count() > 1 Then
		
		SecondObject = ObjectsArray[1];
		If TypeOf(SecondObject) = Type("Structure") Then
			
			Query.SetParameter("ObjectsArray", New Array);
			
			Query.SetParameter("DateBeg", BegOfDay(SecondObject.Date));
			Query.SetParameter("DateEnd", EndOfDay(SecondObject.Date));
			Query.SetParameter("Company", SecondObject.Company);
			Query.SetParameter("CashCR", SecondObject.CashCR);
			Query.SetParameter("ReceiptNumber", SecondObject.ReceiptNumber);
			Query.SetParameter("ReceiptNumberWithNoughts", Right("000000" + TrimAll(SecondObject.ReceiptNumber), 6));
			
			StandartMode = False;
			ObjectsArray.Delete(1);
			
		EndIf;
		
	EndIf;
	
	If StandartMode Then
		
		Query.SetParameter("ObjectsArray", ObjectsArray);
		
		Query.SetParameter("DateBeg", Undefined);
		Query.SetParameter("DateEnd", Undefined);
		Query.SetParameter("Company", Undefined);
		Query.SetParameter("CashCR", Undefined);
		Query.SetParameter("ReceiptNumber", Undefined);
		Query.SetParameter("ReceiptNumberWithNoughts", Undefined);
		
	EndIf;
		
	#Region PrintSimplifiedTaxInvoiceQueryText
	
	Query.Text = 
	"SELECT ALLOWED
	|	SalesSlip.Ref AS Ref,
	|	SalesSlip.Number AS Number,
	|	SalesSlip.SalesSlipNumber AS SalesSlipNumber,
	|	SalesSlip.Date AS Date,
	|	SalesSlip.Company AS Company,
	|	SalesSlip.CompanyVATNumber AS CompanyVATNumber,
	|	SalesSlip.CashCR AS CashCR,
	|	SalesSlip.AmountIncludesVAT AS AmountIncludesVAT,
	|	SalesSlip.DocumentCurrency AS DocumentCurrency,
	|	CAST(SalesSlip.Comment AS STRING(1024)) AS Comment
	|INTO SalesSlips
	|FROM
	|	Document.SalesSlip AS SalesSlip
	|WHERE
	|	SalesSlip.Ref IN(&ObjectsArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	ShiftClosure.Ref AS Ref,
	|	&ReceiptNumber AS ReceiptNumber,
	|	ShiftClosure.Date AS Date,
	|	ShiftClosure.Company AS Company,
	|	ShiftClosure.CompanyVATNumber AS CompanyVATNumber,
	|	ShiftClosure.AmountIncludesVAT AS AmountIncludesVAT,
	|	ShiftClosure.DocumentCurrency AS DocumentCurrency,
	|	CAST(ShiftClosure.Comment AS STRING(1024)) AS Comment
	|INTO ShiftClosures
	|FROM
	|	Document.ShiftClosure AS ShiftClosure
	|WHERE
	|	ShiftClosure.Date BETWEEN &DateBeg AND &DateEnd
	|	AND ShiftClosure.Company = &Company
	|	AND ShiftClosure.CashCR = &CashCR
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	SalesSlip.Ref AS Ref,
	|	CASE
	|		WHEN CashRegister.UseWithoutEquipmentConnection
	|			THEN SUBSTRING(SalesSlip.Number, 6, 6)
	|		ELSE SalesSlip.SalesSlipNumber
	|	END AS SalesSlip,
	|	SalesSlip.Date AS DocumentDate,
	|	SalesSlip.Company AS Company,
	|	SalesSlip.CompanyVATNumber AS CompanyVATNumber,
	|	Companies.LogoFile AS CompanyLogoFile,
	|	SalesSlip.AmountIncludesVAT AS AmountIncludesVAT,
	|	SalesSlip.DocumentCurrency AS DocumentCurrency,
	|	SalesSlip.Comment AS Comment
	|INTO Header
	|FROM
	|	SalesSlips AS SalesSlip
	|		LEFT JOIN Catalog.Companies AS Companies
	|		ON SalesSlip.Company = Companies.Ref
	|		LEFT JOIN Catalog.CashRegisters AS CashRegister
	|		ON SalesSlip.CashCR = CashRegister.Ref
	|
	|UNION ALL
	|
	|SELECT
	|	ShiftClosure.Ref,
	|	ShiftClosure.ReceiptNumber,
	|	ShiftClosure.Date,
	|	ShiftClosure.Company,
	|	ShiftClosure.CompanyVATNumber,
	|	Companies.LogoFile,
	|	ShiftClosure.AmountIncludesVAT,
	|	ShiftClosure.DocumentCurrency,
	|	ShiftClosure.Comment
	|FROM
	|	ShiftClosures AS ShiftClosure
	|		LEFT JOIN Catalog.Companies AS Companies
	|		ON ShiftClosure.Company = Companies.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	Header.Ref AS Ref,
	|	Header.SalesSlip AS SalesSlip,
	|	Header.DocumentDate AS DocumentDate,
	|	Header.Company AS Company,
	|	Header.CompanyVATNumber AS CompanyVATNumber,
	|	Header.CompanyLogoFile AS CompanyLogoFile,
	|	Header.AmountIncludesVAT AS AmountIncludesVAT,
	|	Header.DocumentCurrency AS DocumentCurrency,
	|	Header.Comment AS Comment,
	|	SalesSlipInventory.LineNumber AS LineNumber,
	|	CatalogProducts.SKU AS SKU,
	|	SalesSlipInventory.Products AS Products,
	|	CASE
	|		WHEN (CAST(CatalogProducts.DescriptionFull AS STRING(1024))) <> """"
	|			THEN CAST(CatalogProducts.DescriptionFull AS STRING(1024))
	|		ELSE CatalogProducts.Description
	|	END AS ProductDescription,
	|	FALSE AS ContentUsed,
	|	CASE
	|		WHEN CatalogProducts.UseCharacteristics
	|			THEN CatalogCharacteristics.Description
	|		ELSE """"
	|	END AS CharacteristicDescription,
	|	CASE
	|		WHEN CatalogProducts.UseBatches
	|			THEN CatalogBatches.Description
	|		ELSE """"
	|	END AS BatchDescription,
	|	SalesSlipInventory.Characteristic AS Characteristic,
	|	SalesSlipInventory.Batch AS Batch,
	|	CatalogProducts.UseSerialNumbers AS UseSerialNumbers,
	|	SalesSlipInventory.ConnectionKey AS ConnectionKey,
	|	ISNULL(CatalogUOM.Description, CatalogUOMClassifier.Description) AS UOM,
	|	SalesSlipInventory.Quantity AS Quantity,
	|	SalesSlipInventory.Price AS Price,
	|	SalesSlipInventory.DiscountMarkupPercent AS DiscountRate,
	|	SalesSlipInventory.AutomaticDiscountAmount AS AutomaticDiscountAmount,
	|	SalesSlipInventory.Amount AS Amount,
	|	SalesSlipInventory.VATRate AS VATRate,
	|	SalesSlipInventory.VATAmount AS VATAmount,
	|	SalesSlipInventory.Total AS Total,
	|	CAST(SalesSlipInventory.Quantity * SalesSlipInventory.Price AS NUMBER(15, 2)) AS Subtotal,
	|	SalesSlipInventory.BundleProduct AS BundleProduct,
	|	SalesSlipInventory.BundleCharacteristic AS BundleCharacteristic
	|INTO Tabular
	|FROM
	|	Header AS Header
	|		INNER JOIN Document.SalesSlip.Inventory AS SalesSlipInventory
	|		ON Header.Ref = SalesSlipInventory.Ref
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON (SalesSlipInventory.Products = CatalogProducts.Ref)
	|		LEFT JOIN Catalog.ProductsCharacteristics AS CatalogCharacteristics
	|		ON (SalesSlipInventory.Characteristic = CatalogCharacteristics.Ref)
	|		LEFT JOIN Catalog.ProductsBatches AS CatalogBatches
	|		ON (SalesSlipInventory.Batch = CatalogBatches.Ref)
	|		LEFT JOIN Catalog.UOM AS CatalogUOM
	|		ON (SalesSlipInventory.MeasurementUnit = CatalogUOM.Ref)
	|		LEFT JOIN Catalog.UOMClassifier AS CatalogUOMClassifier
	|		ON (SalesSlipInventory.MeasurementUnit = CatalogUOMClassifier.Ref)
	|
	|UNION ALL
	|
	|SELECT
	|	Header.Ref,
	|	CASE
	|		WHEN ShiftClosureInventory.ReceiptNumber = &ReceiptNumberWithNoughts
	|			THEN ShiftClosureInventory.ReceiptNumber
	|		ELSE Header.SalesSlip
	|	END,
	|	Header.DocumentDate,
	|	Header.Company,
	|	Header.CompanyVATNumber,
	|	Header.CompanyLogoFile,
	|	Header.AmountIncludesVAT,
	|	Header.DocumentCurrency,
	|	Header.Comment,
	|	ShiftClosureInventory.LineNumber,
	|	CatalogProducts.SKU,
	|	ShiftClosureInventory.Products,
	|	CASE
	|		WHEN (CAST(CatalogProducts.DescriptionFull AS STRING(1024))) <> """"
	|			THEN CAST(CatalogProducts.DescriptionFull AS STRING(1024))
	|		ELSE CatalogProducts.Description
	|	END,
	|	FALSE,
	|	CASE
	|		WHEN CatalogProducts.UseCharacteristics
	|			THEN CatalogCharacteristics.Description
	|		ELSE """"
	|	END,
	|	CASE
	|		WHEN CatalogProducts.UseBatches
	|			THEN CatalogBatches.Description
	|		ELSE """"
	|	END,
	|	ShiftClosureInventory.Characteristic,
	|	ShiftClosureInventory.Batch,
	|	CatalogProducts.UseSerialNumbers,
	|	ShiftClosureInventory.ConnectionKey,
	|	ISNULL(CatalogUOM.Description, CatalogUOMClassifier.Description),
	|	ShiftClosureInventory.Quantity,
	|	ShiftClosureInventory.Price,
	|	ShiftClosureInventory.DiscountMarkupPercent,
	|	ShiftClosureInventory.AutomaticDiscountAmount,
	|	ShiftClosureInventory.Amount,
	|	ShiftClosureInventory.VATRate,
	|	ShiftClosureInventory.VATAmount,
	|	ShiftClosureInventory.Total,
	|	CAST(ShiftClosureInventory.Quantity * ShiftClosureInventory.Price AS NUMBER(15, 2)),
	|	NULL,
	|	NULL
	|FROM
	|	Header AS Header
	|		INNER JOIN Document.ShiftClosure.Inventory AS ShiftClosureInventory
	|		ON Header.Ref = ShiftClosureInventory.Ref
	|			AND (ShiftClosureInventory.ReceiptNumber = &ReceiptNumber
	|				OR ShiftClosureInventory.ReceiptNumber = &ReceiptNumberWithNoughts)
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON (ShiftClosureInventory.Products = CatalogProducts.Ref)
	|		LEFT JOIN Catalog.ProductsCharacteristics AS CatalogCharacteristics
	|		ON (ShiftClosureInventory.Characteristic = CatalogCharacteristics.Ref)
	|		LEFT JOIN Catalog.ProductsBatches AS CatalogBatches
	|		ON (ShiftClosureInventory.Batch = CatalogBatches.Ref)
	|		LEFT JOIN Catalog.UOM AS CatalogUOM
	|		ON (ShiftClosureInventory.MeasurementUnit = CatalogUOM.Ref)
	|		LEFT JOIN Catalog.UOMClassifier AS CatalogUOMClassifier
	|		ON (ShiftClosureInventory.MeasurementUnit = CatalogUOMClassifier.Ref)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Tabular.Ref AS Ref,
	|	Tabular.SalesSlip AS SalesSlip,
	|	Tabular.DocumentDate AS DocumentDate,
	|	Tabular.Company AS Company,
	|	Tabular.CompanyVATNumber AS CompanyVATNumber,
	|	Tabular.CompanyLogoFile AS CompanyLogoFile,
	|	Tabular.AmountIncludesVAT AS AmountIncludesVAT,
	|	Tabular.DocumentCurrency AS DocumentCurrency,
	|	Tabular.Comment AS Comment,
	|	MIN(Tabular.LineNumber) AS LineNumber,
	|	Tabular.SKU AS SKU,
	|	Tabular.Products AS Products,
	|	Tabular.ProductDescription AS ProductDescription,
	|	Tabular.ContentUsed AS ContentUsed,
	|	Tabular.Characteristic AS Characteristic,
	|	Tabular.CharacteristicDescription AS CharacteristicDescription,
	|	Tabular.Batch AS Batch,
	|	Tabular.BatchDescription AS BatchDescription,
	|	Tabular.UseSerialNumbers AS UseSerialNumbers,
	|	MIN(Tabular.ConnectionKey) AS ConnectionKey,
	|	Tabular.UOM AS UOM,
	|	SUM(Tabular.Quantity) AS Quantity,
	|	Tabular.Price AS Price,
	|	Tabular.DiscountRate AS DiscountRate,
	|	SUM(Tabular.AutomaticDiscountAmount) AS AutomaticDiscountAmount,
	|	SUM(Tabular.Amount) AS Amount,
	|	Tabular.VATRate AS VATRate,
	|	SUM(Tabular.VATAmount) AS VATAmount,
	|	SUM(Tabular.Total) AS Total,
	|	SUM(Tabular.Subtotal) AS Subtotal,
	|	Tabular.BundleProduct AS BundleProduct,
	|	Tabular.BundleCharacteristic AS BundleCharacteristic
	|INTO TabularGrouped
	|FROM
	|	Tabular AS Tabular
	|
	|GROUP BY
	|	Tabular.Characteristic,
	|	Tabular.CharacteristicDescription,
	|	Tabular.VATRate,
	|	Tabular.Batch,
	|	Tabular.BatchDescription,
	|	Tabular.CompanyLogoFile,
	|	Tabular.Company,
	|	Tabular.CompanyVATNumber,
	|	Tabular.SKU,
	|	Tabular.AmountIncludesVAT,
	|	Tabular.Products,
	|	Tabular.ProductDescription,
	|	Tabular.UOM,
	|	Tabular.DocumentCurrency,
	|	Tabular.Ref,
	|	Tabular.Comment,
	|	Tabular.ContentUsed,
	|	Tabular.DocumentDate,
	|	Tabular.UseSerialNumbers,
	|	Tabular.SalesSlip,
	|	Tabular.Price,
	|	Tabular.DiscountRate,
	|	Tabular.BundleProduct,
	|	Tabular.BundleCharacteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Tabular.Ref AS Ref,
	|	Tabular.SalesSlip AS SalesSlip,
	|	Tabular.DocumentDate AS DocumentDate,
	|	Tabular.Company AS Company,
	|	Tabular.CompanyVATNumber AS CompanyVATNumber,
	|	Tabular.CompanyLogoFile AS CompanyLogoFile,
	|	Tabular.AmountIncludesVAT AS AmountIncludesVAT,
	|	Tabular.DocumentCurrency AS DocumentCurrency,
	|	Tabular.Comment AS Comment,
	|	Tabular.LineNumber AS LineNumber,
	|	Tabular.SKU AS SKU,
	|	Tabular.ProductDescription AS ProductDescription,
	|	Tabular.ContentUsed AS ContentUsed,
	|	Tabular.Characteristic AS Characteristic,
	|	Tabular.Batch AS Batch,
	|	Tabular.CharacteristicDescription AS CharacteristicDescription,
	|	Tabular.BatchDescription AS BatchDescription,
	|	Tabular.UseSerialNumbers AS UseSerialNumbers,
	|	Tabular.ConnectionKey AS ConnectionKey,
	|	Tabular.UOM AS UOM,
	|	Tabular.Quantity AS Quantity,
	|	Tabular.Price AS Price,
	|	Tabular.Amount AS Amount,
	|	Tabular.VATRate AS VATRate,
	|	Tabular.VATAmount AS VATAmount,
	|	Tabular.Total AS Total,
	|	Tabular.Subtotal AS Subtotal,
	|	Tabular.Subtotal - Tabular.Amount AS DiscountAmount,
	|	CASE
	|		WHEN Tabular.AutomaticDiscountAmount = 0
	|			THEN Tabular.DiscountRate
	|		WHEN Tabular.Subtotal = 0
	|			THEN 0
	|		ELSE CAST((Tabular.Subtotal - Tabular.Amount) / Tabular.Subtotal * 100 AS NUMBER(15, 2))
	|	END AS DiscountRate,
	|	Tabular.BundleProduct AS BundleProduct,
	|	Tabular.BundleCharacteristic AS BundleCharacteristic,
	|	Tabular.Products    
	|FROM
	|	TabularGrouped AS Tabular
	|
	|ORDER BY
	|	SalesSlip,
	|	LineNumber
	|TOTALS
	|	MAX(SalesSlip),
	|	MAX(DocumentDate),
	|	MAX(Company),
	|	MAX(CompanyVATNumber),
	|	MAX(CompanyLogoFile),
	|	MAX(AmountIncludesVAT),
	|	MAX(DocumentCurrency),
	|	MAX(Comment),
	|	MAX(LineNumber),
	|	SUM(Quantity),
	|	SUM(VATAmount),
	|	SUM(Total),
	|	SUM(Subtotal),
	|	SUM(DiscountAmount)
	|BY
	|	Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Tabular.Ref AS Ref,
	|	Tabular.VATRate AS VATRate,
	|	SUM(Tabular.Amount) AS Amount,
	|	SUM(Tabular.VATAmount) AS VATAmount
	|FROM
	|	TabularGrouped AS Tabular
	|
	|GROUP BY
	|	Tabular.Ref,
	|	Tabular.VATRate
	|TOTALS BY
	|	Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	TabularGrouped.Ref AS Ref,
	|	TabularGrouped.ConnectionKey AS ConnectionKey,
	|	SerialNumbers.Description AS SerialNumber
	|FROM
	|	Tabular AS Tabular
	|		INNER JOIN TabularGrouped AS TabularGrouped
	|		ON Tabular.Ref = TabularGrouped.Ref
	|			AND Tabular.Products = TabularGrouped.Products
	|			AND Tabular.DiscountRate = TabularGrouped.DiscountRate
	|			AND Tabular.Price = TabularGrouped.Price
	|			AND Tabular.VATRate = TabularGrouped.VATRate
	|			AND (NOT Tabular.ContentUsed)
	|			AND Tabular.Characteristic = TabularGrouped.Characteristic
	|			AND Tabular.UOM = TabularGrouped.UOM
	|			AND Tabular.Batch = TabularGrouped.Batch
	|		INNER JOIN Document.SalesSlip.SerialNumbers AS SalesSlipSerialNumbers
	|		ON Tabular.Ref = SalesSlipSerialNumbers.Ref
	|			AND Tabular.ConnectionKey = SalesSlipSerialNumbers.ConnectionKey
	|			AND (NOT Tabular.ContentUsed)
	|		LEFT JOIN Catalog.SerialNumbers AS SerialNumbers
	|		ON (SalesSlipSerialNumbers.SerialNumber = SerialNumbers.Ref)
	|
	|UNION ALL
	|
	|SELECT
	|	TabularGrouped.Ref,
	|	TabularGrouped.ConnectionKey,
	|	SerialNumbers.Description
	|FROM
	|	Tabular AS Tabular
	|		INNER JOIN TabularGrouped AS TabularGrouped
	|		ON Tabular.Ref = TabularGrouped.Ref
	|			AND Tabular.Products = TabularGrouped.Products
	|			AND Tabular.DiscountRate = TabularGrouped.DiscountRate
	|			AND Tabular.Price = TabularGrouped.Price
	|			AND Tabular.VATRate = TabularGrouped.VATRate
	|			AND (NOT Tabular.ContentUsed)
	|			AND Tabular.Characteristic = TabularGrouped.Characteristic
	|			AND Tabular.UOM = TabularGrouped.UOM
	|			AND Tabular.Batch = TabularGrouped.Batch
	|		INNER JOIN Document.ShiftClosure.SerialNumbers AS ShiftClosureSerialNumbers
	|		ON Tabular.Ref = ShiftClosureSerialNumbers.Ref
	|			AND Tabular.ConnectionKey = ShiftClosureSerialNumbers.ConnectionKey
	|			AND (NOT Tabular.ContentUsed)
	|		LEFT JOIN Catalog.SerialNumbers AS SerialNumbers
	|		ON (ShiftClosureSerialNumbers.SerialNumber = SerialNumbers.Ref)";
	
	#EndRegion
	
	// MultilingualSupport
	If PrintParams = Undefined Then
		LanguageCode = NationalLanguageSupportClientServer.DefaultLanguageCode();
	Else
		LanguageCode = PrintParams.LanguageCode;
	EndIf;
	
	If LanguageCode <> CurrentLanguage().LanguageCode Then 
		SessionParameters.LanguageCodeForOutput = LanguageCode;
	EndIf;
	
	DriveServer.ChangeQueryTextForCurrentLanguage(Query.Text, LanguageCode);
	// End MultilingualSupport
	
	ResultArray = Query.ExecuteBatch();
	
	FirstDocument = True;
	
	Header						= ResultArray[5].Select(QueryResultIteration.ByGroupsWithHierarchy);
	TaxesHeaderSel				= ResultArray[6].Select(QueryResultIteration.ByGroupsWithHierarchy);
	SerialNumbersSel			= ResultArray[7].Select();
	
	// Bundles
	TableColumns = ResultArray[5].Columns;
	// End Bundles
	
	While Header.Next() Do
		
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_SimplifiedTaxInvoice";
		
		Template = PrintManagement.PrintFormTemplate("DataProcessor.PrintSimplifiedTaxInvoice.PF_MXL_SimplifiedTaxInvoice", LanguageCode);
		
		#Region PrintSimplifiedTaxInvoiceTitleArea
		
		TitleArea = Template.GetArea("Title");
		TitleArea.Parameters.Fill(Header);
        
        If DisplayPrintOption Then 
            TitleArea.Parameters.OriginalDuplicate = ?(PrintParams.OriginalCopy,
				NStr("en = 'ORIGINAL'; ru = 'ОРИГИНАЛ';pl = 'ORYGINAŁ';es_ES = 'ORIGINAL';es_CO = 'ORIGINAL';tr = 'ORİJİNAL';it = 'ORIGINALE';de = 'ORIGINAL'", LanguageCode),
				NStr("en = 'COPY'; ru = 'КОПИЯ';pl = 'KOPIA';es_ES = 'COPIA';es_CO = 'COPIA';tr = 'KOPYALA';it = 'COPIA';de = 'KOPIE'", LanguageCode));
        EndIf;
		
		If ValueIsFilled(Header.CompanyLogoFile) Then
			
			PictureData = AttachedFiles.GetBinaryFileData(Header.CompanyLogoFile);
			If ValueIsFilled(PictureData) Then
				
				TitleArea.Drawings.Logo.Picture = New Picture(PictureData);
				
			EndIf;
			
		Else
			
			TitleArea.Drawings.Delete(TitleArea.Drawings.Logo);
			
		EndIf;
		
		SpreadsheetDocument.Put(TitleArea);
		
		#EndRegion
		
		#Region PrintSimplifiedTaxInvoiceCompanyInfoArea
		
		CompanyInfoArea = Template.GetArea("CompanyInfo");
		
		InfoAboutCompany = DriveServer.InfoAboutLegalEntityIndividual(
			Header.Company, Header.DocumentDate, , , Header.CompanyVATNumber, LanguageCode);
		CompanyInfoArea.Parameters.Fill(InfoAboutCompany);
		BarcodesInPrintForms.AddBarcodeToTableDocument(CompanyInfoArea, Header.Ref);
		SpreadsheetDocument.Put(CompanyInfoArea);
		
		#EndRegion
		
		#Region PrintSimplifiedTaxInvoiceCounterpartyInfoArea
		
		CounterpartyInfoArea = Template.GetArea("CounterpartyInfo");
		CounterpartyInfoArea.Parameters.Fill(Header);
		
		SpreadsheetDocument.Put(CounterpartyInfoArea);
		
		#EndRegion
		
		#Region PrintSimplifiedTaxInvoiceCommentArea
		
		CommentArea = Template.GetArea("Comment");
		CommentArea.Parameters.Fill(Header);
		SpreadsheetDocument.Put(CommentArea);
		
		#EndRegion
		
		#Region PrintSimplifiedTaxInvoiceTotalsAndTaxesAreaPrefill
		
		TotalsAndTaxesAreasArray = New Array;
		       
		If DisplayPrintOption and PrintParams.Discount Then
		    LineTotalArea = Template.GetArea("LineTotal");
            LineTotalArea.Parameters.Fill(Header);
        Else 
            LineTotalArea = Template.GetArea("LineTotalWithoutDiscount");
            LineTotalArea.Parameters.Fill(Header);
            
            // When the "Discount" column is hidden, the results calculate by subtracting the subtotal and the discount.
            LineTotalArea.Parameters.Subtotal = Header.Subtotal-Header.DiscountAmount; 
        EndIf;
        
		TotalsAndTaxesAreasArray.Add(LineTotalArea);
		
		TaxesHeaderSel.Reset();
		If TaxesHeaderSel.FindNext(New Structure("Ref", Header.Ref)) Then
			
			TaxSectionHeaderArea = Template.GetArea("TaxSectionHeader");
			TotalsAndTaxesAreasArray.Add(TaxSectionHeaderArea);
			
			TaxesSel = TaxesHeaderSel.Select();
			While TaxesSel.Next() Do
				
				TaxSectionLineArea = Template.GetArea("TaxSectionLine");
				TaxSectionLineArea.Parameters.Fill(TaxesSel);
				TotalsAndTaxesAreasArray.Add(TaxSectionLineArea);
				
			EndDo;
			
		EndIf;
		
		#EndRegion
		
		#Region PrintSimplifiedTaxInvoiceLinesArea
		
      
        If DisplayPrintOption Then 
            If PrintParams.Discount Then 
                If PrintParams.CodesPosition <> Enums.CodesPositionInPrintForms.SeparateColumn Then 
                    // Template 1: Hide "Intem #", show "Disc.rate"
                    LineHeaderArea = Template.GetArea("LineHeaderWithoutCode");
                    LineSectionArea	= Template.GetArea("LineSectionWithoutCode");
                Else
                    // Template 2: Show all columns
                    LineHeaderArea = Template.GetArea("LineHeader");
                    LineSectionArea	= Template.GetArea("LineSection");
                EndIf;    
            Else
                If PrintParams.CodesPosition <> Enums.CodesPositionInPrintForms.SeparateColumn Then 
                    // Template 3: Hide "Intem #", hide "Disc.rate"
                    LineHeaderArea = Template.GetArea("LineHeaderWithoutItemAndDiscount");
                    LineSectionArea	= Template.GetArea("LineSectionWithoutItemAndDiscount");
                Else
                    // Template 4: Show "Intem #", hide "Disc.rate"
                    LineHeaderArea = Template.GetArea("LineHeaderWithoutDiscount");
                    LineSectionArea	= Template.GetArea("LineSectionWithoutDiscount");
                EndIf;            
            EndIf;    
        Else            
            LineHeaderArea = Template.GetArea("LineHeader");   		
    		LineSectionArea	= Template.GetArea("LineSection");
        EndIf;
        
   		SpreadsheetDocument.Put(LineHeaderArea);
        
		SeeNextPageArea	= Template.GetArea("SeeNextPage");
		EmptyLineArea	= Template.GetArea("EmptyLine");
		PageNumberArea	= Template.GetArea("PageNumber");
		
		PageNumber = 0;
		
		AreasToBeChecked = New Array;
		
		// Bundles
		TableInventoty = BundlesServer.AssemblyTableByBundles(Header.Ref, Header, TableColumns, LineTotalArea);
		EmptyColor = LineSectionArea.CurrentArea.TextColor;
		// End Bundles
		
		PricePrecision = PrecisionAppearancetServer.CompanyPrecision(Header.Company);
		
		For Each TabSelection In TableInventoty Do
			
			LineSectionArea.Parameters.Fill(TabSelection);
			
			DriveClientServer.ComplimentProductDescription(LineSectionArea.Parameters.ProductDescription, TabSelection, SerialNumbersSel);
            
            // Display selected codes if functional option is turned on.
            If DisplayPrintOption Then
                CodesPresentation = PrintManagementServerCallDrive.GetCodesPresentation(PrintParams, TabSelection.Products);
                If PrintParams.CodesPosition = Enums.CodesPositionInPrintForms.SeparateColumn Then
                    LineSectionArea.Parameters.SKU = CodesPresentation;
                ElsIf PrintParams.CodesPosition = Enums.CodesPositionInPrintForms.ProductColumn Then
                    LineSectionArea.Parameters.ProductDescription = LineSectionArea.Parameters.ProductDescription + Chars.CR + CodesPresentation;                    
                EndIf;
            EndIf;    
            
			// Bundles
            If DisplayPrintOption Then 
                If PrintParams.Discount Then 
                    If PrintParams.CodesPosition <> Enums.CodesPositionInPrintForms.SeparateColumn Then 
                        LineSectionArea.Areas.LineSectionWithoutCode.TextColor = BundlesServer.GetBundleComponentsColor(TabSelection, EmptyColor);
                    Else
                        LineSectionArea.Areas.LineSection.TextColor = BundlesServer.GetBundleComponentsColor(TabSelection, EmptyColor);
                    EndIf;    
                Else
                    // Recalculate the price to display the correct information with a hidden discount.
                    LineSectionArea.Parameters.Price = TabSelection.Amount/TabSelection.Quantity;
                    
                    If PrintParams.CodesPosition <> Enums.CodesPositionInPrintForms.SeparateColumn Then 
                        LineSectionArea.Areas.LineSectionWithoutItemAndDiscount.TextColor = BundlesServer.GetBundleComponentsColor(TabSelection, EmptyColor);
                    Else
                        LineSectionArea.Areas.LineSectionWithoutDiscount.TextColor = BundlesServer.GetBundleComponentsColor(TabSelection, EmptyColor);
                    EndIf;            
                EndIf;    
            Else            
                LineSectionArea.Areas.LineSection.TextColor = BundlesServer.GetBundleComponentsColor(TabSelection, EmptyColor);
            EndIf;
			// End Bundles
			
			LineSectionArea.Parameters.Price = Format(TabSelection.Price, "NFD= " + PricePrecision);
			
			AreasToBeChecked.Clear();
			AreasToBeChecked.Add(LineSectionArea);
			For Each Area In TotalsAndTaxesAreasArray Do
				AreasToBeChecked.Add(Area);
			EndDo;
			AreasToBeChecked.Add(PageNumberArea);
			
			If Common.SpreadsheetDocumentFitsPage(SpreadsheetDocument, AreasToBeChecked) Then
				
				SpreadsheetDocument.Put(LineSectionArea);
				
			Else
				
				SpreadsheetDocument.Put(SeeNextPageArea);
				
				AreasToBeChecked.Clear();
				AreasToBeChecked.Add(EmptyLineArea);
				AreasToBeChecked.Add(PageNumberArea);
				
				For i = 1 To 50 Do
					
					If Not Common.SpreadsheetDocumentFitsPage(SpreadsheetDocument, AreasToBeChecked)
						Or i = 50 Then
						
						PageNumber = PageNumber + 1;
						PageNumberArea.Parameters.PageNumber = PageNumber;
						SpreadsheetDocument.Put(PageNumberArea);
						Break;
						
					Else
						
						SpreadsheetDocument.Put(EmptyLineArea);
						
					EndIf;
					
				EndDo;
				
				SpreadsheetDocument.PutHorizontalPageBreak();
				SpreadsheetDocument.Put(TitleArea);
				SpreadsheetDocument.Put(LineHeaderArea);
				SpreadsheetDocument.Put(LineSectionArea);
				
			EndIf;
			
		EndDo;
		
		#EndRegion
		
		#Region PrintSimplifiedTaxInvoiceTotalsAndTaxesArea
		
		For Each Area In TotalsAndTaxesAreasArray Do
			
			SpreadsheetDocument.Put(Area);
			
		EndDo;
        
        #Region PrintAdditionalAttributes
        If DisplayPrintOption And PrintParams.AdditionalAttributes And PrintManagementServerCallDrive.HasAdditionalAttributes(Header.Ref) Then
            
            SpreadsheetDocument.Put(EmptyLineArea);
            
            AddAttribHeader = Template.GetArea("AdditionalAttributesStaticHeader");
            SpreadsheetDocument.Put(AddAttribHeader);
            
            SpreadsheetDocument.Put(EmptyLineArea);
            
            AddAttribHeader = Template.GetArea("AdditionalAttributesHeader");
            SpreadsheetDocument.Put(AddAttribHeader);
            
            AddAttribRow = Template.GetArea("AdditionalAttributesRow");
            
            For each Attr In Header.Ref.AdditionalAttributes Do
                AddAttribRow.Parameters.AddAttributeName = Attr.Property.Title;
                AddAttribRow.Parameters.AddAttributeValue = Attr.Value;
                SpreadsheetDocument.Put(AddAttribRow);                
            EndDo;                
        EndIf;    
        #EndRegion
        
		AreasToBeChecked.Clear();
		AreasToBeChecked.Add(EmptyLineArea);
		AreasToBeChecked.Add(PageNumberArea);
		
		For i = 1 To 50 Do
			
			If Not Common.SpreadsheetDocumentFitsPage(SpreadsheetDocument, AreasToBeChecked)
				Or i = 50 Then
				
				PageNumber = PageNumber + 1;
				PageNumberArea.Parameters.PageNumber = PageNumber;
				SpreadsheetDocument.Put(PageNumberArea);
				Break;
				
			Else
				
				SpreadsheetDocument.Put(EmptyLineArea);
				
			EndIf;
			
		EndDo;
		
		#EndRegion
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, Header.Ref);
		
	EndDo;
	
	SpreadsheetDocument.FitToPage = True;
	
	Return SpreadsheetDocument;
	
EndFunction

#EndRegion

#EndRegion

#EndIf
