#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefWeeklyTimesheet, StructureAdditionalProperties) Export
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	WeekDays = New ValueTable;
	WeekDays.Columns.Add("Prefix");
	
	NewRow = WeekDays.Add();
	NewRow.Prefix = "Mo";
	NewRow = WeekDays.Add();
	NewRow.Prefix = "Tu";
	NewRow = WeekDays.Add();
	NewRow.Prefix = "We";
	NewRow = WeekDays.Add();
	NewRow.Prefix = "Th";
	NewRow = WeekDays.Add();
	NewRow.Prefix = "Fr";
	NewRow = WeekDays.Add();
	NewRow.Prefix = "Sa";
	NewRow = WeekDays.Add();
	NewRow.Prefix = "Su";
	
	DriveServer.CircleShiftCollection(WeekDays, 8 - WeekDay(DocumentRefWeeklyTimesheet.DateFrom));
	
	QueryText = "";
	Counter = 0;
	QueryTextArray = New Array;
	
	For Each WeekDayRow In WeekDays Do
		
		Prefix = WeekDayRow.Prefix;
		
		QueryText = 
		"SELECT
		|	WeeklyTimesheetOperations.LineNumber AS LineNumber,
		|	DATEADD(WeeklyTimesheetOperations.Ref.DateFrom, DAY, &Counter) AS Period,
		|	CASE
		|		WHEN WeeklyTimesheetOperations.Customer REFS Catalog.Counterparties
		|			THEN WeeklyTimesheetOperations.Customer
		|		WHEN WeeklyTimesheetOperations.Customer REFS Catalog.CounterpartyContracts
		|			THEN WeeklyTimesheetOperations.Customer.Owner
		|		WHEN WeeklyTimesheetOperations.Customer REFS Document.SalesOrder
		|			THEN WeeklyTimesheetOperations.Customer.Counterparty
		|	END AS Counterparty,
		|	CASE
		|		WHEN WeeklyTimesheetOperations.Customer REFS Catalog.Counterparties
		|			THEN VALUE(Catalog.CounterpartyContracts.EmptyRef)
		|		WHEN WeeklyTimesheetOperations.Customer REFS Catalog.CounterpartyContracts
		|			THEN WeeklyTimesheetOperations.Customer
		|		WHEN WeeklyTimesheetOperations.Customer REFS Document.SalesOrder
		|			THEN WeeklyTimesheetOperations.Customer.Contract
		|	END AS Contract,
		|	CASE
		|		WHEN WeeklyTimesheetOperations.Customer REFS Catalog.Counterparties
		|				OR WeeklyTimesheetOperations.Customer REFS Catalog.CounterpartyContracts
		|			THEN VALUE(Document.SalesOrder.EmptyRef)
		|		WHEN WeeklyTimesheetOperations.Customer REFS Document.SalesOrder
		|			THEN WeeklyTimesheetOperations.Customer
		|	END AS SalesOrder,
		|	WeeklyTimesheetOperations.Ref.Employee AS Employee,
		|	WeeklyTimesheetOperations.Products AS Products,
		|	WeeklyTimesheetOperations.Characteristic AS Characteristic,
		|	WeeklyTimesheetOperations.WorkKind AS WorkKind,
		|	&DurationField AS ImportActual,
		|	&DurationField * WeeklyTimesheetOperations.Tariff AS AmountFact,
		|	WeeklyTimesheetOperations.Ref.StructuralUnit AS StructuralUnit,
		|	&Company AS Company,
		|	DATEADD(WeeklyTimesheetOperations.Ref.DateFrom, MINUTE, HOUR(&BeginTimeField) * 60 + MINUTE(&BeginTimeField) + 1440 * &Counter) AS BeginTime,
		|	DATEADD(WeeklyTimesheetOperations.Ref.DateFrom, MINUTE, HOUR(&EndTimeField) * 60 + MINUTE(&EndTimeField) + 1440 * &Counter) AS EndTime,
		|	WeeklyTimesheetOperations.Comment AS Comment
		|FROM
		|	Document.WeeklyTimesheet.Operations AS WeeklyTimesheetOperations
		|WHERE
		|	WeeklyTimesheetOperations.Ref = &Ref
		|	AND &DurationField > 0";
		
		BeginTimeField = StrTemplate("WeeklyTimesheetOperations.%1BeginTime", Prefix);
		EndTimeField = StrTemplate("WeeklyTimesheetOperations.%1EndTime", Prefix);
		DurationField = StrTemplate("WeeklyTimesheetOperations.%1Duration", Prefix);
		
		QueryText = StrReplace(QueryText, "&BeginTimeField", BeginTimeField);
		QueryText = StrReplace(QueryText, "&EndTimeField", EndTimeField);
		QueryText = StrReplace(QueryText, "&DurationField", DurationField);
		QueryText = StrReplace(QueryText, "&Counter", Counter);
		
		QueryTextArray.Add(QueryText);
		
		Counter = Counter + 1;
		
	EndDo;
	
	Query.Text = StrConcat(QueryTextArray, DriveClientServer.GetQueryUnion());
	
	Query.SetParameter("Ref", DocumentRefWeeklyTimesheet);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	
	Result = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableEmployeeTasks", Result.Unload());
	
