///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region ForCallsFromOtherSubsystems

// End StandardSubsystems.BatchObjectsModification

// StandardSubsystems.AccessManagement

// See AccessManagementOverridable.OnFillListsWithAccessRestriction. 
Procedure OnFillAccessRestriction(Restriction) Export
	
	Restriction.Text =
	"AllowReadUpdate
	|WHERE
	|	ValueAllowed(Author)
	|	OR NOT AvailableToAuthorOnly";
	
EndProcedure

// End StandardSubsystems.AccessManagement

// StandardSubsystems.AttachableCommands

// Defines the list of commands for generating objects.
//
// Parameters:
//  GenerationCommands - ValueTable - see GenerationOverridable.BeforeAddGenerationCommands. 
//  Parameters - Structure - see GenerationOverridable.BeforeAddGenerationCommands. 
//
Procedure AddGenerationCommands(GenerationCommands, Parameters) Export
	
EndProcedure

// Use this procedure in the AddGenerationCommands procedure of other object manager modules.
// Adds this object to the list of object generation commands.
//
// Parameters:
//  GenerationCommands - ValueTable - see GenerationOverridable.BeforeAddGenerationCommands. 
//
// Returns:
//  ValueTableRow, Undefined - details of the added command.
//
Function AddGenerateCommand(GenerationCommands) Export
	
	If Common.SubsystemExists("StandardSubsystems.AttachableCommands") Then
		ModuleGeneration = Common.CommonModule("Generate");
		Return ModuleGeneration.AddGenerationCommand(GenerationCommands, Metadata.Catalogs.MessageTemplates);
	EndIf;
	
	Return Undefined;
	
EndFunction

// End StandardSubsystems.AttachableCommands

#EndRegion

#EndRegion

#Region EventHandlers

Procedure FormGetProcessing(FormType, Parameters, SelectedForm, AdditionalInformation, StandardProcessing)

	If Parameters.Property("TemplateOwner") AND ValueIsFilled(Parameters.TemplateOwner) Then
		Parameters.Insert("TemplateOwner", Parameters.TemplateOwner);
		If Parameters.Property("New") AND Parameters.New <> True Then
			Parameters.Insert("Key", MessageTemplatesInternal.TemplateByOwner(Parameters.TemplateOwner));
		EndIf;
		SelectedForm = "Catalog.MessageTemplates.ObjectForm";
		StandardProcessing = False;
	EndIf;
	
EndProcedure

#EndRegion

#EndIf
