#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRef, StructureAdditionalProperties) Export
	
	Query = New Query();
	Query.Text =
	"SELECT ALLOWED
	|	ManufacturingOverheadsRates.Date AS Date,
	|	ManufacturingOverheadsRates.Company AS Company,
	|	ManufacturingOverheadsRates.Ref AS Ref,
	|	ManufacturingOverheadsRates.ManufacturingOverheadsAllocationMethod AS AllocationMethod
	|INTO TemporaryDocumentTable
	|FROM
	|	Document.ManufacturingOverheadsRates AS ManufacturingOverheadsRates
	|WHERE
	|	ManufacturingOverheadsRates.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	TemporaryDocumentTable.Ref AS Recorder,
	|	TemporaryDocumentTable.Date AS Period,
	|	TemporaryDocumentTable.Company AS Company,
	|	CASE
	|		WHEN TemporaryDocumentTable.AllocationMethod = VALUE(Enum.ManufacturingOverheadsAllocationMethods.PlantwideAllocation)
	|			THEN TemporaryDocumentTable.Company
	|		WHEN TemporaryDocumentTable.AllocationMethod = VALUE(Enum.ManufacturingOverheadsAllocationMethods.DepartmentalAllocation)
	|			THEN ManufacturingOverheadsRatesRates.BusinessUnit
	|		ELSE ManufacturingActivities.CostPool
	|	END AS Owner,
	|	ManufacturingOverheadsRatesRates.CostDriver AS CostDriver,
	|	CASE
	|		WHEN TemporaryDocumentTable.AllocationMethod = VALUE(Enum.ManufacturingOverheadsAllocationMethods.PlantwideAllocation)
	|			THEN VALUE(Catalog.BusinessUnits.EmptyRef)
	|		ELSE ManufacturingOverheadsRatesRates.BusinessUnit
	|	END AS BusinessUnit,
	|	ManufacturingOverheadsRatesRates.ExpenseItem AS ExpenseItem,
	|	ManufacturingOverheadsRatesRates.Rate AS Rate,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN ManufacturingOverheadsRatesRates.GLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS OverheadsGLAccount
	|FROM
	|	Document.ManufacturingOverheadsRates.Rates AS ManufacturingOverheadsRatesRates
	|		INNER JOIN TemporaryDocumentTable AS TemporaryDocumentTable
	|		ON ManufacturingOverheadsRatesRates.Ref = TemporaryDocumentTable.Ref
	|		LEFT JOIN Catalog.ManufacturingActivities AS ManufacturingActivities
	|		ON ManufacturingOverheadsRatesRates.Activity = ManufacturingActivities.Ref";
	
	Query.SetParameter("Ref", DocumentRef);
	Query.SetParameter("UseDefaultTypeOfAccounting", GetFunctionalOption("UseDefaultTypeOfAccounting"));
	
	Result = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePredeterminedOverheadRates", Result.Unload());
	
EndProcedure

#Region LibrariesHandlers

// StandardSubsystems.ObjectVersioning

Procedure OnDefineObjectVersioningSettings(Settings) Export

EndProcedure

// End StandardSubsystems.ObjectVersioning

#EndRegion

#EndRegion

#Region IncomeAndExpenseItemsInDocuments

Function GetIncomeAndExpenseItemsStructure(StructureData) Export
	
	Return New Structure();
	
EndFunction

Function GetIncomeAndExpenseItemsGLAMap(StructureData) Export

	Result = New Structure;
	If StructureData.TabName = "Rates" Then
		Result.Insert("GLAccount", "ExpenseItem");
	EndIf;

	Return Result;
	
EndFunction

#EndRegion

#EndIf
