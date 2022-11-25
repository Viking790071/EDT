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
	
	SetConditionalAppearance();
	
	ConfigureRoleListRepresentation();
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	If EventName = "Write_ConstantsSet" AND Source = "UseExternalUsers" Then
		ConfigureRoleListRepresentation();
	EndIf;
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure ConfigureRoleListRepresentation()
	
	If GetFunctionalOption("UseExternalUsers") Then
		
		QueryText = "SELECT
		|	CatalogPerformersRoles.Ref,
		|	CatalogPerformersRoles.DeletionMark,
		|	CatalogPerformersRoles.Predefined,
		|	CatalogPerformersRoles.Code,
		|	CatalogPerformersRoles.Description,
		|	CatalogPerformersRoles.UsedWithoutAddressingObjects,
		|	CatalogPerformersRoles.UsedByAddressingObjects,
		|	CatalogPerformersRoles.MainAddressingObjectTypes,
		|	CatalogPerformersRoles.AdditionalAddressingObjectTypes,
		|	CatalogPerformersRoles.Comment,
		|	CASE
		|		WHEN CatalogPerformersRoles.UsedByAddressingObjects
		|			THEN TRUE
		|		WHEN CatalogPerformersRoles.Ref IN
		|				(SELECT TOP 1
		|					InformationRegister.TaskPerformers.PerformerRole.Ref
		|				FROM
		|					InformationRegister.TaskPerformers
		|				WHERE
		|					InformationRegister.TaskPerformers.PerformerRole = CatalogPerformersRoles.Ref)
		|			THEN TRUE
		|		ELSE FALSE
		|	END AS HasPerformers,
		|	CatalogPerformersRoles.ExternalRole,
		|	CatalogPerformersRoles.BriefPresentation
		|FROM
		|	Catalog.PerformerRoles AS CatalogPerformersRoles";
		
	Else
		
		QueryText = "SELECT
		|	CatalogPerformersRoles.Ref,
		|	CatalogPerformersRoles.DeletionMark,
		|	CatalogPerformersRoles.Predefined,
		|	CatalogPerformersRoles.Code,
		|	CatalogPerformersRoles.Description,
		|	CatalogPerformersRoles.UsedWithoutAddressingObjects,
		|	CatalogPerformersRoles.UsedByAddressingObjects,
		|	CatalogPerformersRoles.MainAddressingObjectTypes,
		|	CatalogPerformersRoles.AdditionalAddressingObjectTypes,
		|	CatalogPerformersRoles.Comment,
		|	CASE
		|		WHEN CatalogPerformersRoles.UsedByAddressingObjects
		|			THEN TRUE
		|		WHEN CatalogPerformersRoles.Ref IN
		|				(SELECT TOP 1
		|					InformationRegister.TaskPerformers.PerformerRole.Ref
		|				FROM
		|					InformationRegister.TaskPerformers
		|				WHERE
		|					InformationRegister.TaskPerformers.PerformerRole = CatalogPerformersRoles.Ref)
		|			THEN TRUE
		|		ELSE FALSE
		|	END AS HasPerformers,
		|	CatalogPerformersRoles.ExternalRole,
		|	CatalogPerformersRoles.BriefPresentation
		|FROM
		|	Catalog.PerformerRoles.Purpose AS AssigneeRolesAssignment
		|		LEFT JOIN Catalog.PerformerRoles AS CatalogPerformersRoles
		|		ON AssigneeRolesAssignment.Ref = CatalogPerformersRoles.Ref
		|WHERE
		|	AssigneeRolesAssignment.UsersType = VALUE(Catalog.Users.EmptyRef)";
	EndIf;
	
	ListProperties = Common.DynamicListPropertiesStructure();
	ListProperties.MainTable              = "Catalog.PerformerRoles";
	ListProperties.DynamicDataRead = True;
	ListProperties.QueryText                 = QueryText;
	Common.SetDynamicListProperties(Items.List, ListProperties);
	
EndProcedure

&AtServer
Procedure SetConditionalAppearance()
	
	List.ConditionalAppearance.Items.Clear();
	Item = List.ConditionalAppearance.Items.Add();
	
	FilterItemsGroup = Item.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	FilterItemsGroup .GroupType = DataCompositionFilterItemsGroupType.AndGroup;
	
	ItemFilter = FilterItemsGroup.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("HasPerformers");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;
	
	ItemFilter = FilterItemsGroup.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ExternalRole");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;
	
	Item.Appearance.SetParameterValue("TextColor", StyleColors.RoleWithoutPerformers);
	
EndProcedure

#EndRegion
