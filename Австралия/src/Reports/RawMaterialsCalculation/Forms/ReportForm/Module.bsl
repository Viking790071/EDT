
#Region Variables

Var Template;
Var Document;
Var TableOfOperations, ContentTable;
Var RowAppearance;

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
// Procedure of product content scheme formation.
// 
Procedure DisplayProductContent()
	
	If ContentTable.Count() < 2 Then
		
		Message = New UserMessage();
		Message.Text = NStr("en = 'Raw materials calculation is not filled'; ru = 'Не заполнен нормативный состав изделия';pl = 'Obliczenia materiałów nie są wypełnione';es_ES = 'Cálculo de materias primas no está rellenado';es_CO = 'Cálculo de materias primas no está rellenado';tr = 'Hammadde hesaplaması doldurulmadı';it = 'Il calcolo delle materie prime non è compilato';de = 'Rohstoffkalkulation ist nicht ausgefüllt'");
		Message.Message();
		
		Return;
		
	EndIf;
	
	RowIndex = ContentTable.Count() - 1;
	TotalsCorrespondence = New Map;
	
	While RowIndex >= 0 Do 
		
		CurRow = ContentTable[RowIndex];
		
		If TotalsCorrespondence[CurRow.Level + 1] <> Undefined
			And TotalsCorrespondence[CurRow.Level + 1] <> 0 Then
			CurRow.Cost = TotalsCorrespondence[CurRow.Level + 1];
			TotalsCorrespondence[CurRow.Level + 1] = 0;
		EndIf;
		
		If TotalsCorrespondence[CurRow.Level] = Undefined Then 
			TotalsCorrespondence.Insert(CurRow.Level, CurRow.Cost);
		Else
			TotalsCorrespondence[CurRow.Level] = TotalsCorrespondence[CurRow.Level] + CurRow.Cost;
		EndIf;
		
		RowIndex = RowIndex - 1;
		
	EndDo;
	
	For Each ContentRow In ContentTable Do
		
		Template.Area("ContentRow|Products").Indent = ContentRow.Level*2;
		TemplateArea = Template.GetArea("ContentRow|ContentColumn");
		
		TemplateArea.Parameters.PresentationOfProducts 	= ContentRow.Products.Description +" "+ContentRow.Characteristic.Description;
		TemplateArea.Parameters.Products				= ContentRow.Products;
		TemplateArea.Parameters.Quantity					= ContentRow.Quantity;
		TemplateArea.Parameters.MeasurementUnit			= ContentRow.MeasurementUnit;
		TemplateArea.Parameters.AccountingPrice                 = ContentRow.AccountingPrice;
		TemplateArea.Parameters.Cost	         		= ContentRow.Cost;
		
		RowIndex = ContentTable.IndexOf(ContentRow);
		
		If ContentRow.Node Then
			TemplateArea.Area(1,2,1,19).BackColor = RowAppearance[ContentRow.Level - Int(ContentRow.Level / 5) * 5];
		EndIf;
		
		If RowIndex < ContentTable.Count() - 1 Then
			
			NexRows = ContentTable[RowIndex+1];
			
			If NexRows.Level > ContentRow.Level Then
				Document.Put(TemplateArea);
				Document.StartRowGroup(ContentRow.Products.Description);
			ElsIf NexRows.Level < ContentRow.Level Then
				Document.Put(TemplateArea);
				DifferenceOfLevels = ContentRow.Level - NexRows.Level;
				While DifferenceOfLevels >= 1 Do
					Document.EndRowGroup();
					DifferenceOfLevels = DifferenceOfLevels - 1;
				EndDo;
			Else
				Document.Put(TemplateArea);
			EndIf;
		Else
			Document.Put(TemplateArea);
			Document.EndRowGroup();
		EndIf;
		
	EndDo;
	
	ContentTable.Clear();
	
EndProcedure

