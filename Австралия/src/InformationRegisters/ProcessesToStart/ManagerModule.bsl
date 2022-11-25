///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Private

// Adds information about successful process start.
//
// Parameters:
//   - BusinessProcess - BusinessProcessRef.
//
Procedure RegisterProcessStart(Process) Export
	
	Record = CreateRecordManager();
	Record.Owner = Process;
	Record.Read();
	
	If Not Record.Selected() Then
		Return;
	EndIf;
	
	Record.Delete();
	
EndProcedure

// Adds information about process start cancellation.
//
// Parameters:
//   - BusinessProcess - BusinessProcessRef.
//
Procedure RegisterStartCancellation(Process, CancellationReason) Export
	
	Record = CreateRecordManager();
	Record.Owner = Process;
	Record.Read();
	
	If Not Record.Selected() Then
		Return;
	EndIf;
	
	Record.State = Enums.ProcessesStatesForStart.StartCanceled;
	Record.StartCancelReason = CancellationReason;
	
	Record.Write();
	
EndProcedure

#EndRegion

#EndIf