///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetItemsState();
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject)
	If NOT ValueIsFilled(CurrentObject.MainAddressingObject) Then
		CurrentObject.MainAddressingObject = Undefined;
	EndIf;
	If NOT ValueIsFilled(CurrentObject.AdditionalAddressingObject) Then
		CurrentObject.AdditionalAddressingObject = Undefined;
	EndIf;
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	Notify("Write_RoleAddressing", WriteParameters, Record.PerformerRole);
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)

	// StandardSubsystems.AccessManagement
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.OnReadAtServer(ThisObject, CurrentObject);
	EndIf;
	// End StandardSubsystems.AccessManagement

EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)

	// StandardSubsystems.AccessManagement
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.AfterWriteAtServer(ThisObject, CurrentObject, WriteParameters);
	EndIf;
	// End StandardSubsystems.AccessManagement

EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure PerformerRoleOnChange(Item)
	
	Record.MainAddressingObject = Undefined;
	Record.AdditionalAddressingObject = Undefined;
	SetItemsState();
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetItemsState()

	MainAddressingObjectTypes = Record.PerformerRole.MainAddressingObjectTypes.ValueType;
	AdditionalAddressingObjectTypes = Record.PerformerRole.AdditionalAddressingObjectTypes.ValueType;
	UsedByAddressingObjects = Record.PerformerRole.UsedByAddressingObjects;
	UsedWithoutAddressingObjects = Record.PerformerRole.UsedWithoutAddressingObjects;
	
	RoleIsSet = NOT Record.PerformerRole.IsEmpty();
	MainAddressingObjectTitle = ?(RoleIsSet, String(Record.PerformerRole.MainAddressingObjectTypes), "");
	AdditionalAddressingObjectTitle = ?(RoleIsSet, String(Record.PerformerRole.AdditionalAddressingObjectTypes), "");
	
	MainAddressingObjectTypesAreSet = RoleIsSet AND UsedByAddressingObjects
		AND ValueIsFilled(MainAddressingObjectTypes);
	TypesOfAditionalAddressingObjectAreSet = RoleIsSet AND UsedByAddressingObjects 
		AND ValueIsFilled(AdditionalAddressingObjectTypes);
	Items.MainAddressingObject.Enabled = MainAddressingObjectTypesAreSet;
	Items.AdditionalAddressingObject.Enabled = TypesOfAditionalAddressingObjectAreSet;
	
	Items.MainAddressingObject.AutoMarkIncomplete = MainAddressingObjectTypesAreSet
		AND NOT UsedWithoutAddressingObjects;
	If MainAddressingObjectTypes <> Undefined Then
		Items.MainAddressingObject.TypeRestriction = MainAddressingObjectTypes;
	EndIf;
	Items.MainAddressingObject.Title = MainAddressingObjectTitle;
	
	Items.AdditionalAddressingObject.AutoMarkIncomplete = TypesOfAditionalAddressingObjectAreSet
		AND NOT UsedWithoutAddressingObjects;
	If AdditionalAddressingObjectTypes <> Undefined Then
		Items.AdditionalAddressingObject.TypeRestriction = AdditionalAddressingObjectTypes;
	EndIf;
	Items.AdditionalAddressingObject.Title = AdditionalAddressingObjectTitle;
	
	SetRoleAvailability(Record.PerformerRole);
EndProcedure

&AtServer
Procedure SetRoleAvailability(Role)
	
	RoleIsAvailableToExternalUsers = GetFunctionalOption("UseExternalUsers");
	If Not RoleIsAvailableToExternalUsers Then
		AssignmentOption = "UsersOnly"; 
		RoleIsAvailableToUsers = True;
	Else
		Query = New Query;
		Query.Text = 
		"SELECT
		|	AssigneeRolesAssignment.UsersType
		|FROM
		|	Catalog.PerformerRoles.Purpose AS AssigneeRolesAssignment
		|WHERE
		|	AssigneeRolesAssignment.Ref = &Ref";
		
		Query.SetParameter("Ref", Role);
		
		QueryResult = Query.Execute();
		DetailedRecordsSelection = QueryResult.Select();
		
		RoleIsAvailableToUsers = False;
		ExternalUsersAreNotAssignedForRole = True;
		While DetailedRecordsSelection.Next() Do
			If DetailedRecordsSelection.UsersType = Catalogs.Users.EmptyRef() Then
				RoleIsAvailableToUsers = True;
			Else
				ExternalUsersAreNotAssignedForRole = False;
			EndIf;
		EndDo;
		
		If ExternalUsersAreNotAssignedForRole Then
			RoleIsAvailableToExternalUsers = False;
		EndIf;
	EndIf;
	
	If RoleIsAvailableToExternalUsers AND RoleIsAvailableToUsers Then
		Items.Performer.ChooseType = True;
	Else
		If RoleIsAvailableToExternalUsers AND TypeOf(Record.Performer) = Type("CatalogRef.Users") Then
			Record.Performer = Catalogs.ExternalUsers.EmptyRef();
		ElsIf TypeOf(Record.Performer) = Type("CatalogRef.ExternalUsers") Then
			Record.Performer = Catalogs.Users.EmptyRef();
		EndIf;
		Items.Performer.ChooseType = False;
	EndIf;
	
EndProcedure


#EndRegion
