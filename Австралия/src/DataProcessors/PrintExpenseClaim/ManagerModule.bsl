#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Function PrintForm(ObjectsArray, PrintObjects, TemplateName, PrintParams = Undefined) Export
	
	If TemplateName = "ExpenseClaim" Then
		
		Return PrintExpenseClaim(ObjectsArray, PrintObjects, TemplateName, PrintParams); 
		
	EndIf;
	
EndFunction

#EndRegion

#Region Private

Function PrintExpenseClaim(ObjectsArray, PrintObjects, TemplateName, PrintParams)
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_ExpenseClaim";
	
	Query = New Query();
	Query.SetParameter("ObjectsArray", ObjectsArray);
	
	Query.Text =
	"SELECT ALLOWED
	|	ExpenseReport.Ref AS Ref,
	|	ExpenseReport.Number AS Number,
	|	ExpenseReport.Date AS Date,
	|	ExpenseReport.Company AS Company,
	|	CAST(ExpenseReport.Comment AS STRING(1024)) AS Comment,
	|	ExpenseReport.Employee AS Employee,
	|	ExpenseReport.DocumentCurrency AS DocumentCurrency,
	|	ExpenseReport.BeginOfPeriod AS BeginOfPeriod,
	|	ExpenseReport.EndOfPeriod AS EndOfPeriod,
	|	CAST(ExpenseReport.BusinessPurpose AS STRING(100)) AS Purpose
	|INTO ExpenseReport
	|FROM
	|	Document.ExpenseReport AS ExpenseReport
	|WHERE
	|	ExpenseReport.Ref IN(&ObjectsArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	ExpenseReport.Ref AS Ref,
	|	ExpenseReport.Number AS DocumentNumber,
	|	ExpenseReport.Date AS DocumentDate,
	|	ExpenseReport.Company AS Company,
	|	Companies.LogoFile AS CompanyLogoFile,
	|	ExpenseReport.Comment AS Comment,
	|	ExpenseReport.Employee AS Employee,
	|	ExpenseReport.DocumentCurrency AS DocumentCurrency,
	|	ExpenseReport.BeginOfPeriod AS BeginOfPeriod,
	|	ExpenseReport.EndOfPeriod AS EndOfPeriod,
	|	ExpenseReport.Purpose AS Purpose
	|INTO Header
	|FROM
	|	ExpenseReport AS ExpenseReport
	|		LEFT JOIN Catalog.Companies AS Companies
	|		ON ExpenseReport.Company = Companies.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	ExpenseReportInventory.Ref AS Ref,
	|	ExpenseReportInventory.LineNumber AS LineNumber,
	|	ExpenseReportInventory.Products AS Products,
	|	ExpenseReportInventory.Characteristic AS Characteristic,
	|	ExpenseReportInventory.Batch AS Batch,
	|	ExpenseReportInventory.Quantity AS Quantity,
	|	ExpenseReportInventory.MeasurementUnit AS MeasurementUnit,
	|	ExpenseReport.DocumentCurrency AS DocumentCurrency,
	|	ExpenseReportInventory.IncomingDocumentDate AS IncomingDocumentDate,
	|	ExpenseReportInventory.IncomingDocumentNumber AS IncomingDocumentNumber,
	|	ExpenseReportInventory.Total AS TotalAmount
	|INTO FilteredInventory
	|FROM
	|	ExpenseReport AS ExpenseReport
	|		INNER JOIN Document.ExpenseReport.Inventory AS ExpenseReportInventory
	|		ON ExpenseReport.Ref = ExpenseReportInventory.Ref
	|
	|UNION ALL
	|
	|SELECT
	|	ExpenseReportExpenses.Ref,
	|	ExpenseReportExpenses.LineNumber,
	|	ExpenseReportExpenses.Products,
	|	VALUE(Catalog.ProductsCharacteristics.EmptyRef),
	|	VALUE(Catalog.ProductsBatches.EmptyRef),
	|	ExpenseReportExpenses.Quantity,
	|	ExpenseReportExpenses.MeasurementUnit,
	|	ExpenseReport.DocumentCurrency,
	|	ExpenseReportExpenses.IncomingDocumentDate,
	|	ExpenseReportExpenses.IncomingDocumentNumber,
	|	ExpenseReportExpenses.Total
	|FROM
	|	ExpenseReport AS ExpenseReport
	|		INNER JOIN Document.ExpenseReport.Expenses AS ExpenseReportExpenses
	|		ON ExpenseReport.Ref = ExpenseReportExpenses.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ExpenseReportAdvancesPaid.Ref AS Ref,
	|	SUM(ExpenseReportAdvancesPaid.Amount) AS AdvanceAmount
	|INTO Advances
	|FROM
	|	ExpenseReport AS ExpenseReport
	|		INNER JOIN Document.ExpenseReport.AdvancesPaid AS ExpenseReportAdvancesPaid
	|		ON ExpenseReport.Ref = ExpenseReportAdvancesPaid.Ref
	|
	|GROUP BY
	|	ExpenseReportAdvancesPaid.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Header.Ref AS Ref,
	|	Header.DocumentNumber AS DocumentNumber,
	|	Header.DocumentDate AS DocumentDate,
	|	Header.Company AS Company,
	|	Header.CompanyLogoFile AS CompanyLogoFile,
	|	Header.Employee AS Employee,
	|	Header.Comment AS Comment,
	|	Header.BeginOfPeriod AS BeginOfPeriod,
	|	Header.EndOfPeriod AS EndOfPeriod,
	|	Header.Purpose AS Purpose,
	|	MIN(FilteredInventory.LineNumber) AS LineNumber,
	|	CatalogProducts.SKU AS SKU,
	|	CASE
	|		WHEN (CAST(CatalogProducts.DescriptionFull AS STRING(1024))) <> """"
	|			THEN CAST(CatalogProducts.DescriptionFull AS STRING(1024))
	|		ELSE CatalogProducts.Description
	|	END AS ProductDescription,
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
	|	SUM(FilteredInventory.Quantity) AS Quantity,
	|	FilteredInventory.Products AS Products,
	|	FilteredInventory.Characteristic AS Characteristic,
	|	FilteredInventory.MeasurementUnit AS MeasurementUnit,
	|	FilteredInventory.Batch AS Batch,
	|	FilteredInventory.DocumentCurrency AS DocumentCurrency,
	|	FilteredInventory.IncomingDocumentDate AS IncomingDocumentDate,
	|	FilteredInventory.IncomingDocumentNumber AS IncomingDocumentNumber,
	|	SUM(FilteredInventory.TotalAmount) AS TotalAmount,
	|	MAX(ISNULL(Advances.AdvanceAmount, 0)) AS AdvanceAmount
	|INTO Tabular
	|FROM
	|	Header AS Header
	|		INNER JOIN FilteredInventory AS FilteredInventory
	|		ON Header.Ref = FilteredInventory.Ref
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON (FilteredInventory.Products = CatalogProducts.Ref)
	|		LEFT JOIN Catalog.ProductsCharacteristics AS CatalogCharacteristics
	|		ON (FilteredInventory.Characteristic = CatalogCharacteristics.Ref)
	|		LEFT JOIN Catalog.ProductsBatches AS CatalogBatches
	|		ON (FilteredInventory.Batch = CatalogBatches.Ref)
	|		LEFT JOIN Advances AS Advances
	|		ON Header.Ref = Advances.Ref
	|
	|GROUP BY
	|	Header.DocumentNumber,
	|	Header.DocumentDate,
	|	Header.Company,
	|	Header.Ref,
	|	Header.CompanyLogoFile,
	|	Header.Comment,
	|	CatalogProducts.SKU,
	|	CASE
	|		WHEN (CAST(CatalogProducts.DescriptionFull AS STRING(1024))) <> """"
	|			THEN CAST(CatalogProducts.DescriptionFull AS STRING(1024))
	|		ELSE CatalogProducts.Description
	|	END,
	|	CASE
	|		WHEN CatalogProducts.UseCharacteristics
	|			THEN CatalogCharacteristics.Description
	|		ELSE """"
	|	END,
	|	FilteredInventory.Products,
	|	CASE
	|		WHEN CatalogProducts.UseBatches
	|			THEN CatalogBatches.Description
	|		ELSE """"
	|	END,
	|	FilteredInventory.Characteristic,
	|	FilteredInventory.MeasurementUnit,
	|	FilteredInventory.Batch,
	|	FilteredInventory.DocumentCurrency,
	|	FilteredInventory.IncomingDocumentDate,
	|	FilteredInventory.IncomingDocumentNumber,
	|	Header.BeginOfPeriod,
	|	Header.EndOfPeriod,
	|	Header.Purpose,
	|	Header.Employee
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Tabular.Ref AS Ref,
	|	Tabular.DocumentNumber AS DocumentNumber,
	|	Tabular.DocumentDate AS DocumentDate,
	|	Tabular.Company AS Company,
	|	Tabular.CompanyLogoFile AS CompanyLogoFile,
	|	Tabular.Employee AS Employee,
	|	Tabular.Comment AS Comment,
	|	Tabular.BeginOfPeriod AS BeginOfPeriod,
	|	Tabular.EndOfPeriod AS EndOfPeriod,
	|	Tabular.Purpose AS Purpose,
	|	Tabular.LineNumber AS LineNumber,
	|	Tabular.SKU AS SKU,
	|	Tabular.ProductDescription AS ProductDescription,
	|	FALSE AS UseSerialNumbers,
	|	Tabular.Quantity AS Quantity,
	|	Tabular.Products AS Products,
	|	Tabular.CharacteristicDescription AS CharacteristicDescription,
	|	Tabular.BatchDescription AS BatchDescription,
	|	Tabular.Characteristic AS Characteristic,
	|	Tabular.MeasurementUnit AS MeasurementUnit,
	|	Tabular.Batch AS Batch,
	|	FALSE AS ContentUsed,
	|	Tabular.DocumentCurrency AS DocumentCurrency,
	|	Tabular.IncomingDocumentDate AS IncomingDocumentDate,
	|	Tabular.IncomingDocumentNumber AS IncomingDocumentNumber,
	|	Tabular.TotalAmount AS TotalAmount,
	|	Tabular.AdvanceAmount AS AdvanceAmount
	|FROM
	|	Tabular AS Tabular
	|
	|ORDER BY
	|	Tabular.DocumentNumber,
	|	LineNumber
	|TOTALS
	|	MAX(DocumentNumber),
	|	MAX(DocumentDate),
	|	MAX(Company),
	|	MAX(CompanyLogoFile),
	|	MAX(Employee),
	|	MAX(Comment),
	|	MAX(BeginOfPeriod),
	|	MAX(EndOfPeriod),
	|	MAX(Purpose),
	|	MAX(AdvanceAmount)
	|BY
	|	Ref";
	
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
	
	QueryResult = Query.Execute();
	
	FirstDocument = True;
	
	Header = QueryResult.Select(QueryResultIteration.ByGroups);
	OutputSpreadsheetDocument(PrintObjects, SpreadsheetDocument, Header, FirstDocument, PrintParams);
	
	SpreadsheetDocument.FitToPage = True;
	
	Return SpreadsheetDocument;
	
EndFunction

Procedure OutputSpreadsheetDocument(PrintObjects, SpreadsheetDocument, Header, FirstDocument, PrintParams)
	
	DisplayPrintOption = (PrintParams <> Undefined);
	
	// MultilingualSupport
	If PrintParams = Undefined Then
		LanguageCode = NationalLanguageSupportClientServer.DefaultLanguageCode();
	Else
		LanguageCode = PrintParams.LanguageCode;
	EndIf;
	// End MultilingualSupport
	
	While Header.Next() Do
		
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_ExpenseClaim";
		
		Template = PrintManagement.PrintFormTemplate("DataProcessor.PrintExpenseClaim.PF_MXL_ExpenseClaim", LanguageCode);
		
		#Region PrintTitleArea
		
		TitleArea = Template.GetArea("Title");
		TitleArea.Parameters.Fill(Header);
		
		If DisplayPrintOption Then 
			TitleArea.Parameters.OriginalDuplicate = ?(PrintParams.OriginalCopy,
				NStr("en = 'ORIGINAL'; ru = 'ОРИГИНАЛ';pl = 'ORYGINAŁ';es_ES = 'ORIGINAL';es_CO = 'ORIGINAL';tr = 'ORİJİNAL';it = 'ORIGINALE';de = 'ORIGINAL'", LanguageCode),
				NStr("en = 'COPY'; ru = 'КОПИЯ';pl = 'KOPIA';es_ES = 'COPIA';es_CO = 'COPIA';tr = 'KOPYA';it = 'COPIA';de = 'KOPIE'", LanguageCode));
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
		
		#Region PrintCompanyInfoArea
		
		CompanyInfoArea = Template.GetArea("CompanyInfo");
		
		InfoAboutCompany = DriveServer.InfoAboutLegalEntityIndividual(
			Header.Company,
			Header.DocumentDate,
			,
			,
			,
			LanguageCode);
		CompanyInfoArea.Parameters.Fill(InfoAboutCompany);
		BarcodesInPrintForms.AddBarcodeToTableDocument(CompanyInfoArea, Header.Ref);
		SpreadsheetDocument.Put(CompanyInfoArea);
		
		#EndRegion
		
		#Region PrintDocumentHeaderArea
		
		DocumentHeaderArea = Template.GetArea("DocumentHeader");
		DocumentHeaderArea.Parameters.Fill(Header);
		
		DocumentHeaderArea.Parameters.EmployeeDescr = GetEmployeeDescription(Header.Employee, LanguageCode);
		
		BeginOfPeriod = Format(Header.BeginOfPeriod, "DLF=D");
		EndOfPeriod = Format(Header.EndOfPeriod, "DLF=D");
		
		If ValueIsFilled(BeginOfPeriod) And ValueIsFilled(EndOfPeriod) Then
			PeriodStr = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'from %1 to %2'; ru = 'с %1 по %2';pl = 'od %1 do %2';es_ES = 'desde %1 hasta %2';es_CO = 'desde %1 hasta %2';tr = '%1 itibaren %2 kadar';it = 'da %1 a %2';de = 'von %1 bis %2'", LanguageCode),
				BeginOfPeriod,
				EndOfPeriod);
		ElsIf ValueIsFilled(EndOfPeriod) Then
			PeriodStr = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'to %1'; ru = 'до %1';pl = 'do %1';es_ES = 'a %1';es_CO = 'a %1';tr = 'bitiş %1';it = 'a %1';de = 'bis %1'", LanguageCode),
				EndOfPeriod);
		ElsIf ValueIsFilled(BeginOfPeriod) Then
			PeriodStr = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'from %1'; ru = 'с %1';pl = 'od %1';es_ES = 'desde %1';es_CO = 'desde %1';tr = 'başlangıç %1';it = 'dal %1';de = 'von %1'", LanguageCode),
				BeginOfPeriod);
		Else
			PeriodStr = "";
		EndIf;
		
		DocumentHeaderArea.Parameters.Period = PeriodStr;
		SpreadsheetDocument.Put(DocumentHeaderArea);
		
		#EndRegion
		
		#Region PrintCommentArea
		
		CommentArea = Template.GetArea("Comment");
		CommentArea.Parameters.Fill(Header);
		SpreadsheetDocument.Put(CommentArea);
		
		#EndRegion
		
		#Region PrintLinesArea
		
		If DisplayPrintOption And PrintParams.CodesPosition <> Enums.CodesPositionInPrintForms.SeparateColumn Then
			LineHeaderArea = Template.GetArea("LineHeaderWithoutCode");
			LineSectionArea	= Template.GetArea("LineSectionWithoutCode");
		Else
			LineHeaderArea = Template.GetArea("LineHeader");
			LineSectionArea	= Template.GetArea("LineSection");
		EndIf;
		
		SpreadsheetDocument.Put(LineHeaderArea);
		
		SeeNextPageArea	= Template.GetArea("SeeNextPage");
		EmptyLineArea	= Template.GetArea("EmptyLine");
		PageNumberArea	= Template.GetArea("PageNumber");
		
		PageNumber = 0;
		
		TabSelection = Header.Select();
		While TabSelection.Next() Do
			
			LineSectionArea.Parameters.Fill(TabSelection);
			
			DriveClientServer.ComplimentProductDescription(LineSectionArea.Parameters.ProductDescription, TabSelection);
			
			// Display selected codes if functional option is turned on.
			If DisplayPrintOption Then
				CodesPresentation = PrintManagementServerCallDrive.GetCodesPresentation(PrintParams, TabSelection.Products);
				If PrintParams.CodesPosition = Enums.CodesPositionInPrintForms.SeparateColumn Then
					LineSectionArea.Parameters.SKU = CodesPresentation;
				ElsIf PrintParams.CodesPosition = Enums.CodesPositionInPrintForms.ProductColumn Then
					LineSectionArea.Parameters.ProductDescription = LineSectionArea.Parameters.ProductDescription
						+ Chars.CR + CodesPresentation;
				EndIf;
			EndIf;
			
			AreasToBeChecked = New Array;
			AreasToBeChecked.Add(LineSectionArea);
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
		
		#Region PrintTotalsArea
		
		LineTotalArea = Template.GetArea("LineTotal");
		LineTotalArea.Parameters.Fill(Header);
		SpreadsheetDocument.Put(LineTotalArea);
		
		AreasToBeChecked.Clear();
		AreasToBeChecked.Add(EmptyLineArea);
		AreasToBeChecked.Add(PageNumberArea);
		
		#Region PrintAdditionalAttributes
		
		If DisplayPrintOption
			And PrintParams.AdditionalAttributes
			And PrintManagementServerCallDrive.HasAdditionalAttributes(Header.Ref) Then
			
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
	
EndProcedure

Function GetEmployeeDescription(EmployeeRef, LanguageCode)
	
	Result = "";
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	Employees.Presentation AS Description
	|FROM
	|	Catalog.Employees AS Employees
	|WHERE
	|	Employees.Ref = &EmployeeRef";
	
	Query.SetParameter("EmployeeRef", EmployeeRef);
	
	// MultilingualSupport
	DriveServer.ChangeQueryTextForCurrentLanguage(Query.Text, LanguageCode);
	// End MultilingualSupport
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Result = Selection.Description;
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion

#EndIf