#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Procedure Print(ObjectsArray, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters) Export
	
	PrintManagement.OutputSpreadsheetDocumentToCollection(
		PrintFormsCollection,
		"PF_MXL_ConfirmationOfArrival",
		NStr("en = 'Confirmation of arrival for sales invoice'; ru = 'Подтверждение прибытия для инвойса покупателю';pl = 'Potwierdzenie przybycia dla faktury sprzedaży';es_ES = 'Confirmación de llegada de factura de venta';es_CO = 'Confirmación de llegada de factura de venta';tr = 'Satış faturası için varış onayı';it = 'Conferma dell''arrivo della fattura di vendita';de = 'Ankunftsbestätigung für Verkaufsrechnung'"),
		PrintConfirmationOfArrival(ObjectsArray, PrintObjects, PrintParameters.Result));

	// parameters of sending printing forms by email
	DriveServer.FillSendingParameters(OutputParameters.SendOptions, ObjectsArray, PrintFormsCollection);
	
EndProcedure

#EndRegion

#Region Private

Function PrintConfirmationOfArrival(ObjectsArray, PrintObjects, PrintParams = Undefined)
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_ConfirmationOfArrival";
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	SalesInvoice.Ref AS Ref,
	|	SalesInvoice.CompanyVATNumber AS CompanyVATNumber,
	|	SalesInvoice.Date AS DocumentDate,
	|	SalesInvoice.Company AS Company,
	|	SalesInvoice.Counterparty AS Counterparty,
	|	Counterparties.RegistrationCountry AS Country
	|FROM
	|	Document.SalesInvoice AS SalesInvoice
	|		INNER JOIN Catalog.Counterparties AS Counterparties
	|		ON SalesInvoice.Counterparty = Counterparties.Ref
	|WHERE
	|	SalesInvoice.Ref IN(&ObjectsArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	SalesInvoice.Ref AS Ref,
	|	CatalogProducts.SKU AS SKU,
	|	PRESENTATION(SalesInvoiceInventory.Products) AS ProductDescription,
	|	CASE
	|		WHEN SalesInvoiceInventory.DeliveryEndDate <> DATETIME(1, 1, 1)
	|			THEN SalesInvoiceInventory.DeliveryEndDate
	|		WHEN SalesInvoice.DeliveryEndDate <> DATETIME(1, 1, 1)
	|			THEN SalesInvoice.DeliveryEndDate
	|		ELSE SalesInvoice.Date
	|	END AS DateOfSupply,
	|	SalesInvoice.DocumentCurrency AS Currency,
	|	SUM(SalesInvoiceInventory.Quantity) AS Quantity,
	|	SalesInvoiceInventory.MeasurementUnit AS Unit,
	|	SUM(SalesInvoiceInventory.Total) AS Total,
	|	MIN(SalesInvoiceInventory.LineNumber) AS LineNumber
	|FROM
	|	Document.SalesInvoice.Inventory AS SalesInvoiceInventory
	|		INNER JOIN Catalog.Products AS CatalogProducts
	|		ON SalesInvoiceInventory.Products = CatalogProducts.Ref
	|		INNER JOIN Document.SalesInvoice AS SalesInvoice
	|		ON SalesInvoiceInventory.Ref = SalesInvoice.Ref
	|WHERE
	|	SalesInvoiceInventory.Ref IN(&ObjectsArray)
	|
	|GROUP BY
	|	SalesInvoice.Ref,
	|	CatalogProducts.SKU,
	|	SalesInvoice.DocumentCurrency,
	|	CASE
	|		WHEN SalesInvoiceInventory.DeliveryEndDate <> DATETIME(1, 1, 1)
	|			THEN SalesInvoiceInventory.DeliveryEndDate
	|		WHEN SalesInvoice.DeliveryEndDate <> DATETIME(1, 1, 1)
	|			THEN SalesInvoice.DeliveryEndDate
	|		ELSE SalesInvoice.Date
	|	END,
	|	SalesInvoiceInventory.MeasurementUnit,
	|	PRESENTATION(SalesInvoiceInventory.Products)
	|
	|ORDER BY
	|	LineNumber
	|TOTALS BY
	|	Ref";
	
	Query.SetParameter("DateOfSupply", CurrentSessionDate());
	Query.SetParameter("ObjectsArray", ObjectsArray);
	
	// MultilingualSupport
	If PrintParams = Undefined Or Not PrintParams.Property("LanguageCode") Then
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
	
	Header = ResultArray[0].Select();
	ProductsByRefs = ResultArray[1].Select(QueryResultIteration.ByGroups);
	
	Template = DataProcessors.ConfirmationOfArrival.GetTemplate("PF_MXL_ConfirmationOfArrival");
	
	TitleArea = Template.GetArea("Title");
	LineHeaderArea = Template.GetArea("LineHeader");
	LineSectionArea = Template.GetArea("LineSection");
	CounterpartyInfoArea = Template.GetArea("CounterpartyInfo");
	SignaturesArea = Template.GetArea("Signtures");
	PageNumberArea = Template.GetArea("PageNumber");
	SeeNextPageArea = Template.GetArea("SeeNextPage");
	EmptyLineArea = Template.GetArea("EmptyLine");
	
	PageNumber = 0;
	
	AreasToBeChecked = New Array;
	
	While Header.Next() Do
		
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_ConfirmationOfArrival";
		
		Template = PrintManagement.PrintFormTemplate(
			"DataProcessor.ConfirmationOfArrival.PF_MXL_ConfirmationOfArrival", LanguageCode);
		
		TitleArea.Parameters.FullDescr = DriveServer.InfoAboutLegalEntityIndividual(
			Header.Company, Header.DocumentDate, , , Header.CompanyVATNumber, LanguageCode).FullDescr;
			
		SpreadsheetDocument.Put(TitleArea);
		SpreadsheetDocument.Put(LineHeaderArea);
		
		ProductsByRefs.Reset();
		If ProductsByRefs.FindNext(New Structure("Ref", Header.Ref)) Then
			
			Products = ProductsByRefs.Select();
			While Products.Next() Do
				
				FillPropertyValues(LineSectionArea.Parameters, Products);
				
				AreasToBeChecked.Clear();
				AreasToBeChecked.Add(LineSectionArea);
				AreasToBeChecked.Add(PageNumberArea);
				
				If Common.SpreadsheetDocumentFitsPage(SpreadsheetDocument, AreasToBeChecked) Then
			
					SpreadsheetDocument.Put(LineSectionArea);
				
				Else
				
					SpreadsheetDocument.Put(SeeNextPageArea);
				
					AreasToBeChecked.Clear();
					AreasToBeChecked.Add(EmptyLineArea);
				
					For i = 1 To 60 Do
					
						If Not Common.SpreadsheetDocumentFitsPage(SpreadsheetDocument, AreasToBeChecked)
							Or i = 60 Then
							
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
			
		EndIf;
		
		CounterpartyInfoArea.Parameters.Country = Header.Country;
		CounterpartyInfoArea.Parameters.FullDescr = DriveServer.InfoAboutLegalEntityIndividual(
			Header.Counterparty, Header.DocumentDate, , , , LanguageCode).FullDescr;
			
		AreasToBeChecked.Clear();
		
		AreasToBeChecked.Add(CounterpartyInfoArea);
		AreasToBeChecked.Add(SignaturesArea);
		AreasToBeChecked.Add(PageNumberArea);
		
		If Common.SpreadsheetDocumentFitsPage(SpreadsheetDocument, AreasToBeChecked) Then
			
			SpreadsheetDocument.Put(CounterpartyInfoArea);
			SpreadsheetDocument.Put(SignaturesArea);
			
		Else
			
			AreasToBeChecked.Clear();
			AreasToBeChecked.Add(EmptyLineArea);
			AreasToBeChecked.Add(PageNumberArea);
		
			For i = 1 To 60 Do
				
				If Not Common.SpreadsheetDocumentFitsPage(SpreadsheetDocument, AreasToBeChecked)
					Or i = 60 Then
					
					PageNumber = PageNumber + 1;
					PageNumberArea.Parameters.PageNumber = PageNumber;
					SpreadsheetDocument.Put(PageNumberArea);
					Break;
					
				Else
					
					SpreadsheetDocument.Put(EmptyLineArea);
					
				EndIf;
				
			EndDo;
			
			SpreadsheetDocument.PutHorizontalPageBreak();
			SpreadsheetDocument.Put(CounterpartyInfoArea);
			SpreadsheetDocument.Put(SignaturesArea);
			
		EndIf;
		
		AreasToBeChecked.Clear();
		AreasToBeChecked.Add(EmptyLineArea);
		AreasToBeChecked.Add(PageNumberArea);
			
		For i = 1 To 60 Do
			
			If Not Common.SpreadsheetDocumentFitsPage(SpreadsheetDocument, AreasToBeChecked)
				Or i = 60 Then
				
				PageNumber = PageNumber + 1;
				PageNumberArea.Parameters.PageNumber = PageNumber;
				SpreadsheetDocument.Put(PageNumberArea);
				Break;
				
			Else
				
				SpreadsheetDocument.Put(EmptyLineArea);
				
			EndIf;
			
		EndDo;
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, Header.Ref);
		
	EndDo;
	
	SpreadsheetDocument.FitToPage = True;
	
	Return SpreadsheetDocument;
	
EndFunction

#EndRegion

#EndIf