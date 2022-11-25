#If Server OR ThickClientOrdinaryApplication OR ExternalConnection Then

#Region Public

#Region LibrariesHandlers

#Region PrintInterface

// Generate printed forms of objects
//
// Incoming:
//  TemplateNames   - String	- Names of layouts separated by commas 
//  ObjectsArray	- Array		- Array of refs to objects that need to be printed 
//  PrintParameters - Structure	- Structure of additional printing parameters
//
// Outgoing:
//  PrintFormsCollection	- Values table	- Generated table documents 
//  OutputParameters		- Structure		- Parameters of generated table documents
//
Procedure Print(ObjectsArray, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters) Export
	
	If PrintManagement.TemplatePrintRequired(PrintFormsCollection, "RMARequest") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(
            PrintFormsCollection, 
            "RMARequest", 
            NStr("en = 'RMA request'; ru = 'Сервисный запрос';pl = 'Żądanie RMA';es_ES = 'Solicitud de RMA';es_CO = 'Solicitud de RMA';tr = 'RMA talebi';it = 'TICKET ASSISTENZA';de = 'RMA-Anfrage'"), 
            PrintForm(ObjectsArray, PrintObjects, "RMARequest", PrintParameters.Result));
		
	EndIf;
	
	// parameters of sending printing forms by email
	DriveServer.FillSendingParameters(OutputParameters.SendOptions, ObjectsArray, PrintFormsCollection);
	
EndProcedure

// Fills in Sales order printing commands list
// 
// Parameters:
//  PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	// Order confirmation
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "RMARequest";
	PrintCommand.Presentation				= NStr("en = 'RMA request'; ru = 'Сервисный запрос';pl = 'Żądanie RMA';es_ES = 'Solicitud de RMA';es_CO = 'Solicitud de RMA';tr = 'RMA talebi';it = 'TICKET ASSISTENZA';de = 'RMA-Anfrage'");
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

