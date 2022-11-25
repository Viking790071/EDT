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

// StandardSubsystems.BatchObjectsModification

// Returns object attributes allowed to be edited using batch attribute change data processor.
// 
//
// Returns:
//  Array - a list of object attribute names.
Function AttributesToEditInBatchProcessing() Export
	
	Result = New Array;
	Result.Add("Author");
	Result.Add("Importance");
	Result.Add("StartDate");
	Result.Add("EndDate");
	Result.Add("EmployeeResponsible");
	Result.Add("InteractionBasis");
	Result.Add("Comment");
	Result.Add("Members.Contact");
	Result.Add("Members.ContactPresentation");
	Result.Add("Members.HowToContact");
	Return Result;
	
EndFunction

// End StandardSubsystems.BatchObjectsModification

// StandardSubsystems.Interactions

// Gets meeting attendees.
//
// Parameters:
//  Ref - DocumentRef.Meeting - a document whose contacts are to be received.
//
// Returns:
//   ValueTable - a table that contains the Contact, Presentation, and Address columns.
//
Function GetContacts(Ref) Export
	
	Return Interactions.GetParticipantsByTable(Ref);
	
EndFunction

// End StandardSubsystems.Interactions

// StandardSubsystems.AccessManagement

// See AccessManagementOverridable.OnFillListsWithAccessRestriction. 
Procedure OnFillAccessRestriction(Restriction) Export
	
	Restriction.Text =
	"AllowReadUpdate
	|WHERE
	|	ValueAllowed(EmployeeResponsible, Disabled AS False)
	|	OR ValueAllowed(Author, Disabled AS False)";
	
EndProcedure

// End StandardSubsystems.AccessManagement

// StandardSubsystems.AttachableCommands

// Defined the list of commands for creating on the basis.
//
// Parameters:
//  GenerationCommands - ValueTable - see GenerationOverridable.BeforeAddGenerationCommands. 
//  Parameters - Structure - see GenerationOverridable.BeforeAddGenerationCommands. 
//
Procedure AddGenerationCommands(GenerationCommands, Parameters) Export
	
	AddGenerateCommand(GenerationCommands);
	Documents.PlannedInteraction.AddGenerateCommand(GenerationCommands);
	Documents.SMSMessage.AddGenerateCommand(GenerationCommands);
	Documents.PhoneCall.AddGenerateCommand(GenerationCommands);
	Documents.OutgoingEmail.AddGenerateCommand(GenerationCommands);
	
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
	
	Command = Generate.AddGenerationCommand(GenerationCommands, Metadata.Documents.Meeting);
	If Command <> Undefined Then
		Command.FunctionalOptions = "UseOtherInteractions";
	EndIf;
	
	Return Command;
	
EndFunction

// End StandardSubsystems.AttachableCommands

#EndRegion

#EndRegion

#Region EventHandlers

Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	InteractionsEvents.ChoiceDataGetProcessing(Metadata.Documents.Meeting.Name,
		ChoiceData, Parameters, StandardProcessing);
	
EndProcedure

#EndRegion

#EndIf
