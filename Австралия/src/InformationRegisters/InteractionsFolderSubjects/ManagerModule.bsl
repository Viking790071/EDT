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
	|	ObjectUpdateAllowed(Interaction)";
	
EndProcedure

// End StandardSubsystems.AccessManagement

#EndRegion

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Update handlers

// Generates a blank structure to write to the InteractionsFolderSubjects information register.
//
Function InteractionAttributes() Export

	Result = New Structure;
	Result.Insert("Topic"                ,Undefined);
	Result.Insert("Folder"                  ,Undefined);
	Result.Insert("Reviewed"            ,Undefined);
	Result.Insert("ReviewAfter"       ,Undefined);
	Result.Insert("CalculateReviewedItems",True);
	
	Return Result;
	
EndFunction

// Sets a folder, subject, and review attributes for interactions.
//
// Parameters:
//  Ref - DocumentRef.IncomingEmail,
//                DocumentRef.OutgoingEmail,
//                DocumentRef.Meeting,
//                DocumentRef.PlannedInteraction,
//                DocumentRef.PhoneCall - an interaction, for which a folder and a subject will be set.
//  Attributes    - Structure - see InformationRegisters.InteractionsFolderSubjects. InteractionAttributes.
//  RecordSet - InformationRegister.InteractionsFolderSubjects.RecordSet - a register record set if 
//                 is created at the time of the procedure call.
//
Procedure WriteInteractionFolderSubjects(Interaction, Attributes, RecordSet = Undefined) Export
	
	Folder                   = Attributes.Folder;
	Topic                 = Attributes.Topic;
	Reviewed             = Attributes.Reviewed;
	ReviewAfter        = Attributes.ReviewAfter;
	CalculateReviewedItems = Attributes.CalculateReviewedItems;
	
	CreateAndWrite = (RecordSet = Undefined);
	
	If Folder = Undefined AND Topic = Undefined AND Reviewed = Undefined 
		AND ReviewAfter = Undefined  Then
		
		Return;
		
	ElsIf Folder = Undefined OR Topic = Undefined OR Reviewed = Undefined 
		OR ReviewAfter = Undefined Then
		
		Query = New Query;
		Query.Text = "
		|SELECT
		|	InteractionsFolderSubjects.Topic,
		|	InteractionsFolderSubjects.EmailMessageFolder,
		|	InteractionsFolderSubjects.Reviewed,
		|	InteractionsFolderSubjects.ReviewAfter
		|FROM
		|	InformationRegister.InteractionsFolderSubjects AS InteractionsFolderSubjects
		|WHERE
		|	InteractionsFolderSubjects.Interaction = &Interaction";
		
		Query.SetParameter("Interaction", Interaction);
		
		Result = Query.Execute();
		If NOT Result.IsEmpty() Then
			
			Selection = Result.Select();
			Selection.Next();
			
			If Folder = Undefined Then
				Folder = Selection.EmailMessageFolder;
			EndIf;
			
			If Topic = Undefined Then
				Topic = Selection.Topic;
			EndIf;
			
			If Reviewed = Undefined Then
				Reviewed = Selection.Reviewed;
			EndIf;
			
			If ReviewAfter = Undefined Then
				ReviewAfter = Selection.ReviewAfter;
			EndIf;
			
		EndIf;
	EndIf;
	
	If CreateAndWrite Then
		RecordSet = CreateRecordSet();
		RecordSet.Filter.Interaction.Set(Interaction);
	EndIf;
	Record = RecordSet.Add();
	Record.Interaction          = Interaction;
	Record.Topic                 = Topic;
	Record.EmailMessageFolder = Folder;
	Record.Reviewed             = Reviewed;
	Record.ReviewAfter        = ReviewAfter;
	RecordSet.AdditionalProperties.Insert("CalculateReviewedItems", CalculateReviewedItems);
	
	If CreateAndWrite Then
		RecordSet.Write();
	EndIf;
	
EndProcedure

Procedure BlockInteractionFoldersSubjects(Lock, Interactions) Export
	
	LockItem = Lock.Add("InformationRegister.InteractionsFolderSubjects"); 
	If TypeOf(Interactions) = Type("Array") Then
		For each InteractionHyperlink In Interactions Do
			LockItem.SetValue("Interaction", InteractionHyperlink);
		EndDo	
	Else
		LockItem.SetValue("Interaction", Interactions);
	EndIf;	
	
EndProcedure

Procedure BlochFoldersSubjects(Lock, DataSource, NameSourceField) Export
	
	LockItem = Lock.Add("InformationRegister.InteractionsFolderSubjects"); 
	LockItem.DataSource = DataSource;
	LockItem.UseFromDataSource("Interaction", NameSourceField);
	
EndProcedure

#EndRegion

#EndIf
