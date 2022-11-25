#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefHrMove, StructureAdditionalProperties) Export

	Query = New Query(
	"SELECT
	|	&Company AS Company,
	|	StaffDisplacementEmployees.LineNumber,
	|	StaffDisplacementEmployees.Employee,
	|	StaffDisplacementEmployees.StructuralUnit,
	|	StaffDisplacementEmployees.Position,
	|	StaffDisplacementEmployees.WorkSchedule,
	|	StaffDisplacementEmployees.OccupiedRates,
	|	StaffDisplacementEmployees.Period,
	|	StaffDisplacementEmployees.Ref
	|INTO TableEmployees
	|FROM
	|	Document.TransferAndPromotion.Employees AS StaffDisplacementEmployees
	|WHERE
	|	StaffDisplacementEmployees.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	&Company AS Company,
	|	StaffDisplacementEmployees.LineNumber,
	|	StaffDisplacementEmployees.Employee,
	|	StaffDisplacementEmployees.Period,
	|	StaffDisplacementEarningsDeductions.EarningAndDeductionType AS EarningAndDeductionType,
	|	StaffDisplacementEarningsDeductions.Currency,
	|	StaffDisplacementEarningsDeductions.Amount AS Amount,
	|	CASE
	|		WHEN StaffDisplacementEarningsDeductions.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Earning)
	|			THEN StaffDisplacementEarningsDeductions.ExpenseItem
	|		WHEN StaffDisplacementEarningsDeductions.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Deduction)
	|			THEN StaffDisplacementEarningsDeductions.IncomeItem
	|		ELSE VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
	|	END AS IncomeAndExpenseItem,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN StaffDisplacementEarningsDeductions.GLExpenseAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLExpenseAccount,
	|	StaffDisplacementEarningsDeductions.Actuality
	|INTO TableEarningsDeductions
	|FROM
	|	Document.TransferAndPromotion.Employees AS StaffDisplacementEmployees
	|		INNER JOIN Document.TransferAndPromotion.EarningsDeductions AS StaffDisplacementEarningsDeductions
	|		ON StaffDisplacementEmployees.ConnectionKey = StaffDisplacementEarningsDeductions.ConnectionKey
	|WHERE
	|	StaffDisplacementEmployees.Ref = &Ref
	|	AND StaffDisplacementEarningsDeductions.Ref = &Ref
	|
	|UNION ALL
	|
	|SELECT
	|	&Company,
	|	StaffDisplacementEmployees.LineNumber,
	|	StaffDisplacementEmployees.Employee,
	|	StaffDisplacementEmployees.Period,
	|	StaffDisplacementIncomeTaxes.EarningAndDeductionType,
	|	StaffDisplacementIncomeTaxes.Currency,
	|	0,
	|	UNDEFINED,
	|	UNDEFINED,
	|	StaffDisplacementIncomeTaxes.Actuality
	|FROM
	|	Document.TransferAndPromotion.Employees AS StaffDisplacementEmployees
	|		INNER JOIN Document.TransferAndPromotion.IncomeTaxes AS StaffDisplacementIncomeTaxes
	|		ON StaffDisplacementEmployees.ConnectionKey = StaffDisplacementIncomeTaxes.ConnectionKey
	|WHERE
	|	StaffDisplacementEmployees.Ref = &Ref
	|	AND StaffDisplacementIncomeTaxes.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableEmployees.Company,
	|	TableEmployees.LineNumber,
	|	TableEmployees.Employee,
	|	TableEmployees.StructuralUnit,
	|	TableEmployees.Position,
	|	TableEmployees.WorkSchedule,
	|	TableEmployees.OccupiedRates,
	|	TableEmployees.Period
	|FROM
	|	TableEmployees AS TableEmployees
	|WHERE
	|	TableEmployees.Ref.OperationKind = VALUE(Enum.OperationTypesTransferAndPromotion.TransferAndPaymentFormChange)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableEarningsDeductions.Company,
	|	TableEarningsDeductions.LineNumber,
	|	TableEarningsDeductions.Employee,
	|	TableEarningsDeductions.Period,
	|	TableEarningsDeductions.EarningAndDeductionType,
	|	TableEarningsDeductions.Currency,
	|	TableEarningsDeductions.Amount,
	|	TableEarningsDeductions.IncomeAndExpenseItem,
	|	TableEarningsDeductions.GLExpenseAccount,
	|	TableEarningsDeductions.Actuality
	|FROM
	|	TableEarningsDeductions AS TableEarningsDeductions");

	Query.SetParameter("Ref", DocumentRefHrMove);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("UseDefaultTypeOfAccounting", GetFunctionalOption("UseDefaultTypeOfAccounting"));
	
	TempTablesManager = New TempTablesManager;
	Query.TempTablesManager = TempTablesManager;
	
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableEmployees", 				ResultsArray[2].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableCompensationPlan", ResultsArray[3].Unload());
	
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