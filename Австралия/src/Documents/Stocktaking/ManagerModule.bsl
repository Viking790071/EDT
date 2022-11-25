#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region GLAccounts

Function GetGLAccountsStructure(StructureData) Export

	GLAccountsForFilling = New Structure;
	
	Return GLAccountsForFilling;
	
EndFunction

#EndRegion

#Region Batches

Function BatchCheckFillingParameters(DocObject) Export
	
	Parameters = New Structure;
	
	Warehouses = New Array;
	
	WarehouseData = New Structure;
	WarehouseData.Insert("Warehouse", DocObject.StructuralUnit);
	WarehouseData.Insert("TrackingArea", "PhysicalInventory");
	
	Warehouses.Add(WarehouseData);
	
	Parameters.Insert("Warehouses", Warehouses);
	
	Return Parameters;
	
EndFunction

#EndRegion

#EndRegion

#Region Internal

#Region LibrariesHandlers

#Region PrintInterface

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
	
	If PrintManagement.TemplatePrintRequired(PrintFormsCollection, "MerchandiseFillingForm") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(
			PrintFormsCollection,
			"MerchandiseFillingForm",
			NStr("en = 'Merchandise filling form'; ru = 'Форма заполнения сопутствующих товаров';pl = 'Formularz wypełnienia towaru';es_ES = 'Formulario para rellenar las mercancías';es_CO = 'Formulario para rellenar las mercancías';tr = 'Mamul formu';it = 'Modulo di compilazione merce';de = 'Handelswarenformular'"),
			PrintForm(ObjectsArray, PrintObjects, "MerchandiseFillingForm", PrintParameters.Result));
		
	ElsIf PrintManagement.TemplatePrintRequired(PrintFormsCollection, "Stocktaking") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(
			PrintFormsCollection,
			"Stocktaking",
			NStr("en = 'Inventory reconciliation'; ru = 'Сверка товарно-материальных ценностей';pl = 'Uzgodnienie zapasów';es_ES = 'Reconciliación del inventario';es_CO = 'Reconciliación del inventario';tr = 'Stok mutabakatı';it = 'Riconciliazione scorte';de = 'Bestandsabstimmung'"),
			PrintForm(ObjectsArray, PrintObjects, "Stocktaking", PrintParameters.Result));
		
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
	PrintCommand.ID = "Stocktaking";
	PrintCommand.Presentation = NStr("en = 'Inventory count sheet'; ru = 'Инвентаризация запасов';pl = 'Arkusz inwentaryzacyjny';es_ES = 'Inventario';es_CO = 'Inventario';tr = 'Stok sayımı';it = 'Foglio di calcolo conteggio scorte';de = 'Inventurblatt '");
	PrintCommand.FormsList = "DocumentForm,ListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 1;
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "MerchandiseFillingForm";
	PrintCommand.Presentation = NStr("en = 'Inventory allocation card'; ru = 'Бланк распределения запасов';pl = 'Karta alokacji zapasów';es_ES = 'Tarjeta de asignación de inventario';es_CO = 'Tarjeta de asignación de inventario';tr = 'Stok dağıtım kartı';it = 'Scheda di allocazione scorte';de = 'Bestandszuordnungskarte'");
	PrintCommand.FormsList = "DocumentForm,ListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 2;
	
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

