#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

// Procedure creates an empty temporary table of records change.
//
Procedure CreateEmptyTemporaryTableChange(AdditionalProperties) Export
	
	If Not AdditionalProperties.Property("ForPosting")
	 Or Not AdditionalProperties.ForPosting.Property("StructureTemporaryTables") Then	
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	Query = New Query(
	"SELECT TOP 0
	|	SubcontractorPlanning.LineNumber AS LineNumber,
	|	SubcontractorPlanning.Company AS Company,
	|	SubcontractorPlanning.WorkInProgress AS WorkInProgress,
	|	SubcontractorPlanning.Products AS Products,
	|	SubcontractorPlanning.Characteristic AS Characteristic,
	|	SubcontractorPlanning.Quantity AS QuantityBeforeWrite,
	|	SubcontractorPlanning.Quantity AS QuantityChange,
	|	SubcontractorPlanning.Quantity AS QuantityOnWrite
	|INTO RegisterRecordsSubcontractorPlanningChange
	|FROM
	|	AccumulationRegister.SubcontractorPlanning AS SubcontractorPlanning");
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureTemporaryTables.Insert("RegisterRecordsSubcontractorPlanningChange", False);
	
EndProcedure

Function BalancesControlQueryText() Export

	Return "SELECT
		|	RegisterRecordsSubcontractorPlanningChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsSubcontractorPlanningChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsSubcontractorPlanningChange.WorkInProgress) AS WorkInProgressPresentation,
		|	REFPRESENTATION(RegisterRecordsSubcontractorPlanningChange.Products) AS ProductsPresentation,
		|	REFPRESENTATION(RegisterRecordsSubcontractorPlanningChange.Characteristic) AS CharacteristicPresentation,
		|	REFPRESENTATION(SubcontractorPlanningBalances.Products.MeasurementUnit) AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsSubcontractorPlanningChange.QuantityChange, 0) + ISNULL(SubcontractorPlanningBalances.QuantityBalance, 0) AS BalanceWorkInProgreses,
		|	ISNULL(SubcontractorPlanningBalances.QuantityBalance, 0) AS QuantityBalanceWorkInProgreses
		|FROM
		|	RegisterRecordsSubcontractorPlanningChange AS RegisterRecordsSubcontractorPlanningChange
		|		LEFT JOIN AccumulationRegister.SubcontractorPlanning.Balance(
		|				&ControlTime,
		|				(Company, WorkInProgress, Products, Characteristic) IN
		|					(SELECT
		|						RegisterRecordsSubcontractorPlanningChange.Company AS Company,
		|						RegisterRecordsSubcontractorPlanningChange.WorkInProgress AS WorkInProgress,
		|						RegisterRecordsSubcontractorPlanningChange.Products AS Products,
		|						RegisterRecordsSubcontractorPlanningChange.Characteristic AS Characteristic
		|					FROM
		|						RegisterRecordsSubcontractorPlanningChange AS RegisterRecordsSubcontractorPlanningChange)) AS SubcontractorPlanningBalances
		|		ON RegisterRecordsSubcontractorPlanningChange.Company = SubcontractorPlanningBalances.Company
		|			AND RegisterRecordsSubcontractorPlanningChange.WorkInProgress = SubcontractorPlanningBalances.WorkInProgress
		|			AND RegisterRecordsSubcontractorPlanningChange.Products = SubcontractorPlanningBalances.Products
		|			AND RegisterRecordsSubcontractorPlanningChange.Characteristic = SubcontractorPlanningBalances.Characteristic
		|WHERE
		|	ISNULL(SubcontractorPlanningBalances.QuantityBalance, 0) < 0
		|
		|ORDER BY
		|	LineNumber";

EndFunction

#EndRegion

#EndIf