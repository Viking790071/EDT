#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region LibrariesHandlers

#Region PrintInterface

// The procedure of document printing.
//
Function PrintForm(ObjectsArray, PrintObjects, TemplateName, PrintParams = Undefined)
	
	If TemplateName = "RequisitionOrder" Then
		
		Return PrintRequisitionOrder(ObjectsArray, PrintObjects, TemplateName, PrintParams);
		
	EndIf;
	
EndFunction

// The procedure of document printing.
Function PrintRequisitionOrder(ObjectsArray, PrintObjects, TemplateName, PrintParams)
	
	DisplayPrintOption = (PrintParams <> Undefined);
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_RequisitionOrder";
	
	Query = New Query();
	Query.SetParameter("ObjectsArray", ObjectsArray);
	
	#Region PrintRequisitionOrderQueryText
	
	Query.Text = QueryText();
	
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
	
	ResultArray = Query.Execute();
	
	FirstDocument = True;
	
	Header = ResultArray.Select(QueryResultIteration.ByGroupsWithHierarchy);
	
	While Header.Next() Do
		
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		Template = PrintManagement.PrintFormTemplate("Document.RequisitionOrder.PF_MXL_RequisitionOrderTemplate", LanguageCode);
		
		#Region PrintRequisitionOrderTitleArea
		
		TitleArea = Template.GetArea("Title");
		TitleArea.Parameters.Fill(Header);
		SpreadsheetDocument.Put(TitleArea);
		
		#EndRegion
	
		#Region PrintOrderConfirmationCommentArea
		
		CommentArea = Template.GetArea("Comment");
		CommentArea.Parameters.Fill(Header);
		SpreadsheetDocument.Put(CommentArea);
		
		#EndRegion
		
		#Region PrintOrderConfirmationLinesArea
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
			
			AreasToBeChecked = New Array;
			AreasToBeChecked.Add(LineSectionArea);
			AreasToBeChecked.Add(PageNumberArea);
			
			If Common.SpreadsheetDocumentFitsPage(SpreadsheetDocument, AreasToBeChecked) Then
				// Display selected codes if functional option is turned on.
				If DisplayPrintOption Then
					CodesPresentation = PrintManagementServerCallDrive.GetCodesPresentation(PrintParams, TabSelection.Products);
					If PrintParams.CodesPosition = Enums.CodesPositionInPrintForms.SeparateColumn Then
						LineSectionArea.Parameters.SKU = CodesPresentation;
					ElsIf PrintParams.CodesPosition = Enums.CodesPositionInPrintForms.ProductColumn Then
						LineSectionArea.Parameters.ProductDescription = LineSectionArea.Parameters.ProductDescription + Chars.CR + CodesPresentation;                    
					EndIf;
				EndIf;
				
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
		
		#Region PrintOrderConfirmationTotalsArea
		
		#Region PrintApprovedByArea
		
		ApprovedBy	= Template.GetArea("ApprovedBy");
		SpreadsheetDocument.Put(ApprovedBy);
		
		#EndRegion

		AreasToBeChecked.Clear();
		AreasToBeChecked.Add(EmptyLineArea);
		AreasToBeChecked.Add(PageNumberArea);
		
		#Region PrintAdditionalAttributes
		If DisplayPrintOption And PrintParams.AdditionalAttributes
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
	
	SpreadsheetDocument.FitToPage = True;
	
	Return SpreadsheetDocument;
	
EndFunction

