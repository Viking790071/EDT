#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

// The procedure updates register cache attributes based on the result of changing the content of 
// value types and access value groups.
//
Procedure UpdateAuxiliaryRegisterDataByConfigurationChanges() Export
	
	SetPrivilegedMode(True);
	
	LastChanges = StandardSubsystemsServer.ApplicationParameterChanges(
		"StandardSubsystems.AccessManagement.GroupAndAccessValueTypes");
	
	If (LastChanges = Undefined
	      OR LastChanges.Count() > 0)
	   AND Constants.LimitAccessAtRecordLevel.Get() Then
		
		AccessManagementInternal.SetDataFillingForAccessRestriction(True);
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

// The procedure updates the register data during the full update of auxiliary data.
// 
// Parameters:
//  HasChanges - Boolean (return value) - if recorded, True is set, otherwise, it is not changed.
//                  
//
Procedure UpdateRegisterData(HasChanges = Undefined) Export
	
	StandardSubsystemsServer.CheckApplicationVersionDynamicUpdate();
	
	DataVolume = 0;
	While DataVolume > 0 Do
		DataVolume = 0;
		AccessManagementInternal.DataFillingForAccessRestriction(DataVolume, True, HasChanges);
	EndDo;
	
	ObjectsTypes = AccessManagementInternalCached.ObjectsTypesInSubscriptionsToEvents(
		"WriteAccessValuesSets");
	
	For each TypeDetails In ObjectsTypes Do
		Type = TypeDetails.Key;
		
		If Type = Type("String") Then
			Continue;
		EndIf;
		
		Selection = Common.ObjectManagerByFullName(Metadata.FindByType(Type).FullName()).Select();
		
		While Selection.Next() Do
			AccessManagementInternal.UpdateAccessValuesSets(Selection.Ref, HasChanges);
		EndDo;
	EndDo;
	
EndProcedure

#EndRegion

#EndIf
