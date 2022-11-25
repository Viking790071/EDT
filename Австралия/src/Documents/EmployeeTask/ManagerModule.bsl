#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefEmployeeTask, StructureAdditionalProperties) Export
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text = 
	"SELECT
	|	&Company AS Company,
	|	WorkOrderWorks.Day AS Period,
	|	CASE
	|		WHEN WorkOrderWorks.Customer REFS Catalog.Counterparties
	|			THEN WorkOrderWorks.Customer
	|		WHEN WorkOrderWorks.Customer REFS Catalog.CounterpartyContracts
	|			THEN WorkOrderWorks.Customer.Owner
	|		WHEN WorkOrderWorks.Customer REFS Document.SalesOrder
	|			THEN WorkOrderWorks.Customer.Counterparty
	|	END AS Counterparty,
	|	CASE
	|		WHEN WorkOrderWorks.Customer REFS Catalog.Counterparties
	|			THEN VALUE(Catalog.CounterpartyContracts.EmptyRef)
	|		WHEN WorkOrderWorks.Customer REFS Catalog.CounterpartyContracts
	|			THEN WorkOrderWorks.Customer
	|		WHEN WorkOrderWorks.Customer REFS Document.SalesOrder
	|			THEN WorkOrderWorks.Customer.Contract
	|	END AS Contract,
	|	CASE
	|		WHEN WorkOrderWorks.Customer REFS Catalog.Counterparties
	|				OR WorkOrderWorks.Customer REFS Catalog.CounterpartyContracts
	|			THEN VALUE(Document.SalesOrder.EmptyRef)
	|		WHEN WorkOrderWorks.Customer REFS Document.SalesOrder
	|			THEN WorkOrderWorks.Customer
	|	END AS SalesOrder,
	|	WorkOrderWorks.Ref.Employee,
	|	WorkOrderWorks.Products,
	|	WorkOrderWorks.Characteristic,
	|	WorkOrderWorks.WorkKind,
	|	WorkOrderWorks.DurationInHours AS ImportPlan,
	|	WorkOrderWorks.Amount AS AmountPlan,
	|	WorkOrderWorks.Ref.StructuralUnit,
	|	DATEADD(WorkOrderWorks.Day, MINUTE, HOUR(WorkOrderWorks.BeginTime) * 60 + MINUTE(WorkOrderWorks.BeginTime)) AS BeginTime,
	|	DATEADD(WorkOrderWorks.Day, MINUTE, HOUR(WorkOrderWorks.EndTime) * 60 + MINUTE(WorkOrderWorks.EndTime)) AS EndTime,
	|	WorkOrderWorks.Comment
	|FROM
	|	Document.EmployeeTask.Works AS WorkOrderWorks
	|WHERE
	|	WorkOrderWorks.Ref = &Ref
	|	AND WorkOrderWorks.DurationInHours > 0";
	
	Query.SetParameter("Ref", DocumentRefEmployeeTask);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);

	Result = Query.Execute();
	TableEmployeeTasks = Result.Unload();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableEmployeeTasks", TableEmployeeTasks);
	
EndProcedure

#Region LibrariesHandlers

#Region PrintInterface

// Generate printed forms of objects
//
// Incoming:
//   TemplateNames    - String    - Names of layouts separated by commas
//   ObjectsArray     - Array     - Array of refs to objects that need to be printed
//   PrintParameters  - Structure - Structure of additional printing parameters
//
// Outgoing:
//   PrintFormsCollection - Values table - Generated table documents 
//   OutputParameters     - Structure    - Parameters of generated table documents
//
Procedure Print(ObjectsArray, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters) Export
	
	If PrintManagement.TemplatePrintRequired(PrintFormsCollection, "EmployeeTasks") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(
			PrintFormsCollection,
			"EmployeeTasks",
			NStr("en = 'Employee task'; ru = 'Задача сотрудника';pl = 'Zadanie pracownika';es_ES = 'Tarea de empleado';es_CO = 'Tarea de empleado';tr = 'Çalışan görevi';it = 'Compito dipendente';de = 'Mitarbeiteraufgabe'"),
			PrintForm(ObjectsArray, PrintObjects, , PrintParameters.Result));
		
	EndIf;
	
	If PrintManagement.TemplatePrintRequired(PrintFormsCollection, "Requisition") Then
		PrintManagement.OutputSpreadsheetDocumentToCollection(
			PrintFormsCollection,
			"Requisition",
			NStr("en = 'Requisition'; ru = 'Требование';pl = 'Zapotrzebowanie';es_ES = 'Solicitud';es_CO = 'Solicitud';tr = 'Talep formu';it = 'Requisizione';de = 'Anforderung'"),
			DataProcessors.PrintRequisition.PrintForm(ObjectsArray, PrintObjects, "Requisition"));
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
	PrintCommand.ID						 = "EmployeeTasks";
	PrintCommand.Presentation			 = NStr("en = 'Employee task'; ru = 'Задача сотрудника';pl = 'Zadanie pracownika';es_ES = 'Tarea de empleado';es_CO = 'Tarea de empleado';tr = 'Çalışan görevi';it = 'Compito dipendente';de = 'Mitarbeiteraufgabe'");
	PrintCommand.FormsList				 = "DocumentForm,ListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 1;
	