Function PrintRMARequest(ObjectsArray, PrintObjects, TemplateName, PrintParams)
    
    DisplayPrintOption = (PrintParams <> Undefined);
    
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_RMARequest";
	
	Query = New Query();
	Query.SetParameter("ObjectsArray", ObjectsArray);
	
	#Region PrintRMARequestQueryText
	
	Query.Text = 
	"SELECT ALLOWED
	|	RMARequest.Ref AS Ref,
	|	RMARequest.Number AS Number,
	|	RMARequest.Date AS Date,
	|	RMARequest.Company AS Company,
	|	RMARequest.Counterparty AS Counterparty,
	|	RMARequest.Contract AS Contract,
	|	RMARequest.Location AS Location,
	|	RMARequest.ContactPerson AS ContactPerson,
	|	RMARequest.Equipment AS Equipment,
	|	RMARequest.Characteristic AS Characteristic,
	|	RMARequest.SerialNumber AS SerialNumber,
	|	REFPRESENTATION(RMARequest.Invoice) AS BasisDocument,
	|	CAST(RMARequest.ProblemDescription AS STRING(1024)) AS ProblemDescription,
	|	CAST(RMARequest.ContactInfo AS STRING(1024)) AS ContactInfo,
	|	RMARequest.InWarranty AS InWarranty,
	|	RMARequest.ExpectedDate AS ExpectedDate
	|INTO RMARequestTable
	|FROM
	|	Document.RMARequest AS RMARequest
	|WHERE
	|	RMARequest.Ref IN(&ObjectsArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	RMARequestTable.Ref AS Ref,
	|	RMARequestTable.Number AS DocumentNumber,
	|	RMARequestTable.Date AS DocumentDate,
	|	RMARequestTable.Company AS Company,
	|	Companies.LogoFile AS CompanyLogoFile,
	|	RMARequestTable.Counterparty AS Counterparty,
	|	RMARequestTable.Contract AS Contract,
	|	CASE
	|		WHEN RMARequestTable.ContactPerson <> VALUE(Catalog.ContactPersons.EmptyRef)
	|			THEN RMARequestTable.ContactPerson
	|		WHEN CounterpartyContracts.ContactPerson <> VALUE(Catalog.ContactPersons.EmptyRef)
	|			THEN CounterpartyContracts.ContactPerson
	|		ELSE Counterparties.ContactPerson
	|	END AS CounterpartyContactPerson,
	|	RMARequestTable.Location AS Location,
	|	RMARequestTable.ProblemDescription AS ProblemDescription,
	|	RMARequestTable.ContactInfo AS ContactInfo,
	|	RMARequestTable.SerialNumber AS SerialNumber,
	|	RMARequestTable.Characteristic AS Characteristic,
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
	|	VALUE(Catalog.ProductsBatches.EmptyRef) AS Batch,
	|	"""" AS BatchDescription,
	|	FALSE AS ContentUsed,
	|	FALSE AS UseSerialNumbers,
	|	RMARequestTable.BasisDocument AS BasisDocument,
	|	RMARequestTable.InWarranty AS InWarranty,
	|	RMARequestTable.ExpectedDate AS ExpectedDate
	|FROM
	|	RMARequestTable AS RMARequestTable
	|		LEFT JOIN Catalog.Companies AS Companies
	|		ON RMARequestTable.Company = Companies.Ref
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON RMARequestTable.Counterparty = Counterparties.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON RMARequestTable.Contract = CounterpartyContracts.Ref
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON RMARequestTable.Equipment = CatalogProducts.Ref
	|		LEFT JOIN Catalog.ProductsCharacteristics AS CatalogCharacteristics
	|		ON RMARequestTable.Characteristic = CatalogCharacteristics.Ref";
	
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
	
	QueryResult = Query.Execute();
	
	FirstDocument = True;
	
	Header = QueryResult.Select(QueryResultIteration.ByGroupsWithHierarchy);
	
	While Header.Next() Do
		
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_RMARequest";
		
		Template = PrintManagement.PrintFormTemplate("Document.RMARequest.PF_MXL_RMARequest", LanguageCode);
		
		#Region PrintRMARequestTitleArea
		
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
		
		#Region PrintRMARequestCompanyInfoArea
		
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
		
		#Region PrintRMARequestCounterpartyInfoArea
		
		CounterpartyInfoArea = Template.GetArea("CounterpartyInfo");
		CounterpartyInfoArea.Parameters.Fill(Header);
		
		InfoAboutCounterparty = DriveServer.InfoAboutLegalEntityIndividual(
			Header.Counterparty,
			Header.DocumentDate,
			,
			,
			,
			LanguageCode);
		CounterpartyInfoArea.Parameters.Fill(InfoAboutCounterparty);
		
		InfoAboutShippingAddress	= DriveServer.InfoAboutShippingAddress(Header.Location);
		InfoAboutContactPerson		= DriveServer.InfoAboutContactPerson(Header.CounterpartyContactPerson);
		
		If NOT IsBlankString(InfoAboutShippingAddress.DeliveryAddress) Then
			CounterpartyInfoArea.Parameters.DeliveryAddress = InfoAboutShippingAddress.DeliveryAddress;
		EndIf;
		
		If NOT IsBlankString(InfoAboutContactPerson.PhoneNumbers) Then
			CounterpartyInfoArea.Parameters.PhoneNumbers = InfoAboutContactPerson.PhoneNumbers;
		EndIf;
		
		If IsBlankString(CounterpartyInfoArea.Parameters.DeliveryAddress) Then
			
			If Not IsBlankString(InfoAboutCounterparty.ActualAddress) Then
				
				CounterpartyInfoArea.Parameters.DeliveryAddress = InfoAboutCounterparty.ActualAddress;
				
			Else
				
				CounterpartyInfoArea.Parameters.DeliveryAddress = InfoAboutCounterparty.LegalAddress;
				
			EndIf;
			
		EndIf;
		
		SpreadsheetDocument.Put(CounterpartyInfoArea);
		
		#EndRegion
		
		#Region PrintRMARequestEquipmentSectionArea
		
		EquipmentSectionArea = Template.GetArea("EquipmentSection");
		EquipmentSectionArea.Parameters.Fill(Header);
		
		ProductDescription = Header.ProductDescription;
		
		DriveClientServer.ComplimentProductDescription(ProductDescription, Header);
		
		EquipmentSectionArea.Parameters.Equipment = ProductDescription;
		
		SpreadsheetDocument.Put(EquipmentSectionArea);
		
		#EndRegion
		
		#Region PrintRMARequestAdditionalInfoArea
		
		AdditionalInfoArea = Template.GetArea("AdditionalInfo");
		AdditionalInfoArea.Parameters.Fill(Header);
		SpreadsheetDocument.Put(AdditionalInfoArea);
		
		#EndRegion
        
        #Region PrintAdditionalAttributes
		If DisplayPrintOption And PrintParams.AdditionalAttributes
			And PrintManagementServerCallDrive.HasAdditionalAttributes(Header.Ref) Then
            
            EmptyLineArea	= Template.GetArea("EmptyLine");
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
        
        
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, Header.Ref);
		
	EndDo;
	
	SpreadsheetDocument.FitToPage = True;
	
	Return SpreadsheetDocument;
	
EndFunction

// Function checks if the document is posted and calls
// the procedure of document printing.
//
Function PrintForm(ObjectsArray, PrintObjects, TemplateName, PrintParams = Undefined)
	
	If TemplateName = "RMARequest" Then
		
		Return PrintRMARequest(ObjectsArray, PrintObjects, TemplateName, PrintParams);
		
	EndIf;
	
EndFunction

#EndRegion

#EndIf
