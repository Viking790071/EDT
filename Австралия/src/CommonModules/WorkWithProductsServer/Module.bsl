
#Region WorkWithTabularSectionProducts

Procedure FillDataInTabularSectionRow(Object, TabularSectionName, TabularSectionRow) Export
	
	StructureData = New Structure;
	StructureData.Insert("Company", Object.Company);
	StructureData.Insert("Products", TabularSectionRow.Products);
	If WorkWithProductsClientServer.IsObjectAttribute("Characteristic", TabularSectionRow) Then
		StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
	EndIf;
	StructureData.Insert("ProcessingDate", CurrentSessionDate());
	If WorkWithProductsClientServer.IsObjectAttribute("Factor", TabularSectionRow) 
		AND WorkWithProductsClientServer.IsObjectAttribute("Multiplicity", TabularSectionRow) 
		Then
		StructureData.Insert("TimeNorm", 1);
	EndIf;
	If WorkWithProductsClientServer.IsObjectAttribute("VATTaxation", Object) Then
		StructureData.Insert("VATTaxation", Object.VATTaxation);
	EndIf;
	If WorkWithProductsClientServer.IsObjectAttribute("DocumentCurrency", Object) Then
		StructureData.Insert("DocumentCurrency", Object.DocumentCurrency);
	EndIf;
	If WorkWithProductsClientServer.IsObjectAttribute("AmountIncludesVAT", Object) Then
		StructureData.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
	EndIf;
	If WorkWithProductsClientServer.IsObjectAttribute("PriceKind", Object) AND ValueIsFilled(Object.PriceKind) Then
		StructureData.Insert("PriceKind", Object.PriceKind);
	EndIf; 
	If WorkWithProductsClientServer.IsObjectAttribute("SupplierPriceTypes", Object) AND ValueIsFilled(Object.SupplierPriceTypes) Then
		StructureData.Insert("SupplierPriceTypes", Object.SupplierPriceTypes);
	EndIf; 
	If WorkWithProductsClientServer.IsObjectAttribute("MeasurementUnit", Object) AND TypeOf(TabularSectionRow.MeasurementUnit)=Type("CatalogRef.UOM") Then
		StructureData.Insert("Factor", TabularSectionRow.MeasurementUnit.Factor);
	Else
		StructureData.Insert("Factor", 1);
	EndIf;
	If WorkWithProductsClientServer.IsObjectAttribute("WorkKind", Object) AND ValueIsFilled(Object.WorkKind) Then
		StructureData.Insert("WorkKind", Object.WorkKind);
	EndIf; 
	
	UseDiscounts = WorkWithProductsClientServer.IsObjectAttribute("DiscountMarkupKind", Object);
	If UseDiscounts AND ValueIsFilled(Object.DiscountMarkupKind) Then
		StructureData.Insert("DiscountMarkupKind", Object.DiscountMarkupKind);
	EndIf; 
	If WorkWithProductsClientServer.IsObjectAttribute("DiscountCard", Object) AND ValueIsFilled(Object.DiscountCard) Then
		StructureData.Insert("DiscountCard", Object.DiscountCard);
		StructureData.Insert("DiscountPercentByDiscountCard", Object.DiscountPercentByDiscountCard);		
	EndIf; 

	RowFillingData = GetProductDataOnChange(StructureData);
	
	FillPropertyValues(TabularSectionRow, RowFillingData);
	
	If WorkWithProductsClientServer.IsObjectAttribute("Quantity", TabularSectionRow) Then
		
		If TabularSectionName = "Works" Then
			
			TabularSectionRow.Quantity = StructureData.TimeNorm;
			
			If Not ValueIsFilled(TabularSectionRow.Multiplicity) Then
				TabularSectionRow.Multiplicity = 1;
			EndIf;
			If Not ValueIsFilled(TabularSectionRow.Factor) Then
				TabularSectionRow.Factor = 1;
			EndIf;
			
			TabularSectionRow.ProductsTypeService = StructureData.IsService;
			
		ElsIf TabularSectionName = "Inventory" Then
			
			If WorkWithProductsClientServer.IsObjectAttribute("ProductsTypeInventory", Object) Then
				TabularSectionRow.ProductsTypeInventory = StructureData.IsInventory;
			EndIf;
			
			If Not ValueIsFilled(TabularSectionRow.MeasurementUnit) Then
				TabularSectionRow.MeasurementUnit = StructureData.BaseMeasurementUnit;
			EndIf;
			
		ElsIf TabularSectionName = "ConsumerMaterials" Then
			
			If Not ValueIsFilled(TabularSectionRow.MeasurementUnit) Then
				TabularSectionRow.MeasurementUnit = StructureData.BaseMeasurementUnit;
			EndIf;
			
		EndIf;
		
		WorkWithProductsClientServer.CalculateAmountInTabularSectionRow(Object, TabularSectionRow, TabularSectionName);
		
	EndIf;
	
