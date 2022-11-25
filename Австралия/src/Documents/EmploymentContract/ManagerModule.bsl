#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefCreateEmploymentContract, StructureAdditionalProperties) Export

	Query = New Query(
	"SELECT
	|	&Company AS Company,
	|	EmploymentContractEmployees.LineNumber AS LineNumber,
	|	EmploymentContractEmployees.Employee AS Employee,
	|	EmploymentContractEmployees.StructuralUnit AS StructuralUnit,
	|	EmploymentContractEmployees.Position AS Position,
	|	EmploymentContractEmployees.WorkSchedule AS WorkSchedule,
	|	EmploymentContractEmployees.OccupiedRates AS OccupiedRates,
	|	EmploymentContractEmployees.Period AS Period
	|INTO TableEmployees
	|FROM
	|	Document.EmploymentContract.Employees AS EmploymentContractEmployees
	|WHERE
	|	EmploymentContractEmployees.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	&Company AS Company,
	|	EmploymentContractEmployees.LineNumber AS LineNumber,
	|	EmploymentContractEmployees.Employee AS Employee,
	|	EmploymentContractEmployees.Period AS Period,
	|	EmploymentContractPayrollRetention.EarningAndDeductionType AS EarningAndDeductionType,
	|	EmploymentContractPayrollRetention.Currency AS Currency,
	|	EmploymentContractPayrollRetention.Amount AS Amount,
	|	CASE
	|		WHEN EmploymentContractPayrollRetention.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Earning)
	|			THEN EmploymentContractPayrollRetention.ExpenseItem
	|		WHEN EmploymentContractPayrollRetention.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Deduction)
	|			THEN EmploymentContractPayrollRetention.IncomeItem
	|		ELSE VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
	|	END AS IncomeAndExpenseItem,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN EmploymentContractPayrollRetention.GLExpenseAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLExpenseAccount
	|INTO TableEarningsDeductions
	|FROM
	|	Document.EmploymentContract.Employees AS EmploymentContractEmployees
	|		INNER JOIN Document.EmploymentContract.EarningsDeductions AS EmploymentContractPayrollRetention
	|		ON EmploymentContractEmployees.ConnectionKey = EmploymentContractPayrollRetention.ConnectionKey
	|			AND EmploymentContractEmployees.Ref = EmploymentContractPayrollRetention.Ref
	|WHERE
	|	EmploymentContractEmployees.Ref = &Ref
	|
	|UNION ALL
	|
	|SELECT
	|	&Company,
	|	EmploymentContractEmployees.LineNumber,
	|	EmploymentContractEmployees.Employee,
	|	EmploymentContractEmployees.Period,
	|	EmploymentContractIncomeTaxes.EarningAndDeductionType,
	|	EmploymentContractIncomeTaxes.Currency,
	|	0,
	|	UNDEFINED,
	|	UNDEFINED
	|FROM
	|	Document.EmploymentContract.Employees AS EmploymentContractEmployees
	|		INNER JOIN Document.EmploymentContract.IncomeTaxes AS EmploymentContractIncomeTaxes
	|		ON EmploymentContractEmployees.ConnectionKey = EmploymentContractIncomeTaxes.ConnectionKey
	|			AND EmploymentContractEmployees.Ref = EmploymentContractIncomeTaxes.Ref
	|WHERE
	|	EmploymentContractEmployees.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableEmployees.Company AS Company,
	|	TableEmployees.LineNumber AS LineNumber,
	|	TableEmployees.Employee AS Employee,
	|	TableEmployees.StructuralUnit AS StructuralUnit,
	|	TableEmployees.Position AS Position,
	|	TableEmployees.WorkSchedule AS WorkSchedule,
	|	TableEmployees.OccupiedRates AS OccupiedRates,
	|	TableEmployees.Period AS Period
	|FROM
	|	TableEmployees AS TableEmployees
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableEarningsDeductions.Company AS Company,
	|	TableEarningsDeductions.LineNumber AS LineNumber,
	|	TableEarningsDeductions.Employee AS Employee,
	|	TableEarningsDeductions.Period AS Period,
	|	TableEarningsDeductions.EarningAndDeductionType AS EarningAndDeductionType,
	|	TableEarningsDeductions.Currency AS Currency,
	|	TableEarningsDeductions.Amount AS Amount,
	|	TableEarningsDeductions.GLExpenseAccount AS GLExpenseAccount,
	|	TRUE AS Actuality,
	|	TableEarningsDeductions.IncomeAndExpenseItem AS IncomeAndExpenseItem
	|FROM
	|	TableEarningsDeductions AS TableEarningsDeductions");
	
	Query.SetParameter("Ref", DocumentRefCreateEmploymentContract);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("UseDefaultTypeOfAccounting", GetFunctionalOption("UseDefaultTypeOfAccounting"));
	
	TempTablesManager = New TempTablesManager;
	Query.TempTablesManager = TempTablesManager;
	
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableEmployees",			ResultsArray[2].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableCompensationPlan",	ResultsArray[3].Unload());
	
	StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager = Query.TempTablesManager;
	
EndProcedure

#Region IncomeAndExpenseItemsInDocuments

Function GetIncomeAndExpenseItemsStructure(StructureData) Export 
	
	IncomeAndExpenseStructure = New Structure;
	
	If StructureData.TabName = "EarningsDeductions" Then
		TypeOfEarningAndDeductionType = Common.ObjectAttributeValue(StructureData.EarningAndDeductionType, "Type");
	Else
		TypeOfEarningAndDeductionType = Undefined;
	EndIf;
	
	If StructureData.TabName = "EarningsDeductions"
			And TypeOfEarningAndDeductionType = Enums.EarningAndDeductionTypes.Earning Then
		IncomeAndExpenseStructure.Insert("ExpenseItem", StructureData.ExpenseItem);
	ElsIf StructureData.TabName = "EarningsDeductions"
			And TypeOfEarningAndDeductionType = Enums.EarningAndDeductionTypes.Deduction Then
		IncomeAndExpenseStructure.Insert("IncomeItem", StructureData.IncomeItem);
	EndIf;
	
	Return IncomeAndExpenseStructure;
	
EndFunction

Function GetIncomeAndExpenseItemsGLAMap(StructureData) Export

	Result = New Structure;
	
	If StructureData.TabName = "EarningsDeductions" Then
		TypeOfEarningAndDeductionType = Common.ObjectAttributeValue(StructureData.EarningAndDeductionType, "Type");
	Else
		TypeOfEarningAndDeductionType = Undefined;
	EndIf;
	
	If StructureData.TabName = "EarningsDeductions"
			And TypeOfEarningAndDeductionType = Enums.EarningAndDeductionTypes.Earning Then
		Result.Insert("GLExpenseAccount", "ExpenseItem");
	ElsIf StructureData.TabName = "EarningsDeductions"
			And TypeOfEarningAndDeductionType = Enums.EarningAndDeductionTypes.Deduction Then
		Result.Insert("GLExpenseAccount", "IncomeItem");
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion

#Region GLAccounts

Function GetGLAccountsStructure(StructureData) Export

	GLAccountsForFilling = New Structure;
	Return GLAccountsForFilling;
	
EndFunction

#EndRegion

#Region LibrariesHandlers

#Region PrintInterface

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	
	
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