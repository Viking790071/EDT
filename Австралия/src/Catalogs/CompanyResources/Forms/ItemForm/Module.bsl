
#Region FormEventHandlers

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetPlanningIncompleteMark();
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.ObjectAttributesLock
	ObjectAttributesLock.LockAttributes(ThisObject);
	// End StandardSubsystems.ObjectAttributesLock
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject, Object);
	
EndProcedure

// Procedure - event handler OnOpen.
//
&AtClient
Procedure OnOpen(Cancel)
	
	SetVisiblePlanning();
	
EndProcedure

// Procedure - event handler AfterWriting.
//
&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("Record_CompanyResources");
	Notify("WorkcentersWereChanged", Object.WorkcenterType);
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)

	NativeLanguagesSupportServer.BeforeWriteAtServer(CurrentObject);
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)

	// StandardSubsystems.ObjectAttributesLock
		ObjectAttributesLock.LockAttributes(ThisObject);
	// End StandardSubsystems.ObjectAttributesLock
	
	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure WorkcenterTypeOnChange(Item)
	
	SetVisiblePlanning();
	SetPlanningIncompleteMark();
	
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

&AtClient
Procedure Attachable_Open(Item, StandardProcessing)
	NativeLanguagesSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure SetVisiblePlanning()
	
	If Not ValueIsFilled(Object.WorkcenterType) Then
		
		IsVisiblePlanning = True;
		
	Else
		
		IsVisiblePlanning = GetVisiblePlanning(Object.WorkcenterType);
		
	EndIf;
	
	Items.ScheduleBusinessCalendar.Visible		= IsVisiblePlanning;
	Items.Capacity.Visible						= IsVisiblePlanning;
	Items.DecorationPlanningOnTypeLevel.Visible	= Not IsVisiblePlanning;
	
EndProcedure

&AtServerNoContext
Function GetVisiblePlanning(RefWorkcenterType)
	
	Return Common.ObjectAttributeValue(RefWorkcenterType, "PlanningOnWorkcentersLevel");
	
EndFunction

&AtServer
Procedure SetPlanningIncompleteMark()
	
	Items.Capacity.AutoMarkIncomplete = False;
	Items.ScheduleBusinessCalendar.AutoMarkIncomplete = False;
	
	PlanningOnWorkcentersLevel = Common.ObjectAttributeValue(Object.WorkcenterType, "PlanningOnWorkcentersLevel");
	
	If PlanningOnWorkcentersLevel = True Then
		
		UsePlanning = Constants.UseProductionPlanning.Get();
		
		If UsePlanning Then
			Items.Capacity.AutoMarkIncomplete = True;
			Items.ScheduleBusinessCalendar.AutoMarkIncomplete = True;
		EndIf;
		
	EndIf;

EndProcedure

#EndRegion