EndProcedure

Function GetProductDataOnChange(StructureData)
	
	ProductsAttributes = Common.ObjectAttributesValues(StructureData.Products, "MeasurementUnit, VATRate, ProductsType");
	
	StructureData.Insert("BaseMeasurementUnit", ProductsAttributes.MeasurementUnit);
	
	StructureData.Insert("IsService", ProductsAttributes.ProductsType = PredefinedValue("Enum.ProductsTypes.Service"));
	StructureData.Insert("IsInventory", ProductsAttributes.ProductsType = PredefinedValue("Enum.ProductsTypes.InventoryItem"));
	
	If StructureData.Property("TimeNorm") Then
		StructureData.TimeNorm = DriveServer.GetWorkTimeRate(StructureData);
	EndIf;
	
	If StructureData.Property("VATTaxation")
		AND Not StructureData.VATTaxation = PredefinedValue("Enum.VATTaxationTypes.SubjectToVAT") Then
		
		If StructureData.VATTaxation = PredefinedValue("Enum.VATTaxationTypes.NotSubjectToVAT") Then
			StructureData.Insert("VATRate", Catalogs.VATRates.Exempt);
		Else
			StructureData.Insert("VATRate", Catalogs.VATRates.ZeroRate);
		EndIf;
		
	ElsIf ValueIsFilled(StructureData.Products) And ValueIsFilled(ProductsAttributes.VATRate) Then
		StructureData.Insert("VATRate", ProductsAttributes.VATRate);
	Else
		StructureData.Insert("VATRate", InformationRegisters.AccountingPolicy.GetDefaultVATRate(, StructureData.Company));
	EndIf;
	
	If StructureData.Property("Characteristic") Then
		StructureData.Insert("Specification", DriveServer.GetDefaultSpecification(StructureData.Products, StructureData.Characteristic));
	Else
		StructureData.Insert("Specification", DriveServer.GetDefaultSpecification(StructureData.Products));
	EndIf;
	
	If StructureData.Property("PriceKind") Then
		
		If Not StructureData.Property("Characteristic") Then
			StructureData.Insert("Characteristic", Catalogs.ProductsCharacteristics.EmptyRef());
		EndIf;
		If Not StructureData.Property("DocumentCurrency") AND ValueIsFilled(StructureData.PriceKind) Then
			StructureData.Insert(
				"DocumentCurrency", Common.ObjectAttributeValue(StructureData.PriceKind, "PriceCurrency"));
		EndIf;
		
		If StructureData.Property("WorkKind") Then
		
			CurProduct = StructureData.Products;
			StructureData.Products = StructureData.WorkKind;
			StructureData.Characteristic = Catalogs.ProductsCharacteristics.EmptyRef();
			Price = DriveServer.GetProductsPriceByPriceKind(StructureData);
			StructureData.Insert("Price", Price);
			
			StructureData.Products = CurProduct;
		
		Else
			
			Price = DriveServer.GetProductsPriceByPriceKind(StructureData);
			StructureData.Insert("Price", Price);
			
		EndIf;
		
	Else
		
		StructureData.Insert("Price", 0);
		
	EndIf;
	
	If StructureData.Property("DiscountMarkupKind")
		AND ValueIsFilled(StructureData.DiscountMarkupKind) Then
		StructureData.Insert(
			"DiscountMarkupPercent", Common.ObjectAttributeValue(StructureData.DiscountMarkupKind, "Percent"));
	Else
		StructureData.Insert("DiscountMarkupPercent", 0);
	EndIf;
	
	If StructureData.Property("DiscountPercentByDiscountCard") 
		AND ValueIsFilled(StructureData.DiscountCard) Then
		CurPercent = StructureData.DiscountMarkupPercent;
		StructureData.Insert("DiscountMarkupPercent", CurPercent + StructureData.DiscountPercentByDiscountCard);
	EndIf;
	
	Return StructureData;
	
