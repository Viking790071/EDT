#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
Procedure InitializeDocumentData(DocumentRefPackingSlip, StructureAdditionalProperties) Export

	Query = New Query;
	Query.Text = 
	"SELECT
	|	PackingSlip.Ref AS Ref,
	|	PackingSlip.Date AS Date,
	|	PackingSlip.Company AS Company
	|INTO PackingSlips
	|FROM
	|	Document.PackingSlip AS PackingSlip
	|WHERE
	|	PackingSlip.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PackingSlips.Date AS Period,
	|	PackingSlips.Company AS Company,
	|	PackingSlipPackageContents.Ref AS Ref,
	|	PackingSlipPackageContents.SalesOrder AS SalesOrder,
	|	PackingSlipPackageContents.Products AS Products,
	|	PackingSlipPackageContents.Characteristic AS Characteristic,
	|	PackingSlipPackageContents.Batch AS Batch,
	|	PackingSlipPackageContents.MeasurementUnit AS MeasurementUnit,
	|	PackingSlipPackageContents.Quantity AS Quantity,
	|	PackingSlipPackageContents.Weight AS Weight,
	|	PackingSlipExistingPackages.InternalID AS InternalID,
	|	PackingSlipExistingPackages.TrackingNumber AS TrackingNumber,
	|	PackingSlipExistingPackages.ContainerType AS ContainerType
	|FROM
	|	PackingSlips AS PackingSlips
	|		INNER JOIN Document.PackingSlip.Inventory AS PackingSlipPackageContents
	|			INNER JOIN Document.PackingSlip.ExistingPackages AS PackingSlipExistingPackages
	|			ON PackingSlipPackageContents.ExistingPackageLine = PackingSlipExistingPackages.KeyExistingPackages
	|				AND PackingSlipPackageContents.Ref = PackingSlipExistingPackages.Ref
	|		ON PackingSlips.Ref = PackingSlipPackageContents.Ref";
	
	Query.SetParameter("Ref", DocumentRefPackingSlip);
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePackedOrders", Query.Execute().Unload());
	
EndProcedure

#EndRegion
	
#Region Private

#Region PrintInterface

