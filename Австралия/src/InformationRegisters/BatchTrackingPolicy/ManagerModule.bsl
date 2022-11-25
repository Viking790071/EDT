#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

Procedure CreateDefaultTrackingPolicy(BatchSettings, StructuralUnit) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	
	Query.SetParameter("BatchSettings", BatchSettings);
	Query.SetParameter("StructuralUnit", StructuralUnit);
	
	Query.Text =
	"SELECT
	|	BatchSettings.Ref AS BatchSettings,
	|	BusinessUnits.Ref AS StructuralUnit,
	|	BatchSettings.DefaultTrackingPolicy AS Policy
	|FROM
	|	Catalog.BatchSettings AS BatchSettings,
	|	Catalog.BusinessUnits AS BusinessUnits
	|WHERE
	|	(BatchSettings.Ref = &BatchSettings
	|			OR &BatchSettings = UNDEFINED)
	|	AND (BusinessUnits.Ref = &StructuralUnit
	|			OR &StructuralUnit = UNDEFINED)
	|	AND BusinessUnits.Ref <> VALUE(Catalog.BusinessUnits.GoodsInTransit)";
	
	QueryResult = Query.Execute();
	
	RecordSet = CreateRecordSet();
	
	If Not BatchSettings = Undefined Then
		RecordSet.Filter.BatchSettings.Set(BatchSettings);
	EndIf;
	If Not StructuralUnit = Undefined Then
		RecordSet.Filter.StructuralUnit.Set(StructuralUnit);
	EndIf;
	
	RecordSet.Load(QueryResult.Unload());
	
	RecordSet.Write();
	
EndProcedure

#EndRegion

#EndIf