&AtServer
// Procedure of product operation scheme formation.
// 
Procedure OutputOperationsContent()
	
	RowIndex = TableOfOperations.Count() - 1;
	TotalsCorrespondenceTimeNorm = New Map;
	MapTotalsDuration = New Map;
	TotalsCorrespondenceCost = New Map;
	
	While RowIndex >= 0 Do 
		
        CurRow = TableOfOperations[RowIndex];
		
		If RowIndex = 0 Then
			
			CurRow.TimeNorm = TotalsCorrespondenceTimeNorm.Get(CurRow.Level);
			CurRow.Duration = MapTotalsDuration.Get(CurRow.Level);
			CurRow.Cost = TotalsCorrespondenceCost.Get(CurRow.Level);
			
		Else
			
			NextRow = TableOfOperations[RowIndex - 1];
			
			If CurRow.Node Then
				
				CurRow.TimeNorm = TotalsCorrespondenceTimeNorm.Get(CurRow.Level);
				If TotalsCorrespondenceTimeNorm.Get(CurRow.Level - 1) = Undefined Then 
					TotalsCorrespondenceTimeNorm.Insert(CurRow.Level - 1, CurRow.TimeNorm);
				Else
					TotalsCorrespondenceTimeNorm[CurRow.Level - 1] = TotalsCorrespondenceTimeNorm[CurRow.Level - 1] + CurRow.TimeNorm;
				EndIf;	
				TotalsCorrespondenceTimeNorm.Insert(CurRow.Level, 0);
				
				CurRow.Duration = MapTotalsDuration.Get(CurRow.Level);
				If MapTotalsDuration.Get(CurRow.Level - 1) = Undefined Then 
					MapTotalsDuration.Insert(CurRow.Level - 1, CurRow.Duration);
				Else
					MapTotalsDuration[CurRow.Level - 1] = MapTotalsDuration[CurRow.Level - 1] + CurRow.Duration;
				EndIf;	
				MapTotalsDuration.Insert(CurRow.Level, 0);
				
				CurRow.Cost = TotalsCorrespondenceCost.Get(CurRow.Level);
				If TotalsCorrespondenceCost.Get(CurRow.Level - 1) = Undefined Then 
					TotalsCorrespondenceCost.Insert(CurRow.Level - 1, CurRow.Cost);
				Else
					TotalsCorrespondenceCost[CurRow.Level - 1] = TotalsCorrespondenceCost[CurRow.Level - 1] + CurRow.Cost;
				EndIf;	
				TotalsCorrespondenceCost.Insert(CurRow.Level, 0);
				
			Else
				
				If TotalsCorrespondenceTimeNorm.Get(CurRow.Level - 1) = Undefined Then 
					TotalsCorrespondenceTimeNorm.Insert(CurRow.Level - 1, CurRow.TimeNorm);
				Else
					TotalsCorrespondenceTimeNorm[CurRow.Level - 1] = TotalsCorrespondenceTimeNorm[CurRow.Level - 1] + CurRow.TimeNorm;
				EndIf;	
				
				If MapTotalsDuration.Get(CurRow.Level - 1) = Undefined Then 
					MapTotalsDuration.Insert(CurRow.Level - 1, CurRow.Duration);
				Else
					MapTotalsDuration[CurRow.Level - 1] = MapTotalsDuration[CurRow.Level - 1] + CurRow.Duration;
				EndIf;	
				
				If TotalsCorrespondenceCost.Get(CurRow.Level - 1) = Undefined Then 
					TotalsCorrespondenceCost.Insert(CurRow.Level - 1, CurRow.Cost);
				Else
					TotalsCorrespondenceCost[CurRow.Level - 1] = TotalsCorrespondenceCost[CurRow.Level - 1] + CurRow.Cost;
				EndIf;	
				
			EndIf;
			
		EndIf;
		
		RowIndex = RowIndex - 1;
		
	EndDo;
	
	GroupRowsIsOpen = False;
	
	For Each RowOperation In TableOfOperations Do
		
		Template.Area("RowOperation|Products").Indent = RowOperation.Level * 2;
		TemplateArea = Template.GetArea("RowOperation|ContentColumn");
		
		If RowOperation.Node Then
			TemplateArea.Parameters.PresentationOfProducts = RowOperation.Products.Description +" "+RowOperation.Characteristic.Description;
		Else
			TemplateArea.Parameters.PresentationOfProducts = RowOperation.Products.Description;
		EndIf;
		
		TemplateArea.Parameters.Products = RowOperation.Products;
		TemplateArea.Parameters.Norm		 = RowOperation.TimeNorm;
		TemplateArea.Parameters.Duration = RowOperation.Duration;
		TemplateArea.Parameters.AccountingPrice  = RowOperation.AccountingPrice;
		TemplateArea.Parameters.Cost	 = RowOperation.Cost;
		
		RowIndex = TableOfOperations.IndexOf(RowOperation);
		
		If RowOperation.Node Then
			TemplateArea.Area(1,2,1,19).BackColor = RowAppearance[RowOperation.Level - Int(RowOperation.Level / 5) * 5];
		EndIf;
		
		If RowIndex < TableOfOperations.Count() - 1 Then
			
			NexRows = TableOfOperations[RowIndex+1];
			
			If NexRows.Level > RowOperation.Level Then
				
				Document.Put(TemplateArea);
				Document.StartRowGroup(RowOperation.Products.Description);
				GroupRowsIsOpen = True;
				
			ElsIf NexRows.Level < RowOperation.Level Then
				
				Document.Put(TemplateArea);
				DifferenceOfLevels = RowOperation.Level - NexRows.Level;                                  
				While DifferenceOfLevels >= 1 Do
					
					Document.EndRowGroup();
					DifferenceOfLevels = DifferenceOfLevels - 1;
					
				EndDo;
				
			Else
				
				Document.Put(TemplateArea);
				
			EndIf;
			
		Else
			
			Document.Put(TemplateArea);
			
			// Check the need to close the grouping
			If GroupRowsIsOpen Then 
				
				Document.EndRowGroup();
				GroupRowsIsOpen = False;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	TableOfOperations.Clear();
	