Function PrintPackingList(ObjectArray, PrintObjects, TemplateName, PrintParams)
	Var FirstDocument, FirstRowNumber;
	
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
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_PackingSlip";

	FirstDocument = True;
	
	SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_PackingSlip_MXL_PackingSlip";
	
	Template = PrintManagement.PrintFormTemplate("Document.PackingSlip.PF_MXL_PackingSlip", LanguageCode);
	
	Query = New Query();
	Query.SetParameter("ObjectArray", ObjectArray);
	Query.Text =
	"SELECT ALLOWED
	|	PackingSlip.Ref AS Ref,
	|	PackingSlip.Number AS Number,
	|	PackingSlip.Date AS DocumentDate,
	|	PackingSlip.Company AS Company,
	|	PackingSlip.CompanyVATNumber AS CompanyVATNumber,
	|	PackingSlip.StructuralUnit AS StructuralUnit,
	|	PackingSlip.Comment AS Comment,
	|	PackingSlip.Presentation AS Presentation,
	|	PackingSlip.PointInTime AS PointInTime
	|INTO Header
	|FROM
	|	Document.PackingSlip AS PackingSlip
	|WHERE
	|	PackingSlip.Ref IN(&ObjectArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	Header.Ref AS Ref,
	|	Header.Number AS Number,
	|	Header.DocumentDate AS DocumentDate,
	|	Header.Company AS Company,
	|	Header.CompanyVATNumber AS CompanyVATNumber,
	|	Header.StructuralUnit AS StructuralUnit,
	|	Header.Comment AS Comment,
	|	Header.Presentation AS Presentation,
	|	Header.PointInTime AS PointInTime,
	|	PackingSlipExistingPackages.ContainerType AS ContainerType,
	|	PackingSlipExistingPackages.InternalID AS InternalID,
	|	PackingSlipExistingPackages.Weight AS Weight,
	|	PackingSlipExistingPackages.KeyExistingPackages AS KeyExistingPackages,
	|	WeightUOM.Value.Description AS WeightUOM,
	|	Companies.LogoFile AS CompanyLogoFile,
	|	ContainerTypes.Weight AS WeightOfContainer
	|FROM
	|	Header AS Header
	|		LEFT JOIN Constant.WeightUOM AS WeightUOM
	|		ON (TRUE)
	|		LEFT JOIN Catalog.Companies AS Companies
	|		ON Header.Company = Companies.Ref
	|		INNER JOIN Document.PackingSlip.ExistingPackages AS PackingSlipExistingPackages
	|			LEFT JOIN Catalog.ContainerTypes AS ContainerTypes
	|			ON PackingSlipExistingPackages.ContainerType = ContainerTypes.Ref
	|		ON Header.Ref = PackingSlipExistingPackages.Ref
	|TOTALS
	|	MAX(Number),
	|	MAX(DocumentDate),
	|	MAX(Company),
	|	MAX(CompanyVATNumber),
	|	MAX(StructuralUnit),
	|	MAX(Presentation),
	|	MAX(CompanyLogoFile)
	|BY
	|	Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	PackingSlipInventory.Ref AS Ref,
	|	PackingSlipInventory.LineNumber AS LineNumber,
	|	PackingSlipInventory.SalesOrder AS SalesOrder,
	|	PackingSlipInventory.Products AS Products,
	|	PackingSlipInventory.Characteristic AS Characteristic,
	|	PackingSlipInventory.Batch AS Batch,
	|	PackingSlipInventory.SerialNumbers AS SerialNumbers,
	|	PackingSlipInventory.MeasurementUnit AS MeasurementUnit,
	|	PackingSlipInventory.Quantity AS Quantity,
	|	PackingSlipInventory.Weight AS Weight,
	|	PackingSlipInventory.Responsible AS Responsible,
	|	PackingSlipInventory.ExistingPackageLine AS ExistingPackageLine,
	|	PackingSlipInventory.ConnectionKey AS ConnectionKey,
	|	SalesOrderDocument.ShippingAddress AS ShippingAddress,
	|	ProductsCatalog.Description AS ProductsDescription,
	|	CharacteristicsCatalog.Description AS CharacteristicDescription
	|FROM
	|	Header AS Header
	|		INNER JOIN Document.PackingSlip.Inventory AS PackingSlipInventory
	|			LEFT JOIN Document.SalesOrder AS SalesOrderDocument
	|			ON PackingSlipInventory.SalesOrder = SalesOrderDocument.Ref
	|			LEFT JOIN Catalog.Products AS ProductsCatalog
	|			ON PackingSlipInventory.Products = ProductsCatalog.Ref
	|			LEFT JOIN Catalog.ProductsCharacteristics AS CharacteristicsCatalog
	|			ON PackingSlipInventory.Characteristic = CharacteristicsCatalog.Ref
	|		ON Header.Ref = PackingSlipInventory.Ref";
	
	// MultilingualSupport
	DriveServer.ChangeQueryTextForCurrentLanguage(Query.Text, LanguageCode);
	// End MultilingualSupport
	
	ResultsArray = Query.ExecuteBatch();
	Header = ResultsArray[1].Select(QueryResultIteration.ByGroups);
	
	While Header.Next() Do
				
		FirstRowNumber = SpreadsheetDocument.TableHeight + 1;
		DocumentNumber = Header.Number;
		ExistingPackages = Header.Select();
		
		While ExistingPackages.Next() Do
		
			WeightOfContainer = Common.ObjectAttributeValue(ExistingPackages.ContainerType, "Weight");
			If ExistingPackages.Weight = WeightOfContainer Then
				Continue;
			EndIf;
			
			TemplateArea = Template.GetArea("Title");
			
			Prototype = DataProcessors.PrintLabelsAndTags.GetTemplate("Prototype");
			MmsInPixel = Prototype.Drawings.Square100Pixels.Height / 100;
			
			BarcodeParameters = New Structure;
			Barcode = BarcodesInPrintForms.CodeByReference(Header.Ref);
			BarcodeParameters.Insert("Width",		StrLen(Barcode)*10);
			BarcodeParameters.Insert("Height",		40);
			BarcodeParameters.Insert("Barcode",		Barcode);
			BarcodeParameters.Insert("CodeType",	4);
			BarcodeParameters.Insert("ShowText",	False);
			BarcodeParameters.Insert("SizeOfFont",	6);
			
			If ValueIsFilled(Header.CompanyLogoFile) Then
				
				PictureData = AttachedFiles.GetBinaryFileData(Header.CompanyLogoFile);
				If ValueIsFilled(PictureData) Then
					TemplateArea.Drawings.Logo.Picture = New Picture(PictureData);
				EndIf;
				
			Else
				TemplateArea.Drawings.Delete(TemplateArea.Drawings.Logo);
			EndIf;
			
			TemplateArea.Parameters.DocumentNumber = DocumentNumber;
			TemplateArea.Parameters.DocumentDate   = Format(Header.DocumentDate,"DLF=D");
			
			SpreadsheetDocument.Put(TemplateArea);
			
			TemplateArea = Template.GetArea("CompanyInfo");
			InfoAboutCompany = DriveServer.InfoAboutLegalEntityIndividual(
				Header.Company, Header.DocumentDate, , , Header.CompanyVATNumber, LanguageCode);
			TemplateArea.Parameters.Fill(InfoAboutCompany);
			BarcodesInPrintForms.AddBarcodeToTableDocument(TemplateArea, Header.Ref);
			SpreadsheetDocument.Put(TemplateArea);
			
			PackageContentsTable = ResultsArray[2].Unload();
			PackageContentsTableOfPakage = PackageContentsTable.Copy(New Structure("ExistingPackageLine", ExistingPackages.KeyExistingPackages));
			
			TemplateArea = Template.GetArea("Container");
			
			BarcodeParameters = New Structure;
			
			CleanUUID = "0x" + StrReplace(ExistingPackages.KeyExistingPackages, "-", "");
			NumberFromHexString = NumberFromHexString(CleanUUID);
			Barcode =  Format(NumberFromHexString, "NG = 100");

			BarcodeParameters.Insert("Width",		StrLen(Barcode)*10);
			BarcodeParameters.Insert("Height",		40);
			BarcodeParameters.Insert("Barcode",		Barcode);
			BarcodeParameters.Insert("CodeType",	4);
			BarcodeParameters.Insert("ShowText",	False);
			BarcodeParameters.Insert("SizeOfFont",	6);
			
			TemplateArea.Drawings.ContainerBarcode.Picture = EquipmentManagerServerCall.GetBarcodePicture(BarcodeParameters);
			
			TemplateArea.Parameters.PackingDate	= Format(Header.DocumentDate,"DLF=D");
			TemplateArea.Parameters.ContainerNo	= ExistingPackages.InternalID;
			Weight = NStr("en = 'Gross %1 %2, Net %3 %4'; ru = 'Брутто %1 %2, Нетто %3 %4';pl = 'Brutto %1 %2, Netto %3 %4';es_ES = 'Ganancia %1 %2, Neto%3 %4';es_CO = 'Ganancia %1 %2, Neto%3 %4';tr = 'Brüt %1 %2, Net %3 %4';it = 'Lordo %1 %2, Netto %3 %4';de = 'Brutto, %1 %2, Netto %3 %4'", LanguageCode);
			Weight = StringFunctionsClientServer.SubstituteParametersToString(
				Weight,
				ExistingPackages.Weight,
				ExistingPackages.WeightUOM,
				ExistingPackages.Weight - ExistingPackages.WeightOfContainer,
				ExistingPackages.WeightUOM);
			TemplateArea.Parameters.Weight = Weight;
			SpreadsheetDocument.Put(TemplateArea);
			
			TemplateArea = Template.GetArea("PerAddressHeader");
			
			If PackageContentsTableOfPakage.Count() > 0 Then 
				TemplateArea.Parameters.ShipTo = PackageContentsTableOfPakage[0].ShippingAddress;
			Else
				TemplateArea.Parameters.ShipTo = "";
			EndIf;
			
			SpreadsheetDocument.Put(TemplateArea);
			
			LineNumber = 1;
			
			For Each Row In PackageContentsTableOfPakage Do
				
				RowArea = Template.GetArea("Line");
				
				RowArea.Parameters.ItemN	= LineNumber;
				RowArea.Parameters.Product	= Row.ProductsDescription
					+ ?(ValueIsFilled(Row.CharacteristicDescription),", " + Row.CharacteristicDescription, "")
					+ ?(ValueIsFilled(Row.SerialNumbers),", " + Row.SerialNumbers, "");
				RowArea.Parameters.UOM		= Row.MeasurementUnit;
				RowArea.Parameters.Qty		= Row.Quantity;
				RowArea.Parameters.Weight	= Row.Weight;
				
				SpreadsheetDocument.Put(RowArea);
				
				LineNumber = LineNumber + 1;
			EndDo;
			
			TemplateArea = Template.GetArea("Footer");
			SpreadsheetDocument.Put(TemplateArea);
			
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndDo;
		
	EndDo;
	
	Return SpreadsheetDocument;
	
EndFunction

// Function checks if the document is posted and calls
// the procedure of document printing.
//
Function PrintForm(ObjectsArray, PrintObjects, TemplateName, PrintParams = Undefined)
	
	If TemplateName = "PackingSlip" Then
		
		Return PrintPackingList(ObjectsArray, PrintObjects, TemplateName, PrintParams);
		
	EndIf;
	
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
	
	If PrintManagement.TemplatePrintRequired(PrintFormsCollection, "PackingSlip") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(
			PrintFormsCollection,
			"PackingSlip",
			NStr("en = 'Packing slip'; ru = 'Упаковочный лист';pl = 'List przewozowy';es_ES = 'Albarán de entrega';es_CO = 'Albarán de entrega';tr = 'Sevk irsaliyesi';it = 'Packing list';de = 'Packzettel'"),
			PrintForm(ObjectsArray, PrintObjects, "PackingSlip", PrintParameters.Result));
		
	EndIf;
	
	// parameters of sending printing forms by email
	DriveServer.FillSendingParameters(OutputParameters.SendOptions, ObjectsArray, PrintFormsCollection);
	
EndProcedure

// Fills in Sales order printing commands list
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	// Order confirmation
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "PackingSlip";
	PrintCommand.Presentation				= NStr("en = 'Packing slip'; ru = 'Упаковочный лист';pl = 'List przewozowy';es_ES = 'Albarán de entrega';es_CO = 'Albarán de entrega';tr = 'Sevk irsaliyesi';it = 'Packing list';de = 'Packzettel'");
	PrintCommand.FormsList					= "DocumentForm,ListForm";
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 1;
	
	
EndProcedure

#EndRegion

#EndRegion

#EndIf