EndProcedure

#EndRegion

#Region LibrariesHandlers

#Region PrintInterface

// Function checks if the document is posted and calls
// the procedure of document printing.
//
Function PrintForm(ObjectsArray, PrintObjects, PrintParams = Undefined)
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_WeeklyTimesheet";
	
	Query = New Query();
	Query.SetParameter("ObjectsArray", ObjectsArray);
	Query.Text = 
	"SELECT ALLOWED
	|	WeeklyTimesheet.Ref,
	|	WeeklyTimesheet.Date AS DocumentDate,
	|	WeeklyTimesheet.Company.DescriptionFull AS Company,
	|	WeeklyTimesheet.Number AS Number,
	|	WeeklyTimesheet.Company.Prefix AS Prefix,
	|	WeeklyTimesheet.StructuralUnit,
	|	WeeklyTimesheet.Employee,
	|	WeeklyTimesheet.Employee.Code AS TabNumber,
	|	WeeklyTimesheet.DateFrom,
	|	WeeklyTimesheet.DateTo,
	|	WeeklyTimesheet.Operations.(
	|		LineNumber AS LineNumber,
	|		Customer,
	|		CASE
	|			WHEN (CAST(WeeklyTimesheet.Operations.WorkKind.DescriptionFull AS String(1000))) = """"
	|				THEN WeeklyTimesheet.Operations.WorkKind.Description
	|			ELSE CAST(WeeklyTimesheet.Operations.WorkKind.DescriptionFull AS String(1000))
	|		END AS WorkKind,
	|		CASE
	|			WHEN (CAST(WeeklyTimesheet.Operations.Products.DescriptionFull AS String(1000))) = """"
	|				THEN WeeklyTimesheet.Operations.Products.Description
	|			ELSE CAST(WeeklyTimesheet.Operations.Products.DescriptionFull AS String(1000))
	|		END AS Products,
	|		Characteristic,
	|		Tariff,
	|		Total,
	|		Amount AS Amount,
	|		Comment,
	|		MoDuration AS Time1,
	|		TuDuration AS Time2,
	|		WeDuration AS Time3,
	|		ThDuration AS Time4,
	|		FrDuration AS Time5,
	|		SaDuration AS Time6,
	|		SuDuration AS Time7,
	|		MoBeginTime AS MoFrom,
	|		MoEndTime AS MoTo,
	|		TuBeginTime AS TuFrom,
	|		TuEndTime AS TuTo,
	|		WeEndTime AS WeTo,
	|		WeBeginTime AS WeFrom,
	|		ThBeginTime AS ThFrom,
	|		ThEndTime AS ThOn,
	|		FrBeginTime AS FrFr,
	|		FrEndTime AS FrTo,
	|		SaBeginTime AS SbS,
	|		SaEndTime AS SaTo,
	|		SuBeginTime AS VsS,
	|		SuEndTime AS SuOn,
	|		Products.SKU AS SKU
	|	)
	|FROM
	|	Document.WeeklyTimesheet AS WeeklyTimesheet
	|WHERE
	|	WeeklyTimesheet.Ref IN(&ObjectsArray)
	|
	|ORDER BY
	|	LineNumber";
	
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
	
	Header = Query.Execute().Select();
	
	FirstDocument = True;
	
	While Header.Next() Do
		
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		SpreadsheetDocument.PrintParametersName = "PARAMETERS_PRINT_Template_WeeklyTimesheet";
		
		If Header.DocumentDate < Date('20110101') Then
			DocumentNumber = DriveServer.GetNumberForPrinting(Header.Number, Header.Prefix);
		Else
			DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Header.Number, True, True);
		EndIf;
		
		Shift = 8 - WeekDay(Header.DateFrom);
		
		Template = PrintManagement.PrintFormTemplate("Document.WeeklyTimesheet.PF_MXL_Template", LanguageCode);
		TemplateArea = Template.GetArea("Title");
		TemplateArea.Parameters.HeaderText = "Time tracking No "
												+ DocumentNumber
												+ " from "
												+ Format(Header.DocumentDate, "DLF=DD");
		
		SpreadsheetDocument.Put(TemplateArea);
		
		TemplateArea = Template.GetArea("Employee");
		TemplateArea.Parameters.Fill(Header);
		TemplateArea.Parameters.DateFrom = Format(Header.DateFrom, "DF=dd.MM.yy");
		TemplateArea.Parameters.DateTo = Format(Header.DateTo, "DF=dd.MM.yy");
		SpreadsheetDocument.Put(TemplateArea);
		
		LinesSelectionOperations = Header.Operations.Select();
		
		TemplateArea = Template.GetArea("TableHeader");
		
		TemplateArea.Parameters.Mo = Format(Header.DateFrom, "DF=dd.MM");
		TemplateArea.Parameters.Tu = Format(Header.DateFrom + 86400, "DF=dd.MM");
		TemplateArea.Parameters.We = Format(Header.DateFrom + 86400*2, "DF=dd.MM");
		TemplateArea.Parameters.Th = Format(Header.DateFrom + 86400*3, "DF=dd.MM");
		TemplateArea.Parameters.Fr = Format(Header.DateFrom + 86400*4, "DF=dd.MM");
		TemplateArea.Parameters.Sa = Format(Header.DateFrom + 86400*5, "DF=dd.MM");
		TemplateArea.Parameters.Su = Format(Header.DateFrom + 86400*6, "DF=dd.MM");
		
		TemplateArea.Parameters.Header1 = Format(Header.DateFrom, "DF=ddd");
		TemplateArea.Parameters.Header2 = Format(Header.DateFrom + 86400, "DF=ddd");
		TemplateArea.Parameters.Header3 = Format(Header.DateFrom + 86400 * 2, "DF=ddd");
		TemplateArea.Parameters.Header4 = Format(Header.DateFrom + 86400 * 3, "DF=ddd");
		TemplateArea.Parameters.Header5 = Format(Header.DateFrom + 86400 * 4, "DF=ddd");
		TemplateArea.Parameters.Header6 = Format(Header.DateFrom + 86400 * 5, "DF=ddd");
		TemplateArea.Parameters.Header7 = Format(Header.DateFrom + 86400 * 6, "DF=ddd");
		
		SpreadsheetDocument.Put(TemplateArea);
		
		TemplateArea = Template.GetArea("String");
		
		Amount   = 0;
		TotalAmount   = 0;
		
		While LinesSelectionOperations.Next() Do
			
			TemplateArea.Parameters.Fill(LinesSelectionOperations);
			
			If ValueIsFilled(LinesSelectionOperations.MoFrom) OR ValueIsFilled(LinesSelectionOperations.MoTo) Then
				TemplateArea.Parameters.Period1 = Format(LinesSelectionOperations.MoFrom, "DF=H:mm; DE=0:00") + "-" + Format(LinesSelectionOperations.MoTo, "DF=H:mm; DE=0:00");
			Else
				TemplateArea.Parameters.Period1 = "";
			EndIf;
			If ValueIsFilled(LinesSelectionOperations.TuFrom) OR ValueIsFilled(LinesSelectionOperations.TuTo) Then
				TemplateArea.Parameters.Period2 = Format(LinesSelectionOperations.TuFrom, "DF=H:mm; DE=0:00") + "-" + Format(LinesSelectionOperations.TuTo, "DF=H:mm; DE=0:00");
			Else
				TemplateArea.Parameters.Period2 = "";
			EndIf;
			If ValueIsFilled(LinesSelectionOperations.WeFrom) OR ValueIsFilled(LinesSelectionOperations.WeTo) Then
				TemplateArea.Parameters.Period3 = Format(LinesSelectionOperations.WeFrom, "DF=H:mm; DE=0:00") + "-" + Format(LinesSelectionOperations.WeTo, "DF=H:mm; DE=0:00");
			Else
				TemplateArea.Parameters.Period3 = "";
			EndIf;
			If ValueIsFilled(LinesSelectionOperations.ThFrom) OR ValueIsFilled(LinesSelectionOperations.ThOn) Then
				TemplateArea.Parameters.Period4 = Format(LinesSelectionOperations.ThFrom, "DF=H:mm; DE=0:00") + "-" + Format(LinesSelectionOperations.ThOn, "DF=H:mm; DE=0:00");
			Else	
				TemplateArea.Parameters.Period4 = "";
			EndIf;
			If ValueIsFilled(LinesSelectionOperations.FrFr) OR ValueIsFilled(LinesSelectionOperations.FrTo) Then
				TemplateArea.Parameters.Period5 = Format(LinesSelectionOperations.FrFr, "DF=H:mm; DE=0:00") + "-" + Format(LinesSelectionOperations.FrTo, "DF=H:mm; DE=0:00");
			Else	
				TemplateArea.Parameters.Period5 = "";
			EndIf;
			If ValueIsFilled(LinesSelectionOperations.SbS) OR ValueIsFilled(LinesSelectionOperations.SaTo) Then
				TemplateArea.Parameters.Period6 = Format(LinesSelectionOperations.SbS, "DF=H:mm; DE=0:00") + "-" + Format(LinesSelectionOperations.SaTo, "DF=H:mm; DE=0:00");
			Else	
				TemplateArea.Parameters.Period6 = "";
			EndIf;
			If ValueIsFilled(LinesSelectionOperations.VsS) OR ValueIsFilled(LinesSelectionOperations.SuOn) Then
				TemplateArea.Parameters.Period7 = Format(LinesSelectionOperations.VsS, "DF=H:mm; DE=0:00") + "-" + Format(LinesSelectionOperations.SuOn, "DF=H:mm; DE=0:00");
			Else	
				TemplateArea.Parameters.Period7 = "";
			EndIf;
			
			TemplateArea.Parameters.WorkPresentation = DriveServer.GetProductsPresentationForPrinting(LinesSelectionOperations.Products, 
				LinesSelectionOperations.Characteristic, LinesSelectionOperations.SKU);
			
			CircleShiftCellsContent(TemplateArea.Parameters, "Time", Shift);
			CircleShiftCellsContent(TemplateArea.Parameters, "Period", Shift);
			SpreadsheetDocument.Put(TemplateArea);
			
			Amount = Amount + LinesSelectionOperations.Amount;
			TotalAmount = TotalAmount + LinesSelectionOperations.Total;
		EndDo;
		
		TemplateArea = Template.GetArea("Total");
		TemplateArea.Parameters.Total = TotalAmount;
		TemplateArea.Parameters.Amount = DriveServer.AmountsFormat(Amount);
		SpreadsheetDocument.Put(TemplateArea);
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, Header.Ref);
	EndDo;
	
	SpreadsheetDocument.PageOrientation = PageOrientation.Landscape;
	SpreadsheetDocument.FitToPage = True;
	
	Return SpreadsheetDocument;
	
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
	
	If PrintManagement.TemplatePrintRequired(PrintFormsCollection, "WeeklyTimesheet") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(
			PrintFormsCollection,
			"WeeklyTimesheet",
			NStr("en = 'Time tracking'; ru = 'Отслеживание времени';pl = 'Śledzenie czasu';es_ES = 'Seguimiento del tiempo';es_CO = 'Seguimiento del tiempo';tr = 'Zaman takibi';it = 'Tracciamento tempo';de = 'Zeiterfassung'"),
			PrintForm(ObjectsArray, PrintObjects, PrintParameters.Result));
		
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
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "WeeklyTimesheet";
	PrintCommand.Presentation = NStr("en = 'Weekly timesheet'; ru = 'Учет времени';pl = 'Tygodniowy arkusz czasu pracy';es_ES = 'Hoja de tiempo semanal';es_CO = 'Hoja de tiempo semanal';tr = 'Haftalık zaman çizelgesi';it = 'Timesheet settimanale';de = 'Wöchentliche Zeiterfassung'");
	PrintCommand.FormsList = "DocumentForm,ListForm";
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

#Region Private

Procedure CircleShiftCellsContent(TemplateParameters, FieldName, Shift, Val StartIndex = 1, Val EndIndex = 7)
	
	ParametersTable = New ValueTable;
	ParametersTable.Columns.Add("Content");
	
	While StartIndex <= EndIndex Do
		
		Row = ParametersTable.Add();
		Row.Content = TemplateParameters[StrTemplate("%1%2", FieldName, StartIndex)];
		StartIndex = StartIndex + 1;
		
	EndDo;
	
	DriveServer.CircleShiftCollection(ParametersTable, Shift);
	StartIndex = 1;
	
	While StartIndex <= EndIndex Do
		
		TemplateParameters[StrTemplate("%1%2", FieldName, StartIndex)] = ParametersTable[StartIndex - 1].Content;
		StartIndex = StartIndex + 1;
		
	EndDo;
	
EndProcedure

#EndRegion

#EndIf