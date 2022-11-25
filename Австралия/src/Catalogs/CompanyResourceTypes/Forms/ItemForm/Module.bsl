#Region FormEventHandlers

// Procedure - event handler OnCreateAtServer of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetPlanningIncompleteMark();
	
	PlanningOnWorkcentersLevel = Object.PlanningOnWorkcentersLevel;
	
	// StandardSubsystems.ObjectAttributesLock
	ObjectAttributesLock.LockAttributes(ThisObject);
	// End StandardSubsystems.ObjectAttributesLock
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject, Object);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SetVisiblePlanning();
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	// StandardSubsystems.ObjectAttributesLock
		ObjectAttributesLock.LockAttributes(ThisObject);
	// End StandardSubsystems.ObjectAttributesLock
	
	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("WorkcentersWereChanged", Object.Ref);
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	NativeLanguagesSupportServer.BeforeWriteAtServer(CurrentObject);
	IsNew = CurrentObject.IsNew();
	
	If PlanningOnWorkcentersLevel <> CurrentObject.PlanningOnWorkcentersLevel And Not CurrentObject.IsNew() Then
		
		CurrentObject.AdditionalProperties.Insert("MarkWorkcentersAvailabilityForDeletion");
		PlanningOnWorkcentersLevel = CurrentObject.PlanningOnWorkcentersLevel;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure PlanningOnWorkcentersLevelOnChange(Item)
	
	SetVisiblePlanning();
	SetPlanningIncompleteMark();
	
EndProcedure

&AtClient
Procedure Attachable_Open(Item, StandardProcessing)
	NativeLanguagesSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

#Region LibrariesHandlers

// StandardSubsystems.ObjectAttributesLock

&AtClient
Procedure Attachable_AllowObjectAttributesEditing(Command)
	ObjectAttributesLockClient.AllowObjectAttributeEdit(ThisObject);
EndProcedure

// End StandardSubsystems.ObjectAttributesLock

#EndRegion

#EndRegion

#Region Private

&AtClient
Procedure SetVisiblePlanning()
	
	IsVisiblePlanning = Not Object.PlanningOnWorkcentersLevel;
	
	Items.GroupPlanningAttributes.Visible = IsVisiblePlanning;
	Items.EachOperationForSingleWC.Visible = Not IsVisiblePlanning;
	
EndProcedure

&AtServer
Procedure SetPlanningIncompleteMark()
	
	Items.Capacity.AutoMarkIncomplete = False;
	Items.Schedule.AutoMarkIncomplete = False;
	
	If Not Object.PlanningOnWorkcentersLevel Then
		
		UsePlanning = Constants.UseProductionPlanning.Get();
		
		If UsePlanning Then
			Items.Capacity.AutoMarkIncomplete = True;
			Items.Schedule.AutoMarkIncomplete = True;
		EndIf;
		
	EndIf;

EndProcedure

#EndRegion
