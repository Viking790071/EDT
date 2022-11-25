#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Procedure InitializeDocumentData(DocumentRef, AdditionalProperties) Export
	
	Query = New Query;
	Query.TempTablesManager = AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	#Region InitializeDocumentDataQueryText
	
	Query.Text = 
	"SELECT
	|	ProductionTaskDocument.Date AS Period,
	|	ProductionTaskDocument.BasisDocument AS WorkInProgress,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	ProductionTaskDocument.Operation AS Operation,
	|	CASE
	|		WHEN ProductionTaskDocument.Status = VALUE(Enum.ProductionTaskStatuses.Canceled)
	|			THEN 0
	|		ELSE ProductionTaskDocument.OperationQuantity
	|	END AS Quantity,
	|	CASE
	|		WHEN ProductionTaskDocument.Status = VALUE(Enum.ProductionTaskStatuses.Completed)
	|			THEN ProductionTaskDocument.OperationQuantity
	|		ELSE 0
	|	END AS QuantityProduced,
	|	ProductionTaskDocument.ConnectionKey AS ConnectionKey
	|FROM
	|	Document.ProductionTask AS ProductionTaskDocument
	|WHERE
	|	ProductionTaskDocument.Ref = &Ref";
	
	#EndRegion
	
	Query.SetParameter("Ref", DocumentRef);
	
	ResultsArray = Query.ExecuteBatch();
	
	AdditionalProperties.TableForRegisterRecords.Insert("TableProductionAccomplishment", ResultsArray[0].Unload());
	
EndProcedure

#Region LibrariesHandlers

#Region ObjectVersioning

// StandardSubsystems.ObjectVersioning

Procedure OnDefineObjectVersioningSettings(Settings) Export

EndProcedure

// End StandardSubsystems.ObjectVersioning

#EndRegion

#Region PrintInterface

// Generate objects printing forms.
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
	
	If PrintManagement.TemplatePrintRequired(PrintFormsCollection, "ProductionTasksList") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(
			PrintFormsCollection,
			"ProductionTasksList",
			Nstr("en = 'Production tasks list'; ru = 'Список производственных задач';pl = 'Lista zadań produkcyjnych';es_ES = 'Lista de tareas de producción';es_CO = 'Lista de tareas de producción';tr = 'Üretim görevleri listesi';it = 'Elenco incarichi di produzione';de = 'Liste der Produktionsaufgaben'"),
			PrintForm(
				ObjectsArray,
				PrintObjects,
				"ProductionTasksList",
				PrintParameters.Result));
			
	EndIf;
	
EndProcedure

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "ProductionTasksList";
	PrintCommand.Presentation				= NStr("en = 'Production tasks list'; ru = 'Список производственных задач';pl = 'Lista zadań produkcyjnych';es_ES = 'Lista de tareas de producción';es_CO = 'Lista de tareas de producción';tr = 'Üretim görevleri listesi';it = 'Elenco incarichi di produzione';de = 'Liste der Produktionsaufgaben'");
	PrintCommand.CheckPostingBeforePrint	= True;
	PrintCommand.Order						= 1;
	
EndProcedure

#EndRegion

#EndRegion

#EndRegion

#Region Private

#Region PrintInterface

