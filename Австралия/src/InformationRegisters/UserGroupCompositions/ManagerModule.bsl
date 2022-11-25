#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.AccessManagement

// See AccessManagementOverridable.OnFillListsWithAccessRestriction. 
Procedure OnFillAccessRestriction(Restriction) Export
	
	Restriction.Text =
	"AllowReadUpdate
	|WHERE
	|	IsAuthorizedUser(User)";
	
	Restriction.TextForExternalUsers = Restriction.Text;
	
EndProcedure

// End StandardSubsystems.AccessManagement

#EndRegion

#EndRegion

#Region Private

// This procedure updates all register data.
// 
// Parameters:
//  HasChanges - Boolean (return value) - if recorded, True is set, otherwise, it is not changed.
//                  
//
Procedure UpdateRegisterData(HasChanges = Undefined) Export
	
	SetPrivilegedMode(True);
	
	Lock = New DataLock;
	LockItem = Lock.Add("InformationRegister.UserGroupCompositions");
	
	BeginTransaction();
	Try
		Lock.Lock();
		
		// Updating user mapping
		ItemsToChange = New Map;
		ModifiedGroups   = New Map;
		
		Selection = Catalogs.UserGroups.Select();
		While Selection.Next() Do
			UsersInternal.UpdateUserGroupComposition(
				Selection.Ref, , ItemsToChange, ModifiedGroups);
		EndDo;
		
		// Updating external user mapping
		Selection = Catalogs.ExternalUsersGroups.Select();
		While Selection.Next() Do
			UsersInternal.UpdateExternalUserGroupCompositions(
				Selection.Ref, , ItemsToChange, ModifiedGroups);
		EndDo;
		
		If ItemsToChange.Count() > 0
		 OR ModifiedGroups.Count() > 0 Then
		
			HasChanges = True;
			
			UsersInternal.AfterUserGroupsUpdate(
				ItemsToChange, ModifiedGroups);
		EndIf;
		
		UsersInternal.UpdateExternalUsersRoles();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

#EndRegion

#EndIf