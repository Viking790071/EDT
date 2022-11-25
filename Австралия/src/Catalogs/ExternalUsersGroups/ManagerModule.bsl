#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.BatchObjectsModification

// Returns the object attributes that are not recommended to be edited using batch attribute 
// modification data processor.
//
// Returns:
//  Array - a list of object attribute names.
Function AttributesToSkipInBatchProcessing() Export
	
	AttributesToSkip = New Array;
	AttributesToSkip.Add("AuthorizationObjectsType");
	AttributesToSkip.Add("AllAuthorizationObjects");
	AttributesToSkip.Add("Roles.DeleteRole");
	
	Return AttributesToSkip;
	
EndFunction

// End StandardSubsystems.BatchObjectModification

// StandardSubsystems.AccessManagement

// See AccessManagementOverridable.OnFillListsWithAccessRestriction. 
Procedure OnFillAccessRestriction(Restriction) Export
	
	Restriction.TextForExternalUsers =
	"AllowReadUpdate
	|WHERE
	|	Ref = Value(Catalog.ExternalUsersGroups.AllExternalUsers)";
	
EndProcedure

// End StandardSubsystems.AccessManagement

#EndRegion

#EndRegion

#EndIf
