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
//  Folder - Catalog.EmailsFolders, Undefined - a folder, for which the record is being deleted.
//          If the Undefined value is specified, the register will be cleared.
//
Procedure DeleteRecordFromRegister(Folder = Undefined) Export
	
	SetPrivilegedMode(True);
	
	RecordSet = CreateRecordSet();
	If Folder <> Undefined Then
		RecordSet.Filter.Folder.Set(Folder);
	EndIf;
	
	RecordSet.Write();
	
EndProcedure

// Writes to the information register for the specified folder.
//
// Parameters:
//  Folder - Catalog.EmailsFolders - a folder to be recorded.
//  Count  - Number - a number of unreviewed interactions for this folder.
//
Procedure ExecuteRecordToRegister(Folder, Count) Export

	SetPrivilegedMode(True);
	
	Record = CreateRecordManager();
	Record.Folder = Folder;
	Record.NotReviewedInteractionsCount = Count;
	Record.Write(True);

EndProcedure

Procedure BlockEmailsFoldersStatus(Lock, DataSource, NameSourceField) Export
	
	LockItem = Lock.Add("InformationRegister.EmailFolderStates"); 
	LockItem.DataSource = DataSource;
	LockItem.UseFromDataSource("Folder", NameSourceField);
	
EndProcedure

#EndRegion

#EndIf