// Procedure forms and displays a printable document form by the specified layout.
//
// Parameters:
// SpreadsheetDocument - TabularDocument
// 			   in which printing form will be displayed.
//  TemplateName    - String, printing form layout name.
//
Function PrintForm(ObjectsArray, PrintObjects, TemplateName, PrintParams = Undefined)
	
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
	
	FirstDocument = True;
	
	For Each CurrentDocument In ObjectsArray Do
	
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		If TemplateName = "MerchandiseFillingForm" Then
			
			Query = New Query();
			Query.SetParameter("CurrentDocument", CurrentDocument);
			Query.Text = 
			"SELECT ALLOWED
			|	Stocktaking.Date AS DocumentDate,
			|	Stocktaking.StructuralUnit AS WarehousePresentation,
			|	Stocktaking.Cell AS CellPresentation,
			|	Stocktaking.Number,
			|	Stocktaking.Company.Prefix AS Prefix,
			|	Stocktaking.Inventory.(
			|		LineNumber AS LineNumber,
			|		Products.Warehouse AS Warehouse,
			|		Products.Cell AS Cell,
			|		CASE
			|			WHEN (CAST(Stocktaking.Inventory.Products.DescriptionFull AS String(100))) = """"
			|				THEN Stocktaking.Inventory.Products.Description
			|			ELSE Stocktaking.Inventory.Products.DescriptionFull
			|		END AS InventoryItem,
			|		Products.SKU AS SKU,
			|		Products.Code AS Code,
			|		MeasurementUnit.Description AS MeasurementUnit,
			|		Quantity AS Quantity,
			|		Characteristic,
			|		Products.ProductsType AS ProductsType,
			|		ConnectionKey
			|	),
			|	Stocktaking.SerialNumbers.(
			|		SerialNumber,
			|		ConnectionKey
			|	)
			|FROM
			|	Document.Stocktaking AS Stocktaking
			|WHERE
			|	Stocktaking.Ref = &CurrentDocument
			|
			|ORDER BY
			|	LineNumber";
			
			// MultilingualSupport
			DriveServer.ChangeQueryTextForCurrentLanguage(Query.Text, LanguageCode);
			// End MultilingualSupport
			
			Header = Query.Execute().Select();
			Header.Next();
			
			LinesSelectionInventory = Header.Inventory.Select();
			LinesSelectionSerialNumbers = Header.SerialNumbers.Select();
			
			SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_InventoryOfInventory_FormOfFilling";
			
			Template = PrintManagement.PrintFormTemplate("Document.Stocktaking.PF_MXL_MerchandiseFillingForm", LanguageCode);
			
			If Header.DocumentDate < Date('20110101') Then
				DocumentNumber = DriveServer.GetNumberForPrinting(Header.Number, Header.Prefix);
			Else
				DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Header.Number, True, True);
			EndIf;
			
			TemplateArea = Template.GetArea("Title");
			TemplateArea.Parameters.HeaderText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Inventory count sheet #%1, %2'; ru = 'Инвентаризация запасов №%1, %2';pl = 'Arkusz inwentaryzacyjny nr%1, %2';es_ES = 'Inventario #%1, %2';es_CO = 'Inventario #%1, %2';tr = 'Stok sayım belgesi # %1, %2';it = 'Foglio di calcolo conteggio scorte #%1, %2';de = 'Inventurblatt Nr. %1, %2'", LanguageCode),
				DocumentNumber,
				Format(Header.DocumentDate, "DLF=DD"));
			
			SpreadsheetDocument.Put(TemplateArea);
			
			TemplateArea = Template.GetArea("Warehouse");
			TemplateArea.Parameters.WarehousePresentation = Header.WarehousePresentation;
			SpreadsheetDocument.Put(TemplateArea);
			
			If Constants.UseStorageBins.Get() Then
				
				TemplateArea = Template.GetArea("Cell");
				TemplateArea.Parameters.CellPresentation = Header.CellPresentation;
				SpreadsheetDocument.Put(TemplateArea);
				
			EndIf;
			
			TemplateArea = Template.GetArea("PrintingTime");
			TemplateArea.Parameters.PrintingTime = 	StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Date and time of printing: %1. User: %2.'; ru = 'Дата и время печати: %1. Пользователь: %2.';pl = 'Data i godzina wydruku: %1. Użytkownik: %2.';es_ES = 'Fecha y hora de la impresión: %1. Usuario: %2.';es_CO = 'Fecha y hora de la impresión: %1. Usuario: %2.';tr = 'Yazdırma tarihi ve saati: %1. Kullanıcı: %2.';it = 'Data e orario della stampa: %1. Utente: %2';de = 'Datum und Uhrzeit des Drucks: %1. Benutzer: %2.'", LanguageCode),
				CurrentSessionDate(),
				Users.CurrentUser());
				
			SpreadsheetDocument.Put(TemplateArea);
			
			TemplateArea = Template.GetArea("TableHeader");
			SpreadsheetDocument.Put(TemplateArea);
			TemplateArea = Template.GetArea("String");
			
			While LinesSelectionInventory.Next() Do
				
				If Not LinesSelectionInventory.ProductsType = Enums.ProductsTypes.InventoryItem Then
					Continue;
				EndIf;
				
				TemplateArea.Parameters.Fill(LinesSelectionInventory);
				
				StringSerialNumbers = WorkWithSerialNumbers.SerialNumbersStringFromSelection(LinesSelectionSerialNumbers, LinesSelectionInventory.ConnectionKey);
				TemplateArea.Parameters.InventoryItem = DriveServer.GetProductsPresentationForPrinting(LinesSelectionInventory.InventoryItem, 
					LinesSelectionInventory.Characteristic, LinesSelectionInventory.SKU, StringSerialNumbers);
				
				SpreadsheetDocument.Put(TemplateArea);
				
			EndDo;
			
			TemplateArea = Template.GetArea("Total");
			SpreadsheetDocument.Put(TemplateArea);	
			
		ElsIf TemplateName = "Stocktaking" Then
			
			Query = New Query;
			Query.SetParameter("CurrentDocument", CurrentDocument);
			Query.Text =
			"SELECT ALLOWED
			|	Stocktaking.Number,
			|	Stocktaking.Date AS DocumentDate,
			|	Stocktaking.Company,
			|	Stocktaking.StructuralUnit.Presentation AS WarehousePresentation,
			|	Stocktaking.Company.Prefix AS Prefix,
			|	Stocktaking.Inventory.(
			|		LineNumber,
			|		Products,
			|		CASE
			|			WHEN (CAST(Stocktaking.Inventory.Products.DescriptionFull AS String(1000))) = """"
			|				THEN Stocktaking.Inventory.Products.Description
			|			ELSE CAST(Stocktaking.Inventory.Products.DescriptionFull AS String(1000))
			|		END AS Product,
			|		Characteristic,
			|		Products.SKU AS SKU,
			|		Quantity AS Quantity,
			|		QuantityAccounting AS AccountingCount,
			|		Deviation AS Deviation,
			|		MeasurementUnit AS MeasurementUnit,
			|		Price,
			|		Amount,
			|		AmountAccounting AS AmountByAccounting
			|	)
			|FROM
			|	Document.Stocktaking AS Stocktaking
			|WHERE
			|	Stocktaking.Ref = &CurrentDocument
			|
			|ORDER BY
			|	Stocktaking.Inventory.LineNumber";
			
			// MultilingualSupport
			DriveServer.ChangeQueryTextForCurrentLanguage(Query.Text, LanguageCode);
			// End MultilingualSupport
			
			Header = Query.Execute().Select();
			Header.Next();
			
			StringSelectionProducts = Header.Inventory.Select();
			
			PrintingCurrency = DriveServer.GetPresentationCurrency(Header.Company);

			SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_InventoryInventory_InventoryInventory";
			
			Template = PrintManagement.PrintFormTemplate("Document.Stocktaking.PF_MXL_Stocktaking", LanguageCode);
			
			If Header.DocumentDate < Date('20110101') Then
				DocumentNumber = DriveServer.GetNumberForPrinting(Header.Number, Header.Prefix);
			Else
				DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Header.Number, True, True);
			EndIf;
			
			// Displaying invoice header
			TemplateArea = Template.GetArea("Title");
			TemplateArea.Parameters.HeaderText = NStr("en = 'Inventory count sheet #'; ru = 'Инвентаризация запасов №';pl = 'Arkusz inwentaryzacyjny nr';es_ES = 'Inventario #';es_CO = 'Inventario #';tr = 'Stok sayım kağıdı #';it = 'Foglio di calcolo conteggio scorte #';de = 'Inventurblatt Nr.'", LanguageCode)
				+ DocumentNumber
				+ " " + NStr("en = 'dated'; ru = 'от';pl = 'z dn.';es_ES = 'fechado';es_CO = 'fechado';tr = 'tarihli';it = 'con data';de = 'datiert'", LanguageCode) + " "
				+ Format(Header.DocumentDate, "DLF=DD");
				
			SpreadsheetDocument.Put(TemplateArea);
			
			// Output company and warehouse data
			TemplateArea = Template.GetArea("Vendor");
			TemplateArea.Parameters.Fill(Header);
			
			InfoAboutCompany    = DriveServer.InfoAboutLegalEntityIndividual(
				Header.Company,
				Header.DocumentDate,
				,
				,
				,
				LanguageCode);
			CompanyPresentation = DriveServer.CompaniesDescriptionFull(InfoAboutCompany, "FullDescr,");
			TemplateArea.Parameters.CompanyPresentation = CompanyPresentation;
			
			TemplateArea.Parameters.CurrencyName = String(PrintingCurrency);
			TemplateArea.Parameters.Currency             = PrintingCurrency;
			SpreadsheetDocument.Put(TemplateArea);

			// Output table header.
			TemplateArea = Template.GetArea("TableHeader");
			TemplateArea.Parameters.Fill(Header);
			SpreadsheetDocument.Put(TemplateArea);
			
			TotalAmount        = 0;
			TotalAmountByAccounting = 0;

			TemplateArea = Template.GetArea("String");
			PricePrecision = PrecisionAppearancetServer.CompanyPrecision(Header.Company);
			
			While StringSelectionProducts.Next() Do

				TemplateArea.Parameters.Fill(StringSelectionProducts);
				TemplateArea.Parameters.Price = Format(StringSelectionProducts.Price,
					"NFD= " + PricePrecision);
				TemplateArea.Parameters.Product = DriveServer.GetProductsPresentationForPrinting(StringSelectionProducts.Product, 
																		StringSelectionProducts.Characteristic, StringSelectionProducts.SKU);
				TotalAmount        = TotalAmount        + StringSelectionProducts.Amount;
				TotalAmountByAccounting = TotalAmountByAccounting + StringSelectionProducts.AmountByAccounting;
				SpreadsheetDocument.Put(TemplateArea);

			EndDo;

			// Output Total
			TemplateArea                        = Template.GetArea("Total");
			TemplateArea.Parameters.Total        = DriveServer.AmountsFormat(TotalAmount);
			TemplateArea.Parameters.TotalByAccounting = DriveServer.AmountsFormat(TotalAmountByAccounting);
			SpreadsheetDocument.Put(TemplateArea);

			// Output signatures to document
			TemplateArea = Template.GetArea("Signatures");
			SpreadsheetDocument.Put(TemplateArea);
			
		EndIf;
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, CurrentDocument);
		
	EndDo;
	
	SpreadsheetDocument.FitToPage = True;
	
	Return SpreadsheetDocument;
	
EndFunction

#EndRegion

#EndRegion

#EndRegion

#EndIf