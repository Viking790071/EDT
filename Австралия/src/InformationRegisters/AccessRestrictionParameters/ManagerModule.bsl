#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Private

// The procedure updates the register data during the full update of auxiliary data.
// 
// Parameters:
//  HasChanges - Boolean (return value) - if recorded, True is set, otherwise, it is not changed.
//                  
//
Procedure UpdateRegisterData(HasChanges = Undefined) Export
	
	If Not AccessManagementInternal.LimitAccessAtRecordLevelUniversally() Then
		Return;
	EndIf;
	
	AccessManagementInternal.ActiveAccessRestrictionParameters(Undefined,
		Undefined, False, True, HasChanges);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Updating an infobase.

Procedure RegisterDataToProcessForMigrationToNewVersion1(Parameters) Export
	
	// Data registration is not required.
	
EndProcedure

Procedure ProcessDataForMigrationToNewVersion1(Parameters) Export
	
	DataRestrictionsDetails = AccessManagementInternal.DataRestrictionsDetails();
	
	Lists = New Array;
	ListsForExternalUsers = New Array;
	For Each KeyAndValue In DataRestrictionsDetails Do
		If HasRightToListCheck(KeyAndValue.Value.Text) Then
			Lists.Add(KeyAndValue.Key);
		EndIf;
		If HasRightToListCheck(KeyAndValue.Value.TextForExternalUsers) Then
			ListsForExternalUsers.Add(KeyAndValue.Key);
		EndIf;
	EndDo;
	
	PlanningParameters = AccessManagementInternal.AccessUpdatePlanningParameters();
	PlanningParameters.DataAccessKeys = False;
	
	PlanningParameters.ForExternalUsers = False;
	AccessManagementInternal.ScheduleAccessUpdate(Lists, PlanningParameters);
	
	PlanningParameters.ForUsers = False;
	PlanningParameters.ForExternalUsers = True;
	AccessManagementInternal.ScheduleAccessUpdate(ListsForExternalUsers, PlanningParameters);
	
	Parameters.ProcessingCompleted = True;
	
EndProcedure

// For the ProcessDataForMigrationToNewVersion1 procedure.
Function HasRightToListCheck(RestrictionText)
	
	Return StrFind(Upper(RestrictionText), Upper("ListReadingAllowed")) > 0
		Or StrFind(Upper(RestrictionText), Upper("ListUpdateAllowed")) > 0;
	
EndFunction

#EndRegion

#EndIf