EndProcedure

#EndRegion

#Region PrivatePrintInterface

// Function generates document printing form by specified layout.
//
// Parameters:
// SpreadsheetDocument - TabularDocument in which
// 			   printing form will be displayed.
//  TemplateName    - String, printing form layout name.
//
Function PrintForm(ObjectsArray, PrintObjects, TemplateName = "", PrintParams = Undefined)
	
	SpreadsheetDocument 	= New SpreadsheetDocument;
	FirstDocument 		= True;
	
	For Each CurrentDocument In ObjectsArray Do
	
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		Query = New Query();
		
		Query.SetParameter("Company", 		DriveServer.GetCompany(CurrentDocument.Company));
		Query.SetParameter("CurrentDocument", 	CurrentDocument);
		
		Query.Text = 
		"SELECT ALLOWED
		|	WorkOrder.Ref,
		|	WorkOrder.DataVersion,
		|	WorkOrder.DeletionMark,
		|	WorkOrder.Number,
		|	WorkOrder.Date,
		|	WorkOrder.Posted,
		|	WorkOrder.Company,
		|	WorkOrder.OperationKind,
		|	WorkOrder.WorkKind AS WorkKind,
		|	WorkOrder.PriceKind,
		|	WorkOrder.Employee AS Employee,
		|	WorkOrder.Employee.Code AS EmployeeCode,
		|	WorkOrder.StructuralUnit AS Department,
		|	EmployeesSliceLast.Position AS Position,
		|	WorkOrder.DocumentAmount,
		|	WorkOrder.WorkKindPosition,
		|	WorkOrder.Event,
		|	WorkOrder.Comment,
		|	WorkOrder.Author
		|FROM
		|	Document.EmployeeTask AS WorkOrder
		|		LEFT JOIN InformationRegister.Employees.SliceLast(, ) AS EmployeesSliceLast
		|		ON WorkOrder.Employee = EmployeesSliceLast.Employee
		|			AND (&Company = EmployeesSliceLast.Company)
		|WHERE
		|	WorkOrder.Ref = &CurrentDocument
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	WorkOrderWorks.Ref,
		|	WorkOrderWorks.LineNumber,
		|	WorkOrderWorks.WorkKind,
		|	WorkOrderWorks.Customer,
		|	WorkOrderWorks.Products,
		|	WorkOrderWorks.Characteristic,
		|	WorkOrderWorks.Day AS Day,
		|	WorkOrderWorks.BeginTime AS BeginTime,
		|	WorkOrderWorks.EndTime,
		|	WorkOrderWorks.Duration,
		|	WorkOrderWorks.DurationInHours AS DurationInHours,
		|	WorkOrderWorks.Price,
		|	WorkOrderWorks.Amount AS Amount,
		|	WorkOrderWorks.Comment AS TaskDescription
		|FROM
		|	Document.EmployeeTask.Works AS WorkOrderWorks
		|WHERE
		|	WorkOrderWorks.Ref = &CurrentDocument
		|
		|ORDER BY
		|	BeginTime
		|TOTALS
		|	SUM(DurationInHours),
		|	SUM(Amount)
		|BY
		|	Day";
		
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
		
		QueryResult	= Query.ExecuteBatch();
		Header 				= QueryResult[0].Select();
		Header.Next();
		
		DaysSelection			= QueryResult[1].Select(QueryResultIteration.ByGroups);
		
		SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_EmployeeTask_UnifiedForm";
		
		Template = PrintManagement.PrintFormTemplate("Document.EmployeeTask.PF_MXL_Task", LanguageCode);
		
		AreaHeader		= Template.GetArea("Header");
		TableHeaderArea	= Template.GetArea("TableHeader");
		AreaDay			= Template.GetArea("Day");
		AreaDetails		= Template.GetArea("Details");
		AreaTotalAmount	= Template.GetArea("Total");
		FooterArea		= Template.GetArea("Footer");
		
		AreaHeader.Parameters.Fill(Header);
		
		AreaHeader.Parameters.NumberDate = "#" + Header.Number + ", " + Format(Header.Date, "DLF=DD");
		
		InfoAboutCompany = DriveServer.InfoAboutLegalEntityIndividual(
			Header.Company,
			Header.Date,
			,
			,
			,
			LanguageCode);
		AreaHeader.Parameters.CompanyPresentation = DriveServer.CompaniesDescriptionFull(
			InfoAboutCompany, 
			"FullDescr, TIN, ActualAddress, PhoneNumbers, AccountNo, Bank, BIN");
		
		SpreadsheetDocument.Put(AreaHeader);
		
		TableHeaderArea.Parameters.TaskKindText = ?(
			Header.OperationKind = Enums.OperationTypesEmployeeTask.External,
			NStr("en = 'Employee task is external.'; ru = 'Задача сотрудника внешняя.';pl = 'Zadanie pracownika jest zewnętrzne.';es_ES = 'La tarea del empleado es externa.';es_CO = 'La tarea del empleado es externa.';tr = 'Çalışan görevi haricidir.';it = 'L''incarico del dipendente è esterno.';de = 'Äußere Arbeitnehmeraufgabe.'", LanguageCode),
			NStr("en = 'Employee task is internal.'; ru = 'Задача сотрудника служебная.';pl = 'Zadanie pracownika jest wewnętrzne.';es_ES = 'La tarea del empleado es interna.';es_CO = 'La tarea del empleado es interna.';tr = 'Çalışan görevi dahilidir.';it = 'L''incarico del dipendente è interno.';de = 'Innere Arbeitnehmeraufgabe.'", LanguageCode));
			
		SpreadsheetDocument.Put(TableHeaderArea);
		
		TotalDurationInHours = 0;
		
		PricePrecision = PrecisionAppearancetServer.CompanyPrecision(Header.Company);
		
		While DaysSelection.Next() Do
			
			AreaDay.Parameters.Fill(DaysSelection);
			SpreadsheetDocument.Put(AreaDay);
			
			SelectionDayWorks	= DaysSelection.Select();
			While SelectionDayWorks.Next() Do
				
				TotalDurationInHours = TotalDurationInHours + SelectionDayWorks.DurationInHours;
				AreaDetails.Parameters.Fill(SelectionDayWorks);
				AreaDetails.Parameters.Price = Format(SelectionDayWorks.Price,
					"NFD= " + PricePrecision);
				
				// If kind of work is shown in TS, then generate the description 
				If Header.WorkKindPosition = Enums.AttributeStationing.InTabularSection Then
					
					AreaDetails.Parameters.TaskDescription = "[" + SelectionDayWorks.WorkKind + "] " + SelectionDayWorks.TaskDescription;
					
				EndIf;
				
				
				SpreadsheetDocument.Put(AreaDetails);
				
			EndDo;
			
		EndDo;
	
		AreaTotalAmount.Parameters.Fill(Header);
		AreaTotalAmount.Parameters.DurationInHours = TotalDurationInHours;
		SpreadsheetDocument.Put(AreaTotalAmount);
		
		FooterArea.Parameters.DetailsOfResponsible = "" + Header.Employee + ?(ValueIsFilled(Header.Position), ", " + Header.Position, "");
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, Header.Ref);
		
		SpreadsheetDocument.Put(FooterArea);
		
	EndDo;
	
	Return SpreadsheetDocument;
	
EndFunction

#EndRegion

#Region ObjectVersioning

// StandardSubsystems.ObjectVersioning

Procedure OnDefineObjectVersioningSettings(Settings) Export

EndProcedure

// End StandardSubsystems.ObjectVersioning

#EndRegion

#EndRegion

#EndRegion

#EndIf