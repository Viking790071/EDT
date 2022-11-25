#If Server OR ThickClientOrdinaryApplication OR ExternalConnection Then

#Region Public

#Region GLAccounts

Function GetGLAccountsStructure(StructureData) Export

	GLAccountsForFilling = New Structure;
	
	Return GLAccountsForFilling;
	
EndFunction

#EndRegion

#EndRegion

#Region Internal

#Region LibrariesHandlers

#Region PrintInterface

Function PrintRequestForQuotation(ObjectsArray, PrintObjects, TemplateName, PrintParams = Undefined) Export
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_RequestForQuotation";
	
	Query = New Query();
	Query.SetParameter("ObjectsArray", ObjectsArray);
	Query.SetParameter("UseDefaultTypeOfAccounting", GetFunctionalOption("UseDefaultTypeOfAccounting"));
	
	#Region PrintRequestForQuotationQueryText
	
	Query.Text = 
	"SELECT ALLOWED
	|	RequestForQuotation.Ref AS Ref,
	|	RequestForQuotation.Number AS DocumentNumber,
	|	RequestForQuotation.Date AS DocumentDate,
	|	RequestForQuotation.Company AS Company,
	|	RequestForQuotation.CompanyVATNumber AS CompanyVATNumber,
	|	RequestForQuotation.Subject AS Subject,
	|	RequestForQuotation.DescriptionOfRequirements AS DescriptionOfRequirements,
	|	CAST(RequestForQuotation.Comment AS STRING(1024)) AS Comment,
	|	RequestForQuotation.ClosingDate AS ClosingDate,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN RequestForQuotation.Budget
	|		ELSE VALUE(Document.Budget.EmptyRef)
	|	END AS Budget,
	|	RequestForQuotation.DocumentCurrency AS Currency,
	|	Companies.LogoFile AS CompanyLogoFile
	|INTO RequestForQuotation
	|FROM
	|	Document.RequestForQuotation AS RequestForQuotation
	|		LEFT JOIN Catalog.Companies AS Companies
	|		ON RequestForQuotation.Company = Companies.Ref
	|WHERE
	|	RequestForQuotation.Ref IN(&ObjectsArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	RequestForQuotationProducts.Ref AS Ref,
	|	RequestForQuotation.Company AS Company,
	|	RequestForQuotation.CompanyVATNumber AS CompanyVATNumber,
	|	RequestForQuotation.DocumentNumber AS DocumentNumber,
	|	RequestForQuotation.DocumentDate AS DocumentDate,
	|	RequestForQuotation.Subject AS Subject,
	|	RequestForQuotation.DescriptionOfRequirements AS DescriptionOfRequirements,
	|	RequestForQuotationProducts.LineNumber AS LineNumber,
	|	FALSE AS ContentUsed,
	|	CASE
	|		WHEN (CAST(CatalogProducts.DescriptionFull AS STRING(1024))) <> """"
	|			THEN CAST(CatalogProducts.DescriptionFull AS STRING(1024))
	|		ELSE CatalogProducts.Description
	|	END AS ProductDescription,
	|	CASE
	|		WHEN CatalogProducts.UseCharacteristics
	|			THEN CatalogProductsCharacteristics.Description
	|		ELSE """"
	|	END AS CharacteristicDescription,
	|	"""" AS Batch,
	|	RequestForQuotationProducts.Description AS Description,
	|	CatalogProducts.SKU AS SKU,
	|	RequestForQuotationProducts.MeasurementUnit AS MeasurementUnit,
	|	RequestForQuotationProducts.Quantity AS Quantity,
	|	RequestForQuotationProducts.Products AS Products,
	|	RequestForQuotationProducts.Characteristic AS Characteristic,
	|	RequestForQuotation.Comment AS Comment,
	|	RequestForQuotation.ClosingDate AS ClosingDate,
	|	RequestForQuotation.Currency AS Currency,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN RequestForQuotation.Budget
	|		ELSE VALUE(Document.Budget.EmptyRef)
	|	END AS Budget,
	|	CASE
	|		WHEN RequestForQuotationProducts.Ref IS NULL
	|			THEN FALSE
	|		ELSE TRUE
	|	END AS ExistsTabularSection,
	|	RequestForQuotation.CompanyLogoFile AS CompanyLogoFile
	|FROM
	|	RequestForQuotation AS RequestForQuotation
	|		LEFT JOIN Document.RequestForQuotation.Products AS RequestForQuotationProducts
	|		ON RequestForQuotation.Ref = RequestForQuotationProducts.Ref
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON (RequestForQuotationProducts.Products = CatalogProducts.Ref)
	|		LEFT JOIN Catalog.ProductsCharacteristics AS CatalogProductsCharacteristics
	|		ON (CatalogProductsCharacteristics.Ref = RequestForQuotationProducts.Characteristic)
	|TOTALS
	|	MAX(Company),
	|	MAX(CompanyVATNumber),
	|	MAX(DocumentNumber),
	|	MAX(DocumentDate),
	|	MAX(Subject),
	|	MAX(DescriptionOfRequirements),
	|	MAX(LineNumber),
	|	SUM(Quantity),
	|	MAX(Comment),
	|	MAX(ClosingDate),
	|	MAX(Currency),
	|	MAX(Budget),
	|	MAX(ExistsTabularSection),
	|	MAX(CompanyLogoFile)
	|BY
	|	Ref";
	
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
	
	Header = Query.Execute().Select(QueryResultIteration.ByGroupsWithHierarchy);
	
	FirstDocument = True;
	
	While Header.Next() Do
		
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_RequestForQuotation";
		
		Template = PrintManagement.PrintFormTemplate("Document.RequestForQuotation.PF_MXL_RequestForQuotation", LanguageCode);
		
		#Region TitleArea
		
		TitleArea = Template.GetArea("Title");
		TitleArea.Parameters.Fill(Header);
		
		
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
		
		#Region CompanyInfoArea
		
		CompanyInfoArea = Template.GetArea("CompanyInfo");
		CompanyInfoArea.Parameters.Fill(Header);
		
		InfoAboutCompany = DriveServer.InfoAboutLegalEntityIndividual(
			Header.Company, Header.DocumentDate, , , Header.CompanyVATNumber, LanguageCode);
		CompanyInfoArea.Parameters.Fill(InfoAboutCompany);
		
		SpreadsheetDocument.Put(CompanyInfoArea);
		
		#EndRegion
		
		#Region Comment
		
		CommentArea = Template.GetArea("Comment");
		CommentArea.Parameters.Fill(Header);
		SpreadsheetDocument.Put(CommentArea);
		
		#EndRegion
		
		#Region SubjectArea
		
		SubjectArea = Template.GetArea("Subject");
		SubjectArea.Parameters.Fill(Header);
		SpreadsheetDocument.Put(SubjectArea);
		
		#EndRegion
		
		#Region LinesArea
		
		If Header.ExistsTabularSection Then
			
			LineHeaderArea = Template.GetArea("LineHeader");
			SpreadsheetDocument.Put(LineHeaderArea);
			
			LineSectionArea	= Template.GetArea("LineSection");
			SeeNextPageArea	= Template.GetArea("SeeNextPage");
			EmptyLineArea	= Template.GetArea("EmptyLine");
			PageNumberArea	= Template.GetArea("PageNumber");
			
			LineTotalArea = Template.GetArea("LineTotal");
			LineTotalArea.Parameters.Fill(Header);
			
			PageNumber = 0;
			AreasToBeChecked = New Array;
			
			Products = Header.Select();
			While Products.Next() Do
				
				LineSectionArea.Parameters.Fill(Products);
				
				DriveClientServer.ComplimentProductDescription(LineSectionArea.Parameters.ProductDescription, Products);
				If ValueIsFilled(Products.Description) Then
					LineSectionArea.Parameters.ProductDescription = LineSectionArea.Parameters.ProductDescription +
						" " + Products.Description;
				EndIf;
				
				AreasToBeChecked.Clear();
				AreasToBeChecked.Add(LineSectionArea);
				AreasToBeChecked.Add(LineTotalArea);
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
			
			SpreadsheetDocument.Put(LineTotalArea);
			
		EndIf;
		
		#EndRegion
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, Header.Ref);
		
	EndDo;
	
	SpreadsheetDocument.FitToPage = True;
	
	Return SpreadsheetDocument;
	
EndFunction

// Generate printed forms of objects
//
// Incoming:
//  TemplateNames   - String	- Names of layouts separated by commas 
//	ObjectsArray	- Array		- Array of refs to objects that need to be printed 
//	PrintParameters - Structure - Structure of additional printing parameters
//
// Outgoing:
//   PrintFormsCollection	- Values table	- Generated table documents 
//	OutputParameters		- Structure     - Parameters of generated table documents
//
Procedure Print(ObjectsArray, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters) Export
	
	If PrintManagement.TemplatePrintRequired(PrintFormsCollection, "RequestForQuotation") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(
			PrintFormsCollection,
			"RequestForQuotation",
			NStr("en = 'Request for quotation'; ru = 'Запрос коммерческого предложения';pl = 'Zapytanie ofertowe';es_ES = 'Solicitud de presupuesto';es_CO = 'Solicitud de presupuesto';tr = 'Satın alma talebi';it = 'Richiesta di offerta';de = 'Angebotsanfrage'"),
			PrintForm(ObjectsArray, PrintObjects, "RequestForQuotation", PrintParameters.Result));
		
	EndIf;
	
	// parameters of sending printing forms by email
	DriveServer.FillSendingParameters(OutputParameters.SendOptions, ObjectsArray, PrintFormsCollection);
	
EndProcedure

// Fills in Request for quotation printing commands list
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	// Order confirmation
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "RequestForQuotation";
	PrintCommand.Presentation				= NStr("en = 'Request for quotation'; ru = 'Запрос коммерческого предложения';pl = 'Zapytanie ofertowe';es_ES = 'Solicitud de presupuesto';es_CO = 'Solicitud de presupuesto';tr = 'Satın alma talebi';it = 'Richiesta di offerta';de = 'Angebotsanfrage'");
	PrintCommand.FormsList					= "DocumentForm,ListForm";
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 1;
	
EndProcedure

#EndRegion

#Region ObjectVersioning

// StandardSubsystems.ObjectVersioning

Procedure OnDefineObjectVersioningSettings(Settings) Export

EndProcedure

// End StandardSubsystems.ObjectVersioning

#EndRegion

#EndRegion

#EndRegion

#Region Private

#Region LibrariesHandlers

#Region PrintInterface

// Function checks if the document is posted and calls
// the procedure of document printing.
//
Function PrintForm(ObjectsArray, PrintObjects, TemplateName, PrintParams = Undefined)
	
	If TemplateName = "RequestForQuotation" Then
		
		Return PrintRequestForQuotation(ObjectsArray, PrintObjects, TemplateName, PrintParams);
		
	EndIf;
	
EndFunction

#EndRegion

#EndRegion

#EndRegion


#EndIf