EndProcedure

&AtServer
// Function forms tree by request.
//
// Parameters:
//  exProducts - CatalogRef.Products - products.
//
Function GenerateTree(Products, Specification, Characteristic)
	
	ContentStructure = DriveServer.GenerateContentStructure();
	ContentStructure.Products		= Products;
	ContentStructure.Characteristic		= Characteristic;
	ContentStructure.MeasurementUnit	= Products.MeasurementUnit;
	ContentStructure.Quantity			= Report.Quantity;
	ContentStructure.Specification		= Specification;
	ContentStructure.ProcessingDate		= Report.CalculationDate;
	ContentStructure.PriceKind     		= Report.PriceKind;
	ContentStructure.Level			= 0;
	ContentStructure.AccountingPrice		= 0;
	ContentStructure.Cost			= 0;
	
	Array = New Array;
	Array.Add(Type("Number"));
	TypeDescription = New TypeDescription(Array, , , New NumberQualifiers(15, 3));
	
	ContentTable = New ValueTable;
	
	ContentTable.Columns.Add("Products");
	ContentTable.Columns.Add("Characteristic");
	ContentTable.Columns.Add("MeasurementUnit");
	ContentTable.Columns.Add("Quantity", TypeDescription);
    ContentTable.Columns.Add("Level");
	ContentTable.Columns.Add("Node");
	ContentTable.Columns.Add("AccountingPrice", TypeDescription);
	ContentTable.Columns.Add("Cost", TypeDescription);
	
	TableOfOperations = New ValueTable;
	
	TableOfOperations.Columns.Add("Products");
	TableOfOperations.Columns.Add("Characteristic");
	TableOfOperations.Columns.Add("TimeNorm", TypeDescription);
	TableOfOperations.Columns.Add("Duration", TypeDescription);
	TableOfOperations.Columns.Add("Level");
	TableOfOperations.Columns.Add("Node");
	TableOfOperations.Columns.Add("AccountingPrice", TypeDescription);
	TableOfOperations.Columns.Add("Cost", TypeDescription);
	
	DriveServer.Denoding(ContentStructure, ContentTable, TableOfOperations);
	
EndFunction