EndFunction

#EndRegion

Function PrintWarrantyCard(ObjectsArray, PrintObjects, Variant, PrintParams = Undefined) Export
	
	SpreadsheetDocument = New SpreadsheetDocument;
	DocumentType = "";
	TableName = "";
	
	If ObjectsArray.Count() Then
		If TypeOf(ObjectsArray[0]) = Type("DocumentRef.GoodsIssue") Then
			DocumentType = "GoodsIssue";
			TableName = "Products";
		ElsIf TypeOf(ObjectsArray[0]) = Type("DocumentRef.SalesInvoice") Then 
			DocumentType = "SalesInvoice";
			TableName = "Inventory";
		ElsIf TypeOf(ObjectsArray[0]) = Type("DocumentRef.SalesSlip") Then
			DocumentType = "SalesSlip";
			TableName = "Inventory";
		// begin Drive.FullVersion
		ElsIf TypeOf(ObjectsArray[0]) = Type("DocumentRef.Manufacturing") Then
			If ObjectsArray[0].OperationKind = Enums.OperationTypesProduction.Assembly Then
				TableName = "Products";
			ElsIf ObjectsArray[0].OperationKind = Enums.OperationTypesProduction.Disassembly Then
				TableName = "Inventory";
			Else 
				TableName = "Products";
			EndIf; 
			DocumentType = "Manufacturing";
		// end Drive.FullVersion
		EndIf;
	EndIf;
	
	If IsBlankString(DocumentType) Or IsBlankString(TableName) Then
		Return SpreadsheetDocument;
	EndIf;
	
	// MultilingualSupport
	If PrintParams = Undefined Then
		LanguageCode = NationalLanguageSupportClientServer.DefaultLanguageCode();
	Else
		LanguageCode = PrintParams.LanguageCode;
	EndIf;
	
	If LanguageCode <> CurrentLanguage().LanguageCode Then 
		SessionParameters.LanguageCodeForOutput = LanguageCode;
	EndIf;
	// End MultilingualSupport
	
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_WarrantyCard" + Variant;
	SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_" + DocumentType + "_WarrantyCard" + Variant;
		
	Template = PrintManagement.PrintFormTemplate("CommonTemplate.PF_MXL_WarrantyCard", LanguageCode);
	
	Query = New Query;
	Query.SetParameter("ObjectsArray", ObjectsArray);
	Query.Text =
	"SELECT ALLOWED
	|	ProductsTable.Ref AS Ref,
	|	ProductsTable.Ref.Number AS DocumentNumber,
	|	ProductsTable.Ref.Date AS DocumentDate,
	|	ProductsTable.Ref.Date AS PurchaseDate,
	|	ProductsTable.Ref.Company AS Company,
	|	ProductsTable.Ref.%6 AS CompanyVATNumber,
	|	%3 AS FullDescr,
	|	%4 AS BankAccount,
	|	ProductsTable.Products AS Product,
	|	ProductsTable.Products.GuaranteePeriod AS WarrantyPeriod,
	|	SerialNumbersTable.SerialNumber AS SerialNumber
	|FROM
	|	Document.%1.%2 AS ProductsTable
	|		LEFT JOIN Document.%1.%5 AS SerialNumbersTable
	|		ON ProductsTable.ConnectionKey = SerialNumbersTable.ConnectionKey
	|			AND (SerialNumbersTable.Ref IN(&ObjectsArray))
	|WHERE
	|	ProductsTable.Ref IN(&ObjectsArray)
	|TOTALS BY
	|	Ref";
	
	FirstDocument = True;
	Query.Text = StringFunctionsClientServer.SubstituteParametersToString(
		Query.Text, 
		DocumentType, 
		TableName,
		?(DocumentType = "SalesSlip", """""", ?(DocumentType = "Manufacturing", "UNDEFINED", "ProductsTable.Ref.Counterparty.DescriptionFull")),
		?(DocumentType = "SalesInvoice", "ProductsTable.Ref.BankAccount", "UNDEFINED"),
		?(DocumentType = "Manufacturing", ?(TableName = "Inventory", "SerialNumbers", "SerialNumbersProducts"), "SerialNumbers"),
		?(DocumentType = "Manufacturing", "Company.VATNumber", "CompanyVATNumber"));
	
	// MultilingualSupport
	DriveServer.ChangeQueryTextForCurrentLanguage(Query.Text, LanguageCode);
	// End MultilingualSupport
		
	Header = Query.Execute().Select(QueryResultIteration.ByGroups);
	
	While Header.Next() Do
		
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		TitleArea = Template.GetArea("Title");
		TitleArea.Parameters.Fill(Header);
		
		CompanyInfoArea = Template.GetArea("CompanyInfo");
		InfoAboutCompany = DriveServer.InfoAboutLegalEntityIndividual(
			Header.Company, 
			Header.DocumentDate,,
			?(DocumentType = "SalesInvoice", Header.BankAccount, Undefined),
			Header.CompanyVATNumber,
			LanguageCode);
		CompanyInfoArea.Parameters.Fill(InfoAboutCompany);
		
		If Variant = "PerSerialNumber" Then
			
			PerSerialCardArea = Template.GetArea("PerSerialCard");
			
			Products = Header.Select();
			While Products.Next() Do
				SpreadsheetDocument.Put(TitleArea);
				SpreadsheetDocument.Put(CompanyInfoArea);
				
				PerSerialCardArea.Parameters.Fill(Products);
				SpreadsheetDocument.Put(PerSerialCardArea);
				
				SpreadsheetDocument.PutHorizontalPageBreak();
			EndDo;
			
		ElsIf Variant = "Consolidated" Then
			
			SpreadsheetDocument.Put(TitleArea);
			SpreadsheetDocument.Put(CompanyInfoArea);
			
			ConsolidatedCardHeaderArea = Template.GetArea("ConsolidatedCardHeader");
			ConsolidatedCardHeaderArea.Parameters.Fill(Header);
			SpreadsheetDocument.Put(ConsolidatedCardHeaderArea);
			
			ConsolidatedLineArea = Template.GetArea("ConsolidatedLine");
			
			Products = Header.Select();
			While Products.Next() Do
				ConsolidatedLineArea.Parameters.Fill(Products);
				SpreadsheetDocument.Put(ConsolidatedLineArea);
			EndDo;
			
			ConsolidatedFooterArea = Template.GetArea("ConsolidatedFooter");
			SpreadsheetDocument.Put(ConsolidatedFooterArea);
			
		EndIf;
				
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, Header.Ref);
		
	EndDo;
	
	SpreadsheetDocument.FitToPage = True;
	
	Return SpreadsheetDocument;	
	
EndFunction
