
#Region Public

// Calculate and fill the cost layers records in the "InventoryCostLayer" register.
// It used for calculate costs in the month-end closing document.
//
// Parameters:
//	EndOfCalculationPeriod - Date - End of calculation period.
//	Company - Catalog.Companies, Undefined - Company for calculation.
//
Procedure CalculateAll(Val EndOfCalculationPeriod, Company = Undefined) Export
	
	SetPrivilegedMode(True);
	
	InformationLevel = EventLogLevel.Information;
	FormatOfPeriod = "DLF=D";
	LanguageCode = CommonClientServer.DefaultLanguageCode();
	ConstantName = ConstantName();
	
	OldTaskNumber = InformationRegisters.TasksForCostsCalculation.IncreaseTaskNumber();
	
	BeginTransaction();
	
	Try
		InformationRegisters.TasksForCostsCalculation.LockRegister(OldTaskNumber);
		
		CalculationScheme = CalculationScheme(
			EndOfCalculationPeriod,
			Company,
			Undefined,
			OldTaskNumber);
			
		If CalculationScheme.Count() > 0 Then
			TempTableOfTasks = GetTempTableOfTasksBeforeCalculation(
				OldTaskNumber,
				CalculationScheme[CalculationScheme.Count() - 1].Companies);
		EndIf;
			
		CommitTransaction();
		
	Except
		RollbackTransaction();
		ErrorText = DetailErrorDescription(ErrorInfo());
		Raise ErrorText;
	EndTry;
	
	If CalculationScheme.Count() > 0 Then
		NeedCalculation = (BegOfMonth(CalculationScheme[0].Date) <= BegOfMonth(EndOfCalculationPeriod));
		FinishSchemeLines = New Array;
	Else
		NeedCalculation = False;
	EndIf;
	
	If NeedCalculation Then
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Running FIFO calculation to %1'; ru = 'Запуск расчета FIFO на %1';pl = 'Uruchamianie obliczeń FIFO do %1';es_ES = 'Lanzando el cálculo FIFO para %1';es_CO = 'Lanzando el cálculo FIFO para %1';tr = 'FIFO hesaplamasını %1 '' ye çalıştırma';it = 'Calcolo FIFO in esecuzione %1';de = 'Laufende FIFO-Berechnung auf %1'"),
			Format(EndOfCalculationPeriod, FormatOfPeriod));
			
		WriteLogEvent(
			NStr("en = 'FIFO.Beginning'; ru = 'FIFO.Начало';pl = 'FIFO.Początek';es_ES = 'FIFO.Inicio';es_CO = 'FIFO.Inicio';tr = 'FIFO. Başlıyor';it = 'FIFO.Inizio';de = 'FIFO.Anfang'", LanguageCode),
			InformationLevel,
			EndOfCalculationPeriod,
			MessageText);
			
			For Each CalculationSchemeLine In CalculationScheme Do
				
				BeginOfPeriod    = BegOfMonth(CalculationSchemeLine.Date);
				EndOfOfPeriod    = EndOfMonth(CalculationSchemeLine.Date);
				ArrayOfCompanies = CalculationSchemeLine.Companies;
				
				CalculateInventoryCosts(BeginOfPeriod, EndOfOfPeriod, ArrayOfCompanies);
				
				CalculateLandedCosts(BeginOfPeriod, EndOfOfPeriod, ArrayOfCompanies);
				
				MoveBoundaryToNextPeriod(BeginOfPeriod, ArrayOfCompanies, OldTaskNumber, TempTableOfTasks);
				
			EndDo;
		
	EndIf;
	
EndProcedure

Procedure ExecuteScheduledJob() Export
	
	SetPrivilegedMode(True);
	
	EndOfCalculationPeriod = EndOfYear(CurrentSessionDate()) + 1;
	ArrayOfCompanies = Catalogs.Companies.AllCompanies();
	
	CalculateAll(EndOfCalculationPeriod, ArrayOfCompanies);
	
EndProcedure

#Region Posting

Procedure ReflectTasks(Document, AdditionalProperties) Export
	
	If ExchangePlans.MasterNode() <> Undefined Then // Records are creating only in the master node.
		Return;
	EndIf;
	
	ControlRegisterCollection = ControlRegisterCollection();
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	TempTables = StructureTemporaryTables.TempTablesManager;
	
	QueryTemplate = 
	"SELECT DISTINCT
	|	Table.Month AS Month,
	|	Table.Company AS Company,
	|	Table.Document AS Document
	|FROM
	|	&DataCollection AS Table
	|";
	
	NestedQueryText = "";
	DropTableText = "; ";
	
	For Each ControlRegister In ControlRegisterCollection Do
		AddTaskTableInQueryText(ControlRegister, TempTables.Tables, QueryTemplate, NestedQueryText, DropTableText);
	EndDo;
	
	If ValueIsFilled(NestedQueryText) Then 
		QueryText = StrReplace(QueryTemplate, "&DataCollection", "(" + NestedQueryText + ")")
			+ DropTableText;
			
		Query = New Query(QueryText);
		Query.TempTablesManager = TempTables;
		
		Result = Query.Execute();
		If Result.IsEmpty() Then
			Return; // no tasks
		EndIf;
		
		Selection = Result.Select();
		While Selection.Next() Do
			InformationRegisters.TasksForCostsCalculation.CreateRegisterRecord(
				Selection.Month,
				Selection.Company,
				Selection.Document);
		EndDo;
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion

#Region Private

#Region WorkWithTasks

Function GetTempTableOfTasksBeforeCalculation(OldTaskNumber, Companies)
	Return InformationRegisters.TasksForCostsCalculation.GetTempTableOfTasks(OldTaskNumber, Companies);
EndFunction

Procedure MoveBoundaryToNextPeriod(BeginOfPeriod, ArrayOfCompanies, OldTaskNumber, TempTables)
	
	BeginTransaction();
	
	Try
		InformationRegisters.TasksForCostsCalculation.LockRegister(OldTaskNumber);
		InformationRegisters.TasksForCostsCalculation.MoveBoundaryToNextPeriod(BeginOfPeriod, ArrayOfCompanies, TempTables);
		CommitTransaction();
	Except
		RollbackTransaction();
		ErrorText = DetailErrorDescription(ErrorInfo());
		Raise ErrorText;
	EndTry;
	
EndProcedure

Function ConstantName()
	Return "CostCalculationTaskNumber";
EndFunction

Function ControlRegisterCollection()
	
	Collection = New Array;
	Collection.Add("Inventory");
	Collection.Add("LandedCosts");
	
	Return Collection;
EndFunction

Procedure AddTaskTableInQueryText(RegisterName, Tables, QueryTemplate, QueryText, DropTableText)
	TableName = RegisterName + "Tasks";
	If Tables.Find(TableName) <> Undefined Then
		If ValueIsFilled(QueryText) Then
			QueryText = QueryText + "
			|
			|UNION ALL
			|"
		EndIf;
		QueryText = QueryText + StrReplace(QueryTemplate, "&DataCollection", TableName);
		DropTableText = DropTableText + "DROP " + TableName + "; ";
	EndIf;
EndProcedure

#EndRegion

#Region CalculationScheme

Function EmptyCalculationScheme()
	
	CalculationScheme = New ValueTable;
	
	CalculationScheme.Columns.Add("Date", New TypeDescription("Date"));
	CalculationScheme.Columns.Add("Companies", New TypeDescription("Array"));
	CalculationScheme.Columns.Add("CompaniesPresentation", New TypeDescription("String"));
	CalculationScheme.Columns.Add("ChangedDocumentsCount", New TypeDescription("Number"));
	
	CalculationScheme.Indexes.Add("Date");
	
	Return CalculationScheme;
	
EndFunction

