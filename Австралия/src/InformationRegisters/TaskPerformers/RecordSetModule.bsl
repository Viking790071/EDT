///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Variables

// StandardSubsystems.AccessManagement
Var ModifiedPerformersGroups; // Modified assignee groups.
// End StandardSubsystems.AccessManagement

#EndRegion

#Region EventHandlers

Procedure BeforeWrite(Cancel, Replacing)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Count() > 0 Then
		NewTasksPerformers = Unload();
		SetPrivilegedMode(True);
		TaskPerformersGroups = BusinessProcessesAndTasksServer.TaskPerformersGroups(NewTasksPerformers);
		SetPrivilegedMode(False);
		Index = 0;
		For each Record In ThisObject Do
			Record.TaskPerformersGroup = TaskPerformersGroups[Index];
			Index = Index + 1;
		EndDo
	EndIf;
		
	// StandardSubsystems.AccessManagement
	FillModifiedTaskPerformersGroups();
	// End StandardSubsystems.AccessManagement
	
EndProcedure

// StandardSubsystems.AccessManagement

Procedure OnWrite(Cancel, Replacing)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
	ModuleAccessManagementInternal.UpdatePerformersGroupsUsers(ModifiedPerformersGroups);
	
EndProcedure

#EndRegion

#Region Private

Procedure FillModifiedTaskPerformersGroups()
	
	Query = New Query;
	Query.SetParameter("NewRecords", Unload());
	Query.Text =
	"SELECT
	|	NewRecords.PerformerRole,
	|	NewRecords.Performer,
	|	NewRecords.MainAddressingObject,
	|	NewRecords.AdditionalAddressingObject,
	|	NewRecords.TaskPerformersGroup
	|INTO NewRecords
	|FROM
	|	&NewRecords AS NewRecords
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Total.TaskPerformersGroup
	|FROM
	|	(SELECT DISTINCT
	|		Differences.TaskPerformersGroup AS TaskPerformersGroup
	|	FROM
	|		(SELECT
	|			TaskPerformers.PerformerRole AS PerformerRole,
	|			TaskPerformers.Performer AS Performer,
	|			TaskPerformers.MainAddressingObject AS MainAddressingObject,
	|			TaskPerformers.AdditionalAddressingObject AS AdditionalAddressingObject,
	|			TaskPerformers.TaskPerformersGroup AS TaskPerformersGroup,
	|			-1 AS RowChangeKind
	|		FROM
	|			InformationRegister.TaskPerformers AS TaskPerformers
	|		WHERE
	|			&FilterConditions
	|		
	|		UNION ALL
	|		
	|		SELECT
	|			NewRecords.PerformerRole,
	|			NewRecords.Performer,
	|			NewRecords.MainAddressingObject,
	|			NewRecords.AdditionalAddressingObject,
	|			NewRecords.TaskPerformersGroup,
	|			1
	|		FROM
	|			NewRecords AS NewRecords) AS Differences
	|	
	|	GROUP BY
	|		Differences.PerformerRole,
	|		Differences.Performer,
	|		Differences.MainAddressingObject,
	|		Differences.AdditionalAddressingObject,
	|		Differences.TaskPerformersGroup
	|	
	|	HAVING
	|		SUM(Differences.RowChangeKind) <> 0) AS Total
	|WHERE
	|	Total.TaskPerformersGroup <> VALUE(Catalog.TaskPerformersGroups.EmptyRef)";
	
	FilterConditions = "True";
	For each FilterItem In Filter Do
		If FilterItem.Use Then
			FilterConditions = FilterConditions + "
			|AND TaskPerformers." + FilterItem.Name + " = &" + FilterItem.Name;
			Query.SetParameter(FilterItem.Name, FilterItem.Value);
		EndIf;
	EndDo;
	
	Query.Text = StrReplace(Query.Text, "&FilterConditions", FilterConditions);
	ModifiedPerformersGroups = Query.Execute().Unload().UnloadColumn("TaskPerformersGroup");
	
EndProcedure

// End StandardSubsystems.AccessManagement

#EndRegion

#Else
Raise NStr("ru = 'Недопустимый вызов объекта на клиенте.'; en = 'Invalid object call on the client.'; pl = 'Niepoprawne wywołanie obiektu w kliencie.';es_ES = 'Invalidar la llamada de objeto al cliente.';es_CO = 'Invalidar la llamada de objeto al cliente.';tr = 'İstemcide geçersiz nesne çağrısı.';it = 'Chiamata oggetto non valida per il client.';de = 'Ungültiger Objektabruf beim Kunden.'");
#EndIf