&AtServer
// Procedure forms report by product content.
//
Procedure GenerateReport(Products, Characteristic, Specification)
	
	If Not ValueIsFilled(Products) Then
		
		MessageText = NStr("en = 'The Products field is required'; ru = 'Поле Номенклатура не заполнено';pl = 'Nie wypełniono pola ""Towary""';es_ES = 'Se requiere el campo Productos';es_CO = 'Se requiere el campo Productos';tr = '""Ürünler"" alanı gerekli';it = 'Il campo articolo è obbligatorio';de = 'Das Feld Produkte ist erforderlich'");
		MessageField = "Products";
		DriveServer.ShowMessageAboutError(Report, MessageText,,,MessageField);
		
		Return;
	
	EndIf;
	
	If Not ValueIsFilled(Specification) Then
		
		MessageText = NStr("en = 'The ""Bill of materials"" field is not filled in'; ru = 'Поле Спецификация не заполнено';pl = 'Nie wypełniono pola ""Specyfikacja materiałowa""';es_ES = 'El campo ""Lista de materiales"" no está rellenado';es_CO = 'El campo ""Lista de materiales"" no está rellenado';tr = '""Ürün reçetesi"" alanı doldurulmadı';it = 'Il campo ""Distinta base"" non è compilato';de = 'Das Feld ""Stückliste"" ist nicht ausgefüllt'");
		MessageField = "Specification";
		DriveServer.ShowMessageAboutError(Report, MessageText,,,MessageField);
		
		Return;
	
	EndIf;
	
	Document = SpreadsheetDocumentReport;
	Document.Clear();
	
	GenerateTree(Products, Specification, Characteristic);
	
	Report.Cost = ContentTable.Total("Cost") + TableOfOperations.Total("Cost");
	
	Template = Reports.RawMaterialsCalculation.GetTemplate("Template");
	
	TemplateArea = Template.GetArea("Title");
	TemplateArea.Parameters.Title = "Finished product cost components as of " + Format(Report.CalculationDate,"DLF=DD") + Chars.LF
										+ "Product: " + Products.Description
										+ ?(ValueIsFilled(Report.Characteristic), ", " + Report.Characteristic, "")
										+ ", " + Specification + Chars.LF
										+ "Quantity: " + Report.Quantity + " " + Products.MeasurementUnit
										+ ". Cost: " + Report.Cost + " " + Report.PriceKind.PriceCurrency.Description
										+ Chars.LF;
	Document.Put(TemplateArea);
	
	RowAppearance = New Array;
	
	RowAppearance.Add(WebColors.MediumTurquoise);
	RowAppearance.Add(WebColors.MediumGreen);
	RowAppearance.Add(WebColors.AliceBlue);
	RowAppearance.Add(WebColors.Cream);
	RowAppearance.Add(WebColors.Azure);

	TemplateArea = Template.GetArea("ContentTitle|ContentColumn");
	Document.Put(TemplateArea);
	
	DisplayProductContent();
	
	If Constants.UseOperationsManagement.Get() AND TableOfOperations.Count() > 0 Then
	
		TemplateAreaOperations = Template.GetArea("Indent");
		Document.Put(TemplateAreaOperations);
		
		TemplateArea = Template.GetArea("OperationTitle|ContentColumn");
		Document.Put(TemplateArea);
		
		OutputOperationsContent();
		
	EndIf;	

EndProcedure

&AtServerNoContext
// Receives the set of data from the server for the ProductsOnChange procedure.
//
Function GetDataProductsOnChange(StructureData)
	
	StructureData.Insert("Specification", DriveServer.GetDefaultSpecification(StructureData.Products, StructureData.Characteristic));
	
	Return StructureData;
	
EndFunction

#Region ProcedureActionsOfTheFormCommandPanels

&AtClient
// Procedure is called when clicking "Generate" command
// panel of tabular field.
//
Procedure Generate(Command)
	
	GenerateReport(Report.Products, Report.Characteristic, Report.Specification);
	
EndProcedure

#EndRegion

#Region ProcedureEventHandlersOfHeaderAttributes

&AtClient
// Procedure - event handler OnChange of the Products input field.
//
Procedure ProductsOnChange(Item)
	
	StructureData = New Structure;
	StructureData.Insert("Products", Report.Products);
	StructureData.Insert("Characteristic", Report.Characteristic);
	
	StructureData = GetDataProductsOnChange(StructureData);
	Report.Specification = StructureData.Specification;

EndProcedure

&AtClient
// Procedure - event handler OnChange of the variant input field.
//
Procedure CharacteristicOnChange(Item)
	
	StructureData = New Structure;
	StructureData.Insert("Products", Report.Products);
	StructureData.Insert("Characteristic", Report.Characteristic);
	
	StructureData = GetDataProductsOnChange(StructureData);
	Report.Specification = StructureData.Specification;
	
EndProcedure

// Procedure - OnOpen form event handler
//
&AtClient
Procedure OnOpen(Cancel)
	
	Report.CalculationDate = CommonClient.SessionDate();
		
EndProcedure

// Procedure - event handler OnCreateAtServer of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("Products") Then
		
		If ValueIsFilled(Parameters.Products) Then
			
			StructureData = New Structure;
			
			If TypeOf(Parameters.Products ) = Type("CatalogRef.Products") Then
				StructureData.Insert("Products", Parameters.Products);
				StructureData.Insert("Characteristic", Catalogs.ProductsCharacteristics.EmptyRef());
				StructureData      = GetDataProductsOnChange(StructureData);
				Report.Products   = StructureData.Products;
				Report.Specification   = StructureData.Specification;
			Else // BillsOfMaterials
				Report.Products   = Parameters.Products.Owner;
				Report.Characteristic = Parameters.Products.ProductCharacteristic;
				Report.Specification   = Parameters.Products;
			EndIf;
			
		EndIf;
		
	EndIf;
	
	Report.PriceKind = Catalogs.PriceTypes.Accounting;
	Report.Quantity = 1;
	
EndProcedure

&AtServer
Procedure OnSaveUserSettingsAtServer(Settings)
	ReportsOptions.OnSaveUserSettingsAtServer(ThisObject, Settings);
EndProcedure

#EndRegion

#EndRegion