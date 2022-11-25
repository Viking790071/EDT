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
	
	Performers.Parameters.SetParameterValue("NoAddressObject", NStr("ru = '<Без объекта адресации>'; en = '<Without addressing object>'; pl = '<Bez obiektu adresującego>';es_ES = '<Sin objeto de direccionamiento>';es_CO = '<Sin objeto de direccionamiento>';tr = '<Gönderim hedefi yok>';it = '<senza oggetto di indirizzamento>';de = '<Ohne Objekt von Adressierung>'"));
	
	ConfigureRoleListRepresentation();

EndProcedure

&AtServer
Procedure ConfigureRoleListRepresentation()
	
	Var GroupField, RoleProperties;
	
	CommonClientServer.SetDynamicListFilterItem(Performers, 
	"PerformerRole", Parameters.PerformerRole, DataCompositionComparisonType.Equal);
	RoleProperties = Common.ObjectAttributesValues(Parameters.PerformerRole, "UsedByAddressingObjects,AdditionalAddressingObjectTypes,MainAddressingObjectTypes");
	If RoleProperties.UsedByAddressingObjects Then
		GroupField = Performers.Group.Items.Add(Type("DataCompositionGroupField"));
		GroupField.Field = New DataCompositionField("MainAddressingObject");
		GroupField.Use = True;
		If Not RoleProperties.AdditionalAddressingObjectTypes.IsEmpty() Then
			GroupField = Performers.Group.Items.Add(Type("DataCompositionGroupField"));
			GroupField.Field = New DataCompositionField("AdditionalAddressingObject");
			GroupField.Use = True;
		EndIf;
	EndIf;

EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure PerformersAfterDeletion(Item)
	Notify("Write_RoleAddressing", Undefined, Undefined);
EndProcedure

#EndRegion


#Region Private

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearanceItem = Performers.ConditionalAppearance.Items.Add();
	ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	
	FormattedField = ConditionalAppearanceItem.Fields.Items.Add();
	FormattedField.Field = New DataCompositionField("Performer");
	FormattedField.Use = True;
	
	DataFilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue = New DataCompositionField("Performer.Invalid");
	DataFilterItem.ComparisonType = DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue = True;
	
	ConditionalAppearanceItem.Appearance.SetParameterValue("TextColor", Metadata.StyleItems.InaccessibleCellTextColor.Value);
	
EndProcedure


#EndRegion