// The procedure of document printing.
Function QueryText()
	
	QueryText = 
	"SELECT ALLOWED
	|	RequisitionOrder.Ref AS Ref,
	|	RequisitionOrder.Number AS Number,
	|	RequisitionOrder.Date AS Date,
	|	RequisitionOrder.Company AS Company,
	|	CAST(RequisitionOrder.Comment AS STRING(1024)) AS Comment,
	|	RequisitionOrder.Warehouse AS Warehouse,
	|	RequisitionOrder.ReceiptDate AS ReceiptDate,
	|	RequisitionOrder.Responsible AS Responsible,
	|	RequisitionOrder.StructuralUnit AS StructuralUnit
	|INTO RequisitionOrders
	|FROM
	|	Document.RequisitionOrder AS RequisitionOrder
	|WHERE
	|	RequisitionOrder.Ref IN(&ObjectsArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	RequisitionOrders.Ref AS Ref,
	|	RequisitionOrders.Number AS DocumentNumber,
	|	RequisitionOrders.Date AS DocumentDate,
	|	RequisitionOrders.Company AS Company,
	|	RequisitionOrders.Comment AS Comment,
	|	RequisitionOrders.Warehouse AS Warehouse,
	|	RequisitionOrders.ReceiptDate AS ReceiptDate,
	|	RequisitionOrders.Responsible AS Responsible,
	|	RequisitionOrders.StructuralUnit AS StructuralUnit
	|INTO Header
	|FROM
	|	RequisitionOrders AS RequisitionOrders
	|		LEFT JOIN Catalog.Companies AS Companies
	|		ON RequisitionOrders.Company = Companies.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	RequisitionOrderInventory.Ref AS Ref,
	|	RequisitionOrderInventory.LineNumber AS LineNumber,
	|	RequisitionOrderInventory.Products AS Products,
	|	RequisitionOrderInventory.Characteristic AS Characteristic,
	|	RequisitionOrderInventory.Quantity AS Quantity,
	|	RequisitionOrderInventory.MeasurementUnit AS MeasurementUnit,
	|	RequisitionOrderInventory.Content AS Content
	|INTO FilteredInventory
	|FROM
	|	Document.RequisitionOrder.Inventory AS RequisitionOrderInventory
	|WHERE
	|	RequisitionOrderInventory.Ref IN(&ObjectsArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	Header.Ref AS Ref,
	|	Header.DocumentNumber AS DocumentNumber,
	|	Header.DocumentDate AS DocumentDate,
	|	Header.Company AS Company,
	|	Header.Comment AS Comment,
	|	MIN(FilteredInventory.LineNumber) AS LineNumber,
	|	CatalogProducts.SKU AS SKU,
	|	CASE
	|		WHEN (CAST(FilteredInventory.Content AS STRING(1024))) <> """"
	|			THEN CAST(FilteredInventory.Content AS STRING(1024))
	|		WHEN (CAST(CatalogProducts.DescriptionFull AS STRING(1024))) <> """"
	|			THEN CAST(CatalogProducts.DescriptionFull AS STRING(1024))
	|		ELSE CatalogProducts.Description
	|	END AS ProductDescription,
	|	(CAST(FilteredInventory.Content AS STRING(1024))) <> """" AS ContentUsed,
	|	CASE
	|		WHEN CatalogProducts.UseCharacteristics
	|			THEN CatalogCharacteristics.Description
	|		ELSE """"
	|	END AS CharacteristicDescription,
	|	CatalogProducts.UseSerialNumbers AS UseSerialNumbers,
	|	ISNULL(CatalogUOM.Description, CatalogUOMClassifier.Description) AS UOM,
	|	SUM(FilteredInventory.Quantity) AS Quantity,
	|	FilteredInventory.Products AS Products,
	|	FilteredInventory.Characteristic AS Characteristic,
	|	FilteredInventory.MeasurementUnit AS MeasurementUnit,
	|	Header.Warehouse AS Warehouse,
	|	Header.Responsible AS Responsible,
	|	Header.ReceiptDate AS ReceiptDate,
	|	Header.StructuralUnit AS StructuralUnit
	|INTO Tabular
	|FROM
	|	Header AS Header
	|		INNER JOIN FilteredInventory AS FilteredInventory
	|		ON Header.Ref = FilteredInventory.Ref
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON (FilteredInventory.Products = CatalogProducts.Ref)
	|		LEFT JOIN Catalog.ProductsCharacteristics AS CatalogCharacteristics
	|		ON (FilteredInventory.Characteristic = CatalogCharacteristics.Ref)
	|		LEFT JOIN Catalog.UOM AS CatalogUOM
	|		ON (FilteredInventory.MeasurementUnit = CatalogUOM.Ref)
	|		LEFT JOIN Catalog.UOMClassifier AS CatalogUOMClassifier
	|		ON (FilteredInventory.MeasurementUnit = CatalogUOMClassifier.Ref)
	|
	|GROUP BY
	|	Header.Company,
	|	CatalogProducts.SKU,
	|	Header.Comment,
	|	CASE
	|		WHEN (CAST(FilteredInventory.Content AS STRING(1024))) <> """"
	|			THEN CAST(FilteredInventory.Content AS STRING(1024))
	|		WHEN (CAST(CatalogProducts.DescriptionFull AS STRING(1024))) <> """"
	|			THEN CAST(CatalogProducts.DescriptionFull AS STRING(1024))
	|		ELSE CatalogProducts.Description
	|	END,
	|	(CAST(FilteredInventory.Content AS STRING(1024))) <> """",
	|	Header.DocumentNumber,
	|	Header.Ref,
	|	Header.DocumentDate,
	|	CASE
	|		WHEN CatalogProducts.UseCharacteristics
	|			THEN CatalogCharacteristics.Description
	|		ELSE """"
	|	END,
	|	CatalogProducts.UseSerialNumbers,
	|	ISNULL(CatalogUOM.Description, CatalogUOMClassifier.Description),
	|	FilteredInventory.Products,
	|	FilteredInventory.Characteristic,
	|	FilteredInventory.MeasurementUnit,
	|	Header.Warehouse,
	|	Header.Responsible,
	|	Header.StructuralUnit,
	|	Header.ReceiptDate
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Tabular.Ref AS Ref,
	|	Tabular.DocumentNumber AS DocumentNumber,
	|	Tabular.DocumentDate AS DocumentDate,
	|	Tabular.Company AS Company,
	|	Tabular.Comment AS Comment,
	|	Tabular.LineNumber AS LineNumber,
	|	Tabular.SKU AS SKU,
	|	Tabular.ProductDescription AS ProductDescription,
	|	Tabular.ContentUsed AS ContentUsed,
	|	Tabular.UseSerialNumbers AS UseSerialNumbers,
	|	Tabular.Quantity AS Quantity,
	|	Tabular.CharacteristicDescription AS CharacteristicDescription,
	|	Tabular.Characteristic AS Characteristic,
	|	Tabular.UOM AS UOM,
	|	Tabular.Warehouse AS Warehouse,
	|	Tabular.Products AS Products,
	|	Tabular.ReceiptDate AS ReceiptDate,
	|	Tabular.StructuralUnit AS StructuralUnit,
	|	Tabular.Responsible AS Responsible
	|FROM
	|	Tabular AS Tabular
	|
	|ORDER BY
	|	DocumentNumber,
	|	LineNumber
	|TOTALS
	|	MAX(DocumentNumber),
	|	MAX(DocumentDate),
	|	MAX(Company),
	|	MAX(Comment),
	|	COUNT(LineNumber),
	|	SUM(Quantity),
	|	MAX(Warehouse),
	|	MAX(ReceiptDate),
	|	MAX(StructuralUnit),
	|	MAX(Responsible)
	|BY
	|	Ref";;
	
	Return QueryText;
	
EndFunction

// Generate printed forms of objects
//
// Incoming:
//   TemplateNames    - String    - Names of layouts separated
//   by commas ObjectsArray  - Array    - Array of refs to objects that
//   need to be printed PrintParameters - Structure - Structure of additional printing parameters
//
// Outgoing:
//   PrintFormsCollection - Values table - Generated
//   table documents OutputParameters       - Structure        - Parameters of generated table documents
//
Procedure Print(ObjectsArray, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters) Export
	
	If PrintManagement.TemplatePrintRequired(PrintFormsCollection, "RequisitionOrderTemplate") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(
			PrintFormsCollection,
			"RequisitionOrderTemplate", 
			NStr("en = 'Requisition order'; ru = 'Заявка на закупку';pl = 'Żądanie zakupu';es_ES = 'Orden de solicitud';es_CO = 'Orden de solicitud';tr = 'Talep emri';it = 'Richiesta di acquisto';de = 'Einkaufsauftrag'"), 
			PrintForm(ObjectsArray, PrintObjects, "RequisitionOrder", PrintParameters.Result));
		
	EndIf;
	
	// parameters of sending printing forms by email
	DriveServer.FillSendingParameters(OutputParameters.SendOptions, ObjectsArray, PrintFormsCollection);
	
EndProcedure

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "RequisitionOrderTemplate";
	PrintCommand.Presentation = NStr("en = 'Requisition order'; ru = 'Заявка на закупку';pl = 'Żądanie zakupu';es_ES = 'Orden de solicitud';es_CO = 'Orden de solicitud';tr = 'Talep emri';it = 'Richiesta di acquisto';de = 'Einkaufsauftrag'");
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 1;
	
EndProcedure

#EndRegion

#Region ObjectVersioning

// StandardSubsystems.ObjectVersioning

Procedure OnDefineObjectVersioningSettings(Settings) Export

EndProcedure

// End StandardSubsystems.ObjectVersioning

#EndRegion

#EndRegion

#EndIf
