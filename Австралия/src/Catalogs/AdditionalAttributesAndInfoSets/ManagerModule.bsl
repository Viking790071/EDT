#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.BatchObjectsModification

// Returns object attributes allowed to be edited using bench attribute change data processor.
// 
//
// Returns:
//  Array - a list of object attribute names.
Function AttributesToEditInBatchProcessing() Export
	
	AttributesToEdit = New Array;
	
	Return AttributesToEdit;
	
EndFunction

// End StandardSubsystems.BatchObjectModification

#EndRegion

#EndRegion

#Region Internal

// Updates descriptions of predefined sets in parameters of additional attributes and info.
// 
// 
// Parameters:
//  HasChanges - Boolean (return value) - if recorded, True is set, otherwise, it is not changed.
//                  
//
Procedure RefreshPredefinedSetsDescriptionsContent(HasChanges = Undefined) Export
	
	SetPrivilegedMode(True);
	
	PredefinedSets = PredefinedSets();
	
	BeginTransaction();
	Try
		HasCurrentChanges = False;
		PreviousValue = Undefined;
		
		StandardSubsystemsServer.UpdateApplicationParameter(
			"StandardSubsystems.Properties.AdditionalDataAndAttributePredefinedSets",
			PredefinedSets, HasCurrentChanges, PreviousValue);
		
		StandardSubsystemsServer.AddApplicationParameterChanges(
			"StandardSubsystems.Properties.AdditionalDataAndAttributePredefinedSets",
			?(HasCurrentChanges,
			  New FixedStructure("HasChanges", True),
			  New FixedStructure()) );
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	If HasCurrentChanges Then
		HasChanges = True;
	EndIf;
	
EndProcedure



#EndRegion

#Region Private

Function PredefinedSets()
	
	PredefinedSets = New Map;
	
	PredefinedItemNames = Metadata.Catalogs.AdditionalAttributesAndInfoSets.GetPredefinedNames();
	
	For each Name In PredefinedItemNames Do
		PredefinedSets.Insert(
			Name, PropertyManagerInternal.PredefinedSetDescription(Name));
	EndDo;
	
	Return New FixedMap(PredefinedSets);
	
EndFunction

#EndRegion

#EndIf