Function CalculationScheme(Val Date = Undefined, CompanyFilter = Undefined, Delimeter = Undefined, TaskNumber = 0)
	
	Date = EndOfMonth(?(Not ValueIsFilled(Date), CurrentSessionDate(), Date));
	ArrayOfCompanies = DriveClientServer.ArrayFromItem(CompanyFilter);
	
	CalculationScheme = EmptyCalculationScheme();
	
	CompaniesCalculationDates = New Map;
	FirstCalculationDate = EndOfMonth(EndOfMonth(Date) + 1);
	
	NeedCalculation = False;
	
	Query = New Query(
	"SELECT ALLOWED
	|	Tasks.Company AS Company,
	|	MIN(ENDOFPERIOD(Tasks.Month, MONTH)) AS Month
	|FROM
	|	InformationRegister.TasksForCostsCalculation AS Tasks
	|	INNER JOIN Catalog.Companies AS Companies
	|		ON Tasks.Company = Companies.Ref
	|WHERE
	|	BEGINOFPERIOD(Tasks.Month, MONTH) <= &Date
	|	AND (Tasks.TaskNumber <= &TaskNumber OR &UseAllNumbers)
	|	AND NOT Tasks.Company.DeletionMark
	|
	|GROUP BY
	|	Tasks.Company");
	
	Query.SetParameter("Date", Date);
	Query.SetParameter("TaskNumber", TaskNumber);
	Query.SetParameter("UseAllNumbers", TaskNumber = 0);
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		If ArrayOfCompanies.Find(Selection.Company) <> Undefined Then
			NeedCalculation = True;
		EndIf;
			
		CompaniesCalculationDates.Insert(Selection.Company, Selection.Month);
		FirstCalculationDate = Min(FirstCalculationDate, Selection.Month);
		
	EndDo;
	
	Query.Text = 
	"SELECT ALLOWED
	|	ENDOFPERIOD(Tasks.Month, MONTH) AS Month,
	|	Tasks.Company AS Company,
	|	COUNT(DISTINCT Tasks.Document) AS ChangedDocumentsCount
	|FROM
	|	InformationRegister.TasksForCostsCalculation AS Tasks
	|WHERE
	|	Tasks.Document <> UNDEFINED
	|	AND BEGINOFPERIOD(Tasks.Month, MONTH) <= &Date
	|	AND (Tasks.TaskNumber <= &TaskNumber
	|			OR &UseAllNumbers)
	|	AND NOT Tasks.Company.DeletionMark
	|
	|GROUP BY
	|	ENDOFPERIOD(Tasks.Month, MONTH),
	|	Tasks.Company
	|
	|ORDER BY
	|	Month,
	|	Company";
	
	ChangedDocuments = Query.Execute().Unload();
	ChangedDocuments.Indexes.Add("Month, Company");
	
	CurrentDate = FirstCalculationDate;
	While CurrentDate <= Date Do // fill in lines in the calculation scheme from the earliest to the end of calculation period
		
		AddLineIntoCalculationScheme(
			CalculationScheme,
			CurrentDate,
			?(CurrentDate = Date, ArrayOfCompanies, New Array));
			
		CurrentDate = EndOfMonth(EndOfMonth(CurrentDate) + 1);
		
	EndDo;
		
	// fill in companies in the calculation scheme
	CurrentDate = Max(FirstCalculationDate, Date);
	While CurrentDate <= Date Do
		
		CurrentLine = CalculationScheme.Find(CurrentDate, "Date");
		PreviousLine = CalculationScheme.Find(BegOfMonth(CurrentDate) - 1, "Date");
		
		If PreviousLine <> Undefined Then
			
			ChangesInArrayOfCompanies = False;
			
			// Add companies which was changed in earlier period. It is will be calculation and in current period too.
			For Each PreviousCompany In PreviousLine.Companies Do
				If DriveClientServer.AddNewValueInArray(CurrentLine.Companies, PreviousCompany) Then
					ChangesInArrayOfCompanies = True;
				EndIf;
			EndDo;
			
		EndIf;
		
		ChangedCurrentDate = CurrentDate;
		
		For Each CurrentCompany In CurrentLine.Companies Do
			
			CompanyCalculationDate = CompaniesCalculationDates[CurrentCompany];
			
			If ValueIsFilled(CompanyCalculationDate) And CompanyCalculationDate < CurrentDate Then
				
				CompanyLine = CalculationScheme.Find(CompanyCalculationDate, "Date");
				If DriveClientServer.AddNewValueInArray(CompanyLine.Companies, CurrentCompany) Then
					ChangedCurrentDate = Min(ChangedCurrentDate, CompanyCalculationDate);
				EndIf;
				
			EndIf;
			
		EndDo;
		
		If ChangedCurrentDate < CurrentDate Then
			CurrentDate = ChangedCurrentDate;
		Else
			CurrentDate = EndOfMonth(EndOfMonth(CurrentDate) + 1);
		EndIf;
		
	EndDo;
	
	While CalculationScheme.Count() > 0 And CalculationScheme[0].Companies.Count() = 0 Do
		// The erlier periods without companies will be deleted
		CalculationScheme.Delete(0);
	EndDo;
	
	If CalculationScheme.Count() > 0 And ValueIsFilled(ArrayOfCompanies) Then
		
		IntersecrionOfArrays = DriveClientServer.IntersecrionOfArrays(
			ArrayOfCompanies,
			CalculationScheme[CalculationScheme.Count() - 1].Companies);
			
		If IntersecrionOfArrays.Count() = ArrayOfCompanies.Count() 
			And Not NeedCalculation Then
			CalculationScheme.Clear();
		EndIf;
		
	EndIf;
		
	CompaniesList = New ValueList;
	
	For Each CurrentLine In CalculationScheme Do
		
		CompaniesList.LoadValues(CurrentLine.Companies);
		CompaniesList.SortByValue();
		
		CurrentLine.Companies             = CompaniesList.UnloadValues();
		CurrentLine.CompaniesPresentation = CompaniesPresentation(CurrentLine.Companies, Delimeter);
		CurrentLine.ChangedDocumentsCount = 0;
		
		For Each CurrentCompany In CurrentLine.Companies Do
			
			DocumentsLines = ChangedDocuments.FindRows(
				New Structure("Month, Company", CurrentLine.Date, CurrentCompany));
				
			If DocumentsLines.Count() = 1 Then
				CurrentLine.ChangedDocumentsCount = CurrentLine.ChangedDocumentsCount + DocumentsLines[0].ChangedDocumentsCount;
			EndIf;
			
		EndDo;
		
	EndDo;
	
	Return CalculationScheme;
	
EndFunction

Procedure AddLineIntoCalculationScheme(CalculationScheme, Date, ArrayOfCompanies, FillPresentation = False)
	
	NewLine = CalculationScheme.Add();
	NewLine.Date = EndOfMonth(Date);
	NewLine.Companies = CommonClientServer.CopyArray(ArrayOfCompanies);
	
	If FillPresentation Then
		NewLine.CompaniesPresentation = CompaniesPresentation(NewLine.Companies);
	EndIf;
	
EndProcedure

#EndRegion

#Region InventoryCosts

Procedure CalculateInventoryCosts(BeginOfPeriod, EndOfOfPeriod, ArrayOfCompanies)
	
	RegisterName = Metadata.AccumulationRegisters.InventoryCostLayer.Name;
	
	StartAt = CurrentUniversalDateInMilliseconds();
	
	DataForInventoryCosts = DataForInventoryCosts(BeginOfPeriod, EndOfOfPeriod, ArrayOfCompanies);
	
	ArrayOfExcludedTypes = New Array;
	ArrayOfExcludedTypes.Add(Type("DocumentRef.RegistersCorrection"));
	
	Recorders = Recorders(BeginOfPeriod, EndOfOfPeriod, ArrayOfCompanies, RegisterName, ArrayOfExcludedTypes);
	
	CostsLayers = CalculateInventoryCostsLayers(DataForInventoryCosts, Recorders);
	
	WriteCostsLayers(AccumulationRegisters[RegisterName], CostsLayers, Recorders);
	ClearRegister(Recorders, RegisterName);
	
	DataForInventoryCosts.Close();
	CostsLayers = Undefined;
	
EndProcedure

Function CalculateInventoryCostsLayers(DataForInventoryCosts, Recorders, RecordsChains = Undefined)
	
	Query = New Query(TextOfDescriptionInventoryCosts());
	CostsLayers = Query.Execute().Unload();
	
	TypesOfChains = DescriptionOfChains("Balance, CostLayer, Consumption, Reversal, Transfer,
		|PreviousPeriods, ConsumerMaterials, IntraTransfer, ConsumptionIntraTransfer, Production, WIP, KitProcessing");
	
	ConsumptionFields = "Company, PresentationCurrency, StructuralUnit, InventoryAccountType, Products,
		|Characteristic, Batch, Ownership, CostObject";
	
	RecordsContext = New Structure();
	RecordsContext.Insert("Context",           "InventoryCostLayer");
	RecordsContext.Insert("RegisterName",      "InventoryCostLayer");
	RecordsContext.Insert("CalculationFields",  ListOfFields(CostsLayers.Columns));
	RecordsContext.Insert("ConsumptionFields",  ConsumptionFields);
	RecordsContext.Insert("Indicators",        "Denominator, Quantity, Amount");
	RecordsContext.Insert("ReceiptField",      "Quantity");
	RecordsContext.Insert("ExpenseField",      "Quantity");
	RecordsContext.Insert("ExpenseKey",        "SourceDocument");
	RecordsContext.Insert("OrderField",        "Period");
	RecordsContext.Insert("SortField",         "CostLayer");
	RecordsContext.Insert("UseSort",            True);
	RecordsContext.Insert("SumFields",          "Denominator, Quantity, Amount");
	RecordsContext.Insert("GroupingFields",     ListOfFields(CostsLayers.Columns, RecordsContext.SumFields));
	
	AddReceiptDescription(TypesOfChains, "Consumption", ConsumptionFields);
	AddSourceDescription(TypesOfChains,  "Consumption", "Balance", ConsumptionFields);
	AddSourceDescription(TypesOfChains,  "Consumption", "CostLayer", ConsumptionFields);
	AddSourceDescription(TypesOfChains,  "Consumption", "Transfer", ConsumptionFields);
	AddSourceDescription(TypesOfChains,  "Consumption", "Reversal", ConsumptionFields);
	AddSourceDescription(TypesOfChains,  "Consumption", "IntraTransfer", ConsumptionFields);
	AddSourceDescription(TypesOfChains,  "Consumption", "KitProcessing", ConsumptionFields);
	AddSourceDescription(TypesOfChains,  "Consumption", "WIP", ConsumptionFields);
	AddSourceDescription(TypesOfChains,  "Consumption", "Production", ConsumptionFields);
	
	AddReceiptDescription(TypesOfChains, "Transfer", "SourceDocument, Company, PresentationCurrency, StructuralUnit,
		|InventoryAccountType, Products, Characteristic, Batch, Ownership");
	AddSourceDescription(TypesOfChains, "Transfer", "Consumption", "Recorder, Company, PresentationCurrency, CorrStructuralUnit,
		|CorrInventoryAccountType, Products, Characteristic, Batch, Ownership");
	
	AddReceiptDescription(TypesOfChains, "Reversal", "SourceDocument, Company, PresentationCurrency,
		|InventoryAccountType, Products, Characteristic, Batch, Ownership");
	AddSourceDescription(TypesOfChains,  "Reversal", "Consumption", "SourceDocument, Company, PresentationCurrency,
		|InventoryAccountType,, Products, Characteristic, Batch, Ownership");
	AddSourceDescription(TypesOfChains,  "Reversal", "PreviousPeriods", "SourceDocument, Company, PresentationCurrency,
		|InventoryAccountType, Products, Characteristic, Batch, Ownership");
	
	AddReceiptDescription(TypesOfChains, "ConsumerMaterials", "Recorder, Company, PresentationCurrency, StructuralUnit,
		|InventoryAccountType, Products, Characteristic, Batch, Ownership");
	AddSourceDescription(TypesOfChains, "ConsumerMaterials", "Consumption", "Recorder, Company, PresentationCurrency, StructuralUnit,
		|InventoryAccountType, Products, Characteristic, Batch, Ownership");
		
	AddReceiptDescription(TypesOfChains, "ConsumptionIntraTransfer", "SourceDocument, Company, PresentationCurrency, StructuralUnit,
		|InventoryAccountType, Products, Characteristic, Batch, Ownership");
	AddSourceDescription(TypesOfChains, "ConsumptionIntraTransfer", "Transfer", "Recorder, Company, PresentationCurrency, StructuralUnit,
		|InventoryAccountType, Products, Characteristic, Batch, Ownership");
	AddSourceDescription(TypesOfChains, "ConsumptionIntraTransfer", "PreviousPeriods", "SourceDocument, Company, PresentationCurrency, StructuralUnit,
		|InventoryAccountType, Products, Characteristic, Batch, Ownership");
	
	AddReceiptDescription(TypesOfChains, "IntraTransfer", "SourceDocument, Company, PresentationCurrency, CorrStructuralUnit,
		|CorrInventoryAccountType, Products, Characteristic, Batch, Ownership");
	AddSourceDescription(TypesOfChains, "IntraTransfer", "ConsumptionIntraTransfer", "Recorder, Company, PresentationCurrency, StructuralUnit,
		|InventoryAccountType, Products, Characteristic, Batch, Ownership");
	
	// Component income to WIP account
	AddReceiptDescription(TypesOfChains, "WIP", "SourceDocument, Company, PresentationCurrency, StructuralUnit,
		|InventoryAccountType, Products, Characteristic, Ownership, CostObject");
	// Component expence from Inventry account
	AddSourceDescription(TypesOfChains, "WIP", "Consumption", "Recorder, Company, PresentationCurrency, CorrStructuralUnit,
		|CorrInventoryAccountType, Products, Characteristic, Ownership, CorrCostObject");
	
	// Finished product income to Inventry account
	AddReceiptDescription(TypesOfChains, "Production", "SourceDocument, Company, PresentationCurrency, StructuralUnit,
		|InventoryAccountType, Products, Characteristic, Batch, Ownership");
	// Component expence from WIP account
	AddSourceDescription(TypesOfChains, "Production", "Consumption", "Recorder, Company, PresentationCurrency, CorrStructuralUnit,
		|CorrInventoryAccountType, CorrProducts, CorrCharacteristic, CorrBatch, CorrOwnership");
	
	AddReceiptDescription(TypesOfChains, "KitProcessing", "SourceDocument, Company, PresentationCurrency, StructuralUnit,
		|InventoryAccountType, Products, Characteristic, Batch, Ownership");
	AddSourceDescription(TypesOfChains, "KitProcessing", "Consumption", "Recorder, Company, PresentationCurrency, CorrStructuralUnit,
		|CorrInventoryAccountType, CorrProducts, CorrCharacteristic, CorrBatch, CorrOwnership");
	
	GetChains(TypesOfChains, DataForInventoryCosts);
	CalculateCostsLayersByChains(RecordsContext, DataForInventoryCosts, CostsLayers, Recorders);
	RecordsChains = DataForInventoryCosts;
	
	DeleteUnrecordedLines(RecordsContext.Context, CostsLayers);
	
	CostsLayers.Sort("Recorder, Priority", New CompareValues);
	
	Return CostsLayers;
EndFunction

Procedure FillInventoryCostLayer(CostLayer, Expense, Receipt)
	
	FillPropertyValues(CostLayer, Expense);
	
	If CostLayer.RecordKind = "KitProcessing"
		Or CostLayer.RecordKind = "Production"
		Or CostLayer.RecordKind = "Subcontracting" Then
		
		CostLayer.CostLayer = Receipt.SourceDocument;
		
		CostLayer.Amount = Receipt.Amount;
		CostLayer.Quantity = 0;
		
		Receipt.Amount = 0;
		Receipt.Quantity = 0;
		
		If Not ValueIsFilled(CostLayer.SourceDocument) Then
			CostLayer.SourceDocument = Receipt.Recorder;
		EndIf;
		
		CostLayer.FinishCalculation = Receipt.FinishCalculation;
		
	Else
		
		If Expense.RecordKind = "Material" And Receipt.Quantity <= Expense.Denominator Then
			Receipt.Denominator = ?(Receipt.Denominator = 0, Receipt.Quantity, Receipt.Denominator);
			ExpenseQuantity = Receipt.Denominator / Expense.Denominator * Expense.Quantity;
			CostLayer.Denominator = Receipt.Denominator;
			Expense.Denominator = Expense.Denominator - Receipt.Denominator;
		Else
			Receipt.Denominator = 0;
			ExpenseQuantity = Min(Expense.Quantity, Receipt.Quantity);
		EndIf;
		
		If Receipt.Quantity = 0 And (
			TypeOf(Receipt.CostLayer) = Type("DocumentRef.Production")
			// begin Drive.FullVersion
			Or TypeOf(Receipt.CostLayer) = Type("DocumentRef.Manufacturing")
			// end Drive.FullVersion
			Or TypeOf(Receipt.CostLayer) = Type("DocumentRef.SubcontractorOrderIssued")
			)
		Then
			
			CostLayer.Amount = Receipt.Amount;
			CostLayer.Quantity = 0;
			
			Receipt.Amount = 0;
			
		Else
			
			ExpenseBasis = ?(Expense.Quantity <> 0, ExpenseQuantity / Expense.Quantity, 0);
			ReceiptBasis = ?(Receipt.Quantity <> 0, ExpenseQuantity / Receipt.Quantity, 0);
			
			CostLayer.Amount = Round(ReceiptBasis * Receipt.Amount, 2);
			CostLayer.Quantity = Round(ExpenseQuantity, 3);
			
			Expense.Amount = Expense.Amount - Round(ExpenseBasis + Expense.Amount, 2);
			Receipt.Amount = Receipt.Amount - CostLayer.Amount;
			
			Expense.Quantity = Expense.Quantity - CostLayer.Quantity;
			Receipt.Quantity = Receipt.Quantity - CostLayer.Quantity;
			
		EndIf;
	
		If Not ValueIsFilled(CostLayer.CostLayer) Or CostLayer.RecordKind = "Consumption" Then
			CostLayer.CostLayer = Receipt.CostLayer;
		EndIf;
		
		If CostLayer.RecordKind = "Reversal" Then
			CostLayer.SourceDocument = Receipt.SourceDocument;
		EndIf;
		
		If Not ValueIsFilled(CostLayer.SourceDocument) Then
			CostLayer.SourceDocument = Receipt.Recorder;
		EndIf;
		
		CostLayer.FinishCalculation = Receipt.FinishCalculation;
		
	EndIf;
	
EndProcedure

Procedure FillLandedCostLayer(CostLayer, Expense, Receipt)
	
	FillPropertyValues(CostLayer, Expense);
	
	If TypeOf(Receipt.CostLayer) = Type("DocumentRef.SubcontractorOrderIssued") Then
		Receipt.Quantity = Receipt.TotalQuantity;
	EndIf;
	
	If Expense.RecordKind = "Material" And Receipt.Quantity <= Expense.Denominator Then
		Receipt.Denominator = ?(Receipt.Denominator = 0, Receipt.Quantity, Receipt.Denominator);
		ExpenseQuantity = Receipt.Denominator / Expense.Denominator * Expense.Quantity;
		CostLayer.Denominator = Receipt.Denominator;
		Expense.Denominator = Expense.Denominator - Receipt.Denominator;
	Else
		Receipt.Denominator = 0;
		ExpenseQuantity = Min(Expense.Quantity, Receipt.Quantity);
	EndIf;
	
	If CostLayer.RecordKind = "KitProcessing"
		Or CostLayer.RecordKind = "Production"
		Or CostLayer.RecordKind = "Subcontracting" Then
		
		CostLayer.Amount = Receipt.Amount;
		Receipt.Amount = 0;
		Receipt.Quantity = 0;
		
	Else
		
		ExpenseBasis = ?(Expense.Quantity <> 0, ExpenseQuantity / Expense.Quantity, 0);
		ReceiptBasis = ?(Receipt.Quantity <> 0, ExpenseQuantity / Receipt.Quantity, 0);
		
		CostLayer.Amount = Round(ReceiptBasis * Receipt.Amount, 2);
		CostLayer.Quantity = Round(ExpenseQuantity, 3);
		
		Expense.Amount = Expense.Amount - Round(ExpenseBasis + Expense.Amount, 2);
		Receipt.Amount = Receipt.Amount - CostLayer.Amount;
		
		If TypeOf(Receipt.CostLayer) <> Type("DocumentRef.SubcontractorOrderIssued") Then
			Expense.TotalQuantity = Expense.TotalQuantity - CostLayer.Quantity;
		EndIf;
		Receipt.Quantity = Receipt.Quantity - CostLayer.Quantity;
		
	EndIf;
	
	If Not ValueIsFilled(CostLayer.CostLayer) Or CostLayer.RecordKind = "Consumption" Then
		CostLayer.CostLayer = Receipt.CostLayer;
	EndIf;
	If CostLayer.RecordKind = "Reversal" Then
		CostLayer.SourceDocument = Receipt.SourceDocument;
	EndIf;
	If Not ValueIsFilled(CostLayer.SourceDocument) Then
		CostLayer.SourceDocument = Receipt.Recorder;
	EndIf;
	
	CostLayer.FinishCalculation = Receipt.FinishCalculation;
	
EndProcedure

Function DataForInventoryCosts(BeginOfPeriod, EndOfOfPeriod, ArrayOfCompanies)
	
	OrderText = "
		|ORDER BY
		|	Products, Period, Priority ASC, Company, Recorder
		|";
	
	IndexText = "
		|INDEX BY
		|	Products
		|";
	
	QueryText =
		TextInitializationOfInventoryCosts() + ";" // it returns common temp tables
		+ TextOfDescriptionInventoryCosts()
		+ "UNION ALL" + TextOfInventoryCostsBalance() // use PreviousPeriods
		+ "UNION ALL" + TextOfSourceCostsLayers()
		+ "UNION ALL" + TextOfSalesInPreviousPeriods()
		+ "UNION ALL" + TextOfConsumptionsCostsLayers()
		+ "UNION ALL" + TextOfTransfersReceipt()
		+ "UNION ALL" + TextOfReversalCostsLayers()
		+ "UNION ALL" + TextOfConsumerMaterials()
		+ "UNION ALL" + TextOfIntraCommunityTransfers()
		// begin Drive.FullVersion
		+ "UNION ALL" + TextOfWorkInProgressReceipt()
		+ "UNION ALL" + TextOfProductionReceipt()
		// end Drive.FullVersion
		+ "UNION ALL" + TextOfKitProcessingReceipt()
		+ IndexText;
		
	TempTables = New TempTablesManager;
	
	SourceQuery = New Query(StrReplace(QueryText, "//UseTempTable", ""));
	SourceQuery.SetParameter("BeginOfPeriod", BeginOfPeriod);
	SourceQuery.SetParameter("EndOfPeriod", EndOfOfPeriod);
	SourceQuery.SetParameter("ArrayOfCompanies", ArrayOfCompanies);
	SourceQuery.TempTablesManager = TempTables;
	SourceQuery.Execute();
	
	NamesOfTempTables = "PreviousPeriods, SourceDocuments, SalesInPreviousPeriods";
	
	DeleteTempTables(SourceQuery, NamesOfTempTables);
	
	Query = New Query(TextOfDescriptionInventoryCosts());
	CostsLayers = Query.Execute().Unload();
	
	TempTableOnFilter("Product", OrderText, CostsLayers, TempTables);
	
	Return TempTables;
EndFunction

#Region QueryTexts

Function TextInitializationOfInventoryCosts()
	
	Return "
	|SELECT ALLOWED DISTINCT
	|	CostLayerTable.CostLayer AS CostLayer,
	|	MAX(PreviousPeriods.Period) AS Period
	|INTO PreviousPeriods
	|FROM
	|	AccumulationRegister.InventoryCostLayer.Balance(&BeginOfPeriod, Company IN (&ArrayOfCompanies)) AS CostLayerTable
	|	INNER JOIN AccumulationRegister.InventoryInWarehouses AS PreviousPeriods
	|		ON PreviousPeriods.Period < &BeginOfPeriod
	|		AND PreviousPeriods.Recorder = CostLayerTable.CostLayer
	|WHERE
	|	CostLayerTable.CostLayer <> UNDEFINED
	|GROUP BY
	|	CostLayerTable.CostLayer
	|;
	|/////////////////////////////////////////////////
	|SELECT ALLOWED DISTINCT
	|	Table.SourceDocument AS Recorder,
	|	Table.Company AS Company,
	|	Table.PresentationCurrency AS PresentationCurrency,
	|	Table.Products AS Products,
	|	Table.Characteristic AS Characteristic,
	|	Table.Batch AS Batch,
	|	Table.Ownership AS Ownership,
	|	Table.CostObject AS CostObject,
	|	Table.InventoryAccountType AS InventoryAccountType
	|INTO SourceDocuments
	|FROM
	|	AccumulationRegister.Inventory AS Table
	|WHERE
	|	Table.Period BETWEEN &BeginOfPeriod AND &EndOfPeriod
	|	AND Table.Company IN (&ArrayOfCompanies)
	|	AND Table.Active
	|	AND Table.SourceDocument <> UNDEFINED
	|	AND Table.SourceDocument <> Table.Recorder
	|;
	|/////////////////////////////////////////////////
	|SELECT ALLOWED DISTINCT
	|	Sales.Period AS Period,
	|	Table.Recorder AS Recorder,
	|	Table.Company AS Company,
	|	Table.PresentationCurrency AS PresentationCurrency,
	|	Table.Products AS Products,
	|	Table.Characteristic AS Characteristic,
	|	Table.Batch AS Batch,
	|	Table.Ownership AS Ownership,
	|	Table.InventoryAccountType AS InventoryAccountType
	|INTO SalesInPreviousPeriods
	|FROM
	|	SourceDocuments AS Table
	|	INNER JOIN AccumulationRegister.Inventory AS Sales
	|		ON Sales.Period < &BeginOfPeriod
	|		AND Sales.Recorder = Table.Recorder
	|		AND Sales.Company = Table.Company
	|		AND Sales.Products = Table.Products
	|		AND Sales.Characteristic = Table.Characteristic
	|		AND Sales.Batch = Table.Batch
	|		AND Sales.Ownership = Table.Ownership
	|		AND Sales.InventoryAccountType = Table.InventoryAccountType
	|";
	
EndFunction

Function TextOfDescriptionInventoryCosts()
	
	Return "
	|SELECT ALLOWED TOP 0
	|	CAST ("""" AS STRING(80)) AS QueryName,
	|	0 AS Priority,
	|	""XXXXXXXXXXXXXXXXXXX"" AS RecordKind,
	|	FALSE AS FinishCalculation,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DATETIME(1, 1, 1, 0, 0, 0) AS Period,
	|	Table.Recorder AS Recorder,
	|	Table.Company AS Company,
	|	Table.PresentationCurrency AS PresentationCurrency,
	|	Table.Products AS Products,
	|	Table.Characteristic AS Characteristic,
	|	Table.CostLayer AS CostLayer,
	|	Table.Batch AS Batch,
	|	Table.Ownership AS Ownership,
	|	Table.StructuralUnit AS StructuralUnit,
	|	Table.GLAccount AS GLAccount,
	|	Table.SalesOrder AS SalesOrder,
	|	0 AS Denominator,
	|	0 AS Quantity,
	|	0 AS Amount,
	|	UNDEFINED AS SourceDocument,
	|	UNDEFINED AS CorrStructuralUnit,
	|	UNDEFINED AS CorrSalesOrder,
	|	Table.CorrGLAccount AS CorrGLAccount,
	|	VALUE(Catalog.VATRates.EmptyRef) AS VATRate,
	|	VALUE(Catalog.Employees.EmptyRef) AS Responsible,
	|	VALUE(Catalog.BusinessUnits.EmptyRef) AS Department,
	|	FALSE AS SourceRecord,
	|	FALSE AS RIMTransfer,
	|	VALUE(Catalog.Employees.EmptyRef) AS SalesRep,
	|	VALUE(Catalog.Counterparties.EmptyRef) AS Counterparty,
	|	VALUE(Catalog.Currencies.EmptyRef) AS Currency,
	|	VALUE(Catalog.CostObjects.EmptyRef) AS CostObject,
	|	VALUE(Catalog.CostObjects.EmptyRef) AS CorrCostObject,
	|	UNDEFINED AS CorrProducts,
	|	VALUE(Catalog.ProductsCharacteristics.EmptyRef) AS CorrCharacteristic,
	|	VALUE(Catalog.ProductsBatches.EmptyRef) AS CorrBatch,
	|	VALUE(Catalog.InventoryOwnership.EmptyRef) AS CorrOwnership,
	|	VALUE(Catalog.BillsOfMaterials.EmptyRef) AS CorrSpecification,
	|	VALUE(Catalog.BillsOfMaterials.EmptyRef) AS Specification,
	|	VALUE(Enum.InventoryAccountTypes.EmptyRef) AS InventoryAccountType,
	|	VALUE(Enum.InventoryAccountTypes.EmptyRef) AS CorrInventoryAccountType,
	|	VALUE(Catalog.IncomeAndExpenseItems.EmptyRef) AS IncomeAndExpenseItem,
	|	VALUE(Catalog.IncomeAndExpenseItems.EmptyRef) AS CorrIncomeAndExpenseItem
	|//UseTempTable INTO SourceData
	|FROM
	|	AccumulationRegister.InventoryCostLayer AS Table
	|";
	
EndFunction

Function TextOfInventoryCostsBalance()
	
	Return "
	|SELECT
	|	""BalanceCostsLayers"" AS QueryName,
	|	10 AS Priority,
	|	""Balance"" AS RecordKind,
	|	TRUE AS FinishCalculation,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	ISNULL(PreviousPeriods.Period, &BeginOfPeriod) AS Period,
	|	Table.CostLayer AS Recorder,
	|	Table.Company AS Company,
	|	Table.PresentationCurrency AS PresentationCurrency,
	|	Table.Products AS Products,
	|	Table.Characteristic AS Characteristic,
	|	Table.CostLayer AS CostLayer,
	|	Table.Batch AS Batch,
	|	Table.Ownership AS Ownership,
	|	Table.StructuralUnit AS StructuralUnit,
	|	VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef) AS GLAccount,
	|	UNDEFINED AS SalesOrder,
	|	0 AS Denominator,
	|	Table.QuantityBalance AS Quantity,
	|	Table.AmountBalance AS Amount,
	|	UNDEFINED AS SourceDocument,
	|	VALUE(Catalog.BusinessUnits.EmptyRef) AS CorrStructuralUnit,
	|	UNDEFINED AS CorrSalesOrder,
	|	VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef) AS CorrGLAccount,
	|	VALUE(Catalog.VATRates.EmptyRef) AS VATRate,
	|	VALUE(Catalog.Employees.EmptyRef) AS Responsible,
	|	VALUE(Catalog.BusinessUnits.EmptyRef) AS Department,
	|	FALSE AS SourceRecord,
	|	FALSE AS RIMTransfer,
	|	VALUE(Catalog.Employees.EmptyRef) AS SalesRep,
	|	VALUE(Catalog.Counterparties.EmptyRef) AS Counterparty,
	|	VALUE(Catalog.Currencies.EmptyRef) AS Currency, 
	|	Table.CostObject AS CostObject,
	|	VALUE(Catalog.CostObjects.EmptyRef) AS CorrCostObject,
	|	UNDEFINED AS CorrProducts,
	|	VALUE(Catalog.ProductsCharacteristics.EmptyRef) AS CorrCharacteristic,
	|	VALUE(Catalog.ProductsBatches.EmptyRef) AS CorrBatch,
	|	VALUE(Catalog.InventoryOwnership.EmptyRef) AS CorrOwnership,
	|	VALUE(Catalog.BillsOfMaterials.EmptyRef) AS CorrSpecification,
	|	VALUE(Catalog.BillsOfMaterials.EmptyRef) AS Specification,
	|	Table.InventoryAccountType AS InventoryAccountType,
	|	VALUE(Enum.InventoryAccountTypes.EmptyRef) AS CorrInventoryAccountType,
	|	VALUE(Catalog.IncomeAndExpenseItems.EmptyRef) AS IncomeAndExpenseItem,
	|	VALUE(Catalog.IncomeAndExpenseItems.EmptyRef) AS CorrIncomeAndExpenseItem
	|FROM
	|	AccumulationRegister.InventoryCostLayer.Balance(&BeginOfPeriod, Company IN (&ArrayOfCompanies)) AS Table
	|		LEFT JOIN PreviousPeriods AS PreviousPeriods
	|		ON (PreviousPeriods.CostLayer = Table.CostLayer)
	|WHERE
	|	Table.QuantityBalance > 0
	|";
	
EndFunction

Function TextOfSourceCostsLayers()
	
	Return "
	|SELECT
	|	""SourceCostsLayers"" AS QueryName,
	|	10 AS Priority,
	|	""CostLayer"" AS RecordKind,
	|	TRUE AS FinishCalculation,
	|	Table.RecordType AS RecordType,
	|	Table.Period AS Period,
	|	Table.Recorder AS Recorder,
	|	Table.Company AS Company,
	|	Table.PresentationCurrency AS PresentationCurrency,
	|	Table.Products AS Products,
	|	Table.Characteristic AS Characteristic,
	|	Table.CostLayer AS CostLayer,
	|	Table.Batch AS Batch,
	|	Table.Ownership AS Ownership,
	|	Table.StructuralUnit AS StructuralUnit,
	|	Table.GLAccount AS GLAccount,
	|	Table.SalesOrder AS SalesOrder,
	|	0 AS Denominator,
	|	SUM(CASE
	|			WHEN Table.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN -Table.Quantity
	|			ELSE Table.Quantity
	|		END) AS Quantity,
	|	SUM(CASE
	|			WHEN Table.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN -Table.Amount
	|			ELSE Table.Amount
	|		END) AS Amount,
	|	UNDEFINED AS SourceDocument,
	|	VALUE(Catalog.BusinessUnits.EmptyRef) AS CorrStructuralUnit,
	|	UNDEFINED AS CorrSalesOrder,
	|	Table.CorrGLAccount AS CorrGLAccount,
	|	Table.VATRate AS VATRate,
	|	Table.Responsible AS Responsible,
	|	Table.Department AS Department,
	|	Table.SourceRecord AS SourceRecord,
	|	Table.RIMTransfer AS RIMTransfer,
	|	VALUE(Catalog.Employees.EmptyRef) AS SalesRep,
	|	VALUE(Catalog.Counterparties.EmptyRef) AS Counterparty,
	|	VALUE(Catalog.Currencies.EmptyRef) AS Currency,
	|	Table.CostObject AS CostObject,
	|	Table.CorrCostObject AS CorrCostObject,
	|	Table.CorrProducts AS CorrProducts,
	|	Table.CorrCharacteristic AS CorrCharacteristic,
	|	Table.CorrBatch AS CorrBatch,
	|	Table.CorrOwnership AS CorrOwnership,
	|	Table.CorrSpecification AS CorrSpecification,
	|	Table.Specification,
	|	Table.InventoryAccountType,
	|	Table.CorrInventoryAccountType,
	|	Table.IncomeAndExpenseItem,
	|	Table.CorrIncomeAndExpenseItem
	|FROM
	|	AccumulationRegister.InventoryCostLayer AS Table
	|WHERE
	|	Table.Period BETWEEN &BeginOfPeriod AND &EndOfPeriod
	|	AND Table.Company IN (&ArrayOfCompanies)
	|	AND Table.Active
	|	AND Table.SourceRecord
	|GROUP BY
	|	Table.RecordType,
	|	Table.Period,
	|	Table.Recorder,
	|	Table.Company,
	|	Table.PresentationCurrency,
	|	Table.Products,
	|	Table.Characteristic,
	|	Table.CostLayer,
	|	Table.Batch,
	|	Table.Ownership,
	|	Table.StructuralUnit,
	|	Table.GLAccount,
	|	Table.SalesOrder,
	|	Table.CorrGLAccount,
	|	Table.VATRate,
	|	Table.Responsible,
	|	Table.Department,
	|	Table.SourceRecord,
	|	Table.RIMTransfer,
	|	Table.CostObject,
	|	Table.CorrCostObject,
	|	Table.CorrProducts,
	|	Table.CorrCharacteristic,
	|	Table.CorrBatch,
	|	Table.CorrOwnership,
	|	Table.CorrSpecification,
	|	Table.Specification,
	|	Table.InventoryAccountType,
	|	Table.CorrInventoryAccountType,
	|	Table.IncomeAndExpenseItem,
	|	Table.CorrIncomeAndExpenseItem
	|";
	
EndFunction

Function TextOfSalesInPreviousPeriods()
	
	Return "
	|SELECT
	|	""SalesInPreviousPeriods"" AS QueryName,
	|	10 AS Priority,
	|	""PreviousPeriods"" AS RecordKind,
	|	TRUE AS FinishCalculation,
	|	Table.RecordType AS RecordType,
	|	Table.Period AS Period,
	|	Table.Recorder AS Recorder,
	|	Table.Company AS Company,
	|	Table.PresentationCurrency AS PresentationCurrency,
	|	Table.Products AS Products,
	|	Table.Characteristic AS Characteristic,
	|	Table.CostLayer AS CostLayer,
	|	Table.Batch AS Batch,
	|	Table.Ownership AS Ownership,
	|	Table.StructuralUnit AS StructuralUnit,
	|	Table.GLAccount AS GLAccount,
	|	Table.SalesOrder AS SalesOrder,
	|	0 AS Denominator,
	|	SUM(Table.Quantity) AS Quantity,
	|	SUM(Table.Amount) AS Amount,
	|	Table.Recorder AS SourceDocument,
	|	VALUE(Catalog.BusinessUnits.EmptyRef) AS CorrStructuralUnit,
	|	UNDEFINED AS CorrSalesOrder,
	|	Table.CorrGLAccount AS CorrGLAccount,
	|	VALUE(Catalog.VATRates.EmptyRef) AS VATRate,
	|	VALUE(Catalog.Employees.EmptyRef) AS Responsible,
	|	VALUE(Catalog.BusinessUnits.EmptyRef) AS Department,
	|	Table.SourceRecord AS SourceRecord,
	|	Table.RIMTransfer AS RIMTransfer,
	|	VALUE(Catalog.Employees.EmptyRef) AS SalesRep,
	|	VALUE(Catalog.Counterparties.EmptyRef) AS Counterparty,
	|	VALUE(Catalog.Currencies.EmptyRef) AS Currency,
	|	Table.CostObject AS CostObject,
	|	Table.CorrCostObject AS CorrCostObject,
	|	Table.CorrProducts AS CorrProducts,
	|	Table.CorrCharacteristic AS CorrCharacteristic,
	|	Table.CorrBatch AS CorrBatch,
	|	Table.CorrOwnership AS CorrOwnership,
	|	Table.CorrSpecification,
	|	Table.Specification,
	|	Table.InventoryAccountType,
	|	Table.CorrInventoryAccountType,
	|	Table.IncomeAndExpenseItem,
	|	Table.CorrIncomeAndExpenseItem
	|FROM
	|	AccumulationRegister.InventoryCostLayer AS Table
	|	INNER JOIN SalesInPreviousPeriods AS PreviousSales
	|		ON Table.Period = PreviousSales.Period
	|		AND Table.Recorder = PreviousSales.Recorder
	|		AND Table.Company = PreviousSales.Company
	|		AND Table.Products = PreviousSales.Products
	|		AND Table.Characteristic = PreviousSales.Characteristic
	|		AND Table.Batch = PreviousSales.Batch
	|		AND Table.Ownership = PreviousSales.Ownership
	|		AND Table.InventoryAccountType = PreviousSales.InventoryAccountType
	|WHERE
	|	Table.Company IN (&ArrayOfCompanies)
	|	AND Table.Active
	|GROUP BY
	|	Table.RecordType,
	|	Table.Period,
	|	Table.Recorder,
	|	Table.Company,
    |	Table.PresentationCurrency,
	|	Table.Products,
	|	Table.Characteristic,
	|	Table.CostLayer,
	|	Table.Batch,
	|	Table.Ownership,
	|	Table.StructuralUnit,
	|	Table.GLAccount,
	|	Table.SalesOrder,
	|	Table.Recorder,
	|	Table.CorrGLAccount,
	|	Table.SourceRecord,
	|	Table.RIMTransfer,
	|	Table.CostObject,
	|	Table.CorrCostObject,
	|	Table.CorrProducts,
	|	Table.CorrCharacteristic,
	|	Table.CorrBatch,
	|	Table.CorrOwnership,
	|	Table.CorrSpecification,
	|	Table.Specification,
	|	Table.InventoryAccountType,
	|	Table.CorrInventoryAccountType,
	|	Table.IncomeAndExpenseItem,
	|	Table.CorrIncomeAndExpenseItem
	|";
	
EndFunction

Function TextOfConsumptionsCostsLayers()
	
	Return "
	|	SELECT
	|	""ConsumptionsCostsLayers"" AS QueryName,
	|	90 AS Priority,
	|	""Consumption"" AS RecordKind,
	|	FALSE AS FinishCalculation,
	|	Table.RecordType AS RecordType,
	|	Table.Period AS Period,
	|	Table.Recorder AS Recorder,
	|	Table.Company AS Company,
	|	Table.PresentationCurrency AS PresentationCurrency,
	|	Table.Products AS Products,
	|	Table.Characteristic AS Characteristic,
	|	UNDEFINED AS CostLayer,
	|	Table.Batch AS Batch,
	|	Table.Ownership AS Ownership,
	|	Table.StructuralUnit AS StructuralUnit,
	|	Table.GLAccount AS GLAccount,
	|	Table.SalesOrder AS SalesOrder,
	|	0 AS Denominator,
	|	SUM(Table.Quantity) AS Quantity,
	|	0 AS Amount,
	|	Table.Recorder AS SourceDocument,
	|	Table.StructuralUnitCorr AS CorrStructuralUnit,
	|	Table.CorrSalesOrder AS CorrSalesOrder,
	|	Table.CorrGLAccount AS CorrGLAccount,
	|	Table.VATRate AS VATRate,
	|	Table.Responsible AS Responsible,
	|	Table.Department AS Department,
	|	FALSE AS SourceRecord,
	|	Table.RetailTransferEarningAccounting AS RIMTransfer,
	|	Table.SalesRep AS SalesRep,
	|	Table.Counterparty AS Counterparty,
	|	Table.Currency AS Currency,
	|	Table.CostObject AS CostObject,
	|	Table.CostObjectCorr AS CorrCostObject,
	|	Table.ProductsCorr AS CorrProducts,
	|	Table.CharacteristicCorr AS CorrCharacteristic,
	|	Table.BatchCorr AS CorrBatch,
	|	Table.OwnershipCorr AS CorrOwnership,
	|	Table.SpecificationCorr,
	|	Table.Specification,
	|	Table.InventoryAccountType,
	|	Table.CorrInventoryAccountType,
	|	Table.IncomeAndExpenseItem,
	|	Table.CorrIncomeAndExpenseItem
	|FROM
	|	AccumulationRegister.Inventory AS Table
	|WHERE
	|	Table.Period BETWEEN &BeginOfPeriod AND &EndOfPeriod
	|	AND Table.Company IN(&ArrayOfCompanies)
	|	AND Table.Active
	|	AND Table.RecordType = VALUE(AccumulationRecordType.Expense)
	|	AND Table.Quantity > 0
	|	AND (Table.SourceDocument = UNDEFINED
	|			OR Table.SourceDocument = Table.Recorder)
	|	AND (VALUETYPE(Table.Recorder) = TYPE(Document.GoodsIssue)
	|			OR VALUETYPE(Table.Recorder) = TYPE(Document.InventoryTransfer)
	|			OR VALUETYPE(Table.Recorder) = TYPE(Document.InventoryWriteOff)
	|			OR VALUETYPE(Table.Recorder) = TYPE(Document.SalesInvoice)
	|			OR VALUETYPE(Table.Recorder) = TYPE(Document.ShiftClosure)
	|			OR VALUETYPE(Table.Recorder) = TYPE(Document.SupplierInvoice)
	|			OR VALUETYPE(Table.Recorder) = TYPE(Document.WorkOrder)
	|			OR VALUETYPE(Table.Recorder) = TYPE(Document.SubcontractorInvoiceReceived))
	|
	|GROUP BY
	|	Table.RecordType,
	|	Table.Period,
	|	Table.Recorder,
	|	Table.Company,
	|	Table.PresentationCurrency,
	|	Table.Products,
	|	Table.Characteristic,
	|	Table.Batch,
	|	Table.Ownership,
	|	Table.StructuralUnit,
	|	Table.StructuralUnitCorr,
	|	Table.GLAccount,
	|	Table.CorrGLAccount,
	|	Table.SalesOrder,
	|	Table.VATRate,
	|	Table.Responsible,
	|	Table.Department,
	|	Table.CorrSalesOrder,
	|	Table.RetailTransferEarningAccounting,
	|	Table.SalesRep,
	|	Table.Counterparty,
	|	Table.Currency,
	|	Table.CostObject,
	|	Table.CostObjectCorr,
	|	Table.ProductsCorr,
	|	Table.CharacteristicCorr,
	|	Table.BatchCorr,
	|	Table.OwnershipCorr,
	|	Table.SpecificationCorr,
	|	Table.Specification,
	|	Table.InventoryAccountType,
	|	Table.CorrInventoryAccountType,
	|	Table.IncomeAndExpenseItem,
	|	Table.CorrIncomeAndExpenseItem
	|
	|UNION ALL
	|
	|SELECT
	|	""ConsumptionsCostsLayers"",
	|	90,
	|	""Consumption"",
	|	FALSE,
	|	Table.RecordType,
	|	Table.Period,
	|	Table.Recorder,
	|	Table.Company,
	|	Table.PresentationCurrency,
	|	Table.Products,
	|	Table.Characteristic,
	|	UNDEFINED,
	|	Table.Batch,
	|	Table.Ownership,
	|	Table.StructuralUnit,
	|	Table.GLAccount,
	|	Table.SalesOrder,
	|	0,
	|	SUM(Table.Quantity),
	|	0,
	|	Table.Recorder,
	|	Table.StructuralUnitCorr,
	|	Table.CorrSalesOrder,
	|	Table.CorrGLAccount,
	|	Table.VATRate,
	|	Table.Responsible,
	|	Table.Department,
	|	FALSE,
	|	Table.RetailTransferEarningAccounting,
	|	Table.SalesRep,
	|	Table.Counterparty,
	|	Table.Currency,
	|	Table.CostObject,
	|	Table.CostObjectCorr,
	|	Table.ProductsCorr,
	|	Table.CharacteristicCorr,
	|	Table.BatchCorr,
	|	Table.OwnershipCorr,
	|	Table.SpecificationCorr,
	|	Table.Specification,
	|	Table.InventoryAccountType,
	|	Table.CorrInventoryAccountType,
	|	Table.IncomeAndExpenseItem,
	|	Table.CorrIncomeAndExpenseItem
	|FROM
	|	AccumulationRegister.Inventory AS Table
	|WHERE
	|	Table.Period BETWEEN &BeginOfPeriod AND &EndOfPeriod
	|	AND Table.Company IN(&ArrayOfCompanies)
	|	AND Table.Active
	|	AND Table.RecordType = VALUE(AccumulationRecordType.Expense)
	|	AND Table.Quantity <> 0
	|	AND VALUETYPE(Table.Recorder) = TYPE(Document.DebitNote)
	|
	|GROUP BY
	|	Table.RecordType,
	|	Table.Period,
	|	Table.Recorder,
	|	Table.Company,
	|	Table.PresentationCurrency,
	|	Table.Products,
	|	Table.Characteristic,
	|	Table.Batch,
	|	Table.Ownership,
	|	Table.StructuralUnit,
	|	Table.StructuralUnitCorr,
	|	Table.GLAccount,
	|	Table.CorrGLAccount,
	|	Table.SalesOrder,
	|	Table.VATRate,
	|	Table.Responsible,
	|	Table.Department,
	|	Table.CorrSalesOrder,
	|	Table.RetailTransferEarningAccounting,
	|	Table.SalesRep,
	|	Table.Counterparty,
	|	Table.Currency,
	|	Table.CostObject,
	|	Table.CostObjectCorr,
	|	Table.ProductsCorr,
	|	Table.CharacteristicCorr,
	|	Table.BatchCorr,
	|	Table.OwnershipCorr,
	|	Table.SpecificationCorr,
	|	Table.Specification,
	|	Table.InventoryAccountType,
	|	Table.CorrInventoryAccountType,
	|	Table.IncomeAndExpenseItem,
	|	Table.CorrIncomeAndExpenseItem
	|
	|UNION ALL
	|
	|SELECT
	|	""ConsumptionsCostsLayers"",
	|	90,
	|	""Consumption"",
	|	FALSE,
	|	Table.RecordType,
	|	Table.Period,
	|	Table.Recorder,
	|	Table.Company,
	|	Table.PresentationCurrency,
	|	Table.Products,
	|	Table.Characteristic,
	|	UNDEFINED,
	|	Table.Batch,
	|	Table.Ownership,
	|	Table.StructuralUnit,
	|	Table.GLAccount,
	|	Table.SalesOrder,
	|	0,
	|	SUM(Table.Quantity),
	|	0,
	|	Table.Recorder,
	|	Table.StructuralUnitCorr,
	|	Table.CorrSalesOrder,
	|	Table.CorrGLAccount,
	|	Table.VATRate,
	|	Table.Responsible,
	|	Table.Department,
	|	FALSE,
	|	Table.RetailTransferEarningAccounting,
	|	Table.SalesRep,
	|	Table.Counterparty,
	|	Table.Currency,
	|	Table.CostObject,
	|	Table.CostObjectCorr,
	|	Table.ProductsCorr,
	|	Table.CharacteristicCorr,
	|	Table.BatchCorr,
	|	Table.OwnershipCorr,
	|	Table.SpecificationCorr,
	|	Table.Specification,
	|	Table.InventoryAccountType,
	|	Table.CorrInventoryAccountType,
	|	Table.IncomeAndExpenseItem,
	|	Table.CorrIncomeAndExpenseItem
	|FROM
	|	AccumulationRegister.Inventory AS Table
	|WHERE
	|	Table.Period BETWEEN &BeginOfPeriod AND &EndOfPeriod
	|	AND Table.Company IN(&ArrayOfCompanies)
	|	AND Table.Active
	|	AND Table.RecordType = VALUE(AccumulationRecordType.Expense)
	|	AND Table.Quantity > 0
	|	AND (Table.SourceDocument = UNDEFINED
	|			OR Table.SourceDocument = Table.Recorder)
	|	AND VALUETYPE(Table.Recorder) = TYPE(Document.Production)
	|
	|GROUP BY
	|	Table.RecordType,
	|	Table.Period,
	|	Table.Recorder,
	|	Table.Company,
	|	Table.PresentationCurrency,
	|	Table.Products,
	|	Table.Characteristic,
	|	Table.Batch,
	|	Table.Ownership,
	|	Table.StructuralUnit,
	|	Table.StructuralUnitCorr,
	|	Table.GLAccount,
	|	Table.CorrGLAccount,
	|	Table.SalesOrder,
	|	Table.VATRate,
	|	Table.Responsible,
	|	Table.Department,
	|	Table.CorrSalesOrder,
	|	Table.RetailTransferEarningAccounting,
	|	Table.SalesRep,
	|	Table.Counterparty,
	|	Table.Currency,
	|	Table.CostObject,
	|	Table.CostObjectCorr,
	|	Table.Recorder,
	|	Table.ProductsCorr,
	|	Table.CharacteristicCorr,
	|	Table.BatchCorr,
	|	Table.OwnershipCorr,
	|	Table.SpecificationCorr,
	|	Table.Specification,
	|	Table.InventoryAccountType,
	|	Table.CorrInventoryAccountType,
	|	Table.IncomeAndExpenseItem,
	|	Table.CorrIncomeAndExpenseItem
	|
	// begin Drive.FullVersion
	|UNION ALL
	|
	|SELECT
	|	""ConsumptionsCostsLayers"",
	|	90,
	|	""Consumption"",
	|	FALSE,
	|	Table.RecordType,
	|	Table.Period,
	|	Table.Recorder,
	|	Table.Company,
	|	Table.PresentationCurrency,
	|	Table.Products,
	|	Table.Characteristic,
	|	UNDEFINED,
	|	Table.Batch,
	|	Table.Ownership,
	|	Table.StructuralUnit,
	|	Table.GLAccount,
	|	Table.SalesOrder,
	|	0,
	|	SUM(Table.Quantity),
	|	0,
	|	Table.Recorder,
	|	Table.StructuralUnitCorr,
	|	Table.CorrSalesOrder,
	|	Table.CorrGLAccount,
	|	Table.VATRate,
	|	Table.Responsible,
	|	Table.Department,
	|	FALSE,
	|	Table.RetailTransferEarningAccounting,
	|	Table.SalesRep,
	|	Table.Counterparty,
	|	Table.Currency,
	|	Table.CostObject,
	|	Table.CostObjectCorr,
	|	Table.ProductsCorr,
	|	Table.CharacteristicCorr,
	|	Table.BatchCorr,
	|	Table.OwnershipCorr,
	|	Table.SpecificationCorr,
	|	Table.Specification,
	|	Table.InventoryAccountType,
	|	Table.CorrInventoryAccountType,
	|	Table.IncomeAndExpenseItem,
	|	Table.CorrIncomeAndExpenseItem
	|FROM
	|	AccumulationRegister.Inventory AS Table
	|WHERE
	|	Table.Period BETWEEN &BeginOfPeriod AND &EndOfPeriod
	|	AND Table.Company IN(&ArrayOfCompanies)
	|	AND Table.Active
	|	AND Table.RecordType = VALUE(AccumulationRecordType.Expense)
	|	AND Table.Quantity > 0
	|	AND (Table.SourceDocument = UNDEFINED
	|			OR Table.SourceDocument = Table.Recorder)
	|	AND (VALUETYPE(Table.Recorder) = TYPE(Document.ManufacturingOperation)
	|			OR VALUETYPE(Table.Recorder) = TYPE(Document.Manufacturing))
	|
	|GROUP BY
	|	Table.RecordType,
	|	Table.Period,
	|	Table.Recorder,
	|	Table.Company,
	|	Table.PresentationCurrency,
	|	Table.Products,
	|	Table.Characteristic,
	|	Table.Batch,
	|	Table.Ownership,
	|	Table.StructuralUnit,
	|	Table.StructuralUnitCorr,
	|	Table.GLAccount,
	|	Table.CorrGLAccount,
	|	Table.SalesOrder,
	|	Table.VATRate,
	|	Table.Responsible,
	|	Table.Department,
	|	Table.CorrSalesOrder,
	|	Table.RetailTransferEarningAccounting,
	|	Table.SalesRep,
	|	Table.Counterparty,
	|	Table.Currency,
	|	Table.CostObject,
	|	Table.CostObjectCorr,
	|	Table.ProductsCorr,
	|	Table.CharacteristicCorr,
	|	Table.BatchCorr,
	|	Table.OwnershipCorr,
	|	Table.SpecificationCorr,
	|	Table.Specification,
	|	Table.InventoryAccountType,
	|	Table.CorrInventoryAccountType,
	|	Table.IncomeAndExpenseItem,
	|	Table.CorrIncomeAndExpenseItem
	// end Drive.FullVersion
	|";
	
EndFunction

Function TextOfTransfersReceipt()
	
	Return "
	|SELECT
	|	""CostsLayersTransfersReceipt"" AS QueryName,
	|	90 AS Priority,
	|	""Transfer"" AS RecordKind,
	|	FALSE AS FinishCalculation,
	|	Table.RecordType AS RecordType,
	|	Table.Period AS Period,
	|	Table.Recorder AS Recorder,
	|	Table.Company AS Company,
	|	Table.PresentationCurrency AS PresentationCurrency,
	|	Table.Products AS Products,
	|	Table.Characteristic AS Characteristic,
	|	UNDEFINED AS CostLayer,
	|	Table.Batch AS Batch,
	|	Table.Ownership AS Ownership,
	|	Table.StructuralUnit AS StructuralUnit,
	|	Table.GLAccount AS GLAccount,
	|	Table.SalesOrder AS SalesOrder,
	|	0 AS Denominator,
	|	SUM(Table.Quantity) AS Quantity,
	|	0 AS Amount,
	|	Table.Recorder AS SourceDocument,
	|	VALUE(Catalog.BusinessUnits.EmptyRef) AS CorrStructuralUnit,
	|	UNDEFINED AS CorrSalesOrder,
	|	Table.CorrGLAccount AS CorrGLAccount,
	|	Table.VATRate AS VATRate,
	|	Table.Responsible AS Responsible,
	|	Table.Department AS Department,
	|	FALSE AS SourceRecord,
	|	Table.RetailTransferEarningAccounting AS RIMTransfer,
	|	Table.SalesRep AS SalesRep,
	|	Table.Counterparty AS Counterparty,
	|	Table.Currency AS Currency,
	|	Table.CostObject,
	|	Table.CostObjectCorr,
	|	Table.ProductsCorr,
	|	Table.CharacteristicCorr,
	|	Table.BatchCorr,
	|	Table.OwnershipCorr,
	|	Table.SpecificationCorr,
	|	Table.Specification,
	|	Table.InventoryAccountType,
	|	Table.CorrInventoryAccountType,
	|	Table.IncomeAndExpenseItem,
	|	Table.CorrIncomeAndExpenseItem
	|FROM
	|	AccumulationRegister.Inventory AS Table
	|WHERE
	|	Table.Period BETWEEN &BeginOfPeriod AND &EndOfPeriod
	|	AND Table.Company IN (&ArrayOfCompanies)
	|	AND Table.Active
	|	AND Table.RecordType = VALUE(AccumulationRecordType.Receipt)
	|	AND Table.Quantity > 0
	|	AND (VALUETYPE(Table.Recorder) = TYPE(Document.InventoryTransfer)
	|		OR VALUETYPE(Table.Recorder) = TYPE(Document.GoodsIssue))
	|GROUP BY
	|	Table.RecordType,
	|	Table.Period,
	|	Table.Recorder,
	|	Table.Company,
	|	Table.PresentationCurrency,
	|	Table.Products,
	|	Table.Characteristic,
	|	Table.Batch,
	|	Table.Ownership,
	|	Table.StructuralUnit,
	|	Table.GLAccount,
	|	Table.CorrGLAccount,
	|	Table.VATRate,
	|	Table.Responsible,
	|	Table.Department,
	|	Table.SalesOrder,
	|	Table.RetailTransferEarningAccounting,
	|	Table.SalesRep,
	|	Table.Counterparty,
	|	Table.Currency,
	|	Table.CostObject,
	|	Table.CostObjectCorr,
	|	Table.ProductsCorr,
	|	Table.CharacteristicCorr,
	|	Table.BatchCorr,
	|	Table.OwnershipCorr,
	|	Table.SpecificationCorr,
	|	Table.Specification,
	|	Table.InventoryAccountType,
	|	Table.CorrInventoryAccountType,
	|	Table.IncomeAndExpenseItem,
	|	Table.CorrIncomeAndExpenseItem
	|";
	
EndFunction

Function TextOfReversalCostsLayers()
	
	Return "
	|SELECT
	|	""ReversalCostsLayers"" AS QueryName,
	|	10 AS Priority,
	|	""Reversal"" AS RecordKind,
	|	FALSE AS FinishCalculation,
	|	Table.RecordType AS RecordType,
	|	Table.Period AS Period,
	|	Table.Recorder AS Recorder,
	|	Table.Company AS Company,
	|	Table.PresentationCurrency AS PresentationCurrency,
	|	Table.Products AS Products,
	|	Table.Characteristic AS Characteristic,
	|	UNDEFINED AS CostLayer,
	|	Table.Batch AS Batch,
	|	Table.Ownership AS Ownership,
	|	Table.StructuralUnit AS StructuralUnit,
	|	Table.GLAccount AS GLAccount,
	|	Table.SalesOrder AS SalesOrder,
	|	0 AS Denominator,
	|	SUM(Table.Quantity) AS Quantity,
	|	0 AS Amount,
	|	Table.SourceDocument AS SourceDocument,
	|	Table.StructuralUnitCorr AS CorrStructuralUnit,
	|	UNDEFINED AS CorrSalesOrder,
	|	Table.CorrGLAccount AS CorrGLAccount,
	|	Table.VATRate AS VATRate,
	|	Table.Responsible AS Responsible,
	|	Table.Department AS Department,
	|	FALSE AS SourceRecord,
	|	Table.RetailTransferEarningAccounting AS RIMTransfer,
	|	Table.SalesRep AS SalesRep,
	|	Table.Counterparty AS Counterparty,
	|	Table.Currency AS Currency,
	|	Table.CostObject,
	|	Table.CostObjectCorr,
	|	Table.ProductsCorr,
	|	Table.CharacteristicCorr,
	|	Table.BatchCorr,
	|	Table.OwnershipCorr,
	|	Table.SpecificationCorr,
	|	Table.Specification,
	|	Table.InventoryAccountType,
	|	Table.CorrInventoryAccountType,
	|	Table.IncomeAndExpenseItem,
	|	Table.CorrIncomeAndExpenseItem
	|FROM
	|	AccumulationRegister.Inventory AS Table
	|WHERE
	|	Table.Period BETWEEN &BeginOfPeriod AND &EndOfPeriod
	|	AND Table.Company IN (&ArrayOfCompanies)
	|	AND Table.Active
	|	AND Table.RecordType = VALUE(AccumulationRecordType.Receipt)
	|	AND Table.Quantity <> 0
	|	AND VALUETYPE(Table.Recorder) = TYPE(Document.CreditNote)
	|GROUP BY
	|	Table.RecordType,
	|	Table.Period,
	|	Table.Recorder,
	|	Table.Company,
	|	Table.PresentationCurrency,
	|	Table.Products,
	|	Table.Characteristic,
	|	Table.Batch,
	|	Table.Ownership,
	|	Table.StructuralUnit,
	|	Table.GLAccount,
	|	Table.SalesOrder,
	|	Table.StructuralUnitCorr,
	|	Table.SourceDocument,
	|	Table.CorrGLAccount,
	|	Table.VATRate,
	|	Table.Responsible,
	|	Table.Department,
	|	Table.RetailTransferEarningAccounting,
	|	Table.SalesRep,
	|	Table.Counterparty,
	|	Table.Currency,
	|	Table.CostObject,
	|	Table.CostObjectCorr,
	|	Table.ProductsCorr,
	|	Table.CharacteristicCorr,
	|	Table.BatchCorr,
	|	Table.OwnershipCorr,
	|	Table.SpecificationCorr,
	|	Table.Specification,
	|	Table.InventoryAccountType,
	|	Table.CorrInventoryAccountType,
	|	Table.IncomeAndExpenseItem,
	|	Table.CorrIncomeAndExpenseItem
	|
	|UNION ALL
	|
	|SELECT
	|	""ReversalCostsLayers"" AS QueryName,
	|	10 AS Priority,
	|	""Reversal"" AS RecordKind,
	|	FALSE AS FinishCalculation,
	|	Table.RecordType AS RecordType,
	|	Table.Period AS Period,
	|	Table.Recorder AS Recorder,
	|	Table.Company AS Company,
	|	Table.PresentationCurrency AS PresentationCurrency,
	|	Table.Products AS Products,
	|	Table.Characteristic AS Characteristic,
	|	UNDEFINED AS CostLayer,
	|	Table.Batch AS Batch,
	|	Table.Ownership AS Ownership,
	|	Table.StructuralUnit AS StructuralUnit,
	|	Table.GLAccount AS GLAccount,
	|	Table.SalesOrder AS SalesOrder,
	|	0 AS Denominator,
	|	SUM(Table.Quantity) AS Quantity,
	|	0 AS Amount,
	|	Table.SourceDocument AS SourceDocument,
	|	Table.StructuralUnitCorr AS CorrStructuralUnit,
	|	UNDEFINED AS CorrSalesOrder,
	|	Table.CorrGLAccount AS CorrGLAccount,
	|	Table.VATRate AS VATRate,
	|	Table.Responsible AS Responsible,
	|	Table.Department AS Department,
	|	FALSE AS SourceRecord,
	|	Table.RetailTransferEarningAccounting AS RIMTransfer,
	|	Table.SalesRep AS SalesRep,
	|	Table.Counterparty AS Counterparty,
	|	Table.Currency AS Currency,
	|	Table.CostObject,
	|	Table.CostObjectCorr,
	|	Table.ProductsCorr,
	|	Table.CharacteristicCorr,
	|	Table.BatchCorr,
	|	Table.OwnershipCorr,
	|	Table.SpecificationCorr,
	|	Table.Specification,
	|	Table.InventoryAccountType,
	|	Table.CorrInventoryAccountType,
	|	Table.IncomeAndExpenseItem,
	|	Table.CorrIncomeAndExpenseItem
	|FROM
	|	AccumulationRegister.Inventory AS Table
	|	INNER JOIN Document.GoodsReceipt AS GoodsReceipt
	|	ON Table.Recorder = GoodsReceipt.Ref
	|		AND GoodsReceipt.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.SalesReturn)
	|WHERE
	|	Table.Period BETWEEN &BeginOfPeriod AND &EndOfPeriod
	|	AND Table.Company IN (&ArrayOfCompanies)
	|	AND Table.Active
	|	AND Table.RecordType = VALUE(AccumulationRecordType.Receipt)
	|	AND Table.Quantity <> 0
	|
	|GROUP BY
	|	Table.RecordType,
	|	Table.Period,
	|	Table.Recorder,
	|	Table.Company,
	|	Table.PresentationCurrency,
	|	Table.Products,
	|	Table.Characteristic,
	|	Table.Batch,
	|	Table.Ownership,
	|	Table.StructuralUnit,
	|	Table.GLAccount,
	|	Table.SalesOrder,
	|	Table.StructuralUnitCorr,
	|	Table.SourceDocument,
	|	Table.CorrGLAccount,
	|	Table.VATRate,
	|	Table.Responsible,
	|	Table.Department,
	|	Table.RetailTransferEarningAccounting,
	|	Table.SalesRep,
	|	Table.Counterparty,
	|	Table.Currency,
	|	Table.CostObject,
	|	Table.CostObjectCorr,
	|	Table.ProductsCorr,
	|	Table.CharacteristicCorr,
	|	Table.BatchCorr,
	|	Table.OwnershipCorr,
	|	Table.SpecificationCorr,
	|	Table.Specification,
	|	Table.InventoryAccountType,
	|	Table.CorrInventoryAccountType,
	|	Table.IncomeAndExpenseItem,
	|	Table.CorrIncomeAndExpenseItem
	|";
	
EndFunction

Function TextOfConsumerMaterials()
	
	Return "
	|SELECT
	|	""ConsumerMaterialsCostsLayers"" AS QueryName,
	|	90 AS Priority,
	|	""ConsumerMaterials"" AS RecordKind,
	|	FALSE AS FinishCalculation,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	Table.Period AS Period,
	|	Table.Recorder AS Recorder,
	|	Table.Company AS Company,
	|	Table.PresentationCurrency AS PresentationCurrency,
	|	Table.Products AS Products,
	|	Table.Characteristic AS Characteristic,
	|	UNDEFINED AS CostLayer,
	|	Table.Batch AS Batch,
	|	Table.Ownership AS Ownership,
	|	Table.StructuralUnit AS StructuralUnit,
	|	Table.GLAccount AS GLAccount,
	|	Table.SalesOrder AS SalesOrder,
	|	0 AS Denominator,
	|	Table.Quantity AS Quantity,
	|	0 AS Amount,
	|	UNDEFINED AS SourceDocument,
	|	Table.StructuralUnitCorr AS CorrStructuralUnit,
	|	Table.CorrSalesOrder AS CorrSalesOrder,
	|	Table.CorrGLAccount AS CorrGLAccount,
	|	Table.VATRate AS VATRate,
	|	Table.Responsible AS Responsible,
	|	Table.Department AS Department,
	|	FALSE AS SourceRecord,
	|	Table.RetailTransferEarningAccounting AS RIMTransfer,
	|	Table.SalesRep AS SalesRep,
	|	Table.Counterparty AS Counterparty,
	|	Table.Currency AS Currency,
	|	Table.CostObject,
	|	Table.CostObjectCorr,
	|	Table.ProductsCorr,
	|	Table.CharacteristicCorr,
	|	Table.BatchCorr,
	|	Table.OwnershipCorr,
	|	Table.SpecificationCorr,
	|	Table.Specification,
	|	Table.InventoryAccountType,
	|	Table.CorrInventoryAccountType,
	|	Table.IncomeAndExpenseItem,
	|	Table.CorrIncomeAndExpenseItem
	|FROM
	|	AccumulationRegister.Inventory AS Table
	|WHERE
	|	Table.Period BETWEEN &BeginOfPeriod AND &EndOfPeriod
	|	AND Table.Company IN(&ArrayOfCompanies)
	|	AND Table.Active
	|	AND Table.RecordType = VALUE(AccumulationRecordType.Expense)
	|	AND Table.ProductionExpenses
	|	AND (Table.SourceDocument = UNDEFINED
	|			OR Table.SourceDocument = Table.Recorder)
	|	AND VALUETYPE(Table.Recorder) = TYPE(Document.SupplierInvoice)";
	
EndFunction

Function TextOfIntraCommunityTransfers()
	
	Return "
	|SELECT
	|	""IntraCommunityTransfers"" AS QueryName,
	|	95 AS Priority,
	|	""ConsumptionIntraTransfer"" AS RecordKind,
	|	FALSE AS FinishCalculation,
	|	Table.RecordType AS RecordType,
	|	Table.Period AS Period,
	|	Table.Recorder AS Recorder,
	|	Table.Company AS Company,
	|	Table.PresentationCurrency AS PresentationCurrency,
	|	Table.Products AS Products,
	|	Table.Characteristic AS Characteristic,
	|	UNDEFINED AS CostLayer,
	|	Table.Batch AS Batch,
	|	Table.Ownership AS Ownership,
	|	Table.StructuralUnit AS StructuralUnit,
	|	Table.GLAccount AS GLAccount,
	|	Table.SalesOrder AS SalesOrder,
	|	0 AS Denominator,
	|	SUM(Table.Quantity) AS Quantity,
	|	0 AS Amount,
	|	Table.SourceDocument AS SourceDocument,
	|	Table.StructuralUnitCorr AS CorrStructuralUnit,
	|	UNDEFINED AS CorrSalesOrder,
	|	Table.CorrGLAccount AS CorrGLAccount,
	|	Table.VATRate AS VATRate,
	|	Table.Responsible AS Responsible,
	|	UNDEFINED AS Department,
	|	FALSE AS SourceRecord,
	|	Table.RetailTransferEarningAccounting AS RIMTransfer,
	|	Table.SalesRep AS SalesRep,
	|	Table.Counterparty AS Counterparty,
	|	Table.Currency AS Currency,
	|	Table.CostObject,
	|	Table.CostObjectCorr,
	|	Table.ProductsCorr,
	|	Table.CharacteristicCorr,
	|	Table.BatchCorr,
	|	Table.OwnershipCorr,
	|	Table.SpecificationCorr,
	|	Table.Specification,
	|	Table.InventoryAccountType,
	|	Table.CorrInventoryAccountType,
	|	Table.IncomeAndExpenseItem,
	|	Table.CorrIncomeAndExpenseItem
	|FROM
	|	AccumulationRegister.Inventory AS Table
	|WHERE
	|	Table.Period BETWEEN &BeginOfPeriod AND &EndOfPeriod
	|	AND Table.Company IN(&ArrayOfCompanies)
	|	AND Table.Active
	|	AND Table.RecordType = VALUE(AccumulationRecordType.Expense)
	|	AND Table.Quantity > 0
	|	AND VALUETYPE(Table.Recorder) = VALUE(Document.GoodsReceipt)
	|	AND Table.StructuralUnit = VALUE(Catalog.BusinessUnits.GoodsInTransit)
	|
	|GROUP BY
	|	Table.RecordType,
	|	Table.Period,
	|	Table.Recorder,
	|	Table.Company,
	|	Table.PresentationCurrency,
	|	Table.Products,
	|	Table.Characteristic,
	|	Table.Batch,
	|	Table.Ownership,
	|	Table.StructuralUnit,
	|	Table.GLAccount,
	|	Table.CorrGLAccount,
	|	Table.VATRate,
	|	Table.Responsible,
	|	Table.Department,
	|	Table.SalesOrder,
	|	Table.StructuralUnitCorr,
	|	Table.SourceDocument,
	|	Table.RetailTransferEarningAccounting,
	|	Table.SalesRep,
	|	Table.Counterparty,
	|	Table.Currency,
	|	Table.CostObject,
	|	Table.CostObjectCorr,
	|	Table.ProductsCorr,
	|	Table.CharacteristicCorr,
	|	Table.BatchCorr,
	|	Table.OwnershipCorr,
	|	Table.SpecificationCorr,
	|	Table.Specification,
	|	Table.InventoryAccountType,
	|	Table.CorrInventoryAccountType,
	|	Table.IncomeAndExpenseItem,
	|	Table.CorrIncomeAndExpenseItem
	|
	|UNION ALL
	|
	|SELECT
	|	""IntraCommunityTransfers"",
	|	97,
	|	""IntraTransfer"",
	|	FALSE,
	|	Table.RecordType,
	|	Table.Period,
	|	Table.Recorder,
	|	Table.Company,
	|	Table.PresentationCurrency,
	|	Table.Products,
	|	Table.Characteristic,
	|	UNDEFINED,
	|	Table.Batch,
	|	Table.Ownership,
	|	Table.StructuralUnit,
	|	Table.GLAccount,
	|	Table.SalesOrder,
	|	0,
	|	SUM(Table.Quantity),
	|	0,
	|	Table.SourceDocument,
	|	Table.StructuralUnitCorr,
	|	UNDEFINED,
	|	Table.CorrGLAccount,
	|	Table.VATRate,
	|	Table.Responsible,
	|	UNDEFINED,
	|	FALSE,
	|	Table.RetailTransferEarningAccounting,
	|	Table.SalesRep,
	|	Table.Counterparty,
	|	Table.Currency,
	|	Table.CostObject,
	|	Table.CostObjectCorr,
	|	Table.ProductsCorr,
	|	Table.CharacteristicCorr,
	|	Table.BatchCorr,
	|	Table.OwnershipCorr,
	|	Table.SpecificationCorr,
	|	Table.Specification,
	|	Table.InventoryAccountType,
	|	Table.CorrInventoryAccountType,
	|	Table.IncomeAndExpenseItem,
	|	Table.CorrIncomeAndExpenseItem
	|FROM
	|	AccumulationRegister.Inventory AS Table
	|WHERE
	|	Table.Period BETWEEN &BeginOfPeriod AND &EndOfPeriod
	|	AND Table.Company IN(&ArrayOfCompanies)
	|	AND Table.Active
	|	AND Table.RecordType = VALUE(AccumulationRecordType.Receipt)
	|	AND Table.Quantity > 0
	|	AND VALUETYPE(Table.Recorder) = VALUE(Document.GoodsReceipt)
	|	AND Table.StructuralUnitCorr = VALUE(Catalog.BusinessUnits.GoodsInTransit)
	|
	|GROUP BY
	|	Table.RecordType,
	|	Table.Period,
	|	Table.Recorder,
	|	Table.Company,
	|	Table.PresentationCurrency,
	|	Table.Products,
	|	Table.Characteristic,
	|	Table.Batch,
	|	Table.Ownership,
	|	Table.StructuralUnit,
	|	Table.GLAccount,
	|	Table.CorrGLAccount,
	|	Table.VATRate,
	|	Table.Responsible,
	|	Table.Department,
	|	Table.SalesOrder,
	|	Table.StructuralUnitCorr,
	|	Table.SourceDocument,
	|	Table.RetailTransferEarningAccounting,
	|	Table.SalesRep,
	|	Table.Counterparty,
	|	Table.Currency,
	|	Table.CostObject,
	|	Table.CostObjectCorr,
	|	Table.ProductsCorr,
	|	Table.CharacteristicCorr,
	|	Table.BatchCorr,
	|	Table.OwnershipCorr,
	|	Table.SpecificationCorr,
	|	Table.Specification,
	|	Table.InventoryAccountType,
	|	Table.CorrInventoryAccountType,
	|	Table.IncomeAndExpenseItem,
	|	Table.CorrIncomeAndExpenseItem
	|";
	
EndFunction

// begin Drive.FullVersion
Function TextOfWorkInProgressReceipt()
	
	Return "
	|	SELECT
	|	""WorkInProgressReceipt"" AS QueryName,
	|	90 AS Priority,
	|	""WIP"" AS RecordKind,
	|	FALSE AS FinishCalculation,
	|	Table.RecordType AS RecordType,
	|	Table.Period AS Period,
	|	Table.Recorder AS Recorder,
	|	Table.Company AS Company,
	|	Table.PresentationCurrency AS PresentationCurrency,
	|	Table.Products AS Products,
	|	Table.Characteristic AS Characteristic,
	|	UNDEFINED AS CostLayer,
	|	Table.Batch AS Batch,
	|	Table.Ownership AS Ownership,
	|	Table.StructuralUnit AS StructuralUnit,
	|	Table.GLAccount AS GLAccount,
	|	Table.SalesOrder AS SalesOrder,
	|	0 AS Denominator,
	|	SUM(Table.Quantity) AS Quantity,
	|	0 AS Amount,
	|	Table.Recorder AS SourceDocument,
	|	VALUE(Catalog.BusinessUnits.EmptyRef) AS CorrStructuralUnit,
	|	UNDEFINED AS CorrSalesOrder,
	|	Table.CorrGLAccount AS CorrGLAccount,
	|	Table.VATRate AS VATRate,
	|	Table.Responsible AS Responsible,
	|	Table.Department AS Department,
	|	FALSE AS SourceRecord,
	|	Table.RetailTransferEarningAccounting AS RIMTransfer,
	|	Table.SalesRep AS SalesRep,
	|	Table.Counterparty AS Counterparty,
	|	Table.Currency AS Currency,
	|	Table.CostObject,
	|	Table.CostObjectCorr,
	|	Table.ProductsCorr,
	|	Table.CharacteristicCorr,
	|	Table.BatchCorr,
	|	Table.OwnershipCorr,
	|	Table.SpecificationCorr,
	|	Table.Specification,
	|	Table.InventoryAccountType,
	|	Table.CorrInventoryAccountType,
	|	Table.IncomeAndExpenseItem,
	|	Table.CorrIncomeAndExpenseItem
	|FROM
	|	AccumulationRegister.Inventory AS Table
	|WHERE
	|	Table.Period BETWEEN &BeginOfPeriod AND &EndOfPeriod
	|	AND Table.Company IN(&ArrayOfCompanies)
	|	AND Table.Active
	|	AND Table.RecordType = VALUE(AccumulationRecordType.Receipt)
	|	AND Table.Quantity > 0
	|	AND VALUETYPE(Table.Recorder) = TYPE(Document.ManufacturingOperation)
	|	AND VALUETYPE(Table.Products) = TYPE(Catalog.Products)
	|
	|GROUP BY
	|	Table.RecordType,
	|	Table.Period,
	|	Table.Recorder,
	|	Table.Company,
	|	Table.PresentationCurrency,
	|	Table.Products,
	|	Table.Characteristic,
	|	Table.Batch,
	|	Table.Ownership,
	|	Table.StructuralUnit,
	|	Table.GLAccount,
	|	Table.CorrGLAccount,
	|	Table.VATRate,
	|	Table.Responsible,
	|	Table.Department,
	|	Table.SalesOrder,
	|	Table.RetailTransferEarningAccounting,
	|	Table.SalesRep,
	|	Table.Counterparty,
	|	Table.Currency,
	|	Table.CostObject,
	|	Table.CostObjectCorr,
	|	Table.ProductsCorr,
	|	Table.CharacteristicCorr,
	|	Table.BatchCorr,
	|	Table.OwnershipCorr,
	|	Table.SpecificationCorr,
	|	Table.Specification,
	|	Table.InventoryAccountType,
	|	Table.CorrInventoryAccountType,
	|	Table.IncomeAndExpenseItem,
	|	Table.CorrIncomeAndExpenseItem
	|";
	
EndFunction

Function TextOfProductionReceipt()
	
	Return "
	|	SELECT
	|	""ProductionReceipt"" AS QueryName,
	|	90 AS Priority,
	|	""Production"" AS RecordKind,
	|	FALSE AS FinishCalculation,
	|	Table.RecordType AS RecordType,
	|	Table.Period AS Period,
	|	Table.Recorder AS Recorder,
	|	Table.Company AS Company,
	|	Table.PresentationCurrency AS PresentationCurrency,
	|	Table.Products AS Products,
	|	Table.Characteristic AS Characteristic,
	|	UNDEFINED AS CostLayer,
	|	Table.Batch AS Batch,
	|	Table.Ownership AS Ownership,
	|	Table.StructuralUnit AS StructuralUnit,
	|	Table.GLAccount AS GLAccount,
	|	Table.SalesOrder AS SalesOrder,
	|	0 AS Denominator,
	|	SUM(Table.Quantity) AS Quantity,
	|	0 AS Amount,
	|	Table.Recorder AS SourceDocument,
	|	VALUE(Catalog.BusinessUnits.EmptyRef) AS CorrStructuralUnit,
	|	UNDEFINED AS CorrSalesOrder,
	|	Table.CorrGLAccount AS CorrGLAccount,
	|	Table.VATRate AS VATRate,
	|	Table.Responsible AS Responsible,
	|	Table.Department AS Department,
	|	FALSE AS SourceRecord,
	|	Table.RetailTransferEarningAccounting AS RIMTransfer,
	|	Table.SalesRep AS SalesRep,
	|	Table.Counterparty AS Counterparty,
	|	Table.Currency AS Currency,
	|	Table.CostObject AS CostObject,
	|	Table.CostObjectCorr AS CostObjectCorr,
	|	Table.ProductsCorr AS ProductsCorr,
	|	Table.CharacteristicCorr AS CharacteristicCorr,
	|	Table.BatchCorr AS BatchCorr,
	|	Table.OwnershipCorr AS OwnershipCorr,
	|	Table.SpecificationCorr,
	|	Table.Specification,
	|	Table.InventoryAccountType,
	|	Table.CorrInventoryAccountType,
	|	Table.IncomeAndExpenseItem,
	|	Table.CorrIncomeAndExpenseItem
	|FROM
	|	AccumulationRegister.Inventory AS Table
	|		INNER JOIN AccumulationRegister.ProductRelease AS ProductRelease
	|		ON Table.Recorder = ProductRelease.Recorder
	|			AND Table.Company = ProductRelease.Company
	|			AND Table.StructuralUnit = ProductRelease.StructuralUnit
	|			AND Table.Products = ProductRelease.Products
	|			AND Table.Characteristic = ProductRelease.Characteristic
	|			AND Table.Batch = ProductRelease.Batch
	|			AND Table.Ownership = ProductRelease.Ownership
	|			AND Table.SalesOrder = ProductRelease.SalesOrder
	|WHERE
	|	Table.Period BETWEEN &BeginOfPeriod AND &EndOfPeriod
	|	AND Table.Company IN(&ArrayOfCompanies)
	|	AND Table.Active
	|	AND Table.RecordType = VALUE(AccumulationRecordType.Receipt)
	|	AND Table.Quantity > 0
	|
	|GROUP BY
	|	Table.RecordType,
	|	Table.Period,
	|	Table.Recorder,
	|	Table.Company,
	|	Table.PresentationCurrency,
	|	Table.Products,
	|	Table.Characteristic,
	|	Table.Batch,
	|	Table.Ownership,
	|	Table.StructuralUnit,
	|	Table.GLAccount,
	|	Table.CorrGLAccount,
	|	Table.VATRate,
	|	Table.Responsible,
	|	Table.Department,
	|	Table.SalesOrder,
	|	Table.RetailTransferEarningAccounting,
	|	Table.SalesRep,
	|	Table.Counterparty,
	|	Table.Currency,
	|	Table.SpecificationCorr,
	|	Table.CostObject,
	|	Table.CostObjectCorr,
	|	Table.ProductsCorr,
	|	Table.CharacteristicCorr,
	|	Table.BatchCorr,
	|	Table.OwnershipCorr,
	|	Table.SpecificationCorr,
	|	Table.Specification,
	|	Table.InventoryAccountType,
	|	Table.CorrInventoryAccountType,
	|	Table.IncomeAndExpenseItem,
	|	Table.CorrIncomeAndExpenseItem
	|	";
	
EndFunction
// end Drive.FullVersion

Function TextOfKitProcessingReceipt()
	
	Return "
	|	SELECT
	|	""KitProcessingReceipt"" AS QueryName,
	|	90 AS Priority,
	|	""KitProcessing"" AS RecordKind,
	|	FALSE AS FinishCalculation,
	|	Table.RecordType AS RecordType,
	|	Table.Period AS Period,
	|	Table.Recorder AS Recorder,
	|	Table.Company AS Company,
	|	Table.PresentationCurrency AS PresentationCurrency,
	|	Table.Products AS Products,
	|	Table.Characteristic AS Characteristic,
	|	UNDEFINED AS CostLayer,
	|	Table.Batch AS Batch,
	|	Table.Ownership AS Ownership,
	|	Table.StructuralUnit AS StructuralUnit,
	|	Table.GLAccount AS GLAccount,
	|	Table.SalesOrder AS SalesOrder,
	|	0 AS Denominator,
	|	SUM(Table.Quantity) AS Quantity,
	|	0 AS Amount,
	|	Table.Recorder AS SourceDocument,
	|	VALUE(Catalog.BusinessUnits.EmptyRef) AS CorrStructuralUnit,
	|	UNDEFINED AS CorrSalesOrder,
	|	Table.CorrGLAccount AS CorrGLAccount,
	|	Table.VATRate AS VATRate,
	|	Table.Responsible AS Responsible,
	|	Table.Department AS Department,
	|	FALSE AS SourceRecord,
	|	Table.RetailTransferEarningAccounting AS RIMTransfer,
	|	Table.SalesRep AS SalesRep,
	|	Table.Counterparty AS Counterparty,
	|	Table.Currency AS Currency,
	|	Table.CostObject,
	|	Table.CostObjectCorr,
	|	Table.ProductsCorr,
	|	Table.CharacteristicCorr,
	|	Table.BatchCorr,
	|	Table.OwnershipCorr,
	|	Table.SpecificationCorr,
	|	Table.Specification,
	|	Table.InventoryAccountType,
	|	Table.CorrInventoryAccountType,
	|	Table.IncomeAndExpenseItem,
	|	Table.CorrIncomeAndExpenseItem
	|FROM
	|	AccumulationRegister.Inventory AS Table
	|		INNER JOIN Document.Production AS Production
	|		ON Table.Recorder = Production.Ref
	|WHERE
	|	Table.Period BETWEEN &BeginOfPeriod AND &EndOfPeriod
	|	AND Table.Company IN(&ArrayOfCompanies)
	|	AND Table.Active
	|	AND Table.RecordType = VALUE(AccumulationRecordType.Receipt)
	|	AND Table.Quantity > 0
	|
	|GROUP BY
	|	Table.RecordType,
	|	Table.Period,
	|	Table.Recorder,
	|	Table.Company,
	|	Table.PresentationCurrency,
	|	Table.Products,
	|	Table.Characteristic,
	|	Table.Batch,
	|	Table.Ownership,
	|	Table.StructuralUnit,
	|	Table.GLAccount,
	|	Table.CorrGLAccount,
	|	Table.VATRate,
	|	Table.Responsible,
	|	Table.Department,
	|	Table.SalesOrder,
	|	Table.RetailTransferEarningAccounting,
	|	Table.SalesRep,
	|	Table.Counterparty,
	|	Table.Currency,
	|	Table.CostObject,
	|	Table.CostObjectCorr,
	|	Table.ProductsCorr,
	|	Table.CharacteristicCorr,
	|	Table.BatchCorr,
	|	Table.OwnershipCorr,
	|	Table.SpecificationCorr,
	|	Table.Specification,
	|	Table.InventoryAccountType,
	|	Table.CorrInventoryAccountType,
	|	Table.IncomeAndExpenseItem,
	|	Table.CorrIncomeAndExpenseItem
	|	";
	
EndFunction

#EndRegion

#EndRegion

#Region LandedCosts

Procedure CalculateLandedCosts(BeginOfPeriod, EndOfOfPeriod, ArrayOfCompanies)
	
	RegisterName = Metadata.AccumulationRegisters.LandedCosts.Name;
	
	StartAt = CurrentUniversalDateInMilliseconds();
	
	DataForLandedCosts = DataForLandedCosts(BeginOfPeriod, EndOfOfPeriod, ArrayOfCompanies);
	
	ArrayOfExcludedTypes = New Array;
	ArrayOfExcludedTypes.Add(Type("DocumentRef.RegistersCorrection"));
	
	Recorders = Recorders(BeginOfPeriod, EndOfOfPeriod, ArrayOfCompanies, RegisterName, ArrayOfExcludedTypes);
	
	LandedCosts = CalculateLandedCostsLayers(DataForLandedCosts, Recorders);
	
	WriteCostsLayers(AccumulationRegisters[RegisterName], LandedCosts, Recorders);
	ClearRegister(Recorders, RegisterName);
	
	DataForLandedCosts.Close();
	LandedCosts = Undefined;
	
EndProcedure

Function DataForLandedCosts(BeginOfPeriod, EndOfOfPeriod, ArrayOfCompanies)
	
	OrderText = "
		|ORDER BY
		|	Products, Period, Priority ASC, Company, Recorder
		|";
	
	IndexText = "
		|INDEX BY
		|	Products
		|";
	
	QueryText =
		TextInitializationOfLandedCosts() + ";" // it returns common temp tables
		+ TextOfDescriptionLandedCosts()
		+ "UNION ALL" + TextOfLandedCostsBalance() // use PreviousPeriods
		+ "UNION ALL" + TextOfSourceLandedCosts() // use InventoryRecords
		+ "UNION ALL" + TextOfSubcontractingComponentsLandedCosts() // use InventoryRecords
		+ "UNION ALL" + TextOfLandedCostsSalesInPreviousPeriods() // use SourceDocuments
		+ "UNION ALL" + TextOfConsumptionsLandedCosts() 
		+ "UNION ALL" + TextOfTransfersLandedCostsReceipt()
		+ "UNION ALL" + TextOfReversalLandedCosts()
		+ "UNION ALL" + TextOfIntraCommunityTransfersLandedCosts()
		// begin Drive.FullVersion
		+ "UNION ALL" + TextOfWorkInProgressReceiptLandedCosts()
		+ "UNION ALL" + TextOfProductionReceiptLandedCosts()
		// end Drive.FullVersion
		+ "UNION ALL" + TextOfKitProcessingReceiptLandedCosts()
		+ "UNION ALL" + TextOfSubcontractingReceiptLandedCosts()
		+ IndexText;
		
	TempTables = New TempTablesManager;
	
	SourceQuery = New Query(StrReplace(QueryText, "//UseTempTable", ""));
	SourceQuery.SetParameter("BeginOfPeriod", BeginOfPeriod);
	SourceQuery.SetParameter("EndOfPeriod", EndOfOfPeriod);
	SourceQuery.SetParameter("ArrayOfCompanies", ArrayOfCompanies);
	SourceQuery.TempTablesManager = TempTables;
	SourceQuery.Execute();
	
	NamesOfTempTables = "PreviousPeriods, InventoryRecords,
		| LandedCostsBalance, SourceDocuments,
		| LandedCostsInCurrentPeriod,
		| CountOfLandedCosts
		|";
		
	DeleteTempTables(SourceQuery, NamesOfTempTables);
	
	Query = New Query(TextOfDescriptionLandedCosts());
	LandedCosts = Query.Execute().Unload();
	
	TempTableOnFilter("Product", OrderText, LandedCosts, TempTables);
	
	Return TempTables;
	
EndFunction

Function CalculateLandedCostsLayers(DataForLandedCostsLayers, Recorders, RecordsChains = Undefined)
	
	Query = New Query(TextOfDescriptionLandedCosts());
	LandedCosts = Query.Execute().Unload();
	
	TypesOfChains = DescriptionOfChains("Balance, LandedCosts, Consumption, Reversal, Transfer,
		|PreviousPeriods, IntraTransfer, ConsumptionIntraTransfer, Production, WIP, KitProcessing, Subcontracting");
	
	ConsumptionFields = "Company, PresentationCurrency, StructuralUnit, InventoryAccountType, Products,
		|Characteristic, Batch, Ownership, CostLayer, CostObject";
	
	RecordsContext = New Structure();
	RecordsContext.Insert("Context",           "LandedCosts");
	RecordsContext.Insert("RegisterName",      "LandedCosts");
	RecordsContext.Insert("CalculationFields",  ListOfFields(LandedCosts.Columns));
	RecordsContext.Insert("ConsumptionFields",  ConsumptionFields);
	RecordsContext.Insert("Indicators",        "Denominator, Quantity, Amount");
	RecordsContext.Insert("ReceiptField",      "Quantity");
	RecordsContext.Insert("ExpenseField",      "TotalQuantity");
	RecordsContext.Insert("ExpenseKey",        "SourceDocument");
	RecordsContext.Insert("OrderField",        "Period");
	RecordsContext.Insert("SortField",         "CostLayer");
	RecordsContext.Insert("UseSort",            True);
	RecordsContext.Insert("SumFields",          "Denominator, Quantity, Amount");
	RecordsContext.Insert("GroupingFields",     ListOfFields(LandedCosts.Columns, RecordsContext.SumFields));
	
	AddReceiptDescription(TypesOfChains, "Consumption", ConsumptionFields);
	AddSourceDescription(TypesOfChains,  "Consumption", "Balance", ConsumptionFields);
	AddSourceDescription(TypesOfChains,  "Consumption", "LandedCosts", ConsumptionFields);
	AddSourceDescription(TypesOfChains,  "Consumption", "Transfer", ConsumptionFields);
	AddSourceDescription(TypesOfChains,  "Consumption", "Reversal", ConsumptionFields);
	AddSourceDescription(TypesOfChains,  "Consumption", "IntraTransfer", ConsumptionFields);
	AddSourceDescription(TypesOfChains,  "Consumption", "KitProcessing", ConsumptionFields);
	AddSourceDescription(TypesOfChains,  "Consumption", "WIP", ConsumptionFields);
	AddSourceDescription(TypesOfChains,  "Consumption", "Production", ConsumptionFields);
	AddSourceDescription(TypesOfChains,  "Consumption", "Subcontracting", ConsumptionFields);
	
	AddReceiptDescription(TypesOfChains, "Transfer", "SourceDocument, Company, PresentationCurrency, StructuralUnit,
		|InventoryAccountType, Products, Characteristic, Batch, Ownership, CostLayer");
	AddSourceDescription(TypesOfChains, "Transfer", "Consumption", "Recorder, Company, PresentationCurrency, CorrStructuralUnit,
		|CorrInventoryAccountType, Products, Characteristic, Batch, Ownership, CostLayer");
	
	AddReceiptDescription(TypesOfChains, "Reversal", "SourceDocument, Company, PresentationCurrency,
		|InventoryAccountType, Products, Characteristic, Batch, Ownership, CostLayer");
	AddSourceDescription(TypesOfChains,  "Reversal", "Consumption", "SourceDocument, Company, PresentationCurrency,
		|InventoryAccountType, Products, Characteristic, Batch, Ownership, CostLayer");
	AddSourceDescription(TypesOfChains,  "Reversal", "PreviousPeriods", "SourceDocument, Company, PresentationCurrency,
		|InventoryAccountType, Products, Characteristic, Batch, Ownership, CostLayer");
	
	AddReceiptDescription(TypesOfChains, "ConsumptionIntraTransfer", "SourceDocument, Company, PresentationCurrency, StructuralUnit,
		|InventoryAccountType, Products, Characteristic, Batch, Ownership");
	AddSourceDescription(TypesOfChains, "ConsumptionIntraTransfer", "Transfer", "Recorder, Company, PresentationCurrency, StructuralUnit,
		|InventoryAccountType, Products, Characteristic, Batch, Ownership");
	
	AddReceiptDescription(TypesOfChains, "IntraTransfer", "SourceDocument, Company, PresentationCurrency, CorrStructuralUnit,
		|CorrInventoryAccountType, Products, Characteristic, Batch, Ownership");
	AddSourceDescription(TypesOfChains, "IntraTransfer", "ConsumptionIntraTransfer", "Recorder, Company, PresentationCurrency, StructuralUnit,
		|InventoryAccountType, Products, Characteristic, Batch, Ownership");
	
	// Component income to WIP account
	AddReceiptDescription(TypesOfChains, "WIP", "SourceDocument, Company, PresentationCurrency, StructuralUnit,
		|InventoryAccountType, Products, Characteristic, Ownership, CostObject");
	// Component expence from Inventry account
	AddSourceDescription(TypesOfChains, "WIP", "Consumption", "Recorder, Company, PresentationCurrency, CorrStructuralUnit,
		|CorrInventoryAccountType, Products, Characteristic, Ownership, CorrCostObject");
	
	// Finished product income to Inventry account
	AddReceiptDescription(TypesOfChains, "Production", "SourceDocument, Company, PresentationCurrency, StructuralUnit,
		|InventoryAccountType, Products, Characteristic, Batch, Ownership");
	// Component expence from WIP account
	AddSourceDescription(TypesOfChains, "Production", "Consumption", "Recorder, Company, PresentationCurrency, CorrStructuralUnit,
		|CorrInventoryAccountType, CorrProducts, CorrCharacteristic, CorrBatch, CorrOwnership");
	
	AddReceiptDescription(TypesOfChains, "KitProcessing", "SourceDocument, Company, PresentationCurrency, StructuralUnit,
		|InventoryAccountType, Products, Characteristic, Batch, Ownership");
	AddSourceDescription(TypesOfChains, "KitProcessing", "Consumption", "Recorder, Company, PresentationCurrency, CorrStructuralUnit,
		|CorrInventoryAccountType, CorrProducts, CorrCharacteristic, CorrBatch, CorrOwnership");
	
	// Finished product income
	AddReceiptDescription(TypesOfChains, "Subcontracting", "SourceDocument, Company, PresentationCurrency, StructuralUnit,
		|InventoryAccountType, Products, Characteristic, Batch, Ownership");
	// Component expence
	AddSourceDescription(TypesOfChains, "Subcontracting", "Consumption", "Recorder, Company, PresentationCurrency, CorrStructuralUnit,
		|CorrInventoryAccountType, CorrProducts, CorrCharacteristic, CorrBatch, CorrOwnership");
	
	GetChains(TypesOfChains, DataForLandedCostsLayers);
	CalculateCostsLayersByChains(RecordsContext, DataForLandedCostsLayers, LandedCosts, Recorders);
	RecordsChains = DataForLandedCostsLayers;
	
	DeleteUnrecordedLines(RecordsContext.Context, LandedCosts);
	
	LandedCosts.Sort("Recorder, Priority", New CompareValues);
	
	Return LandedCosts;
EndFunction

#Region QueryTexts

Function TextInitializationOfLandedCosts()
	
	Return "
	|SELECT ALLOWED
	|	InventoryBalance.Company AS Company,
	|	InventoryBalance.PresentationCurrency AS PresentationCurrency,
	|	InventoryBalance.Products AS Products,
	|	InventoryBalance.CostLayer AS CostLayer,
	|	InventoryBalance.Characteristic AS Characteristic,
	|	InventoryBalance.Batch AS Batch,
	|	InventoryBalance.Ownership AS Ownership,
	|	InventoryBalance.StructuralUnit AS StructuralUnit,
	|	InventoryBalance.InventoryAccountType AS InventoryAccountType,
	|	InventoryBalance.CostObject AS CostObject,
	|	InventoryBalance.QuantityBalance AS Quantity
	|INTO InventoryRecordsNotGrouped
	|FROM
	|	AccumulationRegister.InventoryCostLayer.Balance(&BeginOfPeriod, Company IN (&ArrayOfCompanies)) AS InventoryBalance
	|WHERE
	|	InventoryBalance.Company IN(&ArrayOfCompanies)
	|
	|UNION ALL
	|
	|SELECT
	|	Inventory.Company,
	|	Inventory.PresentationCurrency,
	|	Inventory.Products,
	|	Inventory.CostLayer,
	|	Inventory.Characteristic,
	|	Inventory.Batch,
	|	Inventory.Ownership,
	|	Inventory.StructuralUnit,
	|	Inventory.InventoryAccountType,
	|	Inventory.CostObject,
	|	SUM(Inventory.Quantity)
	|FROM
	|	AccumulationRegister.InventoryCostLayer AS Inventory
	|WHERE
	|	Inventory.Period BETWEEN &BeginOfPeriod AND &EndOfPeriod
	|	AND Inventory.Company IN(&ArrayOfCompanies)
	|	AND Inventory.SourceRecord
	|	AND Inventory.Active
	|
	|GROUP BY
	|	Inventory.Period,
	|	Inventory.Recorder,
	|	Inventory.Company,
	|	Inventory.Products,
	|	Inventory.CostLayer,
	|	Inventory.Characteristic,
	|	Inventory.Batch,
	|	Inventory.Ownership,
	|	Inventory.StructuralUnit,
	|	Inventory.InventoryAccountType,
	|	Inventory.CostObject,
	|	Inventory.PresentationCurrency
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	InventoryRecordsNotGrouped.Company AS Company,
	|	InventoryRecordsNotGrouped.PresentationCurrency AS PresentationCurrency,
	|	InventoryRecordsNotGrouped.Products AS Products,
	|	InventoryRecordsNotGrouped.CostLayer AS CostLayer,
	|	InventoryRecordsNotGrouped.Characteristic AS Characteristic,
	|	InventoryRecordsNotGrouped.Batch AS Batch,
	|	InventoryRecordsNotGrouped.Ownership AS Ownership,
	|	InventoryRecordsNotGrouped.StructuralUnit AS StructuralUnit,
	|	InventoryRecordsNotGrouped.InventoryAccountType AS InventoryAccountType,
	|	InventoryRecordsNotGrouped.CostObject AS CostObject,
	|	SUM(InventoryRecordsNotGrouped.Quantity) AS Quantity
	|INTO InventoryRecords
	|FROM
	|	InventoryRecordsNotGrouped AS InventoryRecordsNotGrouped
	|
	|GROUP BY
	|	InventoryRecordsNotGrouped.Company,
	|	InventoryRecordsNotGrouped.Products,
	|	InventoryRecordsNotGrouped.CostLayer,
	|	InventoryRecordsNotGrouped.Batch,
	|	InventoryRecordsNotGrouped.PresentationCurrency,
	|	InventoryRecordsNotGrouped.Ownership,
	|	InventoryRecordsNotGrouped.Characteristic,
	|	InventoryRecordsNotGrouped.CostObject,
	|	InventoryRecordsNotGrouped.StructuralUnit,
	|	InventoryRecordsNotGrouped.InventoryAccountType
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	Table.CostLayer AS Recorder,
	|	Table.Company AS Company,
	|	Table.PresentationCurrency AS PresentationCurrency,
	|	Table.Products AS Products,
	|	Table.Characteristic AS Characteristic,
	|	Table.CostLayer AS CostLayer,
	|	Table.Batch AS Batch,
	|	Table.Ownership AS Ownership,
	|	Table.StructuralUnit AS StructuralUnit,
	|	Table.InventoryAccountType AS InventoryAccountType,
	|	Table.CostObject AS CostObject,
	|	ISNULL(InventoryRecords.Quantity, 0) AS Quantity,
	|	Table.AmountBalance AS Amount
	|INTO LandedCostsBalance
	|FROM
	|	AccumulationRegister.LandedCosts.Balance(&BeginOfPeriod, Company IN (&ArrayOfCompanies)) AS Table
	|		LEFT JOIN InventoryRecords AS InventoryRecords
	|		ON Table.Company = InventoryRecords.Company
	|			AND Table.Products = InventoryRecords.Products
	|			AND Table.CostLayer = InventoryRecords.CostLayer
	|			AND Table.Characteristic = InventoryRecords.Characteristic
	|			AND Table.Batch = InventoryRecords.Batch
	|			AND Table.Ownership = InventoryRecords.Ownership
	|			AND Table.StructuralUnit = InventoryRecords.StructuralUnit
	|			AND Table.CostObject = InventoryRecords.CostObject
	|			AND Table.PresentationCurrency = InventoryRecords.PresentationCurrency
	|			AND Table.InventoryAccountType = InventoryRecords.InventoryAccountType
	|WHERE
	|	Table.AmountBalance > 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED DISTINCT
	|	LandedCostsTable.CostLayer AS CostLayer,
	|	MAX(PreviousPeriods.Period) AS Period
	|INTO PreviousPeriods
	|FROM
	|	LandedCostsBalance AS LandedCostsTable
	|		INNER JOIN AccumulationRegister.InventoryInWarehouses AS PreviousPeriods
	|		ON (PreviousPeriods.Period < &BeginOfPeriod)
	|			AND (PreviousPeriods.Recorder = LandedCostsTable.CostLayer)
	|WHERE
	|	LandedCostsTable.CostLayer <> UNDEFINED
	|
	|GROUP BY
	|	LandedCostsTable.CostLayer
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED DISTINCT
	|	Table.SourceDocument AS Recorder,
	|	Table.Company AS Company,
	|	Table.PresentationCurrency AS PresentationCurrency,
	|	Table.Products AS Products,
	|	Table.Characteristic AS Characteristic,
	|	Table.Batch AS Batch,
	|	Table.Ownership AS Ownership,
	|	Table.InventoryAccountType AS InventoryAccountType,
	|	Table.GLAccount AS GLAccount,
	|	Table.CostObject AS CostObject,
	|	Table.CorrGLAccount AS CorrGLAccount,
	|	Table.CorrInventoryAccountType AS CorrInventoryAccountType,
	|	Table.CostLayer AS CostLayer
	|INTO SourceDocuments
	|FROM
	|	AccumulationRegister.InventoryCostLayer AS Table
	|WHERE
	|	Table.Period BETWEEN &BeginOfPeriod AND &EndOfPeriod
	|	AND Table.Company IN(&ArrayOfCompanies)
	|	AND Table.Active
	|	AND Table.SourceDocument <> UNDEFINED
	|	AND Table.SourceDocument <> Table.Recorder
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED DISTINCT
	|	Table.CostLayer AS CostLayer,
	|	Table.Recorder AS Recorder,
	|	1 AS Number
	|INTO LandedCostsInCurrentPeriod
	|FROM
	|	AccumulationRegister.LandedCosts AS Table
	|WHERE
	|	Table.Period BETWEEN &BeginOfPeriod AND &EndOfPeriod
	|	AND Table.Company IN(&ArrayOfCompanies)
	|	AND Table.RecordType = VALUE(AccumulationRecordType.Receipt)
	|	AND Table.SourceRecord
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Table.CostLayer AS CostLayer,
	|	SUM(Table.Number) AS Count
	|INTO CountOfLandedCosts
	|FROM
	|	LandedCostsInCurrentPeriod AS Table
	|
	|GROUP BY
	|	Table.CostLayer
	|";

EndFunction

Function TextOfDescriptionLandedCosts()
	
	Return "
	|SELECT ALLOWED TOP 0
	|	CAST ("""" AS STRING(80)) AS QueryName,
	|	0 AS Priority,
	|	""XXXXXXXXXXXXXXXXXXX"" AS RecordKind,
	|	FALSE AS FinishCalculation,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DATETIME(1, 1, 1, 0, 0, 0) AS Period,
	|	Table.Recorder AS Recorder,
	|	Table.Company AS Company,
	|	Table.PresentationCurrency AS PresentationCurrency,
	|	Table.Products AS Products,
	|	Table.Characteristic AS Characteristic,
	|	Table.CostLayer AS CostLayer,
	|	Table.Batch AS Batch,
	|	Table.Ownership AS Ownership,
	|	Table.StructuralUnit AS StructuralUnit,
	|	Table.InventoryAccountType AS InventoryAccountType,
	|	UNDEFINED AS SalesOrder,
	|	0 AS Denominator,
	|	0 AS Quantity,
	|	0 AS TotalQuantity,
	|	0 AS Amount,
	|	UNDEFINED AS SourceDocument,
	|	UNDEFINED AS CorrStructuralUnit,
	|	UNDEFINED AS CorrSalesOrder,
	|	Table.GLAccount AS GLAccount,
	|	Table.CorrGLAccount AS CorrGLAccount,
	|	VALUE(Enum.InventoryAccountTypes.EmptyRef) AS CorrInventoryAccountType,
	|	VALUE(Catalog.VATRates.EmptyRef) AS VATRate,
	|	VALUE(Catalog.Employees.EmptyRef) AS Responsible,
	|	VALUE(Catalog.BusinessUnits.EmptyRef) AS Department,
	|	FALSE AS SourceRecord,
	|	FALSE AS RIMTransfer,
	|	VALUE(Catalog.Employees.EmptyRef) AS SalesRep,
	|	VALUE(Catalog.Counterparties.EmptyRef) AS Counterparty,
	|	VALUE(Catalog.Currencies.EmptyRef) AS Currency,
	|	VALUE(Catalog.CostObjects.EmptyRef) AS CostObject,
	|	VALUE(Catalog.CostObjects.EmptyRef) AS CorrCostObject,
	|	UNDEFINED AS CorrProducts,
	|	VALUE(Catalog.ProductsCharacteristics.EmptyRef) AS CorrCharacteristic,
	|	VALUE(Catalog.ProductsBatches.EmptyRef) AS CorrBatch,
	|	VALUE(Catalog.InventoryOwnership.EmptyRef) AS CorrOwnership,
	|	VALUE(Catalog.BillsOfMaterials.EmptyRef) AS CorrSpecification,
	|	VALUE(Catalog.BillsOfMaterials.EmptyRef) AS Specification,
	|	Table.IncomeAndExpenseItem AS IncomeAndExpenseItem,
	|	Table.CorrIncomeAndExpenseItem AS CorrIncomeAndExpenseItem
	|//UseTempTable INTO SourceData
	|FROM
	|	AccumulationRegister.LandedCosts AS Table
	|";
	
EndFunction

Function TextOfLandedCostsBalance()
	
	Return "
	|SELECT
	|	""BalanceLandedCosts"" AS QueryName,
	|	10 AS Priority,
	|	""Balance"" AS RecordKind,
	|	TRUE AS FinishCalculation,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	ISNULL(PreviousPeriods.Period, &BeginOfPeriod) AS Period,
	|	Table.CostLayer AS Recorder,
	|	Table.Company AS Company,
	|	Table.PresentationCurrency AS PresentationCurrency,
	|	Table.Products AS Products,
	|	Table.Characteristic AS Characteristic,
	|	Table.CostLayer AS CostLayer,
	|	Table.Batch AS Batch,
	|	Table.Ownership AS Ownership,
	|	Table.StructuralUnit AS StructuralUnit,
	|	Table.InventoryAccountType AS InventoryAccountType,
	|	UNDEFINED AS SalesOrder,
	|	0 AS Denominator,
	|	Table.Quantity AS Quantity,
	|	Table.Quantity AS TotalQuantity,
	|	Table.Amount AS Amount,
	|	UNDEFINED AS SourceDocument,
	|	VALUE(Catalog.BusinessUnits.EmptyRef) AS CorrStructuralUnit,
	|	UNDEFINED AS CorrSalesOrder,
	|	VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef) AS GLAccount,
	|	VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef) AS CorrGLAccount,
	|	VALUE(Enum.InventoryAccountTypes.EmptyRef) AS CorrInventoryAccountType,
	|	VALUE(Catalog.VATRates.EmptyRef) AS VATRate,
	|	VALUE(Catalog.Employees.EmptyRef) AS Responsible,
	|	VALUE(Catalog.BusinessUnits.EmptyRef) AS Department,
	|	FALSE AS SourceRecord,
	|	FALSE AS RIMTransfer,
	|	VALUE(Catalog.Employees.EmptyRef) AS SalesRep,
	|	VALUE(Catalog.Counterparties.EmptyRef) AS Counterparty,
	|	VALUE(Catalog.Currencies.EmptyRef) AS SalesCurrencyRep,
	|	Table.CostObject AS CostObject,
	|	VALUE(Catalog.CostObjects.EmptyRef) AS CorrCostObject,
	|	UNDEFINED AS CorrProducts,
	|	VALUE(Catalog.ProductsCharacteristics.EmptyRef) AS CorrCharacteristic,
	|	VALUE(Catalog.ProductsBatches.EmptyRef) AS CorrBatch,
	|	VALUE(Catalog.InventoryOwnership.EmptyRef) AS CorrOwnership,
	|	VALUE(Catalog.BillsOfMaterials.EmptyRef) AS CorrSpecification,
	|	VALUE(Catalog.BillsOfMaterials.EmptyRef) AS Specification,
	|	VALUE(Catalog.IncomeAndExpenseItems.EmptyRef) AS IncomeAndExpenseItem,
	|	VALUE(Catalog.IncomeAndExpenseItems.EmptyRef) AS CorrIncomeAndExpenseItem
	|FROM
	|	LandedCostsBalance AS Table
	|		LEFT JOIN PreviousPeriods AS PreviousPeriods
	|		ON (PreviousPeriods.CostLayer = Table.CostLayer)
	|";
	
EndFunction

Function TextOfSourceLandedCosts()
	
	Return "
	|SELECT
	|	""SourceLandedCosts"" AS QueryName,
	|	10 AS Priority,
	|	""LandedCosts"" AS RecordKind,
	|	TRUE AS FinishCalculation,
	|	Table.RecordType AS RecordType,
	|	Table.Period AS Period,
	|	Table.Recorder AS Recorder,
	|	Table.Company AS Company,
	|	Table.PresentationCurrency AS PresentationCurrency,
	|	Table.Products AS Products,
	|	Table.Characteristic AS Characteristic,
	|	Table.CostLayer AS CostLayer,
	|	Table.Batch AS Batch,
	|	Table.Ownership AS Ownership,
	|	Table.StructuralUnit AS StructuralUnit,
	|	Table.InventoryAccountType AS InventoryAccountType,
	|	Table.SalesOrder AS SalesOrder,
	|	0 AS Denominator,
	|	SUM(ISNULL(Inventory.Quantity, 0)) AS Quantity,
	|	SUM(ISNULL(Inventory.Quantity, 0)) AS TotalQuantity,
	|	SUM(Table.Amount) AS Amount,
	|	UNDEFINED AS SourceDocument,
	|	Table.CorrStructuralUnit AS CorrStructuralUnit,
	|	UNDEFINED AS CorrSalesOrder,
	|	Table.GLAccount AS GLAccount,
	|	Table.CorrGLAccount AS CorrGLAccount,
	|	Table.CorrInventoryAccountType AS CorrInventoryAccountType,
	|	Table.VATRate AS VATRate,
	|	Table.Responsible AS Responsible,
	|	Table.Department AS Department,
	|	Table.SourceRecord AS SourceRecord,
	|	Table.RIMTransfer AS RIMTransfer,
	|	VALUE(Catalog.Employees.EmptyRef) AS SalesRep,
	|	VALUE(Catalog.Counterparties.EmptyRef) AS Counterparty,
	|	VALUE(Catalog.Currencies.EmptyRef) AS Currency,
	|	Table.CostObject AS CostObject,
	|	Table.CorrCostObject AS CorrCostObject,
	|	Table.CorrProducts AS CorrProducts,
	|	Table.CorrCharacteristic AS CorrCharacteristic,
	|	Table.CorrBatch AS CorrBatch,
	|	Table.CorrOwnership AS CorrOwnership,
	|	Table.CorrSpecification,
	|	Table.Specification,
	|	Table.IncomeAndExpenseItem,
	|	Table.CorrIncomeAndExpenseItem
	|FROM
	|	AccumulationRegister.LandedCosts AS Table
	|		LEFT JOIN InventoryRecords AS Inventory
	|		ON Table.Company = Inventory.Company
	|			AND Table.PresentationCurrency = Inventory.PresentationCurrency
	|			AND Table.Products = Inventory.Products
	|			AND Table.CostLayer = Inventory.CostLayer
	|			AND Table.Characteristic = Inventory.Characteristic
	|			AND Table.Batch = Inventory.Batch
	|			AND Table.Ownership = Inventory.Ownership
	|			AND Table.StructuralUnit = Inventory.StructuralUnit
	|			AND Table.InventoryAccountType = Inventory.InventoryAccountType
	|			AND Table.CostObject = Inventory.CostObject
	|WHERE
	|	Table.Period BETWEEN &BeginOfPeriod AND &EndOfPeriod
	|	AND Table.Company IN(&ArrayOfCompanies)
	|	AND Table.Active
	|	AND Table.SourceRecord
	|
	|GROUP BY
	|	Table.RecordType,
	|	Table.Period,
	|	Table.Recorder,
	|	Table.Company,
	|	Table.PresentationCurrency,
	|	Table.Products,
	|	Table.Characteristic,
	|	Table.CostLayer,
	|	Table.Batch,
	|	Table.Ownership,
	|	Table.StructuralUnit,
	|	Table.InventoryAccountType,
	|	Table.SalesOrder,
	|	Table.CorrStructuralUnit,
	|	Table.GLAccount,
	|	Table.CorrGLAccount,
	|	Table.CorrInventoryAccountType,
	|	Table.VATRate,
	|	Table.Responsible,
	|	Table.Department,
	|	Table.SourceRecord,
	|	Table.RIMTransfer,
	|	Table.CostObject,
	|	Table.CorrCostObject,
	|	Table.CorrProducts,
	|	Table.CorrCharacteristic,
	|	Table.CorrBatch,
	|	Table.CorrOwnership,
	|	Table.CorrSpecification,
	|	Table.Specification,
	|	Table.IncomeAndExpenseItem,
	|	Table.CorrIncomeAndExpenseItem
	|";
	
EndFunction

// Subcontracting components amount is sourse Landed cost for subcontracting products
Function TextOfSubcontractingComponentsLandedCosts()
	
	Return "
	|SELECT
	|	""SourceLandedCosts"" AS QueryName,
	|	10 AS Priority,
	|	""LandedCosts"" AS RecordKind,
	|	TRUE AS FinishCalculation,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	Table.Period AS Period,
	|	Table.Recorder AS Recorder,
	|	Table.Company AS Company,
	|	Table.PresentationCurrency AS PresentationCurrency,
	|	Table.CorrProducts AS Products,
	|	Table.CorrCharacteristic AS Characteristic,
	|	SubcontractorInvoiceReceived.BasisDocument AS CostLayer,
	|	Table.CorrBatch AS Batch,
	|	Table.CorrOwnership AS Ownership,
	|	Table.CorrStructuralUnit AS StructuralUnit,
	|	Table.CorrInventoryAccountType AS InventoryAccountType,
	|	Table.CorrSalesOrder AS SalesOrder,
	|	0 AS Denominator,
	|	ISNULL(InventoryRecords.Quantity, 0) AS Quantity,
	|	ISNULL(InventoryRecords.Quantity, 0) AS TotalQuantity,
	|	SUM(Table.Amount) AS Amount,
	|	UNDEFINED AS SourceDocument,
	|	VALUE(Catalog.BusinessUnits.EmptyRef) AS CorrStructuralUnit,
	|	UNDEFINED AS CorrSalesOrder,
	|	Table.CorrGLAccount AS GLAccount,
	|	VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef) AS CorrGLAccount,
	|	VALUE(Enum.InventoryAccountTypes.EmptyRef) AS CorrInventoryAccountType,
	|	VALUE(Catalog.VATRates.EmptyRef) AS VATRate,
	|	Table.Responsible AS Responsible,
	|	Table.Department AS Department,
	|	Table.SourceRecord AS SourceRecord,
	|	FALSE AS RIMTransfer,
	|	VALUE(Catalog.Employees.EmptyRef) AS SalesRep,
	|	VALUE(Catalog.Counterparties.EmptyRef)  AS Counterparty,
	|	VALUE(Catalog.Counterparties.EmptyRef)AS Currency,
	|	Table.CorrCostObject AS CostObject,
	|	VALUE(Catalog.CostObjects.EmptyRef) AS CorrCostObject,
	|	UNDEFINED AS CorrProducts,
	|	VALUE(Catalog.ProductsCharacteristics.EmptyRef) AS CorrCharacteristic,
	|	VALUE(Catalog.ProductsBatches.EmptyRef) AS CorrBatch,
	|	VALUE(Catalog.InventoryOwnership.EmptyRef) AS CorrOwnership,
	|	VALUE(Catalog.BillsOfMaterials.EmptyRef) AS CorrSpecification,
	|	Table.CorrSpecification AS Specification,
	|	Table.CorrIncomeAndExpenseItem AS IncomeAndExpenseItem,
	|	Table.IncomeAndExpenseItem AS CorrIncomeAndExpenseItem
	|FROM
	|	AccumulationRegister.InventoryCostLayer AS Table
	|		INNER JOIN Document.SubcontractorInvoiceReceived AS SubcontractorInvoiceReceived
	|		ON Table.Recorder = SubcontractorInvoiceReceived.Ref
	|		LEFT JOIN InventoryRecords AS InventoryRecords
	|		ON SubcontractorInvoiceReceived.BasisDocument = InventoryRecords.CostLayer
	|			AND Table.Company = InventoryRecords.Company
	|			AND Table.PresentationCurrency = InventoryRecords.PresentationCurrency
	|			AND Table.CorrProducts = InventoryRecords.Products
	|			AND Table.CorrCharacteristic = InventoryRecords.Characteristic
	|			AND Table.CorrBatch = InventoryRecords.Batch
	|			AND Table.CorrOwnership = InventoryRecords.Ownership
	|			AND Table.CorrStructuralUnit = InventoryRecords.StructuralUnit
	|			AND Table.CorrInventoryAccountType = InventoryRecords.InventoryAccountType
	|			AND Table.CorrCostObject = InventoryRecords.CostObject
	|WHERE
	|	Table.Period BETWEEN &BeginOfPeriod AND &EndOfPeriod
	|	AND Table.Company IN(&ArrayOfCompanies)
	|	AND Table.Active
	|	AND Table.RecordType = VALUE(AccumulationRecordType.Expense)
	|
	|GROUP BY
	|	Table.Period,
	|	Table.Recorder,
	|	Table.Company,
	|	Table.PresentationCurrency,
	|	Table.CorrStructuralUnit,
	|	Table.GLAccount,
	|	Table.CorrGLAccount,
	|	Table.CorrInventoryAccountType,
	|	Table.VATRate,
	|	Table.Responsible,
	|	Table.Department,
	|	Table.SourceRecord,
	|	Table.SourceRecord,
	|	Table.RIMTransfer,
	|	Table.CostObject,
	|	Table.CorrCostObject,
	|	Table.CorrProducts,
	|	Table.CorrCharacteristic,
	|	Table.CorrBatch,
	|	Table.CorrOwnership,
	|	Table.CorrSpecification,
	|	Table.Specification,
	|	Table.CorrSalesOrder,
	|	Table.CorrIncomeAndExpenseItem,
	|	Table.IncomeAndExpenseItem,
	|	SubcontractorInvoiceReceived.BasisDocument,
	|	Table.CorrGLAccount,
	|	InventoryRecords.Quantity
	|";
	
EndFunction

Function TextOfLandedCostsSalesInPreviousPeriods()
	
	Return "
	|SELECT
	|	""SalesInPreviousPeriods"" AS QueryName,
	|	10 AS Priority,
	|	""PreviousPeriods"" AS RecordKind,
	|	TRUE AS FinishCalculation,
	|	Table.RecordType AS RecordType,
	|	Table.Period AS Period,
	|	Table.Recorder AS Recorder,
	|	Table.Company AS Company,
	|	Table.PresentationCurrency AS PresentationCurrency,
	|	Table.Products AS Products,
	|	Table.Characteristic AS Characteristic,
	|	Table.CostLayer AS CostLayer,
	|	Table.Batch AS Batch,
	|	Table.Ownership AS Ownership,
	|	Table.StructuralUnit AS StructuralUnit,
	|	Table.InventoryAccountType AS InventoryAccountType,
	|	Table.SalesOrder AS SalesOrder,
	|	0 AS Denominator,
	|	SUM(Inventory.Quantity) AS Quantity,
	|	SUM(Inventory.Quantity) AS TotalQuantity,
	|	SUM(Table.Amount) AS Amount,
	|	Table.Recorder AS SourceDocument,
	|	Table.CorrStructuralUnit AS CorrStructuralUnit,
	|	UNDEFINED AS CorrSalesOrder,
	|	Table.GLAccount AS GLAccount,
	|	Table.CorrGLAccount AS CorrGLAccount,
	|	Table.CorrInventoryAccountType AS CorrInventoryAccountType,
	|	VALUE(Catalog.VATRates.EmptyRef) AS VATRate,
	|	VALUE(Catalog.Employees.EmptyRef) AS Responsible,
	|	VALUE(Catalog.BusinessUnits.EmptyRef) AS Department,
	|	Table.SourceRecord AS SourceRecord,
	|	Table.RIMTransfer AS RIMTransfer,
	|	VALUE(Catalog.Employees.EmptyRef) AS SalesRep,
	|	VALUE(Catalog.Counterparties.EmptyRef) AS Counterparty,
	|	VALUE(Catalog.Currencies.EmptyRef) AS Currency,
	|	Table.CostObject AS CostObject,
	|	Table.CorrCostObject AS CorrCostObject,
	|	Table.CorrProducts AS CorrProducts,
	|	Table.CorrCharacteristic AS CorrCharacteristic,
	|	Table.CorrBatch AS CorrBatch,
	|	Table.CorrOwnership AS CorrOwnership,
	|	Table.CorrSpecification,
	|	Table.Specification,
	|	Table.IncomeAndExpenseItem,
	|	Table.CorrIncomeAndExpenseItem
	|FROM
	|	SourceDocuments AS PreviousSales
	|	INNER JOIN AccumulationRegister.LandedCosts AS Table
	|		ON Table.Period < &BeginOfPeriod
	|		AND Table.Recorder = PreviousSales.Recorder
	|		AND Table.Company = PreviousSales.Company
	|		AND Table.PresentationCurrency = PreviousSales.PresentationCurrency
	|		AND Table.Products = PreviousSales.Products
	|		AND Table.Characteristic = PreviousSales.Characteristic
	|		AND Table.Batch = PreviousSales.Batch
	|		AND Table.Ownership = PreviousSales.Ownership
	|		AND Table.InventoryAccountType = PreviousSales.InventoryAccountType
	|		AND Table.CostLayer = PreviousSales.CostLayer
	|		AND Table.CostObject = PreviousSales.CostObject
	|	INNER JOIN AccumulationRegister.InventoryCostLayer AS Inventory
	|		ON Inventory.Period < &BeginOfPeriod
	|		AND Inventory.Recorder = PreviousSales.Recorder
	|		AND Inventory.Company = PreviousSales.Company
	|		AND Inventory.Products = PreviousSales.Products
	|		AND Inventory.Characteristic = PreviousSales.Characteristic
	|		AND Inventory.Batch = PreviousSales.Batch
	|		AND Inventory.Ownership = PreviousSales.Ownership
	|		AND Inventory.InventoryAccountType = PreviousSales.InventoryAccountType
	|		AND Inventory.CostLayer = PreviousSales.CostLayer
	|		AND Inventory.CostObject = PreviousSales.CostObject
	|
	|GROUP BY
	|	Table.RecordType,
	|	Table.Period,
	|	Table.Recorder,
	|	Table.Company,
	|	Table.PresentationCurrency,
	|	Table.Products,
	|	Table.Characteristic,
	|	Table.CostLayer,
	|	Table.Batch,
	|	Table.Ownership,
	|	Table.StructuralUnit,
	|	Table.InventoryAccountType,
	|	Table.SalesOrder,
	|	Table.Recorder,
	|	Table.CorrStructuralUnit,
	|	Table.GLAccount,
	|	Table.CorrGLAccount,
	|	Table.CorrInventoryAccountType,
	|	Table.SourceRecord,
	|	Table.RIMTransfer,
	|	Table.CostObject,
	|	Table.CorrCostObject,
	|	Table.CorrProducts,
	|	Table.CorrCharacteristic,
	|	Table.CorrBatch,
	|	Table.CorrOwnership,
	|	Table.CorrSpecification,
	|	Table.Specification,
	|	Table.IncomeAndExpenseItem,
	|	Table.CorrIncomeAndExpenseItem
	|";
	
EndFunction

Function TextOfConsumptionsLandedCosts()
	
	Return "
	|SELECT
	|	""ConsumptionsCostsLayers"" AS QueryName,
	|	90 AS Priority,
	|	""Consumption"" AS RecordKind,
	|	FALSE AS FinishCalculation,
	|	Table.RecordType AS RecordType,
	|	Table.Period AS Period,
	|	Table.Recorder AS Recorder,
	|	Table.Company AS Company,
	|	Table.PresentationCurrency AS PresentationCurrency,	
	|	Table.Products AS Products,
	|	Table.Characteristic AS Characteristic,
	|	Table.CostLayer AS CostLayer,
	|	Table.Batch AS Batch,
	|	Table.Ownership AS Ownership,
	|	Table.StructuralUnit AS StructuralUnit,
	|	Table.InventoryAccountType AS InventoryAccountType,
	|	Table.SalesOrder AS SalesOrder,
	|	0 AS Denominator,
	|	SUM(Table.Quantity) AS Quantity,
	|	SUM(Table.Quantity * ISNULL(CountOfLandedCosts.Count, 1)) AS TotalQuantity,
	|	0 AS Amount,
	|	Table.Recorder AS SourceDocument,
	|	Table.CorrStructuralUnit AS CorrStructuralUnit,
	|	Table.CorrSalesOrder AS CorrSalesOrder,
	|	Table.GLAccount AS GLAccount,
	|	Table.CorrGLAccount AS CorrGLAccount,
	|	Table.CorrInventoryAccountType AS CorrInventoryAccountType,
	|	Table.VATRate AS VATRate,
	|	Table.Responsible AS Responsible,
	|	Table.Department AS Department,
	|	FALSE AS SourceRecord,
	|	Table.RIMTransfer AS RIMTransfer,
	|	Table.SalesRep AS SalesRep,
	|	Table.Counterparty AS Counterparty,
	|	Table.Currency AS Currency,
	|	Table.CostObject AS CostObject,
	|	Table.CorrCostObject AS CorrCostObject,
	|	Table.CorrProducts AS CorrProducts,
	|	Table.CorrCharacteristic AS CorrCharacteristic,
	|	Table.CorrBatch AS CorrBatch,
	|	Table.CorrOwnership AS CorrOwnership,
	|	Table.CorrSpecification,
	|	Table.Specification,
	|	Table.IncomeAndExpenseItem,
	|	Table.CorrIncomeAndExpenseItem
	|FROM
	|	AccumulationRegister.InventoryCostLayer AS Table
	|		LEFT JOIN CountOfLandedCosts AS CountOfLandedCosts
	|		ON Table.CostLayer = CountOfLandedCosts.CostLayer
	|WHERE
	|	Table.Period BETWEEN &BeginOfPeriod AND &EndOfPeriod
	|	AND Table.Company IN (&ArrayOfCompanies)
	|	AND Table.Active
	|	AND Table.RecordType = VALUE(AccumulationRecordType.Expense)
	|	AND Table.Quantity > 0
	|	AND (Table.SourceDocument = UNDEFINED
	|			OR Table.SourceDocument = Table.Recorder)
	|	AND (VALUETYPE(Table.Recorder) = TYPE (Document.GoodsIssue)
	|		OR VALUETYPE(Table.Recorder) = TYPE (Document.InventoryTransfer)
	|		OR VALUETYPE(Table.Recorder) = TYPE (Document.InventoryWriteOff)
	|		OR VALUETYPE(Table.Recorder) = TYPE (Document.SalesInvoice)
	|		OR VALUETYPE(Table.Recorder) = TYPE (Document.ShiftClosure)
	|		OR VALUETYPE(Table.Recorder) = TYPE(Document.WorkOrder)
	|		OR VALUETYPE(Table.Recorder) = TYPE (Document.SubcontractorInvoiceReceived))
	|
	|GROUP BY
	|	Table.RecordType,
	|	Table.Period,
	|	Table.Recorder,
	|	Table.Company,
	|	Table.PresentationCurrency,
	|	Table.Products,
	|	Table.Characteristic,
	|	Table.CostLayer,
	|	Table.Batch,
	|	Table.Ownership,
	|	Table.StructuralUnit,
	|	Table.InventoryAccountType,
	|	Table.SalesOrder,
	|	Table.Recorder,
	|	Table.CorrStructuralUnit,
	|	Table.CorrSalesOrder,
	|	Table.GLAccount,
	|	Table.CorrGLAccount,
	|	Table.CorrInventoryAccountType,
	|	Table.VATRate,
	|	Table.Responsible,
	|	Table.Department,
	|	Table.RIMTransfer,
	|	Table.SalesRep,
	|	Table.Counterparty,
	|	Table.Currency,
	|	Table.CostObject,
	|	Table.CorrCostObject,
	|	Table.CorrProducts,
	|	Table.CorrCharacteristic,
	|	Table.CorrBatch,
	|	Table.CorrOwnership,
	|	Table.CorrSpecification,
	|	Table.Specification,
	|	Table.IncomeAndExpenseItem,
	|	Table.CorrIncomeAndExpenseItem
	|
	|UNION ALL
	|
	|SELECT
	|	""ConsumptionsCostsLayers"" AS QueryName,
	|	90 AS Priority,
	|	""Consumption"" AS RecordKind,
	|	FALSE AS FinishCalculation,
	|	Table.RecordType AS RecordType,
	|	Table.Period AS Period,
	|	Table.Recorder AS Recorder,
	|	Table.Company AS Company,
	|	Table.PresentationCurrency AS PresentationCurrency,
	|	Table.Products AS Products,
	|	Table.Characteristic AS Characteristic,
	|	Table.CostLayer AS CostLayer,
	|	Table.Batch AS Batch,
	|	Table.Ownership AS Ownership,
	|	Table.StructuralUnit AS StructuralUnit,
	|	Table.InventoryAccountType AS InventoryAccountType,
	|	Table.SalesOrder AS SalesOrder,
	|	0 AS Denominator,
	|	SUM(Table.Quantity) AS Quantity,
	|	SUM(Table.Quantity * ISNULL(CountOfLandedCosts.Count, 1)) AS TotalQuantity,
	|	0 AS Amount,
	|	Table.Recorder AS SourceDocument,
	|	Table.CorrStructuralUnit AS CorrStructuralUnit,
	|	Table.CorrSalesOrder AS CorrSalesOrder,
	|	Table.GLAccount AS GLAccount,
	|	Table.CorrGLAccount AS CorrGLAccount,
	|	Table.CorrInventoryAccountType AS CorrInventoryAccountType,
	|	Table.VATRate AS VATRate,
	|	Table.Responsible AS Responsible,
	|	Table.Department AS Department,
	|	FALSE AS SourceRecord,
	|	Table.RIMTransfer AS RIMTransfer,
	|	Table.SalesRep AS SalesRep,
	|	Table.Counterparty AS Counterparty,
	|	Table.Currency AS Currency,
	|	Table.CostObject,
	|	Table.CorrCostObject,
	|	Table.CorrProducts,
	|	Table.CorrCharacteristic,
	|	Table.CorrBatch,
	|	Table.CorrOwnership,
	|	Table.CorrSpecification,
	|	Table.Specification,
	|	Table.IncomeAndExpenseItem,
	|	Table.CorrIncomeAndExpenseItem
	|FROM
	|	AccumulationRegister.InventoryCostLayer AS Table
	|		LEFT JOIN CountOfLandedCosts AS CountOfLandedCosts
	|		ON Table.CostLayer = CountOfLandedCosts.CostLayer
	|WHERE
	|	Table.Period BETWEEN &BeginOfPeriod AND &EndOfPeriod
	|	AND Table.Company IN (&ArrayOfCompanies)
	|	AND Table.Active
	|	AND Table.RecordType = VALUE(AccumulationRecordType.Expense)
	|	AND Table.Quantity > 0
	|	AND VALUETYPE(Table.Recorder) = TYPE(Document.DebitNote)
	|
	|GROUP BY
	|	Table.RecordType,
	|	Table.Period,
	|	Table.Recorder,
	|	Table.Company,
	|	Table.PresentationCurrency,
	|	Table.Products,
	|	Table.Characteristic,
	|	Table.CostLayer,
	|	Table.Batch,
	|	Table.Ownership,
	|	Table.StructuralUnit,
	|	Table.InventoryAccountType,
	|	Table.SalesOrder,
	|	Table.Recorder,
	|	Table.CorrStructuralUnit,
	|	Table.CorrSalesOrder,
	|	Table.GLAccount,
	|	Table.CorrGLAccount,
	|	Table.CorrInventoryAccountType,
	|	Table.VATRate,
	|	Table.Responsible,
	|	Table.Department,
	|	Table.RIMTransfer,
	|	Table.SalesRep,
	|	Table.Counterparty,
	|	Table.Currency,
	|	Table.CostObject,
	|	Table.CorrCostObject,
	|	Table.CorrProducts,
	|	Table.CorrCharacteristic,
	|	Table.CorrBatch,
	|	Table.CorrOwnership,
	|	Table.CorrSpecification,
	|	Table.Specification,
	|	Table.IncomeAndExpenseItem,
	|	Table.CorrIncomeAndExpenseItem
	|
	|UNION ALL
	|
	|SELECT
	|	""ConsumptionsCostsLayers"" AS QueryName,
	|	90 AS Priority,
	|	""Consumption"" AS RecordKind,
	|	FALSE AS FinishCalculation,
	|	Table.RecordType AS RecordType,
	|	Table.Period AS Period,
	|	Table.Recorder AS Recorder,
	|	Table.Company AS Company,
	|	Table.PresentationCurrency AS PresentationCurrency,
	|	Table.Products AS Products,
	|	Table.Characteristic AS Characteristic,
	|	Table.CostLayer AS CostLayer,
	|	Table.Batch AS Batch,
	|	Table.Ownership AS Ownership,
	|	Table.StructuralUnit AS StructuralUnit,
	|	Table.InventoryAccountType AS InventoryAccountType,
	|	Table.SalesOrder AS SalesOrder,
	|	0 AS Denominator,
	|	SUM(Table.Quantity) AS Quantity,
	|	SUM(Table.Quantity * ISNULL(CountOfLandedCosts.Count, 1)) AS TotalQuantity,
	|	0 AS Amount,
	|	Table.Recorder AS SourceDocument,
	|	Table.CorrStructuralUnit AS CorrStructuralUnit,
	|	Table.CorrSalesOrder AS CorrSalesOrder,
	|	Table.GLAccount AS GLAccount,
	|	Table.CorrGLAccount AS CorrGLAccount,
	|	Table.CorrInventoryAccountType,
	|	Table.VATRate AS VATRate,
	|	Table.Responsible AS Responsible,
	|	Table.Department AS Department,
	|	FALSE AS SourceRecord,
	|	Table.RIMTransfer AS RIMTransfer,
	|	Table.SalesRep AS SalesRep,
	|	Table.Counterparty AS Counterparty,
	|	Table.Currency AS Currency,
	|	Table.CostObject,
	|	Table.CorrCostObject,
	|	Table.CorrProducts,
	|	Table.CorrCharacteristic,
	|	Table.CorrBatch,
	|	Table.CorrOwnership,
	|	Table.CorrSpecification,
	|	Table.Specification,
	|	Table.IncomeAndExpenseItem,
	|	Table.CorrIncomeAndExpenseItem
	|FROM
	|	AccumulationRegister.InventoryCostLayer AS Table
	|		LEFT JOIN CountOfLandedCosts AS CountOfLandedCosts
	|		ON Table.CostLayer = CountOfLandedCosts.CostLayer
	|WHERE
	|	Table.Period BETWEEN &BeginOfPeriod AND &EndOfPeriod
	|	AND Table.Company IN (&ArrayOfCompanies)
	|	AND Table.Active
	|	AND Table.RecordType = VALUE(AccumulationRecordType.Expense)
	|	AND Table.Quantity > 0
	|	AND VALUETYPE(Table.Recorder) = TYPE(Document.Production)
	|
	|GROUP BY
	|	Table.RecordType,
	|	Table.Period,
	|	Table.Recorder,
	|	Table.Company,
	|	Table.PresentationCurrency,
	|	Table.Products,
	|	Table.Characteristic,
	|	Table.CostLayer,
	|	Table.Batch,
	|	Table.Ownership,
	|	Table.StructuralUnit,
	|	Table.InventoryAccountType,
	|	Table.SalesOrder,
	|	Table.Recorder,
	|	Table.CorrStructuralUnit,
	|	Table.CorrSalesOrder,
	|	Table.GLAccount,
	|	Table.CorrGLAccount,
	|	Table.CorrInventoryAccountType,
	|	Table.VATRate,
	|	Table.Responsible,
	|	Table.Department,
	|	Table.RIMTransfer,
	|	Table.SalesRep,
	|	Table.Counterparty,
	|	Table.Currency,
	|	Table.CostObject,
	|	Table.CorrCostObject,
	|	Table.CorrProducts,
	|	Table.CorrCharacteristic,
	|	Table.CorrBatch,
	|	Table.CorrOwnership,
	|	Table.CorrSpecification,
	|	Table.Specification,
	|	Table.IncomeAndExpenseItem,
	|	Table.CorrIncomeAndExpenseItem
	|
	// begin Drive.FullVersion
	|UNION ALL
	|
	|SELECT
	|	""ConsumptionsCostsLayers"" AS QueryName,
	|	90 AS Priority,
	|	""Consumption"" AS RecordKind,
	|	FALSE AS FinishCalculation,
	|	Table.RecordType AS RecordType,
	|	Table.Period AS Period,
	|	Table.Recorder AS Recorder,
	|	Table.Company AS Company,
	|	Table.PresentationCurrency AS PresentationCurrency,
	|	Table.Products AS Products,
	|	Table.Characteristic AS Characteristic,
	|	Table.CostLayer AS CostLayer,
	|	Table.Batch AS Batch,
	|	Table.Ownership AS Ownership,
	|	Table.StructuralUnit AS StructuralUnit,
	|	Table.InventoryAccountType AS InventoryAccountType,
	|	Table.SalesOrder AS SalesOrder,
	|	0 AS Denominator,
	|	SUM(Table.Quantity) AS Quantity,
	|	SUM(Table.Quantity * ISNULL(CountOfLandedCosts.Count, 1)) AS TotalQuantity,
	|	0 AS Amount,
	|	Table.Recorder AS SourceDocument,
	|	Table.CorrStructuralUnit AS CorrStructuralUnit,
	|	Table.CorrSalesOrder AS CorrSalesOrder,
	|	Table.GLAccount AS GLAccount,
	|	Table.CorrGLAccount AS CorrGLAccount,
	|	Table.CorrInventoryAccountType,
	|	Table.VATRate AS VATRate,
	|	Table.Responsible AS Responsible,
	|	Table.Department AS Department,
	|	FALSE AS SourceRecord,
	|	Table.RIMTransfer AS RIMTransfer,
	|	Table.SalesRep AS SalesRep,
	|	Table.Counterparty AS Counterparty,
	|	Table.Currency AS Currency,
	|	Table.CostObject,
	|	Table.CorrCostObject,
	|	Table.CorrProducts,
	|	Table.CorrCharacteristic,
	|	Table.CorrBatch,
	|	Table.CorrOwnership,
	|	Table.CorrSpecification,
	|	Table.Specification,
	|	Table.IncomeAndExpenseItem,
	|	Table.CorrIncomeAndExpenseItem
	|FROM
	|	AccumulationRegister.InventoryCostLayer AS Table
	|		LEFT JOIN CountOfLandedCosts AS CountOfLandedCosts
	|		ON Table.CostLayer = CountOfLandedCosts.CostLayer
	|WHERE
	|	Table.Period BETWEEN &BeginOfPeriod AND &EndOfPeriod
	|	AND Table.Company IN (&ArrayOfCompanies)
	|	AND Table.Active
	|	AND Table.RecordType = VALUE(AccumulationRecordType.Expense)
	|	AND Table.Quantity > 0
	|	AND (VALUETYPE(Table.Recorder) = TYPE(Document.ManufacturingOperation)
	|			OR VALUETYPE(Table.Recorder) = TYPE(Document.Manufacturing))
	|
	|GROUP BY
	|	Table.RecordType,
	|	Table.Period,
	|	Table.Recorder,
	|	Table.Company,
	|	Table.PresentationCurrency,
	|	Table.Products,
	|	Table.Characteristic,
	|	Table.CostLayer,
	|	Table.Batch,
	|	Table.Ownership,
	|	Table.StructuralUnit,
	|	Table.InventoryAccountType,
	|	Table.GLAccount,
	|	Table.SalesOrder,
	|	Table.Recorder,
	|	Table.CorrStructuralUnit,
	|	Table.CorrSalesOrder,
	|	Table.CorrGLAccount,
	|	Table.GLAccount,
	|	Table.CorrInventoryAccountType,
	|	Table.VATRate,
	|	Table.Responsible,
	|	Table.Department,
	|	Table.RIMTransfer,
	|	Table.SalesRep,
	|	Table.Counterparty,
	|	Table.Currency,
	|	Table.CostObject,
	|	Table.CorrCostObject,
	|	Table.CorrProducts,
	|	Table.CorrCharacteristic,
	|	Table.CorrBatch,
	|	Table.CorrOwnership,
	|	Table.CorrSpecification,
	|	Table.Specification,
	|	Table.IncomeAndExpenseItem,
	|	Table.CorrIncomeAndExpenseItem
	// end Drive.FullVersion
	|";
	
EndFunction

Function TextOfTransfersLandedCostsReceipt()
	
	Return "
	|SELECT
	|	""CostsLayersTransfersReceipt"" AS QueryName,
	|	90 AS Priority,
	|	""Transfer"" AS RecordKind,
	|	FALSE AS FinishCalculation,
	|	Table.RecordType AS RecordType,
	|	Table.Period AS Period,
	|	Table.Recorder AS Recorder,
	|	Table.Company AS Company,
	|	Table.PresentationCurrency AS PresentationCurrency,
	|	Table.Products AS Products,
	|	Table.Characteristic AS Characteristic,
	|	Table.CostLayer AS CostLayer,
	|	Table.Batch AS Batch,
	|	Table.Ownership AS Ownership,
	|	Table.StructuralUnit AS StructuralUnit,
	|	Table.InventoryAccountType AS InventoryAccountType,
	|	Table.SalesOrder AS SalesOrder,
	|	0 AS Denominator,
	|	SUM(Table.Quantity) AS Quantity,
	|	SUM(Table.Quantity * ISNULL(CountOfLandedCosts.Count, 1)) AS TotalQuantity,
	|	0 AS Amount,
	|	Table.Recorder AS SourceDocument,
	|	Table.CorrStructuralUnit AS CorrStructuralUnit,
	|	UNDEFINED AS CorrSalesOrder,
	|	Table.GLAccount AS GLAccount,
	|	Table.CorrGLAccount AS CorrGLAccount,
	|	Table.CorrInventoryAccountType AS CorrInventoryAccountType,
	|	Table.VATRate AS VATRate,
	|	Table.Responsible AS Responsible,
	|	Table.Department AS Department,
	|	FALSE AS SourceRecord,
	|	Table.RIMTransfer AS RIMTransfer,
	|	Table.SalesRep AS SalesRep,
	|	Table.Counterparty AS Counterparty,
	|	Table.Currency AS Currency,
	|	Table.CostObject,
	|	Table.CorrCostObject,
	|	Table.CorrProducts,
	|	Table.CorrCharacteristic,
	|	Table.CorrBatch,
	|	Table.CorrOwnership,
	|	Table.CorrSpecification,
	|	Table.Specification,
	|	Table.IncomeAndExpenseItem,
	|	Table.CorrIncomeAndExpenseItem
	|FROM
	|	AccumulationRegister.InventoryCostLayer AS Table
	|		LEFT JOIN CountOfLandedCosts AS CountOfLandedCosts
	|		ON Table.CostLayer = CountOfLandedCosts.CostLayer
	|WHERE
	|	Table.Period BETWEEN &BeginOfPeriod AND &EndOfPeriod
	|	AND Table.Company IN (&ArrayOfCompanies)
	|	AND Table.Active
	|	AND Table.RecordType = VALUE(AccumulationRecordType.Receipt)
	|	AND Table.Quantity > 0
	|	AND (VALUETYPE(Table.Recorder) = TYPE(Document.InventoryTransfer)
	|		OR VALUETYPE(Table.Recorder) = TYPE(Document.GoodsIssue))
	|
	|GROUP BY
	|	Table.RecordType,
	|	Table.Period,
	|	Table.Recorder,
	|	Table.CorrStructuralUnit,
	|	Table.Company,
	|	Table.PresentationCurrency,
	|	Table.Products,
	|	Table.Characteristic,
	|	Table.CostLayer,
	|	Table.Batch,
	|	Table.Ownership,
	|	Table.StructuralUnit,
	|	Table.InventoryAccountType,
	|	Table.GLAccount,
	|	Table.CorrGLAccount,
	|	Table.CorrInventoryAccountType,
	|	Table.VATRate,
	|	Table.Responsible,
	|	Table.Department,
	|	Table.SalesOrder,
	|	Table.RIMTransfer,
	|	Table.SalesRep,
	|	Table.Counterparty,
	|	Table.Currency,
	|	Table.CostObject,
	|	Table.CorrCostObject,
	|	Table.CorrProducts,
	|	Table.CorrCharacteristic,
	|	Table.CorrBatch,
	|	Table.CorrOwnership,
	|	Table.CorrSpecification,
	|	Table.Specification,
	|	Table.IncomeAndExpenseItem,
	|	Table.CorrIncomeAndExpenseItem
	|";
	
EndFunction

Function TextOfReversalLandedCosts()
	
	Return "
	|SELECT
	|	""ReversalCostsLayers"" AS QueryName,
	|	10 AS Priority,
	|	""Reversal"" AS RecordKind,
	|	FALSE AS FinishCalculation,
	|	Table.RecordType AS RecordType,
	|	Table.Period AS Period,
	|	Table.Recorder AS Recorder,
	|	Table.Company AS Company,
	|	Table.PresentationCurrency AS PresentationCurrency,
	|	Table.Products AS Products,
	|	Table.Characteristic AS Characteristic,
	|	Table.CostLayer AS CostLayer,
	|	Table.Batch AS Batch,
	|	Table.Ownership AS Ownership,
	|	Table.StructuralUnit AS StructuralUnit,
	|	Table.InventoryAccountType AS InventoryAccountType,
	|	Table.SalesOrder AS SalesOrder,
	|	0 AS Denominator,
	|	SUM(Table.Quantity) AS Quantity,
	|	SUM(Table.Quantity * ISNULL(CountOfLandedCosts.Count, 1)) AS TotalQuantity,
	|	0 AS Amount,
	|	Table.SourceDocument AS SourceDocument,
	|	Table.CorrStructuralUnit AS CorrStructuralUnit,
	|	UNDEFINED AS CorrSalesOrder,
	|	Table.GLAccount AS GLAccount,
	|	Table.CorrGLAccount AS CorrGLAccount,
	|	Table.CorrInventoryAccountType AS CorrInventoryAccountType,
	|	Table.VATRate AS VATRate,
	|	Table.Responsible AS Responsible,
	|	Table.Department AS Department,
	|	FALSE AS SourceRecord,
	|	Table.RIMTransfer AS RIMTransfer,
	|	Table.SalesRep AS SalesRep,
	|	Table.Counterparty AS Counterparty,
	|	Table.Currency AS Currency,
	|	Table.CostObject,
	|	Table.CorrCostObject,
	|	Table.CorrProducts,
	|	Table.CorrCharacteristic,
	|	Table.CorrBatch,
	|	Table.CorrOwnership,
	|	Table.CorrSpecification,
	|	Table.Specification,
	|	Table.IncomeAndExpenseItem,
	|	Table.CorrIncomeAndExpenseItem
	|FROM
	|	AccumulationRegister.InventoryCostLayer AS Table
	|		LEFT JOIN CountOfLandedCosts AS CountOfLandedCosts
	|		ON Table.CostLayer = CountOfLandedCosts.CostLayer
	|WHERE
	|	Table.Period BETWEEN &BeginOfPeriod AND &EndOfPeriod
	|	AND Table.Company IN (&ArrayOfCompanies)
	|	AND Table.Active
	|	AND Table.RecordType = VALUE(AccumulationRecordType.Receipt)
	|	AND Table.Quantity > 0
	|	AND VALUETYPE(Table.Recorder) = TYPE(Document.CreditNote)
	|
	|GROUP BY
	|	Table.RecordType,
	|	Table.Period,
	|	Table.Recorder,
	|	Table.Company,
	|	Table.PresentationCurrency,
	|	Table.Products,
	|	Table.Characteristic,
	|	Table.CostLayer,
	|	Table.Batch,
	|	Table.Ownership,
	|	Table.StructuralUnit,
	|	Table.InventoryAccountType,
	|	Table.SalesOrder,
	|	Table.SourceDocument,
	|	Table.CorrStructuralUnit,
	|	Table.GLAccount,
	|	Table.CorrGLAccount,
	|	Table.CorrInventoryAccountType,
	|	Table.VATRate,
	|	Table.Responsible,
	|	Table.Department,
	|	Table.RIMTransfer,
	|	Table.SalesRep,
	|	Table.Counterparty,
	|	Table.Currency,
	|	Table.CostObject,
	|	Table.CorrCostObject,
	|	Table.CorrProducts,
	|	Table.CorrCharacteristic,
	|	Table.CorrBatch,
	|	Table.CorrOwnership,
	|	Table.CorrSpecification,
	|	Table.Specification,
	|	Table.IncomeAndExpenseItem,
	|	Table.CorrIncomeAndExpenseItem
	|
	|UNION ALL
	|
	|SELECT
	|	""ReversalCostsLayers"" AS QueryName,
	|	10 AS Priority,
	|	""Reversal"" AS RecordKind,
	|	FALSE AS FinishCalculation,
	|	Table.RecordType AS RecordType,
	|	Table.Period AS Period,
	|	Table.Recorder AS Recorder,
	|	Table.Company AS Company,
	|	Table.PresentationCurrency AS PresentationCurrency,
	|	Table.Products AS Products,
	|	Table.Characteristic AS Characteristic,
	|	Table.CostLayer AS CostLayer,
	|	Table.Batch AS Batch,
	|	Table.Ownership AS Ownership,
	|	Table.StructuralUnit AS StructuralUnit,
	|	Table.InventoryAccountType AS InventoryAccountType,
	|	Table.SalesOrder AS SalesOrder,
	|	0 AS Denominator,
	|	SUM(Table.Quantity) AS Quantity,
	|	SUM(Table.Quantity * ISNULL(CountOfLandedCosts.Count, 1)) AS TotalQuantity,
	|	0 AS Amount,
	|	Table.SourceDocument AS SourceDocument,
	|	Table.CorrStructuralUnit AS CorrStructuralUnit,
	|	UNDEFINED AS CorrSalesOrder,
	|	Table.GLAccount AS GLAccount,
	|	Table.CorrGLAccount AS CorrGLAccount,
	|	Table.CorrInventoryAccountType AS CorrInventoryAccountType,
	|	Table.VATRate AS VATRate,
	|	Table.Responsible AS Responsible,
	|	Table.Department AS Department,
	|	FALSE AS SourceRecord,
	|	Table.RIMTransfer AS RIMTransfer,
	|	Table.SalesRep AS SalesRep,
	|	Table.Counterparty AS Counterparty,
	|	Table.Currency AS Currency,
	|	Table.CostObject,
	|	Table.CorrCostObject,
	|	Table.CorrProducts,
	|	Table.CorrCharacteristic,
	|	Table.CorrBatch,
	|	Table.CorrOwnership,
	|	Table.CorrSpecification,
	|	Table.Specification,
	|	Table.IncomeAndExpenseItem,
	|	Table.CorrIncomeAndExpenseItem
	|FROM
	|	AccumulationRegister.InventoryCostLayer AS Table
	|		INNER JOIN Document.GoodsReceipt AS GoodsReceipt
	|		ON Table.Recorder = GoodsReceipt.Ref
	|			AND GoodsReceipt.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.SalesReturn)
	|		LEFT JOIN CountOfLandedCosts AS CountOfLandedCosts
	|		ON Table.CostLayer = CountOfLandedCosts.CostLayer
	|WHERE
	|	Table.Period BETWEEN &BeginOfPeriod AND &EndOfPeriod
	|	AND Table.Company IN (&ArrayOfCompanies)
	|	AND Table.Active
	|	AND Table.RecordType = VALUE(AccumulationRecordType.Receipt)
	|	AND Table.Quantity > 0
	|
	|GROUP BY
	|	Table.RecordType,
	|	Table.Period,
	|	Table.Recorder,
	|	Table.Company,
	|	Table.PresentationCurrency,
	|	Table.Products,
	|	Table.Characteristic,
	|	Table.CostLayer,
	|	Table.Batch,
	|	Table.Ownership,
	|	Table.StructuralUnit,
	|	Table.InventoryAccountType,
	|	Table.SalesOrder,
	|	Table.SourceDocument,
	|	Table.CorrStructuralUnit,
	|	Table.GLAccount,
	|	Table.CorrGLAccount,
	|	Table.CorrInventoryAccountType,
	|	Table.VATRate,
	|	Table.Responsible,
	|	Table.Department,
	|	Table.RIMTransfer,
	|	Table.SalesRep,
	|	Table.Counterparty,
	|	Table.Currency,
	|	Table.CostObject,
	|	Table.CorrCostObject,
	|	Table.CorrProducts,
	|	Table.CorrCharacteristic,
	|	Table.CorrBatch,
	|	Table.CorrOwnership,
	|	Table.CorrSpecification,
	|	Table.Specification,
	|	Table.IncomeAndExpenseItem,
	|	Table.CorrIncomeAndExpenseItem
	|";
	
EndFunction

Function TextOfIntraCommunityTransfersLandedCosts()
	
	Return "
	|SELECT
	|	""IntraCommunityTransfersLandedCosts"" AS QueryName,
	|	95 AS Priority,
	|	""ConsumptionIntraTransfer"" AS RecordKind,
	|	FALSE AS FinishCalculation,
	|	Table.RecordType AS RecordType,
	|	Table.Period AS Period,
	|	Table.Recorder AS Recorder,
	|	Table.Company AS Company,
	|	Table.PresentationCurrency AS PresentationCurrency,
	|	Table.Products AS Products,
	|	Table.Characteristic AS Characteristic,
	|	Table.CostLayer AS CostLayer,
	|	Table.Batch AS Batch,
	|	Table.Ownership AS Ownership,
	|	Table.StructuralUnit AS StructuralUnit,
	|	Table.InventoryAccountType AS InventoryAccountType,
	|	Table.SalesOrder AS SalesOrder,
	|	0 AS Denominator,
	|	SUM(Table.Quantity) AS Quantity,
	|	SUM(Table.Quantity * ISNULL(CountOfLandedCosts.Count, 1)) AS TotalQuantity,
	|	0 AS Amount,
	|	Table.SourceDocument AS SourceDocument,
	|	Table.CorrStructuralUnit AS CorrStructuralUnit,
	|	UNDEFINED AS CorrSalesOrder,
	|	Table.GLAccount AS GLAccount,
	|	Table.CorrGLAccount AS CorrGLAccount,
	|	Table.CorrInventoryAccountType AS CorrInventoryAccountType,
	|	Table.VATRate AS VATRate,
	|	Table.Responsible AS Responsible,
	|	UNDEFINED AS Department,
	|	FALSE AS SourceRecord,
	|	Table.RIMTransfer AS RIMTransfer,
	|	Table.SalesRep AS SalesRep,
	|	Table.Counterparty AS Counterparty,
	|	Table.Currency AS Currency,
	|	Table.CostObject,
	|	Table.CorrCostObject,
	|	Table.CorrProducts,
	|	Table.CorrCharacteristic,
	|	Table.CorrBatch,
	|	Table.CorrOwnership,
	|	Table.CorrSpecification,
	|	Table.Specification,
	|	Table.IncomeAndExpenseItem,
	|	Table.CorrIncomeAndExpenseItem
	|FROM
	|	AccumulationRegister.InventoryCostLayer AS Table
	|		LEFT JOIN CountOfLandedCosts AS CountOfLandedCosts
	|		ON Table.CostLayer = CountOfLandedCosts.CostLayer
	|WHERE
	|	Table.Period BETWEEN &BeginOfPeriod AND &EndOfPeriod
	|	AND Table.Company IN(&ArrayOfCompanies)
	|	AND Table.Active
	|	AND Table.RecordType = VALUE(AccumulationRecordType.Expense)
	|	AND Table.Quantity > 0
	|	AND VALUETYPE(Table.Recorder) = VALUE(Document.GoodsReceipt)
	|	AND Table.StructuralUnit = VALUE(Catalog.BusinessUnits.GoodsInTransit)
	|
	|GROUP BY
	|	Table.RecordType,
	|	Table.Period,
	|	Table.Recorder,
	|	Table.Company,
	|	Table.PresentationCurrency,
	|	Table.Products,
	|	Table.SourceDocument,
	|	Table.Characteristic,
	|	Table.CostLayer,
	|	Table.Batch,
	|	Table.Ownership,
	|	Table.StructuralUnit,
	|	Table.CorrStructuralUnit,
	|	Table.InventoryAccountType,
	|	Table.GLAccount,
	|	Table.CorrGLAccount,
	|	Table.CorrInventoryAccountType,
	|	Table.VATRate,
	|	Table.Responsible,
	|	Table.Department,
	|	Table.SalesOrder,
	|	Table.RIMTransfer,
	|	Table.SalesRep,
	|	Table.Counterparty,
	|	Table.Currency,
	|	Table.CostObject,
	|	Table.CorrCostObject,
	|	Table.CorrProducts,
	|	Table.CorrCharacteristic,
	|	Table.CorrBatch,
	|	Table.CorrOwnership,
	|	Table.CorrSpecification,
	|	Table.Specification,
	|	Table.IncomeAndExpenseItem,
	|	Table.CorrIncomeAndExpenseItem
	|
	|UNION ALL
	|
	|SELECT
	|	""IntraCommunityTransfersLandedCosts"",
	|	97,
	|	""IntraTransfer"",
	|	FALSE,
	|	Table.RecordType,
	|	Table.Period,
	|	Table.Recorder,
	|	Table.Company,
	|	Table.PresentationCurrency,
	|	Table.Products,
	|	Table.Characteristic,
	|	Table.CostLayer,
	|	Table.Batch,
	|	Table.Ownership,
	|	Table.StructuralUnit,
	|	Table.InventoryAccountType,
	|	Table.SalesOrder,
	|	0,
	|	SUM(Table.Quantity),
	|	SUM(Table.Quantity * ISNULL(CountOfLandedCosts.Count, 1)),
	|	0,
	|	Table.SourceDocument,
	|	Table.CorrStructuralUnit,
	|	UNDEFINED,
	|	Table.GLAccount,
	|	Table.CorrGLAccount,
	|	Table.CorrInventoryAccountType,
	|	Table.VATRate,
	|	Table.Responsible,
	|	UNDEFINED,
	|	FALSE,
	|	Table.RIMTransfer,
	|	Table.SalesRep,
	|	Table.Counterparty,
	|	Table.Currency,
	|	Table.CostObject,
	|	Table.CorrCostObject,
	|	Table.CorrProducts,
	|	Table.CorrCharacteristic,
	|	Table.CorrBatch,
	|	Table.CorrOwnership,
	|	Table.CorrSpecification,
	|	Table.Specification,
	|	Table.IncomeAndExpenseItem,
	|	Table.CorrIncomeAndExpenseItem
	|FROM
	|	AccumulationRegister.InventoryCostLayer AS Table
	|		LEFT JOIN CountOfLandedCosts AS CountOfLandedCosts
	|		ON Table.CostLayer = CountOfLandedCosts.CostLayer
	|WHERE
	|	Table.Period BETWEEN &BeginOfPeriod AND &EndOfPeriod
	|	AND Table.Company IN(&ArrayOfCompanies)
	|	AND Table.Active
	|	AND Table.RecordType = VALUE(AccumulationRecordType.Receipt)
	|	AND Table.Quantity > 0
	|	AND VALUETYPE(Table.Recorder) = VALUE(Document.GoodsReceipt)
	|	AND Table.CorrStructuralUnit = VALUE(Catalog.BusinessUnits.GoodsInTransit)
	|
	|GROUP BY
	|	Table.RecordType,
	|	Table.Period,
	|	Table.Recorder,
	|	Table.Company,
	|	Table.PresentationCurrency,
	|	Table.Products,
	|	Table.Characteristic,
	|	Table.CostLayer,
	|	Table.Batch,
	|	Table.Ownership,
	|	Table.StructuralUnit,
	|	Table.CorrStructuralUnit,
	|	Table.InventoryAccountType,
	|	Table.SourceDocument,
	|	Table.GLAccount,
	|	Table.CorrGLAccount,
	|	Table.CorrInventoryAccountType,
	|	Table.VATRate,
	|	Table.Responsible,
	|	Table.Department,
	|	Table.SalesOrder,
	|	Table.RIMTransfer,
	|	Table.SalesRep,
	|	Table.Counterparty,
	|	Table.Currency,
	|	Table.CostObject,
	|	Table.CorrCostObject,
	|	Table.CorrProducts,
	|	Table.CorrCharacteristic,
	|	Table.CorrBatch,
	|	Table.CorrOwnership,
	|	Table.CorrSpecification,
	|	Table.Specification,
	|	Table.IncomeAndExpenseItem,
	|	Table.CorrIncomeAndExpenseItem
	|";
	
EndFunction

// begin Drive.FullVersion
Function TextOfWorkInProgressReceiptLandedCosts()
	
	Return "
	|	SELECT
	|	""WorkInProgressReceiptLandedCosts"" AS QueryName,
	|	90 AS Priority,
	|	""WIP"" AS RecordKind,
	|	FALSE AS FinishCalculation,
	|	Table.RecordType AS RecordType,
	|	Table.Period AS Period,
	|	Table.Recorder AS Recorder,
	|	Table.Company AS Company,
	|	Table.PresentationCurrency AS PresentationCurrency,
	|	Table.Products AS Products,
	|	Table.Characteristic AS Characteristic,
	|	Table.CostLayer AS CostLayer,
	|	Table.Batch AS Batch,
	|	Table.Ownership AS Ownership,
	|	Table.StructuralUnit AS StructuralUnit,
	|	Table.InventoryAccountType,
	|	Table.SalesOrder AS SalesOrder,
	|	0 AS Denominator,
	|	SUM(Table.Quantity) AS Quantity,
	|	SUM(Table.Quantity * ISNULL(CountOfLandedCosts.Count, 1)) AS TotalQuantity,
	|	0 AS Amount,
	|	Table.Recorder AS SourceDocument,
	|	Table.CorrStructuralUnit AS CorrStructuralUnit,
	|	UNDEFINED AS CorrSalesOrder,
	|	Table.GLAccount AS GLAccount,
	|	Table.CorrGLAccount AS CorrGLAccount,
	|	Table.CorrInventoryAccountType AS CorrInventoryAccountType,
	|	Table.VATRate AS VATRate,
	|	Table.Responsible AS Responsible,
	|	UNDEFINED AS Department,
	|	FALSE AS SourceRecord,
	|	Table.RIMTransfer AS RIMTransfer,
	|	Table.SalesRep AS SalesRep,
	|	Table.Counterparty AS Counterparty,
	|	Table.Currency AS Currency,
	|	Table.CostObject,
	|	Table.CorrCostObject,
	|	Table.CorrProducts,
	|	Table.CorrCharacteristic,
	|	Table.CorrBatch,
	|	Table.CorrOwnership,
	|	Table.CorrSpecification,
	|	Table.Specification,
	|	Table.IncomeAndExpenseItem,
	|	Table.CorrIncomeAndExpenseItem
	|FROM
	|	AccumulationRegister.InventoryCostLayer AS Table
	|		LEFT JOIN CountOfLandedCosts AS CountOfLandedCosts
	|		ON Table.CostLayer = CountOfLandedCosts.CostLayer
	|WHERE
	|	Table.Period BETWEEN &BeginOfPeriod AND &EndOfPeriod
	|	AND Table.Company IN(&ArrayOfCompanies)
	|	AND Table.Active
	|	AND Table.RecordType = VALUE(AccumulationRecordType.Receipt)
	|	AND Table.Quantity > 0
	|	AND VALUETYPE(Table.Recorder) = TYPE(Document.ManufacturingOperation)
	|	AND VALUETYPE(Table.Products) = TYPE(Catalog.Products)
	|
	|GROUP BY
	|	Table.RecordType,
	|	Table.Period,
	|	Table.Recorder,
	|	Table.Company,
	|	Table.PresentationCurrency,
	|	Table.Products,
	|	Table.Recorder,
	|	Table.Characteristic,
	|	Table.CostLayer,
	|	Table.Batch,
	|	Table.Ownership,
	|	Table.StructuralUnit,
	|	Table.CorrStructuralUnit,
	|	Table.InventoryAccountType,
	|	Table.GLAccount,
	|	Table.CorrGLAccount,
	|	Table.CorrInventoryAccountType,
	|	Table.VATRate,
	|	Table.Responsible,
	|	Table.Department,
	|	Table.SalesOrder,
	|	Table.RIMTransfer,
	|	Table.SalesRep,
	|	Table.Counterparty,
	|	Table.Currency,
	|	Table.CostObject,
	|	Table.CorrCostObject,
	|	Table.CorrProducts,
	|	Table.CorrCharacteristic,
	|	Table.CorrBatch,
	|	Table.CorrOwnership,
	|	Table.CorrSpecification,
	|	Table.Specification,
	|	Table.IncomeAndExpenseItem,
	|	Table.CorrIncomeAndExpenseItem
	|";
	
EndFunction

Function TextOfProductionReceiptLandedCosts()
	
	Return "
	|	SELECT
	|	""ProductionReceiptLandedCosts"" AS QueryName,
	|	90 AS Priority,
	|	""Production"" AS RecordKind,
	|	FALSE AS FinishCalculation,
	|	Table.RecordType AS RecordType,
	|	Table.Period AS Period,
	|	Table.Recorder AS Recorder,
	|	Table.Company AS Company,
	|	Table.PresentationCurrency AS PresentationCurrency,
	|	Table.Products AS Products,
	|	Table.Characteristic AS Characteristic,
	|	Table.CostLayer AS CostLayer,
	|	Table.Batch AS Batch,
	|	Table.Ownership AS Ownership,
	|	Table.StructuralUnit AS StructuralUnit,
	|	Table.InventoryAccountType AS InventoryAccountType,
	|	Table.SalesOrder AS SalesOrder,
	|	0 AS Denominator,
	|	SUM(Table.Quantity) AS Quantity,
	|	SUM(Table.Quantity * ISNULL(CountOfLandedCosts.Count, 1)) AS TotalQuantity,
	|	0 AS Amount,
	|	Table.Recorder AS SourceDocument,
	|	Table.CorrStructuralUnit AS CorrStructuralUnit,
	|	UNDEFINED AS CorrSalesOrder,
	|	Table.GLAccount AS GLAccount,
	|	Table.CorrGLAccount AS CorrGLAccount,
	|	Table.CorrInventoryAccountType AS CorrInventoryAccountType,
	|	Table.VATRate AS VATRate,
	|	Table.Responsible AS Responsible,
	|	UNDEFINED AS Department,
	|	FALSE AS SourceRecord,
	|	Table.RIMTransfer AS RIMTransfer,
	|	Table.SalesRep AS SalesRep,
	|	Table.Counterparty AS Counterparty,
	|	Table.Currency AS Currency,
	|	Table.CostObject,
	|	Table.CorrCostObject,
	|	Table.CorrProducts,
	|	Table.CorrCharacteristic,
	|	Table.CorrBatch,
	|	Table.CorrOwnership,
	|	Table.CorrSpecification,
	|	Table.Specification,
	|	Table.IncomeAndExpenseItem,
	|	Table.CorrIncomeAndExpenseItem
	|FROM
	|	AccumulationRegister.InventoryCostLayer AS Table
	|		INNER JOIN AccumulationRegister.ProductRelease AS ProductRelease
	|		ON Table.Recorder = ProductRelease.Recorder
	|			AND Table.Company = ProductRelease.Company
	|			AND Table.StructuralUnit = ProductRelease.StructuralUnit
	|			AND Table.Products = ProductRelease.Products
	|			AND Table.Characteristic = ProductRelease.Characteristic
	|			AND Table.Batch = ProductRelease.Batch
	|			AND Table.Ownership = ProductRelease.Ownership
	|			AND Table.SalesOrder = ProductRelease.SalesOrder
	|		LEFT JOIN CountOfLandedCosts AS CountOfLandedCosts
	|		ON Table.CostLayer = CountOfLandedCosts.CostLayer
	|WHERE
	|	Table.Period BETWEEN &BeginOfPeriod AND &EndOfPeriod
	|	AND Table.Company IN(&ArrayOfCompanies)
	|	AND Table.Active
	|	AND Table.RecordType = VALUE(AccumulationRecordType.Receipt)
	|	AND Table.Quantity > 0
	|
	|GROUP BY
	|	Table.RecordType,
	|	Table.Period,
	|	Table.Recorder,
	|	Table.Company,
	|	Table.PresentationCurrency,
	|	Table.Products,
	|	Table.Characteristic,
	|	Table.CostLayer,
	|	Table.Batch,
	|	Table.Ownership,
	|	Table.StructuralUnit,
	|	Table.CorrStructuralUnit,
	|	Table.InventoryAccountType,
	|	Table.GLAccount,
	|	Table.CorrGLAccount,
	|	Table.CorrInventoryAccountType,
	|	Table.VATRate,
	|	Table.Responsible,
	|	Table.Department,
	|	Table.SalesOrder,
	|	Table.RIMTransfer,
	|	Table.SalesRep,
	|	Table.Counterparty,
	|	Table.Currency,
	|	Table.CostObject,
	|	Table.CorrCostObject,
	|	Table.CorrProducts,
	|	Table.CorrCharacteristic,
	|	Table.CorrBatch,
	|	Table.CorrOwnership,
	|	Table.CorrSpecification,
	|	Table.Specification,
	|	Table.IncomeAndExpenseItem,
	|	Table.CorrIncomeAndExpenseItem
	|	";
	
EndFunction
// end Drive.FullVersion

Function TextOfKitProcessingReceiptLandedCosts()
	
	Return "
	|	SELECT
	|	""KitProcessingReceiptLandedCosts"" AS QueryName,
	|	90 AS Priority,
	|	""KitProcessing"" AS RecordKind,
	|	FALSE AS FinishCalculation,
	|	Table.RecordType AS RecordType,
	|	Table.Period AS Period,
	|	Table.Recorder AS Recorder,
	|	Table.Company AS Company,
	|	Table.PresentationCurrency AS PresentationCurrency,
	|	Table.Products AS Products,
	|	Table.Characteristic AS Characteristic,
	|	Table.CostLayer AS CostLayer,
	|	Table.Batch AS Batch,
	|	Table.Ownership AS Ownership,
	|	Table.StructuralUnit AS StructuralUnit,
	|	Table.InventoryAccountType AS InventoryAccountType,
	|	Table.SalesOrder AS SalesOrder,
	|	0 AS Denominator,
	|	SUM(Table.Quantity) AS Quantity,
	|	SUM(Table.Quantity * ISNULL(CountOfLandedCosts.Count, 1)) AS TotalQuantity,
	|	0 AS Amount,
	|	Table.Recorder AS SourceDocument,
	|	Table.CorrStructuralUnit AS CorrStructuralUnit,
	|	UNDEFINED AS CorrSalesOrder,
	|	Table.GLAccount AS GLAccount,
	|	Table.CorrGLAccount,
	|	Table.CorrInventoryAccountType,
	|	Table.VATRate AS VATRate,
	|	Table.Responsible AS Responsible,
	|	UNDEFINED AS Department,
	|	FALSE AS SourceRecord,
	|	Table.RIMTransfer AS RIMTransfer,
	|	Table.SalesRep AS SalesRep,
	|	Table.Counterparty AS Counterparty,
	|	Table.Currency AS Currency,
	|	Table.CostObject,
	|	Table.CorrCostObject,
	|	Table.CorrProducts,
	|	Table.CorrCharacteristic,
	|	Table.CorrBatch,
	|	Table.CorrOwnership,
	|	Table.CorrSpecification,
	|	Table.Specification,
	|	Table.IncomeAndExpenseItem,
	|	Table.CorrIncomeAndExpenseItem
	|FROM
	|	AccumulationRegister.InventoryCostLayer AS Table
	|		INNER JOIN Document.Production AS Production
	|		ON Table.Recorder = Production.Ref
	|		LEFT JOIN CountOfLandedCosts AS CountOfLandedCosts
	|		ON Table.CostLayer = CountOfLandedCosts.CostLayer
	|WHERE
	|	Table.Period BETWEEN &BeginOfPeriod AND &EndOfPeriod
	|	AND Table.Company IN(&ArrayOfCompanies)
	|	AND Table.Active
	|	AND Table.RecordType = VALUE(AccumulationRecordType.Receipt)
	|	AND Table.Quantity > 0
	|
	|GROUP BY
	|	Table.RecordType,
	|	Table.Period,
	|	Table.Recorder,
	|	Table.Company,
	|	Table.PresentationCurrency,
	|	Table.Products,
	|	Table.SourceDocument,
	|	Table.Characteristic,
	|	Table.CostLayer,
	|	Table.Batch,
	|	Table.Ownership,
	|	Table.StructuralUnit,
	|	Table.CorrStructuralUnit,
	|	Table.InventoryAccountType,
	|	Table.GLAccount,
	|	Table.CorrGLAccount,
	|	Table.CorrInventoryAccountType,
	|	Table.VATRate,
	|	Table.Responsible,
	|	Table.Department,
	|	Table.SalesOrder,
	|	Table.RIMTransfer,
	|	Table.SalesRep,
	|	Table.Counterparty,
	|	Table.Currency,
	|	Table.CostObject,
	|	Table.CorrCostObject,
	|	Table.CorrProducts,
	|	Table.CorrCharacteristic,
	|	Table.CorrBatch,
	|	Table.CorrOwnership,
	|	Table.CorrSpecification,
	|	Table.Specification,
	|	Table.IncomeAndExpenseItem,
	|	Table.CorrIncomeAndExpenseItem
	|	";
	
EndFunction

Function TextOfSubcontractingReceiptLandedCosts()
	
	Return "
	|	SELECT
	|	""SubcontractingReceiptLandedCosts"" AS QueryName,
	|	90 AS Priority,
	|	""Subcontracting"" AS RecordKind,
	|	FALSE AS FinishCalculation,
	|	InventoryRegister.RecordType AS RecordType,
	|	InventoryRegister.Period AS Period,
	|	InventoryRegister.Recorder AS Recorder,
	|	InventoryRegister.Company AS Company,
	|	InventoryRegister.PresentationCurrency AS PresentationCurrency,
	|	InventoryRegister.Products AS Products,
	|	InventoryRegister.Characteristic AS Characteristic,
	|	InventoryCostLayer.CostLayer AS CostLayer,
	|	InventoryRegister.Batch AS Batch,
	|	InventoryRegister.Ownership AS Ownership,
	|	InventoryRegister.StructuralUnit AS StructuralUnit,
	|	InventoryRegister.InventoryAccountType AS InventoryAccountType,
	|	InventoryRegister.SalesOrder AS SalesOrder,
	|	0 AS Denominator,
	|	SUM(InventoryCostLayer.Quantity) AS Quantity,
	|	SUM(InventoryCostLayer.Quantity * ISNULL(CountOfLandedCosts.Count, 1)) AS TotalQuantity,
	|	0 AS Amount,
	|	InventoryRegister.Recorder AS SourceDocument,
	|	InventoryRegister.StructuralUnitCorr AS CorrStructuralUnit,
	|	InventoryRegister.CorrSalesOrder AS CorrSalesOrder,
	|	InventoryRegister.GLAccount AS GLAccount,
	|	InventoryRegister.CorrGLAccount AS CorrGLAccount,
	|	InventoryRegister.CorrInventoryAccountType AS CorrInventoryAccountType,
	|	InventoryRegister.VATRate AS VATRate,
	|	InventoryRegister.Responsible AS Responsible,
	|	UNDEFINED AS Department,
	|	FALSE AS SourceRecord,
	|	FALSE AS RIMTransfer,
	|	InventoryRegister.SalesRep AS SalesRep,
	|	InventoryRegister.Counterparty AS Counterparty,
	|	InventoryRegister.Currency AS Currency,
	|	InventoryRegister.CostObject AS CostObject,
	|	InventoryRegister.CostObjectCorr AS CorrCostObject,
	|	InventoryRegister.ProductsCorr AS CorrProducts,
	|	InventoryRegister.CharacteristicCorr AS CorrCharacteristic,
	|	InventoryRegister.BatchCorr AS CorrBatch,
	|	InventoryRegister.OwnershipCorr AS CorrOwnership,
	|	InventoryRegister.SpecificationCorr AS CorrSpecification,
	|	InventoryRegister.Specification AS Specification,
	|	InventoryRegister.IncomeAndExpenseItem AS IncomeAndExpenseItem,
	|	InventoryRegister.CorrIncomeAndExpenseItem AS CorrIncomeAndExpenseItem
	|FROM
	|	AccumulationRegister.Inventory AS InventoryRegister
	|		INNER JOIN Document.SubcontractorInvoiceReceived AS SubcontractorInvoiceReceived
	|		ON InventoryRegister.Recorder = SubcontractorInvoiceReceived.Ref
	|		INNER JOIN AccumulationRegister.InventoryCostLayer AS InventoryCostLayer
	|		ON InventoryRegister.RecordType = InventoryCostLayer.RecordType
	|			AND InventoryRegister.Company = InventoryCostLayer.Company
	|			AND InventoryRegister.PresentationCurrency = InventoryCostLayer.PresentationCurrency
	|			AND InventoryRegister.Products = InventoryCostLayer.Products
	|			AND InventoryRegister.Characteristic = InventoryCostLayer.Characteristic
	|			AND InventoryRegister.Batch = InventoryCostLayer.Batch
	|			AND InventoryRegister.Ownership = InventoryCostLayer.Ownership
	|			AND InventoryRegister.StructuralUnit = InventoryCostLayer.StructuralUnit
	|			AND InventoryRegister.CostObject = InventoryCostLayer.CostObject
	|			AND InventoryRegister.InventoryAccountType = InventoryCostLayer.InventoryAccountType
	|			AND (SubcontractorInvoiceReceived.BasisDocument = InventoryCostLayer.CostLayer)
	|		LEFT JOIN CountOfLandedCosts AS CountOfLandedCosts
	|		ON (InventoryCostLayer.CostLayer = CountOfLandedCosts.CostLayer)
	|WHERE
	|	InventoryRegister.Period BETWEEN &BeginOfPeriod AND &EndOfPeriod
	|	AND InventoryRegister.Company IN(&ArrayOfCompanies)
	|	AND InventoryRegister.Active
	|	AND InventoryRegister.RecordType = VALUE(AccumulationRecordType.Receipt)
	|	AND NOT InventoryRegister.OfflineRecord
	|	AND InventoryCostLayer.Period BETWEEN &BeginOfPeriod AND &EndOfPeriod
	|
	|GROUP BY
	|	InventoryRegister.RecordType,
	|	InventoryRegister.Period,
	|	InventoryRegister.Recorder,
	|	InventoryRegister.Company,
	|	InventoryRegister.PresentationCurrency,
	|	InventoryRegister.Products,
	|	InventoryRegister.Characteristic,
	|	InventoryCostLayer.CostLayer,
	|	InventoryRegister.Batch,
	|	InventoryRegister.Ownership,
	|	InventoryRegister.StructuralUnit,
	|	InventoryRegister.InventoryAccountType,
	|	InventoryRegister.GLAccount,
	|	InventoryRegister.CorrGLAccount,
	|	InventoryRegister.CorrInventoryAccountType,
	|	InventoryRegister.VATRate,
	|	InventoryRegister.Responsible,
	|	InventoryRegister.Department,
	|	InventoryRegister.SalesOrder,
	|	InventoryRegister.SalesRep,
	|	InventoryRegister.Counterparty,
	|	InventoryRegister.Currency,
	|	InventoryRegister.CostObject,
	|	InventoryRegister.Specification,
	|	InventoryRegister.IncomeAndExpenseItem,
	|	InventoryRegister.CorrIncomeAndExpenseItem,
	|	InventoryRegister.CorrSalesOrder,
	|	InventoryRegister.StructuralUnitCorr,
	|	InventoryRegister.CostObjectCorr,
	|	InventoryRegister.SpecificationCorr,
	|	InventoryRegister.BatchCorr,
	|	InventoryRegister.OwnershipCorr,
	|	InventoryRegister.CharacteristicCorr,
	|	InventoryRegister.ProductsCorr,
	|	InventoryRegister.Recorder
	|	";
	
EndFunction

#EndRegion

#EndRegion

#Region CalculateCostsLayers

Procedure CalculateCostsLayersByChains(RecordsDescription, DataForCalculation, CostLayers, Recorders)
	
	Receipts = New Map;
	Expenses = New Map;
	
	ReceiptsLines = CostLayers.CopyColumns();
	ExpensesLines = CostLayers.CopyColumns();
	
	Path = New Map;
	
	ExpensesIndexes = New Array;
	
	Chains = New Map;
	ChainsLines = New ValueTable;
	
	ExpensesLinesCount = 0;
	GrouppingKey = Undefined;
	
	Data = New Structure;
	Data.Insert("CostLayers",      CostLayers);
	Data.Insert("Chains",          Chains);
	Data.Insert("ChainsLines",     ChainsLines);
	Data.Insert("Receipts",        Receipts);
	Data.Insert("Expenses",        Expenses);
	Data.Insert("ReceiptsLines",   ReceiptsLines);
	Data.Insert("ExpensesLines",   ExpensesLines);
	Data.Insert("ExpensesIndexes", ExpensesIndexes);
	Data.Insert("Path",            Path);
	
	RecordsCount = RecordsCount(DataForCalculation);
	ConnectionCount = ConnectionCountBetweenRecords(DataForCalculation);
	
	LineIndex = -1;
	EndOfChain = -1;
	ArcsCount = 0;
	
	While LineIndex <= RecordsCount Do
		
		LineIndex = LineIndex + 1;
		If LineIndex > EndOfChain Then
			StartOfChain = LineIndex;
			EndOfChain = EndOfChain + 10000;
			Selection = SelectDataByIndex(DataForCalculation, StartOfChain, EndOfChain);
			ArcsCount = ChainsByIndex(DataForCalculation, StartOfChain, EndOfChain, Chains, ChainsLines);
		EndIf;
		
		If Not Selection.Next() Then
			Break;
		EndIf;
		
		Chain = Chains[LineIndex];
		If Chain = Undefined Then
			
			CostLayer = CostLayers.Add();
			FillPropertyValues(CostLayer, Selection);
			
		ElsIf Selection.FinishCalculation Then
			
			CostLayer = CostLayers.Add();
			FillPropertyValues(CostLayer, Selection);
			
			If Chain.Receivers.Count() > 0 Then
				Receipt = ReceiptsLines.Add();
				FillPropertyValues(Receipt, CostLayer);
				Revert = (Receipt.RecordKind = "Reversal");
				RevertFields(Receipt, RecordsDescription.Indicators, Revert);
				Receipts.Insert(LineIndex, New Array);
				Receipts[LineIndex].Add(Receipt);
			EndIf;
			
			Chains.Delete(LineIndex);
			ChainsLines.Delete(Chain);
		Else
			Expense = ExpensesLines.Add();
			FillPropertyValues(Expense, Selection);
			Expenses.Insert(LineIndex, Expense);
			ExpensesIndexes.Add(LineIndex);
		EndIf;
		
		If CostLayers.Count() > 100000 Then
			If RecordsDescription.Property("GroupingFields") Then
				CostLayers.GroupBy(RecordsDescription.GroupingFields, RecordsDescription.SumFields);
			EndIf;
			DeleteUnrecordedLines(RecordsDescription.Context, CostLayers);
			WriteCostsLayers(AccumulationRegisters[RecordsDescription.RegisterName], CostLayers, Recorders);
			CostLayers.Clear();
		EndIf;
		
		If LineIndex > 0 And LineIndex % 10000 = 0 Then
			
			Data.Insert("LineIndex", LineIndex);
			
			If Receipts.Count() > 0 Then // there are some records with property "FinishCalculation"
				While ExpensesIndexes.Count() > 0 Do
					ExpenseIndex = ExpensesIndexes.Get(0);
					ExpensesIndexes.Delete(0);
					If Expenses[ExpenseIndex] = Undefined Then
						Continue; // line is not registered for calculation
					EndIf;
					ExpenseBasis = Expenses[ExpenseIndex][RecordsDescription.ExpenseField];
					Path.Clear();
					CalculateCostLayersByChainsFromSelection(RecordsDescription, Data, ExpenseIndex, Recorders);
					
					Item = Expenses[ExpenseIndex];
					If Item <> Undefined
						And Item[RecordsDescription.ExpenseField] > 0 
						And Item[RecordsDescription.ExpenseField] <> ExpenseBasis Then
						ExpensesIndexes.Add(ExpenseIndex);
					EndIf;
					
					If CostLayers.Count() > 100000 Then
						If RecordsDescription.Property("GroupingFields") Then
							CostLayers.GroupBy(RecordsDescription.GroupingFields, RecordsDescription.SumFields);
						EndIf;
						DeleteUnrecordedLines(RecordsDescription.Context, CostLayers);
						WriteCostsLayers(AccumulationRegisters[RecordsDescription.RegisterName], CostLayers, Recorders);
						CostLayers.Clear();
					EndIf;
				EndDo;
					
				For Each Item In Expenses Do
					ExpenseIndex = Item.Key;
					ExpensesIndexes.Add(ExpenseIndex);
				EndDo;
				
				List = New ValueList;
				List.LoadValues(ExpensesIndexes);
				List.SortByValue();
				ExpensesIndexes = List.UnloadValues();
					
			EndIf;
			
		EndIf;
		
	EndDo;
	
	If LineIndex > EndOfChain Then
		StartOfChain = LineIndex;
		EndOfChain = EndOfChain + 10000;
		ArcsCount = ChainsByIndex(DataForCalculation, StartOfChain, EndOfChain, Chains, ChainsLines);
	EndIf;
	
	Data.Insert("LineIndex", LineIndex);
	While ExpensesIndexes.Count() > 0 Do
		
		ExpenseIndex = ExpensesIndexes.Get(0);
		ExpensesIndexes.Delete(0);
		
		If Expenses[ExpenseIndex] = Undefined Then
			Continue;
		EndIf;
		
		ExpenseBasis = Expenses[ExpenseIndex][RecordsDescription.ExpenseField];
		Path.Clear();
		
		CalculateCostLayersByChainsFromSelection(RecordsDescription, Data, ExpenseIndex, Recorders);
		
		Item = Expenses[ExpenseIndex];
		If Item <> Undefined 
			And Item[RecordsDescription.ExpenseField] > 0
			And Item[RecordsDescription.ExpenseField] <> ExpenseBasis Then
				ExpensesIndexes.Add(ExpenseIndex);
		EndIf;
			
		
		If CostLayers.Count() > 100000 Then
			If RecordsDescription.Property("GroupingFields") Then
				CostLayers.GroupBy(RecordsDescription.GroupingFields, RecordsDescription.SumFields);
			EndIf;
			DeleteUnrecordedLines(RecordsDescription.Context, CostLayers);
			WriteCostsLayers(AccumulationRegisters[RecordsDescription.RegisterName], CostLayers, Recorders);
			CostLayers.Clear();
		EndIf;
		
	EndDo;
	
	For Each Line In Expenses Do
		
		CostLayer = CostLayers.Add();
		FillPropertyValues(CostLayer, Line.Value);
		
		If CostLayers.Count() > 100000 Then
			If RecordsDescription.Property("GroupingFields") Then
				CostLayers.GroupBy(RecordsDescription.GroupingFields, RecordsDescription.SumFields);
			EndIf;
			DeleteUnrecordedLines(RecordsDescription.Context, CostLayers);
			WriteCostsLayers(AccumulationRegisters[RecordsDescription.RegisterName], CostLayers, Recorders);
			CostLayers.Clear();
		EndIf;
		
	EndDo;
	
	If RecordsDescription.Property("GroupingFields") Then
		CostLayers.GroupBy(RecordsDescription.GroupingFields, RecordsDescription.SumFields);
	EndIf;
	
	Selection = Undefined;
	Receipts.Clear();
	Expenses.Clear();
	ReceiptsLines.Clear();
	ExpensesLines.Clear();
	Chains.Clear();
	ChainsLines.Clear();
	
EndProcedure

Function CalculateCostLayersByChainsFromSelection(RecordsDescription, Data, ExpenseIndex, Recorders)
	
	CostLayers = Data.CostLayers;
	Path = Data.Path;
	Chains = Data.Chains;
	ChainsLines = Data.ChainsLines;
	ExpensionChain = Chains[ExpenseIndex];
	
	If ExpensionChain = Undefined Then
		Return "NoNeeded";
	EndIf;
	
	Sources = ExpensionChain.Sources;
	ThereIsLooping = False;
	If ExpenseIndex = Path[ExpenseIndex] Or (Sources.Count() = 0) Then
		ThereIsLooping = True;
	EndIf;
	
	LineIndex = Data.LineIndex;
	For Each ReceiptIndex In Sources Do
		If ReceiptIndex > LineIndex Then
			Return "NoData"; // no data
		EndIf;
	EndDo;
	
	Path.Insert(ExpenseIndex, ExpenseIndex);
	
	Receipts = Data.Receipts;
	Expenses = Data.Expenses;
	ReceiptsLines = Data.ReceiptsLines;
	NewReceipts = Undefined;
	ExpensesLines = Data.ExpensesLines;
	
	Expense = Expenses[ExpenseIndex];
	
	IsReversal = (Expense.RecordKind = "ReversalSalesOrders");
	
	ReceiptBasis = 0;
	If RecordsDescription.Property("GroupingFields") Or IsReversal Then
		For Each SourceIndex In Sources Do
			If Not ThereIsLooping
				And Data.Receipts[SourceIndex] = Undefined
				And Data.Expenses[SourceIndex] <> Undefined Then // source is not calculated
				Result = CalculateCostLayersByChainsFromSelection(RecordsDescription, Data, SourceIndex, Recorders);
				If Result = "NoData" Then
					Return Result;
				ElsIf Result = "Looping" Then
					ReceiptBasis = ReceiptBasis + Expenses[SourceIndex][RecordsDescription.ReceiptField];
				EndIf;
				If Data.Expenses[ExpenseIndex] = Undefined Then
					Return "NoNeeded";
				EndIf;
			ElsIf ThereIsLooping And Data.Expenses[SourceIndex] <> Undefined Then
				ReceiptBasis = ReceiptBasis + Expenses[SourceIndex][RecordsDescription.ReceiptField];
			EndIf;
		EndDo;
		If IsReversal Then
			SortSources(Sources, RecordsDescription.OrderField, Receipts);
		EndIf;
	EndIf;
	
	If ValueIsFilled(RecordsDescription.SortField) Then
		FiledsValues = New Structure(RecordsDescription.SortField);
		FillPropertyValues(FiledsValues, Expense);
		SortFieldsAreFilled = False;
		For Each SortField In FiledsValues Do
			If ValueIsFilled(SortField.Value) Then
				SortFieldsAreFilled = True;
				Break;
			EndIf;
		EndDo;
		NeedSort = True;
		If SortFieldsAreFilled Then
			SortSourcesByFieldsValues(Sources, FiledsValues, Receipts)
		EndIf;
	EndIf;
	
	Count = 0;
	Ubound = Sources.Ubound();
	BrekLooping = False;
	
	CostLayerIndex = -1;
	RevertFields(Expense, RecordsDescription.Indicators, IsReversal);
	While Count <= Ubound Do
		Index = ?(IsReversal, Ubound - Count, Count);
		SourceIndex = Sources[Index];
		Count = Count + 1;
		
		ReceiptsArray = Receipts[SourceIndex];
		If ReceiptsArray = Undefined Then
			If Expenses[SourceIndex] = Undefined Then
				Continue;
			EndIf;
			Source = Expenses[SourceIndex];
			If Not ThereIsLooping And Not Source.FinishCalculation Then
				CalculateCostLayersByChainsFromSelection(RecordsDescription, Data, SourceIndex, Recorders);
				UBound = Sources.UBound();
				If Data.Expenses[ExpenseIndex] = Undefined Or Chains[ExpenseIndex] = Undefined Then
					Return "NoNeeded";
				EndIf;
				ReceiptsArray = Receipts[SourceIndex];
				If ReceiptsArray = Undefined Then
					Continue;
				EndIf;
			EndIf;
		EndIf;
		
		If IsReversal Then
			SortReceiptsByLIFO(RecordsDescription.OrderField, ReceiptsArray);
		EndIf;
		
		ReceiptsForDelete = New Array;
		If ReceiptsArray <> Undefined Then
			For Each Receipt In ReceiptsArray Do
			
				CostLayer = CostLayers.Add();
				FillCostLayer(RecordsDescription.Context, CostLayer, Expense, Receipt);
				RevertFields(CostLayer, RecordsDescription.Indicators, IsReversal);
				
				If Receipt[RecordsDescription.ReceiptField] <= 0 Then
					ReceiptsForDelete.Add(Receipt);
				EndIf;
				
				If CostLayer.FinishCalculation Then
					If ExpensionChain.Receivers.Count() > 0 Then
						If RecordsDescription.Property("GroupingFields") Then
							If NewReceipts = Undefined Then
								NewReceipts = ReceiptsLines.CopyColumns();
							EndIf;
							NewReceipt = NewReceipts.Add();
							FillPropertyValues(NewReceipt, CostLayer);
							Revert = (NewReceipt.RecordKind = "ReversalSalesOrders");
							RevertFields(NewReceipt, RecordsDescription.Indicators, Revert);
						Else
							NewReceipt = ReceiptsLines.Add();
							FillPropertyValues(NewReceipt, CostLayer);
							Revert = (NewReceipt.RecordKind = "ReversalSalesOrders");
							RevertFields(NewReceipt, RecordsDescription.Indicators, Revert);
							If Receipts[ExpenseIndex] = Undefined Then
								Receipts.Insert(ExpenseIndex, New Array);
							EndIf;
							Receipts[ExpenseIndex].Add(NewReceipt);
						EndIf;
					EndIf;
				Else
					CostLayers.Delete(CostLayer);
				EndIf;
				
				If CostLayers.Count() > 100000 Then
					If RecordsDescription.Property("GroupingFields") Then
						CostLayers.GroupBy(RecordsDescription.GroupingFields, RecordsDescription.SumFields);
					EndIf;
					DeleteUnrecordedLines(RecordsDescription.Context, CostLayers);
					WriteCostsLayers(AccumulationRegisters[RecordsDescription.RegisterName], CostLayers, Recorders);
					CostLayers.Clear();
				EndIf;
				
				If Expense[RecordsDescription.ExpenseField] <= 0 Then
					Break;
				EndIf;
			EndDo;
		EndIf;
		For Each Receipt In ReceiptsForDelete Do
			Index = ReceiptsArray.Find(Receipt);
			If Index <> Undefined Then
				ReceiptsArray.Delete(Index);
			EndIf;
			ReceiptsLines.Delete(Receipt);
		EndDo;
		If ReceiptsArray <> Undefined Then
			If ReceiptsArray.Count() = 0 Then
				Receipts.Delete(SourceIndex);
				If Receipts[SourceIndex] = Undefined Then
					ReceiptChain = Chains[SourceIndex];
					If ReceiptChain <> Undefined Then
						Chains.Delete(SourceIndex);
						ChainsLines.Delete(ReceiptChain);
					EndIf;
				EndIf;
			ElsIf ReceiptsForDelete.Count() > 0 Then
				Receipts.Insert(SourceIndex, ReceiptsArray);
			EndIf;
		EndIf;
		If Expense[RecordsDescription.ExpenseField] <= 0 Then
			Break;
		EndIf;
	EndDo;
	
	ExpenseBasis = 0;
	If RecordsDescription.Property("GroupingFields")
		And NewReceipts <> Undefined
		And NewReceipts.Count() >0 Then
			NewReceipts.GroupBy(RecordsDescription.GroupingFields, RecordsDescription.SumFields);
			If Receipts[ExpenseIndex] = Undefined Then
				Receipts.Insert(ExpenseIndex, New Array);
			EndIf;
			For Each Line In NewReceipts Do
				NewReceipt = ReceiptsLines.Add();
				FillPropertyValues(NewReceipt, Line);
				Receipts[ExpenseIndex].Add(NewReceipt);
				If ExpenseBasis < NewReceipt[RecordsDescription.ExpenseField] Then
					ExpenseBasis = NewReceipt[RecordsDescription.ExpenseField];
				EndIf;
			EndDo;
			NewReceipts = Undefined;
	EndIf;
	
	If Expense.RecordKind = "Production"
		Or Expense.RecordKind = "KitProcessing"
		Or Expense.RecordKind = "Subcontracting" Then
		
		If CostLayers.Count() Then
			CostLayer = CostLayers[CostLayers.Count()-1];
			CostLayer.Quantity = Expense.Quantity;
			Expense.Quantity = 0;
			
			If Receipts[ExpenseIndex] <> Undefined Then
				LastReceiptIndex = Receipts[ExpenseIndex].Ubound();
				Receipts[ExpenseIndex][LastReceiptIndex].Quantity = CostLayer.Quantity;
			EndIf;
		EndIf;
		
	EndIf;
	
	If RecordsDescription.Property("GroupingFields") Then
		If Expense.RecordKind = "Transfer" And ReceiptBasis <> 0 Then
			Expense[RecordsDescription.ExpenseField] = ReceiptBasis;
		ElsIf ExpenseBasis > 0 And Expense[RecordsDescription.ExpenseField] - ExpenseBasis > 0 Then
			Expense[RecordsDescription.ExpenseField] = Expense[RecordsDescription.ExpenseField] - ExpenseBasis;
		Else
			Expense[RecordsDescription.ExpenseField] = 0;
		EndIf;
	EndIf;
	
	If Expense[RecordsDescription.ExpenseField] > 0 Then
		Revert = (Expense.RecordKind = "Reversal");
		RevertFields(Expense, RecordsDescription.Indicators, Revert);
		Expenses.Delete(ExpenseIndex);
		ExpensesLines.Delete(Expense);
	Else
		Expenses.Delete(ExpenseIndex);
		Chains.Delete(ExpenseIndex);
		ExpensesLines.Delete(Expense);
		ChainsLines.Delete(ExpensionChain);
	EndIf;
	
	Return "Complete";
EndFunction

Procedure FillCostLayer(Context, CostLayer, Expense, Receipt)
	
	If Context = "InventoryCostLayer" Then
		FillInventoryCostLayer(CostLayer, Expense, Receipt);
	ElsIf Context = "LandedCosts" Then
		FillLandedCostLayer(CostLayer, Expense, Receipt);
	EndIf;
	
EndProcedure

#Region Sort

Procedure SortSourcesByFieldsValues(Sources, FiledsValues, Receipts)
	
	List = New ValueList;
	ArrayItemIndex = -1;
	
	For Each SourceIndex In Sources Do
		
		ArrayItemIndex = ArrayItemIndex + 1;
		ReceiptArray = Receipts[SourceIndex];
		
		If ReceiptArray = Undefined Or ReceiptArray.Count() = 0 Then
			Shift = 0;
		Else
			Shift = FiledsValues.Count();
			For Each SortField In FiledsValues Do
				If ReceiptArray[0][SortField.Key] = SortField.Value Then
					Shift = Shift - 1;
				EndIf;
			EndDo;
		EndIf;
		List.Add(SourceIndex, Format(ArrayItemIndex + Shift * Sources.Count(), "ND=15; NFD=0; NLZ=; NG="));
	EndDo;
	
	If List.Count() > 0 Then
		List.SortByPresentation(SortDirection.Asc);
		Sources = List.UnloadValues();
	EndIf;
	
EndProcedure

Procedure SortSources(Sources, OrderField, CostLayers)
	
	For FirstSourceCount = 1 To Sources.UBound() Do
		
		FirstSource = Sources[FirstSourceCount];
		If CostLayers[FirstSource] = Undefined Then
			Continue;
		EndIf;
		
		If TypeOf(CostLayers[FirstSource]) = Type("Array") Then
			If CostLayers[FirstSource].Count() = 0 Then
				Continue;
			EndIf;
			FirstElement = CostLayers[FirstSource][0];
		Else
			FirstElement = CostLayers[FirstSource];
		EndIf;
		
		Item = New Structure("Order, Source", FirstElement[OrderField], FirstSource);
		SecondSourceCount = FirstSourceCount - 1;
		While SecondSourceCount >= 0 Do
			
			SecondSource = Sources[SecondSourceCount];
			If TypeOf(CostLayers[SecondSource] = Type("Array")) Then
				If CostLayers[SecondSource].Count() = 0 Then
					SecondSourceCount = SecondSourceCount - 1;
					Continue;
				EndIf;
				SecondElement = CostLayers[SecondSource][0];
			Else
				SecondElement = CostLayers[SecondSource];
			EndIf;
			
			If SecondElement = Undefined Then
				SecondSourceCount = SecondSourceCount - 1;
				Continue;
			EndIf;
			If SecondElement[OrderField] <= Item.Order Then
				Break;
			EndIf;
			
			Sources[SecondSourceCount + 1] = SecondSource;
			SecondSourceCount = SecondSourceCount - 1;
		EndDo;
		
		Sources[SecondSourceCount + 1] = Item.Source;
	EndDo;
	
EndProcedure

Procedure SortReceiptsByLIFO(OrderField, ReceiptsArray)
	
	List = New ValueList;
	For Each Receipt In ReceiptsArray Do
		List.Add(Receipt, Receipt[OrderField]);
	EndDo;
	List.SortByPresentation(SortDirection.Desc);
	
	ReceiptsArray = List.UnloadValues();
	
EndProcedure

#EndRegion

#Region Revert

Procedure RevertFields(Record, FieldsDescription, Invert)
	
	If Not Invert Then
		Return;
	EndIf;
	Fields = New Structure(FieldsDescription);
	For Each Field In Fields Do
		Record[Field.Key] = - Record[Field.Key];
	EndDo;
	
EndProcedure

#EndRegion

#Region Chains

Function ChainsByIndex(TempTables, StartIndex, EndIndex, Chains, ChainsLines)
	
	Columns = ChainsLines.Columns;
	If Columns.Count() = 0 Then
		Columns.Add("Sources", New TypeDescription("Array"));
		Columns.Add("Receivers", New TypeDescription("Array"));
		Columns.Add("Path", New TypeDescription("Map"));
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = TempTables;
	Query.SetParameter("StartIndex", StartIndex);
	Query.SetParameter("EndIndex", EndIndex);
	
	NodesConnectionsTables = New Structure;
	NodesConnectionsTables.Insert("Sources", "Source");
	NodesConnectionsTables.Insert("Receivers", "Receiver");
	
	QueryTemplate =
	"SELECT
	|	Table.Key AS Key,
	|	Table.%2 AS %2
	|FROM
	|	%1 AS Table
	|WHERE
	|	Table.Key >= &StartIndex
	|	AND Table.Key <= &EndIndex
	|	AND Table.Key <> Table.%2
	|
	|ORDER BY
	|	Key,
	|	Table.Order,
	|	%2";
	
	For Each TableDescription In NodesConnectionsTables Do
		
		Query.Text = StringFunctionsClientServer.SubstituteParametersToString(
			QueryTemplate,
			TableDescription.Key,
			TableDescription.Value);
			
		CurrentKey = -1;
		Line = Undefined;
		
		Selection = Query.Execute().Select();
		While Selection.Next() Do
			
			NewKey = Selection.Key;
			If CurrentKey <> NewKey Then
				
				If CurrentKey <> -1 Then
					Chains.Insert(CurrentKey, Line);
				EndIf;
				
				CurrentKey = NewKey;
				
				Line = Chains[CurrentKey];
				If Line = Undefined Then
					Line = ChainsLines.Add();
				EndIf;
				
			EndIf;
			
			Line[TableDescription.Key].Add(Selection[TableDescription.Value]);
			
		EndDo;
			
		If CurrentKey <> -1 Then
			Chains.Insert(CurrentKey, Line);
		EndIf;
			
	EndDo;
		
	Return Selection.Count();
EndFunction

Function SelectDataByIndex(TempTables, StartIndex, EndIndex)
	
	Query = New Query("
	|SELECT
	|	*
	|FROM
	|	Data AS Table
	|WHERE
	|	Table.K >= &StartIndex
	|	AND Table.K <= &EndIndex
	|
	|ORDER BY
	|	Table.K");
	
	Query.TempTablesManager = TempTables;
	Query.SetParameter("StartIndex", StartIndex);
	Query.SetParameter("EndIndex", EndIndex);
	
	Selection = Query.Execute().Select();
	
	Return Selection;
EndFunction

Function RecordsCount(TempTables)
	
	Query = New Query("
	|SELECT
	|	COUNT(DISTINCT Table.K) AS Count
	|FROM
	|	Data AS Table
	|");
	
	Query.TempTablesManager = TempTables;
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Count = Selection.Count;
	Else
		Count = 0;
	EndIf;
	
	Return Count;
EndFunction

Function ConnectionCountBetweenRecords(TempTables)
	
	Query = New Query("
	|SELECT
	|	COUNT(*) AS Count
	|FROM
	|	Sources AS Table
	|");
	
	Query.TempTablesManager = TempTables;
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Count = Selection.Count;
	Else
		Count = 0;
	EndIf;
	
	Return Count;
EndFunction

Function ListOfFields(Columns, Exceptions = "")
	ExcludedColumns = New Structure(Exceptions);
	ListOfFields = "";
	For Each Column In Columns Do
		If Not ExcludedColumns.Property(Column.Name) Then
			ListOfFields = ListOfFields + ?(ValueIsFilled(ListOfFields), ", ", "") + Column.Name;
		EndIf;
	EndDo;
	Return ListOfFields;
EndFunction

Function DescriptionOfChains(TypesOfChains)
	DescriptionOfChains = New Structure(TypesOfChains);
	For Each Description In DescriptionOfChains Do
		DescriptionOfChains[Description.Key] = New Structure("ConnectionFields, TypesOfSources, TypesOfRecipients");
		DescriptionOfChains[Description.Key].ConnectionFields = New Array;
		DescriptionOfChains[Description.Key].TypesOfSources = New Map;
		DescriptionOfChains[Description.Key].TypesOfRecipients = New Map;
	EndDo;
	Return DescriptionOfChains;
EndFunction

Procedure AddSourceDescription(DescriptionOfChains, ReceiptType, SourceType, SourceFields)
	ConnectionFields = New Array;
	DescriptionFields = New Structure(SourceFields);
	For Each DescriptionField In DescriptionFields Do
		ConnectionFields.Add(DescriptionField.Key);
	EndDo;
	DescriptionOfChains[SourceType].TypesOfRecipients.Insert(ReceiptType, ConnectionFields);
	DescriptionOfChains[ReceiptType].TypesOfSources.Insert(SourceType, ConnectionFields);
EndProcedure

Procedure AddReceiptDescription(DescriptionOfChains, ReceiptType, ReceiptFields)
	DescriptionFields = New Structure(ReceiptFields);
	For Each DescriptionField In DescriptionFields Do
		DescriptionOfChains[ReceiptType].ConnectionFields.Add(DescriptionField.Key);
	EndDo;
EndProcedure

Procedure GetChains(DescriptionOfChains, TempTables)
	
	QueryTemplate = "
	|SELECT
	|	Receivers.K AS Receiver,
	|	Sources.K AS Source
	|INTO
	|	&Result
	|FROM
	|	Data AS Receivers
	|	INNER JOIN Data AS Sources
	|	ON &Conditions
	|WHERE
	|	Receivers.K <> Sources.K
	|	AND Receivers.RecordKind = &ReceiverKind
	|	AND Sources.RecordKind = &SourceKind
	|;
	|";
	
	QueryText = "";
	Results = New Array();
	For Each Description In DescriptionOfChains Do
		ReceiptFields = Description.Value.ConnectionFields;
		If ReceiptFields.Count() = 0 Then
			Continue;
		EndIf;
		For Each SourceDescription In Description.Value.TypesOfSources Do
			
			SourceFields = SourceDescription.Value;
			If SourceFields.Count() = 0 Then
				Continue;
			EndIf;
			
			FieldNumber = -1;
			For Each ReceiptField In ReceiptFields Do
				FieldNumber = FieldNumber + 1;
				If FieldNumber = 0 Then
					Conditions = "Receivers." + ReceiptField + " = " + "Sources." + SourceFields[FieldNumber];
				Else
					Conditions = Conditions + Chars.LF + "		AND " + "Receivers." + ReceiptField + " = " + "Sources." + SourceFields[FieldNumber];
				EndIf;
			EndDo;
			
			QueryText = StrReplace(QueryTemplate, "&Result", Description.Key + SourceDescription.Key);
			QueryText = StrReplace(QueryText, "&Conditions", Conditions);
			Results.Add(Description.Key + SourceDescription.Key);
			Query = New Query(QueryText);
			Query.TempTablesManager = TempTables;
			Query.SetParameter("ReceiverKind", Description.Key);
			Query.SetParameter("SourceKind", SourceDescription.Key);
			Query.Execute();
			
		EndDo;
	EndDo;
	
	QueryText =
	"SELECT TOP 0
	|	-1 AS Receiver,
	|	-1 AS Source
	|INTO Chains
	|";
	
	QueryTemplate = "
	|
	|UNION ALL
	|
	|SELECT
	|	Table.Receiver,
	|	Table.Source
	|FROM
	|	&TableName AS Table
	|";
	
	For Each Result In Results Do
		QueryText = QueryText + StrReplace(QueryTemplate, "&TableName", Result);
	EndDo;
	
	QueryText = QueryText + ";";
	For Each Result In Results Do
		QueryText = QueryText + "
		|DROP "+ Result + ";";
	EndDo;
	
	Query = New Query(QueryText);
	Query.TempTablesManager = TempTables;
	Query.Execute(); // create Chains
	
	Query.Text =
	"SELECT DISTINCT
	|	Table.Receiver AS Key,
	|	Table.Source AS Source,
	|	0 AS Order
	|INTO Sources
	|FROM
	|	Chains AS Table
	|INDEX BY
	|	Key
	|;
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	Table.Source AS Key,
	|	Table.Receiver AS Receiver,
	|	0 AS Order
	|INTO Receivers
	|FROM
	|	Chains AS Table
	|INDEX BY
	|	Key
	|;
	|////////////////////////////////////////////////////////////////////////////////
	|DROP Chains
	|";
	
	Query.Execute();
	
	OptimizeNumerationInChains(TempTables);
	
EndProcedure

Procedure OptimizeNumerationInChains(TempTablesManager)
	
	ValueTableSize = TempTableSize(TempTablesManager, "Data");
	
	If ValueTableSize = 0 Then
		Return;
	EndIf;
	
	#Region Initialization
	
	CalculationParameters = CalculationParameters(TempTablesManager);
	
	Query = New Query;
	Query.TempTablesManager = CalculationParameters.TempTablesManager;
	
	Query.SetParameter("ValueTableSize", ValueTableSize);
	Query.SetParameter("LinesCountInValueTable", CalculationParameters.SelectionRestrictions.MaxLineCountInValueTable);
	
	Query.Text = 
	"SELECT TOP 0
	|	*
	|FROM
	|	Data AS Table";
	
	EmptyValueTable = Query.Execute().Unload();
	ValueTableColumns = EmptyValueTable.Columns;
	
	IsReceiptPeriodInData = (ValueTableColumns.Find("ReceiptPeriod") <> Undefined);
	IsPeriodInData = (ValueTableColumns.Find("Period") <> Undefined);
	IsRecorderInData = (ValueTableColumns.Find("Recorder") <> Undefined);
	
	ValueTableColumnsNames = "";
	For Each CurrentColumn In ValueTableColumns Do
		
		ColumnName = ?(CurrentColumn.Name = "K", "NewNumbers.NewNodeNumber AS K", "Table." + CurrentColumn.Name);
		
		ValueTableColumnsNames = ValueTableColumnsNames + ?(ValueTableColumnsNames = "", "", ",
			|	") + ColumnName;
		
	EndDo;
	
	#EndRegion
	
	#Region Ordering
	
	Query.Text =
	"SELECT
	|	Table.K AS NodeNumber,
	|	%1 AS ReceiptPeriod,
	|	%2 AS Period,
	|	%3 AS Recorder
	|INTO TempDataForOrdering
	|FROM
	|	Data AS Table
	|
	|INDEX BY
	|	ReceiptPeriod,
	|	Period,
	|	Recorder";
	
	Query.Text = StringFunctionsClientServer.SubstituteParametersToString(
		Query.Text,
		?(IsReceiptPeriodInData, "ISNULL(Table.ReceiptPeriod, DATETIME(1,1,1))", "DATETIME(1,1,1)"),
		?(IsPeriodInData, "ISNULL(Table.Period, DATETIME(1,1,1))", "DATETIME(1,1,1)"),
		?(IsRecorderInData, "ISNULL(Table.Recorder, UNDEFINED)", "UNDEFINED"));
		
	Query.Execute();
	
	Query.Text = 
	"SELECT DISTINCT
	|	%1 AS DelimeterValue,
	|	Table.ReceiptPeriod AS ReceiptPeriod,
	|	Table.Period AS Period,
	|	Table.Recorder AS Recorder
	|INTO TempFieldForOrdering
	|FROM
	|	TempDataForOrdering AS Table
	|
	|INDEX BY
	|	ReceiptPeriod,
	|	Period,
	|	Recorder";
	
	If IsReceiptPeriodInData Then
		DelimeterValue = "BEGINOFPERIOD(Table.ReceiptPeriod, DAY)";
	ElsIf IsPeriodInData Then
		DelimeterValue = "BEGINOFPERIOD(Table.Period, DAY)";
	Else
		DelimeterValue = "1";
	EndIf;
	
	Query.Text = StringFunctionsClientServer.SubstituteParametersToString(
		Query.Text,
		DelimeterValue);
			
	Query.Execute(); // create TempFieldForOrdering
	
	NumerationParameters = GetTempTableNumerationParameters(
		"DelimeterValue", // delimeter
		"", // resourses
		"ReceiptPeriod, Period, Recorder", // order
		"Order", // number
		"ReceiptPeriod, Period, Recorder", // index
		"", // incured
		False);
		
	FillLinesNumbersInTempTable(
		CalculationParameters,
		NumerationParameters,
		"TempFieldForOrdering");
		
	Query.Text = 
	"SELECT
	|	Table.NodeNumber AS NodeNumber,
	|	FieldForOrdering.Order AS Order
	|INTO TempNodeOrders
	|FROM
	|	TempDataForOrdering AS Table
	|	INNER JOIN TempFieldForOrdering AS FieldForOrdering
	|	ON Table.ReceiptPeriod = FieldForOrdering.ReceiptPeriod
	|		AND Table.Period = FieldForOrdering.Period
	|		AND Table.Recorder = FieldForOrdering.Recorder
	|
	|INDEX BY
	|	NodeNumber";
	
	Query.Execute(); // create TempNodeOrders
	
	DeleteTempTables(CalculationParameters, "TempDataForOrdering, TempFieldForOrdering");
	
	#EndRegion
	
	#Region SeparateGraph
	
	Query.Text =
	"SELECT
	|	Table.K AS NodeNumber,
	|	Table.K AS SubgraphNumber
	|INTO TempSubgraphsNodes
	|FROM
	|	Data AS Table
	|
	|INDEX BY
	|	NodeNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Table.Key AS NodeNumber,
	|	Table.Source AS ConnectedNode,
	|	TRUE AS IsSource
	|INTO TempNodesConnections
	|FROM
	|	Sources AS Table
	|
	|UNION ALL
	|
	|SELECT
	|	Table.Key,
	|	Table.Receiver,
	|	FALSE
	|FROM
	|	Receivers AS Table
	|
	|INDEX BY
	|	ConnectedNode,
	|	IsSource";
	
	Query.Execute(); // create TempSubgraphsNodes and TempNodesConnections
	
	ThereAreChanges = True;
	IterationsCount = 0;
	
	While ThereAreChanges Do
		
		IterationsCount = IterationsCount + 1;
		
		Query.Text = 
		"SELECT
		|	NodesConnections.NodeNumber AS NodeNumber,
		|	MIN(Table.SubgraphNumber) AS SubgraphNumber
		|INTO TempSubgraphConnectedNodes
		|FROM
		|	TempSubgraphsNodes AS Table
		|	INNER JOIN TempNodesConnections AS NodesConnections
		|	ON Table.NodeNumber = NodesConnections.ConnectedNode
		|
		|GROUP BY
		|	NodesConnections.NodeNumber
		|
		|INDEX BY
		|	NodeNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	Table.NodeNumber AS NodeNumber,
		|	SubgraphConnectedNodes.SubgraphNumber AS SubgraphNumber
		|INTO TempChangedSubgraph
		|FROM
		|	TempSubgraphsNodes AS Table
		|	INNER JOIN TempSubgraphConnectedNodes AS SubgraphConnectedNodes
		|	ON Table.NodeNumber = SubgraphConnectedNodes.NodeNumber
		|
		|WHERE
		|	 SubgraphConnectedNodes.SubgraphNumber < Table.SubgraphNumber
		|
		|INDEX BY
		|	NodeNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TempSubgraphConnectedNodes";
		
		Query.Execute(); // create TempChangedSubgraph
		
		ThereAreChanges = (TempTableSize(CalculationParameters, "TempChangedSubgraph") > 0);
		
		If ThereAreChanges Then
			
			Query.Text = 
			"SELECT
			|	Table.NodeNumber AS NodeNumber,
			|	CASE
			|		WHEN ChangesSubgraphs.NodeNumber IS NULL
			|			THEN Table.SubgraphNumber
			|		ELSE ChangesSubgraphs.SubgraphNumber
			|	END AS SubgraphNumber
			|INTO TempNewSubgraphsNodes
			|FROM
			|	TempSubgraphsNodes AS Table
			|		LEFT JOIN TempChangedSubgraph AS ChangesSubgraphs
			|		ON Table.NodeNumber = ChangesSubgraphs.NodeNumber
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|DROP TempSubgraphsNodes
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT
			|	Table.NodeNumber AS NodeNumber,
			|	Table.SubgraphNumber AS SubgraphNumber
			|INTO TempSubgraphsNodes
			|FROM
			|	TempNewSubgraphsNodes AS Table
			|
			|INDEX BY
			|	NodeNumber
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|DROP TempNewSubgraphsNodes";
			
			Query.Execute(); // update TempSubgraphsNodes
			
		EndIf;
		
		DeleteTempTables(CalculationParameters, "TempChangedSubgraph");
		
	EndDo;
	
	Query.Text =
	"SELECT
	|	Table.SubgraphNumber AS SubgraphNumber,
	|	SUM(1) AS NodesCount,
	|	SUM(1) AS NewNumberSubgraphFirstNode
	|INTO TempSubgraphs
	|FROM
	|	TempSubgraphsNodes AS Table
	|
	|GROUP BY
	|	Table.SubgraphNumber";
	
	Query.Execute(); // create TempSubgraphs
	
	NumerationParameters = GetTempTableNumerationParameters(
		"", // delimeter
		"", // resourses
		"NodesCount DESC, SubgraphNumber", // order
		"NewSubgraphNumber", // number
		"SubgraphNumber", // index
		"NewNumberSubgraphFirstNode"); // accumulation
	
	FillLinesNumbersInTempTable(
		CalculationParameters,
		NumerationParameters,
		"TempSubgraphs");
	
	#EndRegion
	
	#Region FindInGraph
	
	Query.Text = 
	"SELECT
	|	Table.NodeNumber AS NodeNumber,
	|	COUNT(DISTINCT Receivers.Receiver) AS ReceiversCount,
	|	0 AS SourcesCount
	|INTO TempSourcesReceivers
	|FROM
	|	TempSubgraphsNodes AS Table
	|	LEFT JOIN Receivers AS Receivers
	|		ON Table.NodeNumber = Receivers.Key
	|
	|GROUP BY
	|	Table.NodeNumber
	|
	|UNION ALL
	|
	|SELECT
	|	Table.NodeNumber,
	|	0,
	|	COUNT(DISTINCT Sources.Source)
	|FROM
	|	TempSubgraphsNodes AS Table
	|	LEFT JOIN Sources AS Sources
	|		ON Table.NodeNumber = Sources.Key
	|
	|GROUP BY
	|	Table.NodeNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Table.NodeNumber AS NodeNumber,
	|	Table.ReceiversCount AS ReceiversCount,
	|	Table.SourcesCount AS SourcesCount,
	|	CASE
	|		WHEN Table.ReceiversCount = 0 AND Table.SourcesCount = 0
	|			THEN &ValueTableSize
	|		WHEN Table.SourcesCount = 0
	|			THEN 1
	|		ELSE 0
	|	END AS WaveNumber
	|INTO TempNodesDescription
	|FROM
	|	(SELECT
	|		Table.NodeNumber AS NodeNumber,
	|		SUM(Table.ReceiversCount) AS ReceiversCount,
	|		SUM(Table.SourcesCount) AS SourcesCount
	|	FROM
	|		TempSourcesReceivers AS Table
	|
	|	GROUP BY
	|		Table.NodeNumber
	|	
	|	) AS Table
	|
	|INDEX BY
	|	NodeNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP TempSourcesReceivers
	|";
	
	Query.Execute(); // create TempNodesDescription
	
	ThereAreChanges = True;
	WaveNumber = 1;
	WaveNumberForCycle = 0;
	
	While ThereAreChanges Do
		
		WaveNumber = WaveNumber + 1;
		Query.SetParameter("WaveNumber", WaveNumber);
		
		Query.Text = 
		"SELECT DISTINCT
		|	Receivers.Receiver AS NodeNumber
		|INTO TempChangesNodesDescription
		|FROM
		|	TempNodesDescription AS Table
		|	INNER JOIN Receivers AS Receivers
		|		ON Table.NodeNumber = Receivers.Key
		|	INNER JOIN TempNodesDescription AS ReceiversNodesDescription
		|		ON Receivers.Receiver = ReceiversNodesDescription.NodeNumber
		|		AND (ReceiversNodesDescription.WaveNumber = 0)
		|
		|WHERE
		|	Table.WaveNumber = &WaveNumber - 1
		|
		|INDEX BY
		|	NodeNumber";
		
		Query.Execute(); // create ChangesNodesDescription
		
		ThereAreChanges = (TempTableSize(CalculationParameters, "TempChangesNodesDescription") > 0);
		
		If Not ThereAreChanges Then
			
			Query.Text = 
			"SELECT
			|	COUNT(*) AS NodesCountInLoops
			|FROM
			|	TempNodesDescription AS Table
			|WHERE
			|	Table.WaveNumber = 0";
			
			Selection = Query.Execute().Select();
			Selection.Next();
			
			ThereAreChanges = (Selection.NodesCountInLoops > 0); // if false, then finish
			
			If ThereAreChanges Then
				
				WaveNumberForLoops = ?(ValueIsFilled(WaveNumberForLoops), WaveNumberForLoops, WaveNumber);
				
				Query.Text = 
				"SELECT
				|	Table.SubgraphNumber AS SubgraphNumber,
				|	Table.NodeNumber AS NodeNumber,
				|	NodesDescription.ReceiversCount AS ReceiversCount
				|INTO TempNodesForFind
				|FROM
				|	TempSubgraphsNodes AS Table
				|	INNER JOIN TempNodesDescription AS NodesDescription
				|		ON Table.NodeNumber = NodesDescription.NodeNumber
				|WHERE
				|	NodesDescription.WaveNumber = 0
				|
				|INDEX BY
				|	SubgraphNumber,
				|	ReceiversCount
				|;
				|
				|////////////////////////////////////////////////////////////////////////////////
				|SELECT
				|	Table.SubgraphNumber AS SubgraphNumber,
				|	MIN(Table.ReceiversCount) AS ReceiversCount
				|INTO TempSubgraphsForFind
				|FROM
				|	TempNodesForFind AS Table
				|
				|GROUP BY
				|	Table.SubgraphNumber
				|
				|INDEX BY
				|	SubgraphNumber,
				|	ReceiversCount
				|;
				|
				|////////////////////////////////////////////////////////////////////////////////
				|DROP TempChangesNodesDescription
				|;
				|
				|////////////////////////////////////////////////////////////////////////////////
				|SELECT
				|	NodesForFind.SubgraphNumber AS SubgraphNumber,
				|	MIN(NodesForFind.NodeNumber) AS NodeNumber
				|INTO TempChangesNodesDescription
				|FROM
				|	TempNodesForFind AS NodesForFind
				|	INNER JOIN TempSubgraphsForFind AS SubgraphsForFind
				|	ON NodesForFind.SubgraphNumber = SubgraphsForFind.SubgraphNumber
				|		AND NodesForFind.ReceiversCount = SubgraphsForFind.ReceiversCount
				|
				|GROUP BY
				|	NodesForFind.SubgraphNumber
				|
				|INDEX BY
				|	NodeNumber";
				
				Query.Execute(); // create TempChangesNodesDescription
				
				DeleteTempTables(CalculationParameters, "TempNodesForFind, TempSubgraphsForFind");
				
			EndIf;
			
		EndIf;
		
		If ThereAreChanges Then
			
			Query.Text =
			"SELECT
			|	Table.NodeNumber AS NodeNumber,
			|	Table.ReceiversCount AS ReceiversCount,
			|	Table.SourcesCount AS SourcesCount,
			|	CASE
			|		WHEN ChangesNodesDescription.NodeNumber IS NULL
			|			THEN Table.WaveNumber
			|		ELSE &WaveNumber
			|	END AS WaveNumber
			|INTO TempNewNodesDescription
			|FROM
			|	TempNodesDescription AS Table
			|		LEFT JOIN TempChangesNodesDescription AS ChangesNodesDescription
			|		ON Table.NodeNumber = ChangesNodesDescription.NodeNumber
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|DROP TempNodesDescription
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT
			|	Table.NodeNumber AS NodeNumber,
			|	Table.ReceiversCount AS ReceiversCount,
			|	Table.SourcesCount AS SourcesCount,
			|	Table.WaveNumber AS WaveNumber
			|INTO TempNodesDescription
			|FROM
			|	TempNewNodesDescription AS Table
			|
			|INDEX BY
			|	Table.NodeNumber
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|DROP TempNewNodesDescription";
			
			Query.Execute(); // update TempNodesDescription
			
		EndIf;
		
		DeleteTempTables(CalculationParameters, "TempChangesNodesDescription");
		
	EndDo;
	
	#EndRegion
	
	#Region CalculateNewNumbersForNodes
	
	Query.Text = 
	"SELECT
	|	CAST(Subgraphs.NewNumberSubgraphFirstNode / &LinesCountInValueTable AS NUMBER (15,0)) AS DelimeterValue,
	|	Subgraphs.SubgraphNumber AS SubgraphNumber,
	|	Subgraphs.NewSubgraphNumber AS NewSubgraphNumber,
	|	Table.WaveNumber AS WaveNumber,
	|	Table.NodeNumber AS NodeNumber,
	|	Table.NodeNumber AS NewNodeNumber,
	|	NodeOrders.Order AS Order
	|INTO TempNewNodesNumbers
	|FROM
	|	TempNodesDescription AS Table
	|	
	|	INNER JOIN TempSubgraphsNodes AS NodesSubgraphs
	|	ON Table.NodeNumber = NodesSubgraphs.NodeNumber
	|	
	|	INNER JOIN TempSubgraphs AS Subgraphs
	|	ON NodesSubgraphs.SubgraphNumber = Subgraphs.SubgraphNumber
	|	
	|	INNER JOIN TempNodeOrders AS NodeOrders
	|	ON Table.NodeNumber = NodeOrders.NodeNumber";
	
	Query.Execute(); // create TempNewNodesNumbers
	
	NumerationParameters = GetTempTableNumerationParameters(
		"DelimeterValue", // delimeter
		"", // resourses
		"NewSubgraphNumber, WaveNumber, Order, NodeNumber", // order
		"NewNodeNumber", // number
		"NodeNumber", // index
		"",
		False);
		
	FillLinesNumbersInTempTable(
		CalculationParameters,
		NumerationParameters,
		"TempNewNodesNumbers");
		
	#EndRegion
	
	#Region ChangeNumerationsInTables
	
	Query.Text =
	"SELECT
	|	Table.NodeNumber AS Key,
	|	Table.ConnectedNode AS Source,
	|	NodeOrders.Order AS Order
	|INTO Sources_Temp
	|FROM
	|	TempNodesConnections AS Table
	|		INNER JOIN TempNodeOrders AS NodeOrders
	|		ON Table.ConnectedNode = NodeOrders.NodeNumber
	|			AND (Table.IsSource = TRUE)
	|
	|INDEX BY
	|	Key
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP Sources
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	NewKeysNumbers.NewNodeNumber AS Key,
	|	NewSourcesNumbers.NewNodeNumber AS Source,
	|	Table.Order AS Order
	|INTO Sources
	|FROM
	|	Sources_Temp AS Table
	|		INNER JOIN TempNewNodesNumbers AS NewKeysNumbers
	|		ON Table.Key = NewKeysNumbers.NodeNumber
	|		INNER JOIN TempNewNodesNumbers AS NewSourcesNumbers
	|		ON Table.Source = NewSourcesNumbers.NodeNumber
	|
	|INDEX BY
	|	Key
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP Sources_Temp";
	
	Query.Execute(); // update Sources
	
	Query.Text = 
	"SELECT
	|	Table.NodeNumber AS Key,
	|	Table.ConnectedNode AS Source,
	|	NodeOrders.Order AS Order
	|INTO Receivers_Temp
	|FROM
	|	TempNodesConnections AS Table
	|		INNER JOIN TempNodeOrders AS NodeOrders
	|		ON Table.ConnectedNode = NodeOrders.NodeNumber
	|			AND (Table.IsSource = FALSE)
	|
	|INDEX BY
	|	Key
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP Receivers
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	NewKeysNumbers.NewNodeNumber AS Key,
	|	NewReceiversNumbers.NewNodeNumber AS Receiver,
	|	Table.Order AS Order
	|INTO Receivers
	|FROM
	|	Receivers_Temp AS Table
	|		INNER JOIN TempNewNodesNumbers AS NewKeysNumbers
	|		ON Table.Key = NewKeysNumbers.NodeNumber
	|		INNER JOIN TempNewNodesNumbers AS NewReceiversNumbers
	|		ON Table.Source = NewReceiversNumbers.NodeNumber
	|
	|INDEX BY
	|	Key
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP Receivers_Temp";
	
	Query.Execute(); // update Receivers
	
	Query.Text =
	"SELECT TOP 1
	|	TRUE AS ThereAreSomeDifferents
	|FROM
	|	TempNewNodesNumbers AS Table
	|WHERE
	|	Table.NodeNumber <> Table.NewNodeNumber";
	
	ThereAreChanges = Not Query.Execute().IsEmpty();
	
	If ThereAreChanges Then
		
		Query.Text =
		"SELECT
		|	*
		|INTO Data_Temp
		|FROM
		|	Data AS Table
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP Data
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	%1
		|INTO Data
		|FROM
		|	Data_Temp AS Table
		|	INNER JOIN TempNewNodesNumbers AS NewNumbers
		|	ON Table.K = NewNumbers.NodeNumber
		|
		|INDEX BY
		|	K
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP Data_Temp";
		
		Query.Text = StringFunctionsClientServer.SubstituteParametersToString(Query.Text, ValueTableColumnsNames);
		
		Query.Execute(); // update Data
		
	EndIf;
	
	#EndRegion
	
	#Region DescriptionStatisticsGraph

	Query.Text = 
	"SELECT
	|	Table.NewNodeNumber AS NodeNumber,
	|	Table.NewSubgraphNumber AS SubgraphNumber,
	|	Table.WaveNumber AS WaveNumber,
	|	Table.Order AS Order,
	|	NodesDescription.ReceiversCount AS ReceiversCount,
	|	NodesDescription.SourcesCount AS SourcesCount
	|INTO SubgraphsNodesDescription
	|FROM
	|	TempNewNodesNumbers AS Table
	|		INNER JOIN TempNodesDescription AS NodesDescription
	|		ON Table.NodeNumber = NodesDescription.NodeNumber
	|
	|INDEX BY
	|	NodeNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Table.SubgraphNumber AS SubgraphNumber,
	|	COUNT(DISTINCT Table.WaveNumber) AS WaveCount,
	|	SUM(Table.SourcesCount) AS ConnectionsCount,
	|	COUNT(DISTINCT Table.NodeNumber) AS NodesCount,
	|	MIN(Table.NodeNumber) AS MinNodeNumber,
	|	MAX(Table.NodeNumber) AS MaxNodeNumber,
	|	MAX(Table.ReceiversCount) AS MaxReceiversCount,
	|	MAX(Table.SourcesCount) AS MaxSourcesCount
	|INTO SubgraphsDescription
	|FROM
	|	SubgraphsNodesDescription AS Table
	|
	|GROUP BY
	|	Table.SubgraphNumber
	|
	|INDEX BY
	|	SubgraphNumber";
	
	Query.Execute(); // create SubgraphsNodesDescription and SubgraphsDescription
	
	#EndRegion
	
	DeleteTempTables(CalculationParameters,
		"TempNodeOrders, TempSubgraphsNodes, TempNodesConnections, TempSubgraphs, TempNodesDescription, TempNewNodesNumbers");
	
EndProcedure

Function CalculationParameters(TempTablesManager)
	
	CalculationParameters = New Structure;
	CalculationParameters.Insert("TempTablesManager", TempTablesManager);
	CalculationParameters.Insert("SelectionRestrictions", New Structure);
	CalculationParameters.SelectionRestrictions.Insert("MaxLineCountInValueTable", 100000);
	
	Return CalculationParameters;
EndFunction

#EndRegion

#Region WorkWithRegister

Procedure ClearRegister(Recorders, RegisterName, SaveRecordsInRegisters = Undefined)
	
	For Each Recorder In Recorders Do
		
		If SaveRecordsInRegisters <> Undefined
			And SaveRecordsInRegisters.Get(Recorder.Key) <> Undefined Then
			SaveRecordsInRegisters.Insert(Recorder.Key, True);
			Continue;
		EndIf;
		
		Records = AccumulationRegisters[RegisterName].CreateRecordSet();
		Records.Filter.Recorder.Set(Recorder.Key);
		Records.Write();
		
	EndDo;
	
EndProcedure

Procedure WriteCostsLayers(RegisterManager, CostLayers, Recorders)
	
	If CostLayers.Count() = 0 Then
		Return;
	EndIf;
	
	FilledRecordsCount = 0;
	RecordersCount = 0;
	
	CostLayers.Sort("Recorder", New CompareValues);
	
	Records = RegisterManager.CreateRecordSet();
	
	MetadataRegister = Records.Metadata();
	ResourcesStructure = New Structure;
	For Each Resource In MetadataRegister.Resources Do
		ResourcesStructure.Insert(Resource.Name, 0);
	EndDo;
	
	Recorder = Undefined;
	Replace = True;
	Count = 0;
	MaxCount = CostLayers.Count() - 1;
	
	While Count <= MaxCount Do
		
		CostLayer = CostLayers[Count];
		If Recorder <> CostLayer.Recorder Then
			Recorder = CostLayer.Recorder;
			
			Records.Clear();
			Records.Filter.Recorder.Set(Recorder);
			
			If Recorders <> Undefined Then
				If Recorders[Recorder] <> Undefined Then
					Replace = True;
					Recorders.Delete(Recorder);
				Else
					Replace = False;
				EndIf;
			EndIf;
		EndIf;
		
		FillPropertyValues(ResourcesStructure, CostLayer);
		
		If Not DriveClientServer.ValuesInStructureNotFilled(ResourcesStructure) Then
			Record = Records.Add();
			FillPropertyValues(Record, CostLayer);
		EndIf;
		
		Count = Count + 1;
		
		If Count > MaxCount Or (Recorder <> CostLayers[Count].Recorder) Then
			If Replace Or Records.Count() > 0 Then
				Records.Write(Replace);
			EndIf;
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure DeleteUnrecordedLines(Context, CostLayers)
	
	TypesForDelete = New Structure;
	
	If Context = "InventoryCostLayer" Then 
		TypesForDelete.Insert("Balance");
		TypesForDelete.Insert("PreviousPeriods");
		DeleteUncalculation = False;
		DeleteWithZeroAmount = False;
	ElsIf Context = "LandedCosts" Then
		TypesForDelete.Insert("Balance");
		TypesForDelete.Insert("PreviousPeriods");
		DeleteUncalculation = True;
		DeleteWithZeroAmount = True;
	EndIf;
	
	MinIndex = 1 - CostLayers.Count();
	For Index = MinIndex To 0 Do
		CostLayer = CostLayers[-Index];
		RecordWasDeleted = False;
		If (DeleteUncalculation And CostLayer.FinishCalculation <> True)
			Or TypesForDelete.Property(CostLayer.RecordKind) Then
			CostLayers.Delete(-Index);
			RecordWasDeleted = True;
		EndIf;
		If Not RecordWasDeleted And DeleteWithZeroAmount
			And CostLayer.Amount = 0 Then
			CostLayers.Delete(-Index);
		EndIf;
	EndDo;
	
EndProcedure

#EndRegion

#EndRegion

#Region WorkWithTempTables

Function TempTableSize(TempTablesContainer, TempTableName)
	
	Query = New Query;
	Query.TempTablesManager = GetTempTablesManagerFromContainer(TempTablesContainer);
	Query.Text = 
	"SELECT
	|	COUNT(*) AS LineCount
	|FROM
	|	%1 AS Table";
	
	Query.Text = StringFunctionsClientServer.SubstituteParametersToString(Query.Text, TempTableName);
	
	Selection = Query.Execute().Select();
	Selection.Next();
	
	Return Selection.LineCount;
EndFunction

Function GetTempTablesManagerFromContainer(TempTablesContainer)
	
	If TypeOf(TempTablesContainer) = Type("TempTablesManager") Then
		TempTablesManager = TempTablesContainer;
	Else
		TempTablesManager = TempTablesContainer.TempTablesManager;
	EndIf;
		
	Return TempTablesManager;
EndFunction

Procedure TempTableOnFilter(FilterField, OrderText, Table, TempTablesManager)
	
	CalculationParameters = CalculationParameters(TempTablesManager);
	
	OrderText = StrReplace(OrderText, "	", " ");
	OrderText = StrReplace(OrderText, Chars.LF, " ");
	OrderText = StrReplace(Lower(OrderText), "order by", "");
	
	NumerationParameters = GetTempTableNumerationParameters(
		FilterField, // delimeter
		"", // resourses
		TrimAll(OrderText)); // order
		
	FillLinesNumbersInTempTable(
		CalculationParameters,
		NumerationParameters,
		"SourceData",
		"Data");
	
EndProcedure

Procedure DeleteTempTables(TempTablesContainer, TablesNames)
	
	Query = New Query;
	Query.TempTablesManager = GetTempTablesManagerFromContainer(TempTablesContainer);
	
	TablesStructure = New Structure(TablesNames);
	QueryText = "";
	
	For Each KeyAndValue In TablesStructure Do
		
		If Not TempTableIsExist(Query.TempTablesManager, KeyAndValue.Key) Then
			Continue;
		EndIf;
		
		QueryText = QueryText
			+ ?(QueryText = "", "", DriveClientServer.GetQueryDelimeter())
			+ "
			|DROP " + KeyAndValue.Key;
			
	EndDo;
		
	If ValueIsFilled(QueryText) Then
		Query.Text = QueryText;
		Query.Execute();
	EndIf;
	
EndProcedure

Function TempTableIsExist(TempTablesContainer, TempTableName)
	
	TempTablesManager = GetTempTablesManagerFromContainer(TempTablesContainer);
	
	For Each TempTable In TempTablesManager.Tables Do
		If Lower(TempTable.FullName) = Lower(TempTableName) Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
EndFunction

Function GetTempTableNumerationParameters(DelimeterName = "",
	SumFieldsNames = "", OrderFieldsNames = "", LineNumberName = "",
	IndexFieldsNames = "", IncuredFieldsNames = "", SearchDelimeter = True)
	
	NumerationParameters = New Structure;
	NumerationParameters.Insert("DelimeterName",       DelimeterName);
	NumerationParameters.Insert("OptimalDelimeter",   ?(SearchDelimeter, "", DelimeterName));
	NumerationParameters.Insert("SumFieldsNames",     SumFieldsNames);
	NumerationParameters.Insert("OrderFieldsNames",   ?(Not ValueIsFilled(OrderFieldsNames), DelimeterName, OrderFieldsNames));
	NumerationParameters.Insert("LineNumberName",     ?(Not ValueIsFilled(LineNumberName), GetDefaultLineNumberName(), LineNumberName));
	NumerationParameters.Insert("IndexFieldsNames",   ?(Not ValueIsFilled(IndexFieldsNames), NumerationParameters.LineNumberName, IndexFieldsNames));
	NumerationParameters.Insert("IncuredFieldsNames", IncuredFieldsNames);
	
	Return NumerationParameters;
EndFunction

Function GetDefaultLineNumberName()
	Return "K";
EndFunction

Procedure FillLinesNumbersInTempTable(CalculationParameters, NumerationParameters, TableName, NumerationTableName = Undefined)
	
	If Not ValueIsFilled(NumerationTableName) Then
		NumerationTableName = TableName;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = CalculationParameters.TempTablesManager;
	Query.SetParameter("PortionSize", CalculationParameters.SelectionRestrictions.MaxLineCountInValueTable);
	
	Query.Text = 
	"SELECT TOP 0
	|	Table.*
	|FROM
	|	%1 AS Table";
	
	Query.Text = StringFunctionsClientServer.SubstituteParametersToString(Query.Text, TableName);
	
	EmptyTable = Query.Execute().Unload();
	
	If ValueIsFilled(NumerationParameters.SumFieldsNames) Then
		
		SumFieldsNamesStructure = New Structure(NumerationParameters.SumFieldsNames);
		
		FieldTableText = "";
		GroupTableText = "";
		
		For Each Column In EmptyTable.Columns Do
			
			If SumFieldsNamesStructure.Property(Column.Name) Then
				FieldTableText = FieldTableText + ?(FieldTableText = "", "", ",
					|	") + "SUM(Table." + Column.Name + ") AS " + Column.Name;
			Else
				FieldTableText = FieldTableText + ?(FieldTableText = "", "", ",
					|	") + "Table." + Column.Name + " AS " + Column.Name;
				GroupTableText = GroupTableText + ?(GroupTableText = "", "", "
					|	") + "Table." + Column.Name;
			EndIf;
			
			
		EndDo;
		
		GroupTableText = ?(GroupTableText = "", "", "GROUP BY
			|	") + GroupTableText;
		
		Query.Text = 
		"SELECT
		|	%1
		|INTO %2ForGrouping
		|FROM
		|	%2 AS Table
		|%3
		|;
		|////////////////////////////////////////////////////////////////////////////////
		|DROP %2
		|;
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	Table.*
		|INTO %2
		|FROM
		|	%2ForGrouping AS Table
		|;
		|////////////////////////////////////////////////////////////////////////////////
		|DROP %2ForGrouping
		|";
		
		Query.Text = StringFunctionsClientServer.SubstituteParametersToString(Query.Text, FieldTableText, TableName, GroupTableText);
		Query.Execute();
		
	EndIf;
	
	NumerationParameters.OptimalDelimeter = GetOptimalDelimeter(CalculationParameters, NumerationParameters, TableName, EmptyTable);
	
	SeparateTableOnPortions = ValueIsFilled(NumerationParameters.OptimalDelimeter);
	
	SumFieldsNames = NumerationParameters.SumFieldsNames;
	
	NamesOfAllOrderFields = StrReplace(
		?(ValueIsFilled(NumerationParameters.OrderFieldsNames), NumerationParameters.OrderFieldsNames, NumerationParameters.OptimalDelimeter),
		"	",
		" ");
		
	StructureExceptionFields = New Structure(NumerationParameters.LineNumberName + ", LineNumber, QueryName, FinishCalculation");
	StructureFieldsNames = New Structure( // NamesOfAllOrderFields and SumFieldsNames uses as keys.
		StrReplace(StrReplace(Lower(NamesOfAllOrderFields), " asc", ""), " desc", "")
		+ ?(SumFieldsNames = "" Or NamesOfAllOrderFields = "", "", ", ") + SumFieldsNames);
		
		For Each DataColumn In EmptyTable.Columns Do
			
			If StructureExceptionFields.Property(DataColumn.Name) // service field
				Or StructureFieldsNames.Property(DataColumn.Name) Then // already used
				Continue;
			EndIf;
			
			If IsSummableDataColumn(DataColumn) Then
				SumFieldsNames = SumFieldsNames + ?(SumFieldsNames = "", "", ", ") + DataColumn.Name;
			Else
				NamesOfAllOrderFields = NamesOfAllOrderFields + ?(NamesOfAllOrderFields = "", "", ", ")
					+ DataColumn.Name;
			EndIf;
			
			StructureFieldsNames.Insert(StructureFieldsNames);
			
		EndDo;
		
	NamesOfAllOrderFields = NamesOfAllOrderFields
		+ ?(SumFieldsNames = "" Or NamesOfAllOrderFields = "", "", ", ") + SumFieldsNames;
		
	AddColumnForLineNumeration(EmptyTable, NumerationParameters.LineNumberName);
	
	ColumnsNames = "";
	For Each CurrentColumn In EmptyTable.Columns Do
		ColumnsNames = ColumnsNames + ?(ColumnsNames = "", "", ", ") + "Table." + CurrentColumn.Name;
	EndDo;
	
	If SeparateTableOnPortions Then
		
		Query.Text = 
		"SELECT
		|	Table.%2 AS Delimeter,
		|	SUM(CAST(1 AS NUMBER(15,0))) AS LinesCount
		|INTO TempLinesPortions
		|FROM
		|	%1 AS Table
		|GROUP BY
		|	Table.%2";
		
		Query.Text = StringFunctionsClientServer.SubstituteParametersToString(
			Query.Text,
			TableName,
			NumerationParameters.OptimalDelimeter);
			
		Query.Execute();
			
		SeparateParameters = GetSeparateParametersTempTableOnPortions(
			CalculationParameters.SelectionRestrictions.MaxLineCountInValueTable,
			"LinesCount",
			"Delimeter",
			,
			"Delimeter, PortionNumber");
			
		MaxPortionNumber = SeparateTempTableOnPortions(CalculationParameters, SeparateParameters, "TempLinesPortions");
		
	Else
		
		MaxPortionNumber = 1; // one table is one potrion
		
	EndIf;
	
	LineNumber = 0;
	
	For PortionNumber = 1 To Max(MaxPortionNumber, 1) Do
		
		If MaxPortionNumber > 1 Then
			
			Query.SetParameter("PortionNumber", PortionNumber);
			
			Query.Text = 
			"SELECT
			|	Table.*
			|FROM
			|	%1 AS Table
			|	INNER JOIN TempLinesPortions AS LinesPortions
			|	ON Table.%2 = LinesPortions.Delimeter
			|		AND LinesPortions.PortionNumber = &PortionNumber
			|ORDER BY
			|	%3";
			
		Else
			
			Query.Text =
			"SELECT
			|	Table.*
			|FROM
			|	%1 AS Table
			|ORDER BY
			|	%3";
			
		EndIf;
		
		Query.Text = StringFunctionsClientServer.SubstituteParametersToString(
			Query.Text,
			TableName,
			NumerationParameters.OptimalDelimeter,
			NamesOfAllOrderFields);
			
		Table = Query.Execute().Unload();
		
		AddColumnForLineNumeration(Table, NumerationParameters.LineNumberName);
		
		CorrectEmptyColumnsTypesOfTable(Table);
		
		TotalValue = 0;
		
		For Each CurrentLine In Table Do
			
			CurrentLine[NumerationParameters.LineNumberName] = LineNumber;
			LineNumber = LineNumber + 1;
			
			If ValueIsFilled(NumerationParameters.IncuredFieldsNames) Then
				CurrenTotalValue = CurrentLine[NumerationParameters.IncuredFieldsNames];
				CurrentLine[NumerationParameters.IncuredFieldsNames] = TotalValue;
				TotalValue = TotalValue + CurrenTotalValue;
			EndIf;
			
		EndDo;
		
		If PortionNumber = 1 Then // select the first portion
			
			Query.Text = 
			"SELECT
			|	%2
			|INTO %1ForNumeration
			|FROM
			|	&Table AS Table";
			
		Else // select the second or next portions
			
			Query.Text = 
			"SELECT
			|	%2
			|INTO %1ForNumeration2
			|FROM
			|	&Table AS Table
			|;
			|//////////////////////////////////////
			|SELECT
			|	%2
			|INTO %1ForNumeration3
			|FROM
			|	%1ForNumeration AS Table
			|
			|UNION ALL
			|
			|SELECT
			|	%2
			|FROM
			|	%1ForNumeration2 AS Table
			|;
			|//////////////////////////////////////
			|DROP %1ForNumeration
			|;
			|//////////////////////////////////////
			|DROP %1ForNumeration2
			|;
			|//////////////////////////////////////
			|SELECT
			|	%2
			|INTO %1ForNumeration
			|FROM
			|	%1ForNumeration3 AS Table
			|;
			|//////////////////////////////////////
			|DROP %1ForNumeration3";
			
		EndIf;
		
		Query.Text = StringFunctionsClientServer.SubstituteParametersToString(
			Query.Text,
			TableName,
			ColumnsNames);
			
		Query.SetParameter("Table", Table);
		Query.Execute();
		
	EndDo;
	
	Query.Text = 
	"DROP %1
	|;
	|//////////////////////////////////////
	|SELECT
	|	%3
	|INTO %2
	|FROM
	|	%1ForNumeration AS Table
	|%4
	|;
	|//////////////////////////////////////
	|DROP %1ForNumeration";
	
	Query.Text = StringFunctionsClientServer.SubstituteParametersToString(
		Query.Text,
		TableName,
		NumerationTableName,
		ColumnsNames,
		?(Not ValueIsFilled(NumerationParameters.IndexFieldsNames), "", "INDEX BY " + NumerationParameters.IndexFieldsNames));
		
	Query.Execute();
	
	If SeparateTableOnPortions Then
		DeleteTempTables(CalculationParameters, "TempLinesPortions");
	EndIf;
		
	ValueTableSize = TempTableSize(Query, NumerationTableName);
	
	If ValueTableSize > 0 Then
		
		Query.Text = 
		"SELECT
		|	SUM(Table.CountNumbers) AS CountNumbers,
		|	SUM(Table.MinNumber) AS MinNumber,
		|	SUM(Table.MaxNumber) AS MaxNumber
		|FROM
		|	(SELECT
		|		COUNT(DISTINCT Table.%2) AS CountNumbers,
		|		0 AS MinNumber,
		|		0 AS MaxNumber
		|	FROM
		|		%1 AS Table
		|
		|	UNION ALL
		|	
		|	SELECT
		|		 0,
		|		MIN(Table.%2),
		|		MAX(Table.%2)
		|	FROM
		|		%1 AS Table
		|	
		|	) AS Table";
		
			Query.Text = StringFunctionsClientServer.SubstituteParametersToString(
				Query.Text,
				NumerationTableName,
				NumerationParameters.LineNumberName);
				
			Selection = Query.Execute().Select();
			Selection.Next();
			
			If Selection.CountNumbers <> ValueTableSize Then
				ErrorText = NStr("en = 'Error on numeration temp table. Numbers is not unique'; ru = 'Ошибка во временной таблице нумерации. Неуникальный номер.';pl = 'Błąd nr w tabeli temp. Liczby nie są unikalne';es_ES = 'Error de la tabla del modelo de numeración. Números no son únicos';es_CO = 'Error de la tabla del modelo de numeración. Números no son únicos';tr = 'Numaralandırma şablon tablosunda hata. Sayılar benzersiz değil';it = 'Errore nella tabella numerazione temp. I numeri non sono univoci';de = 'Fehler bei Nummerierung der temporären Tabelle. Zahlen sind nicht eindeutig'");
			ElsIf Selection.MinNumber <> 0 Then 
				ErrorText = NStr("en = 'Error on numeration temp table. Minimal number is incorrect'; ru = 'Ошибка во временной таблице нумерации. Неправильный минимальный номер';pl = 'Błąd nr w tabeli temp. Minimalna liczba jest niepoprawna';es_ES = 'Error de la tabla del modelo de numeración. Número mínimo es incorrecto';es_CO = 'Error de la tabla del modelo de numeración. Número mínimo es incorrecto';tr = 'Numaralandırma şablon tablosunda hata. Minimal sayı yanlış';it = 'Errore nella tabella numerazione temp. Il numero minimo non è corretto';de = 'Fehler bei Nummerierung der temporären Tabelle. Minimale Zahl ist falsch'");
			ElsIf Selection.MaxNumber <> ValueTableSize - 1 Then
				ErrorText = NStr("en = 'Error on numeration temp table. Maximum number is incorrect'; ru = 'Ошибка во временной таблице нумерации. Неправильный максимальный номер';pl = 'Błąd nr w tabeli temp. Maksymalna liczba jest niepoprawna';es_ES = 'Error de la tabla del modelo de numeración. Número máximo es incorrecto';es_CO = 'Error de la tabla del modelo de numeración. Número máximo es incorrecto';tr = 'Numaralandırma şablon tablosunda hata. Maksimum sayı yanlış';it = 'Errore nella tabella numerazione temp. Il numero massimo non è corretto';de = 'Fehler bei Nummerierung der temporären Tabelle. Maximale Zahl ist falsch'");
			Else
				ErrorText = "";
			EndIf;
			
			If ValueIsFilled(ErrorText) Then
				Raise ErrorText;
			EndIf;
			
	EndIf;
	
EndProcedure

Function GetOptimalDelimeter(CalculationParameters, NumerationParameters, TableName, EmptyTable)
	
	If ValueIsFilled(NumerationParameters.OptimalDelimeter) Then
		Return NumerationParameters.OptimalDelimeter; // already defined
	ElsIf TempTableSize(CalculationParameters, TableName) <= CalculationParameters.SelectionRestrictions.MaxLineCountInValueTable Then
		Return ""; // no need
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = CalculationParameters.TempTablesManager;
	
	Query.SetParameter("PortionSize", CalculationParameters.SelectionRestrictions.MaxLineCountInValueTable);
	
	QueryTemplate = 
	"%1
	|
	|SELECT
	|	""%2"" AS Delimeter,
	|	SUM(CAST(1 AS NUMBER(15,0))) AS DelimeterCount,
	|	MAX(Table.LinesCount) AS LinesCount,
	|	%5 AS IsSourceDelimeter
	|%3
	|FROM
	|	(SELECT
	|		Table.%2 AS Delimeter,
	|		MAX(CASE WHEN T.%2 IS NULL THEN TRUE ELSE FALSE END) AS IsNullValue,
	|		MAX(CASE WHEN CAST(%6 AS NUMBER(23,3)) = %6 THEN FALSE ELSE TRUE END) AS IsNumbersWithMaxPrecision,
	|		SUM(CAST(1 AS NUMBER(15,0))) AS LinesCount
	|	FROM
	|		%4 AS Table
	|	GROUP BY
	|		Table.%2) AS Table
	|HAVING
	|	MAX(Table.IsNullValue) = FALSE
	|	AND MAX(Table.IsNumbersWithMaxPrecision) = FALSE
	|
	|";
	
	ColumnsNames = "";
	ExceptionsStructure = New Structure(NumerationParameters.SumFieldsNames);
	
	For Each CurrentColumn In EmptyTable.Columns Do
		
		If ExceptionsStructure.Property(CurrentColumn.Name) Then
			Continue;
		EndIf;
		
		ColumnValueType = CurrentColumn.ValueType;
		If ColumnValueType.ContainsType(Type("AccumulationRecordType"))
			Or (ColumnValueType.Types().Count() > 1
				And ColumnValueType.ContainsType(Type("String"))) Then
			Continue;
		EndIf;
		
		Query.Text = Query.Text
			+ StringFunctionsClientServer.SubstituteParametersToString(
				QueryTemplate,
				?(Query.Text = "", "", "UNION ALL"),
				CurrentColumn.Name,
				?(Query.Text = "", "INTO TempDelimeters", "UNION ALL"),
				TableName,
				?(Lower(CurrentColumn.Name) = Lower(NumerationParameters.DelimeterName), "TRUE", "FALSE"),
				?(ColumnValueType.ContainsType(Type("Number")), "Table." + CurrentColumn.Name, "0"));
				
	EndDo;
			
	Query.Execute();
	
	Query.Text = 
	"SELECT TOP 1
	|	Table.Delimeter
	|FROM
	|	TempDelimeters AS Table
	|WHERE
	|	Table.LinesCount <=&PortionSize
	|
	|ORDER BY
	|	Table.DelimeterCount,
	|	Table.IsSourceDelimeter DESC,
	|	Table.Delimeter
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	Table.Delimeter AS Delimeter
	|FROM
	|	TempDelimeters AS Table
	|WHERE
	|	Table.LinesCount > &PortionSize
	|
	|ORDER BY
	|	Table.LinesCount,
	|	Table.DelimeterCount,
	|	Table.IsSourceDelimeter DESC,
	|	Table.Delimeter
	|";
	
	Query.Text = StringFunctionsClientServer.SubstituteParametersToString(Query.Text, NumerationParameters.DelimeterName);
	
	Result = Query.ExecuteBatch();
	
	Selection = Result[0].Select();
	
	If Not Selection.Next() Then
		
		Selection = Result[1].Select();
		
		If Not Selection.Next() Then
			
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Can''t find delimeter for table %1'; ru = 'Не найден ограничитель для таблицы %1';pl = 'Nie można znaleźć separatora dla tabeli %1';es_ES = 'No se puede encontrar el delimitador para la tabla %1';es_CO = 'No se puede encontrar el delimitador para la tabla %1';tr = 'Tablo %1 için sınırlayıcı bulunamıyor';it = 'Impossibile trovare il delimitatore per la tabella %1';de = 'Trennzeichen für Tabelle %1 kann nicht gefunden werden'"),
				TableName);
				
			Raise ErrorText;
			
		EndIf;
		
	EndIf;
	
	DeleteTempTables(Query, "TempDelimeters");
	
	Return Selection.Delimeter;
EndFunction

Function GetSeparateParametersTempTableOnPortions(PortionSize, WeightLineFieldName,
	OrderFieldsNames = "", PortionNumberFieldName = "", IndexFieldsNames = "")
	
	SeparateParameters = New Structure;
	SeparateParameters.Insert("PortionSize",            PortionSize);
	SeparateParameters.Insert("WeightLineFieldName",    WeightLineFieldName);
	SeparateParameters.Insert("OrderFieldsNames",       ?(Not ValueIsFilled(OrderFieldsNames), WeightLineFieldName + " " + "DESC", OrderFieldsNames));
	SeparateParameters.Insert("PortionNumberFieldName", ?(Not ValueIsFilled(PortionNumberFieldName), DefaultPortionNumberFieldName(), PortionNumberFieldName));
	SeparateParameters.Insert("IndexFieldsNames",       ?(Not ValueIsFilled(IndexFieldsNames), SeparateParameters.PortionNumberFieldName, IndexFieldsNames));
	
	Return SeparateParameters;
EndFunction

Function DefaultPortionNumberFieldName()
	Return "PortionNumber";
EndFunction

Function SeparateTempTableOnPortions(CalculationParameters, SeparateParameters, TableName)
	
	Query = New Query;
	Query.TempTablesManager = CalculationParameters.TempTablesManager;
	
	Query.Text = 
	"SELECT TOP 0
	|	Table.*
	|FROM
	|	%1 AS Table";
	
	Query.Text = StringFunctionsClientServer.SubstituteParametersToString(Query.Text, TableName);
	
	DataTable = Query.Execute().Unload();
	
	FieldTableText = "";
	FieldTableTemplate = "";
	
	For Each DataColumn In DataTable.Columns Do
		FieldTableText = FieldTableText + ?(FieldTableText = "", "", ",
			|	") + "Table." + DataColumn.Name;
		FieldTableTemplate = FieldTableTemplate + ?(FieldTableTemplate = "", "", ", ") + "%1" + DataColumn.Name;
	EndDo;
	
	ColumnWasAdded = AddColumnForLinesPortionsNumbers(DataTable, SeparateParameters.PortionNumberFieldName);
	
	If ColumnWasAdded Then
		FieldTableTemplate = FieldTableTemplate + ", %1" + SeparateParameters.PortionNumberFieldName;
	EndIf;
	
	PutValueTableIntoTempTable(
		CalculationParameters,
		TableName + "_Temp",
		DataTable,
		FieldTableTemplate);
		
	Query.Text =
	"SELECT
	|	%1
	|FROM
	|	%2 AS Table
	|ORDER BY
	|	%3
	|";
	
	Query.Text = StringFunctionsClientServer.SubstituteParametersToString(
		Query.Text,
		FieldTableText,
		TableName,
		SeparateParameters.OrderFieldsNames);
		
	Selection = Query.Execute().Select();
	
	PortionNumber = 1;
	CurrentPortionSize = 0;
	
	SelectionLineNumber = 0;
	SelectionSize = Selection.Count();
	
	While Selection.Next() Do
		
		SelectionLineNumber = SelectionLineNumber + 1;
		
		CurrentLine = DataTable.Add();
		FillPropertyValues(CurrentLine, Selection);
		
		LineWeight = CurrentLine[SeparateParameters.WeightLineFieldName];
		LineWeight = ?(LineWeight < 0, - LineWeight, LineWeight);
		
		If CurrentPortionSize + LineWeight <= SeparateParameters.PortionSize Then
			// string was added in current portion
		ElsIf CurrentPortionSize > 0 Then
			// string was added as first in current portion
			PortionNumber = PortionNumber + 1;
			CurrentPortionSize = 0;
		Else
			// string was put in different portion
		EndIf;
		
		CurrentLine[SeparateParameters.PortionNumberFieldName] = PortionNumber;
		
		CurrentPortionSize = CurrentPortionSize + LineWeight;
		
		If SelectionLineNumber = SelectionSize
			Or DataTable.Count() = CalculationParameters.SelectionRestrictions.MaxLineCountInValueTable Then
			
			UnionValueTableAndTempTable(
				CalculationParameters,
				TableName + "_Temp",
				DataTable,
				"", // all columns
				FieldTableTemplate,
				"");
				
			DataTable.Clear();
			
		EndIf;
		
	EndDo;
	
	// Delete old table and put the new table with filled column "portion number"
	Query.Text =
	"DROP %1
	|;
	|///////////////////////////////////////////////
	|
	|SELECT
	|	Table.*
	|INTO %1
	|FROM
	|	%1_Temp AS Table
	|
	|INDEX BY
	|	%2
	|
	|;
	|///////////////////////////////////////////////
	|DROP %1_Temp";
	
	Query.Text = StringFunctionsClientServer.SubstituteParametersToString(
		Query.Text,
		TableName,
		SeparateParameters.IndexFieldsNames);
		
	Query.Execute();
	
	Return ?(SelectionSize = 0, 0, PortionNumber);
EndFunction

Procedure UnionValueTableAndTempTable(TempTablesContainer, TempTableName, Table, ValueTableFields, TableFields, TableResourses, IndexFields = "")
	
	InnerTableName = "TempDataStorageForUnion";
	
	If ValueIsFilled(ValueTableFields) Then
		PutValueTableIntoTempTable(TempTablesContainer, InnerTableName, Table, ValueTableFields, IndexFields);
	Else
		PutValueTableIntoTempTable(TempTablesContainer, InnerTableName, Table, GetColumnFieldsAsString(Table), IndexFields);
	EndIf;
	
	AddMissingTempTableColumns(TempTablesContainer, InnerTableName, TempTableName, IndexFields);
	
	UnionTempTables(TempTablesContainer, InnerTableName, TempTableName, TableFields, TableResourses, IndexFields);
	
	DeleteTempTables(TempTablesContainer, InnerTableName);
	
EndProcedure

Procedure UnionTempTables(TempTablesContainer, TableName, RecipientName, TableFields, TableResorses, IndexFields = "")
	
	InnerTableName = "TempDataStorageForTablesUnion";
	
	Query = New Query;
	Query.TempTablesManager = GetTempTablesManagerFromContainer(TempTablesContainer);
	
	Query.Text = 
	"SELECT
	|	%Fields
	|INTO %InnerTableName
	|FROM
	|	%SourceName AS Table
	|
	|UNION ALL
	|
	|SELECT
	|	%Fields
	|FROM
	|	%RecipientName  AS Table
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP %RecipientName
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|
	|SELECT
	|	%GrouppedFields
	|INTO %RecipientName
	|FROM
	|	%InnerTableName AS Table
	|
	|%GroupText
	|
	|%FilterFilledResourses
	|
	|%Indexes
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP %InnerTableName";
	
	TableFieldText = TrimAll(StrReplace(TableFields, "%1", "
		|	Table."));
	
	IndexFieldText = ?(IndexFields = "", "", "INDEX BY " + IndexFields);
	
	GrouppedFieldsText = "";
	FilterFilledResoursesText = "";
	GroupText = "";
	
	FieldsArray = StringFunctionsClientServer.SplitStringIntoSubstringsArray(
		StrReplace(TableFields, "%1", "Table."),
		",",
		True,
		True);
	ResoursesArray = StringFunctionsClientServer.SplitStringIntoSubstringsArray(
		StrReplace(TableResorses, "%1", "Table."),
		",",
		True,
		True);
		
	For Each CurrentField In FieldsArray Do
		
		If ResoursesArray.Find(CurrentField) <> Undefined Then
			
			//Resourses
			GrouppedFieldsText = GrouppedFieldsText
				+ ?(GrouppedFieldsText = "", "", ",
				|	") + "SUM(" + CurrentField + ")";
				
			FilterFilledResoursesText = FilterFilledResoursesText
				+ ?(FilterFilledResoursesText = "", "", ",
				|	OR ") + "SUM(" + CurrentField + ") <> 0";
				
		Else
			
			// Dimension or attribute
			GrouppedFieldsText = GrouppedFieldsText
				+ ?(GrouppedFieldsText = "", "", ",
				|	") + CurrentField;
				
			GroupText = GroupText
				+ ?(GroupText = "", "", ",
				|	") + CurrentField;
				
		EndIf;
			
	EndDo;
	
	GroupText = ?(GroupText = "", "", "GROUP BY
		|	") + GroupText;
	FilterFilledResoursesText = ?(FilterFilledResoursesText = "", "", "HAVING
		|	") + FilterFilledResoursesText;
	
	Query.Text = StrReplace(Query.Text, "%Fields", TableFieldText);
	Query.Text = StrReplace(Query.Text, "%SourceName", TableName);
	Query.Text = StrReplace(Query.Text, "%RecipientName", RecipientName);
	
	Query.Text = StrReplace(Query.Text, "%GrouppedFields", GrouppedFieldsText);
	Query.Text = StrReplace(Query.Text, "%GroupText", GroupText);
	Query.Text = StrReplace(Query.Text, "%FilterFilledResourses", FilterFilledResoursesText);
	Query.Text = StrReplace(Query.Text, "%Indexes", IndexFieldText);
	
	Query.Text = StrReplace(Query.Text, "%InnerTableName", InnerTableName);
	
	Query.Execute();
	
EndProcedure

Procedure AddMissingTempTableColumns(TempTablesContainer, TableName, EtalonName, IndexFields = "")
	
	InnerTableName = "TempDataStorageForAddColumns";
	
	Query = New Query;
	Query.TempTablesManager = GetTempTablesManagerFromContainer(TempTablesContainer);
	
	QueryTemplate = 
	"SELECT TOP 0
	|	Table.*
	|FROM
	|	%1 AS Table";
	
	Query.Text = StringFunctionsClientServer.SubstituteParametersToString(QueryTemplate, TableName);
	TableColumns = Query.Execute().Columns;
	
	Query.Text = StringFunctionsClientServer.SubstituteParametersToString(QueryTemplate, EtalonName);
	EtalonColumns = Query.Execute().Columns;
	
	NewColumns = New Structure;
	
	For Each CurrentColumn In EtalonColumns Do
		
		If TableColumns.Find(CurrentColumn.Name) <> Undefined Then
			Continue;
		EndIf;
		
		ValueTypeColumn = New TypeDescription(CurrentColumn.ValueType, ,"Null");
		
		NewColumns.Insert(CurrentColumn.Name, ValueTypeColumn.AdjustValue(Undefined));
		
	EndDo;
	
	If NewColumns.Count() = 0 Then
		Return;
	EndIf;
	
	TableFieldText = "";
	ParametersCount = 0;
	
	For Each CurrentColumn In TableColumns Do
		TableFieldText = TableFieldText + ?(TableFieldText = "", "", ",
			|	") + "Table." + CurrentColumn.Name + " AS " + CurrentColumn.Name;
	EndDo;
	
	For Each CurrentColumn In NewColumns Do
		
		ParametersCount = ParametersCount + 1;
		ParameterName = "NewFieldValue" + Format(ParametersCount, "NZ=0; NG=");
		
		Query.SetParameter(ParameterName, CurrentColumn.Value);
		
		TableFieldText = TableFieldText + ?(TableFieldText = "", "", ",
			|	") + "&" + ParameterName + " AS " + CurrentColumn.Key;
		
	EndDo;
	
	IndexFieldText = ?(IndexFields = "", "", "INDEX BY " + IndexFields);
	
	QueryTemplate = 
	"SELECT
	|	Table.*
	|INTO %2
	|FROM
	|	%1 AS Table
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP %1
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	%3
	|INTO %1
	|FROM
	|	%2 AS Table
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP %2";
	
	Query.Text = StringFunctionsClientServer.SubstituteParametersToString(
		QueryTemplate,
		TableName,
		InnerTableName,
		TableFieldText,
		IndexFieldText);
		
	Query.Execute();
	
EndProcedure

#EndRegion

#Region WorkWithValueTable

Function IsSummableDataColumn(Column)
	
	ExceptionStructure = New Structure("Priority");
	
	Return Column.ValueType.ContainsType(Type("Number")) And Not ExceptionStructure.Property(Column.Name);
EndFunction

Function AddColumnForLineNumeration(Table, LineNumberName)
	
	If Not ValueIsFilled(LineNumberName) Then
		LineNumberName = GetDefaultLineNumberName();
	EndIf;
	
	Return AddColumnNumberIntoValueTable(Table, LineNumberName);
EndFunction

Function AddColumnNumberIntoValueTable(Table, ColumnName)
	
	ColumnWasAdded = False;
	
	If Table.Columns.Find(ColumnName) = Undefined Then
		Table.Columns.Add(ColumnName, New TypeDescription("Number", New NumberQualifiers(15)));
		ColumnWasAdded = True;
	EndIf;
	
	Return ColumnWasAdded;
EndFunction

Function GetColumnFieldsAsString(ColumnsSource)
	
	If TypeOf(ColumnsSource) = Type("ValueTable")
		Or TypeOf(ColumnsSource) = Type("QueryResult") Then
		Columns = ColumnsSource.Columns;
	Else
		Columns = ColumnsSource;
	EndIf;
	
	ColumnsNames = "";
	
	For Each Column In Columns Do
		ColumnsNames = ColumnsNames + ?(ColumnsNames = "", "", ", ") + "%1" + Column.Name;
	EndDo;
	
	Return ColumnsNames;
EndFunction

Function AddColumnForLinesPortionsNumbers(Table, PortionNumberFieldName = "")
	
	If Not ValueIsFilled(PortionNumberFieldName) Then
		PortionNumberFieldName = DefaultPortionNumberFieldName();
	EndIf;
	
	Return AddColumnNumberIntoValueTable(Table, PortionNumberFieldName);
EndFunction

Procedure PutValueTableIntoTempTable(TempTablesContainer, TempTableName, Table, TableFields, IndexFields = "")
	
	Query = New Query;
	Query.TempTablesManager = GetTempTablesManagerFromContainer(TempTablesContainer);
	
	Query.Text = 
	"SELECT
	|	%Fields
	|INTO %TempTableName
	|FROM
	|	&Table AS Table
	|%Index";
	
	TableFieldsText = TrimAll(StrReplace(TableFields, "%1", "
		|	Table."));
	IndexFieldsText = ?(IndexFields = "", "", "INDEX BY " + IndexFieldsText);
	
	Query.Text = StrReplace(Query.Text, "%Fields", TableFieldsText);
	Query.Text = StrReplace(Query.Text, "%TempTableName", TempTableName);
	Query.Text = StrReplace(Query.Text, "%Index", IndexFieldsText);
	
	Query.SetParameter("Table", Table);
	
	Query.Execute();
	
EndProcedure

// Add the Null type in empty columns
Procedure CorrectEmptyColumnsTypesOfTable(Table)
	
	ColumnsStructure = New Structure;
	
	For Each Column In Table.Columns Do
		If Column.ValueType.Types().Count() = 0 Then
			ColumnsStructure.Insert(Column.Name);
		EndIf;
	EndDo;
	
	If Not ValueIsFilled(ColumnsStructure) Then
		Return;
	EndIf;
	
	For Each KeyAndValue In ColumnsStructure Do
		
		ColumnName = KeyAndValue.Key + "_Typed";
		
		Table.Columns.Add(
			ColumnName,
			Common.AllRefsTypeDetails(),
			Table.Columns[KeyAndValue.Key].Title);
			
		Table.FillValues(Undefined, ColumnName);
			
		Table.Columns.Delete(KeyAndValue.Key);
		Table.Columns[ColumnName].Name = KeyAndValue.Key;
		
	EndDo;
	
EndProcedure

#EndRegion

#Region Others

Function Recorders(BeginOfPeriod, EndOfOfPeriod, ArrayOfCompanies, NameOfRegister, ArrayOfExcludedTypes = Undefined, ArrayOfIncludedTypes = Undefined)
	
	If ArrayOfExcludedTypes = Undefined Then
		ArrayOfExcludedTypes = New Array;
	EndIf;
	
	If ArrayOfIncludedTypes = Undefined Then
		ArrayOfIncludedTypes = New Array;
	EndIf;
	
	QueryTemplate = "
	|SELECT DISTINCT
	|	Table.Recorder AS Recorder
	|FROM
	|	&NameOfRegister AS Table
	|WHERE
	|	Table.Period BETWEEN &BeginOfPeriod AND &EndOfOfPeriod
	|	AND Table.Company IN (&ArrayOfCompanies)
	|	AND NOT VALUETYPE(Table.Recorder) IN (&ArrayOfExcludedTypes)
	|	AND (&SupportedAllTypes OR VALUETYPE(Table.Recorder) IN (&ArrayOfIncludedTypes))
	|";
	
	Query = New Query(StrReplace(QueryTemplate, "&NameOfRegister", "AccumulationRegister." + NameOfRegister));
	Query.SetParameter("BeginOfPeriod", BeginOfPeriod);
	Query.SetParameter("EndOfOfPeriod", EndOfOfPeriod);
	Query.SetParameter("ArrayOfCompanies", ArrayOfCompanies);
	Query.SetParameter("ArrayOfExcludedTypes", ArrayOfExcludedTypes);
	Query.SetParameter("ArrayOfIncludedTypes", ArrayOfIncludedTypes);
	Query.SetParameter("SupportedAllTypes", Not ValueIsFilled(ArrayOfIncludedTypes));
	
	Recorders = New Map;
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		Recorders.Insert(Selection.Recorder, True);
	EndDo;
	
	Return Recorders;
EndFunction

Function CompaniesPresentation(ArrayOfCompanies, Delimeter = Undefined)
	
	SetPrivilegedMode(True);
	
	If ArrayOfCompanies = Undefined Then
		Return NStr("en = '<All companies>'; ru = '<Все организации>';pl = '<Wszystkie firmy>';es_ES = '<Todas empresas>';es_CO = '<All companies>';tr = '<Tüm iş yerleri>';it = '<Tutte le aziende>';de = '<Alle Firmen>'");
	EndIf;
	
	CompaniesPresentation = "";
	
	If Delimeter = Undefined Then
		Delimeter = Chars.CR;
	EndIf;
	
	Query = New Query(
	"SELECT ALLOWED
	|	Company.Description AS CompanyPresentation
	|FROM
	|	Catalog.Companies AS Company
	|WHERE
	|	Company.Ref IN(&ArrayOfCompanies)
	|
	|ORDER BY
	|	CompanyPresentation");
	
	Query.SetParameter("ArrayOfCompanies", DriveClientServer.ArrayFromItem(ArrayOfCompanies));
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		CompaniesPresentation = CompaniesPresentation
			+ ?(IsBlankString(CompaniesPresentation), "", Delimeter)
			+ Selection.CompanyPresentation;
	EndDo;
		
	Return CompaniesPresentation;
	
EndFunction

#EndRegion

#EndRegion