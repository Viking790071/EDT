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
	AttributesToSkip.Add("Internal");
	AttributesToSkip.Add("IBUserID");
	AttributesToSkip.Add("ServiceUserID");
	AttributesToSkip.Add("IBUserProperies");
	
	Return AttributesToSkip;
	
EndFunction

// End StandardSubsystems.BatchObjectModification

// StandardSubsystems.AccessManagement

// See AccessManagementOverridable.OnFillListsWithAccessRestriction. 
Procedure OnFillAccessRestriction(Restriction) Export
	
	Restriction.Text =
	"AllowRead
	|WHERE
	|	TRUE
	|;
	|AllowUpdateIfReadingAllowed
	|WHERE
	|	IsAuthorizedUser(Ref)";
	
EndProcedure

// End StandardSubsystems.AccessManagement

#EndRegion

#EndRegion

#EndIf

#Region EventHandlers

Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	If NOT Parameters.Filter.Property("Invalid") Then
		Parameters.Filter.Insert("Invalid", False);
	EndIf;
	
	If NOT Parameters.Filter.Property("Internal") Then
		Parameters.Filter.Insert("Internal", False);
	EndIf;
	
EndProcedure

#EndRegion