Function PrintProductionTasksList(ObjectsArray, PrintObjects, TemplateName, PrintParams)
	
	// MultilingualSupport
	
	If PrintParams = Undefined Then
		LanguageCode = CommonClientServer.DefaultLanguageCode();
	Else
		LanguageCode = PrintParams.LanguageCode;
	EndIf;
	
	If LanguageCode <> CurrentLanguage().LanguageCode Then 
		SessionParameters.LanguageCodeForOutput = LanguageCode;
	EndIf;
	
	// End MultilingualSupport
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_ProductionTasksList";
	SpreadsheetDocument.PrintParametersName = "PrintParameters_ProductionTasksList";
	
	Template = PrintManagement.PrintFormTemplate("Document.ProductionTask.ProductionTasksList", LanguageCode);
	
	Query = New Query();
	Query.SetParameter("ObjectsArray", ObjectsArray);
	Query.Text =
	"SELECT
	|	ProductionTask.Ref AS ProductionTask,
	|	ProductionTask.Company AS Company,
	|	ProductionTask.StructuralUnit AS StructuralUnit,
	|	ProductionOrder.BasisDocument AS SalesOrder,
	|	ManufacturingOperation.Products AS FinishedProduct,
	|	ManufacturingOperation.Characteristic AS FinishedVariant,
	|	ManufacturingOperation.Quantity AS ProductQuantity,
	|	ManufacturingOperation.MeasurementUnit AS Unit,
	|	ProductionTask.Output AS Output,
	|	ProductionOrder.Ref AS ProductionOrder,
	|	ProductionTask.Operation AS Operation,
	|	ProductionTask.OperationQuantity AS OperationQuantity,
	|	ProductionTask.StandardTimeInUOM AS StandardTimeInUOM,
	|	ProductionTask.TimeUOM AS TimeUOM,
	|	ProductionTask.EndDatePlanned AS EndDatePlanned,
	|	ProductionTask.StartDatePlanned AS StartDatePlanned,
	|	ProductionTask.WorkcenterType AS WorkcenterType,
	|	ProductionTask.Workcenter AS Workcenter,
	|	ProductionTask.Assignee AS Assignee,
	|	ProductionTask.Number AS TaskNumber,
	|	ProductionTask.Date AS TaskDate
	|FROM
	|	Document.ProductionTask AS ProductionTask
	|		LEFT JOIN Document.ManufacturingOperation AS ManufacturingOperation
	|			LEFT JOIN Document.ProductionOrder AS ProductionOrder
	|			ON ManufacturingOperation.BasisDocument = ProductionOrder.Ref
	|		ON ProductionTask.BasisDocument = ManufacturingOperation.Ref
	|WHERE
	|	ProductionTask.Ref IN(&ObjectsArray)
	|
	|ORDER BY
	|	TaskNumber
	|TOTALS
	|	MAX(Company),
	|	MAX(StructuralUnit),
	|	MAX(SalesOrder)
	|BY
	|	ProductionOrder";
	
	// MultilingualSupport
	DriveServer.ChangeQueryTextForCurrentLanguage(Query.Text, LanguageCode);
	// End MultilingualSupport
	
	ProductionOrderHeader = Query.Execute().Select(QueryResultIteration.ByGroups);
	
	// Header
	TemplateArea = Template.GetArea("Header");
	TemplateArea.Parameters.CurrentDate = Format(CurrentSessionDate(), "DLF=D");
	SpreadsheetDocument.Put(TemplateArea);
	
	EmptyLine = Template.GetArea("EmptyLine");
	SpreadsheetDocument.Put(EmptyLine);
	
	While ProductionOrderHeader.Next() Do
		
		// Production order header
		
		TemplateArea = Template.GetArea("ProductionOrderHeader");
		
		TemplateArea.Parameters.Company = ProductionOrderHeader.Company;
		TemplateArea.Parameters.StructuralUnit = ProductionOrderHeader.StructuralUnit;
		
		If ValueIsFilled(ProductionOrderHeader.ProductionOrder) Then
			
			TemplateArea.Parameters.ProductionOrder = ProductionOrderHeader.ProductionOrder;
			
		EndIf;
		
		If ValueIsFilled(ProductionOrderHeader.SalesOrder) Then
			
			TemplateArea.Parameters.SalesOrder = ProductionOrderHeader.SalesOrder;
			
		EndIf;
		
		SpreadsheetDocument.Put(TemplateArea);
		SpreadsheetDocument.Put(EmptyLine);
		
		ProductionTaskSelection = ProductionOrderHeader.Select();
		
		While ProductionTaskSelection.Next() Do
			
			SpreadsheetDocument.StartRowAutoGrouping();
			
			// Production task line header
			
			TemplateArea = Template.GetArea("ProductionTaskLineHeader");
			
			FillPropertyValues(TemplateArea.Parameters, ProductionTaskSelection);
			TemplateArea.Parameters.TaskNumber = ObjectPrefixationClientServer.GetNumberForPrinting(ProductionTaskSelection.TaskNumber, True, True);
			TemplateArea.Parameters.TaskDate = Format(ProductionTaskSelection.TaskDate, "DLF=D");
			TemplateArea.Parameters.Output = ?(ProductionTaskSelection.Output, NStr("en = 'output'; ru = 'вывод';pl = 'wyjście';es_ES = 'salida';es_CO = 'salida';tr = 'çıktı';it = 'output';de = 'Produktionsmenge'"), NStr("en = 'no output'; ru = 'нет выработки';pl = 'brak wyjścia';es_ES = 'sin producción';es_CO = 'sin producción';tr = 'çıkış yok';it = 'nessun output';de = 'keine Produktionsmenge'"));
			
			ProductText = "";
			If ValueIsFilled(ProductionTaskSelection.FinishedVariant) Then
				ProductText = " , " + ProductionTaskSelection.FinishedVariant; 
			EndIf;
			If ValueIsFilled(ProductionTaskSelection.ProductQuantity) Then
				ProductText = ProductText + ", " + ProductionTaskSelection.ProductQuantity + " " + ProductionTaskSelection.Unit; 
			EndIf;
			TemplateArea.Parameters.ProductText = ProductText;
			
			SpreadsheetDocument.Put(TemplateArea);
			
			// Production task line section
			
			TemplateArea = Template.GetArea("ProductionTaskLineSection");
			
			BarcodesInPrintForms.AddWidthBarcodeToTableDocument(TemplateArea, ProductionTaskSelection.ProductionTask);
			FillPropertyValues(TemplateArea.Parameters, ProductionTaskSelection);
			
			TemplateArea.Parameters.PlannedWorkloadTime = ProductionTaskSelection.OperationQuantity * ProductionTaskSelection.StandardTimeInUOM;
			TemplateArea.Parameters.StartDatePlanned = Format(ProductionTaskSelection.StartDatePlanned, "DLF=DT; DE=-");
			TemplateArea.Parameters.EndDatePlanned = Format(ProductionTaskSelection.EndDatePlanned, "DLF=DT; DE=-");
			
			ComponentsList = Chars.LF;
			Components = Common.ObjectAttributeValue(ProductionTaskSelection.ProductionTask, "Inventory");
			ComponentsSelection = Components.Select();
			
			While ComponentsSelection.Next() Do
				
				ComponentsList = ComponentsList + ComponentsSelection.Products + " " + ComponentsSelection.Characteristic
				+ ", " + ComponentsSelection.Quantity + ComponentsSelection.MeasurementUnit + Chars.LF;
				
			EndDo;
			
			TemplateArea.Parameters.ComponentsList = ComponentsList;
			
			SpreadsheetDocument.Put(TemplateArea);
			
			SpreadsheetDocument.EndRowAutoGrouping();
			
			SpreadsheetDocument.Put(EmptyLine);
			
		EndDo;
		
		TemplateArea = Template.GetArea("DivideLine");
		SpreadsheetDocument.Put(TemplateArea);
		
	EndDo;
	
	TemplateArea = Template.GetArea("Footer");
	SpreadsheetDocument.Put(TemplateArea);
	
	Return SpreadsheetDocument;

EndFunction

Function PrintForm(ObjectsArray, PrintObjects, TemplateName, PrintParams = Undefined)
	
	If TemplateName = "ProductionTasksList" Then
		
		Return PrintProductionTasksList(ObjectsArray, PrintObjects, TemplateName, PrintParams)
		
	EndIf;
	
EndFunction

#EndRegion

#EndRegion

#EndIf