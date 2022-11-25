#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

// The infobase update handler.
Procedure MoveDataToNewRegister() Export
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	TRUE AS TrueValue
	|FROM
	|	InformationRegister.ObjectsRightsSettings AS RightsByAccessValues
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DeleteRightsByAccessValues.AccessValue AS Object,
	|	DeleteRightsByAccessValues.User,
	|	DeleteRightsByAccessValues.Right,
	|	MAX(DeleteRightsByAccessValues.Denied) AS RightIsProhibited,
	|	MAX(DeleteRightsByAccessValues.DistributedByHierarchy) AS InheritanceIsAllowed
	|FROM
	|	InformationRegister.DeleteRightsByAccessValues AS DeleteRightsByAccessValues
	|
	|GROUP BY
	|	DeleteRightsByAccessValues.AccessValue,
	|	DeleteRightsByAccessValues.User,
	|	DeleteRightsByAccessValues.Right";
	
	Lock = New DataLock;
	LockItem = Lock.Add("InformationRegister.ObjectsRightsSettings");
	LockItem = Lock.Add("InformationRegister.DeleteRightsByAccessValues");
	
	BeginTransaction();
	Try
		Lock.Lock();
		QueryResults = Query.ExecuteBatch();
		
		If QueryResults[0].IsEmpty()
		   AND NOT QueryResults[1].IsEmpty() Then
			
			RecordSet = InformationRegisters.ObjectsRightsSettings.CreateRecordSet();
			RecordSet.Load(QueryResults[1].Unload());
			RecordSet.Write();
			
			RecordSet = CreateRecordSet();
			RecordSet.Write();
			
			InformationRegisters.ObjectsRightsSettings.UpdateAuxiliaryRegisterData();
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

#EndRegion

#EndIf