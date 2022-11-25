#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Not IsNew() Then
		
		If DeletionMark <> Common.ObjectAttributeValue(Ref, "DeletionMark") Then
			
			SetPrivilegedMode(True);
			
			SetDeletionMarkForAllAssociatedObjects(Ref, DeletionMark);
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure BeforeDelete(Cancel)
	
	// There is no DataExchange.Load property value verification, because the code below implements the 
	// logic that must be executed, including when this property is set to True (on the side of the code 
	// that records to this exchange plan).
	
	SetPrivilegedMode(True);
	Common.DeleteDataFromSecureStorage(Ref);
	SetPrivilegedMode(False);
EndProcedure

#EndRegion

#Region Private

// Sets or clears the deletion mark for all associated objects.
//
// Parameters:
//  Owner - ExchangePlanRef, CatalogRef, DocumentRef - reference to the object that is
//                    an owner of the objects to be marked for deletion.
//
//  DeletionMark - Boolean - flag that shows whether deletion marks of all subordinate objects must be set or cleared.
//
Procedure SetDeletionMarkForAllAssociatedObjects(Val Owner, Val DeletionMark)
	
	BeginTransaction();
	Try
		
		RefsList = New Array;
		RefsList.Add(Owner);
		References = FindByRef(RefsList);
		
		For Each CurrentRef In References Do
			
			If Common.RefTypeValue(CurrentRef[1]) Then
				CurrentRef[1].GetObject().SetDeletionMark(DeletionMark);
			EndIf;
			
		EndDo;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

#EndRegion

#EndIf