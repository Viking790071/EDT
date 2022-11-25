///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Private

// Deletes one record or all records from the register.
//
// Parameters:
//  Subject - DocumentRef, CatalogRef, Undefined - a subject, for which the record is being deleted.
//                                                              If the Undefined value is specified, 
//                                                              the register will be cleared.
//
Procedure DeleteRecordFromRegister(Topic = Undefined) Export
	
	SetPrivilegedMode(True);
	
	RecordSet = CreateRecordSet();
	If Topic <> Undefined Then
		RecordSet.Filter.Topic.Set(Topic);
	EndIf;
	
	RecordSet.Write();
	
EndProcedure

// Writes to the information register for the specified subject.
//
// Parameters:
//  Subject                       - DocumentRef, CatalogRef - a subject to be recorded.
//  NotReviewedInteractionsCount       - Number - a number of unreviewed interactions for the subject.
//  LastInteractionDate - DateTime - a date of last interaction on the subject.
//  Active                         - Boolean - indicates that the subject is active.
//
Procedure ExecuteRecordToRegister(Topic,
	                              NotReviewedInteractionsCount = Undefined,
	                              LastInteractionDate = Undefined,
	                              Active = Undefined) Export
	
	SetPrivilegedMode(True);
	
	If NotReviewedInteractionsCount = Undefined AND LastInteractionDate = Undefined AND Active = Undefined Then
		
		Return;
		
	ElsIf NotReviewedInteractionsCount = Undefined OR LastInteractionDate = Undefined OR Active = Undefined Then
		
		Query = New Query;
		Query.Text = "
		|SELECT
		|	InteractionsSubjectsStates.Topic,
		|	InteractionsSubjectsStates.NotReviewedInteractionsCount,
		|	InteractionsSubjectsStates.LastInteractionDate,
		|	InteractionsSubjectsStates.IsActive
		|FROM
		|	InformationRegister.InteractionsSubjectsStates AS InteractionsSubjectsStates
		|WHERE
		|	InteractionsSubjectsStates.Topic = &Topic";
		
		Query.SetParameter("Topic",Topic);
		
		Result = Query.Execute();
		If NOT Result.IsEmpty() Then
			
			Selection = Result.Select();
			Selection.Next();
			
			If NotReviewedInteractionsCount = Undefined Then
				NotReviewedInteractionsCount = Selection.NotReviewedInteractionsCount;
			EndIf;
			
			If LastInteractionDate = Undefined Then
				LastInteractionDate = LastInteractionDate.Topic;
			EndIf;
			
			If Active = Undefined Then
				Active = Selection.IsActive;
			EndIf;
			
		EndIf;
	EndIf;

	RecordSet = CreateRecordSet();
	RecordSet.Filter.Topic.Set(Topic);
	
	Record = RecordSet.Add();
	Record.Topic                      = Topic;
	Record.NotReviewedInteractionsCount      = NotReviewedInteractionsCount;
	Record.LastInteractionDate = LastInteractionDate;
	Record.IsActive                      = Active;
	RecordSet.Write();

EndProcedure

Procedure BlockInteractionObjectsStatus(Lock, DataSource, NameSourceField) Export
	
	LockItem = Lock.Add("InformationRegister.InteractionsSubjectsStates"); 
	LockItem.DataSource = DataSource;
	LockItem.UseFromDataSource("Topic", NameSourceField);
	
EndProcedure

#EndRegion

#EndIf