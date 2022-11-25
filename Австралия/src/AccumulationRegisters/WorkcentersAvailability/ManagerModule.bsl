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
	|	WorkcentersAvailability.Period AS Period,
	|	WorkcentersAvailability.Recorder AS Recorder,
	|	WorkcentersAvailability.LineNumber AS LineNumber,
	|	WorkcentersAvailability.Active AS Active,
	|	WorkcentersAvailability.WorkcenterType AS WorkcenterType,
	|	WorkcentersAvailability.Workcenter AS Workcenter,
	|	WorkcentersAvailability.Used AS Used,
	|	WorkcentersAvailability.UsedFromReservedTime AS UsedFromReservedTime,
	|	WorkcentersAvailability.Available AS Available,
	|	WorkcentersAvailability.AvailableOfReservedTime AS AvailableOfReservedTime,
	|	WorkcentersAvailability.ManualCorrection AS ManualCorrection,
	|	WorkcentersAvailability.PointInTime AS PointInTime
	|INTO RegisterWorkcentersAvailabilityChange
	|FROM
	|	AccumulationRegister.WorkcentersAvailability AS WorkcentersAvailability");
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureTemporaryTables.Insert("RegisterWorkcentersAvailabilityChange", False);
	
EndProcedure

#EndRegion

#EndIf