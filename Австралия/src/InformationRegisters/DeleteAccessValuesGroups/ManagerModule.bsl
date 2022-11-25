#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

// The infobase update handler.
Procedure MoveDataToNewRegister() Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	TRUE AS TrueValue
	|FROM
	|	InformationRegister.DeleteAccessValuesGroups AS DeleteAccessValuesGroups";
	
	If Query.Execute().IsEmpty() Then
		Return;
	EndIf;
	
	Query.SetParameter("OwnersTypes",
		AccessManagementInternalCached.RightsForObjectsRightsSettingsAvailable().OwnersTypes);
	
	Query.Text =
	"SELECT
	|	DeleteAccessValuesGroups.AccessValue AS Object,
	|	DeleteAccessValuesGroups.AccessValuesGroup AS Parent,
	|	DeleteAccessValuesGroups.InheritParentRights AS Inherit
	|FROM
	|	InformationRegister.DeleteAccessValuesGroups AS DeleteAccessValuesGroups
	|		INNER JOIN Catalog.MetadataObjectIDs AS MetadataObjectIDs
	|		ON (DeleteAccessValuesGroups.AccessValue = DeleteAccessValuesGroups.AccessValuesGroup)
	|			AND (DeleteAccessValuesGroups.InheritParentRights = FALSE)
	|			AND (VALUETYPE(DeleteAccessValuesGroups.AccessValue) = VALUETYPE(MetadataObjectIDs.EmptyRefValue))
	|			AND (MetadataObjectIDs.EmptyRefValue IN (&OwnersTypes))";
	
	BeginTransaction();
	Try
		QueryResult = Query.Execute();
		
		If Not QueryResult.IsEmpty() Then
			RecordSet = InformationRegisters.ObjectRightsSettingsInheritance.CreateRecordSet();
			RecordSet.Load(QueryResult.Unload());
			RecordSet.Write();
		EndIf;
		
		RecordSet = CreateRecordSet();
		RecordSet.Write();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// The infobase update handler.
Procedure ClearRegister() Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	TRUE AS TrueValue
	|FROM
	|	InformationRegister.DeleteAccessValuesGroups AS DeleteAccessValuesGroups";
	
	If Query.Execute().IsEmpty() Then
		Return;
	EndIf;
	
	RecordSet = CreateRecordSet();
	RecordSet.Write();
	
EndProcedure

#EndRegion

#EndIf